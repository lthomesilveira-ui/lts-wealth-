"""Preserve bounded polling across same-version cache readiness transitions."""
import argparse,hashlib,json,shutil,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];SOURCE=Path(__file__).resolve().parent;BASE=ROOT/'releases/v446'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def build(target):
    shutil.copytree(BASE,target)
    p=target/'app.html';p.write_text(p.read_text().replace('V446','V447'))
    shutil.copyfile(SOURCE/'controller.js',target/'lts-v415-product-refresh.js')
    (target/'provenance.json').write_text(json.dumps({'release':'v447','base_release':'v446','scope':'Preserve polling and verify a same-version product after temporary cache invalidation','financial_readers_changed':False,'financial_writers_changed':False,'source_guards_changed':False,'authentication_changed':False,'query_deadlines_changed':False,'physical_mobile_validated':False},indent=2)+'\n')
    m={'release':'v447','version':'v447','base_release':'v446','entry':'app.html','protected_manifest':{'path':'releases/v446/manifest.json','sha256':digest(BASE/'manifest.json')},'files':{p.name:digest(p)for p in sorted(target.iterdir())if p.name!='manifest.json'}}
    (target/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--check',action='store_true');a=a.parse_args()
    with tempfile.TemporaryDirectory() as t:
        expected=Path(t)/'v447';build(expected);actual=ROOT/'releases/v447'
        if a.check:assert {p.name:p.read_bytes()for p in actual.iterdir()}=={p.name:p.read_bytes()for p in expected.iterdir()}
        else:
            if actual.exists():shutil.rmtree(actual)
            shutil.copytree(expected,actual)
    print(json.dumps({'pass':True,'release':'v447','deterministic':True,'base_unchanged':'v446'}))
