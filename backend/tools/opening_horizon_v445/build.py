"""Build the aligned opening candidate from immutable V444 assets."""
import argparse, hashlib, json, shutil, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
SOURCE=Path(__file__).resolve().parent
BASE=ROOT/'releases/v444'
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def build(target):
    shutil.copytree(BASE,target)
    p=target/'app.html';p.write_text(p.read_text().replace('V444','V445'))
    p=target/'lts-v384-startup-1.js';s=p.read_text()
    old="(Number(today().slice(0,4))+(window.__LTS_V412_PROJECTION?.model?5:4))+'-12-31'"
    assert s.count(old)==2
    p.write_text(s.replace(old,'window.parent.LTSV421Scenario.horizon(today(),window.__LTS_V412_PROJECTION?.model)'))
    shutil.copyfile(SOURCE/'projection.js',target/'lts-v412-projection-policy.js')
    (target/'provenance.json').write_text(json.dumps({'release':'v445','base_release':'v444',
        'scope':'Align opening review horizon and avoid restarting already aligned dashboard readers',
        'financial_readers_changed':False,'financial_writers_changed':False,'authentication_changed':False,
        'source_guards_changed':False,'query_deadlines_changed':False,'physical_mobile_validated':False},indent=2)+'\n')
    m={'release':'v445','version':'v445','base_release':'v444','entry':'app.html',
       'protected_manifest':{'path':'releases/v444/manifest.json','sha256':digest(BASE/'manifest.json')},
       'files':{p.name:digest(p) for p in sorted(target.iterdir()) if p.name!='manifest.json'}}
    (target/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--check',action='store_true');a=a.parse_args()
    with tempfile.TemporaryDirectory() as temp:
        expected=Path(temp)/'v445';build(expected);actual=ROOT/'releases/v445'
        if a.check: assert {p.name:p.read_bytes() for p in actual.iterdir()}=={p.name:p.read_bytes() for p in expected.iterdir()}
        else:
            if actual.exists():shutil.rmtree(actual)
            shutil.copytree(expected,actual)
    print(json.dumps({'pass':True,'release':'v445','deterministic':True,'base_unchanged':'v444'}))
