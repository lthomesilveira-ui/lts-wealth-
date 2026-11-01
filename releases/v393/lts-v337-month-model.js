/* Monthly consumption and current bank positions; no invented history or deltas. */
(function(root,factory){
 'use strict';const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;else root.LTSV337Month=api;
})(typeof window==='undefined'?globalThis:window,function(){
 'use strict';
 const finite=x=>(typeof x==='number'||typeof x==='string'&&x.trim()!==''&&/^-?\d+(?:\.\d+)?$/.test(x))&&Number.isFinite(Number(x))?Number(x):null;
 function bounds(month,today){
  if(!/^\d{4}-\d{2}$/.test(month||'')||!/^\d{4}-\d{2}-\d{2}$/.test(today||''))return null;
  const start=month+'-01',d=new Date(start+'T12:00:00Z');
  if(!Number.isFinite(d.valueOf())||d.toISOString().slice(0,10)!==start||month<'2013-10'||month>today.slice(0,7))return null;
  d.setUTCMonth(d.getUTCMonth()+1);d.setUTCDate(0);const last=d.toISOString().slice(0,10);
  return{month,from:start<'2013-10-10'?'2013-10-10':start,to:last>today?today:last,partial:last>today};
 }
 function summarize(payload,range){
  if(!range||!payload||!Array.isArray(payload.monthly_totals))return null;
  const integrity=payload.window_integrity||payload;
  if(integrity.from!==range.from||integrity.to!==range.to)return null;
  const rows=payload.monthly_totals;if(rows.length!==1||String(rows[0].month).slice(0,10)!==range.month+'-01')return null;
  const row=rows[0],revenue=finite(row.revenue),extraordinary=finite(row.extraordinary),expenses=finite(row.expenses),result=finite(row.cash_after_extraordinary);
  if([revenue,extraordinary,expenses,result].some(x=>x===null)||Math.abs(revenue+extraordinary-expenses-result)>.021)return null;
  const totals=payload.totals||{};
  if(['revenue','extraordinary','expenses','cash_after_extraordinary'].some(k=>finite(totals[k])===null||Math.abs(Number(totals[k])-Number(row[k]))>.021))return null;
  return{month:range.month,from:range.from,to:range.to,partial:range.partial,revenue,extraordinary,entries:revenue+extraordinary,expenses,result};
 }
 function bankPositions(cash,today){
  if(cash?.status!=='complete'||cash.as_of!==today||finite(cash.cash)===null||!Array.isArray(cash.bank_positions)||cash.bank_positions.length!==3)return null;
  const specs=[['341','Itaú'],['237','Bradesco'],['336','C6']],rows=[];
  for(const [code,name]of specs){const found=cash.bank_positions.filter(x=>x.institution_code===code);if(found.length!==1||finite(found[0].balance)===null)return null;rows.push({code,name,balance:Number(found[0].balance)});}
  const total=rows.reduce((n,x)=>n+x.balance,0);if(Math.abs(total-Number(cash.cash))>.021)return null;
  return{rows,total,asOf:today};
 }
 function validDate(value){
  if(!/^\d{4}-\d{2}-\d{2}$/.test(value||''))return false;
  const day=new Date(value+'T12:00:00Z');return Number.isFinite(day.valueOf())&&day.toISOString().slice(0,10)===value;
 }
 function periodBounds(from,to,today){
  if(![from,to,today].every(validDate)||from<'2013-10-10'||to>today||from>to)return null;
  const months=[],day=new Date(from.slice(0,7)+'-01T12:00:00Z');
  while(day.toISOString().slice(0,7)<=to.slice(0,7)){months.push(day.toISOString().slice(0,7));day.setUTCMonth(day.getUTCMonth()+1);}
  return{from,to,months,partial:to===today};
 }
 function summarizePeriod(payload,range){
  if(!range||!payload||!Array.isArray(range.months)||!Array.isArray(payload.monthly_totals))return null;
  const integrity=payload.window_integrity||payload;
  if(integrity.from!==range.from||integrity.to!==range.to||payload.monthly_totals.length!==range.months.length)return null;
  const keys=['revenue','extraordinary','expenses','cash_after_extraordinary'],sums=Object.fromEntries(keys.map(k=>[k,0])),byMonth=new Map();
  for(const row of payload.monthly_totals){
   const month=String(row.month||'').slice(0,7);
   if(String(row.month)!==month+'-01'||!range.months.includes(month)||byMonth.has(month)||keys.some(k=>finite(row[k])===null))return null;
   const revenue=Number(row.revenue),extraordinary=Number(row.extraordinary),expenses=Number(row.expenses),result=Number(row.cash_after_extraordinary);
   if(Math.abs(revenue+extraordinary-expenses-result)>.021)return null;
   keys.forEach(k=>sums[k]+=Number(row[k]));byMonth.set(month,{month,revenue,extraordinary,entries:revenue+extraordinary,expenses,result});
  }
  const totals=payload.totals||{};
  if(keys.some(k=>finite(totals[k])===null||Math.abs(Number(totals[k])-sums[k])>.021))return null;
  const revenue=Number(totals.revenue),extraordinary=Number(totals.extraordinary),expenses=Number(totals.expenses),result=Number(totals.cash_after_extraordinary);
  if(Math.abs(revenue+extraordinary-expenses-result)>.021)return null;
  return{from:range.from,to:range.to,partial:range.partial,revenue,extraordinary,entries:revenue+extraordinary,expenses,result,months:range.months.map(m=>byMonth.get(m))};
 }

 function monthBounds(month,today){
  if(!validDate(today)||!/^\d{4}-\d{2}$/.test(month||''))return null;
  const start=month+'-01';if(!validDate(start))return null;
  const last=new Date(start+'T12:00:00Z');last.setUTCMonth(last.getUTCMonth()+1);last.setUTCDate(0);
  const range=forecastPeriodBounds(start<'2013-10-10'?'2013-10-10':start,last.toISOString().slice(0,10),today);
  return range?{...range,month}:null;
 }
 function forecastPeriodBounds(from,to,today){
  if(![from,to,today].every(validDate)||from<'2013-10-10'||from>to||to>(Number(today.slice(0,4))+5)+'-12-31')return null;
  if((Date.parse(to)-Date.parse(from))/86400000>12000)return null;
  const months=[],d=new Date(from.slice(0,7)+'-01T12:00:00Z');
  while(d.toISOString().slice(0,7)<=to.slice(0,7)){months.push(d.toISOString().slice(0,7));d.setUTCMonth(d.getUTCMonth()+1);}
  return{from,to,months,partial:from<=today&&to>=today};
 }
 function summarizeOverview(payload,range,today){
  if(!range||payload?.version!=='month-overview-v393'||payload.from!==range.from||payload.to!==range.to||payload.as_of!==today||typeof payload.complete!=='boolean')return null;
  const cash=payload.cash,book=payload.competence;
  if(!cash||!book||!Array.isArray(cash.items)||!Array.isArray(cash.excluded)||!Array.isArray(cash.undated)||!Array.isArray(book.items)||!Array.isArray(payload.months))return null;
  if(cash.undated.length&&payload.complete!==false)return null;
  const cents=x=>finite(x)===null?null:Math.round(Number(x)*100),number=x=>finite(x)===null?null:Number(x);
  const count=x=>Number.isSafeInteger(x)&&x>=0;
  const metrics=items=>{const m=items.reduce((m,r)=>{const n=number(r.signed_amount);m.entries+=Math.max(n,0);m.payments-=Math.min(n,0);m.result+=n;m.count++;return m;},{entries:0,payments:0,result:0,count:0});for(const k of['entries','payments','result'])m[k]=Math.round(m[k]*100);return m;};
  const matches=(m,n)=>m&&count(m.count)&&m.count===n.count&&['entries','payments','result'].every(k=>cents(m[k])===n[k])&&cents(m.entries)-cents(m.payments)===cents(m.result);
  const keys=new Set();
  for(const r of cash.items){
   if(!validDate(r.event_date)||r.event_date<range.from||r.event_date>range.to||cents(r.signed_amount)===null||!['Itaú','Bradesco','C6'].includes(r.account)||!r.source||!r.source_ref||!['realized','forecast','unconfirmed'].includes(r.cash_state))return null;
   if((r.cash_state==='forecast')!==(r.event_date>today))return null;
   if(r.internal_transfer===true||r.source==='internal_transfer'||r.is_asset_movement===true||r.asset_movement===true)return null;
   const key=JSON.stringify([r.source,r.source_ref,r.account,r.event_date]);if(keys.has(key))return null;keys.add(key);
  }
  for(const state of['realized','forecast','unconfirmed'])if(!matches(cash[state],metrics(cash.items.filter(r=>r.cash_state===state))))return null;
  if(!matches(cash.total,metrics(cash.items)))return null;
  if(!validDate(book.from)||!validDate(book.to)||book.from>range.from||book.to<range.to||!count(book.count)||book.count!==book.items.length||cents(book.total)===null||book.basis!=='competence_month'||book.payment_proven!==false)return null;
  const bookKeys=new Set();let sum=0,received=0,projected=0;
  for(const r of book.items){
   if(!r.row_key||bookKeys.has(r.row_key)||!validDate(r.event_date)||r.event_date<book.from||r.event_date>book.to||!validDate(r.competence_month)||r.competence_month!==r.event_date.slice(0,7)+'-01'||cents(r.amount)===null)return null;
   for(const value of[r.transaction_date,r.purchase_date])if(value!==null&&value!==undefined&&!validDate(value))return null;
   bookKeys.add(r.row_key);sum+=number(r.amount);if(r.coverage_mode==='card_installment_projected')projected+=number(r.amount);else received+=number(r.amount);
  }
  if(Math.round(sum*100)!==cents(book.total)||Math.round(received*100)!==cents(book.received_total)||Math.round(projected*100)!==cents(book.projected_total)||payload.months.length!==range.months.length)return null;
  const seen=new Set();
  for(const m of payload.months){const month=String(m.month||'').slice(0,7);if(m.month!==month+'-01'||!range.months.includes(month)||seen.has(month))return null;seen.add(month);
   if(!matches(m.cash,metrics(cash.items.filter(r=>r.event_date.slice(0,7)===month)))||cents(m.competence)!==Math.round(book.items.filter(r=>r.competence_month===m.month).reduce((n,r)=>n+number(r.amount),0)*100))return null;
  }
  return{...payload,month:range.month,partial:range.partial,entries:number(cash.total.entries),expenses:number(cash.total.payments),result:number(cash.total.result),
   sourceIncomplete:payload.complete===false||payload.source_complete===false};
 }
 return Object.freeze({bounds,summarize,bankPositions,periodBounds,summarizePeriod,monthBounds,forecastPeriodBounds,summarizeOverview});
});
