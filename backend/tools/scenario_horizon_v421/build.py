"""Build an additive immutable release, or verify its exact reproducibility."""
from pathlib import Path
import hashlib,json,shutil,tempfile
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;SRC=ROOT/'releases/v417';TARGET=ROOT/'releases/v421'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def once(s,old,new):
 assert s.count(old)==1,(old[:100],s.count(old));return s.replace(old,new)
manifest=json.loads((SRC/'manifest.json').read_text())
for n,h in manifest['files'].items():assert digest(SRC/n)==h,('immutable source changed',n)
work=tempfile.TemporaryDirectory() if TARGET.exists() else None
DST=Path(work.name)/'v421' if work else TARGET
shutil.copytree(SRC,DST)
p=DST/'lts-v384-startup-1.js';s=p.read_text()
s=once(s,"const end=(Number(today().slice(0,4))+(window.__LTS_V412_PROJECTION?.model?5:4))+'-12-31',from=today().slice(0,4)","const end=window.parent.LTSV421Scenario.horizon(today(),window.__LTS_V412_PROJECTION?.model),from=today().slice(0,4)")
s=once(s,"const now=today(),horizon=(Number(now.slice(0,4))+(window.__LTS_V412_PROJECTION?.model?5:4))+'-12-31';","const now=today(),horizon=window.parent.LTSV421Scenario.horizon(now,window.__LTS_V412_PROJECTION?.model);")
a=s.index('    function dailyScenario(flow,key){');b=s.index('    function deficitDetail',a)
s=s[:a]+"    function dailyScenario(flow,key){return window.parent.LTSV421Scenario.scenario(flow,key,today(),window.parent.LTSV421Scenario.horizon(today(),window.__LTS_V412_PROJECTION?.model));}\n"+s[b:]
s=once(s,'<dt>Pior saldo projetado</dt>','<dt>Menor saldo no horizonte</dt>')
s=once(s,":'<span>Sem saldo negativo no período</span>';",":'<span>Sem saldo negativo até '+date(scenario.horizon)+'</span>';")
s=once(s,"planningReady=planningUI.version==='planning-ui-contract-v2',baseScenario=","planningReady=days.length>0,baseScenario=")
s=once(s,"const baseNegDate=planningReady?planningUI.d01_first_need:null,vestedNegDate=planningReady?planningUI.rsu_first_need:null,fgtsNegDate=planningReady?planningUI.fgts_first_negative:null;","const baseNegDate=baseScenario.complete?baseScenario.firstNegative?.date:null,vestedNegDate=vestedScenario.complete?vestedScenario.firstNegative?.date:null,fgtsNegDate=fgtsScenario.complete?fgtsScenario.firstNegative?.date:null;")
s=once(s,"const label=dt=>!planningReady?'Carregando…':dt?'Cobertura até '+date(addDays(dt,-1)):'Cobertura até '+date(lastHorizon);const baseLabel=label(baseNegDate),vestedLabel=label(vestedNegDate),fgtsLabel=label(fgtsNegDate);","const label=(dt,scenario)=>!planningReady?'Carregando…':!scenario.complete?'Projeção a conferir':dt?'Cobertura até '+date(addDays(dt,-1)):'Cobertura até '+date(scenario.horizon);const baseLabel=label(baseNegDate,baseScenario),vestedLabel=label(vestedNegDate,vestedScenario),fgtsLabel=label(fgtsNegDate,fgtsScenario);")
s=once(s,"p_to:(year+(window.__LTS_V412_PROJECTION?.model?5:1))+'-12-31'","p_to:window.parent.LTSV421Scenario.horizon(now,window.__LTS_V412_PROJECTION?.model)")
p.write_text(s)
shutil.copyfile(HERE/'model.js',DST/'lts-v421-scenario-model.js')
p=DST/'app.html';s=p.read_text().replace('V417','V421').replace('v417-report-presentation','v421-full-scenario-horizon')
s=once(s,'<script src="lts-v384-startup-1.js"></script>','<script src="lts-v421-scenario-model.js"></script>\n<script src="lts-v384-startup-1.js"></script>');p.write_text(s)
(DST/'provenance.json').write_text(json.dumps({'release':'v421','base_release':'v417','scope':'full configured scenario horizon','financial_balances_recalculated':False,'server_or_source_writes_added':False,'physical_iphone_verified':False,'private_session_verified':False},indent=2)+'\n')
manifest.update(release='v421',version='v421',base_release='v417',protected_manifest={'path':'releases/v417/manifest.json','sha256':digest(SRC/'manifest.json')})
manifest['files']={n:digest(DST/n) for n in sorted(set(manifest['files'])|{'lts-v421-scenario-model.js'})}
(DST/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n')
if work:
 assert {p.name:digest(p) for p in DST.iterdir()}=={p.name:digest(p) for p in TARGET.iterdir()},'candidate differs';work.cleanup()
print(json.dumps({'release':'v421','protected_v417':True,'assets':len(manifest['files'])}))
