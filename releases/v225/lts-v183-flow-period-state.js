/* Candidate-only presentation guard. Never changes financial rows or readers. */
(function(){
 'use strict';
 function runtime(){
  if(window.__LTS_V183_FLOW_PERIOD_STATE)return;
  const baseRender=render;
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
   const hide=loading||stale||!!data?.error;
   table.hidden=hide;table.style.display=hide?'none':'';
   table.setAttribute('aria-busy',String(loading));
  }
  render=function(){
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
