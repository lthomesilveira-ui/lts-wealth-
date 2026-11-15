"""Recheck an existing deferred snapshot after a transient projection read failure."""
import argparse, hashlib, json, shutil, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'releases/v447'
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def replace_once(path, old, new):
    s=path.read_text(); assert s.count(old)==1,(path,old)
    path.write_text(s.replace(old,new))
def build(target):
    shutil.copytree(BASE,target)
    p=target/'app.html';p.write_text(p.read_text().replace('V447','V448'))
    p=target/'lts-v227-read-transport.js'
    old="document.documentElement.setAttribute('data-lts-v227-reads',JSON.stringify(events));};"
    new="""document.documentElement.setAttribute('data-lts-v227-reads',JSON.stringify(events));
   // Ingestion may invalidate the projection snapshot after the opening read.
   // Ask the existing controller to observe its job; never enqueue a new job,
   // retry a writer, mask the failure or relax a source guard here.
   if(entry.name==='lts_browser_recurring_future_gap_audit_v5'&&entry.status>=500&&entry.status<600)
    window.dispatchEvent(new Event('lts:deferred-read-failed'));
  };"""
    replace_once(p,old,new)
    p=target/'lts-v415-product-refresh.js'
    replace_once(p,"win.removeEventListener('lts:data-invalidated', invalidated);", "win.removeEventListener('lts:data-invalidated', invalidated); win.removeEventListener('lts:deferred-read-failed', invalidated);")
    replace_once(p,"win.addEventListener('lts:data-invalidated', invalidated);", "win.addEventListener('lts:data-invalidated', invalidated); win.addEventListener('lts:deferred-read-failed', invalidated);")
    (target/'provenance.json').write_text(json.dumps({'release':'v448','base_release':'v447','scope':'Observe the existing refresh job after a transient deferred projection read failure','financial_readers_changed':False,'financial_writers_changed':False,'source_guards_changed':False,'authentication_changed':False,'query_deadlines_changed':False,'physical_mobile_validated':False},indent=2)+'\n')
    m={'release':'v448','version':'v448','base_release':'v447','entry':'app.html','protected_manifest':{'path':'releases/v447/manifest.json','sha256':digest(BASE/'manifest.json')},'files':{p.name:digest(p) for p in sorted(target.iterdir()) if p.name!='manifest.json'}}
    (target/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--check',action='store_true');a=a.parse_args()
    with tempfile.TemporaryDirectory() as t:
        expected=Path(t)/'v448';build(expected);actual=ROOT/'releases/v448'
        if a.check: assert {p.name:p.read_bytes() for p in actual.iterdir()}=={p.name:p.read_bytes() for p in expected.iterdir()}
        else:
            assert not actual.exists(),'Never overwrite a release'
            shutil.copytree(expected,actual)
    print(json.dumps({'pass':True,'release':'v448','base_unchanged':'v447'}))
