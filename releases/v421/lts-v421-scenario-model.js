/* Select existing daily balances; never synthesize movements or fill missing days. */
(function(root){'use strict';
 const DAY=86400000;
 function stamp(value){if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(value))return null;const t=Date.parse(value+'T12:00:00Z');return Number.isFinite(t)&&new Date(t).toISOString().slice(0,10)===value?t:null;}
 function number(value){return(typeof value==='number'||typeof value==='string'&&value.trim()!=='')&&Number.isFinite(Number(value))?Number(value):null;}
 function horizon(asOf,policy){if(stamp(asOf)===null)throw Error('Invalid planning date');const target=(Number(asOf.slice(0,4))+5)+'-12-31';return policy?.asOf===asOf&&stamp(policy.horizon)!==null&&policy.horizon>=target?policy.horizon:target;}
 function scenario(flow,key,asOf,to){
  const column={base:'saldo_apos_d0_1',vested:'saldo_apos_rsu',fgts:'saldo_apos_fgts'}[key],start=stamp(asOf),end=stamp(to);
  if(!column||start===null||end===null||end<start)throw Error('Invalid scenario range');
  const input=flow?.flow?.current_future?.days,all=Array.isArray(input)?input:[],validDates=all.every(d=>stamp(d?.date)!==null);
  const days=all.filter(d=>stamp(d?.date)!==null&&d.date>=asOf&&d.date<=to).slice().sort((a,b)=>a.date.localeCompare(b.date));
  const read=d=>number(d?.fix86_columns?.[column]),seen=new Set(days.map(d=>d.date)),expected=(end-start)/DAY+1;
  const coverage=flow?.coverage,declared=(!coverage?.from||stamp(coverage.from)!==null&&coverage.from<=asOf)&&(!coverage?.to||stamp(coverage.to)!==null&&coverage.to>=to);
  const complete=flow?.complete!==false&&coverage?.complete!==false&&declared&&validDates&&seen.size===days.length&&days.length===expected&&days.every(d=>read(d)!==null);
  const firstNegative=days.find(d=>read(d)!==null&&read(d)<0)||null,worst=days.reduce((m,d)=>read(d)===null?m:!m||read(d)<read(m)?d:m,null);
  return {available:days.some(d=>read(d)!==null),complete,firstNegative,firstAmount:firstNegative?read(firstNegative):null,worstAmount:worst?read(worst):null,worstDate:worst?.date||null,lastDate:days.at(-1)?.date||null,horizon:to};
 }
 const api={horizon,scenario};if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.LTSV421Scenario=api;
})(typeof window==='undefined'?globalThis:window);
