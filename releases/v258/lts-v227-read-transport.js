/* Read-only transport: one in-flight request per authenticated query, bounded waits.
   Writes are never cached, replayed, or remapped here. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V227_TRANSPORT)return;
  const native=window.fetch.bind(window),pending=new Map(),completed=new Map(),events=[];let revision=0;const invalidate=(notify=true)=>{revision++;completed.clear();pending.clear();if(notify)window.dispatchEvent(new Event('lts:data-invalidated'))};const ttl=60000;
  const readName=/^lts_browser_(?:product_|dashboard_cockpit_|cash_today_|expenses_|expense_executive_|expense_context_|expense_review_queue_|wealth_detail_|awards_|planning_ui_|flow_v|monthly_|card_cycles_|card_history_|card_detail_|card_flow_schedule_|open_finance_status_|open_finance_pending_|recurring_future_gap_)/;
  // The production database has a shared execution budget. Admit one expensive
  // read at a time across screen owners; cash and status remain independent.
  const heavy=/^lts_browser_(?:expenses_|expense_executive_|expense_context_|expense_review_queue_|planning_ui_|flow_v|monthly_|card_cycles_|card_history_|card_detail_|card_flow_schedule_|open_finance_pending_|recurring_future_gap_)/;
  // The complete flow reader has a 45-second database ceiling. Do not cancel
  // valid cold/year reads at the generic 25-second transport deadline.
  const readBudget=name=>/^lts_browser_flow_v/.test(name)?48000:25000;
  const waiting=[];let active=false,pumpTimer=null,order=0;
  const priority=name=>/expense_review_queue_|card_detail_/.test(name)?0:/card_cycles_|flow_v/.test(name)?1:/recurring_future_gap_/.test(name)?3:2;
  function pump(){
   pumpTimer=null;if(active||!waiting.length)return;
   waiting.sort((a,b)=>a.priority-b.priority||a.order-b.order);
   const next=waiting.shift();clearTimeout(next.timer);next.signal.removeEventListener('abort',next.cancel);active=true;
   let released=false;next.resolve(()=>{if(released)return;released=true;active=false;pump();});
  }
  function admit(name,signal){
   if(!heavy.test(name))return Promise.resolve(()=>{});
   return new Promise((resolve,reject)=>{
    const item={resolve,priority:priority(name),order:order++,signal,cancel:()=>{clearTimeout(item.timer);signal.removeEventListener('abort',item.cancel);const i=waiting.indexOf(item);if(i>=0)waiting.splice(i,1);reject(new DOMException('Aborted','AbortError'));}};
    if(signal.aborted){item.cancel();return;}
    signal.addEventListener('abort',item.cancel,{once:true});item.timer=setTimeout(item.cancel,60000);waiting.push(item);
    if(!active&&!pumpTimer)pumpTimer=setTimeout(pump,30);
   });
  }
  const publish=entry=>{events.push(entry);if(events.length>30)events.shift();document.documentElement.setAttribute('data-lts-v227-reads',JSON.stringify(events));};
  window.fetch=async function(input,init){
   const url=typeof input==='string'?input:input?.url||'',name=url.split('/').pop();
   if(!url.includes('/rest/v1/rpc/'))return native(input,init);
   if(!readName.test(name)){const mutation=/_decision_|_update_|_save_|_apply_|_delete_|_refresh_|_confirm_|_upload_|_mutate_|_classify_|_classification_|_create_/.test(name);if(mutation)invalidate(false);const response=await native(input,init);if(mutation&&response.ok)invalidate();return response}
   const headers=new Headers(init?.headers||input?.headers),key=name+'|'+headers.get('Authorization')+'|'+String(init?.body||'');
   const cacheable=!/open_finance_status_/.test(name);
   const saved=cacheable?completed.get(key):null;if(saved&&performance.now()-saved.at<ttl)return saved.response.clone();
   const generation=revision;
   if(pending.has(key))return (await pending.get(key)).clone();
   const controller=new AbortController(),signal=init?.signal||input?.signal;
   const cancel=()=>controller.abort();
   if(signal?.aborted)cancel();else signal?.addEventListener('abort',cancel,{once:true});
   const queued=performance.now();let started=queued,timer,release=()=>{};
   const job=(async()=>{
    try{release=await admit(name,controller.signal);started=performance.now();init?.ltsOnReadStart?.();timer=setTimeout(cancel,readBudget(name));const response=await native(input,{...init,signal:controller.signal});
     // Buffer before resolving so both headers and the response body are bounded.
     const body=await response.arrayBuffer();
     publish({name,status:response.status,duration_ms:Math.round(performance.now()-started),queued_ms:Math.round(started-queued)});
     const buffered=new Response(body,{status:response.status,statusText:response.statusText,headers:response.headers});
     if(cacheable&&response.ok&&generation===revision){completed.set(key,{at:performance.now(),response:buffered.clone()});if(completed.size>24)completed.delete(completed.keys().next().value)}
     return buffered;
    }catch(error){publish({name,status:controller.signal.aborted?'timeout':'network_error',duration_ms:Math.round(performance.now()-started)});throw error;}
    finally{clearTimeout(timer);signal?.removeEventListener('abort',cancel);release();}
   })();
   pending.set(key,job);
   try{return (await job).clone();}finally{if(pending.get(key)===job)pending.delete(key);}
  };
  window.__LTS_V227_TRANSPORT={installed:true,invalidate,get revision(){return revision}};
  if(typeof S!=='undefined')S.auth.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT'||event==='SIGNED_IN'){invalidate();if(typeof FLOWQ!=='undefined')FLOWQ=null}});
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!d?.head||!String(w.location.pathname).endsWith('/index.html'))return false;if(!w.__LTS_V227_TRANSPORT){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);}return !!w.__LTS_V227_TRANSPORT;}catch{return false}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,50);}shell?.addEventListener('load',()=>{tries=0;start();});start();
})();
