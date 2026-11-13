(function(root,factory){'use strict';const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.LTSV441Budget=api;})(typeof window==='undefined'?globalThis:window,function(){
 'use strict';
 const cents=v=>typeof v!=='number'&&!(typeof v==='string'&&/^[+-]?\d+(\.\d+)?$/.test(v))?null:Number.isFinite(Number(v))&&Number.isSafeInteger(Math.round(Number(v)*100))?Math.round(Number(v)*100):null;
 const sum=xs=>xs.some(x=>x===null)?null:xs.reduce((a,b)=>a+b,0);
 const nullable=(v,positive=false)=>{const n=cents(v);if(v!==null&&(n===null||positive&&n<0))throw Error('invalid amount');return n;};
 function build(p){
  if(!p||p.ok!==true||p.version!=='budget-v441'||!Number.isInteger(p.year)||!/^\d{4}-\d{2}-\d{2}$/.test(p.as_of||'')
   ||!Number.isSafeInteger(p.plan_revision)||p.plan_revision<0||p.flow_provision_included!==false||p.basis!=='canonical_consumption_not_card_payment'
   ||!Array.isArray(p.rows)||!Array.isArray(p.months)||p.months.length!==12||!p.reference)throw Error('budget unavailable');
  const keys=Array.from({length:12},(_,i)=>p.year+'-'+String(i+1).padStart(2,'0')),seen=new Set();
  const rows=p.rows.map(r=>{
   if(typeof r.category!=='string'||!r.category.trim()||r.category.length>120||seen.has(r.category)||!Array.isArray(r.months)||r.months.length!==12)throw Error('invalid category');
   seen.add(r.category);
   return {category:r.category,reference:nullable(r.reference_monthly,true),months:r.months.map((m,i)=>{
    if(m.month!==keys[i]||!['owner','history','proposal'].includes(m.target_basis))throw Error('invalid month');
    return {month:m.month,target:nullable(m.target,true),actual:nullable(m.actual),pending:nullable(m.pending),basis:m.target_basis,strategy:m.strategy||null};
   })};
  });
  const months=p.months.map((m,i)=>{
   if(m.month!==keys[i]||typeof m.started!=='boolean'||typeof m.complete!=='boolean')throw Error('invalid month');
   const v={month:m.month,target:nullable(m.target,true),actual:nullable(m.actual),pending:nullable(m.pending),incomeTarget:nullable(m.income_target,true),
    incomeRegular:nullable(m.income_regular),extra:nullable(m.income_extraordinary),bonus:nullable(m.income_bonus??0),thirteenth:nullable(m.income_thirteenth??0),started:m.started,complete:m.complete};
   if(sum(rows.map(r=>r.months[i].actual))!==v.actual||sum(rows.map(r=>r.months[i].pending))!==v.pending||(rows.length?sum(rows.map(r=>r.months[i].target)):null)!==v.target)throw Error('totals mismatch');
   return v;
  });
  return {year:p.year,asOf:p.as_of,revision:p.plan_revision,proposed:p.proposed===true,rows,months,
   reference:{from:p.reference.from,to:p.reference.to,months:p.reference.months,expected:p.reference.expected_months,salaryMonths:p.reference.salary_months,salaryMonthly:nullable(p.reference.salary_monthly,true)},
   strategy:p.strategy||null,unknown:nullable(p.unclassified_actual),incomeGroups:p.actual_income_groups||[]};
 }
 function view(m,mode,month){
  const indices=mode==='year'?m.months.map((_,i)=>i):[Number(month.slice(5,7))-1];
  if(indices.some(i=>i<0||i>11)||month.slice(0,4)!==String(m.year))throw Error('invalid period');
  const cashUnallocated=(m.strategy?.cash_without_competence||[]).filter(x=>indices.some(i=>String(x.date).slice(0,7)===m.months[i].month)),cashWithoutCompetence=sum(cashUnallocated.map(x=>cents(x.amount)));
  const selected=indices.map(i=>m.months[i]),target=cashUnallocated.length?null:sum(selected.map(x=>x.target)),actual=sum(selected.map(x=>x.actual)),incomeTarget=sum(selected.map(x=>x.incomeTarget)),incomeRegular=sum(selected.map(x=>x.incomeRegular)),extra=sum(selected.map(x=>x.extra));
  return {cashUnallocated,cashWithoutCompetence,hasIncompletePlan:cashUnallocated.length>0||selected.some(x=>x.target===null),target,actual,incomeTarget,incomeRegular,extra,bonus:sum(selected.map(x=>x.bonus)),thirteenth:sum(selected.map(x=>x.thirteenth)),minimum:sum(m.rows.map(r=>sum(indices.map(i=>cents(r.months[i].strategy?.floor??0))))),pending:sum(selected.map(x=>x.pending)),
   plannedBalance:target===null||incomeTarget===null?null:incomeTarget-target,
   operating:incomeRegular===null||actual===null?null:incomeRegular-actual,
   afterExtras:incomeRegular===null||actual===null||extra===null?null:incomeRegular+extra-actual,
   started:selected.some(x=>x.started),complete:selected.every(x=>x.complete),
   rows:m.rows.map(r=>({category:r.category,reference:r.reference,target:sum(indices.map(i=>r.months[i].target)),actual:sum(indices.map(i=>r.months[i].actual)),
    gap:sum(indices.map(i=>r.months[i].target))===null?null:sum(indices.map(i=>r.months[i].target))-sum(indices.map(i=>r.months[i].actual)),
    type:r.months[indices[0]].strategy?.type||'unreviewed',reason:r.months[indices[0]].strategy?.reason||'',minimum:sum(indices.map(i=>cents(r.months[i].strategy?.floor??0))),details:indices.flatMap(i=>r.months[i].strategy?.details||[]),needsReview:indices.some(i=>r.months[i].strategy?.needsReview===true),suggested:indices.some(i=>r.months[i].basis==='history'||r.months[i].basis==='proposal')}))};
 }
 function flow(p,asOf){
  const days=p?.current_future?.days;if(!Array.isArray(days))return null;
  const vals=days.filter(d=>/^\d{4}-\d{2}-\d{2}$/.test(d.date)&&d.date>=asOf).sort((a,b)=>a.date.localeCompare(b.date));
  if(!vals.length)return null;
  const extract=d=>({date:d.date,bank:cents(d.fix86_columns?.saldo_final??d.Consolidado?.bank_balance),liquid:cents(d.fix86_columns?.saldo_apos_d0_1),shares:cents(d.fix86_columns?.saldo_apos_rsu),restricted:cents(d.fix86_columns?.saldo_apos_fgts)});
  const rows=vals.map(extract),limit=new Date(asOf+'T12:00:00Z');limit.setUTCDate(limit.getUTCDate()+90);const end=limit.toISOString().slice(0,10),short=rows.filter(x=>x.date<=end);
  const first=key=>{if(!short.length||short.some(x=>x[key]===null))return {known:false,date:null,amount:null};const r=short.find(x=>x[key]<0);return {known:true,date:r?.date||null,amount:r?.[key]??null};};
  return {asOf,through:short.at(-1)?.date||null,today:rows.find(x=>x.date===asOf)||null,bank:first('bank'),liquid:first('liquid'),shares:first('shares'),restricted:first('restricted')};
 }
 return Object.freeze({build,view,flow,cents,sum});
});
