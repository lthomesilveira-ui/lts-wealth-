/* Rearm idempotent local components when a prerequisite is inserted late. */
(function(){
 'use strict';if(window.LTSV339Boot)return;
 const shell=document.getElementById('shell'),components=new Map(),limit=128;
 let frameDocument=null,observer=null,epoch=0,scheduled=false,flushing=false;
 function disconnect(){observer?.disconnect();observer=null;}
 function pending(){return [...components.values()].some(x=>!x.ready&&x.attempts<limit);}
 function bind(){
  let doc;try{if(!String(shell?.contentWindow?.location.pathname||'').endsWith('/index.html'))return false;doc=shell.contentDocument;if(!doc?.head)return false;}catch{return false;}
  if(doc!==frameDocument){disconnect();frameDocument=doc;epoch++;for(const value of components.values()){value.ready=false;value.attempts=0;}}
  if(!observer&&pending()){observer=new MutationObserver(schedule);observer.observe(doc.head,{childList:true});}
  return true;
 }
 function flush(){
  scheduled=false;if(flushing||!bind())return;flushing=true;
  try{for(const component of components.values()){
   if(component.ready||component.attempts>=limit)continue;
   component.attempts++;try{component.ready=component.install()===true;}catch{component.ready=false;}
  }}finally{flushing=false;if(!pending())disconnect();}
 }
 function schedule(){if(scheduled)return;scheduled=true;queueMicrotask(flush);}
 function watch(id,install){
  if(typeof id!=='string'||typeof install!=='function'||components.has(id))return;
  components.set(id,{install,ready:false,attempts:0});bind();schedule();
 }
 shell?.addEventListener('load',()=>{bind();schedule();});
 window.LTSV339Boot=Object.freeze({watch,snapshot:()=>({epoch,observer_active:!!observer,components:[...components].map(([id,x])=>({id,ready:x.ready,attempts:x.attempts,exhausted:!x.ready&&x.attempts>=limit}))})});
})();
