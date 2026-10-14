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
  return 'unknown';
 }
 const number=v=>v===null||v===undefined||v===''||!Number.isFinite(Number(v))?null:Number(v);
 function validDate(v){if(!/^\d{4}-\d{2}-\d{2}$/.test(v||''))return false;const d=new Date(v+'T12:00:00Z');return Number.isFinite(d.getTime())&&d.toISOString().slice(0,10)===v;}
 const cell=v=>v==null?'Não comprovado':Number(v).toFixed(2).replace('.',',');
 function consolidatedTsv(input){
  const {from,to,days,events,contract,policy}=input;
  if(input.loading)return {ok:false,message:'Aguarde o carregamento completo do período.'};
  if(input.error)return {ok:false,message:'O período não foi carregado. Tente novamente antes de copiar.'};
  if(!validDate(from)||!validDate(to)||from>to||!Array.isArray(days)||!Array.isArray(events))return {ok:false,message:'Selecione e carregue um período válido.'};
  const rows=days.filter(x=>x&&x.date>=from&&x.date<=to).slice().sort((a,b)=>a.date.localeCompare(b.date));
  const expected=Math.round((Date.parse(to+'T12:00:00Z')-Date.parse(from+'T12:00:00Z'))/86400000)+1;
  if(!rows.length||rows.length!==expected||new Set(rows.map(x=>x.date)).size!==expected||rows.some(x=>!validDate(x.date)))return {ok:false,message:'Há dias ausentes no período. Recarregue antes de copiar.'};
  const cash=new Map();
  for(const e of events){if(e.internal_transfer||e.source==='economic_withholding')continue;const date=e.event_date||e.date,n=number(e.signed_amount),tot=cash.get(date)||{entries:0,exits:0,valid:true};if(n==null)tot.valid=false;else if(n>0)tot.entries+=n;else tot.exits-=n;cash.set(date,tot);}
  const text=['Data\tSaldo anterior\tEntradas\tSaídas\tSaldo final\tD+0/1\tSaldo após D+0/1\tRSU vested\tSaldo após RSU\tFGTS\tSaldo após FGTS\tBase do saldo'];
  rows.forEach((row,i)=>{
   const c=row.fix86_columns||{},z=row.Consolidado||{},tot=cash.get(row.date)||{entries:0,exits:0,valid:true};
   let opening=number(c.saldo_anterior_operacional??c.saldo_anterior),closing=number(c.saldo_final_operacional??c.saldo_final??z.bank_balance),entries=number(c.entradas_operacionais),exits=number(c.saidas_operacionais);
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
   const values=[opening,entries,exits,closing,number(c.liq_d0_1_recurso),documented?number(c.saldo_apos_d0_1):null,number(c.rsus_vested),documented?number(c.saldo_apos_rsu):null,number(c.fgts),documented?number(c.saldo_apos_fgts):null];
   text.push(row.date+'\t'+values.map(cell).join('\t')+'\t'+basis);
  });
  return {ok:true,text:text.join('\n'),rows:rows.length,from,to};
 }
 return Object.freeze({periodState,consolidatedTsv});
});
