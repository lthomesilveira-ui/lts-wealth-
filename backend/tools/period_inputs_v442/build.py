"""Immutable V442: preserve V441 finances and accept native period input events."""
import hashlib,json,shutil,tempfile,sys,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];BASE=ROOT/'releases/v441';OUT=ROOT/'releases/v442'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def build(out):
 m=json.loads((BASE/'manifest.json').read_text())
 for n,h in m['files'].items():assert digest(BASE/n)==h,n
 shutil.copytree(BASE,out)
 (out/'app.html').write_text((BASE/'app.html').read_text().replace('V441','V442'))
 source=ROOT/'backend/tools/strategic_budget_v442'
 for name,target in [('budget-ui.js','lts-v441-budget-ui.js'),('budget-model.js','lts-v441-budget-model.js'),('strategy.js','lts-v442-strategy.js'),('income-composition.js','lts-v442-income-composition.js')]:
  shutil.copyfile(source/('review' if name in ('budget-ui.js','budget-model.js','strategy.js') else '')/name,out/target)
 app=(out/'app.html').read_text()
 app=app.replace('<script src="lts-v441-budget-ui.js"></script>','<script src="lts-v442-strategy.js"></script>\n<script src="lts-v441-budget-ui.js"></script>')
 app=app.replace('<script src="lts-v441-flow-summary.js"></script>','<script src="lts-v441-flow-summary.js"></script>\n<script src="lts-v442-income-composition.js"></script>')
 (out/'app.html').write_text(app)
 (out/'provenance.json').write_text(json.dumps({'release':'v442','base_release':'v441','scope':'Strategic category budget in Expenses with native periods, income composition and separately guarded audit','provision_policy_changed':False,'existing_financial_writers_changed':False,'physical_mobile_validated':False},indent=2)+'\n')
 m.update(release='v442',version='v442',base_release='v441',protected_manifest={'path':'releases/v441/manifest.json','sha256':digest(BASE/'manifest.json')})
 m['files']={p.name:digest(p) for p in sorted(out.iterdir()) if p.name!='manifest.json'}
 (out/'manifest.json').write_text(json.dumps(m,indent=2,ensure_ascii=False)+'\n')
 return len(m['files'])
if __name__=='__main__':
 with tempfile.TemporaryDirectory(dir=OUT.parent) as t:
  p=Path(t)/OUT.name;n=build(p)
  if '--check' in sys.argv:
   assert sorted(x.name for x in p.iterdir())==sorted(x.name for x in OUT.iterdir())
   for x in p.iterdir():assert x.read_bytes()==(OUT/x.name).read_bytes(),x.name
  else:
   ref='refs/remotes/origin/main' if '--update-unpublished' in sys.argv else 'HEAD'
   subprocess.run(['git','rev-parse','--verify',ref],cwd=ROOT,capture_output=True,text=True,check=True)
   assert not subprocess.run(['git','ls-tree','-r','--name-only',ref,'--','releases/v442'],cwd=ROOT,capture_output=True,text=True,check=True).stdout,'Never rebuild a published release; an unpublished candidate requires --update-unpublished'
   if OUT.exists():shutil.rmtree(OUT)
   p.rename(OUT)
 print(json.dumps({'pass':True,'release':'v442','assets':n,'v441_preserved':True}))
