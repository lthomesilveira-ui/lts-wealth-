/* Read-only transport: one in-flight request per authenticated query, bounded waits.
   Writes are never cached, replayed, or remapped here. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V227_TRANSPORT)return;
  const native=window.fetch.bind(window),pending=new Map(),completed=new Map(),events=[],reads=new Set();let revision=0;
  // A new snapshot supersedes queued and running readers as well as cached
  // replies. Let their existing cancellation paths release admission before
  // fresh screen owners enqueue work; never cancel or replay a writer.
  const invalidate=(notify=true)=>{revision++;completed.clear();for(const read of reads)read.cancel('superseded');pending.clear();if(notify)window.dispatchEvent(new Event('lts:data-invalidated'))};const ttl=60000;
  const readName=/^lts_browser_(?:product_(?!refresh_request_v415$)|projection_policy_v412$|dashboard_cockpit_|cash_today_|income_review_queue_|card_review_queue_|expenses_|expense_executive_|expense_context_|expense_review_queue_|expense_detail_|expense_composition_|wealth_detail_|awards_|planning_ui_|flow_v|monthly_|month_overview_|budget_read_|card_cycles_|card_history_|card_detail_|card_flow_schedule_|open_finance_status_|open_finance_pending_|recurring_future_gap_)/;
  // The production database has a shared execution budget. Admit one expensive
  // read at a time across screen owners, including classification queues and
  // wealth/award readers that perform the same guarded card preparation.
  // Cash and connection status remain independent; writers are never admitted here.
  const heavy=/^lts_browser_(?:product_(?!refresh_(?:status|request)_v415$)|projection_policy_v412$|dashboard_cockpit_|wealth_detail_|awards_|income_review_queue_|card_review_queue_|expenses_|expense_executive_|expense_context_|expense_review_queue_|expense_detail_|expense_composition_|planning_ui_|flow_v|monthly_|month_overview_|budget_read_|card_cycles_|card_history_|card_detail_|card_flow_schedule_|open_finance_pending_|recurring_future_gap_)/;
  // Flow, month overview and cockpit have a 45-second database ceiling.
  // Their complete response bodies receive the matching 48-second budget.
  const readBudget=name=>name==='lts_browser_expense_review_queue_v229'?22000:name==='lts_browser_product_refresh_status_v415'?10000:/^lts_browser_(?:flow_v|month_overview_v393$|dashboard_cockpit_v1$)/.test(name)?48000:25000;
  const waiting=[],holds=new Set();let active=false,pumpTimer=null,order=0;
  // An intentional collection hold has its own existing 90s ceiling. Preserve
  // each reader's 60s eligible-admission budget while that hold blocks all reads.
  function pauseAdmission(item){if(item.timer!=null){clearTimeout(item.timer);item.timer=null;item.remaining=Math.max(0,item.remaining-(performance.now()-item.armedAt));}}
  function armAdmission(item){if(item.timer!=null||holds.size)return;item.armedAt=performance.now();item.timer=setTimeout(item.cancel,item.remaining);}
  // BEGIN COLLECTION READ HOLD
  // A collection starts after the admitted reader finishes. Other expensive
  // reads wait until collection ends; cash/status and writes stay independent.
  function holdHeavyReads(){
   let resolveReady,released=false,ready=false,timer;
   const promise=new Promise(resolve=>resolveReady=resolve);
   const hold={notify(){if(!active&&!released&&!ready){ready=true;resolveReady(true)}},release(){
    if(released)return;released=true;clearTimeout(timer);holds.delete(hold);resolveReady(false);if(!holds.size)for(const item of waiting)armAdmission(item);pump();
   }};
   if(!holds.size)for(const item of waiting)pauseAdmission(item);holds.add(hold);hold.notify();timer=setTimeout(hold.release,90000);
   return {ready:promise,release:hold.release};
  }
  function releaseReadHolds(){for(const hold of [...holds])hold.release();}
  // END COLLECTION READ HOLD
  const priority=name=>window.parent?.LTSV384ReadPriority?.forRoute(name,typeof V==='undefined'?null:V)??(/income_review_queue_|card_review_queue_|expense_review_queue_|expense_detail_|expense_composition_|card_detail_/.test(name)?0:/card_cycles_|flow_v/.test(name)?1:/recurring_future_gap_/.test(name)?3:2);
  function pump(){
   pumpTimer=null;if(!active)for(const hold of holds)hold.notify();
   if(active||holds.size||!waiting.length)return;
   waiting.sort((a,b)=>priority(a.name)-priority(b.name)||a.order-b.order);
   const next=waiting.shift();clearTimeout(next.timer);next.signal.removeEventListener('abort',next.cancel);active=true;
   let released=false;next.resolve(()=>{if(released)return;released=true;active=false;pump();});
  }
  function admit(name,signal){
   if(!heavy.test(name))return Promise.resolve(()=>{});
   return new Promise((resolve,reject)=>{
    const item={resolve,name,order:order++,signal,remaining:60000,armedAt:0,timer:null,cancel:()=>{clearTimeout(item.timer);signal.removeEventListener('abort',item.cancel);const i=waiting.indexOf(item);if(i>=0)waiting.splice(i,1);reject(new DOMException('Aborted','AbortError'));}};
    if(signal.aborted){item.cancel();return;}
    signal.addEventListener('abort',item.cancel,{once:true});waiting.push(item);armAdmission(item);
    if(!active&&!pumpTimer)pumpTimer=setTimeout(pump,30);
   });
  }
  const publish=entry=>{events.push(entry);if(events.length>30)events.shift();document.documentElement.setAttribute('data-lts-v227-reads',JSON.stringify(events));
   // A late source change can withdraw the audit snapshot after initial boot.
   // Observe the existing job; never request a job or replay a financial write.
   if(entry.status>=500&&entry.status<=504&&
    (entry.name==='lts_browser_recurring_future_gap_audit_v5'||
     !/^lts_browser_product_/.test(entry.name)&&['57014','55000'].includes(entry.code)))
    window.dispatchEvent(new Event('lts:deferred-read-failed'));
  };
  window.fetch=async function(input,init){
   const url=typeof input==='string'?input:input?.url||'',name=url.split('/').pop();
   if(!url.includes('/rest/v1/rpc/'))return native(input,init);
   if(!readName.test(name)){const mutation=name!=='lts_browser_budget_save_v441'&&name!=='lts_browser_open_finance_refresh_v1'&&/_decision_|_update_|_save_|_apply_|_delete_|_refresh_|_confirm_|_upload_|_mutate_|_classify_|_classification_|_create_/.test(name);if(mutation)invalidate(false);const response=await native(input,init);if(mutation&&response.ok)invalidate();return response}
   const headers=new Headers(init?.headers||input?.headers),key=name+'|'+headers.get('Authorization')+'|'+String(init?.body||'');
   const cacheable=name!=='lts_browser_budget_read_v441'&&name!=='lts_browser_product_refresh_status_v415'&&!/open_finance_status_/.test(name);
   const saved=cacheable?completed.get(key):null;if(saved&&performance.now()-saved.at<ttl)return saved.response.clone();
   const generation=revision;
   if(pending.has(key))return (await pending.get(key)).clone();
   const controller=new AbortController(),signal=init?.signal||input?.signal;
   let cancellation=null;const cancel=reason=>{cancellation=typeof reason==='string'?reason:'cancelled';controller.abort()};
   const read={cancel};reads.add(read);
   if(signal?.aborted)cancel();else signal?.addEventListener('abort',cancel,{once:true});
   const queued=performance.now();let started=queued,admitted=false,timer,release=()=>{};
   const job=(async()=>{
    try{release=await admit(name,controller.signal);started=performance.now();admitted=true;init?.ltsOnReadStart?.();timer=setTimeout(()=>cancel('timeout'),readBudget(name));const response=await native(input,{...init,signal:controller.signal});
     // Buffer before resolving so both headers and the response body are bounded.
     const body=await response.arrayBuffer();
     // Only an allowlisted transient SQL code crosses into private diagnostics.
     // The existing bounded controller rechecks the current job; no new job,
     // broad server-error retry or mutation replay is introduced.
     let code; if(response.status>=500&&response.status<=504){try{const value=JSON.parse(new TextDecoder().decode(body));if(['57014','55000'].includes(value?.code))code=value.code;}catch{}}
     publish({name,status:response.status,...(code?{code}:{}),duration_ms:Math.round(performance.now()-started),queued_ms:Math.round(started-queued)});
     const buffered=new Response(body,{status:response.status,statusText:response.statusText,headers:response.headers});
     if(cacheable&&response.ok&&generation===revision){completed.set(key,{at:performance.now(),response:buffered.clone()});if(completed.size>24)completed.delete(completed.keys().next().value)}
     return buffered;
    }catch(error){publish({name,status:cancellation||(!admitted&&error?.name==='AbortError'?'admission_timeout':'network_error'),duration_ms:admitted?Math.round(performance.now()-started):0,queued_ms:Math.round((admitted?started:performance.now())-queued)});throw error;}
    finally{reads.delete(read);clearTimeout(timer);signal?.removeEventListener('abort',cancel);release();}
   })();
   pending.set(key,job);
   try{return (await job).clone();}finally{if(pending.get(key)===job)pending.delete(key);}
  };
  window.__LTS_V227_TRANSPORT={installed:true,invalidate,holdHeavyReads,get revision(){return revision}};
  if(typeof S!=='undefined')S.auth.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT'||event==='SIGNED_IN'){invalidate();releaseReadHolds();if(typeof FLOWQ!=='undefined')FLOWQ=null}});
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!d?.head||!String(w.location.pathname).endsWith('/index.html'))return false;if(!w.__LTS_V227_TRANSPORT){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);}return !!w.__LTS_V227_TRANSPORT;}catch{return false}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,50);}shell?.addEventListener('load',()=>{tries=0;start();});start();
})();
