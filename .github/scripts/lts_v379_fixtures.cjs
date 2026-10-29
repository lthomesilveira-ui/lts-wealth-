'use strict';
const base=require('./lts_v309_fixtures.cjs');
const ledger=[
 ['2025-12-18',1000,200,300],['2026-01-05',2000,0,900],['2026-01-25',0,0,90],
 ['2026-06-12',4000,300,500],['2026-06-20',6000,0,700],['2026-10-05',500,0,700],['2026-10-16',10000,1000,9000]
].map(([date,revenue,extraordinary,expenses])=>({date,revenue,extraordinary,expenses}));
function monthly(from,to){
 const months=[];for(let d=new Date(from.slice(0,7)+'-01T12:00:00Z');d.toISOString().slice(0,7)<=to.slice(0,7);d.setUTCMonth(d.getUTCMonth()+1))months.push(d.toISOString().slice(0,10));
 const entries=ledger.filter(x=>x.date>=from&&x.date<=to),total=k=>entries.reduce((s,x)=>s+x[k],0),monthlyTotals=months.map(month=>{
  const rows=entries.filter(x=>x.date.slice(0,7)===month.slice(0,7)),sum=k=>rows.reduce((s,x)=>s+x[k],0),revenue=sum('revenue'),extraordinary=sum('extraordinary'),expenses=sum('expenses');return{month,revenue,extraordinary,expenses,operating_balance:revenue-expenses,cash_after_extraordinary:revenue+extraordinary-expenses};
 });
 const groups=(field,label)=>total(field)?[{label,total:total(field),source_rows:entries.filter(x=>x[field]).length,monthly:monthlyTotals.map(x=>({month:x.month,amount:x[field]}))}]:[];
 return{version:'monthly-v178-person-integrity',from,to,window_integrity:{from,to},months,monthly_totals:monthlyTotals,totals:{revenue:total('revenue'),extraordinary:total('extraordinary'),expenses:total('expenses'),operating_balance:total('revenue')-total('expenses'),cash_after_extraordinary:total('revenue')+total('extraordinary')-total('expenses')},revenue_groups:groups('revenue','Receita de teste'),extraordinary_groups:groups('extraordinary','Entrada extraordinária de teste'),expense_groups:groups('expenses','Compromissos financeiros — Empréstimos'),expense_unclassified_card_coverage:{total:0,monthly:months.map(month=>({month,amount:0}))},stock_sale_supplement:{total:0,monthly:[]},open_audit_issues:[]};
}
function cards(){return{version:'card-cycles-v226',as_of:'2026-10-16',complete:true,active_billing_accounts:2,cards:[{bank:'Bradesco',family:'aeternum',name:'Visa Aeternum',last4:'0000',status:'ACTIVE',cycles:[{month:'2026-12-01',due_date:'2026-12-03',amount:2299.31,complete:true,basis:'received_and_projected_installments',payment_status:'open',settlement_confirmed:false}]},{bank:'Itaú',family:'itau_mastercard',name:'Mastercard Black',last4:'0001',status:'ACTIVE',cycles:[{month:'2026-11-01',due_date:'2026-11-16',amount:532.73,complete:true,basis:'open_finance_composition',payment_status:'open',settlement_confirmed:false}]}]};}
module.exports={...base,ledger,monthly,cards};
