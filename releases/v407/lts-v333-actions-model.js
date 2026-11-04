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
