"""Build a CSS-only expense chart candidate without modifying frozen releases."""
import argparse,hashlib,json,shutil,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];SOURCE=Path(__file__).resolve().parent;BASE=ROOT/'releases/v447'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def build(target):
    shutil.copytree(BASE,target)
    p=target/'app.html';p.write_text(p.read_text().replace('V447','V448'))
    p=target/'lts-v168-feedback-package.css';p.write_bytes(p.read_bytes()+b'\n'+(SOURCE/'chart.css').read_bytes())
    (target/'provenance.json').write_text(json.dumps({'release':'v448','base_release':'v447','scope':'Prevent overlapping monthly expense chart labels with content-sized horizontal scrolling','financial_readers_changed':False,'financial_writers_changed':False,'source_guards_changed':False,'authentication_changed':False,'physical_mobile_validated':False},indent=2)+'\n')
    m={'release':'v448','version':'v448','base_release':'v447','entry':'app.html','protected_manifest':{'path':'releases/v447/manifest.json','sha256':digest(BASE/'manifest.json')},'files':{p.name:digest(p)for p in sorted(target.iterdir())if p.name!='manifest.json'}}
    (target/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--check',action='store_true');a=a.parse_args()
    with tempfile.TemporaryDirectory() as t:
        expected=Path(t)/'v448';build(expected);actual=ROOT/'releases/v448'
        if a.check:assert {p.name:p.read_bytes()for p in actual.iterdir()}=={p.name:p.read_bytes()for p in expected.iterdir()}
        else:
            assert not actual.exists(),'Refuse to replace an existing release; use --check'
            shutil.copytree(expected,actual)
    print(json.dumps({'pass':True,'release':'v448','deterministic':True,'base_unchanged':'v447'}))
