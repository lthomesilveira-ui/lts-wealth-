/* Select read order only. Admission, authentication, cache and queries stay with the transport. */
(function(root,factory){
 'use strict';const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 else root.LTSV384ReadPriority=api;
})(typeof window==='undefined'?globalThis:window,function(){
 'use strict';
 const legacy=name=>/income_review_queue_|card_review_queue_|expense_review_queue_|expense_detail_|expense_composition_|card_detail_/.test(name)?0:/card_cycles_|flow_v/.test(name)?1:/recurring_future_gap_/.test(name)?3:2;
 function forRoute(name,route){
  if(route!=='Dashboard')return legacy(name);
  if(/dashboard_cockpit_/.test(name))return -2;
  if(/card_cycles_|flow_v|monthly_|wealth_detail_|awards_|expenses_/.test(name))return -1;
  if(/income_review_queue_|card_review_queue_|expense_review_queue_/.test(name))return 4;
  return legacy(name);
 }
 return Object.freeze({forRoute});
});

;
;
/* LTS V384: lts-v339-component-boot.js */
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

;
;
/* LTS V384: lts-v227-read-transport.js */
/* Read-only transport: one in-flight request per authenticated query, bounded waits.
   Writes are never cached, replayed, or remapped here. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V227_TRANSPORT)return;
  const native=window.fetch.bind(window),pending=new Map(),completed=new Map(),events=[];let revision=0;const invalidate=(notify=true)=>{revision++;completed.clear();pending.clear();if(notify)window.dispatchEvent(new Event('lts:data-invalidated'))};const ttl=60000;
  const readName=/^lts_browser_(?:product_|dashboard_cockpit_|cash_today_|income_review_queue_|card_review_queue_|expenses_|expense_executive_|expense_context_|expense_review_queue_|expense_detail_|expense_composition_|wealth_detail_|awards_|planning_ui_|flow_v|monthly_|card_cycles_|card_history_|card_detail_|card_flow_schedule_|open_finance_status_|open_finance_pending_|recurring_future_gap_)/;
  // The production database has a shared execution budget. Admit one expensive
  // read at a time across screen owners, including classification queues and
  // wealth/award readers that perform the same guarded card preparation.
  // Cash and connection status remain independent; no timeout is enlarged.
  const heavy=/^lts_browser_(?:product_|dashboard_cockpit_|wealth_detail_|awards_|income_review_queue_|card_review_queue_|expenses_|expense_executive_|expense_context_|expense_review_queue_|expense_detail_|expense_composition_|planning_ui_|flow_v|monthly_|card_cycles_|card_history_|card_detail_|card_flow_schedule_|open_finance_pending_|recurring_future_gap_)/;
  // The complete flow reader has a 45-second database ceiling. Do not cancel
  // valid cold/year reads at the generic 25-second transport deadline.
  const readBudget=name=>/^lts_browser_flow_v/.test(name)?48000:25000;
  const waiting=[],holds=new Set();let active=false,pumpTimer=null,order=0;
  // BEGIN COLLECTION READ HOLD
  // A collection starts after the admitted reader finishes. Other expensive
  // reads wait until collection ends; cash/status and writes stay independent.
  function holdHeavyReads(){
   let resolveReady,released=false,ready=false,timer;
   const promise=new Promise(resolve=>resolveReady=resolve);
   const hold={notify(){if(!active&&!released&&!ready){ready=true;resolveReady(true)}},release(){
    if(released)return;released=true;clearTimeout(timer);holds.delete(hold);resolveReady(false);pump();
   }};
   holds.add(hold);hold.notify();timer=setTimeout(hold.release,90000);
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
    const item={resolve,name,order:order++,signal,cancel:()=>{clearTimeout(item.timer);signal.removeEventListener('abort',item.cancel);const i=waiting.indexOf(item);if(i>=0)waiting.splice(i,1);reject(new DOMException('Aborted','AbortError'));}};
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
  window.__LTS_V227_TRANSPORT={installed:true,invalidate,holdHeavyReads,get revision(){return revision}};
  if(typeof S!=='undefined')S.auth.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT'||event==='SIGNED_IN'){invalidate();releaseReadHolds();if(typeof FLOWQ!=='undefined')FLOWQ=null}});
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!d?.head||!String(w.location.pathname).endsWith('/index.html'))return false;if(!w.__LTS_V227_TRANSPORT){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);}return !!w.__LTS_V227_TRANSPORT;}catch{return false}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,50);}shell?.addEventListener('load',()=>{tries=0;start();});start();
})();

;
;
/* LTS V384: lts-history-coverage-policy.js */
/* Shared, read-only coverage policy. Contains no private balances or transactions. */
(function(root,factory){
  const policy=factory();
  if(typeof module==='object'&&module.exports)module.exports=policy;
  else root.LTSHistoryCoverage=policy;
})(typeof window==='undefined'?this:window,function(){
  'use strict';
  const expenseFrom='2013-10-10',operationalFrom='2026-07-08';
  function iso(value){
    if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(value))return null;
    const date=new Date(value+'T12:00:00Z');
    return Number.isFinite(date.getTime())&&date.toISOString().slice(0,10)===value?value:null;
  }
  const br=value=>value.split('-').reverse().join('/');
  // A documentary opening or a successful arithmetic check is not reconciliation.
  // Only a source-compared, contiguous interval can certify historical balances.
  function verifiedRange(contract,account){
    const item=contract?.reconciled_intervals?.[account];
    if(!item||item.status!=='source_reconciled'||item.contiguous!==true||
      item.movements_compared!==true||item.balances_compared!==true||
      typeof item.evidence_ref!=='string'||!item.evidence_ref.trim())return null;
    const from=iso(item.from),through=iso(item.through);
    if(!from||!through||from>through||through>=operationalFrom)return null;
    return {from,through};
  }
  function dayStatus(day,account,contract){
    const date=iso(day);
    if(!date)return 'unavailable';
    if(date>=operationalFrom)return 'operational';
    const range=verifiedRange(contract,account);
    return range&&date>=range.from&&date<=range.through?'reconciled':'uncertified';
  }
  function flowMessage(account,contract){
    const range=verifiedRange(contract,account);
    const history=range?'Fluxo conciliado de '+br(range.from)+' a '+br(range.through)+'.':
      'Fluxo histórico: início conciliado ainda não estabelecido.';
    return history+' Despesas preservadas desde 2013, independentemente da conciliação dos saldos. Operação LTS preservada a partir de 08/07/2026.';
  }
  function canReplaceWithHistoricalSource(day){
    const date=iso(day);
    return Boolean(date&&date<operationalFrom);
  }
  return Object.freeze({expenseFrom,operationalFrom,verifiedRange,dayStatus,flowMessage,
    canReplaceWithHistoricalSource,
    expenseMessage:'Despesas desde 2013. A cobertura das despesas é independente dos saldos conciliados no Fluxo; resultado do período não é saldo bancário.',
    uncertifiedMessage:'Saldo histórico não conciliado. Entradas e saídas permanecem disponíveis; este saldo não entra nos totais.'});
});

;
;
/* LTS V384: lts-v268-read-tools.js */
/* Read-only period states and explicit clipboard export. No financial writer. */
(function(root,factory){
 'use strict';
 const tools=factory();
 if(typeof module==='object'&&module.exports){module.exports=tools;return;}
 root.LTSV268ReadTools=tools;
 const shell=document.getElementById('shell');
 function install(){
  try{
   const w=shell?.contentWindow,d=shell?.contentDocument;
   if(!w?.__LTS_V226?.installed||!d?.getElementById('app'))return false;
   if(w.__LTS_V268_READ_TOOLS?.installed)return true;
   const runtime=function(){
    const tools=window.parent.LTSV268ReadTools;
    let copying=false;
    function snapshot(){
     return tools.consolidatedTsv({from:FLOWFROM,to:FLOWTO,loading:FLOWLOADING,error:FLOWQ?.error,
      days:typeof mergedFlowDays==='function'?mergedFlowDays():[],events:typeof mergedFlowEvents==='function'?mergedFlowEvents():[],
      contract:FLOWQ?.historical_balance_truth_contract,policy:window.parent.LTSHistoryCoverage});
    }
    function bind(){
     if(V!=='Fluxo Diário')return;
     const anchor=document.getElementById('flowCloseDetails');if(!anchor)return;
     let button=document.getElementById('flowCopyConsolidated');
     if(!button){button=document.createElement('button');button.id='flowCopyConsolidated';button.type='button';button.className='chip';button.textContent='Copiar Consolidado';button.title='Copiar todos os dias do período carregado, inclusive dias sem movimento. O banco e os filtros não mudam.';anchor.after(button);}
     button.disabled=copying||FLOWLOADING||!FLOWQ||!!FLOWQ.error;
     button.onclick=async()=>{
      if(copying)return;
      const result=snapshot();
      let notice=document.getElementById('flowCopyStatus');
      if(!notice){notice=document.createElement('span');notice.id='flowCopyStatus';notice.className='mut';notice.setAttribute('role','status');notice.setAttribute('aria-live','polite');button.after(notice);}
      if(!result.ok){notice.textContent=result.message;return;}
      copying=true;button.disabled=true;
      try{
       if(navigator.clipboard?.writeText)await navigator.clipboard.writeText(result.text);
       else{
        const previousFocus=document.activeElement,area=document.createElement('textarea');
        area.value=result.text;area.style.cssText='position:fixed;left:-10000px;top:0';document.body.appendChild(area);area.select();
        let copied;try{copied=document.execCommand('copy');}finally{area.remove();previousFocus?.focus?.({preventScroll:true});}
        if(!copied)throw new Error('clipboard unavailable');
       }
       if(notice.isConnected)notice.textContent=result.rows+' dia(s) do Consolidado copiado(s). Saldos sem comprovação estão identificados.';
      }catch{
       if(notice.isConnected)notice.textContent='Não foi possível copiar. Autorize a área de transferência e tente novamente.';
      }finally{copying=false;if(button.isConnected)button.disabled=FLOWLOADING||!FLOWQ||!!FLOWQ.error;}
     };
    }
    const previous=render;render=function(){const result=previous.apply(this,arguments);bind();return result;};
    const style=document.createElement('style');style.textContent='.v268-period[data-period-state="awaiting"],.v268-period[data-period-state="gap"]{border-color:#c4a167}.v268-period[data-period-state="actual"]{border-color:#8cae9d}.v268-period[data-period-state="forecast"]{border-color:#a5b4c6}.v268-period{white-space:normal;max-width:100%;font-size:11px}#flowCopyStatus{max-width:340px;overflow-wrap:anywhere}';document.head.appendChild(style);
    window.__LTS_V268_READ_TOOLS={installed:true,financial_data_changed:false,export_scope:'consolidated-full-loaded-period',snapshot};bind();
   };
   const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);
   return !!w.__LTS_V268_READ_TOOLS?.installed;
  }catch{return false;}
 }
 let tries=0;const timer=setInterval(()=>{if(install()||++tries>200)clearInterval(timer);},100);
 shell?.addEventListener('load',install);
})(typeof window==='undefined'?globalThis:window,function(){
 'use strict';
 function periodState(p){
  if(p?.status==='awaiting_payment_evidence')return 'awaiting';
  if(p?.status==='review')return 'gap';
  if(Number(p?.actual_events)>0)return 'actual';
  if(Number(p?.future_events)>0)return 'forecast';
  if(p?.status==='no_payment_due')return 'no_payment';
  return 'unknown';
 }
 const number=v=>v===null||v===undefined||v===''||!Number.isFinite(Number(v))?null:Number(v);
 function validDate(v){if(!/^\d{4}-\d{2}-\d{2}$/.test(v||''))return false;const d=new Date(v+'T12:00:00Z');return Number.isFinite(d.getTime())&&d.toISOString().slice(0,10)===v;}
 const cell=v=>v==null?'Não comprovado':Number(v).toFixed(2).replace('.',',');
 function isNonCashAwardEvent(e){
  const src=String(e?.source||'').toLowerCase(),cat=String(e?.category||'').toLowerCase(),acct=String(e?.account||'').toLowerCase();
  return /^future_(rsu|cash_rsu)_available$/.test(src)||src==='future_award_vesting_marker'||(src.startsWith('future_')&&acct==='corretora'&&/(rsu|cash rsu)/.test(cat));
 }
 function consolidatedTsv(input){
  const {from,to,days,events,contract,policy}=input;
  if(input.loading)return {ok:false,message:'Aguarde o carregamento completo do período.'};
  if(input.error)return {ok:false,message:'O período não foi carregado. Tente novamente antes de copiar.'};
  if(!validDate(from)||!validDate(to)||from>to||!Array.isArray(days)||!Array.isArray(events))return {ok:false,message:'Selecione e carregue um período válido.'};
  const rows=days.filter(x=>x&&x.date>=from&&x.date<=to).slice().sort((a,b)=>a.date.localeCompare(b.date));
  const expected=Math.round((Date.parse(to+'T12:00:00Z')-Date.parse(from+'T12:00:00Z'))/86400000)+1;
  if(!rows.length||rows.length!==expected||new Set(rows.map(x=>x.date)).size!==expected||rows.some(x=>!validDate(x.date)))return {ok:false,message:'Há dias ausentes no período. Recarregue antes de copiar.'};
  const cash=new Map();
  for(const e of events){if(e.internal_transfer||e.source==='economic_withholding'||isNonCashAwardEvent(e))continue;const date=e.event_date||e.date,n=number(e.signed_amount),tot=cash.get(date)||{entries:0,exits:0,valid:true};if(n==null)tot.valid=false;else if(n>0)tot.entries+=n;else tot.exits-=n;cash.set(date,tot);}
  const text=['Data\tSaldo anterior\tEntradas\tSaídas\tSaldo final\tD+0/1\tSaldo após D+0/1\tRSU vested\tSaldo após RSU\tFGTS\tSaldo após FGTS\tBase do saldo'];
  let invalidArithmetic=false;
  rows.forEach((row,i)=>{
   const c=row.fix86_columns||{},z=row.Consolidado||{},tot=cash.get(row.date)||{entries:0,exits:0,valid:true};
   let opening=number(c.saldo_anterior_operacional??c.saldo_anterior),closing=number(c.saldo_final_operacional??c.saldo_final??z.bank_balance),entries=number(c.entradas??c.entradas_operacionais),exits=number(c.saidas??c.saidas_operacionais);
   let documented=true,basis='Operacional';
   if(row.historical){
    const arithmetic=row.v170_cash_arithmetic?.balanced===true;
    const source=(z.workbook_cash_reconciled===true||z.documentary_reconstruction===true)&&number(z.bank_balance)!=null&&arithmetic;
    const reconciled=policy?.dayStatus(row.date,'Consolidado',contract)==='reconciled';
    documented=!row.relative_balance_display&&z.balance_basis!=='relative_tracked_bank_ledger'&&(source||reconciled);
    basis=documented?(source?'Posição reconstruída de fonte identificada':'Intervalo conciliado'):'Saldo histórico sem comprovação';
    if(documented&&closing!=null&&opening==null){const previous=rows[i-1];opening=number(previous?.fix86_columns?.saldo_final_operacional??previous?.Consolidado?.bank_balance);if(opening==null&&number(z.economic_net??z.net)!=null)opening=closing-number(z.economic_net??z.net);}
    entries=source?number(c.entradas):null;exits=source?number(c.saidas):null;
   }
   if(entries==null)entries=tot.valid?tot.entries:null;if(exits==null)exits=tot.valid?tot.exits:null;
   if(!documented){opening=null;closing=null;}
   if([opening,entries,exits,closing].every(x=>x!==null)&&Math.abs(opening+entries-exits-closing)>0.021)invalidArithmetic=true;
   const values=[opening,entries,exits,closing,number(c.liq_d0_1_recurso),documented?number(c.saldo_apos_d0_1):null,number(c.rsus_vested),documented?number(c.saldo_apos_rsu):null,number(c.fgts),documented?number(c.saldo_apos_fgts):null];
   text.push(row.date+'\t'+values.map(cell).join('\t')+'\t'+basis);
  });
  if(invalidArithmetic)return {ok:false,message:'As entradas e saídas não fecham com os saldos do período. Recarregue o Fluxo antes de copiar.'};
  return {ok:true,text:text.join('\n'),rows:rows.length,from,to};
 }
 return Object.freeze({periodState,consolidatedTsv,isNonCashAwardEvent});
});

;
;
/* LTS V384: lts-v183-core-loading-guard.js */
/* Candidate-only guard for a restored Flow route before the authenticated product arrives. */
(function(){
  'use strict';
  const shell=document.getElementById('shell');
  function install(){
    try{
      const w=shell?.contentWindow,d=shell?.contentDocument;
      if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html')||typeof w.fluxo!=='function')return false;
      if(w.__LTS_V183_CORE_LOADING_GUARD?.installed)return true;
      if(d.getElementById('v183-core-loading-guard'))return false;
      const runtime=function(){
        if(window.__LTS_V183_CORE_LOADING_GUARD?.installed)return;
        const original=fluxo;
        fluxo=function(){
          if(typeof D==='undefined'||!D)return '<div class="notice" role="status">Preparando o Fluxo Diário…</div>';
          return original();
        };
        // The base renderer binds Flow controls after calling fluxo(). A
        // placeholder alone still raises when those controls do not exist.
        const originalRender=render;
        render=function(){
          if(V==='Fluxo Diário'&&(typeof D==='undefined'||!D)){
            A.innerHTML='<div class="notice" role="status">Preparando o Fluxo Diário…</div>';
            return;
          }
          return originalRender();
        };
        window.__LTS_V183_CORE_LOADING_GUARD={installed:true,financial_data_changed:false};
      };
      const script=d.createElement('script');script.id='v183-core-loading-guard';script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);
      return !!w.__LTS_V183_CORE_LOADING_GUARD?.installed;
    }catch{return false}
  }
  let tries=0;const timer=setInterval(()=>{if(install()||++tries>120)clearInterval(timer)},100);
  shell?.addEventListener('load',()=>{tries=0;if(!install())setTimeout(install,150)});
 window.LTSV339Boot?.watch('lts-v183-core-loading-guard.js',install);
})();

;
;
/* LTS V384: wip35-v162-flow-recovery.js */
(function(){
  'use strict';
  const CONTRACT='v150-flow-direct-current-read-v3';
  const TARGET_RPC='lts_browser_flow_v242';
  const TARGET_MUTATION_RPC='lts_browser_flow_mutate_v2';
  const SESSION_KEY='lts_supabase_session_v1';
  const outer=document.getElementById('shell');
  const gate=document.getElementById('gate');
  let bootGeneration=0;
  function recoveryRuntime(){
    'use strict';
    const CONTRACT='v150-flow-direct-current-read-v3';
    const TARGET_RPC='lts_browser_flow_v242';
    const TARGET_MUTATION_RPC='lts_browser_flow_mutate_v2';
    if(window.__LTS_V162_FLOW_RECOVERY_STATUS?.installed===true)return;
    const calls=[];
    const status=window.__LTS_V162_FLOW_RECOVERY_STATUS={installed:true,contract:CONTRACT,baseline:'Protected index V150 Flow component',route:null,data_rpc:TARGET_RPC,legacy_flow_reads_mapped:true,public_index_changed:false,mutation_rpc:TARGET_MUTATION_RPC,financial_writer_changed:false,dashboard_in_scope:false,bounded_boot:true,permanent_polling:false,refresh_requested:false,last_flow_done:false,last_flow_ok:false,last_flow_error:null,calls};
    const baseRpc=S.rpc.bind(S);
    async function mappedRpc(name,args){
      const requested=String(name||'');
      const mapped=(requested==='lts_browser_flow_v3'||requested==='lts_browser_flow_v4')?TARGET_RPC:requested==='lts_browser_flow_mutate_v1'?TARGET_MUTATION_RPC:requested==='lts_browser_wealth_detail_v4'?'lts_browser_wealth_detail_v242':requested==='lts_browser_cash_today_v178'?'lts_browser_cash_today_v242':requested;
      calls.push({requested,mapped,at:new Date().toISOString()});if(calls.length>40)calls.shift();
      try{
        const result=await baseRpc(mapped,args);
        if(mapped===TARGET_RPC){status.last_flow_rpc=mapped;status.last_flow_done=true;status.last_flow_ok=!result?.error&&!!result?.data?.flow;status.last_flow_error=result?.error?.message||(!result?.data?.flow?'Resposta do Fluxo sem dados':null);status.last_flow_at=new Date().toISOString()}
        return result;
      }catch(error){
        if(mapped===TARGET_RPC){status.last_flow_rpc=mapped;status.last_flow_done=true;status.last_flow_ok=false;status.last_flow_error=String(error?.message||error||'Falha de leitura');status.last_flow_at=new Date().toISOString()}
        throw error;
      }
    }
    mappedRpc.__ltsV162FlowBridge=true;S.rpc=mappedRpc;
    const DEFAULT_RANGE_CONTRACT='previous-5-today-next-30-v1';
    const DEFAULT_RANGE_LABEL='5 anteriores + 30 próximos';
    let flowRequestSequence=0,lastRenderedRoute=V;
    status.default_range_contract=DEFAULT_RANGE_CONTRACT;status.default_range_applied=false;
    function defaultRange(){const day=today();const shift=offset=>{const date=new Date(day+'T12:00:00Z');date.setUTCDate(date.getUTCDate()+offset);return date.toISOString().slice(0,10)};return {from:shift(-5),to:shift(30)}}
    function useDefaultState(){const range=defaultRange();FLOWPRESET=DEFAULT_RANGE_LABEL;SHOWZERO=false;FLOWFORCEZERO=false;FLOWYEAR=Number(today().slice(0,4));status.default_range_applied=true;status.default_range=range;return range}
    loadFlowRange=async function(from,to){
      if(!window.__LTS_V178_REVIEW?.installed)return; // Final screen owner starts the first read.
      if(!status.default_range_applied){const range=useDefaultState();from=range.from;to=range.to}
      const valid=value=>/^\d{4}-\d{2}-\d{2}$/.test(String(value||''));if(!valid(from)||!valid(to)||from>to)return;
      const sequence=++flowRequestSequence;FLOWLOADING=true;FLOWFROM=from;FLOWTO=to;status.refresh_requested=true;status.last_flow_done=false;status.last_flow_ok=false;status.requested_range={from,to};if(V==='Fluxo Diário')render();
      try{
        const {data,error}=await S.rpc('lts_browser_flow_v3',{p_from:from,p_to:to});if(sequence!==flowRequestSequence)return;
        if(error||!data?.flow)throw new Error(error?.message||'Resposta do Fluxo sem dados');
        FLOWQ=data.flow;status.last_flow_ok=true;status.last_flow_error=null;status.loaded_range={from,to};
      }catch(error){if(sequence!==flowRequestSequence)return;status.last_flow_ok=false;status.last_flow_error=String(error?.message||error||'Falha de leitura');FLOWQ={error:'Não foi possível carregar este período. Tente novamente.',historical:{days:[],events:[]},current_future:{days:[],events:[]}}}
      finally{if(sequence===flowRequestSequence){FLOWLOADING=false;status.last_flow_done=true;if(V==='Fluxo Diário')render()}}
    };
    function openDefaultRange(){const range=useDefaultState();return loadFlowRange(range.from,range.to)}
    function bindDefaultRange(){
      if(V!=='Fluxo Diário')return;
      const first=document.querySelector('[data-p]');
      if(first&&!document.getElementById('flowDefaultRange')){const button=document.createElement('button');button.id='flowDefaultRange';button.type='button';button.className='chip';button.textContent=DEFAULT_RANGE_LABEL;button.title='Cinco dias anteriores, hoje e os próximos 30 dias';first.parentNode.insertBefore(button,first)}
      const button=document.getElementById('flowDefaultRange');if(button){const range=defaultRange(),active=FLOWFROM===range.from&&FLOWTO===range.to;button.classList.toggle('active',active);button.setAttribute('aria-pressed',String(active));button.onclick=openDefaultRange}
      document.querySelectorAll('[data-p="Hoje"]').forEach(node=>node.remove());const go=document.getElementById('goToday');if(go)go.onclick=()=>openDefaultRange();
    }
    const preservedRender=render;
    render=function(){const entered=V==='Fluxo Diário'&&lastRenderedRoute!=='Fluxo Diário';lastRenderedRoute=V;preservedRender();bindDefaultRange();if(entered&&D&&status.default_range_applied){queueMicrotask(()=>{if(V==='Fluxo Diário')openDefaultRange()})}};
    const preservedRenderNav=renderNav;
    renderNav=function(){preservedRenderNav();const button=document.querySelector('.nav [data-v="Fluxo Diário"]');if(button)button.onclick=()=>{V='Fluxo Diário';lastRenderedRoute=V;renderNav();render();openDefaultRange()}};
    renderNav();bindDefaultRange();
    status.invoice_contract='all-cards-aeternum-summary-source-v1';
    const previousCardPredicate=isCardSettlement;
    isCardSettlement=function(event){const name=String(event.description||event.description_raw||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();return num(event.signed_amount)<0&&(event.source==='card_invoice'||/fatura|personnalite|pers black|gastos cartao de credito/.test(name)||previousCardPredicate(event))};
    let invoiceSequence=0;
    openCardSettlement=async function(event){
      const sequence=++invoiceSequence;EXP.add(event.event_date);CARDDETAILFULL=false;CARDDETAILLOADING=true;CARDDETAIL={event};render();focusCardDetail(event.event_date);
      try{const {data,error}=await S.rpc('lts_browser_card_settlement_detail_v2',{p_event_date:event.event_date,p_description:event.description||event.description_raw||'',p_amount:Math.abs(num(event.signed_amount)),p_account:event.account||null});if(sequence!==invoiceSequence)return;if(error)throw error;CARDDETAIL={event,...(data||{})}}
      catch(error){if(sequence!==invoiceSequence)return;CARDDETAIL={event,error:'Não foi possível consultar o detalhe. Feche e abra a fatura para tentar novamente.'}}
      finally{if(sequence===invoiceSequence){CARDDETAILLOADING=false;render();focusCardDetail(event.event_date)}}
    };
    cardSettlementDrawer=function(){
      if(!CARDDETAIL)return '';
      const detail=CARDDETAIL,event=detail.event||{},purchases=detail.purchases||[];
      const title=detail.card_name||event.description||'Cartão não identificado';
      const close='<button id="closeCardDetail" class="btn ghost" type="button">Fechar</button>';
      const head=(full=false)=>`<div class="invoice-head"><div><b>${full?'Fatura completa':'Resumo da fatura'}</b><div class="mut">${esc(title)}</div></div><div class="chips">${full?'<button id="backCardSummary" class="chip" type="button">Voltar ao resumo</button>':''}${close}</div></div>`;
      const shell=body=>`<section class="invoice-inline fx89-invoice lts-invoice-unified ${CARDDETAILFULL?'':'fx89-invoice-compact'}" data-invoice-contract="all-cards-aeternum-summary-source-v1" aria-label="Resumo da fatura">${body}</section>`;
      if(CARDDETAILLOADING)return shell(head()+'<div class="notice" role="status">Carregando compras da fatura…</div>');
      if(detail.error)return shell(head()+`<div class="notice" role="alert">${esc(detail.error)}</div>`);
      if(!detail.matched)return shell(head()+`<div class="fx89-metric"><span>Valor no Fluxo</span><b>${brl(Math.abs(num(event.signed_amount)))}</b><small>${esc(event.account||'')} · caixa ${fmt(event.event_date)}</small></div><div class="notice">Sem fatura documental vinculada com segurança a este banco, cartão e competência. Não há compras a exibir. Um valor igual em outro mês não confirma este vínculo.</div>`);
      const state=detail.open_cycle?'Em aberto':detail.projected_cycle?'Projeção':detail.payment_documented?'Pagamento documentado':detail.historical_only?'Registro histórico':'Fechada · pagamento não confirmado';
      const lines=Array.isArray(purchases)?purchases:[];
      const grouped=new Map();let pendingCharges=0,pendingCredits=0,chargeCount=0,creditCount=0;
      lines.forEach(item=>{const category=item.category||'A classificar',amount=num(item.amount);grouped.set(category,(grouped.get(category)||0)+amount);if(['a classificar','—',''].includes(String(category).toLowerCase().trim())){if(amount<0){pendingCredits+=Math.abs(amount);creditCount++}else{pendingCharges+=amount;chargeCount++}}});
      const categories=[...grouped].map(([category,total])=>({category,total})).sort((a,b)=>b.total-a.total||a.category.localeCompare(b.category,'pt-BR'));
      const net=lines.reduce((value,item)=>value+num(item.amount),0)-num(detail.invoice_credit);
      const delta=lines.length?num(detail.invoice_total)-net:null;
      const complete=lines.length>0&&Math.abs(delta)<0.005;
      const dates=`<div class="lts-invoice-dates"><span class="status at">${esc(state)}</span><span>Vencimento ${fmt(detail.due_date)}</span><span>Caixa ${fmt(detail.cash_event_date||event.event_date)}</span>${detail.evidence_as_of?`<span>Posição ${fmt(detail.evidence_as_of)}</span>`:''}</div>`;
      const categoryHtml=categories.map(category=>`<div class="fx89-cat ${category.category==='A classificar'?'pending':''}" data-category-total="${category.total}"><span>${esc(category.category)}</span><b>${brl(category.total)}</b></div>`).join('');
      const pending=chargeCount||creditCount?`<div class="fx89-class-alert"><b>Classificação pendente</b>${chargeCount?`<span>${chargeCount} lançamento(s) de despesa · ${brl(pendingCharges)}</span>`:''}${creditCount?`<span class="lts-pending-credit">${creditCount} crédito(s)/estorno(s) · ${brl(pendingCredits)}. Não é uma nova despesa.</span>`:''}<button id="goCardClassification" class="chip" type="button">Revisar classificação</button></div>`:lines.length?'<div class="fx89-class-ok">Itens documentados classificados.</div>':'';
      const check=complete?'Detalhe confere com o total':lines.length?'Detalhe parcial · diferença a conferir':'Detalhe não documentado';
      const metric=`<div class="fx89-metric"><span>${detail.open_cycle?'Total da posição aberta':'Total da fatura'}</span><b>${brl(detail.invoice_total)}</b><small>${lines.length} lançamento(s) · ${check}${delta!==null?' · diferença '+brl(delta):''}</small>${detail.open_cycle?'<small>A fatura ainda pode crescer; não indica pagamento.</small>':''}</div>`;
      const guard='<div class="notice lts-invoice-guard">Pagamento da fatura explica o caixa; compras explicam consumo e não são somadas novamente. Datas, finais e parcelas são apresentados somente quando documentados.</div>';
      if(!CARDDETAILFULL)return shell(head()+dates+`<div class="fx89-invoice-body"><div><div class="fx89-invoice-title">Por categoria</div><div class="mut">Valores líquidos, do maior para o menor.</div><div class="fx89-catgrid">${categoryHtml||'<div class="empty">Sem detalhe documental para agrupar.</div>'}</div>${num(detail.invoice_credit)?`<div class="fx89-cat"><span>Créditos da fatura fora das compras</span><b>− ${brl(detail.invoice_credit)}</b></div>`:''}</div><div class="fx89-invoice-side">${metric}${pending}${lines.length?'<button id="openCardFull" class="btn ghost" type="button">Acessar fatura completa</button>':''}</div></div>`+guard);
      const items=lines.map(item=>{const date=item.purchase_date?fmt(item.purchase_date):item.date_printed?String(item.date_printed)+' · ano não informado':'Data não informada';const installment=item.installment_label||(item.installment_number&&item.installments?item.installment_number+'/'+item.installments:null);return `<div class="expense-tx lts-source-line" data-source-row="${esc(item.row_id||'')}"><div class="expense-main"><b>${esc(item.description)}</b><span>${esc(date)}${item.card_final?' · final '+esc(item.card_final):''}${item.holder?' · '+esc(item.holder):''}</span><div class="expense-meta"><i class="tag">${esc(item.category||'A classificar')}</i>${installment?`<i class="tag">Parcela ${esc(installment)}</i>`:''}${num(item.amount)<0?'<i class="tag">Crédito / estorno</i>':''}${item.source_page?`<i class="tag">Página ${esc(item.source_page)}</i>`:''}</div></div><b class="expense-val ${num(item.amount)<0?'pos':'neg'}">${num(item.amount)<0?'− ':''}${brl(Math.abs(num(item.amount)))}</b></div>`}).join('');
      return shell(head(true)+dates+`<div class="lts-invoice-metrics">${metric}<div class="fx89-metric"><span>Créditos não incluídos nas linhas</span><b>${brl(detail.invoice_credit)}</b><small>${check}</small></div></div><div class="invoice-grid"><div class="card"><div class="title">Por categoria</div>${categoryHtml}${pending}</div><div class="card"><div class="title">Compras e créditos da fatura</div>${items||'<div class="empty">Sem linhas documentadas.</div>'}</div></div>`+guard);
    };
    // The preserved Flow calls the inline entrypoint, not the standalone drawer.
    cardSettlementInline=function(day){return CARDDETAIL?.event?.event_date===day?cardSettlementDrawer():''};
    const invoiceStyle=document.createElement('style');invoiceStyle.id='lts-integrated-invoices-style';
    invoiceStyle.textContent=`
      .lts-invoice-unified{box-sizing:border-box!important;width:100%!important;min-width:0!important;margin-left:0!important}
      .lts-invoice-unified .invoice-grid{grid-template-columns:minmax(200px,30%) minmax(0,1fr)!important}
      .lts-invoice-unified .card,.lts-invoice-unified .expense-main{min-width:0;overflow-wrap:anywhere}
      .lts-invoice-unified .expense-val{white-space:nowrap;flex-shrink:0}
      .lts-invoice-dates{display:flex;flex-wrap:wrap;gap:8px 14px;font-size:11px;margin:8px 0 14px;color:var(--mut)}
      .lts-invoice-metrics{display:grid;grid-template-columns:1fr 1fr;gap:12px}
      .lts-invoice-unified .fx89-class-alert>span{display:block;margin:6px 0}
      .lts-invoice-unified .fx89-catgrid{margin-top:10px}
      .lts-invoice-guard{margin-top:14px;font-size:11px}
      .lts-reconciliation-warning{margin:12px 0;font-size:12px}
      @media(max-width:820px){.lts-invoice-unified .invoice-grid,.lts-invoice-metrics{grid-template-columns:1fr!important}.lts-invoice-unified .invoice-head{flex-wrap:wrap}.lts-invoice-unified .fx89-invoice-body{display:grid;grid-template-columns:1fr}.lts-invoice-unified button{min-height:36px}.lts-invoice-unified .expense-tx{display:flex;gap:10px}.lts-invoice-unified .expense-main{flex:1}.lts-invoice-unified{padding:12px!important}}
    `;document.head.appendChild(invoiceStyle);
    function reconciliationNoticeEligible(day,bank,value){
      const account=day?.[bank]||{};
      return Math.abs(num(value))>.005&&
        (ACC==='Consolidado'||ACC===bank)&&
        String(account.documentary_anchor_date||'')===String(day?.date||'')&&
        String(account.balance_basis||'')==='documentary_close';
    }
    window.__LTS_RECONCILIATION_NOTICE_ELIGIBLE=reconciliationNoticeEligible;
    function addReconciliationNotice(){
      if(V!=='Fluxo Diário'||!FLOWQ)return;
      document.getElementById('ltsFgtsScenarioNote')?.remove();
      // Keep source reconciliation metadata for the private audit, never as a product banner.
      document.getElementById('ltsBankEvidence')?.remove();
      document.getElementById('ltsReconciliationWarning')?.remove();
    }
    // Expanded days and invoice requests belong to the selected bank context.
    // Keep the period; never carry an old bank's disclosure into the new bank.
    status.bank_scope_contract='bank-switch-closes-days-and-invoices-v1';
    let renderedBank=ACC,renderedRoute=V;
    function clearInvoiceContext(){
      invoiceSequence+=1; // Any earlier success/error/finally is now obsolete.
      CARDDETAIL=null;CARDDETAILFULL=false;CARDDETAILLOADING=false;
    }
    function bindInvoiceContextControls(){
      const closeAll=document.getElementById('flowCloseDetails');
      if(closeAll)closeAll.onclick=()=>{EXP.clear();clearInvoiceContext();render()};
      const close=document.getElementById('closeCardDetail');
      if(close)close.onclick=()=>{clearInvoiceContext();render()};
      document.querySelectorAll('[data-d]').forEach(button=>{
        const toggle=button.onclick;
        if(typeof toggle!=='function')return;
        button.onclick=function(event){
          if(EXP.has(button.dataset.d)&&CARDDETAIL?.event?.event_date===button.dataset.d){clearInvoiceContext()}
          return toggle.call(this,event);
        };
      });
    }
    const renderWithInvoices=render;
    render=function(){
      const changedBank=ACC!==renderedBank;
      const changedRoute=V!==renderedRoute;
      if(changedBank){EXP.clear();clearInvoiceContext()}
      else if(changedRoute){clearInvoiceContext()}
      // Defensive boundary, also covers an incorrectly scoped retained detail.
      if(V==='Fluxo Diário'&&CARDDETAIL&&ACC!=='Consolidado'&&CARDDETAIL.event?.account!==ACC){clearInvoiceContext()}
      renderedBank=ACC;renderedRoute=V;
      renderWithInvoices();addReconciliationNotice();bindInvoiceContextControls();
      if(changedBank){
        const scroller=document.querySelector('.fx87-scroll')||document.querySelector('.mscroll');
        if(scroller)scroller.scrollTop=0;
      }
    };
    function applyScope(){document.querySelectorAll('.brand small').forEach(node=>{node.textContent='Recuperação do Fluxo Diário'});document.querySelectorAll('.footer').forEach(node=>{node.hidden=true})}
    window.__LTS_V162_ROUTE_FLOW=function(){
      if(!D){applyScope();return {state:document.querySelector('.login')?'login':'waiting',done:false,ok:false}}
      if(status.route!=='Fluxo Diário'){V='Fluxo Diário';renderNav();render();status.route='Fluxo Diário';status.route_applied_at=new Date().toISOString()}
      applyScope();
      // Dashboard is the initial route; binding Flow must not prefetch its default period.
      status.initial_read_deferred=true;
      return {state:'flow',done:status.last_flow_done,ok:status.last_flow_ok,error:status.last_flow_error};
    };
  }
  function currentFrame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!d.documentElement)return null;const path=w.location?.pathname||'';if(!path.endsWith('/index.html'))return null;return {w,d}}catch(error){return null}}
  function showGate(message){if(!gate)return;gate.textContent=message||'Preparando o Fluxo Diário…';gate.hidden=false}
  function hideGate(){if(gate)gate.hidden=true}
  function runtimePrerequisitesReady(frame){return ['render','renderNav','loadFlowRange','isCardSettlement'].every(name=>typeof frame.w[name]==='function')}
  function installRuntime(frame){if(frame.w.__LTS_V162_FLOW_RECOVERY_STATUS?.installed===true)return true;if(!runtimePrerequisitesReady(frame))return false;if(frame.d.getElementById('lts-v162-flow-runtime'))return false;const host=frame.d.head||frame.d.documentElement;if(!host)return false;const script=frame.d.createElement('script');script.id='lts-v162-flow-runtime';script.textContent=`(${recoveryRuntime.toString()})();`;host.appendChild(script);return frame.w.__LTS_V162_FLOW_RECOVERY_STATUS?.installed===true}
  function install(){
    const frame=currentFrame();if(!frame)return false;
    if(!frame.d.getElementById('v162-flow-scope-css')){
      const host=frame.d.head||frame.d.documentElement;if(!host)return false;const style=frame.d.createElement('style');style.id='v162-flow-scope-css';
      style.textContent=`
        .nav [data-v="Dashboard"]{display:none!important}
        .footer{display:none!important}
        @media(max-width:820px){
          .fx87-row.fx87-cons .fx87-cell:nth-child(n+2){display:block!important;padding:8px 7px!important;text-align:right!important;min-height:49px}
          .fx87-row.fx87-cons .fx87-cell:nth-child(n+2)::before{display:block;margin-bottom:4px;color:var(--mut);font-size:8px;font-weight:850;line-height:1.15;text-align:left;text-transform:uppercase;letter-spacing:.025em}
          .fx87-row.fx87-cons .fx87-cell:nth-child(2)::before{content:'Saldo anterior'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(3)::before{content:'Entradas'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(4)::before{content:'Saídas'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(5)::before{content:'Saldo final'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(6)::before{content:'D0/D1'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(7)::before{content:'Saldo c/ D0/D1'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(8)::before{content:'RSU vested'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(9)::before{content:'Saldo c/ RSU'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(10)::before{content:'FGTS restrito'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(11)::before{content:'Saldo total'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(2),.fx87-row.fx87-cons .fx87-cell:nth-child(5),.fx87-row.fx87-cons .fx87-cell:nth-child(7),.fx87-row.fx87-cons .fx87-cell:nth-child(9),.fx87-row.fx87-cons .fx87-cell:nth-child(11){background:#f2f4f6!important;border-radius:8px}
          .fx87-row.fx87-cons .fx87-cell:nth-child(6),.fx87-row.fx87-cons .fx87-cell:nth-child(7){border-top:1px solid #e4e9ef}
          .fx87-date{display:flex!important;min-height:0!important;text-align:left!important}
        }
      `;host.appendChild(style);
    }
    if(!installRuntime(frame))return false;
    const result=frame.w.__LTS_V162_ROUTE_FLOW?.(),status=frame.w.__LTS_V162_FLOW_RECOVERY_STATUS;
    if(result?.state==='login'){hideGate();return true}
    if(status?.refresh_requested&&status?.last_flow_done){hideGate();return true}
    if(result?.state==='flow')showGate('Atualizando o Fluxo Diário…');return result?.state==='flow';
  }
  function burst(){const generation=++bootGeneration;let attempt=0;function step(){if(generation!==bootGeneration)return;install();attempt+=1;if(attempt<360&&gate&&!gate.hidden)setTimeout(step,100)}step();[250,600,1200,2400,4800,8000,12000,18000,24000,30000,36000].forEach(delay=>{setTimeout(()=>{if(generation===bootGeneration)install()},delay)})}
  outer?.addEventListener('load',()=>{showGate('Preparando o Fluxo Diário…');burst()});
  window.addEventListener('storage',event=>{if(event.key===SESSION_KEY){showGate('Atualizando o Fluxo Diário…');burst()}});
  document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();
  window.__LTS_TOP_CANDIDATE_VERSION='v162-flow-recovery';
  window.__LTS_V162_STATUS={contract:CONTRACT,source_candidate:'index.html',flow_baseline:'WIP35-v150 Flow component',data_rpc:TARGET_RPC,dashboard_in_scope:false,public_index_changed:false,bounded_boot:true,permanent_polling:false};
})();

;
;
/* LTS V384: lts-expense-presentation-model.js */
/* Group the same canonical cells; no source classification or financial writes. */
(function(root){
 'use strict';
 const dims=['property','person','center_cost'],number=v=>(typeof v==='number'||typeof v==='string'&&v.trim()!=='')&&Number.isFinite(Number(v));
 function validate(p){
  if(p?.version!=='expense-presentation-v353'||!Array.isArray(p.cells)||!p.summary)throw Error('Apresentação indisponível');
  let gross=0,compensations=0,net=0,rows=0;
  for(const c of p.cells){
   if(!['macrogroup','group_name','category',...dims].every(k=>typeof c[k]==='string')||!['gross','compensations','net'].every(k=>number(c[k]))||!Number.isSafeInteger(c.rows)||c.rows<1||Number(c.gross)<0||Number(c.compensations)<0||Math.abs(Number(c.gross)-Number(c.compensations)-Number(c.net))>.011)throw Error('Composição indisponível');
   gross+=Number(c.gross);compensations+=Number(c.compensations);net+=Number(c.net);rows+=c.rows;
  }
  if(!['gross','compensations','net'].every(k=>number(p.summary[k]))||rows!==p.summary.rows||Math.abs(gross-Number(p.summary.gross))>.011||Math.abs(compensations-Number(p.summary.compensations))>.011||Math.abs(net-Number(p.summary.net))>.011)throw Error('Totais precisam ser atualizados');
  return p;
 }
 function build(input,requested={}){
  const p=validate(input),scope={view:requested.view||'type'};
  if(!['type','property','tax'].includes(scope.view))throw Error('Perspectiva inválida');
  for(const k of dims)if(requested[k])scope[k]=String(requested[k]);
  const cells=p.cells.filter(c=>dims.every(k=>!scope[k]||c[k]===scope[k])&&(scope.view!=='tax'||c.is_tax===true));
  const summary={gross:0,compensations:0,net:0,rows:0},tree=new Map();
  const labels=new Map((p.dimensions?.property||[]).map(x=>[x.key,x.label]));
  const add=(s,c)=>{for(const k of ['gross','compensations','net'])s[k]+=Number(c[k]);s.rows+=c.rows;};
  for(const c of cells){
   add(summary,c);let map=tree,path={...scope};
   const steps=scope.view==='property'?[['property',c.property,labels.get(c.property)||'Bem informado na origem']]:[];
   steps.push(['macrogroup',c.macrogroup,c.macrogroup],['group',c.group_name,c.group_name],['category',c.category,c.category]);
   for(const[k,key,name]of steps){
    path={...path,[k]:key};let n=map.get(key);
    if(!n){n={name,scope:{...path},gross:0,compensations:0,net:0,rows:0,children:new Map()};map.set(key,n)}
    add(n,c);map=n.children;
   }
  }
  const array=map=>[...map.values()].sort((a,b)=>b.net-a.net||a.name.localeCompare(b.name,'pt-BR')).map(n=>({...n,children:array(n.children)}));
  return{version:p.version,period:p.period,scope,summary,nodes:array(tree),dimensions:p.dimensions};
 }
 const api={validate,build};if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.LTSExpensePresentation=api;
})(typeof window==='undefined'?{}:window);

;
;
/* LTS V384: lts-property-reconciliation-model.js */
/* Read-only property comparisons. Source copies corroborate; they never add expenses. */
(function(root){
 'use strict';
 const number=v=>v===null||v===undefined||v===''||!Number.isFinite(Number(v))?null:Number(v);
 const sum=rows=>rows.reduce((n,r)=>n+Number(r.amount),0);
 const same=(a,b)=>number(a)!==null&&number(b)!==null&&Math.round(Number(a)*100)===Math.round(Number(b)*100);
 const definitions=[
  ['acquisition','Aquisição','Patrimônio e financiamentos','Aquisição imobiliária'],
  ['works','Obra e reforma','Moradia','Obra, reforma e equipamentos'],
  ['housing','Moradia','Moradia','Uso e manutenção'],
  ['tax','Tributos','Moradia','Tributos']
 ];
 function build(wealth,packet,range){
  const rows=packet?.rows;
  if(!Array.isArray(rows)||!range?.from||!range?.to||packet.row_count!==rows.length||!same(sum(rows),packet.total))throw Error('Incomplete property list');
  const keys=new Set();
  for(const r of rows){
   if(!r.key||keys.has(r.key)||r.property_code!=='cipo396'||number(r.amount)===null)throw Error('Invalid property identity');
   keys.add(r.key);
  }
  const groups=definitions.map(([id,label,macrogroup,group])=>{
   const scope={property:'cipo396',macrogroup,group,sign:'net'};
   const selected=rows.filter(r=>r.taxonomy?.macrogroup===macrogroup&&r.taxonomy?.group===group),categories=new Map();
   for(const r of selected){
    const name=r.taxonomy?.category;if(!name)throw Error('Missing category');
    if(!categories.has(name))categories.set(name,[]);categories.get(name).push(r);
   }
   return{id,label,scope,total:sum(selected),count:selected.length,rows:selected,categories:[...categories].map(([label,items])=>({label,total:sum(items),count:items.length,scope:{...scope,category:label}})).sort((a,b)=>b.total-a.total)};
  });
  if(groups.reduce((n,g)=>n+g.count,0)!==rows.length)throw Error('Unknown property group');
  const model={total:sum(rows),count:rows.length,range:{...range},scope:{property:'cipo396',sign:'net'},groups,bridge:null};
  const rec=wealth?.wealth?.cipo_reconciliation,audit=rec?.consortium?.itau_source_audit,s=audit?.snapshot_scope;
  if(audit?.status!=='verified_original_signed_rows'||!s?.source_file||!/^\d{4}-\d\d-\d\d$/.test(s.source_paid_cutoff||'')||range.from!=='2013-10-10'||range.to<s.source_paid_cutoff)return model;
  function sourceRows(name){
   const all=s[name];if(!Array.isArray(all))throw Error('Missing source rows');
   const byFile=new Map();
   for(const r of all){
    if(!r.file||!/^[0-9a-f]{64}$/.test(r.sha256||'')||!r.sheet||!Number.isInteger(r.row)||r.row<1||number(r.signed_amount)===null)throw Error('Incomplete source identity');
    if(!byFile.has(r.file))byFile.set(r.file,[]);byFile.get(r.file).push(r);
   }
   const primary=byFile.get(s.source_file);if(!primary||byFile.size<2)throw Error('Uncorroborated source');
   const normalized=items=>items.map(r=>[r.sheet,r.row,r.date||'',r.description||'',Math.round(Number(r.signed_amount)*100)]).sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b)));
   for(const items of byFile.values()){
    if(new Set(items.map(r=>r.sheet+'|'+r.row)).size!==items.length||new Set(items.map(r=>r.sha256)).size!==1||JSON.stringify(normalized(items))!==JSON.stringify(normalized(primary)))throw Error('Conflicting source copies');
   }
   return primary.map(r=>({...r}));
  }
  try{
   const cash=sourceRows('source_cash_rows'),card=sourceRows('source_card_consortium_rows'),unlinked=sourceRows('works_unlinked_source_rows');
   const summaries=s.investment_summary;if(!Array.isArray(summaries)||summaries.length<2)throw Error('Missing summary');
   const source=summaries.find(r=>r.file===s.source_file);if(!source?.cells)throw Error('Missing primary summary');
   for(const other of summaries)for(const key of ['D3','D4','D13','D14','D41','J4','J5','J31'])if(!same(source.cells[key],other.cells?.[key]))throw Error('Conflicting summary');
   const cashTotal=cash.reduce((n,r)=>n+Number(r.signed_amount),0),cardTotal=card.reduce((n,r)=>n+Number(r.signed_amount),0),c=source.cells;
   if(!same(cashTotal,Number(c.D13)+Number(c.D14))||!same(cardTotal,c.D41)||!same(c.J4,cashTotal+cardTotal)||!same(c.J5,Number(c.D3)+Number(c.D4)+Number(c.J4))||!same(c.D3,s.source_loan_paid)||!same(c.D14,rec.consortium.itau_ledger))throw Error('Changed source totals');
   const acq=groups[0],works=groups[1],loan=acq.rows.filter(r=>r.taxonomy.category==='Financiamento Imobiliário');
   const prefix=loan.filter(r=>(r.event_date||r.date)<=s.source_paid_cutoff),tail=loan.filter(r=>(r.event_date||r.date)>s.source_paid_cutoff);
   const cardRows=acq.rows.filter(r=>r.taxonomy.category==='Consórcio');
   if(!same(sum(prefix),c.D3)||!same(sum(cardRows),cardTotal)||!same(sum(acq.rows.filter(r=>!loan.includes(r)&&!cardRows.includes(r))),c.D4))throw Error('Changed acquisition perimeter');
   const expected=Number(c.J5)+sum(tail)-cashTotal;if(!same(expected,acq.total))throw Error('Acquisition comparison does not close');
   const components=(rec.components||[]).filter(r=>r.class==='improvement');
   if(!components.length||components.some(r=>number(r.source_paid)===null))throw Error('Missing improvement components');
   const unique=components.reduce((n,r)=>n+Number(r.source_paid),0),duplicate=number(rec.source_internal_consistency?.duplicate_row_amount);
   if(duplicate===null||!same(unique+duplicate,c.J31)||!same(unique,rec.source_internal_consistency?.improvement_detail_total))throw Error('Changed improvement summary');
   model.bridge={cutoff:s.source_paid_cutoff,sourceFile:s.source_file,sourceSheet:s.source_sheet,copies:summaries.map(r=>({file:r.file,sha256:r.sha256})),source,
    acquisition:{sourceTotal:Number(c.J5),loanPrefix:{total:sum(prefix),count:prefix.length,scope:{...acq.scope,category:'Financiamento Imobiliário'}},loanTail:{total:sum(tail),count:tail.length,scope:{...acq.scope,category:'Financiamento Imobiliário'}},cashTotal,cashRows:cash,cardTotal,cardScope:{...acq.scope,category:'Consórcio'},canonical:acq.total},
    works:{sourceTotal:Number(c.J31),duplicate,unique,components:components.map(r=>({...r})),canonical:works.total,gap:(Math.round(unique*100)-Math.round(works.total*100))/100,unlinkedRows:unlinked,duplicateCells:Array.isArray(s.duplicate_formula_cells)?s.duplicate_formula_cells.slice():[]}};
  }catch{model.bridge=null;}
  return model;
 }
 root.LTSPropertyReconciliation={build};
 if(typeof module!=='undefined'&&module.exports)module.exports=root.LTSPropertyReconciliation;
})(typeof window==='undefined'?globalThis:window);

;
;
/* LTS V384: lts-expense-read-model.js */
/* Existing Despesas readers: pure normalization and request lifecycle.
 * No RPC names, network, database writes, browser storage or category mapping.
 * Accept only payloads already obtained through an authorized application path.
 */
(function (root, factory) {
  'use strict';
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.LTSExpenseReadModel = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  const MONTH_VERSION = 'expense-month-detail-v2-certified-category-allocation';
  const EXEC_VERSION = 'expense-executive-v12-cached-effective-contract';
  const PENDING = new Set(['', 'a classificar', '—', 'classificação pendente']);
  const LEVELS = new Set(['transaction', 'category_only', 'total_only']);
  const own = (o, k) => Object.prototype.hasOwnProperty.call(o, k);
  function freeze(value) {
    if (value && typeof value === 'object' && !Object.isFrozen(value)) {
      Object.values(value).forEach(freeze); Object.freeze(value);
    }
    return value;
  }
  const copy = value => JSON.parse(JSON.stringify(value));
  function record(value) {
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new TypeError('Expected object.');
    return value;
  }
  function date(value) {
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) throw new TypeError('Expected ISO date.');
    const time = Date.parse(value + 'T12:00:00Z');
    if (!Number.isFinite(time) || new Date(time).toISOString().slice(0, 10) !== value) throw new TypeError('Invalid date.');
    return value;
  }
  function monthEnd(month) {
    const d = new Date(date(month) + 'T12:00:00Z');
    d.setUTCMonth(d.getUTCMonth() + 1, 0); return d.toISOString().slice(0, 10);
  }
  function integer(value) {
    if (!Number.isSafeInteger(value) || value < 0) throw new TypeError('Expected nonnegative count.');
    return value;
  }
  function text(value, empty) {
    if (typeof value !== 'string' || (!empty && !value.trim())) throw new TypeError('Expected text.');
    return value; // Preserve the original spelling; never normalize the taxonomy.
  }
  function cents(value) {
    if (typeof value !== 'string' && typeof value !== 'number') throw new TypeError('Missing monetary value.');
    const s = String(value);
    if (!/^-?\d+(?:\.\d{1,2})?$/.test(s)) throw new TypeError('Expected exact decimal money, at most two decimals.');
    const [whole, fraction = ''] = s.replace(/^-/, '').split('.');
    const n = (BigInt(whole) * 100n + BigInt(fraction.padEnd(2, '0'))) * (s[0] === '-' ? -1n : 1n);
    if (n > BigInt(Number.MAX_SAFE_INTEGER) || n < BigInt(Number.MIN_SAFE_INTEGER)) throw new RangeError('Money exceeds exact range.');
    return Number(n);
  }
  function sum(values) {
    let n = 0;
    for (const v of values) { n += v; if (!Number.isSafeInteger(n)) throw new RangeError('Total exceeds exact range.'); }
    return n;
  }
  function selection(input) {
    record(input);
    const month = date(input.month), through = date(input.through);
    if (!month.endsWith('-01') || through < month || through > monthEnd(month)) throw new TypeError('Invalid month interval.');
    const category = input.category == null ? null : text(input.category, false);
    return freeze({month, through, category});
  }
  function keyFor(row, month) {
    // Exact report identity, NOT a guessed cross-source reconciliation link.
    return JSON.stringify([text(row.source_table, false), text(row.source_ref, false), date(month)]);
  }
  function normalizeMonth(payload, requested) {
    record(payload);
    if (payload.version !== MONTH_VERSION) throw new TypeError('Unsupported monthly reader contract.');
    const scope = selection({month: payload.month, through: payload.through, category: payload.category_filter});
    if (requested) {
      const wanted = selection(requested);
      if (JSON.stringify(scope) !== JSON.stringify(wanted)) throw new TypeError('Response differs from selected period/category.');
    }
    if (!Array.isArray(payload.items) || !Array.isArray(payload.categories)) throw new TypeError('Missing detail arrays.');
    const issues = [], add = (code, key) => issues.push({code, ...(key ? {key} : {})});
    const total = cents(payload.total), declaredRows = integer(payload.rows), identities = new Set();
    const rows = payload.items.map(raw => {
      record(raw);
      const eventDate = date(raw.event_date);
      // A historical category-only row need not identify a real purchase date.
      const transactionDate = raw.transaction_date == null ? null : date(raw.transaction_date);
      if (!LEVELS.has(raw.detail_level)) throw new TypeError('Unknown documentary detail level.');
      const key = keyFor(raw, scope.month), category = text(raw.category, true);
      if (identities.has(key)) add('duplicate_source', key);
      identities.add(key);
      if (eventDate < scope.month || eventDate > scope.through) add('outside_selected_period', key);
      if (scope.category !== null && category !== scope.category) add('wrong_category_filter', key);
      if (PENDING.has(category.trim().toLocaleLowerCase('pt-BR'))) add('category_pending', key);
      return {key, sourceTable: raw.source_table, sourceRef: raw.source_ref, eventDate, transactionDate,
        amountCents: cents(raw.amount), category, centerCost: raw.center_cost == null ? null : text(raw.center_cost, true),
        counterparty: raw.counterparty == null ? null : text(raw.counterparty, true), originType: text(raw.origin_type, false),
        originName: text(raw.origin_name, false), detailLevel: raw.detail_level, coverageMode: text(raw.coverage_mode, false),
        canOpenTransaction: raw.detail_level === 'transaction'};
    });
    if (declaredRows !== rows.length) add('row_count_mismatch');
    const actualTotal = sum(rows.map(r => r.amountCents));
    if (total !== actualTotal) add('detail_total_mismatch');
    const partial = scope.through !== monthEnd(scope.month);
    if (payload.is_partial !== partial) add('partial_period_flag_mismatch');
    const amounts = new Map();
    for (const row of rows) {
      if (row.detailLevel === 'total_only') continue;
      const prev = amounts.get(row.category) || {name: row.category, totalCents: 0, rows: 0};
      prev.totalCents = sum([prev.totalCents, row.amountCents]); prev.rows++; amounts.set(row.category, prev);
    }
    const categories = Array.from(amounts.values()).sort((a, b) => b.totalCents - a.totalCents || a.name.localeCompare(b.name, 'pt-BR'));
    const declaredCategories = new Map();
    for (const c of payload.categories) {
      record(c); const name = text(c.name, true);
      if (declaredCategories.has(name)) add('duplicate_category_summary', name);
      declaredCategories.set(name, {totalCents: cents(c.total), rows: integer(c.rows)});
    }
    for (const c of categories) {
      const d = declaredCategories.get(c.name);
      if (!d || d.totalCents !== c.totalCents || d.rows !== c.rows) add('category_summary_mismatch', c.name);
    }
    for (const name of declaredCategories.keys()) if (!amounts.has(name)) add('extra_category_summary', name);
    const unallocated = sum(rows.filter(r => r.detailLevel === 'total_only').map(r => r.amountCents));
    const allocated = sum(rows.filter(r => r.detailLevel === 'category_only').map(r => r.amountCents));
    if (cents(payload.category_unallocated_total) !== unallocated) add('unallocated_total_mismatch');
    if (cents(payload.category_allocated_history_total) !== allocated) add('allocated_total_mismatch');
    if (cents(payload.category_known_total) !== total - unallocated) add('known_category_total_mismatch');
    const integrity = issues.filter(x => x.code !== 'category_pending');
    return freeze({version: 'expense-month-read-model-v1', scope, rows, categories, declaredTotalCents: total,
      actualTotalCents: actualTotal, partial, issues, internallyConsistent: integrity.length === 0,
      missingCategoryRows: issues.filter(x => x.code === 'category_pending').length,
      totalOnlyRows: rows.filter(r => r.detailLevel === 'total_only').length,
      categoryOnlyRows: rows.filter(r => r.detailLevel === 'category_only').length,
      sourceParityVerified: false, definitiveReportReady: false});
  }
  function compareExecutiveMonth(executive, detail) {
    record(executive);
    if (executive.version !== EXEC_VERSION || detail.version !== 'expense-month-read-model-v1') throw new TypeError('Unsupported reader contracts.');
    record(executive.period); record(executive.summary);
    const from = date(executive.period.from), to = date(executive.period.to), issues = [];
    if (detail.scope.category !== null || from !== detail.scope.month || to !== detail.scope.through) {
      return freeze({comparable: false, agreement: false, sourceParityVerified: false, issues: [{code: 'different_selection'}]});
    }
    if (!Array.isArray(executive.monthly_detail)) throw new TypeError('Missing executive month array.');
    const entries = executive.monthly_detail.filter(m => m.month === detail.scope.month);
    if (entries.length !== 1) issues.push({code: 'executive_month_missing_or_duplicated'});
    else {
      if (cents(entries[0].total) !== detail.declaredTotalCents) issues.push({code: 'executive_month_total_mismatch'});
      if (integer(entries[0].rows) !== detail.rows.length) issues.push({code: 'executive_month_rows_mismatch'});
    }
    if (cents(executive.summary.selected_total) !== detail.declaredTotalCents) issues.push({code: 'executive_selected_total_mismatch'});
    // Rankings are intentionally limited by the existing backend. Check displayed
    // rows, but never treat an omitted rank as a zero-valued category.
    const ranks = executive.rankings && executive.rankings.categories;
    if (!Array.isArray(ranks)) throw new TypeError('Missing category ranking.');
    const seen = new Set(), known = new Map(detail.categories.map(c => [c.name, c]));
    for (const r of ranks) {
      const name = text(r.name, true), c = known.get(name);
      if (seen.has(name)) issues.push({code: 'duplicate_executive_rank', key: name});
      seen.add(name);
      if (!c || cents(r.total) !== c.totalCents || integer(r.rows) !== c.rows) issues.push({code: 'executive_category_mismatch', key: name});
    }
    if (!detail.internallyConsistent) issues.push({code: 'monthly_detail_inconsistent'});
    const rawTimestamp = executive.data_quality && executive.data_quality.cache_refreshed_at;
    const cacheAsOf = typeof rawTimestamp === 'string' && Number.isFinite(Date.parse(rawTimestamp)) ? rawTimestamp : null;
    return freeze({comparable: true, agreement: issues.length === 0, issues, cacheAsOf,
      sourceParityVerified: false, definitiveReportReady: false});
  }
  function rangeSelection(input) {
    record(input); const from=date(input.from), to=date(input.to);
    if (from>to) throw new TypeError('Invalid inclusive interval.');
    return freeze({from,to});
  }
  function normalizeDual(payload, requested) {
    record(payload);
    if (payload.version !== 'expense-dual-lens-v2-recent-cash') throw new TypeError('Unsupported cash/consumption contract.');
    const scope=rangeSelection(payload);
    if (requested && JSON.stringify(scope)!==JSON.stringify(rangeSelection(requested))) throw new TypeError('Response differs from selected interval.');
    const cash=record(payload.cash), cons=record(payload.consumption);
    for(const array of [cash.buckets,cash.monthly,cash.recent,cons.categories,cons.monthly]) if(!Array.isArray(array))throw new TypeError('Missing lens arrays.');
    const issues=[], add=code=>issues.push({code});
    const gross=cents(cash.gross_outflows), transfers=cents(cash.own_transfers), spend=cents(cash.spend_outflows);
    const pendingCash=cents(cash.pending_reconciliation), consumed=cents(cons.total), pendingCons=cents(cons.unclassified);
    const buckets=cash.buckets.map(b=>{
      if(typeof b.excluded_from_spend!=='boolean')throw new TypeError('Missing documented cash treatment.');
      return {name:text(b.bucket,false),rows:integer(b.rows),totalCents:cents(b.total),excluded:b.excluded_from_spend};
    });
    const categories=cons.categories.map(c=>({name:text(c.category,true),rows:integer(c.rows),totalCents:cents(c.total)}))
      .sort((a,b)=>b.totalCents-a.totalCents||a.name.localeCompare(b.name,'pt-BR'));
    if(new Set(buckets.map(b=>b.name)).size!==buckets.length)add('duplicate_cash_bucket');
    if(new Set(categories.map(c=>c.name)).size!==categories.length)add('duplicate_consumption_category');
    if(sum([spend,transfers])!==gross || sum(buckets.map(b=>b.totalCents))!==gross)add('cash_total_mismatch');
    if(sum(buckets.filter(b=>b.excluded).map(b=>b.totalCents))!==transfers)add('cash_treatment_mismatch');
    if(sum(categories.map(c=>c.totalCents))!==consumed)add('consumption_total_mismatch');
    if(sum(categories.map(c=>c.rows))!==integer(cons.rows))add('consumption_row_count_mismatch');
    if(sum(categories.filter(c=>c.name.trim().toLocaleLowerCase('pt-BR')==='a classificar').map(c=>c.totalCents))!==pendingCons)add('pending_consumption_mismatch');
    const monthly=(array)=>{
      const map=new Map();
      for(const item of array){const month=date(item.month);if(!month.endsWith('-01'))throw new TypeError('Invalid monthly key.');
        if(month<scope.from.slice(0,7)+'-01'||month>scope.to.slice(0,7)+'-01')add('monthly_point_outside_interval');
        if(map.has(month))add('duplicate_monthly_point');
        map.set(month,cents(item.total));}
      return map;
    };
    const cashMonth=monthly(cash.monthly), consMonth=monthly(cons.monthly);
    if(sum(cashMonth.values())!==spend)add('cash_monthly_total_mismatch');
    if(sum(consMonth.values())!==consumed)add('consumption_monthly_total_mismatch');
    const seen=new Set();
    const recent=cash.recent.map(r=>{
      const day=date(r.date),key=JSON.stringify([text(r.source,false),text(r.source_ref,false),day]);
      if(seen.has(key))add('duplicate_recent_cash_source'); seen.add(key);
      if(day<scope.from||day>scope.to)add('recent_cash_outside_interval');
      if(typeof r.excluded_from_spend!=='boolean')throw new TypeError('Missing cash treatment.');
      return {key,date:day,description:text(r.description,true),account:r.account==null?null:text(r.account,true),
        amountCents:cents(r.amount),category:r.category==null?null:text(r.category,true),bucket:text(r.bucket,false),
        excluded:r.excluded_from_spend,evidenceStatus:text(r.evidence_status,false)};
    });
    const allCashRows=sum(buckets.map(b=>b.rows));
    if(recent.length>allCashRows || recent.length>120)add('recent_cash_count_mismatch');
    const bucketByName=new Map(buckets.map(b=>[b.name,b]));
    for(const row of recent){
      const bucket=bucketByName.get(row.bucket);
      if(!bucket)add('recent_cash_bucket_unknown');
      else if(row.excluded!==bucket.excluded)add('recent_cash_treatment_mismatch');
    }
    // Only a complete, uniquely identified list can explain the whole cash
    // summary. A capped/partial recent list must never be forced to its total.
    const completeRecent=recent.length===allCashRows && seen.size===recent.length;
    if(completeRecent){
      if(sum(recent.map(r=>r.amountCents))!==gross)add('recent_cash_total_mismatch');
      for(const bucket of buckets){
        const rows=recent.filter(r=>r.bucket===bucket.name);
        if(rows.length!==bucket.rows || sum(rows.map(r=>r.amountCents))!==bucket.totalCents)add('recent_cash_bucket_mismatch');
      }
      const recentByMonth=new Map();
      for(const row of recent){
        const month=row.date.slice(0,7)+'-01';
        if(!recentByMonth.has(month))recentByMonth.set(month,0);
        if(!row.excluded)recentByMonth.set(month,sum([recentByMonth.get(month),row.amountCents]));
      }
      for(const month of new Set([...cashMonth.keys(),...recentByMonth.keys()])){
        // Missing explicit zero-month metadata is not invented. Only differing
        // observed sums are a monetary conflict; absence remains null below.
        if((cashMonth.get(month) ?? 0)!==(recentByMonth.get(month) ?? 0))add('recent_cash_monthly_mismatch');
      }
      const observedPending=sum(recent.filter(r=>r.evidenceStatus.startsWith('operacional')).map(r=>r.amountCents));
      if(observedPending!==pendingCash)add('recent_pending_cash_mismatch');
    }
    // Include silent months within the requested interval as missing, not as
    // zero spend or silently removed timeline points. No source dates change.
    const calendarMonths=[];
    let cursor=scope.from.slice(0,7)+'-01';
    const lastMonth=scope.to.slice(0,7)+'-01';
    while(cursor<=lastMonth){
      calendarMonths.push(cursor);
      if(cursor===lastMonth)break;
      const d=new Date(cursor+'T12:00:00Z');d.setUTCMonth(d.getUTCMonth()+1,1);
      cursor=d.toISOString().slice(0,10);
    }
    return freeze({version:'expense-dual-read-model-v1',scope,issues,internallyConsistent:issues.length===0,
      grossOutflowsCents:gross,ownTransfersCents:transfers,spendOutflowsCents:spend,consumptionCents:consumed,
      pendingCashCents:pendingCash,missingCategoryRows:sum(categories.filter(c=>PENDING.has(c.name.trim().toLocaleLowerCase('pt-BR'))).map(c=>c.rows)),
      buckets,categories,recentCash:recent,recentCashIsComplete:completeRecent,
      monthly:calendarMonths.map(month=>({month,
        cashCents:cashMonth.has(month)?cashMonth.get(month):null,consumptionCents:consMonth.has(month)?consMonth.get(month):null})),
      partialCalendarRange:scope.from.slice(8)!=='01'||scope.to!==monthEnd(scope.to.slice(0,7)+'-01'),
      sourceParityVerified:false,definitiveReportReady:false});
  }
  function createReadSession(options) {
    if (!options || typeof options.load !== 'function') throw new TypeError('Provide an authorized response loader.');
    const adapt = options.adapt || normalizeMonth, selectScope = options.selection || selection, listeners = new Set();
    let generation = 0, destroyed = false, active = null;
    let state = freeze({phase: 'idle', request: null, model: null, message: null});
    function emit(next) {
      const snapshot = state = freeze(next);
      // Deliver a stable listener snapshot. A callback can cancel/dispose or
      // request another period synchronously; never re-emit obsolete state.
      for (const fn of [...listeners]) {
        if (state !== snapshot) break;
        if (!listeners.has(fn)) continue;
        try { fn(snapshot); } catch (_) { /* isolate view callbacks */ }
      }
    }
    async function select(request) {
      if (destroyed) throw new Error('Session disposed.');
      let wanted;
      try { wanted = selectScope(request); }
      catch (error) { clear(); throw error; }
      const seq = ++generation, previous = active;
      const controller = new AbortController(); active = controller;
      const signal = controller.signal;
      // Publish ownership before aborting: abort listeners can request a newer
      // period. A superseded call must not invoke its loader even once.
      if (previous) previous.abort();
      if (destroyed || seq !== generation) return state;
      emit({phase: 'loading', request: wanted, model: null, message: 'Carregando despesas do período selecionado…'});
      if (destroyed || seq !== generation || signal.aborted) return state;
      try {
        const answer = await options.load(copy(wanted), {signal});
        if (destroyed || seq !== generation) return state;
        let payload = answer;
        if (answer && own(answer, 'error') && own(answer, 'data')) {
          if (answer.error) throw answer.error; payload = answer.data;
        }
        const model = adapt(payload, wanted);
        if (destroyed || seq !== generation) return state;
        if (active === controller) active = null;
        emit({phase: 'ready', request: wanted, model, message: null});
      } catch (error) {
        if (destroyed || seq !== generation) return state;
        if (active === controller) active = null;
        const auth = error && (error.status === 401 || error.status === 403 || error.code === '42501');
        emit({phase: auth ? 'authentication_required' : 'error', request: wanted, model: null,
          message: auth ? 'Sua sessão precisa ser renovada para consultar as despesas.' : 'Não foi possível carregar este período. Nenhum valor foi substituído por zero.'});
      }
      return state;
    }
    function clear() {
      if (destroyed) return;
      const seq = ++generation, previous = active; active = null;
      if (previous) previous.abort();
      if (!destroyed && seq === generation) emit({phase: 'idle', request: null, model: null, message: null});
    }
    return Object.freeze({select, getState: () => state,
      subscribe(fn) { if (destroyed || typeof fn !== 'function') throw new TypeError('Invalid subscriber.'); listeners.add(fn); return () => listeners.delete(fn); },
      invalidate: clear,
      dispose() {
        if (destroyed) return;
        destroyed = true; ++generation;
        const previous = active; active = null;
        if (previous) previous.abort();
        emit({phase: 'idle', request: null, model: null, message: null});
        listeners.clear();
      }});
  }
  function presentation(model) {
    if (!model || model.version !== 'expense-month-read-model-v1') throw new TypeError('Expected normalized month.');
    return freeze({title: 'Conferência de despesas',
      status: model.internallyConsistent ? 'Totais internos conferidos; conciliação da origem ainda pendente.' : 'Resumo e detalhamento divergem. Total indisponível até conferência.',
      totalCents: model.internallyConsistent ? model.declaredTotalCents : null,
      periodLabel: model.partial ? 'Mês parcial' : 'Mês completo no intervalo consultado',
      coverageLabel: model.totalOnlyRows ? 'Há valores históricos sem composição por categoria.' : model.categoryOnlyRows ? 'Parte do histórico tem categoria, mas não compras individuais.' : 'Linhas de transação disponíveis; cobertura documental ainda não certificada.',
      missingCategoryRows: model.missingCategoryRows, definitiveReportReady: false});
  }
  return Object.freeze({cents, date, selection, normalizeMonth, compareExecutiveMonth, normalizeDual, rangeSelection, createReadSession, presentation, keyFor});
});

;
;
/* LTS V384: lts-expense-screen-alignment.js */
/* Existing V162 executive/monthly Despesas integration. No financial writes,
 * added frames, background polling or persistent storage. */
(function () {
  'use strict';
  function runtime() {
    'use strict';
    if (window.__LTS_EXPENSE_SCREEN_ALIGNMENT?.installed) return;
    const M = window.parent.LTSExpenseReadModel;
    if (!M || typeof ex135State !== 'function' || typeof despesas !== 'function') return;
    const status = window.__LTS_EXPENSE_SCREEN_ALIGNMENT = {installed:true,version:'current-executive-screen-v2',financial_writes:0,lastDetailParity:null};
    let route=V,product=D,executiveKey=null,monthSelection=null,fullMonth=null;
    function state() { return window.EX135 || (window.EX135={rangeKey:'ytd',winKey:'6m',loading:false,error:null,data:null,key:null,month:null,monthData:null,monthLoading:false,monthError:null,monthCategory:null}); }
    function sumCents(items, field) { return items.reduce((n,x)=>{const v=n+M.cents(x[field]);if(!Number.isSafeInteger(v))throw Error('Unsafe total');return v;},0); }
    function adaptExecutive(payload, request) {
      if(payload?.version!=='expense-executive-v12-cached-effective-contract')throw Error('Unexpected report contract');
      const scope=M.rangeSelection(payload.period);
      if(JSON.stringify(scope)!==JSON.stringify(request))throw Error('Wrong report interval');
      if(!payload.summary || !Array.isArray(payload.monthly_detail) || !Array.isArray(payload.yearly_detail))throw Error('Missing report detail');
      const total=M.cents(payload.summary.selected_total),known=M.cents(payload.data_quality?.selected_category_unallocated_total),seen=new Set();
      if(sumCents(payload.monthly_detail,'total')!==total || M.cents(payload.summary.account_total)+M.cents(payload.summary.card_total)!==total)throw Error('Report totals disagree');
      for(const m of payload.monthly_detail){
        M.date(m.month);if(!m.month.endsWith('-01') || seen.has(m.month)||m.month.slice(0,7)<scope.from.slice(0,7)||m.month.slice(0,7)>scope.to.slice(0,7))throw Error('Invalid report month');seen.add(m.month);
        if(!Number.isSafeInteger(m.rows)||m.rows<0||M.cents(m.card_total)+M.cents(m.account_total)!==M.cents(m.total))throw Error('Monthly total mismatch');
      }
      if(known<0)throw Error('Invalid coverage amount');
      const legacy=JSON.parse(JSON.stringify(payload));
      for(const m of legacy.monthly_detail)if(m.is_partial===true){m.mom_comparison_pct=null;m.yoy_comparison_pct=null;}
      for(const k of ['3m','6m','12m']){
        const w=legacy.rolling_windows?.[k];if(!w || !Array.isArray(w.top_categories))throw Error('Missing rolling window');
        M.cents(w.total);M.cents(w.known_category_total);M.cents(w.financing_total);
        w.top_categories.sort((a,b)=>M.cents(b.total)-M.cents(a.total));
      }
      return Object.freeze({legacy,scope,totalCents:total,sourceParityVerified:false});
    }
    function expectedThrough(month){const d=new Date(month+'T12:00:00Z');d.setUTCMonth(d.getUTCMonth()+1,0);return [today(),d.toISOString().slice(0,10)].sort()[0];}
    function resetMonth(){monthSelection=null;fullMonth=null;const s=state();s.month=null;s.monthData=null;s.monthModel=null;s.monthCategory=null;s.monthLoading=false;s.monthError=null;monthSession.invalidate();}
    const executiveSession=M.createReadSession({selection:M.rangeSelection,load:r=>S.rpc('lts_browser_expense_executive_v3',{p_from:r.from,p_to:r.to}),adapt:adaptExecutive});
    const monthSession=M.createReadSession({load:r=>S.rpc('lts_browser_expense_month_detail_v2',{p_month:r.month,p_category:r.category}),adapt(payload,requested){
      const model=M.normalizeMonth(payload,requested);if(!model.internallyConsistent)throw Error('Monthly detail not consistent');
      const base=state().data?.monthly_detail?.find(m=>m.month===model.scope.month);
      if(model.scope.category===null){
        if(!base || M.cents(base.total)!==model.actualTotalCents || base.rows!==model.rows.length)throw Error('Summary and month differ');
        fullMonth=model;
      }else if(fullMonth?.scope.month===model.scope.month){
        const cat=fullMonth.categories.find(c=>c.name===model.scope.category);
        if(!cat || cat.totalCents!==model.actualTotalCents || cat.rows!==model.rows.length)throw Error('Category and detail differ');
      }
      status.lastDetailParity=true;return Object.freeze({...model,legacy:payload});
    }});
    executiveSession.subscribe(s=>{const v=state();v.loading=s.phase==='loading';v.phase=s.phase;v.error=['error','authentication_required'].includes(s.phase)?s.message:null;v.data=s.model?.legacy||null;v.key=executiveKey;if(V==='Despesas')render();});
    monthSession.subscribe(s=>{const v=state();v.monthLoading=s.phase==='loading';v.monthPhase=s.phase;v.monthError=['error','authentication_required'].includes(s.phase)?s.message:null;v.monthData=s.model?.legacy||null;v.monthModel=s.model||null;if(V==='Despesas')render();});
    ex135Load=function(k){const s=state();s.rangeKey=k||s.rangeKey||'ytd';const r=ex135Range(s.rangeKey);executiveKey=r.from+'|'+r.to;s.key=executiveKey;resetMonth();return executiveSession.select({from:r.from,to:r.to});};
    ex135State=function(){const s=state(),r=ex135Range(s.rangeKey||'ytd'),key=r.from+'|'+r.to;if(executiveKey!==key)ex135Load(s.rangeKey);return s;};
    ex135SetRange=function(k){if(state().rangeKey===k && state().data)return;return ex135Load(k);};
    ex135OpenMonth=function(month,category=null){M.date(month);const s=state();if(!s.data)return;status.lastDetailParity=null;s.month=month;s.monthCategory=category;monthSelection={month,through:expectedThrough(month),category};return monthSession.select(monthSelection);};
    ex135CloseMonth=function(){resetMonth();if(V==='Despesas')render();};
    const oldRank=ex135Rank;
    ex135Rank=function(items,known,limit){return oldRank([...(items||[])].sort((a,b)=>Number(b.total)-Number(a.total)),known,limit);};
    ex135MonthDetail=function(s){
      if(!s.month)return '';
      if(s.monthLoading)return '<div class="ex135-detail" role="status">Carregando o mês selecionado…</div>';
      if(s.monthError)return `<div class="ex135-detail"><b>Não foi possível conferir o detalhamento.</b><p>${esc(s.monthError)}</p><button class="chip" data-exp-close>Fechar</button></div>`;
      const d=s.monthModel;if(!d)return '';
      const categories=fullMonth?.scope.month===d.scope.month?fullMonth.categories:d.categories;
      const provisional=d.rows.some(r=>r.sourceTable==='card_invoice_current_items');
      const precision=d.legacy?.source_precision?.notice;
      const textDate=r=>r.transactionDate?fmt(r.transactionDate):r.originType==='cartão'?'Data original não informada':r.detailLevel==='transaction'?fmt(r.eventDate):'Composição histórica';
      return `<div class="ex135-detail"><div class="ex135-detailhead"><div><span class="ex135-eye">Lançamentos do mês</span><h3>${esc(ex135MonthLabel(d.scope.month,true))}${d.partial?' · parcial':''}</h3><div class="mut">${d.scope.category?'Categoria '+esc(window.LTSCategoryDisplay.category(d.scope.category))+' · ':''}${d.rows.length} linha(s) · ${brl(d.actualTotalCents/100)}</div></div><button class="chip" data-exp-close>Fechar</button></div>${provisional?'<div class="notice">Inclui fatura aberta. A posição é provisória e pode mudar até o fechamento; não representa pagamento confirmado.</div>':''}${precision?'<div class="notice lts-exp-precision-notice">'+esc(precision)+'</div>':''}<div class="ex135-detailcats"><button data-exp-category="-1" class="${d.scope.category===null?'active':''}">Tudo</button>${categories.map((c,i)=>`<button data-exp-category="${i}" class="${d.scope.category===c.name?'active':''}">${esc(window.LTSCategoryDisplay.category(c.name))} · ${brl(c.totalCents/100)}</button>`).join('')}</div><div class="ex135-items">${d.rows.slice(0,180).map(r=>`<div class="ex135-item"><span>${esc(textDate(r))}</span><div><b>${esc(r.counterparty||'Contraparte não informada')}</b><span>${esc(window.LTSCategoryDisplay.category(r.category))} · ${esc(r.originName)} · ${r.detailLevel==='category_only'?'composição histórica por categoria':r.detailLevel==='total_only'?'total histórico sem compras individuais':'lançamento individual'}${r.sourceTable==='card_invoice_current_items'?' · fatura aberta':''}</span>${r.centerCost && r.centerCost!=='Não atribuído'?'<span>Centro de custo: '+esc(r.centerCost)+'</span>':''}</div><strong>${brl(r.amountCents/100)}</strong></div>`).join('')||'<div class="empty">Sem linhas no resultado.</div>'}</div>${d.rows.length>180?`<div class="mut">Exibindo 180 de ${d.rows.length} linhas. Selecione uma categoria para reduzir o resultado.</div>`:''}</div>`;
    };
    const oldView=despesas;
    despesas=function(){
      const html=oldView(),s=state();if(!s.data||s.loading||s.error)return html;
      const q=D?.expense_universe_qa,asof=q?.bank_documented_through,scope=s.data.period;
      const precision=s.data.source_precision?.notice;
      const opened=(D?.expense_drilldown?.rows||[]).filter(r=>r.source_table==='card_invoice_current_items'&&String(r.competence_month||'').slice(0,7)>=scope.from.slice(0,7)&&String(r.competence_month||'').slice(0,7)<=scope.to.slice(0,7));
      return `<div class="notice lts-exp-source-notice" role="status">${asof?'Base bancária documentada até '+esc(fmt(asof))+'. ':''}Cartões por competência da fatura; movimentos bancários por data de caixa. ${opened.length?'Inclui fatura aberta: posição provisória. Comparações de mês parcial aguardam períodos equivalentes. ':''}Categoria definida não significa detalhe individual disponível em todo o histórico.</div>${precision?'<div class="notice lts-exp-precision-notice">'+esc(precision)+'</div>':''}`+html;
    };
    const oldRender=render;
    render=function(){
      const leaving=route==='Despesas'&&V!=='Despesas',changed=product!==D;
      route=V;product=D;
      if(leaving||changed){executiveKey=null;resetMonth();executiveSession.invalidate();}
      const value=oldRender(),s=state();
      document.querySelectorAll('[data-exp-close]').forEach(b=>b.onclick=ex135CloseMonth);
      const cats=fullMonth?.scope.month===s.month?fullMonth.categories:s.monthModel?.categories||[];
      document.querySelectorAll('[data-exp-category]').forEach(b=>b.onclick=()=>ex135OpenMonth(s.month,b.dataset.expCategory==='-1'?null:cats[Number(b.dataset.expCategory)]?.name));
      const badge=window.parent.document.getElementById('scope');if(badge)badge.textContent=V==='Despesas'?'Despesas · homologação':'Fluxo Diário · homologação';return value;
    };
    const style=document.createElement('style');style.id='lts-expense-source-alignment-style';style.textContent='.lts-exp-source-notice{font-size:12px;line-height:1.55;margin-bottom:14px}.ex135-detailcats{max-height:210px;overflow:auto}.ex135-item>span{white-space:normal;overflow-wrap:anywhere}.ex135-item>div{min-width:0;overflow-wrap:anywhere}.ex135-detail .notice{font-size:12px;line-height:1.5}';document.head.appendChild(style);
    if(V==='Despesas')render();
  }
  const frame=document.getElementById('shell');
  function install(){try{const doc=frame?.contentDocument;if(!doc||!frame.contentWindow?.location.pathname.endsWith('/index.html')||doc.getElementById('lts-expense-source-alignment'))return;const s=doc.createElement('script');s.id='lts-expense-source-alignment';s.textContent='('+runtime.toString()+')();';(doc.head||doc.documentElement).appendChild(s);}catch(_){/* Same-origin frame may still be navigating. Its load event retries installation. */}}
  frame?.addEventListener('load',install);if(frame?.contentDocument?.readyState==='complete')install();
})();


;
;
/* LTS V384: lts-dashboard-executive-v1.js */
(function(){
  'use strict';
  const CONTRACT='dashboard-executive-cash-answer-v1';
  const MODEL_SRC='lts-dashboard-read-model.js?v=20260915-cash-answer-v1';
  const SESSION_KEY='lts_supabase_session_v1';
  const outer=document.getElementById('shell');
  const gate=document.getElementById('gate');
  let generation=0;
  function dashboardRuntime(){
    'use strict';
    if(window.__LTS_DASHBOARD_EXECUTIVE_STATUS?.installed)return;
    const modelApi=window.LTSDashboardReadModel;
    if(!modelApi)return;
    const status=window.__LTS_DASHBOARD_EXECUTIVE_STATUS={installed:true,contract:'dashboard-executive-cash-answer-v1',reader:'lts_browser_dashboard_cockpit_v1',read_only:true,financial_writer_changed:false,flow_runtime_preserved:true,expense_runtime_preserved:true,public_index_changed:false,initial_route:'Dashboard',mobile_nav_six_fixed:true,permanent_polling:false,loaded:false,loading:false,error:null,calls:0};
    const state={cockpit:D?.dashboard_cockpit||null,loading:false,loaded:false,error:null,sequence:0,rpcRequested:false,initialApplied:false};
    const money=value=>value===null||value===undefined?'Indisponível':brl(value);
    const date=value=>value?fmt(value):'Indisponível';
    const txt=value=>esc(value==null?'':value);
    const signed=value=>value===null||value===undefined?'':value<0?'neg':'pos';
    function go(route){
      if(route==='Dashboard'){V='Dashboard';renderNav();render();return}
      const top=document.querySelector('.nav [data-v="'+CSS.escape(route)+'"]');
      if(top&&typeof top.onclick==='function'){top.click();return}
      V=route;renderNav();render();
    }
    function chart(series){
      const points=(series||[]).filter(point=>point.base!==null||point.conditional!==null||point.restricted!==null);
      if(points.length<2)return '<div class="dx1-empty">A curva será exibida quando houver pelo menos dois horizontes projetados documentados.</div>';
      const values=points.flatMap(point=>[point.base,point.conditional,point.restricted]).filter(value=>value!==null);
      const lo=Math.min(...values,0),hi=Math.max(...values,0),span=Math.max(hi-lo,1),x=index=>34+(index*(552/Math.max(points.length-1,1))),y=value=>22+((hi-value)/span)*156;
      const path=key=>{const valid=points.map((point,index)=>({value:point[key],index})).filter(point=>point.value!==null);return valid.length<2?'':valid.map((point,i)=>(i?'L':'M')+x(point.index).toFixed(1)+' '+y(point.value).toFixed(1)).join(' ')};
      const labels=points.map((point,index)=>'<text x="'+x(index)+'" y="201" text-anchor="middle">'+txt(point.label||fmt(point.date))+'</text>').join('');
      const dots=points.map((point,index)=>point.base===null?'':'<circle cx="'+x(index)+'" cy="'+y(point.base)+'" r="4"></circle>').join('');
      return '<div class="dx1-chart"><svg viewBox="0 0 620 214" role="img" aria-label="Evolução projetada da liquidez"><line class="zero" x1="34" x2="586" y1="'+y(0)+'" y2="'+y(0)+'"></line><path class="base" d="'+path('base')+'"></path><path class="conditional" d="'+path('conditional')+'"></path><path class="restricted" d="'+path('restricted')+'"></path><g class="dots">'+dots+'</g><g class="labels">'+labels+'</g></svg></div>';
    }
    function kpi(label,value,note,kind){return '<article class="dx1-kpi '+(kind||'')+'"><span>'+txt(label)+'</span><strong>'+money(value)+'</strong><small>'+txt(note)+'</small></article>'}
    function metric(label,value,note){return '<div class="dx1-metric"><span>'+txt(label)+'</span><b class="'+signed(value)+'">'+money(value)+'</b><small>'+txt(note||'')+'</small></div>'}
    function dashboardView(){
      const vm=modelApi.build(state.cockpit||{}),decision=vm.decision,k=vm.kpis,pa=vm.planning,expense=vm.expenses,current=expense.current||{},previous=expense.previous||{},next=vm.cards.nextDue||{};
      const decisionClass=decision.state==='negative'?'risk':decision.state==='sufficient'?'safe':'unknown';
      const firstNegative=decision.firstNegative?date(decision.firstNegative):decision.state==='sufficient'?'Não no horizonte':'Indisponível';
      const covered=decision.coveredUntil?date(decision.coveredUntil):decision.state==='sufficient'?'Horizonte confirmado':'Indisponível';
      const worstNote=decision.worstDate?'Em '+date(decision.worstDate):'Data não informada pelo leitor';
      const accounts=vm.accounts.map(account=>'<div class="dx1-row"><span>'+txt(account.institution||account.account||'Conta')+'</span><b>'+money(modelApi.finite(account.balance))+'</b></div>').join('');
      const horizons=vm.horizons.map(item=>'<div class="dx1-horizon"><div><span>'+txt(item.label||item.id||'Horizonte')+'</span><small>'+date(item.date)+'</small></div><b class="'+signed(item.base)+'">'+money(item.base)+'</b><em>Cenário-base</em></div>').join('');
      const maxTop=Math.max(...expense.top.map(item=>Math.abs(modelApi.finite(item.amount??item.spend??item.total)||0)),1);
      const top=expense.top.slice(0,5).map(item=>{const value=modelApi.finite(item.amount??item.spend??item.total);return '<button class="dx1-rank" data-go="Despesas" type="button"><span>'+txt(item.category||item.name||item.label||'Categoria')+'</span><i><u style="width:'+Math.min(100,Math.abs(value||0)/maxTop*100)+'%"></u></i><b>'+money(value)+'</b></button>'}).join('');
      const actions=vm.work.actions.slice(0,4).map(action=>'<div class="dx1-action"><div><b>'+txt(action.title||'Ação pendente')+'</b><span>'+txt(action.description||'')+'</span></div></div>').join('');
      const loading=state.loading?'<div class="dx1-loading" role="status">Atualizando dados executivos…</div>':'';
      const error=state.error?'<div class="notice" role="alert">Não foi possível atualizar o resumo. Os últimos dados disponíveis permanecem identificados na tela.</div>':'';
      return '<main class="dx1" data-dashboard-contract="executive-cash-answer-evidence-v1">'+
        '<header class="dx1-head"><div><span class="dx1-kicker">Resumo executivo</span><h1>Sua posição financeira</h1><p>Caixa disponível, projeção e compromissos — sem misturar fato presente com cenário futuro.</p></div><div class="dx1-head-actions"><span>Posição '+date(vm.asOf)+'</span><button id="dx1Refresh" class="chip" type="button">Atualizar</button></div></header>'+loading+error+
        '<section class="dx1-decision '+decisionClass+'"><div class="dx1-answer"><span>A pergunta principal</span><h2>Tenho dinheiro suficiente?</h2><strong>'+txt(decision.answer)+'</strong><p>'+txt(decision.detail)+'</p><i>Cenário-base operacional</i></div><div class="dx1-answer-grid">'+
          metric('Primeiro saldo negativo',null,decision.firstNegative?'Cenário-base projetado':decision.state==='sufficient'?'Sem ruptura no horizonte':'Data não informada').replace('Indisponível</b>',''+txt(firstNegative)+'</b>')+
          metric('Caixa coberto até',null,decision.firstNegative?'Véspera da primeira ruptura':decision.state==='sufficient'?'Fim do horizonte disponível':'Cobertura não confirmada').replace('Indisponível</b>',''+txt(covered)+'</b>')+
          metric('Pior saldo projetado',decision.worst,worstNote)+
          metric('Ponto de gestão',null,pa.managementDate?'Data de reavaliação':'Não informado').replace('Indisponível</b>',txt(pa.managementDate?date(pa.managementDate):'Indisponível')+'</b>')+
        '</div></section>'+ 
        '<section class="dx1-kpis">'+
          kpi('Dinheiro em contas',k.bankCash,'Saldo bancário documentado','primary')+
          kpi('Contas + curto prazo',k.shortTerm.value,k.shortTerm.method==='bank_cash_plus_d0'?'Contas + liquidez D+0':'Derivado de D+3 sem RSUs')+
          kpi('RSUs vested',k.vested,'Disponibilidade evidenciada separadamente')+
          kpi('FGTS',k.fgts,'Restrito · não é caixa presente','restricted')+
          kpi('Despesas (mês)',k.expenses,'Mês corrente no leitor reconciliado')+
        '</section>'+ 
        '<section class="dx1-grid-main"><article class="dx1-card dx1-evolution"><div class="dx1-cardhead"><div><span>Liquidez</span><h3>Evolução projetada do caixa</h3></div><button class="chip" data-go="Fluxo Diário" type="button">Abrir Fluxo</button></div><div class="dx1-legend"><i class="base"></i>Base operacional <i class="conditional"></i>Com RSUs futuras <i class="restricted"></i>Com recursos restritos</div>'+chart(vm.horizons)+'<div class="dx1-horizons">'+(horizons||'<div class="dx1-empty">Horizontes indisponíveis.</div>')+'</div></article>'+ 
        '<aside class="dx1-card"><div class="dx1-cardhead"><div><span>Contas</span><h3>Posição bancária</h3></div></div>'+(accounts||'<div class="dx1-empty">Detalhamento por conta indisponível.</div>')+'<button class="dx1-link" data-go="Fluxo Diário" type="button">Ver movimentações</button></aside></section>'+ 
        '<section class="dx1-grid-three"><article class="dx1-card"><div class="dx1-cardhead"><div><span>Consumo</span><h3>Principais despesas</h3></div></div>'+metric('Mês atual',modelApi.finite(current.spend),'Leitor reconciliado')+metric('Mês anterior',modelApi.finite(previous.spend),'Referência histórica')+(top||'<div class="dx1-empty">Categorias ainda indisponíveis.</div>')+'<button class="dx1-link" data-go="Despesas" type="button">Abrir relatório de despesas</button></article>'+ 
        '<article class="dx1-card"><div class="dx1-cardhead"><div><span>Compromissos</span><h3>O que vem pela frente</h3></div></div>'+metric('Próxima fatura',modelApi.finite(next.amount),next.due_date?'Vence em '+date(next.due_date):'Data indisponível')+metric('Ciclos em aberto',vm.cards.open,'Ainda podem mudar')+metric('Fechado ou vencido',vm.cards.closed,'Não somar novamente ao consumo')+'<button class="dx1-link" data-go="Cartões" type="button">Ver cartões</button></article>'+ 
        '<article class="dx1-card validation"><div class="dx1-cardhead"><div><span>Patrimônio</span><h3>Posição patrimonial em validação</h3></div></div><div class="dx1-validation"><b>Total consolidado ainda não certificado</b><p>Ativos, dívidas, disponibilidade, avaliação e datas-base continuam no gate independente. Nenhum total patrimonial é apresentado como aprovado nesta tela.</p></div><button class="dx1-link" data-go="Patrimônio" type="button">Abrir posição patrimonial</button></article></section>'+ 
        '<section class="dx1-grid-bottom"><article class="dx1-card"><div class="dx1-cardhead"><div><span>Planejamento</span><h3>Proteções e decisões</h3></div><button class="chip" data-go="Planejamento" type="button">Detalhar</button></div>'+metric('Após contingência / FGTS',pa.worstAfter,pa.fgtsRequestBy?'Solicitar até '+date(pa.fgtsRequestBy):'Prazo de solicitação indisponível')+'<div class="dx1-note">FGTS permanece separado do caixa presente. '+(pa.fgtsEstimated?'Há estimativa de acréscimo futuro sinalizada pelo leitor.':'Não há estimativa de acréscimo futuro aplicada.')+'</div></article>'+ 
        '<article class="dx1-card"><div class="dx1-cardhead"><div><span>Atualizações</span><h3>O que precisa da sua atenção</h3></div><b class="dx1-count">'+(vm.work.count===null?'—':txt(vm.work.count))+'</b></div>'+(actions||'<div class="dx1-empty">Nenhuma ação detalhada disponível no resumo.</div>')+'<button class="dx1-link" data-go="Atualizações" type="button">Abrir atualizações</button></article></section>'+ 
        '<p class="dx1-footnote">Fato documentado e projeção aparecem em camadas distintas. Valores indisponíveis não são inferidos.</p></main>';
    }
    dashboard=dashboardView;
    function bind(){
      document.querySelectorAll('[data-go]').forEach(button=>button.onclick=()=>go(button.dataset.go));
      const refresh=document.getElementById('dx1Refresh');if(refresh)refresh.onclick=()=>loadDashboard(true);
      const badge=window.parent.document.getElementById('scope');if(badge)badge.textContent=V==='Dashboard'?'Resumo executivo · homologação':V==='Despesas'?'Despesas · homologação':'Fluxo Diário · homologação';
      document.querySelectorAll('.brand small').forEach(node=>{node.textContent=V==='Dashboard'?'Resumo executivo':V==='Despesas'?'Relatório reconciliado':'Recuperação do Fluxo Diário'});
      bindMobileNav();
    }
    function bindMobileNav(){
      let nav=document.getElementById('dx1MobileNav');if(!nav){nav=document.createElement('nav');nav.id='dx1MobileNav';nav.className='dx1-mobile-nav';nav.setAttribute('aria-label','Navegação principal');document.body.appendChild(nav)}
      const routes=[['Dashboard','Resumo'],['Fluxo Diário','Fluxo'],['Despesas','Despesas'],['Cartões','Cartões'],['Patrimônio','Patrimônio'],['Atualizações','Atualizar']];
      nav.innerHTML=routes.map(route=>'<button type="button" data-mobile-route="'+route[0]+'" class="'+(V===route[0]?'active':'')+'"><i aria-hidden="true"></i><span>'+route[1]+'</span></button>').join('');
      nav.querySelectorAll('[data-mobile-route]').forEach(button=>button.onclick=()=>go(button.dataset.mobileRoute));
    }
    const baseRender=render;
    render=function(){baseRender();bind();if(V==='Dashboard'&&!state.rpcRequested&&!state.loading)queueMicrotask(()=>loadDashboard(false))};
    const baseRenderNav=renderNav;
    renderNav=function(){
      baseRenderNav();
      let button=N.querySelector('[data-v="Dashboard"]');
      if(!button){button=document.createElement('button');button.type='button';button.dataset.v='Dashboard';button.textContent='Dashboard';N.prepend(button)}
      button.classList.toggle('active',V==='Dashboard');button.onclick=()=>go('Dashboard');button.style.display='';
      const order=['Dashboard','Fluxo Diário','Despesas','Cartões','Patrimônio','Atualizações','Planejamento'];order.forEach(route=>{const item=N.querySelector('[data-v="'+route+'"]');if(item)N.appendChild(item)});
    };
    async function loadDashboard(force){
      if(state.loading)return;state.rpcRequested=true;state.loading=true;state.error=null;status.loading=true;status.calls+=1;const sequence=++state.sequence;if(V==='Dashboard')render();
      try{const {data,error}=await S.rpc('lts_browser_dashboard_cockpit_v1');if(sequence!==state.sequence)return;if(error||!data)throw new Error(error?.message||'Resumo executivo indisponível');state.cockpit=data;state.loaded=true;D.dashboard_cockpit=data;status.loaded=true;status.error=null;status.as_of=data.as_of||null}
      catch(error){if(sequence!==state.sequence)return;state.error=String(error?.message||error||'Falha de leitura');status.error=state.error}
      finally{if(sequence===state.sequence){state.loading=false;status.loading=false;if(V==='Dashboard')render()}}
    }
    function applyInitial(){const flow=window.__LTS_V162_FLOW_RECOVERY_STATUS;if(state.initialApplied||!D||!flow?.route_applied_at)return false;state.initialApplied=true;status.initial_applied_at=new Date().toISOString();status.flow_ready_before_initial=true;status.flow_runtime_ready_before_initial=true;status.flow_read_completion_not_required=true;V='Dashboard';renderNav();render();return true}
    window.__LTS_V163_ROUTE_DASHBOARD=function(){return applyInitial()?{state:'dashboard',done:true}:state.initialApplied?{state:'dashboard',done:true}:{state:document.querySelector('.login')?'login':'waiting',done:false}};
    const style=document.createElement('style');style.id='lts-dashboard-executive-style';style.textContent=`
      .nav [data-v="Dashboard"]{display:block!important}.dx1{max-width:1320px;margin:0 auto}.dx1-head{display:flex;align-items:flex-end;justify-content:space-between;gap:24px;margin:2px 0 14px}.dx1-head h1{font-size:30px;letter-spacing:-.04em;margin:3px 0}.dx1-head p{margin:0;color:var(--mut);font-size:11px}.dx1-kicker,.dx1-cardhead span{font-size:9px;font-weight:900;letter-spacing:.12em;text-transform:uppercase;color:#8d6f42}.dx1-head-actions{display:flex;align-items:center;gap:8px;color:var(--mut);font-size:10px}.dx1-decision{display:grid;grid-template-columns:minmax(280px,.82fr) minmax(0,1.45fr);border-radius:22px;overflow:hidden;box-shadow:0 16px 44px rgba(16,43,80,.14);margin-bottom:11px}.dx1-answer{padding:24px;color:#fff;background:linear-gradient(135deg,#102b50,#1b3b6f)}.dx1-decision.safe .dx1-answer{background:linear-gradient(135deg,#123f38,#1f705d)}.dx1-decision.risk .dx1-answer{background:linear-gradient(135deg,#6f2c2c,#a04742)}.dx1-answer>span{font-size:9px;opacity:.7;text-transform:uppercase;letter-spacing:.12em}.dx1-answer h2{font-size:16px;margin:15px 0 8px}.dx1-answer strong{display:block;font-size:25px;line-height:1.08;letter-spacing:-.025em}.dx1-answer p{font-size:10px;line-height:1.5;opacity:.78;margin:10px 0 14px}.dx1-answer i{font-style:normal;font-size:8px;border:1px solid #ffffff3a;border-radius:999px;padding:5px 8px}.dx1-answer-grid{display:grid;grid-template-columns:1fr 1fr;background:#fff}.dx1-metric{padding:15px;border-left:1px solid #edf0f4;border-bottom:1px solid #edf0f4}.dx1-metric span,.dx1-metric small{display:block;color:var(--mut);font-size:8px}.dx1-metric b{display:block;font-size:16px;margin:5px 0}.dx1-kpis{display:grid;grid-template-columns:repeat(5,1fr);gap:9px;margin-bottom:11px}.dx1-kpi{background:#fff;border:1px solid var(--bd);border-radius:15px;padding:14px;box-shadow:var(--shadow);min-width:0}.dx1-kpi.primary{border-color:#c3d3e5}.dx1-kpi.restricted{background:#fffcf5;border-color:#e5d6b7}.dx1-kpi span,.dx1-kpi small{display:block;color:var(--mut);font-size:8px}.dx1-kpi strong{display:block;font-size:19px;letter-spacing:-.025em;margin:7px 0;overflow-wrap:anywhere}.dx1-card{background:#fff;border:1px solid var(--bd);border-radius:17px;padding:15px;box-shadow:var(--shadow);min-width:0}.dx1-cardhead{display:flex;align-items:flex-start;justify-content:space-between;gap:10px;margin-bottom:9px}.dx1-cardhead h3{font-size:15px;margin:3px 0 0}.dx1-grid-main{display:grid;grid-template-columns:minmax(0,1.55fr) minmax(250px,.55fr);gap:10px;margin-bottom:10px}.dx1-grid-three{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-bottom:10px}.dx1-grid-bottom{display:grid;grid-template-columns:1fr 1fr;gap:10px}.dx1-legend{display:flex;gap:12px;flex-wrap:wrap;color:var(--mut);font-size:8px}.dx1-legend i{width:14px;height:3px;border-radius:9px;background:#1b3b6f;align-self:center}.dx1-legend i.conditional{background:#b8935a}.dx1-legend i.restricted{background:#a7b0bc}.dx1-chart{width:100%;overflow:hidden}.dx1-chart svg{width:100%;height:190px;display:block}.dx1-chart path{fill:none;stroke-width:4;stroke-linecap:round;stroke-linejoin:round}.dx1-chart .base{stroke:#1b3b6f}.dx1-chart .conditional{stroke:#b8935a;stroke-dasharray:8 7}.dx1-chart .restricted{stroke:#a7b0bc;stroke-dasharray:3 7}.dx1-chart .zero{stroke:#c5ccd5;stroke-dasharray:4 5}.dx1-chart .dots{fill:#1b3b6f}.dx1-chart text{font-size:9px;fill:#748197}.dx1-horizons{display:grid;grid-template-columns:repeat(3,1fr);gap:7px}.dx1-horizon{border:1px solid #edf0f4;border-radius:11px;padding:9px}.dx1-horizon>div{display:flex;justify-content:space-between;gap:5px}.dx1-horizon span,.dx1-horizon small,.dx1-horizon em{font-size:8px;color:var(--mut);font-style:normal}.dx1-horizon b{display:block;font-size:12px;margin:7px 0 2px}.dx1-row{display:flex;justify-content:space-between;gap:12px;padding:11px 0;border-bottom:1px solid #edf0f4;font-size:10px}.dx1-row:last-of-type{border-bottom:0}.dx1-link{display:block;width:100%;border:0;border-top:1px solid #edf0f4;background:none;color:var(--nv);text-align:left;padding:11px 0 0;margin-top:8px;font:800 9px/1.2 inherit;cursor:pointer}.dx1-rank{display:grid;grid-template-columns:minmax(80px,1fr) 1.2fr auto;gap:8px;align-items:center;width:100%;border:0;border-top:1px solid #edf0f4;background:none;padding:9px 0;text-align:left;color:inherit;font-family:inherit}.dx1-rank span,.dx1-rank b{font-size:9px}.dx1-rank i{height:5px;background:#eef1f4;border-radius:99px;overflow:hidden}.dx1-rank u{display:block;height:100%;background:var(--nv);border-radius:99px;text-decoration:none}.dx1-validation{padding:15px;border-radius:13px;background:#f7f9fb}.dx1-validation b{font-size:13px}.dx1-validation p,.dx1-note{font-size:9px;color:var(--mut);line-height:1.5}.dx1-action{padding:9px 0;border-top:1px solid #edf0f4}.dx1-action:first-of-type{border-top:0}.dx1-action b,.dx1-action span{display:block;font-size:9px}.dx1-action span{font-size:8px;color:var(--mut);margin-top:2px}.dx1-count{display:grid;place-items:center;min-width:30px;height:30px;border-radius:50%;background:#eef2f6;color:var(--nv);font-size:11px}.dx1-empty{padding:18px;text-align:center;color:var(--mut);font-size:9px}.dx1-loading{padding:8px 11px;margin-bottom:9px;border-radius:10px;background:#edf4fa;color:var(--nv);font-size:9px}.dx1-footnote{text-align:center;color:var(--mut);font-size:8px;margin:12px 0 72px}.dx1-mobile-nav{display:none}
      @media(max-width:1000px){.dx1-kpis{grid-template-columns:repeat(3,1fr)}.dx1-grid-main{grid-template-columns:1fr}.dx1-grid-three{grid-template-columns:1fr 1fr}.dx1-grid-three .validation{grid-column:1/-1}}
      @media(max-width:820px){body{padding-bottom:76px}.nav{display:none}.dx1-head{align-items:flex-start;flex-direction:column;gap:9px}.dx1-head h1{font-size:25px}.dx1-head-actions{width:100%;justify-content:space-between}.dx1-decision{grid-template-columns:1fr;border-radius:18px}.dx1-answer{padding:20px}.dx1-answer strong{font-size:23px}.dx1-answer-grid{grid-template-columns:1fr 1fr}.dx1-kpis{grid-template-columns:1fr 1fr}.dx1-kpi:first-child{grid-column:1/-1}.dx1-grid-three,.dx1-grid-bottom{grid-template-columns:1fr}.dx1-grid-three .validation{grid-column:auto}.dx1-chart svg{height:auto}.dx1-horizons{grid-template-columns:1fr}.dx1-card{border-radius:15px}.dx1-mobile-nav{position:fixed;display:grid;grid-template-columns:repeat(6,minmax(0,1fr));left:0;right:0;bottom:0;z-index:50;min-height:64px;padding:6px max(5px,env(safe-area-inset-right)) calc(6px + env(safe-area-inset-bottom)) max(5px,env(safe-area-inset-left));background:#fff;border-top:1px solid var(--bd);box-shadow:0 -8px 24px rgba(16,43,80,.09)}.dx1-mobile-nav button{min-width:0;min-height:48px;border:0;background:none;color:var(--mut);font-family:inherit;padding:3px 1px}.dx1-mobile-nav button i{display:block;width:7px;height:7px;border:2px solid currentColor;border-radius:50%;margin:0 auto 5px}.dx1-mobile-nav button span{display:block;font-size:7px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.dx1-mobile-nav button.active{color:var(--nv);font-weight:900}.dx1-mobile-nav button.active i{background:var(--ouro);border-color:var(--ouro)}}
      @media(max-width:420px){.dx1-kpis{grid-template-columns:1fr}.dx1-kpi:first-child{grid-column:auto}.dx1-metric{padding:12px}.dx1-mobile-nav button span{font-size:6.5px}}
    `;document.head.appendChild(style);
    renderNav();bindMobileNav();applyInitial();
  }
  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!d.documentElement||!String(w.location.pathname||'').endsWith('/index.html'))return null;return {w,d}}catch(error){return null}}
  function install(){
    const f=frame();if(!f||typeof f.w.render!=='function'||typeof f.w.dashboard!=='function')return false;
    if(!f.w.LTSDashboardReadModel){
      if(!f.d.getElementById('lts-dashboard-read-model')){const script=f.d.createElement('script');script.id='lts-dashboard-read-model';script.src=MODEL_SRC;script.onload=burst;(f.d.head||f.d.documentElement).appendChild(script)}return false;
    }
    if(!f.w.__LTS_DASHBOARD_EXECUTIVE_STATUS?.installed&&!f.d.getElementById('lts-dashboard-executive-runtime')){const script=f.d.createElement('script');script.id='lts-dashboard-executive-runtime';script.textContent='('+dashboardRuntime.toString()+')();';(f.d.head||f.d.documentElement).appendChild(script)}
    const result=f.w.__LTS_V163_ROUTE_DASHBOARD?.();if((result?.state==='dashboard'||result?.state==='login')&&gate)gate.hidden=true;return result?.state==='dashboard';
  }
  function burst(){const current=++generation;let attempt=0;function step(){if(current!==generation)return;const done=install();attempt+=1;if(!done&&attempt<180)setTimeout(step,100)}step();[250,600,1200,2400,4800,8000,12000,18000].forEach(delay=>setTimeout(()=>{if(current===generation)install()},delay))}
  function sessionChanged(event){if(event.storageArea===localStorage&&event.key===SESSION_KEY&&event.newValue)burst()}
  window.addEventListener('storage',sessionChanged);
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();
  window.__LTS_TOP_CANDIDATE_VERSION='v163-dashboard-executive';
  window.__LTS_V163_STATUS={contract:CONTRACT,source_candidate:'index.html',flow_baseline:'wip35-v162-flow-recovery',expense_baseline:'ex135-reconciled',dashboard_reader:'lts_browser_dashboard_cockpit_v1',read_only:true,financial_writer_changed:false,public_index_changed:false,bounded_boot:true,post_login_session_rearm:true,permanent_polling:false};
})();

;
;
/* LTS V384: lts-executive-visual-system-v2.js */
(function(){
  'use strict';
  const CONTRACT='executive-visual-system-v2';
  const outer=document.getElementById('shell');
  const gate=document.getElementById('gate');
  let generation=0;

  function visualRuntime(){
    'use strict';
    if(window.__LTS_EXECUTIVE_VISUAL_SYSTEM_V2?.installed)return;
    const modelApi=window.LTSDashboardReadModel;
    if(!modelApi||typeof dashboard!=='function'||typeof render!=='function'||typeof renderNav!=='function')return;

    const original={
      dashboard,
      despesas,
      patrimonio,
      atualizacoes,
      cartoes:typeof cartoesBase121==='function'?cartoesBase121:cartoes,
      render,
      renderNav
    };
    const VERSION='V165';
    const state=window.__LTS_V165_STATE||(window.__LTS_V165_STATE={
      expenseTab:'overview',wealthTab:'overview',
      wealth:{loading:false,loaded:false,data:null,error:null},
      search:{query:'',loading:false,total:0,rows:[],error:null,seq:0,timer:null},
      anticipation:{results:{},loading:{},errors:{}}
    });

    const status=window.__LTS_EXECUTIVE_VISUAL_SYSTEM_V2={
      installed:true,contract:'executive-visual-system-v2',version:'v165',
      reference_sha256:'0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b',
      navigation_routes:['Dashboard','Fluxo Diário','Despesas','Patrimônio','Atualizações'],
      planning_consolidated_into_dashboard:true,cards_consolidated_into_expenses:true,
      classification_and_document_coverage_separated:true,
      rsu_regular_gross_factor:1,cash_rsu_net_factor:.7,
      anticipated_vesting_is_scenario_only:true,retention_separate_from_rsu:true,
      transaction_search_without_date:true,flow_renderer_preserved:true,
      private_awards_only:true,anticipation_audited_and_user_scoped:true,
      financial_writers_changed:false,public_index_changed:false,style_ready:false
    };

    let link=document.getElementById('lts-executive-visual-system-v2-style');
    if(!link){link=document.createElement('link');link.id='lts-executive-visual-system-v2-style';link.rel='stylesheet';link.href='lts-executive-visual-system-v2.css?v=20260916-v165';document.head.appendChild(link)}
    link.addEventListener('load',()=>{status.style_ready=true;if(D&&!N.classList.contains('hidden'))render()},{once:true});
    if(link.sheet)status.style_ready=true;

    const finite=value=>value!==null&&value!==undefined&&value!==''&&Number.isFinite(Number(value))?Number(value):null;
    const amount=value=>finite(value)===null?'—':brl(Number(value));
    const date=value=>value?fmt(String(value).slice(0,10)):'—';
    const iso=value=>/^\d{4}-\d{2}-\d{2}$/.test(String(value||'').slice(0,10))?String(value).slice(0,10):null;
    const text=value=>esc(value==null?'':String(value));
    const signed=value=>finite(value)!==null&&Number(value)<0?'is-negative':'';
    const total=values=>(values||[]).reduce((sum,value)=>sum+(finite(value)||0),0);
    const pct=value=>finite(value)===null?'—':Number(value).toLocaleString('pt-BR',{maximumFractionDigits:0})+'%';
    const number=value=>finite(value)===null?'—':Number(value).toLocaleString('pt-BR',{maximumFractionDigits:3});
    const usd=value=>finite(value)===null?'—':'US$ '+Number(value).toLocaleString('pt-BR',{minimumFractionDigits:2,maximumFractionDigits:3});
    const fx=value=>finite(value)===null?'—':'R$ '+Number(value).toLocaleString('pt-BR',{minimumFractionDigits:4,maximumFractionDigits:5});
    const dayBefore=value=>modelApi.dayBefore(value);
    const monthLabel=value=>{const key=String(value||'').slice(0,7);if(!/^\d{4}-\d{2}$/.test(key))return key||'—';return new Intl.DateTimeFormat('pt-BR',{month:'short',year:'2-digit'}).format(new Date(key+'-01T12:00:00')).replace('.','')};
    const normalize=value=>String(value||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();

    function icon(route){
      const paths={
        'Dashboard':'<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="4" rx="2"/><rect x="14" y="11" width="7" height="10" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/>',
        'Fluxo Diário':'<path d="M4 7h12M13 4l3 3-3 3M20 17H8M11 14l-3 3 3 3"/>',
        'Despesas':'<path d="M4 19V9M10 19V5M16 19v-7M22 19H2"/>',
        'Patrimônio':'<path d="M3 10.5 12 4l9 6.5M5 10v9h14v-9M9 19v-5h6v5"/>',
        'Atualizações':'<path d="M12 3a9 9 0 1 0 8.1 5.1M20 3v5h-5"/><path d="M12 7v5l3 2"/>'
      };
      return '<svg viewBox="0 0 24 24" aria-hidden="true">'+(paths[route]||paths.Dashboard)+'</svg>';
    }

    function go(route,tab){
      if(route==='Planejamento')route='Dashboard';
      if(route==='Cartões'){route='Despesas';tab='cards'}
      if(route==='Lançamentos'){route='Atualizações';tab='search'}
      if(route==='Despesas'&&tab)state.expenseTab=tab;
      if(route==='Patrimônio'&&tab)state.wealthTab=tab;
      V=route;renderNav();render();window.scrollTo({top:0,behavior:'smooth'});
      if(tab==='search')setTimeout(()=>document.getElementById('v165SearchInput')?.focus(),50);
    }

    function sourceAsOf(){
      const candidates=[D?.expense_universe_qa?.bank_documented_through,D?.updates?.freshness?.position_as_of,D?.dashboard_cockpit?.liquidity?.as_of,D?.dashboard_cockpit?.as_of].map(iso).filter(Boolean);
      return candidates[0]||null;
    }

    function pageHead(kicker,title,subtitle,aside){
      return '<header class="v165-pagehead"><div><span class="v165-eyebrow">'+text(kicker)+'</span><h1>'+text(title)+'</h1><p>'+text(subtitle)+'</p></div>'+(aside||'')+'</header>';
    }

    function kpi(label,value,note,kind){
      return '<article class="v165-kpi '+(kind||'')+'"><span>'+text(label)+'</span><strong class="'+signed(value)+'">'+amount(value)+'</strong><small>'+text(note||'')+'</small></article>';
    }

    function chart(vm){
      const initial=finite(vm.kpis.shortTerm?.value??vm.kpis.bankCash);
      const points=[];
      if(initial!==null)points.push({date:today(),label:'Hoje',base:initial,conditional:initial,restricted:initial+(finite(vm.kpis.fgts)||0)});
      (vm.horizons||[]).forEach(point=>points.push(point));
      if(points.length<2)return '<div class="v165-empty">Projeção ainda sem pontos suficientes.</div>';
      const values=points.flatMap(point=>[point.base,point.conditional,point.restricted]).filter(value=>finite(value)!==null);
      const lo=Math.min(0,...values),hi=Math.max(0,...values),span=Math.max(1,hi-lo),W=650,H=218,pad={l:34,r:18,t:18,b:34};
      const x=index=>pad.l+index*((W-pad.l-pad.r)/Math.max(1,points.length-1));
      const y=value=>pad.t+(hi-Number(value))/span*(H-pad.t-pad.b);
      const path=key=>points.map((point,index)=>finite(point[key])===null?null:{index,value:Number(point[key])}).filter(Boolean).map((point,index)=>(index?'L':'M')+x(point.index).toFixed(1)+' '+y(point.value).toFixed(1)).join(' ');
      const labels=points.map((point,index)=>'<text x="'+x(index)+'" y="'+(H-8)+'" text-anchor="middle">'+text(point.label||date(point.date))+'</text>').join('');
      return '<div class="v165-chart"><svg viewBox="0 0 '+W+' '+H+'" role="img" aria-label="Evolução da liquidez"><line class="zero" x1="'+pad.l+'" x2="'+(W-pad.r)+'" y1="'+y(0)+'" y2="'+y(0)+'"/><text class="zero-label" x="2" y="'+(y(0)+3)+'">R$ 0</text><path class="base" d="'+path('base')+'"/><path class="conditional" d="'+path('conditional')+'"/><path class="restricted" d="'+path('restricted')+'"/><g class="labels">'+labels+'</g></svg></div>';
    }

    function categoryParts(label){
      const raw=String(label||'Outros'),n=normalize(raw);
      if(n.includes('benjamin')&&n.includes('educa'))return {group:'Benjamin',detail:'Educação'};
      if(n==='educacao')return {group:'Benjamin',detail:'Educação'};
      if(n.includes('financ'))return {group:'Financiamento imobiliário',detail:''};
      return {group:raw,detail:''};
    }

    function rank(items,maxItems=5){
      const rows=(items||[]).slice(0,maxItems),max=Math.max(1,...rows.map(item=>Math.abs(finite(item.amount??item.total??item.spend)||0)));
      return '<div class="v165-rank">'+(rows.map(item=>{const value=finite(item.amount??item.total??item.spend)||0,parts=categoryParts(item.category||item.name||item.label);return '<div class="v165-rankrow"><div><b>'+text(parts.group)+'</b>'+(parts.detail?'<small>'+text(parts.detail)+'</small>':'')+'</div><i><u style="width:'+Math.max(3,Math.abs(value)/max*100)+'%"></u></i><strong>'+amount(value)+'</strong></div>'}).join('')||'<div class="v165-empty">Sem composição disponível.</div>')+'</div>';
    }

    function dashboardV165(){
      const cockpit=D?.dashboard_cockpit||{},vm=modelApi.build(cockpit),planning=D?.planning_executive||{},ps=planning.summary||{},wealth=D?.wealth_executive||{},ws=wealth.summary||{},source=sourceAsOf();
      const firstGap=iso(ps.first_real_gap_date)||vm.decision.firstNegative,covered=firstGap?dayBefore(firstGap):vm.decision.coveredUntil,requestBy=iso(ps.fgts_request_by)||vm.planning.fgtsRequestBy,uncovered=iso(ps.first_negative_even_with_fgts)||iso(cockpit.planning_audited?.first_uncovered_gap_date),worst=finite(ps.worst_balance??cockpit.planning_audited?.worst_before_brl),worstAfter=finite(cockpit.planning_audited?.worst_after_brl),fgts=finite(vm.kpis.fgts),episodes=planning.gap_episodes||[];
      const accounts=(vm.accounts||[]).map((account,index)=>'<div class="v165-bankrow"><i>'+text((account.institution||account.account||'C').slice(0,3).toUpperCase())+'</i><div><b>'+text(account.institution||account.account||'Conta')+'</b><small>posição '+date(source||vm.asOf)+'</small></div><strong>'+amount(account.balance)+'</strong></div>').join('');
      const next=vm.cards.nextDue||{},actions=(vm.work.actions||[]).slice(0,3),current=vm.expenses.current||{},previous=vm.expenses.previous||{};
      const liquidity=finite(ws.liquidity_through_d3??vm.kpis.shortTerm?.value)||0,assets=finite(ws.assets_central)||0,cipo=finite(wealth.assets?.cipo_396?.market_central)||0,vehicle=finite(wealth.assets?.volvo_xc40?.market_central)||0,ringTotal=Math.max(1,assets),liqShare=Math.max(2,Math.min(35,liquidity/ringTotal*100)),vehicleShare=Math.max(2,Math.min(15,vehicle/ringTotal*100));
      const actionTitle=requestBy?'Resgatar FGTS até '+date(requestBy):'Definir ação de cobertura';
      const answer=firstGap?'Coberto até '+date(covered):'Horizonte coberto';
      return '<div class="v165-dashboard" data-reference-sha="0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b">'+
        pageHead('LTS Wealth / resumo executivo','Dashboard','Caixa, horizonte e decisões em uma única leitura.','<div class="v165-headtools"><span class="v165-source"><i></i>Hoje '+date(today())+(source?' · dados até '+date(source):'')+'</span><button id="v165Refresh" class="v165-btn secondary" type="button">Atualizar</button></div>')+
        '<section class="v165-decision"><div class="v165-decision-main"><span>Disponibilidade projetada</span><strong>'+text(answer)+'</strong><small>'+(firstGap?'primeiro dia negativo em '+date(firstGap):'nenhum saldo negativo encontrado')+'</small></div><div class="v165-decision-step danger"><span>Quando fico negativo</span><b>'+date(firstGap)+'</b><small>'+(worst!==null?'pior ponto '+amount(worst):'valor ainda não disponível')+'</small></div><div class="v165-decision-step action"><span>Ação recomendada</span><b>'+text(actionTitle)+'</b><small>'+amount(fgts)+' · contingência aproximada D+30</small></div><div class="v165-decision-step"><span>Depois do FGTS</span><b>'+(uncovered?'nova falta em '+date(uncovered):'horizonte coberto')+'</b><small>'+(worstAfter!==null?'pior ponto '+amount(worstAfter):'sem valor residual informado')+'</small></div></section>'+
        '<section class="v165-kpis">'+
          kpi('Dinheiro em contas',vm.kpis.bankCash,'saldo bancário evidenciado','primary')+
          kpi('Contas + curto prazo',vm.kpis.shortTerm?.value,'contas + liquidez D+0')+
          kpi('RSUs vested',vm.kpis.vested,'adquiridas · liquidez D+3','positive')+
          kpi('FGTS',vm.kpis.fgts,'restrito · aproximadamente D+30','restricted')+
          kpi('Despesas do mês',vm.kpis.expenses,'mês parcial documentado','expense')+
        '</section>'+
        '<section class="v165-grid dashboard-main"><article class="v165-card liquidity-card"><div class="v165-cardhead"><div><span>Liquidez</span><h2>Evolução projetada</h2></div><button class="v165-btn quiet" data-v165-go="Fluxo Diário" type="button">Abrir fluxo</button></div><div class="v165-legend"><span><i class="base"></i>sem novos vestings</span><span><i class="conditional"></i>com vestings</span><span><i class="restricted"></i>com FGTS</span></div>'+chart(vm)+'</article><article class="v165-card distribution-card"><div class="v165-cardhead"><div><span>Patrimônio</span><h2>Distribuição</h2></div></div><div class="v165-ring" style="--liq:'+liqShare+'%;--vehicle:'+vehicleShare+'%"><div><b>'+amount(ws.net_worth_central)+'</b><small>líquido estimado</small></div></div><div class="v165-ringlegend"><span><i class="property"></i>CIPÓ <b>'+amount(cipo)+'</b></span><span><i class="liquid"></i>Liquidez <b>'+amount(liquidity)+'</b></span><span><i class="vehicle"></i>Volvo <b>'+amount(vehicle)+'</b></span></div></article><article class="v165-card bank-card"><div class="v165-cardhead"><div><span>Contas</span><h2>Posição por banco</h2></div></div>'+(accounts||'<div class="v165-empty">Contas não recebidas.</div>')+'<button class="v165-link" data-v165-go="Fluxo Diário" type="button">Ver movimentações</button></article></section>'+
        '<section class="v165-grid dashboard-lower"><article class="v165-card"><div class="v165-cardhead"><div><span>Despesas</span><h2>Principais grupos</h2></div><button class="v165-btn quiet" data-v165-go="Despesas" type="button">Ver análise</button></div>'+rank(vm.expenses.top,4)+'<div class="v165-comparison"><span>Mês anterior</span><b>'+amount(previous.spend)+'</b><span>Atual</span><b>'+amount(current.spend)+'</b></div></article><article class="v165-card"><div class="v165-cardhead"><div><span>Próximos compromissos</span><h2>O que vem pela frente</h2></div></div><div class="v165-commit"><i class="blue">'+date(next.due_date).slice(0,5)+'</i><div><b>Próxima fatura</b><small>'+text(next.card_name||'cartão')+'</small></div><strong>'+amount(next.amount)+'</strong></div><div class="v165-commit"><i class="gold">'+date(requestBy).slice(0,5)+'</i><div><b>Acionar FGTS</b><small>para chegar antes da primeira ruptura</small></div><strong>'+amount(fgts)+'</strong></div><div class="v165-commit"><i class="red">'+date(firstGap).slice(0,5)+'</i><div><b>Primeiro dia negativo</b><small>com vestings programados</small></div><strong>'+amount(worst)+'</strong></div></article><article class="v165-card"><div class="v165-cardhead"><div><span>Atualizações</span><h2>O que pede atenção</h2></div><b class="v165-count">'+text(vm.work.count??0)+'</b></div>'+(actions.map(action=>'<button class="v165-actionrow" data-v165-go="Atualizações" type="button"><i></i><span><b>'+text(action.title||'Atualização')+'</b><small>'+text(action.description||'')+'</small></span></button>').join('')||'<div class="v165-ok"><i>✓</i><span><b>Nenhuma ação prioritária</b><small>O caixa não depende de uma pendência aberta agora.</small></span></div>')+'<button class="v165-link" data-v165-go="Atualizações" type="button">Abrir central</button></article></section>'+
        '<section class="v165-cashplan"><div><span>Plano de caixa</span><h2>Agir antes do déficit</h2></div><div class="v165-planpoint"><span>Preparar</span><b>'+date(requestBy)+'</b></div><i></i><div class="v165-planpoint danger"><span>Primeiro negativo</span><b>'+date(firstGap)+'</b></div><div class="v165-planpoint"><span>Contingência</span><b>'+amount(fgts)+'</b></div></section>'+
      '</div>';
    }

    function expenseState(){
      try{return typeof ex135State==='function'?ex135State():(window.EX135||{})}catch(error){return {error:String(error?.message||error)}}
    }

    function expenseTabs(){
      const tabs=[['overview','Visão geral'],['categories','Categorias'],['cards','Cartões'],['transactions','Lançamentos']];
      return '<div class="v165-tabs" role="tablist">'+tabs.map(([key,label])=>'<button type="button" role="tab" aria-selected="'+(state.expenseTab===key)+'" class="'+(state.expenseTab===key?'active':'')+'" data-v165-expense-tab="'+key+'">'+label+'</button>').join('')+'</div>';
    }

    function periodPicker(s){
      const current=s?.rangeKey||'ytd';return '<div class="v165-periods">'+[['ytd','Ano atual'],['6m','6 meses'],['12m','12 meses'],['all','Desde 2013']].map(([key,label])=>'<button type="button" class="'+(current===key?'active':'')+'" data-v165-expense-range="'+key+'">'+label+'</button>').join('')+'</div>';
    }

    function monthBars(rows,key='total'){
      const items=(rows||[]).slice(-12),max=Math.max(1,...items.map(row=>Math.abs(finite(row[key])||0)));
      return '<div class="v165-bars">'+(items.map(row=>{const value=finite(row[key])||0;return '<button type="button" class="v165-bar" data-v165-month="'+text(row.month||row.reference_month)+'" title="'+text(monthLabel(row.month||row.reference_month))+' · '+text(amount(value))+'"><b>'+amount(value)+'</b><i><u style="height:'+Math.max(4,Math.abs(value)/max*100)+'%"></u></i><span>'+text(monthLabel(row.month||row.reference_month))+'</span></button>'}).join('')||'<div class="v165-empty">Sem histórico mensal disponível.</div>')+'</div>';
    }

    function cardGroups(){
      const operating=D?.card_operating||{},map=new Map(),key=name=>{const n=normalize(name);if(n.includes('aeternum'))return'aeternum';if(n.includes('personnalite'))return'personnalite';if(n.includes('c6'))return'c6';return n||'cartao'};
      const ensure=name=>{const id=key(name);if(!map.has(id))map.set(id,{id,name:String(name||'Cartão'),open:null,closed:null,future:[]});return map.get(id)};
      (operating.open_cycles||[]).forEach(item=>ensure(item.card_name).open=item);
      (operating.closed_or_due||[]).forEach(item=>ensure(item.card_name).closed=item);
      (operating.contracted_installment_floor_months||[]).forEach(month=>(month.detail||[]).forEach(item=>ensure(item.card_name).future.push({...item,reference_month:month.reference_month})));
      return [...map.values()].sort((a,b)=>(b.open?.amount||0)-(a.open?.amount||0));
    }

    function cardsPanel(){
      const o=D?.card_operating||{},groups=cardGroups(),history=D?.card_history?.monthly||[],next=o.next_due||{};
      return '<section class="v165-expense-cards"><div class="v165-kpis four">'+kpi('Faturas abertas',o.open_cycles_total,(o.open_cycles||[]).length+' ciclo(s)','primary')+'<article class="v165-kpi"><span>Próximo vencimento</span><strong>'+date(next.due_date)+'</strong><small>'+amount(next.amount)+' · '+text(next.card_name||'cartão')+'</small></article>'+kpi('Parcelas contratadas',o.contracted_installment_floor_total,'piso futuro conhecido','restricted')+'<article class="v165-kpi '+(finite(o.classification_review?.pending_lines)?'expense':'positive')+'"><span>A classificar</span><strong>'+text(String(o.classification_review?.pending_lines||0))+'</strong><small>lançamento(s) de cartão</small></article></div><div class="v165-grid split"><article class="v165-card"><div class="v165-cardhead"><div><span>Histórico</span><h2>Uso mensal dos cartões</h2></div></div>'+monthBars(history,'total')+'</article><article class="v165-card"><div class="v165-cardhead"><div><span>Carteira</span><h2>Faturas e parcelas</h2></div></div>'+(groups.map(group=>{const current=group.closed||group.open,future=total(group.future.map(item=>item.amount));return '<div class="v165-cardrow"><i>'+text(group.id==='aeternum'?'AE':group.id==='personnalite'?'IT':group.id==='c6'?'C6':'CC')+'</i><div><b>'+text(group.name)+'</b><small>'+(group.closed?'vencida · confirmar pagamento':group.open?'aberta · ainda pode crescer':'sem ciclo aberto')+(current?.due_date?' · vence '+date(current.due_date):'')+'</small></div><strong>'+amount(current?.amount)+'</strong><em>parcelas '+amount(future)+'</em></div>'}).join('')||'<div class="v165-empty">Nenhum cartão recebido.</div>')+'</article></div><div class="v165-callout"><b>Uma compra, uma despesa.</b><span>Pagamento de fatura liquida o caixa e não duplica o consumo. Cartões da mesma fatura permanecem agrupados pela base reconciliada.</span></div></section>';
    }

    function expenseOverview(report,s){
      const summary=report.summary||{},monthly=report.monthly_detail||[],windows=report.rolling_windows||{},windowData=windows[s.winKey||'6m']||windows['6m']||{},last=monthly.at(-1)||{},pending=(finite(D?.semantic_review?.pending_groups)||0)+(finite(D?.card_classification_review?.pending_groups)||0),documentCoverage=finite(windowData.transaction_detail_pct??report.data_quality?.selected_transaction_detail_pct),classified=pending===0?'100%':pending+' pendência(s)';
      return '<div class="v165-kpis four"><article class="v165-kpi primary"><span>Gasto no período</span><strong>'+amount(summary.selected_total)+'</strong><small>'+text(monthly.length)+' competência(s)</small></article>'+kpi('Média mensal',summary.monthly_average,'média do período')+kpi('Mês atual',last.total,(last.is_partial?'parcial · ':'')+monthLabel(last.month),'expense')+'<article class="v165-kpi positive"><span>Classificação revisada</span><strong>'+text(classified)+'</strong><small>escopo disponível; cobertura documental '+pct(documentCoverage)+'</small></article></div><div class="v165-grid expense-overview"><article class="v165-card wide"><div class="v165-cardhead"><div><span>Tendência</span><h2>Despesas mês a mês</h2></div><small>toque no mês para abrir os lançamentos</small></div>'+monthBars(monthly)+'</article><article class="v165-card"><div class="v165-cardhead"><div><span>Composição</span><h2>Principais grupos</h2></div></div>'+rank(windowData.top_categories,7)+'</article></div><div class="v165-grid split"><article class="v165-card"><div class="v165-cardhead"><div><span>Qualidade</span><h2>O que está classificado</h2></div></div><div class="v165-quality"><div class="complete"><i>✓</i><span><b>'+text(classified)+'</b><small>das decisões no escopo revisado</small></span></div><div><b>'+pct(documentCoverage)+'</b><small>dos lançamentos têm detalhe documental individual</small></div></div><p class="v165-footnote">Classificação e cobertura documental são medidas diferentes. Faturas antigas sem itens preservam o total sem inventar estabelecimentos.</p></article><article class="v165-card"><div class="v165-cardhead"><div><span>Cartões</span><h2>Obrigações atuais</h2></div><button class="v165-btn quiet" data-v165-expense-tab="cards">Ver cartões</button></div><div class="v165-bigrow"><span>Em aberto</span><b>'+amount(D?.card_operating?.open_cycles_total)+'</b></div><div class="v165-bigrow"><span>Piso de parcelas futuras</span><b>'+amount(D?.card_operating?.contracted_installment_floor_total)+'</b></div></article></div>';
    }

    function categoriesPanel(report,s){
      const w=report.rolling_windows?.[s.winKey||'6m']||report.rolling_windows?.['6m']||{},items=w.top_categories||[];
      return '<div class="v165-grid categories"><article class="v165-card"><div class="v165-cardhead"><div><span>Grupos</span><h2>Para onde foi o dinheiro</h2></div><b>'+amount(w.known_category_total)+'</b></div>'+rank(items,20)+'</article><article class="v165-card"><div class="v165-cardhead"><div><span>Família</span><h2>Benjamin</h2></div></div><div class="v165-family"><i>B</i><div><b>Benjamin</b><small>grupo de acompanhamento</small></div><strong>'+amount(total(items.filter(item=>normalize(item.name||item.category).includes('educa')||normalize(item.name||item.category).includes('benjamin')).map(item=>item.total??item.amount)))+'</strong></div><div class="v165-subcategory"><span>Educação</span><b>'+amount(total(items.filter(item=>normalize(item.name||item.category).includes('educa')||normalize(item.name||item.category).includes('benjamin')).map(item=>item.total??item.amount)))+'</b></div><p class="v165-footnote">A apresentação agrupa Educação em Benjamin; os lançamentos e a classificação de origem permanecem preservados.</p></article></div>';
    }

    function transactionsPanel(report){
      const rows=(D?.expense_drilldown?.rows||[]).slice().sort((a,b)=>String(b.transaction_date||b.event_date||'').localeCompare(String(a.transaction_date||a.event_date||''))).slice(0,80);
      return '<article class="v165-card"><div class="v165-cardhead"><div><span>Detalhes</span><h2>Lançamentos recentes</h2></div><button class="v165-btn quiet" data-v165-go="Atualizações" data-v165-tab="search">Pesquisar todo o histórico</button></div><div class="v165-tablewrap"><table class="v165-table"><thead><tr><th>Data</th><th>Descrição</th><th>Grupo</th><th>Origem</th><th class="num">Valor</th></tr></thead><tbody>'+(rows.map(row=>{const parts=categoryParts(row.category);return '<tr><td>'+date(row.transaction_date||row.event_date)+'</td><td><b>'+text(row.counterparty||row.description||row.description_raw||'Não informado')+'</b></td><td>'+text(parts.group)+(parts.detail?'<small>'+text(parts.detail)+'</small>':'')+'</td><td>'+text(row.card_name||row.account||row.origin_name||'—')+'</td><td class="num">'+amount(row.amount)+'</td></tr>'}).join('')||'<tr><td colspan="5" class="v165-empty">Abra um mês para carregar os lançamentos detalhados.</td></tr>')+'</tbody></table></div></article>';
    }

    function despesasV165(){
      const s=expenseState(),report=s.data||{},source=sourceAsOf(),aside='<div class="v165-headtools"><span class="v165-source"><i></i>Dados até '+date(report.period?.last_available||source)+'</span>'+periodPicker(s)+'</div>';
      let body='';
      if(s.loading&&!s.data)body='<div class="v165-skeleton">Carregando despesas reconciliadas…</div>';
      else if(s.error&&!s.data)body='<div class="v165-callout error"><b>Despesas indisponíveis</b><span>'+text(s.error)+'</span></div>';
      else if(state.expenseTab==='cards')body=cardsPanel();
      else if(state.expenseTab==='categories')body=categoriesPanel(report,s);
      else if(state.expenseTab==='transactions')body=transactionsPanel(report);
      else body=expenseOverview(report,s);
      return '<div class="v165-report v165-expenses">'+pageHead('Despesas / consumo e cartões','Despesas','Consumo, cartões e lançamentos sem dupla contagem.',aside)+expenseTabs()+body+'</div>';
    }

    function ensureWealth(){
      if(state.wealth.loading||state.wealth.loaded)return;
      state.wealth.loading=true;
      S.rpc('lts_browser_wealth_detail_v2').then(({data,error})=>{if(error||!data)throw Error(error?.message||'Patrimônio indisponível');state.wealth.data=data;state.wealth.loaded=true}).catch(error=>state.wealth.error=String(error?.message||error)).finally(()=>{state.wealth.loading=false;if(V==='Patrimônio')render()});
    }

    function awardType(item){return /cash/i.test(String(item?.asset_type||item?.type||item?.label||''))?'Cash RSU':'RSU'}
    function awardData(){
      const j=state.wealth.data||{},source=Array.isArray(j.rsu?.future_schedule)?j.rsu.future_schedule:[];
      return source.map(item=>{
        const type=awardType(item),vesting=iso(item.eligibility_date),anticipated=iso(item.anticipated_date),id=String(item.group_key||''),awardIds=Array.isArray(item.award_ids)?item.award_ids.map(String):[];
        return {...item,id,awardIds,type,vesting,units:finite(item.quantity),price:finite(item.unit_price_usd),fx:finite(item.fx_rate),gross:finite(item.gross_value_brl),net:type==='Cash RSU'?finite(item.net_value_brl):finite(item.gross_value_brl),available:iso(item.available_date),anticipated,effective:anticipated||vesting};
      }).filter(item=>item.id&&item.vesting&&item.awardIds.length).sort((a,b)=>String(a.effective).localeCompare(String(b.effective)));
    }

    function wealthTabs(){
      const tabs=[['overview','Visão geral'],['rsu','RSUs e awards'],['assets','Bens e dívidas']];return '<div class="v165-tabs" role="tablist">'+tabs.map(([key,label])=>'<button type="button" role="tab" aria-selected="'+(state.wealthTab===key)+'" class="'+(state.wealthTab===key?'active':'')+'" data-v165-wealth-tab="'+key+'">'+label+'</button>').join('')+'</div>';
    }

    function wealthOverview(j){
      const w=j.wealth||D?.wealth_executive||{},s=w.summary||{},l=w.liquidity||{},c=w.assets?.cipo_396||{},v=w.assets?.volvo_xc40||{},mid=finite(s.net_worth_central),lo=finite(s.net_worth_low),hi=finite(s.net_worth_high),span=Math.max(1,(hi||0)-(lo||0)),marker=Math.max(0,Math.min(100,((mid||0)-(lo||0))/span*100));
      return '<div class="v165-kpis four"><article class="v165-kpi primary"><span>Patrimônio líquido estimado</span><strong>'+amount(mid)+'</strong><small>faixa '+amount(lo)+' → '+amount(hi)+'</small></article>'+kpi('Ativos',s.assets_central,'valor central')+kpi('Dívidas conhecidas',s.known_debt_total,'saldos documentados','expense')+kpi('Liquidez até D+3',s.liquidity_through_d3,'FGTS separado','positive')+'</div><div class="v165-grid split"><article class="v165-card"><div class="v165-cardhead"><div><span>Faixa patrimonial</span><h2>Valor líquido estimado</h2></div></div><div class="v165-range-values"><span>Baixa<b>'+amount(lo)+'</b></span><span>Central<b>'+amount(mid)+'</b></span><span>Alta<b>'+amount(hi)+'</b></span></div><div class="v165-range"><i style="left:'+marker+'%"></i></div><p class="v165-footnote">A faixa varia com o preço de mercado do imóvel e do veículo; não é laudo nem preço garantido.</p></article><article class="v165-card"><div class="v165-cardhead"><div><span>Liquidez</span><h2>Quando pode virar caixa</h2></div><button class="v165-btn quiet" data-v165-wealth-tab="rsu">Abrir RSUs</button></div><div class="v165-liqrow"><span>Contas + Cofrinho</span><b>'+amount((finite(l.bank_cash)||0)+(finite(l.d0)||0))+'</b><em>D+0</em></div><div class="v165-liqrow"><span>RSUs vested</span><b>'+amount(l.d3)+'</b><em>D+3</em></div><div class="v165-liqrow"><span>FGTS</span><b>'+amount(l.fgts_contingency)+'</b><em>D+30</em></div><div class="v165-liqrow"><span>Awards futuros</span><b>'+amount(s.future_awards_excluded)+'</b><em>futuro</em></div></article></div><div class="v165-grid split"><article class="v165-card asset-summary"><div class="v165-cardhead"><div><span>Principal ativo</span><h2>CIPÓ 396</h2></div><button class="v165-btn quiet" data-v165-wealth-tab="assets">Ver detalhes</button></div><strong>'+amount(c.equity_central)+'</strong><small>equity central</small><div class="v165-splitvalues"><span>Mercado<b>'+amount(c.market_central)+'</b></span><span>Dívida<b>'+amount(c.documentary_debt)+'</b></span></div></article><article class="v165-card asset-summary"><div class="v165-cardhead"><div><span>Veículo</span><h2>Volvo XC40</h2></div></div><strong>'+amount(v.equity_central)+'</strong><small>equity central</small><div class="v165-splitvalues"><span>Mercado<b>'+amount(v.market_central)+'</b></span><span>Financiado<b>'+amount(v.documented_financed_balance)+'</b></span></div></article></div>';
    }

    function scenarioResult(award){
      const result=state.anticipation.results[award.id],error=state.anticipation.errors[award.id];if(state.anticipation.loading[award.id])return '<div class="v165-scenario-result">Calculando impacto no caixa…</div>';if(error)return '<div class="v165-scenario-result error">'+text(error)+'</div>';if(!result)return '';
      return '<div class="v165-scenario-result"><span>Modelo atual <b>'+(result.current_model?.first_negative_date?date(result.current_model.first_negative_date):'sem ruptura')+'</b></span><span>Com antecipação <b>'+(result.scenario?.first_negative_date?date(result.scenario.first_negative_date):'sem ruptura')+'</b></span><span>Valor deslocado <b>'+amount(result.selected_amount_brl)+'</b></span></div>';
    }

    function retentionPanel(j){
      const award=j.employment_awards?.retention||{},gross=finite(award.gross_total_brl),installments=Array.isArray(award.installments)?award.installments:[],projected=Array.isArray(j.employment_awards?.retention_projected_events)?j.employment_awards.retention_projected_events:[];
      if(gross===null&&!installments.length)return '<article class="v165-card retention"><div class="v165-cardhead"><div><span>Retention Award</span><h2>Acordo separado de RSU</h2></div></div><div class="v165-empty">Detalhes contratuais não disponíveis na leitura autenticada.</div></article>';
      const rows=installments.map((item,index)=>{const event=projected[index]||{},share=finite(item.share),portion=finite(item.gross_value_brl)??(share===null?null:gross*share);return '<div><i>'+text(item.sequence||index+1)+'</i><span><b>'+text(item.label||'Parcela')+'</b><small>'+text(item.detail||'')+(event.date?' · projeção '+date(event.date):'')+'</small></span><strong>'+amount(portion)+'</strong></div>'}).join('');
      return '<article class="v165-card retention"><div class="v165-cardhead"><div><span>'+text(award.label||'Retention Award')+'</span><h2>Acordo separado de RSU</h2></div><strong>'+amount(gross)+'</strong></div><div class="v165-retention">'+(rows||'<div class="v165-empty">Parcelas ainda não documentadas.</div>')+'</div><div class="v165-callout muted"><b>Tratamento separado.</b><span>'+text(award.note||'O Fluxo mantém somente as parcelas documentadas. O total bruto e a tributação não são confundidos com a regra de Cash RSU.')+'</span></div></article>';
    }

    function rsuPanel(j){
      const rsu=j.rsu||{},position=(rsu.vested_positions||[])[0]||{},awards=awardData(),regular=awards.filter(x=>x.type==='RSU'),cash=awards.filter(x=>x.type==='Cash RSU'),regularTotal=total(regular.map(x=>x.gross)),cashGross=total(cash.map(x=>x.gross)),cashNet=total(cash.map(x=>x.net));
      const rows=awards.map(award=>'<div class="v165-award '+(award.type==='Cash RSU'?'cash':'regular')+'"><div class="v165-award-date"><span>Vesting original</span><b>'+date(award.vesting)+'</b><small>'+text(award.type)+'</small></div><div class="v165-award-units"><span>Quantidade</span><b>'+number(award.units)+'</b><small>'+(award.type==='Cash RSU'?'liquidação em dinheiro':'ações após vesting')+'</small></div><div><span>Preço OGN usado</span><b>'+usd(award.price)+'</b><small>câmbio '+fx(award.fx)+'</small></div><div><span>'+(award.type==='Cash RSU'?'Líquido projetado':'Valor de referência')+'</span><b>'+amount(award.type==='Cash RSU'?award.net:award.gross)+'</b><small>'+(award.type==='Cash RSU'?'70% do bruto; 30% de imposto':'100% bruto; sem corte automático')+'</small></div><label><span>Data antecipada</span><input type="date" data-v165-award-date="'+text(award.id)+'" max="'+text(award.vesting)+'" value="'+text(award.anticipated||'')+'"><small>'+(award.anticipated?'cenário ativo · original preservada':'opcional · cenário Sun Pharma')+'</small></label><button type="button" class="v165-btn '+(award.anticipated?'secondary':'quiet')+'" data-v165-award-save="'+text(award.id)+'">'+(award.anticipated?'Atualizar cenário':'Salvar cenário')+'</button>'+scenarioResult(award)+'</div>').join('');
      return '<div class="v165-kpis four"><article class="v165-kpi primary"><span>RSU já vested</span><strong>'+amount(position.value_brl||j.wealth?.liquidity?.d3)+'</strong><small>'+(position.units!=null?number(position.units)+' ações · ':'')+'D+3</small></article>'+kpi('RSUs futuras',regularTotal,regular.length+' vestings · 100% bruto')+kpi('Cash RSUs · bruto',cashGross,cash.length+' parcelas','restricted')+kpi('Cash RSUs · líquido',cashNet,'70% após imposto de 30%','positive')+'</div><article class="v165-card"><div class="v165-cardhead"><div><span>Agenda de vesting</span><h2>Datas, quantidades e valor considerado</h2></div><div class="v165-quote"><span>Referência usada</span><b>'+usd(awards[0]?.price)+'</b><small>FX '+fx(awards[0]?.fx)+'</small></div></div><div class="v165-awards-head"><span>Vesting</span><span>Quantidade</span><span>Cotação</span><span>Valor</span><span>Antecipação</span><span>Ação</span></div><div class="v165-awards">'+(rows||'<div class="v165-empty">Nenhum vesting futuro disponível.</div>')+'</div><div class="v165-callout"><b>Antecipação é cenário.</b><span>A data original nunca é apagada. A data alternativa fica salva na sua conta; o Fluxo oficial e o vesting real continuam inalterados até existir evidência.</span></div></article>'+retentionPanel(j);
    }

    function assetsPanel(j){
      const w=j.wealth||D?.wealth_executive||{},c=w.assets?.cipo_396||{},v=w.assets?.volvo_xc40||{},vf=j.volvo_financing||{},commitments=j.documentary_commitments?.items||[];
      return '<div class="v165-grid split"><article class="v165-card asset-detail"><div class="v165-cardhead"><div><span>Imóvel</span><h2>CIPÓ 396</h2></div><em>valor · dívida · equity</em></div><div class="v165-fourfacts"><span>Mercado<b>'+amount(c.market_central)+'</b><small>'+amount(c.market_low)+' → '+amount(c.market_high)+'</small></span><span>Dívida documental<b>'+amount(c.documentary_debt)+'</b><small>Bradesco</small></span><span>Equity central<b>'+amount(c.equity_central)+'</b><small>mercado − dívida</small></span><span>Compra + reforma<b>'+amount(c.historical_purchase_plus_reform)+'</b><small>histórico</small></span></div><p class="v165-footnote">O preço pedido do próprio imóvel não é usado como comparável independente.</p></article><article class="v165-card asset-detail"><div class="v165-cardhead"><div><span>Veículo</span><h2>Volvo XC40</h2></div><em>mercado · financiamento</em></div><div class="v165-fourfacts"><span>Mercado<b>'+amount(v.market_central)+'</b><small>'+amount(v.market_low)+' → '+amount(v.market_high)+'</small></span><span>Saldo financiado<b>'+amount(v.documented_financed_balance)+'</b><small>posição documental</small></span><span>Equity central<b>'+amount(v.equity_central)+'</b><small>mercado − dívida</small></span><span>Próxima parcela<b>'+amount(vf.installment_amount)+'</b><small>'+date(vf.next_due)+'</small></span></div></article></div><article class="v165-card"><div class="v165-cardhead"><div><span>Compromissos</span><h2>Saídas futuras sem confundir com dívida atual</h2></div></div>'+(commitments.map(item=>'<div class="v165-liqrow"><span>'+text(item.label||item.commitment_id||'Compromisso')+'</span><b>'+amount(item.debt_balance??item.schedule_loaded?.future_loaded_total)+'</b><em>'+date(item.schedule_loaded?.next_date)+'</em></div>').join('')||'<div class="v165-empty">Nenhum compromisso adicional recebido.</div>')+'</article>';
    }

    function patrimonioV165(){
      ensureWealth();const j=state.wealth.data||{wealth:D?.wealth_executive||{},rsu:{future_schedule:D?.wealth?.asset_layers?.derived_future_schedule||[],vested_positions:[]}},w=j.wealth||{},body=state.wealth.loading&&!state.wealth.data?'<div class="v165-skeleton">Carregando patrimônio e RSUs…</div>':state.wealth.error&&!state.wealth.data?'<div class="v165-callout error"><b>Patrimônio detalhado indisponível</b><span>'+text(state.wealth.error)+'</span></div>':state.wealthTab==='rsu'?rsuPanel(j):state.wealthTab==='assets'?assetsPanel(j):wealthOverview(j);
      return '<div class="v165-report v165-wealth">'+pageHead('Patrimônio / visão executiva','Patrimônio','Ativos, dívidas, liquidez e awards em camadas claras.','<div class="v165-headtools"><span class="v165-source"><i></i>Posição '+date(w.as_of||j.as_of||sourceAsOf())+'</span></div>')+wealthTabs()+body+'</div>';
    }

    function searchRows(){
      const s=state.search;if(s.loading)return '<div class="v165-search-empty">Buscando em todo o histórico…</div>';if(s.error)return '<div class="v165-search-empty error">'+text(s.error)+'</div>';if(!s.query)return '<div class="v165-search-empty">Comece a digitar. Ex.: retention, Mastercard, condomínio, escola.</div>';if(!s.rows.length)return '<div class="v165-search-empty">Nenhum lançamento encontrado para “'+text(s.query)+'”.</div>';
      return s.rows.map(row=>'<div class="v165-searchrow"><div><b>'+text(row.description||row.counterparty||row.category||'Lançamento')+'</b><small>'+date(row.date||row.event_date)+' · '+text(row.account||'sem conta')+' · '+text(row.category||'sem categoria')+(row.center_cost?' · '+text(row.center_cost):'')+'</small></div><strong>'+amount(row.amount)+'</strong></div>').join('');
    }

    function paintSearch(){
      const meta=document.getElementById('v165SearchMeta'),out=document.getElementById('v165SearchResults');if(meta)meta.textContent=state.search.loading?'Buscando…':state.search.query?'Data e valor são opcionais · '+state.search.total.toLocaleString('pt-BR')+' lançamento(s) encontrado(s)':'Data e valor são opcionais';if(out)out.innerHTML=searchRows();
    }

    function scheduleSearch(value){
      state.search.query=String(value||'');clearTimeout(state.search.timer);if(!state.search.query.trim()){state.search.loading=false;state.search.total=0;state.search.rows=[];state.search.error=null;paintSearch();return}state.search.timer=setTimeout(()=>runSearch(state.search.query),260);paintSearch();
    }

    async function runSearch(value){
      const query=String(value||'').trim(),seq=++state.search.seq;state.search.query=query;state.search.loading=true;state.search.error=null;paintSearch();
      try{const {data,error}=await S.rpc('lts_browser_transactions_v2',{p_from:'2013-10-10',p_to:null,p_query:query,p_direction:null,p_account:null,p_limit:200,p_offset:0});if(seq!==state.search.seq)return;if(error||!data)throw Error(error?.message||'Consulta indisponível');state.search.total=finite(data.total)||0;state.search.rows=Array.isArray(data.rows)?data.rows:[]}
      catch(error){if(seq!==state.search.seq)return;state.search.total=0;state.search.rows=[];state.search.error='Não foi possível consultar agora: '+String(error?.message||error)}finally{if(seq===state.search.seq){state.search.loading=false;paintSearch()}}
    }

    function updateButton(item){
      const type=String(item?.type||''),id=text(item?.id||''),destination=String(item?.destination||'');
      if(type==='overdue_transfer_review')return '<button class="v165-btn secondary updconfirm" data-update="'+id+'">Confirmar realizado</button>';
      if(type==='overdue_event_review')return '<button class="v165-btn secondary updeventconfirm" data-update="'+id+'">Confirmar realizado</button>';
      if(type==='card_payment_review')return '<button class="v165-btn secondary cardpayconfirm" data-update="'+id+'">Confirmar pagamento</button>';
      if(type==='document_request'||type==='reconciliation')return '<button class="v165-btn secondary updinput" data-update="'+id+'">Enviar evidência</button>';
      if(destination)return '<button class="v165-btn quiet" data-v165-go="'+text(destination)+'">Abrir</button>';
      return '<span class="v165-pill">Revisar</span>';
    }

    function atualizacoesV165(){
      const updates=D?.updates||{},items=(updates.items||[]).filter(item=>typeof updateIsAction==='function'?updateIsAction(item):true).sort((a,b)=>(finite(a.priority)||9)-(finite(b.priority)||9)||Math.abs(finite(b.impact_amount)||0)-Math.abs(finite(a.impact_amount)||0)),pending=(finite(D?.semantic_review?.pending_groups)||0)+(finite(D?.card_classification_review?.pending_groups)||0),fresh=sourceAsOf();
      const search='<article class="v165-card v165-search"><div class="v165-cardhead"><div><span>Pesquisar lançamentos</span><h2>Encontre sem saber a data</h2></div><small>histórico desde 2013 + lançamentos futuros</small></div><div class="v165-searchbox"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/></svg><input id="v165SearchInput" type="search" autocomplete="off" placeholder="Digite retention, Mastercard, condomínio…" value="'+text(state.search.query)+'"></div><div id="v165SearchMeta" class="v165-searchmeta">'+(state.search.query?'Data e valor são opcionais · '+state.search.total.toLocaleString('pt-BR')+' lançamento(s) encontrado(s)':'Data e valor são opcionais')+'</div><div id="v165SearchResults" class="v165-searchresults">'+searchRows()+'</div></article>';
      const taskRows=items.slice(0,12).map((item,index)=>'<div class="v165-task '+((finite(item.priority)||9)===1?'urgent':'')+'"><i>'+(index+1)+'</i><div><b>'+text(item.title||'Atualização')+'</b><small>'+text(item.detail||'')+(finite(item.impact_amount)?' · impacto '+amount(Math.abs(finite(item.impact_amount))):'')+'</small></div>'+updateButton(item)+'</div>').join('');
      const classifications=pending?'<details class="v165-card v165-details"><summary>Classificações pendentes <b>'+pending+'</b></summary><div class="v165-details-body">'+(typeof cardClassificationUpdates==='function'?cardClassificationUpdates():'')+(typeof expenseClassificationUpdates==='function'?expenseClassificationUpdates():'')+'</div></details>':'<div class="v165-ok wide"><i>✓</i><span><b>Classificação concluída no escopo revisado</b><small>0 grupos pendentes nas fontes disponíveis. Cobertura documental continua medida separadamente.</small></span></div>';
      return '<div class="v165-report v165-updates">'+pageHead('Atualizações / trabalho e controle','Atualizações','Pesquise o histórico e resolva somente o que exige sua decisão.','<div class="v165-headtools"><span class="v165-source"><i></i>Dados até '+date(fresh)+'</span><button type="button" class="v165-btn secondary" data-v165-go="Entradas">Adicionar documento</button></div>')+'<div class="v165-update-kpis"><div><span>Ações abertas</span><b>'+items.length+'</b></div><div><span>Classificações pendentes</span><b>'+pending+'</b></div><div><span>Escopo revisado</span><b>'+(pending?'em revisão':'100%')+'</b></div></div>'+search+'<article class="v165-card"><div class="v165-cardhead"><div><span>Prioridades</span><h2>O que precisa de você</h2></div><b class="v165-count">'+items.length+'</b></div><div class="v165-tasks">'+(taskRows||'<div class="v165-empty">Nenhuma ação operacional aberta.</div>')+'</div></article>'+classifications+'</div>';
    }

    async function refreshDashboard(){
      const button=document.getElementById('v165Refresh');if(button){button.disabled=true;button.textContent='Atualizando…'}
      try{const {data,error}=await S.rpc('lts_browser_dashboard_cockpit_v1');if(error||!data)throw Error(error?.message||'Resumo indisponível');D.dashboard_cockpit=data;render()}catch(error){toast('Não foi possível atualizar: '+String(error?.message||error));if(button){button.disabled=false;button.textContent='Atualizar'}}
    }

    async function saveAnticipation(id){
      const input=document.querySelector('[data-v165-award-date="'+CSS.escape(id)+'"]'),value=iso(input?.value),award=awardData().find(item=>item.id===id);if(!award)return;
      if(value&&value>award.vesting){toast('A antecipação precisa ser anterior ao vesting original.');return}
      delete state.anticipation.results[id];delete state.anticipation.errors[id];
      state.anticipation.loading[id]=true;render();
      try{const {data,error}=await S.rpc('lts_browser_save_vesting_anticipation_v1',{p_group_key:id,p_anticipated_date:value});if(error||!data)throw Error(error?.message||'Cenário indisponível');const row=state.wealth.data?.rsu?.future_schedule?.find(item=>item.group_key===id);if(row)row.anticipated_date=value||null;if(data.scenario)state.anticipation.results[id]=data.scenario;toast(value?'Cenário salvo na sua conta.':'Cenário removido.')}catch(error){state.anticipation.errors[id]='Não foi possível salvar: '+String(error?.message||error)}finally{state.anticipation.loading[id]=false;if(V==='Patrimônio')render()}
    }

    function decorateNav(){
      const order=['Dashboard','Fluxo Diário','Despesas','Patrimônio','Atualizações'],labels={'Dashboard':'Dashboard','Fluxo Diário':'Fluxo de caixa','Despesas':'Despesas','Patrimônio':'Patrimônio','Atualizações':'Atualizações'};
      order.forEach(route=>{let button=N.querySelector('[data-v="'+route+'"]');if(!button){button=document.createElement('button');button.dataset.v=route}button.classList.toggle('active',V===route);button.innerHTML=icon(route)+'<span>'+labels[route]+'</span>';button.setAttribute('aria-label',labels[route]);button.onclick=()=>go(route);N.appendChild(button)});
      N.querySelectorAll('[data-v]').forEach(button=>{if(!order.includes(button.dataset.v))button.remove()});
    }

    function decorateMobile(){
      const nav=document.getElementById('dx1MobileNav');if(!nav)return;const routes=[['Dashboard','Início'],['Fluxo Diário','Fluxo'],['Despesas','Despesas'],['Patrimônio','Bens'],['Atualizações','Ações']];nav.innerHTML=routes.map(([route,label])=>'<button type="button" data-mobile-route="'+route+'" class="'+(V===route?'active':'')+'">'+icon(route)+'<span>'+label+'</span></button>').join('');nav.querySelectorAll('[data-mobile-route]').forEach(button=>button.onclick=()=>go(button.dataset.mobileRoute));
    }

    function stampBrand(){
      document.querySelectorAll('.brand small').forEach(node=>{if(node.textContent.trim()!=='V165 · Homologação')node.innerHTML='<b>V165</b> · Homologação'});
    }

    function preserveBrand(){
      stampBrand();
      if(window.__LTS_V165_FLOW_ROUTE_WRAPPED||typeof window.__LTS_V162_ROUTE_FLOW!=='function')return;
      const routeFlow=window.__LTS_V162_ROUTE_FLOW;window.__LTS_V162_ROUTE_FLOW=function(){const result=routeFlow.apply(this,arguments);stampBrand();return result};window.__LTS_V165_FLOW_ROUTE_WRAPPED=true;
    }

    function bind(){
      const authenticated=Boolean(D)&&!N.classList.contains('hidden');document.body.classList.toggle('v165-authenticated',authenticated);document.body.classList.add('v165-ready');decorateMobile();
      document.querySelectorAll('[data-v165-go]').forEach(button=>button.onclick=()=>go(button.dataset.v165Go,button.dataset.v165Tab));
      document.querySelectorAll('[data-v165-expense-tab]').forEach(button=>button.onclick=()=>{state.expenseTab=button.dataset.v165ExpenseTab;render()});
      document.querySelectorAll('[data-v165-wealth-tab]').forEach(button=>button.onclick=()=>{state.wealthTab=button.dataset.v165WealthTab;render()});
      document.querySelectorAll('[data-v165-expense-range]').forEach(button=>button.onclick=()=>{if(typeof ex135SetRange==='function')ex135SetRange(button.dataset.v165ExpenseRange)});
      document.querySelectorAll('[data-v165-month]').forEach(button=>button.onclick=()=>{if(button.dataset.v165Month&&typeof ex135OpenMonth==='function'){state.expenseTab='transactions';ex135OpenMonth(button.dataset.v165Month)}});
      document.querySelectorAll('[data-v165-award-save]').forEach(button=>button.onclick=()=>saveAnticipation(button.dataset.v165AwardSave));
      const input=document.getElementById('v165SearchInput');if(input)input.oninput=event=>scheduleSearch(event.target.value);
      const refresh=document.getElementById('v165Refresh');if(refresh)refresh.onclick=refreshDashboard;
      preserveBrand();
      const badge=window.parent.document.getElementById('scope');if(badge)badge.textContent=VERSION+' · '+(V==='Fluxo Diário'?'Fluxo de caixa':V)+' · Homologação';
    }

    dashboard=dashboardV165;despesas=despesasV165;patrimonio=patrimonioV165;atualizacoes=atualizacoesV165;
    renderNav=function(){if(D&&!status.authenticated_started){V='Dashboard';status.authenticated_started=true}if(V==='Planejamento')V='Dashboard';if(V==='Cartões'){V='Despesas';state.expenseTab='cards'}original.renderNav();decorateNav()};
    render=function(){if(V==='Planejamento')V='Dashboard';if(V==='Cartões'){V='Despesas';state.expenseTab='cards'}const value=original.render();bind();return value};

    if(D&&!N.classList.contains('hidden')){V='Dashboard';status.authenticated_started=true;renderNav();render()}else bind();
  }

  function frame(){
    try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!d.documentElement||!String(w.location.pathname||'').endsWith('/index.html'))return null;return {w,d}}catch(_){return null}
  }

  function install(){
    const current=frame();if(!current)return false;
    if(!current.w.__LTS_V162_FLOW_RECOVERY_STATUS?.installed||!current.w.__LTS_EXPENSE_SCREEN_ALIGNMENT?.installed||!current.w.__LTS_DASHBOARD_EXECUTIVE_STATUS?.installed)return false;
    if(!current.w.__LTS_EXECUTIVE_VISUAL_SYSTEM_V2?.installed&&!current.d.getElementById('lts-executive-visual-system-v2-runtime')){const script=current.d.createElement('script');script.id='lts-executive-visual-system-v2-runtime';script.textContent='('+visualRuntime.toString()+')();';(current.d.head||current.d.documentElement).appendChild(script)}
    const ready=current.w.__LTS_EXECUTIVE_VISUAL_SYSTEM_V2?.installed===true;
    if(ready){
      current.d.querySelectorAll('.brand small').forEach(node=>{if(node.textContent.trim()!=='V165 · Homologação')node.innerHTML='<b>V165</b> · Homologação'});
      if(gate)gate.hidden=true;
    }
    return ready;
  }

  function burst(){const current=++generation;let attempt=0;function step(){if(current!==generation)return;const ready=install();attempt+=1;if(!ready&&attempt<240)setTimeout(step,100)}step();[300,700,1400,2800,5200,9000,15000,22000].forEach(delay=>setTimeout(()=>{if(current===generation)install()},delay))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();
  window.__LTS_TOP_CANDIDATE_VERSION='v165-executive-ux-rsu';
  window.__LTS_V165_STATUS={contract:CONTRACT,source_candidate:'index.html',public_index_changed:false,financial_writers_changed:false,routes:['Dashboard','Fluxo Diário','Despesas','Patrimônio','Atualizações'],reference_sha256:'0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b'};
})();

;
;
/* LTS V384: lts-v166-feedback-closure.js */
(function(){
  'use strict';
  const outer=document.getElementById('shell'),gate=document.getElementById('gate'),scope=document.getElementById('scope');let generation=0;
  function runtime(){
    'use strict';
    if(window.__LTS_V166_FEEDBACK?.installed||!window.__LTS_EXECUTIVE_VISUAL_SYSTEM_V2?.installed)return;
    const original={dashboard,despesas,patrimonio,atualizacoes,render,renderNav};
    const v165=window.__LTS_V165_STATE||{};
    const st=window.__LTS_V166_STATE||(window.__LTS_V166_STATE={recurring:null,recurringLoading:false,expense:null,expenseLoading:false,invoices:null,invoicesLoading:false,horizon:null,horizonLoading:false});
    const status=window.__LTS_V166_FEEDBACK={installed:true,version:'v166',v165_preserved:true,flow_1409_preserved:true,financial_writers:['lts_browser_flow_mutate_v2','lts_browser_create_future_event_v1','lts_browser_save_award_assumption_v1'],cash_rsu_available_date_contract:true,public_index_changed:false};
    const num=v=>v===null||v===undefined||v===''?null:(Number.isFinite(Number(v))?Number(v):null);
    const arr=v=>Array.isArray(v)?v:[];
    const e=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
    const money=v=>num(v)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',maximumFractionDigits:2}).format(Number(v));
    const date=v=>{const p=String(v||'').slice(0,10).split('-');return p.length===3?p.reverse().join('/'):'—'};
    const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
    const add=(iso,days)=>{const d=new Date(iso+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+days);return d.toISOString().slice(0,10)};
    async function rpc(name,args){const {data,error}=await S.rpc(name,args||{});if(error||!data)throw Error(error?.message||name+' indisponível');return data}
    function toast2(message){if(typeof toast==='function')toast(message);else alert(message)}
    function ensureStyle(){if(document.getElementById('lts-v166-feedback-css'))return;const l=document.createElement('link');l.id='lts-v166-feedback-css';l.rel='stylesheet';l.href='lts-v166-feedback-closure.css?v=20260916-v166';document.head.appendChild(l)}

    async function loadRecurring(){if(st.recurring||st.recurringLoading)return;st.recurringLoading=true;try{st.recurring=await rpc('lts_browser_recurring_future_gap_audit_v4',{p_as_of:today()})}catch(error){st.recurring={error:String(error?.message||error),items:[]}}finally{st.recurringLoading=false;if(V==='Atualizações')render()}}
    async function loadExpense(){if(st.expense||st.expenseLoading)return;st.expenseLoading=true;try{st.expense=await rpc('lts_browser_expense_executive_v3',{p_from:today().slice(0,4)+'-01-01',p_to:today()})}catch(error){st.expense={error:String(error?.message||error)}}finally{st.expenseLoading=false;if(V==='Dashboard')render()}}
    async function loadInvoices(){if(st.invoices||st.invoicesLoading)return;st.invoicesLoading=true;try{const x=await rpc('lts_browser_transactions_v2',{p_from:'2013-10-10',p_to:null,p_query:'fatura',p_direction:null,p_account:null,p_limit:250,p_offset:0});st.invoices=arr(x.rows)}catch(error){st.invoices=[]}finally{st.invoicesLoading=false;if(V==='Despesas'&&v165.expenseTab==='cards')render()}}
    async function loadHorizon(){if(st.horizon||st.horizonLoading)return;st.horizonLoading=true;try{const x=await rpc('lts_browser_flow_v241',{p_from:today(),p_to:(Number(today().slice(0,4))+1)+'-12-31'}),days=arr(x?.flow?.current_future?.days);const ends=[today(),today().slice(0,4)+'-12-31',(Number(today().slice(0,4))+1)+'-03-31',(Number(today().slice(0,4))+1)+'-06-30',(Number(today().slice(0,4))+1)+'-09-30',(Number(today().slice(0,4))+1)+'-12-31'];st.horizon=ends.map(target=>days.find(d=>d.date===target)||days.filter(d=>d.date<=target).slice(-1)[0]).filter(Boolean).map(d=>({date:d.date,base:num(d.fix86_columns?.saldo_apos_d0_1),vested:num(d.fix86_columns?.saldo_apos_rsu)}))}catch(error){st.horizon=[]}finally{st.horizonLoading=false;if(V==='Dashboard')render()}}

    function modal(title,subtitle,body,actions){document.getElementById('v166Modal')?.remove();const bg=document.createElement('div');bg.className='v166-modal-bg';bg.id='v166Modal';bg.innerHTML='<div class="v166-modal" role="dialog" aria-modal="true"><h3>'+e(title)+'</h3><p>'+e(subtitle)+'</p>'+body+'<div id="v166ModalError" class="v166-error" hidden></div><div class="v166-modal-actions"><button type="button" data-v166-close>Fechar</button>'+actions+'</div></div>';document.body.appendChild(bg);const close=()=>bg.remove();bg.onclick=x=>{if(x.target===bg)close()};bg.querySelector('[data-v166-close]').onclick=close;return bg}
    function showError(bg,message){const out=bg.querySelector('#v166ModalError');out.hidden=false;out.textContent=message}

    function openInFlow(row){V='Fluxo Diário';renderNav();render();setTimeout(()=>{const year=document.getElementById('fvYear');if(year){year.value=String(row.date||row.event_date).slice(0,4);year.dispatchEvent(new Event('change',{bubbles:true}))}},120)}
    async function openTransaction(row){
      let info=null;try{info=await rpc('lts_browser_flow_event_editor_v1',{p_source:row.source,p_source_ref:String(row.source_ref||''),p_event_date:String(row.date||row.event_date).slice(0,10)})}catch(error){toast2('Não foi possível abrir este lançamento agora.');return}
      if(!info?.editable){if(String(row.date||row.event_date).slice(0,10)>=today()){toast2('Este lançamento é ajustado no Fluxo. Abrindo a data correspondente.');openInFlow(row);return}const bg=modal('Lançamento histórico protegido','Fatos conciliados não são sobrescritos. A correção deve ser registrada como ajuste auditável.','<div class="v166-note">'+e(info?.reason||'Este lançamento já é um fato histórico conciliado.')+'</div>','');return bg}
      const body='<div class="v166-form"><label>Data<input id="v166TxDate" type="date" value="'+e(String(info.event_date||row.date).slice(0,10))+'"></label><label>Valor<input id="v166TxAmount" inputmode="decimal" value="'+e(String(info.display_amount??info.amount??row.amount??''))+'"></label><label class="wide">Descrição<input id="v166TxDesc" value="'+e(info.description||row.description||'')+'"></label><label class="wide">Conta<select id="v166TxAccount">'+['Itau','Itaú','Bradesco','C6'].map(a=>'<option '+(a===(info.account||row.account)?'selected':'')+'>'+e(a)+'</option>').join('')+'</select></label></div><div class="v166-note">Editar substitui a projeção sem apagar a origem. Cancelar registra uma reversão auditável.</div>';
      const bg=modal('Editar lançamento','Altere a data ou o valor e confirme.',''+body,'<button type="button" class="danger" data-v166-cancel>Cancelar previsão</button><button type="button" class="primary" data-v166-save>Salvar alteração</button>');
      const mutate=async action=>{const raw=bg.querySelector('#v166TxAmount').value.replace(/\./g,'').replace(',','.'),payload={event_date:bg.querySelector('#v166TxDate').value,amount:Number(raw),description:bg.querySelector('#v166TxDesc').value.trim(),account:bg.querySelector('#v166TxAccount').value,amount_semantics:info.amount_semantics||'event_amount',flow_intent:action};if(action==='edit'&&(!payload.event_date||!Number.isFinite(payload.amount)||payload.amount<=0||!payload.description)){showError(bg,'Preencha data, valor e descrição.');return}try{await rpc('lts_browser_flow_mutate_v2',{p_action:action,p_source:info.source||row.source,p_source_ref:String(info.source_ref||row.source_ref),p_payload:action==='cancel'?{flow_intent:'cancel'}:payload,p_idempotency_key:['v166',action,row.source,row.source_ref,Date.now()].join(':')});bg.remove();toast2(action==='cancel'?'Previsão cancelada com histórico preservado.':'Lançamento atualizado.');if(v165.search){v165.search.rows=[];v165.search.total=0;v165.search.query=''}render()}catch(error){showError(bg,'Não foi possível salvar: '+String(error?.message||error))}};
      bg.querySelector('[data-v166-save]').onclick=()=>mutate('edit');bg.querySelector('[data-v166-cancel]').onclick=()=>{if(confirm('Cancelar esta previsão e preservar o histórico da alteração?'))mutate('cancel')};
    }

    function nextSuggested(item){let d=String(item.historical_last_date||today()).slice(0,10);const annual=/annual|seasonal/i.test(item.recurrence_pattern||'');do{const x=new Date(d+'T12:00:00Z');annual?x.setUTCFullYear(x.getUTCFullYear()+1):x.setUTCMonth(x.getUTCMonth()+1);d=x.toISOString().slice(0,10)}while(d<today());return d}
    function openProposal(item){const suggested=nextSuggested(item),body='<div class="v166-form"><label>Data sugerida<input id="v166NewDate" type="date" min="'+today()+'" value="'+suggested+'"></label><label>Valor sugerido<input id="v166NewAmount" inputmode="decimal" value="'+e(String(num(item.observed_median_amount_brl)||''))+'"></label><label class="wide">Descrição<input id="v166NewDesc" value="'+e(item.description||item.description_key||'')+'"></label><label>Tipo<select id="v166NewDirection"><option value="saida" '+(item.direction==='expense'?'selected':'')+'>Saída</option><option value="entrada" '+(item.direction==='income'?'selected':'')+'>Entrada</option></select></label><label>Conta<select id="v166NewAccount"><option>Itau</option><option>Bradesco</option><option>C6</option></select></label></div><div class="v166-note">Sugestão baseada na mediana histórica. Nada entra no Fluxo até você confirmar.</div>';const bg=modal(item.description||'Revisar recorrência','Confira a sugestão antes de criar a próxima ocorrência.',body,'<button type="button" class="primary" data-v166-create>Adicionar ao Fluxo</button>');bg.querySelector('[data-v166-create]').onclick=async()=>{const amount=Number(bg.querySelector('#v166NewAmount').value.replace(/\./g,'').replace(',','.'));try{await rpc('lts_browser_create_future_event_v1',{p_date:bg.querySelector('#v166NewDate').value,p_description:bg.querySelector('#v166NewDesc').value,p_amount:amount,p_direction:bg.querySelector('#v166NewDirection').value,p_account:bg.querySelector('#v166NewAccount').value,p_category:item.category||null});bg.remove();st.recurring=null;toast2('Lançamento futuro adicionado ao Fluxo.');loadRecurring()}catch(error){showError(bg,'Não foi possível adicionar: '+String(error?.message||error))}}}

    function actions(){const recurring=arr(st.recurring?.items).filter(x=>['planning_review','reconciliation_review'].includes(x.review_kind)),cockpit=arr(D?.dashboard_cockpit?.work?.top_actions);return [...cockpit.map(x=>({...x,origin:'cockpit'})),...recurring.map(x=>({...x,origin:'recurring',title:x.description,detail:x.review_kind==='planning_review'?'Histórico recorrente sem previsão futura.':'Possível recorrência ou transferência a reconciliar.',impact_amount:x.observed_median_amount_brl}))]}
    function decorateUpdates(){const root=document.querySelector('.v165-updates');if(!root)return;loadRecurring();const xs=actions(),kpis=root.querySelector('.v165-update-kpis');if(kpis)kpis.innerHTML='<div><span>Ações abertas</span><b>'+xs.length+'</b></div><div><span>Recorrências a revisar</span><b>'+arr(st.recurring?.items).filter(x=>x.review_kind==='planning_review').length+'</b></div><div><span>Classificações pendentes</span><b>'+((num(D?.semantic_review?.pending_groups)||0)+(num(D?.card_classification_review?.pending_groups)||0))+'</b></div>';const cards=[...root.querySelectorAll('.v165-card')],priority=cards.find(c=>/O que precisa de você/i.test(c.textContent||''));if(priority){priority.querySelector('.v165-count')?.replaceChildren(document.createTextNode(String(xs.length)));const host=priority.querySelector('.v165-tasks');if(host)host.innerHTML=xs.length?'<div class="v166-actions">'+xs.map((x,i)=>'<div class="v166-action"><i>'+(i+1)+'</i><div><b>'+e(x.title||'Revisar')+'</b><small>'+e(x.detail||x.review_reason||'')+'</small>'+(num(x.impact_amount)!=null?'<strong>Referência '+money(Math.abs(num(x.impact_amount)))+'</strong>':'')+'</div><button class="v165-btn secondary" data-v166-action="'+i+'">'+(x.origin==='recurring'?'Revisar sugestão':'Abrir')+'</button></div>').join('')+'</div>':'<div class="v165-empty">Nenhuma ação operacional aberta.</div>';host.querySelectorAll('[data-v166-action]').forEach(b=>b.onclick=()=>{const x=xs[Number(b.dataset.v166Action)];if(x.origin==='recurring')openProposal(x);else{v165.search.query=x.card_name||x.title||'';const input=document.getElementById('v165SearchInput');if(input){input.value=v165.search.query;input.dispatchEvent(new Event('input',{bubbles:true}));input.scrollIntoView({behavior:'smooth',block:'center'})}}})}
      decorateSearch();
    }

    function decorateSearch(){const rows=arr(v165.search?.rows),els=document.querySelectorAll('.v165-searchrow');els.forEach((el,i)=>{if(el.querySelector('.v166-search-actions'))return;const row=rows[i];if(!row)return;const box=document.createElement('div');box.className='v166-search-actions';const future=row.future===true||String(row.date||row.event_date)>=today();box.innerHTML='<button type="button" class="primary" '+(future?'':'disabled')+'>'+(future?'Editar':'Histórico protegido')+'</button><button type="button">Abrir no Fluxo</button>';box.firstElementChild.onclick=()=>future&&openTransaction(row);box.lastElementChild.onclick=()=>openInFlow(row);el.querySelector('div')?.appendChild(box)})}
    let searchDecorationQueued=false;
    const searchObserver=new MutationObserver(()=>{if(V!=='Atualizações'||searchDecorationQueued)return;searchDecorationQueued=true;requestAnimationFrame(()=>{searchDecorationQueued=false;decorateSearch()})});
    searchObserver.observe(document.body,{childList:true,subtree:true});

    function decorateExpense(){const root=document.querySelector('.v165-expenses');if(!root)return;const s=typeof ex135State==='function'?ex135State():{},period=root.querySelector('.v165-pagehead p');if(period&&s.data?.period)period.textContent='Análise de '+date(s.data.period.from)+' a '+date(s.data.period.to)+' — os botões atualizam todo o relatório.';const quality=[...root.querySelectorAll('.v165-card')].find(c=>/O que está classificado/i.test(c.textContent||''));if(quality)quality.innerHTML='<div class="v165-cardhead"><div><span>Leitura dos dados</span><h2>Base pronta para análise</h2></div></div><div class="v166-clean-coverage"><div><b>Categorias revisadas</b><span>Os grupos disponíveis já podem ser comparados.</span></div><div><b>Histórico preservado</b><span>Faturas antigas sem itens mantêm o total, sem inventar compras.</span></div></div>';if(v165.expenseTab==='cards'){loadInvoices();let panel=root.querySelector('#v166Invoices');if(!panel){panel=document.createElement('article');panel.id='v166Invoices';panel.className='v165-card';root.appendChild(panel)}const rows=arr(st.invoices);panel.innerHTML='<div class="v165-cardhead"><div><span>Faturas</span><h2>Histórico considerado no Fluxo</h2></div><small>'+rows.length+' lançamentos encontrados</small></div><div class="v166-invoices">'+rows.slice(0,80).map((x,i)=>'<div class="v166-invoice"><span>'+date(x.date)+'</span><div><b>'+e(x.description||'Fatura')+'</b><small>'+e(x.account||'')+' · '+e(x.category||'')+'</small></div><strong>'+money(x.amount)+'</strong><button class="v166-inline-btn" data-v166-invoice="'+i+'">'+(x.future?'Editar':'Ver')+'</button></div>').join('')+'</div>';panel.querySelectorAll('[data-v166-invoice]').forEach(b=>b.onclick=()=>openTransaction(rows[Number(b.dataset.v166Invoice)]))}}

    function horizonSvg(rows){if(rows.length<2)return'';const vals=rows.flatMap(x=>[x.base,x.vested]).filter(x=>num(x)!=null),lo=Math.min(0,...vals),hi=Math.max(0,...vals),span=Math.max(1,hi-lo),W=720,H=230,p={l:42,r:16,t:15,b:35},x=i=>p.l+i*(W-p.l-p.r)/Math.max(1,rows.length-1),y=v=>p.t+(hi-v)/span*(H-p.t-p.b),path=k=>rows.map((r,i)=>(i?'L':'M')+x(i).toFixed(1)+' '+y(num(r[k])||0).toFixed(1)).join(' ');return '<div class="v166-horizon"><svg viewBox="0 0 '+W+' '+H+'"><line class="zero" x1="'+p.l+'" x2="'+(W-p.r)+'" y1="'+y(0)+'" y2="'+y(0)+'"/><path d="'+path('base')+'"/><path class="vest" d="'+path('vested')+'"/>'+rows.map((r,i)=>'<text x="'+x(i)+'" y="'+(H-9)+'" text-anchor="middle">'+e(String(r.date).slice(5,7)+'/'+String(r.date).slice(2,4))+'</text>').join('')+'</svg><div class="v166-period-label">Horizonte: ano atual + ano seguinte · azul sem novos vestings · verde com awards disponíveis</div></div>'}
    function decorateDashboard(){/* V179 owns the current reports; V166 must not start hidden reads. */const card=document.querySelector('.liquidity-card');if(card&&st.horizon?.length){const old=card.querySelector('.v165-chart');if(old)old.outerHTML=horizonSvg(st.horizon)}const empty=[...document.querySelectorAll('.v165-dashboard .v165-empty')].find(x=>/Sem composição/i.test(x.textContent||''));if(empty){const top=arr(st.expense?.rolling_windows?.['6m']?.top_categories);if(top.length)empty.outerHTML='<div class="v165-rank">'+top.slice(0,5).map(x=>'<div class="v165-rankrow"><div><b>'+e(x.category||x.name||'Outros')+'</b></div><i><u style="width:70%"></u></i><strong>'+money(x.total)+'</strong></div>').join('')+'</div>'}}

    function wealthData(){return v165.wealth?.data||{}}
    function decorateWealth(){const j=wealthData();if(v165.wealthTab==='rsu'){const root=document.querySelector('.v165-wealth');const first=root?.querySelector('.v165-kpis');const pos=arr(j.rsu?.vested_positions)[0]||{},meta=pos.metadata||{},cash=num(pos.brokerage_cash_brl??pos.cash_brl??meta.brokerage_cash_brl??j.rsu?.brokerage_cash_brl),shares=num(pos.shares_value_brl??meta.shares_value_brl??pos.value_brl),total=num(pos.available_total_brl??meta.available_total_brl)??((shares||0)+(cash||0));if(first&&!root.querySelector('.v166-rsu-split'))first.insertAdjacentHTML('afterend','<div class="v166-rsu-split"><div><span>Ações já adquiridas</span><b>'+money(shares)+'</b><small>'+e(pos.units!=null?Number(pos.units).toLocaleString('pt-BR',{maximumFractionDigits:3})+' ações':'posição documentada')+'</small></div><div><span>Saldo em corretora</span><b>'+money(cash)+'</b><small>separado das ações</small></div><div><span>Total disponível na corretora</span><b>'+money(total)+'</b><small>posição atual</small></div></div>');const awards=arr(j.rsu?.future_schedule);document.querySelectorAll('.v165-award').forEach((row,i)=>{if(row.querySelector('.v166-award-edit')||!awards[i])return;const b=document.createElement('button');b.className='v166-inline-btn v166-award-edit';b.textContent='Editar cotação e câmbio';b.onclick=()=>openAward(awards[i]);row.appendChild(b)})}if(v165.wealthTab==='assets'){const root=document.querySelector('.v165-wealth');root?.querySelectorAll('.v165-liqrow').forEach((row,i)=>{if(/cipo[_ ]?396/i.test(row.textContent||'')&&i>0)row.remove()});const cipo=[...root?.querySelectorAll('.asset-detail')||[]].find(x=>/CIPÓ 396/i.test(x.textContent||''));if(cipo&&!cipo.querySelector('[data-v166-cipo]'))cipo.insertAdjacentHTML('beforeend','<button type="button" class="v165-btn secondary" data-v166-cipo>Ver gastos detalhados da obra</button>');cipo?.querySelector('[data-v166-cipo]')?.addEventListener('click',openCipo);const list=j.wealth?.scheduled_commitments_not_counted_as_current_debt||[];if(list.length&&!root.querySelector('#v166FamilyLoan')){const card=[...root.querySelectorAll('.v165-card')].find(x=>/Saídas futuras/i.test(x.textContent||''));card?.insertAdjacentHTML('beforeend','<div id="v166FamilyLoan">'+list.map(x=>'<div class="v165-liqrow"><span>'+e(x.id==='pai_mae'?'Empréstimo pai e mãe':x.label||x.name||x.id||'Compromisso futuro')+'</span><b>'+money(x.amount??x.total??x.future_schedule_total)+'</b><em>compromisso futuro</em></div>').join('')+'</div>')}}}
    function openAward(a){const id=a.group_key,body='<div class="v166-form"><label>Preço da ação (USD)<input id="v166AwardPrice" inputmode="decimal" value="'+e(String(a.unit_price_usd??''))+'"></label><label>Câmbio USD/BRL<input id="v166AwardFx" inputmode="decimal" value="'+e(String(a.fx_rate??''))+'"></label></div><div class="v166-note">RSU normal usa 100%. Cash RSU usa 70% líquido após a reserva de 30% para imposto.</div>';const bg=modal('Editar premissas da RSU',date(a.eligibility_date)+' · '+(a.asset_type||'RSU'),body,'<button type="button" class="primary" data-v166-award-save>Salvar premissas</button>');bg.querySelector('[data-v166-award-save]').onclick=async()=>{const parse=id=>Number(bg.querySelector(id).value.replace(',','.'));try{await rpc('lts_browser_save_award_assumption_v1',{p_group_key:id,p_unit_price_usd:parse('#v166AwardPrice'),p_fx_rate:parse('#v166AwardFx')});bg.remove();v165.wealth.loaded=false;v165.wealth.data=null;toast2('Premissas atualizadas e Fluxo recalculável.');render()}catch(error){showError(bg,'Não foi possível salvar: '+String(error?.message||error))}}}
    function openCipo(){const j=wealthData(),rows=arr(j.cipo?.components),c=j.wealth?.assets?.cipo_396||{},body='<div class="v166-cipo-list">'+(rows.length?rows.map(x=>'<div class="v166-cipo-row"><span>'+e(x.label||x.category||x.name||'Item')+'</span><b>'+money(x.amount??x.value_brl??x.total)+'</b></div>').join(''):'<div class="v166-note">O total histórico de compra e reforma é '+money(c.historical_purchase_plus_reform)+'. O detalhamento documental ainda não foi recebido por este leitor.</div>')+'</div>';modal('CIPÓ 396 · compra e obra','Detalhamento do investimento preservado na base.',body,'')}

    function stamp(){document.querySelectorAll('.brand small').forEach(n=>n.innerHTML='<b>V166</b> · Homologação');const badge=window.parent.document.getElementById('scope');if(badge)badge.textContent='V166 · '+(V==='Fluxo Diário'?'Fluxo de caixa':V)+' · Homologação'}
    function decorate(){ensureStyle();stamp();if(V==='Atualizações')decorateUpdates();if(V==='Despesas')decorateExpense();if(V==='Dashboard')decorateDashboard();if(V==='Patrimônio')decorateWealth();decorateSearch()}
    render=function(){const out=original.render();decorate();return out};
    renderNav=function(){const out=original.renderNav();stamp();return out};
    dashboard=original.dashboard;despesas=original.despesas;patrimonio=original.patrimonio;atualizacoes=original.atualizacoes;
    if(D&&!N.classList.contains('hidden'))render();
  }
  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return null;return{w,d}}catch{return null}}
  function install(){const f=frame();if(!f)return false;f.d.querySelectorAll('.brand small').forEach(n=>n.innerHTML='<b>V166</b> · Homologação');if(scope)scope.textContent='V166 · Homologação';if(!f.w.__LTS_EXECUTIVE_VISUAL_SYSTEM_V2?.installed)return false;if(!f.w.__LTS_V166_FEEDBACK?.installed&&!f.d.getElementById('lts-v166-feedback-runtime')){const s=f.d.createElement('script');s.id='lts-v166-feedback-runtime';s.textContent='('+runtime.toString()+')();';(f.d.head||f.d.documentElement).appendChild(s)}const ready=f.w.__LTS_V166_FEEDBACK?.installed===true;if(ready&&gate)gate.hidden=true;return ready}
  function burst(){const current=++generation;let n=0;function step(){if(current!==generation)return;const ok=install();n++;if(!ok&&n<260)setTimeout(step,100)}step();[400,900,1800,3600,7000,12000,20000].forEach(ms=>setTimeout(()=>{if(current===generation)install()},ms))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();window.__LTS_TOP_CANDIDATE_VERSION='v166-feedback-closure';
})();

;
;
/* LTS V384: lts-v333-actions-model.js */
/* Read-only action projection shared by Dashboard and Actions. */
(function(root,factory){
 'use strict';const model=factory();
 if(typeof module==='object'&&module.exports)module.exports=model;
 else root.LTSV333Actions=model;
})(typeof window==='undefined'?globalThis:window,function(){
 'use strict';
 const list=x=>Array.isArray(x)?x:[];
 const norm=x=>String(x||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim();
 const names={aeternum:'Visa Aeternum',bradesco_prime:'Visa Infinite Prime',itau_mastercard:'Mastercard Black',itau_visa:'Visa Infinite',c6:'C6 Carbon'};
 const date=x=>/^\d{4}-\d{2}-\d{2}$/.test(x||'')?x.split('-').reverse().join('/'):null;
 function build({recurring,cockpit,cards,asOf,error=false}){
  const items=[],seen=new Set();
  const push=x=>{const key=x.action_key||norm(x.title||x.description);if(key&&!seen.has(key)){seen.add(key);items.push(x);}};
  // Legacy cached card tasks describe older snapshots. Only the canonical
  // card reader can provide their amount, due date and remaining uncertainty.
  list(cockpit?.work?.top_actions).filter(x=>x.maintenance_kind!=='card_cycle'&&!/confirmar.*fatura|fatura.*(pessoal|black)/i.test(String(x.title||''))).forEach(x=>push({...x,origin:'cockpit'}));
  const end=new Date(asOf+'T12:00:00Z');end.setUTCDate(end.getUTCDate()+60);
  const limit=Number.isFinite(end.valueOf())?end.toISOString().slice(0,10):asOf;
  for(const card of list(cards?.cards)){
   const cycles=list(card.cycles).filter(c=>c.settlement_confirmed!==true&&c.basis!=='open_finance_invoice_v263'&&
    (c.due_date?c.due_date>=asOf&&c.due_date<=limit:String(c.month||c.reference_month||'')>=asOf.slice(0,7)+'-01'&&String(c.month||c.reference_month||'')<=limit))
    .slice().sort((a,b)=>String(a.month||a.reference_month||'').localeCompare(String(b.month||b.reference_month||'')));
   const cycle=cycles[0];if(!cycle)continue;
   const month=cycle.month||cycle.reference_month,label=names[card.family]||card.name||card.card_name||'Cartão';
   const valid=cycle.amount!==null&&cycle.amount!==undefined&&Number.isFinite(Number(cycle.amount))&&cycle.complete!==false;
   push({action_key:'card|'+card.family+'|'+month,origin:'card',family:card.family,month,
    title:label+' · '+String(month||'').slice(5,7)+'/'+String(month||'').slice(0,4),
    detail:(date(cycle.due_date)?'Vencimento previsto: '+date(cycle.due_date)+'. ':'Vencimento a confirmar. ')+
     (valid?'O total oficial da fatura ainda não foi recebido.':'Há compras cujo ciclo ou valor precisa ser conferido.'),
    impact_amount:valid?Number(cycle.amount):null});
  }
  const checks=list(recurring?.horizon_checks),knownKeys=new Set(checks.flatMap(x=>[norm(x.key),norm(x.description_key),norm(x.description),norm(x.title)]));
  checks.filter(x=>['planning_review','reconciliation_review'].includes(x.review_kind)).forEach(x=>{
   const gaps=list(x.missing_months),first=gaps[0]||list(x.missing_years)[0],last=gaps.at(-1)||list(x.missing_years).at(-1);
   push({...x,action_key:'recurring|'+(x.key||norm(x.title)),title:x.title||x.description,
    detail:(gaps.length||list(x.missing_years).length?'Período sem previsão: '+first+(first!==last?' a '+last:'')+'. ':'')+
     (x.awaiting_payment_evidence_count?'Há pagamento a confirmar. ':'')+
     (x.historical_last_date?'Último realizado: '+date(x.historical_last_date)+'. ':'')+'Revise a vigência e a continuidade da série.',
    impact_amount:null,origin:'recurring'});
  });
  list(recurring?.items).filter(x=>['planning_review','reconciliation_review'].includes(x.review_kind)&&!knownKeys.has(norm(x.description_key||x.description))).forEach(x=>push({...x,title:x.description||x.description_key,
   detail:x.review_kind==='planning_review'?'Verifique valor e próximas ocorrências.':'Movimento recorrente para conciliar.',impact_amount:x.observed_median_amount_brl,origin:'recurring'}));
  return {items,ready:!!recurring&&Array.isArray(cards?.cards)&&!error,error:!!error};
 }
 return Object.freeze({build});
});

;
;
/* LTS V384: lts-v183-v168-feedback-safe.js */
(function(){
  'use strict';
  const outer=document.getElementById('shell'),gate=document.getElementById('gate'),scope=document.getElementById('scope');
  let generation=0;

  function runtime(){
    'use strict';
    const v233Formatters=[new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',maximumFractionDigits:2}),new Intl.DateTimeFormat('pt-BR',{month:'short',year:'2-digit'}),new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}),new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',notation:'compact',maximumFractionDigits:1})];

    if(window.__LTS_V168_COMPLETE_REVIEW?.installed||!window.__LTS_V166_FEEDBACK?.installed)return;
    const baseRender=render,baseNav=renderNav;
    const st=window.__LTS_V168_STATE||(window.__LTS_V168_STATE={
      dashboard:{loading:false,started:false,token:0,pending:0,data:null,error:null,detailErrors:[]},
      expense:{key:'ytd',tab:'overview',loading:false,token:0,data:null,context:null,error:null,customFrom:'',customTo:''},
      wealth:{tab:'overview',loading:false,data:null,error:null},
      updates:{loading:false,recurring:null,openFinance:null,error:null},
      invoices:{loading:false,rows:null,display:[],error:null},
      transactions:{loading:false,token:0,rangeKey:'',rows:null,error:null,count:null,total:null,revision:null,detail:null,pageIndex:0},
      search:{query:'',loading:false,rows:[],total:0,error:null,seq:0,timer:null},
      nl:{draft:'',preview:null,key:null,busy:false,error:'',message:''}
    });
    window.__LTS_V168_COMPLETE_REVIEW={installed:true,version:'v168',routes:['Dashboard','Fluxo Diário','Despesas','Patrimônio','Atualizações'],reliable_progressive_reads:true,expense_periods_live:true,expense_custom_period:true,expense_hierarchical_drilldown:true,wealth_pensions:true,financing_drilldown:true,exact_flow_navigation:true,guided_statement_upload:true,reviewed_text_input:true,historical_balance_truth:true,public_index_changed:false};

    const arr=v=>Array.isArray(v)?v:[];
    const num=v=>v===null||v===undefined||v===''?null:(Number.isFinite(Number(v))?Number(v):null);
    const esc=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
    const norm=s=>String(s??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
    const money=v=>num(v)==null?'—':v233Formatters[0].format(Number(v));
    const number=v=>num(v)==null?'—':Number(v).toLocaleString('pt-BR',{maximumFractionDigits:3});
    const usd=v=>num(v)==null?'—':'US$ '+Number(v).toLocaleString('pt-BR',{minimumFractionDigits:2,maximumFractionDigits:3});
    const fx=v=>num(v)==null?'—':'R$ '+Number(v).toLocaleString('pt-BR',{minimumFractionDigits:4,maximumFractionDigits:5});
    const pct=v=>num(v)==null?'—':Number(v).toLocaleString('pt-BR',{maximumFractionDigits:1})+'%';
    const humanText=s=>String(s??'').replace(/R\$\s*(-?[\d,]+\.\d{2})(?!\d)/g,(_,raw)=>money(Number(raw.replace(/,/g,''))));
    const date=v=>{const p=String(v||'').slice(0,10).split('-');return p.length===3?p.reverse().join('/'):'—'};
    const month=v=>{const key=String(v||'').slice(0,7);if(!/^\d{4}-\d{2}$/.test(key))return key||'—';return v233Formatters[1].format(new Date(key+'-01T12:00:00')).replace('.','')};
    const today=()=>v233Formatters[2].format(new Date());
    const addMonths=(iso,n)=>{const d=new Date(iso+'T12:00:00Z');d.setUTCMonth(d.getUTCMonth()+n);return d.toISOString().slice(0,10)};
    const addDays=(iso,n)=>{const d=new Date(iso+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10)};
    const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
    function effectiveRows(value){const now=today();return arr(value).filter(x=>x.source!=='evento_usuario').map(x=>{const y={...x};if(y.account==='Itau')y.account='Itaú';if(y.source==='evento_base'){y.source='legacy_fix86';y.source_ref='evento_base:'+String(y.source_ref||'');y.editable=String(y.date||y.event_date)>=now}else y.editable=y.source==='current_event'&&y.confidence==='user_flow_editable';return y})}
    async function rpc(name,args){const {data,error}=await S.rpc(name,args||{});if(error||data==null)throw Error(error?.message||name+' indisponível');return data}
    const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
    async function rpcRead(name,args,retries=2,isCurrent=()=>true){let last;for(let attempt=0;attempt<=retries;attempt++){if(!isCurrent())throw Error('Leitura substituída por outra sessão.');try{const data=await rpc(name,args);if(!isCurrent())throw Error('Leitura substituída por outra sessão.');return data}catch(error){last=error;if(!isCurrent())throw error;if(attempt<retries)await pause(180*(attempt+1))}}throw last}
    function toast2(msg){if(typeof toast==='function')toast(msg);else alert(msg)}
    function ensureStyle(){if(document.getElementById('lts-v168-css'))return;const l=document.createElement('link');l.id='lts-v168-css';l.rel='stylesheet';l.href='lts-v168-feedback-package.css?v=20260917-v168a';document.head.appendChild(l)}
    function refresh(route){if(V===route)render()}
    function release(){return '<span class="v168-release">V168 · Homologação</span>'}
    function sourceLabel(value){return '<span class="v168-source"><i></i>Dados até '+date(value)+'</span>'}
    function head(kicker,title,subtitle,meta){return '<header class="v168-head"><div><span class="v168-eyebrow">'+esc(kicker)+'</span><h1>'+esc(title)+'</h1><p>'+esc(subtitle)+'</p></div><div class="v168-headmeta">'+(meta||'')+release()+'</div></header>'}
    function kpi(label,value,note,kind){return '<article class="v168-kpi '+(kind||'')+'"><span>'+esc(label)+'</span><strong>'+money(value)+'</strong><small>'+esc(note||'')+'</small></article>'}
    function kpiText(label,value,note,kind){return '<article class="v168-kpi '+(kind||'')+'"><span>'+esc(label)+'</span><strong>'+esc(value??'—')+'</strong><small>'+esc(note||'')+'</small></article>'}
    function tabs(items,active,attr){return '<div class="v168-tabs" role="tablist">'+items.map(x=>'<button type="button" role="tab" aria-selected="'+(active===x[0])+'" class="'+(active===x[0]?'active':'')+'" '+attr+'="'+x[0]+'">'+esc(x[1])+'</button>').join('')+'</div>'}
    function loading(){return '<div class="v168-skeleton" aria-label="Carregando"></div>'}
    function errorBox(x){return '<div class="v168-error">'+esc(x||'Não foi possível carregar esta área agora.')+'</div>'}

    function expenseRange(key){const t=today(),year=t.slice(0,4);if(key==='6m')return{from:addMonths(t,-5).slice(0,8)+'01',to:t,label:'Últimos 6 meses'};if(key==='12m')return{from:addMonths(t,-11).slice(0,8)+'01',to:t,label:'Últimos 12 meses'};if(key==='all')return{from:'2013-10-10',to:t,label:'Desde 2013'};if(key==='custom'&&/^\d{4}-\d{2}-\d{2}$/.test(st.expense.customFrom)&&/^\d{4}-\d{2}-\d{2}$/.test(st.expense.customTo))return{from:st.expense.customFrom,to:st.expense.customTo,label:date(st.expense.customFrom)+' a '+date(st.expense.customTo)};return{from:year+'-01-01',to:t,label:'Ano atual'}}
    function ensureDashboard(force){if(!window.__LTS_V178_REVIEW?.installed)return;const s=st.dashboard;if(s.loading&&!force||s.started&&!force)return;const end=(Number(today().slice(0,4))+4)+'-12-31',from=today().slice(0,4)+'-01-01',token=(s.token||0)+1;s.token=token;s.started=true;s.loading=true;s.error=null;s.detailErrors=[];s.data={...(s.data||{})};if(D?.dashboard_cockpit&&!s.data.cockpit)s.data.cockpit=D.dashboard_cockpit;const jobs=[
        ['cockpit','lts_browser_dashboard_cockpit_v1',{}],
        ['flow','lts_browser_flow_v241',{p_from:today(),p_to:end}],
        ['expense','lts_browser_expense_executive_v4',{p_from:from,p_to:today()}],
        ['expenseContext','lts_browser_expense_context_lens_v1',{p_from:from,p_to:today()}],
        ['wealth','lts_browser_wealth_detail_v3',{}],
        ['recurring','lts_browser_recurring_future_gap_audit_v5',{p_as_of:today(),p_horizon_end:(Number(today().slice(0,4))+4)+'-12-31'}]
      ];s.pending=jobs.length;for(const [key,name,args]of jobs){rpcRead(name,args).then(value=>{if(s.token!==token)return;s.data={...(s.data||{}),[key]:value};if(key==='cockpit'&&D)D.dashboard_cockpit=value;if(key==='recurring')st.updates.recurring=value;refresh('Dashboard')}).catch(()=>{if(s.token!==token)return;s.detailErrors.push(key)}).finally(()=>{if(s.token!==token)return;s.pending=Math.max(0,s.pending-1);if(!s.pending){s.loading=false;if(!s.data?.cockpit&&!s.data?.flow&&!s.data?.expense&&!s.data?.wealth)s.error='Não foi possível atualizar o resumo agora.'}refresh('Dashboard')})}}
    function expenseRangeError(r){const valid=value=>/^\d{4}-\d{2}-\d{2}$/.test(value)&&Number.isFinite(Date.parse(value+'T12:00:00Z'))&&new Date(value+'T12:00:00Z').toISOString().slice(0,10)===value;if(!valid(r.from)||!valid(r.to)||r.from>r.to)return 'Informe um período válido.';if(r.from<'2013-10-10')return 'O histórico de despesas começa em 10/10/2013. O período escolhido foi preservado.';if(r.to>today())return 'Despesas realizadas estão disponíveis até '+date(today())+'. Para datas futuras, consulte o Fluxo Diário. O período escolhido foi preservado.';return null;}
    // Keep editor-only values out of the applied period used by every report/RPC.
    let expenseDraft=null,expenseDraftEpoch=0;
    const expenseDraftGeneration=()=>typeof BOOT!=='undefined'?BOOT.generation:(typeof D!=='undefined'?D:null);
    let expenseReaderOwner={generation:expenseDraftGeneration(),epoch:expenseDraftEpoch};
    function expenseReaderCurrent(owner){return !!owner&&owner.generation===expenseDraftGeneration()&&owner.epoch===expenseDraftEpoch&&!!D}
    function syncExpenseReaders(){
      if(expenseReaderOwner.generation!==expenseDraftGeneration()||expenseReaderOwner.epoch!==expenseDraftEpoch){
        expenseReaderOwner={generation:expenseDraftGeneration(),epoch:expenseDraftEpoch};
        for(const key of ['expense','transactions','invoices']){const s=st[key];if(!s)continue;s.token=(s.token||0)+1;s.loading=false;s.error=null;if(key==='expense'){s.data=null;s.context=null;s.rangeInvalid=false;s.drill=[]}else{s.rows=null;if(key==='transactions'){s.rangeKey='';s.pageIndex=0;s.count=null;s.total=null;s.revision=null;s.detail?.remove();s.detail=null}if(key==='invoices')s.display=[]}}
      }
      return expenseReaderOwner;
    }
    function expenseReadCurrent(key,s,token,owner){return expenseReaderCurrent(owner)&&st[key]===s&&s.token===token}
    const expenseAppliedSignature=()=>JSON.stringify([st.expense.key,st.expense.customFrom,st.expense.customTo]);
    function expenseDraftCurrent(d){return !!d&&d.generation===expenseDraftGeneration()&&d.epoch===expenseDraftEpoch&&d.applied===expenseAppliedSignature()}
    function syncExpenseDraft(){if(expenseDraft&&!expenseDraftCurrent(expenseDraft))expenseDraft=null;return expenseDraft}
    function openExpenseDraft(){syncExpenseDraft();if(!expenseDraft){const r=expenseRange(st.expense.key);expenseDraft={generation:expenseDraftGeneration(),epoch:expenseDraftEpoch,applied:expenseAppliedSignature(),from:r.from,to:r.to,error:null,nodes:{}}}return expenseDraft}
    function readExpenseDraft(){const d=syncExpenseDraft();if(!d)return null;for(const [id,key] of [['v168ExpenseFrom','from'],['v168ExpenseTo','to']]){const input=document.getElementById(id);if(input&&input===d.nodes[key])d[key]=input.value}return d}
    function invalidateExpenseTransactions(){const s=st.transactions;s.token=(s.token||0)+1;s.rangeKey='';s.pageIndex=0;s.loading=false;s.rows=null;s.error=null;s.count=null;s.total=null;s.revision=null;s.detail?.remove();s.detail=null}
    function selectExpensePeriod(key){syncExpenseDraft();if(key==='custom'){if(expenseDraft)return;openExpenseDraft();render();return}expenseDraft=null;if(st.expense.key===key){render();return}st.expense.key=key;st.expense.data=null;st.expense.context=null;invalidateExpenseTransactions();ensureExpense(true);render()}
    function applyExpenseDraft(){const d=readExpenseDraft();if(!d)return;d.error=expenseRangeError(d);if(d.error){render();return}st.expense.key='custom';st.expense.customFrom=d.from;st.expense.customTo=d.to;d.applied=expenseAppliedSignature();st.expense.data=null;st.expense.context=null;invalidateExpenseTransactions();ensureExpense(true);render()}
    function bindExpenseDraft(){
      const generation=expenseDraftGeneration(),epoch=expenseDraftEpoch,current=()=>generation===expenseDraftGeneration()&&epoch===expenseDraftEpoch;
      document.querySelectorAll('[data-v168-exp-range]').forEach(b=>{const key=b.dataset.v168ExpRange;const action={changesPeriod:()=>current()&&key!=='custom'&&st.expense.key!==key,run:()=>{if(current())selectExpensePeriod(key)}};b.__ltsExpenseAction=action;b.onclick=action.run});
      const d=syncExpenseDraft();if(!d)return;
      for(const [id,key] of [['v168ExpenseFrom','from'],['v168ExpenseTo','to']]){const input=document.getElementById(id);if(!input)continue;d.nodes[key]=input;input.oninput=input.onchange=()=>{if(current()&&syncExpenseDraft()===d)d[key]=input.value}}
      const apply=document.getElementById('v168ExpenseApply');if(apply){const action={changesPeriod:()=>current()&&syncExpenseDraft()===d&&!expenseRangeError(readExpenseDraft()),run:()=>{if(current()&&syncExpenseDraft()===d)applyExpenseDraft()}};apply.__ltsExpenseAction=action;apply.onclick=action.run}
    }
    function preserveExpenseDraftControls(){
      const d=readExpenseDraft();if(!d)return null;
      const active=document.activeElement,key=Object.keys(d.nodes).find(k=>d.nodes[k]===active);
      let selection=null;try{if(key&&typeof active.selectionStart==='number')selection=[active.selectionStart,active.selectionEnd,active.selectionDirection]}catch{}
      return{draft:d,active:key,selection};
    }
    function restoreExpenseDraftControls(saved){
      const d=syncExpenseDraft();if(!saved||saved.draft!==d||V!=='Despesas')return;
      // Reuse native date nodes: .value alone loses incomplete date segments.
      for(const [id,key] of [['v168ExpenseFrom','from'],['v168ExpenseTo','to']]){const fresh=document.getElementById(id),prior=d.nodes[key];if(fresh&&prior&&fresh!==prior)fresh.replaceWith(prior)}
      const active=saved.active&&d.nodes[saved.active];if(active?.isConnected){try{active.focus({preventScroll:true});if(saved.selection)active.setSelectionRange(...saved.selection)}catch{}}
    }
    S.auth.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT'||event==='SIGNED_IN'){expenseDraftEpoch++;expenseDraft=null;st.updates.token=(st.updates.token||0)+1;st.updates.loading=false;st.updates.recurring=null;st.updates.openFinance=null;st.updates.error=null;st.dashboard.token=(st.dashboard.token||0)+1;st.dashboard.data=null;st.dashboard.started=false;st.dashboard.loading=false}});
    async function expenseContextWithinBudget(args){let timer;try{return await Promise.race([rpc('lts_browser_expense_context_lens_v1',args),new Promise(resolve=>{timer=setTimeout(()=>resolve(null),12000)})])}catch{return null}finally{clearTimeout(timer)}}
    async function ensureExpense(force){const owner=syncExpenseReaders();if(!expenseReaderCurrent(owner))return;const s=st.expense;if(!force&&(s.loading||s.data||s.error))return;const token=(s.token||0)+1;s.token=token;const r=expenseRange(s.key),invalid=expenseRangeError(r);s.error=invalid;s.rangeInvalid=!!invalid;if(invalid){s.loading=false;return;}s.loading=true;try{const [data,context]=await Promise.all([rpc('lts_browser_expense_executive_v4',{p_from:r.from,p_to:r.to}),expenseContextWithinBudget({p_from:r.from,p_to:r.to})]);if(!expenseReadCurrent('expense',s,token,owner))return;s.data=data;s.context=context}catch(x){if(!expenseReadCurrent('expense',s,token,owner))return;s.error=String(x?.message||x)}finally{if(expenseReadCurrent('expense',s,token,owner)){s.loading=false;refresh('Despesas')}}}
    async function ensureWealth(force){const s=st.wealth;if(s.loading||(!force&&(s.data||s.error)))return;const token=(s.token||0)+1;s.token=token;s.loading=true;s.error=null;try{const data=await rpcRead('lts_browser_wealth_detail_v3');if(s.token===token)s.data=data}catch(x){if(s.token===token)s.error=String(x?.message||x)}finally{if(s.token===token){s.loading=false;refresh('Patrimônio')}}}
    async function ensureUpdates(force){
      syncActionsOwner();const s=st.updates;if(!s.recurring&&st.dashboard.data?.recurring)s.recurring=st.dashboard.data.recurring;
      if(s.loading||(!force&&(s.error||(s.recurring&&s.openFinance))))return;
      const token=(s.token||0)+1,owner=expenseDraftGeneration();s.token=token;s.loading=true;s.error=null;
      const current=()=>s.token===token&&owner===expenseDraftGeneration()&&!!D;
      s.partErrors={};s.pending=2;
      const jobs=[['recurring','lts_browser_recurring_future_gap_audit_v5',{p_as_of:today(),p_horizon_end:(Number(today().slice(0,4))+4)+'-12-31'}],['openFinance','lts_browser_open_finance_status_v1',{}]];
      await Promise.all(jobs.map(async([key,name,args])=>{
        try{
          const value=s[key]&&!force?s[key]:await rpcRead(name,args,1,current);
          if(!current())return;s[key]=value;
          if(key==='recurring'&&st.dashboard.data)st.dashboard.data.recurring=value;
        }catch{if(current())s.partErrors[key]=true;}
        finally{if(current()){
          s.pending=Math.max(0,s.pending-1);s.loading=s.pending>0;
          s.error=Object.keys(s.partErrors).length?'Não foi possível atualizar todas as revisões.':null;
          if(['Dashboard','Atualizações'].includes(V))render();
        }}
      }));
    }

    async function ensureInvoices(force){const owner=syncExpenseReaders();if(!expenseReaderCurrent(owner))return;const s=st.invoices;if(s.loading||(!force&&s.rows))return;const token=(s.token||0)+1;s.token=token;s.loading=true;s.error=null;try{const j=await rpcRead('lts_browser_transactions_v2',{p_from:'2013-10-10',p_to:null,p_query:'fatura',p_direction:null,p_account:null,p_limit:300,p_offset:0},2,()=>expenseReadCurrent('invoices',s,token,owner));if(!expenseReadCurrent('invoices',s,token,owner))return;s.rows=effectiveRows(j.rows)}catch(x){if(!expenseReadCurrent('invoices',s,token,owner))return;s.error=String(x?.message||x);s.rows=[]}finally{if(expenseReadCurrent('invoices',s,token,owner)){s.loading=false;refresh('Despesas')}}}
    async function ensureTransactions(force){
      const owner=syncExpenseReaders();if(!expenseReaderCurrent(owner))return;
      const s=st.transactions,r=expenseRange(st.expense.key),key=r.from+'|'+r.to;
      if(s.rangeKey!==key){invalidateExpenseTransactions();s.rangeKey=key}
      if(!force&&(s.loading||s.rows||s.error))return;
      const token=(s.token||0)+1;s.token=token;s.loading=true;s.error=null;s.pageIndex=0;s.rows=null;s.count=null;s.total=null;s.revision=null;s.detail?.remove();s.detail=null;
      const current=()=>{const applied=expenseRange(st.expense.key);return expenseReadCurrent('transactions',s,token,owner)&&s.rangeKey===key&&key===applied.from+'|'+applied.to};
      try{
        const invalid=expenseRangeError(r);if(invalid)throw Error(invalid);
        const rows=[],keys=new Set(),limit=10000,finiteNumber=value=>typeof value==='number'&&Number.isFinite(value)?value:null;let offset=0,revision=null,count=null,total=null;
        do{
          const p=await rpcRead('lts_browser_expense_detail_v229',{p_from:r.from,p_to:r.to,p_group:null,p_subgroup:null,p_offset:offset,p_limit:limit,p_query:null},2,current);
          if(!current())return;
          const pageCount=finiteNumber(p?.row_count),pageTotal=finiteNumber(p?.total),matchedCount=finiteNumber(p?.matched_count),matchedTotal=finiteNumber(p?.matched_total);
          if(!p||p.from!==r.from||p.to!==r.to||p.group!==null||p.subgroup!==null||p.offset!==offset||!Array.isArray(p.rows)||typeof p.revision!=='string'||!p.revision||!Number.isInteger(pageCount)||pageCount<0||pageTotal==null||matchedCount!==pageCount||matchedTotal!==pageTotal)throw Error('A resposta não corresponde ao período solicitado. Tente novamente.');
          if(revision!==null&&(p.revision!==revision||pageCount!==count||pageTotal!==total))throw Error('Os dados mudaram durante a leitura. Tente novamente.');
          revision=p.revision;count=pageCount;total=pageTotal;
          if(p.rows.length>limit)throw Error('A página de lançamentos está incompleta ou duplicada. Tente novamente.');
          for(const row of p.rows){
            if(!row||typeof row.key!=='string'||!row.key||keys.has(row.key)||finiteNumber(row.amount)==null||!['day','month'].includes(row.date_kind))throw Error('A lista precisa ser atualizada antes da conferência. Tente novamente.');
            keys.add(row.key);rows.push(row);
          }
          if(rows.length>count)throw Error('A quantidade de lançamentos mudou. Tente novamente.');
          const next=p.next_offset;
          if(next!==null&&(!Number.isInteger(next)||next<=offset||next!==rows.length||next>=count||!p.rows.length))throw Error('A paginação não fechou com a lista. Tente novamente.');
          offset=next;
        }while(offset!==null);
        if(rows.length!==count||Math.abs(rows.reduce((sum,row)=>sum+row.amount,0)-total)>0.02)throw Error('A lista não fechou com o total. Tente novamente.');
        if(!current())return;s.rows=rows;s.pageIndex=0;s.count=count;s.total=total;s.revision=revision;
      }catch(x){if(!current())return;s.error=String(x?.message||x);s.rows=null;s.count=null;s.total=null;s.revision=null}
      finally{if(current()){s.loading=false;refresh('Despesas')}}
    }

    function planningReviewCount(recurring){
      if(!recurring)return null;
      const checks=arr(recurring.horizon_checks).filter(x=>x?.review_kind==='planning_review');
      const items=arr(recurring.items).filter(x=>x?.review_kind==='planning_review');
      const explicit=x=>{for(const value of [x.series_id,x.key]){if(value!=null&&String(value).trim()!=='')return String(value)}return null};
      const signature=x=>{
        const descriptor=norm(x.description_key||x.description||x.title||'').trim();
        return descriptor?String(x.direction||'unknown')+'|'+descriptor:null;
      };
      const explicitBySignature=new Map();
      [...checks,...items].forEach(x=>{
        const id=explicit(x),sig=signature(x);if(id==null||!sig)return;
        if(!explicitBySignature.has(sig))explicitBySignature.set(sig,new Set());
        explicitBySignature.get(sig).add(String(x.direction||'unknown')+'|id|'+id);
      });
      const identity=(x,index,source)=>{
        const id=explicit(x),sig=signature(x);
        if(id!=null)return String(x.direction||'unknown')+'|id|'+id;
        const candidates=sig?explicitBySignature.get(sig):null;
        if(candidates?.size===1)return [...candidates][0];
        // Keep ambiguous or unidentified rows separate rather than merge distinct series by name.
        return candidates?.size>1||!sig?source+'|unresolved|'+index:'name|'+sig;
      };
      const horizon=new Set(checks.map((x,i)=>identity(x,i,'horizon'))),all=new Set(horizon);
      const declared=num(recurring.horizon_review_count);
      if(declared!=null&&declared>horizon.size)return null;
      items.forEach((x,i)=>all.add(identity(x,i,'item')));
      return all.size;
    }
    let actionReadOwner=expenseDraftGeneration();
    function syncActionsOwner(){
      const current=expenseDraftGeneration();if(current===actionReadOwner)return;
      actionReadOwner=current;st.updates.token=(st.updates.token||0)+1;
      Object.assign(st.updates,{loading:false,recurring:null,openFinance:null,error:null});
      if(st.dashboard.data)delete st.dashboard.data.recurring;
    }
    function actionsSnapshot(){
      syncActionsOwner();
      const cards=window.__LTS_V226;
      if(!st.updates.recurring&&!st.updates.loading&&!st.updates.error)queueMicrotask(()=>ensureUpdates());
      if(cards&&!cards.cycles&&!cards.loading&&!cards.error)queueMicrotask(()=>cards.read?.());
      return window.parent.LTSV333Actions.build({
        recurring:st.updates.recurring||st.dashboard.data?.recurring,
        cockpit:st.dashboard.data?.cockpit||D?.dashboard_cockpit,
        cards:cards?.cycles,asOf:today(),
        error:!!st.updates.error||!!cards?.error
      });
    }
    function actionList(){return actionsSnapshot().items}
    function actionsLabel(){const a=actionsSnapshot();return a.ready?'Ver todas ('+a.items.length+')':'Ver ações'}
    function actionsWarning(){const a=actionsSnapshot();return a.error?'<p class="v168-note warn" role="status">Não foi possível atualizar todas as ações. <button class="v168-btn" data-v333-actions-refresh>Atualizar ações</button></p>':''}

    function horizonPoints(flow){
      const now=today(),horizon=(Number(now.slice(0,4))+4)+'-12-31';
      // Keep every daily point: a positive month-end must not hide an intra-month deficit.
      return arr(flow?.flow?.current_future?.days).filter(d=>String(d.date)>=now&&String(d.date)<=horizon).map(d=>{
        const c=d.fix86_columns||{};
        return {date:d.date,base:num(c.saldo_apos_d0_1??c.posicao_antes_rsus??d.Consolidado?.bank_balance),vested:num(c.saldo_apos_rsu??c.posicao_curto_prazo),fgts:num(c.saldo_apos_fgts),documented:num(c.saldo_apos_fgts_documental),projectionEnabled:flow?.flow?.fgts_projection_contract?.version==='owner-withdrawal-and-recomposition-v242',monthlyEstimate:flow?.flow?.fgts_projection_contract?.monthly_estimate_brl};
      }).sort((a,b)=>String(a.date).localeCompare(String(b.date)));
    }
    function dailyScenario(flow,key){
      const now=today(),horizon=(Number(now.slice(0,4))+4)+'-12-31',column={base:'saldo_apos_d0_1',vested:'saldo_apos_rsu',fgts:'saldo_apos_fgts'}[key];
      const days=arr(flow?.flow?.current_future?.days).filter(x=>String(x.date)>=now&&String(x.date)<=horizon).sort((a,b)=>String(a.date).localeCompare(String(b.date))),read=d=>num(d.fix86_columns?.[column]);
      const dates=new Set(days.map(d=>d.date)),expected=Math.round((Date.parse(horizon+'T12:00:00Z')-Date.parse(now+'T12:00:00Z'))/86400000)+1;
      const complete=dates.size===expected&&days.every(d=>read(d)!=null),firstNegative=days.find(d=>read(d)!=null&&read(d)<0)||null,worst=days.reduce((m,d)=>read(d)==null?m:!m||read(d)<read(m)?d:m,null);
      return{available:days.some(d=>read(d)!=null),complete,firstNegative,firstAmount:firstNegative?read(firstNegative):null,worstAmount:worst?read(worst):null,worstDate:worst?.date||null,lastDate:days[days.length-1]?.date||null};
    }
    function deficitDetail(scenario,ready){
      if(!ready||!scenario.complete)return '';
      if(!scenario.firstNegative)return '<small class="v260-deficit">Sem saldo negativo até '+date(scenario.lastDate)+'</small>';
      return '<small class="v260-deficit">Primeiro saldo negativo: <strong>'+money(scenario.firstAmount)+'</strong> · '+date(scenario.firstNegative.date)+'</small><small class="v260-deficit">Pior saldo: <strong>'+money(scenario.worstAmount)+'</strong> · '+date(scenario.worstDate)+'</small><small class="v260-horizon">Projeção até '+date(scenario.lastDate)+'</small>';
    }
    function cockpitPoints(cockpit){const l=cockpit?.liquidity||{},rows=[{date:cockpit?.as_of||today(),base:(num(l.bank_cash)||0)+(num(l.d0)||0),vested:num(l.through_d3),fgts:(num(l.through_d3)||0)+(num(l.fgts_d30)||0)}];for(const x of arr(cockpit?.horizons))rows.push({date:x.date,base:num(x.current_liquidity_balance),vested:num(x.conditional_rsu_balance),fgts:num(x.restricted_total_balance)});return rows.filter(x=>x.date&&[x.base,x.vested,x.fgts].some(v=>v!=null)).sort((a,b)=>String(a.date).localeCompare(String(b.date)))}
    const moneyAxis=value=>v233Formatters[3].format(Number(value)||0);
    function lineChart(allRows){
      const year=st.chartYear||'all',rows=allRows.filter(r=>year==='all'||r.date.slice(0,4)===year);
      const controls='<label style="display:block;text-align:right;margin-bottom:12px"><select id="v242ChartYear" aria-label="Período do gráfico">'+[today().slice(0,4),String(Number(today().slice(0,4))+4),'all'].map(v=>'<option value="'+v+'" '+(v===year?'selected':'')+'>'+(v==='all'?'Todos':v)+'</option>').join('')+'</select></label>';
      if(rows.length<2)return controls+'<div class="v168-empty">Carregando projeção…</div>';
      const vals=rows.flatMap(r=>[r.base,r.vested,r.fgts]).filter(v=>num(v)!=null);
      if(!vals.length)return controls+'<div class="v168-empty">Projeção indisponível.</div>';
      const lo=Math.min(0,...vals),hi=Math.max(0,...vals),span=Math.max(1,hi-lo);
      // Keep mobile axis text and daily marks at their intended size, rather
      // than shrinking a 920px desktop plot into a phone-width card.
      const W=innerWidth<600?Math.max(280,innerWidth-64):920,H=innerWidth<600?260:330,p={l:76,r:32,t:18,b:38};
      const stamp=d=>Date.parse(String(d)+'T12:00:00Z'),start=stamp(rows[0].date),elapsed=Math.max(1,stamp(rows.at(-1).date)-start);
      const x=i=>p.l+(stamp(rows[i].date)-start)*(W-p.l-p.r)/elapsed,y=v=>p.t+(hi-Number(v))/span*(H-p.t-p.b);
      // Monotone cubic segments pass through every original day and cannot
      // introduce an extremum between two days. Nulls break the path.
      function path(key){
        let result='',segment=[];
        function flush(){
          const q=segment;if(!q.length)return;
          result+=' M'+q[0][0].toFixed(2)+' '+q[0][1].toFixed(2);
          const sec=q.slice(1).map((v,i)=>(v[1]-q[i][1])/(v[0]-q[i][0])),m=q.map((v,i)=>i===0?(sec[0]||0):i===q.length-1?(sec.at(-1)||0):sec[i-1]*sec[i]>0?2*sec[i-1]*sec[i]/(sec[i-1]+sec[i]):0);
          for(let i=1;i<q.length;i++){const dx=q[i][0]-q[i-1][0];let a=m[i-1],b=m[i],d=sec[i-1];if(!d){a=0;b=0}else{const z=(a/d)**2+(b/d)**2;if(z>9){const factor=3/Math.sqrt(z);a*=factor;b*=factor}}result+=' C'+(q[i-1][0]+dx/3).toFixed(2)+' '+(q[i-1][1]+a*dx/3).toFixed(2)+' '+(q[i][0]-dx/3).toFixed(2)+' '+(q[i][1]-b*dx/3).toFixed(2)+' '+q[i][0].toFixed(2)+' '+q[i][1].toFixed(2)}
          segment=[];
        }
        rows.forEach((r,i)=>{if(num(r[key])==null)flush();else segment.push([x(i),y(r[key])])});flush();return result.trim();
      }
      const ticks=[hi,(hi+lo)/2,0,lo].filter((v,i,a)=>a.findIndex(z=>Math.abs(z-v)<1)===i),valid=rows.filter(r=>num(r.fgts)!=null),first=valid.find(r=>r.fgts<0),minimum=valid.length?valid.reduce((a,b)=>a.fgts<=b.fgts?a:b):null;
      const marker=minimum?'<circle data-v242-minimum="'+esc(minimum.date)+'" data-value="'+minimum.fgts+'" cx="'+x(rows.indexOf(minimum)).toFixed(2)+'" cy="'+y(minimum.fgts).toFixed(2)+'" r="4" fill="'+(minimum.fgts<0?'#c93642':'#b5881a')+'"><title>Menor saldo: '+date(minimum.date)+' · '+money(minimum.fgts)+'</title></circle>':'';
      const firstMarker=first?'<circle data-v239-first-negative="'+esc(first.date)+'" cx="'+x(rows.indexOf(first)).toFixed(2)+'" cy="'+y(first.fgts).toFixed(2)+'" r="3" fill="#c93642"/>':'';
      const labels=[{r:rows[0],i:0}],gap=innerWidth<600?74:66;
      rows.forEach((r,i)=>{if(i&&i<rows.length-1&&r.date.slice(8)==='01'&&x(i)-x(labels.at(-1).i)>=gap)labels.push({r,i})});
      while(labels.length>1&&x(rows.length-1)-x(labels.at(-1).i)<gap)labels.pop();
      labels.push({r:rows.at(-1),i:rows.length-1});
      const series=rows.map((r,i)=>({...r,x:x(i),baseY:num(r.base)==null?null:y(r.base),vestedY:num(r.vested)==null?null:y(r.vested),fgtsY:num(r.fgts)==null?null:y(r.fgts)}));
      return '<div class="v168-chart">'+controls+'<svg viewBox="0 0 '+W+' '+H+'" data-v242-points="'+rows.length+'" data-v244-rows="'+esc(JSON.stringify(series))+'" tabindex="0" role="img" aria-label="Evolução diária da liquidez em '+(year==='all'?'toda a projeção':year)+'. Use as setas para consultar os saldos." aria-describedby="v244-chart-values">'+ticks.map(v=>'<line class="'+(Math.abs(v)<.01?'zero':'grid')+'" x1="'+p.l+'" x2="'+(W-p.r)+'" y1="'+y(v)+'" y2="'+y(v)+'"/><text class="'+(Math.abs(v)<.01?'zero-label':'axis-label')+'" x="'+(p.l-8)+'" y="'+(y(v)+4)+'" text-anchor="end">'+esc(moneyAxis(v))+'</text>').join('')+'<path class="base" d="'+path('base')+'"/><path class="vested" d="'+path('vested')+'"/><path class="fgts" d="'+path('fgts')+'"/>'+marker+firstMarker+labels.map(({r,i},k)=>'<text class="axis-label" data-v244-axis-date="'+r.date+'" x="'+x(i)+'" y="'+(H-10)+'" text-anchor="'+(k===0?'start':k===labels.length-1?'end':'middle')+'">'+esc(k===0||k===labels.length-1?date(r.date).slice(0,5):month(r.date))+'</text>').join('')+'<g data-v244-inspection hidden><line y1="'+p.t+'" y2="'+(H-p.b)+'" stroke="#8193a7" stroke-dasharray="3 3"/><circle class="base" r="3" fill="#2d72d2"/><circle class="vested" r="3" fill="#19a17a"/><circle class="fgts" r="3" fill="#d3a229"/></g></svg><div id="v244-chart-values" class="v244-chart-values" role="status" aria-live="polite" hidden></div><div class="v168-legend"><span><i></i>Caixa e aplicações</span><span class="vested"><i></i>Com ações</span><span class="fgts"><i></i>Com FGTS</span></div></div>';
    }
    function bindChart(){
      const svg=document.querySelector('.v168-chart svg[data-v244-rows]');if(!svg)return;
      const rows=JSON.parse(svg.dataset.v244Rows),panel=document.getElementById('v244-chart-values'),group=svg.querySelector('[data-v244-inspection]');let selected=0;
      function show(i){selected=clamp(i,0,rows.length-1);const r=rows[selected];group.removeAttribute('hidden');group.style.display='';const line=group.querySelector('line');line.setAttribute('x1',r.x);line.setAttribute('x2',r.x);for(const key of ['base','vested','fgts']){const circle=group.querySelector('.'+key);circle.style.display=r[key+'Y']==null?'none':'';circle.setAttribute('cx',r.x);circle.setAttribute('cy',r[key+'Y']??0)}panel.hidden=false;panel.innerHTML='<b>'+esc(date(r.date))+'</b><span>Caixa e aplicações <strong>'+money(r.base)+'</strong></span><span>Com ações <strong>'+money(r.vested)+'</strong></span><span>Com FGTS <strong>'+money(r.fgts)+'</strong></span>';panel.dataset.date=r.date;}
      const hide=()=>{group.style.display='none';panel.hidden=true};hide();
      svg.onpointermove=event=>{const matrix=svg.getScreenCTM();if(!matrix)return;const point=svg.createSVGPoint();point.x=event.clientX;point.y=event.clientY;const local=point.matrixTransform(matrix.inverse());const i=rows.reduce((best,row,n)=>Math.abs(row.x-local.x)<Math.abs(rows[best].x-local.x)?n:best,0);show(i)};
      svg.onpointerleave=()=>{if(document.activeElement!==svg)hide()};svg.onfocus=()=>show(selected);svg.onblur=hide;
      svg.onkeydown=event=>{if(!['ArrowLeft','ArrowRight','Home','End'].includes(event.key))return;event.preventDefault();show(event.key==='Home'?0:event.key==='End'?rows.length-1:selected+(event.key==='ArrowLeft'?-1:1))};
    }
    function rankRows(rows,max){const xs=arr(rows).slice(0,max||8),top=Math.max(1,...xs.map(x=>num(x.total)||0));return xs.length?'<div class="v168-rank">'+xs.map(x=>'<div class="v168-rankrow"><b>'+esc(window.LTSCategoryDisplay.category(x.name||x.category||'Outros'))+'</b><i><u style="width:'+clamp((num(x.total)||0)/top*100,2,100)+'%"></u></i><strong>'+money(x.total)+'</strong></div>').join('')+'</div>':'<div class="v168-empty">Sem composição para este período.</div>'}
    function contextBreakdowns(context){const out=[];for(const group of arr(context?.contexts)){const contextName=group.name||group.context||group.center_cost||group.key||'',children=arr(group.categories||group.category_breakdown||group.breakdown||group.items);for(const item of children){const category=item.name||item.category||item.key||'Outros',total=num(item.total??item.amount??item.value);if(total==null)continue;out.push({name:contextName&&norm(contextName)!=='nao atribuido'?contextName+' · '+category:category,total,dimension:'center',key:contextName})}}return out.sort((a,b)=>(b.total||0)-(a.total||0))}
    function futureItems(flow){const now=today();return arr(flow?.flow?.current_future?.events).filter(x=>String(x.event_date)>=now&&Math.abs(num(x.signed_amount)||0)>.01).sort((a,b)=>String(a.event_date).localeCompare(String(b.event_date))).slice(0,6)}

    function dashboardV168(){ensureDashboard();const s=st.dashboard,d=s.data||{},cockpit=d.cockpit||D?.dashboard_cockpit||{},flow=d.flow||{},days=arr(flow?.flow?.current_future?.days),todayRow=days.find(x=>x.date===today())||days[0]||{},c=todayRow.fix86_columns||{},w=d.wealth||{},rsu=w.rsu_summary||{},exp=d.expense||{},sum=exp.summary||{},actions=actionList(d.recurring,cockpit),detailedPoints=horizonPoints(flow),points=detailedPoints,planning=cockpit.planning_audited||{},baseNeg=points.find(x=>(num(x.base)||0)<0),fgtsNeg=points.find(x=>(num(x.fgts)||0)<0),baseNegDate=baseNeg?.date||planning.management_point_date||planning.first_negative_date,fgtsNegDate=fgtsNeg?.date||planning.first_uncovered_gap_date,futureDetailed=futureItems(flow),nextDue=cockpit.cards?.next_due,future=futureDetailed.length?futureDetailed:(nextDue?[{description:nextDue.card_name||'Próxima fatura',event_date:nextDue.due_date,account:'Cartões',signed_amount:-Math.abs(num(nextDue.amount)||0)}]:[]),topDetailed=arr(exp.rankings?.categories).slice(0,6),top=topDetailed.length?topDetailed:arr(cockpit.expenses?.current_month?.top_categories).map(x=>({name:x.name||x.category,total:x.total??x.amount})).slice(0,6);const bank=num(todayRow.Consolidado?.bank_balance??w.wealth?.liquidity?.bank_cash??cockpit.liquidity?.bank_cash),short=num(c.saldo_apos_rsu??w.wealth?.summary?.liquidity_through_d3??cockpit.liquidity?.through_d3),rsuTotal=(num(rsu.available_total_brl)!=null||num(rsu.future_considered_total_brl)!=null)?(num(rsu.available_total_brl)||0)+(num(rsu.future_considered_total_brl)||0):null,pensions=num(w.pensions?.total_gross_brl),expenseTotal=num(sum.selected_total??cockpit.expenses?.current_month?.spend),status=s.loading?'<div class="v168-loadstatus" role="status"><i></i><span><b>Dashboard disponível.</b> Completando detalhes de Fluxo, Despesas e Patrimônio…</span></div>':s.detailErrors?.length?'<div class="v168-loadstatus warn"><span><b>Resumo carregado.</b> Alguns detalhes não atualizaram; os valores disponíveis continuam visíveis.</span><button class="v168-btn" data-v168-dashboard-refresh>Tentar novamente</button></div>':'';if(s.error&&!Object.keys(cockpit).length&&!Object.keys(d).some(k=>k!=='cockpit'))return '<div class="v168">'+head('Visão executiva','Dashboard','Não foi possível atualizar o resumo agora.')+errorBox(s.error)+'<button class="v168-btn primary" data-v168-dashboard-refresh>Tentar novamente</button></div>';const hasProjection=points.length>1,baseLabel=baseNegDate?'Caixa-base negativo em '+date(baseNegDate):hasProjection?'Caixa-base sem ruptura no horizonte':'Calculando a primeira data de atenção',fgtsLabel=fgtsNegDate?'Mesmo com FGTS, negativo em '+date(fgtsNegDate):hasProjection?'FGTS cobre o horizonte exibido':'Calculando o cenário com FGTS';return '<div class="v168 v168-dashboard">'+head('Visão executiva','Dashboard','O que você tem hoje, quando o caixa aperta e qual ação vem primeiro.',sourceLabel(cockpit.as_of||today()))+status+'<div class="v168-kpis">'+kpi('Contas correntes hoje',bank,'saldo do Fluxo em '+date(cockpit.as_of||today()),'primary')+kpi('Liquidez de curto prazo',short,'caixa + D0/D1 + RSUs disponíveis')+kpi('RSUs · posição total',rsuTotal,rsuTotal==null?'completando posição':'disponível + vestings futuros')+kpi('Previdências',pensions,pensions==null?'completando posição':'saldo bruto restrito')+kpi('Despesas no período',expenseTotal,sum.selected_total!=null?'média '+money(sum.monthly_average):'mês atual')+'</div><div class="v168-grid two"><article class="v168-card"><div class="v168-cardhead"><div><span>Liquidez</span><h2>Evolução projetada até o fim do próximo ano</h2></div><small>base · vestings · FGTS</small></div>'+lineChart(points)+'</article><article class="v168-card"><div class="v168-cardhead"><div><span>Plano de ação</span><h2>O que exige decisão</h2></div><button class="v168-btn" data-v168-go="Atualizações">'+actionsLabel()+'</button></div>'+actionsWarning()+'<div class="v168-decision"><i>1</i><div><b>'+baseLabel+'</b><span>'+(baseNegDate?'Planeje a cobertura antes dessa data.':'O cálculo detalhado será incorporado sem bloquear esta tela.')+'</span></div></div><div class="v168-decision"><i>2</i><div><b>'+fgtsLabel+'</b><span>FGTS continua restrito e só entra como contingência.</span></div></div><div class="v168-note warn"><b>Próxima revisão:</b> confirme projeções recorrentes em Atualizações antes de usar o cenário como compromisso.</div></article></div><div class="v168-grid equal"><article class="v168-card"><div class="v168-cardhead"><div><span>Despesas</span><h2>Principais grupos</h2></div><button class="v168-btn" data-v168-go="Despesas">Abrir relatório</button></div>'+rankRows(top,6)+'</article><article class="v168-card"><div class="v168-cardhead"><div><span>Fluxo</span><h2>O que vem pela frente</h2></div><button class="v168-btn" data-v168-go="Fluxo Diário">Abrir Fluxo</button></div><div class="v168-statlist">'+(future.map(x=>'<div class="v168-stat"><span><b>'+esc(x.description||'Lançamento')+'</b><small>'+date(x.event_date)+' · '+esc(x.account||'sem conta')+'</small></span><b>'+money(x.signed_amount)+'</b></div>').join('')||'<div class="v168-empty">Completando os próximos compromissos…</div>')+'</div></article></div></div>'}

    function kpiSection(title,subtitle,content,kind){return '<section class="v168-kpi-section '+(kind||'')+'"><div class="v168-sectiontitle"><div><b>'+esc(title)+'</b><span>'+esc(subtitle)+'</span></div></div><div class="v168-kpis">'+content+'</div></section>'}
    function dashboardV168Final(){
      ensureDashboard();
      const s=st.dashboard,d=s.data||{},cockpit=d.cockpit||D?.dashboard_cockpit||{},flow=d.flow||{},days=arr(flow?.flow?.current_future?.days),todayRow=days.find(x=>x.date===today())||null,c=todayRow?.fix86_columns||{},w=d.wealth||{},wealth=w.wealth||{},liquidity=wealth.liquidity||{},rsu=w.rsu_summary||{},pensions=w.pensions||{},pensionRows=arr(pensions.positions),exp=d.expense||{},sum=exp.summary||{},expensePeriod=exp.period||{},actions=actionList(d.recurring,cockpit),detailedPoints=horizonPoints(flow),points=detailedPoints,planning=cockpit.planning_audited||{},planningUI=d.planningUI||{},planningReady=planningUI.version==='planning-ui-contract-v2',baseScenario=dailyScenario(flow,'base'),vestedScenario=dailyScenario(flow,'vested'),fgtsScenario=dailyScenario(flow,'fgts'),lastHorizon=fgtsScenario.lastDate||vestedScenario.lastDate||baseScenario.lastDate||points[points.length-1]?.date||null;
      const baseNegDate=planningReady?planningUI.d01_first_need:null,vestedNegDate=planningReady?planningUI.rsu_first_need:null,fgtsNegDate=planningReady?planningUI.fgts_first_negative:null;
      const futureDetailed=futureItems(flow),nextDue=cockpit.cards?.next_due,future=futureDetailed.length?futureDetailed:(nextDue?[{description:nextDue.card_name||'Próxima fatura',event_date:nextDue.due_date,account:'Cartões',signed_amount:-Math.abs(num(nextDue.amount)||0)}]:[]),contextual=contextBreakdowns(d.expenseContext),topDetailed=contextual.length?contextual:arr(exp.rankings?.categories),top=topDetailed.length?topDetailed.slice(0,6):arr(cockpit.expenses?.current_month?.top_categories).map(x=>({name:x.name||x.category,total:x.total??x.amount})).slice(0,6);
      const bank=todayRow?num(todayRow.Consolidado?.bank_balance):null,d0=num(liquidity.d0??cockpit.liquidity?.d0),availableRsu=num(rsu.available_total_brl),fgts=num(liquidity.fgts_contingency??wealth.summary?.restricted_contingency??cockpit.liquidity?.fgts_d30),knownCurrent=[bank,d0,availableRsu,fgts].filter(x=>x!=null),mappedTotal=knownCurrent.length?knownCurrent.reduce((a,b)=>a+b,0):null,futureRegular=num(rsu.future_regular_brl),futureCash=num(rsu.future_cash_net_brl),futureTotal=num(rsu.future_considered_total_brl),pensionTotal=num(pensions.total_gross_brl),organon=pensionRows.find(x=>/organon/i.test(x.name||'')),novartis=pensionRows.find(x=>/novartis/i.test(x.name||'')),expenseTotal=num(sum.selected_total??cockpit.expenses?.current_month?.spend),periodLabel=expensePeriod.from&&expensePeriod.to?date(expensePeriod.from)+' a '+date(expensePeriod.to):'ano atual';
      const status=s.loading?'<div class="v168-loadstatus" role="status"><i></i><span><b>Resumo já disponível.</b> Atualizando os detalhes sem apagar os valores exibidos…</span></div>':s.detailErrors?.length?'<div class="v168-loadstatus warn"><span><b>Resumo preservado.</b> '+s.detailErrors.length+' leitura(s) não atualizaram; nenhuma informação anterior foi apagada.</span><button class="v168-btn" data-v168-dashboard-refresh>Tentar novamente</button></div>':'';
      if(s.error&&!Object.keys(cockpit).length&&!Object.keys(d).some(k=>k!=='cockpit'))return '<div class="v168">'+head('Visão executiva','Dashboard','Não foi possível atualizar o resumo agora.')+errorBox(s.error)+'<button class="v168-btn primary" data-v168-dashboard-refresh>Tentar novamente</button></div>';
      const label=dt=>!planningReady?'Carregando…':dt?'Cobertura até '+date(addDays(dt,-1)):'Cobertura até '+date(lastHorizon);const baseLabel=label(baseNegDate),vestedLabel=label(vestedNegDate),fgtsLabel=label(fgtsNegDate);
      const currentCards=kpi('Contas correntes hoje',bank,todayRow?'saldo consolidado em '+date(todayRow.date):'atualizando o saldo do dia','primary')+kpi('Aplicações D0',d0,'disponíveis no curto prazo')+kpi('RSUs já disponíveis',availableRsu,'ações vested + saldo em corretora')+kpi('FGTS',num(c.fgts_documental??fgts),'saldo restrito')+kpi('Recursos mapeados',mappedTotal,'soma das quatro posições ao lado');
      const futureCards=kpi('RSUs futuras',futureRegular,'100% do valor projetado')+kpi('Cash RSUs futuras',futureCash,'70% após reserva fiscal')+kpi('Compensação futura',futureTotal,'RSU + Cash RSU; não é caixa atual');
      const restrictedCards=kpi('Previdências',pensionTotal,'saldo bruto restrito','primary')+kpi('Organon',organon?.gross_balance_brl,'posição em '+date(organon?.as_of))+kpi('Novartis',novartis?.gross_balance_brl,'posição em '+date(novartis?.as_of))+kpi('Despesas do período',expenseTotal,periodLabel);
      return '<div class="v168 v168-dashboard">'+head('Visão executiva','Dashboard','',sourceLabel(todayRow?.date||cockpit.as_of||w.as_of||today()))+status+kpiSection('Recursos de hoje','',currentCards,'current')+kpiSection('Posições futuras','não somadas ao dinheiro disponível hoje',futureCards,'future')+kpiSection('Recursos restritos e consumo','',restrictedCards,'restricted')+'<div class="v168-grid two"><article class="v168-card"><div class="v168-cardhead"><div><span>Liquidez</span><h2>Evolução projetada</h2></div></div>'+lineChart(points)+'</article><article class="v168-card"><div class="v168-cardhead"><div><span>Plano de ação</span><h2>O que exige decisão</h2></div><button class="v168-btn" data-v168-go="Atualizações">'+actionsLabel()+'</button></div>'+actionsWarning()+'<div class="v168-decision"><i>1</i><div><b>Caixa e aplicações</b><span>'+baseLabel+'</span></div></div><div class="v168-decision"><i>2</i><div><b>Com ações</b><span>'+vestedLabel+'</span></div></div><div class="v168-decision"><i>3</i><div><b>Com FGTS</b><span>'+fgtsLabel+'</span>'+deficitDetail(fgtsScenario,planningReady)+'</div></div></article></div><div class="v168-grid equal"><article class="v168-card"><div class="v168-cardhead"><div><span>Despesas · '+esc(periodLabel)+'</span><h2>Principais grupos</h2></div><button class="v168-btn" data-v168-go="Despesas">Abrir relatório</button></div>'+rankRows(top,6)+'</article><article class="v168-card"><div class="v168-cardhead"><div><span>Fluxo</span><h2>O que vem pela frente</h2></div><button class="v168-btn" data-v168-go="Fluxo Diário">Abrir Fluxo</button></div><div class="v168-statlist">'+(future.map(x=>{const incoming=(num(x.signed_amount)||0)>=0;return '<div class="v168-stat v168-future '+(incoming?'income':'expense')+'"><span><b>'+esc(x.description||'Lançamento')+'</b><small>'+date(x.event_date)+' · '+esc(x.account||'sem conta')+' · '+(incoming?'entrada':'saída')+'</small></span><b>'+money(x.signed_amount)+'</b></div>'}).join('')||'<div class="v168-empty">Nenhum compromisso futuro carregado.</div>')+'</div></article></div></div>';
    }

    function periodButtons(){syncExpenseDraft();if(st.expense.key==='custom'||st.expense.periodEditorVisible===true)openExpenseDraft();const d=expenseDraft,selected=st.expense.key;return '<div class="v168-expense-controls"><div class="v168-periods">'+[['ytd','Ano atual'],['6m','6 meses'],['12m','12 meses'],['all','Desde 2013'],['custom','Período personalizado']].map(x=>'<button type="button" class="'+(selected===x[0]?'active':'')+'" data-v168-exp-range="'+x[0]+'">'+x[1]+'</button>').join('')+'</div>'+(d?'<div class="v168-custom-range"><label>De<input id="v168ExpenseFrom" type="date" value="'+esc(d.from)+'"></label><label>Até<input id="v168ExpenseTo" type="date" value="'+esc(d.to)+'"></label><button type="button" class="v168-btn primary" id="v168ExpenseApply">Aplicar período</button>'+(d.error?'<div class="v168-error" role="alert" style="flex-basis:100%;grid-column:1/-1" data-v280-expense-draft-error>'+esc(d.error)+'</div>':'')+'</div>':'')+'</div>'}
    function expenseTabs(){return tabs([['overview','Visão geral'],['categories','Categorias'],['cards','Cartões e faturas'],['transactions','Lançamentos']],st.expense.tab,'data-v168-exp-tab')}
    function barChart(rows){const xs=arr(rows).slice(-18),top=Math.max(1,...xs.map(x=>num(x.total)||0));return '<div class="v168-bars">'+xs.map(x=>'<div class="v168-bar"><b>'+money(x.total).replace(/,\d{2}$/,'')+'</b><i style="height:'+clamp((num(x.total)||0)/top*100,2,100)+'%"></i><span>'+esc(month(x.month))+'</span></div>').join('')+'</div>'}
    function expenseOverview(r){const s=r.summary||{},ms=arr(r.monthly_detail).filter(x=>String(x.month)>=expenseRange(st.expense.key).from.slice(0,7)),last=ms[ms.length-1]||{},prev=ms[ms.length-2]||{},cats=arr(r.rankings?.categories);return '<div class="v168-kpis">'+kpi('Total do período',s.selected_total,expenseRange(st.expense.key).label,'primary')+kpi('Média mensal',s.monthly_average,(r.period?.months_in_selection||ms.length)+' meses')+kpi('Mês atual',last.total,last.is_partial?'parcial até '+date(r.period?.last_available):'mês fechado')+kpi('Cartões',s.card_total,'consumo consolidado')+kpi('Contas',s.account_total,'pagamentos fora de cartão')+'</div><div class="v168-grid two"><article class="v168-card"><div class="v168-cardhead"><div><span>Evolução</span><h2>Despesa mês a mês</h2></div><small>'+date(r.period?.from)+' → '+date(r.period?.to)+'</small></div>'+barChart(ms)+'</article><article class="v168-card"><div class="v168-cardhead"><div><span>Leitura rápida</span><h2>Comparações</h2></div></div><div class="v168-statlist"><div class="v168-stat"><span>Mês anterior</span><b>'+money(prev.total)+'</b></div><div class="v168-stat"><span>Variação mensal</span><b>'+pct(last.mom_comparison_pct)+'</b></div><div class="v168-stat"><span>Últimos 12 meses</span><b>'+money(s.last_12m)+'</b></div><div class="v168-stat"><span>Histórico analisado</span><b>'+money(s.history_total)+'</b></div></div><div class="v168-note"><b>Período ativo:</b> todos os números e gráficos desta tela usam a seleção acima.</div></article></div><article class="v168-card"><div class="v168-cardhead"><div><span>Composição</span><h2>Maiores grupos</h2></div><button class="v168-btn" data-v168-exp-tab="categories">Ver categorias</button></div>'+rankRows(cats,10)+'</article>'}
    function expenseCategories(r){const cats=arr(r.rankings?.categories),centers=arr(r.rankings?.centers),ben=centers.find(x=>norm(x.name)==='benjamin'),edu=cats.find(x=>norm(x.name)==='educacao');return '<div class="v168-grid two"><article class="v168-card"><div class="v168-cardhead"><div><span>Categorias</span><h2>Para onde foi o dinheiro</h2></div><strong>'+money(r.summary?.selected_total)+'</strong></div>'+rankRows(cats,25)+'</article><div class="v168-grid"><article class="v168-card"><div class="v168-cardhead"><div><span>Família</span><h2>Benjamin</h2></div></div><div class="v168-family"><i>B</i><div><b>Benjamin</b><span>grupo de acompanhamento</span></div><strong>'+money(ben?.total)+'</strong></div><div class="v168-statlist"><div class="v168-stat"><span>Educação</span><b>'+money(edu?.total)+'</b></div><div class="v168-stat"><span>Total atribuído a Benjamin</span><b>'+money(ben?.total)+'</b></div></div></article><article class="v168-card"><div class="v168-cardhead"><div><span>Pessoas e contextos</span><h2>Centros de acompanhamento</h2></div></div>'+rankRows(centers.filter(x=>norm(x.name)!=='nao atribuido'),12)+'</article></div></div>'}
    function cardAccount(name){const n=norm(name);if(n.includes('aeternum')||n.includes('bradesco'))return'Bradesco';if(n.includes('c6')||n.includes('carbon'))return'C6';if(n.includes('personnalite')||n.includes('mastercard')||n.includes('itau'))return'Itaú';return''}
    function cardDisplayRows(){const o=D?.card_operating||{},live=[...arr(o.open_cycles).map(x=>({...x,date:x.due_date,status:'Fatura aberta',live:true})),...arr(o.closed_or_due).map(x=>({...x,date:x.due_date,status:x.state==='payment_evidence_needed'?'Pagamento a confirmar':'Fatura fechada',live:true})),...arr(o.paid_recent).map(x=>({...x,date:x.payment_date||x.due_date,status:'Pagamento documentado',live:true}))],history=arr(st.invoices.rows).map(x=>({...x,status:'Histórico do Fluxo'})),seen=new Set(),out=[];for(const x of [...live,...history].sort((a,b)=>String(b.date||b.event_date).localeCompare(String(a.date||a.event_date)))){const key=[String(x.date||x.event_date).slice(0,10),Math.abs(num(x.amount)||0).toFixed(2),norm(x.card_name||x.description||'')].join('|');if(seen.has(key))continue;seen.add(key);out.push(x)}st.invoices.display=out;return out}
    function detailCategories(rows){const m=new Map();for(const x of arr(rows)){const key=x.category||x.category_lts||'A classificar';m.set(key,(m.get(key)||0)+(num(x.amount)||0))}return[...m].map(([name,total])=>({name,total})).sort((a,b)=>b.total-a.total)}
    function showInvoiceDetail(x,j){const purchases=arr(j?.purchases?.length?j.purchases:x.detail_preview).map(p=>({...p,category:p.category||p.category_lts||'A classificar'})),cats=detailCategories(purchases),total=num(j?.invoice_total??x.amount),pending=purchases.filter(p=>norm(p.category)==='a classificar').length,title=j?.card_name||x.card_name||x.description||'Fatura';const bg=modal(title,(x.status||'Fatura')+' · '+date(j?.due_date||x.due_date||x.date||x.event_date),'<div class="v168-kpis">'+kpi('Total da fatura',total,'valor observado','primary')+kpiText('Itens documentados',purchases.length,'compras disponíveis')+kpiText('A classificar',pending,pending?'revisão necessária':'itens classificados')+'</div><div class="v168-grid equal" style="margin-top:12px"><article class="v168-card"><div class="v168-cardhead"><div><span>Composição</span><h2>Por categoria</h2></div></div>'+rankRows(cats,30)+'</article><article class="v168-card"><div class="v168-cardhead"><div><span>Conciliação</span><h2>Leitura da fatura</h2></div></div><div class="v168-statlist"><div class="v168-stat"><span>Vencimento</span><b>'+date(j?.due_date||x.due_date||x.date)+'</b></div><div class="v168-stat"><span>Detalhe × total</span><b>'+(purchases.length?(j?.cash_reconciled===false?'Em revisão':'Disponível'):'Não documentado')+'</b></div><div class="v168-stat"><span>Situação</span><b>'+esc(x.status||'Fatura')+'</b></div></div></article></div><div class="v168-tablewrap" style="margin-top:12px"><table class="v168-table"><thead><tr><th>Compra</th><th>Categoria</th><th>Parcela</th><th class="num">Valor</th></tr></thead><tbody>'+(purchases.map(p=>'<tr><td>'+esc(p.description||'Compra')+'</td><td>'+esc(window.LTSCategoryDisplay.category(p.category))+'</td><td>'+esc(p.installment||p.installment_label||(p.installments>1?(p.installment_number||'—')+'/'+p.installments:'—'))+'</td><td class="num">'+money(p.amount)+'</td></tr>').join('')||'<tr><td colspan="4">O total está preservado, mas esta competência ainda não tem compras individualizadas.</td></tr>')+'</tbody></table></div>'+(x.source?'<div style="margin-top:12px"><button class="v168-btn blue" id="v168InvoiceFlow">Abrir esta fatura no Fluxo</button></div>':'')+'<div class="v168-note" style="margin-top:12px">Pagamento de fatura explica o caixa; cada compra explica o consumo uma única vez.</div>');bg.querySelector('#v168InvoiceFlow')?.addEventListener('click',()=>{bg.remove();openInFlow(x,false)})}
    async function openInvoiceDetail(x,button){if(!x)return;const owner=syncExpenseReaders(),s=st.invoices,token=s.token;if(!expenseReaderCurrent(owner))return;button.disabled=true;const old=button.textContent;button.textContent='Carregando…';try{if(arr(x.detail_preview).length)return showInvoiceDetail(x,{matched:true,invoice_total:x.amount,due_date:x.due_date,purchases:x.detail_preview});const j=await rpc('lts_browser_card_settlement_detail_v2',{p_event_date:String(x.date||x.event_date||x.due_date).slice(0,10),p_description:x.description||('Fatura '+(x.card_name||'')),p_amount:Math.abs(num(x.amount)||0),p_account:x.account||cardAccount(x.card_name)});if(expenseReadCurrent('invoices',s,token,owner))showInvoiceDetail(x,j||{})}catch(e){if(!expenseReadCurrent('invoices',s,token,owner))return;toast2('Não foi possível abrir a composição: '+String(e?.message||e))}finally{if(expenseReadCurrent('invoices',s,token,owner)){button.disabled=false;button.textContent=old}}}
    function expenseCards(){ensureInvoices();const s=st.invoices,o=D?.card_operating||{},rows=cardDisplayRows(),pending=num(o.classification_review?.pending_lines)||0;return '<div class="v168-grid"><div class="v168-kpis">'+kpi('Faturas abertas',o.open_cycles_total,arr(o.open_cycles).length+' ciclo(s)','primary')+kpi('Vencidas / a confirmar',o.closed_or_due_total,arr(o.closed_or_due).length+' ciclo(s)')+kpi('Parcelas futuras',o.contracted_installment_floor_total,'piso já contratado')+kpi('A classificar',pending,'itens documentados')+'</div><article class="v168-card"><div class="v168-cardhead"><div><span>Cartões e faturas</span><h2>Faturas consideradas no Fluxo</h2></div><small>'+rows.length+' registro(s)</small></div>'+(s.loading?loading():s.error?errorBox(s.error):'<div class="v168-invoices">'+(rows.map((x,i)=>'<div class="v168-invoice"><span>'+date(x.date||x.event_date||x.due_date)+'</span><div><b>'+esc(x.card_name||x.description||'Fatura')+'</b><small>'+esc(x.status||'Fatura')+' · '+esc(x.account||cardAccount(x.card_name)||'')+(arr(x.detail_preview).length?' · '+arr(x.detail_preview).length+' itens':'')+'</small></div><strong>'+money(Math.abs(num(x.amount)||0))+'</strong><div class="v168-searchactions"><button class="v168-btn primary" data-v168-invoice-detail="'+i+'">Ver composição</button>'+(x.source?'<button class="v168-btn" data-v168-flow-row="invoice-display:'+i+'">Fluxo</button>':'')+'</div></div>').join('')||'<div class="v168-empty">Nenhuma fatura encontrada.</div>')+'</div>')+'<div class="v168-note"><b>Bradesco de R$ 29,90:</b> classificado como Assinaturas. O pagamento explica o caixa; compras classificadas explicam o consumo, sem dupla contagem.</div></article></div>'}
    function expenseTransactionDate(row){if(row.date_kind==='month'){const period=typeof row.period==='string'?row.period:'';return /^\d{4}-(0[1-9]|1[0-2])(?:-\d{2})?$/.test(period)?month(period)+' · competência':'Competência não informada'}const value=typeof row.date==='string'?row.date:'';return /^\d{4}-\d{2}-\d{2}$/.test(value)&&Number.isFinite(Date.parse(value+'T12:00:00Z'))&&new Date(value+'T12:00:00Z').toISOString().slice(0,10)===value?date(value):'Data não informada'}
    function expenseTransactionDetailBody(row){
      const fields=[['Data',expenseTransactionDate(row)],['Valor',money(row.amount)],['Categoria',window.LTSCategoryDisplay.category(row.current_category||'A classificar')],['Grupo',window.LTSCategoryDisplay.category(row.category||'—')],['Subgrupo',window.LTSCategoryDisplay.category(row.subgroup||'—')],['Conta/cartão',row.account_source||'—'],['Beneficiário',row.beneficiary||'—'],['Imóvel',row.property_code||'—'],['Origem',row.source_table||'—'],['Referência',row.reference||row.source_ref||'—']];
      return '<div class="v168-statlist">'+fields.map(([label,value])=>'<div class="v168-stat"><span>'+esc(label)+'</span><b>'+esc(value)+'</b></div>').join('')+'</div>'+(row.source_audit?.note?'<div class="v168-note">'+esc(row.source_audit.note)+'</div>':'')+(row.source_identity?.note?'<div class="v168-note">'+esc(row.source_identity.note)+'</div>':'')+'<div class="v168-note">Detalhe do registro de despesas. Compras e ajustes de cartão explicam o consumo; o pagamento da fatura é acompanhado no Fluxo.</div>';
    }
    function bindExpenseTransactionActions(){
      const owner=syncExpenseReaders(),s=st.transactions,token=s.token,key=s.rangeKey;
      const current=()=>{const r=expenseRange(st.expense.key);return V==='Despesas'&&st.expense.tab==='transactions'&&expenseReadCurrent('transactions',s,token,owner)&&key===s.rangeKey&&key===r.from+'|'+r.to};
      const retry=document.querySelector('[data-v281-expense-transactions-retry]');retry?.addEventListener('click',()=>{if(current()&&retry.isConnected){ensureTransactions(true);render()}});
      document.querySelectorAll('[data-v281-expense-transaction-detail]').forEach(button=>{const row=arr(s.rows)[Number(button.dataset.v281ExpenseTransactionDetail)];button.onclick=()=>{if(!current()||!button.isConnected||!row)return;s.detail=modal(row.description||'Lançamento',expenseTransactionDate(row),expenseTransactionDetailBody(row));s.detail.setAttribute('data-v281-expense-transaction-modal','')}});
      document.querySelectorAll('[data-v281-expense-transactions-page]').forEach(button=>button.onclick=()=>{if(!current()||!button.isConnected||s.loading||s.error)return;const last=Math.max(0,Math.ceil(arr(s.rows).length/100)-1),next=clamp((s.pageIndex||0)+(button.dataset.v281ExpenseTransactionsPage==='next'?1:-1),0,last);if(next!==s.pageIndex){s.pageIndex=next;render()}});
    }
    function expenseTransactions(){
      ensureTransactions();const s=st.transactions,rows=arr(s.rows),pageCount=Math.max(1,Math.ceil(rows.length/100)),pageIndex=clamp(Number.isInteger(s.pageIndex)?s.pageIndex:0,0,pageCount-1),start=pageIndex*100,visible=rows.slice(start,start+100);s.pageIndex=pageIndex;
      const navigation='<div class="v168-cardhead"><span data-v281-expense-transactions-page-summary>Exibindo '+(rows.length?start+1:0)+' a '+(start+visible.length)+' de '+rows.length+' lançamento(s) · Página '+(pageIndex+1)+' de '+pageCount+'</span><div><button class="v168-btn" data-v281-expense-transactions-page="prev"'+(pageIndex===0?' disabled':'')+'>Anterior</button> <button class="v168-btn" data-v281-expense-transactions-page="next"'+(pageIndex===pageCount-1?' disabled':'')+'>Próxima</button></div></div>';
      const content=s.loading?loading():s.error?errorBox(s.error)+'<button class="v168-btn primary" data-v281-expense-transactions-retry>Tentar novamente</button>':'<div class="v168-note">'+rows.length+' lançamento(s) · Total '+money(s.total)+'</div><div class="v168-tablewrap"><table class="v168-table"><thead><tr><th>Data / competência</th><th>Descrição</th><th>Categoria</th><th>Conta/cartão</th><th>Beneficiário</th><th class="num">Valor</th><th></th></tr></thead><tbody>'+(visible.map((row,i)=>'<tr data-v281-expense-row-key="'+esc(row.key)+'"><td>'+esc(expenseTransactionDate(row))+'</td><td><b>'+esc(row.description||'Lançamento')+'</b></td><td>'+esc(window.LTSCategoryDisplay.category(row.current_category||'A classificar'))+'</td><td>'+esc(row.account_source||'—')+'</td><td>'+esc(row.beneficiary||'—')+'</td><td class="num">'+money(row.amount)+'</td><td><button class="v168-btn" data-v281-expense-transaction-detail="'+(start+i)+'">Detalhes</button></td></tr>').join('')||'<tr><td colspan="7">Nenhum lançamento no período selecionado.</td></tr>')+'</tbody></table></div>'+navigation;
      return '<article class="v168-card" data-v281-expense-transactions-list><div class="v168-cardhead"><div><span>Lançamentos</span><h2>Despesas do período</h2></div><button class="v168-btn" data-v168-go="Atualizações" data-focus="search">Pesquisar todo o histórico</button></div>'+content+'</article>';
    }
    function despesasV168(){ensureExpense();const s=st.expense,r=s.data||{},meta=sourceLabel(r.period?.last_available||today())+periodButtons();let body=s.loading&&!s.data?loading():s.error&&!s.data?errorBox(s.error):s.tab==='categories'?expenseCategories(r):s.tab==='cards'?expenseCards():s.tab==='transactions'?expenseTransactions():expenseOverview(r);return '<div class="v168 v168-expenses">'+head('Despesas','Despesas','Consumo, cartões e lançamentos com período explícito e sem dupla contagem.',meta)+expenseTabs()+body+'</div>'}

    function expenseTimeline(r){const monthly=arr(r.monthly_detail).filter(x=>String(x.month)>=expenseRange(st.expense.key).from.slice(0,7)&&String(x.month).slice(0,7)<=expenseRange(st.expense.key).to.slice(0,7));if(st.expense.key!=='all'&&monthly.length<=24)return{rows:monthly.map(x=>({label:month(x.month),total:num(x.total)})),title:'Despesa mês a mês',unit:'total mensal'};const yearly=arr(r.yearly_detail);if(yearly.length)return{rows:yearly.map(x=>{const months=num(x.months??x.month_count??x.months_in_year)||12,total=num(x.total??x.selected_total);return{label:String(x.year||x.reference_year||String(x.period||'').slice(0,4)),total:num(x.monthly_average??x.average_monthly)??(total==null?null:total/months)}}).filter(x=>x.label&&x.total!=null),title:'Média mensal por ano',unit:'média mensal'};const byYear=new Map();for(const row of monthly){const year=String(row.month||'').slice(0,4),value=num(row.total);if(!year||value==null)continue;const item=byYear.get(year)||{sum:0,count:0};item.sum+=value;item.count++;byYear.set(year,item)}return{rows:[...byYear].map(([label,x])=>({label,total:x.sum/x.count})),title:'Média mensal por ano',unit:'média mensal'}}
    function expenseBarChart(rows){const xs=arr(rows),top=Math.max(1,...xs.map(x=>Math.abs(num(x.total)||0)));return xs.length?'<div class="v168-bars '+(xs.length>18?'compact':'')+'">'+xs.map(x=>'<div class="v168-bar"><b>'+money(x.total).replace(/,\d{2}$/,'')+'</b><i style="height:'+clamp(Math.abs(num(x.total)||0)/top*100,2,100)+'%"></i><span>'+esc(x.label||'—')+'</span></div>').join('')+'</div>':'<div class="v168-empty">Sem despesas no período selecionado.</div>'}
    function expenseOverviewV168(r){const selected=expenseRange(st.expense.key),range={...selected,label:r.period?.label||selected.label||date(selected.from)+' → '+date(selected.to)},s=r.summary||{},comparison=r.comparison||{},monthly=arr(r.monthly_detail).filter(x=>String(x.month)>=range.from.slice(0,7)&&String(x.month).slice(0,7)<=range.to.slice(0,7)),last=monthly[monthly.length-1]||{},prev=monthly[monthly.length-2]||{},cats=arr(r.rankings?.categories),timeline=expenseTimeline(r);return '<div class="v168-period-summary"><b>'+esc(range.label)+'</b><span>'+date(range.from)+' → '+date(range.to)+'</span></div><div class="v168-kpis">'+kpi('Total do período',s.selected_total,range.label,'primary')+kpi('Média mensal',s.monthly_average,(r.period?.months_in_selection||monthly.length)+' meses')+kpi('Último mês disponível',last.total,(last.is_partial?'parcial · ':'')+month(last.month))+kpi('Cartões',s.card_total,'compras do período')+kpi('Contas',s.account_total,'pagamentos fora de cartões')+'</div><div class="v168-grid two"><article class="v168-card"><div class="v168-cardhead"><div><span>'+esc(timeline.unit)+'</span><h2>'+esc(timeline.title)+'</h2></div><small>'+date(range.from)+' → '+date(range.to)+'</small></div>'+expenseBarChart(timeline.rows)+'</article><article class="v168-card"><div class="v168-cardhead"><div><span>Leitura rápida</span><h2>Comparações do período</h2></div></div><div class="v168-statlist"><div class="v168-stat"><span>Mês anterior'+(comparison.partial?' · até o mesmo dia':'')+'</span><b>'+(comparison.previous_total==null?'Sem base comparável':money(comparison.previous_total))+'</b></div><div class="v168-stat"><span>Variação do último mês</span><b>'+(comparison.variation_pct==null?'Sem base comparável':pct(comparison.variation_pct))+'</b></div><div class="v168-stat"><span>Últimos 12 meses</span><b>'+(s.last_12m==null?'Sem base disponível':money(s.last_12m))+'</b></div><div class="v168-stat"><span>Período selecionado</span><b>'+esc(range.label)+'</b></div></div></article></div><article class="v168-card"><div class="v168-cardhead"><div><span>Composição</span><h2>Maiores grupos · '+esc(range.label)+'</h2></div><button class="v168-btn" data-v168-exp-tab="categories">Ver detalhes</button></div>'+rankRows(cats,12)+'</article>'}
    function expenseContextGroups(r,context){const direct=arr(context?.contexts).map(group=>({name:group.name||group.context||group.center_cost||group.key||'Outros',total:num(group.total??group.amount??group.value),children:arr(group.categories||group.category_breakdown||group.breakdown||group.items).map(x=>({name:x.name||x.category||x.key||'Outros',total:num(x.total??x.amount??x.value)})).filter(x=>x.total!=null)})).filter(x=>x.total!=null||x.children.length);if(direct.length)return direct.sort((a,b)=>(b.total||0)-(a.total||0));return arr(r.rankings?.centers).filter(x=>norm(x.name)!=='nao atribuido').map(x=>({name:x.name,total:num(x.total),children:[]}))}
    function drillEntry(dimension,key,label,total){const index=(st.expense.drill||(st.expense.drill=[])).push({dimension,key,label,total})-1;return '<button class="v168-btn" data-v168-exp-drill="'+index+'">Ver lançamentos</button>'}
    function expenseCategoriesV168(r){const range=expenseRange(st.expense.key),cats=arr(r.rankings?.categories),groups=expenseContextGroups(r,st.expense.context);st.expense.drill=[];return '<div class="v168-period-summary"><b>Categorias e contextos</b><span>'+esc(range.label)+' · '+date(range.from)+' → '+date(range.to)+'</span></div><div class="v168-grid two"><article class="v168-card"><div class="v168-cardhead"><div><span>Categorias</span><h2>Natureza das despesas</h2></div><strong>'+money(r.summary?.selected_total)+'</strong></div><div class="v168-category-list">'+(cats.map(x=>'<div class="v168-category-row"><div><b>'+esc(window.LTSCategoryDisplay.category(x.name||x.category||'Outros'))+'</b><small>'+esc(range.label)+'</small></div><strong>'+money(x.total)+'</strong>'+drillEntry('category',x.name||x.category,x.name||x.category,x.total)+'</div>').join('')||'<div class="v168-empty">Sem categorias no período.</div>')+'</div></article><article class="v168-card"><div class="v168-cardhead"><div><span>Contextos</span><h2>Para quem ou para qual objetivo</h2></div></div><div class="v168-contexts">'+(groups.map(group=>'<section class="v168-context"><div class="v168-context-head"><div><b>'+esc(group.name)+'</b><small>'+group.children.length+' detalhamento(s)</small></div><strong>'+money(group.total??group.children.reduce((a,x)=>a+(x.total||0),0))+'</strong>'+drillEntry('center',group.name,group.name,group.total)+'</div>'+(group.children.length?'<div class="v168-context-children">'+group.children.slice(0,8).map(x=>'<span><b>'+esc(group.name)+' · '+esc(window.LTSCategoryDisplay.category(x.name))+'</b><strong>'+money(x.total)+'</strong></span>').join('')+'</div>':'')+'</section>').join('')||'<div class="v168-empty">'+(st.expense.context==null?'Detalhamento de contextos indisponível neste momento.':'Sem contextos no período.')+'</div>')+'</div></article></div>'}
    async function openExpenseDrilldown(entry){if(!entry)return;const owner=syncExpenseReaders(),s=st.expense,token=s.token;if(!expenseReaderCurrent(owner))return;const range=expenseRange(st.expense.key),bg=modal(entry.dimension==='category'?window.LTSCategoryDisplay.category(entry.label):entry.label,range.label+' · '+date(range.from)+' a '+date(range.to),'<div class="v168-drill-body">'+loading()+'</div>');try{const j=await rpcRead('lts_browser_expense_drilldown_v1',{p_from:range.from,p_to:range.to,p_dimension:entry.dimension,p_key:entry.key},2,()=>expenseReadCurrent('expense',s,token,owner));if(!expenseReadCurrent('expense',s,token,owner))return;const rows=arr(j?.rows).length?arr(j.rows):arr(j?.items),total=num(j?.summary?.total??j?.total??entry.total),body=bg.querySelector('.v168-drill-body');body.innerHTML='<div class="v168-kpis">'+kpi('Total selecionado',total,rows.length+' lançamento(s)','primary')+'</div><div class="v168-tablewrap" style="margin-top:12px"><table class="v168-table"><thead><tr><th>Data</th><th>Descrição</th><th>Categoria</th><th>Contexto</th><th class="num">Valor</th></tr></thead><tbody>'+(rows.map(x=>'<tr><td>'+date(x.date||x.event_date||x.transaction_date)+'</td><td>'+esc(x.description||x.counterparty||'Lançamento')+'</td><td>'+esc(window.LTSCategoryDisplay.category(x.category||x.category_lts||'—'))+'</td><td>'+esc(x.center_cost||x.context||'—')+'</td><td class="num">'+money(Math.abs(num(x.amount)||0))+'</td></tr>').join('')||'<tr><td colspan="5">Não há linhas individualizadas para este recorte.</td></tr>')+'</tbody></table></div>'}catch(error){if(!expenseReadCurrent('expense',s,token,owner))return;bg.querySelector('.v168-drill-body').innerHTML=errorBox(String(error?.message||error))}}
    function expenseCardsV168(){ensureInvoices();const s=st.invoices,o=D?.card_operating||{},rows=cardDisplayRows(),future=arr(o.contracted_installment_floor_months),byBank=new Map();for(const row of rows){const bank=row.account||cardAccount(row.card_name)||'Outros';if(!byBank.has(bank))byBank.set(bank,[]);byBank.get(bank).push(row)}const detailCount=rows.filter(x=>arr(x.detail_preview).length).length;return '<div class="v168-grid"><div class="v168-kpis">'+kpi('Faturas abertas',o.open_cycles_total,arr(o.open_cycles).length+' fatura(s)','primary')+kpi('A confirmar',o.closed_or_due_total,arr(o.closed_or_due).length+' fatura(s)')+kpi('Parcelas futuras',o.contracted_installment_floor_total,future.length+' competência(s)')+kpiText('Bancos e emissores',byBank.size,'Itaú, Bradesco e C6 quando documentados')+kpiText('Com compras detalhadas',detailCount,rows.length+' fatura(s) listadas')+'</div><article class="v168-card"><div class="v168-cardhead"><div><span>Cartões e faturas</span><h2>Todos os bancos</h2></div><small>'+rows.length+' registro(s)</small></div>'+(s.loading&&!s.rows?loading():s.error&&!s.rows?errorBox(s.error):[...byBank].map(([bank,items])=>'<section class="v168-card-bank"><div class="v168-card-bank-head"><b>'+esc(bank)+'</b><strong>'+money(items.reduce((a,x)=>a+Math.abs(num(x.amount)||0),0))+'</strong></div><div class="v168-invoices">'+items.map(x=>{const i=rows.indexOf(x);return '<div class="v168-invoice"><span>'+date(x.date||x.event_date||x.due_date)+'</span><div><b>'+esc(x.card_name||x.description||'Fatura')+'</b><small>'+esc(x.status||'Fatura')+(arr(x.detail_preview).length?' · '+arr(x.detail_preview).length+' compras detalhadas':' · total preservado')+'</small></div><strong>'+money(Math.abs(num(x.amount)||0))+'</strong><div class="v168-searchactions"><button class="v168-btn primary" data-v168-invoice-detail="'+i+'">Ver composição</button>'+(x.source?'<button class="v168-btn" data-v168-flow-row="invoice-display:'+i+'">Fluxo</button>':'')+'</div></div>'}).join('')+'</div></section>').join('')||'<div class="v168-empty">Nenhuma fatura encontrada.</div>')+'</article><article class="v168-card"><div class="v168-cardhead"><div><span>Parcelas futuras</span><h2>Compromissos já contratados</h2></div><strong>'+money(o.contracted_installment_floor_total)+'</strong></div><div class="v168-statlist">'+(future.map(x=>'<div class="v168-stat"><span><b>'+esc(month(x.reference_month))+'</b><small>'+arr(x.detail).map(y=>y.card_name).filter(Boolean).join(' · ')+'</small></span><b>'+money(x.amount)+'</b></div>').join('')||'<div class="v168-empty">Nenhuma parcela futura documentada.</div>')+'</div></article></div>'}
    function despesasV168Final(){ensureExpense();const s=st.expense,r=s.data||{},range=expenseRange(s.key),meta=sourceLabel(r.period?.last_available||today())+periodButtons();let body=s.loading&&!s.data?loading():s.error&&!s.data?errorBox(s.error)+(s.rangeInvalid?'':'<button type="button" class="v168-btn primary" data-v168-exp-retry>Tentar novamente</button>'):s.tab==='categories'?expenseCategoriesV168(r):s.tab==='cards'?expenseCardsV168():s.tab==='transactions'?expenseTransactions():expenseOverviewV168(r);return '<div class="v168 v168-expenses">'+head('Despesas','Despesas','Análise por período, categoria, contexto, cartões e lançamentos.',meta)+(s.loading&&s.data?'<div class="v168-loadstatus"><i></i><span><b>'+esc(range.label)+'.</b> Atualizando este período…</span></div>':'')+expenseTabs()+body+'</div>'}

    function wealthTabs(){return tabs([['overview','Visão geral'],['rsu','RSUs e awards'],['assets','Bens e dívidas'],['pensions','Previdências']],st.wealth.tab,'data-v168-wealth-tab')}
    function wealthOverview(j){const w=j.wealth||{},s=w.summary||{},x=j.wealth_v168||{},p=j.pensions||{},r=j.rsu_summary||{},c=w.assets?.cipo_396||{},v=w.assets?.volvo_xc40||{},dist=[{name:'CIPÓ 396',total:c.market_central},{name:'Volvo XC40',total:v.market_central},{name:'RSUs e corretora',total:r.available_total_brl},{name:'Previdências',total:p.total_gross_brl},{name:'Liquidez bancária e D0',total:(num(w.liquidity?.bank_cash)||0)+(num(w.liquidity?.d0)||0)}];return '<div class="v168-kpis">'+kpi('Patrimônio líquido central',x.net_worth_central_including_pensions??s.net_worth_central,'inclui previdências brutas','primary')+kpi('Ativos',x.assets_central_including_pensions??s.assets_central,'valor central')+kpi('Dívidas conhecidas',s.known_debt_total,'saldos documentados')+kpi('Liquidez até D+3',s.liquidity_through_d3,'FGTS e previdências separados')+kpi('Previdências',p.total_gross_brl,'restritas · valor bruto')+'</div><div class="v168-grid equal"><article class="v168-card"><div class="v168-cardhead"><div><span>Composição</span><h2>Onde está o patrimônio</h2></div></div>'+rankRows(dist,8)+'</article><article class="v168-card"><div class="v168-cardhead"><div><span>Posições principais</span><h2>Ativos e acesso ao dinheiro</h2></div></div><div class="v168-statlist"><div class="v168-stat"><span>CIPÓ 396<small>mercado central · dívida '+money(c.documentary_debt)+'</small></span><b>'+money(c.market_central)+'</b></div><div class="v168-stat"><span>Volvo XC40<small>mercado central · financiado '+money(v.documented_financed_balance)+'</small></span><b>'+money(v.market_central)+'</b></div><div class="v168-stat"><span>RSUs + saldo em corretora<small>posição disponível em '+date(r.as_of)+'</small></span><b>'+money(r.available_total_brl)+'</b></div><div class="v168-stat"><span>Previdências<small>restritas · saldos brutos</small></span><b>'+money(p.total_gross_brl)+'</b></div><div class="v168-stat"><span>Schiavalli<small>posição documental ainda não localizada</small></span><b>—</b></div></div></article></div>'}
    function awardType(x){return /cash/i.test(String(x.asset_type||''))?'Cash RSU':'RSU'}
    function rsuPanel(j){const r=j.rsu_summary||{},rows=arr(j.rsu?.future_schedule),ret=j.employment_awards?.retention||{};return '<div class="v168-kpis">'+kpi('Já vested · ações',r.vested_shares_brl,date(r.as_of),'primary')+kpi('Saldo em corretora',r.brokerage_cash_brl,date(r.as_of))+kpi('Total disponível',r.available_total_brl,'ações + saldo')+kpi('RSUs futuras',r.future_regular_brl,'100% bruto')+kpi('Cash RSUs futuras',r.future_cash_net_brl,'70% após reserva fiscal')+'</div><article class="v168-card"><div class="v168-cardhead"><div><span>Agenda</span><h2>Vestings e disponibilidade</h2></div><strong>'+money(r.future_considered_total_brl)+'</strong></div><div class="v168-awards">'+rows.map((x,i)=>{const type=awardType(x),value=type==='Cash RSU'?x.net_value_brl:x.gross_value_brl;return '<div class="v168-award"><div><span>Vesting</span><b>'+date(x.eligibility_date)+'</b><small>'+esc(type)+'</small></div><div><span>Quantidade</span><b>'+number(x.quantity)+'</b></div><div><span>Cotação usada</span><b>'+usd(x.unit_price_usd)+'</b><small>câmbio '+fx(x.fx_rate)+'</small></div><div><span>Valor considerado</span><b>'+money(value)+'</b><small>'+date(x.available_date)+' disponível</small></div><label><span>Antecipação opcional</span><input type="date" data-v168-award-date="'+i+'" max="'+esc(x.eligibility_date)+'" value="'+esc(x.anticipated_date||'')+'"></label><div><button class="v168-btn" data-v168-award-edit="'+i+'">Cotação</button> <button class="v168-btn blue" data-v168-award-save="'+i+'">Salvar data</button></div></div>'}).join('')+'</div><div class="v168-note"><b>Datas diferentes:</b> vesting é o direito adquirido; disponibilidade é a data em que entra na liquidez. O Fluxo agora mostra os dois marcos.</div></article><article class="v168-card"><div class="v168-cardhead"><div><span>Retention Award</span><h2>Acordo separado de RSU</h2></div><strong>'+money(ret.gross_total_brl)+'</strong></div><div class="v168-note">As parcelas permanecem separadas de RSU e Cash RSU. Tributação líquida não é presumida sem documento.</div></article>'}
    function commitmentBy(j,id){return arr(j.financing?.summary?.commitments).find(x=>x.id===id)||{}}
    function docBy(j,id){return arr(j.financing?.documentary?.items).filter(x=>x.commitment_id===id).sort((a,b)=>arr(b.schedule_loaded?.rows).length-arr(a.schedule_loaded?.rows).length)[0]||{}}
    function loanCard(j,id,label,type){
      const c=commitmentBy(j,id),doc=docBy(j,id),meta=doc.metadata||{},total=num(c.total_events??meta.total_installments??(id==='cipo_396'?meta.term_total:null)),remaining=num(c.remaining_events??doc.schedule_loaded?.future_loaded_count),paid=num(Object.hasOwn(c,'confirmed_paid_installments')?c.confirmed_paid_installments:meta.paid_installments),progress=total&&paid!=null?clamp(paid/total*100,0,100):0,balance=num(c.current_documentary_debt_balance??doc.debt_balance),future=num(c.remaining_scheduled_outflow_current_terms??c.remaining_scheduled_outflow??c.remaining_economic_outflow??doc.schedule_loaded?.future_loaded_total),unconfirmed=num(c.unconfirmed_past_events??doc.schedule_loaded?.unconfirmed_past_count)||0,asof=c.current_debt_as_of||doc.as_of_date;
      return '<article class="v168-loan" data-v309-contract="'+esc(id)+'"><span>'+esc(type)+'</span><h3>'+esc(label)+'</h3><div class="v168-loanmetrics"><div><span>Saldo documental</span><b>'+money(balance)+'</b></div><div><span>Parcelas futuras</span><b>'+money(future)+'</b></div><div><span>Pagas comprovadas</span><b>'+(paid==null?'—':paid)+'</b></div><div><span>Previstas</span><b>'+(remaining==null?'—':remaining)+'</b></div></div>'+(paid!=null&&total?'<div class="v168-progress"><i style="width:'+progress+'%"></i></div>':'')+(asof&&balance!=null?'<div class="v168-asof">Saldo documental em '+date(asof)+'</div>':'')+(c.next_due?'<div class="v168-asof">Próxima prevista: '+date(c.next_due)+' · '+money(c.next_amount)+'</div>':'')+(unconfirmed?'<div class="v168-note warn" data-v309-unconfirmed>'+unconfirmed+' parcela(s) anterior(es) sem pagamento identificado. Isso não confirma atraso.</div>':'')+'<div style="margin-top:10px"><button class="v168-btn" data-v168-loan="'+id+'">Ver parcelas e detalhes</button>'+(balance==null?'<button class="v168-btn blue" data-v168-go="Atualizações">Atualizar saldo</button>':'')+'</div></article>';
    }
    function assetsPanel(j){const w=j.wealth||{},c=w.assets?.cipo_396||{},v=w.assets?.volvo_xc40||{},r=j.rsu_summary||{},p=j.pensions||{};return '<div class="v168-wealthcards"><article class="v168-asset"><div class="v168-assettop"><div><span>Imóvel</span><h3>CIPÓ 396</h3></div><div class="v168-asof">Participação líquida estimada · dívida em '+date(commitmentBy(j,'cipo_396').current_debt_as_of)+'</div></div><strong>'+money(c.equity_central)+'</strong><div class="v168-facts"><div class="v168-fact"><span>Mercado central</span><b>'+money(c.market_central)+'</b></div><div class="v168-fact"><span>Saldo documental</span><b>'+money(c.documentary_debt)+'</b></div><div class="v168-fact"><span>Compra + reforma</span><b>'+money(c.historical_purchase_plus_reform)+'</b></div><div class="v168-fact"><span>Até o contrato*</span><b>'+money(j.cipo_detail?.contractual_outflow_current_terms_brl)+'</b><small>*termos atuais; sujeito à TR</small></div></div><div style="margin-top:10px"><button class="v168-btn" data-v168-cipo>Ver gastos da obra</button></div></article><article class="v168-asset"><div class="v168-assettop"><div><span>Veículo</span><h3>Volvo XC40</h3></div><div class="v168-asof">posição documental</div></div><strong>'+money(v.equity_central)+'</strong><div class="v168-facts"><div class="v168-fact"><span>Mercado central</span><b>'+money(v.market_central)+'</b></div><div class="v168-fact"><span>Saldo financiado</span><b>'+money(v.documented_financed_balance)+'</b></div></div></article><article class="v168-asset"><div class="v168-assettop"><div><span>Ações</span><h3>RSUs e corretora</h3></div><div class="v168-asof">'+date(r.as_of)+'</div></div><strong>'+money(r.available_total_brl)+'</strong><div class="v168-facts"><div class="v168-fact"><span>Ações vested</span><b>'+money(r.vested_shares_brl)+'</b></div><div class="v168-fact"><span>Saldo em corretora</span><b>'+money(r.brokerage_cash_brl)+'</b></div></div></article><article class="v168-asset"><div class="v168-assettop"><div><span>Previdência</span><h3>Organon + Novartis</h3></div><div class="v168-asof">bruto restrito</div></div><strong>'+money(p.total_gross_brl)+'</strong><div class="v168-note">Regime regressivo. O valor líquido depende do tempo de cada contribuição.</div></article></div><article class="v168-card"><div class="v168-cardhead"><div><span>Financiamentos e empréstimos</span><h2>Saldo, parcelas e progresso</h2></div></div><div class="v168-loans">'+loanCard(j,'cipo_396','CIPÓ 396','Financiamento imobiliário')+loanCard(j,'volvo','Volvo XC40','Financiamento de veículo')+loanCard(j,'coopharma','Coopharma','Empréstimo consignado')+loanCard(j,'pai_mae','Pai e Mãe','Empréstimo familiar')+'</div></article>'}
    function cipoMetrics(j){const rows=arr(j.cipo_detail?.components),value=x=>num(x?.source_paid??x?.ledger_amount??x?.delta),details=rows.filter(x=>norm(x.component_class||x.class||x.kind)==='improvement'&&value(x)!=null),summaries=rows.filter(x=>norm(x.component_class||x.class||x.kind).includes('historical_basis_summary')),purchaseRow=summaries.find(x=>/compra.*(pago|imovel)|aquisi[cç][aã]o/.test(norm(x.description||x.category))),works=details.length?details.reduce((a,x)=>a+(value(x)||0),0):null,purchase=value(purchaseRow),combined=num(j.cipo_detail?.historical_purchase_plus_reform_brl??j.wealth?.assets?.cipo_396?.historical_purchase_plus_reform);return{rows,details,summaries,purchase,works,combined}}
    function wealthOverviewV168(j){const w=j.wealth||{},s=w.summary||{},x=j.wealth_v167||{},p=j.pensions||{},r=j.rsu_summary||{},c=w.assets?.cipo_396||{},v=w.assets?.volvo_xc40||{},liquidity=w.liquidity||{},current=[{name:'CIPÓ 396 · valor de mercado',total:c.market_central},{name:'Volvo XC40 · valor de mercado',total:v.market_central},{name:'RSUs vested + corretora',total:r.available_total_brl},{name:'Contas + aplicações D0',total:(num(liquidity.bank_cash)||0)+(num(liquidity.d0)||0)}],future=[{name:'RSUs futuras',total:r.future_regular_brl},{name:'Cash RSUs futuras · líquido projetado',total:r.future_cash_net_brl}],debts=[{name:'Financiamento imobiliário',total:c.documentary_debt},{name:'Financiamento Volvo',total:v.documented_financed_balance},{name:'Outras dívidas documentadas',total:(num(s.known_debt_total)||0)-(num(c.documentary_debt)||0)-(num(v.documented_financed_balance)||0)}].filter(x=>(num(x.total)||0)>0);return '<div class="v168-kpis">'+kpi('Patrimônio líquido central',x.net_worth_central_including_pensions??s.net_worth_central,'ativos menos dívidas conhecidas','primary')+kpi('Ativos atuais',x.assets_central_including_pensions??s.assets_central,'valor central documentado')+kpi('Dívidas atuais',s.known_debt_total,'saldos devedores documentados')+kpi('Compensação futura',r.future_considered_total_brl,'RSU + Cash RSU; fora do caixa atual')+kpi('Previdências',p.total_gross_brl,'brutas e restritas')+'</div><div class="v168-wealth-layers"><article class="v168-card"><div class="v168-cardhead"><div><span>Hoje</span><h2>Ativos e dinheiro já disponíveis</h2></div><small>posição atual</small></div>'+rankRows(current,10)+'</article><article class="v168-card"><div class="v168-cardhead"><div><span>Futuro</span><h2>Compensação ainda não disponível</h2></div><small>vestings projetados</small></div>'+rankRows(future,10)+'</article><article class="v168-card"><div class="v168-cardhead"><div><span>Restrito</span><h2>Previdências</h2></div><strong>'+money(p.total_gross_brl)+'</strong></div><div class="v168-statlist">'+arr(p.positions).map(row=>'<div class="v168-stat"><span><b>'+esc(row.name)+'</b><small>regime regressivo · posição '+date(row.as_of)+'</small></span><b>'+money(row.gross_balance_brl)+'</b></div>').join('')+'</div></article><article class="v168-card"><div class="v168-cardhead"><div><span>Passivos</span><h2>Dívidas atuais conhecidas</h2></div><strong>'+money(s.known_debt_total)+'</strong></div>'+rankRows(debts,10)+'</article></div>'}
    function rsuPanelV168(j){const r=j.rsu_summary||{},rows=arr(j.rsu?.future_schedule),ret=j.employment_awards?.retention||{},morgan=(num(r.available_total_brl)!=null||num(r.future_considered_total_brl)!=null)?(num(r.available_total_brl)||0)+(num(r.future_considered_total_brl)||0):null;return '<div class="v168-kpis">'+kpi('Total Morgan Stanley',morgan,'disponível + vestings futuros','primary')+kpi('Total disponível',r.available_total_brl,'ações vested + saldo em corretora')+kpi('Ações já vested',r.vested_shares_brl,date(r.as_of))+kpi('Saldo em corretora',r.brokerage_cash_brl,date(r.as_of))+kpi('RSUs futuras',r.future_regular_brl,'100% bruto')+kpi('Cash RSUs futuras',r.future_cash_net_brl,'70% após reserva fiscal')+'</div><article class="v168-card"><div class="v168-cardhead"><div><span>Agenda</span><h2>Vestings e disponibilidade</h2></div><strong>'+money(r.future_considered_total_brl)+'</strong></div><div class="v168-awards">'+rows.map((x,i)=>{const type=awardType(x),value=type==='Cash RSU'?x.net_value_brl:x.gross_value_brl;return '<div class="v168-award"><div><span>Vesting</span><b>'+date(x.eligibility_date)+'</b><small>'+esc(type)+'</small></div><div><span>Quantidade</span><b>'+number(x.quantity)+'</b></div><div><span>Cotação usada</span><b>'+usd(x.unit_price_usd)+'</b><small>câmbio '+fx(x.fx_rate)+'</small></div><div><span>Valor considerado</span><b>'+money(value)+'</b><small>'+date(x.available_date)+' disponível</small></div><label><span>Antecipação opcional</span><input type="date" data-v168-award-date="'+i+'" max="'+esc(x.eligibility_date)+'" value="'+esc(x.anticipated_date||'')+'"></label><div><button class="v168-btn" data-v168-award-edit="'+i+'">Cotação</button> <button class="v168-btn blue" data-v168-award-save="'+i+'">Salvar data</button></div></div>'}).join('')+'</div><div class="v168-note"><b>Conciliação:</b> o total Morgan Stanley soma o que já está disponível e os vestings futuros. Retention Award permanece fora deste total.</div></article><article class="v168-card"><div class="v168-cardhead"><div><span>Retention Award</span><h2>Acordo separado de RSU</h2></div><strong>'+money(ret.gross_total_brl)+'</strong></div><div class="v168-note">As parcelas permanecem separadas de RSU e Cash RSU. Tributação líquida não é presumida sem documento.</div></article>'}
    function loanCardV168(j,id,label,type){return loanCard(j,id,label,type)}
    function assetsPanelV168(j){const w=j.wealth||{},c=w.assets?.cipo_396||{},v=w.assets?.volvo_xc40||{},r=j.rsu_summary||{},p=j.pensions||{},cm=cipoMetrics(j);return '<div class="v168-wealthcards"><article class="v168-asset"><div class="v168-assettop"><div><span>Imóvel</span><h3>CIPÓ 396</h3></div><div class="v168-asof">Participação líquida estimada · dívida em '+date(commitmentBy(j,'cipo_396').current_debt_as_of)+'</div></div><strong>'+money(c.equity_central)+'</strong><div class="v168-facts"><div class="v168-fact"><span>Valor de mercado</span><b>'+money(c.market_central)+'</b></div><div class="v168-fact"><span>Saldo documental</span><b>'+money(c.documentary_debt)+'</b></div><div class="v168-fact"><span>Compra paga</span><b>'+money(cm.purchase)+'</b></div><div class="v168-fact"><span>Obra nos componentes do Excel</span><b>'+money(cm.works)+'</b></div></div><div style="margin-top:10px"><button class="v168-btn" data-v168-cipo>Ver composição e diferenças</button></div></article><article class="v168-asset"><div class="v168-assettop"><div><span>Veículo</span><h3>Volvo XC40</h3></div><div class="v168-asof">posição documental</div></div><strong>'+money(v.equity_central)+'</strong><div class="v168-facts"><div class="v168-fact"><span>Valor de mercado</span><b>'+money(v.market_central)+'</b></div><div class="v168-fact"><span>Saldo financiado</span><b>'+money(v.documented_financed_balance)+'</b></div></div></article><article class="v168-asset"><div class="v168-assettop"><div><span>Ações</span><h3>RSUs e corretora</h3></div><div class="v168-asof">posição '+date(r.as_of)+'</div></div><strong>'+money((num(r.available_total_brl)||0)+(num(r.future_considered_total_brl)||0))+'</strong><div class="v168-facts"><div class="v168-fact"><span>Disponível agora</span><b>'+money(r.available_total_brl)+'</b></div><div class="v168-fact"><span>Vestings futuros</span><b>'+money(r.future_considered_total_brl)+'</b></div></div></article><article class="v168-asset"><div class="v168-assettop"><div><span>Previdência</span><h3>Organon + Novartis</h3></div><div class="v168-asof">bruto restrito</div></div><strong>'+money(p.total_gross_brl)+'</strong><div class="v168-note">Regime regressivo. O valor líquido depende do tempo de cada contribuição.</div></article></div><article class="v168-card"><div class="v168-cardhead"><div><span>Financiamentos e empréstimos</span><h2>Saldos atuais, parcelas e progresso</h2></div></div><div class="v168-loans">'+loanCardV168(j,'cipo_396','CIPÓ 396','Financiamento imobiliário')+loanCardV168(j,'volvo','Volvo XC40','Financiamento de veículo')+loanCardV168(j,'coopharma','Coopharma','Empréstimo consignado')+loanCardV168(j,'pai_mae','Pai e Mãe','Empréstimo familiar')+'</div></article>'}
    function openCipoV168(j){return window.__LTS_V178_REVIEW?.openCipoReconciliation(j)}
    function patrimonioV168Final(){ensureWealth();const s=st.wealth,j=s.data||{},body=s.loading&&!s.data?loading():s.error&&!s.data?errorBox(s.error):s.tab==='rsu'?rsuPanelV168(j):s.tab==='assets'?assetsPanelV168(j):s.tab==='pensions'?pensionsPanel(j):wealthOverviewV168(j);return '<div class="v168 v168-wealth">'+head('Patrimônio','Patrimônio','Dinheiro atual, posições futuras, recursos restritos, bens e dívidas.',sourceLabel(j.as_of||today()))+(s.loading&&s.data?'<div class="v168-loadstatus"><i></i><span><b>Posição preservada.</b> Atualizando detalhes…</span></div>':'')+wealthTabs()+body+'</div>'}

    function pensionsPanel(j){const p=j.pensions||{},rows=arr(p.positions);return '<div class="v168-kpis">'+kpi('Total em previdências',p.total_gross_brl,'saldos brutos restritos','primary')+kpi('Organon',rows.find(x=>/organon/i.test(x.name||''))?.gross_balance_brl,'Multiprev')+kpi('Novartis',rows.find(x=>/novartis/i.test(x.name||''))?.gross_balance_brl,'Plano D')+'</div><div class="v168-pensions">'+rows.map(x=>'<article class="v168-pension"><span>Previdência privada</span><h3>'+esc(x.name)+'</h3><strong>'+money(x.gross_balance_brl)+'</strong><dl><dt>Posição</dt><dd>'+date(x.as_of)+'</dd><dt>Regime</dt><dd>Regressivo</dd><dt>Perfil</dt><dd>'+esc(x.profile||'—')+'</dd><dt>Saldo participante</dt><dd>'+money(x.participant_balance_brl)+'</dd><dt>Saldo patrocinadora</dt><dd>'+money(x.sponsor_balance_brl)+'</dd><dt>Rentabilidade do mês</dt><dd>'+money(x.monthly_return_brl)+' · '+pct(x.monthly_return_pct)+'</dd></dl></article>').join('')+'</div><div class="v168-note warn"><b>Valores brutos e restritos.</b> No regime regressivo, a alíquota depende da idade de cada contribuição; o valor líquido só será mostrado quando houver histórico suficiente.</div>'}
    function patrimonioV168(){ensureWealth();const s=st.wealth,j=s.data||{},body=s.loading&&!s.data?loading():s.error&&!s.data?errorBox(s.error):s.tab==='rsu'?rsuPanel(j):s.tab==='assets'?assetsPanel(j):s.tab==='pensions'?pensionsPanel(j):wealthOverview(j);return '<div class="v168 v168-wealth">'+head('Patrimônio','Patrimônio','Ativos, dívidas, financiamentos, RSUs e previdências com data de posição.',sourceLabel(j.as_of||today()))+wealthTabs()+body+'</div>'}

    function filteredActions(){return actionList(st.updates.recurring)}
    function isStatementAction(x){return /extrato/i.test(String(x.title||x.description||''))}
    function bankFromAction(x){const t=String(x.title||x.description||'');return /bradesco/i.test(t)?'Bradesco':/ita[uú]/i.test(t)?'Itaú':/\bc6\b/i.test(t)?'C6':'Bradesco'}
    function searchRows(){const s=st.search;if(s.loading)return '<div class="v168-empty">Buscando em todo o histórico…</div>';if(s.error)return errorBox(s.error);if(!s.query)return '<div class="v168-empty">Digite uma descrição, contraparte, categoria ou valor.</div>';if(!s.rows.length)return '<div class="v168-empty">Nenhum lançamento efetivo encontrado.</div>';return '<div class="v168-searchrows">'+s.rows.map((x,i)=>'<div class="v168-searchrow"><div><b>'+esc(x.description||x.counterparty||window.LTSCategoryDisplay.category(x.category||'Lançamento'))+'</b><small>'+date(x.date||x.event_date)+' · '+esc(x.account||x.card_name||'sem conta')+' · '+esc(window.LTSCategoryDisplay.category(x.category||'sem categoria'))+'</small></div><strong>'+money(x.amount)+'</strong><div class="v168-searchactions"><button class="v168-btn blue" data-v168-search-flow="'+i+'">Ir ao Fluxo</button>'+(x.editable?'<button class="v168-btn primary" data-v168-search-edit="'+i+'">Editar</button>':'')+'</div></div>').join('')+'</div>'}
    async function runSearch(q){const value=String(q||'').trim(),seq=++st.search.seq;st.search.query=value;if(!value){st.search.rows=[];st.search.total=0;st.search.error=null;refresh('Atualizações');return}st.search.loading=true;st.search.error=null;refresh('Atualizações');try{const j=await rpc('lts_browser_transactions_v2',{p_from:'2013-10-10',p_to:null,p_query:value,p_direction:null,p_account:null,p_limit:200,p_offset:0});if(seq!==st.search.seq)return;st.search.rows=effectiveRows(j.rows);st.search.total=st.search.rows.length}catch(x){if(seq!==st.search.seq)return;st.search.error=String(x?.message||x);st.search.rows=[]}finally{if(seq===st.search.seq){st.search.loading=false;refresh('Atualizações')}}}

    function parseNumber(raw,m=1){let s=String(raw||'').trim().toLowerCase().replace(/^r\$\s*/,'').replace(/\s+/g,'');if(!s)return null;if(s.includes(',')&&s.includes('.'))s=s.replace(/\./g,'').replace(',','.');else if(s.includes(','))s=s.replace(',','.');else if((s.match(/\./g)||[]).length>1||/^\d{1,3}\.\d{3}$/.test(s))s=s.replace(/\./g,'');const n=Number(s)*m;return Number.isFinite(n)&&n>0?Math.round(n*100)/100:null}
    function parseAmount(source){let s=String(source||'').replace(/\b(?:final|fim|cart[aã]o|card)\s*[:#-]?\s*\d{4}\b/gi,' ').replace(/\b\d{1,2}[\/-]\d{1,2}(?:[\/-]\d{2,4})?\b/g,' ').replace(/\bdia\s+\d{1,2}\b/gi,' ');const marked=[...s.matchAll(/r\$\s*(\d{1,3}(?:\.\d{3})*(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?)\s*(mil|k)?/gi)];if(marked.length)return parseNumber(marked[0][1],marked[0][2]?1000:1);const scaled=[...s.matchAll(/\b(\d+(?:[.,]\d{1,2})?)\s*(mil|k)\b/gi)];if(scaled.length)return parseNumber(scaled[0][1],1000);const plain=[...s.matchAll(/\b(\d{1,3}(?:\.\d{3})*(?:,\d{1,2})?|\d+(?:,\d{1,2})?)\b/g)].map(x=>parseNumber(x[1])).filter(x=>x!=null);return plain.length?Math.max(...plain):null}
    function phraseDate(n){let d=today(),explicit=false;if(/\bamanha\b/.test(n)){d=addDays(d,1);explicit=true}else if(/\bontem\b/.test(n)){d=addDays(d,-1);explicit=true}else if(/\bhoje\b/.test(n))explicit=true;else{const m=n.match(/\b(\d{1,2})[\/-](\d{1,2})(?:[\/-](\d{2,4}))?\b/);if(m){let y=m[3]?Number(m[3]):Number(d.slice(0,4));if(y<100)y+=2000;d=y+'-'+String(Number(m[2])).padStart(2,'0')+'-'+String(Number(m[1])).padStart(2,'0');explicit=true}}return{date:d,explicit}}
    function parsePhrase(source){const original=String(source||'').trim(),n=norm(original),when=phraseDate(n),amount=parseAmount(original),accounts=['Itaú','Bradesco','C6'],mentions=accounts.filter(a=>n.includes(norm(a)));if(/transfer|transferencia/.test(n)){let from=mentions[0]||'',to=mentions[1]||'';for(const a of accounts){const na=norm(a),i=n.indexOf(na);if(i>=0){const before=n.slice(Math.max(0,i-12),i);if(/(para|pro|à|a)\s*$/.test(before))to=a;if(/(do|da|de)\s*$/.test(before))from=a}}return{kind:'transfer',original,event_date:when.date,amount,from_account:from,to_account:to,description:original,missing:[amount==null?'valor':null,!when.explicit?'data explícita':null,!from?'conta de origem':null,!to?'conta de destino':null].filter(Boolean)}}const income=/(recebi|receber|reembolso|salario|adiantamento|entrada|caiu|credito)/.test(n)&&!/(paguei|pagar|gastei|comprei|saida)/.test(n),nature=income?'income':'expense';let account='',card='';if(/aeternum/.test(n))card='Visa Aeternum';else if(/mastercard|personnalite|final\s*5546/.test(n))card='Personnalite Black Pontos final 5546';else if(/cartao\s*c6|c6\s*card/.test(n))card='Cartão C6';else if(/itau/.test(n))account='Itaú';else if(/bradesco/.test(n))account='Bradesco';else if(/\bc6\b/.test(n))account='C6';let category='A classificar',cost='',counter='';if(/fisioterapia|reumato|saude|pediatra|vacina|sulamerica|sul america/.test(n))category='Saúde';else if(/escola|educacao|mensalidade escolar/.test(n))category='Educação';else if(/condominio|o parque|aluguel/.test(n)){category='Moradia';cost='Casa'}else if(/enel|eletropaulo|energia/.test(n)){category='Energia';cost='Casa'}else if(/netflix|amazon prime|spotify|apple music|assinatura/.test(n))category='Assinaturas';else if(/uber|\b99\b|taxi/.test(n))category='Transporte';else if(/ifood|restaurante|cafe|padaria/.test(n))category='Alimentação';else if(/volvo|financiamento carro|parcela carro/.test(n))category='Financiamento veículo';if(/benjamin/.test(n))cost='Benjamin';else if(/larissa/.test(n))cost='Larissa';else if(/lucas/.test(n))cost='Lucas';else if(/rafiki/.test(n))cost='Rafiki';return{kind:'entry',original,event_date:when.date,amount,nature,account,card,category,cost_center:cost,counterparty:counter,description:original,missing:[amount==null?'valor':null,!when.explicit?'data explícita':null,!account&&!card?'conta ou cartão':null,category==='A classificar'?'categoria':null].filter(Boolean)}}
    function nlPreview(){const p=st.nl.preview;if(!p)return'';if(p.kind==='transfer')return '<div class="v168-nlpreview"><label>Data<input id="v168NlDate" type="date" value="'+esc(p.event_date)+'"></label><label>Valor<input id="v168NlAmount" inputmode="decimal" value="'+esc(p.amount||'')+'"></label><label>Origem<select id="v168NlFrom"><option></option>'+['Itaú','Bradesco','C6'].map(x=>'<option '+(x===p.from_account?'selected':'')+'>'+x+'</option>').join('')+'</select></label><label>Destino<select id="v168NlTo"><option></option>'+['Itaú','Bradesco','C6'].map(x=>'<option '+(x===p.to_account?'selected':'')+'>'+x+'</option>').join('')+'</select></label><label class="wide">Descrição<input id="v168NlDesc" value="'+esc(p.description)+'"></label></div><div class="v168-note"><b>Transferência própria:</b> serão criadas duas pernas, com efeito consolidado zero.</div><label class="v168-confirm"><input type="checkbox" id="v168NlConfirm">Revisei data, valor, origem e destino.</label><button class="v168-btn primary" id="v168NlApply" disabled>Confirmar transferência</button>';return '<div class="v168-nlpreview"><label>Data<input id="v168NlDate" type="date" value="'+esc(p.event_date)+'"></label><label>Valor<input id="v168NlAmount" inputmode="decimal" value="'+esc(p.amount||'')+'"></label><label>Natureza<select id="v168NlNature"><option value="expense" '+(p.nature==='expense'?'selected':'')+'>Despesa</option><option value="income" '+(p.nature==='income'?'selected':'')+'>Receita</option></select></label><label>Conta<select id="v168NlAccount"><option></option>'+['Itaú','Bradesco','C6'].map(x=>'<option '+(x===p.account?'selected':'')+'>'+x+'</option>').join('')+'</select></label><label>Cartão<select id="v168NlCard"><option></option>'+['Visa Aeternum','Personnalite Black Pontos final 5546','Cartão C6'].map(x=>'<option '+(x===p.card?'selected':'')+'>'+x+'</option>').join('')+'</select></label><label>Categoria<input id="v168NlCategory" value="'+esc(p.category)+'"></label><label>Contexto<input id="v168NlCost" value="'+esc(p.cost_center)+'"></label><label class="wide">Descrição<input id="v168NlDesc" value="'+esc(p.description)+'"></label></div><div class="v168-note"><b>Nada foi gravado.</b> A interpretação é editável e só será aplicada após sua confirmação.</div><label class="v168-confirm"><input type="checkbox" id="v168NlConfirm">Revisei data, valor, natureza, conta/cartão, categoria e descrição.</label><button class="v168-btn primary" id="v168NlApply" disabled>Confirmar lançamento</button>'}
    function coverageAudit(){
      const j=st.updates.recurring,checks=arr(j?.horizon_checks),years=[...new Set(checks.flatMap(x=>arr(x.period_coverage).map(p=>String(p.period_start||'').slice(0,4))).filter(Boolean))].sort();
      if(!j)return '';
      const year=years.includes(String(st.coverageYear))?String(st.coverageYear):(years[0]||String(today().slice(0,4)));st.coverageYear=year;
      const months=['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'];
      const tools=window.parent.LTSV268ReadTools;
      const rows=checks.map(x=>{const periods=arr(x.period_coverage).filter(p=>String(p.period_start||'').startsWith(year)),counts={actual:0,forecast:0,awaiting:0,gap:0,unknown:0,no_payment:0};periods.forEach(p=>counts[tools.periodState(p)]++);return{x,periods,counts}}).filter(r=>r.periods.length);
      const labels={actual:'Realizado',forecast:'Previsão',awaiting:'Pagamento a confirmar',gap:'Sem previsão',unknown:'Sem comprovação',no_payment:'Sem débito'};
      return '<article class="v168-card" id="v237CoverageAudit"><div class="v168-cardhead"><div><span>Recorrências</span><h2>Cobertura das projeções por ano e mês</h2></div><label>Ano <select id="v237CoverageYear" class="v168-btn" aria-label="Ano da auditoria">'+years.map(y=>'<option '+(y===year?'selected':'')+'>'+esc(y)+'</option>').join('')+'</select></label></div><p class="v168-searchmeta">Confira os meses sem previsão e os pagamentos ainda não identificados.</p><details><summary>Como interpretar</summary><p>Realizado, previsto e pagamento a confirmar são situações diferentes. Um mês sem previsão não comprova o fim de uma obrigação. Sem débito identifica um mês sem cobrança pela mudança de vencimento confirmada. Os valores históricos servem apenas como referência.</p></details><p class="v168-searchmeta" hidden></p><div class="v168-actions">'+(rows.map(r=>{
        const gaps=r.periods.filter(p=>tools.periodState(p)==='gap'),awaiting=r.periods.filter(p=>tools.periodState(p)==='awaiting'),first=awaiting[0]||gaps[0]||r.periods[0];
        return '<div class="v168-action" data-coverage-key="'+esc(r.x.key)+'"><div style="min-width:0;flex:1"><b>'+esc(r.x.title||r.x.description)+'</b><small>'+r.counts.actual+' realizado(s) · '+r.counts.forecast+' previsão(ões) · '+r.counts.awaiting+' pagamento(s) a confirmar · '+r.counts.gap+' sem previsão'+(r.counts.no_payment?' · '+r.counts.no_payment+' sem débito':'')+(r.counts.unknown?' · '+r.counts.unknown+' sem comprovação':'')+' · '+(r.x.direction==='income'?'Receita':'Despesa')+'</small><small>'+(gaps.length?'Revisar: '+esc(gaps.map(p=>r.x.cadence==='annual'?year:months[Number(String(p.period_start).slice(5,7))-1]).join(', ')):'Sem lacunas de previsão neste ano. Isto não comprova pagamentos futuros.')+'</small><div class="v268-periods" style="display:flex;flex-wrap:wrap;gap:5px;margin-top:8px">'+r.periods.map(p=>{const state=tools.periodState(p),period=r.x.cadence==='annual'?year:months[Number(String(p.period_start).slice(5,7))-1];return '<button class="v168-btn v268-period" data-period-state="'+state+'" data-v237-coverage-from="'+esc(p.period_start)+'" data-v237-coverage-to="'+esc(p.period_end)+'" title="'+esc(labels[state]+' · '+date(p.period_start)+' a '+date(p.period_end))+'" aria-label="'+esc(period+' · '+labels[state])+'">'+esc(period+' · '+labels[state])+'</button>'}).join('')+'</div>'+(r.x.observed_median_amount_brl!=null?'<small>Referência histórica '+money(Math.abs(Number(r.x.observed_median_amount_brl)))+'</small>':'')+'</div><button class="v168-btn" data-v237-coverage-from="'+esc(first.period_start)+'" data-v237-coverage-to="'+esc(first.period_end)+'">Ver período</button></div>';
      }).join('')||'<div class="v168-empty">Sem séries observadas com cobertura disponível para este ano.</div>')+'</div></article>';
    }
    function updatesV168(){ensureUpdates();const s=st.updates,xs=filteredActions(),of=s.openFinance||{},recurringReview=planningReviewCount(s.recurring),connected=of.connected===true||norm(of.status)==='connected'||arr(of.connections).some(x=>x.status==='connected'),ofLabel=s.openFinance?(connected?'Conectado':'Não conectado'):(s.partErrors?.openFinance?'Consulta indisponível':'Consultando…'),ofNote=s.openFinance?(connected?'conexão ativa':'aguardando conexão'):'aguardando a consulta';return '<div class="v168 v168-updates">'+head('Central de revisão','Ações','Classifique lançamentos, confira previsões e consulte seu histórico.',sourceLabel(today()))+'<div class="v168-kpis">'+kpiText('Ações abertas',actionsSnapshot().ready?xs.length:'—',actionsSnapshot().ready?'a lista abaixo contém '+xs.length:'Atualizando revisões','primary')+kpiText('Séries a revisar',recurringReview==null?'—':recurringReview,'séries distintas até '+(Number(today().slice(0,4))+4))+kpiText('Open Finance',ofLabel,ofNote)+'</div>'+(s.loading&&!s.recurring?loading():s.error&&!s.recurring?actionsWarning():'<div class="v168-updategrid"><article class="v168-card"><div class="v168-cardhead"><div><span>Prioridades</span><h2>Revisões em aberto</h2></div><strong>'+(actionsSnapshot().ready?xs.length:'—')+'</strong></div>'+actionsWarning()+'<div class="v168-actions" id="v333PriorityActions">'+(xs.map((x,i)=>'<div class="v168-action"><i>'+(i+1)+'</i><div><b>'+esc(x.title||x.description||'Revisar')+'</b><small>'+esc(humanText(x.detail||x.review_reason||''))+'</small>'+(num(x.impact_amount)!=null?'<strong>'+esc(x.origin==='card'?'Compras e parcelas conhecidas ':'Referência ')+money(Math.abs(num(x.impact_amount)))+'</strong>':'')+'</div><button class="v168-btn '+(x.origin==='recurring'?'blue':'')+'" data-v168-action="'+i+'">'+(isStatementAction(x)?'Enviar extrato':x.origin==='recurring'?'Revisar sugestão':'Abrir')+'</button></div>').join('')||'<div class="v168-empty">'+(actionsSnapshot().ready?'Nenhuma ação aberta.':'Aguardando as revisões disponíveis.')+'</div>')+'</div></article><div class="v168-grid"><article class="v168-card"><div class="v168-cardhead"><div><span>Open Finance</span><h2>Conexão bancária</h2></div></div><div class="v168-openfinance"><i>OF</i><div><b>'+(s.openFinance?(connected?'Conectado':'Ainda não conectado'):'Consultando conexão…')+'</b><span>'+(s.openFinance?(connected?'Conexões disponíveis para sincronização.':'Confira a conexão bancária em Atualizações.'):'A consulta da conexão está em andamento.')+'</span></div></div></article><article class="v168-card"><div class="v168-cardhead"><div><span>Documento</span><h2>Enviar extrato agora</h2></div></div><button class="v168-btn primary" data-v168-upload="Bradesco">Enviar extrato bancário</button></article></div></div>')+coverageAudit()+'<article class="v168-card" id="v168SearchCard"><div class="v168-cardhead"><div><span>Busca</span><h2>Pesquisar lançamento sem saber a data</h2></div><small id="v168SearchCount">'+(st.search.query?st.search.total+' resultado(s)':'todo o histórico')+'</small></div><div class="v168-searchbox"><input id="v168SearchInput" value="'+esc(st.search.query)+'" placeholder="Ex.: salário, retention, Mastercard, condomínio"><button class="v168-btn primary" id="v168SearchButton">Buscar</button></div><div class="v168-searchmeta">Editar abre exatamente o lançamento no Fluxo quando ele ainda é uma projeção.</div>'+searchRows()+'</article><article class="v168-card v168-nl"><div class="v168-cardhead"><div><span>Entrada inteligente</span><h2>Lançar em texto</h2></div><small>interpretar → revisar → confirmar</small></div><textarea id="v168NlPhrase" placeholder="Ex.: paguei R$ 100 para fulano no Aeternum hoje; transferir R$ 500 do Itaú para o Bradesco hoje">'+esc(st.nl.draft)+'</textarea><div style="margin-top:8px"><button class="v168-btn blue" id="v168NlPreview">Interpretar</button></div>'+(st.nl.error?errorBox(st.nl.error):'')+(st.nl.message?'<div class="v168-note good">'+esc(st.nl.message)+'</div>':'')+nlPreview()+'</article></div>'}

    function modal(title,subtitle,body,small){document.getElementById('v168Modal')?.remove();const bg=document.createElement('div');bg.className='v168-modal-bg';bg.id='v168Modal';bg.innerHTML='<div class="v168-modal '+(small?'small':'')+'" role="dialog" aria-modal="true"><h2>'+esc(title)+'</h2><p>'+esc(subtitle||'')+'</p>'+body+'<div id="v168ModalMsg"></div><div class="v168-modal-actions"><button class="v168-btn" data-v168-close>Fechar</button></div></div>';document.body.appendChild(bg);const close=()=>bg.remove();bg.onclick=x=>{if(x.target===bg)close()};bg.querySelector('[data-v168-close]').onclick=close;return bg}
    function modalMsg(bg,msg,ok){const x=bg.querySelector('#v168ModalMsg');x.className=ok?'v168-modal-ok':'v168-modal-error';x.textContent=msg}
    function openUpload(bank){const bg=modal('Enviar extrato bancário','O arquivo fica privado e entra na trilha de conciliação.','<div class="v168-upload"><label>Banco<select id="v168UpBank">'+['Bradesco','Itaú','C6'].map(x=>'<option '+(x===bank?'selected':'')+'>'+x+'</option>').join('')+'</select></label><label>Data de referência<input id="v168UpDate" type="date" value="'+today()+'"></label><label>Arquivo<input id="v168UpFile" type="file" accept=".pdf,.png,.jpg,.jpeg,.csv,.txt,.tsv,.xlsx,.xls,application/pdf,image/*,text/*"></label><button class="v168-btn primary" id="v168UpSend">Enviar com segurança</button></div>',true);bg.querySelector('#v168UpSend').onclick=()=>uploadStatement(bg)}
    async function uploadStatement(bg){
      const file=bg.querySelector('#v168UpFile')?.files?.[0],button=bg.querySelector('#v168UpSend');
      if(!button||button.dataset.uploadState==='busy'||button.dataset.uploadState==='registered'||button.dataset.uploadState==='uncertain')return;
      const bank=bg.querySelector('#v168UpBank')?.value,ref=bg.querySelector('#v168UpDate')?.value;
      if(!file)return modalMsg(bg,'Escolha um arquivo.',false);
      if(!Number.isFinite(file.size)||file.size<=0||file.size>52428800)return modalMsg(bg,'Escolha um arquivo de até 50 MB, com conteúdo.',false);
      if(!['Bradesco','Itaú','C6'].includes(bank))return modalMsg(bg,'Escolha o banco deste documento.',false);
      if(!/^\d{4}-\d\d-\d\d$/.test(ref||'')||Number.isNaN(Date.parse(ref+'T12:00:00Z'))||new Date(ref+'T12:00:00Z').toISOString().slice(0,10)!==ref)return modalMsg(bg,'Informe uma data de referência válida para o documento.',false);
      const fields=['#v168UpFile','#v168UpBank','#v168UpDate'].map(id=>bg.querySelector(id)).filter(Boolean);
      button.dataset.uploadState='busy';button.disabled=true;button.textContent='Enviando…';fields.forEach(x=>x.disabled=true);
      let uploaded=false,registrationStarted=false,registered=false;
      try{
        const {data:u,error:ue}=await S.auth.getUser();
        if(ue||!u?.user?.id)throw Error('Sessão expirada. Entre novamente.');
        const safe=String(file.name||'extrato').replace(/[^a-zA-Z0-9._-]/g,'_').slice(-120);
        const path=u.user.id+'/'+today()+'/'+crypto.randomUUID()+'-'+safe;
        const {error:se}=await S.storage.from('lts-documents').upload(path,file,{contentType:file.type||'application/octet-stream',upsert:false});
        if(se)throw Error(se.message);
        uploaded=true;registrationStarted=true;
        const inputType=file.type==='application/pdf'||/\.pdf$/i.test(file.name)?'pdf':file.type?.startsWith('image/')?'photo':'file';
        const {data:reg,error:re}=await S.rpc('lts_browser_register_document_v2',{p_storage_path:path,p_original_name:file.name,p_mime_type:file.type||'application/octet-stream',p_size_bytes:file.size,p_input_type:inputType,p_task_context:{source:'v183_guided_bank_statement',document_type:'bank_statement',institution:bank,reference_date:ref,requested_action:'ingest_reconcile',uploaded_at:new Date().toISOString()}});
        if(re||reg?.ok!==true||!reg.inbox_id)throw Error(re?.message||'O registro não devolveu confirmação.');
        registered=true;button.dataset.uploadState='registered';
        modalMsg(bg,'Extrato recebido para revisão · protocolo '+reg.inbox_id+'. Nenhum lançamento financeiro foi criado.',true);
        button.remove();st.updates.recurring=null;
        try{await ensureUpdates(true)}catch{
          modalMsg(bg,'Extrato recebido · protocolo '+reg.inbox_id+'. O arquivo foi preservado; atualize a tela para conferir a fila de revisão.',true);
        }
      }catch(error){
        // A timeout can occur after a committed registration. Never delete the
        // uploaded object or repeat that write merely because the reply was lost.
        if(uploaded&&registrationStarted&&!registered){
          button.dataset.uploadState='uncertain';button.disabled=true;button.textContent='Registro a conferir';
          modalMsg(bg,'O arquivo foi enviado, mas a confirmação do registro não chegou. Ele foi preservado. Confira a fila de documentos antes de reenviar; nenhum lançamento financeiro foi criado automaticamente.',false);
        }else if(!registered){
          button.dataset.uploadState='ready';button.disabled=false;button.textContent='Enviar com segurança';fields.forEach(x=>x.disabled=false);
          modalMsg(bg,'Não foi possível concluir o envio: '+String(error?.message||error),false);
        }
      }
    }

    function nextSuggestion(x){let d=String(x.historical_last_date||today()).slice(0,10),annual=/annual|seasonal/i.test(x.recurrence_pattern||'');do{const z=new Date(d+'T12:00:00Z');annual?z.setUTCFullYear(z.getUTCFullYear()+1):z.setUTCMonth(z.getUTCMonth()+1);d=z.toISOString().slice(0,10)}while(d<today());return d}
    function transferProposal(x){
      const value=[x?.title,x?.description,x?.category,x?.nature,x?.kind].filter(Boolean).join(' ').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
      const banks=[...new Set(value.match(/\b(?:itau|bradesco|c6)\b/g)||[])];
      return x?.internal_transfer===true||x?.is_internal_transfer===true||x?.direction==='transfer'||/transferencia interna|entre contas|internal_transfer/.test(value)||(banks.length>=2&&/recebimento|transfer|\bpara\b|\bde\b/.test(value));
    }
    function reviewTransferProposal(x){
      const query=x.description||x.title||'Transferência';
      const bg=modal('Conferir transferência entre contas','Uma movimentação entre contas próprias não é receita nem despesa.','<div class="v168-note">Confira primeiro os lançamentos de origem e destino já existentes. Esta sugestão não pode criar uma entrada isolada nem escolher uma conta por padrão.</div><p>'+esc(query)+'</p><button class="v168-btn primary" id="v183TransferReview">Conferir lançamentos existentes</button>',true);
      bg.querySelector('#v183TransferReview').onclick=()=>{bg.remove();st.search.query=query;runSearch(query);document.getElementById('v168SearchCard')?.scrollIntoView({behavior:'smooth',block:'start'})};
    }
    function openProposal(x){if(transferProposal(x))return reviewTransferProposal(x);const bg=modal(x.title||x.description||'Revisar recorrência','A sugestão usa a mediana histórica e só entra no Fluxo após confirmação.','<div class="v168-form"><label>Data sugerida<input id="v168PrDate" type="date" min="'+today()+'" value="'+nextSuggestion(x)+'"></label><label>Valor sugerido<input id="v168PrAmount" inputmode="decimal" value="'+esc(num(x.observed_median_amount_brl)||num(x.impact_amount)||'')+'"></label><label class="wide">Descrição<input id="v168PrDesc" value="'+esc(x.description||x.title||'')+'"></label><label>Tipo<select id="v168PrDir"><option value="saida" '+(x.direction==='expense'?'selected':'')+'>Saída</option><option value="entrada" '+(x.direction==='income'?'selected':'')+'>Entrada</option></select></label><label>Conta<select id="v168PrAcc"><option>Itaú</option><option>Bradesco</option><option>C6</option></select></label></div><button class="v168-btn primary" id="v168PrSave">Adicionar ao Fluxo</button>',true);bg.querySelector('#v168PrSave').onclick=async()=>{const amount=parseNumber(bg.querySelector('#v168PrAmount').value);try{await rpc('lts_browser_create_future_event_v1',{p_date:bg.querySelector('#v168PrDate').value,p_description:bg.querySelector('#v168PrDesc').value,p_amount:amount,p_direction:bg.querySelector('#v168PrDir').value,p_account:bg.querySelector('#v168PrAcc').value,p_category:x.category||null});bg.remove();st.updates.recurring=null;toast2('Projeção adicionada ao Fluxo.');ensureUpdates(true)}catch(e){modalMsg(bg,String(e?.message||e),false)}}}
    function openCipo(j){const rows=arr(j.cipo_detail?.components).filter(x=>num(x.source_paid??x.ledger_amount??x.delta)!=null);const bg=modal('CIPÓ 396 · compra e obra','Detalhamento preservado da planilha e das conciliações.','<div class="v168-kpis">'+kpi('Compra + reforma',j.cipo_detail?.historical_purchase_plus_reform_brl,'histórico')+kpi('Saldo para quitação',j.cipo_detail?.current_payoff_brl,'posição documental')+kpi('Até o vencimento',j.cipo_detail?.contractual_outflow_current_terms_brl,'termos atuais · sujeito à TR')+'</div><div class="v168-tablewrap" style="margin-top:12px"><table class="v168-table"><thead><tr><th>Item</th><th>Origem</th><th>Situação</th><th class="num">Valor</th></tr></thead><tbody>'+rows.map(x=>'<tr><td>'+esc(x.description||x.category||'Item')+'</td><td>'+esc(x.origin||'—')+'</td><td>'+esc(x.status==='exact'?'Conciliado':x.status==='source_only'?'Planilha de origem':'Em revisão')+'</td><td class="num">'+money(x.source_paid??x.ledger_amount)+'</td></tr>').join('')+'</tbody></table></div>');return bg}
    function openLoan(j,id){
      const c=commitmentBy(j,id),doc=docBy(j,id),loaded=doc.schedule_loaded||{},rows=arr(loaded.rows??c.schedule_rows),paid=arr(loaded.realized_rows??c.realized_rows),label=c.label||id,meta=doc.metadata||{},unconfirmed=num(c.unconfirmed_past_events??loaded.unconfirmed_past_count)||0,asof=c.current_debt_as_of||doc.as_of_date,future=c.remaining_scheduled_outflow_current_terms??c.remaining_scheduled_outflow??c.remaining_economic_outflow??loaded.future_loaded_total;
      const compare='<div class="v168-grid equal"><div class="v168-note"><b>Saldo documental'+(asof?' em '+date(asof):'')+'</b><br>'+money(c.current_documentary_debt_balance??doc.debt_balance)+'<br><small>Não representa uma cotação atual de quitação.</small></div><div class="v168-note"><b>Parcelas futuras</b><br>'+money(future)+(id==='cipo_396'?'<br><small>Termos recebidos, sujeitos à TR.</small>':'')+'</div></div>';
      const warning=unconfirmed?'<div class="v168-note warn" data-v309-unconfirmed>'+unconfirmed+' parcela(s) anterior(es) sem pagamento identificado. O vencimento, por si só, não comprova pagamento nem atraso.</div>':'';
      const schedule='<h3>Parcelas previstas e pagamentos a confirmar</h3><div class="v168-tablewrap" data-v309-schedule><table class="v168-table"><thead><tr><th>Parcela</th><th>Vencimento</th><th>Situação</th><th class="num">Valor previsto</th><th class="num">Saldo previsto</th></tr></thead><tbody>'+(rows.slice(0,360).map(x=>'<tr><td>'+esc(x.installment_number??'—')+'</td><td>'+date(x.due_date)+'</td><td>'+esc(x.status==='payment_unconfirmed'?'Pagamento a confirmar':'Prevista')+'</td><td class="num">'+money(x.amount)+'</td><td class="num">'+money(x.balance_after)+'</td></tr>').join('')||'<tr><td colspan="5">Cronograma individual não disponível. '+esc(meta.note||c.note||'')+'</td></tr>')+'</tbody></table></div>';
      const realized=paid.length?'<h3>Pagamentos identificados</h3><div class="v168-tablewrap" data-v309-payments><table class="v168-table"><thead><tr><th>Parcela</th><th>Vencimento original</th><th class="num">Valor previsto</th><th>Pagamento</th><th class="num">Valor pago</th></tr></thead><tbody>'+paid.map(x=>'<tr><td>'+esc(x.installment_number??'—')+'</td><td>'+date(x.due_date)+'</td><td class="num">'+money(x.scheduled_amount)+'</td><td>'+date(x.paid_date)+'</td><td class="num">'+money(x.paid_amount)+'</td></tr>').join('')+'</tbody></table></div>':'<div class="v168-note">Nenhum pagamento individual identificado neste cronograma.</div>';
      modal(label,'Cronograma e pagamentos documentados. As parcelas futuras não são saldo devedor.',compare+warning+realized+schedule);
    }
    function openAwardEdit(j,index){const x=arr(j.rsu?.future_schedule)[index];if(!x)return;const bg=modal('Premissas da '+awardType(x),date(x.eligibility_date),' <div class="v168-form"><label>Preço da ação (USD)<input id="v168AwPrice" inputmode="decimal" value="'+esc(x.unit_price_usd??'')+'"></label><label>Câmbio USD/BRL<input id="v168AwFx" inputmode="decimal" value="'+esc(x.fx_rate??'')+'"></label></div><div class="v168-note">RSU normal usa 100%. Cash RSU usa 70% líquido após a reserva de 30% para imposto.</div><button class="v168-btn primary" id="v168AwSave">Salvar premissas</button>',true);bg.querySelector('#v168AwSave').onclick=async()=>{try{await rpc('lts_browser_save_award_assumption_v1',{p_group_key:x.group_key,p_unit_price_usd:parseNumber(bg.querySelector('#v168AwPrice').value),p_fx_rate:parseNumber(bg.querySelector('#v168AwFx').value)});bg.remove();st.wealth.data=null;ensureWealth(true);toast2('Premissas atualizadas.')}catch(e){modalMsg(bg,String(e?.message||e),false)}}}
    async function saveAnticipation(j,index,button){const x=arr(j.rsu?.future_schedule)[index],input=document.querySelector('[data-v168-award-date="'+index+'"]');if(!x||!input)return;button.disabled=true;try{await rpc('lts_browser_save_vesting_anticipation_v1',{p_group_key:x.group_key,p_anticipated_date:input.value||null});st.wealth.data=null;await ensureWealth(true);toast2(input.value?'Cenário de antecipação salvo.':'Antecipação removida.')}catch(e){toast2('Não foi possível salvar: '+String(e?.message||e))}finally{button.disabled=false}}

    function eventId(x){const d=String(x.date||x.event_date||'').slice(0,10),src=x.source||'',ref=x.source_ref||'',desc=x.description||'',amt=x.amount??x.signed_amount??'';return btoa(unescape(encodeURIComponent([d,src,ref,desc,amt].join('|')))).replace(/=+$/,'')}
    function focusFlowRow(row,edit,day){let expanded=false,tries=0;const timer=setInterval(()=>{tries++;const rowEl=document.getElementById('fv-'+day)||document.getElementById('d-'+day);if(rowEl){const exp=rowEl.querySelector('[data-expand]')||rowEl.querySelector('.exp[data-d]');if(exp&&!expanded){expanded=true;if(exp.getAttribute('aria-expanded')!=='true'&&!String(exp.textContent||'').includes('−'))exp.click();return}const normalized={...row,event_date:day,signed_amount:row.signed_amount??row.amount},legacyKey=typeof flowEventKey==='function'?flowEventKey(normalized):'',canonical=document.querySelector('[data-flow-event="'+CSS.escape(eventId(normalized))+'"]'),legacy=legacyKey?document.querySelector('.floweditbtn[data-ekey="'+CSS.escape(legacyKey)+'"]'):null,target=canonical||legacy?.closest('.fx89-detail-row')||rowEl;(target||rowEl).scrollIntoView({behavior:'smooth',block:'center'});target?.classList?.add('v168-flow-truth');if(edit){if(canonical)canonical.querySelector('[data-event-action="edit"]')?.click();else legacy?.click()}clearInterval(timer)}else if(tries>160){clearInterval(timer);toast2('O período foi aberto, mas a linha não ficou disponível.')}},120)}
    function openInFlow(row,edit){const day=String(row.date||row.event_date||'').slice(0,10);if(!day)return toast2('Este lançamento não tem data navegável.');V='Fluxo Diário';if(typeof FLOWPRESET!=='undefined')FLOWPRESET='Período selecionado';if(typeof FLOWFORCEZERO!=='undefined')FLOWFORCEZERO=false;renderNav();render();if(typeof loadFlowRange==='function'){Promise.resolve(loadFlowRange(day,day)).then(()=>focusFlowRow(row,edit,day)).catch(e=>toast2('Não foi possível abrir a data no Fluxo: '+String(e?.message||e)));return}const from=document.getElementById('fvFrom')||document.getElementById('flowFrom'),to=document.getElementById('fvTo')||document.getElementById('flowTo'),apply=document.getElementById('fvApply')||document.getElementById('flowApply');if(from&&to&&apply){from.value=day;to.value=day;apply.click();focusFlowRow(row,edit,day)}else toast2('O Fluxo não ficou disponível para esta data.')}
    function rowFromRef(ref){const [kind,raw]=String(ref||'').split(':'),i=Number(raw);return kind==='invoice'?arr(st.invoices.rows)[i]:kind==='invoice-display'?arr(st.invoices.display)[i]:kind==='transaction'?arr(st.transactions.rows)[i]:null}

    async function applyNatural(){const p=st.nl.preview,check=document.getElementById('v168NlConfirm');if(!p||!check?.checked||st.nl.busy)return;st.nl.busy=true;st.nl.error='';try{const amount=parseNumber(document.getElementById('v168NlAmount')?.value),eventDate=document.getElementById('v168NlDate')?.value,desc=document.getElementById('v168NlDesc')?.value.trim();if(!amount||!eventDate||!desc)throw Error('Preencha data, valor e descrição.');if(p.kind==='transfer'){const from=document.getElementById('v168NlFrom')?.value,to=document.getElementById('v168NlTo')?.value;if(!from||!to||from===to)throw Error('Informe contas de origem e destino diferentes.');await rpc('lts_browser_create_internal_transfer_v1',{p_date:eventDate,p_amount:amount,p_from_account:from,p_to_account:to,p_description:desc,p_idempotency_key:st.nl.key})}else{const nature=document.getElementById('v168NlNature')?.value==='income'?'income':'expense',account=document.getElementById('v168NlAccount')?.value||null,card=document.getElementById('v168NlCard')?.value||null,category=document.getElementById('v168NlCategory')?.value.trim()||'A classificar',cost=document.getElementById('v168NlCost')?.value.trim()||null;if(!account&&!card)throw Error('Escolha uma conta ou cartão.');await rpc('lts_browser_apply_reviewed_input_v1',{p_preview:{...p,event_date:eventDate,amount:nature==='expense'?-amount:amount,nature,account,card,category,cost_center:cost,description:desc,requires_review:false,approved:true,write_allowed:false},p_idempotency_key:st.nl.key})}st.nl={draft:'',preview:null,key:null,busy:false,error:'',message:'Lançamento confirmado e Fluxo atualizado.'};st.dashboard.data=null;refresh('Atualizações')}catch(e){st.nl.busy=false;st.nl.error=String(e?.message||e);refresh('Atualizações')}}

    function bindCommon(){const chartYear=document.getElementById('v242ChartYear');if(chartYear)chartYear.onchange=()=>{st.chartYear=chartYear.value;render()};document.querySelectorAll('[data-v168-go]').forEach(b=>b.onclick=()=>{const route=b.dataset.v168Go;V=route;renderNav();render();if(b.dataset.focus==='search')setTimeout(()=>document.getElementById('v168SearchInput')?.focus(),80)});document.querySelectorAll('[data-v168-dashboard-refresh]').forEach(b=>b.onclick=()=>ensureDashboard(true));document.querySelectorAll('[data-v168-exp-range]').forEach(b=>b.onclick=()=>{if(st.expense.key===b.dataset.v168ExpRange)return;st.expense.key=b.dataset.v168ExpRange;st.expense.data=null;st.transactions.rows=null;render();ensureExpense(true)});document.querySelectorAll('[data-v168-exp-tab]').forEach(b=>b.onclick=()=>{st.expense.tab=b.dataset.v168ExpTab;render()});document.querySelectorAll('[data-v168-wealth-tab]').forEach(b=>b.onclick=()=>{st.wealth.tab=b.dataset.v168WealthTab;render()});document.querySelectorAll('[data-v168-flow-row]').forEach(b=>{const x=rowFromRef(b.dataset.v168FlowRow);b.onclick=()=>x&&openInFlow(x,false)});document.querySelectorAll('[data-v168-invoice-detail]').forEach(b=>b.onclick=()=>openInvoiceDetail(st.invoices.display[Number(b.dataset.v168InvoiceDetail)],b));document.querySelectorAll('[data-v168-upload]').forEach(b=>b.onclick=()=>openUpload(b.dataset.v168Upload));}
    function bindCommonV168(){
      document.querySelectorAll('[data-v333-actions-refresh]').forEach(b=>b.onclick=()=>{ensureUpdates(true);window.__LTS_V226?.refresh?.();});
      bindExpenseTransactionActions();
      bindChart();
      const chartYear=document.getElementById('v242ChartYear');if(chartYear)chartYear.onchange=()=>{st.chartYear=chartYear.value;render()};
      document.querySelectorAll('[data-v168-go]').forEach(b=>b.onclick=()=>{const route=b.dataset.v168Go;V=route;renderNav();render();if(b.dataset.focus==='search')setTimeout(()=>document.getElementById('v168SearchInput')?.focus(),80)});
      document.querySelectorAll('[data-v168-dashboard-refresh]').forEach(b=>b.onclick=()=>ensureDashboard(true));
      bindExpenseDraft();

      const retry=document.querySelector('[data-v168-exp-retry]');if(retry)retry.onclick=()=>{ensureExpense(true);render()};
      document.querySelectorAll('[data-v168-exp-tab]').forEach(b=>b.onclick=()=>{st.expense.tab=b.dataset.v168ExpTab;render()});
      document.querySelectorAll('[data-v168-exp-drill]').forEach(b=>b.onclick=()=>openExpenseDrilldown(arr(st.expense.drill)[Number(b.dataset.v168ExpDrill)]));
      document.querySelectorAll('[data-v168-wealth-tab]').forEach(b=>b.onclick=()=>{st.wealth.tab=b.dataset.v168WealthTab;render()});
      document.querySelectorAll('[data-v168-flow-row]').forEach(b=>{const x=rowFromRef(b.dataset.v168FlowRow);b.onclick=()=>x&&openInFlow(x,false)});
      document.querySelectorAll('[data-v168-invoice-detail]').forEach(b=>b.onclick=()=>openInvoiceDetail(st.invoices.display[Number(b.dataset.v168InvoiceDetail)],b));
      document.querySelectorAll('[data-v168-upload]').forEach(b=>b.onclick=()=>openUpload(b.dataset.v168Upload));
    }
    function bindWealthV168(){const j=st.wealth.data||{};document.querySelector('[data-v168-cipo]')?.addEventListener('click',()=>openCipoV168(j));document.querySelectorAll('[data-v168-loan]').forEach(b=>b.onclick=()=>openLoan(j,b.dataset.v168Loan));document.querySelectorAll('[data-v168-award-edit]').forEach(b=>b.onclick=()=>openAwardEdit(j,Number(b.dataset.v168AwardEdit)));document.querySelectorAll('[data-v168-award-save]').forEach(b=>b.onclick=()=>saveAnticipation(j,Number(b.dataset.v168AwardSave),b))}
    function bindUpdates(){const year=document.getElementById('v237CoverageYear');if(year)year.onchange=()=>{st.coverageYear=year.value;render()};document.querySelectorAll('[data-v237-coverage-from]').forEach(b=>b.onclick=()=>{V='Fluxo Diário';renderNav();loadFlowRange(b.dataset.v237CoverageFrom,b.dataset.v237CoverageTo)});const xs=filteredActions();document.querySelectorAll('[data-v168-action]').forEach(b=>b.onclick=()=>{const x=xs[Number(b.dataset.v168Action)];if(!x)return;if(x.origin==='card')return window.__LTS_V226?.openDetail?.(x.family,x.month);if(isStatementAction(x))return openUpload(bankFromAction(x));if(x.origin==='recurring')return openProposal(x);st.search.query=x.card_name||x.title||'';runSearch(st.search.query)});const input=document.getElementById('v168SearchInput'),button=document.getElementById('v168SearchButton');if(input)input.oninput=()=>{st.search.query=input.value;clearTimeout(st.search.timer);st.search.timer=setTimeout(()=>runSearch(input.value),280)};if(button)button.onclick=()=>runSearch(input?.value||'');document.querySelectorAll('[data-v168-search-flow]').forEach(b=>b.onclick=()=>openInFlow(st.search.rows[Number(b.dataset.v168SearchFlow)],false));document.querySelectorAll('[data-v168-search-edit]').forEach(b=>b.onclick=()=>openInFlow(st.search.rows[Number(b.dataset.v168SearchEdit)],true));const phrase=document.getElementById('v168NlPhrase');if(phrase)phrase.oninput=()=>st.nl.draft=phrase.value;document.getElementById('v168NlPreview')?.addEventListener('click',()=>{st.nl.draft=phrase?.value||'';st.nl.error='';st.nl.message='';if(!st.nl.draft.trim())st.nl.error='Escreva o lançamento antes de interpretar.';else{st.nl.preview=parsePhrase(st.nl.draft);st.nl.key='v168-'+Date.now().toString(36)+'-'+Math.random().toString(36).slice(2,10)}render()});const check=document.getElementById('v168NlConfirm'),apply=document.getElementById('v168NlApply');if(check&&apply)check.onchange=()=>apply.disabled=!check.checked||st.nl.busy;if(apply)apply.onclick=applyNatural}
    function decorateFlow(){if(V!=='Fluxo Diário')return;const foot=document.querySelector('.fv-foot');if(foot&&!foot.querySelector('.v168-history-note'))foot.insertAdjacentHTML('beforeend','<div class="v168-history-note" style="margin-top:5px"><b>Histórico:</b> antes da primeira abertura documental completa, o LTS mostra movimentos e deixa o saldo absoluto em branco — não projeta o saldo atual para trás.</div>')}
    function stamp(){if(window.__LTS_V169_V168_FEEDBACK?.installed||String(window.parent?.__LTS_TOP_CANDIDATE_VERSION||'').startsWith('v169'))return;document.querySelectorAll('.brand small').forEach(n=>{if(n.textContent.trim()!=='V168 · Homologação')n.innerHTML='<b>V168</b> · Homologação'});const badge=window.parent.document.getElementById('scope');const label='V168 · '+(V==='Fluxo Diário'?'Fluxo de caixa':V)+' · Homologação';if(badge&&badge.textContent!==label)badge.textContent=label}
    let mutating=false;function after(){ensureStyle();stamp();bindCommonV168();if(V==='Patrimônio')bindWealthV168();if(V==='Atualizações')bindUpdates();decorateFlow()}
    render=function(){syncExpenseReaders();const saved=preserveExpenseDraftControls();const out=baseRender();restoreExpenseDraftControls(saved);after();return out};
    renderNav=function(){const out=baseNav();stamp();return out};
    dashboard=dashboardV168Final;despesas=despesasV168Final;patrimonio=patrimonioV168Final;atualizacoes=updatesV168;
    const observer=new MutationObserver(()=>{if(mutating)return;mutating=true;requestAnimationFrame(()=>{mutating=false;stamp();decorateFlow()})});observer.observe(document.body,{childList:true,subtree:true});
    if(D&&!N.classList.contains('hidden'))render();
  }

  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return null;return{w,d}}catch{return null}}
  function install(){const f=frame();if(!f)return false;const superseded=f.w.__LTS_V169_V168_FEEDBACK?.installed||String(window.__LTS_TOP_CANDIDATE_VERSION||'').startsWith('v169');if(!superseded){f.d.querySelectorAll('.brand small').forEach(n=>{if(n.textContent.trim()!=='V168 · Homologação')n.innerHTML='<b>V168</b> · Homologação'});if(scope&&scope.textContent!=='V168 · Homologação')scope.textContent='V168 · Homologação'}if(!f.w.__LTS_V166_FEEDBACK?.installed)return false;if(!f.w.__LTS_V168_COMPLETE_REVIEW?.installed&&!f.d.getElementById('lts-v168-runtime')){const s=f.d.createElement('script');s.id='lts-v168-runtime';s.textContent='('+runtime.toString()+')();';(f.d.head||f.d.documentElement).appendChild(s)}const ready=f.w.__LTS_V168_COMPLETE_REVIEW?.installed===true;if(ready&&gate)gate.hidden=true;return ready}
  function burst(){const current=++generation;let n=0;function step(){if(current!==generation)return;const ok=install();n++;if(!ok&&n<320)setTimeout(step,100)}step();[400,900,1800,3600,7000,12000,20000,30000].forEach(ms=>setTimeout(()=>{if(current===generation)install()},ms))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();window.__LTS_TOP_CANDIDATE_VERSION='v168-feedback-package';
})();



;
;
/* LTS V384: lts-v169-v168-feedback-closure.js */
(function(){
  'use strict';
  const outer=document.getElementById('shell'),gate=document.getElementById('gate'),scope=document.getElementById('scope');
  let generation=0;

  function runtime(){
    'use strict';
    if(window.__LTS_V169_V168_FEEDBACK?.installed||!window.__LTS_V168_COMPLETE_REVIEW?.installed)return;
    const baseRender=render,baseNav=renderNav,baseDashboard=dashboard,baseExpenses=despesas,baseWealth=patrimonio;
    const baseOpenFlowEditor=openFlowEditor,baseFlowEditorInline=flowEditorInline,baseSaveFlowEdit=saveFlowEdit,baseDeleteFlowEvent=deleteFlowEvent;
    const v168=window.__LTS_V168_STATE;
    const state=window.__LTS_V169_STATE||(window.__LTS_V169_STATE={
      monthly:{loading:false,key:'',data:null,error:null,token:0},
      cardBank:'all'
    });
    window.__LTS_V169_V168_FEEDBACK={
      installed:true,version:'v169',base_version:'v168',public_index_changed:false,
      monthly_balance:true,card_future_by_bank:true,paired_transfer_crud:true,
      explicit_passive_layers:true,dashboard_total_emphasis:true,
      historical_card_coverage_disclosed:true
    };

    const arr=v=>Array.isArray(v)?v:[];
    const finite=v=>v===null||v===undefined||v===''?null:(Number.isFinite(Number(v))?Number(v):null);
    const esc169=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
    const norm169=s=>String(s??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
    const brl169=v=>finite(v)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(v));
    const date169=v=>{const p=String(v||'').slice(0,10).split('-');return p.length===3?p.reverse().join('/'):'—'};
    const month169=v=>{const key=String(v||'').slice(0,7);return /^\d{4}-\d{2}$/.test(key)?new Intl.DateTimeFormat('pt-BR',{month:'short',year:'2-digit'}).format(new Date(key+'-01T12:00:00Z')).replace('.',''):key||'—'};
    const today169=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
    const addMonths169=(iso,n)=>{const d=new Date(iso+'T12:00:00Z');d.setUTCMonth(d.getUTCMonth()+n);return d.toISOString().slice(0,10)};
    const sum169=xs=>arr(xs).reduce((s,x)=>s+(finite(x)||0),0);
    function template(html){const t=document.createElement('template');t.innerHTML=html;return t}
    function range169(){const s=v168.expense,t=today169(),year=t.slice(0,4),key=s.key;if(key==='6m')return{from:addMonths169(t,-5).slice(0,8)+'01',to:t,label:'Últimos 6 meses'};if(key==='12m')return{from:addMonths169(t,-11).slice(0,8)+'01',to:t,label:'Últimos 12 meses'};if(key==='all')return{from:'2013-10-10',to:t,label:'Desde 2013'};if(key==='custom'&&/^\d{4}-\d{2}-\d{2}$/.test(s.customFrom)&&/^\d{4}-\d{2}-\d{2}$/.test(s.customTo))return{from:s.customFrom,to:s.customTo,label:date169(s.customFrom)+' a '+date169(s.customTo)};return{from:year+'-01-01',to:t,label:'Ano atual'}}
    function rank169(rows){const xs=arr(rows),top=Math.max(1,...xs.map(x=>Math.abs(finite(x.total)||0)));return '<div class="v168-rank">'+(xs.map(x=>'<div class="v168-rankrow"><b>'+esc169(x.name||x.label||'Outros')+'</b><i><u style="width:'+Math.max(2,Math.abs(finite(x.total)||0)/top*100)+'%"></u></i><strong>'+brl169(x.total)+'</strong></div>').join('')||'<div class="v168-empty">Sem composição para este período.</div>')+'</div>'}

    function findKpi(section,label){return [...section.querySelectorAll('.v168-kpi')].find(x=>norm169(x.querySelector('span')?.textContent)===norm169(label))}
    function markTotal(section,label,newLabel,value,note){section.querySelectorAll('.v168-kpi').forEach(x=>x.classList.remove('primary'));const k=findKpi(section,label);if(!k)return;k.classList.add('primary');if(newLabel)k.querySelector('span').textContent=newLabel;if(value!==undefined)k.querySelector('strong').textContent=brl169(value);if(note)k.querySelector('small').textContent=note}
    function dashboardV169(){
      const t=template(baseDashboard()),root=t.content.querySelector('.v168-dashboard');if(!root)return t.innerHTML;
      const sections=[...root.querySelectorAll('.v168-kpi-section')],data=v168.dashboard.data||{},wealth=data.wealth||{},liquidity=wealth.wealth?.liquidity||{},rsu=wealth.rsu_summary||{},flow=data.flow||{},days=arr(flow.flow?.current_future?.days),todayRow=days.find(x=>x.date===today169())||null;
      const availableParts=[finite(todayRow?.Consolidado?.bank_balance),finite(liquidity.d0),finite(rsu.available_total_brl)].filter(x=>x!=null),available=availableParts.length?sum169(availableParts):null;
      if(sections[0])markTotal(sections[0],'Recursos mapeados','Total disponível hoje',available,'contas + D0 + RSUs já disponíveis');
      if(sections[1])markTotal(sections[1],'Compensação futura','Total de posições futuras',finite(rsu.future_considered_total_brl),'RSU + Cash RSU; ainda fora do caixa atual');
      if(sections[2]){
        sections[2].querySelectorAll('.v168-kpi').forEach(x=>x.classList.remove('primary'));
        const pension=findKpi(sections[2],'Previdências'),expense=findKpi(sections[2],'Despesas do período');
        pension?.classList.add('primary');expense?.classList.add('primary');
        if(pension)pension.querySelector('span').textContent='Total em previdências';
        if(expense)expense.querySelector('span').textContent='Total de despesas do período';
      }
      const expenseCard=[...root.querySelectorAll('.v168-card')].find(x=>/principais grupos/i.test(x.querySelector('h2')?.textContent||'')),raw=arr(data.expense?.rankings?.categories),coverage=raw.find(x=>/detalhe hist[oó]rico n[aã]o recuperado|faturas hist[oó]ricas sem compras/i.test(String(x.name||x.category||''))),groups=raw.filter(x=>x!==coverage).map(x=>{let name=x.name||x.category||'Outros';if(norm169(name)==='compromissos financeiros')name='Empréstimo consignado · Coopharma';return{name,total:x.total??x.amount}}).slice(0,6);
      if(expenseCard){expenseCard.querySelector('.v168-rank,.v168-empty')?.remove();expenseCard.insertAdjacentHTML('beforeend',rank169(groups)+(coverage?'<div class="v169-coverage"><b>Faturas históricas sem compras individualizadas · '+brl169(coverage.total??coverage.amount)+'</b><span>O total das faturas foi preservado, mas as compras desses ciclos não estão disponíveis. O LTS não inventa estabelecimentos nem categorias.</span></div>':''))}
      return t.innerHTML;
    }

    async function ensureMonthly(force){
      const r=range169(),key=r.from+'|'+r.to,s=state.monthly,changed=s.key!==key;if(!force&&!changed&&(s.loading||s.data))return;
      const token=++s.token;s.loading=true;s.key=key;s.error=null;if(force||changed)s.data=null;
      try{const {data,error}=await S.rpc('lts_browser_monthly_balance_v1',{p_from:r.from,p_to:r.to});if(error||!data)throw Error(error?.message||'Balanço mensal indisponível');if(token===s.token)s.data=data}catch(e){if(token===s.token)s.error=String(e?.message||e)}finally{if(token===s.token){s.loading=false;if(V==='Despesas'&&v168.expense.tab==='monthly')render()}}
    }
    function monthlyMatrix(title,subtitle,groups,kind){const data=state.monthly.data||{},months=arr(data.months);return '<article class="v169-balance-section '+kind+'"><div class="v168-cardhead"><div><span>'+esc169(subtitle)+'</span><h2>'+esc169(title)+'</h2></div><small>'+groups.length+' grupo(s)</small></div><div class="v169-matrix-wrap"><table class="v169-matrix"><thead><tr><th>Grupo</th>'+months.map(m=>'<th>'+esc169(month169(m))+'</th>').join('')+'<th>Total</th></tr></thead><tbody>'+(groups.map(g=>'<tr><th><b>'+esc169(g.label)+'</b><small>'+esc169(String(g.source_rows||0))+' origem(ns)</small></th>'+arr(g.monthly).map(x=>'<td class="'+((finite(x.amount)||0)<0?'negative':'')+'">'+((finite(x.amount)||0)?brl169(x.amount):'—')+'</td>').join('')+'<td class="total">'+brl169(g.total)+'</td></tr>').join('')||'<tr><td colspan="'+(months.length+2)+'" class="v168-empty">Sem valores neste período.</td></tr>')+'</tbody></table></div></article>'}
    function monthlyPanel(){
      ensureMonthly(false);const s=state.monthly,j=s.data||{},tot=j.totals||{},months=arr(j.monthly_totals),coverage=j.coverage||{};
      if(s.loading&&!s.data)return '<div class="v168-skeleton" aria-label="Carregando balanço mensal"></div>';
      if(s.error&&!s.data)return '<div class="v168-error">'+esc169(s.error)+'</div><button class="v168-btn primary" data-v169-month-retry>Tentar novamente</button>';
      const balance=finite(tot.operating_balance)||0,cash=finite(tot.cash_after_extraordinary)||0;
      return '<div class="v169-monthly"><div class="v168-kpis"><article class="v168-kpi primary"><span>Total de receitas</span><strong>'+brl169(tot.revenue)+'</strong><small>entradas recorrentes e operacionais</small></article><article class="v168-kpi"><span>Total de despesas</span><strong>'+brl169(tot.expenses)+'</strong><small>consumo por competência</small></article><article class="v168-kpi '+(balance<0?'v169-negative':'')+'"><span>Saldo mensal operacional</span><strong>'+brl169(balance)+'</strong><small>receitas menos despesas</small></article><article class="v168-kpi"><span>Entradas extraordinárias</span><strong>'+brl169(tot.extraordinary)+'</strong><small>empréstimos, FGTS e venda de bens</small></article><article class="v168-kpi '+(cash<0?'v169-negative':'')+'"><span>Saldo após extraordinárias</span><strong>'+brl169(cash)+'</strong><small>explica a cobertura pontual de caixa</small></article></div><div class="v169-month-cards">'+months.map(x=>'<article class="'+((finite(x.operating_balance)||0)<0?'negative':'positive')+'"><span>'+esc169(month169(x.month))+'</span><dl><dt>Receitas</dt><dd>'+brl169(x.revenue)+'</dd><dt>Despesas</dt><dd>'+brl169(x.expenses)+'</dd><dt>Saldo operacional</dt><dd>'+brl169(x.operating_balance)+'</dd><dt>Extraordinárias</dt><dd>'+brl169(x.extraordinary)+'</dd></dl></article>').join('')+'</div>'+monthlyMatrix('Receitas mês a mês','Parte de cima',arr(j.revenue_groups),'revenue')+monthlyMatrix('Entradas extraordinárias','Separadas das receitas',arr(j.extraordinary_groups),'extraordinary')+monthlyMatrix('Principais grupos de despesa','Parte de baixo',arr(j.expense_groups),'expense')+monthlyTotalsTable(months)+'<div class="v169-coverage"><b>Como este balanço evita dupla contagem</b><span>Transferências internas, aplicações e pagamentos de fatura não entram como consumo. As compras de cartão entram uma única vez. Entradas extraordinárias ficam separadas das receitas.</span>'+(finite(coverage.historical_invoice_aggregate)>0?'<span><strong>'+brl169(coverage.historical_invoice_aggregate)+'</strong> em faturas históricas têm o total preservado, mas não compras individualizadas ('+esc169(coverage.historical_invoice_months||0)+' competência(s)).</span>':'')+'</div></div>';
    }
    function monthlyTotalsTable(rows){return '<article class="v169-balance-section totals"><div class="v168-cardhead"><div><span>Fechamento</span><h2>Saldo de cada mês</h2></div><small>positivo ou negativo</small></div><div class="v169-matrix-wrap"><table class="v169-matrix compact"><thead><tr><th>Mês</th><th>Receitas</th><th>Despesas</th><th>Saldo operacional</th><th>Extraordinárias</th><th>Saldo após extraordinárias</th></tr></thead><tbody>'+rows.map(x=>'<tr><th>'+esc169(month169(x.month))+'</th><td>'+brl169(x.revenue)+'</td><td>'+brl169(x.expenses)+'</td><td class="'+((finite(x.operating_balance)||0)<0?'negative':'positive')+'">'+brl169(x.operating_balance)+'</td><td>'+brl169(x.extraordinary)+'</td><td class="'+((finite(x.cash_after_extraordinary)||0)<0?'negative':'positive')+'">'+brl169(x.cash_after_extraordinary)+'</td></tr>').join('')+'</tbody></table></div></article>'}

    function cardBank(name){const n=norm169(name);if(n.includes('aeternum')||n.includes('bradesco'))return'Bradesco';if(n.includes('c6')||n.includes('carbon'))return'C6';if(n.includes('personnalite')||n.includes('mastercard')||n.includes('itau'))return'Itaú';return'Outros'}
    function cardsPanel169(){
      const o=D?.card_operating||{},filter=state.cardBank,match=x=>filter==='all'||cardBank(x.card_name||x.description)===filter,cycles=[...arr(o.open_cycles).map(x=>({...x,stateLabel:'Fatura aberta'})),...arr(o.closed_or_due).map(x=>({...x,stateLabel:x.state==='payment_evidence_needed'?'Fechada · pagamento a confirmar':'Fatura fechada'}))].filter(match),floors=arr(o.contracted_installment_floor_months),map=new Map(),ensure=m=>{const key=String(m).slice(0,7);if(!map.has(key))map.set(key,{month:key,invoices:[],installments:[]});return map.get(key)};
      cycles.forEach(x=>{const key=String(x.due_date||'').slice(0,7);if(key)ensure(key).invoices.push(x)});floors.forEach(m=>arr(m.detail).filter(match).forEach(x=>ensure(m.reference_month).installments.push({...x,reference_month:m.reference_month})));
      const rows=[...map.values()].filter(x=>x.month>=today169().slice(0,7)).sort((a,b)=>a.month.localeCompare(b.month)),openTotal=sum169(cycles.map(x=>x.amount)),floorTotal=sum169(rows.flatMap(x=>x.installments).map(x=>x.amount)),consideredTotal=sum169(rows.map(x=>x.invoices.length?sum169(x.invoices.map(y=>y.amount)):sum169(x.installments.map(y=>y.amount)))),banks=['all','Itaú','Bradesco','C6'];
      return '<div class="v169-cards"><div class="v169-bank-filter" role="tablist" aria-label="Filtrar cartões por banco">'+banks.map(x=>'<button type="button" class="v168-btn '+(filter===x?'primary':'')+'" data-v169-card-bank="'+esc169(x)+'">'+(x==='all'?'Todos os bancos':esc169(x))+'</button>').join('')+'</div><div class="v168-kpis"><article class="v168-kpi primary"><span>Considerado no Fluxo</span><strong>'+brl169(consideredTotal)+'</strong><small>fatura quando conhecida; senão piso contratado</small></article><article class="v168-kpi"><span>Faturas abertas/fechadas</span><strong>'+brl169(openTotal)+'</strong><small>'+cycles.length+' ciclo(s) no filtro</small></article><article class="v168-kpi"><span>Piso futuro contratado</span><strong>'+brl169(floorTotal)+'</strong><small>parcelas já conhecidas</small></article><article class="v168-kpi"><span>Meses à frente</span><strong>'+esc169(rows.length)+'</strong><small>'+esc169(filter==='all'?'todos os bancos':filter)+'</small></article></div><article class="v168-card"><div class="v168-cardhead"><div><span>Conferência com o banco</span><h2>Valores futuros mês a mês</h2></div><small>'+esc169(filter==='all'?'visão consolidada':filter)+'</small></div><div class="v169-card-months">'+(rows.map(x=>{const invoice=sum169(x.invoices.map(y=>y.amount)),floor=sum169(x.installments.map(y=>y.amount)),considered=x.invoices.length?invoice:floor,source=x.invoices.length?'Fatura já observada':'Piso das parcelas contratadas',details=[...x.invoices.map(y=>(y.card_name||'Cartão')+' · '+y.stateLabel),...x.installments.map(y=>(y.card_name||'Cartão')+' · parcela conhecida')];return '<div class="v169-card-month"><div><span>'+esc169(month169(x.month))+'</span><b>'+esc169(source)+'</b><small>'+esc169(details.join(' · ')||'Sem detalhe')+'</small></div><dl><dt>Fatura conhecida</dt><dd>'+brl169(invoice)+'</dd><dt>Piso parcelado</dt><dd>'+brl169(floor)+'</dd><dt>Valor usado no Fluxo</dt><dd><strong>'+brl169(considered)+'</strong></dd></dl></div>'}).join('')||'<div class="v168-empty">Nenhum valor futuro documentado para este banco.</div>')+'</div></article><div class="v169-coverage"><b>Regra de conferência</b><span>Quando já existe uma fatura observada, ela é o valor usado no Fluxo. Nos meses ainda sem fatura, o LTS mostra o piso das parcelas contratadas; compras novas podem aumentar o valor final.</span></div></div>';
    }
    function expensesV169(){
      const t=template(baseExpenses()),root=t.content.querySelector('.v168-expenses'),tabs=root?.querySelector('.v168-tabs');if(!root||!tabs)return t.innerHTML;
      if(!tabs.querySelector('[data-v168-exp-tab="monthly"]'))tabs.insertAdjacentHTML('beforeend','<button type="button" role="tab" aria-selected="'+(v168.expense.tab==='monthly')+'" class="'+(v168.expense.tab==='monthly'?'active':'')+'" data-v168-exp-tab="monthly">Balanço mensal</button>');
      if(v168.expense.tab==='monthly'||v168.expense.tab==='cards'){
        let n=tabs.nextSibling;while(n){const next=n.nextSibling;n.remove();n=next}
        tabs.insertAdjacentHTML('afterend',v168.expense.tab==='monthly'?monthlyPanel():cardsPanel169());
      }
      return t.innerHTML;
    }

    function commitment(j,id){return arr(j.financing?.summary?.commitments).find(x=>x.id===id)||{}}
    function obligationValue(x){return finite(x.remaining_scheduled_outflow_current_terms??x.remaining_scheduled_outflow??x.remaining_economic_outflow)}
    function wealthV169(){
      const html=baseWealth(),t=template(html),root=t.content.querySelector('.v168-wealth'),j=v168.wealth.data||{};if(!root||v168.wealth.tab!=='overview'||!j.wealth)return t.innerHTML;
      const summary=j.wealth.summary||{},c=j.wealth.assets?.cipo_396||{},v=j.wealth.assets?.volvo_xc40||{},co=commitment(j,'coopharma'),family=commitment(j,'pai_mae'),coValue=obligationValue(co),familyValue=obligationValue(family),obligations=[{name:'Empréstimo consignado · Coopharma',total:coValue,note:(co.remaining_events??'—')+' parcela(s) remanescente(s)'},{name:'Empréstimo familiar · Pai e Mãe',total:familyValue,note:(family.remaining_events??'—')+' parcela(s) remanescente(s)'}],obligationTotal=sum169(obligations.map(x=>x.total));
      const kpis=root.querySelector('.v168-kpis');if(kpis){const debt=findKpi(kpis,'Dívidas atuais');if(debt){debt.querySelector('span').textContent='Dívidas com saldo atual';debt.querySelector('small').textContent='quitação documental · CIPÓ + Volvo'}debt?.insertAdjacentHTML('afterend','<article class="v168-kpi"><span>Obrigações remanescentes</span><strong>'+brl169(obligationTotal)+'</strong><small>Coopharma + Pai e Mãe · cronogramas, não saldo de quitação</small></article>')}
      const card=[...root.querySelectorAll('.v168-card')].find(x=>/^passivos$/i.test(x.querySelector('.v168-cardhead span')?.textContent||''));if(card){const head=card.querySelector('.v168-cardhead');head.querySelector('h2').textContent='Dívidas e obrigações remanescentes';const strong=head.querySelector('strong');if(strong)strong.textContent=brl169(summary.known_debt_total);[...card.children].filter(x=>x!==head).forEach(x=>x.remove());card.insertAdjacentHTML('beforeend','<div class="v169-passives"><section><div class="v169-passive-title"><b>Saldo de quitação documentado</b><strong>'+brl169(summary.known_debt_total)+'</strong></div>'+rank169([{name:'Financiamento imobiliário · CIPÓ 396',total:c.documentary_debt},{name:'Financiamento do Volvo XC40',total:v.documented_financed_balance}].filter(x=>(finite(x.total)||0)>0))+'</section><section><div class="v169-passive-title"><b>Obrigações sem saldo de quitação informado</b><strong>'+brl169(obligationTotal)+'</strong></div><div class="v168-statlist">'+obligations.map(x=>'<div class="v168-stat"><span><b>'+esc169(x.name)+'</b><small>'+esc169(x.note)+'</small></span><b>'+brl169(x.total)+'</b></div>').join('')+'</div></section><div class="v169-coverage"><b>Critério financeiro</b><span>Coopharma e Pai e Mãe agora aparecem nos passivos. Como só há cronogramas remanescentes — e não saldos atuais de quitação — esses totais não são somados ao patrimônio líquido central para evitar tratar juros futuros como principal atual.</span></div></div>')}
      return t.innerHTML;
    }

    const isTransfer=e=>e?.source==='internal_transfer'&&e?.confidence==='user_flow_editable'&&String(e?.source_ref||'').startsWith('financial_events:');
    openFlowEditor=async function(e,mode='edit'){
      if(!isTransfer(e))return baseOpenFlowEditor(e,mode);
      const anchor=e.event_date;EXP.add(anchor);FLOWEDIT={event:e,anchor_date:anchor,mode:'edit',loading:true,error:null,data:{kind:'internal_transfer_pair'},parts:[]};render();
      const {data,error}=await S.rpc('lts_browser_internal_transfer_editor_v1',{p_source_ref:e.source_ref});
      if(error||!data?.editable){FLOWEDIT={...FLOWEDIT,loading:false,error:error?.message||data?.reason||'Esta transferência não pode ser editada.'};render();return}
      FLOWEDIT={event:e,anchor_date:anchor,mode:'edit',loading:false,error:null,data,parts:[]};render();
    };
    flowEditorInline=function(day){
      if(FLOWEDIT?.data?.kind!=='internal_transfer_pair')return baseFlowEditorInline(day);
      if(FLOWEDIT.anchor_date!==day)return'';if(FLOWEDIT.loading)return'<div class="flowedit-panel"><div class="mut">Carregando a transferência completa…</div></div>';if(FLOWEDIT.error)return'<div class="flowedit-panel"><div class="notice">'+esc169(FLOWEDIT.error)+'</div><button id="flowEditClose" class="btn ghost" style="margin-top:8px">Fechar</button></div>';
      const d=FLOWEDIT.data||{},accounts=['Itaú','Bradesco','C6'];return '<div class="flowedit-panel v169-transfer-editor"><div class="flowedit-head"><div><div class="title">Editar transferência entre contas</div><div class="mut">'+date169(d.event_date)+' · duas pernas vinculadas · efeito consolidado R$ 0,00</div></div><button id="flowEditClose" class="btn ghost">Fechar</button></div><div class="flowedit-grid"><label>Data<input id="flowEditDate" type="date" value="'+esc169(d.event_date)+'"></label><label>Valor<input id="flowEditAmount" type="number" min="0.01" step="0.01" value="'+esc169(d.amount)+'"></label><label>Conta de origem<select id="v169TransferFrom">'+accounts.map(a=>'<option '+(a===d.from_account?'selected':'')+'>'+a+'</option>').join('')+'</select></label><label>Conta de destino<select id="v169TransferTo">'+accounts.map(a=>'<option '+(a===d.to_account?'selected':'')+'>'+a+'</option>').join('')+'</select></label><label class="wide">Descrição<input id="flowEditDesc" value="'+esc169(d.description||'')+'"></label></div><div class="flowedit-hint"><b>Operação atômica:</b> salvar atualiza simultaneamente a saída e a entrada. Excluir cancela as duas pernas. O histórico original permanece na auditoria.</div><div class="flowedit-actions"><button id="flowEditSave" class="btn">Salvar transferência</button><button id="flowEditCancelProjection" class="btn ghost danger-text">Excluir transferência</button></div></div>';
    };
    saveFlowEdit=async function(cancelOnly=false){
      if(FLOWEDIT?.data?.kind!=='internal_transfer_pair')return baseSaveFlowEdit(cancelOnly);if(FLOWEDITSAVING)return;const d=FLOWEDIT.data,action=cancelOnly?'cancel':'edit';let payload={};
      if(action==='edit'){payload={event_date:document.getElementById('flowEditDate')?.value,amount:Number(document.getElementById('flowEditAmount')?.value),from_account:document.getElementById('v169TransferFrom')?.value,to_account:document.getElementById('v169TransferTo')?.value,description:document.getElementById('flowEditDesc')?.value.trim()};if(!payload.event_date||!Number.isFinite(payload.amount)||payload.amount<=0||!payload.description||payload.from_account===payload.to_account){alert('Revise data, valor, descrição e use contas de origem e destino diferentes.');return}}
      if(action==='cancel'&&!confirm('Excluir esta transferência do Fluxo? A saída e a entrada serão canceladas juntas e o registro original ficará preservado para auditoria.'))return;
      FLOWEDITSAVING=true;const b=document.getElementById('flowEditSave');if(b){b.disabled=true;b.textContent='Salvando…'}try{const key='transfer-'+action+'-'+(crypto.randomUUID?crypto.randomUUID():Date.now()+'-'+Math.random().toString(36).slice(2)),{data,error}=await S.rpc('lts_browser_internal_transfer_mutate_v1',{p_action:action,p_source_ref:d.source_ref,p_payload:payload,p_idempotency_key:key});if(error||!data?.ok)throw Error(error?.message||'Não foi possível salvar a transferência.');FLOWEDIT=null;await loadFlowRange(FLOWFROM||today169(),FLOWTO||today169())}catch(e){alert('Falha ao ajustar transferência: '+String(e?.message||e))}finally{FLOWEDITSAVING=false;if(V==='Fluxo Diário')render()}
    };
    deleteFlowEvent=async function(e,b){
      if(!isTransfer(e))return baseDeleteFlowEvent(e,b);if(!confirm('Excluir esta transferência do Fluxo? A saída e a entrada serão canceladas juntas e o registro original ficará preservado para auditoria.'))return;const old=b?.textContent||'Excluir';if(b){b.disabled=true;b.textContent='Excluindo…'}try{const key='transfer-cancel-'+(crypto.randomUUID?crypto.randomUUID():Date.now()+'-'+Math.random().toString(36).slice(2)),{data,error}=await S.rpc('lts_browser_internal_transfer_mutate_v1',{p_action:'cancel',p_source_ref:e.source_ref,p_payload:{},p_idempotency_key:key});if(error||!data?.ok)throw Error(error?.message||'Não foi possível excluir.');FLOWEDIT=null;await loadFlowRange(FLOWFROM||today169(),FLOWTO||today169())}catch(err){alert('Falha ao excluir transferência: '+String(err?.message||err));if(b){b.disabled=false;b.textContent=old}}
    };
    function decorateTransferActions(){if(V!=='Fluxo Diário'||typeof mergedFlowEvents!=='function')return;const events=mergedFlowEvents();document.querySelectorAll('.floweditbtn[data-mode="duplicate"]').forEach(b=>{const e=events.find(x=>flowEventKey(x)===b.dataset.ekey);if(isTransfer(e))b.remove()});document.querySelectorAll('.floweditbtn[data-mode="edit"]').forEach(b=>{const e=events.find(x=>flowEventKey(x)===b.dataset.ekey);if(isTransfer(e))b.textContent='Editar transferência'});document.querySelectorAll('.flowdeletebtn').forEach(b=>{const e=events.find(x=>flowEventKey(x)===b.dataset.ekey);if(isTransfer(e))b.textContent='Excluir transferência'})}

    function bind169(){
      document.querySelectorAll('[data-v169-card-bank]').forEach(b=>b.onclick=()=>{state.cardBank=b.dataset.v169CardBank;render()});
      document.querySelector('[data-v169-month-retry]')?.addEventListener('click',()=>ensureMonthly(true));
      document.querySelectorAll('[data-v168-exp-range]').forEach(b=>{const old=b.onclick;b.onclick=e=>{state.monthly.data=null;state.monthly.key='';state.monthly.error=null;return old?.call(b,e)}});
      const apply=document.getElementById('v168ExpenseApply');if(apply){const old=apply.onclick;apply.onclick=e=>{state.monthly.data=null;state.monthly.key='';state.monthly.error=null;return old?.call(apply,e)}}
      decorateTransferActions();
    }
    function stamp(){document.querySelectorAll('.brand small').forEach(n=>{if(n.textContent.trim()!=='V169 · Homologação')n.innerHTML='<b>V169</b> · Homologação'});document.querySelectorAll('.v168-release').forEach(n=>{if(n.textContent.trim()!=='V169 · Homologação')n.textContent='V169 · Homologação'});const badge=window.parent.document.getElementById('scope'),label='V169 · '+(V==='Fluxo Diário'?'Fluxo de caixa':V)+' · Homologação';if(badge&&badge.textContent!==label)badge.textContent=label}
    function after(){stamp();bind169()}
    dashboard=dashboardV169;despesas=expensesV169;patrimonio=wealthV169;
    render=function(){const out=baseRender();after();return out};
    renderNav=function(){const out=baseNav();stamp();return out};
    const versionObserver=new MutationObserver(stamp);versionObserver.observe(document.body,{childList:true,subtree:true,characterData:true});
    if(D&&!N.classList.contains('hidden'))render();
  }

  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return null;return{w,d}}catch{return null}}
  function install(){const f=frame();if(!f)return false;if(!f.w.__LTS_V168_COMPLETE_REVIEW?.installed)return false;f.d.querySelectorAll('.brand small').forEach(n=>n.innerHTML='<b>V169</b> · Homologação');f.d.querySelectorAll('.v168-release').forEach(n=>n.textContent='V169 · Homologação');if(!f.d.getElementById('lts-v169-style')){const l=f.d.createElement('link');l.id='lts-v169-style';l.rel='stylesheet';l.href='lts-v169-v168-feedback-closure.css?v=20260916-v169a';f.d.head.appendChild(l)}if(!f.w.__LTS_V169_V168_FEEDBACK?.installed&&!f.d.getElementById('lts-v169-runtime')){const s=f.d.createElement('script');s.id='lts-v169-runtime';s.textContent='('+runtime.toString()+')();';f.d.head.appendChild(s)}const ready=f.w.__LTS_V169_V168_FEEDBACK?.installed===true;if(ready&&gate)gate.hidden=true;if(ready&&scope)scope.textContent='V169 · Homologação';return ready}
  function burst(){const current=++generation;let n=0;function step(){if(current!==generation)return;const ok=install();n++;if(!ok&&n<320)setTimeout(step,100)}step();[400,900,1800,3600,7000,12000,20000,30000].forEach(ms=>setTimeout(()=>{if(current===generation)install()},ms))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();window.__LTS_TOP_CANDIDATE_VERSION='v169-v168-feedback-closure';
})();

;
;
/* LTS V384: lts-v170-v169-review.js */
(function(){
  'use strict';
  const outer=document.getElementById('shell'),gate=document.getElementById('gate'),scope=document.getElementById('scope');
  let generation=0;

  function runtime(){
    'use strict';
    if(window.__LTS_V170_V169_REVIEW?.installed||!window.__LTS_V169_V168_FEEDBACK?.installed)return;
    const baseRender=render,baseNav=renderNav,baseDashboard=dashboard,baseExpenses=despesas,baseWealth=patrimonio,baseLoadFlowRange=loadFlowRange,baseFlowVals=flowVals,baseFlowSemanticMeta=flowSemanticMeta;
    const v168=window.__LTS_V168_STATE;
    const state=window.__LTS_V170_STATE||(window.__LTS_V170_STATE={globalAward:{saving:false,message:'',error:''},lastRoute:V,defaultOpening:false});
    const priorRpc=S.rpc.bind(S),rpcCalls=[];
    S.rpc=async function(name,args){
      const requested=String(name||''),mapped=requested==='lts_browser_flow_v3'||requested==='lts_browser_flow_v4'||requested==='lts_browser_flow_v241'?'lts_browser_flow_v241':requested==='lts_browser_wealth_detail_v3'?'lts_browser_wealth_detail_v4':requested==='lts_browser_expense_executive_v4'?'lts_browser_expense_executive_v5':requested;
      rpcCalls.push({requested,mapped,at:new Date().toISOString()});if(rpcCalls.length>50)rpcCalls.shift();
      return priorRpc(mapped,args);
    };
    window.__LTS_V170_V169_REVIEW={
      installed:true,version:'v170',base_version:'v169',public_index_changed:false,
      data_rpcs:{flow:'lts_browser_flow_v241',wealth:'lts_browser_wealth_detail_v4',expense:'lts_browser_expense_executive_v5'},
      default_flow_range:'previous-5-through-next-year-end',historical_balance_basis:'relative_movement_ledger',
      morgan_statement_reconciled:true,global_award_assumption:true,management_groups:true,rpcCalls
    };

    const arr=v=>Array.isArray(v)?v:[],finite=v=>v===null||v===undefined||v===''?null:(Number.isFinite(Number(v))?Number(v):null);
    const esc=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
    const norm=s=>String(s??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
    const money=v=>finite(v)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(v));
    const number=v=>finite(v)==null?'—':new Intl.NumberFormat('pt-BR',{maximumFractionDigits:3}).format(Number(v));
    const usd=v=>finite(v)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'USD',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(v));
    const fx=v=>finite(v)==null?'—':new Intl.NumberFormat('pt-BR',{minimumFractionDigits:4,maximumFractionDigits:6}).format(Number(v));
    const date=v=>{const p=String(v||'').slice(0,10).split('-');return p.length===3?p.reverse().join('/'):'—'};
    const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
    const shift=(iso,n)=>{const d=new Date(iso+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10)};
    const template=html=>{const t=document.createElement('template');t.innerHTML=html;return t};
    const total=xs=>arr(xs).reduce((a,x)=>a+(finite(x)||0),0);

    function managementGroups(source){return arr(source?.management_groups).filter(x=>finite(x.total)!=null)}
    function managementRows(source,limit=15){
      const rows=[];
      for(const group of managementGroups(source)){
        const children=arr(group.subgroups).filter(x=>finite(x.total)!=null);
        if(norm(group.name)==='educacao'&&children.length){rows.push({name:'Educação',total:group.total,detail:'por pessoa',children,source_categories:group.source_categories,forceChildren:true});continue}
        rows.push({name:group.name,total:group.total,detail:children.slice(0,4).map(x=>x.name.replace(/^Educação · /i,'')).join(' · '),children,source_categories:group.source_categories});
      }
      return rows.sort((a,b)=>(finite(b.total)||0)-(finite(a.total)||0)).slice(0,limit);
    }
    function managementRank(rows,expanded){
      const xs=arr(rows),top=Math.max(1,...xs.map(x=>Math.abs(finite(x.total)||0)));
      return '<div class="v170-rank">'+(xs.map((x,i)=>'<div class="v170-rankrow"><span class="v170-rankn">'+(i+1)+'</span><div><b>'+esc(x.name||'Outros')+'</b>'+(x.detail?'<small>'+esc(x.detail)+'</small>':'')+'<i><u style="width:'+Math.max(2,Math.abs(finite(x.total)||0)/top*100)+'%"></u></i>'+((expanded||x.forceChildren)&&arr(x.children).length?'<div class="v170-subgroups">'+x.children.map(y=>'<span><em>'+esc(y.name)+'</em><strong>'+money(y.total)+'</strong></span>').join('')+'</div>':'')+(expanded&&arr(x.source_categories).length?'<details><summary>Ver categorias de origem</summary>'+x.source_categories.map(y=>'<span><em>'+esc(y.name)+'</em><strong>'+money(y.total)+'</strong></span>').join('')+'</details>':'')+'</div><strong>'+money(x.total)+'</strong></div>').join('')||'<div class="v168-empty">Sem grupos gerenciais neste período.</div>')+'</div>';
    }
    function coverage(source){const c=source?.coverage_disclosure||{};return finite(c.total)>0?'<div class="v169-coverage"><b>'+esc(c.label||'Faturas históricas sem compras individualizadas')+' · '+money(c.total)+'</b><span>'+esc(c.guardrail||'O total foi preservado, sem inventar estabelecimentos ou categorias.')+'</span></div>':''}
    function auditNote(source){const a=source?.management_group_audit||{};return '<div class="v170-audit"><div><span>Financiamentos auditados</span><b>'+money(a.financing_brl)+'</b><small>'+esc(a.financing_definition||'Parcelas imobiliárias e de veículo.')+'</small></div><div><span>Empréstimos</span><b>'+money(a.loans_brl)+'</b><small>Itaú e consignado Coopharma separados em subgrupos.</small></div><div><span>Obra e reforma · O Parque / CIPÓ 396</span><b>'+money(a.works_brl)+'</b><small>'+esc(a.works_definition||'O Parque / CIPÓ 396, sem financiamento.')+'</small></div></div>'}

    function dashboardV170(){
      const t=template(baseDashboard()),root=t.content.querySelector('.v168-dashboard');if(!root)return t.innerHTML;
      const sections=[...root.querySelectorAll('.v168-kpi-section')],restricted=sections[2]?.querySelector('.v168-kpis');
      if(restricted){const pension=[...restricted.querySelectorAll('.v168-kpi')].find(x=>norm(x.querySelector('span')?.textContent).includes('total em previdencias'));const expense=[...restricted.querySelectorAll('.v168-kpi')].find(x=>norm(x.querySelector('span')?.textContent).includes('total de despesas'));if(pension&&expense)restricted.insertBefore(pension,expense)}
      const data=v168.dashboard.data?.expense||{},card=[...root.querySelectorAll('.v168-card')].find(x=>/principais grupos/i.test(x.querySelector('h2')?.textContent||''));
      if(card&&managementGroups(data).length){card.querySelector('.v168-rank,.v169-coverage,.v170-rank')?.remove();const cardHead=card.querySelector('.v168-cardhead'),head=cardHead?.querySelector('small');if(head)head.textContent='Top 15 · grupos gerenciais';else cardHead?.insertAdjacentHTML('beforeend','<small>Top 15 · grupos gerenciais</small>');card.insertAdjacentHTML('beforeend',managementRank(managementRows(data,15),false)+coverage(data))}
      return t.innerHTML;
    }

    function expensesV170(){
      const t=template(baseExpenses()),root=t.content.querySelector('.v168-expenses'),data=v168.expense.data||{},groups=managementGroups(data);if(!root||!groups.length)return t.innerHTML;
      if(v168.expense.tab==='overview'){
        const card=[...root.querySelectorAll('.v168-card')].find(x=>/maiores grupos/i.test(x.querySelector('h2')?.textContent||''));
        if(card){card.querySelector('.v168-rank,.v170-rank')?.remove();const h=card.querySelector('h2');if(h)h.textContent='Maiores grupos gerenciais';card.insertAdjacentHTML('beforeend',managementRank(managementRows(data,15),true)+auditNote(data)+coverage(data))}
      }
      if(v168.expense.tab==='categories'){
        const tabs=root.querySelector('.v168-tabs');tabs?.insertAdjacentHTML('afterend','<article class="v168-card v170-management-card"><div class="v168-cardhead"><div><span>Composição consolidada e rastreável</span><h2>Grupos gerenciais com subgrupos</h2></div><small>categorias originais preservadas abaixo</small></div>'+managementRank(managementRows(data,99),true)+auditNote(data)+coverage(data)+'</article>');
      }
      return t.innerHTML;
    }

    function awardType(x){return /cash/i.test(String(x.asset_type||''))?'Cash RSU':'RSU'}
    function rsuPanel(j){
      const r=j.rsu_summary||{},m=j.morgan_statement||{},available=m.available_components||{},future=m.future_components||{},q=m.quantities||{},recon=m.planning_schedule_reconciliation||{},rows=arr(j.rsu?.future_schedule),ret=j.employment_awards?.retention||{},first=rows[0]||{},currentPairs=[...new Set(rows.map(x=>String(x.unit_price_usd)+'|'+String(x.fx_rate)))],mixed=currentPairs.length>1;
      const gross=m.gross_total_brl??((finite(r.available_total_brl)||0)+(finite(r.future_regular_brl)||0)+(finite(r.future_cash_net_brl)||0)),considered=m.considered_total_after_reserve_brl??((finite(r.available_total_brl)||0)+(finite(r.future_considered_total_brl)||0));
      return '<div class="v170-morgan-summary"><div class="v168-kpis"><article class="v168-kpi primary"><span>Total bruto do extrato</span><strong>'+money(gross)+'</strong><small>disponível + indisponível · '+date(m.as_of||r.as_of)+'</small></article><article class="v168-kpi"><span>Total considerado após reserva</span><strong>'+money(considered)+'</strong><small>cenário de planejamento; não é outro saldo do banco</small></article><article class="v168-kpi"><span>Disponível agora</span><strong>'+money(m.available_total_brl??r.available_total_brl)+'</strong><small>ações vested + saldo em corretora</small></article><article class="v168-kpi"><span>Indisponível bruto</span><strong>'+money(m.unavailable_gross_brl)+'</strong><small>RSU + Cash RSU futuros</small></article><article class="v168-kpi"><span>Reserva fiscal projetada</span><strong>'+money(future.cash_rsu_reserve_brl)+'</strong><small>30% somente sobre Cash RSU</small></article></div><div class="v170-morgan-components"><article><span>Disponível</span><h3>'+money(m.available_total_brl??r.available_total_brl)+'</h3><dl><dt>Ações vested</dt><dd>'+money(available.vested_shares_brl??r.vested_shares_brl)+'</dd><dt>Saldo em corretora</dt><dd>'+money(available.brokerage_cash_brl??r.brokerage_cash_brl)+'</dd></dl></article><article><span>RSUs futuras · bruto</span><h3>'+money(future.regular_rsu_gross_brl)+'</h3><small>'+number(q.future_regular_rsu)+' unidades</small></article><article><span>Cash RSUs futuras · bruto</span><h3>'+money(future.cash_rsu_gross_brl)+'</h3><dl><dt>Após reserva</dt><dd>'+money(future.cash_rsu_after_reserve_brl)+'</dd><dt>Quantidade</dt><dd>'+number(q.future_cash_rsu)+'</dd></dl></article></div><div class="v168-note"><b>Leitura correta:</b> o total bruto confere com a tela da Morgan Stanley. O total considerado aplica uma reserva de 30% às Cash RSUs para planejamento; não presume imposto definitivo.</div></div>'+
      '<article class="v168-card v170-global-award"><div class="v168-cardhead"><div><span>Premissa única</span><h2>Atualizar a cotação de todos os vestings</h2></div><small>'+rows.length+' vesting(s) ativo(s)</small></div><div class="v170-global-form"><label>Preço da ação (USD)<input id="v170AllAwardPrice" type="number" min="0.01" max="10000" step="0.01" value="'+esc(first.unit_price_usd??'')+'"></label><label>Câmbio USD/BRL<input id="v170AllAwardFx" type="number" min="0.0001" max="100" step="0.000001" value="'+esc(first.fx_rate??'')+'"></label><button class="v168-btn primary" id="v170AllAwardApply" '+(state.globalAward.saving?'disabled':'')+'>'+(state.globalAward.saving?'Atualizando todos…':'Aplicar a todos os vestings')+'</button></div><div class="v170-global-help">'+(mixed?'As premissas atuais variam entre vestings. Os campos acima usam a primeira linha; ao aplicar, todos receberão exatamente os mesmos valores.':'A mesma ação e o mesmo câmbio serão aplicados a RSUs e Cash RSUs. A reserva de 30% continua somente nas Cash RSUs.')+'</div>'+(state.globalAward.message?'<div class="v168-note good">'+esc(state.globalAward.message)+'</div>':'')+(state.globalAward.error?'<div class="v168-note warn">'+esc(state.globalAward.error)+'</div>':'')+'</article>'+
      '<article class="v168-card"><div class="v168-cardhead"><div><span>Agenda calculada</span><h2>Vestings e disponibilidade</h2></div><strong>'+money(r.future_considered_total_brl)+'</strong></div><div class="v170-reconciliation"><span>Extrato e agenda permanecem separados para conferência.</span><small>RSU: diferença '+money(recon.regular_delta_brl)+' · Cash RSU bruto: diferença '+money(recon.cash_delta_brl)+'. Atualizar a cotação recalcula a agenda; não reescreve o extrato de '+date(m.as_of)+'.</small></div><div class="v168-awards">'+rows.map((x,i)=>{const type=awardType(x),value=type==='Cash RSU'?x.net_value_brl:x.gross_value_brl;return '<div class="v168-award"><div><span>Vesting</span><b>'+date(x.eligibility_date)+'</b><small>'+esc(type)+'</small></div><div><span>Quantidade</span><b>'+number(x.quantity)+'</b></div><div><span>Cotação usada</span><b>'+usd(x.unit_price_usd)+'</b><small>câmbio '+fx(x.fx_rate)+'</small></div><div><span>Valor considerado</span><b>'+money(value)+'</b><small>'+date(x.available_date)+' disponível</small></div><label><span>Antecipação opcional</span><input type="date" data-v168-award-date="'+i+'" max="'+esc(x.eligibility_date)+'" value="'+esc(x.anticipated_date||'')+'"></label><div><button class="v168-btn" data-v168-award-edit="'+i+'">Cotação individual</button> <button class="v168-btn blue" data-v168-award-save="'+i+'">Salvar data</button></div></div>'}).join('')+'</div></article><article class="v168-card"><div class="v168-cardhead"><div><span>Retention Award</span><h2>Acordo separado de RSU</h2></div><strong>'+money(ret.gross_total_brl)+'</strong></div><div class="v168-note">Permanece fora dos totais Morgan Stanley e da agenda de RSU/Cash RSU.</div></article>';
    }
    function wealthV170(){
      const t=template(baseWealth()),root=t.content.querySelector('.v168-wealth'),j=v168.wealth.data||{};if(!root)return t.innerHTML;
      const tabs=root.querySelector('.v168-tabs');
      if(v168.wealth.tab==='rsu'&&tabs&&v168.wealth.data){let n=tabs.nextSibling;while(n){const next=n.nextSibling;n.remove();n=next}tabs.insertAdjacentHTML('afterend',rsuPanel(j))}
      if(v168.wealth.tab==='overview'&&tabs){tabs.insertAdjacentHTML('afterend','<div class="v170-wealth-guide"><span><b>Hoje</b> ativos já adquiridos</span><span><b>Futuro</b> vestings ainda condicionais</span><span><b>Restrito</b> previdências fora do caixa</span><span><b>Passivos</b> saldo atual separado de parcelas futuras</span></div>');const cards=[...root.querySelectorAll('.v168-card')],passive=cards.find(x=>/dívidas e obrigações/i.test(x.querySelector('h2')?.textContent||''));passive?.classList.add('v170-passive-card');const net=[...root.querySelectorAll('.v168-kpi')].find(x=>norm(x.querySelector('span')?.textContent).includes('patrimonio liquido'));if(net){net.querySelector('span').textContent='Patrimônio líquido · saldos atuais';net.querySelector('small').textContent='obrigações sem saldo de quitação ficam visíveis, sem dupla contagem'}}
      return t.innerHTML;
    }

    async function applyAllAwards(){
      if(state.globalAward.saving)return;const price=Number(document.getElementById('v170AllAwardPrice')?.value),fxRate=Number(document.getElementById('v170AllAwardFx')?.value),count=arr(v168.wealth.data?.rsu?.future_schedule).length;
      if(!Number.isFinite(price)||price<=0||!Number.isFinite(fxRate)||fxRate<=0){state.globalAward.error='Informe preço e câmbio válidos.';state.globalAward.message='';render();return}
      if(!confirm('Aplicar US$ '+price.toLocaleString('pt-BR')+' e câmbio '+fxRate.toLocaleString('pt-BR')+' a todos os '+count+' vestings ativos?'))return;
      state.globalAward={saving:true,message:'',error:''};render();
      try{const {data,error}=await S.rpc('lts_browser_save_all_award_assumptions_v1',{p_unit_price_usd:price,p_fx_rate:fxRate});if(error||!data?.ok)throw Error(error?.message||'Não foi possível atualizar as premissas.');state.globalAward={saving:false,message:data.award_count+' vesting(s) recalculado(s) com a mesma cotação e câmbio.',error:''};v168.wealth.data=null;v168.dashboard.data=null;render()}
      catch(e){state.globalAward={saving:false,message:'',error:'Falha ao atualizar todos: '+String(e?.message||e)};render()}
    }

    function defaultRange(){const t=today();return{from:shift(t,-5),to:String(Number(t.slice(0,4))+4)+'-12-31'}}
    function oldDefaultRange(){const t=today();return{from:shift(t,-5),to:shift(t,30)}}
    function isOldDefault(from,to){const r=oldDefaultRange();return from===r.from&&to===r.to}
    loadFlowRange=async function(from,to){if(isOldDefault(from,to)){const r=defaultRange();from=r.from;to=r.to}const s=window.__LTS_V162_FLOW_RECOVERY_STATUS;if(s){s.default_range_applied=true;s.default_range_contract='previous-5-through-next-year-end-v170';s.default_range=defaultRange()}return baseLoadFlowRange(from,to)};
    function trackedBankEvent(e){return ['itau','bradesco','c6'].includes(norm(e?.account))&&String(e?.source||'')!=='economic_withholding'}
    function historicalCashParts(day){
      const record=mergedFlowDays().find(x=>x.date===day),proof=record?.v170_cash_arithmetic;if(proof?.version==='tracked-bank-cash-arithmetic-v1')return{rows:dayEvents(day).filter(trackedBankEvent),internalNet:finite(proof.internal_transfer_net_brl)||0,entries:(finite(proof.operating_entries_brl)||0)+Math.max(finite(proof.internal_transfer_net_brl)||0,0),exits:(finite(proof.operating_exits_brl)||0)+Math.max(-(finite(proof.internal_transfer_net_brl)||0),0),proof};
      const rows=dayEvents(day).filter(trackedBankEvent),operating=rows.filter(e=>!e.internal_transfer),internalNet=total(rows.filter(e=>e.internal_transfer).map(e=>e.signed_amount));
      return{rows,internalNet,entries:total(operating.filter(e=>(finite(e.signed_amount)||0)>0).map(e=>e.signed_amount))+Math.max(internalNet,0),exits:Math.abs(total(operating.filter(e=>(finite(e.signed_amount)||0)<0).map(e=>e.signed_amount)))+Math.max(-internalNet,0)};
    }
    function flowValsV170(x,prev){
      if(!x?.historical||ACC!=='Consolidado')return baseFlowVals(x,prev);
      const cash=historicalCashParts(x.date),z=x.Consolidado||{},c=x.fix86_columns||{},fin=c.saldo_final_operacional??z.bank_balance;
      if(fin==null)return{prev:null,en:cash.entries,ex:cash.exits,fin:null,basis:'movement_only',internalNet:cash.internalNet};
      const pc=prev?.fix86_columns||{},opening=pc.saldo_final_operacional??(prev?.historical?prev?.Consolidado?.bank_balance:null)??c.saldo_anterior_operacional??c.saldo_anterior??(Number(fin)-cash.entries+cash.exits);
      return{prev:opening,en:cash.entries,ex:cash.exits,fin,basis:'tracked_bank_cash',internalNet:cash.internalNet};
    }
    flowVals=flowValsV170;
    flowSemanticMeta=function(e){return baseFlowSemanticMeta(e)};
    function openDefault(){const r=defaultRange();FLOWPRESET='5 anteriores + fim do próximo ano';SHOWZERO=false;FLOWFORCEZERO=false;return loadFlowRange(r.from,r.to)}
    function bindFlowDefault(){
      const nav=document.querySelector('.nav [data-v="Fluxo Diário"]');if(nav)nav.onclick=()=>{V='Fluxo Diário';state.lastRoute=V;renderNav();render();openDefault()};
      if(V!=='Fluxo Diário')return;const b=document.getElementById('flowDefaultRange');if(b){const r=defaultRange();b.textContent='5 anteriores + fim de '+r.to.slice(0,4);b.title='Cinco dias anteriores até o fim do quinto ano do horizonte';b.classList.toggle('active',FLOWFROM===r.from&&FLOWTO===r.to);b.onclick=openDefault}const go=document.getElementById('goToday');if(go)go.onclick=openDefault;
    }
    function decorateFlow(){
      if(V!=='Fluxo Diário')return;document.querySelectorAll('.fx87-cons.fx87-head').forEach(h=>{const cells=h.children;if(cells[7]&&cells[7].textContent!=='Morgan disponível')cells[7].textContent='Morgan disponível';if(cells[8]&&cells[8].textContent!=='Saldo c/ Morgan')cells[8].textContent='Saldo c/ Morgan'});let note=document.querySelector('.v168-history-note');if(!note){const controls=document.querySelector('.flow-sticky-controls');controls?.insertAdjacentHTML('beforeend','<div class="v168-history-note"></div>');note=document.querySelector('.v168-history-note')}const historyHtml='<b>Histórico auditável:</b> antes da primeira abertura documental completa, “saldo anterior” e “saldo final” usam o acumulado dos movimentos recuperados, com base zero em 09/10/2013. O consolidado considera somente Itaú, Bradesco e C6; transferências pareadas se anulam e uma movimentação interna líquida só aparece quando altera o caixa acompanhado.';if(note&&note.innerHTML!==historyHtml)note.innerHTML=historyHtml;
    }
    function bind(){document.getElementById('v170AllAwardApply')?.addEventListener('click',applyAllAwards);bindFlowDefault();decorateFlow()}
    function stamp(){const badge=window.parent.document.getElementById('scope');if(badge)badge.dataset.v170Route=V==='Fluxo Diário'?'Fluxo de caixa':V}
    function after(){stamp();bind()}

    dashboard=dashboardV170;despesas=expensesV170;patrimonio=wealthV170;
    render=function(){const entered=V==='Fluxo Diário'&&state.lastRoute!=='Fluxo Diário';state.lastRoute=V;const out=baseRender();after();if(entered)queueMicrotask(()=>{if(V==='Fluxo Diário')openDefault()});return out};
    renderNav=function(){const out=baseNav();stamp();bindFlowDefault();return out};
    let decorationPending=false;const observer=new MutationObserver(()=>{if(decorationPending)return;decorationPending=true;requestAnimationFrame(()=>{decorationPending=false;stamp();decorateFlow()})});observer.observe(document.body,{childList:true,subtree:true});

    if(v168.dashboard.data&&!v168.dashboard.data.expense?.management_groups){v168.dashboard.token=(v168.dashboard.token||0)+1;v168.dashboard.data=null;v168.dashboard.started=false;v168.dashboard.loading=false;v168.dashboard.pending=0}
    if(v168.expense.data&&!v168.expense.data.management_groups){v168.expense.token=(v168.expense.token||0)+1;v168.expense.data=null;v168.expense.loading=false}
    if(v168.wealth.data&&!v168.wealth.data.morgan_statement){v168.wealth.data=null;v168.wealth.loading=false}
    if(D&&!N.classList.contains('hidden'))render();
  }

  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return null;return{w,d}}catch{return null}}
  function install(){const f=frame();if(!f)return false;if(!f.w.__LTS_V169_V168_FEEDBACK?.installed)return false;if(!f.d.getElementById('lts-v170-style')){const l=f.d.createElement('link');l.id='lts-v170-style';l.rel='stylesheet';l.href='lts-v170-v169-review.css?v=20260917-v170a';f.d.head.appendChild(l)}if(!f.w.__LTS_V170_V169_REVIEW?.installed&&!f.d.getElementById('lts-v170-runtime')){const s=f.d.createElement('script');s.id='lts-v170-runtime';s.textContent='('+runtime.toString()+')();';f.d.head.appendChild(s)}const ready=f.w.__LTS_V170_V169_REVIEW?.installed===true;if(ready&&gate)gate.hidden=true;return ready}
  function burst(){const current=++generation;let n=0;function step(){if(current!==generation)return;const ok=install();n++;if(!ok&&n<320)setTimeout(step,100)}step();[400,900,1800,3600,7000,12000,20000,30000].forEach(ms=>setTimeout(()=>{if(current===generation)install()},ms))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();window.__LTS_TOP_CANDIDATE_VERSION='v170-v169-review';
})();

;
;
/* LTS V384: lts-v171-v170-review.js */
(function(){
  'use strict';
  const outer=document.getElementById('shell'),gate=document.getElementById('gate'),scope=document.getElementById('scope');
  let generation=0;

  function runtime(){
    'use strict';
    if(window.__LTS_V171_V170_REVIEW?.installed||!window.__LTS_V170_V169_REVIEW?.installed)return;
    const baseRender=render,baseNav=renderNav,baseDashboard=dashboard,baseExpenses=despesas;
    const v168=window.__LTS_V168_STATE,v169=window.__LTS_V169_STATE;
    const topScope=window.parent?.document?.getElementById('scope');
    const legacyFlow=window.__LTS_V162_FLOW_RECOVERY_STATUS;if(legacyFlow){legacyFlow.refresh_requested=true;legacyFlow.last_flow_done=true;legacyFlow.last_flow_ok=true}window.__LTS_V162_ROUTE_FLOW=()=>({state:'flow',done:true,ok:true});
    const state=window.__LTS_V171_STATE||(window.__LTS_V171_STATE={cardBank:'Todos',flowSequence:0,expenseLoadScheduled:false,wealthLoadScheduled:false});
    const previousRpc=S.rpc.bind(S);
    S.rpc=async function(name,args){
      const requested=String(name||'');let mapped=requested,next={...(args||{})};
      if(['lts_browser_expense_executive_v4','lts_browser_expense_executive_v5'].includes(requested))mapped='lts_browser_expense_executive_v6';
      if(requested==='lts_browser_monthly_balance_v1')mapped='lts_browser_monthly_balance_v2';
      if(requested==='lts_browser_transactions_v2'&&next.p_direction==='expense')next.p_direction='saida';
      return previousRpc(mapped,next);
    };
    window.__LTS_V171_V170_REVIEW={installed:true,version:'v171',base_version:'v170',public_index_changed:false,professional_expense_taxonomy:true,monthly_period_complete:true,ledger_direction_fixed:true,flow_progressive_load:true,validated_flow_columns_restored:true};

    const arr=v=>Array.isArray(v)?v:[],n=v=>v===null||v===undefined||v===''?null:(Number.isFinite(Number(v))?Number(v):null);
    const esc=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
    const norm=s=>String(s??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
    const brl=v=>n(v)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(v));
    const date=v=>{const p=String(v||'').slice(0,10).split('-');return p.length===3?p.reverse().join('/'):'—'};
    const month=v=>{const k=String(v||'').slice(0,7);return /^\d{4}-\d{2}$/.test(k)?new Intl.DateTimeFormat('pt-BR',{month:'short',year:'2-digit'}).format(new Date(k+'-01T12:00:00Z')).replace('.',''):k||'—'};
    const total=xs=>arr(xs).reduce((s,x)=>s+(n(x)||0),0),tpl=html=>{const t=document.createElement('template');t.innerHTML=html;return t};
    const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
    const addMonths=(iso,delta)=>{const d=new Date(iso+'T12:00:00Z'),day=d.getUTCDate();d.setUTCDate(1);d.setUTCMonth(d.getUTCMonth()+delta);const last=new Date(Date.UTC(d.getUTCFullYear(),d.getUTCMonth()+1,0)).getUTCDate();d.setUTCDate(Math.min(day,last));return d.toISOString().slice(0,10)};
    function expenseRange(){const s=v168.expense,t=today(),year=t.slice(0,4);if(s.key==='6m')return{from:addMonths(t,-5).slice(0,8)+'01',to:t};if(s.key==='12m')return{from:addMonths(t,-11).slice(0,8)+'01',to:t};if(s.key==='all')return{from:'2013-10-10',to:t};if(s.key==='custom'&&/^\d{4}-\d{2}-\d{2}$/.test(s.customFrom)&&/^\d{4}-\d{2}-\d{2}$/.test(s.customTo))return{from:s.customFrom,to:s.customTo};return{from:year+'-01-01',to:t}}
    async function ensureExpenseV171(){
      const s=v168?.expense;if(!s||s.loading||s.data||s.error)return;const token=(s.token||0)+1,r=expenseRange();s.token=token;s.loading=true;s.error=null;state.expenseLoadScheduled=false;
      try{
        const [main,context]=await Promise.all([S.rpc('lts_browser_expense_executive_v6',{p_from:r.from,p_to:r.to}),S.rpc('lts_browser_expense_context_lens_v1',{p_from:r.from,p_to:r.to}).catch(error=>({error}))]);
        if(s.token!==token)return;if(main?.error||!main?.data)throw Error(main?.error?.message||'Despesas indisponíveis');s.data=main.data;s.context=context?.error?null:context?.data;
      }catch(error){if(s.token===token)s.error=String(error?.message||error)}finally{if(s.token===token){s.loading=false;if(V==='Despesas')render()}}
    }
    async function ensureWealthV171(){
      const s=v168?.wealth;if(!s||s.loading||s.data||s.error)return;s.loading=true;s.error=null;state.wealthLoadScheduled=false;
      try{const result=await S.rpc('lts_browser_wealth_detail_v4',{});if(result?.error||!result?.data)throw Error(result?.error?.message||'Patrimônio indisponível');s.data=result.data}
      catch(error){s.error=String(error?.message||error)}finally{s.loading=false;if(V==='Patrimônio')render()}
    }
    function kind(name){const x=norm(name);if(x.includes('investimentos no imovel'))return'Investimento no imóvel';if(x.includes('financiamento')||x.includes('emprestimos'))return'Financiamento';return'Despesa'}
    function rank(groups,limit=15,details=false){const xs=arr(groups).filter(x=>n(x.total)!=null).sort((a,b)=>n(b.total)-n(a.total)).slice(0,limit),top=Math.max(1,...xs.map(x=>Math.abs(n(x.total)||0)));return '<div class="v171-rank">'+(xs.map((x,i)=>'<div class="v171-rankrow"><span>'+(i+1)+'</span><div><b>'+esc(x.name||x.label||'Outros')+'</b><small>'+esc(kind(x.name||x.label))+'</small><i><u style="width:'+Math.max(2,Math.abs(n(x.total)||0)/top*100)+'%"></u></i>'+(details&&arr(x.subgroups).length?'<details open><summary>Composição</summary>'+x.subgroups.map(y=>'<em><span>'+esc(y.name)+'</span><b>'+brl(y.total)+'</b></em>').join('')+'</details>':'')+'</div><strong>'+brl(x.total)+'</strong></div>').join('')||'<div class="v168-empty">Sem despesas no período selecionado.</div>')+'</div>'}
    function reconciliation(data){const c=data?.coverage_disclosure||{};return n(c.total)>0?'<div class="v171-reconciliation"><b>Conciliação de cartões</b><span>'+brl(c.total)+' permanecem no total do período, sem atribuição a um grupo até que as compras da fatura sejam identificadas.</span></div>':''}

    function dashboardV171(){const t=tpl(baseDashboard()),root=t.content.querySelector('.v168-dashboard'),data=v168.dashboard.data?.expense||{};if(!root)return t.innerHTML;const expense=[...root.querySelectorAll('.v168-kpi')].find(x=>/total de despesas/i.test(x.querySelector('span')?.textContent||''));expense?.classList.add('v171-expense-total');const card=[...root.querySelectorAll('.v168-card')].find(x=>/principais grupos/i.test(x.querySelector('h2')?.textContent||''));if(card&&arr(data.management_groups).length){card.querySelectorAll('.v168-rank,.v169-coverage,.v170-rank,.v170-audit').forEach(x=>x.remove());const sm=card.querySelector('.v168-cardhead small');if(sm)sm.textContent='Top 12 · classificação financeira';card.insertAdjacentHTML('beforeend',rank(data.management_groups,12,false)+reconciliation(data))}return t.innerHTML}

    function matrix(title,subtitle,groups,months){return '<article class="v169-balance-section"><div class="v168-cardhead"><div><span>'+esc(subtitle)+'</span><h2>'+esc(title)+'</h2></div><small>'+groups.length+' grupo(s)</small></div><div class="v169-matrix-wrap"><table class="v169-matrix"><thead><tr><th>Grupo</th>'+months.map(x=>'<th>'+esc(month(x))+'</th>').join('')+'<th>Total</th></tr></thead><tbody>'+(groups.map(g=>'<tr><th>'+esc(g.label)+'</th>'+arr(g.monthly).map(x=>'<td>'+((n(x.amount)||0)?brl(x.amount):'—')+'</td>').join('')+'<td class="total">'+brl(g.total)+'</td></tr>').join('')||'<tr><td colspan="'+(months.length+2)+'" class="v168-empty">Sem valores neste período.</td></tr>')+'</tbody></table></div></article>'}
    function monthly(){const j=v169?.monthly?.data||{},tot=j.totals||{},rows=arr(j.monthly_totals),months=arr(j.months),cover=j.expense_unclassified_card_coverage||{};if(v169?.monthly?.loading&&!v169.monthly.data)return'<div class="v168-skeleton"></div>';if(v169?.monthly?.error&&!v169.monthly.data)return'<div class="v168-error">'+esc(v169.monthly.error)+'</div>';return '<div class="v169-monthly v171-monthly"><div class="v168-kpis"><article class="v168-kpi primary"><span>Receitas operacionais</span><strong>'+brl(tot.revenue)+'</strong><small>recorrentes e operacionais</small></article><article class="v168-kpi v171-expense-total"><span>Despesas do período</span><strong>'+brl(tot.expenses)+'</strong><small>recorrentes, financiamentos e investimentos separados abaixo</small></article><article class="v168-kpi"><span>Resultado mensal</span><strong>'+brl(tot.operating_balance)+'</strong><small>receitas menos despesas</small></article><article class="v168-kpi"><span>Entradas extraordinárias</span><strong>'+brl(tot.extraordinary)+'</strong><small>fora da receita recorrente</small></article><article class="v168-kpi"><span>Resultado após entradas extraordinárias</span><strong>'+brl(tot.cash_after_extraordinary)+'</strong><small>efeito total no mês</small></article></div>'+matrix('Receitas operacionais','Entradas recorrentes',arr(j.revenue_groups),months)+matrix('Entradas extraordinárias','Eventos não recorrentes',arr(j.extraordinary_groups),months)+matrix('Despesas por grupo','Classificação financeira',arr(j.expense_groups),months)+(n(cover.total)>0?'<article class="v169-balance-section"><div class="v168-cardhead"><div><span>Conciliação</span><h2>Compras de cartão ainda sem categoria</h2></div><strong>'+brl(cover.total)+'</strong></div><p class="v171-copy">Esses valores permanecem no total mensal, mas não foram atribuídos a um grupo sem o detalhe das compras.</p></article>':'')+'<article class="v169-balance-section"><div class="v168-cardhead"><div><span>Fechamento</span><h2>Resultado de cada mês</h2></div><small>todo o período selecionado</small></div><div class="v169-matrix-wrap"><table class="v169-matrix compact"><thead><tr><th>Mês</th><th>Receitas</th><th>Despesas</th><th>Resultado mensal</th><th>Extraordinárias</th><th>Resultado final</th></tr></thead><tbody>'+rows.map(x=>'<tr><th>'+month(x.month)+'</th><td>'+brl(x.revenue)+'</td><td>'+brl(x.expenses)+'</td><td class="'+((n(x.operating_balance)||0)<0?'negative':'positive')+'">'+brl(x.operating_balance)+'</td><td>'+brl(x.extraordinary)+'</td><td class="'+((n(x.cash_after_extraordinary)||0)<0?'negative':'positive')+'">'+brl(x.cash_after_extraordinary)+'</td></tr>').join('')+'</tbody></table></div></article></div>'}

    function bank(name){const x=norm(name);if(x.includes('aeternum')||x.includes('bradesco'))return'Bradesco';if(x.includes('c6')||x.includes('carbon'))return'C6';if(x.includes('personnalite')||x.includes('mastercard')||x.includes('itau'))return'Itaú';return'Outros'}
    function cards(){const o=D?.card_operating||{},map=new Map(),ensure=(b,c,m)=>{const k=[b,c,m].join('|');if(!map.has(k))map.set(k,{bank:b,card:c,month:m,invoices:[],installments:[]});return map.get(k)};[...arr(o.open_cycles),...arr(o.closed_or_due)].forEach(x=>{const c=x.card_name||x.description||'Cartão não identificado',m=String(x.due_date||'').slice(0,7);if(m)ensure(bank(c),c,m).invoices.push(x)});arr(o.contracted_installment_floor_months).forEach(m=>arr(m.detail).forEach(x=>{const c=x.card_name||'Cartão não identificado';ensure(bank(c),c,String(m.reference_month).slice(0,7)).installments.push(x)}));const all=[...map.values()].filter(x=>x.month>=new Date().toISOString().slice(0,7)).sort((a,b)=>a.bank.localeCompare(b.bank)||a.card.localeCompare(b.card)||a.month.localeCompare(b.month)),banks=['Todos',...new Set(all.map(x=>x.bank))],visible=all.filter(x=>state.cardBank==='Todos'||x.bank===state.cardBank),groups=new Map();visible.forEach(x=>{const k=x.bank+'|'+x.card;if(!groups.has(k))groups.set(k,{bank:x.bank,card:x.card,rows:[]});groups.get(k).rows.push(x)});return '<div class="v171-cards"><div class="v169-bank-filter">'+banks.map(x=>'<button class="v168-btn '+(state.cardBank===x?'primary':'')+'" data-v171-card-bank="'+esc(x)+'">'+esc(x)+'</button>').join('')+'</div><article class="v168-card"><div class="v168-cardhead"><div><span>Conferência bancária</span><h2>Faturas e parcelas por banco e cartão</h2></div><small>mês a mês</small></div>'+( [...groups.values()].map(g=>'<section class="v171-cardgroup"><header><span>'+esc(g.bank)+'</span><h3>'+esc(g.card)+'</h3></header><div class="v171-cardmonths">'+g.rows.map(x=>{const inv=total(x.invoices.map(y=>y.amount)),inst=total(x.installments.map(y=>y.amount)),used=x.invoices.length?inv:inst,diff=x.invoices.length&&x.installments.length?inv-inst:null;return '<div><b>'+month(x.month)+'</b><dl><dt>Fatura conhecida</dt><dd>'+brl(inv)+'</dd><dt>Parcelas já contratadas</dt><dd>'+brl(inst)+'</dd><dt>Considerado no Fluxo</dt><dd><strong>'+brl(used)+'</strong></dd>'+(diff!=null?'<dt>Diferença</dt><dd>'+brl(diff)+'</dd>':'')+'</dl></div>'}).join('')+'</div></section>').join('')||'<div class="v168-empty">Nenhuma fatura futura documentada neste filtro.</div>')+'</article><div class="v171-reconciliation"><b>Leitura</b><span>Quando existe fatura observada, ela prevalece. Nos meses seguintes aparecem apenas as parcelas já contratadas; novas compras ainda podem alterar a fatura.</span></div></div>'}

    function expensesV171(){const t=tpl(baseExpenses()),root=t.content.querySelector('.v168-expenses'),data=v168.expense.data||{},tabs=root?.querySelector('.v168-tabs');if(!root||!tabs)return t.innerHTML;if(v168.expense.tab==='overview'&&arr(data.management_groups).length){const card=[...root.querySelectorAll('.v168-card')].find(x=>/maiores grupos/i.test(x.querySelector('h2')?.textContent||''));if(card){card.querySelectorAll('.v168-rank,.v169-coverage,.v170-rank,.v170-audit').forEach(x=>x.remove());card.insertAdjacentHTML('beforeend',rank(data.management_groups,15,false)+reconciliation(data))}}if(v168.expense.tab==='categories'&&arr(data.management_groups).length){let p=tabs.nextSibling;while(p){const q=p.nextSibling;p.remove();p=q}tabs.insertAdjacentHTML('afterend','<article class="v168-card v171-categories"><div class="v168-cardhead"><div><span>Classificação financeira</span><h2>Despesas, financiamentos e investimentos separados</h2></div><strong>'+brl(data.summary?.selected_total)+'</strong></div>'+rank(data.management_groups,99,true)+reconciliation(data)+'</article>')}if(v168.expense.tab==='monthly'){const old=root.querySelector('.v169-monthly,.v168-skeleton,.v168-error');if(old){const h=tpl(monthly());old.replaceWith(...h.content.childNodes)}}if(v168.expense.tab==='cards'){const old=root.querySelector('.v169-cards');if(old){const h=tpl(cards());old.replaceWith(...h.content.childNodes)}}return t.innerHTML}

    const rawRpc=(name,args)=>previousRpc(name,args||{});
    function mergeFlows(parts,from,to){const flows=parts.map(x=>x?.data?.flow).filter(Boolean),hist=flows.flatMap(x=>arr(x.historical?.days)),histEvents=flows.flatMap(x=>arr(x.historical?.events)),future=flows.flatMap(x=>arr(x.current_future?.days)),futureEvents=flows.flatMap(x=>arr(x.current_future?.events)),base=flows[0]||{};return{...base,from,to,historical:{...(base.historical||{}),days:hist.sort((a,b)=>String(a.date).localeCompare(String(b.date))),events:histEvents.sort((a,b)=>String(a.event_date).localeCompare(String(b.event_date)))},current_future:{...(base.current_future||{}),days:future.sort((a,b)=>String(a.date).localeCompare(String(b.date))),events:futureEvents.sort((a,b)=>String(a.event_date).localeCompare(String(b.event_date)))}}}
    loadFlowRange=async function(from,to){const t=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo'}).format(new Date()),shift=delta=>{const d=new Date(t+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+delta);return d.toISOString().slice(0,10)};if(from===shift(-5)&&to===shift(30))to=String(Number(t.slice(0,4))+1)+'-12-31';const seq=++state.flowSequence,yesterday=new Date(t+'T12:00:00Z');yesterday.setUTCDate(yesterday.getUTCDate()-1);const y=yesterday.toISOString().slice(0,10),calls=[];FLOWLOADING=true;FLOWFROM=from;FLOWTO=to;if(V==='Fluxo Diário')render();if(from<t)calls.push(rawRpc('lts_browser_flow_v241',{p_from:from,p_to:to<t?to:y}));if(to>=t)calls.push(rawRpc('lts_browser_flow_v241',{p_from:from>t?from:t,p_to:to}));try{const parts=await Promise.all(calls);if(seq!==state.flowSequence)return;const error=parts.find(x=>x.error);if(error)throw Error(error.error?.message||'Fluxo indisponível');FLOWQ=mergeFlows(parts,from,to);FLOWLOADING=false;if(V==='Fluxo Diário')render();if(from<t){rawRpc('lts_browser_flow_v241',{p_from:from,p_to:to<t?to:y}).then(up=>{if(seq!==state.flowSequence||up.error||!up.data?.flow)return;FLOWQ=mergeFlows([{data:{flow:{...FLOWQ,historical:up.data.flow.historical}}}],from,to);if(V==='Fluxo Diário')render()})}}catch(e){if(seq!==state.flowSequence)return;FLOWQ={error:'Não foi possível carregar este período. Tente novamente.',historical:{days:[],events:[]},current_future:{days:[],events:[]}};FLOWLOADING=false;if(V==='Fluxo Diário')render()}};

    function after(){document.querySelectorAll('.v168-history-note').forEach(x=>x.setAttribute('aria-hidden','true'));document.querySelectorAll('[data-v171-card-bank]').forEach(b=>b.onclick=()=>{state.cardBank=b.dataset.v171CardBank;render()});if(V==='Despesas'&&v168?.expense&&!v168.expense.loading&&!v168.expense.data&&!v168.expense.error&&!state.expenseLoadScheduled){state.expenseLoadScheduled=true;queueMicrotask(ensureExpenseV171)}if(V==='Patrimônio'&&v168?.wealth&&!v168.wealth.loading&&!v168.wealth.data&&!v168.wealth.error&&!state.wealthLoadScheduled){state.wealthLoadScheduled=true;queueMicrotask(ensureWealthV171)}if(topScope)topScope.dataset.v171Route=V==='Fluxo Diário'?'Fluxo de caixa':V}
    dashboard=dashboardV171;despesas=expensesV171;
    render=function(){const out=baseRender();after();return out};renderNav=function(){const out=baseNav();after();return out};
    if(v168){v168.dashboard.data=null;v168.dashboard.started=false;v168.dashboard.loading=false;v168.transactions.rows=null;v168.transactions.error=null}if(v169){v169.monthly.data=null;v169.monthly.key='';v169.monthly.error=null}
    if(D&&!N.classList.contains('hidden'))render();
  }

  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return null;return{w,d}}catch{return null}}
  function install(){const f=frame();if(!f||!f.w.__LTS_V170_V169_REVIEW?.installed)return false;if(!f.d.getElementById('lts-v171-style')){const l=f.d.createElement('link');l.id='lts-v171-style';l.rel='stylesheet';l.href='lts-v171-v170-review.css?v=20260917-v171a';f.d.head.appendChild(l)}if(!f.w.__LTS_V171_V170_REVIEW?.installed&&!f.d.getElementById('lts-v171-runtime')){const s=f.d.createElement('script');s.id='lts-v171-runtime';s.textContent='('+runtime.toString()+')();';f.d.head.appendChild(s)}const ready=f.w.__LTS_V171_V170_REVIEW?.installed===true;if(ready&&gate)gate.remove();return ready}
  function burst(){const current=++generation;let n=0;function step(){if(current!==generation)return;const ok=install();n++;if(!ok&&n<320)setTimeout(step,100)}step();[400,900,1800,3600,7000,12000,20000,30000].forEach(ms=>setTimeout(()=>{if(current===generation)install()},ms))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();window.__LTS_TOP_CANDIDATE_VERSION='v171-v170-review';
})();

;
;
/* LTS V384: lts-v172-v171-review.js */
(function(){
  'use strict';
  const outer=document.getElementById('shell'),gate=document.getElementById('gate'),scope=document.getElementById('scope');
  let generation=0;

  function runtime(){
    'use strict';
    if(window.__LTS_V172_V171_REVIEW?.installed||!window.__LTS_V171_V170_REVIEW?.installed)return;
    const baseRender=render,baseNav=renderNav,baseDashboard=dashboard,baseExpenses=despesas,baseWealth=patrimonio;
    const v168=window.__LTS_V168_STATE,v169=window.__LTS_V169_STATE;
    const state=window.__LTS_V172_STATE||(window.__LTS_V172_STATE={flowSequence:0,flowWarning:'',monthlyChunkCalls:0});
    const previousRpc=S.rpc.bind(S);
    async function directRpc(name,args){
      const controller=new AbortController();let timer;const startTimer=()=>{timer=setTimeout(()=>controller.abort(),name==='lts_browser_flow_v242'?48000:25000)};if(!window.__LTS_V227_TRANSPORT?.installed)startTimer();
      try{
        const auth=await S.auth.getSession(),token=auth?.data?.session?.access_token||K,response=await fetch(U+'/rest/v1/rpc/'+encodeURIComponent(name),{method:'POST',headers:{apikey:K,Authorization:'Bearer '+token,'Content-Type':'application/json',Accept:'application/json'},body:JSON.stringify(args||{}),signal:controller.signal,ltsOnReadStart:startTimer}),payload=await response.json().catch(()=>null);
        if(!response.ok)return{data:null,error:{message:String(payload?.message||payload?.error_description||('HTTP '+response.status)),status:response.status,code:payload?.code}};
        return{data:payload,error:null};
      }catch(error){return{data:null,error:{message:'Não foi possível carregar agora. Tente novamente.',retryable:true}}}finally{clearTimeout(timer)}
    }
    window.__LTS_V172_V171_REVIEW={
      installed:true,version:'v172',base_version:'v171',public_index_changed:false,
      flow_resilient_reader:true,default_flow_range:'previous-5-through-next-year-end',
      monthly_chunked_full_history:true,expense_source_reconciliation:true,
      professional_wealth_overview:true,morgan_decision_summary:true
    };

    const arr=v=>Array.isArray(v)?v:[];
    const num=v=>v===null||v===undefined||v===''?null:(Number.isFinite(Number(v))?Number(v):null);
    const sum=xs=>arr(xs).reduce((total,value)=>total+(num(value)||0),0);
    const esc=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
    const norm=s=>String(s??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim();
    const money=v=>num(v)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(v));
    const number=v=>num(v)==null?'—':new Intl.NumberFormat('pt-BR',{maximumFractionDigits:3}).format(Number(v));
    const usd=v=>num(v)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'USD',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(v));
    const fx=v=>num(v)==null?'—':new Intl.NumberFormat('pt-BR',{minimumFractionDigits:4,maximumFractionDigits:6}).format(Number(v));
    const date=v=>{const p=String(v||'').slice(0,10).split('-');return p.length===3?p.reverse().join('/'):'—'};
    const month=v=>{const key=String(v||'').slice(0,7);return /^\d{4}-\d{2}$/.test(key)?new Intl.DateTimeFormat('pt-BR',{month:'short',year:'2-digit'}).format(new Date(key+'-01T12:00:00Z')).replace('.',''):key||'—'};
    const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
    const shift=(iso,delta)=>{const d=new Date(iso+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+delta);return d.toISOString().slice(0,10)};
    const tpl=html=>{const t=document.createElement('template');t.innerHTML=html;return t};

    function professionalName(value){
      const x=norm(value);
      if(x==='emprestimos e consignado')return'Empréstimos';
      if(x==='compras de cartao ainda sem categoria'||x==='faturas historicas sem compras individualizadas')return'Faturas conciliadas pelo total';
      if(x==='venda de bens e ativos')return'Venda de ações, RSUs e outros ativos';
      if(x==='mercado')return'Mercado';
      if(x==='presentes')return'Presentes';
      if(x==='amazon')return'Amazon';
      return String(value||'Outros');
    }
    function subgroupName(group,value){
      const g=professionalName(group),x=String(value||'').trim();
      if(g==='Financiamento imobiliário')return /^casa$/i.test(x)?'Financiamento imobiliário — Casa':/^cip[oó] 396$/i.test(x)?'Financiamento imobiliário — CIPÓ 396':x;
      if(g==='Empréstimos'&&/^consignado/i.test(x))return'Empréstimo consignado · Coopharma';
      return professionalName(x);
    }
    function usefulSubgroups(group,rows){
      const seen=new Map();
      for(const row of arr(rows)){
        const name=subgroupName(group,row.name),key=norm(name);
        if(!key||key===norm(professionalName(group)))continue;
        const current=seen.get(key)||{name,total:0,rows:0};
        current.total+=(num(row.total)||0);current.rows+=(num(row.rows)||0);seen.set(key,current);
      }
      return [...seen.values()].sort((a,b)=>b.total-a.total);
    }
    function coverageGroup(data){
      const c=data?.coverage_disclosure||{},total=num(c.total)||0;if(total<=0)return null;
      const origins=new Map();
      for(const row of arr(c.by_origin)){
        const name=String(row.name||'Cartão não identificado'),key=norm(name),current=origins.get(key)||{name,total:0,rows:0};
        current.total+=(num(row.total)||0);current.rows+=(num(row.rows)||0);origins.set(key,current);
      }
      return{name:'Faturas conciliadas pelo total',total,rows:num(c.rows)||0,subgroups:[...origins.values()].sort((a,b)=>b.total-a.total)};
    }
    function displayGroups(data,includeCoverage=false){
      const groups=arr(data?.management_groups).map(group=>({
        ...group,name:professionalName(group.name),subgroups:usefulSubgroups(group.name,group.subgroups)
      }));
      if(includeCoverage){const coverage=coverageGroup(data);if(coverage)groups.push(coverage)}
      return groups.sort((a,b)=>(num(b.total)||0)-(num(a.total)||0));
    }
    function rank(groups,limit=15,details=false){
      const rows=arr(groups).filter(x=>num(x.total)!=null).slice(0,limit),top=Math.max(1,...rows.map(x=>Math.abs(num(x.total)||0)));
      return '<div class="v172-rank">'+(rows.map((row,index)=>{
        const children=usefulSubgroups(row.name,row.subgroups);
        return '<div class="v172-rankrow"><span>'+(index+1)+'</span><div><b>'+esc(professionalName(row.name))+'</b><i><u style="width:'+Math.max(2,Math.abs(num(row.total)||0)/top*100)+'%"></u></i>'+(details&&children.length?'<details><summary>Ver composição</summary>'+children.map(child=>'<em><span>'+esc(child.name)+'</span><b>'+money(child.total)+'</b></em>').join('')+'</details>':'')+'</div><strong>'+money(row.total)+'</strong></div>';
      }).join('')||'<div class="v168-empty">Sem despesas no período selecionado.</div>')+'</div>';
    }
    function coverageNote(data){
      const c=data?.coverage_disclosure||{},count=num(c.rows)||0;return (num(c.total)||0)>0?'<div class="v172-coverage"><b>Faturas conciliadas pelo total</b><strong>'+money(c.total)+'</strong><span>Este valor já está incluído nas despesas de cartão e não representa uma categoria adicional. Em '+count+' ciclo(s), a fonte histórica contém o total da fatura, mas não as compras individuais necessárias para uma divisão confiável por tipo de gasto.</span></div>':'';
    }

    function dashboardV172(){
      const t=tpl(baseDashboard()),root=t.content.querySelector('.v168-dashboard'),data=v168?.dashboard?.data?.expense||{};if(!root)return t.innerHTML;
      const card=[...root.querySelectorAll('.v168-card')].find(x=>/principais grupos/i.test(x.querySelector('h2')?.textContent||''));
      if(card&&displayGroups(data).length){
        card.querySelectorAll('.v171-rank,.v171-reconciliation,.v170-rank,.v170-audit,.v169-coverage').forEach(x=>x.remove());
        const caption=card.querySelector('.v168-cardhead small');if(caption)caption.textContent='Top 12';
        card.insertAdjacentHTML('beforeend',rank(displayGroups(data),12,false)+coverageNote(data));
      }
      return t.innerHTML;
    }

    function matrix(title,subtitle,groups,months){
      return '<article class="v169-balance-section"><div class="v168-cardhead"><div><span>'+esc(subtitle)+'</span><h2>'+esc(title)+'</h2></div><small>'+groups.length+' grupo(s)</small></div><div class="v169-matrix-wrap"><table class="v169-matrix v172-matrix"><thead><tr><th>Grupo</th>'+months.map(value=>'<th>'+esc(month(value))+'</th>').join('')+'<th>Total</th></tr></thead><tbody>'+(groups.map(group=>'<tr><th>'+esc(professionalName(group.label))+'</th>'+months.map(value=>{const item=arr(group.monthly).find(x=>String(x.month).slice(0,7)===String(value).slice(0,7)),amount=num(item?.amount)||0;return'<td>'+(amount?money(amount):'—')+'</td>'}).join('')+'<td class="total">'+money(group.total)+'</td></tr>').join('')||'<tr><td colspan="'+(months.length+2)+'" class="v168-empty">Sem valores neste período.</td></tr>')+'</tbody></table></div></article>';
    }
    function monthlyV172(){
      const j=v169?.monthly?.data||{},tot=j.totals||{},rows=arr(j.monthly_totals),months=arr(j.months),cover=j.expense_unclassified_card_coverage||{},expenseGroups=arr(j.expense_groups).map(group=>({...group,label:professionalName(group.label)}));
      if(v169?.monthly?.loading&&!v169.monthly.data)return'<div class="v168-skeleton"></div>';
      if(v169?.monthly?.error&&!v169.monthly.data)return'<div class="v168-error">'+esc(v169.monthly.error)+'</div>';
      return '<div class="v169-monthly v171-monthly v172-monthly"><div class="v168-kpis"><article class="v168-kpi primary"><span>Receitas operacionais</span><strong>'+money(tot.revenue)+'</strong><small>entradas recorrentes</small></article><article class="v168-kpi v171-expense-total"><span>Despesas do período</span><strong>'+money(tot.expenses)+'</strong><small>cartões e contas correntes</small></article><article class="v168-kpi"><span>Resultado operacional</span><strong>'+money(tot.operating_balance)+'</strong><small>receitas menos despesas</small></article><article class="v168-kpi"><span>Entradas extraordinárias</span><strong>'+money(tot.extraordinary)+'</strong><small>vendas de ações, bens, FGTS e empréstimos</small></article><article class="v168-kpi"><span>Resultado final</span><strong>'+money(tot.cash_after_extraordinary)+'</strong><small>após entradas extraordinárias</small></article></div>'+matrix('Receitas operacionais','Receitas',arr(j.revenue_groups),months)+matrix('Entradas extraordinárias','Entradas não recorrentes',arr(j.extraordinary_groups).map(group=>({...group,label:professionalName(group.label)})),months)+matrix('Despesas por categoria','Despesas',expenseGroups,months)+((num(cover.total)||0)>0?'<div class="v172-coverage compact"><b>Faturas conciliadas pelo total</b><strong>'+money(cover.total)+'</strong><span>Incluídas no total mensal; sem divisão por categoria quando a fonte não contém as compras individuais.</span></div>':'')+'<article class="v169-balance-section"><div class="v168-cardhead"><div><span>Fechamento</span><h2>Resultado de cada mês</h2></div><small>'+months.length+' mês(es)</small></div><div class="v169-matrix-wrap"><table class="v169-matrix compact v172-matrix"><thead><tr><th>Mês</th><th>Receitas</th><th>Despesas</th><th>Resultado operacional</th><th>Extraordinárias</th><th>Resultado final</th></tr></thead><tbody>'+rows.map(row=>'<tr><th>'+month(row.month)+'</th><td>'+money(row.revenue)+'</td><td>'+money(row.expenses)+'</td><td class="'+((num(row.operating_balance)||0)<0?'negative':'positive')+'">'+money(row.operating_balance)+'</td><td>'+money(row.extraordinary)+'</td><td class="'+((num(row.cash_after_extraordinary)||0)<0?'negative':'positive')+'">'+money(row.cash_after_extraordinary)+'</td></tr>').join('')+'</tbody></table></div></article></div>';
    }
    function expensesV172(){
      const t=tpl(baseExpenses()),root=t.content.querySelector('.v168-expenses'),data=v168?.expense?.data||{},tabs=root?.querySelector('.v168-tabs');if(!root||!tabs)return t.innerHTML;
      if(v168.expense.tab==='overview'&&displayGroups(data).length){
        const card=[...root.querySelectorAll('.v168-card')].find(x=>/maiores grupos/i.test(x.querySelector('h2')?.textContent||''));
        if(card){card.querySelectorAll('.v171-rank,.v171-reconciliation,.v170-rank,.v170-audit,.v169-coverage').forEach(x=>x.remove());card.insertAdjacentHTML('beforeend',rank(displayGroups(data),15,false)+coverageNote(data))}
      }
      if(v168.expense.tab==='categories'&&displayGroups(data).length){
        let node=tabs.nextSibling;while(node){const next=node.nextSibling;node.remove();node=next}
        tabs.insertAdjacentHTML('afterend','<article class="v168-card v172-categories"><div class="v168-cardhead"><div><span>Composição</span><h2>Despesas por categoria</h2></div><strong>'+money(data.summary?.selected_total)+'</strong></div>'+rank(displayGroups(data),99,true)+coverageNote(data)+'</article>');
      }
      if(v168.expense.tab==='monthly'){
        const old=root.querySelector('.v171-monthly,.v169-monthly,.v168-skeleton,.v168-error');if(old){const content=tpl(monthlyV172());old.replaceWith(...content.content.childNodes)}
      }
      return t.innerHTML;
    }

    function monthSpan(from,to){const a=new Date(from+'T12:00:00Z'),b=new Date(to+'T12:00:00Z');return (b.getUTCFullYear()-a.getUTCFullYear())*12+b.getUTCMonth()-a.getUTCMonth()+1}
    function yearChunks(from,to){const chunks=[];let year=Number(from.slice(0,4)),last=Number(to.slice(0,4));for(;year<=last;year++)chunks.push({from:year===Number(from.slice(0,4))?from:year+'-01-01',to:year===last?to:year+'-12-31'});return chunks}
    async function mapLimit(items,limit,worker){const output=new Array(items.length);let cursor=0;async function run(){while(true){const index=cursor++;if(index>=items.length)return;output[index]=await worker(items[index],index)}}await Promise.all(Array.from({length:Math.min(limit,items.length)},run));return output}
    function mergeMonthlyGroups(parts,key,months){
      const groups=new Map();
      for(const part of parts)for(const row of arr(part[key])){
        const label=professionalName(row.label),id=norm(label),current=groups.get(id)||{label,total:0,source_rows:0,values:new Map()};
        current.total+=(num(row.total)||0);current.source_rows+=(num(row.source_rows)||0);
        for(const item of arr(row.monthly)){const monthKey=String(item.month).slice(0,10);current.values.set(monthKey,(current.values.get(monthKey)||0)+(num(item.amount)||0))}
        groups.set(id,current);
      }
      return [...groups.values()].map(group=>({label:group.label,total:group.total,source_rows:group.source_rows,monthly:months.map(monthKey=>({month:monthKey,amount:group.values.get(monthKey)||0}))})).sort((a,b)=>b.total-a.total);
    }
    function mergeMonthly(parts,from,to){
      const months=parts.flatMap(part=>arr(part.months)).map(value=>String(value).slice(0,10)).filter((value,index,self)=>self.indexOf(value)===index).sort();
      const monthRows=parts.flatMap(part=>arr(part.monthly_totals)).sort((a,b)=>String(a.month).localeCompare(String(b.month)));
      const totals=['revenue','expenses','operating_balance','extraordinary','cash_after_extraordinary'].reduce((out,key)=>(out[key]=sum(parts.map(part=>part.totals?.[key])),out),{});
      const coverageValues=new Map();let coverageTotal=0,coverageRows=0;
      for(const part of parts){const coverage=part.expense_unclassified_card_coverage||{};coverageTotal+=(num(coverage.total)||0);coverageRows+=(num(coverage.source_rows)||0);for(const item of arr(coverage.monthly)){const key=String(item.month).slice(0,10);coverageValues.set(key,(coverageValues.get(key)||0)+(num(item.amount)||0))}}
      return{...parts[0],version:'monthly-balance-v3-v172-chunked',from,to,months,monthly_totals:monthRows,totals,revenue_groups:mergeMonthlyGroups(parts,'revenue_groups',months),extraordinary_groups:mergeMonthlyGroups(parts,'extraordinary_groups',months),expense_groups:mergeMonthlyGroups(parts,'expense_groups',months),expense_unclassified_card_coverage:{label:'Faturas conciliadas pelo total',total:coverageTotal,source_rows:coverageRows,monthly:months.map(key=>({month:key,amount:coverageValues.get(key)||0}))}};
    }
    S.rpc=async function(name,args){
      const requested=String(name||''),next={...(args||{})};
      if((requested==='lts_browser_monthly_balance_v1'||requested==='lts_browser_monthly_balance_v2')&&/^\d{4}-\d{2}-\d{2}$/.test(next.p_from||'')&&/^\d{4}-\d{2}-\d{2}$/.test(next.p_to||'')&&monthSpan(next.p_from,next.p_to)>18){
        const chunks=yearChunks(next.p_from,next.p_to);state.monthlyChunkCalls=chunks.length;
        try{
          const parts=await mapLimit(chunks,3,async chunk=>{const response=await directRpc('lts_browser_monthly_balance_v2',{p_from:chunk.from,p_to:chunk.to});if(response?.error||!response?.data)throw Error(response?.error?.message||'Balanço mensal indisponível');return response.data});
          return{data:mergeMonthly(parts,next.p_from,next.p_to),error:null};
        }catch(error){return{data:null,error:{message:String(error?.message||error)}}}
      }
      if(requested==='lts_browser_monthly_balance_v1')return previousRpc('lts_browser_monthly_balance_v2',next);
      return previousRpc(requested,next);
    };

    function commitment(j,id){return arr(j?.financing?.summary?.commitments).find(row=>row.id===id)||{}}
    function obligationValue(row){return num(row.remaining_scheduled_outflow_current_terms??row.remaining_scheduled_outflow??row.remaining_economic_outflow)}
    function list(rows){return '<div class="v172-value-list">'+arr(rows).filter(row=>num(row.total)!=null).map(row=>'<div><span>'+esc(row.name)+(row.note?'<small>'+esc(row.note)+'</small>':'')+'</span><b>'+money(row.total)+'</b></div>').join('')+'</div>'}
    function wealthOverview(j){
      const w=j.wealth||{},summary=w.summary||{},x=j.wealth_v167||j.wealth_v168||{},p=j.pensions||{},r=j.rsu_summary||{},m=j.morgan_statement||{},c=w.assets?.cipo_396||{},v=w.assets?.volvo_xc40||{},liquidity=w.liquidity||{},co=commitment(j,'coopharma'),family=commitment(j,'pai_mae'),coValue=obligationValue(co),familyValue=obligationValue(family),cash=(num(liquidity.bank_cash)||0)+(num(liquidity.d0)||0),futureNet=num(r.future_considered_total_brl),net=x.net_worth_central_including_pensions??summary.net_worth_central,assets=x.assets_central_including_pensions??summary.assets_central;
      return '<div class="v172-wealth-overview"><div class="v168-kpis"><article class="v168-kpi primary"><span>Patrimônio líquido hoje</span><strong>'+money(net)+'</strong><small>ativos atuais menos dívidas atuais</small></article><article class="v168-kpi"><span>Bens e ativos atuais</span><strong>'+money(assets)+'</strong><small>inclui previdências</small></article><article class="v168-kpi v171-expense-total"><span>Dívidas com saldo informado</span><strong>'+money(summary.known_debt_total)+'</strong><small>financiamentos atuais</small></article><article class="v168-kpi"><span>Previdências</span><strong>'+money(p.total_gross_brl)+'</strong><small>valor bruto restrito</small></article><article class="v168-kpi"><span>A receber no futuro</span><strong>'+money(futureNet)+'</strong><small>fora do patrimônio de hoje</small></article></div><div class="v172-wealth-grid"><article class="v168-card"><div class="v168-cardhead"><div><span>Bens</span><h2>Imóvel e veículo</h2></div></div>'+list([{name:'CIPÓ 396 · valor de mercado',total:c.market_central},{name:'Volvo XC40 · valor de mercado',total:v.market_central}])+'</article><article class="v168-card"><div class="v168-cardhead"><div><span>Disponível agora</span><h2>Dinheiro e investimentos líquidos</h2></div></div>'+list([{name:'Contas + aplicações D0',total:cash},{name:'Morgan Stanley · disponível',total:j.current_liquidity?.brokerage_available??m.available_total_brl??r.available_total_brl}])+'</article><article class="v168-card"><div class="v168-cardhead"><div><span>Restrito</span><h2>Previdências</h2></div><strong>'+money(p.total_gross_brl)+'</strong></div>'+list(arr(p.positions).map(row=>({name:row.name,total:row.gross_balance_brl,note:'posição '+date(row.as_of)})))+'</article><article class="v168-card v172-debts"><div class="v168-cardhead"><div><span>Dívidas</span><h2>Financiamentos e empréstimos</h2></div></div><h3>Saldos para quitação</h3>'+list([{name:'Financiamento imobiliário · CIPÓ 396',total:c.documentary_debt},{name:'Financiamento do Volvo XC40',total:v.documented_financed_balance}])+'<h3>Parcelas restantes</h3>'+list([{name:'Empréstimo consignado · Coopharma',total:coValue,note:(co.remaining_events??'—')+' parcela(s)'},{name:'Empréstimo familiar · Pai e Mãe',total:familyValue,note:(family.remaining_events??'—')+' parcela(s)'}])+'</article><article class="v168-card v172-future"><div class="v168-cardhead"><div><span>Futuro</span><h2>Compensação ainda não disponível</h2></div><strong>'+money(futureNet)+'</strong></div>'+list([{name:'RSUs futuras · bruto',total:r.future_regular_brl},{name:'Cash RSUs futuras · líquido projetado',total:r.future_cash_net_brl}])+'</article></div></div>';
    }
    function awardType(row){return /cash/i.test(String(row.asset_type||''))?'Cash RSU':'RSU'}
    function rsuPanel(j){
      const r=j.rsu_summary||{},m=j.morgan_statement||{},available=m.available_components||{},future=m.future_components||{},q=m.quantities||{},recon=m.planning_schedule_reconciliation||{},rows=arr(j.rsu?.future_schedule),ret=j.employment_awards?.retention||{},first=rows[0]||{},pairs=[...new Set(rows.map(row=>String(row.unit_price_usd)+'|'+String(row.fx_rate)))],mixed=pairs.length>1,gross=m.gross_total_brl??((num(r.available_total_brl)||0)+(num(r.future_regular_brl)||0)+(num(r.future_cash_net_brl)||0)),futureNet=r.future_considered_total_brl,currentAvailable=j.current_liquidity?.brokerage_available??m.available_total_brl??r.available_total_brl,currentShares=j.current_awards?.vested_shares??available.vested_shares_brl??r.vested_shares_brl,currentCash=j.current_awards?.brokerage_cash??available.brokerage_cash_brl??r.brokerage_cash_brl,totalNet=num(currentAvailable)!==null&&num(futureNet)!==null?num(currentAvailable)+num(futureNet):null;
      return '<div class="v172-morgan"><div class="v168-kpis"><article class="v168-kpi primary"><span>Total bruto do extrato</span><strong>'+money(gross)+'</strong><small>posição Morgan Stanley em '+date(m.as_of||r.as_of)+'</small></article><article class="v168-kpi"><span>Disponível agora</span><strong>'+money(currentAvailable)+'</strong><small>'+(num(r.settled_withdrawals_brl)>0?'Após resgates recebidos':'Ações e saldo em corretora')+'</small></article><article class="v168-kpi"><span>A receber líquido projetado</span><strong>'+money(futureNet)+'</strong><small>RSUs futuras + Cash RSUs após reserva</small></article><article class="v168-kpi"><span>Total líquido projetado</span><strong>'+money(totalNet)+'</strong><small>disponível agora + futuro líquido</small></article></div><div class="v172-morgan-components"><article><span>Composição em '+date(j.current_awards?.as_of||m.as_of||r.as_of)+'</span><h3>'+money(num(currentShares)+num(currentCash))+'</h3><dl><dt>Ações vested</dt><dd>'+money(currentShares)+'</dd><dt>Saldo em corretora</dt><dd>'+money(currentCash)+'</dd></dl></article><article><span>RSUs futuras</span><h3>'+money(r.future_regular_brl)+'</h3><small>Projeção da agenda · valor bruto</small></article><article><span>Cash RSUs futuras</span><h3>'+money(r.future_cash_net_brl)+'</h3><small>Projeção da agenda · reserva de 30%</small></article></div><div class="v168-note">As projeções usam as quantidades da agenda e as referências atuais de Cotações. O extrato mantém sua posição original. As Cash RSUs usam reserva de 30% somente para planejamento.</div></div><article class="v168-card v170-global-award"><div class="v168-cardhead"><div><span>Cotação única</span><h2>Atualizar todos os vestings</h2></div><small>'+rows.length+' vesting(s) ativo(s)</small></div><div class="v170-global-form"><label>Preço da ação (USD)<input id="v170AllAwardPrice" type="number" min="0.01" max="10000" step="0.01" value="'+esc(first.unit_price_usd??'')+'"></label><label>Câmbio USD/BRL<input id="v170AllAwardFx" type="number" min="0.0001" max="100" step="0.000001" value="'+esc(first.fx_rate??'')+'"></label><button class="v168-btn primary" id="v170AllAwardApply" '+(window.__LTS_V170_STATE?.globalAward?.saving?'disabled':'')+'>'+(window.__LTS_V170_STATE?.globalAward?.saving?'Atualizando todos…':'Aplicar a todos os vestings')+'</button></div><div class="v170-global-help">'+(mixed?'As premissas atuais variam. Ao aplicar, todos os vestings receberão os mesmos valores.':'A mesma cotação e o mesmo câmbio serão aplicados a RSUs e Cash RSUs.')+'</div>'+(window.__LTS_V170_STATE?.globalAward?.message?'<div class="v168-note good">'+esc(window.__LTS_V170_STATE.globalAward.message)+'</div>':'')+(window.__LTS_V170_STATE?.globalAward?.error?'<div class="v168-note warn">'+esc(window.__LTS_V170_STATE.globalAward.error)+'</div>':'')+'</article><article class="v168-card"><div class="v168-cardhead"><div><span>Agenda</span><h2>Vestings e disponibilidade</h2></div><strong>'+money(futureNet)+'</strong></div><div class="v170-reconciliation"><span>Extrato e agenda permanecem separados para conferência.</span><small>RSU: diferença '+money(recon.regular_delta_brl)+' · Cash RSU bruto: diferença '+money(recon.cash_delta_brl)+'.</small></div><div class="v168-awards">'+rows.map((row,index)=>{const type=awardType(row),value=type==='Cash RSU'?row.net_value_brl:row.gross_value_brl;return'<div class="v168-award"><div><span>Vesting</span><b>'+date(row.eligibility_date)+'</b><small>'+esc(type)+'</small></div><div><span>Quantidade</span><b>'+number(row.quantity)+'</b></div><div><span>Cotação usada</span><b>'+usd(row.unit_price_usd)+'</b><small>câmbio '+fx(row.fx_rate)+'</small></div><div><span>Valor considerado</span><b>'+money(value)+'</b><small>'+date(row.available_date)+' disponível</small></div><label><span>Antecipação opcional</span><input type="date" data-v168-award-date="'+index+'" max="'+esc(row.eligibility_date)+'" value="'+esc(row.anticipated_date||'')+'"></label><div><button class="v168-btn" data-v168-award-edit="'+index+'">Cotação individual</button> <button class="v168-btn blue" data-v168-award-save="'+index+'">Salvar data</button></div></div>'}).join('')+'</div></article><article class="v168-card"><div class="v168-cardhead"><div><span>Retention Award</span><h2>Acordo separado de RSU</h2></div><strong>'+money(ret.gross_total_brl)+'</strong></div></article>';
    }
    function wealthV172(){
      const t=tpl(baseWealth()),root=t.content.querySelector('.v168-wealth'),tabs=root?.querySelector('.v168-tabs'),j=v168?.wealth?.data||{};if(!root||!tabs)return t.innerHTML;
      if(v168.wealth.tab==='overview'&&j.wealth){let node=tabs.nextSibling;while(node){const next=node.nextSibling;node.remove();node=next}tabs.insertAdjacentHTML('afterend',wealthOverview(j))}
      if(v168.wealth.tab==='rsu'&&j.morgan_statement){let node=tabs.nextSibling;while(node){const next=node.nextSibling;node.remove();node=next}tabs.insertAdjacentHTML('afterend',rsuPanel(j))}
      return t.innerHTML;
    }

    function defaultRange(){const current=today();return{from:shift(current,-5),to:String(Number(current.slice(0,4))+4)+'-12-31'}}
    function isLegacyDefault(from,to){const current=today(),nextYear=String(Number(current.slice(0,4))+4)+'-12-31';return from===shift(current,-5)&&(to===String(Number(current.slice(0,4))+4)+'-12-31'||to===shift(current,30))}
    function uniqueRows(rows,dateKey,extraKey){const seen=new Map();for(const row of rows){const key=String(row?.[dateKey]||'')+'|'+String(row?.[extraKey]||'')+'|'+String(row?.source_ref||'');seen.set(key,row)}return[...seen.values()].sort((a,b)=>String(a?.[dateKey]).localeCompare(String(b?.[dateKey])))}
    function mergeFlows(parts,from,to){
      const flows=parts.map(part=>part?.data?.flow).filter(Boolean),base=flows.reduce((out,flow)=>({...out,...flow}),{}),historicalDays=uniqueRows(flows.flatMap(flow=>arr(flow.historical?.days)),'date',''),historicalEvents=uniqueRows(flows.flatMap(flow=>arr(flow.historical?.events)),'event_date','description'),futureDays=uniqueRows(flows.flatMap(flow=>arr(flow.current_future?.days)),'date',''),futureEvents=uniqueRows(flows.flatMap(flow=>arr(flow.current_future?.events)),'event_date','description');
      return{...base,from,to,historical:{...(base.historical||{}),days:historicalDays,events:historicalEvents},current_future:{...(base.current_future||{}),days:futureDays,events:futureEvents}};
    }
    async function flowPart(name,from,to){const shared=await window.__LTS_V178_REVIEW?.cachedFlow?.(from,to);if(shared)return{data:shared,error:null};const response=await directRpc(name,{p_from:from,p_to:to});if(response?.error||!response?.data?.flow){const error=Error(response?.error?.message||'Fluxo indisponível');error.retryable=!!response?.error?.retryable||['57014','40001'].includes(response?.error?.code)||[408,429,500,502,503,504].includes(response?.error?.status);throw error}return response}
    async function performFlowRange(from,to){
      const current=today(),seq=++state.flowSequence,yesterday=shift(current,-1),calls=[];state.flowWarning='';FLOWLOADING=true;FLOWFROM=from;FLOWTO=to;FLOWPRESET=from===shift(current,-5)&&to===String(Number(current.slice(0,4))+4)+'-12-31'?'5 anteriores + fim de '+current.slice(0,4):FLOWPRESET;if(V==='Fluxo Diário')render();
      calls.push({kind:'complete',from,to});
      // Avoid competing historical/future scans while bank ingestion is active.
      // Retry transient read failures once, after the other part has finished.
      const settled=[];
      for(const call of calls){
        if(seq!==state.flowSequence)return;
        try{settled.push({status:'fulfilled',value:await flowPart('lts_browser_flow_v242',call.from,call.to)})}
        catch(reason){settled.push({status:'rejected',reason})}
      }
      for(let i=0;i<settled.length;i++){
        if(seq!==state.flowSequence)return;
        if(settled[i].status!=='rejected'||!settled[i].reason?.retryable)continue;
        const call=calls[i];
        try{settled[i]={status:'fulfilled',value:await flowPart('lts_browser_flow_v242',call.from,call.to)}}
        catch(reason){settled[i]={status:'rejected',reason}}
      }
      if(seq!==state.flowSequence)return;
      const good=settled.filter(item=>item.status==='fulfilled').map(item=>item.value),failed=settled.filter(item=>item.status==='rejected');
      if(!good.length){FLOWQ={error:'Não foi possível carregar este período. Tente novamente.',historical:{days:[],events:[]},current_future:{days:[],events:[]}};FLOWLOADING=false;if(V==='Fluxo Diário')render();return}
      FLOWQ=mergeFlows(good,from,to);FLOWLOADING=false;if(failed.length)state.flowWarning='Uma parte do período não pôde ser atualizada. Os dados disponíveis continuam visíveis.';if(V==='Fluxo Diário')render();

    }
    loadFlowRange=function(from,to){
      if(!window.__LTS_V178_REVIEW?.installed)return Promise.resolve();
      if(from===today()&&to===shift(today(),29)&&(V!=='Fluxo Diário'||(!window.__LTS_DASHBOARD_EXECUTIVE_STATUS?.initial_applied_at&&!window.__LTS_V382_FLOW_LAYOUT?.explicit_period_action)))return Promise.resolve();
      if(isLegacyDefault(from,to)){const range=defaultRange();from=range.from;to=range.to}const key=from+'|'+to;
      if(state.rangePending?.key===key)return state.rangePending.promise;
      const promise=performFlowRange(from,to);state.rangePending={key,promise};
      promise.finally(()=>{if(state.rangePending?.promise===promise)state.rangePending=null});return promise;
    };
    function openDefault(){
      const range=defaultRange(),key=range.from+'|'+range.to;SHOWZERO=false;FLOWFORCEZERO=false;
      if(state.defaultPending?.key===key&&FLOWFROM===range.from&&FLOWTO===range.to)return state.defaultPending.promise;
      const promise=Promise.resolve(loadFlowRange(range.from,range.to));state.defaultPending={key,promise};
      promise.finally(()=>setTimeout(()=>{if(state.defaultPending?.promise===promise)state.defaultPending=null},1200));return promise;
    }
    function bindFlow(){
      const activate=()=>{const hasPeriod=/^\d{4}-\d{2}-\d{2}$/.test(String(FLOWFROM||''))&&/^\d{4}-\d{2}-\d{2}$/.test(String(FLOWTO||''))&&FLOWFROM<=FLOWTO;V='Fluxo Diário';if(window.__LTS_V170_STATE)window.__LTS_V170_STATE.lastRoute=V;renderNav();render();if(!hasPeriod||!state.flowNavigationOpened){state.flowNavigationOpened=true;openDefault()}};
      document.querySelectorAll('.nav [data-v="Fluxo Diário"],#dx1MobileNav [data-mobile-route="Fluxo Diário"]').forEach(button=>button.onclick=activate);
      if(V!=='Fluxo Diário')return;const range=defaultRange(),button=document.getElementById('flowDefaultRange');if(button){button.textContent='5 anteriores + fim de '+range.to.slice(0,4);button.title='Cinco dias anteriores até 31 de dezembro do quinto ano do horizonte';button.classList.toggle('active',FLOWFROM===range.from&&FLOWTO===range.to);button.onclick=openDefault}const todayButton=document.getElementById('goToday');if(todayButton)todayButton.onclick=openDefault;
      document.querySelectorAll('.v168-history-note').forEach(node=>node.remove());document.querySelector('.v172-flow-warning')?.remove();if(state.flowWarning){document.querySelector('.flow-sticky-controls')?.insertAdjacentHTML('beforeend','<div class="v172-flow-warning">'+esc(state.flowWarning)+'</div>')}
    }
    function stamp(){const badge=window.parent?.document?.getElementById('scope');if(badge)badge.dataset.v172Route=V==='Fluxo Diário'?'Fluxo de caixa':V}
    function after(){stamp();bindFlow()}

    dashboard=dashboardV172;despesas=expensesV172;patrimonio=wealthV172;
    render=function(){const out=baseRender();after();return out};renderNav=function(){const out=baseNav();stamp();bindFlow();return out};
    if(v168){v168.dashboard.data=null;v168.dashboard.started=false;v168.dashboard.loading=false;v168.expense.data=null;v168.expense.loading=false}if(v169){v169.monthly.data=null;v169.monthly.key='';v169.monthly.error=null}
    if(D&&!N.classList.contains('hidden'))render();
  }

  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return null;return{w,d}}catch{return null}}
  function install(){const f=frame();if(!f||!f.w.__LTS_V171_V170_REVIEW?.installed)return false;if(!f.d.getElementById('lts-v172-style')){const link=f.d.createElement('link');link.id='lts-v172-style';link.rel='stylesheet';link.href='lts-v172-v171-review.css?v=20260917-v172a';f.d.head.appendChild(link)}if(!f.w.__LTS_V172_V171_REVIEW?.installed&&!f.d.getElementById('lts-v172-runtime')){const script=f.d.createElement('script');script.id='lts-v172-runtime';script.textContent='('+runtime.toString()+')();';f.d.head.appendChild(script)}const ready=f.w.__LTS_V172_V171_REVIEW?.installed===true;if(ready&&gate)gate.remove();return ready}
  function burst(){const current=++generation;let attempt=0;function step(){if(current!==generation)return;const ready=install();attempt++;if(!ready&&attempt<320)setTimeout(step,100)}step();[400,900,1800,3600,7000,12000,20000,30000].forEach(ms=>setTimeout(()=>{if(current===generation)install()},ms))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();window.__LTS_TOP_CANDIDATE_VERSION='v172-v171-review';
})();


;
;
/* LTS V384: lts-v183-v173-feedback-safe.js */
(function(){
  'use strict';
  const outer=document.getElementById('shell'),gate=document.getElementById('gate'),scope=document.getElementById('scope');
  let generation=0;

  function runtime(){
    'use strict';
    if(window.__LTS_V173_V172_FEEDBACK?.installed||!window.__LTS_V172_V171_REVIEW?.installed)return;
    const baseRender=render,baseNav=renderNav,v168=window.__LTS_V168_STATE;
    const norm=value=>String(value??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim().replace(/\s+/g,' ');
    const esc=value=>String(value??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
    const canonicalAliases=new Map([
      ['imagem e cuidados pessoais','Vestuário'],
      ['assinatura','Assinaturas'],['benjamin - educacao','Educação'],['pet','Rafiki'],
      ['benjamin - saude','Saúde'],['larissa - saude','Saúde'],['benjamin - vestuario','Vestuário'],
      ['viagem','Viagens'],['financiamento veiculo','Financiamento veículo']
    ]);
    const seed=[
      'Alimentação e Bebidas','Aluguel Carro','Amazon','Anuidade','Apple','Armazenamento','Assinaturas',
      'Bebidas','Benjamin - Aulas complementares','Benjamin - Brinquedos e presentes',
      'Benjamin - Estrutura e manutenção','Benjamin - Presentes','Benjamin - Batizado',
      'Cabelereiro','Carro','Casa - Utensílios e equipamentos','Casamento','Combustível','Cursos',
      'Desenvolvimento','Duty free','Educação','Empréstimos','Energia','Estacionamento E Pedágio',
      'Eventos','Família','Farmácia','Financiamento Imobiliário','Financiamento veículo','Hotel',
      'Ifood','Impostos','Impostos do Imóvel','Investimento Imobiliário','Investimentos','Lavanderia',
      'Lazer','Mercado','Mercado Livre','Moradia','Móveis e Decoração','Obra e Reforma',
      'Organon Despesas','Outros','Passeios','Presentes','Rafiki','Reembolso Organon',
      'Reembolso plano de saúde','Reembolsos','Rendimentos financeiros','Restaurantes',
      'Restaurantes e Lazer','Salário','Saque / Dinheiro','Saúde','Seguros','Seguros - Vida',
      'Serviços Administrativos','Sócio Rei','Spotify','Supermercado','Tarifas Bancárias',
      'Tarifas e Juros','Táxi/Uber','Telefone','Transferência própria','Veículos - Aquisição',
      'Veículos - Estacionamento','Veículos - Manutenção','Veículos - Multas','Veículos - Tributos',
      'Vestuário','Viagens','Volvo XC40'
    ];

    function canonical(value){
      const raw=String(value||'').trim();if(!raw||norm(raw)==='a classificar')return'';
      return canonicalAliases.get(norm(raw))||raw;
    }
    function categoryOptions(){
      const map=new Map(),add=value=>{const label=canonical(value),key=norm(label);if(key&&!map.has(key))map.set(key,label)};
      seed.forEach(add);
      for(const data of [v168?.dashboard?.data?.expense,v168?.expense?.data]){
        for(const group of Array.isArray(data?.management_groups)?data.management_groups:[]){
          for(const source of Array.isArray(group.source_categories)?group.source_categories:[])add(source?.name);
        }
      }
      for(const row of Array.isArray(v168?.transactions?.rows)?v168.transactions.rows:[])add(row?.category);
      return [...map.values()].sort((a,b)=>a.localeCompare(b,'pt-BR',{sensitivity:'base'}));
    }
    function mentionedCategory(phrase,options){
      const n=norm(phrase).replace(/\bimagem e cuidados pessoais\b/g,'vestuario'),ordered=options.map(x=>({label:x,key:norm(x)})).filter(x=>x.key.length>=4).sort((a,b)=>b.key.length-a.key.length);
      const marker=n.match(/(?:classificad[oa]\s+como|categoria)\s+(.+?)(?:\s+em\s+\d{1,2}[\/-]|\s+no\s+dia\s+\d{1,2}|$)/);
      if(marker){
        const target=norm(marker[1]);
        const exact=ordered.find(x=>target===x.key||target.startsWith(x.key+' '));if(exact)return exact.label;
      }
      const direct=ordered.find(x=>n===x.key||n.includes(' '+x.key+' ')||n.endsWith(' '+x.key)||n.startsWith(x.key+' '));
      if(direct)return direct.label;
      if(/\bfamilia\b/.test(n))return options.find(x=>norm(x)==='familia')||'Família';
      return'';
    }
    function decorateNatural(){
      const field=document.getElementById('v168NlCategory');if(!field)return;
      const options=categoryOptions(),phrase=document.getElementById('v168NlPhrase')?.value||v168?.nl?.draft||'',existing=canonical(field.value),inferred=mentionedCategory(phrase,options),selected=inferred||existing;
      if(field.tagName!=='SELECT'){
        const select=document.createElement('select');select.id='v168NlCategory';select.className=(field.className?field.className+' ':'')+'v173-category-select';select.setAttribute('aria-label','Categoria');
        select.innerHTML='<option value="">Selecione uma categoria</option>'+options.map(label=>'<option value="'+esc(label)+'">'+esc(window.LTSCategoryDisplay.category(label))+'</option>').join('');
        field.replaceWith(select);
        if(selected&&options.some(label=>norm(label)===norm(selected)))select.value=options.find(label=>norm(label)===norm(selected));
        select.addEventListener('change',()=>{if(v168?.nl?.preview)v168.nl.preview.category=select.value||'A classificar'});
        if(inferred&&v168?.nl?.preview){v168.nl.preview.category=inferred;v168.nl.preview.missing=(Array.isArray(v168.nl.preview.missing)?v168.nl.preview.missing:[]).filter(x=>norm(x)!=='categoria')}
        const label=select.closest('label');if(label&&!label.querySelector('.v173-category-hint')){const hint=document.createElement('small');hint.className='v173-category-hint';hint.textContent=inferred?'Interpretado da descrição; você pode alterar.':'Escolha uma categoria existente.';label.appendChild(hint)}
      }else if(inferred&&options.some(label=>norm(label)===norm(inferred))){
        field.value=options.find(label=>norm(label)===norm(inferred));if(v168?.nl?.preview)v168.nl.preview.category=field.value;
      }
    }
    function childName(node){return node.querySelector('span')?.textContent?.trim()||''}
    function setChildName(node,value){const span=node.querySelector('span');if(span)span.textContent=value}
    function decorateCompositions(){
      const root=document.querySelector('.v172-categories');if(!root)return;
      for(const row of root.querySelectorAll('.v172-rankrow')){
        const parent=row.querySelector(':scope > div > b')?.textContent?.trim()||'',p=norm(parent),details=row.querySelector('details');if(!details)continue;
        const children=[...details.querySelectorAll('em')];
        for(const child of children){
          const name=norm(childName(child));
          if(p==='financiamento de veiculo'&&(name==='nao identificado'||name==='veiculo nao atribuido'))setChildName(child,'Volvo XC40');
        }
        const names=[...details.querySelectorAll('em')].map(child=>norm(childName(child))).filter(Boolean),unique=[...new Set(names.filter(name=>name!==p))];
        const realEstateNames=['financiamento imobiliario — casa','financiamento imobiliario - casa','casa','financiamento imobiliario — cipo 396','financiamento imobiliario - cipo 396','cipo 396'];
        const sameRealEstateChain=p==='financiamento imobiliario'&&unique.length>0&&unique.every(name=>realEstateNames.includes(name));
        if(unique.length<=1||sameRealEstateChain)details.remove();
      }
    }
    function stamp(){const badge=window.parent?.document?.getElementById('scope');if(badge)badge.dataset.v173Route=V==='Fluxo Diário'?'Fluxo de caixa':V}
    function after(){stamp();decorateNatural();decorateCompositions()}
    render=function(){const out=baseRender();after();return out};
    renderNav=function(){const out=baseNav();stamp();return out};
    const observer=new MutationObserver(()=>queueMicrotask(after));observer.observe(document.body,{childList:true,subtree:true});
    window.__LTS_V173_V172_FEEDBACK={installed:true,version:'v173',base_version:'v172',public_index_changed:false,category_select:true,canonical_category_inference:true,redundant_composition_suppressed:true,vehicle_financing_identity:'Volvo XC40',real_estate_financing_single_chain:true};
    if(typeof D!=='undefined'&&D&&typeof N!=='undefined'&&!N.classList.contains('hidden'))render();
  }

  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return null;return{w,d}}catch{return null}}
  function install(){
    const f=frame();if(!f||!f.w.__LTS_V172_V171_REVIEW?.installed)return false;
    if(!f.d.getElementById('lts-v173-style')){const link=f.d.createElement('link');link.id='lts-v173-style';link.rel='stylesheet';link.href='lts-v173-v172-feedback.css?v=20260918-v173a';f.d.head.appendChild(link)}
    if(!f.w.__LTS_V173_V172_FEEDBACK?.installed&&!f.d.getElementById('lts-v173-runtime')){const script=f.d.createElement('script');script.id='lts-v173-runtime';script.textContent='('+runtime.toString()+')();';f.d.head.appendChild(script)}
    const ready=f.w.__LTS_V173_V172_FEEDBACK?.installed===true;if(ready&&gate)gate.remove();return ready;
  }
  function burst(){const current=++generation;let attempt=0;function step(){if(current!==generation)return;const ready=install();attempt++;if(!ready&&attempt<320)setTimeout(step,100)}step();[400,900,1800,3600,7000,12000,20000,30000].forEach(ms=>setTimeout(()=>{if(current===generation)install()},ms))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();window.__LTS_TOP_CANDIDATE_VERSION='v173-v172-feedback';
})();

;
;
/* LTS V384: lts-v174-v173-review.js */
(function(){
  'use strict';
  const outer=document.getElementById('shell'),gate=document.getElementById('gate'),scope=document.getElementById('scope');
  let generation=0;

  function runtime(){
    'use strict';
    if(window.__LTS_V174_V173_REVIEW?.installed||!window.__LTS_V173_V172_FEEDBACK?.installed)return;
    const baseRender=render,baseNav=renderNav,baseDashboard=dashboard,baseExpenses=despesas;
    const v168=window.__LTS_V168_STATE,v169=window.__LTS_V169_STATE,v171=window.__LTS_V171_STATE||{};
    const state=window.__LTS_V174_STATE||(window.__LTS_V174_STATE={
      monthlyWarning:'',monthlyChunkCalls:0,cardFlow:null,cardFlowLoading:false,cardFlowError:'',cardFlowSeq:0
    });
    const previousRpc=S.rpc.bind(S);

    const arr=v=>Array.isArray(v)?v:[],num=v=>v===null||v===undefined||v===''?null:(Number.isFinite(Number(v))?Number(v):null);
    const sum=xs=>arr(xs).reduce((s,x)=>s+(num(x)||0),0);
    const esc=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
    const norm=s=>String(s??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim().replace(/\s+/g,' ');
    const money=v=>num(v)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(v));
    const month=v=>{const k=String(v||'').slice(0,7);return /^\d{4}-\d{2}$/.test(k)?new Intl.DateTimeFormat('pt-BR',{month:'short',year:'2-digit'}).format(new Date(k+'-01T12:00:00Z')).replace('.',''):k||'—'};
    const date=v=>{const p=String(v||'').slice(0,10).split('-');return p.length===3?p.reverse().join('/'):'—'};
    const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
    const tpl=html=>{const t=document.createElement('template');t.innerHTML=html;return t};

    async function directRpc(name,args){
      try{
        const auth=await S.auth.getSession(),token=auth?.data?.session?.access_token||K;
        const response=await fetch(U+'/rest/v1/rpc/'+encodeURIComponent(name),{
          method:'POST',
          headers:{apikey:K,Authorization:'Bearer '+token,'Content-Type':'application/json',Accept:'application/json'},
          body:JSON.stringify(args||{})
        });
        const payload=await response.json().catch(()=>null);
        if(!response.ok)return{data:null,error:{message:String(payload?.message||payload?.error_description||('HTTP '+response.status)),status:response.status}};
        return{data:payload,error:null};
      }catch(error){return{data:null,error:{message:String(error?.message||error)}}}
    }

    function professionalName(value){
      const x=norm(value);
      if(x==='emprestimos e consignado')return'Empréstimos';
      if(x==='familia — saidas'||x==='familia - saidas')return'Família — saídas';
      if(x==='venda de bens e ativos')return'Venda de ações, RSUs e outros ativos';
      if(x==='compras de cartao ainda sem categoria'||x==='faturas historicas sem compras individualizadas')return'Faturas conciliadas pelo total';
      if(x==='mercado')return'Mercado';
      if(x==='presentes')return'Presentes';
      if(x==='amazon')return'Amazon';
      if(x==='viagem')return'Viagens';
      return String(value||'Outros');
    }
    function subgroupName(group,value){
      const g=professionalName(group),x=String(value||'').trim(),n=norm(x);
      if(g==='Empréstimos'&&n.includes('itau'))return'Histórico pago · Itaú';
      if(g==='Empréstimos'&&n.includes('coopharma'))return'Empréstimo consignado · Coopharma';
      if(g==='Empréstimos'&&n.includes('pai'))return'Empréstimo familiar · Pai e Mãe';
      if(g==='Financiamento de veículo'&&(n==='nao identificado'||n==='veiculo nao atribuido'))return'Volvo XC40';
      return professionalName(x);
    }
    function usefulSubgroups(group,rows){
      const seen=new Map();
      for(const row of arr(rows)){
        const name=subgroupName(group,row.name),key=norm(name),parent=norm(professionalName(group));
        if(!key||key===parent)continue;
        const cur=seen.get(key)||{name,total:0,rows:0};
        cur.total+=(num(row.total)||0);cur.rows+=(num(row.rows)||0);seen.set(key,cur);
      }
      const values=[...seen.values()].sort((a,b)=>b.total-a.total);
      if(professionalName(group)==='Financiamento imobiliário'){
        const allowed=new Set(['casa','cipo 396','financiamento imobiliario — casa','financiamento imobiliario - casa','financiamento imobiliario — cipo 396','financiamento imobiliario - cipo 396']);
        if(values.length&&values.every(x=>allowed.has(norm(x.name))))return[];
      }
      return values;
    }

    function propertyReconciliation(data){return data?.property_improvement_reconciliation||{}}
    function displayGroups(data){
      const prop=propertyReconciliation(data),hasProp=num(prop.reconciled_unique_brl)!=null;
      return arr(data?.management_groups).map(group=>{
        const name=professionalName(group.name);
        const row={...group,name,subgroups:usefulSubgroups(name,group.subgroups)};
        if(name==='Investimentos no imóvel — obra e reforma'&&hasProp){
          row.dated_total=num(group.total)||0;
          row.total=num(prop.reconciled_unique_brl);
          row.source_reconciled=true;
        }
        return row;
      }).sort((a,b)=>(num(b.total)||0)-(num(a.total)||0));
    }
    function rank(groups,limit=99,details=true){
      const xs=arr(groups).filter(x=>num(x.total)!=null).slice(0,limit),top=Math.max(1,...xs.map(x=>Math.abs(num(x.total)||0)));
      return '<div class="v174-rank">'+(xs.map((row,index)=>{
        const children=usefulSubgroups(row.name,row.subgroups);
        return '<div class="v174-rankrow"><span>'+(index+1)+'</span><div><b>'+esc(professionalName(row.name))+'</b>'+(row.source_reconciled?'<small class="v174-source-badge">fonte reconciliada</small>':'')+'<i><u style="width:'+Math.max(2,Math.abs(num(row.total)||0)/top*100)+'%"></u></i>'+(details&&children.length>1?'<details><summary>Ver composição</summary>'+children.map(child=>'<em><span>'+esc(child.name)+'</span><b>'+money(child.total)+'</b></em>').join('')+'</details>':'')+'</div><strong>'+money(row.total)+'</strong></div>';
      }).join('')||'<div class="v168-empty">Sem despesas no período selecionado.</div>')+'</div>';
    }
    function coverageNote(data){
      const c=data?.coverage_disclosure||{},count=num(c.rows)||0;
      return (num(c.total)||0)>0?'<div class="v172-coverage"><b>Faturas conciliadas pelo total</b><strong>'+money(c.total)+'</strong><span>Esse valor já está no total de despesas. Em '+count+' ciclo(s), a fonte preserva a fatura, mas não todas as compras necessárias para uma divisão confiável por categoria.</span></div>':'';
    }
    function propertyNote(data){
      const p=propertyReconciliation(data);if(num(p.reconciled_unique_brl)==null)return'';
      return '<div class="v174-property-note"><div><span>Planilha original · Reformas e melhorias</span><b>'+money(p.workbook_summary_brl)+'</b></div><div><span>Duplicidade confirmada na fonte · Móveis</span><b>− '+money(p.duplicate_source_brl)+'</b></div><div class="primary"><span>Reformas e melhorias · reconciliado</span><b>'+money(p.reconciled_unique_brl)+'</b></div><p>O valor reconciliado conta a saída econômica uma única vez. '+money(p.historical_card_coverage_gap_brl)+' permanecem documentados em agregados históricos de cartão sem data/compra individual suficiente para uma distribuição mensal inventada.</p></div>';
    }

    function monthSpan(from,to){const a=new Date(from+'T12:00:00Z'),b=new Date(to+'T12:00:00Z');return (b.getUTCFullYear()-a.getUTCFullYear())*12+b.getUTCMonth()-a.getUTCMonth()+1}
    function yearChunks(from,to){const out=[];let y=Number(from.slice(0,4)),last=Number(to.slice(0,4));for(;y<=last;y++)out.push({from:y===Number(from.slice(0,4))?from:y+'-01-01',to:y===last?to:y+'-12-31'});return out}
    async function mapLimitSettled(items,limit,worker){
      const out=new Array(items.length);let cursor=0;
      async function run(){while(true){const i=cursor++;if(i>=items.length)return;try{out[i]={status:'fulfilled',value:await worker(items[i],i)}}catch(reason){out[i]={status:'rejected',reason}}}}
      await Promise.all(Array.from({length:Math.min(limit,items.length)},run));return out;
    }
    function mergeGroups(parts,key,months){
      const groups=new Map();
      for(const part of parts)for(const row of arr(part[key])){
        const label=professionalName(row.label),id=norm(label),cur=groups.get(id)||{label,total:0,source_rows:0,values:new Map()};
        cur.total+=(num(row.total)||0);cur.source_rows+=(num(row.source_rows)||0);
        for(const item of arr(row.monthly)){const k=String(item.month).slice(0,10);cur.values.set(k,(cur.values.get(k)||0)+(num(item.amount)||0))}
        groups.set(id,cur);
      }
      return [...groups.values()].map(g=>({label:g.label,total:g.total,source_rows:g.source_rows,monthly:months.map(k=>({month:k,amount:g.values.get(k)||0}))})).sort((a,b)=>b.total-a.total);
    }
    function mergeMonthly(parts,from,to,failed){
      const months=parts.flatMap(x=>arr(x.months)).map(x=>String(x).slice(0,10)).filter((x,i,a)=>a.indexOf(x)===i).sort();
      const monthlyTotals=parts.flatMap(x=>arr(x.monthly_totals)).sort((a,b)=>String(a.month).localeCompare(String(b.month)));
      const totals=['revenue','expenses','operating_balance','extraordinary','cash_after_extraordinary'].reduce((o,k)=>(o[k]=sum(parts.map(x=>x.totals?.[k])),o),{});
      const covMap=new Map();let covTotal=0,covRows=0;
      for(const part of parts){const c=part.expense_unclassified_card_coverage||{};covTotal+=(num(c.total)||0);covRows+=(num(c.source_rows)||0);for(const m of arr(c.monthly)){const k=String(m.month).slice(0,10);covMap.set(k,(covMap.get(k)||0)+(num(m.amount)||0))}}
      const saleMap=new Map();let saleTotal=0;
      for(const part of parts){const s=part.stock_sale_supplement||{};saleTotal+=(num(s.total)||0);for(const m of arr(s.monthly)){const k=String(m.month).slice(0,10);saleMap.set(k,(saleMap.get(k)||0)+(num(m.amount)||0))}}
      return{
        ...parts[0],version:'monthly-balance-v4-v174-resilient-chunked',from,to,months,monthly_totals,totals,
        revenue_groups:mergeGroups(parts,'revenue_groups',months),
        extraordinary_groups:mergeGroups(parts,'extraordinary_groups',months),
        expense_groups:mergeGroups(parts,'expense_groups',months),
        expense_unclassified_card_coverage:{label:'Faturas conciliadas pelo total',total:covTotal,source_rows:covRows,monthly:months.map(k=>({month:k,amount:covMap.get(k)||0}))},
        stock_sale_supplement:{total:saleTotal,monthly:months.map(k=>({month:k,amount:saleMap.get(k)||0}))},
        partial_year_failures:failed||[]
      };
    }
    const addMonths=(iso,delta)=>{const d=new Date(iso+'T12:00:00Z'),day=d.getUTCDate();d.setUTCDate(1);d.setUTCMonth(d.getUTCMonth()+delta);const last=new Date(Date.UTC(d.getUTCFullYear(),d.getUTCMonth()+1,0)).getUTCDate();d.setUTCDate(Math.min(day,last));return d.toISOString().slice(0,10)};
    function expenseRange174(){
      const s=v168?.expense||{},t=today(),year=t.slice(0,4),key=s.key;
      if(key==='6m')return{from:addMonths(t,-5).slice(0,8)+'01',to:t};
      if(key==='12m')return{from:addMonths(t,-11).slice(0,8)+'01',to:t};
      if(key==='all')return{from:'2013-10-10',to:t};
      if(key==='custom'&&/^\\d{4}-\\d{2}-\\d{2}$/.test(s.customFrom||'')&&/^\\d{4}-\\d{2}-\\d{2}$/.test(s.customTo||''))return{from:s.customFrom,to:s.customTo};
      return{from:year+'-01-01',to:t};
    }
    async function monthlyV174Rpc(args){
      const from=args?.p_from,to=args?.p_to;state.monthlyWarning='';state.monthlyChunkCalls=1;
      if(!/^\d{4}-\d{2}-\d{2}$/.test(from||'')||!/^\d{4}-\d{2}-\d{2}$/.test(to||''))return directRpc('lts_browser_monthly_balance_v3',args||{});
      const direct=await directRpc('lts_browser_monthly_balance_v3',{p_from:from,p_to:to});
      if(!direct?.error&&direct?.data)return{data:{...direct.data,version:'monthly-balance-v4-v174-direct'},error:null};
      if(monthSpan(from,to)<=18)return direct;
      const chunks=yearChunks(from,to);state.monthlyChunkCalls=chunks.length;
      const settled=await mapLimitSettled(chunks,3,async chunk=>{
        const r=await directRpc('lts_browser_monthly_balance_v3',{p_from:chunk.from,p_to:chunk.to});
        if(r?.error||!r?.data)throw Error(r?.error?.message||'Balanço anual indisponível');
        return{chunk,data:r.data};
      });
      const good=settled.filter(x=>x.status==='fulfilled').map(x=>x.value.data),failed=settled.map((x,i)=>x.status==='rejected'?chunks[i]:null).filter(Boolean);
      if(!good.length)return{data:null,error:{message:direct?.error?.message||'Balanço mensal indisponível para o período selecionado.'}};
      if(failed.length)state.monthlyWarning='Alguns anos não responderam. O LTS manteve os anos carregados e não apagou o relatório: '+failed.map(x=>x.from.slice(0,4)).join(', ')+'.';
      return{data:mergeMonthly(good,from,to,failed),error:null};
    }

    S.rpc=async function(name,args){
      const requested=String(name||''),next={...(args||{})};
      if(requested==='lts_browser_expense_executive_v6')return previousRpc('lts_browser_expense_executive_v7',next);
      if(requested==='lts_browser_monthly_balance_v1'||requested==='lts_browser_monthly_balance_v2'||requested==='lts_browser_monthly_balance_v3')return monthlyV174Rpc(next);
      return previousRpc(requested,next);
    };

    function coverageByMonth(j){const m=new Map();for(const row of arr(j?.expense_unclassified_card_coverage?.monthly))m.set(String(row.month).slice(0,10),num(row.amount)||0);return m}
    function matrix(title,subtitle,groups,months,expense,j){
      const cov=coverageByMonth(j);
      return '<article class="v169-balance-section"><div class="v168-cardhead"><div><span>'+esc(subtitle)+'</span><h2>'+esc(title)+'</h2></div><small>'+groups.length+' grupo(s)</small></div><div class="v169-matrix-wrap"><table class="v169-matrix v174-matrix"><thead><tr><th>Grupo</th>'+months.map(x=>'<th>'+esc(month(x))+'</th>').join('')+'<th>Total</th></tr></thead><tbody>'+(groups.map(group=>'<tr><th>'+esc(professionalName(group.label))+'</th>'+months.map(k=>{const item=arr(group.monthly).find(x=>String(x.month).slice(0,10)===String(k).slice(0,10)),amount=num(item?.amount)||0,unknown=expense&&amount===0&&(cov.get(String(k).slice(0,10))||0)>0;return'<td class="'+(unknown?'v174-unknown':'')+'">'+(amount?money(amount):unknown?'—*':'—')+'</td>'}).join('')+'<td class="total">'+money(group.total)+'</td></tr>').join('')||'<tr><td colspan="'+(months.length+2)+'" class="v168-empty">Sem valores neste período.</td></tr>')+'</tbody></table></div></article>';
    }
    function monthlyPanel(){
      const j=v169?.monthly?.data||{},tot=j.totals||{},rows=arr(j.monthly_totals),months=arr(j.months),cover=j.expense_unclassified_card_coverage||{},sales=j.stock_sale_supplement||{};
      if(v169?.monthly?.loading&&!v169.monthly.data)return'<div class="v168-skeleton"></div>';
      if(v169?.monthly?.error&&!v169.monthly.data)return'<div class="v168-error">'+esc(v169.monthly.error)+'</div>';
      return '<div class="v169-monthly v174-monthly">'+(state.monthlyWarning?'<div class="v174-warning">'+esc(state.monthlyWarning)+'</div>':'')+
        '<div class="v168-kpis"><article class="v168-kpi primary"><span>Receitas operacionais</span><strong>'+money(tot.revenue)+'</strong><small>entradas recorrentes</small></article><article class="v168-kpi v171-expense-total"><span>Despesas com competência conhecida</span><strong>'+money(tot.expenses)+'</strong><small>cartões + contas sem dupla contagem</small></article><article class="v168-kpi"><span>Resultado operacional</span><strong>'+money(tot.operating_balance)+'</strong><small>receitas menos despesas</small></article><article class="v168-kpi"><span>Entradas extraordinárias</span><strong>'+money(tot.extraordinary)+'</strong><small>inclui venda de ações comprovada</small></article><article class="v168-kpi"><span>Resultado final</span><strong>'+money(tot.cash_after_extraordinary)+'</strong><small>após entradas extraordinárias</small></article></div>'+
        ((num(sales.total)||0)>0?'<div class="v174-audit-strip"><span>Venda de ações recuperada no período</span><b>'+money(sales.total)+'</b><small>Venda/realização é receita extraordinária; transferência posterior C6 → Itaú/Bradesco continua neutra.</small></div>':'')+
        matrix('Receitas operacionais','Receitas',arr(j.revenue_groups),months,false,j)+
        matrix('Entradas extraordinárias','Entradas não recorrentes',arr(j.extraordinary_groups),months,false,j)+
        matrix('Despesas por categoria','Despesas',arr(j.expense_groups),months,true,j)+
        ((num(cover.total)||0)>0?'<div class="v174-coverage"><b>—* não significa despesa zero</b><span>O mês tem '+money(cover.total)+' de cobertura agregada de cartão ao longo da seleção. Quando a compra individual não existe na fonte, o LTS não inventa Restaurante, iFood, Rafiki ou outra categoria.</span></div>':'')+
        '<article class="v169-balance-section"><div class="v168-cardhead"><div><span>Fechamento</span><h2>Resultado de cada mês</h2></div><small>'+months.length+' mês(es)</small></div><div class="v169-matrix-wrap"><table class="v169-matrix compact"><thead><tr><th>Mês</th><th>Receitas</th><th>Despesas</th><th>Resultado operacional</th><th>Extraordinárias</th><th>Resultado final</th></tr></thead><tbody>'+rows.map(row=>'<tr><th>'+month(row.month)+'</th><td>'+money(row.revenue)+'</td><td>'+money(row.expenses)+'</td><td class="'+((num(row.operating_balance)||0)<0?'negative':'positive')+'">'+money(row.operating_balance)+'</td><td>'+money(row.extraordinary)+'</td><td class="'+((num(row.cash_after_extraordinary)||0)<0?'negative':'positive')+'">'+money(row.cash_after_extraordinary)+'</td></tr>').join('')+'</tbody></table></div></article></div>';
    }

    function cardBank(name){const n=norm(name);if(n.includes('aeternum')||n.includes('bradesco'))return'Bradesco';if(n.includes('c6')||n.includes('carbon')||n.includes('7873')||n.includes('8304'))return'C6';if(n.includes('personnalite')||n.includes('mastercard')||n.includes('itau'))return'Itaú';return'Outros'}
    function cardKey(name){const n=norm(name);if(n.includes('aeternum'))return'aeternum';if(n.includes('c6')||n.includes('carbon')||n.includes('7873')||n.includes('8304'))return'c6';if(n.includes('personnalite')||n.includes('5546')||n.includes('mastercard'))return'personnalite';if(n.includes('visa infinite prime'))return'visa-infinite-prime';return n.replace(/\W+/g,'-')}
    async function ensureCardFlow(force=false){
      if(state.cardFlowLoading||(!force&&state.cardFlow))return;
      const seq=++state.cardFlowSeq;state.cardFlowLoading=true;state.cardFlowError='';
      const from=today(),to=String(Number(from.slice(0,4))+1)+'-12-31';
      try{const r=await directRpc('lts_browser_card_flow_schedule_v1',{p_from:from,p_to:to});if(r?.error||!r?.data)throw Error(r?.error?.message||'Fluxo de cartões indisponível');if(seq===state.cardFlowSeq)state.cardFlow=r.data}
      catch(e){if(seq===state.cardFlowSeq)state.cardFlowError=String(e?.message||e)}
      finally{if(seq===state.cardFlowSeq){state.cardFlowLoading=false;if(V==='Despesas'&&v168?.expense?.tab==='cards')render()}}
    }
    function cardsPanel(){
      const o=D?.card_operating||{},map=new Map(),ensure=(b,c,m)=>{const k=[b,cardKey(c),m].join('|');if(!map.has(k))map.set(k,{bank:b,card:c,month:m,invoices:[],installments:[],flows:[]});return map.get(k)};
      for(const x of [...arr(o.open_cycles),...arr(o.closed_or_due)]){const c=x.card_name||x.description||'Cartão não identificado',m=String(x.due_date||'').slice(0,7);if(m)ensure(cardBank(c),c,m).invoices.push(x)}
      for(const m of arr(o.contracted_installment_floor_months))for(const x of arr(m.detail)){const c=x.card_name||'Cartão não identificado';ensure(cardBank(c),c,String(m.reference_month).slice(0,7)).installments.push(x)}
      for(const x of arr(state.cardFlow?.events)){const c=x.card_name||x.description||'Cartão não identificado',m=String(x.event_date||'').slice(0,7),b=cardBank(c);if(m)ensure(b,c,m).flows.push(x)}
      const filter=v171.cardBank||'Todos',all=[...map.values()].filter(x=>x.month>=today().slice(0,7)).sort((a,b)=>a.bank.localeCompare(b.bank)||cardKey(a.card).localeCompare(cardKey(b.card))||a.month.localeCompare(b.month)),banks=['Todos',...new Set(all.map(x=>x.bank))],visible=all.filter(x=>filter==='Todos'||x.bank===filter),groups=new Map();
      for(const x of visible){const k=x.bank+'|'+cardKey(x.card);if(!groups.has(k))groups.set(k,{bank:x.bank,card:x.card,rows:[]});groups.get(k).rows.push(x)}
      return '<div class="v174-cards"><div class="v169-bank-filter">'+banks.map(x=>'<button class="v168-btn '+(filter===x?'primary':'')+'" data-v174-card-bank="'+esc(x)+'">'+esc(x)+'</button>').join('')+'</div>'+
        (state.cardFlowLoading?'<div class="v174-warning">Conferindo os valores efetivamente usados no Fluxo…</div>':'')+
        (state.cardFlowError?'<div class="v174-warning">Não foi possível atualizar o comparativo com o Fluxo agora: '+esc(state.cardFlowError)+'</div>':'')+
        '<article class="v168-card"><div class="v168-cardhead"><div><span>Conferência bancária</span><h2>Fatura, piso contratado e valor do Fluxo</h2></div><small>mês a mês</small></div>'+
        ([...groups.values()].map(g=>'<section class="v171-cardgroup"><header><span>'+esc(g.bank)+'</span><h3>'+esc(g.card)+'</h3></header><div class="v171-cardmonths">'+g.rows.map(x=>{const invoice=sum(x.invoices.map(y=>y.amount)),floor=sum(x.installments.map(y=>y.amount)),flow=sum(x.flows.map(y=>y.amount)),used=x.flows.length?flow:x.invoices.length?invoice:floor,diff=x.flows.length&&floor?flow-floor:null;return'<div><b>'+month(x.month)+'</b><dl><dt>Fatura conhecida</dt><dd>'+money(invoice)+'</dd><dt>Parcelas já contratadas</dt><dd>'+money(floor)+'</dd><dt>Valor no Fluxo</dt><dd><strong>'+(x.flows.length?money(flow):'—')+'</strong></dd><dt>Considerado</dt><dd><strong>'+money(used)+'</strong></dd>'+(diff!=null?'<dt>Fluxo × piso</dt><dd>'+money(diff)+'</dd>':'')+'</dl></div>'}).join('')+'</div></section>').join('')||'<div class="v168-empty">Nenhuma fatura futura documentada neste filtro.</div>')+
        '</article><div class="v171-reconciliation"><b>Leitura corrigida</b><span>“Parcelas já contratadas” é apenas um piso. “Valor no Fluxo” mostra o compromisso/projeção realmente usado no caixa; quando existe fatura observada ela prevalece.</span></div></div>';
    }

    function expensesV174(){
      const t=tpl(baseExpenses()),root=t.content.querySelector('.v168-expenses'),data=v168?.expense?.data||{},tabs=root?.querySelector('.v168-tabs');if(!root||!tabs)return t.innerHTML;
      if(v168.expense.tab==='overview'&&displayGroups(data).length){
        const card=[...root.querySelectorAll('.v168-card')].find(x=>/maiores grupos/i.test(x.querySelector('h2')?.textContent||''));
        if(card){card.querySelectorAll('.v168-rank,.v169-coverage,.v170-rank,.v170-audit,.v171-rank,.v171-reconciliation,.v172-rank,.v172-coverage').forEach(x=>x.remove());card.insertAdjacentHTML('beforeend',rank(displayGroups(data),15,false)+coverageNote(data)+propertyNote(data))}
      }
      if(v168.expense.tab==='categories'&&displayGroups(data).length){
        let node=tabs.nextSibling;while(node){const next=node.nextSibling;node.remove();node=next}
        tabs.insertAdjacentHTML('afterend','<article class="v168-card v174-categories"><div class="v168-cardhead"><div><span>Composição auditada</span><h2>Despesas por categoria</h2></div><small>Total com data/competência: '+money(data.summary?.selected_total)+'</small></div>'+rank(displayGroups(data),99,true)+propertyNote(data)+coverageNote(data)+'</article>');
      }
      if(v168.expense.tab==='monthly'){
        const old=root.querySelector('.v171-monthly,.v172-monthly,.v169-monthly,.v168-skeleton,.v168-error');if(old){const h=tpl(monthlyPanel());old.replaceWith(...h.content.childNodes)}
      }
      if(v168.expense.tab==='cards'){
        const old=root.querySelector('.v171-cards,.v169-cards,.v174-cards');if(old){const h=tpl(cardsPanel());old.replaceWith(...h.content.childNodes)}
      }
      return t.innerHTML;
    }

    function dashboardV174(){
      const t=tpl(baseDashboard()),root=t.content.querySelector('.v168-dashboard'),data=v168?.dashboard?.data?.expense||{};if(!root)return t.innerHTML;
      const card=[...root.querySelectorAll('.v168-card')].find(x=>/principais grupos/i.test(x.querySelector('h2')?.textContent||''));
      if(card&&displayGroups(data).length){card.querySelectorAll('.v171-rank,.v172-rank,.v174-rank,.v171-reconciliation,.v172-coverage').forEach(x=>x.remove());card.insertAdjacentHTML('beforeend',rank(displayGroups(data),12,false)+coverageNote(data))}
      return t.innerHTML;
    }

    function after(){
      const badge=window.parent?.document?.getElementById('scope');if(badge)badge.dataset.v174Route=V==='Fluxo Diário'?'Fluxo de caixa':V;
      document.querySelectorAll('[data-v174-card-bank]').forEach(b=>b.onclick=()=>{v171.cardBank=b.dataset.v174CardBank;render()});
      if(V==='Despesas'&&v168?.expense?.tab==='cards'&&!state.cardFlow&&!state.cardFlowLoading)queueMicrotask(()=>ensureCardFlow(false));
    }

    dashboard=dashboardV174;despesas=expensesV174;
    render=function(){const out=baseRender();after();return out};
    renderNav=function(){const out=baseNav();after();return out};

    if(v168){v168.dashboard.data=null;v168.dashboard.started=false;v168.dashboard.loading=false;v168.expense.data=null;v168.expense.loading=false}
    if(v169){v169.monthly.token=(v169.monthly.token||0)+1;v169.monthly.data=null;v169.monthly.key='';v169.monthly.error=null;v169.monthly.loading=false}
    window.__LTS_V174_V173_REVIEW={
      installed:true,version:'v174',base_version:'v173',public_index_changed:false,
      deep_expense_audit:true,stock_sales_extraordinary_fixed:true,monthly_resilient_full_history:true,
      card_flow_precedence:true,property_source_reconciliation:true,family_outflows_explicit:true
    };
    if(D&&!N.classList.contains('hidden'))render();
  }

  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return null;return{w,d}}catch{return null}}
  function install(){
    const f=frame();if(!f||!f.w.__LTS_V173_V172_FEEDBACK?.installed)return false;
    if(!f.d.getElementById('lts-v174-style')){const link=f.d.createElement('link');link.id='lts-v174-style';link.rel='stylesheet';link.href='lts-v174-v173-review.css?v=20260918-v174a';f.d.head.appendChild(link)}
    if(!f.w.__LTS_V174_V173_REVIEW?.installed&&!f.d.getElementById('lts-v174-runtime')){const script=f.d.createElement('script');script.id='lts-v174-runtime';script.textContent='('+runtime.toString()+')();';f.d.head.appendChild(script)}
    const ready=f.w.__LTS_V174_V173_REVIEW?.installed===true;if(ready&&gate)gate.remove();return ready;
  }
  function burst(){const current=++generation;let attempt=0;function step(){if(current!==generation)return;const ready=install();attempt++;if(!ready&&attempt<320)setTimeout(step,100)}step();[400,900,1800,3600,7000,12000,20000,30000].forEach(ms=>setTimeout(()=>{if(current===generation)install()},ms))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();window.__LTS_TOP_CANDIDATE_VERSION='v174-v173-review';
})();
;
;
/* LTS V384: lts-v183-expense-history-candidate.js */
(function(){
  'use strict';
  const outer=document.getElementById('shell'),gate=document.getElementById('gate'),scope=document.getElementById('scope');
  let generation=0;

  function runtime(){
    'use strict';
    if(window.__LTS_V175_EXPENSE_AUDIT?.installed||!window.__LTS_V174_V173_REVIEW?.installed)return;

    const baseRender=render,baseNav=renderNav,baseDashboard=dashboard,baseExpenses=despesas;
    const v168=window.__LTS_V168_STATE,v169=window.__LTS_V169_STATE,v171=window.__LTS_V171_STATE||{};
    const state=window.__LTS_V175_STATE||(window.__LTS_V175_STATE={
      expense:{key:'',data:null,loading:false,error:null,token:0},
      monthly:{key:'',data:null,loading:false,error:null,token:0,mode:'',year:null,progress:''},
      cards:{data:null,loading:false,error:null,token:0,bank:'Todos'},
      lastRoute:null
    });
    const previousRpc=S.rpc.bind(S);

    const arr=v=>Array.isArray(v)?v:[];
    const num=v=>v===null||v===undefined||v===''?null:(Number.isFinite(Number(v))?Number(v):null);
    const sum=xs=>arr(xs).reduce((s,x)=>s+(num(x)||0),0);
    const esc=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
    const norm=s=>String(s??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim().replace(/\s+/g,' ');
    const brl=v=>num(v)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(v));
    const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
    const monthLabel=v=>{const k=String(v||'').slice(0,7);return /^\d{4}-\d{2}$/.test(k)?new Intl.DateTimeFormat('pt-BR',{month:'short',year:'2-digit'}).format(new Date(k+'-01T12:00:00Z')).replace('.',''):k||'—'};
    const yearOf=v=>String(v||'').slice(0,4);
    const tpl=html=>{const t=document.createElement('template');t.innerHTML=html;return t};
    const addMonths=(iso,delta)=>{const d=new Date(iso+'T12:00:00Z'),day=d.getUTCDate();d.setUTCDate(1);d.setUTCMonth(d.getUTCMonth()+delta);const last=new Date(Date.UTC(d.getUTCFullYear(),d.getUTCMonth()+1,0)).getUTCDate();d.setUTCDate(Math.min(day,last));return d.toISOString().slice(0,10)};

    function expenseRange(){
      const s=v168?.expense||{},t=today(),year=t.slice(0,4);
      if(s.key==='6m')return{from:addMonths(t,-5).slice(0,8)+'01',to:t,label:'6 meses'};
      if(s.key==='12m')return{from:addMonths(t,-11).slice(0,8)+'01',to:t,label:'12 meses'};
      if(s.key==='all')return{from:'2013-10-10',to:t,label:'Desde 2013'};
      if(s.key==='custom'&&/^\d{4}-\d{2}-\d{2}$/.test(s.customFrom||'')&&/^\d{4}-\d{2}-\d{2}$/.test(s.customTo||''))return{from:s.customFrom,to:s.customTo,label:'Personalizado'};
      return{from:year+'-01-01',to:t,label:'Ano atual'};
    }

    let expenseReadEpoch=0;
    const expenseReadGeneration=()=>typeof BOOT!=='undefined'?BOOT.generation:(typeof D!=='undefined'?D:null);
    let expenseReadOwner={generation:expenseReadGeneration(),epoch:expenseReadEpoch};
    function readSessionCurrent(owner){return !!owner&&owner.generation===expenseReadGeneration()&&owner.epoch===expenseReadEpoch&&!!D}
    function syncExpenseReaders(){
      if(expenseReadOwner.generation!==expenseReadGeneration()||expenseReadOwner.epoch!==expenseReadEpoch){
        expenseReadOwner={generation:expenseReadGeneration(),epoch:expenseReadEpoch};
        for(const key of ['expense','monthly','cards']){const s=state[key];if(!s)continue;s.token=(s.token||0)+1;s.loading=false;s.data=null;s.error=null;if(key!=='cards'){s.key='';s.rangeInvalid=false}if(key==='monthly'){s.progress='';s.mode=''}}
      }
      return expenseReadOwner;
    }
    S.auth.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT'||event==='SIGNED_IN')expenseReadEpoch++});

    async function directRpc(name,args,timeoutMs=18000){
      const owner={generation:expenseReadGeneration(),epoch:expenseReadEpoch};
      if(!readSessionCurrent(owner))return{data:null,error:{message:'Leitura substituída por outra sessão.'}};
      const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),timeoutMs);
      try{
        const auth=await S.auth.getSession();
        if(!readSessionCurrent(owner))return{data:null,error:{message:'Leitura substituída por outra sessão.'}};
        const token=auth?.data?.session?.access_token||K;
        const response=await fetch(U+'/rest/v1/rpc/'+encodeURIComponent(name),{
          method:'POST',
          headers:{apikey:K,Authorization:'Bearer '+token,'Content-Type':'application/json',Accept:'application/json'},
          body:JSON.stringify(args||{}),
          signal:controller.signal
        });
        const payload=await response.json().catch(()=>null);
        if(!readSessionCurrent(owner))return{data:null,error:{message:'Leitura substituída por outra sessão.'}};
        if(!response.ok)return{data:null,error:{message:String(payload?.message||payload?.error_description||('HTTP '+response.status)),status:response.status}};
        return{data:payload,error:null};
      }catch(error){
        return{data:null,error:{message:error?.name==='AbortError'?'Tempo de leitura excedido.':String(error?.message||error)}};
      }finally{clearTimeout(timer)}
    }

    function yearChunks(from,to){
      const out=[],first=Number(from.slice(0,4)),last=Number(to.slice(0,4));
      for(let y=first;y<=last;y++)out.push({from:y===first?from:y+'-01-01',to:y===last?to:y+'-12-31'});
      return out;
    }
    async function mapLimit(items,limit,worker){
      const out=new Array(items.length);let cursor=0;
      async function run(){while(true){const i=cursor++;if(i>=items.length)return;try{out[i]={ok:true,value:await worker(items[i],i)}}catch(error){out[i]={ok:false,error}}}}
      await Promise.all(Array.from({length:Math.min(limit,items.length)},run));return out;
    }
    function mergeGroups(parts,key,months){
      const map=new Map();
      for(const part of parts)for(const row of arr(part?.[key])){
        const label=String(row.label||row.name||'Outros'),id=norm(label),cur=map.get(id)||{label,total:0,source_rows:0,values:new Map()};
        cur.total+=(num(row.total)||0);cur.source_rows+=(num(row.source_rows??row.rows)||0);
        for(const item of arr(row.monthly)){const k=String(item.month).slice(0,10);cur.values.set(k,(cur.values.get(k)||0)+(num(item.amount)||0))}
        map.set(id,cur);
      }
      return [...map.values()].map(g=>({label:g.label,total:g.total,source_rows:g.source_rows,monthly:months.map(k=>({month:k,amount:g.values.get(k)||0}))})).sort((a,b)=>b.total-a.total);
    }
    function mergeMonthly(parts,from,to,failed){
      const months=parts.flatMap(x=>arr(x.months)).map(x=>String(x).slice(0,10)).filter((x,i,a)=>a.indexOf(x)===i).sort();
      const monthlyTotals=parts.flatMap(x=>arr(x.monthly_totals)).sort((a,b)=>String(a.month).localeCompare(String(b.month)));
      const totals=['revenue','expenses','operating_balance','extraordinary','cash_after_extraordinary'].reduce((o,k)=>(o[k]=sum(parts.map(x=>x?.totals?.[k])),o),{});
      const coverageMap=new Map();let coverageTotal=0,coverageRows=0;
      for(const part of parts){
        const c=part?.expense_unclassified_card_coverage||{};coverageTotal+=(num(c.total)||0);coverageRows+=(num(c.source_rows)||0);
        for(const m of arr(c.monthly)){const k=String(m.month).slice(0,10);coverageMap.set(k,(coverageMap.get(k)||0)+(num(m.amount)||0))}
      }
      const stockMap=new Map();let stockTotal=0;
      for(const part of parts){
        const s=part?.stock_sale_supplement||{};stockTotal+=(num(s.total)||0);
        for(const m of arr(s.monthly)){const k=String(m.month).slice(0,10),cur=stockMap.get(k)||{amount:0,source_rows:0};cur.amount+=(num(m.amount)||0);cur.source_rows+=(num(m.source_rows)||0);stockMap.set(k,cur)}
      }
      const sourceCoverage={};
      for(const part of parts)for(const [key,value] of Object.entries(part?.coverage||{}))if(typeof value==='number')sourceCoverage[key]=(sourceCoverage[key]||0)+value;
      const recurring=parts.map(x=>x?.recurring_gap_audit).filter(Boolean);
      const recurringItems=recurring.flatMap(x=>arr(x.items));
      const issues=new Map();
      for(const part of parts)for(const issue of arr(part?.open_audit_issues)){if(issue?.issue_id)issues.set(issue.issue_id,issue)}
      return{
        ...parts[0],version:'monthly-balance-v5-v183-complete-chunks',from,to,months,monthly_totals:monthlyTotals,totals,
        revenue_groups:mergeGroups(parts,'revenue_groups',months),
        extraordinary_groups:mergeGroups(parts,'extraordinary_groups',months),
        expense_groups:mergeGroups(parts,'expense_groups',months),
        expense_unclassified_card_coverage:{label:'Faturas conciliadas pelo total',total:coverageTotal,source_rows:coverageRows,monthly:months.map(k=>({month:k,amount:coverageMap.get(k)||0}))},
        stock_sale_supplement:{total:stockTotal,monthly:months.map(k=>({month:k,amount:stockMap.get(k)?.amount||0,source_rows:stockMap.get(k)?.source_rows||0}))},
        coverage:{...parts[0]?.coverage,...sourceCoverage},
        recurring_gap_audit:recurring.length?{...recurring.at(-1),from:recurring[0].from,to:recurring.at(-1).to,items:recurringItems,open_zero_count:sum(recurring.map(x=>x.open_zero_count))}:parts[0]?.recurring_gap_audit,
        open_audit_issues:[...issues.values()],
        partial_year_failures:failed
      };
    }

    function halfYearChunks(from,to){
      const out=[];
      for(let y=Number(from.slice(0,4));y<=Number(to.slice(0,4));y++)
        for(const [start,end] of [['01-01','06-30'],['07-01','12-31']]){
          const a=y+'-'+start,b=y+'-'+end,lo=a<from?from:a,hi=b>to?to:b;
          if(lo<=hi)out.push({from:lo,to:hi});
        }
      return out;
    }
    function monthsExpected(from,to){
      const out=[],date=new Date(from.slice(0,7)+'-01T12:00:00Z'),end=to.slice(0,7);
      while(date.toISOString().slice(0,7)<=end){out.push(date.toISOString().slice(0,10));date.setUTCMonth(date.getUTCMonth()+1)}
      return out;
    }
    function verifyPart(data,from,to){
      const actual=arr(data?.months).map(x=>String(x).slice(0,10)),expected=monthsExpected(from,to);
      if(actual.length!==expected.length||actual.some((value,i)=>value!==expected[i]))throw Error('Meses ausentes em '+from+' a '+to);
      if(arr(data?.monthly_totals).length!==expected.length)throw Error('Totais mensais ausentes em '+from+' a '+to);
      const expectedKeys=new Set(expected),seen=new Set();
      for(const row of arr(data.monthly_totals)){
        const key=String(row.month).slice(0,10);
        if(!expectedKeys.has(key)||seen.has(key))throw Error('Mês repetido ou fora do período em '+from+' a '+to);
        seen.add(key);
        for(const field of ['revenue','expenses','extraordinary'])if(num(row[field])===null)throw Error('Valor mensal ausente em '+from+' a '+to);
      }
      for(const key of ['revenue','expenses','extraordinary']){
        if(num(data?.totals?.[key])===null)throw Error('Total ausente em '+from+' a '+to);
        const monthly=sum(arr(data.monthly_totals).map(x=>x[key]));
        if(Math.abs(monthly-(num(data?.totals?.[key])||0))>0.05)throw Error('Total '+key+' divergente em '+from+' a '+to);
      }
      for(const [field,totalField] of [['revenue_groups','revenue'],['extraordinary_groups','extraordinary'],['expense_groups','expenses']]){
        if(!Array.isArray(data[field]))throw Error('Composição mensal ausente em '+from+' a '+to);
        const groups=[...data[field]];
        if(field==='expense_groups'&&data.expense_unclassified_card_coverage)groups.push(data.expense_unclassified_card_coverage);
        const totals=new Map(expected.map(key=>[key,0]));
        for(const group of groups){
          const keys=new Set();
          for(const row of arr(group.monthly)){
            const key=String(row.month).slice(0,10),amount=num(row.amount);
            if(!expectedKeys.has(key)||keys.has(key)||amount===null)throw Error('Composição fora do período ou incompleta em '+from+' a '+to);
            keys.add(key);totals.set(key,totals.get(key)+amount);
          }
          if(keys.size!==expected.length||num(group.total)===null||Math.abs(sum(arr(group.monthly).map(x=>x.amount))-Number(group.total))>0.05)throw Error('Grupo histórico divergente em '+from+' a '+to);
        }
        for(const row of data.monthly_totals)if(Math.abs(totals.get(String(row.month).slice(0,10))-Number(row[totalField]))>0.05)throw Error('Composição não fecha com o mês em '+from+' a '+to);
      }
      return data;
    }
    function currentRead(s,key,token,owner){
      const r=expenseRange();
      return readSessionCurrent(owner)&&(state.expense===s||state.monthly===s)&&token===s.token&&s.key===key&&key===r.from+'|'+r.to;
    }
    function invalidateExpensePeriod(){
      for(const s of [state.expense,state.monthly]){
        s.token++;s.key='';s.data=null;s.loading=false;s.error=null;
      }
      state.monthly.progress='';
    }
    async function loadMonthly(from,to,isCurrent=()=>true){
      const checkCurrent=()=>{if(!isCurrent())throw Error('Leitura substituída por outro período.')};
      checkCurrent();
      const chunks=halfYearChunks(from,to),long=chunks.length>2;
      if(!long){
        state.monthly.progress='Conferindo o período…';
        const full=await directRpc('lts_browser_monthly_balance_v5',{p_from:from,p_to:to},14000);
        checkCurrent();
        if(!full.error&&full.data)return{data:verifyPart(full.data,from,to),mode:'direct'};
      }
      state.monthly.progress='Conferindo histórico por semestre…';
      if(V==='Despesas'&&v168?.expense?.tab==='monthly')render();
      const good=[],failures=[];
      for(const [index,chunk] of chunks.entries()){
        checkCurrent();
        state.monthly.progress='Conferindo '+(index+1)+' de '+chunks.length+' períodos…';
        if(V==='Despesas'&&v168?.expense?.tab==='monthly'&&index%4===0)render();
        let result=await directRpc('lts_browser_monthly_balance_v5',{p_from:chunk.from,p_to:chunk.to},12000);
        checkCurrent();
        try{
          if(result.error||!result.data){
            if([401,403].includes(result.error?.status))throw Error('Acesso negado');
            const year=Number(chunk.from.slice(0,4)),pieces=[];
            for(const [start,end] of [['01-01','03-31'],['04-01','06-30'],['07-01','09-30'],['10-01','12-31']]){
              const a=year+'-'+start,b=year+'-'+end,lo=a<chunk.from?chunk.from:a,hi=b>chunk.to?chunk.to:b;
              if(lo>hi)continue;
              const part=await directRpc('lts_browser_monthly_balance_v5',{p_from:lo,p_to:hi},12000);
              checkCurrent();
              if(part.error||!part.data)throw Error(part.error?.message||'Leitura trimestral indisponível');
              pieces.push(verifyPart(part.data,lo,hi));
            }
            if(!pieces.length)throw Error('Nenhum trimestre disponível');
            result={data:mergeMonthly(pieces,chunk.from,chunk.to,[]),error:null};
          }
          good.push(verifyPart(result.data,chunk.from,chunk.to));
        }catch(error){checkCurrent();failures.push(chunk.from+' a '+chunk.to)}
      }
      if(failures.length)return{error:'Histórico incompleto em '+failures.join(', ')+'. Nenhum total parcial será exibido.'};
      const merged=mergeMonthly(good,from,to,[]);
      verifyPart(merged,from,to);
      for(const key of ['revenue_groups','extraordinary_groups','expense_groups']){
        for(const row of arr(merged[key]))
          if(Math.abs(sum(arr(row.monthly).map(x=>x.amount))-(num(row.total)||0))>0.05)
            return{error:'Grupo histórico divergente. Nenhum total parcial será exibido.'};
      }
      return{data:merged,mode:'semester-fallback'};
    }

    async function ensureMonthly(force=false){
      const owner=syncExpenseReaders();if(!readSessionCurrent(owner))return;
      const r=expenseRange(),key=r.from+'|'+r.to,s=state.monthly;
      if(s.key===key&&(s.loading||(!force&&(s.data||s.error))))return;
      const token=++s.token;s.key=key;s.data=null;s.loading=true;s.error=null;s.progress='Preparando balanço…';
      if(V==='Despesas'&&v168?.expense?.tab==='monthly')render();
      try{
        const result=await loadMonthly(r.from,r.to,()=>currentRead(s,key,token,owner));
        if(!currentRead(s,key,token,owner))return;
        if(result.error||!result.data)throw Error(result.error||'Balanço indisponível');
        s.data=result.data;s.mode=result.mode||'direct';
        const years=[...new Set(arr(s.data.months).map(yearOf))].filter(Boolean);
        if(!years.includes(String(s.year)))s.year=years.at(-1)||today().slice(0,4);
      }catch(error){if(currentRead(s,key,token,owner)){s.error=String(error?.message||error);s.data=null}}
      finally{if(readSessionCurrent(owner)&&state.monthly===s&&token===s.token){s.loading=false;s.progress='';if(V==='Despesas'&&v168?.expense?.tab==='monthly')render()}}
    }

    async function ensureExpense(force=false){
      const owner=syncExpenseReaders();if(!readSessionCurrent(owner))return;
      const r=expenseRange(),key=r.from+'|'+r.to,s=state.expense;
      if(s.key===key&&(s.loading||(!force&&(s.data||s.error))))return;
      const token=++s.token;s.key=key;s.data=null;s.loading=true;s.error=null;
      const dateValid=value=>/^\d{4}-\d{2}-\d{2}$/.test(value)&&Number.isFinite(Date.parse(value+'T12:00:00Z'))&&new Date(value+'T12:00:00Z').toISOString().slice(0,10)===value;
      if(!dateValid(r.from)||!dateValid(r.to)||r.from>r.to||r.from<'2013-10-10'||r.to>today()){s.loading=false;s.error=r.to>today()?'Despesas realizadas estão disponíveis até '+today()+'. Para datas futuras, consulte o Fluxo Diário. O período escolhido foi preservado.':'Informe um período válido a partir de 10/10/2013.';s.rangeInvalid=true;if(V==='Despesas')render();return;}s.rangeInvalid=false;
      try{
        const result=await directRpc('lts_browser_expense_executive_v8',{p_from:r.from,p_to:r.to},18000);
        if(!currentRead(s,key,token,owner))return;
        if(result.error||!result.data)throw Error(result.error?.message||'Despesas indisponíveis');
        s.data=result.data;
      }catch(error){if(currentRead(s,key,token,owner)){s.error=String(error?.message||error);s.data=null}}
      finally{if(readSessionCurrent(owner)&&state.expense===s&&token===s.token){s.loading=false;if(V==='Despesas'&&['overview','categories'].includes(v168?.expense?.tab))render()}}
    }

    async function ensureCards(force=false){
      const owner=syncExpenseReaders();if(!readSessionCurrent(owner))return;
      const s=state.cards;if(s.loading||(!force&&(s.data||s.error)))return;
      const token=++s.token;s.loading=true;s.error=null;
      if(V==='Despesas'&&v168?.expense?.tab==='cards')render();
      try{
        const from=today(),to=String(Number(from.slice(0,4))+1)+'-12-31';
        const result=await directRpc('lts_browser_card_flow_schedule_v2',{p_from:from,p_to:to},22000);
        if(!readSessionCurrent(owner)||state.cards!==s||token!==s.token)return;
        if(result.error||!result.data)throw Error(result.error?.message||'Cartões indisponíveis');
        s.data=result.data;
      }catch(error){if(readSessionCurrent(owner)&&state.cards===s&&token===s.token){s.error=String(error?.message||error);s.data=null}}
      finally{if(readSessionCurrent(owner)&&state.cards===s&&token===s.token){s.loading=false;if(V==='Despesas'&&v168?.expense?.tab==='cards')render()}}
    }

    S.rpc=async function(name,args){
      const requested=String(name||''),next={...(args||{})};
      if(['lts_browser_expense_executive_v4','lts_browser_expense_executive_v5','lts_browser_expense_executive_v6','lts_browser_expense_executive_v7','lts_browser_expense_executive_v8'].includes(requested))
        return directRpc('lts_browser_expense_executive_v8',next,18000);
      if(['lts_browser_monthly_balance_v1','lts_browser_monthly_balance_v2','lts_browser_monthly_balance_v3','lts_browser_monthly_balance_v5'].includes(requested))
        return directRpc('lts_browser_monthly_balance_v5',next,18000);
      if(['lts_browser_card_flow_schedule_v1','lts_browser_card_flow_schedule_v2'].includes(requested))
        return directRpc('lts_browser_card_flow_schedule_v2',next,22000);
      return previousRpc(requested,next);
    };

    function usefulChildren(group){
      const parent=norm(group?.name||group?.label),map=new Map();
      for(const child of arr(group?.subgroups)){
        const name=String(child.name||child.label||'').trim(),key=norm(name);
        if(!key||key===parent)continue;
        const cur=map.get(key)||{name,total:0,rows:0,origins:child.origins||''};cur.total+=(num(child.total)||0);cur.rows+=(num(child.rows)||0);if(child.origins)cur.origins=child.origins;map.set(key,cur);
      }
      const children=[...map.values()].sort((a,b)=>b.total-a.total);
      if(parent==='financiamento imobiliario')return[];
      if(children.length===1&&norm(children[0].name)===parent)return[];
      return children;
    }

    function rank(groups,limit=99,details=true){
      const xs=arr(groups).filter(x=>num(x.total)!=null).sort((a,b)=>(num(b.total)||0)-(num(a.total)||0)).slice(0,limit),top=Math.max(1,...xs.map(x=>Math.abs(num(x.total)||0)));
      return '<div class="v175-rank">'+(xs.map((row,index)=>{
        const children=usefulChildren(row),loan=norm(row.name)==='emprestimos';
        return '<div class="v175-rankrow"><span>'+(index+1)+'</span><div><div class="v175-rank-title"><b>'+esc(window.LTSCategoryDisplay.category(row.name||row.label||'Outros'))+'</b>'+(row.source_reconciled?'<small>fonte reconciliada</small>':'')+'</div><i><u style="width:'+Math.max(2,Math.abs(num(row.total)||0)/top*100)+'%"></u></i>'+
          (details&&children.length>1?'<details><summary>Ver composição</summary>'+children.map(child=>'<em><span>'+esc(window.LTSCategoryDisplay.category(child.name))+(child.origins?'<small>'+esc(child.origins)+'</small>':'')+'</span><b>'+brl(child.total)+'</b></em>').join('')+(loan?'<p class="v175-detail-note">Valores acima são pagamentos históricos, não saldo devedor atual.</p>':'')+'</details>':'')+
          '</div><strong>'+brl(row.total)+'</strong></div>';
      }).join('')||'<div class="v168-empty">Sem despesas no período selecionado.</div>')+'</div>';
    }

    function propertyNote(data){
      const p=data?.property_improvement_reconciliation||{};if(num(p.reconciled_unique_brl)==null)return'';
      return '<div class="v175-property"><div><span>Planilha original</span><b>'+brl(p.workbook_summary_brl)+'</b></div><div><span>Duplicidade Móveis</span><b>− '+brl(p.duplicate_source_brl)+'</b></div><div class="primary"><span>Obra/reforma reconciliada</span><b>'+brl(p.reconciled_unique_brl)+'</b></div><p>O total reconciliado preserva os componentes econômicos únicos. '+brl(p.historical_card_coverage_gap_brl)+' continuam como evidência histórica agregada de cartão sem datas de compra inventadas.</p></div>';
    }
    function coverageNote(data){
      const c=data?.coverage_disclosure||{};if((num(c.total)||0)<=0)return'';
      return '<div class="v175-coverage"><b>Registros de faturas com detalhe pendente</b><strong>'+brl(c.total)+'</strong><span>O total permanece nas despesas. O LTS só atribui categoria quando a fonte fecha exatamente; não distribui fatura por hipótese.</span></div>';
    }

    function annualRows(data){
      const map=new Map();
      for(const row of arr(data?.monthly_totals)){
        const y=yearOf(row.month),cur=map.get(y)||{year:y,revenue:0,expenses:0,operating_balance:0,extraordinary:0,cash_after_extraordinary:0,months:0};
        for(const k of ['revenue','expenses','operating_balance','extraordinary','cash_after_extraordinary'])cur[k]+=(num(row[k])||0);
        cur.months++;map.set(y,cur);
      }
      return [...map.values()].sort((a,b)=>a.year.localeCompare(b.year));
    }
    function annualTable(data){
      const rows=annualRows(data);
      return '<article class="v175-section"><div class="v168-cardhead"><div><span>Histórico completo</span><h2>Resultado anual</h2></div><small>'+rows.length+' ano(s)</small></div><div class="v175-tablewrap"><table class="v175-table compact"><thead><tr><th>Ano</th><th>Receitas</th><th>Despesas</th><th>Resultado operacional</th><th>Extraordinárias</th><th>Resultado final</th></tr></thead><tbody>'+rows.map(x=>'<tr><th>'+esc(x.year)+'</th><td>'+brl(x.revenue)+'</td><td>'+brl(x.expenses)+'</td><td class="'+(x.operating_balance<0?'negative':'positive')+'">'+brl(x.operating_balance)+'</td><td>'+brl(x.extraordinary)+'</td><td class="'+(x.cash_after_extraordinary<0?'negative':'positive')+'">'+brl(x.cash_after_extraordinary)+'</td></tr>').join('')+'</tbody></table></div></article>';
    }
    function yearGroups(groups,year){
      return arr(groups).map(g=>{
        const monthly=arr(g.monthly).filter(x=>yearOf(x.month)===String(year)),total=sum(monthly.map(x=>x.amount));
        return{...g,total,monthly};
      }).filter(g=>Math.abs(num(g.total)||0)>0).sort((a,b)=>Math.abs(num(b.total)||0)-Math.abs(num(a.total)||0));
    }
    function coverageMap(data,year){
      const map=new Map();for(const m of arr(data?.expense_unclassified_card_coverage?.monthly))if(yearOf(m.month)===String(year))map.set(String(m.month).slice(0,10),num(m.amount)||0);return map;
    }
    function yearMonths(data,year){return arr(data?.months).map(x=>String(x).slice(0,10)).filter(x=>yearOf(x)===String(year))}
    function matrix(title,subtitle,groups,months,expense,data){
      const cov=coverageMap(data,state.monthly.year);
      return '<article class="v175-section"><div class="v168-cardhead"><div><span>'+esc(subtitle)+'</span><h2>'+esc(title)+'</h2></div><small>'+groups.length+' grupo(s)</small></div><div class="v175-tablewrap"><table class="v175-table"><thead><tr><th>Grupo</th>'+months.map(m=>'<th>'+esc(monthLabel(m))+'</th>').join('')+'<th>Total</th></tr></thead><tbody>'+(
        groups.map(g=>'<tr data-lts-category-key="'+esc(g.label||g.name)+'"><th>'+esc(window.LTSCategoryDisplay.category(g.label||g.name))+'</th>'+months.map(m=>{const item=arr(g.monthly).find(x=>String(x.month).slice(0,10)===m),value=num(item?.amount)||0,unknown=expense&&value===0&&(cov.get(m)||0)>0;return'<td class="'+(unknown?'unknown':'')+'">'+(value?brl(value):unknown?'—*':'—')+'</td>'}).join('')+'<td class="total">'+brl(g.total)+'</td></tr>').join('')
        ||'<tr><td colspan="'+(months.length+2)+'" class="v168-empty">Sem valores neste ano.</td></tr>')+'</tbody></table></div></article>';
    }
    function auditIssues(data){
      const issues=arr(data?.open_audit_issues);if(!issues.length)return'';
      return '<div class="v175-open-issues">'+issues.map(x=>'<div><b>Pendência de fonte</b><strong>'+esc(x.title)+'</strong><span>'+esc(x.detail)+'</span></div>').join('')+'</div>';
    }
    function monthlyPanel(){
      const s=state.monthly,r=expenseRange(),matches=s.key===r.from+'|'+r.to;
      if(!matches||(!s.data&&!s.error))return'<div class="v175-loading" role="status"><div class="v168-skeleton"></div><b>'+esc(matches?s.progress||'Carregando…':'Preparando o período selecionado…')+'</b><span>Somente os dados completos do período selecionado serão exibidos.</span></div>';
      if(s.error&&!s.data)return'<div class="v168-error">'+esc(s.error)+'</div><button class="v168-btn primary" data-v175-month-retry>Tentar novamente</button>';
      const j=s.data||{},tot=j.totals||{},years=[...new Set(arr(j.months).map(yearOf))].filter(Boolean),selected=years.includes(String(s.year))?String(s.year):years.at(-1),months=yearMonths(j,selected);
      s.year=selected;
      const revenue=yearGroups(j.revenue_groups,selected),extra=yearGroups(j.extraordinary_groups,selected),expense=yearGroups(j.expense_groups,selected),stock=j.stock_sale_supplement||{};
      const pendingApr=arr(j.open_audit_issues).some(x=>x.issue_id==='stock_sale_2026_04_missing_source');
      return '<div class="v175-monthly"><p class="v183-expense-coverage" style="font-size:13px;line-height:1.5;color:#42546a">'+esc(window.parent.LTSHistoryCoverage?.expenseMessage||'Despesas e saldos bancários têm coberturas independentes.')+'</p>'+
        '<div class="v168-kpis"><article class="v168-kpi primary"><span>Receitas operacionais</span><strong>'+brl(tot.revenue)+'</strong><small>todo o período selecionado</small></article><article class="v168-kpi"><span>Despesas</span><strong>'+brl(tot.expenses)+'</strong><small>contas + cartões, uma vez</small></article><article class="v168-kpi"><span>Resultado operacional</span><strong>'+brl(tot.operating_balance)+'</strong><small>receitas menos despesas</small></article><article class="v168-kpi"><span>Entradas extraordinárias</span><strong>'+brl(tot.extraordinary)+'</strong><small>ações separadas de transferências</small></article><article class="v168-kpi"><span>Resultado final</span><strong>'+brl(tot.cash_after_extraordinary)+'</strong><small>após extraordinárias</small></article></div>'+
        '<div class="v175-sale-strip"><div><span>Venda de ações, RSUs e outros ativos</span><b>'+brl(stock.total)+'</b><small>Set/26 recuperado em R$ 18.808,69; transferências posteriores continuam neutras.'+(pendingApr?' Abril/26 permanece aberto porque a fonte do crédito ainda não foi localizada.':'')+'</small></div></div>'+
        auditIssues(j)+annualTable(j)+
        '<div class="v175-yearbar"><div><span>Detalhe mensal</span><b>Escolha o ano</b></div><select data-v175-year aria-label="Ano do detalhe mensal">'+years.map(y=>'<option value="'+esc(y)+'" '+(y===selected?'selected':'')+'>'+esc(y)+'</option>').join('')+'</select><small>'+(s.mode==='annual-fallback'?'carregamento anual de contingência':'leitura integral concluída')+'</small></div>'+
        matrix('Receitas operacionais',selected,revenue,months,false,j)+
        matrix('Entradas extraordinárias',selected,extra,months,false,j)+
        matrix('Despesas por categoria',selected,expense,months,true,j)+
        ((num(j.expense_unclassified_card_coverage?.total)||0)>0?'<div class="v175-coverage"><b>—* não significa zero.</b><strong>'+brl(j.expense_unclassified_card_coverage.total)+'</strong><span>Há faturas históricas cujo total é conhecido, mas a composição individual ainda não está documentada. Categorias recuperadas do workbook só entram quando o total do mês fecha exatamente.</span></div>':'')+
        '</div>';
    }

    function canonicalInventoryName(card){
      const bank=card.bank||'',name=card.card_name||'',last=card.last4?(' · final '+card.last4):'';
      if(bank==='Bradesco'&&/Visa Infinite Prime/i.test(name))return'Visa'+last;
      if(bank==='Itaú'&&/Mastercard Black/i.test(name))return'Mastercard Black Itaú';
      if(bank==='C6'&&/histórico/i.test(name))return'C6 histórico'+last;
      if(bank==='C6'&&/C6 Carbon/i.test(name))return'C6 Carbon'+last;
      return name+last;
    }
    function inventoryPanel(data){
      const cards=arr(data?.inventory?.cards),groups=new Map();
      for(const card of cards){const b=card.bank||'Outros';if(!groups.has(b))groups.set(b,[]);groups.get(b).push(card)}
      return '<article class="v168-card v175-inventory"><div class="v168-cardhead"><div><span>Inventário histórico</span><h2>Todos os cartões documentados</h2></div><small>ativos e históricos</small></div><div class="v175-inventory-grid">'+[...groups.entries()].map(([bank,rows])=>'<section><header>'+esc(bank)+'</header>'+rows.map(card=>'<div><b>'+esc(canonicalInventoryName(card))+'</b><span>'+esc(card.status==='historical'?'Histórico':'Atual/recente')+'</span><small>'+esc(card.first_seen||'—')+' → '+esc(card.last_seen||'—')+'</small></div>').join('')+'</section>').join('')+'</div></article>';
    }
    function cardBank(name){const n=norm(name);if(n.includes('aeternum')||n.includes('bradesco'))return'Bradesco';if(n.includes('c6')||n.includes('carbon')||n.includes('7873')||n.includes('8304')||n.includes('6610'))return'C6';if(n.includes('personnalite')||n.includes('mastercard')||n.includes('itau')||n.includes('itaú'))return'Itaú';return'Outros'}
    function cardKey(name){const n=norm(name);if(n.includes('aeternum'))return'aeternum';if(n.includes('c6')||n.includes('carbon'))return'c6';if(n.includes('mastercard')||n.includes('personnalite'))return'mastercard-itau';if(n.includes('visa infinite prime'))return'visa-prime';if(n.includes('visa infinite')&&n.includes('itau'))return'visa-infinite-itau';return n.replace(/\W+/g,'-')}
    function cardsPanel(){
      const s=state.cards;if(s.loading&&!s.data)return'<div class="v175-loading"><div class="v168-skeleton"></div><b>Conferindo cartões com o Fluxo…</b></div>';if(s.error&&!s.data)return'<div class="v168-error">A conferência do histórico com o Fluxo não está disponível agora.</div><button class="v168-btn primary" data-v175-card-retry>Tentar novamente</button>';
      const data=s.data||{},o=D?.card_operating||{},map=new Map(),ensure=(b,c,m)=>{const k=[b,cardKey(c),m].join('|');if(!map.has(k))map.set(k,{bank:b,card:c,month:m,invoices:[],floors:[],flows:[]});return map.get(k)};
      for(const x of [...arr(o.open_cycles),...arr(o.closed_or_due)]){const c=x.card_name||x.description||'Cartão não identificado',m=String(x.due_date||'').slice(0,7);if(m)ensure(cardBank(c),c,m).invoices.push(x)}
      for(const m of arr(o.contracted_installment_floor_months))for(const x of arr(m.detail)){const c=x.card_name||'Cartão não identificado';ensure(cardBank(c),c,String(m.reference_month).slice(0,7)).floors.push(x)}
      for(const x of arr(data.events)){const c=x.card_name||x.description||'Cartão não identificado',m=String(x.event_date||'').slice(0,7);if(m)ensure(cardBank(c),c,m).flows.push(x)}
      const banks=['Todos',...new Set([...map.values()].map(x=>x.bank))],filter=s.bank||'Todos',rows=[...map.values()].filter(x=>x.month>=today().slice(0,7)&&(filter==='Todos'||x.bank===filter)).sort((a,b)=>a.bank.localeCompare(b.bank)||cardKey(a.card).localeCompare(cardKey(b.card))||a.month.localeCompare(b.month)),groups=new Map();
      for(const row of rows){const k=row.bank+'|'+cardKey(row.card);if(!groups.has(k))groups.set(k,{bank:row.bank,card:row.card,rows:[]});groups.get(k).rows.push(row)}
      return '<div class="v175-cards">'+inventoryPanel(data)+'<div class="v169-bank-filter">'+banks.map(b=>'<button class="v168-btn '+(filter===b?'primary':'')+'" data-v175-card-bank="'+esc(b)+'">'+esc(b)+'</button>').join('')+'</div><article class="v168-card"><div class="v168-cardhead"><div><span>Conferência com o Fluxo</span><h2>Fatura, piso contratado e valor usado no caixa</h2></div><small>mês a mês</small></div>'+(
        [...groups.values()].map(g=>'<section class="v171-cardgroup"><header><span>'+esc(g.bank)+'</span><h3>'+esc(g.card)+'</h3></header><div class="v171-cardmonths">'+g.rows.map(x=>{const invoice=sum(x.invoices.map(y=>y.amount)),floor=sum(x.floors.map(y=>y.amount)),flow=sum(x.flows.map(y=>y.amount)),considered=x.flows.length?flow:x.invoices.length?invoice:floor;return'<div><b>'+monthLabel(x.month)+'</b><dl><dt>Fatura conhecida</dt><dd>'+brl(invoice)+'</dd><dt>Parcelas contratadas</dt><dd>'+brl(floor)+'</dd><dt>Valor no Fluxo</dt><dd><strong>'+(x.flows.length?brl(flow):'—')+'</strong></dd><dt>Considerado</dt><dd><strong>'+brl(considered)+'</strong></dd></dl></div>'}).join('')+'</div></section>').join('')
        ||'<div class="v168-empty">Nenhum valor futuro documentado neste filtro.</div>')+'</article><div class="v175-coverage"><b>Regra</b><span>Fatura observada e valor do Fluxo prevalecem sobre o piso parcelado. Cartões históricos continuam no inventário mesmo sem fatura futura.</span></div></div>';
    }

    function shellForHeavyTab(){
      const original=v168.expense.tab,editor=v168.expense.periodEditorVisible;v168.expense.periodEditorVisible=original==='monthly';v168.expense.tab='overview';
      try{return baseExpenses()}finally{v168.expense.tab=original;v168.expense.periodEditorVisible=editor}
    }
    function expensesV175(){
      const tab=v168?.expense?.tab||'overview',heavy=['monthly','cards'].includes(tab),t=tpl(heavy?shellForHeavyTab():baseExpenses()),root=t.content.querySelector('.v168-expenses'),tabs=root?.querySelector('.v168-tabs');if(!root||!tabs)return t.innerHTML;
      tabs.querySelectorAll('[data-v168-exp-tab]').forEach(b=>{const active=b.dataset.v168ExpTab===tab;b.classList.toggle('active',active);b.setAttribute('aria-selected',String(active))});
      if(tab==='categories'){
        let n=tabs.nextSibling;while(n){const q=n.nextSibling;n.remove();n=q}
        const r=expenseRange(),matches=state.expense.key===r.from+'|'+r.to,data=matches?state.expense.data:null,error=matches?state.expense.error:null;
        tabs.insertAdjacentHTML('afterend',!data&&!error?'<div class="v168-skeleton" role="status" aria-label="Carregando o período selecionado"></div>':error&&!data?'<div class="v168-error">'+esc(error)+'</div>'+(state.expense.rangeInvalid?'':'<button class="v168-btn primary" data-v183-expense-retry>Tentar novamente</button>'):'<article class="v168-card v175-categories"><div class="v168-cardhead"><div><span>Composição auditada</span><h2>Despesas por categoria</h2></div><small>'+esc(r.label)+'</small></div>'+rank(data?.management_groups,99,true)+propertyNote(data)+coverageNote(data)+'</article>');
      }
      if(tab==='monthly'||tab==='cards'){
        let n=tabs.nextSibling;while(n){const q=n.nextSibling;n.remove();n=q}
        tabs.insertAdjacentHTML('afterend',tab==='monthly'?monthlyPanel():cardsPanel());
      }
      return t.innerHTML;
    }

    function dashboardV175(){
      const t=tpl(baseDashboard()),root=t.content.querySelector('.v168-dashboard');if(!root)return t.innerHTML;
      const data=state.expense.data,card=[...root.querySelectorAll('.v168-card')].find(x=>/principais grupos/i.test(x.querySelector('h2')?.textContent||''));
      if(card&&data?.management_groups){card.querySelectorAll('.v168-rank,.v169-coverage,.v170-rank,.v170-audit,.v171-rank,.v171-reconciliation,.v172-rank,.v172-coverage,.v174-rank,.v174-property-note').forEach(x=>x.remove());card.insertAdjacentHTML('beforeend',rank(data.management_groups,12,false)+coverageNote(data))}
      return t.innerHTML;
    }

    function after(){
      const badge=window.parent?.document?.getElementById('scope');if(badge)badge.dataset.v175Route=V==='Fluxo Diário'?'Fluxo de caixa':V;
      const tab=v168?.expense?.tab;
      if(V==='Despesas'){
        const r=expenseRange(),key=r.from+'|'+r.to;
        if(['overview','categories'].includes(tab)&&(state.expense.key!==key||(!state.expense.loading&&!state.expense.data&&!state.expense.error)))queueMicrotask(()=>ensureExpense(false));
        if(tab==='monthly'&&(state.monthly.key!==key||(!state.monthly.loading&&!state.monthly.data&&!state.monthly.error)))queueMicrotask(()=>ensureMonthly(false));
        if(tab==='cards'&&!state.cards.loading&&!state.cards.data&&!state.cards.error)queueMicrotask(()=>ensureCards(false));
      }
      document.querySelector('[data-v175-month-retry]')?.addEventListener('click',()=>ensureMonthly(true));
      document.querySelector('[data-v175-card-retry]')?.addEventListener('click',()=>ensureCards(true));
      document.querySelector('[data-v183-expense-retry]')?.addEventListener('click',()=>ensureExpense(true));
      document.querySelector('[data-v175-year]')?.addEventListener('change',e=>{state.monthly.year=e.currentTarget.value;render()});
      document.querySelectorAll('[data-v175-card-bank]').forEach(b=>b.onclick=()=>{state.cards.bank=b.dataset.v175CardBank;render()});
      // V168 owns the editor transaction. Only a committed action retires reads;
      // bypass the legacy V169 pre-invalidation for open/invalid/no-op actions.
      const bindPeriodAction=b=>{const action=b.__ltsExpenseAction;if(action){b.onclick=e=>{if(action.changesPeriod()){invalidateExpensePeriod();if(v169?.monthly){v169.monthly.data=null;v169.monthly.key='';v169.monthly.error=null}}return action.run(e)}}else{const old=b.onclick;b.onclick=e=>{invalidateExpensePeriod();return old?.call(b,e)}}};
      document.querySelectorAll('[data-v168-exp-range]').forEach(bindPeriodAction);
      const apply=document.getElementById('v168ExpenseApply');if(apply)bindPeriodAction(apply);
    }

    dashboard=dashboardV175;despesas=expensesV175;
    render=function(){syncExpenseReaders();const out=baseRender();after();return out};
    renderNav=function(){syncExpenseReaders();const out=baseNav();after();return out};

    state.expense.data=null;state.expense.key='';state.monthly.data=null;state.monthly.key='';state.cards.data=null;
    if(v168){v168.expense.data=null;v168.expense.loading=false;v168.dashboard.data=null;v168.dashboard.started=false;v168.dashboard.loading=false}
    if(v169){v169.monthly.token=(v169.monthly.token||0)+1;v169.monthly.data=null;v169.monthly.key='';v169.monthly.loading=false;v169.monthly.error=null}
    window.__LTS_V175_EXPENSE_AUDIT={
      installed:true,version:'v175',base_version:'v174',public_index_changed:false,
      all_supported_cards_and_accounts_once:true,full_history_monthly_bounded_render:true,
      lender_split_fixed:true,workbook_category_reconciliation:true,historical_card_inventory:true,
      september_stock_sale_restored:true,april_stock_sale_open_source_issue:true,property_reconciled:true
    };
    if(D&&!N.classList.contains('hidden'))render();
  }

  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return null;return{w,d}}catch{return null}}
  function install(){
    const f=frame();if(!f||!f.w.__LTS_V174_V173_REVIEW?.installed)return false;
    if(!f.d.getElementById('lts-v175-style')){const link=f.d.createElement('link');link.id='lts-v175-style';link.rel='stylesheet';link.href='lts-v175-expense-financial-audit.css?v=20260918-v175a';f.d.head.appendChild(link)}
    if(!f.w.__LTS_V175_EXPENSE_AUDIT?.installed&&!f.d.getElementById('lts-v175-runtime')){const script=f.d.createElement('script');script.id='lts-v175-runtime';script.textContent='('+runtime.toString()+')();';f.d.head.appendChild(script)}
    const ready=f.w.__LTS_V175_EXPENSE_AUDIT?.installed===true;if(ready&&gate)gate.remove();return ready;
  }
  function burst(){const current=++generation;let attempt=0;function step(){if(current!==generation)return;const ready=install();attempt++;if(!ready&&attempt<320)setTimeout(step,100)}step();[400,900,1800,3600,7000,12000,20000,30000].forEach(ms=>setTimeout(()=>{if(current===generation)install()},ms))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();
  window.__LTS_TOP_CANDIDATE_VERSION='v175-expense-financial-audit';
})();

;
;
/* LTS V384: lts-v176-flow-expense-audit.js */
(function(){
  'use strict';
  const outer=document.getElementById('shell'),gate=document.getElementById('gate'),scope=document.getElementById('scope');
  let generation=0;

  function runtime(){
    'use strict';
    if(window.__LTS_V176_FLOW_EXPENSE_AUDIT?.installed||!window.__LTS_V175_EXPENSE_AUDIT?.installed)return;

    const state=window.__LTS_V176_STATE||(window.__LTS_V176_STATE={installedAt:new Date().toISOString()});
    const nativeFetch=window.fetch.bind(window);
    const rpcMap=new Map([
      ['lts_browser_expense_executive_v8','lts_browser_expense_executive_v9'],
      ['lts_browser_monthly_balance_v5','lts_browser_monthly_balance_v6']
    ]);

    function remapRpcUrl(input){
      const raw=typeof input==='string'?input:input?.url;
      if(!raw)return input;
      let next=raw;
      for(const [from,to] of rpcMap){
        next=next.replace('/rest/v1/rpc/'+from,'/rest/v1/rpc/'+to);
      }
      if(next===raw)return input;
      if(typeof input==='string')return next;
      return new Request(next,input);
    }
    window.fetch=function(input,init){return nativeFetch(remapRpcUrl(input),init)};

    const isNonCashAwardEvent=window.parent.LTSV268ReadTools.isNonCashAwardEvent;

    const baseDayEvents=dayEvents;
    dayEvents=function(day){return baseDayEvents(day).filter(e=>!isNonCashAwardEvent(e))};

    const baseFlowVals=flowVals;
    flowVals=function(x,prev){
      const value=baseFlowVals(x,prev);
      if(!x?.historical&&ACC==='Consolidado'){
        const c=x.fix86_columns||{};
        if(c.entradas!==undefined&&c.entradas!==null)value.en=num(c.entradas);
        if(c.saidas!==undefined&&c.saidas!==null)value.ex=num(c.saidas);
      }
      return value;
    };

    flowDayMaterial=function(x,prev){
      const v=flowVals(x,prev);
      if(x.date===today()||x.date===FLOWFROM||x.date===FLOWTO||Math.abs(num(v?.en))>0.005||Math.abs(num(v?.ex))>0.005)return true;
      if(ACC!=='Consolidado'||!prev)return false;
      return ['liq_d0_1_recurso','rsus_vested','fgts'].some(key=>{
        const a=x.fix86_columns?.[key],b=prev.fix86_columns?.[key];
        return a!=null&&b!=null&&Math.abs(Number(a)-Number(b))>.005;
      });
    };

    let rsuIndex=null;
    function rsuDeltaFor(day){
      const historical=FLOWQ?.historical?.days,future=FLOWQ?.current_future?.days;
      if(!rsuIndex||rsuIndex.historical!==historical||rsuIndex.future!==future){
        const days=mergedFlowDays(),deltas=new Map();
        days.forEach((x,i)=>deltas.set(x.date,i?num(x.fix86_columns?.rsus_vested)-num(days[i-1].fix86_columns?.rsus_vested):0));
        rsuIndex={historical,future,deltas};
      }
      return rsuIndex.deltas.get(day)||0;
    }
    function decorateFlow(){
      if(V!=='Fluxo Diário')return;
      document.querySelectorAll('.fx87-row.fx87-cons[id^="d-"]').forEach(row=>{
        const day=row.id.slice(2),delta=rsuDeltaFor(day),cell=row.children?.[7];
        if(!cell)return;
        cell.querySelector('.v176-rsu-delta')?.remove();
        cell.classList.toggle('v176-rsu-active',delta>0.005);
        if(delta>0.005){
          const small=document.createElement('small');
          small.className='v176-rsu-delta';
          small.textContent='+'+brl(delta);
          small.title='Aumento de RSU vested / disponível na corretora; não é entrada de conta corrente.';
          cell.appendChild(small);
        }
      });
      const zero=document.getElementById('flowZero');
      if(zero){
        zero.onclick=()=>{
          SHOWZERO=!SHOWZERO;
          if(!SHOWZERO)FLOWFORCEZERO=false;
          render();
        };
        zero.title=SHOWZERO
          ?'Ocultar dias sem entrada ou saída de caixa'
          :'Mostrar também dias sem entrada ou saída de caixa';
      }
    }

    const baseRender=render;
    render=function(){const out=baseRender();decorateFlow();return out};
    const baseRenderNav=renderNav;
    renderNav=function(){const out=baseRenderNav();const badge=window.parent?.document?.getElementById('scope');if(badge)badge.dataset.v176Route=V==='Fluxo Diário'?'Fluxo de caixa':V;return out};

    const v175=window.__LTS_V175_STATE;
    if(v175){
      if(v175.expense){v175.expense.data=null;v175.expense.key='';v175.expense.error=null;v175.expense.loading=false;v175.expense.token=(v175.expense.token||0)+1}
      if(v175.monthly){v175.monthly.data=null;v175.monthly.key='';v175.monthly.error=null;v175.monthly.loading=false;v175.monthly.token=(v175.monthly.token||0)+1}
    }

    window.__LTS_V176_FLOW_EXPENSE_AUDIT={
      installed:true,version:'v176',base_version:'v175',public_index_changed:false,
      rsu_non_cash_in_entries:true,zero_day_cash_only:true,
      expense_window_reader:'lts_browser_expense_executive_v9',
      monthly_window_reader:'lts_browser_monthly_balance_v6',
      health_6m_corrected_brl:56307.56,
      health_12m_audited_brl:105050.49,
      loans_6m_audited_brl:38691.93,
      loans_12m_audited_brl:109227.39
    };
    if(D&&!N.classList.contains('hidden'))render();
  }

  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return null;return{w,d}}catch{return null}}
  function install(){
    const f=frame();if(!f||!f.w.__LTS_V175_EXPENSE_AUDIT?.installed)return false;
    if(!f.d.getElementById('lts-v176-style')){const link=f.d.createElement('link');link.id='lts-v176-style';link.rel='stylesheet';link.href='lts-v176-flow-expense-audit.css?v=20260918-v176a';f.d.head.appendChild(link)}
    if(!f.w.__LTS_V176_FLOW_EXPENSE_AUDIT?.installed&&!f.d.getElementById('lts-v176-runtime')){const script=f.d.createElement('script');script.id='lts-v176-runtime';script.textContent='('+runtime.toString()+')();';f.d.head.appendChild(script)}
    const ready=f.w.__LTS_V176_FLOW_EXPENSE_AUDIT?.installed===true;if(ready&&gate)gate.remove();return ready;
  }
  function burst(){const current=++generation;let attempt=0;function step(){if(current!==generation)return;const ready=install();attempt++;if(!ready&&attempt<320)setTimeout(step,100)}step();[400,900,1800,3600,7000,12000,20000,30000].forEach(ms=>setTimeout(()=>{if(current===generation)install()},ms))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();
  window.__LTS_TOP_CANDIDATE_VERSION='v176-flow-expense-audit';
})();

;
;
/* LTS V384: lts-v179-cash-recovery.js */
/* V178 replaces the V177 polling/drawer layer. Financial facts stay server-side. */
(function(){
 'use strict';
 const outer=document.getElementById('shell'); let generation=0;
 function runtime(){
  'use strict';
    const v233Formatters=[new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}),new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}),new Intl.DateTimeFormat('pt-BR',{month:'short',year:'2-digit'})];

  if(window.__LTS_V178_REVIEW?.installed||!window.__LTS_V176_FLOW_EXPENSE_AUDIT?.installed)return;
  const v168=window.__LTS_V168_STATE,v175=window.__LTS_V175_STATE;
  const previousRender=render,previousNav=renderNav,previousDashboard=dashboard,previousExpenses=despesas;
  const rawFetch=window.fetch.bind(window),inflight=new Map(),cache=new Map();
  const state=window.__LTS_V178_STATE={cash:{status:'idle'},planningUI:{status:'idle'},wealth:{status:'idle'},forecast:{status:'idle'},awards:{status:'idle'},dashboardReport:{status:'idle'},detail:null,errors:[],diagnostics:[],date:null};
  let dashboardFlight=null,dashboardSerial=0;
  let cashFlight=null,cashActive=null,cashDemand=null,cashRevision=0,cashAuthEpoch=0;
  const cashGeneration=()=>typeof BOOT!=='undefined'?BOOT.generation:(typeof D!=='undefined'?D:null);
  let cashSessionGeneration=cashGeneration(),cashSessionEpoch=cashAuthEpoch,cashCalendarDay=null;
  const arr=x=>Array.isArray(x)?x:[],finite=x=>x==null||x===''?null:(Number.isFinite(Number(x))?Number(x):null);
  const money=x=>finite(x)==null?'—':v233Formatters[0].format(Number(x));
  const escape=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const normalize=x=>String(x??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
  const day=()=>v233Formatters[1].format(new Date());
  const dateLabel=x=>/^\d{4}-\d{2}-\d{2}$/.test(String(x))?x.split('-').reverse().join('/'):String(x||'—');
  const monthLabel=x=>/^\d{4}-\d{2}/.test(String(x))?v233Formatters[2].format(new Date(String(x).slice(0,7)+'-01T12:00:00Z')):'Histórico';
  const total=xs=>xs.reduce((a,b)=>a+(finite(b)||0),0);
  const template=html=>{const t=document.createElement('template');t.innerHTML=html;return t};
  const yearRange=()=>({from:day().slice(0,4)+'-01-01',to:day(),label:'Ano atual'});
  function reportRange(){
   const s=v168.expense,t=day();let from=t.slice(0,4)+'-01-01';
   if(s.key==='all')from='2013-10-10';
   else if(s.key==='6m'||s.key==='12m'){const d=new Date(t.slice(0,7)+'-01T12:00:00Z');d.setUTCMonth(d.getUTCMonth()-(s.key==='6m'?5:11));from=d.toISOString().slice(0,10)}
   else if(s.key==='custom')return{from:s.customFrom||from,to:s.customTo||t,label:'Período personalizado'};
   return{from,to:t,label:s.key==='all'?'Desde 2013':s.key==='6m'?'6 meses':s.key==='12m'?'12 meses':'Ano atual'};
  }
  const safeMessage=error=>String(error?.message||error||'Falha').replace(/Bearer\s+\S+/gi,'Bearer [redacted]').replace(/eyJ[A-Za-z0-9._-]+/g,'[redacted]').slice(0,240);
  function cashReasons(s){
   const x=s?.data,reasons=[];
   if(s?.status!=='ready')reasons.push('reader_'+String(s?.status||'missing'));
   if(s?.date!==day())reasons.push('client_date_mismatch');
   if(x?.as_of!==day())reasons.push('server_date_mismatch');
   if(x?.status!=='complete')reasons.push('payload_not_complete');
   const fields=['cash','d0','brokerage_available','available_total'];
   for(const field of fields)if(finite(x?.[field])==null)reasons.push('non_finite_'+field);
   if(fields.every(field=>finite(x?.[field])!=null)&&Math.abs(total([x.cash,x.d0,x.brokerage_available])-Number(x.available_total))>=0.02)reasons.push('sum_mismatch');
   return reasons;
  }
  function publishCashDiagnostic(){
   const s=state.cash,x=s?.data,last=state.diagnostics.filter(d=>d.name==='lts_browser_cash_today_v242').slice(-5);
   const summary={build:'v179-cash-recovery-1',local_day:day(),reader_status:s?.status||'missing',state_date:s?.date||null,error:s?.error||null,reasons:cashReasons(s),payload:x?{server_status:x.status||null,server_as_of:x.as_of||null,fields:{cash:finite(x.cash)!=null,d0:finite(x.d0)!=null,brokerage_available:finite(x.brokerage_available)!=null,available_total:finite(x.available_total)!=null},sum_consistent:[x.cash,x.d0,x.brokerage_available,x.available_total].every(v=>finite(v)!=null)?Math.abs(total([x.cash,x.d0,x.brokerage_available])-Number(x.available_total))<0.02:null}:null,history:last,concurrent:state.diagnostics.slice(-20).map(d=>({name:d.name,outcome:d.outcome,http_status:d.http_status,duration_ms:d.duration_ms}))};
   document.documentElement.setAttribute('data-lts-v179-cash-diagnostic',JSON.stringify(summary));
  }
  function recordDiagnostic(entry){state.diagnostics.push({...entry,at:new Date().toISOString()});state.diagnostics=state.diagnostics.slice(-50);publishCashDiagnostic()}
  function logError(name,error){state.errors.push({reader:name,message:safeMessage(error),code:error?.code||null,http_status:error?.httpStatus||null,at:new Date().toISOString()});state.errors=state.errors.slice(-30)}
  async function request(name,args={},timeout=20000,force=false,isCurrent=null){
   const started=Date.now();let httpStatus=null,serverCode=null;
   const auth=await S.auth.getSession(),token=auth?.data?.session?.access_token;
   if(isCurrent&&!isCurrent()){const error=Error('Leitura substituída.');error.code='CASH_SUPERSEDED';throw error}
   if(!token){const error=Error('Sessão indisponível. Entre novamente.');error.code='SESSION_UNAVAILABLE';recordDiagnostic({name,outcome:'session_unavailable',http_status:null,server_code:null,duration_ms:Date.now()-started,message:safeMessage(error)});throw error}
   const key=token+'|'+name+'|'+JSON.stringify(args)+'|'+(window.__LTS_V227_TRANSPORT?.revision||0),stored=cache.get(key);
   if(!force&&stored&&Date.now()-stored.time<30000)return structuredClone(stored.data);
   if(!force&&inflight.has(key))return structuredClone(await inflight.get(key));
   const job=(async()=>{
    const abort=new AbortController();let timer;const startTimer=()=>{timer=setTimeout(()=>abort.abort(),timeout)};if(!window.__LTS_V227_TRANSPORT?.installed)startTimer();
    try{
     const res=await rawFetch(U+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:K,Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify(args),signal:abort.signal,ltsOnReadStart:startTimer});
     httpStatus=res.status;let data;
     try{data=await res.json()}catch(parseError){const error=Error('Resposta inválida do serviço.');error.code='INVALID_JSON';error.httpStatus=res.status;throw error}
     serverCode=data?.code||null;
     if(!res.ok){const error=Error(data?.message||'Falha na leitura.');error.code=serverCode||'HTTP_ERROR';error.httpStatus=res.status;throw error}
     recordDiagnostic({name,outcome:'success',http_status:res.status,server_code:serverCode,duration_ms:Date.now()-started,message:null});
     cache.set(key,{time:Date.now(),data});if(cache.size>32)cache.delete(cache.keys().next().value);return data;
    }catch(error){const outcome=error?.name==='AbortError'?'client_timeout':error?.code==='SESSION_UNAVAILABLE'?'session_unavailable':error?.httpStatus?'http_error':'network_error';try{error.ltsOutcome=outcome}catch{}recordDiagnostic({name,outcome,http_status:error?.httpStatus||httpStatus,server_code:error?.code||serverCode,duration_ms:Date.now()-started,message:safeMessage(error)});logError(name,error);throw error}finally{clearTimeout(timer)}
   })();
   inflight.set(key,job);try{return structuredClone(await job)}finally{if(inflight.get(key)===job)inflight.delete(key)}
  }
  window.fetch=async function(input,init){
   const url=typeof input==='string'?input:input?.url||'',name=url.split('/').pop();
   let target=null;
   if(/^lts_browser_expense_executive_v\d+$/.test(name))target='lts_browser_expenses_v229';
   if(/^lts_browser_monthly_balance_v\d+$/.test(name))target='lts_browser_monthly_v229';
   if(!target)return rawFetch(input,init);
   try{const args=JSON.parse(init?.body||'{}'),data=await request(target,args,22000);return new Response(JSON.stringify(data),{status:200,headers:{'Content-Type':'application/json'}})}
   catch(error){return new Response(JSON.stringify({message:'Não foi possível atualizar este relatório.'}),{status:503,headers:{'Content-Type':'application/json'}})}
  };
  async function loadState(key,name,args={},force=false){
   const s=state[key];if(s.status==='loading'||(!force&&s.status!=='idle'))return;
   const token=(s.token||0)+1;s.token=token;s.status='loading';s.error=null;s.outcome=null;s.code=null;s.httpStatus=null;
   try{const value=await request(name,args,key==='planningUI'?48000:20000,force);if(state[key]!==s||s.token!==token)return;s.data=value;s.date=day();s.status='ready';if(key==='wealth'&&!v168.wealth.loading){v168.wealth.data=value;v168.wealth.error=null}}
   catch(e){if(state[key]===s&&s.token===token){s.status='error';s.error=String(e.message||e);s.outcome=e?.ltsOutcome||null;s.code=e?.code||null;s.httpStatus=e?.httpStatus||null}}
   finally{if(state[key]===s&&s.token===token){publishCashDiagnostic();queueMicrotask(()=>{if(D&&!N.classList.contains('hidden'))render()})}}
   return true;
  }
  function forecastCoverage(parts,from,to){
   const parseDate=value=>{
    if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(value))return null;
    const stamp=Date.parse(value+'T12:00:00Z');
    return Number.isFinite(stamp)&&new Date(stamp).toISOString().slice(0,10)===value?stamp:null;
   };
   const start=parseDate(from),end=parseDate(to),seen=new Set();
   const result={complete:false,from,to,expected_days:start!=null&&end!=null&&end>=start?(end-start)/86400000+1:0,received_days:0,reason:null};
   if(!result.expected_days){result.reason='invalid_horizon';return result}
   const numeric=value=>(typeof value==='number'||(typeof value==='string'&&value.trim()!==''))&&Number.isFinite(Number(value));
   for(const part of parts){
    const rows=part?.flow?.current_future?.days;
    if(!Array.isArray(rows)){result.reason='invalid_days';return result}
    for(const row of rows){
     const stamp=parseDate(row?.date);
     if(stamp==null){result.reason='invalid_date';return result}
     if(stamp<start||stamp>end)continue;
     if(seen.has(row.date)){result.reason='duplicate_date';return result}
     seen.add(row.date);result.received_days=seen.size;
     if(['saldo_apos_d0_1','saldo_apos_rsu','saldo_apos_fgts'].some(key=>!numeric(row.fix86_columns?.[key]))){result.reason='unknown_resource';return result}
    }
   }
   if(seen.size!==result.expected_days){result.reason='missing_dates';return result}
   result.complete=true;return result;
  }
  function mergeForecast(parts){
   const days=new Map(),events=new Map();
   for(const part of parts){const f=part?.flow?.current_future||{};for(const d of arr(f.days))days.set(d.date,d);for(const e of arr(f.events))events.set([e.source,e.source_ref,e.event_date].join('|'),e)}
   return{ok:true,complete:!parts.some(p=>p?.complete===false),incomplete_families:[...new Set(parts.flatMap(p=>p?.incomplete_families||[]))],flow:{fgts_projection_contract:parts.at(-1)?.flow?.fgts_projection_contract||null,current_future:{days:[...days.values()].sort((a,b)=>a.date.localeCompare(b.date)),events:[...events.values()]}}};
  }
  function observedTodayForForecast(cashDay,forecast){
   const observed=structuredClone(cashDay);
   if(forecast?.complete===false){
    observed.projection_complete=false;
    observed.incomplete_families=forecast.incomplete_families||[];
    observed.fix86_columns={...observed.fix86_columns,liq_d30:null};
   }
   return observed;
  }
  async function loadForecast(force=false){
   const s=state.forecast;if(s.status==='loading'||(!force&&s.status!=='idle'))return;
   const token=(s.token||0)+1;s.token=token;s.status='loading';s.date=day();s.parts=[];s.data=null;s.error=null;let releaseWaiting;s.waiting=new Promise(resolve=>{releaseWaiting=resolve});
   const now=day(),year=Number(now.slice(0,4)),past=new Date(now+'T12:00:00Z');past.setUTCDate(past.getUTCDate()-5);const ranges=[{p_from:past.toISOString().slice(0,10),p_to:(year+1)+'-12-31'}];
   state.planningUI={status:'loading',date:now,data:null};
   try{
    for(const r of ranges){let p;try{p=await request('lts_browser_flow_v242',r,48000,force)}catch(error){if(state.forecast!==s||s.token!==token)return;if(!['40001','57014'].includes(String(error?.code))&&![408,429,500,502,503,504].includes(Number(error?.httpStatus)))throw error;p=await request('lts_browser_flow_v242',r,48000,true)}if(state.forecast!==s||s.token!==token)return;
     if(!arr(p?.flow?.current_future?.days).length)throw Error('Projeção sem dias retornados.');s.parts.push(p);const coverage=forecastCoverage(s.parts,now,ranges[0].p_to);s.data=mergeForecast(s.parts);s.data.coverage=coverage;if(!coverage.complete)s.data.complete=false;render();}
    const authToken=(await S.auth.getSession())?.data?.session?.access_token;
    if(state.forecast!==s||s.token!==token)return;s.status=s.data?.complete===false?'incomplete':'ready';s.updatedAt=Date.now();s.authToken=authToken;
    const rows=arr(s.data?.flow?.current_future?.days).filter(d=>d.date>=now&&d.date<=ranges[0].p_to),first=key=>rows.find(d=>finite(d.fix86_columns?.[key])!=null&&Number(d.fix86_columns[key])<0)?.date||null;
    state.planningUI=s.data?.complete===false||rows.some(d=>['saldo_apos_d0_1','saldo_apos_rsu','saldo_apos_fgts'].some(k=>finite(d.fix86_columns?.[k])==null))?{status:'incomplete',date:now,data:null}:{status:'ready',date:now,data:{version:'planning-ui-contract-v2',scenario_revision:'v242',period_to:ranges[0].p_to,d01_first_need:first('saldo_apos_d0_1'),rsu_first_need:first('saldo_apos_rsu'),fgts_first_negative:first('saldo_apos_fgts'),fgts_covers_horizon:!first('saldo_apos_fgts')}};
   }catch(e){if(state.forecast===s&&s.token===token){s.status=s.parts.length?'partial':'error';s.error=String(e.message||e);state.planningUI={status:'error',date:now,data:null}}}
   finally{releaseWaiting();if(state.forecast===s&&s.token===token&&D&&!N.classList.contains('hidden'))render()}
  }
  function retryableCashFailure(s){return s?.status==='error'&&(s.outcome==='client_timeout'||s.outcome==='network_error'||String(s.code)==='57014'||[408,429,500,502,503,504].includes(Number(s.httpStatus)))}
  const cashVisible=()=>D&&!N.classList.contains('hidden')&&(V==='Dashboard'||V==='Fluxo Diário');
  const transportRevision=()=>window.__LTS_V227_TRANSPORT?.revision||0;
  function syncCashContext(){
   const session=cashGeneration(),date=day();
   if(cashCalendarDay===null)cashCalendarDay=state.cash.date||date;
   const sessionChanged=session!==cashSessionGeneration||cashSessionEpoch!==cashAuthEpoch;
   if(!sessionChanged&&date===cashCalendarDay)return;
   cashSessionGeneration=session;cashSessionEpoch=cashAuthEpoch;cashCalendarDay=date;
   cashRevision++;cashDemand=null;dashboardSerial++;
   // The shipped auth shim has no auth callbacks. BOOT transitions must also
   // retire every V179 slot captured by reads from the preceding session.
   for(const key of sessionChanged?['cash','wealth','forecast','awards','dashboardReport','planningUI']:['cash']){
    const previous=state[key];previous.token=(previous.token||0)+1;
    state[key]={status:'idle',token:previous.token};
   }
   if(sessionChanged){state.date=null;closeDetail()}
   cache.clear();window.__LTS_V227_TRANSPORT?.invalidate?.(false);
   // state.date belongs to the complete dashboard, not this cash-only reader.
  }
  function cashTicketCurrent(ticket){
   return !!D&&!N.classList.contains('hidden')&&ticket.session===cashGeneration()&&ticket.authEpoch===cashAuthEpoch&&ticket.date===day()&&ticket.revision===cashRevision&&state.cash===ticket.slot&&ticket.slot.token===ticket.token;
  }
  function cashReadCurrent(ticket){return cashTicketCurrent(ticket)&&ticket.transport===transportRevision()}
  function recoverCashOnly(){
   syncCashContext();if(cashVisible()&&state.cash.status==='idle')refreshCashOnly();
  }
  async function readCashTicket(ticket){
   const s=ticket.slot;
   try{
    for(let attempt=0;attempt<2;attempt++){
     if(!cashReadCurrent(ticket))return;
     try{
      const value=await request('lts_browser_cash_today_v242',{},20000,true,()=>cashReadCurrent(ticket));
      if(!cashReadCurrent(ticket))return;
      s.data=value;s.date=ticket.date;s.sessionGeneration=ticket.session;s.authEpoch=ticket.authEpoch;s.status='ready';return;
     }catch(error){
      if(!cashReadCurrent(ticket))return;
      s.status='error';s.error=String(error.message||error);s.outcome=error?.ltsOutcome||null;s.code=error?.code||null;s.httpStatus=error?.httpStatus||null;
      if(attempt===0&&retryableCashFailure(s)){s.status='loading';s.error=null;continue}
      return;
     }
    }
   }finally{
    if(cashReadCurrent(ticket)){
     publishCashDiagnostic();queueMicrotask(()=>{if(cashReadCurrent(ticket)&&cashVisible())render()});
    }else{
     // A cache-only revision may change during getSession without a UI event.
     // Retire that ticket and queue one current replacement after this RPC ends.
     if(cashTicketCurrent(ticket)){s.token++;s.status='idle';s.data=null}
     recoverCashOnly();
    }
   }
  }
  function refreshCashOnly(force=false){
   syncCashContext();if(!D||N.classList.contains('hidden'))return Promise.resolve(false);
   const s=state.cash;
   if((cashActive&&cashReadCurrent(cashActive))||(cashDemand&&cashReadCurrent(cashDemand)))return cashFlight;
   if(!force&&s.status!=='idle'&&s.status!=='loading')return Promise.resolve(false);
   s.token=(s.token||0)+1;s.status='loading';s.data=null;s.error=null;s.outcome=null;s.code=null;s.httpStatus=null;
   const ticket=cashDemand={slot:s,token:s.token,session:cashGeneration(),authEpoch:cashAuthEpoch,date:day(),revision:cashRevision,transport:transportRevision()};
   queueMicrotask(()=>{if(cashReadCurrent(ticket)&&cashVisible())render()});
   if(!cashFlight){
    cashFlight=Promise.resolve().then(async()=>{
     try{while(cashDemand){const ticket=cashDemand;cashDemand=null;cashActive=ticket;await readCashTicket(ticket)}}
     finally{cashActive=null;cashFlight=null}
     return true;
    });
   }
   return cashFlight;
  }
  async function priorityCash(force=false,serial){
   const reading=refreshCashOnly(force);
   queueMicrotask(()=>{if(serial===dashboardSerial&&cashVisible())render()});
   return reading;
  }
  function startDashboard(force=false,alreadyInvalidated=false){
   syncCashContext();
   if(force&&!alreadyInvalidated){cache.clear();window.__LTS_V227_TRANSPORT?.invalidate?.()}
   const t=day();
   const changed=state.date!==t;
   if(changed){window.__LTS_V227_TRANSPORT?.invalidate?.(false);state.date=t;dashboardSerial++;for(const k of ['cash','wealth','awards','forecast','dashboardReport','planningUI']){state[k].token=(state[k].token||0)+1;state[k].status='idle';state[k].data=null}cache.clear()}
   if(dashboardFlight){
    const waitingSerial=dashboardSerial,waitingSession=cashGeneration(),waitingAuthEpoch=cashAuthEpoch,waitingRevision=cashRevision;
    return(changed||force)?dashboardFlight.then(()=>{
     if(!D||N.classList.contains('hidden')||waitingSerial!==dashboardSerial||waitingSession!==cashGeneration()||waitingAuthEpoch!==cashAuthEpoch||waitingRevision!==cashRevision||t!==day())return;
     return startDashboard(force,true);
    }):dashboardFlight;
   }
   const serial=++dashboardSerial,r=yearRange();
   const job=(async()=>{
    await priorityCash(force,serial);
    if(serial!==dashboardSerial)return;
    // Each section already handles its own error. Keep database-heavy reports
    // sequential so a cold opening cannot exhaust the shared database budget.
    const sections=[
     ()=>loadForecast(force),
     ()=>loadState('wealth','lts_browser_wealth_detail_v242',{},force),
     ()=>loadState('awards','lts_browser_awards_v178',{},force),
     ()=>loadState('dashboardReport','lts_browser_expenses_v229',{p_from:r.from,p_to:r.to},force)
    ];
    for(const section of sections){if(serial!==dashboardSerial)return;await section();}
   })().catch(error=>logError('dashboard_orchestration',error));
   dashboardFlight=job;job.finally(()=>{if(dashboardFlight===job)dashboardFlight=null});return job;
  }
  function cashComplete(s){const x=s.data;return s.status==='ready'&&s.sessionGeneration===cashGeneration()&&s.authEpoch===cashAuthEpoch&&s.date===day()&&x?.as_of===day()&&x.status==='complete'&&x.version==='cash-today-v179-current-canonical'&&[x.cash,x.d0,x.brokerage_available,x.available_total].every(v=>finite(v)!=null)&&Math.abs(total([x.cash,x.d0,x.brokerage_available])-Number(x.available_total))<0.02}
  function kpi(root,label,value,note,newLabel){
   const el=[...root.querySelectorAll('.v168-kpi')].find(x=>normalize(x.querySelector('span')?.textContent).trim()===normalize(label));
   if(!el)return;
   if(newLabel)el.querySelector('span').textContent=newLabel;
   el.querySelector('strong').textContent=money(value);
   if(el.querySelector('small'))el.querySelector('small').textContent=note||'';
  }
  function presentation(data,filtered=false){
   if(!data?.presentation)return null;
   return window.parent.LTSExpensePresentation.build(data.presentation,filtered?(state.hierarchyScope||{}):{});
  }
  function presentationButton(name,scope,value,label=name){
   return '<button type="button" class="v353-open" data-v353-scope="'+escape(JSON.stringify(scope))+'" data-v353-label="'+escape(label)+'" data-v353-total="'+Number(value)+'">'+escape(name)+'</button>';
  }
  function presentationTree(nodes){
   return arr(nodes).map(n=>{
    const key=JSON.stringify(n.scope),moneyButton=presentationButton(money(n.net),n.scope,n.net,n.name);
    const parts=n.compensations>0?'<div class="v353-parts">'+presentationButton('Bruto '+money(n.gross),{...n.scope,sign:'gross'},n.gross,n.name+' · bruto')+' · '+presentationButton('Compensações −'+money(n.compensations),{...n.scope,sign:'compensations'},-n.compensations,n.name+' · compensações')+'</div>':'';
    if(!n.children.length)return '<div class="v353-leaf"><div class="v353-nodehead">'+presentationButton(n.name,n.scope,n.net)+'<b>'+moneyButton+'</b></div>'+parts+'</div>';
    return '<details class="v353-node" data-v353-node="'+escape(key)+'"'+(state.hierarchyExpanded?.has(key)?' open':'')+'><summary><span>'+escape(n.name)+'</span><b>'+moneyButton+'</b></summary>'+parts+'<div class="v353-children">'+presentationTree(n.children)+'</div></details>';
   }).join('');
  }
  function presentationPanel(model){
   const s=model.summary,scope=model.scope,option=(xs,value)=>'<option value="">Todos</option>'+arr(xs).map(o=>'<option value="'+escape(o.key)+'"'+(value===o.key?' selected':'')+'>'+escape(o.label)+'</option>').join('');
   const metric=(label,value,sign,totalValue=value)=>'<button type="button" class="v353-open v353-metric" data-v353-scope="'+escape(JSON.stringify({...scope,sign}))+'" data-v353-label="'+escape(label)+'" data-v353-total="'+Number(totalValue)+'"><span>'+label+'</span><strong>'+money(value)+'</strong></button>';
   return '<div class="v353-presentation"><div class="v353-metrics">'+metric('Gasto bruto',s.gross,'gross')+metric('Compensações',s.compensations,'compensations',-s.compensations)+metric('Líquido',s.net,'net')+'</div><div class="v353-controls"><label>Organizar por<select data-v353-view>'+[['type','Tipo de gasto'],['property','Bem relacionado'],['tax','Tributos']].map(([k,v])=>'<option value="'+k+'"'+(scope.view===k?' selected':'')+'>'+v+'</option>').join('')+'</select></label><details class="v353-filters"'+(state.hierarchyFiltersOpen?' open':'')+'><summary>Filtros complementares</summary><div>'+[['property','Bem'],['person','Pessoa'],['center_cost','Centro de custo']].map(([k,label])=>'<label>'+label+'<select data-v353-filter="'+k+'">'+option(model.dimensions?.[k],scope[k])+'</select></label>').join('')+'</div></details></div><p class="v353-tree-note">Macrogrupo → Grupo → Categoria. Clique em um valor para consultar os lançamentos.</p><div class="v353-tree">'+(model.nodes.length?presentationTree(model.nodes):'<p>Nenhum lançamento neste filtro.</p>')+'</div></div>';
  }

  function reportRank(data,limit=99,includeCoverage=false){
   if(data?.presentation){try{const model=presentation(data);return '<div class="v178-rank">'+model.nodes.filter(n=>includeCoverage||n.name!=='Sem composição individual').slice(0,limit).map((n,i)=>'<div class="v178-rankrow"><span>'+(i+1)+'</span><div>'+presentationButton(n.name,n.scope,n.net)+'</div>'+presentationButton(money(n.net),n.scope,n.net,n.name)+'</div>').join('')+'</div>'}catch{return '<p>Não foi possível conferir os grupos deste período.</p>'}}
   const list=arr(data?.management_groups).filter(g=>includeCoverage||!['Faturas conciliadas pelo total','Faturas sem composição individual'].includes(g.name)).slice(0,limit),max=Math.max(1,...list.map(g=>Math.abs(g.total)));
   return '<div class="v178-rank">'+list.map((g,i)=>'<div class="v178-rankrow"><span>'+(i+1)+'</span><div><button type="button" class="v178-open title" data-group="'+escape(g.name)+'">'+escape(window.LTSCategoryDisplay.category(g.name))+'</button><i><u style="width:'+Math.max(1,Math.abs(g.total)/max*100)+'%"></u></i></div><button type="button" class="v178-open amount" data-group="'+escape(g.name)+'">'+money(g.total)+'</button></div>').join('')+'</div>';
  }
  function dashboard178(){
   const ds=v168.dashboard;ds.started=true;ds.loading=false;ds.error=null;ds.detailErrors=[];
   ds.data=ds.data||{};
   ds.data.planningUI=state.planningUI.status==='ready'&&state.planningUI.date===day()?state.planningUI.data:null;
   if(state.wealth.data)ds.data.wealth=state.wealth.data;
   if(state.dashboardReport.data)ds.data.expense=state.dashboardReport.data;
   const f=state.forecast.date===day()?state.forecast.data:null;
   ds.data.flow=f?structuredClone(f):{flow:{current_future:{days:[],events:[]}}};
   if(cashComplete(state.cash)){
    const days=ds.data.flow.flow.current_future.days.filter(d=>d.date!==day());days.unshift(observedTodayForForecast(state.cash.data.day,f));ds.data.flow.flow.current_future.days=days;
   }
   const saved=v175.expense.data;
   v175.expense.data=state.dashboardReport.data||null;
   let html;try{html=previousDashboard()}finally{v175.expense.data=saved}
   const t=template(html),root=t.content.querySelector('.v168-dashboard');if(!root)return html;
   root.querySelectorAll('.v168-loadstatus').forEach(x=>x.remove());
   const complete=cashComplete(state.cash),c=complete?state.cash.data:null;
   const pendingCash=state.cash.status==='idle'||state.cash.status==='loading';
   const note=pendingCash?'Carregando…':complete?'Calculado para '+dateLabel(c.as_of):'Indisponível';
   kpi(root,'Contas correntes hoje',c?.cash,note);
   kpi(root,'Aplicações D0',c?.d0,complete?'Disponibilidade de curto prazo':'Aguardando posição completa');
   kpi(root,'RSUs já disponíveis',c?.brokerage_available,complete?'Ações disponíveis + saldo em corretora':'Aguardando posição completa');
   kpi(root,'FGTS',c?.fgts,'Recurso restrito');
   kpi(root,'Total disponível hoje',c?.available_total,complete?'Contas, aplicações e ações disponíveis':'Indisponível');
   const warnings=[];
   if(!complete)warnings.push(pendingCash?'Atualizando a posição de caixa…':'Não foi possível obter a posição completa de caixa.');
   if(state.wealth.status==='error')warnings.push('Posições patrimoniais não atualizadas.');
   if(state.planningUI.status==='error')warnings.push('Planejamento não atualizado.');
   if(state.dashboardReport.status==='error')warnings.push('Relatório de despesas não atualizado.');
   if(warnings.length)(root.querySelector('.v168-pagehead')||root.firstElementChild)?.insertAdjacentHTML('afterend','<div class="v178-notice" role="status">'+escape(warnings.join(' '))+' <button class="v178-refresh">Tentar novamente</button></div>');
   const cards=[...root.querySelectorAll('.v168-card')];
   const forecastReady=!!f&&f.complete!==false&&arr(f.flow?.current_future?.days).length>1&&state.forecast.date===day();
   if(!forecastReady){for(const card of cards.filter(x=>/Evolução projetada|O que exige decisão/.test(x.querySelector('h2')?.textContent||''))){const head=card.querySelector('.v168-cardhead')?.outerHTML||'';card.innerHTML=head+'<div class="v178-empty" role="status">'+(state.forecast.status==='loading'?'<span class="v242-spinner" style="display:inline-block;vertical-align:middle;margin-right:8px" aria-hidden="true"></span>Carregando projeção…':(state.forecast.status==='idle'?'Aguardando carregamento da projeção…':(f?.coverage?.complete===false?'Projeção incompleta. Atualize para conferir todo o período.':f?.complete===false?'Projeção consolidada incompleta: C6 em conferência. Os demais bancos continuam disponíveis no fluxo.':'Projeção indisponível.')))+'</div><button class="v178-refresh">Atualizar projeção</button>'}}
   else if(state.forecast.status!=='ready'){
    const last=arr(f.flow.current_future.days).at(-1)?.date;const title=cards.find(x=>/Evolução projetada/.test(x.querySelector('h2')?.textContent||''))?.querySelector('h2');if(title)title.textContent='Evolução projetada até '+dateLabel(last);
    cards.find(x=>/Evolução projetada/.test(x.querySelector('h2')?.textContent||''))?.insertAdjacentHTML('beforeend','<div class="v178-notice">Projeção disponível até '+escape(dateLabel(last))+'. O restante ainda não foi atualizado.</div>');
   }
   const exp=cards.find(x=>/Principais grupos/.test(x.querySelector('h2')?.textContent||''));
   if(exp){const head=exp.querySelector('.v168-cardhead')?.outerHTML||'';exp.innerHTML=head+(state.dashboardReport.data?reportRank(state.dashboardReport.data,12):'<div class="v178-empty">'+(state.dashboardReport.status==='error'?'Despesas indisponíveis.':'Carregando despesas…')+'</div>');exp.dataset.v178Scope='dashboard'}
   kpi(root,'Total de despesas do período',state.dashboardReport.data?.summary?.selected_total,dateLabel(yearRange().from)+' a '+dateLabel(yearRange().to));
   publishCashDiagnostic();return t.innerHTML;
  }
  function expenses178(){
   const html=previousExpenses(),t=template(html),root=t.content.querySelector('.v168-expenses');if(!root)return html;
   root.querySelectorAll('.v175-property,.v174-property-note,.v175-sale-strip,.v174-audit-strip').forEach(e=>e.remove());
   root.querySelectorAll('.v175-open-issues').forEach(e=>{e.innerHTML='<div class="v178-notice">Há movimentações aguardando confirmação. Consulte Atualizações.</div>'});
   root.querySelectorAll('.v175-coverage,.v172-coverage,.v174-coverage,.v171-reconciliation').forEach(e=>e.remove());
   const data=v175.expense.data,tab=v168.expense.tab;
   if(['overview','categories'].includes(tab)&&Array.isArray(data?.management_groups)){
    const cards=[...root.querySelectorAll('.v168-card')],target=tab==='categories'?root.querySelector('.v175-categories'):cards.find(x=>/maiores grupos/i.test(x.querySelector('h2')?.textContent||''));
    if(target){
     const head=target.querySelector('.v168-cardhead')?.outerHTML||'';
     if(data.presentation){try{target.innerHTML=head+presentationPanel(presentation(data,true));}catch{target.innerHTML=head+'<p role="alert">Não foi possível conferir os totais. Atualize o relatório.</p><button class="v168-btn v353-retry">Atualizar relatório</button>';}}
     else target.innerHTML=head+reportRank(data,tab==='overview'?15:99,true);
     target.dataset.v178Scope='expenses';
    }
   }
   root.querySelectorAll('.v168-cardhead span').forEach(e=>{if(/^Composição auditada$/i.test(e.textContent.trim()))e.textContent='Composição'});
   return t.innerHTML;
  }
  let sequence=0,lastFocus=null,cipoModal=null,cipoReturn=null;
  const detailHistory=[];
  const apartment='Apartamento · CIPÓ 396';
  function closeDetail(){sequence++;detailHistory.length=0;state.detail=null;cipoReturn=null;document.getElementById('v178Drawer')?.remove();if(lastFocus?.isConnected)lastFocus.focus();lastFocus=null}
  function closeCipo(){const current=cipoModal;cipoModal=null;current?.host.remove();if(current?.badge)current.badge.hidden=current.badgeHidden;if(current?.focus?.isConnected)current.focus.focus()}
  function cipoCurrent(c){return c===cipoModal&&c.host.isConnected&&c.route===V&&c.session===cashGeneration()&&c.epoch===cashAuthEpoch&&c.day===day()&&!!D&&!N.classList.contains('hidden')}
  async function openCipoReconciliation(wealth,force=false){
   closeCipo();closeDetail();
   if(force){cache.clear();window.__LTS_V227_TRANSPORT?.invalidate(false);}
   const host=document.createElement('div');host.id='v359Cipo';host.className='v168-modal-bg';
   host.innerHTML='<section class="v168-modal v359-property" role="dialog" aria-modal="true" aria-labelledby="v359CipoTitle"><header><div><h2 id="v359CipoTitle">CIPÓ 396 · composição dos gastos</h2><p>Da aquisição às despesas do imóvel.</p></div><button type="button" class="v168-btn v359-close" aria-label="Fechar composição de Cipó">×</button></header><div class="v359-content" role="status">Carregando lançamentos…</div></section>';
   const c=cipoModal={host,focus:document.activeElement,wealth,route:V,session:cashGeneration(),epoch:cashAuthEpoch,day:day(),range:{from:'2013-10-10',to:day()}};
   c.badge=window.parent.document.getElementById('release-badge-v183');c.badgeHidden=c.badge?.hidden;if(c.badge)c.badge.hidden=true;
   document.body.appendChild(host);host.querySelector('.v359-close').onclick=closeCipo;
   host.onclick=e=>{if(e.target===host)closeCipo()};
   host.addEventListener('keydown',e=>{if(e.key==='Escape')closeCipo();if(e.key==='Tab'){const els=[...host.querySelectorAll('button,summary,a[href],input')].filter(x=>x.getClientRects().length),first=els[0],last=els.at(-1);if(e.shiftKey&&document.activeElement===first){e.preventDefault();last?.focus()}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first?.focus()}}});
   host.querySelector('.v359-close').focus();
   try{
    let currentWealth=null;
    try{currentWealth=await request('lts_browser_wealth_detail_v242',{},22000,force,()=>cipoCurrent(c));}catch{}
    if(!cipoCurrent(c))return;c.wealth=currentWealth||{};
    const rows=[],keys=new Set();let offset=0,revision=null,packet;
    do{
     packet=await request('lts_browser_expense_scope_detail_v374',{p_from:c.range.from,p_to:c.range.to,p_scope:{property:'cipo396'},p_offset:offset,p_limit:10000,p_query:null},22000,force,()=>cipoCurrent(c));
     if(!cipoCurrent(c))return;
     if((revision!==null&&revision!==packet.revision)||!packet.revision||packet.offset!==offset||!Array.isArray(packet.rows))throw Error('Changed property page');revision=packet.revision;
     for(const r of packet.rows){if(!r.key||keys.has(r.key))throw Error('Duplicate property identity');keys.add(r.key);rows.push(r)}
     const next=packet.next_offset;if(next!==null&&(!Number.isInteger(next)||next<=offset))throw Error('Invalid property page');offset=next;
    }while(offset!==null);
    const model=window.parent.LTSPropertyReconciliation.build(c.wealth,{...packet,rows},c.range);if(!cipoCurrent(c))return;
    drawCipo(c,model);
   }catch{if(cipoCurrent(c)){const content=host.querySelector('.v359-content');content.innerHTML='<p>Não foi possível conferir os gastos do imóvel. Atualize a consulta.</p><button type="button" class="v168-btn v359-retry">Tentar novamente</button>';content.querySelector('button').onclick=()=>openCipoReconciliation(wealth,true)}}
  }
  function drawCipo(c,m){
   const links=[],link=(label,value,scope,range=m.range,count=null)=>{const id=links.push({label,value,scope,range})-1;return'<button type="button" class="v359-drill" data-v359-drill="'+id+'"><span>'+escape(label)+(count===null?'':'<small>'+count+' registros</small>')+'</span><b>'+money(value)+'</b><span aria-hidden="true">→</span></button>'};
   const line=(label,value)=>'<div class="v359-line"><span>'+escape(label)+'</span><b>'+money(value)+'</b></div>';
   const originRow=r=>'<details class="v359-origin"><summary>Origem</summary><p>'+escape(r.file)+'<br>'+escape(r.sheet)+' · linha '+escape(r.row)+(r.cell?' · '+escape(r.cell):'')+'<br>Valor original: '+escape(r.original_value??r.signed_amount)+'</p></details>';
   const sourceTable=rows=>'<div class="v359-table-scroll"><table class="v168-table"><thead><tr><th>Data</th><th>Descrição original</th><th>Valor</th></tr></thead><tbody>'+rows.map(r=>'<tr><td>'+escape(dateLabel(r.date))+'</td><td>'+escape(r.description)+(Number(r.signed_amount)===0?'<small>Linha sem valor movimentado</small>':'')+originRow(r)+'</td><td>'+money(r.signed_amount)+'</td></tr>').join('')+'</tbody></table></div>';
   let html='<p class="v359-period">'+escape(dateLabel(m.range.from)+' a '+dateLabel(m.range.to))+'</p>'+link('Todos os gastos classificados',m.total,m.scope,m.range,m.count)+'<div class="v359-groups">'+m.groups.map(g=>'<section class="v359-group">'+link(g.label,g.total,g.scope,m.range,g.count)+'<details><summary>Consultar categorias</summary>'+g.categories.map(x=>link(x.label,x.total,x.scope,m.range,x.count)).join('')+'</details></section>').join('')+'</div>';
   const b=m.bridge;
   if(!b)html+='<p class="v168-note warn">A comparação com o resumo do Excel precisa ser atualizada. Os lançamentos classificados estão disponíveis acima.</p>';
   else{
    const a=b.acquisition,w=b.works,after=new Date(b.cutoff+'T12:00:00Z');after.setUTCDate(after.getUTCDate()+1);
    html+='<section class="v359-bridge"><h3>Da aquisição no Excel aos gastos classificados</h3>'+line('Aquisição no resumo do Excel',a.sourceTotal)+link('Parcelas incluídas no resumo · até '+dateLabel(b.cutoff),a.loanPrefix.total,a.loanPrefix.scope,{from:m.range.from,to:b.cutoff},a.loanPrefix.count)+link('Somar parcelas após '+dateLabel(b.cutoff),a.loanTail.total,a.loanTail.scope,{from:after.toISOString().slice(0,10),to:m.range.to},a.loanTail.count)+line('Retirar aportes do consórcio fora das despesas',-a.cashTotal)+line('Aquisição nos gastos classificados',a.canonical)+'<details class="v359-source-cash"><summary>Consultar aportes do consórcio · '+money(a.cashTotal)+'</summary><p>Aportes de conta corrente presentes no resumo do imóvel e fora das despesas de consumo. O sinal negativo é o ajuste de custo registrado na planilha.</p>'+sourceTable(a.cashRows)+'</details>'+link('Consórcio no cartão · já incluído na aquisição',a.cardTotal,a.cardScope)+'</section>';
    html+='<section class="v359-bridge"><h3>Do resumo da obra aos gastos classificados</h3>'+line('Obra no resumo do Excel',w.sourceTotal)+line('Retirar fórmula repetida de móveis',-w.duplicate)+line('Componentes únicos no Excel',w.unique)+line('Obra nos gastos classificados',w.canonical);
    if(Math.abs(w.gap)>=0.005)html+='<p class="v168-note warn v359-gap"><b>'+money(Math.abs(w.gap))+'</b> '+(w.gap>0?'do Excel ainda sem vínculo suficiente com os gastos classificados.':'acima da composição identificada no Excel.')+' Os valores permanecem separados.</p><details class="v359-unlinked"><summary>Conferir origem da diferença</summary><p>As linhas abaixo exigem comprovação do vínculo. Coincidência de data e valor não comprova outro pagamento nem autoriza reclassificação.</p>'+sourceTable(w.unlinkedRows)+'</details>';
    html+='<details class="v359-components"><summary>Consultar os '+w.components.length+' componentes do Excel</summary><div class="v359-table-scroll"><table class="v168-table"><thead><tr><th>Descrição original</th><th>Valor</th></tr></thead><tbody>'+w.components.map(r=>'<tr><td>'+escape(r.description)+'<small>'+escape(r.origin)+'</small></td><td>'+money(r.source_paid)+'</td></tr>').join('')+'</tbody></table></div></details></section>';
    html+='<details class="v359-origin v359-summary-origin"><summary>Origem e precisão dos resumos</summary><p>'+escape(b.sourceFile)+' · '+escape(b.sourceSheet)+'<br>Aquisição: J5; financiamento incluído: D3; consórcios: D13, D14 e D41; obra: J31.<br>Fórmulas conferidas: '+escape(w.duplicateCells.join(', '))+'.</p><p>O corte do financiamento indica a última parcela incluída em D3. Não é a data da posição de mercado ou do saldo devedor. As cópias dos arquivos corroboram a mesma base e são contadas uma vez.</p>'+b.copies.map(r=>'<p>'+escape(r.file)+'<br>SHA256 '+escape(r.sha256)+'</p>').join('')+'<p>Valores originais da obra: resumo '+escape(w.sourceTotal)+'; componentes únicos '+escape(w.unique)+'; gastos classificados '+escape(w.canonical)+'. As frações de centavo da planilha foram preservadas; a comparação é apresentada em reais.</p></details>';
   }
   html+='<p class="v359-footnote">Gastos históricos não representam valor de mercado, amortização do principal ou saldo para quitação.</p>';
   const content=c.host.querySelector('.v359-content');content.removeAttribute('role');content.innerHTML=html;
   content.querySelectorAll('[data-v359-drill]').forEach(button=>button.onclick=()=>{if(!cipoCurrent(c))return;const l=links[Number(button.dataset.v359Drill)],back={wealth:c.wealth,route:c.route,session:c.session,epoch:c.epoch,day:c.day};closeCipo();openDetail(l.label,null,l.range,l.value,{scope:l.scope,visibleRows:300});cipoReturn=back});
  }
  function rememberDetail(){
   const d=state.detail,host=document.getElementById('v178Drawer');if(!d||!host)return;
   detailHistory.push({scope:d.scope||null,visibleRows:d.visibleRows||300,group:d.group,subgroup:d.subgroup,range:{...d.range},expected:d.expected,archive:!!d.archive,archiveComponent:d.archiveComponent||null,query:d.query||'',scrollTop:host.querySelector('.v178-detail-scroll')?.scrollTop||0,allRowsVisible:host.querySelector('.v178-detail-scroll')?.hidden===false,route:d.route});
  }
  function beginDetail(group,subgroup,range,restore,archive=false,archiveComponent=null){
   if(!state.detail){lastFocus=document.activeElement;detailHistory.length=0;}
   else if(!restore&&(state.detail.group!==group||state.detail.subgroup!==subgroup||!!state.detail.archive!==archive||(state.detail.archiveComponent||null)!==archiveComponent))rememberDetail();
   return {scope:restore?.scope||null,visibleRows:restore?.visibleRows||300,query:restore?.query||'',restoreScroll:restore?.scrollTop??null,restoreAllRows:restore?.allRowsVisible===true,route:V};
  }
  function backDetail(){
   const parent=detailHistory.pop();
   if(!parent){const back=cipoReturn;closeDetail();if(back&&back.route===V&&back.session===cashGeneration()&&back.epoch===cashAuthEpoch&&back.day===day())openCipoReconciliation(back.wealth);return;}
   if(parent.route!==V){closeDetail();return;}
   if(parent.archive)return openArchive(parent.range,parent.archiveComponent,parent);
   return openDetail(parent.group,parent.subgroup,parent.range,parent.expected,parent);
  }
  // The existing lightweight auth client does not expose auth subscriptions.
  // Preserve its methods and promises while clearing private detail context.
  for(const name of ['signOut','signInWithPassword']){
   const original=S.auth[name];
   if(typeof original==='function')S.auth[name]=function(...args){closeCipo();closeDetail();state.hierarchyScope={};state.hierarchyExpanded=new Set();state.hierarchyFiltersOpen=false;return original.apply(this,args)};
  }
  function shellDetail(){
   document.getElementById('v178Drawer')?.remove();
   const d=state.detail,host=document.createElement('div');host.id='v178Drawer';
   const parent=detailHistory.at(-1),backLabel=parent?(parent.subgroup||parent.group||'Detalhamento'):(d.route||'Despesas');
   host.innerHTML='<div class="v178-backdrop"></div><aside class="v178-drawer" role="dialog" aria-modal="true" aria-labelledby="v178DetailTitle"><header><div style="min-width:0"><div style="margin-bottom:8px"><button type="button" class="v168-btn v344-back" aria-label="Voltar para '+escape(backLabel)+'">← Voltar</button></div><div class="v344-context" style="font-size:12px;line-height:1.4;color:#64748b;margin-bottom:4px;overflow-wrap:anywhere">'+escape(backLabel)+'</div><h2 id="v178DetailTitle">'+escape(window.LTSCategoryDisplay.category(d.subgroup||d.group||'Lançamentos'))+'</h2><small>'+escape(dateLabel(d.range.from)+' a '+dateLabel(d.range.to))+'</small></div><button class="v178-close" aria-label="Fechar">×</button></header><div class="v178-detail-summary"></div><div class="v178-components"></div><div class="v178-filter"><input type="search" placeholder="Filtrar histórico, conta, cartão ou pessoa" value="'+escape(d.query||'')+'" disabled></div><div class="v178-detail-scroll" tabindex="0"><table><thead><tr><th>Data / mês</th><th>Histórico</th><th>Conta ou cartão</th><th>Pessoa</th>'+ (d.scope?'<th>Bem</th><th>Centro de custo</th>':'')+'<th>Valor</th></tr></thead><tbody></tbody></table></div><footer><span role="status">Carregando lançamentos…</span><button class="v178-retry" hidden>Atualizar lista</button></footer></aside>';
   document.body.appendChild(host);
   host.querySelector('.v178-close').onclick=closeDetail;host.querySelector('.v178-backdrop').onclick=closeDetail;
   host.querySelector('.v344-back').onclick=backDetail;
   host.querySelector('.v178-filter input').oninput=e=>{if(state.detail){state.detail.query=e.target.value;state.detail.visibleRows=300;drawRows()}};
   host.querySelector('.v178-retry').onclick=()=>d.composition?openComposition(d.parent,d.range,true):d.archive?openArchive(d.range,d.archiveComponent,{query:d.query}):openDetail(d.group,d.subgroup,d.range,d.expected,{query:d.query,scope:d.scope,visibleRows:d.visibleRows});
   host.addEventListener('keydown',e=>{if(e.key==='Escape')closeDetail();if(e.key==='Tab'){const els=[...host.querySelectorAll('button:not([hidden]),input:not(:disabled),[tabindex="0"]')];const first=els[0],last=els.at(-1);if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus()}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus()}}});
   host.querySelector('.v344-back').focus();
  }
  function drawRows(){
   const d=state.detail,host=document.getElementById('v178Drawer');if(!d||!host)return;
   if(d.composition)return drawComposition();
   const q=normalize(d.query),matched=d.rows.filter(r=>!q||normalize([r.description,r.account_source,r.beneficiary,r.component,r.category,r.current_category,r.property_code,r.property_code==='cipo396'?'CIPÓ 396':'',r.center_cost].join(' ')).includes(q)),rows=d.scope?matched.slice(0,d.visibleRows||300):matched,tbody=host.querySelector('tbody');
   tbody.innerHTML=rows.map(r=>'<tr data-row-key="'+escape(r.key)+'"><td>'+escape(r.date_kind==='day'?dateLabel(r.date):r.date_kind==='historical'?'Histórico':monthLabel(r.period))+(r.date_kind==='day'&&r.period&&r.date?.slice(0,7)!==r.period.slice(0,7)?'<small>Fatura '+escape(monthLabel(r.period))+'</small>':'')+'</td><td><b>'+escape(r.description)+'</b>'+(d.group===apartment&&!d.subgroup?'<small>'+escape(r.component||'')+'</small>':'')+(d.scope?'<small>'+escape(r.taxonomy?.category||r.current_category||'')+'</small><details class="v353-row-origin"><summary>Origem</summary><p>Classificação original: '+escape(r.original_category||r.current_category||'—')+'<br>'+escape(r.source_audit?.file||r.source_identity?.sheet||r.source_table||'Fonte registrada')+'<br>'+escape(r.source_audit?.sheet||r.source_identity?.sheet||'')+((r.source_audit?.rows||r.source_identity?.rows)?' · linhas '+escape(r.source_audit?.rows||r.source_identity?.rows):'')+'<br>Referência: '+escape(r.source_ref||'—')+'</p></details>':'')+(r.composition?'<button type="button" class="v168-btn v346-open-composition" data-composition-key="'+escape(r.key)+'">Ver composição</button>':'')+'</td><td>'+escape(r.account_source||'—')+'</td><td>'+escape(r.beneficiary||'—')+'</td>'+ (d.scope?'<td>'+escape(r.property_code==='cipo396'?'CIPÓ 396':r.property_code==='other_property'?'Outro imóvel':'—')+'</td><td>'+escape(r.center_cost||'—')+'</td>':'')+'<td>'+money(r.amount)+'</td></tr>').join('')||'<tr><td colspan="'+(d.scope?7:5)+'">'+(d.loading?'Carregando…':'Nenhum lançamento neste filtro.')+'</td></tr>';
   tbody.querySelectorAll('[data-composition-key]').forEach(b=>b.onclick=()=>openComposition(d.rows.find(r=>r.key===b.dataset.compositionKey),d.range));
   host.querySelector('footer span').textContent=d.error||((q?rows.length+' exibidos · ':'')+d.rows.length+' de '+(d.count??'…')+' itens'+(d.loading?' · carregando':' · lista completa'));
   host.querySelector('.v353-more')?.remove();
   if(d.scope&&matched.length>rows.length){
    host.querySelector('footer span').textContent=rows.length+' exibidos de '+matched.length+(q?' neste filtro':' itens')+(d.loading?' · carregando':'');
    const more=document.createElement('button');more.className='v168-btn v353-more';more.textContent='Mostrar mais';more.onclick=()=>{d.visibleRows=(d.visibleRows||300)+300;drawRows()};host.querySelector('footer').appendChild(more);
   }
   host.querySelector('.v178-filter input').disabled=d.loading;
   host.querySelector('.v178-retry').hidden=!d.error;
   host.querySelector('.v178-detail-summary').innerHTML='<span>'+escape(d.archive?'Investimentos históricos documentados':'Total do período')+'<b>'+money(d.total)+'</b></span><span>Itens<b>'+(d.count??'—')+'</b></span>';
   if(!d.loading&&d.restoreScroll!=null){host.querySelector('.v178-detail-scroll').scrollTop=d.restoreScroll;d.restoreScroll=null;}
  }
  function drawComponents(){
   const d=state.detail,host=document.getElementById('v178Drawer');if(!d||!host||d.subgroup||d.archive)return;
   const box=host.querySelector('.v178-components'),cs=d.components||[];
   if(d.group===apartment){
    const standard=['Aquisição do imóvel','Obra e reforma','Custos de moradia','Impostos do imóvel'];const names=[...standard,...cs.map(c=>c.name).filter(n=>!standard.includes(n))];
    box.innerHTML=names.map(n=>{const c=cs.find(x=>x.name===n);return'<button data-component="'+escape(n)+'"><span>'+escape(n)+'</span><b>'+money(c?.total||0)+'</b></button>'}).join('')+'<button class="v178-archive"><span>Histórico de investimentos</span><small>Obra e consórcio</small></button><button class="v178-all-rows">Ver todos os lançamentos do período</button>';
    host.querySelector('.v178-detail-scroll').hidden=!d.restoreAllRows;host.querySelector('.v178-filter').hidden=!d.restoreAllRows;
    box.querySelector('.v178-all-rows').onclick=()=>{host.querySelector('.v178-detail-scroll').hidden=false;host.querySelector('.v178-filter').hidden=false};
    box.querySelector('.v178-archive').onclick=()=>openArchive(d.range);
   }else if(cs.length>1)box.innerHTML=cs.map(c=>'<button data-component="'+escape(c.name)+'"><span>'+escape(window.LTSCategoryDisplay.category(c.name))+'</span><b>'+money(c.total)+'</b></button>').join('');
   box.querySelectorAll('[data-component]').forEach(b=>b.onclick=()=>openDetail(d.group,b.dataset.component,d.range,cs.find(c=>c.name===b.dataset.component)?.total));
  }
  async function openDetail(group,subgroup,range,expected,restore=null){
   const context=beginDetail(group,subgroup,range,restore),token=++sequence;
   const d=state.detail={...context,group,subgroup,range:{...range},expected,rows:[],loading:true,error:null,count:null,total:null};shellDetail();drawRows();
   try{
    let offset=0,revision=null,keys=new Set();
    do{
     const limit=d.scope||group==null||group==='__card_total__'||group==='__account_total__'?10000:500;
     const p=await request(d.scope?'lts_browser_expense_scope_detail_v374':'lts_browser_expense_detail_v374',d.scope?{p_from:range.from,p_to:range.to,p_scope:d.scope,p_offset:offset,p_limit:limit,p_query:null}:{p_from:range.from,p_to:range.to,p_group:group,p_subgroup:subgroup||null,p_offset:offset,p_limit:limit,p_query:null},22000);
     if(token!==sequence)return;
     if(revision&&p.revision!==revision)throw Error('Os dados mudaram durante a leitura. Atualize a lista.');revision=p.revision;
     for(const row of arr(p.rows)){if(keys.has(row.key))throw Error('A lista precisa ser atualizada antes da conferência.');keys.add(row.key);d.rows.push(row)}
     d.total=p.total;d.count=p.row_count;d.components=p.components;
     offset=p.next_offset;drawRows();if(p.offset===0)drawComponents();
    }while(offset!=null);
    if(d.rows.length!==d.count||Math.abs(total(d.rows.map(x=>x.amount))-d.total)>0.02)throw Error('A lista não fechou com o total. Atualize antes de conferir.');
    if(finite(expected)!=null&&Math.abs(d.total-expected)>0.02)throw Error('O total mudou desde a leitura do relatório. Atualize o relatório.');
   }catch(e){if(token===sequence)d.error=d.scope?'Não foi possível conferir esta lista. Atualize o relatório antes de usar este total.':String(e.message||e)}
   finally{if(token===sequence){d.loading=false;drawRows()}}
  }
  function compositionOrigin(r){
   const x=r.source||{},doc=r.document;
   if(x.kind==='bank_invoice_pdf')return '<details class="v346-origin"><summary>Origem</summary><p>'+escape(x.file||'Fatura original')+'<br>Página '+escape(x.page)+' · coluna '+escape(x.column)+' · registro '+escape(x.row)+'<br>Descrição no documento: '+escape(x.description||r.description)+'<br>Classificação do emissor: '+escape(r.original_category||'Não informada')+'<br>Data do documento: '+escape(dateLabel(x.date))+(doc?.purchase_day_month?'<br>Data da compra no documento: '+escape(doc.purchase_day_month)+(doc.purchase_date?'':' · ano não informado'):'')+(doc?.installment_number?'<br>Parcela '+escape(doc.installment_number)+'/'+escape(doc.installments):'')+'<br>Vencimento da fatura: '+escape(dateLabel(doc?.invoice_due_date))+'</p></details>';
   return '<details class="v346-origin"><summary>Origem</summary><p>'+escape(x.file||'Planilha original')+'<br>'+escape(x.sheet||'')+' · linha '+escape(x.row||'')+'<br>Descrição original: '+escape(x.description||r.description)+'<br>Classificação original: '+escape(r.original_category||'—')+'<br>Data da planilha ('+escape(x.date_cell||'')+'): '+escape(dateLabel(x.date))+'<br>Valor original ('+escape(x.amount_cell||'')+'): '+money(r.original_amount)+(x.amount_formula?'<br>Soma ou fórmula registrada: '+escape(x.amount_formula):'')+'</p>'+(doc?'<p>Documento: '+escape(doc.source_file)+' · linha '+escape(doc.source_line)+'<br>'+escape(doc.description||'')+'<br>Compra: '+escape(dateLabel(doc.purchase_date))+(doc.installment_number?'<br>Parcela '+escape(doc.installment_number)+'/'+escape(doc.installments):'')+(Number(r.original_amount)!==Number(r.amount)?'<br>Valor comprovado: '+money(r.amount):'')+'</p>':'')+'</details>';
  }
  function compositionDate(r){return r.date_label||dateLabel(r.date);}
  function compositionDateKind(r){return r.date_kind==='purchase_day_month'?'Ano não informado':r.date_kind==='document'?'Data do documento':r.date_kind==='purchase'?'Compra comprovada':'Data da planilha';}
  function compositionReconciliation(data){
   const b=data?.reconciliation;
   if(b?.status==='documented_cycle_net_match'){
    const w=b.workbook,rs=[...(w?.parent_rows||[]),...(w?.adjustment_rows||[])];
    const intro='Composição de '+Number(b.document_count)+' fatura'+(Number(b.document_count)===1?'':'s')+'. Registro selecionado: '+money(b.selected_total)+'.';
    const amounts=Number(b.adjustments_total)!==0?'Registros de '+money(b.original_total)+' com ajustes de '+money(b.adjustments_total)+': faturas de '+money(b.net_total)+'.':'';
    return '<p class="v346-cycle-scope">'+intro+'</p>'+(amounts?'<p class="v346-document-reconciliation">'+amounts+'</p>':'')+'<details class="v346-origin"><summary>Origem dos registros</summary><p>'+escape(w?.file||'Planilha original')+'<br>'+escape(w?.sheet||'')+' · linhas '+escape(rs.join(', '))+'</p>'+arr(b.members).map(r=>'<p>'+escape(dateLabel(r.date))+' · '+escape(r.description)+' · '+escape(r.account_source)+' · '+money(r.amount)+'</p>').join('')+'</details>';
   }
   if(b?.status!=='documented_net_match')return '';const w=b.workbook,rs=[...(w?.parent_rows||[]),...(w?.adjustment_rows||[])];
   return '<p class="v346-document-reconciliation">Consolidado de '+money(b.original_total)+' com ajuste de '+money(b.adjustments_total)+': fatura de '+money(b.net_total)+'.</p><details class="v346-origin"><summary>Origem do ajuste</summary><p>'+(w?escape(w.file)+'<br>'+escape(w.sheet)+' · linhas '+escape(rs.join(', ')):'Registros originais do histórico')+'</p>'+((b.adjustments||[]).map(a=>'<p>'+escape(dateLabel(a.date))+' · '+money(a.amount)+'</p>').join(''))+'</details>';
  }
  function drawComposition(){
   const d=state.detail,host=document.getElementById('v178Drawer');if(!d||!host)return;
   const q=normalize(d.query),rows=d.rows.filter(r=>!q||normalize([r.description,r.account_source,r.last4,r.category,r.source?.sheet,r.document?.description].join(' ')).includes(q));
   const pdfSources=d.rows.length>0&&d.rows.every(r=>r.source?.kind==='bank_invoice_pdf');
   host.querySelector('thead th:nth-child(4)').textContent=pdfSources?'Classificação do emissor':'Classificação';host.querySelector('.v178-detail-scroll').classList.add('v346-composition');
   host.querySelector('tbody').innerHTML=rows.map(r=>'<tr data-row-key="'+escape(r.key)+'"><td>'+escape(compositionDate(r))+'<small>'+escape(compositionDateKind(r))+'</small></td><td><b>'+escape(r.document?.description||r.description)+'</b>'+(r.source?.amount_formula?'<small>Soma registrada na planilha</small>':'')+compositionOrigin(r)+'</td><td>'+escape(r.account_source)+(r.last4?' · '+escape(r.last4):'')+'<small>Fatura '+escape(monthLabel(r.period))+'</small></td><td>'+escape(pdfSources?String(r.original_category||'Não informada').split('.')[0].trim():window.LTSCategoryDisplay.category(r.category))+'</td><td>'+money(r.amount)+'</td></tr>').join('')||'<tr><td colspan="'+(d.scope?7:5)+'">'+(d.loading?'Carregando composição…':q?'Nenhum registro neste filtro.':'Nenhum item localizado nas fontes consultadas.')+'</td></tr>';
   const data=d.compositionData;
   const cycle=data?.reconciliation?.status==='documented_cycle_net_match',reconciled=cycle||data?.reconciliation?.status==='documented_net_match';
   if(cycle)host.querySelector('h2').textContent='Faturas do ciclo · '+monthLabel(data.period||d.parent.period);
   host.querySelector('.v178-detail-summary').innerHTML='<span>'+escape(cycle?'Registros originais':reconciled?'Consolidado original':'Total do consolidado')+'<b>'+money(cycle?data.reconciliation.original_total:d.total)+'</b></span><span>Identificado<b>'+money(data?.identified_total)+'</b></span><span>'+escape(reconciled?'Sem explicação':data?.status==='difference'?'Diferença em conferência':'Sem composição')+'<b>'+money(data?.unexplained_total??data?.residual_total)+'</b></span>';
   const notices={missing:'O total está preservado. Ainda falta localizar os registros que o compõem.',partial:'Composição parcial: os itens identificados e o valor restante estão separados.',difference:'A soma dos itens difere do consolidado. Os valores estão preservados para conferência.',stale:'A composição mudou desde a última conferência. Atualize a lista para revisar.'};
   host.querySelector('.v178-components').innerHTML=data?compositionReconciliation(data)+(!reconciled&&data.source_document_total!=null?'<p class="v346-document-total">Fatura '+escape(dateLabel(data.source_document_due_date))+': '+money(data.source_document_total)+'.</p>':'')+(notices[data.status]?'<p class="v346-gap" role="status">'+escape(notices[data.status])+'</p>':'')+(data.precision_note?'<details class="v346-origin v346-precision"><summary>Precisão dos valores de origem</summary><p>A planilha contém frações de centavo. A soma coincide com o total quando apresentada em reais; os valores originais estão preservados.</p></details>':''):'';
   host.querySelector('footer span').textContent=d.error||(d.loading?'Carregando composição…':(q?rows.length+' exibidos de ':'')+d.rows.length+' registros · '+(data?.nonzero_count??0)+' com valor');
   host.querySelector('.v178-filter input').disabled=d.loading;host.querySelector('.v178-retry').hidden=!d.error&&data?.status!=='stale';
  }
  async function openComposition(parent,range,retry=false){
   if(!parent)return;if(!retry)rememberDetail();
   const token=++sequence,d=state.detail={group:parent.current_category||parent.category,subgroup:null,range:{...range},composition:true,parent,route:V,query:'',rows:[],loading:true,error:null,count:null,total:parent.amount};
   shellDetail();drawComposition();
   try{
    const p=await request('lts_browser_expense_composition_v374',{p_from:range.from,p_to:range.to,p_row_key:parent.key},22000,retry);
    if(token!==sequence)return;
    if(!Array.isArray(p.rows)||!['complete','partial','missing','difference','stale'].includes(p.status)||finite(p.total)==null||Math.abs(Number(p.total)-Number(parent.amount))>0.01)throw Error('changed composition');
    d.compositionData=p;d.rows=p.rows;d.count=p.count;d.total=p.total;
    if(d.rows.length!==d.count||Math.abs(total(d.rows.map(r=>r.amount))-Number(p.identified_total))>0.011)throw Error('incomplete composition');
   }catch(e){if(token===sequence){d.rows=[];d.compositionData=null;d.error='Não foi possível abrir a composição. Tente novamente.';}}
   finally{if(token===sequence){d.loading=false;drawComposition();}}
  }
  async function openArchive(range,component=null,restore=null){
   const context=beginDetail('Histórico de investimentos',null,range,restore,true,component),token=++sequence,d=state.detail={...context,group:'Histórico de investimentos',subgroup:null,range:{...range},archive:true,archiveComponent:component,rows:[],loading:true,count:null,total:null};shellDetail();drawRows();
   try{const p=await request('lts_browser_property_archive_v178',{});if(token!==sequence)return;d.rows=arr(p.rows).filter(r=>!component||r.component===component);d.total=total(d.rows.map(x=>x.amount));d.count=d.rows.length;
    const cs=new Map();for(const row of d.rows)cs.set(row.component,(cs.get(row.component)||0)+row.amount);
    const box=document.querySelector('#v178Drawer .v178-components');box.innerHTML=[...cs].map(([name,value])=>'<button data-archive-component="'+escape(name)+'"><span>'+escape(name)+'</span><b>'+money(value)+'</b></button>').join('');
    box.querySelectorAll('[data-archive-component]').forEach(b=>b.onclick=()=>openArchive(range,b.dataset.archiveComponent));
   }catch(e){if(token===sequence)d.error=d.scope?'Não foi possível conferir esta lista. Atualize o relatório antes de usar este total.':String(e.message||e)}finally{if(token===sequence){d.loading=false;drawRows()}}
  }
  function decorateFlow(){
   if(V!=='Fluxo Diário')return;
   document.querySelectorAll('.v176-rsu-delta').forEach(x=>x.remove());
   document.querySelectorAll('.v178-award-detail').forEach(x=>x.remove());
   const dayIndex=new Map(mergedFlowDays().map(d=>[d.date,d]));
   const a=state.awards.data,ready=state.awards.status==='ready'&&a?.as_of&&finite(a.brokerage_available)!=null;
   document.querySelectorAll('.fx87-row.fx87-cons[id^="d-"]').forEach(row=>{
    const date=row.id.slice(2),cell=row.children[7];if(!cell)return;
    cell.classList.remove('v176-rsu-active');
    const canonical=dayIndex.get(date)?.fix86_columns;
    cell.textContent=money(canonical?.rsus_vested);
    cell.title='Posição disponível nesta data, conforme o prazo da agenda de RSU.';
    cell.classList.toggle('v178-vested-change',ready&&arr(a.events).some(e=>e.available_date===date));
    if(!ready)return;
    if(!EXP.has(date))return;
    const events=arr(a.events).filter(e=>e.vesting_date===date||e.available_date===date);
    if(!events.length)return;
    const details=row.nextElementSibling;
    if(!details?.classList.contains('fx89-details'))return;
    const section=document.createElement('section');section.className='v178-award-detail';
    section.innerHTML='<b>Ações e RSUs · sem movimento bancário</b>'+events.map(e=>'<div><span>'+escape(e.vesting_date===date?(e.regular_rsu?'Vesting de RSU':'Direito à premiação'):'Disponibilidade prevista na corretora')+'<small>'+escape(e.type)+' · vesting '+dateLabel(e.vesting_date)+' · disponibilidade '+dateLabel(e.available_date)+'</small></span><strong>'+money(e.value)+'</strong></div>').join('');
    details.appendChild(section);
   });
  }
  function cleanTechnical(){
   document.querySelectorAll('.v175-property,.v174-property-note').forEach(x=>x.remove());
   document.querySelectorAll('.v175-rank-title small').forEach(x=>{if(/fonte reconciliada/i.test(x.textContent))x.remove()});
  }
  function after(){
   syncCashContext();
   if(!D||N.classList.contains('hidden'))return;
   if(V==='Dashboard')queueMicrotask(()=>startDashboard(false));
   if(V==='Fluxo Diário'&&state.cash.status==='idle')refreshCashOnly();
   if(V==='Fluxo Diário'&&state.awards.status==='idle')loadState('awards','lts_browser_awards_v178');
   document.querySelectorAll('[data-v178-scope]').forEach(parent=>{
    const range=parent.dataset.v178Scope==='dashboard'?yearRange():reportRange();
    const data=parent.dataset.v178Scope==='dashboard'?state.dashboardReport.data:v175.expense.data;
    parent.querySelectorAll('.v178-open').forEach(b=>b.onclick=()=>openDetail(b.dataset.group,null,range,arr(data?.management_groups).find(g=>g.name===b.dataset.group)?.total));
   });
   document.querySelectorAll('.v178-refresh,[data-v168-dashboard-refresh]').forEach(b=>b.onclick=()=>{startDashboard(true);render()});
   if(V==='Dashboard')document.querySelectorAll('[data-v168-go="Despesas"]').forEach(b=>{const old=b.onclick;b.onclick=e=>{v168.expense.key='ytd';v175.expense.key='';v175.expense.data=null;return old?.call(b,e)}});
   document.querySelectorAll('.v353-open').forEach(b=>b.onclick=e=>{
    e.preventDefault();e.stopPropagation();const parent=b.closest('[data-v178-scope]'),range=parent?.dataset.v178Scope==='dashboard'?yearRange():reportRange();
    try{openDetail(b.dataset.v353Label,null,range,Number(b.dataset.v353Total),{scope:JSON.parse(b.dataset.v353Scope)});}catch{}
   });
   document.querySelectorAll('[data-v353-node]').forEach(el=>el.ontoggle=()=>{state.hierarchyExpanded=state.hierarchyExpanded||new Set();if(el.open)state.hierarchyExpanded.add(el.dataset.v353Node);else state.hierarchyExpanded.delete(el.dataset.v353Node)});
   document.querySelectorAll('.v353-filters').forEach(el=>el.ontoggle=()=>state.hierarchyFiltersOpen=el.open);
   document.querySelectorAll('[data-v353-view],[data-v353-filter]').forEach(el=>el.onchange=()=>{
    const panel=el.closest('.v353-presentation'),scope={view:panel.querySelector('[data-v353-view]').value};
    panel.querySelectorAll('[data-v353-filter]').forEach(x=>{if(x.value)scope[x.dataset.v353Filter]=x.value});state.hierarchyScope=scope;state.hierarchyFiltersOpen=panel.querySelector('.v353-filters').open;closeDetail();render();
   });
   document.querySelectorAll('.v353-retry').forEach(b=>b.onclick=()=>{cache.clear();window.__LTS_V227_TRANSPORT?.invalidate(false);v175.expense.token++;v175.expense.data=null;v175.expense.key='';v175.expense.loading=false;render()});
   cleanTechnical();decorateFlow();
  }
  v168.dashboard.token=(v168.dashboard.token||0)+1;v168.dashboard.started=true;v168.dashboard.loading=false;
  v175.expense.token=(v175.expense.token||0)+1;v175.expense.data=null;v175.expense.key='';v175.expense.loading=false;
  v175.monthly.token=(v175.monthly.token||0)+1;v175.monthly.data=null;v175.monthly.key='';v175.monthly.loading=false;
  dashboard=dashboard178;despesas=expenses178;
  render=function(){if(cipoModal&&!cipoCurrent(cipoModal))closeCipo();if(state.detail&&state.detail.route!==V)closeDetail();const out=previousRender();after();return out};
  renderNav=function(){const out=previousNav();return out};
  document.addEventListener('visibilitychange',()=>{if(!document.hidden&&V==='Dashboard'&&state.date!==day())startDashboard(true)});
  S.auth.onAuthStateChange?.((event)=>{if(event==='SIGNED_IN'||event==='SIGNED_OUT'){closeCipo();state.hierarchyScope={};state.hierarchyExpanded=new Set();state.hierarchyFiltersOpen=false;}if(event==='SIGNED_IN'){closeDetail();cashAuthEpoch++;syncCashContext()}if(event==='SIGNED_OUT'){
   cashAuthEpoch++;cashRevision++;cashDemand=null;
   cashSessionGeneration=cashGeneration();cashSessionEpoch=cashAuthEpoch;cashCalendarDay=day();
   cache.clear();inflight.clear();closeDetail();state.date=null;dashboardSerial++;
   // Invalidate captured slots before replacing them, regardless of listener order.
   for(const k of ['cash','wealth','forecast','awards','dashboardReport','planningUI']){
    const previous=state[k];if(previous)previous.token=(previous.token||0)+1;
    state[k]={status:'idle',token:previous?.token||0};
   }
  }});
  window.addEventListener('lts:data-invalidated',()=>{
   closeCipo();
   if(state.detail)closeDetail();
   cache.clear();dashboardSerial++;cashRevision++;cashDemand=null;
   for(const k of ['cash','wealth','forecast','planningUI','dashboardReport']){state[k].token=(state[k].token||0)+1;state[k].status='idle';state[k].data=null;state[k].parts=[]}
   // Invalidation may follow a successful HTTP response whose payload is unusable.
   // Resume canonical reads after the superseded flight; never replay the mutation.
   const invalidatedSerial=dashboardSerial;
   const recover=()=>{
    if(invalidatedSerial!==dashboardSerial||!cashVisible())return;
    if(V==='Fluxo Diário')refreshCashOnly();else startDashboard(false);
   };
   // Let queued explicit refresh continuations claim their generation first.
   const schedule=()=>queueMicrotask(recover);
   if(V==='Fluxo Diário')schedule();else Promise.resolve(dashboardFlight).then(schedule,schedule);
  });
  async function cachedFlow(from,to){
   const s=state.forecast,token=(await S.auth.getSession())?.data?.session?.access_token;if(s.status==='loading'&&s.waiting)await s.waiting;
   if(s.status!=='ready'||s.date!==day()||s.authToken!==token||Date.now()-s.updatedAt>=300000)return null;
   const j=s.parts?.[0];if(!j?.flow||typeof j.flow.from!=='string'||typeof j.flow.to!=='string'||j.flow.from>from||j.flow.to<to)return null;
   const out=structuredClone(j);out.flow.from=from;out.flow.to=to;
   for(const part of ['historical','current_future'])if(out.flow[part])for(const [name,field]of[['days','date'],['events','event_date']])out.flow[part][name]=arr(out.flow[part][name]).filter(x=>x[field]>=from&&x[field]<=to);
   if(arr(out.flow.historical?.days).length+arr(out.flow.current_future?.days).length!==(Date.parse(to+'T12:00:00Z')-Date.parse(from+'T12:00:00Z'))/86400000+1)return null;
   return out;
  }
  window.__LTS_V178_REVIEW={installed:true,completeness_contract:269,version:'v279-cash-only-candidate',baseline:'v178',cashComplete,retryableCashFailure,refreshCashOnly,openDetail,closeDetail,openCipoReconciliation,closeCipo,cachedFlow,refresh:options=>startDashboard(true,options?.alreadyInvalidated===true),ready:()=>startDashboard(false)};
  publishCashDiagnostic();
  if(D&&!N.classList.contains('hidden'))render();
 }
 function install(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w?.__LTS_V176_FLOW_EXPENSE_AUDIT?.installed)return false;
  if(!d.getElementById('v178-style')){const link=d.createElement('link');link.id='v178-style';link.rel='stylesheet';link.href='lts-v178-integrated-review.css?v=20260920';d.head.appendChild(link)}
  if(!w.__LTS_V178_REVIEW?.installed&&!d.getElementById('v178-runtime')){const script=d.createElement('script');script.id='v178-runtime';script.textContent='('+runtime.toString()+')();';d.head.appendChild(script)}
  if(w.__LTS_V178_REVIEW?.installed){document.getElementById('gate')?.remove();return true}return false;
 }catch{return false}}
 function burst(){const gen=++generation;let count=0;function step(){if(gen!==generation)return;if(!install()&&++count<320)setTimeout(step,100)}step()}
 outer?.addEventListener('load',burst);burst();
 window.LTSV339Boot?.watch('lts-v179-cash-recovery.js',install);
})();


;
;
/* LTS V384: lts-v180-documentary-refresh.js */
/* V180 keeps the V179 cash recovery and aligns future awards with the latest reconciled brokerage statement. */
(function(){
 'use strict';
 const outer=document.getElementById('shell');let generation=0;
 function runtime(){
  'use strict';
  if(window.__LTS_V180_DOCUMENTARY_REFRESH?.installed||!window.__LTS_V178_REVIEW?.installed)return;
  const previousDashboard=dashboard;
  const finite=value=>value==null||value===''?null:(Number.isFinite(Number(value))?Number(value):null);
  const money=value=>finite(value)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(value));
  const normalize=value=>String(value??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
  const dateLabel=value=>/^\d{4}-\d{2}-\d{2}$/.test(String(value))?String(value).split('-').reverse().join('/'):String(value||'—');
  function patchKpi(root,label,value,note){
   const item=[...root.querySelectorAll('.v168-kpi')].find(node=>normalize(node.querySelector('span')?.textContent).trim()===normalize(label));
   if(!item)return;
   item.querySelector('strong').textContent=money(value);
   if(item.querySelector('small'))item.querySelector('small').textContent=note;
  }
  dashboard=function(){
   const html=previousDashboard();
   const summary=window.__LTS_V168_STATE?.dashboard?.data?.wealth?.rsu_summary||window.__LTS_V168_STATE?.wealth?.data?.rsu_summary||window.__LTS_V178_STATE?.wealth?.data?.rsu_summary;
   const regular=finite(summary?.future_regular_brl),cashNet=finite(summary?.future_cash_net_brl),totalNet=finite(summary?.future_considered_total_brl);
   if([regular,cashNet,totalNet].some(value=>value==null)||Math.abs(regular+cashNet-totalNet)>=0.02)return html;
   const template=document.createElement('template');template.innerHTML=html;
   const root=template.content.querySelector('.v168-dashboard');if(!root)return html;
   patchKpi(root,'RSUs futuras',regular,'Projeção da agenda · valor bruto');
   patchKpi(root,'Cash RSUs futuras',cashNet,'Projeção da agenda · reserva de 30%');
   patchKpi(root,'Total de posições futuras',totalNet,'RSU + Cash RSU; referências atuais em Cotações');
   return template.innerHTML;
  };
  window.__LTS_V180_DOCUMENTARY_REFRESH={installed:true,version:'v180-documentary-refresh',baseline:'v179-cash-recovery'};
  if(D&&!N.classList.contains('hidden'))render();
 }
 function install(){try{
  const frameWindow=outer?.contentWindow,frameDocument=outer?.contentDocument;
  if(!frameWindow?.__LTS_V178_REVIEW?.installed)return false;
  if(!frameWindow.__LTS_V180_DOCUMENTARY_REFRESH?.installed&&!frameDocument.getElementById('v180-documentary-runtime')){
   const script=frameDocument.createElement('script');
   script.id='v180-documentary-runtime';
   script.textContent='('+runtime.toString()+')();';
   frameDocument.head.appendChild(script);
  }
  return !!frameWindow.__LTS_V180_DOCUMENTARY_REFRESH?.installed;
 }catch{return false}}
 function burst(){const current=++generation;let count=0;function step(){if(current!==generation)return;if(!install()&&++count<320)setTimeout(step,100)}step()}
 outer?.addEventListener('load',burst);burst();
 window.LTSV339Boot?.watch('lts-v180-documentary-refresh.js',install);
})();

;
;
/* LTS V384: lts-v178-review-actions.js */
/* Review actions use authenticated report rows; no personal constants or writes. */
(function(){
 'use strict';
 const outer=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V178_REVIEW_ACTIONS||!window.__LTS_V178_REVIEW?.installed)return;
  const api=window.__LTS_V178_REVIEW,state=window.__LTS_V178_STATE;
  const escape=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const money=x=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(x)||0);
  const pending='Identificações pendentes';
  function exportPending(){
   const d=state.detail;if(!d||d.group!==pending||d.loading||d.error||d.rows.length!==d.count)return;
   const text=x=>{let s=String(x??'');if(/^[\u0000-\u0020]*[=+@-]/.test(s))s="'"+s;return '"'+s.replace(/"/g,'""')+'"'};
   const rows=[['Data','Competência','Histórico','Conta ou cartão','Pessoa','Categoria','Valor (R$)','Confirmar'].map(text).join(';')];
   for(const r of d.rows)rows.push([text(r.date_kind==='day'?r.date:''),text(String(r.period||'').slice(0,7)),text(r.description),text(r.account_source),text(r.beneficiary),text(r.category),'"'+Number(r.amount).toFixed(2).replace('.',',')+'"',text(r.review_question||'Pessoa ou classificação a confirmar')].join(';'));
   const url=URL.createObjectURL(new Blob(['\ufeff'+rows.join('\r\n')],{type:'text/csv;charset=utf-8'}));
   const a=document.createElement('a');a.href=url;a.download='LTS-identificacoes-'+d.range.from+'-a-'+d.range.to+'.csv';document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);
  }
  function detailQuestions(){
   const d=state.detail,host=document.getElementById('v178Drawer');if(!d||d.group!==pending||!host)return;
   const byKey=new Map(d.rows.map(r=>[String(r.key),r]));
   host.querySelectorAll('tr[data-row-key]').forEach(tr=>{const r=byKey.get(tr.dataset.rowKey);if(!r||tr.querySelector('.v178-question'))return;const small=document.createElement('small');small.className='v178-question';small.textContent=r.review_question||'Pessoa ou classificação a confirmar';tr.children[1]?.appendChild(small)});
   let button=host.querySelector('.v178-export-pending');if(!button){button=document.createElement('button');button.className='v178-refresh v178-export-pending';button.textContent='Exportar lista';button.title='Exportar todos os itens do período';host.querySelector('footer')?.appendChild(button)}
   button.onclick=exportPending;
   button.disabled=Boolean(d.loading||d.error||d.rows.length!==d.count);
   const input=host.querySelector('input');if(input&&!input.dataset.reviewQuestions){input.dataset.reviewQuestions='1';input.addEventListener('input',detailQuestions)}
   const retry=host.querySelector('.v178-retry');if(retry&&!retry.dataset.reviewQuestions){retry.dataset.reviewQuestions='1';const old=retry.onclick;retry.onclick=e=>Promise.resolve(old?.call(retry,e)).finally(detailQuestions)}
  }
  async function open(group,range,expected){await api.openDetail(group,null,range,expected);detailQuestions()}
  function guardSecondaryTotals(){
   if(V!=='Dashboard')return;
   const cards=[...document.querySelectorAll('.v168-dashboard .v168-kpi')];
   const find=label=>cards.find(c=>c.querySelector('span')?.textContent.trim()===label);
   const available=label=>{const text=find(label)?.querySelector('strong')?.textContent.trim();return Boolean(text&&!/^[—–-]$/.test(text))};
   for(const [label,parts] of [['Total de posições futuras',['RSUs futuras','Cash RSUs futuras']],['Total em previdências',['Organon','Novartis']]]){
    if(parts.every(available))continue;const card=find(label);if(!card)continue;card.querySelector('strong').textContent='—';if(card.querySelector('small'))card.querySelector('small').textContent='Aguardando todas as posições';
   }
  }
  function decorate(){
   guardSecondaryTotals();
   document.querySelectorAll('[data-v178-scope]').forEach(parent=>{
    if(parent.querySelector('.v178-review-actions'))return;
    const dashboard=parent.dataset.v178Scope==='dashboard';
    const data=dashboard?state.dashboardReport.data:window.__LTS_V175_STATE?.expense?.data;if(!data)return;
    const year=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
    const range=dashboard?{from:year.slice(0,4)+'-01-01',to:year}:{from:data.period?.from,to:data.period?.to};if(!range.from||!range.to)return;
    const count=Number(data.summary?.pending_identification)||0,coverage=(data.management_groups||[]).find(g=>['Faturas conciliadas pelo total','Faturas sem composição individual'].includes(g.name));
    const box=document.createElement('div');box.className='v178-review-actions';box.style.cssText='display:flex;gap:8px;flex-wrap:wrap;margin-top:12px';
    if(count){const b=document.createElement('button');b.className='v178-refresh v178-pending-open';b.textContent='Identificações pendentes · '+count;b.onclick=()=>open(pending,range,null);box.appendChild(b)}
    if(coverage&&Number(coverage.total)!==0){const b=document.createElement('button');b.className='v178-refresh v178-coverage-open';b.textContent='Faturas a detalhar · '+money(coverage.total);b.onclick=()=>open(coverage.name,range,coverage.total);box.appendChild(b)}
    parent.appendChild(box);
    if(!dashboard&&window.__LTS_V168_STATE?.expense?.tab==='categories'){
     const existing=new Set([...parent.querySelectorAll('.v178-open.title')].map(b=>b.dataset.group));
     const extra=(data.management_groups||[]).filter(g=>!existing.has(g.name)&&!['Faturas conciliadas pelo total','Faturas sem composição individual'].includes(g.name));
     const max=Math.max(1,...(data.management_groups||[]).map(g=>Math.abs(Number(g.total)||0)));
     for(const g of extra){const row=document.createElement('div');row.className='v178-rankrow';row.innerHTML='<span>'+(existing.size+1)+'</span><div><button class="v178-open title">'+escape(window.LTSCategoryDisplay.category(g.name))+'</button><i><u style="width:'+Math.max(1,Math.abs(Number(g.total)||0)/max*100)+'%"></u></i></div><button class="v178-open amount">'+money(g.total)+'</button>';row.querySelectorAll('button').forEach(b=>{b.dataset.group=g.name;b.onclick=()=>open(g.name,range,g.total)});parent.querySelector('.v178-rank')?.appendChild(row);existing.add(g.name)}
    }
   });
   detailQuestions();
  }
  const previous=render;render=function(){const result=previous();decorate();return result};
  window.__LTS_V178_REVIEW_ACTIONS={installed:true,decorate};decorate();
 }
 function install(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w?.__LTS_V178_REVIEW?.installed)return false;if(!w.__LTS_V178_REVIEW_ACTIONS){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);}return !!w.__LTS_V178_REVIEW_ACTIONS?.installed;}catch{return false;}}
 let generation=0;
 function burst(){const current=++generation;let attempts=0;function step(){if(current!==generation)return;if(!install()&&++attempts<320)setTimeout(step,100);}step();}
 outer?.addEventListener('load',burst);burst();
 window.LTSV339Boot?.watch('lts-v178-review-actions.js',install);
})();

;
;
/* LTS V384: lts-category-registry.js */
/* One shared registry. Creating a category never classifies or changes a financial event. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.LTSCategoryRegistry)return;
  let data=null,reading=null,readAt=0,epoch=0,creating=0;
  const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const generation=()=>typeof BOOT==='object'?BOOT.generation:D;
  let owner=generation();
  function session(){
   if(owner!==generation()){owner=generation();data=null;reading=null;readAt=0;epoch++;}
  }
  const canonical=value=>{session();return data?.aliases?.[value]||value;};
  function availableOptions(value){
   const aliases={...(value.aliases||{})},categories=Array.isArray(value.categories)?value.categories:[];
   if(categories.includes('Financiamento Imobiliário'))for(const c of categories)if(c.toLocaleLowerCase('pt-BR')==='financiamento imóvel')aliases[c]='Financiamento Imobiliário';
   return {...value,aliases,categories:[...new Set(categories.map(c=>aliases[c]||c))].filter(c=>c&&c!=='—')};
  }
  function populate(select,selected,force=false){
   if(!select?.isConnected||!data)return;
   if(document.activeElement===select&&!force){
    select.addEventListener('blur',()=>populate(select,select.value),{once:true});return;
   }
   const empty=select.options[0]?.value===''?select.options[0].textContent:'Selecione…';
   const value=canonical(selected??select.value);
   const previousValue=select.value;
   select.innerHTML='<option value="">'+esc(empty)+'</option>'+data.categories.map(c=>'<option value="'+esc(c)+'"'+(c===value?' selected':'')+'>'+esc(window.LTSCategoryDisplay.category(c))+'</option>').join('');
   if(select.value!==previousValue)select.dispatchEvent(new Event('change',{bubbles:true}));
  }
  async function get(force=false){
   session();if(!force&&data&&Date.now()-readAt<60000)return data;
   if(reading)return reading;
   const current=epoch;
   reading=(async()=>{
    const result=await S.rpc('lts_browser_card_category_options_v226',{});
    if(result.error||!Array.isArray(result.data?.categories))throw Error('As classificações não foram carregadas. Tente novamente.');
    if(current!==epoch||owner!==generation())throw Error('A sessão mudou. Abra novamente.');
    data=availableOptions(result.data);readAt=Date.now();return data;
   })().finally(()=>{if(current===epoch)reading=null;});
   return reading;
  }
  function changed(result){
   const review=window.__LTS_V181_STATE?.review;
   if(review?.data)review.data.category_options=result.categories;
   if(window.__LTS_V226)window.__LTS_V226.options=result.categories;
   document.querySelectorAll('select[data-lts-category]').forEach(select=>populate(select));
   window.dispatchEvent(new CustomEvent('lts:categories-changed',{detail:{categories:result.categories}}));
  }
  function attach(select){
   session();
   if(!select||select.dataset.ltsCategory)return;
   select.dataset.ltsCategory='shared';
   const details=document.createElement('details');details.className='lts-new-category';
   details.innerHTML='<summary>Criar nova classificação</summary><label>Nome da classificação<input type="text" minlength="2" maxlength="80" autocomplete="off" placeholder="Ex.: Manutenção"></label><button type="button" class="v168-btn" data-category-create>Criar classificação</button><span role="status" aria-live="polite"></span>';
   const anchor=select.parentElement?.tagName==='LABEL'?select.parentElement:select;
   anchor.insertAdjacentElement('afterend',details);
   const input=details.querySelector('input'),button=details.querySelector('button'),status=details.querySelector('[role=status]');
   details.addEventListener('toggle',()=>{if(details.open)input.focus();});
   input.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();button.click();}});
   button.onclick=async()=>{
    const name=input.value.trim();if(button.disabled)return;
    if(name.length<2||name.length>80){status.textContent='Informe um nome entre 2 e 80 caracteres.';return;}
    button.disabled=true;status.textContent='Criando…';const current=epoch,reviewKey=select.closest('[data-v181-review-key]')?.dataset.v181ReviewKey,cardKey=select.closest('[data-v226-classify]')?.dataset.v226Classify,dialogId=select.closest('dialog')?.id;creating++;
    try{
     const saved=await S.rpc('lts_browser_category_create_v1',{p_category:name});
     if(saved.error||saved.data?.ok!==true)throw Error(saved.error?.message||'Tente novamente.');
     if(current!==epoch||owner!==generation())return;
     // The creation response is authoritative. Do not let an older in-flight
     // options request or an asynchronous row refresh discard this choice.
     if(Array.isArray(saved.data.categories)){data=availableOptions({...(data||{}),categories:saved.data.categories,revision:saved.data.revision});readAt=Date.now();}
     else await get(true);
     const review=window.__LTS_V181_STATE?.review;
     if(reviewKey&&review?.drafts)review.drafts.set(reviewKey,{...(review.drafts.get(reviewKey)||{}),category:saved.data.category});
     changed(data);
     const target=select.isConnected?select:reviewKey?[...document.querySelectorAll('[data-v181-review-key]')].find(row=>row.dataset.v181ReviewKey===reviewKey)?.querySelector('[data-v181-category]'):cardKey?[...document.querySelectorAll('[data-v226-classify]')].find(form=>form.dataset.v226Classify===cardKey)?.querySelector('[name=category]'):document.getElementById(dialogId||'')?.querySelector('[name=category]');
     if(target){populate(target,saved.data.category,true);target.value=saved.data.category;target.dispatchEvent(new Event('change',{bubbles:true}));target.focus();}
     details.open=false;input.value='';status.textContent='Classificação criada e disponível no fluxo e nos cartões.';
    }catch{if(details.isConnected)status.textContent='Não foi possível criar a classificação. Confira a conexão e tente novamente.';}
    finally{creating=Math.max(0,creating-1);button.disabled=false;}
   };
   if(data)populate(select);
   else get().then(()=>populate(select)).catch(()=>{status.textContent='Não foi possível carregar a lista. Reabra para tentar novamente.';});
  }
  window.LTSCategoryRegistry={get,attach,canonical,get busy(){return creating>0;},reset(){epoch++;data=null;reading=null;readAt=0;}};
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V178_REVIEW_ACTIONS?.installed)return false;if(!w.LTSCategoryRegistry){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return !!w.LTSCategoryRegistry;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();
 window.LTSV339Boot?.watch('lts-category-registry.js',install);
})();

;
;
/* LTS V384: lts-v181-regression-closure.js */
/* V181 closes the card-flow regression and turns pending identifications into an authenticated review workflow. */
(function(){
 'use strict';
 const outer=document.getElementById('shell');let generation=0;
 function runtime(){
  'use strict';
  if(window.__LTS_V181_REGRESSION_CLOSURE?.installed||!window.__LTS_V180_DOCUMENTARY_REFRESH?.installed||!window.__LTS_V178_REVIEW_ACTIONS?.installed)return;
  const v168=window.__LTS_V168_STATE,v175=window.__LTS_V175_STATE,v178=window.__LTS_V178_STATE,detailApi=window.__LTS_V178_REVIEW;
  const previousRender=render,previousNav=renderNav,previousExpenses=despesas,previousUpdates=atualizacoes;
  const state=window.__LTS_V181_STATE={
   review:{status:'idle',data:null,error:null,key:'',offset:0,query:'',saving:null,notice:'',drafts:new Map()},
   reconciliation:{status:'idle',data:null,error:null,key:''},
   categoryView:'beneficiary',focusQueue:false
  };
  const arr=value=>Array.isArray(value)?value:[];
  const finite=value=>value===null||value===undefined||value===''?null:(Number.isFinite(Number(value))?Number(value):null);
  const sum=values=>arr(values).reduce((total,value)=>total+(finite(value)||0),0);
  const escape=value=>String(value??'').replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
  const normalize=value=>String(value??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim().replace(/\s+/g,' ');
  const money=value=>finite(value)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(value));
  const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const dateLabel=value=>/^\d{4}-\d{2}-\d{2}$/.test(String(value||''))?String(value).split('-').reverse().join('/'):String(value||'—');
  const monthLabel=value=>{const key=String(value||'').slice(0,7);return /^\d{4}-\d{2}$/.test(key)?new Intl.DateTimeFormat('pt-BR',{month:'short',year:'numeric'}).format(new Date(key+'-01T12:00:00Z')).replace('.',''):key||'—'};
  const template=html=>{const node=document.createElement('template');node.innerHTML=html;return node};
  function addDays(value,days){const date=new Date(String(value).slice(0,10)+'T12:00:00Z');date.setUTCDate(date.getUTCDate()+days);return date.toISOString().slice(0,10)}
  function expenseRange(){
   const source=v168?.expense||{},end=today(),year=end.slice(0,4);let from=year+'-01-01',label='Ano atual';
   if(source.key==='all'){from='2013-10-10';label='Desde 2013'}
   else if(source.key==='6m'||source.key==='12m'){const date=new Date(end.slice(0,7)+'-01T12:00:00Z');date.setUTCMonth(date.getUTCMonth()-(source.key==='6m'?5:11));from=date.toISOString().slice(0,10);label=source.key==='6m'?'6 meses':'12 meses'}
   else if(source.key==='custom'){from=source.customFrom||from;label='Período personalizado'}
   return{from,to:source.key==='custom'?(source.customTo||end):end,label};
  }
  async function rpc(name,args,timeoutMs=22000){
   let timer;const timeout=new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Tempo de leitura excedido.')),timeoutMs)});
   try{const result=await Promise.race([S.rpc(name,args||{}),timeout]);if(result?.error||result?.data==null)throw Error(result?.error?.message||name+' indisponível');return result.data}
   finally{clearTimeout(timer)}
  }
  function optionRows(values,empty,selected,display=value=>value){
   const seen=new Set(),items=[];
   for(const raw of arr(values)){const value=String(typeof raw==='string'?raw:(raw?.value??raw?.label??'')).trim(),label=String(typeof raw==='string'?raw:(raw?.label??raw?.value??'')).trim();if(!value||seen.has(value)||/^(a classificar|identifica[cç][oõ]es pendentes)$/i.test(value))continue;seen.add(value);items.push({value,label:label||value})}
   selected=items.find(x=>normalize(x.value)===normalize(selected))?.value||items.find(x=>normalize(x.value)===normalize(String(selected||'').replace(/^(Lucas|Larissa|Benjamin)\s*[-—]\s*/i,'')))?.value;
   return '<option value="">'+escape(empty)+'</option>'+items.map(item=>'<option value="'+escape(item.value)+'"'+(item.value===selected?' selected':'')+'>'+escape(display(item.label))+'</option>').join('');
  }
  async function ensureReview(force=false){
   const range={from:'2013-10-10',to:today()},s=state.review,key=[range.from,range.to,s.offset,s.query].join('|');
   if(s.status==='loading'||(!force&&s.status==='ready'&&s.key===key))return;
   s.status='loading';s.error=null;s.key=key;render();
   try{s.data=await rpc('lts_browser_expense_review_queue_v229',{p_from:range.from,p_to:range.to,p_offset:s.offset,p_limit:25,p_query:s.query||null});s.status='ready'}
   catch(error){s.status='error';s.error=String(error?.message||error)}
   finally{render()}
  }
  async function ensureReconciliation(force=false){
   const s=state.reconciliation,from=today(),to=addDays(from,730),key=from+'|'+to;
   if(s.status==='loading'||(!force&&s.status==='ready'&&s.key===key))return;
   s.status='loading';s.error=null;s.key=key;render();
   try{s.data=await rpc('lts_browser_invoice_flow_reconciliation_v181',{p_from:from,p_to:to});s.status='ready'}
   catch(error){s.status='error';s.error=String(error?.message||error)}
   finally{render()}
  }
  function reviewFields(row,data){
   const draft=state.review.drafts.get(String(row.key)),choice=name=>draft&&Object.hasOwn(draft,name)?draft[name]:row.suggestion?.[name];
   const person=optionRows(data?.beneficiary_options,'Selecione a pessoa/contexto',choice('beneficiary')),property=optionRows(data?.property_options,'Selecione o imóvel',choice('property_code')),category=optionRows(data?.category_options,'Selecione a categoria',choice('category'),window.LTSCategoryDisplay.category);
   if(row.question_kind==='person')return '<label>Pessoa/contexto<select data-v181-beneficiary>'+person+'</select></label>';
   if(row.question_kind==='property')return '<label>Imóvel<select data-v181-property>'+property+'</select></label>';
   if(row.question_kind==='property_purpose')return '<label>Finalidade/categoria<select data-v181-category>'+category+'</select></label>';
   return '<label>Pessoa/contexto <small>opcional</small><select data-v181-beneficiary>'+person+'</select></label><label>Categoria <small>opcional</small><select data-v181-category>'+category+'</select></label>';
  }
  function reviewPanel(){
   const s=state.review,data=s.data||{},cardState=window.__LTS_V312_CARD_REVIEW?.state,cardData=cardState?.data,
     cardRefs=new Set(arr(cardData?.review_source_refs||cardData?.rows?.map(x=>x.source_ref))),allRows=arr(data.rows),
     rows=allRows.filter(row=>!(row.source_table==='lts_open_finance_staging'&&row.question_kind==='classification'&&cardRefs.has(row.source_ref))),
     overlaps=allRows.length-rows.length,busy=s.status==='loading';
   if(cardData&&allRows.length&&!rows.length&&!data.next_offset&&!data.offset)return'';
   const head='<article class="v168-card v181-review" id="v181ReviewQueue"><div class="v168-cardhead"><div><span>Classificação assistida</span><h2>Outros lançamentos a classificar</h2></div><strong>'+(overlaps?rows.length:(data.row_count??'—'))+'</strong></div><p class="v181-lead">Escolha a classificação do lançamento. Informe uma pessoa somente quando ela estiver identificada.</p>';
   if(s.status==='idle'||(busy&&!s.data))return head+'<div class="v181-loading">Carregando as decisões abertas…</div></article>';
   if(s.status==='error'&&!s.data)return head+'<div class="v168-error">Não foi possível carregar as despesas. Confira a conexão e tente novamente.</div><button class="v168-btn primary" data-v181-review-retry>Tentar novamente</button></article>';
   const notice=s.notice?'<div class="v181-success" role="status">'+escape(s.notice)+'</div>':'';
   const breakdown=!overlaps&&data.queue_breakdown?'<p class="v181-lead">'+escape(data.queue_breakdown.classification_needed)+' lançamentos precisam de categoria; '+escape(data.queue_breakdown.historical_context)+' registros já têm categoria e ainda precisam de contexto. O histórico confirmado está preservado.</p>':'';
   const search='<div class="v181-review-search"><input type="search" data-v181-review-query value="'+escape(s.query)+'" placeholder="Buscar descrição, conta ou categoria"><button class="v168-btn" data-v181-review-search>Buscar</button></div>';
   const body=rows.map(row=>'<section class="v181-review-row" data-v181-review-key="'+escape(row.key)+'"><div class="v181-review-fact"><span>'+escape(dateLabel(row.date))+' · '+escape(row.account_source||'Origem não informada')+'</span><b>'+escape(row.description||'Lançamento')+'</b><small>Atual: '+escape(row.beneficiary||'pessoa não identificada')+' · '+escape(window.LTSCategoryDisplay.category(row.category||'categoria não identificada'))+'</small></div><strong>'+money(row.amount)+'</strong><div class="v181-question"><b>'+escape(row.review_question||'Confirme a classificação correta.')+'</b><div class="v181-fields">'+reviewFields(row,data)+'</div><small data-v181-choice-note>'+escape(row.suggestion?.note||(row.suggestion?.category?'Sugestão do histórico: '+window.LTSCategoryDisplay.category(row.suggestion.category)+' · confirme antes de salvar.':'Confirme a finalidade deste lançamento.'))+'</small>'+suggestionSource(row)+'</div><button class="v168-btn primary" data-v181-review-save disabled>'+((row.suggestion?.category||row.suggestion?.beneficiary||row.suggestion?.property_code)?'Confirmar sugestão':'Salvar classificação')+'</button></section>').join('')||'<div class="v168-empty">Nenhuma identificação pendente neste recorte.</div>';
   const start=Number(data.offset||0),matched=Number(data.matched_count??data.row_count??0),prev=start>0,next=data.next_offset!=null;
   const paging='<div class="v181-paging"><span>'+(overlaps?rows.length+' outros lançamentos nesta página':matched?((start+1)+'–'+Math.min(start+rows.length,matched)+' de '+matched):'0 itens')+'</span><div><button class="v168-btn" data-v181-review-prev '+(prev?'':'disabled')+'>Anterior</button><button class="v168-btn" data-v181-review-next '+(next?'':'disabled')+'>Próxima</button></div></div>';
   return head+notice+breakdown+search+'<div class="v181-review-list">'+body+'</div>'+paging+'<div class="v181-separation"><b>Classificação e documento são pendências diferentes.</b><span>“Faturas sem composição individual” depende de recuperar ou reconciliar as compras da competência; escolher uma categoria não resolve.</span></div></article>';
  }
  function suggestionSource(row){
   const url=row.suggestion?.source_url;if(!url)return'';
   try{if(new URL(url).protocol!=='https:')return''}catch{return''}
   return '<a href="'+escape(url)+'" target="_blank" rel="noopener noreferrer">Consultar estabelecimento</a>';
  }
  function pendingProjectionPanel(){
   const rows=arr(state.review.data?.pending_projections);if(!rows.length)return'';
   return '<article class="v168-card v181-pending-projections"><div class="v168-cardhead"><div><span>Previsões a conferir</span><h2>Pagamentos ainda não identificados no banco</h2></div><strong>'+rows.length+'</strong></div><p class="v181-lead">Estas previsões continuam guardadas. Confira a data ou o pagamento antes de considerá-las realizadas.</p>'+rows.map((e,i)=>'<section class="v181-review-row"><div class="v181-review-fact"><span>'+escape(dateLabel(e.event_date))+' · '+escape(e.account)+'</span><b>'+escape(e.description)+'</b></div><strong>'+money(Math.abs(Number(e.signed_amount)))+'</strong><button class="v168-btn" data-v230-review-projection="'+i+'">Revisar previsão</button></section>').join('')+'</article>';
  }
  function updates181(){
   const t=template(previousUpdates()),root=t.content.querySelector('.v168-updates');if(!root)return t.innerHTML;
   const head=root.querySelector('.v168-head'),kpis=root.querySelector('.v168-kpis');(head||kpis)?.insertAdjacentHTML('afterend',reviewPanel()+pendingProjectionPanel());
   return t.innerHTML;
  }
  function reconciliationPanel(){
   const s=state.reconciliation,data=s.data||{},rows=arr(data.rows);
   if(s.status==='idle'||(s.status==='loading'&&!s.data))return '<article class="v168-card v181-reconciliation"><div class="v168-cardhead"><div><span>Conciliação financeira</span><h2>Faturas e previsões × Fluxo</h2></div></div><div class="v181-loading">Conferindo cada cartão e vencimento…</div></article>';
   if(s.status==='error'&&!s.data)return '<article class="v168-card v181-reconciliation"><div class="v168-cardhead"><div><span>Conciliação financeira</span><h2>Faturas e previsões × Fluxo</h2></div></div><div class="v168-error">Não foi possível conferir os cartões. Tente novamente.</div><button class="v168-btn primary" data-v181-reconciliation-retry>Tentar novamente</button></article>';
   const ok=Number(data.issue_count||0)===0;
   return '<article class="v168-card v181-reconciliation"><div class="v168-cardhead"><div><span>Conciliação financeira</span><h2>Faturas e previsões × Fluxo</h2></div><strong class="'+(ok?'positive':'negative')+'">'+(ok?'Sem divergências':escape(data.issue_count+' divergência(s)'))+'</strong></div><div class="v181-tablewrap"><table class="v181-table"><thead><tr><th>Cartão</th><th>Competência / vencimento</th><th>Referência do cartão</th><th>No Fluxo</th><th>Diferença</th><th>Situação</th><th></th></tr></thead><tbody>'+rows.map(row=>{const reconciled=row.reconciliation_status==='reconciled'&&Math.abs(Number(row.difference)||0)<=0.02;return '<tr><td><b>'+escape(row.card_name||'Cartão')+'</b></td><td>'+escape(monthLabel(row.reference_month))+'<small>'+escape(dateLabel(row.due_date))+'</small><small>'+(row.invoice_status==='projected'?'Previsão · compras e parcelas conhecidas':'Fatura recebida')+'</small></td><td>'+money(row.documented_amount)+'</td><td>'+money(row.flow_amount)+'</td><td class="'+(reconciled?'positive':'negative')+'">'+money(row.difference)+'</td><td><span class="v181-status '+(reconciled?'ok':'issue')+'">'+(reconciled?(row.invoice_status==='projected'?'Previsão alinhada':'Fatura alinhada'):'Conferir vínculo')+'</span></td><td><button class="v168-btn" data-v181-flow-date="'+escape(row.due_date)+'">Abrir no Fluxo</button></td></tr>'}).join('')+'</tbody></table></div><div class="v181-rule"><b>Regra aplicada</b><span>Para o mesmo cartão e competência, a fatura recebida substitui a previsão antiga. Compras e parcelas ainda sem fatura emitida permanecem como previsão. Valores alinhados não comprovam pagamento.</span></div></article>';
  }
  function decorateCards(root){
   const host=root.querySelector('.v175-cards');if(!host)return;
   host.querySelector('.v175-inventory')?.remove();
   const first=host.firstElementChild;first?.insertAdjacentHTML('beforebegin',reconciliationPanel());
   const planning=[...host.children].find(node=>node.matches?.('article.v168-card')&&!node.classList.contains('v181-reconciliation'));
   if(planning){const kicker=planning.querySelector('.v168-cardhead span'),title=planning.querySelector('.v168-cardhead h2'),small=planning.querySelector('.v168-cardhead small');if(kicker)kicker.textContent='Planejamento';if(title)title.textContent='Parcelas e estimativas futuras';if(small)small.textContent='não substitui a conciliação acima';planning.insertAdjacentHTML('afterbegin','<div class="v181-plan-note">Valores futuros sem fatura documentada são cenários de planejamento, não uma segunda obrigação no caixa.</div>')}
  }
  function monthlySummary(data){
   const selected=String(v175?.monthly?.year||''),rows=arr(data?.monthly_totals).filter(row=>String(row.month||'').slice(0,4)===selected);
   if(!rows.length)return'';
   const totals={entries:0,expenses:0,result:0};
   const body=rows.map(row=>{const entries=(finite(row.revenue)||0)+(finite(row.extraordinary)||0),expenses=finite(row.expenses)||0,result=finite(row.cash_after_extraordinary)??(entries-expenses);totals.entries+=entries;totals.expenses+=expenses;totals.result+=result;return '<tr><th>'+escape(monthLabel(row.month))+'</th><td>'+money(entries)+'<small>operacionais '+money(row.revenue)+' · extraordinárias '+money(row.extraordinary)+'</small></td><td>'+money(expenses)+'</td><td class="'+(result<0?'negative':'positive')+'">'+money(result)+'</td></tr>'}).join('');
   return '<article class="v175-section v181-month-summary"><div class="v168-cardhead"><div><span>'+escape(selected)+'</span><h2>Resumo de cada mês</h2></div><small>entradas − despesas = resultado</small></div><div class="v181-tablewrap"><table class="v181-table"><thead><tr><th>Mês</th><th>Entradas</th><th>Despesas</th><th>Resultado</th></tr></thead><tbody>'+body+'<tr class="total"><th>Total de '+escape(selected)+'</th><td>'+money(totals.entries)+'</td><td>'+money(totals.expenses)+'</td><td class="'+(totals.result<0?'negative':'positive')+'">'+money(totals.result)+'</td></tr></tbody></table></div><div class="v181-rule"><b>Resultado do mês</b><span>É a diferença entre entradas e despesas do mês; não é o saldo bancário acumulado.</span></div></article>';
  }
  function decorateMonthly(root){
   const host=root.querySelector('.v175-monthly');if(!host)return;
   for(const section of host.querySelectorAll('.v175-section'))if(normalize(section.querySelector('h2')?.textContent)==='resultado anual')section.remove();
   const kpis=host.querySelector('.v168-kpis'),html=monthlySummary(v175?.monthly?.data);if(kpis&&html)kpis.insertAdjacentHTML('afterend',html);
  }
  function categorySourceRows(data){
   const groups=arr(data?.management_groups),coverage=groups.find(group=>['faturas conciliadas pelo total','faturas sem composicao individual'].includes(normalize(group.name))),rows=[];
   for(const group of groups){
    if(group===coverage)continue;
    const property=/apartamento|moradia|im[oó]vel/i.test(String(group.name||'')),children=property?arr(group.subgroups).filter(child=>child?.name&&finite(child.total)!=null):[];
    const childTotal=sum(children.map(child=>child.total)),canSplit=children.length>1&&Math.abs(childTotal-(finite(group.total)||0))<=0.02;
    if(canSplit)for(const child of children)rows.push({group:group.name,subgroup:child.name,total:Number(child.total),property:true});
    else rows.push({group:group.name,subgroup:null,total:Number(group.total)||0,property});
   }
   return{rows,coverage};
  }
  function categoryDimensions(data){
   const source=categorySourceRows(data),options=arr(state.review.data?.beneficiary_options),named=new Set(options.filter(item=>!/sem prefixo|minha/i.test(String(item?.label||''))).map(item=>normalize(item?.value||item?.label)).filter(Boolean));
   const enriched=source.rows.map(row=>{
    const raw=String(row.group||''),parts=raw.split(/\s+—\s+/),property=row.property||/apartamento|moradia|im[oó]vel/i.test(raw),exactNamed=named.has(normalize(raw));
    let beneficiary,nature;
    if(property){beneficiary='Casa';nature=row.subgroup||raw}
    else if(parts.length>1){beneficiary=parts.shift();nature=parts.join(' — ')}
    else if(exactNamed){beneficiary=raw;nature='Outras despesas'}
    else if(/a classificar|identifica[cç][oõ]es pendentes/i.test(raw)){beneficiary='A confirmar';nature='A classificar'}
    else{beneficiary='Minhas despesas (sem prefixo)';nature=row.subgroup||raw}
    if(normalize(nature)==='custos de moradia')nature='Apartamento – custos recorrentes';
    return{...row,beneficiary,nature};
   });
   return{...source,rows:enriched};
  }
  function groupDimension(rows,key){const map=new Map();for(const row of rows){const label=row[key],item=map.get(label)||{label,total:0,rows:[]};item.total+=row.total;item.rows.push(row);map.set(label,item)}return[...map.values()].sort((a,b)=>Math.abs(b.total)-Math.abs(a.total))}
  function categorySections(data){
   const dimensions=categoryDimensions(data),key=state.categoryView==='nature'?'nature':'beneficiary',groups=groupDimension(dimensions.rows,key);
   const contextLabel=label=>label==='Minhas despesas (sem prefixo)'?'Demais grupos':label;
   return groups.map(group=>'<section class="v181-category-group"><header><div><span>'+(key==='nature'?'Natureza':'Pessoa/contexto')+'</span><h3>'+escape(key==='nature'?window.LTSCategoryDisplay.category(group.label):contextLabel(group.label))+'</h3></div><strong>'+money(group.total)+'</strong></header><div>'+group.rows.sort((a,b)=>Math.abs(b.total)-Math.abs(a.total)).map(row=>{const label=key==='nature'?contextLabel(row.beneficiary):window.LTSCategoryDisplay.category(row.nature);return '<button type="button" data-v181-detail-group="'+escape(row.group)+'" '+(row.subgroup?'data-v181-detail-subgroup="'+escape(row.subgroup)+'"':'')+'><span>'+escape(label)+'<small>'+escape(row.subgroup?window.LTSCategoryDisplay.category(row.group):'Ver lançamentos')+'</small></span><b>'+money(row.total)+'</b></button>'}).join('')+'</div></section>').join('');
  }
  function decorateCategories(root){
   const host=root.querySelector('.v175-categories'),data=v175?.expense?.data;if(!host||!data)return;
   const dimensions=categoryDimensions(data),organized=sum(dimensions.rows.map(row=>row.total)),coverage=finite(dimensions.coverage?.total)||0,selected=finite(data?.summary?.selected_total),difference=selected==null?null:selected-organized-coverage;
   host.classList.add('v181-category-panel');host.innerHTML='<div class="v168-cardhead"><div><span>Leituras alternativas do mesmo total</span><h2>Despesas por pessoa/contexto ou natureza</h2></div><strong>'+money(selected)+'</strong></div><div class="v181-category-toggle" role="tablist"><button class="v168-btn '+(state.categoryView==='beneficiary'?'primary':'')+'" data-v181-category-view="beneficiary">Por pessoa/contexto</button><button class="v168-btn '+(state.categoryView==='nature'?'primary':'')+'" data-v181-category-view="nature">Por natureza</button></div><p class="v181-lead">As duas visões reorganizam os mesmos lançamentos; elas não são blocos a somar entre si. A organização usa os nomes dos grupos do resumo; eles não confirmam, por si só, a pessoa de cada lançamento.</p><div class="v181-category-grid">'+categorySections(data)+'</div><div class="v181-total-check"><span>Grupos e identificações <b>'+money(organized)+'</b></span><span>Faturas sem composição individual <b>'+money(coverage)+'</b></span><span>Total do período <b>'+money(selected)+'</b></span><strong class="'+(difference!=null&&Math.abs(difference)<=0.02?'ok':'issue')+'">'+(difference==null?'Conferência indisponível':Math.abs(difference)<=0.02?'Fechamento sem dupla contagem':'Diferença '+money(difference))+'</strong></div>'+(dimensions.coverage?'<button class="v168-btn v181-coverage-button" data-v181-detail-group="'+escape(dimensions.coverage.name)+'">Abrir faturas sem composição individual</button>':'');
  }
  function expenses181(){
   const t=template(previousExpenses()),root=t.content.querySelector('.v168-expenses');if(!root)return t.innerHTML;
   const tab=v168?.expense?.tab;if(tab==='cards')decorateCards(root);if(tab==='monthly')decorateMonthly(root);if(tab==='categories')decorateCategories(root);
   return t.innerHTML;
  }
  function goFlow(date){
   V='Fluxo Diário';renderNav();render();setTimeout(()=>{const row=document.getElementById('d-'+date);row?.scrollIntoView({behavior:'smooth',block:'center'});const button=row?.querySelector('button');if(button&&window.EXP instanceof Set&&!EXP.has(date))button.click()},120);
  }
  function goReview(){state.focusQueue=true;V='Atualizações';renderNav();render()}
  function invalidateExpense(){
   window.__LTS_V227_TRANSPORT?.invalidate?.();if(window.__LTS_V172_STATE)window.__LTS_V172_STATE.flowSequence++;FLOWLOADING=false;FLOWQ=null;window.__LTS_V226?.invalidate?.();
   if(v168?.expense)v168.expense.data=null;
   if(v175){v175.expense.token=(v175.expense.token||0)+1;v175.expense.data=null;v175.expense.key='';v175.monthly.token=(v175.monthly.token||0)+1;v175.monthly.data=null;v175.monthly.key=''}
   if(v178?.dashboardReport){v178.dashboardReport.token=(v178.dashboardReport.token||0)+1;v178.dashboardReport.status='idle';v178.dashboardReport.data=null}
   detailApi.refresh?.();
  }
  function updateReviewChoice(row,remember=false){
   const model=arr(state.review.data?.rows).find(x=>String(x.key)===row.dataset.v181ReviewKey)||{};
   const person=row.querySelector('[data-v181-beneficiary]')?.value,property=row.querySelector('[data-v181-property]')?.value,category=row.querySelector('[data-v181-category]')?.value;
   if(remember){const draft={};if(person!==undefined)draft.beneficiary=person;if(property!==undefined)draft.property_code=property;if(category!==undefined)draft.category=category;state.review.drafts.set(String(row.dataset.v181ReviewKey),draft)}
   const needsPerson=/^(saúde|saude|educação|educacao|vestuário|vestuario)$/i.test(category||'');
   const knownCategory=!!model.category&&!/^(a classificar|sem categoria|nao identificado|não identificado)$/i.test(model.category);
   const ready=model.question_kind==='person'?!!person:model.question_kind==='property'?!!property:model.question_kind==='property_purpose'?!!category:(!!category&&(!needsPerson||!!person||!!model.beneficiary))||(knownCategory&&!!person);
   const button=row.querySelector('[data-v181-review-save]');if(button)button.disabled=!ready||Boolean(state.review.saving);
   const note=row.querySelector('[data-v181-choice-note]');if(note&&needsPerson&&!person&&!model.beneficiary)note.textContent=(model.suggestion?.note||'')+' Confirme também de quem é a despesa.';

  }
  async function saveReview(button){
   const host=button.closest('[data-v181-review-key]'),key=host?.dataset.v181ReviewKey,row=arr(state.review.data?.rows).find(item=>String(item.key)===String(key));if(!row)return;
   const beneficiary=host.querySelector('[data-v181-beneficiary]')?.value||null,property=host.querySelector('[data-v181-property]')?.value||null,category=host.querySelector('[data-v181-category]')?.value||null;if(!beneficiary&&!property&&!category)return;
   state.review.saving=key;button.disabled=true;button.textContent='Salvando…';
   try{await rpc('lts_browser_expense_review_decision_v229',{p_source_table:row.source_table,p_source_ref:row.source_ref,p_beneficiary:beneficiary,p_property_code:property,p_category_label:category});state.review.drafts.delete(String(key));state.review.notice='Classificação salva. Parcelas identificadas da mesma compra passam a usar essa decisão.';state.review.status='idle';state.review.data=null;invalidateExpense();await ensureReview(true)}
   catch(error){state.review.notice='Não foi possível salvar: '+String(error?.message||error);state.review.saving=null;render()}
   finally{state.review.saving=null}
  }
  function decorateDrawer(){
   const host=document.getElementById('v178Drawer'),detail=v178?.detail;if(!host||!detail||detail.composition)return;
   const title=host.querySelector('#v178DetailTitle'),period=host.querySelector('.v178-drawer>header small'),summary=host.querySelector('.v178-detail-summary span:first-child'),property=/apartamento/i.test(String(detail.group||''));
   const setText=(node,value)=>{if(node&&node.textContent!==value)node.textContent=value};
   setText(period,detail.archive?'Histórico completo documentado · independente do filtro atual':'Período selecionado: '+dateLabel(detail.range?.from)+' a '+dateLabel(detail.range?.to));
   setText(summary?.firstChild,detail.archive?'Investimentos documentados no histórico completo':'Despesas no período selecionado');
   if(property){host.classList.add('v181-property-drawer');for(const button of host.querySelectorAll('.v178-components button')){const span=button.querySelector('span');if(normalize(span?.textContent)==='custos de moradia')setText(span,'Apartamento – custos recorrentes')}setText(host.querySelector('.v178-archive small'),'Histórico completo documentado · independente do filtro atual')}
   if(detail.archive)setText(title,'Histórico completo de investimentos');
   const byKey=new Map(arr(detail.rows).map(row=>[String(row.key),row]));
   const titles={'__card_total__':'Cartões · composição do total','__account_total__':'Contas · composição do total'};
   if(titles[detail.group])setText(title,titles[detail.group]);
   const aggregateGroup=['faturas conciliadas pelo total','faturas sem composicao individual'].includes(normalize(detail.group));
   for(const tr of host.querySelectorAll('tr[data-row-key]')){
    if(tr.dataset.v181Row)continue;const row=byKey.get(String(tr.dataset.rowKey));if(!row)continue;tr.dataset.v181Row='1';
    const cell=tr.children[1],aggregate=aggregateGroup||row.document_status==='composition_missing'||/consolidado hist[oó]rico dos cart[oõ]es/i.test(String(row.account_source||''));
    if(row.current_category){const note=document.createElement('small');note.className='v231-classification';note.textContent='Classificação: '+window.LTSCategoryDisplay.category(row.current_category)+(row.category!==row.current_category?' · '+row.category:'');cell?.appendChild(note)}
    if(row.source_identity){const note=document.createElement('small');note.className='v231-source-note';note.textContent=row.source_identity.note+' Origem: '+row.source_identity.sheet+' · linha(s) '+arr(row.source_identity.rows).join(', ')+'.';cell?.appendChild(note)}
    if(row.source_audit&&row.composition?.status!=='complete'){const a=row.source_audit,note=document.createElement('small');note.className='v231-source-note v234-source-audit';note.textContent=a.note+' Origem: '+a.file+' · '+a.sheet+' · linha(s) '+arr(a.rows).join(', ')+'. Valor na fonte: '+money(a.source_amount)+'.'+(a.status==='unreconciled_detail'?' Detalhe recebido: '+a.detail_rows+' linhas · '+money(a.detail_total)+'. Diferença (detalhe − total): '+money(a.difference)+'.':'');cell?.appendChild(note)}
    if(aggregate&&row.composition?.status!=='complete'){const note=document.createElement('small');note.className='v181-aggregate-note';note.textContent='Registro de fatura sem composição completa. Não equivale a compras classificadas.'+(row.transaction_date?' Data do registro: '+dateLabel(row.transaction_date)+'.':'')+(row.invoice_month?' Fatura de '+monthLabel(row.invoice_month)+'.':'');cell?.appendChild(note)}
    if(!row.composition&&row.source_audit?.status!=='signed_adjustment'&&row.invoice_month&&row.invoice_family&&window.__LTS_V226?.openDetail){const button=document.createElement('button');button.className='v168-btn v231-invoice-detail';button.textContent='Ver composição da fatura';button.onclick=()=>window.__LTS_V226.openDetail(row.invoice_family,row.invoice_month);cell?.appendChild(button)}
    if(!row.composition&&['card_invoice_aggregate_fallback','card_workbook_signed_adjustment_v235'].includes(row.coverage_mode)&&window.__LTS_V235_HISTORY){const button=document.createElement('button');button.className='v168-btn v235-record-button';button.textContent='Conferir origem e composição';button.onclick=()=>window.__LTS_V235_HISTORY.openRecord(row);cell?.appendChild(button)}
    if(row.can_classify===true&&!detail.archive){const button=document.createElement('button');button.className='v168-btn v231-edit-classification';button.textContent='Corrigir classificação';button.onclick=()=>openClassification(row,{...detail.range},button);cell?.appendChild(button)}
    if(row.source_ref){const reference=document.createElement('details');reference.className='v231-record-reference';const label=document.createElement('summary');label.textContent='Referência do registro';const value=document.createElement('small');value.textContent='Identificador: '+row.source_ref;reference.append(label,value);cell?.appendChild(reference)}
   }
  }
  let classificationOptions=null;
  async function openClassification(row,range,trigger){
   document.getElementById('v231Classification')?.remove();
   const dialog=document.createElement('dialog');dialog.id='v231Classification';dialog.className='v231-classification-dialog';
   dialog.innerHTML='<form><header><h2>Corrigir classificação</h2><button type="button" data-close aria-label="Fechar">×</button></header><p><b>'+escape(row.description)+'</b><br>'+escape(row.account_source)+' · '+money(row.amount)+'</p><p class="v231-original">Descrição, data e valor originais serão preservados.</p><div data-fields>Carregando categorias…</div><p role="status"></p><footer><button type="button" class="v168-btn" data-close>Cancelar</button><button type="submit" class="v168-btn primary" disabled>Salvar classificação</button></footer></form>';
   document.body.appendChild(dialog);dialog.querySelectorAll('[data-close]').forEach(button=>button.onclick=()=>dialog.close());dialog.addEventListener('close',()=>{dialog.remove();trigger?.focus()});dialog.showModal();
   let saving=false;
   try{
    classificationOptions=window.LTSCategoryRegistry?await window.LTSCategoryRegistry.get(true):await rpc('lts_browser_card_category_options_v226',{});
    if(!dialog.isConnected)return;
    const categories=[row.current_category,...arr(classificationOptions.categories)],people=[{value:'Lucas',label:'Minha / sem prefixo'},'Larissa','Benjamin','Rafiki'],properties=[{value:'cipo396',label:'CIPÓ 396'},{value:'other_property',label:'Outro imóvel'},{value:'not_property',label:'Não é despesa de imóvel'}];
    dialog.querySelector('[data-fields]').innerHTML='<label>Categoria<select name="category" required>'+optionRows(categories,'Selecione a categoria',row.current_category,window.LTSCategoryDisplay.category)+'</select></label><label>Pessoa/contexto <small>opcional</small><select name="person">'+optionRows(people,'Preservar identificação atual',row.beneficiary)+'</select></label><label>Imóvel <small>opcional</small><select name="property">'+optionRows(properties,'Preservar identificação atual',row.property_code)+'</select></label>';
    window.LTSCategoryRegistry?.attach(dialog.querySelector('[name=category]'));
    const submit=dialog.querySelector('[type=submit]');submit.disabled=false;
    dialog.querySelector('form').onsubmit=async event=>{
     event.preventDefault();if(saving)return;saving=true;submit.disabled=true;submit.textContent='Salvando…';const status=dialog.querySelector('form > [role=status]');status.textContent='';
     try{
      await rpc('lts_browser_expense_classification_v232',{p_from:row.event_date||range.from,p_to:row.event_date||range.to,p_row_key:row.key,p_category:dialog.querySelector('[name=category]').value||null,p_beneficiary:dialog.querySelector('[name=person]').value||null,p_property_code:dialog.querySelector('[name=property]').value||null});
      const current=v178?.detail,group=current?.group,subgroup=current?.subgroup;state.review.data=null;state.review.status='idle';state.review.notice='Classificação salva a partir do detalhamento.';
      dialog.close();invalidateExpense();render();await detailApi.openDetail(group,subgroup,range,null);
     }catch(error){status.textContent='Não foi possível salvar a classificação. Confira a conexão e tente novamente.';submit.disabled=false;submit.textContent='Salvar classificação'}
     finally{saving=false}
    };
   }catch(error){dialog.querySelector('[role=status]').textContent='Não foi possível carregar as categorias. Feche e tente novamente.'}
  }
  function decorateExpenseNumbers(){
   if(V!=='Despesas'||v168?.expense?.tab!=='overview')return;
   const root=document.querySelector('.v168-expenses'),report=v175?.expense?.data;if(!root||!report)return;
   const range=expenseRange(),summary=report.summary||{},monthly=arr(report.monthly_detail),last=monthly.at(-1),comparison=report.comparison||{};
   const monthRange=(value,end)=>({from:String(value).slice(0,7)+'-01',to:end||new Date(Date.UTC(Number(String(value).slice(0,4)),Number(String(value).slice(5,7)),0)).toISOString().slice(0,10)});
   const specs={
    'total do periodo':{expected:summary.selected_total},'cartoes':{group:'__card_total__',expected:summary.card_total},'contas':{group:'__account_total__',expected:summary.account_total},
    'media mensal':{expected:summary.selected_total,note:'Média mensal = total dos lançamentos ÷ '+report.period?.months_in_selection+' meses.'},
    'ultimo mes disponivel':{range:last?{from:range.from>String(last.month)?range.from:String(last.month),to:range.to}:range,expected:last?.total},
    'periodo selecionado':{expected:summary.selected_total}
   };
   const last12=new Date(range.to.slice(0,7)+'-01T12:00:00Z');last12.setUTCMonth(last12.getUTCMonth()-11);specs['ultimos 12 meses']={range:{from:last12.toISOString().slice(0,10),to:range.to},expected:summary.last_12m};
   const previous=new Date(range.to.slice(0,7)+'-01T12:00:00Z');previous.setUTCMonth(previous.getUTCMonth()-1);const priorRange=monthRange(previous.toISOString());priorRange.to=priorRange.to.slice(0,8)+String(Math.min(Number(range.to.slice(8)),Number(priorRange.to.slice(8)))).padStart(2,'0');specs['mes anterior']={range:priorRange,expected:comparison.previous_total};
   for(const node of root.querySelectorAll('.v168-kpi,.v168-stat')){
    const label=normalize(node.querySelector(':scope>span')?.textContent).replace(/ · ate o mesmo dia$/,''),spec=specs[label],value=node.querySelector(':scope>strong,:scope>b');
    if(!spec||!value||value.querySelector('button')||finite(spec.expected)==null)continue;
    const button=document.createElement('button');button.className='v231-number-detail';button.setAttribute('aria-label','Ver composição: '+node.querySelector(':scope>span').textContent);button.textContent=value.textContent;
    button.onclick=async()=>{await detailApi.openDetail(spec.group||null,null,spec.range||range,spec.expected);if(spec.note&&document.querySelector('#v178Drawer .v178-detail-summary')){const note=document.createElement('small');note.className='v231-average-note';note.textContent=spec.note;document.querySelector('#v178Drawer .v178-detail-summary').appendChild(note)}};value.replaceChildren(button);
   }
  }
  function decorateMonthlyNumbers(){
   if(V!=='Despesas'||v168?.expense?.tab!=='monthly'||!v175?.monthly?.data)return;
   const data=v175.monthly.data,range=expenseRange(),year=String(v175.monthly.year),months=arr(data.months).filter(m=>String(m).startsWith(year));
   const bounded=(from,to)=>({from:from<range.from?range.from:from,to:to>range.to?range.to:to});
   function attach(cell,group,dates,expected){
    if(!cell||cell.querySelector('button')||finite(expected)==null||expected===0||dates.from>dates.to)return;
    const button=document.createElement('button');button.className='v231-number-detail';button.textContent=cell.textContent;
    button.setAttribute('aria-label','Ver lançamentos: '+(group||'Despesas')+' · '+dates.from+' a '+dates.to);
    button.onclick=()=>detailApi.openDetail(group,null,dates,expected);cell.replaceChildren(button);
   }
   for(const section of document.querySelectorAll('.v175-monthly .v175-section')){
    const title=section.querySelector('h2')?.textContent;
    if(title==='Despesas por categoria')for(const row of section.querySelectorAll('tbody tr')){
     const name=row.dataset.ltsCategoryKey??row.querySelector('th')?.textContent,group=arr(data.expense_groups).find(g=>g.label===name||g.name===name);if(!group)continue;
     const cells=[...row.querySelectorAll('td')];
     months.forEach((month,i)=>{const date=new Date(String(month).slice(0,7)+'-01T12:00:00Z');date.setUTCMonth(date.getUTCMonth()+1);date.setUTCDate(0);attach(cells[i],name,bounded(String(month).slice(0,10),date.toISOString().slice(0,10)),finite(arr(group.monthly).find(x=>String(x.month)===String(month))?.amount))});
     attach(cells.at(-1),name,bounded(year+'-01-01',year+'-12-31'),sum(arr(group.monthly).filter(m=>String(m.month).startsWith(year)).map(m=>m.amount)));
    }
    if(title==='Resultado anual')for(const row of section.querySelectorAll('tbody tr')){
     const y=row.querySelector('th')?.textContent;attach(row.querySelectorAll('td')[1],null,bounded(y+'-01-01',y+'-12-31'),sum(arr(data.monthly_totals).filter(m=>String(m.month).startsWith(y)).map(m=>m.expenses)));
    }
   }
  }
  function decorateVersion(){
   document.querySelectorAll('.brand small').forEach(node=>node.setAttribute('aria-label','V181 · Homologação'));
   document.querySelectorAll('.v168-headmeta').forEach(node=>{if(!node.querySelector('.v181-release'))node.insertAdjacentHTML('beforeend','<span class="v181-release">V181 · Homologação</span>')});
   try{const scope=window.parent.document.getElementById('scope');if(scope)scope.setAttribute('aria-label','V181 · '+(V==='Fluxo Diário'?'Fluxo de caixa':V)+' · Homologação')}catch{}
  }
  function bind(){
   decorateVersion();decorateDrawer();decorateExpenseNumbers();decorateMonthlyNumbers();
   if(V==='Atualizações'&&state.review.status==='idle')queueMicrotask(()=>ensureReview(false));
   if(V==='Despesas'&&v168?.expense?.tab==='categories'&&state.review.status==='idle')queueMicrotask(()=>ensureReview(false));
   if(V==='Despesas'&&v168?.expense?.tab==='cards'&&state.reconciliation.status==='idle')queueMicrotask(()=>ensureReconciliation(false));
   document.querySelectorAll('.v178-pending-open').forEach(button=>{button.textContent=button.textContent.replace('Identificações pendentes','Classificar identificações');button.onclick=goReview});
   document.querySelectorAll('.v178-coverage-open').forEach(button=>{button.textContent=button.textContent.replace('Faturas a detalhar','Faturas sem composição individual')});
   document.querySelectorAll('[data-v181-review-key] select').forEach(select=>select.onchange=()=>updateReviewChoice(select.closest('[data-v181-review-key]'),true));
   document.querySelectorAll('[data-v181-category]').forEach(select=>window.LTSCategoryRegistry?.attach(select));
   document.querySelectorAll('[data-v181-review-save]').forEach(button=>button.onclick=()=>saveReview(button));
   document.querySelectorAll('[data-v181-review-key]').forEach(row=>updateReviewChoice(row));
   document.querySelectorAll('[data-v230-review-projection]').forEach(button=>button.onclick=async()=>{
    const e=arr(state.review.data?.pending_projections)[Number(button.dataset.v230ReviewProjection)];if(!e)return;
    V='Fluxo Diário';renderNav();await loadFlowRange(e.event_date,addDays(e.event_date,5));await openFlowEditor(e);document.getElementById('d-'+e.event_date)?.scrollIntoView({block:'center'});
   });
   document.querySelector('[data-v181-review-retry]')?.addEventListener('click',()=>{state.review.status='idle';ensureReview(true)});
   document.querySelector('[data-v181-review-search]')?.addEventListener('click',()=>{state.review.query=document.querySelector('[data-v181-review-query]')?.value.trim()||'';state.review.offset=0;state.review.status='idle';ensureReview(true)});
   document.querySelector('[data-v181-review-query]')?.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();document.querySelector('[data-v181-review-search]')?.click()}});
   document.querySelector('[data-v181-review-prev]')?.addEventListener('click',()=>{state.review.offset=Math.max(0,state.review.offset-25);state.review.status='idle';ensureReview(true)});
   document.querySelector('[data-v181-review-next]')?.addEventListener('click',()=>{state.review.offset=Number(state.review.data?.next_offset||state.review.offset);state.review.status='idle';ensureReview(true)});
   document.querySelector('[data-v181-reconciliation-retry]')?.addEventListener('click',()=>{state.reconciliation.status='idle';ensureReconciliation(true)});
   document.querySelectorAll('[data-v181-flow-date]').forEach(button=>button.onclick=()=>goFlow(button.dataset.v181FlowDate));
   document.querySelectorAll('[data-v181-category-view]').forEach(button=>button.onclick=()=>{state.categoryView=button.dataset.v181CategoryView;render()});
   document.querySelectorAll('[data-v181-detail-group]').forEach(button=>button.onclick=()=>detailApi.openDetail(button.dataset.v181DetailGroup,button.dataset.v181DetailSubgroup||null,expenseRange(),null));
   document.querySelectorAll('.v181-category-panel .v178-review-actions').forEach(node=>node.remove());
   if(state.focusQueue&&V==='Atualizações'){state.focusQueue=false;setTimeout(()=>document.getElementById('v181ReviewQueue')?.scrollIntoView({behavior:'smooth',block:'start'}),80)}
  }
  despesas=expenses181;atualizacoes=updates181;
  render=function(){const result=previousRender();bind();return result};
  renderNav=function(){const result=previousNav();decorateVersion();return result};
  const observer=new MutationObserver(()=>decorateDrawer());observer.observe(document.body,{childList:true,subtree:true});
  window.__LTS_V181_REGRESSION_CLOSURE={installed:true,version:'v181-regression-closure',baseline:'v180-documentary-refresh',contracts:{one_invoice_per_card_cycle:true,review_requires_explicit_confirmation:true,owner_category_has_no_prefix:true,category_views_are_alternatives:true,aggregate_only_rows_disclosed:true,drawer_decoration_idempotent:true,protected_root_unchanged:true},state};
  if(D&&!N.classList.contains('hidden'))render();
 }
 function install(){try{
  const frameWindow=outer?.contentWindow,frameDocument=outer?.contentDocument;if(!frameWindow?.__LTS_V180_DOCUMENTARY_REFRESH?.installed||!frameWindow?.__LTS_V178_REVIEW_ACTIONS?.installed)return false;
  if(!frameDocument.getElementById('v181-style')){const link=frameDocument.createElement('link');link.id='v181-style';link.rel='stylesheet';link.href='lts-v181-regression-closure.css?v=20260922-v181a';frameDocument.head.appendChild(link)}
  if(!frameWindow.__LTS_V181_REGRESSION_CLOSURE?.installed&&!frameDocument.getElementById('v181-runtime')){const script=frameDocument.createElement('script');script.id='v181-runtime';script.textContent='('+runtime.toString()+')();';frameDocument.head.appendChild(script)}
  if(frameWindow.__LTS_V181_REGRESSION_CLOSURE?.installed){document.getElementById('gate')?.remove();return true}return false;
 }catch{return false}}
 function burst(){const current=++generation;let count=0;function step(){if(current!==generation)return;if(!install()&&++count<320)setTimeout(step,100)}step()}
 outer?.addEventListener('load',burst);burst();
 window.LTSV339Boot?.watch('lts-v181-regression-closure.js',install);
})();

;
;
/* LTS V384: lts-v183-v182-feedback-safe.js */
/* V183 isolated copy of V182 follow-up: wait for authenticated product state. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function install(){
  try{
   const w=shell?.contentWindow,d=shell?.contentDocument;
   if(!w?.__LTS_V181_REGRESSION_CLOSURE?.installed||!w?.__LTS_V175_STATE)return false;
   if(w.__LTS_V182_FEEDBACK?.installed)return true;
   const run=function(){
    const v168=window.__LTS_V168_STATE,v175=window.__LTS_V175_STATE,detail=window.__LTS_V178_REVIEW;
    const oldExpenses=despesas,oldRender=render;
    const safe=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    const n=x=>Number.isFinite(Number(x))?Number(x):0;
    const money=x=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(n(x));
    const current=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
    const range=()=>{const s=v168.expense,t=current(),year=t.slice(0,4);let from=year+'-01-01';if(s.key==='all')from='2013-10-10';else if(s.key==='6m'||s.key==='12m'){const d=new Date(t.slice(0,7)+'-01T12:00:00Z');d.setUTCMonth(d.getUTCMonth()-(s.key==='6m'?5:11));from=d.toISOString().slice(0,10)}else if(s.key==='custom')from=s.customFrom||from;return{from,to:s.key==='custom'?(s.customTo||t):t}};
    const monthText=k=>{const p=String(k).slice(0,7);return /^\d{4}-\d\d$/.test(p)?new Intl.DateTimeFormat('pt-BR',{month:'short',year:'numeric'}).format(new Date(p+'-01T12:00:00Z')).replace('.',''):p};
    function selectedMonths(data){const r=range();return (Array.isArray(data?.months)?data.months:[]).map(x=>String(x).slice(0,7)).filter(x=>x>=r.from.slice(0,7)&&x<=r.to.slice(0,7)).sort()}
    function summary(data,months){
     const values=new Map((Array.isArray(data?.monthly_totals)?data.monthly_totals:[]).map(x=>[String(x.month).slice(0,7),x]));let entries=0,expense=0,operational=0,extra=0;
     const body=months.map(k=>{const x=values.get(k)||{},rev=n(x.revenue),ex=n(x.extraordinary),out=n(x.expenses),total=rev+ex-out;entries+=rev+ex;expense+=out;operational+=rev;extra+=ex;return '<tr><th>'+safe(monthText(k))+'</th><td>'+money(rev)+'</td><td>'+money(ex)+'</td><td>'+money(rev+ex)+'</td><td>'+money(out)+'</td><td>'+money(total)+'</td></tr>'}).join('');
     const r=range(),label=r.from.split('-').reverse().join('/')+' a '+r.to.split('-').reverse().join('/');
     return '<article class="v175-section v182-months"><div class="v168-cardhead"><div><span>'+safe(label)+'</span><h2>Resumo de cada mês</h2></div><small>'+months.length+' meses no período</small></div><div class="v175-tablewrap"><table class="v175-table"><thead><tr><th>Mês</th><th>Receitas operacionais</th><th>Extraordinárias</th><th>Entradas</th><th>Despesas</th><th>Resultado</th></tr></thead><tbody>'+body+'<tr class="v182-total"><th>Total do período</th><td>'+money(operational)+'</td><td>'+money(extra)+'</td><td>'+money(entries)+'</td><td>'+money(expense)+'</td><td>'+money(entries-expense)+'</td></tr></tbody></table></div><p>Resultado é entradas menos despesas; não é saldo bancário acumulado.</p></article>';
    }
    function detailButton(label,amount,month,text){
     if(!Number.isFinite(Number(amount)))return safe(text);
     return '<button type="button" class="v183-month-detail" data-group="'+safe(label)+'" data-month="'+safe(month||'')+'" data-amount="'+safe(amount)+'" aria-label="'+safe('Ver lançamentos de '+window.LTSCategoryDisplay.category(label)+(month?' em '+monthText(month):' no período'))+'">'+safe(text===label?window.LTSCategoryDisplay.category(text):text)+'</button>';
    }
    function detailRange(month,r){
     if(!month)return {...r};
     if(!/^\d{4}-\d{2}$/.test(month)||Number(month.slice(5))<1||Number(month.slice(5))>12)return null;
     const start=month+'-01',end=new Date(Date.UTC(Number(month.slice(0,4)),Number(month.slice(5)),0)).toISOString().slice(0,10);
     const from=start<r.from?r.from:start,to=end>r.to?r.to:end;
     return from<=to?{from,to}:null;
    }
    function bindMonthlyDetails(){
     document.querySelectorAll('.v183-month-detail').forEach(button=>{button.onclick=()=>{
      const r=range(),data=v175?.monthly?.data;
      if(!data||v175.monthly.loading||v175.monthly.key!==r.from+'|'+r.to)return;
      const month=button.dataset.month,selected=detailRange(month,r),label=button.dataset.group;
      if(!selected||!detail?.openDetail)return;
      const groups=Array.isArray(data.expense_groups)?data.expense_groups:[];
      const coverage=data.expense_unclassified_card_coverage;
      const group=groups.find(x=>(x.label||x.name)===label)||(coverage?.label===label?coverage:null);
      if(!group)return;
      const amount=month?(group.monthly||[]).find(x=>String(x.month).slice(0,7)===month)?.amount:group.total;
      if(amount==null||!Number.isFinite(Number(amount))||Math.abs(Number(amount)-Number(button.dataset.amount))>0.02)return;
      detail.openDetail(label,null,selected,Number(amount));
     }});
    }
    function matrix(title,groups,months,coverage,expandable=false){
     const rows=Array.isArray(groups)?groups:[],totals=months.map(()=>0),items=[];
     function row(label,caption,vals){const total=vals.reduce((a,b)=>a+b,0),show=(v,m,text)=>expandable?detailButton(label,v,m,text):safe(text);return '<tr data-lts-category-key="'+safe(label)+'"><th>'+show(total,'',caption)+'</th>'+vals.map((v,i)=>'<td>'+(v?show(v,months[i],money(v)):'—')+'</td>').join('')+'<td>'+show(total,'',money(total))+'</td></tr>'}
     for(const group of rows){const lookup=new Map((group.monthly||[]).map(x=>[String(x.month).slice(0,7),n(x.amount)]));const vals=months.map((k,i)=>{const v=lookup.get(k)||0;totals[i]+=v;return v});if(vals.every(v=>Math.abs(v)<0.005))continue;items.push(row(group.label||group.name,group.label||group.name,vals))}
     if(coverage){const lookup=new Map((coverage.monthly||[]).map(x=>[String(x.month).slice(0,7),n(x.amount)]));const vals=months.map((k,i)=>{const v=lookup.get(k)||0;totals[i]+=v;return v});if(vals.some(v=>Math.abs(v)>=0.005))items.push(row(coverage.label||'Faturas conciliadas pelo total','Faturas sem composição individual',vals))}
     return '<article class="v175-section v182-matrix"><div class="v168-cardhead"><div><span>Período selecionado</span><h2>'+safe(title)+'</h2></div></div><div class="v175-tablewrap"><table class="v175-table"><thead><tr><th>Grupo</th>'+months.map(m=>'<th>'+safe(monthText(m))+'</th>').join('')+'<th>Total</th></tr></thead><tbody>'+items.join('')+'<tr class="v182-total"><th>Total '+safe(title.toLowerCase())+'</th>'+totals.map(v=>'<td>'+money(v)+'</td>').join('')+'<td>'+money(totals.reduce((a,b)=>a+b,0))+'</td></tr></tbody></table></div></article>';
    }
    function finalBalance(data,months){const lookup=new Map((data.monthly_totals||[]).map(x=>[String(x.month).slice(0,7),x]));const values=months.map(k=>{const x=lookup.get(k)||{};return n(x.revenue)+n(x.extraordinary)-n(x.expenses)});return '<article class="v175-section v182-matrix"><div class="v168-cardhead"><div><span>Depois de todos os grupos</span><h2>Resultado do período</h2></div></div><div class="v175-tablewrap"><table class="v175-table"><thead><tr><th>Entradas − despesas</th>'+months.map(m=>'<th>'+safe(monthText(m))+'</th>').join('')+'<th>Total</th></tr></thead><tbody><tr class="v182-total"><th>Resultado</th>'+values.map(v=>'<td>'+money(v)+'</td>').join('')+'<td>'+money(values.reduce((a,b)=>a+b,0))+'</td></tr></tbody></table></div></article>'}
    function monthly(root){const host=root.querySelector('.v175-monthly'),data=v175?.monthly?.data,r=range();if(!host||!data||v175.monthly.key!==r.from+'|'+r.to)return;const months=selectedMonths(data);if(!months.length)return;
     host.querySelector('.v181-month-summary')?.remove();host.querySelector('.v175-yearbar')?.remove();host.querySelectorAll('.v175-section').forEach(x=>x.remove());
     const kpis=host.querySelector('.v168-kpis');if(!kpis)return;
     kpis.insertAdjacentHTML('beforebegin','<div class="v379-period-head"><h2>Acumulado do período</h2><p>'+safe(r.from.split('-').reverse().join('/')+' a '+r.to.split('-').reverse().join('/'))+'</p></div>');
     kpis.insertAdjacentHTML('afterend',summary(data,months)+matrix('Receitas operacionais',data.revenue_groups,months)+matrix('Entradas extraordinárias',data.extraordinary_groups,months)+matrix('Despesas por categoria',data.expense_groups,months,data.expense_unclassified_card_coverage,true)+finalBalance(data,months));
    }
    despesas=function(){const t=document.createElement('template');t.innerHTML=oldExpenses();const root=t.content.querySelector('.v168-expenses');if(root&&v168.expense.tab==='monthly')monthly(root);return t.innerHTML};
    render=function(){const result=oldRender();document.querySelectorAll('.v181-release').forEach(x=>x.textContent='V182 · Homologação');if(V==='Dashboard'){document.querySelectorAll('button').forEach(button=>{const label=button.textContent.trim();if(label==='Empréstimos'||label==='Apartamento · CIPÓ 396'){button.setAttribute('aria-label','Abrir '+label+' e seus componentes');button.classList.add('v182-expand-cue');}})}return result};
    const detailRender=render;
    render=function(){const result=detailRender();bindMonthlyDetails();return result};
    if(!document.getElementById('v183-month-detail-style')){const style=document.createElement('style');style.id='v183-month-detail-style';style.textContent='.v183-month-detail{font:inherit;color:inherit;background:transparent;border:0;padding:4px 0;cursor:pointer;text-align:inherit;text-decoration:underline;text-decoration-color:#94a3b8;text-underline-offset:3px}.v183-month-detail:focus-visible{outline:2px solid #2563eb;outline-offset:3px;border-radius:2px}';document.head.appendChild(style)}
    window.__LTS_V182_FEEDBACK={installed:true,version:'v183-monthly-detail',contracts:{full_selected_months:true,group_subtotals:true,source_values_unchanged:true,expense_month_drilldown:true}};
    // A saved Flow route can be restored before the authenticated product loads.
    // The base renderer reads D.flow on that route, so defer the initial paint.
    if(D&&!N.classList.contains('hidden'))render();
   };
   const script=d.createElement('script');script.id='v182-runtime';script.textContent='('+run.toString()+')();';d.head.appendChild(script);return !!w.__LTS_V182_FEEDBACK?.installed;
  }catch{return false}
 }
 let attempts=0;const timer=setInterval(()=>{if(install()||++attempts>100)clearInterval(timer)},150);
 shell?.addEventListener('load',()=>{attempts=0;if(!install())setTimeout(install,300)});
 window.LTSV339Boot?.watch('lts-v183-v182-feedback-safe.js',install);
})();

;
;
/* LTS V384: lts-v183-income-review.js */
/* Candidate-only receipt review. No amount/date mutation and no broad rule. */
(function(){
 'use strict';
 function runtime(){
  if(window.__LTS_V183_INCOME_REVIEW)return;
  const oldBadge=flowClassificationBadge,oldBind=bindFlowEditor;
  const safe=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function receiptKey(e){return JSON.stringify([e.source||e.source_table||'',e.source_ref||'',e.event_date||'',e.account||'',String(e.signed_amount??'')])}
  function isUnclassifiedReceipt(e){return Number(e.signed_amount)>0&&!e.internal_transfer&&!e.asset_movement&&!e.excluded_from_spend&&!e.excluded&&!e.is_projection&&!e.unposted_past_projection&&!e.unposted_current_projection&&['','a classificar','—','classificação pendente','sem categoria','não identificado'].includes(String(e.category||'').trim().toLowerCase())}
  function request(e){return {p_source:e.open_finance_id?'open_finance':(e.source||e.source_table||''),p_source_ref:String(e.open_finance_id||e.source_ref||''),p_event_date:e.event_date,p_account:e.account,p_amount:Number(e.signed_amount)}}
  function invalidateMonthly(){
   const monthly=window.__LTS_V175_STATE?.monthly;
   if(monthly){monthly.token=(monthly.token||0)+1;monthly.key='';monthly.data=null;monthly.loading=false;monthly.error=null;monthly.progress=''}
  }
  async function openReceipt(e,trigger){
   document.getElementById('v183-income-dialog')?.remove();
   const dialog=document.createElement('dialog');dialog.id='v183-income-dialog';
   dialog.setAttribute('aria-labelledby','v183-income-title');
   dialog.innerHTML='<h2 id="v183-income-title">Revisar esta receita</h2><p><strong>'+safe(e.description||'Recebimento')+'</strong><br>'+safe(e.event_date)+' · '+safe(e.account)+' · '+safe(brl(e.signed_amount))+'</p><p>Somente a categoria deste lançamento. Valor, data, conta e saldo não serão alterados.</p><div class="income-content" aria-live="polite">Conferindo a origem…</div><p class="income-status" role="status"></p><div class="income-actions"><button type="button" class="chip income-close">Fechar</button></div>';
   document.body.appendChild(dialog);let saving=false,preview=null;
   const status=dialog.querySelector('.income-status'),content=dialog.querySelector('.income-content'),close=dialog.querySelector('.income-close');
   const finish=()=>{if(saving)return;dialog.close();dialog.remove();if(trigger?.isConnected)trigger.focus()};
   close.onclick=finish;dialog.oncancel=event=>{event.preventDefault();finish()};dialog.showModal();close.focus();
   try{
    const {data,error}=await S.rpc('lts_browser_income_category_v183',request(e));
    if(!dialog.isConnected)return;
    if(error||!data?.ok)throw Error(error?.message||'Não foi possível conferir a origem.');
    if(!data.editable){content.textContent='Este recebimento já está classificado.'+(data.category?' Classificação: '+data.category+'.':'');return}
    if(!data.token||!Array.isArray(data.options)||!data.options.length)throw Error('Conferência incompleta; nenhuma gravação disponível.');
    preview=data;
    content.innerHTML='<label for="v183-income-category">Categoria da receita</label><select id="v183-income-category"><option value="">Selecione…</option>'+data.options.map(x=>'<option value="'+safe(x)+'">'+safe(x)+'</option>').join('')+'</select><p>Não cria uma regra para outros lançamentos com a mesma descrição.</p>';
    const select=content.querySelector('select'),save=document.createElement('button');save.type='button';save.className='chip';save.textContent='Salvar somente esta categoria';save.disabled=true;
    dialog.querySelector('.income-actions').prepend(save);select.onchange=()=>{save.disabled=!select.value};window.LTSCategoryRegistry?.attach(select);select.focus();
    save.onclick=async()=>{
     if(saving||!select.value)return;
     saving=true;save.disabled=true;select.disabled=true;close.disabled=true;status.textContent='Salvando a categoria…';
     try{
      const result=await S.rpc('lts_browser_income_category_v183',{...request(e),p_category:select.value,p_expected:preview.token});
      if(result.error||!result.data?.saved)throw Error(result.error?.message||result.data?.reason||'A categoria não foi salva.');
      window.__LTS_V227_TRANSPORT?.invalidate();invalidateMonthly();status.textContent='Classificação salva.';save.remove();
      window.dispatchEvent(new CustomEvent('lts:income-classified',{detail:{event:e,category:select.value}}));
      // Preserve Actions; only reload a visible Flow range.
      if(V==='Fluxo Diário')await loadFlowRange(FLOWFROM||e.event_date,FLOWTO||e.event_date);
     }catch(err){
      status.textContent='Não foi possível confirmar a gravação. Feche e atualize a lista antes de tentar novamente.';
      // No automatic retry after a potentially committed request.
      save.remove();
     }finally{saving=false;close.disabled=false;close.focus()}
    };
   }catch(err){if(dialog.isConnected)content.textContent='Não foi possível abrir este recebimento. Atualize a lista e tente novamente.'}
  }
  flowClassificationBadge=function(e){return isUnclassifiedReceipt(e)?'<button type="button" class="tag flow-unclassified v183-income-review" data-income-key="'+safe(receiptKey(e))+'">Receita a classificar · revisar</button>':oldBadge(e)};
  bindFlowEditor=function(){const result=oldBind();document.querySelectorAll('.v183-income-review').forEach(button=>button.onclick=()=>{
   const matches=mergedFlowEvents().filter(e=>receiptKey(e)===button.dataset.incomeKey);
   if(matches.length===1)openReceipt(matches[0],button);else alert('Lançamento ausente ou ambíguo. Atualize o período antes de revisar.');
  });return result};
  const style=document.createElement('style');style.textContent='#v183-income-dialog{color:#17283c;border:1px solid #cfdae4;border-radius:18px;padding:24px;width:min(520px,calc(100vw - 32px));max-height:calc(100dvh - 32px);overflow:auto;box-sizing:border-box;box-shadow:0 20px 80px #0004}#v183-income-dialog::backdrop{background:#10203388}#v183-income-dialog select{display:block;width:100%;padding:12px;margin:8px 0;border:1px solid #aebdca;border-radius:8px}#v183-income-dialog .income-actions{display:flex;flex-wrap:wrap;justify-content:flex-end;gap:12px}#v183-income-dialog p{line-height:1.5}';document.head.appendChild(style);
  window.__LTS_V183_INCOME_REVIEW={installed:true,source_keyed:true,cash_unchanged:true,openReceipt,isUnclassifiedReceipt};
  if(D&&!N.classList.contains('hidden')&&V==='Fluxo Diário')render();
 }
 const shell=document.getElementById('shell');
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V182_FEEDBACK?.installed)return false;if(w.__LTS_V183_INCOME_REVIEW)return true;const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);return !!w.__LTS_V183_INCOME_REVIEW}catch{return false}}
 let attempts=0;const timer=setInterval(()=>{if(install()||++attempts>160)clearInterval(timer)},150);
 shell?.addEventListener('load',()=>{attempts=0;const retry=setInterval(()=>{if(install()||++attempts>160)clearInterval(retry)},150)});
 window.LTSV339Boot?.watch('lts-v183-income-review.js',install);
})();

;
;
/* LTS V384: lts-v183-search-completeness.js */
/* Candidate-only complete history search. No changes to source rows or writers. */
(function(){
 'use strict';
 function runtime(){
  if(window.__LTS_V183_SEARCH_COMPLETE)return;
  const previous=S.rpc.bind(S),search=window.__LTS_V168_STATE.search;
  function matches(name,args){return name==='lts_browser_transactions_v2'&&args?.p_from==='2013-10-10'&&args.p_to===null&&typeof args.p_query==='string'&&args.p_query.trim()!==''&&args.p_direction===null&&args.p_account===null&&args.p_limit===200&&args.p_offset===0}
  S.rpc=async function(name,args){
   if(!matches(name,args))return previous(name,args);
   const seq=search.seq,query=args.p_query,rows=[],keys=new Set();let expected=null,first=null;
   const current=()=>search.seq===seq&&String(search.query||'').trim()===query.trim();
   try{
    for(let offset=0;offset<10000;offset+=200){
     if(!current())throw Error('Busca substituída.');
     const result=await previous(name,{...args,p_offset:offset});
     if(!current())throw Error('Busca substituída.');
     if(result.error||!result.data)throw Error(result.error?.message||'Busca indisponível.');
     const page=result.data,total=Number(page.total);
     if(page.total==null||!Number.isSafeInteger(total)||total<0||!Array.isArray(page.rows))throw Error('Resposta incompleta. Tente buscar novamente.');
     if(total>10000)throw Error('Há mais de 10.000 resultados. Refine a busca; nenhum resultado parcial foi exibido.');
     if(expected===null){expected=total;first=page}else if(expected!==total)throw Error('Os resultados mudaram durante a busca. Busque novamente.');
     if(page.rows.length!==Math.min(200,expected-offset))throw Error('Página incompleta. Busque novamente; nenhum resultado parcial foi exibido.');
     for(const row of page.rows){
      const key=JSON.stringify([row.source,row.source_ref,row.date,row.amount]);
      if(keys.has(key))throw Error('Resultados repetidos durante a busca. Busque novamente.');
      keys.add(key);rows.push(row);
     }
     if(rows.length===expected)return {data:{...first,rows,total:expected,offset:0,limit:rows.length,complete:true},error:null};
    }
    throw Error('Busca incompleta. Refine os termos.');
   }catch(error){return {data:null,error:{message:String(error?.message||error)}}}
  };
  window.__LTS_V183_SEARCH_COMPLETE={installed:true,read_only:true};
 }
 const shell=document.getElementById('shell');
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V183_INCOME_REVIEW?.installed)return false;if(w.__LTS_V183_SEARCH_COMPLETE)return true;const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);return !!w.__LTS_V183_SEARCH_COMPLETE}catch{return false}}
 function burst(){let count=0;const timer=setInterval(()=>{if(install()||++count>160)clearInterval(timer)},150)}
 shell?.addEventListener('load',burst);burst();
 window.LTSV339Boot?.watch('lts-v183-search-completeness.js',install);
})();

;
;
/* LTS V384: lts-v183-exact-flow-navigation.js */
/* Candidate-only: explicit transaction navigation owns its requested date. */
(function(){
 'use strict';
 function runtime(){
  if(window.__LTS_V183_EXACT_FLOW_NAVIGATION)return;
  const baseRender=render;
  function bind(){
   document.querySelectorAll('[data-v168-search-flow],[data-v168-search-edit],[data-v168-flow-row],[data-v237-coverage-from]').forEach(button=>{
    const previous=button.onclick;
    if(typeof previous!=='function'||previous.__v183ExactFlow)return;
    function explicitNavigation(event){
     // V162 and V170 enqueue default ranges when entering Flow. During this
     // synchronous handler only, suppress those defaults; keep the original
     // exact-date loader, row focus, edit permissions and editor untouched.
     const recovery=window.__LTS_V162_FLOW_RECOVERY_STATUS,review=window.__LTS_V170_STATE;
     const applied=recovery?.default_range_applied,last=review?.lastRoute;
     if(recovery)recovery.default_range_applied=false;
     if(review)review.lastRoute='Fluxo Diário';
     try{return previous.call(this,event)}
     finally{
      if(recovery)recovery.default_range_applied=applied;
      if(review&&V!=='Fluxo Diário')review.lastRoute=last;
     }
    }
    explicitNavigation.__v183ExactFlow=true;button.onclick=explicitNavigation;
   });
  }
  render=function(){const result=baseRender.apply(this,arguments);bind();return result};
  window.__LTS_V183_EXACT_FLOW_NAVIGATION={installed:true};bind();
 }
 const shell=document.getElementById('shell');
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V183_SEARCH_COMPLETE?.installed)return false;if(w.__LTS_V183_EXACT_FLOW_NAVIGATION)return true;const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);return !!w.__LTS_V183_EXACT_FLOW_NAVIGATION}catch{return false}}
 function burst(){let count=0;const timer=setInterval(()=>{if(install()||++count>160)clearInterval(timer)},150)}
 shell?.addEventListener('load',burst);burst();
 window.LTSV339Boot?.watch('lts-v183-exact-flow-navigation.js',install);
})();

;
;
/* LTS V384: lts-v183-flow-period-state.js */
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
 window.LTSV339Boot?.watch('lts-v183-flow-period-state.js',install);
})();

;
;
/* LTS V384: lts-v183-card-period-candidate.js */
/* V183 candidate: scope invoice reconciliation to the user's selected period. */
(function(){
  'use strict';
  const shell=document.getElementById('shell');
  function install(){
    try{
      const w=shell?.contentWindow,d=shell?.contentDocument;
      if(!w?.__LTS_V182_FEEDBACK?.installed)return false;
      if(w.__LTS_V183_CARD_PERIOD?.installed)return true;
      const runtime=function(){
        const v233Formatters=[new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}),new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'})];
        const v168=window.__LTS_V168_STATE,v175=window.__LTS_V175_STATE;
        const oldExpenses=despesas,oldRender=render;
        const state=window.__LTS_V183_CARD_PERIOD={installed:true,status:'idle',key:'',token:0,rows:[],documentary:[],legacy:[],error:null,periods:0};
        const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
        const money=x=>v233Formatters[0].format(Number(x)||0);
        const date=x=>/^\d{4}-\d\d-\d\d$/.test(String(x||''))?x.split('-').reverse().join('/'):String(x||'—');
        const today=()=>v233Formatters[1].format(new Date());
        function range(){
          const s=v168?.expense||{},to=today(),year=to.slice(0,4);
          if(s.key==='all')return{from:'2013-10-10',to};
          if(s.key==='custom'&&/^\d{4}-\d\d-\d\d$/.test(s.customFrom||'')&&/^\d{4}-\d\d-\d\d$/.test(s.customTo||''))return{from:s.customFrom,to:s.customTo};
          if(s.key==='6m'||s.key==='12m'){
            const d=new Date(to.slice(0,7)+'-01T12:00:00Z');d.setUTCMonth(d.getUTCMonth()-(s.key==='6m'?5:11));return{from:d.toISOString().slice(0,10),to};
          }
          return{from:year+'-01-01',to};
        }
        function chunks(from,to){
          const result=[];let start=from;
          while(start<=to){const d=new Date(start+'T12:00:00Z');d.setUTCFullYear(d.getUTCFullYear()+2);d.setUTCDate(d.getUTCDate()-1);const end=d.toISOString().slice(0,10);result.push({from:start,to:end<to?end:to});d.setUTCDate(d.getUTCDate()+1);start=d.toISOString().slice(0,10)}
          return result;
        }
        async function load(force=false){
          const r=range(),key=r.from+'|'+r.to;
          if(state.key===key&&(state.status==='loading'||(!force&&['ready','error'].includes(state.status))))return;
          const token=++state.token,isCurrent=()=>{const active=range();return state.token===token&&state.key===key&&key===active.from+'|'+active.to};
          state.key=key;state.status='loading';state.error=null;state.rows=[];state.documentary=[];state.legacy=[];render();
          try{
            if(r.from>r.to)throw Error('Período inválido');
            const evidence=await S.rpc('lts_browser_invoice_documentary_only_v1');
            if(!isCurrent())return;
            if(evidence?.error||evidence?.data?.financial_effect!=='none'||!Array.isArray(evidence?.data?.invoices))throw Error('Evidência documental indisponível');
            const periods=chunks(r.from,r.to),rows=[],legacy=[],seen=new Set(),seenLegacy=new Set();state.periods=periods.length;
            for(const period of periods){
              const [response,old]=await Promise.all([
                S.rpc('lts_browser_invoice_flow_reconciliation_v183',{p_from:period.from,p_to:period.to}),
                S.rpc('lts_browser_legacy_invoice_gap_v183',{p_from:period.from,p_to:period.to})
              ]);
              if(!isCurrent())return;
              if(response?.error||!response?.data||!Array.isArray(response.data.rows))throw Error(response?.error?.message||'Conciliação indisponível');
              for(const item of response.data.rows){
                const key=[item.card_name,item.reference_month,item.due_date,item.documented_amount].join('|');
                if(seen.has(key))throw Error('Fatura repetida em intervalos de leitura');
                seen.add(key);rows.push(item);
              }
              if(old?.error||old?.data?.financial_effect!=='none'||!Array.isArray(old?.data?.invoices))throw Error(old?.error?.message||'Faturas históricas indisponíveis');
              for(const item of old.data.invoices){
                const invoiceKey=[item.card_name,item.due_date].join('|');
                if(seenLegacy.has(invoiceKey)||!Array.isArray(item.purchases)||item.purchases.length!==Number(item.detail_lines)||Math.abs(Number(item.detail_difference))>0.02)
                  throw Error('Composição histórica inconsistente');
                seenLegacy.add(invoiceKey);legacy.push(item);
              }
            }
            if(!isCurrent())return;
            state.documentary=evidence.data.invoices.filter(x=>x.due_date>=r.from&&x.due_date<=r.to);
            state.rows=rows.sort((a,b)=>String(a.due_date).localeCompare(String(b.due_date))||String(a.card_name).localeCompare(String(b.card_name)));
            state.legacy=legacy.sort((a,b)=>String(a.due_date).localeCompare(String(b.due_date)));
            state.status='ready';
          }catch(e){if(isCurrent()){state.status='error';state.error=String(e?.message||e);state.rows=[];state.documentary=[];state.legacy=[]}}
          if(isCurrent()&&V==='Despesas'&&v168?.expense?.tab==='cards')render();
        }
        function panel(){
          const r=range(),period=date(r.from)+' a '+date(r.to),matches=state.key===r.from+'|'+r.to,status=matches?state.status:'loading',rows=matches?state.rows:[];
          let body='';
          if(status==='loading'||status==='idle')body='<p role="status">Conferindo faturas documentadas neste período…</p>';
          else if(status==='error')body='<p role="alert">Não foi possível conferir os cartões deste período. Confira a conexão e tente novamente; os totais desta conferência continuam indisponíveis.</p><button class="v168-btn" data-v183-card-retry>Tentar novamente</button>';
          else if(status==='ready'){
            const good=rows.filter(x=>x.reconciliation_status==='reconciled'&&Math.abs(Number(x.difference)||0)<=0.02).length;
            body='<p><b>'+rows.length+' fatura(s) ou previsão(ões) neste recorte; '+good+' com valor alinhado ao Fluxo.</b> Essa conferência compara cartão, competência, vencimento, sinal e valor. Previsões continuam identificadas abaixo; não são faturas emitidas. Não comprova que o banco já debitou a fatura; a confirmação de pagamento permanece separada no detalhe. Para vencimentos anteriores a hoje, ausência de evento nesta consulta não comprova ausência de pagamento no caixa histórico. Cartões ou ciclos sem fatura individual permanecem sem conferência.</p>'+
              (rows.length?'<div class="v181-tablewrap"><table class="v181-table"><thead><tr><th>Cartão</th><th>Vencimento</th><th>Referência</th><th>Fluxo</th><th>Diferença</th><th>Situação</th><th>Origem</th></tr></thead><tbody>'+rows.map(row=>{
                const ok=row.reconciliation_status==='reconciled'&&Math.abs(Number(row.difference)||0)<=0.02;
                const historical=String(row.due_date||'')<today()&&row.reconciliation_status==='invoice_event_count_mismatch'&&Number(row.flow_amount)===0;
                return'<tr><td>'+esc(row.card_name||'Cartão não identificado')+'<small>'+(row.invoice_status==='projected'?'Previsão · compras e parcelas conhecidas':'Fatura recebida')+'</small></td><td>'+esc(date(row.due_date))+'</td><td>'+money(row.documented_amount)+'</td><td>'+(historical?'—':money(row.flow_amount))+'</td><td>'+(historical?'—':money(row.difference))+'</td><td>'+(ok?(row.invoice_status==='projected'?'Previsão ↔ Fluxo':'Fatura ↔ Fluxo'):historical?'Conferência histórica pendente':'Conferir vínculo')+'</td><td><button class="v168-btn" data-v181-flow-date="'+esc(row.due_date||'')+'">Abrir no Fluxo</button></td></tr>';
              }).join('')+'</tbody></table></div>':'<p>Não há fatura individual cadastrada neste recorte. Os agregados históricos ainda precisam de composição e conferência por cartão.</p>');
          }
          const inventory=Array.isArray(v175?.cards?.data?.inventory?.cards)?v175.cards.data.inventory.cards:[];
          const cards=[...new Map(inventory.map(x=>[[x.bank,x.card_name,x.last4].join('|'),x])).values()];
          const cardList='<section class="v183-card-families" aria-label="Cartões identificados no histórico"><h3>Cartões identificados no histórico ('+cards.length+')</h3>'+
            (cards.length?'<ul style="display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:8px;list-style:none;padding:0">'+cards.map(x=>'<li style="padding:10px;border:1px solid #d8e1e9;border-radius:9px"><b>'+esc((x.bank||'Banco não identificado')+' · '+(x.card_name||'Cartão não identificado'))+'</b>'+(x.last4?'<small style="display:block">Final '+esc(x.last4)+'</small>':'')+'<small style="display:block">Evidência: '+esc(date(x.first_seen))+' a '+esc(date(x.last_seen))+'</small></li>').join('')+'</ul>':'<p>Inventário histórico indisponível. Os cartões ainda não podem ser conferidos integralmente.</p>')+
            '<p>Presença no histórico não comprova fatura individual para todos os meses. Produtos sem identificação documental continuam pendentes.</p></section>';
          const evidence=status==='ready'&&state.documentary.length?'<section aria-label="Faturas documentais ainda não integradas ao Fluxo"><h3>Faturas com documento, ainda sem conciliação operacional</h3><p>Estas evidências não criam nova saída, despesa ou dívida. Um débito de mesmo banco, data e valor é apenas candidato; pagamento deste cartão não foi confirmado.</p>'+state.documentary.map(x=>{
            const purchases=Array.isArray(x.purchases)?x.purchases:[];
            const cents=purchases.reduce((sum,p)=>sum+Math.round(Number(p.amount)*100),0);
            const total=Math.round(Number(x.invoice_amount)*100);
            const detail=purchases.length&&Number.isFinite(cents)&&cents===total
              ?'<details><summary>Ver '+purchases.length+' lançamento(s) · total '+money(x.invoice_amount)+'</summary><ul>'+purchases.map(p=>'<li>'+esc(date(p.date))+' · '+esc(p.description)+' · '+money(p.amount)+'</li>').join('')+'</ul></details>'
              :'<p>Composição documental ainda não conciliada com o total.</p>';
            return'<div style="border-top:1px solid #d8e1e9;padding:12px 0"><b>'+esc(x.bank)+' · '+esc(x.card_label)+' · final '+esc(x.card_last4)+'</b><p>Vencimento '+esc(date(x.due_date))+' · fatura '+money(x.invoice_amount)+' · pagamento bancário não confirmado'+(x.bank_debit_candidate?' · débito candidato identificado':'')+'</p>'+detail+'</div>';
          }).join('')+'</section>':'';
          const legacy=status==='ready'&&state.legacy.length?'<section aria-label="Faturas históricas importadas"><h3>Faturas históricas importadas ('+state.legacy.length+')</h3><p>Os itens destas faturas fecham com o total importado. Elas ainda não integram o cadastro atual; sua exibição não adiciona saída ao Fluxo nem confirma pagamento no banco.</p>'+state.legacy.map(x=>
            '<details style="border-top:1px solid #d8e1e9;padding:12px 0"><summary><b>'+esc(x.card_name)+'</b> · '+esc(date(x.due_date))+' · '+money(x.documented_amount)+' · '+x.purchases.length+' itens</summary><p>Composição conferida na importação. Pagamento bancário deste cartão ainda não confirmado.</p><ul>'+x.purchases.map(p=>'<li>'+esc(date(p.date))+' · '+esc(p.description||'Lançamento')+(p.card_final?' · final '+esc(p.card_final):'')+' · '+money(p.amount)+'</li>').join('')+'</ul></details>'
          ).join('')+'</section>':'';
          return'<article class="v168-card v183-card-period"><div class="v168-cardhead"><div><span>Referências do cartão · '+esc(period)+'</span><h2>Cartões e faturas do período</h2></div></div>'+cardList+body+legacy+evidence+'</article>';
        }
        despesas=function(){
          const t=document.createElement('template');t.innerHTML=oldExpenses();const root=t.content.querySelector('.v168-expenses');
          if(root&&v168?.expense?.tab==='cards'){
            const host=root.querySelector('.v175-cards'),old=root.querySelector('.v181-reconciliation');
            if(host){old?.remove();host.querySelector('.v175-inventory')?.remove();host.insertAdjacentHTML('afterbegin',panel());
              const planning=[...host.children].find(x=>x.matches?.('article.v168-card')&&!x.classList.contains('v183-card-period'));
              if(planning){const details=document.createElement('details');details.className='v183-planning';details.innerHTML='<summary>Parcelas e projeções futuras</summary>';planning.before(details);details.appendChild(planning)}
            }
          }
          return t.innerHTML;
        };
        render=function(){const result=oldRender();
          if(V==='Despesas'&&v168?.expense?.tab==='cards'){
            const r=range(),key=r.from+'|'+r.to;
            if(state.status==='idle'||state.key!==key)queueMicrotask(()=>load());
            document.querySelector('[data-v183-card-retry]')?.addEventListener('click',()=>load(true));
            document.querySelectorAll('.v183-card-period [data-v181-flow-date]').forEach(button=>button.onclick=async()=>{
              const due=button.dataset.v181FlowDate;
              if(!/^\d{4}-\d\d-\d\d$/.test(due))return;
              V='Fluxo Diário';FLOWYEAR=Number(due.slice(0,4));renderNav();render();
              // The existing route schedules its default interval in a microtask.
              // Let that run, then the exact date becomes the newest Flow request.
              await new Promise(resolve=>setTimeout(resolve,0));
              if(!window.__LTS_V162_FLOW_RECOVERY_STATUS?.default_range_applied){
                document.getElementById('flowDefaultRange')?.click();
                await new Promise(resolve=>setTimeout(resolve,0));
              }
              await loadFlowRange(due,due);
              const day=document.getElementById('d-'+due);
              day?.scrollIntoView({behavior:'smooth',block:'center'});
              const expand=day?.querySelector('button');if(expand?.textContent?.trim()==='+')expand.click();
            });
          }
          return result;
        };
        // Authentication may still be fetching the product state. The base renderer
        // dereferences D.flow, so wait for the core load before first rendering.
        if(D && !N.classList.contains('hidden'))render();
      };
      const script=d.createElement('script');script.id='v183-card-period-runtime';script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);
      return !!w.__LTS_V183_CARD_PERIOD?.installed;
    }catch{return false}
  }
  let attempts=0;const timer=setInterval(()=>{if(install()||++attempts>120)clearInterval(timer)},150);
  shell?.addEventListener('load',()=>{attempts=0;if(!install())setTimeout(install,300)});
 window.LTSV339Boot?.watch('lts-v183-card-period-candidate.js',install);
})();

;
;
/* LTS V384: lts-v183-historical-balance-guard.js */
/* V183 candidate: suppress derived totals when the bank basis is unavailable. */
(function(){
  'use strict';
  const shell=document.getElementById('shell');
  function install(){
    try{
      const w=shell?.contentWindow,d=shell?.contentDocument;
      if(!w?.__LTS_V182_FEEDBACK?.installed)return false;
      if(d.getElementById('v183-historical-balance-guard-runtime'))return true;
      const runtime=function(){
        const policy=window.parent.LTSHistoryCoverage;
        if(!policy)return;
        const explanation='Saldo histórico não confirmado neste período. As entradas e saídas continuam disponíveis.';
        const bankExplanation='Saldo histórico desta conta não confirmado. As entradas e saídas continuam disponíveis.';
        let pending=false;
        const dayFormatter=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'});
        const today=()=>dayFormatter.format(new Date());
        function guard(){
          pending=false;
          const rows=document.querySelectorAll('.fx87-row[id^="d-"]');
          // Wait for the authenticated product state; rendering and historical data
          // may arrive independently. Never derive a position from missing data.
          if(typeof D==='undefined'||!D)return;
          // One fresh local date per render; never retain it across midnight.
          const currentDay=today();
          const days=typeof mergedFlowDays==='function'?mergedFlowDays():[],dayMap=new Map(days.map(x=>[x.date,x]));
          const relative=new Set(days.filter(x=>x?.historical&&x.relative_balance_display===true).map(x=>x.date));
          // The v12 historical upgrade can replace v11 days without carrying its
          // per-day truth flags. Keep the documentary opening from the v11 contract.
          const contract=typeof FLOWQ!=='undefined'?FLOWQ?.historical_balance_truth_contract:null;
          const opening=String(contract?.consolidated_first_complete_opening||'');
          const account=typeof ACC==='undefined'?'Consolidado':ACC;
          const bankOpening=String(({Itaú:contract?.itau_first_documentary_opening,Bradesco:contract?.bradesco_first_documentary_opening,C6:contract?.c6_first_documentary_opening})[account]||'');
          const controls=document.querySelector('.flow-sticky-controls');
          controls?.querySelector('.v183-history-coverage')?.remove();
          let masked=0;
          for(const row of rows){
            const cells=row.children;
            const day=row.id.slice(2);
            const status=policy.dayStatus(day,account,contract);
            const record=dayMap.get(day),position=record?.[account];
            const documentary=record?.historical===true&&(position?.workbook_cash_reconciled===true||position?.documentary_reconstruction===true)
              &&(account==='Consolidado'||!!position.workbook_evidence_ref||!!position.documentary_anchor_ref)
              &&(account==='Consolidado'?position.bank_balance:position.balance)!=null
              &&Number.isFinite(Number(account==='Consolidado'?position.bank_balance:position.balance))
              &&(account==='Consolidado'?record.v170_cash_arithmetic?.balanced===true:Math.abs(Number(position.source_arithmetic_gap))<.005);
            if(documentary){
              row.dataset.historyCoverage='documented_workbook';
              const bounds=(account==='Consolidado'?record.Itaú:position)?.bounded_workbook_evidence;
              const shortDate=x=>/^\d{4}-\d{2}-\d{2}$/.test(x||'')?x.split('-').reverse().join('/'):'';
              row.title=bounds?'Saldo recuperado entre as posições datadas de '+shortDate(bounds.before_date)+' e '+shortDate(bounds.after_date)+'. Os movimentos fecham entre as duas posições das planilhas. Não é certificação integral por extrato.':'Posição histórica reconstruída a partir das fontes identificadas. Não é certificação integral por extrato.';
              if(bounds)for(const index of [1,4])if(cells[index])cells[index].title=row.title;
              continue;
            }
            row.dataset.historyCoverage=status;
            const uncertified=status==='uncertified'||status==='unavailable';
            if(row.classList.contains('fx87-bank')){
              if(cells.length<5||(!uncertified&&(day>=currentDay||(bankOpening&&day>=bankOpening))))continue;
              for(const index of [1,4]){
                const cell=cells[index];
                if(cell.textContent.trim()==='—')continue;
                cell.textContent='—';cell.title=uncertified?policy.uncertifiedMessage:bankExplanation;cell.classList.remove('neg','pos');
              }
              row.classList.add('v183-relative-history');masked++;continue;
            }
            if(!row.classList.contains('fx87-cons')||cells.length<11)continue;
            const beforeDocumentaryOpening=day<currentDay&&(!opening||day<opening);
            const missingBankBasis=cells[1].textContent.trim()==='—'||cells[4].textContent.trim()==='—';
            if(!uncertified&&!relative.has(day)&&!missingBankBasis&&!beforeDocumentaryOpening)continue;
            for(const index of [1,4,6,8,10]){
              const cell=cells[index];
              if(cell.textContent.trim()==='—')continue;
              cell.textContent='—';cell.title=uncertified?policy.uncertifiedMessage:explanation;cell.classList.remove('neg','pos');
            }
            row.classList.add('v183-relative-history');masked++;
          }
          if(masked){
            let note=controls?.querySelector('.v183-balance-basis-note');
            if(controls&&!note){note=document.createElement('p');note.className='v183-balance-basis-note';note.setAttribute('role','status');note.style.cssText='margin:8px 12px;padding:9px 12px;border-radius:9px;background:#fff5df;color:#60451e;font-size:12px;line-height:1.45';controls.appendChild(note)}
            const reason=account==='Consolidado'?explanation:bankExplanation;
            if(note&&note.textContent!==reason)note.textContent=reason;
            const old=document.querySelector('.v168-history-note');
            if(old&&!old.hidden)old.hidden=true;
          }else{
            document.querySelector('.v183-balance-basis-note')?.remove();
            const old=document.querySelector('.v168-history-note');
            if(old&&old.hidden)old.hidden=false;
          }
        }
        const observer=new MutationObserver(()=>{if(!pending){pending=true;requestAnimationFrame(guard)}});
        observer.observe(document.body,{childList:true,subtree:true,characterData:true});
        const originalRender=render;
        render=function(){const result=originalRender();guard();return result};
        window.__LTS_V183_HISTORICAL_BALANCE_GUARD={installed:true,policy:'independent-expense-and-reconciled-balance-coverage',operational_from:policy.operationalFrom,finance_rows_changed:false};
        guard();
      };
      const script=d.createElement('script');script.id='v183-historical-balance-guard-runtime';script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);
      return true;
    }catch{return false}
  }
  let attempts=0;const timer=setInterval(()=>{if(install()||++attempts>120)clearInterval(timer)},150);
  shell?.addEventListener('load',()=>{attempts=0;if(!install())setTimeout(install,300)});
 window.LTSV339Boot?.watch('lts-v183-historical-balance-guard.js',install);
})();

;
;
/* LTS V384: lts-v183-rsu-component-labels.js */
/* V183 candidate: make vested shares distinct from available brokerage cash. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function install(){
  try{
   const w=shell?.contentWindow,d=shell?.contentDocument;
   if(!w?.__LTS_V178_REVIEW?.installed)return false;
   if(d.getElementById('v183-rsu-component-runtime'))return true;
   const runtime=function(){
    const fmt=n=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(n);
    let pending=false;
    function decorate(){
     pending=false;
     const head=document.querySelector('.fx87-cons.fx87-head');
     if(!head||head.children.length<9)return;
     if(head.children[7].getAttribute('aria-label')!=='RSU Vested · disponível na corretora')head.children[7].setAttribute('aria-label','RSU Vested · disponível na corretora');
     if(head.children[8].getAttribute('aria-label')!=='Saldo com RSU vested + corretora')head.children[8].setAttribute('aria-label','Saldo com RSU vested + corretora');
     const a=window.__LTS_V178_STATE?.awards?.data;
     const date=a?.as_of,shares=Number(a?.vested_shares),cash=Number(a?.brokerage_cash),other=Number(a?.other_available),available=Number(a?.brokerage_available);
     if(!/^\d{4}-\d\d-\d\d$/.test(date||'')||![shares,cash,other,available].every(Number.isFinite)||Math.abs(shares+cash+other-available)>.02)return;
     const row=document.getElementById('d-'+date);if(!row||row.children.length<11)return;
     const label='Corretora disponível: '+fmt(available)+' = ações vested '+fmt(shares)+' + saldo em corretora '+fmt(cash)+(Math.abs(other)>.005?' + não alocado '+fmt(other):'')+'. Não é entrada bancária.';
     row.children[7].querySelector('.v183-rsu-components')?.remove();
     if(row.children[7].title!==label)row.children[7].title=label;
     row.children[8].title='Inclui caixa bancário, D0 e total disponível na corretora; componentes da corretora identificados na coluna RSU vested.';
     const details=row.nextElementSibling;
     if(details?.classList.contains('fx89-details')){
      let note=details.querySelector('.v183-rsu-components');
      if(!note){note=document.createElement('section');note.className='v183-rsu-components';note.style.cssText='margin:12px;padding:10px 12px;border-radius:8px;background:#edf4ff;color:#263b57;line-height:1.4';details.appendChild(note)}
      if(note.textContent!==label)note.textContent=label;
     }
    }
    new MutationObserver(()=>{if(!pending){pending=true;requestAnimationFrame(decorate)}}).observe(document.body,{childList:true,subtree:true,characterData:true});
    window.__LTS_V183_RSU_LABELS={installed:true,source:'awards-v180',finance_rows_changed:false};
    decorate();
   };
   if(!d.getElementById('v183-rsu-component-style')){const css=d.createElement('style');css.id='v183-rsu-component-style';css.textContent='.fx87-cons.fx87-head > :nth-child(8),.fx87-cons.fx87-head > :nth-child(9){font-size:0!important}.fx87-cons.fx87-head > :nth-child(8)::after{content:"RSU Vested · disponível na corretora";font-size:12px}.fx87-cons.fx87-head > :nth-child(9)::after{content:"Saldo com RSU vested + corretora";font-size:12px}';d.head.appendChild(css)}
   const s=d.createElement('script');s.id='v183-rsu-component-runtime';s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);return true;
  }catch{return false}
 }
 let tries=0;const timer=setInterval(()=>{if(install()||++tries>120)clearInterval(timer)},150);
 shell?.addEventListener('load',()=>{tries=0;if(!install())setTimeout(install,300)});
 window.LTSV339Boot?.watch('lts-v183-rsu-component-labels.js',install);
})();

;
;
/* LTS V384: lts-v183-retention-composition.js */
/* V183: expose the existing private Retention Award schedule without inventing dates or cash. */
(function(){
  'use strict';
  const shell=document.getElementById('shell');
  function install(){
    try{
      const w=shell?.contentWindow,d=shell?.contentDocument;
      if(!w?.__LTS_V183_CARD_PERIOD?.installed||!w?.__LTS_V168_STATE)return false;
      if(w.__LTS_V183_RETENTION?.installed)return true;
      const runtime=function(){
        const state=window.__LTS_V168_STATE,oldRender=render;
        const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
        const money=c=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(c/100);
        const audit=window.__LTS_V183_RETENTION={installed:true,status:'waiting'};
        function decorate(){
          if(V!=='Patrimônio')return;
          const award=state.wealth?.data?.employment_awards?.retention;
          const rows=Array.isArray(award?.installments)?award.installments:[];
          const gross=Number(award?.gross_total_brl);
          const shares=rows.map(x=>Number(x.share));
          if(!Number.isFinite(gross)||gross<=0||!rows.length||shares.some(x=>!Number.isFinite(x)||x<=0)||Math.abs(shares.reduce((a,b)=>a+b,0)-1)>0.000001){audit.status='source_incomplete';return}
          const cards=[...document.querySelectorAll('article')];
          const card=cards.find(x=>x.textContent?.includes('Retention Award')&&x.querySelector('h2')?.textContent?.includes('Acordo separado'));
          if(!card){audit.status='panel_unavailable';return}
          const grossCents=Math.round(gross*100);
          let assigned=0;
          const items=rows.map((x,i)=>{const cents=i===rows.length-1?grossCents-assigned:Math.round(grossCents*shares[i]);assigned+=cents;return {label:x.label||`Parcela ${i+1}`,detail:x.detail||'',cents}});
          if(items.some(x=>x.cents<0)||assigned!==grossCents){audit.status='sum_mismatch';return}
          const events=Array.isArray(state.wealth?.data?.employment_awards?.retention_projected_events)?state.wealth.data.employment_awards.retention_projected_events:[];
          const future=events.filter(x=>/^\d{4}-\d\d-\d\d$/.test(String(x.date||''))&&Number.isFinite(Number(x.amount))&&Number(x.amount)>0&&x.direction==='entrada');
          const details=document.createElement('details');details.className='v183-retention-composition';
          details.style.cssText='margin:12px 0;padding:12px;border:1px solid #d8e1e9;border-radius:10px';
          details.innerHTML='<summary style="cursor:pointer;font-weight:700">Abrir composição contratual · '+rows.length+' parcelas</summary><div style="display:grid;gap:8px;margin-top:10px">'+items.map(x=>'<div style="display:flex;justify-content:space-between;gap:12px"><span><b>'+esc(x.label)+'</b><small style="display:block">'+esc(x.detail)+'</small></span><strong>'+money(x.cents)+'</strong></div>').join('')+'</div><p>Parcelas brutas do acordo, separadas das RSUs. Os marcos contratuais são relativos ao Closing; a data exata e o status de vesting exigem conferência documental.</p>'+(future.length?'<h3>Projeções já registradas no Fluxo</h3><ul>'+future.map(x=>'<li>'+esc(x.date.split('-').reverse().join('/'))+' · '+money(Math.round(Number(x.amount)*100))+'</li>').join('')+'</ul><p>Estes valores são projeções de entrada, em uma camada diferente do total bruto. A diferença entre as camadas não é atribuída automaticamente a imposto.</p>':'<p>Não há projeções de entrada vinculáveis nesta leitura.</p>');
          card.querySelector('.v183-retention-composition')?.remove();card.appendChild(details);
          audit.status='ready';audit.amount_cents=grossCents;audit.component_cents=assigned;audit.count=rows.length;audit.projected_events=future.length;
        }
        render=function(){const result=oldRender();queueMicrotask(decorate);return result};
        decorate();
      };
      const script=d.createElement('script');script.id='v183-retention-runtime';script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);
      return !!w.__LTS_V183_RETENTION?.installed;
    }catch{return false}
  }
  let tries=0;const timer=setInterval(()=>{if(install()||++tries>120)clearInterval(timer)},150);
  shell?.addEventListener('load',()=>{tries=0;if(!install())setTimeout(install,300)});
 window.LTSV339Boot?.watch('lts-v183-retention-composition.js',install);
})();

;
;
/* LTS V384: lts-v183-wealth-debt-integrity.js */
/* Patrimônio: distinguish payoff evidence, initial financing and future installments. */
(function(){
  'use strict';
  function componentRemainder(total,values){
    const cents=value=>value===null||value===undefined||value===''||!Number.isFinite(Number(value))?null:Math.round(Number(value)*100);
    const target=cents(total),parts=values.map(cents);
    if(target===null||parts.some(x=>x===null))return null;
    return (target-parts.reduce((a,b)=>a+b,0))/100;
  }
  const shell=document.getElementById('shell');
  function install(){
    try{
      const w=shell?.contentWindow,d=shell?.contentDocument;
      if(!w?.__LTS_V183_RETENTION?.installed||!w?.__LTS_V168_STATE)return false;
      if(w.__LTS_V183_WEALTH_INTEGRITY?.installed)return true;
      const runtime=function(){
        const componentRemainder=window.parent.__LTS_V183_COMPONENT_REMAINDER;
        const state=window.__LTS_V168_STATE,previous=patrimonio;
        const amount=v=>v===null||v===undefined||v===''||!Number.isFinite(Number(v))?null:Number(v);
        const money=v=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(v);
        const date=v=>/^\d{4}-\d\d-\d\d$/.test(String(v||'').slice(0,10))?String(v).slice(0,10).split('-').reverse().join('/'):'data não informada';
        const audit=window.__LTS_V183_WEALTH_INTEGRITY={installed:true,status:'waiting'};
        function row(name,value,note){
          const div=document.createElement('div'),label=document.createElement('span'),bold=document.createElement('b');
          label.textContent=name;
          if(note){const small=document.createElement('small');small.textContent=note;label.appendChild(small)}
          bold.textContent=value===null?'Aguardando extrato':money(value);
          div.style.display='grid';div.style.gridTemplateColumns='minmax(0,1fr) auto';div.style.gap='12px';label.style.minWidth='0';bold.style.whiteSpace='nowrap';
          div.append(label,bold);return div;
        }
        function note(text){const p=document.createElement('p');p.className='v168-note';p.textContent=text;return p}
        function decorate(html){
          const j=state.wealth?.data;
          if(!j?.wealth||!html)return html;
          const t=document.createElement('template');t.innerHTML=html;
          const root=t.content.querySelector('.v168-wealth');if(!root)return html;
          if(state.wealth.tab==='rsu'){
            const reference=j.brokerage_reference;
            if(reference?.status==='documentary_reference_pending_reconciliation'){
              const card=document.createElement('article');card.className='v168-card v352-brokerage-reference';
              const title=document.createElement('h2');title.textContent='Referência Morgan recebida em '+date(reference.received_on);card.appendChild(title);
              card.appendChild(note(reference.position_as_of?'Data da posição: '+date(reference.position_as_of)+'.':'A foto não mostra a data da posição. Confira o extrato.'));
              const values=document.createElement('div');values.className='v172-value-list';
              for(const [name,key] of [['Total bruto na foto','total_gross_brl'],['Disponível na foto','available_total_brl'],['Indisponível na foto','unavailable_total_brl']])values.appendChild(row(name,amount(reference[key])));
              card.appendChild(values);
              const details=document.createElement('details'),summary=document.createElement('summary');summary.textContent='Composição identificada e origem';details.appendChild(summary);
              const meta=reference.metadata||{},q=meta.quantities||{},components=meta.available_components||{},quote=meta.quote||{};
              const quantity=(label,total,available)=>{const p=document.createElement('p');p.textContent=label+': '+(amount(total)===null?'quantidade não informada':new Intl.NumberFormat('pt-BR').format(total))+' · disponíveis '+(amount(available)===null?'não informado':new Intl.NumberFormat('pt-BR').format(available));details.appendChild(p)};
              quantity('RSUs',q.regular_rsu_total,q.regular_rsu_available);quantity('Cash RSUs',q.cash_rsu_total,q.cash_rsu_available);
              details.appendChild(row('Organon Long Share Holdings · disponível',amount(components.long_share_holdings_brl)));
              details.appendChild(row('Diferença do disponível ainda sem composição',componentRemainder(reference.available_total_brl,[components.long_share_holdings_brl])));
              details.appendChild(note('A aba QUANTIDADE não discrimina o valor monetário das RSUs e Cash RSUs. Esses valores continuam sem composição; as quantidades não foram usadas para distribuí-los.'));
              details.appendChild(note('Cotação exibida na foto: '+(amount(quote.share_price_usd)===null?'não informada':'US$ '+new Intl.NumberFormat('pt-BR',{minimumFractionDigits:2,maximumFractionDigits:6}).format(quote.share_price_usd))+' · câmbio '+(amount(quote.usd_brl)===null?'não informado':new Intl.NumberFormat('pt-BR',{minimumFractionDigits:6,maximumFractionDigits:6}).format(quote.usd_brl))+'. Referência exibida com atraso de 15 minutos; data própria não visível.'));
              const source=document.createElement('p');source.textContent='Origem: '+String(reference.source_file||'imagem fornecida')+' · SHA256 '+String(reference.source_sha256||'não informado');source.style.overflowWrap='anywhere';details.appendChild(source);
              details.appendChild(note('A posição datada abaixo e a projeção da agenda são bases distintas. A nova referência aguarda conciliação e não integra o saldo atual de liquidez.'));
              card.appendChild(details);
              card.appendChild(note('Composição monetária de RSUs e Cash RSUs pendente. Confira a aba VALOR ou o extrato da corretora.'));
              const tabs=root.querySelector('.v168-tabs');if(tabs)tabs.after(card);else root.prepend(card);
            }
            const awards=root.querySelector('.v168-awards');
            if(awards){
              awards.before(note('A liquidação em D+3 e a reserva de 30% são premissas de planejamento. A corretora e os documentos fiscais confirmam datas e retenções efetivas.'));
              for(const small of awards.querySelectorAll('small'))if(/ disponível$/.test(small.textContent))small.textContent=small.textContent.replace(/ disponível$/,' · disponibilidade estimada');
            }
            const m=j.morgan_statement||{},a=m.available_components||{},f=m.future_components||{},r=j.rsu_summary||{};
            const available=componentRemainder(j.current_liquidity?.brokerage_available??m.available_total_brl??r.available_total_brl,[j.current_awards?.vested_shares??a.vested_shares_brl??r.vested_shares_brl,j.current_awards?.brokerage_cash??a.brokerage_cash_brl??r.brokerage_cash_brl]);
            const future=componentRemainder(r.future_considered_total_brl,[r.future_regular_brl,r.future_cash_net_brl]);
            const components=root.querySelector('.v172-morgan-components');
            if(components){
              const card=document.createElement('article');card.className='v168-card v183-statement-remainders';
              const title=document.createElement('h3');title.textContent='Conferência da composição';card.appendChild(title);
              const list=document.createElement('div');list.className='v172-value-list';card.appendChild(list);
              const label=value=>value===null?'Composição indisponível':value<0?'Componentes acima do total':'Parcela não detalhada';
              for(const [name,value] of [['Disponível agora',available],['Posições futuras',future]]){
                const line=row(name,value,label(value));if(value===null)line.querySelector('b').textContent='—';list.appendChild(line);
              }
              card.appendChild(note('Diferenças entre o total e os componentes de cada base. O disponível preserva a posição de '+date(j.current_awards?.as_of||m.as_of||r.as_of)+'; as projeções usam a agenda e as referências de Cotações. Não são novas entradas nem valores a somar novamente.'));
              components.after(card);
              const archive=document.createElement('details');archive.className='v168-note';
              const summary=document.createElement('summary');summary.textContent='Extrato original · '+date(m.as_of||r.as_of);archive.appendChild(summary);
              archive.append(row('RSUs futuras no extrato',amount(f.regular_rsu_gross_brl)),row('Cash RSUs no extrato após reserva',amount(f.cash_rsu_after_reserve_brl)),row('Total futuro no extrato',amount(f.future_after_reserve_brl)),note('Posição documental preservada na data acima. A projeção da agenda usa as referências atuais e pode ter valor diferente. As duas bases não são somadas.'));
              card.after(archive);
              const kpi=[...root.querySelectorAll('.v168-kpi')].find(x=>x.querySelector('span')?.textContent==='Disponível agora');
              if(kpi&&available!==null&&Math.abs(available)>=0.005)kpi.querySelector('small').textContent=available<0?'Composição divergente; veja a conferência abaixo':'ações vested + saldo em corretora + parcela não detalhada';
            }
          }
          const commitments=Array.isArray(j.financing?.summary?.commitments)?j.financing.summary.commitments:[];
          const docs=Array.isArray(j.financing?.documentary?.items)?j.financing.documentary.items:[];
          const names={cipo_396:'Financiamento imobiliário · CIPÓ 396',volvo:'Financiamento do Volvo XC40',coopharma:'Empréstimo consignado · Coopharma',pai_mae:'Empréstimo familiar · Pai e Mãe'};
          const debt=Object.entries(names).map(([id,name])=>{
            const c=commitments.find(x=>x.id===id)||{},doc=docs.find(x=>x.commitment_id===id)||{};
            const balance=amount(c.current_documentary_debt_balance??doc.debt_balance);
            const asOf=c.current_debt_as_of||doc.as_of_date;
            return {id,name,balance:balance!==null&&asOf?balance:null,asOf,remaining:amount(c.remaining_scheduled_outflow_current_terms??c.remaining_scheduled_outflow??c.remaining_economic_outflow)};
          });
          const known=debt.filter(x=>x.balance!==null),missing=debt.filter(x=>x.balance===null),knownTotal=known.reduce((sum,x)=>sum+x.balance,0);
          if(state.wealth.tab==='overview'){
            const kpis=root.querySelectorAll('.v168-kpis .v168-kpi');
            if(kpis.length>=3){
              const primary=kpis[0],label=primary.querySelector('span'),value=primary.querySelector('strong'),small=primary.querySelector('small');
              if(missing.length){label.textContent='Patrimônio líquido em apuração';value.textContent='—';small.textContent='Faltam saldos de quitação atuais de '+missing.map(x=>x.id==='pai_mae'?'Pai e Mãe':x.id==='cipo_396'?'CIPÓ 396':x.id==='volvo'?'Volvo':'Coopharma').join(', ')+'.'}
              const debtKpi=kpis[2];debtKpi.querySelector('span').textContent='Dívidas com saldo documental';debtKpi.querySelector('strong').textContent=known.length?money(knownTotal):'—';debtKpi.querySelector('small').textContent=missing.length?'Demais saldos ainda não informados':'Soma das posições nas datas informadas';
            }
            const card=root.querySelector('.v172-debts');
            if(card){
              const lists=card.querySelectorAll('.v172-value-list');
              if(lists[0])lists[0].replaceChildren(...debt.map(x=>row(x.name,x.balance,x.balance!==null?'Posição em '+date(x.asOf):'Saldo atual não comprovado')));
              if(lists[1])lists[1].replaceChildren(...debt.filter(x=>x.remaining!==null).map(x=>row(x.name,x.remaining,'Parcelas futuras nos termos atuais; não é saldo de quitação')));
              const headings=card.querySelectorAll('h3');if(headings[0])headings[0].textContent='Saldos documentais';if(headings[1])headings[1].textContent='Compromissos de parcelas futuras';
              if(missing.length)card.appendChild(note('O financiamento inicial e a soma das parcelas futuras não substituem um extrato com saldo atual. O patrimônio líquido fica em apuração até que todos os passivos sejam identificados.'));
            }
          }
          if(state.wealth.tab==='assets'){
            const property=[...root.querySelectorAll('.v168-asset')].find(x=>x.querySelector('h3')?.textContent==='CIPÓ 396');
            if(property){
              for(const fact of property.querySelectorAll('.v168-fact')){
                const label=fact.querySelector('span');
                if(label?.textContent==='Compra paga')label.textContent='Pagamentos de aquisição no Excel histórico';
                if(label?.textContent==='Saldo devedor')label.textContent='Saldo documental';
              }
              const cipo=debt.find(x=>x.id==='cipo_396');
              property.appendChild(note(cipo?.balance!==null&&cipo?.asOf?'Saldo devedor documental com posição em '+date(cipo.asOf)+'. Não é uma nova cotação de quitação. Os pagamentos do Excel incluem aquisição e parcelas; não equivalem a principal amortizado.':'Saldo atual devedor aguardando documento. Os pagamentos de aquisição no Excel histórico não equivalem a principal amortizado.'));
            }

            const vehicle=[...root.querySelectorAll('.v168-asset')].find(x=>x.querySelector('h3')?.textContent==='Volvo XC40');
            if(vehicle){
              const balance=debt.find(x=>x.id==='volvo')?.balance;
              vehicle.querySelector('strong').textContent=balance===null?'Patrimônio líquido em apuração':money((amount(j.wealth?.assets?.volvo_xc40?.market_central)||0)-balance);
              const fact=[...vehicle.querySelectorAll('.v168-fact')].find(x=>x.querySelector('span')?.textContent==='Saldo financiado');
              if(fact){fact.querySelector('span').textContent=balance===null?'Financiamento na contratação':'Saldo para quitação';fact.querySelector('b').textContent=balance===null?money(amount(j.wealth?.assets?.volvo_xc40?.documented_financed_balance)||0):money(balance)}
              vehicle.appendChild(note(balance===null?'O valor financiado na contratação não é o saldo devedor de hoje. Aguardando extrato para calcular a participação líquida no veículo.':'Participação líquida estimada pela posição de mercado e pelo saldo documental de quitação.'));
            }
            const rsu=[...root.querySelectorAll('.v168-asset')].find(x=>x.querySelector('h3')?.textContent==='RSUs e corretora');
            if(rsu){
              const available=amount(j.current_liquidity?.brokerage_available??j.morgan_statement?.available_total_brl??j.rsu_summary?.available_total_brl);
              if(available!==null){
                rsu.querySelector('strong').textContent=money(available);
                for(const fact of rsu.querySelectorAll('.v168-fact')){
                  const label=fact.querySelector('span'),value=fact.querySelector('b');
                  if(label?.textContent==='Disponível agora')value.textContent=money(available);
                  if(label?.textContent==='Vestings futuros'){
                    const future=amount(j.rsu_summary?.future_considered_total_brl);
                    label.textContent='Futuro considerado na agenda';value.textContent=future===null?'—':money(future);
                  }
                }
                rsu.appendChild(note('O valor em destaque é o disponível agora. Vestings futuros permanecem separados e não são patrimônio disponível hoje.'));
              }
            }
          }
          audit.status=missing.length?'partial_debt_evidence':'documented_debts';audit.missing=missing.map(x=>x.id);audit.documented_count=known.length;
          return t.innerHTML;
        }
        patrimonio=function(){return decorate(previous())};
        if(typeof D!=='undefined'&&D&&typeof N!=='undefined'&&!N.classList.contains('hidden')&&V==='Patrimônio')render();
      };
      const script=d.createElement('script');script.id='v183-wealth-debt-integrity-runtime';script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);
      return !!w.__LTS_V183_WEALTH_INTEGRITY?.installed;
    }catch{return false}
  }
  window.__LTS_V183_COMPONENT_REMAINDER=componentRemainder;
  let tries=0;const timer=setInterval(()=>{if(install()||++tries>120)clearInterval(timer)},150);
  shell?.addEventListener('load',()=>{tries=0;if(!install())setTimeout(install,300)});
 window.LTSV339Boot?.watch('lts-v183-wealth-debt-integrity.js',install);
})();

;
;
/* LTS V384: lts-v183-personal-image-labels.js */
/* Candidate-only category labels. Stored categories and drilldown keys stay intact. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V183_PERSONAL_IMAGE_LABELS)return;
  const displayName='Vestuário';
  const category=/^\s*(?:(?:Lucas|Larissa|Benjamin|Rafiki)\s*[-—–·]\s*)?Vestu[aá]rio\s*$/i;
  const word=/\bVestu[aá]rio\b/gi;
  function label(text){return category.test(String(text))?window.LTSCategoryDisplay.category(text):String(text)}
  function decorate(){
   const walk=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);
   for(let node=walk.nextNode();node;node=walk.nextNode()){
    const parent=node.parentElement;
    if(!parent||parent.closest('script,style,textarea,input,code,pre,[contenteditable]'))continue;
    let next=label(node.nodeValue);
    if(parent.closest('.v181-lead,.v181-review-fact small'))next=next.replace(word,displayName);
    if(next===node.nodeValue)continue;
    // An option without an explicit value derives its submitted value from its label.
    const option=parent.closest('option');
    if(option&&!option.hasAttribute('value'))option.setAttribute('value',option.value);
    node.nodeValue=next;
   }
   for(const element of document.querySelectorAll('[data-group],[data-v181-detail-group],#v178DetailTitle')){
    for(const attribute of ['aria-label','title']){
     const old=element.getAttribute(attribute);
     if(old){const next=old.replace(word,displayName);if(next!==old)element.setAttribute(attribute,next)}
    }
   }
  }
  const previous=render;
  render=function(){const result=previous();decorate();return result};
  let scheduled=false;
  new MutationObserver(()=>{
   if(scheduled)return;
   scheduled=true;
   requestAnimationFrame(()=>{scheduled=false;decorate()});
  }).observe(document.body,{childList:true,subtree:true,characterData:true});
  window.__LTS_V183_PERSONAL_IMAGE_LABELS={installed:true,displayName,label,source_categories_unchanged:true};
  decorate();
 }
 function install(){
  try{
   const w=shell?.contentWindow,d=shell?.contentDocument;
   if(!w?.__LTS_V181_REGRESSION_CLOSURE?.installed)return false;
   if(w.__LTS_V183_PERSONAL_IMAGE_LABELS)return true;
   const script=d.createElement('script');script.id='v183-personal-image-runtime';
   script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);
   return !!w.__LTS_V183_PERSONAL_IMAGE_LABELS;
  }catch{return false}
 }
 let generation=0;
 function burst(){const current=++generation;let tries=0;function step(){if(current!==generation)return;if(!install()&&++tries<160)setTimeout(step,150)}step()}
 shell?.addEventListener('load',burst);burst();
 window.LTSV339Boot?.watch('lts-v183-personal-image-labels.js',install);
})();


;
;
/* LTS V384: lts-v183-award-provenance.js */
/* Candidate-only: statement != model. Display provenance without repricing. */
(function(){
 'use strict';
 function runtime(){
  if(window.__LTS_V183_AWARD_PROVENANCE)return;
  const v168=window.__LTS_V168_STATE,previousWealth=patrimonio,previousRender=render;
  const state=window.__LTS_V183_AWARD_PROVENANCE={installed:true,status:'idle',token:0,data:null,error:null};
  const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const finite=x=>x==null||x===''?null:Number.isFinite(Number(x))?Number(x):null;
  const money=x=>finite(x)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(x));
  const number=x=>finite(x)==null?'—':Number(x).toLocaleString('pt-BR',{maximumFractionDigits:6});
  const date=x=>/^\d{4}-\d\d-\d\d/.test(String(x||''))?String(x).slice(0,10).split('-').reverse().join('/'):'não informada';
  const arr=x=>Array.isArray(x)?x:[];
  function scheduleSummary(rows){
   if(!Array.isArray(rows)||!rows.length)return null;
   let regular=0,cash=0,regularQuantity=0,cashQuantity=0;
   for(const row of rows){
    if(!/^(RSU|Cash RSU)$/i.test(String(row.asset_type||'')))return null;
    const isCash=/cash/i.test(String(row.asset_type||''));
    const value=finite(isCash?row.net_value_brl:row.gross_value_brl),quantity=finite(row.quantity);
    if(value===null||quantity===null)return null;
    if(isCash){cash+=Math.round(value*100);cashQuantity+=quantity}else{regular+=Math.round(value*100);regularQuantity+=quantity}
   }
   return {regular:regular/100,cash:cash/100,total:(regular+cash)/100,regularQuantity,cashQuantity};
  }
  function matches(row,group){
   if(!row||!group||row.group_key!==group.group_key)return false;
   const considered=/cash/i.test(String(row.asset_type))?row.net_value_brl:row.gross_value_brl;
   const valuesMatch=[[row.quantity,group.quantity],[row.gross_value_brl,group.gross_value_brl],[considered,group.considered_value_brl]]
    .every(([a,b])=>finite(a)!==null&&finite(b)!==null&&Math.abs(Number(a)-Number(b))<0.005);
   const parts=arr(group.components);
   return valuesMatch&&parts.length>0&&['unit_price_usd','fx_rate'].every(key=>{
    const values=parts.map(x=>finite(x[key]));if(values.some(x=>x===null))return false;
    const unique=[...new Set(values)];return unique.length>1?finite(row[key])===null:finite(row[key])===unique[0];
   });
  }
  function origin(component){
   if(component.provenance==='market_reference')return 'Referências de mercado · preço e câmbio com datas próprias';
   if(component.provenance==='manual')return 'Premissa manual · registrada em '+date(component.assumption_recorded_at);
   return component.provenance==='historical_assumption'?'Premissa histórica importada · data da cotação não informada':'Premissa cadastrada · origem e data da cotação não comprovadas';
  }
  function componentHtml(component,isCash){
   const manual=origin(component),delta=finite(component.calculation_delta_brl);
   if(component.provenance==='market_reference'){
    const stock=component.market_quotes?.stock,fx=component.market_quotes?.usd_brl;
    const stamp=value=>{const d=new Date(value);return Number.isFinite(d.getTime())?new Intl.DateTimeFormat('pt-BR',{timeZone:'America/Sao_Paulo',dateStyle:'short',timeStyle:'short'}).format(d):'não informado';};
    return '<li><b>'+esc(manual)+'</b><br>'+number(component.quantity)+' × US$ '+number(component.unit_price_usd)+' × câmbio '+number(component.fx_rate)+' = '+money(component.calculated_gross_brl)+'.'+(isCash?' Após reserva de 30%: '+money(component.considered_value_brl)+'.':'')+'<br>Organon: '+esc(stock?.source_name)+' · '+esc(stamp(stock?.quoted_at))+'.<br>Dólar: '+esc(fx?.source_name)+' · '+esc(stamp(fx?.quoted_at))+'.<br><small>Horários de Brasília. Valores projetados; o extrato e as quantidades registradas permanecem preservados.</small></li>';
   }
   return '<li><b>'+esc(manual)+'</b><br>'+number(component.quantity)+' × US$ '+number(component.unit_price_usd)+' × câmbio '+number(component.fx_rate)+' = '+money(component.calculated_gross_brl)+' bruto.'+
    (isCash?' Considerado após reserva de 30%: '+money(component.considered_value_brl)+'.':' Considerado a 100%.')+
    (delta!==null&&Math.abs(delta)>=0.005?' Valor registrado: '+money(component.gross_value_brl)+'; diferença de cálculo '+money(delta)+', preservada para conferência.':'')+
    '<br><small>Registro de origem atualizado em '+date(component.source_updated_at)+'. Essa data não é a data de mercado da cotação. Disponibilidade projetada pelo prazo cadastrado de '+esc(component.settlement_days??'não informado')+' dias corridos; não comprova liquidação ou recebimento bancário.</small></li>';
  }
  async function load(force=false){
   if(state.status==='loading'||(!force&&state.status!=='idle'))return;
   const token=++state.token;state.status='loading';state.error=null;
   try{
    const response=await S.rpc('lts_browser_award_provenance_v183');
    if(token!==state.token)return;
    if(response.error||response.data?.financial_effect!=='none'||!Array.isArray(response.data?.groups))throw Error('Não foi possível conferir a origem das premissas.');
    state.data=response.data;state.status='ready';
   }catch(error){if(token!==state.token)return;state.status='error';state.data=null;state.error=String(error?.message||error)}
   if(V==='Patrimônio'&&v168.wealth.tab==='rsu')render();
  }
  function invalidate(){state.token++;state.status='idle';state.data=null;state.error=null}
  function decorate(html){
   if(v168.wealth.tab!=='rsu')return html;
   const rows=arr(v168.wealth.data?.rsu?.future_schedule),summary=scheduleSummary(rows);
   const t=document.createElement('template');t.innerHTML=html;
   const root=t.content.querySelector('.v168-wealth');if(!root)return html;
   const agenda=[...root.querySelectorAll('article')].find(x=>x.querySelector('h2')?.textContent==='Vestings e disponibilidade');
   if(agenda){
    const total=agenda.querySelector('.v168-cardhead strong');if(total)total.textContent=money(summary?.total);
    const help=agenda.querySelector('.v170-reconciliation');
    if(help){
     const note=document.createElement('p');note.className='v183-award-model-note';
     note.textContent=summary?'Total da agenda: '+money(summary.total)+' = RSUs '+money(summary.regular)+' + Cash RSUs após reserva '+money(summary.cash)+'. Quantidades da agenda: '+number(summary.regularQuantity)+' RSUs e '+number(summary.cashQuantity)+' Cash RSUs. Não substitui o extrato nem comprova a quantidade da posição atual.':'Total da agenda indisponível: falta valor ou quantidade em pelo menos um vesting. Nenhuma soma parcial é apresentada.';
     help.prepend(note);
    }
    const cards=[...agenda.querySelectorAll('.v168-award')];
    cards.forEach((card,index)=>{
     const row=rows[index],group=arr(state.data?.groups).find(x=>x.group_key===row?.group_key);
     const available=card.children[3]?.querySelector('small');
     if(available)available.textContent=date(row?.available_date)+' · disponibilidade projetada';
     const detail=document.createElement('details');detail.className='v183-award-source';
     detail.innerHTML='<summary>Origem e cálculo desta premissa</summary>'+
      (state.status==='ready'&&matches(row,group)?'<ul>'+arr(group.components).map(x=>componentHtml(x,/cash/i.test(String(row.asset_type)))).join('')+'</ul>':
       '<p>'+esc(state.status==='ready'?'A agenda mudou desde a leitura. Atualize a conferência antes de usar esta composição.':state.status==='error'?'Origem indisponível. A cotação não está sendo apresentada como preço de mercado atual.':'Conferindo a origem da cotação e do câmbio…')+'</p>');
     card.appendChild(detail);
    });
   }
   const form=root.querySelector('.v170-global-award');
   if(form){const note=document.createElement('div');note.className='v168-note v183-award-provenance-note';
    note.innerHTML='<b>Premissas de planejamento, não cotação ao vivo.</b> Preço e câmbio atualizam somente a agenda; não reescrevem o extrato ou as quantidades e não lançam dinheiro no banco. A data de origem aparece em cada vesting; quando ausente, permanece explicitamente desconhecida. <button type="button" class="v168-btn" data-v183-award-refresh>Atualizar conferência</button>';
    form.appendChild(note);
   }
   return t.innerHTML;
  }
  patrimonio=function(){return decorate(previousWealth())};
  render=function(){const out=previousRender();
   if(V==='Patrimônio'&&v168.wealth.tab==='rsu'){
    if(state.status==='idle')queueMicrotask(()=>load());
    const retry=document.querySelector('[data-v183-award-refresh]');if(retry)retry.onclick=()=>load(true);
   }
   return out;
  };
  // Preserve the existing audited writers. Observe only successful, explicit
  // writes so this reader cannot retain old provenance after a quote/date edit.
  const rpc=S.rpc.bind(S),writers=new Set(['lts_browser_save_all_award_assumptions_v1','lts_browser_save_award_assumption_v1','lts_browser_save_vesting_anticipation_v1']);
  S.rpc=function(name,args,...rest){const result=rpc(name,args,...rest);if(!writers.has(name))return result;
   return Promise.resolve(result).then(response=>{if(!response.error&&response.data?.ok){invalidate();queueMicrotask(()=>window.__LTS_V178_REVIEW?.refresh?.())}return response});
  };
  S.auth.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT')invalidate()});
  const css=document.createElement('style');css.textContent='.v183-award-source{grid-column:1/-1;min-width:0;max-width:100%;font-size:12px;line-height:1.55}.v183-award-source summary{cursor:pointer;color:#425e7b}.v183-award-source ul{padding-left:20px;white-space:normal;overflow-wrap:anywhere}.v183-award-source li+li{margin-top:10px}.v183-award-model-note{margin:0 0 8px;white-space:normal}.v183-award-provenance-note{white-space:normal;line-height:1.5}';document.head.appendChild(css);
  if(D&&!N.classList.contains('hidden')&&V==='Patrimônio')render();
 }
 const shell=document.getElementById('shell');let generation=0;
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V183_WEALTH_INTEGRITY?.installed)return false;if(!w.__LTS_V183_AWARD_PROVENANCE){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);}return !!w.__LTS_V183_AWARD_PROVENANCE;}catch{return false;}}
 function burst(){const current=++generation;let attempts=0;function step(){if(current!==generation)return;if(!install()&&++attempts<160)setTimeout(step,150);}step();}
 shell?.addEventListener('load',burst);burst();
 window.LTSV339Boot?.watch('lts-v183-award-provenance.js',install);
})();

;
;
/* LTS V384: lts-v183-card-payment-status.js */
/* Show documentary payment status separately from invoice/Flow arithmetic. */
(function(){
 'use strict';
 function runtime(){
  if(window.__LTS_V183_CARD_PAYMENT)return;
  const state=window.__LTS_V183_CARD_PAYMENT={installed:true,cache:new Map(),epoch:0};
  const previousRender=render;
  function bank(name){
   const n=String(name||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
   if(/\bc6\b/.test(n))return 'C6';
   if(/aeternum|infinite prime|bradesco/.test(n))return 'Bradesco';
   if(/itau|personnalite/.test(n))return 'Itaú';
   return null;
  }
  function key(row){return JSON.stringify([row.id,row.card_name,row.due_date,row.documented_amount])}
  function classify(row,result){
   if(!result?.matched||result.due_date!==row.due_date||result.invoice_total==null||row.documented_amount==null||
      !Number.isFinite(Number(result.invoice_total))||!Number.isFinite(Number(row.documented_amount))||
      Math.abs(Number(result.invoice_total)-Number(row.documented_amount))>0.005)
    return {label:'Pagamento não conferido',note:'Não foi possível vincular uma única fatura a esta evidência.'};
   const paid=result.payment_documented===true;
   const different=/^\d{4}-\d\d-\d\d$/.test(result.cash_effect_date||'')&&result.cash_effect_date!==row.due_date;
   const date=String(result.cash_effect_date||'').split('-').reverse().join('/');
   return {label:paid?'Pagamento documentado':'Pagamento não comprovado',
    note:(paid?'Há evidência de pagamento vinculada ao ciclo.':'O documento e o evento no Fluxo não bastam para confirmar o débito bancário.')+
     (different?' Data de caixa cadastrada: '+date+'; difere do vencimento. A data efetiva ainda deve ser confrontada com o lançamento bancário.':''),
    documented:paid,dateDifference:different};
  }
  function clear(){state.epoch++;state.cache.clear()}
  function active(){return V==='Despesas'&&window.__LTS_V168_STATE?.expense?.tab==='cards'}
  async function load(row,period){
   const k=key(row),account=bank(row.card_name);if(state.cache.has(k))return;
   if(!account){state.cache.set(k,{status:'ready',result:{label:'Banco a conferir',note:'Nenhuma instituição foi presumida.'}});return}
   const epoch=state.epoch;state.cache.set(k,{status:'loading'});
   try{
    const response=await S.rpc('lts_browser_card_settlement_detail_v3',{p_event_date:row.due_date,p_description:row.card_name,p_amount:row.documented_amount,p_account:account});
    if(epoch!==state.epoch)return;
    if(response.error)throw Error('Leitura indisponível');
    state.cache.set(k,{status:'ready',result:classify(row,response.data)});
   }catch{if(epoch!==state.epoch)return;state.cache.set(k,{status:'error',result:{label:'Pagamento não conferido',note:'A leitura falhou. Use Atualizar pagamentos para tentar novamente.'}})}
   if(active()&&window.__LTS_V183_CARD_PERIOD?.key===period)render();
  }
  function decorate(){
   if(!active())return;
   const period=window.__LTS_V183_CARD_PERIOD;
   if(period?.status!=='ready')return;
   const panel=document.querySelector('.v183-card-period'),table=panel?.querySelector('table.v181-table');
   if(!table)return;
   if(!table.querySelector('[data-v183-payment-head]')){
    const head=document.createElement('th');head.setAttribute('data-v183-payment-head','');head.textContent='Pagamento no banco';table.querySelector('thead tr')?.appendChild(head);
   }
   [...table.querySelectorAll('tbody tr')].forEach((tr,index)=>{
    const row=period.rows[index];if(!row)return;
    let cell=tr.querySelector('[data-v183-payment-status]');
    if(!cell){cell=document.createElement('td');cell.setAttribute('data-v183-payment-status','');cell.style.cssText='min-width:170px;max-width:260px;white-space:normal';tr.appendChild(cell)}
    const entry=state.cache.get(key(row));cell.replaceChildren();
    if(!entry){cell.textContent='Conferindo evidência…';queueMicrotask(()=>load(row,period.key));return}
    if(entry.status==='loading'){cell.textContent='Conferindo evidência…';return}
    const strong=document.createElement('b');strong.textContent=entry.result.label;cell.appendChild(strong);
    const note=document.createElement('small');note.style.cssText='display:block;line-height:1.4;margin-top:4px';note.textContent=entry.result.note;cell.appendChild(note);
   });
   if(!panel.querySelector('[data-v183-payment-refresh]')){
    const button=document.createElement('button');button.className='v168-btn';button.textContent='Atualizar pagamentos';button.setAttribute('data-v183-payment-refresh','');button.onclick=()=>{clear();render()};table.closest('.v181-tablewrap').after(button);
   }
  }
  render=function(){const result=previousRender();decorate();return result};
  S.auth.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT')clear()});
  if(D&&!N.classList.contains('hidden'))decorate();
 }
 const shell=document.getElementById('shell');let generation=0;
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V183_CARD_PERIOD?.installed)return false;if(!w.__LTS_V183_CARD_PAYMENT){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);}return !!w.__LTS_V183_CARD_PAYMENT;}catch{return false;}}
 function burst(){const current=++generation;let attempts=0;function step(){if(current!==generation)return;if(!install()&&++attempts<160)setTimeout(step,150);}step();}
 shell?.addEventListener('load',burst);burst();
 window.LTSV339Boot?.watch('lts-v183-card-payment-status.js',install);
})();

;
