"""New immutable candidate: recover dependent readers after existing-job completion."""
import argparse, hashlib, json, shutil, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'releases/v450'
HERE=Path(__file__).resolve().parent
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def replace_once(path,old,new):
    text=path.read_text(); assert text.count(old)==1,(path.name,old[:80])
    path.write_text(text.replace(old,new))
def build(target):
    shutil.copytree(BASE,target)
    app=target/'app.html';assert app.read_text().count('V450')==5
    app.write_text(app.read_text().replace('V450','V451'))
    scripts={}
    def change(name,old,new):
        scripts.setdefault(name,(BASE/name).read_text())
        replace_once(target/name,old,new)
    name='lts-v227-read-transport.js'
    scripts[name]=(BASE/name).read_text()
    (target/name).write_text((HERE/'read-transport.js').read_text())
    change('lts-v181-regression-closure.js',"window.addEventListener('lts:card-classified',refreshReviewAfterCardClassification);", """window.addEventListener('lts:card-classified',refreshReviewAfterCardClassification);
  window.addEventListener('lts:product-refresh-ready',()=>{
   if(D&&!N.classList.contains('hidden'))refreshReviewAfterCardClassification();
  });""")
    name='lts-v225-open-finance.js'
    scripts[name]=(BASE/name).read_text()
    text=(target/name).read_text()
    assert text.count('if(p.key===key)')==3
    (target/name).write_text(text.replace('if(p.key===key)','if(state.pending===p&&p.key===key)'))
    change(name,"state.refresh=()=>refresh(true);", """// Refresh only this read after the complete product is installed. Collection,
    // connection polling and any in-progress financial action stay independent.
    window.addEventListener('lts:product-refresh-ready',()=>{
      if(!signedIn())return;
      state.pending={key:'',data:null,loading:false,error:''};paintPending();
    });
    state.refresh=()=>refresh(true);""")
    # Production boots bundled scripts. Assert exactly one replacement per owner.
    for name,original in scripts.items():
        bundles=[target/n for n in ['lts-v384-startup-1.js','lts-v384-startup-2.js'] if original in (target/n).read_text()]
        assert len(bundles)==1,name
        replace_once(bundles[0],original,(target/name).read_text())
    (target/'provenance.json').write_text(json.dumps({
        'release':'v451','base_release':'v450',
        'scope':'Recover cancelled or transiently unavailable dependent readers after the existing refresh job completes',
        'financial_math_changed':False,'financial_writers_changed':False,
        'source_guards_changed':False,'authentication_changed':False,
        'single_heavy_read_preserved':True,'existing_job_only':True,
        'automatic_recovery_limit_per_request_version':2,
        'physical_mobile_validated':False},indent=2)+'\n')
    (target/'manifest.json').write_text(json.dumps({'release':'v451','version':'v451',
        'base_release':'v450','entry':'app.html',
        'protected_manifest':{'path':'releases/v450/manifest.json','sha256':digest(BASE/'manifest.json')},
        'files':{p.name:digest(p) for p in sorted(target.iterdir()) if p.name!='manifest.json'}},indent=2)+'\n')
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    with tempfile.TemporaryDirectory() as d:
        expected=Path(d)/'v451';build(expected);actual=ROOT/'releases/v451'
        if args.check: assert {p.name:p.read_bytes() for p in actual.iterdir()}=={p.name:p.read_bytes() for p in expected.iterdir()}
        else:
            assert not actual.exists(),'Never overwrite a published release';shutil.copytree(expected,actual)
    print(json.dumps({'pass':True,'release':'v451','protected_base':'v450'}))
