/* Read-only property comparisons. Source copies corroborate; they never add expenses. */
(function(root){
 'use strict';
 const number=v=>v===null||v===undefined||v===''||!Number.isFinite(Number(v))?null:Number(v);
 const sum=rows=>rows.reduce((n,r)=>n+Number(r.amount),0);
 const same=(a,b)=>number(a)!==null&&number(b)!==null&&Math.round(Number(a)*100)===Math.round(Number(b)*100);
 const definitions=[
  ['acquisition','Aquisição','Patrimônio e financiamentos','Aquisição imobiliária'],
  ['works','Obra e reforma','Moradia','Obra, reforma e equipamentos'],
  ['housing','Moradia','Moradia','Uso e manutenção'],
  ['tax','Tributos','Moradia','Tributos']
 ];
 function build(wealth,packet,range){
  const rows=packet?.rows;
  if(!Array.isArray(rows)||!range?.from||!range?.to||packet.row_count!==rows.length||!same(sum(rows),packet.total))throw Error('Incomplete property list');
  const keys=new Set();
  for(const r of rows){
   if(!r.key||keys.has(r.key)||r.property_code!=='cipo396'||number(r.amount)===null)throw Error('Invalid property identity');
   keys.add(r.key);
  }
  const groups=definitions.map(([id,label,macrogroup,group])=>{
   const scope={property:'cipo396',macrogroup,group,sign:'net'};
   const selected=rows.filter(r=>r.taxonomy?.macrogroup===macrogroup&&r.taxonomy?.group===group),categories=new Map();
   for(const r of selected){
    const name=r.taxonomy?.category;if(!name)throw Error('Missing category');
    if(!categories.has(name))categories.set(name,[]);categories.get(name).push(r);
   }
   return{id,label,scope,total:sum(selected),count:selected.length,rows:selected,categories:[...categories].map(([label,items])=>({label,total:sum(items),count:items.length,scope:{...scope,category:label}})).sort((a,b)=>b.total-a.total)};
  });
  if(groups.reduce((n,g)=>n+g.count,0)!==rows.length)throw Error('Unknown property group');
  const model={total:sum(rows),count:rows.length,range:{...range},scope:{property:'cipo396',sign:'net'},groups,bridge:null};
  const rec=wealth?.wealth?.cipo_reconciliation,audit=rec?.consortium?.itau_source_audit,s=audit?.snapshot_scope;
  if(audit?.status!=='verified_original_signed_rows'||!s?.source_file||!/^\d{4}-\d\d-\d\d$/.test(s.source_paid_cutoff||'')||range.from!=='2013-10-10'||range.to<s.source_paid_cutoff)return model;
  function sourceRows(name){
   const all=s[name];if(!Array.isArray(all))throw Error('Missing source rows');
   const byFile=new Map();
   for(const r of all){
    if(!r.file||!/^[0-9a-f]{64}$/.test(r.sha256||'')||!r.sheet||!Number.isInteger(r.row)||r.row<1||number(r.signed_amount)===null)throw Error('Incomplete source identity');
    if(!byFile.has(r.file))byFile.set(r.file,[]);byFile.get(r.file).push(r);
   }
   const primary=byFile.get(s.source_file);if(!primary||byFile.size<2)throw Error('Uncorroborated source');
   const normalized=items=>items.map(r=>[r.sheet,r.row,r.date||'',r.description||'',Math.round(Number(r.signed_amount)*100)]).sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b)));
   for(const items of byFile.values()){
    if(new Set(items.map(r=>r.sheet+'|'+r.row)).size!==items.length||new Set(items.map(r=>r.sha256)).size!==1||JSON.stringify(normalized(items))!==JSON.stringify(normalized(primary)))throw Error('Conflicting source copies');
   }
   return primary.map(r=>({...r}));
  }
  try{
   const cash=sourceRows('source_cash_rows'),card=sourceRows('source_card_consortium_rows'),unlinked=sourceRows('works_unlinked_source_rows');
   const summaries=s.investment_summary;if(!Array.isArray(summaries)||summaries.length<2)throw Error('Missing summary');
   const source=summaries.find(r=>r.file===s.source_file);if(!source?.cells)throw Error('Missing primary summary');
   for(const other of summaries)for(const key of ['D3','D4','D13','D14','D41','J4','J5','J31'])if(!same(source.cells[key],other.cells?.[key]))throw Error('Conflicting summary');
   const cashTotal=cash.reduce((n,r)=>n+Number(r.signed_amount),0),cardTotal=card.reduce((n,r)=>n+Number(r.signed_amount),0),c=source.cells;
   if(!same(cashTotal,Number(c.D13)+Number(c.D14))||!same(cardTotal,c.D41)||!same(c.J4,cashTotal+cardTotal)||!same(c.J5,Number(c.D3)+Number(c.D4)+Number(c.J4))||!same(c.D3,s.source_loan_paid)||!same(c.D14,rec.consortium.itau_ledger))throw Error('Changed source totals');
   const acq=groups[0],works=groups[1],loan=acq.rows.filter(r=>r.taxonomy.category==='Financiamento Imobiliário');
   const prefix=loan.filter(r=>(r.event_date||r.date)<=s.source_paid_cutoff),tail=loan.filter(r=>(r.event_date||r.date)>s.source_paid_cutoff);
   const cardRows=acq.rows.filter(r=>r.taxonomy.category==='Consórcio');
   if(!same(sum(prefix),c.D3)||!same(sum(cardRows),cardTotal)||!same(sum(acq.rows.filter(r=>!loan.includes(r)&&!cardRows.includes(r))),c.D4))throw Error('Changed acquisition perimeter');
   const expected=Number(c.J5)+sum(tail)-cashTotal;if(!same(expected,acq.total))throw Error('Acquisition comparison does not close');
   const components=(rec.components||[]).filter(r=>r.class==='improvement');
   if(!components.length||components.some(r=>number(r.source_paid)===null))throw Error('Missing improvement components');
   const unique=components.reduce((n,r)=>n+Number(r.source_paid),0),duplicate=number(rec.source_internal_consistency?.duplicate_row_amount);
   if(duplicate===null||!same(unique+duplicate,c.J31)||!same(unique,rec.source_internal_consistency?.improvement_detail_total))throw Error('Changed improvement summary');
   model.bridge={cutoff:s.source_paid_cutoff,sourceFile:s.source_file,sourceSheet:s.source_sheet,copies:summaries.map(r=>({file:r.file,sha256:r.sha256})),source,
    acquisition:{sourceTotal:Number(c.J5),loanPrefix:{total:sum(prefix),count:prefix.length,scope:{...acq.scope,category:'Financiamento Imobiliário'}},loanTail:{total:sum(tail),count:tail.length,scope:{...acq.scope,category:'Financiamento Imobiliário'}},cashTotal,cashRows:cash,cardTotal,cardScope:{...acq.scope,category:'Consórcio'},canonical:acq.total},
    works:{sourceTotal:Number(c.J31),duplicate,unique,components:components.map(r=>({...r})),canonical:works.total,gap:(Math.round(unique*100)-Math.round(works.total*100))/100,unlinkedRows:unlinked,duplicateCells:Array.isArray(s.duplicate_formula_cells)?s.duplicate_formula_cells.slice():[]}};
  }catch{model.bridge=null;}
  // An explanation can account for source coverage without certifying a payment.
  const w=model.bridge?.works,e=s.works_cash_coverage_explanation;
  if(w&&e?.status==='verified_workbook_cash_coverage'){
   const isRow=(r,row,description)=>r.row===row&&r.date===e.date&&r.description===description&&same(r.signed_amount,e.amount);
   const component=w.components.find(r=>r.id===e.component_id);
   const copy=model.bridge.copies.find(r=>r.file===e.file&&r.sha256===e.sha256);
   if(copy&&e.amount>0&&same(e.amount,w.gap)&&component?.status==='source_only'&&component.method==='source_workbook_unmapped_ledger'
    &&component.description===e.description&&same(component.source_paid,e.amount)
    &&/^\d{4}-\d\d-\d\d$/.test(e.date||'')&&Number.isInteger(e.payment_row)&&e.payment_row>0
    &&Number.isInteger(e.services_payment_row)&&e.services_payment_row>0&&e.payment_row!==e.services_payment_row
    &&e.payment_sheet==='Pagamentos e Recebimentos'&&e.cash_sheet==='Fluxo de Caixa'&&/^[A-Z]+$/.test(e.cash_column||'')
    &&Number.isInteger(e.cash_services_row)&&e.cash_services_row>0&&e.cash_label_absent===true
    &&e.bank_payment_confirmed===false&&e.ledger_reclassification_allowed===false&&e.new_cash_event_allowed===false
    &&[e.cash_open,e.cash_income,e.cash_outflow,e.cash_close,e.cash_services_amount].every(v=>number(v)!==null)
    &&e.cash_outflow>=e.cash_services_amount&&e.cash_services_amount>=e.amount
    &&same(e.cash_open+e.cash_income-e.cash_outflow,e.cash_close)
    &&w.unlinkedRows.some(r=>isRow(r,e.payment_row,e.description))
    &&w.unlinkedRows.some(r=>isRow(r,e.services_payment_row,e.services_description)))w.coverageExplanation={...e};
  }
  return model;
 }
 root.LTSPropertyReconciliation={build};
 if(typeof module!=='undefined'&&module.exports)module.exports=root.LTSPropertyReconciliation;
})(typeof window==='undefined'?globalThis:window);
