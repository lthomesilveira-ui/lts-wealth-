(function(){
  'use strict';
  const outer=document.getElementById('shell'),gate=document.getElementById('gate'),scope=document.getElementById('scope');
  let generation=0;

  function runtime(){
    'use strict';
    if(window.__LTS_V176_FLOW_EXPENSE_AUDIT?.installed||!window.__LTS_V175_EXPENSE_AUDIT?.installed)return;

    const state=window.__LTS_V176_STATE||(window.__LTS_V176_STATE={installedAt:new Date().toISOString()});
    const nativeFetch=window.fetch.bind(window);
    const rpcMap=new Map([
      ['lts_browser_expense_executive_v8','lts_browser_expense_executive_v9'],
      ['lts_browser_monthly_balance_v5','lts_browser_monthly_balance_v6']
    ]);

    function remapRpcUrl(input){
      const raw=typeof input==='string'?input:input?.url;
      if(!raw)return input;
      let next=raw;
      for(const [from,to] of rpcMap){
        next=next.replace('/rest/v1/rpc/'+from,'/rest/v1/rpc/'+to);
      }
      if(next===raw)return input;
      if(typeof input==='string')return next;
      return new Request(next,input);
    }
    window.fetch=function(input,init){return nativeFetch(remapRpcUrl(input),init)};

    const isNonCashAwardEvent=e=>{
      const src=String(e?.source||'').toLowerCase(),cat=String(e?.category||'').toLowerCase(),acct=String(e?.account||'').toLowerCase();
      return /^future_(rsu|cash_rsu)_available$/.test(src)
        || src==='future_award_vesting_marker'
        || (src.startsWith('future_')&&acct==='corretora'&&/(rsu|cash rsu)/.test(cat));
    };

    const baseDayEvents=dayEvents;
    dayEvents=function(day){return baseDayEvents(day).filter(e=>!isNonCashAwardEvent(e))};

    const baseFlowVals=flowVals;
    flowVals=function(x,prev){
      const value=baseFlowVals(x,prev);
      if(!x?.historical&&ACC==='Consolidado'){
        const c=x.fix86_columns||{};
        if(c.entradas!==undefined&&c.entradas!==null)value.en=num(c.entradas);
        if(c.saidas!==undefined&&c.saidas!==null)value.ex=num(c.saidas);
      }
      return value;
    };

    flowDayMaterial=function(x,prev){
      const v=flowVals(x,prev);
      return Math.abs(num(v?.en))>0.005||Math.abs(num(v?.ex))>0.005;
    };

    function rsuDeltaFor(day){
      const days=mergedFlowDays(),index=days.findIndex(x=>x.date===day);
      if(index<=0)return 0;
      const current=num(days[index]?.fix86_columns?.rsus_vested),previous=num(days[index-1]?.fix86_columns?.rsus_vested);
      return current-previous;
    }
    function decorateFlow(){
      if(V!=='Fluxo Diário')return;
      document.querySelectorAll('.fx87-row.fx87-cons[id^="d-"]').forEach(row=>{
        const day=row.id.slice(2),delta=rsuDeltaFor(day),cell=row.children?.[7];
        if(!cell)return;
        cell.querySelector('.v176-rsu-delta')?.remove();
        cell.classList.toggle('v176-rsu-active',delta>0.005);
        if(delta>0.005){
          const small=document.createElement('small');
          small.className='v176-rsu-delta';
          small.textContent='+'+brl(delta);
          small.title='Aumento de RSU vested / disponível na corretora; não é entrada de conta corrente.';
          cell.appendChild(small);
        }
      });
      const zero=document.getElementById('flowZero');
      if(zero){
        zero.onclick=()=>{
          SHOWZERO=!SHOWZERO;
          if(!SHOWZERO)FLOWFORCEZERO=false;
          render();
        };
        zero.title=SHOWZERO
          ?'Ocultar dias sem entrada ou saída de caixa'
          :'Mostrar também dias sem entrada ou saída de caixa';
      }
    }

    const baseRender=render;
    render=function(){const out=baseRender();decorateFlow();return out};
    const baseRenderNav=renderNav;
    renderNav=function(){const out=baseRenderNav();const badge=window.parent?.document?.getElementById('scope');if(badge)badge.dataset.v176Route=V==='Fluxo Diário'?'Fluxo de caixa':V;return out};

    const v175=window.__LTS_V175_STATE;
    if(v175){
      if(v175.expense){v175.expense.data=null;v175.expense.key='';v175.expense.error=null;v175.expense.loading=false;v175.expense.token=(v175.expense.token||0)+1}
      if(v175.monthly){v175.monthly.data=null;v175.monthly.key='';v175.monthly.error=null;v175.monthly.loading=false;v175.monthly.token=(v175.monthly.token||0)+1}
    }

    window.__LTS_V176_FLOW_EXPENSE_AUDIT={
      installed:true,version:'v176',base_version:'v175',public_index_changed:false,
      rsu_non_cash_in_entries:true,zero_day_cash_only:true,
      expense_window_reader:'lts_browser_expense_executive_v9',
      monthly_window_reader:'lts_browser_monthly_balance_v6',
      health_6m_corrected_brl:56307.56,
      health_12m_audited_brl:105050.49,
      loans_6m_audited_brl:38691.93,
      loans_12m_audited_brl:109227.39
    };
    if(D&&!N.classList.contains('hidden'))render();
  }

  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return null;return{w,d}}catch{return null}}
  function install(){
    const f=frame();if(!f||!f.w.__LTS_V175_EXPENSE_AUDIT?.installed)return false;
    if(!f.d.getElementById('lts-v176-style')){const link=f.d.createElement('link');link.id='lts-v176-style';link.rel='stylesheet';link.href='lts-v176-flow-expense-audit.css?v=20260918-v176a';f.d.head.appendChild(link)}
    if(!f.w.__LTS_V176_FLOW_EXPENSE_AUDIT?.installed&&!f.d.getElementById('lts-v176-runtime')){const script=f.d.createElement('script');script.id='lts-v176-runtime';script.textContent='('+runtime.toString()+')();';f.d.head.appendChild(script)}
    const ready=f.w.__LTS_V176_FLOW_EXPENSE_AUDIT?.installed===true;if(ready&&gate)gate.remove();return ready;
  }
  function burst(){const current=++generation;let attempt=0;function step(){if(current!==generation)return;const ready=install();attempt++;if(!ready&&attempt<320)setTimeout(step,100)}step();[400,900,1800,3600,7000,12000,20000,30000].forEach(ms=>setTimeout(()=>{if(current===generation)install()},ms))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();
  window.__LTS_TOP_CANDIDATE_VERSION='v176-flow-expense-audit';
})();