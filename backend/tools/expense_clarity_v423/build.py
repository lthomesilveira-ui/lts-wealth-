from pathlib import Path
import hashlib,json,shutil,tempfile
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;SRC=ROOT/'releases/v421';TARGET=ROOT/'releases/v423'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def once(s,a,b):
 assert s.count(a)==1,(a[:80],s.count(a));return s.replace(a,b)
m=json.loads((SRC/'manifest.json').read_text())
for n,h in m['files'].items():assert sha(SRC/n)==h,n
work=tempfile.TemporaryDirectory() if TARGET.exists() else None
DST=Path(work.name)/'v423' if work else TARGET
shutil.copytree(SRC,DST)
shutil.copyfile(HERE/'model.js',DST/'lts-v423-clarity-model.js');shutil.copyfile(HERE/'runtime.js',DST/'lts-v423-clarity.js')
p=DST/'lts-v384-startup-1.js';s=p.read_text()
s=once(s,"  function drawRows(){\n   const d=state.detail,host=document.getElementById('v178Drawer');",(HERE/'subgroups.txt').read_text()+"\n  function drawRows(){\n   const d=state.detail,host=document.getElementById('v178Drawer');")
s=once(s,"const q=normalize(d.query),matched=d.rows.filter(r=>!q||normalize([r.description,r.account_source,r.beneficiary,r.component,r.category,r.current_category,r.property_code,r.property_code==='cipo396'?'CIPÓ 396':'',r.center_cost].join(' ')).includes(q)),rows=", "const q=normalize(d.query),matched=d.rows.filter(r=>(!d.v423Subgroup||window.parent.LTSV423Clarity.identity(r).key===d.v423Subgroup)&&(!q||normalize([r.description,r.account_source,r.beneficiary,r.component,r.category,r.current_category,r.subgroup,r.property_code,r.property_code==='cipo396'?'CIPÓ 396':'',r.center_cost].join(' ')).includes(q))),rows=")
s=once(s,"finally{if(token===sequence){d.loading=false;drawRows()}}\n  }\n  function compositionOrigin", "finally{if(token===sequence){d.loading=false;drawRows();drawKnownSubgroups()}}\n  }\n  function compositionOrigin")
# Display alias only; never replace the key sent in scope/RPC arguments.
s=once(s,"Number(value)+'\">'+escape(name)+'</button>';","Number(value)+'\">'+escape(window.parent.LTSV423Clarity.label(name))+'</button>';" )
s=once(s,"<summary><span>'+escape(n.name)+'</span><b>'+moneyButton", "<summary><span>'+escape(window.parent.LTSV423Clarity.label(n.name))+'</span><b>'+moneyButton")
s=once(s,"escape(window.LTSCategoryDisplay.category(d.subgroup||d.group||'Lançamentos'))", "escape(window.parent.LTSV423Clarity.label(window.LTSCategoryDisplay.category(d.subgroup||d.group||'Lançamentos')))")
p.write_text(s)
p=DST/'app.html';s=p.read_text().replace('V421','V423').replace('v421-full-scenario-horizon','v423-expense-clarity')
s=once(s,'<script src="lts-v421-scenario-model.js"></script>','<script src="lts-v423-clarity-model.js"></script>\n<script src="lts-v421-scenario-model.js"></script>')
s=once(s,'</body>','<script src="lts-v423-clarity.js"></script>\n</body>');p.write_text(s)
(DST/'provenance.json').write_text(json.dumps({'release':'v423','base_release':'v421','scope':'expense subgroup and pending cash evidence presentation','financial_writes_added':False,'real_device_verified':False,'private_session_verified':False},indent=2)+'\n')
m.update(release='v423',version='v423',base_release='v421',protected_manifest={'path':'releases/v421/manifest.json','sha256':sha(SRC/'manifest.json')})
m['files']={n:sha(DST/n) for n in sorted(set(m['files'])|{'lts-v423-clarity.js','lts-v423-clarity-model.js'})};(DST/'manifest.json').write_text(json.dumps(m,indent=2,ensure_ascii=False)+'\n')
if work:
 assert {p.name:sha(p) for p in DST.iterdir()}=={p.name:sha(p) for p in TARGET.iterdir()};work.cleanup()
print(json.dumps({'passed':True,'release':'v423','assets':len(m['files'])}))
