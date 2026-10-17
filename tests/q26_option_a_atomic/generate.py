#!/usr/bin/env python3
"""Reconstruct the frozen atomic gate using a verified public consumer-suite directory.
No SQL, shell, network, compression, binary codec or private map is used.
"""
import argparse,hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parent
SHA=lambda value:hashlib.sha256(value).hexdigest()
def load(name):return json.loads((ROOT/name).read_text())
def verified_file(root,name,contract):
    raw=(root/name).read_bytes()
    if len(raw)!=contract['bytes'] or SHA(raw)!=contract['sha256']:
        raise SystemExit('checksum mismatch: '+name)
    return raw

def build(consumer_dir):
    source=load('SOURCE_MANIFEST.json')
    for entry in source['files']:
        verified_file(ROOT,entry['name'],entry)
    dependency=load('CONSUMER_DEPENDENCY.json')
    consumer_files={name:verified_file(consumer_dir,name,contract)
                    for name,contract in dependency['files'].items()}
    extraction=dependency['named_extraction']
    consumer_sql=consumer_files['option_a_full_consumers.sql'].decode('utf-8')
    marker=extraction['end_marker']
    if marker not in consumer_sql:raise SystemExit('named consumer prefix boundary missing')
    prefix=consumer_sql.split(marker,1)[0]
    if len(prefix.encode())!=extraction['original_prefix_bytes'] or SHA(prefix.encode())!=extraction['original_prefix_sha256']:
        raise SystemExit('named consumer prefix checksum mismatch')
    matches=list(re.finditer(r'DO \$empty\$.*?END \$empty\$;',prefix,re.S))
    if len(matches)!=1:raise SystemExit('exactly one initial guard required')
    old_guard=matches[0].group()
    if SHA(old_guard.encode())!=extraction['original_empty_guard_sha256']:
        raise SystemExit('original consumer guard checksum mismatch')
    # The atomic package already froze this stricter guard. Consumer outputs stay untouched.
    atomic_guard=(ROOT/'frozen_files/empty_instance_guard.sql').read_text().rstrip('\n')
    prefix=prefix.replace(old_guard,atomic_guard,1)
    if len(prefix.encode())!=extraction['atomic_prefix_bytes'] or SHA(prefix.encode())!=extraction['atomic_prefix_sha256']:
        raise SystemExit('frozen atomic prefix checksum mismatch')
    suffix=(ROOT/'atomic_suffix.template.sql').read_text()
    controls={name:(ROOT/'frozen_files'/(name+'_control_synthetic.sql')).read_text() for name in ['apply','rollback']}
    slots=re.findall(r'@@CONTROL:(apply|rollback)@@',suffix)
    if sorted(slots)!=['apply','rollback']:raise SystemExit('two exact named control slots required')
    suffix=re.sub(r'@@CONTROL:(apply|rollback)@@',lambda match:controls[match.group(1)],suffix)
    outputs={p.name:p.read_bytes() for p in (ROOT/'frozen_files').iterdir() if p.is_file()}
    outputs['atomic_setup.sql']=(prefix+suffix).encode('utf-8')
    expected=load('OUTPUT_CONTRACT.json')
    if set(outputs)!=set(expected['files']):raise SystemExit('frozen atomic filename set changed')
    for name,raw in outputs.items():
        contract=expected['files'][name]
        if len(raw)!=contract['bytes'] or SHA(raw)!=contract['sha256']:
            raise SystemExit('frozen atomic output mismatch: '+name)
    return outputs,expected

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--consumer-dir',type=Path,required=True,help='Previously reconstructed exact public consumer339 output directory')
    parser.add_argument('--output',type=Path,required=True,help='New empty atomic output directory')
    args=parser.parse_args()
    outputs,expected=build(args.consumer_dir)
    if args.output.exists() and any(args.output.iterdir()):raise SystemExit('output directory must be empty')
    args.output.mkdir(parents=True,exist_ok=True)
    for name,raw in sorted(outputs.items()):(args.output/name).write_bytes(raw)
    print(json.dumps({'files_reconstructed':len(outputs),'all_bytes_match':True,
                      'atomic_manifest_sha256':expected['frozen_atomic_manifest_sha256'],
                      'expected_results':[175,10,4],'sql_executed':False},sort_keys=True))
if __name__=='__main__':main()
