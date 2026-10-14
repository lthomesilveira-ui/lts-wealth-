/* Fail-closed view boundary for old renderers during an incomplete C6 read. */
(function(root){
 'use strict';
 let observer,panel,style,scheduled=false;
 function check(){
  scheduled=false;const state=root.__LTS_V269_COMPLETENESS?.(),view=root.__LTS_V269_VIEW?.(),a=view?.container;
  if(!a)return;
  if(!style){style=document.createElement('style');style.textContent='[data-v269-blocked="true"]{display:none!important}[data-v269-cards-only="true"] .v168-expenses>*:not(.v168-pagehead):not(.v168-tabs):not(.v226-upcoming){display:none!important}#v269-incomplete-panel{margin:18px;padding:20px;border:1px solid #d9e2eb;border-radius:16px;background:white;color:#17304d;font:14px/1.5 system-ui}#v269-incomplete-panel[hidden]{display:none}';document.head.appendChild(style);}
  if(!panel){panel=document.createElement('section');panel.id='v269-incomplete-panel';panel.setAttribute('role','status');panel.innerHTML='<strong>C6 em conferência</strong><p>Esta visão depende de um consolidado ainda incompleto. Consulte o caixa observado no Dashboard, os demais bancos no Fluxo Diário e as evidências na aba Cartões de Despesas.</p><button type="button">Ver cartões e evidências</button>';panel.querySelector('button').onclick=()=>root.__LTS_V269_OPEN_CARDS?.();a.after(panel);}
  let safe=true,cardsOnly=false;
  if(state?.incomplete){
   safe=false;
   if(view.view==='Dashboard')safe=root.__LTS_V178_REVIEW?.completeness_contract===269&&root.__LTS_V178_STATE?.forecast?.data?.complete===false;
   if(view.view==='Fluxo Diário')safe=root.__LTS_V228_FLOW?.completeness_contract===269&&view.flowIncomplete===true;
   if(view.view==='Despesas'&&view.expenseTab==='cards'){
    safe=root.__LTS_V226?.completeness_contract===269&&root.__LTS_V226?.cycles?.complete===false&&!!a.querySelector('.v226-upcoming');cardsOnly=safe;
   }
  }
  const blocked=state?.incomplete&&!safe;
  if(a.dataset.v269Blocked!==String(blocked))a.dataset.v269Blocked=String(blocked);
  if(a.dataset.v269CardsOnly!==String(cardsOnly))a.dataset.v269CardsOnly=String(cardsOnly);
  a.inert=blocked;panel.hidden=!blocked;
  if(blocked){document.querySelectorAll('dialog[open]:not(#v226-detail),#v178Drawer').forEach(x=>{if(x.close)x.close();else x.remove()});}
 }
 function schedule(){if(scheduled)return;scheduled=true;queueMicrotask(check);}
 root.__LTS_V269_RECHECK=check;
 observer=new MutationObserver(schedule);observer.observe(document,{childList:true,subtree:true});
 document.addEventListener('DOMContentLoaded',check);root.addEventListener('pageshow',check);
})(window);
