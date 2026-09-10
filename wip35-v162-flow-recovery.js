(function(){
  'use strict';

  const CONTRACT='v150-flow-direct-current-read-v2';
  const TARGET_RPC='lts_browser_flow_v10';
  const SESSION_KEY='lts_supabase_session_v1';
  const outer=document.getElementById('shell');
  const gate=document.getElementById('gate');
  let bootGeneration=0;

  function recoveryRuntime(){
    'use strict';

    const CONTRACT='v150-flow-direct-current-read-v2';
    const TARGET_RPC='lts_browser_flow_v10';
    const existing=window.__LTS_V162_FLOW_RECOVERY_STATUS;
    if(existing?.installed===true)return;

    const calls=[];
    const status=window.__LTS_V162_FLOW_RECOVERY_STATUS={
      installed:true,
      contract:CONTRACT,
      baseline:'Protected index V150 Flow component',
      route:null,
      data_rpc:TARGET_RPC,
      legacy_flow_reads_mapped:true,
      public_index_changed:false,
      financial_writer_changed:false,
      dashboard_in_scope:false,
      bounded_boot:true,
      permanent_polling:false,
      refresh_requested:false,
      last_flow_done:false,
      last_flow_ok:false,
      last_flow_error:null,
      calls
    };

    const baseRpc=S.rpc.bind(S);
    async function mappedRpc(name,args){
      const requested=String(name||'');
      const mapped=(requested==='lts_browser_flow_v3'||requested==='lts_browser_flow_v4')?TARGET_RPC:requested;
      calls.push({requested,mapped,at:new Date().toISOString()});
      if(calls.length>40)calls.shift();
      try{
        const result=await baseRpc(mapped,args);
        if(mapped===TARGET_RPC){
          status.last_flow_rpc=mapped;
          status.last_flow_done=true;
          status.last_flow_ok=!result?.error&&!!result?.data?.flow;
          status.last_flow_error=result?.error?.message||(!result?.data?.flow?'Resposta do Fluxo sem dados':null);
          status.last_flow_at=new Date().toISOString();
        }
        return result;
      }catch(error){
        if(mapped===TARGET_RPC){
          status.last_flow_rpc=mapped;
          status.last_flow_done=true;
          status.last_flow_ok=false;
          status.last_flow_error=String(error?.message||error||'Falha de leitura');
          status.last_flow_at=new Date().toISOString();
        }
        throw error;
      }
    }
    mappedRpc.__ltsV162FlowBridge=true;
    S.rpc=mappedRpc;

    function applyScope(){
      document.querySelectorAll('.brand small').forEach(node=>{
        node.textContent='Recuperação do Fluxo Diário';
      });
      document.querySelectorAll('.footer').forEach(node=>{node.hidden=true});
    }

    window.__LTS_V162_ROUTE_FLOW=function(){
      if(!D){
        applyScope();
        return {state:document.querySelector('.login')?'login':'waiting',done:false,ok:false};
      }

      if(status.route!=='Fluxo Diário'||V!=='Fluxo Diário'){
        V='Fluxo Diário';
        renderNav();
        render();
        status.route='Fluxo Diário';
        status.route_applied_at=new Date().toISOString();
      }
      applyScope();

      if(!status.refresh_requested){
        status.refresh_requested=true;
        const from=today();
        const end=new Date(from+'T12:00:00Z');
        end.setUTCDate(end.getUTCDate()+29);
        const to=end.toISOString().slice(0,10);
        status.requested_range={from,to};
        Promise.resolve(loadFlowRange(from,to)).catch(error=>{
          status.last_flow_done=true;
          status.last_flow_ok=false;
          status.last_flow_error=String(error?.message||error||'Falha de leitura');
        });
      }

      return {
        state:'flow',
        done:status.last_flow_done,
        ok:status.last_flow_ok,
        error:status.last_flow_error
      };
    };
  }

  function currentFrame(){
    try{
      const w=outer?.contentWindow,d=outer?.contentDocument;
      if(!w||!d)return null;
      const path=w.location?.pathname||'';
      if(!path.endsWith('/index.html'))return null;
      return {w,d};
    }catch(error){
      return null;
    }
  }

  function showGate(message){
    if(!gate)return;
    gate.textContent=message||'Preparando o Fluxo Diário…';
    gate.hidden=false;
  }

  function hideGate(){
    if(gate)gate.hidden=true;
  }

  function installRuntime(frame){
    if(frame.w.__LTS_V162_FLOW_RECOVERY_STATUS?.installed===true)return true;
    if(frame.d.getElementById('lts-v162-flow-runtime'))return false;
    const script=frame.d.createElement('script');
    script.id='lts-v162-flow-runtime';
    script.textContent=`(${recoveryRuntime.toString()})();`;
    (frame.d.head||frame.d.documentElement).appendChild(script);
    return frame.w.__LTS_V162_FLOW_RECOVERY_STATUS?.installed===true;
  }

  function install(){
    const frame=currentFrame();
    if(!frame)return false;
    if(!frame.d.getElementById('v162-flow-scope-css')){
      const style=frame.d.createElement('style');
      style.id='v162-flow-scope-css';
      style.textContent='.nav [data-v="Dashboard"]{display:none!important}.footer{display:none!important}';
      (frame.d.head||frame.d.documentElement).appendChild(style);
    }
    if(!installRuntime(frame))return false;
    const result=frame.w.__LTS_V162_ROUTE_FLOW?.();
    const status=frame.w.__LTS_V162_FLOW_RECOVERY_STATUS;
    if(result?.state==='login'){
      hideGate();
      return true;
    }
    if(status?.last_flow_done){
      hideGate();
      return true;
    }
    if(result?.state==='flow')showGate('Atualizando o Fluxo Diário…');
    return result?.state==='flow';
  }

  function burst(){
    const generation=++bootGeneration;
    let attempt=0;
    function step(){
      if(generation!==bootGeneration)return;
      install();
      attempt+=1;
      if(attempt<160&&gate&&!gate.hidden)setTimeout(step,100);
    }
    step();
    [250,600,1200,2400,4800,8000,12000,18000].forEach(delay=>{
      setTimeout(()=>{if(generation===bootGeneration)install()},delay);
    });
  }

  outer?.addEventListener('load',()=>{
    showGate('Preparando o Fluxo Diário…');
    burst();
  });
  window.addEventListener('storage',event=>{
    if(event.key===SESSION_KEY){
      showGate('Atualizando o Fluxo Diário…');
      burst();
    }
  });
  document.readyState==='loading'
    ?document.addEventListener('DOMContentLoaded',burst,{once:true})
    :burst();

  window.__LTS_TOP_CANDIDATE_VERSION='v162-flow-recovery';
  window.__LTS_V162_STATUS={
    contract:CONTRACT,
    source_candidate:'index.html',
    flow_baseline:'WIP35-v150 Flow component',
    data_rpc:TARGET_RPC,
    dashboard_in_scope:false,
    public_index_changed:false,
    bounded_boot:true,
    permanent_polling:false
  };
})();
