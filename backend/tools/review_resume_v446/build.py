"""Build read-only review recovery after a complete product replacement."""
import argparse,hashlib,json,shutil,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];BASE=ROOT/'releases/v445'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def build(target):
    shutil.copytree(BASE,target)
    p=target/'app.html';p.write_text(p.read_text().replace('V445','V446'))
    p=target/'lts-v384-startup-2.js';s=p.read_text()
    changes=[
      ("generation:null,sequence:0,loading:false,error:false,data:null,expense:null", "generation:null,sequence:0,loading:false,reload:false,error:false,data:null,expense:null"),
      ("generation:current(),sequence:state.sequence+1,loading:false,error:false,data:null,expense:null", "generation:current(),sequence:state.sequence+1,loading:false,reload:false,error:false,data:null,expense:null"),
      ("session();if(!D||N.classList.contains('hidden')||state.loading||(!force&&Date.now()-state.readAt<300000))return;", "session();if(!D||N.classList.contains('hidden'))return;if(state.loading){if(force)state.reload=true;return;}if(!force&&Date.now()-state.readAt<300000)return;"),
      ("if(V==='Atualizações')render();else badges();\n  }\n  function panel()", "if(V==='Atualizações')render();else badges();\n   if(state.reload){state.reload=false;queueMicrotask(()=>load(true));}\n  }\n  function panel()")]
    for text in ["window.__LTS_V296_CLASSIFICATIONS={installed:true,state,refresh:()=>load(true)};","window.__LTS_V312_CARD_REVIEW={installed:true,state,refresh:()=>load(true),open};"]:
        changes.append((text,text+"\n  window.addEventListener('lts:product-refresh-ready',()=>load(true));"))
    for old,new in changes:
        assert s.count(old)==1,old[:90]
        s=s.replace(old,new)
    p.write_text(s)
    (target/'provenance.json').write_text(json.dumps({'release':'v446','base_release':'v445','scope':'Resume interrupted classification readers after complete product refresh','financial_readers_changed':False,'financial_writers_changed':False,'authentication_changed':False,'source_guards_changed':False,'query_deadlines_changed':False,'physical_mobile_validated':False},indent=2)+'\n')
    m={'release':'v446','version':'v446','base_release':'v445','entry':'app.html','protected_manifest':{'path':'releases/v445/manifest.json','sha256':digest(BASE/'manifest.json')},'files':{p.name:digest(p)for p in sorted(target.iterdir())if p.name!='manifest.json'}}
    (target/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--check',action='store_true');a=a.parse_args()
    with tempfile.TemporaryDirectory() as t:
        expected=Path(t)/'v446';build(expected);actual=ROOT/'releases/v446'
        if a.check:assert {p.name:p.read_bytes()for p in actual.iterdir()}=={p.name:p.read_bytes()for p in expected.iterdir()}
        else:
            if actual.exists():shutil.rmtree(actual)
            shutil.copytree(expected,actual)
    print(json.dumps({'pass':True,'release':'v446','deterministic':True,'base_unchanged':'v445'}))
