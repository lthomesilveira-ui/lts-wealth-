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
 return Object.freeze({bounds,summarize,bankPositions,periodBounds,summarizePeriod});
});
