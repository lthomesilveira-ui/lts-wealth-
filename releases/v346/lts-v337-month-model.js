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
 return Object.freeze({bounds,summarize,bankPositions});
});
