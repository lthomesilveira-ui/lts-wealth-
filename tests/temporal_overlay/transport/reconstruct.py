"""Rebuild the exact, frozen synthetic PG85 package. No SQL/network/compression.
The operator must first review/pin this script and TRANSPORT_MANIFEST.json.
All builders are executed from verified captured bytes, only in a private temp dir.
"""
from pathlib import Path
from contextlib import redirect_stdout
from io import StringIO
import argparse
import hashlib
import json
import os
import re
import stat
import tempfile

TARGET_MANIFEST_SHA256='b96a934778a7cbe8d38f71b0067c074a30d85918b94f4fb513165ca2bc8cc831'
OUTPUT_PINS_SHA256='9e0592a87e02ccec54d7d7eb2616d24557473e49f6cb6521bbfa8625ab145dee'
GENERATED={'inputs.json','expected.json','case-catalog.json','overlay_contract.sql'}
SEEDS={'README.md','baseline-28.json','build_cases.py','build_sql.py','overlay_reference.py','verify_results.py','run_pg17.py','test_package.py','PACKAGE_MANIFEST.json'}
OUTPUT_NAMES=SEEDS|GENERATED
TRANSPORT_NAMES={'reconstruct.py','RECONSTRUCTION_README.md','OUTPUT_PINS.json'}|{'seeds/'+n for n in SEEDS}
MANIFEST_NAME='TRANSPORT_MANIFEST.json'
MAX_FILE_BYTES=1024*1024

class RebuildError(ValueError): pass

def sha(data): return hashlib.sha256(data).hexdigest()
def require(condition,message):
    if not condition: raise RebuildError(message)
def strict_json(data):
    def pairs(items):
        out={}
        for k,v in items:
            require(k not in out,'duplicate JSON key: '+k);out[k]=v
        return out
    return json.loads(data.decode('utf-8'),object_pairs_hook=pairs,
                      parse_constant=lambda v: (_ for _ in ()).throw(RebuildError('nonfinite JSON')))
def read_regular(path,dir_fd=None):
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK,dir_fd=dir_fd)
    try:
        st=os.fstat(fd)
        require(stat.S_ISREG(st.st_mode),'not regular file: '+str(path))
        require(st.st_size<=MAX_FILE_BYTES,'oversized file: '+str(path))
        with os.fdopen(fd,'rb',closefd=False) as f: data=f.read(MAX_FILE_BYTES+1)
        require(len(data)<=MAX_FILE_BYTES,'oversized snapshot')
        return data
    finally: os.close(fd)
def exact_tree(root,names,allow_seeds=False):
    require(root.is_dir() and not root.is_symlink(),'root must be a real directory')
    actual=set()
    for entry in root.iterdir():
        require(not entry.is_symlink(),'symlink rejected: '+entry.name)
        if entry.is_dir():
            require(allow_seeds and entry.name=='seeds','unexpected directory: '+entry.name)
            for child in entry.iterdir():
                require(child.is_file() and not child.is_symlink(),'non-regular seed')
                actual.add('seeds/'+child.name)
        else:
            require(entry.is_file(),'non-regular member');actual.add(entry.name)
    require(actual==set(names),'member names differ: '+repr(sorted(actual^set(names))))
def valid_descriptor(row):
    return (isinstance(row,dict) and set(row)=={'name','bytes','sha256'} and
            isinstance(row['name'],str) and type(row['bytes']) is int and
            0<=row['bytes']<=MAX_FILE_BYTES and isinstance(row['sha256'],str) and
            re.fullmatch('[0-9a-f]{64}',row['sha256']) is not None)
def descriptor_map(rows,names):
    require(isinstance(rows,list) and all(valid_descriptor(x) for x in rows),'invalid descriptors')
    require(len(rows)==len(names) and {x['name'] for x in rows}==names,'descriptor names differ')
    return {x['name']:x for x in rows}
def check_bytes(name,data,pin):
    require(len(data)==pin['bytes'],'size mismatch: '+name)
    require(sha(data)==pin['sha256'],'SHA256 mismatch: '+name)
def scan(data):
    text=data.decode('utf-8')
    for pattern in (r'\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b',
                    r'https?://[^\s/]+\.(?:supabase|vercel)\.',
                    r'\b(?:eyJ[A-Za-z0-9_-]{30,}|sb_secret_[A-Za-z0-9]+)\b',
                    r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'):
        require(re.search(pattern,text) is None,'synthetic privacy scan rejected')
def snapshot_transport(root,manifest_pin):
    require(re.fullmatch('[0-9a-f]{64}',manifest_pin or '') is not None,'external manifest pin required')
    exact_tree(root,TRANSPORT_NAMES|{MANIFEST_NAME},allow_seeds=True)
    # Capture every byte once. Later stages use only these snapshots.
    snap={name:read_regular(root/name) for name in sorted(TRANSPORT_NAMES|{MANIFEST_NAME})}
    require(sha(snap[MANIFEST_NAME])==manifest_pin,'transport manifest pin mismatch')
    manifest=strict_json(snap[MANIFEST_NAME])
    require(set(manifest)=={'format','files','target_manifest_sha256','synthetic_only'},'invalid transport manifest fields')
    require(manifest['format']=='pg85_readable_reconstruction_v1' and manifest['synthetic_only'] is True,'invalid transport format')
    require(manifest['target_manifest_sha256']==TARGET_MANIFEST_SHA256,'wrong target package')
    transport_pins=descriptor_map(manifest['files'],TRANSPORT_NAMES)
    for name in TRANSPORT_NAMES:
        check_bytes(name,snap[name],transport_pins[name]);scan(snap[name])
    require(sha(snap['OUTPUT_PINS.json'])==OUTPUT_PINS_SHA256,'independent output pins changed')
    pins_doc=strict_json(snap['OUTPUT_PINS.json'])
    require(set(pins_doc)=={'format','target_manifest_sha256','outputs'},'invalid output pins fields')
    require(pins_doc['format']=='overlay_pg85_exact_output_pins_v1' and pins_doc['target_manifest_sha256']==TARGET_MANIFEST_SHA256,'invalid output pins')
    pins=descriptor_map(pins_doc['outputs'],OUTPUT_NAMES)
    # Independent target pins also lock every builder/seed before exec. Changing
    # a source plus its transport hash cannot authorize another program/oracle.
    for name in SEEDS: check_bytes(name,snap['seeds/'+name],pins[name])
    require(sha(snap['seeds/PACKAGE_MANIFEST.json'])==TARGET_MANIFEST_SHA256,'original manifest changed')
    return snap,pins

def run_builders(stage,snap):
    for name in SEEDS:(stage/name).write_bytes(snap['seeds/'+name])
    # Neither run_pg17.py nor any SQL is executed. These two exact frozen
    # builders import only standard-library modules and write four text files.
    for name in ('build_cases.py','build_sql.py'):
        code=compile(snap['seeds/'+name],str(stage/name),'exec')
        with redirect_stdout(StringIO()):
            exec(code,{'__name__':'__main__','__file__':str(stage/name)})

def validated_outputs(stage,pins):
    exact_tree(stage,OUTPUT_NAMES)
    out={name:read_regular(stage/name) for name in sorted(OUTPUT_NAMES)}
    for name,data in out.items():check_bytes(name,data,pins[name]);scan(data)
    # Check embedded legacy manifest agrees with all twelve original members.
    original=strict_json(out['PACKAGE_MANIFEST.json'])
    require(sha(out['PACKAGE_MANIFEST.json'])==TARGET_MANIFEST_SHA256,'target manifest mismatch')
    require({x['path'] for x in original['files']}==OUTPUT_NAMES-{'PACKAGE_MANIFEST.json'},'target members differ')
    for row in original['files']:require(sha(out[row['path']])==row['sha256'],'legacy member hash mismatch')
    return out

def same_directory(parent_fd,name,expected):
    try:
        current=os.stat(name,dir_fd=parent_fd,follow_symlinks=False)
        return stat.S_ISDIR(current.st_mode) and (current.st_dev,current.st_ino)==(expected.st_dev,expected.st_ino)
    except OSError:return False

def emit_new(output,out,pins):
    # Pin directory descriptors. O_NOFOLLOW only on a child path would not
    # prevent an attacker replacing the output directory itself with a link.
    parent_fd=os.open(output.parent,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
    output_fd=None;created={};identity=None
    try:
        # Exclusive even if another caller wins after initial path validation.
        os.mkdir(output.name,mode=0o700,dir_fd=parent_fd)
        output_fd=os.open(output.name,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=parent_fd)
        identity=os.fstat(output_fd)
        require(same_directory(parent_fd,output.name,identity),'output directory replaced')
        for name in sorted(out):
            fd=os.open(name,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600,dir_fd=output_fd)
            st=os.fstat(fd);created[name]=(st.st_dev,st.st_ino)
            with os.fdopen(fd,'wb') as f:f.write(out[name])
        require(set(os.listdir(output_fd))==OUTPUT_NAMES,'post-write member names differ')
        final={name:read_regular(name,dir_fd=output_fd) for name in sorted(OUTPUT_NAMES)}
        for name,data in final.items():check_bytes(name,data,pins[name]);scan(data)
        require(final==out,'post-write bytes differ')
        require(same_directory(parent_fd,output.name,identity),'output directory replaced')
        # The originally resolved parent must still be the same directory.
        current_parent=os.stat(output.parent,follow_symlinks=False)
        pinned_parent=os.fstat(parent_fd)
        require(stat.S_ISDIR(current_parent.st_mode) and
                (current_parent.st_dev,current_parent.st_ino)==(pinned_parent.st_dev,pinned_parent.st_ino),
                'output parent replaced')
    except BaseException:
        # Cleanup is relative to our pinned directory, never a substituted path.
        if output_fd is not None:
            for name,created_identity in created.items():
                try:
                    current=os.stat(name,dir_fd=output_fd,follow_symlinks=False)
                    if (current.st_dev,current.st_ino)==created_identity:
                        os.unlink(name,dir_fd=output_fd)
                except OSError:pass
        if identity is not None and same_directory(parent_fd,output.name,identity):
            try:os.rmdir(output.name,dir_fd=parent_fd)
            except OSError:pass
        raise
    finally:
        if output_fd is not None:os.close(output_fd)
        os.close(parent_fd)

def reconstruct(root,output,manifest_pin):
    root=Path(root);output=Path(output)
    require(not os.path.lexists(output),'output already exists')
    require(output.parent.is_dir() and not output.parent.is_symlink(),'output parent must exist and not be a symlink')
    require(output.name not in ('','.', '..'),'invalid output name')
    # resolve the parent once, not an output that does not yet exist.
    output=output.parent.resolve(strict=True)/output.name
    snap,pins=snapshot_transport(root,manifest_pin)
    with tempfile.TemporaryDirectory(prefix='.pg85-rebuild-',dir=output.parent) as temp:
        stage=Path(temp)
        run_builders(stage,snap)
        out=validated_outputs(stage,pins)
    emit_new(output,out,pins)
    return {'status':'exact_reconstruction_pass','target_manifest_sha256':TARGET_MANIFEST_SHA256,
            'files':len(out),'bytes':sum(len(x) for x in out.values()),'privacy_scan_passed':True,
            'sql_executed':False,'pg_executed':False}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--expected-transport-manifest-sha256',required=True)
    args=parser.parse_args()
    try:
        report=reconstruct(Path(__file__).resolve().parent,args.output,args.expected_transport_manifest_sha256)
    except (OSError,ValueError,TypeError,KeyError) as e:
        parser.exit(1,'reconstruction refused: '+str(e)+'\n')
    print(json.dumps(report,sort_keys=True))
if __name__=='__main__':main()
