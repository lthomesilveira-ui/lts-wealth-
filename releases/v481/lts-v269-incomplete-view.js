/* Fail-closed view boundary for old renderers during an incomplete C6 read. */
(function(root){
 'use strict';
 let observer,panel,style,scheduled=false;
 function check(){
  scheduled=false;const state=root.__LTS_V269_COMPLETENESS?.(),view=root.__LTS_V269_VIEW?.(),a=view?.container;
  if(!a)return;
  if(!style){style=document.createElement('style');style.textContent='[data-v269-blocked="true"]{display:none!important}[data-v269-cards-only="true"] .v168-expenses>*:not(.v168-pagehead):not(.v168-tabs):not(.v226-upcoming){display:none!important}#v269-incomplete-panel{position:fixed;z-index:20;top:80px;left:18px;right:18px;max-width:980px;margin:0 auto;box-sizing:border-box;overflow:auto;padding:20px;border:1px solid #d9e2eb;border-radius:16px;background:white;color:#17304d;font:14px/1.5 system-ui}#v269-incomplete-panel[hidden]{display:none}';document.head.appendChild(style);}
  if(!panel){panel=document.createElement('section');panel.id='v269-incomplete-panel';panel.setAttribute('role','status');panel.innerHTML='<strong>C6 em conferência</strong><p>Esta visão depende de um consolidado ainda incompleto. Consulte o caixa observado no Dashboard, os demais bancos no Fluxo Diário e as evidências na aba Cartões de Despesas.</p><button type="button">Ver cartões e evidências</button>';panel.querySelector('button').onclick=()=>root.__LTS_V269_OPEN_CARDS?.();a.after(panel);}
  let safe=true,cardsOnly=false;
  const signedIn=!!document.getElementById('nav')&&!document.getElementById('nav').classList.contains('hidden');
  if(state?.incomplete&&signedIn){
   safe=false;
   if(view.view==='Dashboard')safe=root.__LTS_V178_REVIEW?.completeness_contract===269&&root.__LTS_V178_STATE?.forecast?.data?.complete===false;
   if(view.view==='Fluxo Diário')safe=root.__LTS_V228_FLOW?.completeness_contract===269&&view.flowIncomplete===true;
   if(view.view==='Despesas'&&view.expenseTab==='cards'){
    safe=root.__LTS_V226?.completeness_contract===269&&root.__LTS_V226?.cycles?.complete===false&&!!a.querySelector('.v226-upcoming');cardsOnly=safe;
   }
  }
  const blocked=!!(state?.incomplete&&signedIn&&!safe);
  if(a.dataset.v269Blocked!==String(blocked))a.dataset.v269Blocked=String(blocked);
  if(a.dataset.v269CardsOnly!==String(cardsOnly))a.dataset.v269CardsOnly=String(cardsOnly);
  a.inert=blocked;panel.hidden=!blocked;
  if(blocked){const h=document.querySelector('.hdr')?.getBoundingClientRect(),side=!!h&&h.height>h.width&&h.right<root.innerWidth/2;const top=side?18:Math.max(0,h?.bottom||0)+18;panel.style.top=top+'px';panel.style.left=(side?h.right+18:18)+'px';panel.style.maxHeight=Math.max(80,root.innerHeight-top-100)+'px';}
  if(blocked){document.querySelectorAll('dialog[open]:not(#v226-detail),#v178Drawer').forEach(x=>{if(x.close)x.close();else x.remove()});}
 }
 function schedule(){if(scheduled)return;scheduled=true;queueMicrotask(check);}
 root.__LTS_V269_RECHECK=check;
 observer=new MutationObserver(schedule);observer.observe(document,{childList:true,subtree:true});
 document.addEventListener('DOMContentLoaded',check);root.addEventListener('pageshow',check);root.addEventListener('resize',schedule);
})(window);
