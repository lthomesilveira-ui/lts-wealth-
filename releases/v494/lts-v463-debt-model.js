/* Estimate a fixed-payment loan from the preserved original capital and proved payments. */
(function(root){'use strict';
 const num=x=>(typeof x==='number'||typeof x==='string'&&x.trim()!=='')&&Number.isFinite(Number(x))?Number(x):null;
 const date=x=>typeof x==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(x)&&Number.isFinite(Date.parse(x+'T12:00:00Z'))&&new Date(x+'T12:00:00Z').toISOString().slice(0,10)===x;
 const cents=x=>{const n=num(x);return n!==null&&Number.isSafeInteger(Math.round(n*100))?Math.round(n*100):null;};
 function pv(rate,n,payment){return rate===0?n*payment:payment*-Math.expm1(-n*Math.log1p(rate))/rate;}
 function estimate(asset,loan,asOf){
  if(!date(asOf)||!asset||loan?.id!=='volvo'||loan.confidence!=='documented_contract')return null;
  if(num(loan.current_documentary_debt_balance)!==null&&date(loan.current_debt_as_of))return null;
  const principal=cents(asset.documented_financed_balance),payment=cents(loan.installment),n=loan.total_events;
  const paid=Array.isArray(loan.realized_rows)?[...loan.realized_rows].sort((a,b)=>a.installment_number-b.installment_number):null;
  const future=Array.isArray(loan.schedule_rows)?[...loan.schedule_rows].sort((a,b)=>a.installment_number-b.installment_number):null;
  if(principal===null||principal<=0||payment===null||payment<=0||!Number.isSafeInteger(n)||n<1||n>600||principal>n*payment||!paid||!future||paid.length<1||paid.length+future.length!==n||loan.confirmed_paid_installments!==paid.length||loan.remaining_events!==future.length||num(loan.unconfirmed_past_events)!==0)return null;
  const refs=new Set();
  for(let i=0;i<paid.length;i++){
   const p=paid[i];if(p.status!=='paid'||p.installment_number!==i+1||!date(p.paid_date)||p.paid_date>asOf||!date(p.due_date)||!p.source_ref||refs.has(p.source_ref)||p.payment_basis!=='validated_existing_bank_identity'||cents(p.paid_amount)!==payment||cents(p.scheduled_amount)!==payment)return null;
   refs.add(p.source_ref);
  }
  for(let i=0;i<future.length;i++){const p=future[i];if(p.installment_number!==paid.length+i+1||!date(p.due_date)||p.due_date<=asOf||cents(p.amount)!==payment)return null;}
  let rate=0;
  if(principal<n*payment){let low=0,high=1;if(pv(high,n,payment)>principal)return null;for(let i=0;i<90;i++){const mid=(low+high)/2;if(pv(mid,n,payment)>principal)low=mid;else high=mid;}rate=(low+high)/2;}
  const balance=Math.round(pv(rate,future.length,payment));if(!Number.isSafeInteger(balance)||balance<0||balance>principal)return null;
  return {status:'estimated_after_confirmed_payments',balance:balance/100,asOf:paid.at(-1).paid_date,initialPrincipal:principal/100,paidCount:paid.length,totalCount:n,paidAmount:paid.length*payment/100,remainingCount:future.length,nextDue:future[0]?.due_date||null,nextAmount:future.length?payment/100:null,method:'fixed_payment_annuity',inferredMonthlyRate:rate};
 }
 const api={estimate,pv};if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.LTSV463Debt=api;
})(typeof window==='undefined'?{}:window);
