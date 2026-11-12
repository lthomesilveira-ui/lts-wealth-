"""Immutable V441: retain V440 provisions, queue-aware refresh and category budget."""
import hashlib,json,shutil,tempfile,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'releases/v440'
OUT=ROOT/'releases/v441'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def replace(s,old,new):
 assert s.count(old)==1,old[:100]
 return s.replace(old,new)
def build(out):
 m=json.loads((BASE/'manifest.json').read_text())
 for name,h in m['files'].items():assert digest(BASE/name)==h,name
 shutil.copytree(BASE,out)
 s=(BASE/'index.html').read_text()
 s=replace(s,'signal:options.signal});return {data,error:null}',
  'signal:options.signal,ltsOnReadStart:options.onReadStart});return {data,error:null}')
 s=replace(s,'rpc:(name,args,signal)=>PRODUCT_REFRESH_RPC_V415(name,args,{signal}),',
  'rpc:(name,args,signal,onReadStart)=>PRODUCT_REFRESH_RPC_V415(name,args,{signal,onReadStart}),\n deferProductDeadline:true,')
 (out/'index.html').write_text(s)
 s=(BASE/'lts-v415-product-refresh.js').read_text()
 old="""      let deadline;
      const cancelled"""
 new="""      let deadline, started = false;
      // Admission already has a bounded 60s wait. Its wait is not SQL time.
      // The product still gets exactly 25s after the transport admits it.
      const deferredProduct = name === PRODUCT_RPC && options.deferProductDeadline === true;
      const onReadStart = () => {
        if (started || controller.signal.aborted) return;
        started = true; cancelLater(deadline);
        deadline = later(() => controller.abort(), name === PRODUCT_RPC ? 25000 : 10000);
      };
      const cancelled"""
 s=replace(s,old,new)
 s=replace(s,'deadline = later(() => controller.abort(), name === PRODUCT_RPC ? 25000 : 10000);\n      });',
  'deadline = later(() => controller.abort(), deferredProduct ? 60000 : name === PRODUCT_RPC ? 25000 : 10000);\n      });')
 s=replace(s,'rpc(name, {}, controller.signal)), cancelled]',
  'rpc(name, {}, controller.signal, deferredProduct ? onReadStart : undefined)), cancelled]')
 (out/'lts-v415-product-refresh.js').write_text(s)
 s=(BASE/'lts-v384-read-priority.js').read_text()
 s=replace(s," function forRoute(name,route){"," function forRoute(name,route){\n  if(name==='lts_browser_product_v1')return -3;")
 (out/'lts-v384-read-priority.js').write_text(s)
 # Budget preferences invalidate their own reader, never the financial product.
 for name in ['lts-v227-read-transport.js','lts-v384-startup-1.js']:
  p=BASE/name
  if not p.exists():continue
  s=p.read_text()
  if ' function forRoute(name,route){' in s:
   s=replace(s," function forRoute(name,route){"," function forRoute(name,route){\n  if(name==='lts_browser_product_v1')return -3;")
  s=replace(s,'|month_overview_|card_cycles_', '|month_overview_|budget_read_|card_cycles_') if s.count('|month_overview_|card_cycles_')==1 else s
  # Both admission and read detection must include the new canonical reader.
  s=s.replace('|month_overview_|card_cycles_', '|month_overview_|budget_read_|card_cycles_')
  s=s.replace('const mutation=/_decision_',"const mutation=name!=='lts_browser_budget_save_v441'&&/_decision_")
  s=replace(s,"const cacheable=name!=='lts_browser_product_refresh_status_v415'", "const cacheable=name!=='lts_browser_budget_read_v441'&&name!=='lts_browser_product_refresh_status_v415'")
  (out/name).write_text(s)
 s=(BASE/'app.html').read_text().replace('V440','V441')
 assert 'lts-v384-startup-1.js' in s
 # Components install only after the existing full application boot.
 tail='\n<script src="lts-v441-budget-model.js"></script>\n<script src="lts-v441-budget-ui.js"></script>\n<script src="lts-v441-flow-summary.js"></script>\n'
 assert '</body>' in s
 s=s.replace('</body>',tail+'</body>')
 (out/'app.html').write_text(s)
 for name in ['lts-v441-budget-model.js','lts-v441-budget-ui.js','lts-v441-flow-summary.js']:
  shutil.copyfile(Path(__file__).parent/name,out/name)
 (out/'provenance.json').write_text(json.dumps({'release':'v441','base_release':'v440',
  'scope':'Queue-aware product readiness, canonical category budgets and liquidity scenarios',
  'provision_policy_changed':False,'existing_financial_writers_changed':False,
  'planning_targets_writer_added':True,'physical_mobile_validated':False},indent=2)+'\n')
 m.update(release='v441',version='v441',base_release='v440',protected_manifest={'path':'releases/v440/manifest.json','sha256':digest(BASE/'manifest.json')})
 m['files']={p.name:digest(p) for p in sorted(out.iterdir()) if p.name!='manifest.json'}
 (out/'manifest.json').write_text(json.dumps(m,indent=2,ensure_ascii=False)+'\n')
 return len(m['files'])
if __name__=='__main__':
 with tempfile.TemporaryDirectory(dir=OUT.parent) as temp:
  p=Path(temp)/OUT.name;n=build(p)
  if '--check' in sys.argv:
   assert sorted(x.name for x in p.iterdir())==sorted(x.name for x in OUT.iterdir())
   for x in p.iterdir():assert x.read_bytes()==(OUT/x.name).read_bytes(),x.name
  elif OUT.exists():
   # This path is an unpublished local build only. Published releases are never edited.
   if (ROOT/'.git').exists():
    import subprocess
    committed=subprocess.run(['git','ls-files',str(OUT.relative_to(ROOT))],cwd=ROOT,capture_output=True,text=True,check=True).stdout
    assert not committed,'Do not rebuild a committed release'
   shutil.rmtree(OUT)
  if '--check' not in sys.argv:p.rename(OUT)
 print(json.dumps({'pass':True,'release':'v441','assets':n,'base_preserved':True}))
