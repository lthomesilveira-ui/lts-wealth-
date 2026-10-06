/* Candidate-only presentation guard. Never changes financial rows or readers. */
(function(){
 'use strict';
 function runtime(){
  if(window.__LTS_V183_FLOW_PERIOD_STATE)return;
  const baseRender=render;
  const baseLoadRange=loadFlowRange;
  let draft=null,applying=false;
  const rangeKey=()=>String(FLOWFROM)+'|'+String(FLOWTO);
  function captureDraft(){
   const from=document.getElementById('flowFrom'),to=document.getElementById('flowTo');
   if(!applying&&V==='Fluxo Diário'&&from&&to&&(from.value!==FLOWFROM||to.value!==FLOWTO))draft={key:rangeKey(),from:from.value,to:to.value};
  }
  loadFlowRange=function(from,to){draft=null;applying=true;try{return baseLoadRange.apply(this,arguments)}finally{applying=false}};
  const style=document.createElement('style');style.textContent='.v242-spinner{width:24px;height:24px;border:3px solid #dae4ee;border-top-color:#245c91;border-radius:50%;animation:v242-spin .8s linear infinite}@keyframes v242-spin{to{transform:rotate(360deg)}}@media(prefers-reduced-motion:reduce){.v242-spinner{animation:none;border-style:dotted}}.v168-chart svg{min-height:0!important}.v168-chart path{stroke-width:2;vector-effect:non-scaling-stroke;stroke-linejoin:round;stroke-linecap:round}.v168-chart .zero{stroke-width:1.2;stroke-dasharray:5 5;opacity:.65}.v168-chart select{max-width:130px;border:1px solid #d8e1e9;border-radius:8px;padding:7px 10px;background:#fff;color:#334c65}';document.head.appendChild(style);
  const validDay=value=>/^\d{4}-\d{2}-\d{2}$/.test(String(value||''));
  function period(){
   const from=typeof FLOWFROM==='undefined'?null:FLOWFROM,to=typeof FLOWTO==='undefined'?null:FLOWTO;
   return validDay(from)&&validDay(to)&&from<=to?{from,to}:null;
  }
  function syncYear(){
   const r=period();
   if(r&&r.from.slice(0,4)===r.to.slice(0,4))FLOWYEAR=Number(r.from.slice(0,4));
  }
  function decorate(){
   if(V!=='Fluxo Diário')return;
   const r=period(),select=document.getElementById('flowYear');
   const from=document.getElementById('flowFrom'),to=document.getElementById('flowTo');
   if(draft&&draft.key===rangeKey()&&from&&to){from.value=draft.from;to.value=draft.to}
   else draft=null;
   if(from&&to){from.oninput=to.oninput=captureDraft;from.onchange=to.onchange=captureDraft}
   if(r&&select){
    const singleYear=r.from.slice(0,4)===r.to.slice(0,4),value=singleYear?r.from.slice(0,4):'';
    let option=Array.from(select.options).find(item=>item.value===value);
    if(!option){option=document.createElement('option');option.value=value;option.textContent=singleYear?value:'Período personalizado';option.disabled=!singleYear;select.appendChild(option)}
    select.value=value;
    select.setAttribute('aria-label','Ano do período do Fluxo');
   }
   const table=document.querySelector('.fx87-mesa');
   if(!table)return;
   // The old reader intentionally keeps its previous response while loading.
   // Retain that data, but do not display it underneath the new date controls.
   const loading=typeof FLOWLOADING!=='undefined'&&FLOWLOADING;
   const data=typeof FLOWQ==='undefined'?null:FLOWQ;
   const stale=!!r&&!!data&&(data.from!==r.from||data.to!==r.to);
   const hide=!data||loading||stale||!!data?.error;
   table.hidden=hide;table.style.display=hide?'none':'';
   table.setAttribute('aria-busy',String(loading));
   document.getElementById('v236-current-position-note')?.remove();
   document.getElementById('v242-flow-loading')?.remove();
   if(loading){
    const status=document.createElement('div');status.id='v242-flow-loading';status.setAttribute('role','status');status.setAttribute('aria-live','polite');
    status.innerHTML='<span class="v242-spinner" aria-hidden="true"></span><span>Carregando fluxo de caixa…</span>';
    status.style.cssText='display:flex;align-items:center;justify-content:center;gap:12px;min-height:140px;color:#536174';table.before(status);
   }
  }
  render=function(){
   captureDraft();
   if(V==='Fluxo Diário')syncYear();
   const result=baseRender.apply(this,arguments);decorate();return result;
  };
  window.__LTS_V183_FLOW_PERIOD_STATE={installed:true,financial_data_changed:false};
  syncYear();decorate();
 }
 const shell=document.getElementById('shell');
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V183_EXACT_FLOW_NAVIGATION?.installed)return false;if(w.__LTS_V183_FLOW_PERIOD_STATE)return true;const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);return !!w.__LTS_V183_FLOW_PERIOD_STATE}catch{return false}}
 function burst(){let count=0;const timer=setInterval(()=>{if(install()||++count>160)clearInterval(timer)},150)}
 shell?.addEventListener('load',burst);burst();
})();
