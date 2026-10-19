/* Defer background rendering while a native category picker is focused. */
(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V290_USABILITY)return;
  const previous=render;let deferred=false,route=null;
  const categoryFocused=()=>{const el=document.activeElement;return el?.matches('input,select,textarea')||!!el?.closest('.lts-new-category');};
  const ready=()=>D&&!N.classList.contains('hidden')&&(typeof BOOT==='undefined'||document.body.dataset.ltsBootState==='ready');
  function after(){
   if(V==='Fluxo Diário'&&typeof mergedFlowDays==='function'){
    const now=typeof today==='function'?today():null;
    for(const day of mergedFlowDays()){
     const row=document.getElementById('d-'+day.date);if(!row?.firstElementChild)continue;
     let phase=row.querySelector('.lts-phase');if(!phase){phase=document.createElement('small');phase.className='lts-phase';row.firstElementChild.appendChild(phase);}
     phase.textContent=day.date>now?'Previsto':day.date===now?'Realizado e previsto':day.movements_complete===false?'Em conferência':'Realizado';
    }
   }
  }
  render=function(){
   let notice=document.getElementById('ltsDeferredUpdate');
   if(ready()&&categoryFocused()&&(route===null||route===V)){
    deferred=true;route=V;if(!notice){notice=document.createElement('p');notice.id='ltsDeferredUpdate';notice.setAttribute('role','status');notice.className='lts-editing-update';document.getElementById('app')?.before(notice);}
    notice.textContent='Há dados novos. Eles serão exibidos ao concluir a edição.';notice.hidden=false;return;
   }
   if(notice)notice.hidden=true;
   route=V;deferred=false;const out=previous.apply(this,arguments);after();return out;
  };
  // Flush after the click handler has captured its fields; a blur-time render
  // would remove the target button before the user's first click reaches it.
  document.addEventListener('click',()=>setTimeout(()=>{if(deferred&&!categoryFocused())render();},0));
  window.__LTS_V290_USABILITY={installed:true,source_amounts_unchanged:true};after();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_FLOW_OVERDUE_PROJECTIONS||!w?.LTSCategoryRegistry)return false;if(!w.__LTS_V290_USABILITY){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return !!w.__LTS_V290_USABILITY;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();
})();
