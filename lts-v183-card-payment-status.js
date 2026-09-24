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
 function burst(){const current=++generation;let attempts=0;function install(){
  if(current!==generation)return;
  try{const w=shell?.contentWindow,d=shell?.contentDocument;
   if(w?.__LTS_V183_CARD_PERIOD?.installed){if(!w.__LTS_V183_CARD_PAYMENT){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s)}return}
  }catch{}
  if(++attempts<160)setTimeout(install,150);
 }install()}
 shell?.addEventListener('load',burst);burst();
})();
