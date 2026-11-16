"""Preserve V449 and bound eligible queue wait separately from collection holds."""
import argparse,hashlib,json,shutil,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'releases/v449'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def replace_once(path,old,new):
 s=path.read_text();assert s.count(old)==1,(path.name,old[:80]);path.write_text(s.replace(old,new))
def build(target):
 shutil.copytree(BASE,target)
 p=target/'app.html';p.write_text(p.read_text().replace('V449','V450'))
 p=target/'lts-v227-read-transport.js';old_transport=p.read_text()
 replace_once(p,"/^lts_browser_(?:flow_v|month_overview_v393$)/.test(name)?48000:25000;","/^lts_browser_(?:flow_v|month_overview_v393$|dashboard_cockpit_v1$)/.test(name)?48000:25000;")
 replace_once(p,'const waiting=[],holds=new Set();let active=false,pumpTimer=null,order=0;', '''const waiting=[],holds=new Set();let active=false,pumpTimer=null,order=0;
  // An intentional collection hold has its own existing 90s ceiling. Preserve
  // each reader's 60s eligible-admission budget while that hold blocks all reads.
  function pauseAdmission(item){if(item.timer!=null){clearTimeout(item.timer);item.timer=null;item.remaining=Math.max(0,item.remaining-(performance.now()-item.armedAt));}}
  function armAdmission(item){if(item.timer!=null||holds.size)return;item.armedAt=performance.now();item.timer=setTimeout(item.cancel,item.remaining);}''')
 replace_once(p,'holds.delete(hold);resolveReady(false);pump();','holds.delete(hold);resolveReady(false);if(!holds.size)for(const item of waiting)armAdmission(item);pump();')
 replace_once(p,'holds.add(hold);hold.notify();timer=setTimeout(hold.release,90000);','if(!holds.size)for(const item of waiting)pauseAdmission(item);holds.add(hold);hold.notify();timer=setTimeout(hold.release,90000);')
 replace_once(p,'const item={resolve,name,order:order++,signal,cancel:', 'const item={resolve,name,order:order++,signal,remaining:60000,armedAt:0,timer:null,cancel:')
 replace_once(p,"signal.addEventListener('abort',item.cancel,{once:true});item.timer=setTimeout(item.cancel,60000);waiting.push(item);", "signal.addEventListener('abort',item.cancel,{once:true});waiting.push(item);armAdmission(item);")
 # Correct the comment together with the one explicit cockpit ceiling above.
 replace_once(p,'// Cash and connection status remain independent; no timeout is enlarged.','// Cash and connection status remain independent; writers are never admitted here.')
 replace_once(p,'// The complete flow reader has a 45-second database ceiling. Do not cancel\n  // valid cold/year reads at the generic 25-second transport deadline.','// Flow, month overview and cockpit have a 45-second database ceiling.\n  // Their complete response bodies receive the matching 48-second budget.')
 replace_once(target/'lts-v384-startup-1.js',old_transport,p.read_text())
 (target/'provenance.json').write_text(json.dumps({'release':'v450','base_release':'v449',
  'scope':'Preserve eligible queue wait during bounded collection holds; match the cockpit database deadline',
  'v448_chart_css_unchanged':True,'financial_readers_changed':False,'financial_writers_changed':False,
  'source_guards_changed':False,'authentication_changed':False,'one_heavy_read_preserved':True,
  'cockpit_transport_budget_ms':48000,'database_ceiling_unchanged':True,
  'eligible_admission_budget_ms':60000,'collection_hold_ceiling_ms':90000,'physical_mobile_validated':False},indent=2)+'\n')
 (target/'manifest.json').write_text(json.dumps({'release':'v450','version':'v450','base_release':'v449','entry':'app.html',
  'protected_manifest':{'path':'releases/v449/manifest.json','sha256':digest(BASE/'manifest.json')},
  'files':{p.name:digest(p) for p in sorted(target.iterdir()) if p.name!='manifest.json'}},indent=2)+'\n')
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
 with tempfile.TemporaryDirectory() as d:
  expected=Path(d)/'v450';build(expected);actual=ROOT/'releases/v450'
  if args.check:assert {p.name:p.read_bytes() for p in actual.iterdir()}=={p.name:p.read_bytes() for p in expected.iterdir()}
  else:
   assert not actual.exists(),'Never overwrite a published release';shutil.copytree(expected,actual)
 print(json.dumps({'pass':True,'release':'v450','protected_base':'v449'}))
