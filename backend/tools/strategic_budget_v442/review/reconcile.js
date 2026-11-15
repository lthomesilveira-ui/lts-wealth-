(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.BudgetReconciliation=api;})(globalThis,function(){
'use strict';
const cents=n=>{if(n===null||n===undefined||!Number.isFinite(Number(n)))throw Error('Missing amount');return Math.round(Number(n)*100)};
function reconcile(events,items,month,aliases={}){
 const cash=[],estimates=[],cardPayments=[],income=[],cards=[],seen=new Set(),duplicates=[];
 for(const e of events){if(String(e.event_date).slice(0,7)!==month)continue;
 const id=[e.source,e.source_ref,e.event_date].join('|');if(!e.source||!e.source_ref)throw Error('Missing event identity');
 if(seen.has(id)){duplicates.push(id);continue;}seen.add(id);
 const n=cents(e.signed_amount),r={...e,cents:n};
 if(n>=0){income.push({...r,regular:/^(Salário líquido|Salário|Adiantamento Quinzenal)$/i.test(e.description)});continue;}
 if(e.source==='card_invoice'){cardPayments.push(r);continue;}
 if(e.source==='planning_projection_v412'||/historical_spending|projection_policy/.test(e.source)){estimates.push(r);continue;}
 cash.push({...r,budgetCategory:aliases[e.category]||e.category||'Sem classificação',evidenceLevel:e.confidence,contractVerified:false});
 }
 for(const i of items){if(String(i.competence_month).slice(0,7)!==month||i.is_payment)continue;
 const id=[i.family,i.source_id,i.competence_month,i.installment_number||0].join('|');
 if(!i.source_id||!i.family)throw Error('Missing card identity');if(seen.has(id)){duplicates.push(id);continue;}seen.add(id);
 cards.push({...i,cents:cents(i.amount),budgetCategory:aliases[i.category]||i.category||'Sem classificação'});
 }
 if(duplicates.length)throw Error('Duplicate source identities');
 const categories={};for(const i of cards){const k=i.budgetCategory;const r=categories[k]||(categories[k]={received:0,projected:0,items:0});r[i.status==='PROJECTED'?'projected':'received']+=i.cents;r.items++;}
 return {month,cashSchedule:cash,cashEstimates:estimates,cardPayments,cardsByCompetence:cards,cardCategories:categories,income,
 totals:{scheduledCash:cash.reduce((n,r)=>n-r.cents,0),estimatedCash:estimates.reduce((n,r)=>n-r.cents,0),cardPayments:cardPayments.reduce((n,r)=>n-r.cents,0),cardCompetence:cards.reduce((n,r)=>n+r.cents,0),regularIncome:income.filter(r=>r.regular).reduce((n,r)=>n+r.cents,0),otherIncome:income.filter(r=>!r.regular).reduce((n,r)=>n+r.cents,0)},
 combinedBudgetTotal:null,complete:false,
 warning:'Caixa, estimativas e competência são visões distintas. Não somar pagamentos e compras; obrigação agendada não prova contrato.'};
}
return {reconcile};
});