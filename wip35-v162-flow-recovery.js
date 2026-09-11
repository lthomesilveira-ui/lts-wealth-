(function(){
  'use strict';

  const CONTRACT='v150-flow-direct-current-read-v3';
  const TARGET_RPC='lts_browser_flow_v11';
  const TARGET_MUTATION_RPC='lts_browser_flow_mutate_v2';
  const SESSION_KEY='lts_supabase_session_v1';
  const outer=document.getElementById('shell');
  const gate=document.getElementById('gate');
  let bootGeneration=0;

  function recoveryRuntime(){
    'use strict';

    const CONTRACT='v150-flow-direct-current-read-v3';
    const TARGET_RPC='lts_browser_flow_v11';
    const TARGET_MUTATION_RPC='lts_browser_flow_mutate_v2';
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
      mutation_rpc:TARGET_MUTATION_RPC,
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
      const mapped=(requested==='lts_browser_flow_v3'||requested==='lts_browser_flow_v4')
        ? TARGET_RPC
        : requested==='lts_browser_flow_mutate_v1'
          ? TARGET_MUTATION_RPC
          : requested;
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

    // One owned loader prevents an older response from replacing a newer period.
    const DEFAULT_RANGE_CONTRACT='previous-5-today-next-30-v1';
    const DEFAULT_RANGE_LABEL='5 anteriores + 30 próximos';
    let flowRequestSequence=0;
    let lastRenderedRoute=V;
    status.default_range_contract=DEFAULT_RANGE_CONTRACT;
    status.default_range_applied=false;

    function defaultRange(){
      const day=today();
      const shift=offset=>{
        const date=new Date(day+'T12:00:00Z');
        date.setUTCDate(date.getUTCDate()+offset);
        return date.toISOString().slice(0,10);
      };
      return {from:shift(-5),to:shift(30)};
    }

    function useDefaultState(){
      const range=defaultRange();
      FLOWPRESET=DEFAULT_RANGE_LABEL;
      SHOWZERO=true;
      FLOWFORCEZERO=false;
      FLOWYEAR=Number(today().slice(0,4));
      status.default_range_applied=true;
      status.default_range=range;
      return range;
    }

    loadFlowRange=async function(from,to){
      if(!status.default_range_applied){
        const range=useDefaultState();
        from=range.from;to=range.to;
      }
      const valid=value=>/^\d{4}-\d{2}-\d{2}$/.test(String(value||''));
      if(!valid(from)||!valid(to)||from>to)return;
      const sequence=++flowRequestSequence;
      FLOWLOADING=true;FLOWFROM=from;FLOWTO=to;
      status.refresh_requested=true;
      status.last_flow_done=false;status.last_flow_ok=false;
      status.requested_range={from,to};
      if(V==='Fluxo Diário')render();
      try{
        const {data,error}=await S.rpc('lts_browser_flow_v3',{p_from:from,p_to:to});
        if(sequence!==flowRequestSequence)return;
        if(error||!data?.flow)throw new Error(error?.message||'Resposta do Fluxo sem dados');
        FLOWQ=data.flow;
        status.last_flow_ok=true;status.last_flow_error=null;
        status.loaded_range={from,to};
      }catch(error){
        if(sequence!==flowRequestSequence)return;
        status.last_flow_ok=false;
        status.last_flow_error=String(error?.message||error||'Falha de leitura');
        FLOWQ={error:'Não foi possível carregar este período. Tente novamente.',historical:{days:[],events:[]},current_future:{days:[],events:[]}};
      }finally{
        if(sequence===flowRequestSequence){
          FLOWLOADING=false;status.last_flow_done=true;
          if(V==='Fluxo Diário')render();
        }
      }
    };

    function openDefaultRange(){
      const range=useDefaultState();
      return loadFlowRange(range.from,range.to);
    }

    function bindDefaultRange(){
      if(V!=='Fluxo Diário')return;
      const first=document.querySelector('[data-p]');
      if(first&&!document.getElementById('flowDefaultRange')){
        const button=document.createElement('button');
        button.id='flowDefaultRange';button.type='button';button.className='chip';
        button.textContent=DEFAULT_RANGE_LABEL;
        button.title='Cinco dias anteriores, hoje e os próximos 30 dias';
        first.parentNode.insertBefore(button,first);
      }
      const button=document.getElementById('flowDefaultRange');
      if(button){
        const range=defaultRange(),active=FLOWFROM===range.from&&FLOWTO===range.to;
        button.classList.toggle('active',active);
        button.setAttribute('aria-pressed',String(active));
        button.onclick=openDefaultRange;
      }
      // Preserve one Hoje control; it restores the complete default window.
      document.querySelectorAll('[data-p="Hoje"]').forEach(node=>node.remove());
      const go=document.getElementById('goToday');
      if(go)go.onclick=()=>openDefaultRange();
    }

    const preservedRender=render;
    render=function(){
      const entered=V==='Fluxo Diário'&&lastRenderedRoute!=='Fluxo Diário';
      lastRenderedRoute=V;
      preservedRender();
      bindDefaultRange();
      if(entered&&D&&status.default_range_applied){
        queueMicrotask(()=>{if(V==='Fluxo Diário')openDefaultRange()});
      }
    };
    const preservedRenderNav=renderNav;
    renderNav=function(){
      preservedRenderNav();
      const button=document.querySelector('.nav [data-v="Fluxo Diário"]');
      if(button)button.onclick=()=>{
        V='Fluxo Diário';lastRenderedRoute=V;
        renderNav();openDefaultRange();
      };
    };
    renderNav();
    bindDefaultRange();

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

      // An inherited read may already be running when the frame loads.
      // Let it finish before the default read so it cannot overwrite the new window.
      if(!status.refresh_requested&&!FLOWLOADING){
        Promise.resolve(openDefaultRange()).catch(error=>{
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
      if(!w||!d||!d.documentElement)return null;
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
    const host=frame.d.head||frame.d.documentElement;
    if(!host)return false;
    const script=frame.d.createElement('script');
    script.id='lts-v162-flow-runtime';
    script.textContent=`(${recoveryRuntime.toString()})();`;
    host.appendChild(script);
    return frame.w.__LTS_V162_FLOW_RECOVERY_STATUS?.installed===true;
  }

  function install(){
    const frame=currentFrame();
    if(!frame)return false;
    if(!frame.d.getElementById('v162-flow-scope-css')){
      const host=frame.d.head||frame.d.documentElement;
      if(!host)return false;
      const style=frame.d.createElement('style');
      style.id='v162-flow-scope-css';
      style.textContent=`
        .nav [data-v="Dashboard"]{display:none!important}
        .footer{display:none!important}
        @media(max-width:820px){
          .fx87-row.fx87-cons .fx87-cell:nth-child(n+2){display:block!important;padding:8px 7px!important;text-align:right!important;min-height:49px}
          .fx87-row.fx87-cons .fx87-cell:nth-child(n+2)::before{display:block;margin-bottom:4px;color:var(--mut);font-size:8px;font-weight:850;line-height:1.15;text-align:left;text-transform:uppercase;letter-spacing:.025em}
          .fx87-row.fx87-cons .fx87-cell:nth-child(2)::before{content:'Saldo anterior'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(3)::before{content:'Entradas'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(4)::before{content:'Saídas'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(5)::before{content:'Saldo final'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(6)::before{content:'D0/D1'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(7)::before{content:'Saldo c/ D0/D1'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(8)::before{content:'RSU vested'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(9)::before{content:'Saldo c/ RSU'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(10)::before{content:'FGTS restrito'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(11)::before{content:'Saldo total'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(2),
          .fx87-row.fx87-cons .fx87-cell:nth-child(5),
          .fx87-row.fx87-cons .fx87-cell:nth-child(7),
          .fx87-row.fx87-cons .fx87-cell:nth-child(9),
          .fx87-row.fx87-cons .fx87-cell:nth-child(11){background:#f2f4f6!important;border-radius:8px}
          .fx87-row.fx87-cons .fx87-cell:nth-child(6),
          .fx87-row.fx87-cons .fx87-cell:nth-child(7){border-top:1px solid #e4e9ef}
          .fx87-date{display:flex!important;min-height:0!important;text-align:left!important}
        }
      `;
      host.appendChild(style);
    }
    if(!installRuntime(frame))return false;
    const result=frame.w.__LTS_V162_ROUTE_FLOW?.();
    const status=frame.w.__LTS_V162_FLOW_RECOVERY_STATUS;
    if(result?.state==='login'){
      hideGate();
      return true;
    }
    if(status?.refresh_requested&&status?.last_flow_done){
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
