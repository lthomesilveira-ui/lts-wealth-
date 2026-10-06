/* Preserve card sections through asynchronous reader renders. No financial state is stored. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function install(){
  try{
   const w=shell?.contentWindow,d=shell?.contentDocument;
   if(!w||!d||!w.__LTS_V226?.installed||!d.getElementById('app'))return false;
   if(w.__LTS_V257_UI_STATE?.installed)return true;
   const runtime=function(){
    if(window.__LTS_V257_UI_STATE?.installed)return;
    const saved=new Map(),tracked=new WeakMap(),selector='details.v226-future';
    const key=()=>String(typeof V==='undefined'?'':V)+'|card-future';
    function register(){
     for(const node of document.querySelectorAll(selector)){
      const k=key();tracked.set(node,k);
      if(saved.has(k))node.open=saved.get(k);else saved.set(k,node.open);
     }
    }
    const observer=new MutationObserver(records=>{
     for(const record of records)for(const removed of record.removedNodes){
      if(removed.nodeType!==1)continue;
      for(const node of [removed,...removed.querySelectorAll(selector)]){
       if(tracked.has(node))saved.set(tracked.get(node),node.open);
      }
     }
     register();
    });
    document.addEventListener('toggle',event=>{
     const node=event.target;if(node?.matches?.(selector)&&node.isConnected&&tracked.has(node))saved.set(tracked.get(node),node.open);
    },true);
    register();observer.observe(document.getElementById('app'),{childList:true,subtree:true});
    window.__LTS_V257_UI_STATE={installed:true,financial_data_changed:false};
   };
   const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);return !!w.__LTS_V257_UI_STATE?.installed;
  }catch{return false}
 }
 let tries=0;const timer=setInterval(()=>{if(install()||++tries>200)clearInterval(timer)},100);
 shell?.addEventListener('load',install);
})();
