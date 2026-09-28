/* Read-only transport: one in-flight request per authenticated query, bounded waits.
   Writes are never cached, replayed, or remapped here. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V227_TRANSPORT)return;
  const native=window.fetch.bind(window),pending=new Map(),events=[];
  const readName=/^lts_browser_(?:product_|dashboard_cockpit_|cash_today_|expenses_|expense_executive_|expense_context_|wealth_detail_|awards_|planning_ui_|flow_v|monthly_|card_cycles_|card_history_|card_detail_|card_flow_schedule_|open_finance_status_|open_finance_pending_)/;
  const publish=entry=>{events.push(entry);if(events.length>30)events.shift();document.documentElement.setAttribute('data-lts-v227-reads',JSON.stringify(events));};
  window.fetch=async function(input,init){
   const url=typeof input==='string'?input:input?.url||'',name=url.split('/').pop();
   if(!url.includes('/rest/v1/rpc/')||!readName.test(name))return native(input,init);
   const headers=new Headers(init?.headers||input?.headers),key=name+'|'+headers.get('Authorization')+'|'+String(init?.body||'');
   if(pending.has(key))return (await pending.get(key)).clone();
   const controller=new AbortController(),signal=init?.signal||input?.signal;
   const cancel=()=>controller.abort();
   if(signal?.aborted)cancel();else signal?.addEventListener('abort',cancel,{once:true});
   const started=performance.now(),timer=setTimeout(cancel,25000);
   const job=(async()=>{
    try{const response=await native(input,{...init,signal:controller.signal});
     // Buffer before resolving so both headers and the response body are bounded.
     const body=await response.arrayBuffer();
     publish({name,status:response.status,duration_ms:Math.round(performance.now()-started)});
     return new Response(body,{status:response.status,statusText:response.statusText,headers:response.headers});
    }catch(error){publish({name,status:controller.signal.aborted?'timeout':'network_error',duration_ms:Math.round(performance.now()-started)});throw error;}
    finally{clearTimeout(timer);signal?.removeEventListener('abort',cancel);}
   })();
   pending.set(key,job);
   try{return (await job).clone();}finally{if(pending.get(key)===job)pending.delete(key);}
  };
  window.__LTS_V227_TRANSPORT={installed:true};
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!d?.head||!String(w.location.pathname).endsWith('/index.html'))return false;if(!w.__LTS_V227_TRANSPORT){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);}return !!w.__LTS_V227_TRANSPORT;}catch{return false}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,50);}shell?.addEventListener('load',()=>{tries=0;start();});start();
})();
