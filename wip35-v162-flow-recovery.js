(function(){
  'use strict';

  const CONTRACT='v152-visual-v150-flow-current-read-v1';
  const TARGET_RPC='lts_browser_flow_v10';
  const SESSION_KEY='lts_supabase_session_v1';
  const outer=document.getElementById('shell');
  const gate=document.getElementById('gate');
  let bootGeneration=0;
  let routeApplied=false;
  let refreshRequested=false;

  function addDays(iso,days){
    const d=new Date(iso+'T12:00:00Z');
    d.setUTCDate(d.getUTCDate()+days);
    return d.toISOString().slice(0,10);
  }

  function today(){
    return new Intl.DateTimeFormat('en-CA',{
      timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'
    }).format(new Date());
  }

  function candidate(){
    try{return {w:outer.contentWindow,d:outer.contentDocument}}catch(e){return null}
  }

  function showGate(message){
    if(!gate)return;
    gate.textContent=message||'Preparando o Fluxo Diário…';
    gate.hidden=false;
  }

  function hideGate(){if(gate)gate.hidden=true}

  function deepest(){
    try{
      let frame=outer,last=null;
      for(let i=0;i<24&&frame;i++){
        const w=frame.contentWindow,d=frame.contentDocument;
        if(!w||!d)break;
        last={w,d,frame};
        frame=d.getElementById('shell')||d.querySelector('iframe#app')||d.querySelector('iframe');
      }
      return last;
    }catch(e){return null}
  }

  function scopeCandidate(){
    const c=candidate();
    if(!c?.d)return;
    if(!c.d.getElementById('v162-flow-scope-css')){
      const style=c.d.createElement('style');
      style.id='v162-flow-scope-css';
      style.textContent='#v152MobileNav [data-dest="Dashboard"]{display:none!important}#v152Badge{display:none!important}';
      (c.d.head||c.d.documentElement).appendChild(style);
    }
  }

  function scopeDeep(z){
    if(!z?.d||z.d.getElementById('v162-flow-deep-css'))return;
    const style=z.d.createElement('style');
    style.id='v162-flow-deep-css';
    style.textContent='.nav [data-v143-dest="Dashboard"],.nav [data-v="Dashboard"]{display:none!important}';
    (z.d.head||z.d.documentElement).appendChild(style);
  }

  function installReadBridge(z){
    if(!z?.w?.S||typeof z.w.S.rpc!=='function')return false;
    const existing=z.w.__LTS_V162_FLOW_RECOVERY_STATUS;
    if(existing?.installed===true&&z.w.S.rpc?.__ltsV162FlowBridge===true)return true;

    const base=z.w.S.rpc.bind(z.w.S);
    const calls=[];
    async function mappedRpc(name,args){
      const requested=String(name||'');
      const mapped=(requested==='lts_browser_flow_v3'||requested==='lts_browser_flow_v4')?TARGET_RPC:requested;
      calls.push({requested,mapped,at:new Date().toISOString()});
      if(calls.length>40)calls.shift();
      try{
        const result=await base(mapped,args);
        if(mapped===TARGET_RPC){
          const status=z.w.__LTS_V162_FLOW_RECOVERY_STATUS;
          if(status){
            status.last_flow_rpc=mapped;
            status.last_flow_done=true;
            status.last_flow_ok=!result?.error&&!!result?.data?.flow;
            status.last_flow_error=result?.error?.message||null;
            status.last_flow_at=new Date().toISOString();
          }
        }
        return result;
      }catch(error){
        if(mapped===TARGET_RPC){
          const status=z.w.__LTS_V162_FLOW_RECOVERY_STATUS;
          if(status){
            status.last_flow_rpc=mapped;
            status.last_flow_done=true;
            status.last_flow_ok=false;
            status.last_flow_error=String(error?.message||error||'Falha de leitura');
            status.last_flow_at=new Date().toISOString();
          }
        }
        throw error;
      }
    }
    mappedRpc.__ltsV162FlowBridge=true;
    mappedRpc.__ltsV162FlowBase=base;
    z.w.S.rpc=mappedRpc;
    z.w.__LTS_V162_FLOW_RECOVERY_STATUS={
      installed:true,
      contract:CONTRACT,
      baseline:'WIP35-v152 with WIP35-v150 Flow',
      data_rpc:TARGET_RPC,
      legacy_flow_reads_mapped:true,
      public_index_changed:false,
      financial_writer_changed:false,
      dashboard_in_scope:false,
      bounded_boot:true,
      permanent_polling:false,
      calls
    };
    return true;
  }

  function routeAndRefresh(z){
    if(!z?.w?.D||typeof z.w.render!=='function'){
      if(z?.d?.querySelector('.login'))hideGate();
      return false;
    }
    if(!z.w.LTS_V152_MOBILE_REFERENCE)return false;

    if(!routeApplied){
      routeApplied=true;
      z.w.V='Fluxo Diário';
      try{z.w.renderNav?.()}catch(e){}
      try{z.w.render()}catch(e){return false}
    }

    const status=z.w.__LTS_V162_FLOW_RECOVERY_STATUS;
    if(!refreshRequested&&status&&!status.last_flow_ok&&typeof z.w.loadFlowRange==='function'){
      showGate('Atualizando o Fluxo Diário…');
      refreshRequested=true;
      const from=today(),to=addDays(from,29);
      Promise.resolve(z.w.loadFlowRange(from,to)).catch(()=>{refreshRequested=false});
    }
    if(status?.last_flow_done&&String(z.w.V)==='Fluxo Diário')hideGate();
    return true;
  }

  function install(){
    scopeCandidate();
    const z=deepest();
    if(!z?.w||!z.d)return false;
    scopeDeep(z);
    if(!installReadBridge(z))return false;
    routeAndRefresh(z);
    return true;
  }

  function burst(){
    const generation=++bootGeneration;
    let tries=0;
    function step(){
      if(generation!==bootGeneration)return;
      install();
      tries++;
      if(tries<160&&!routeApplied)setTimeout(step,100);
    }
    step();
    [250,600,1200,2400,4800,8000,12000,18000].forEach(ms=>setTimeout(()=>{
      if(generation===bootGeneration)install();
    },ms));
  }

  outer?.addEventListener('load',()=>{
    showGate('Preparando o Fluxo Diário…');
    routeApplied=false;
    refreshRequested=false;
    burst();
  });
  window.addEventListener('storage',event=>{
    if(event.key===SESSION_KEY&&event.newValue){
      showGate('Atualizando o Fluxo Diário…');
      routeApplied=false;
      refreshRequested=false;
      burst();
    }
  });
  document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();
  window.__LTS_TOP_CANDIDATE_VERSION='v162-flow-recovery';
  window.__LTS_V162_STATUS={
    contract:CONTRACT,
    source_candidate:'wip35-v152-candidate.html',
    flow_baseline:'WIP35-v150',
    data_rpc:TARGET_RPC,
    dashboard_in_scope:false,
    public_index_changed:false,
    bounded_boot:true,
    permanent_polling:false
  };
})();
