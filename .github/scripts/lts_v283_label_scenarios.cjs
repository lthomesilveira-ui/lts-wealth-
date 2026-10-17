'use strict';
const assert=require('node:assert/strict'),path=require('node:path');
const overlay=require('./lts_v283_release_assets.cjs');
const hooks=require(path.join(overlay.fixtureRoot,'playwright-label-assertions.cjs'));
const ALIASES=['Assinatura','Assinaturas','Estacionamento E Pedágio','Tarifas bancárias','Benjamin — Benjamin - Estrutura e manutenção','Farmácia','Saúde','Tarifas e Juros'];
const LABELS=['Assinaturas','Assinaturas','Estacionamento e Pedágio','Tarifas Bancárias','Benjamin — Estrutura e manutenção','Farmácia','Saúde','Tarifas e Juros'];
const MONTH={from:'2026-10-01',to:'2026-10-16'},MATRIX={from:'2026-01-01',to:'2026-02-28'};
const ROWS=Array.from({length:205},(_,i)=>({
 key:'synthetic-label-'+i,source_ref:'synthetic-source-'+i,source_table:'synthetic_fixture',
 date:i===0?null:'2026-10-01',event_date:'2026-10-01',period:'2026-10-01',date_kind:i===0?'month':'day',
 description:'Descrição sintética '+i,current_category:ALIASES[i%ALIASES.length],category:ALIASES[i%ALIASES.length],subgroup:ALIASES[i%ALIASES.length],
 beneficiary:i%2?null:'Pessoa sintética',account_source:'Assinatura',reference:'Estacionamento E Pedágio',
 amount:i===0?0:i===1?-3:i+1,status:'identified',coverage_mode:'bank_observed_individual'
}));
const sum=rows=>rows.reduce((total,row)=>total+row.amount,0);
const months=(from,to)=>{const out=[];for(let date=new Date(from.slice(0,7)+'-01T12:00:00Z');date.toISOString().slice(0,10)<=to;date.setUTCMonth(date.getUTCMonth()+1))out.push(date.toISOString().slice(0,10));return out;};
function monthly(from,to){
 const keys=months(from,to),groups=[['Assinatura','2026-01-01',100],['Assinaturas','2026-02-01',200]];
 const expense_groups=groups.map(([label,month,value])=>({label,total:keys.includes(month)?value:0,source_rows:1,monthly:keys.map(key=>({month:key,amount:key===month?value:0}))}));
 const monthly_totals=keys.map(month=>{const expenses=expense_groups.reduce((total,group)=>total+group.monthly.find(row=>row.month===month).amount,0);return{month,revenue:0,expenses,extraordinary:0,operating_balance:-expenses,cash_after_extraordinary:-expenses};});
 const expenses=monthly_totals.reduce((total,row)=>total+row.expenses,0);
 return {version:'synthetic-label-monthly',from,to,months:keys,monthly_totals,
  totals:{revenue:0,expenses,extraordinary:0,operating_balance:-expenses,cash_after_extraordinary:-expenses},
  expense_groups,revenue_groups:[],extraordinary_groups:[],
  expense_unclassified_card_coverage:{total:0,monthly:keys.map(month=>({month,amount:0}))},
  stock_sale_supplement:{total:0,monthly:[]},open_audit_issues:[]};
}
function periodRows(args){return ROWS.filter(row=>row.event_date>=args.p_from&&row.event_date<=args.p_to);}
function report(args){
 const rows=periodRows(args),total=sum(rows);
 const management_groups=ALIASES.map(name=>{const matching=rows.filter(row=>row.category===name);return{name,total:sum(matching),rows:matching.length,subgroups:[],source_categories:[{name}]};});
 return {version:'expense-executive-v20-v178-review',as_of:args.p_to,
  period:{from:args.p_from,to:args.p_to,last_available:args.p_to,months_in_selection:months(args.p_from,args.p_to).length},
  summary:{selected_total:total,card_total:0,account_total:total,monthly_average:total,rows:rows.length,pending_identification:0},
  management_groups,monthly_detail:[{month:args.p_to.slice(0,7)+'-01',total}],coverage_disclosure:{total:0,rows:0}};
}
function detail(args){
 let rows=periodRows(args);
 if(args.p_group!==null){
  if(['Assinatura','Assinaturas'].includes(args.p_group)&&args.p_from<'2026-03-01'){
   const month=args.p_group==='Assinatura'?'2026-01-01':'2026-02-01',amount=args.p_group==='Assinatura'?100:200;
   rows=month>=args.p_from&&month<=args.p_to?[{...ROWS[1],key:'matrix-'+args.p_group,source_ref:'matrix-ref-'+args.p_group,date:month,event_date:month,period:month,date_kind:'day',amount,category:args.p_group,current_category:args.p_group,subgroup:args.p_group}]:[];
  }else rows=rows.filter(row=>row.category===args.p_group);
 }
 if(args.p_subgroup!==null)rows=rows.filter(row=>row.subgroup===args.p_subgroup);
 const offset=args.p_offset||0,limit=args.p_limit,total=sum(rows);
 return {version:'synthetic-label-detail',from:args.p_from,to:args.p_to,group:args.p_group,subgroup:args.p_subgroup,
  total,matched_total:total,row_count:rows.length,matched_count:rows.length,offset,
  next_offset:offset+limit<rows.length?offset+limit:null,revision:'synthetic-label-stable-1',rows:rows.slice(offset,offset+limit),components:[]};
}
function expectedRow(index){const row=ROWS[index],label=LABELS[index%LABELS.length];return{key:row.key,categoryLabel:label,account:row.account_source,beneficiaryLabel:row.beneficiary||'—',
 modalFields:{Categoria:label,Grupo:label,Subgrupo:label,'Conta/cartão':row.account_source,Beneficiário:row.beneficiary||'—',Origem:row.source_table,Referência:row.reference}};}
function createSuite(){
 const suite={enabled:false};
 suite.response=(name,args)=>{
  if(!suite.enabled)return{handled:false};
  if(name==='lts_browser_expense_detail_v229')return{handled:true,data:detail(args)};
  if(/^lts_browser_expenses_|^lts_browser_expense_executive_/.test(name))return{handled:true,data:report(args)};
  if(name==='lts_browser_monthly_v229'||/^lts_browser_monthly_balance_v/.test(name))return{handled:true,data:monthly(args.p_from,args.p_to)};
  return{handled:false};
 };
 suite.run=async({frame,page,nav,setRange,ready,reportReady,capture,settle,calls,mark})=>{
  suite.enabled=true;
  const result={syntheticOnly:true,writerInvoked:false,canonical:[],natural:null,matrix:null,ranking:[],observations:[]};
  const snapshot=()=>frame.evaluate(()=>{const t=window.__LTS_V168_STATE.transactions;return{pageIndex:t.pageIndex,rows:JSON.stringify(t.rows),total:t.total,count:t.count,
   focus:{tag:document.activeElement?.tagName,id:document.activeElement?.id||null},scroll:window.scrollY,
   scrollers:[...document.querySelectorAll('[data-v281-expense-transactions-list] .v168-tablewrap')].map(node=>({left:node.scrollLeft,width:node.clientWidth,scroll:node.scrollWidth})),
   document:{width:innerWidth,scroll:document.documentElement.scrollWidth}};});
  mark('labels-205-canonical');await setRange(MONTH);await ready(205,MONTH);
  const initial=await snapshot();assert.equal(initial.rows,JSON.stringify(ROWS),'Real reader preserves every raw fixture field');assert.equal(initial.total,sum(ROWS));assert.equal(initial.count,205);
  assert.equal(await frame.locator('[data-v281-expense-row-key]').count(),100);
  assert.match(await frame.locator('[data-v281-expense-row-key="synthetic-label-0"] .num').innerText(),/0,00/);
  assert.match(await frame.locator('[data-v281-expense-row-key="synthetic-label-1"] .num').innerText(),/-.*3,00/);
  result.canonical.push(await hooks.canonicalLedger(frame,{syntheticOnly:true,visibleRows:[expectedRow(0),expectedRow(1)]}));
  await capture('labels-205-first');
  const readsBefore=calls.length;
  for(let cycle=0;cycle<2;cycle++){
   await frame.locator('[data-v281-expense-transactions-page="next"]').click();await settle();
   assert.equal(await frame.locator('[data-v281-expense-row-key]').count(),100);
   assert.equal(await frame.locator('[data-v281-expense-row-key]').first().getAttribute('data-v281-expense-row-key'),'synthetic-label-100');
   result.canonical.push(await hooks.canonicalLedger(frame,{syntheticOnly:true,visibleRows:[100,104,106,107].map(expectedRow)}));
   await frame.locator('[data-v281-expense-transaction-detail="100"]').click();
   assert.equal(await frame.locator('[data-v281-expense-transaction-modal] h2').innerText(),ROWS[100].description,'Page two detail uses the global raw row index');
   await capture('labels-205-canonical-detail-'+cycle,'[data-v281-expense-transaction-modal] .v168-modal');
   await frame.locator('[data-v281-expense-transaction-modal] [data-v168-close]').click();
   await frame.locator('[data-v281-expense-transaction-modal]').waitFor({state:'detached'});
   await capture('labels-205-second-'+cycle);const second=await snapshot();assert.equal(second.pageIndex,1);assert.equal(second.rows,initial.rows);
   assert(second.document.scroll<=second.document.width+2);
   for(const scroll of second.scrollers)assert(scroll.left>=0&&scroll.left<=scroll.scroll-scroll.width+2,'Table scroll remains valid after normal detail clicks');
   await frame.locator('[data-v281-expense-transactions-page="prev"]').click();await settle();
   const returned=await snapshot();assert.equal(returned.pageIndex,0);assert.equal(returned.rows,initial.rows);assert.equal(returned.total,initial.total);
   assert.equal(await frame.locator('[data-v281-expense-row-key]').first().getAttribute('data-v281-expense-row-key'),'synthetic-label-0');
   result.observations.push({cycle,second,returned});await capture('labels-205-return-'+cycle);
  }
  assert.equal(calls.length,readsBefore,'Two page/detail/close/return cycles invoke no RPC');
  // Reach the final five rows through real enabled paging controls as well.
  await frame.locator('[data-v281-expense-transactions-page="next"]').click();await frame.locator('[data-v281-expense-transactions-page="next"]').click();
  assert.equal(await frame.locator('[data-v281-expense-row-key]').count(),5);assert(await frame.locator('[data-v281-expense-transactions-page="next"]').isDisabled());
  assert.equal(await frame.locator('[data-v281-expense-row-key]').first().getAttribute('data-v281-expense-row-key'),'synthetic-label-200');
  await frame.locator('[data-v281-expense-transactions-page="prev"]').click();await frame.locator('[data-v281-expense-transactions-page="prev"]').click();
  assert.equal(calls.length,readsBefore);

  mark('labels-natural-preview');await nav('Atualizações').click();
  await frame.waitForFunction(()=>!window.__LTS_V168_STATE.updates.loading);await settle();
  await frame.locator('#v168NlPhrase').fill('paguei R$ 12 na conta Itaú hoje categoria Assinaturas');
  const naturalStart=calls.length;await frame.locator('#v168NlPreview').click();
  await frame.locator('select#v168NlCategory').waitFor({state:'visible'});
  const initialPreview=await frame.evaluate(()=>JSON.parse(JSON.stringify(window.__LTS_V168_STATE.nl.preview)));
  assert.equal(initialPreview.category,'Assinaturas');assert.equal(initialPreview.amount,12);assert.equal(initialPreview.account,'Itaú');
  result.natural=await hooks.naturalOptions(frame,{syntheticOnly:true,options:[
   {value:'Assinaturas',label:'Assinaturas'},
   {value:'Estacionamento E Pedágio',label:'Estacionamento e Pedágio'},
   {value:'Tarifas Bancárias',label:'Tarifas Bancárias'},
   {value:'Benjamin - Estrutura e manutenção',label:'Benjamin — Estrutura e manutenção'},
   {value:'Benjamin — Benjamin - Estrutura e manutenção',label:'Benjamin — Estrutura e manutenção'},
   {value:'Vestuário',label:'Imagem e cuidados pessoais'},
   {value:'Farmácia',label:'Farmácia'},
   {value:'Tarifas e Juros',label:'Tarifas e Juros'}
  ]});
  const options=await frame.locator('#v168NlCategory option').evaluateAll(nodes=>nodes.map(node=>({value:node.value,label:node.textContent})));
  assert.equal(options.filter(option=>option.label==='Benjamin — Estrutura e manutenção').length,2,'Equal labels retain both existing raw option identities');
  assert(!options.some(option=>option.value==='Assinatura'),'Existing natural-input canonical alias behavior remains intact');
  const afterPreview=await frame.evaluate(()=>JSON.parse(JSON.stringify(window.__LTS_V168_STATE.nl.preview)));
  assert.deepEqual({...afterPreview,category:initialPreview.category},initialPreview,'Only the selected raw category field changes');
  assert.equal(await frame.locator('#v168NlConfirm').isChecked(),false);assert(await frame.locator('#v168NlApply').isDisabled());
  assert(!calls.slice(naturalStart).some(call=>/_decision_|_apply_|_create_|_save_|_mutate_|_classify_|_classification_|_delete_|_confirm_|_refresh_|_upload_|_update_/.test(call.name)),'Preview/options invoke no writer');
  result.natural={...result.natural,initialPreview,afterPreview,options};await capture('labels-natural-preview','.v168-nl');

  mark('labels-monthly-raw-collision');await nav('Despesas').click();await setRange(MATRIX);
  await frame.getByRole('tab',{name:'Balanço mensal',exact:true}).click();
  await frame.waitForFunction(range=>{const state=window.__LTS_V175_STATE.monthly;return !state.loading&&!state.error&&state.key===range.from+'|'+range.to&&state.data?.months?.length===2;},MATRIX);await settle();
  result.matrix=await hooks.monthlyKeys(frame,{syntheticOnly:true,rows:[
   {rawGroup:'Assinatura',label:'Assinaturas',zeroMonthColumns:[1]},
   {rawGroup:'Assinaturas',label:'Assinaturas',zeroMonthColumns:[0]}
  ]});
  const matrix=frame.locator('.v182-matrix').filter({has:frame.locator('h2',{hasText:/^Despesas por categoria$/})});
  const rawData=await frame.evaluate(()=>JSON.stringify(window.__LTS_V175_STATE.monthly.data));
  await capture('labels-monthly-collision','.v182-matrix:has(h2:text-is("Despesas por categoria"))');
  const opened=[];
  for(const [group,month,from,to,total]of [['Assinatura','2026-01','2026-01-01','2026-01-31',100],['Assinaturas','2026-02','2026-02-01','2026-02-28',200]]){
   const button=matrix.locator('tr[data-lts-category-key="'+group+'"] button[data-month="'+month+'"]');
   assert.equal(await button.getAttribute('data-group'),group);assert((await button.getAttribute('aria-label')).includes('Assinaturas'));
   const callStart=calls.length;await button.click();
   await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail&&!window.__LTS_V178_STATE.detail.loading&&!window.__LTS_V178_STATE.detail.error);
   assert.equal(await frame.locator('#v178DetailTitle').innerText(),'Assinaturas');
   const requests=calls.slice(callStart).filter(call=>call.name==='lts_browser_expense_detail_v229');
   assert.equal(requests.length,1);assert.deepEqual(requests[0].args,{p_from:from,p_to:to,p_group:group,p_subgroup:null,p_offset:0,p_limit:500,p_query:null});
   const state=await frame.evaluate(()=>({group:window.__LTS_V178_STATE.detail.group,total:window.__LTS_V178_STATE.detail.total,rows:window.__LTS_V178_STATE.detail.rows}));
   assert.equal(state.group,group);assert.equal(state.total,total);assert.equal(state.rows[0].category,group);
   await capture('labels-monthly-detail-'+month,'#v178Drawer .v178-drawer');
   await frame.locator('#v178Drawer .v178-close').click();await frame.locator('#v178Drawer').waitFor({state:'detached'});
   assert(await button.evaluate(node=>document.activeElement===node),'Existing drawer focus return remains intact');
   assert.equal(await frame.evaluate(()=>JSON.stringify(window.__LTS_V175_STATE.monthly.data)),rawData,'Opening aliased matrix partitions preserves raw monthly data');
   opened.push({group,month,total,args:requests[0].args});
  }
  result.matrix={...result.matrix,opened};

  mark('labels-ranking-drawers');await frame.getByRole('tab',{name:'Visão geral',exact:true}).click();await setRange(MONTH);await reportReady(MONTH);
  for(const index of [0,2,3,4]){
   const group=ALIASES[index],title=LABELS[index];
   const buttons=frame.locator('.v168-expenses button.v178-open.title');
   const position=await buttons.evaluateAll((nodes,raw)=>nodes.findIndex(node=>node.dataset.group===raw),group);
   assert(position>=0,'Raw ranking partition exists: '+group);const button=buttons.nth(position);assert.equal(await button.innerText(),title);
   const callStart=calls.length;await button.click();await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail&&!window.__LTS_V178_STATE.detail.loading&&!window.__LTS_V178_STATE.detail.error);
   assert.equal(await frame.locator('#v178DetailTitle').innerText(),title);
   const requests=calls.slice(callStart).filter(call=>call.name==='lts_browser_expense_detail_v229');assert.equal(requests.length,1);assert.equal(requests[0].args.p_group,group);
   await capture('labels-category-drawer-'+index,'#v178Drawer .v178-drawer');
   await frame.locator('#v178Drawer .v178-close').click();await frame.locator('#v178Drawer').waitFor({state:'detached'});
   result.ranking.push({rawGroup:group,label:title,args:requests[0].args});
  }
  assert(!calls.some(call=>/_decision_|_apply_|_create_|_save_|_mutate_|_classify_|_classification_|_delete_|_confirm_|_refresh_|_upload_|_update_/.test(call.name)),'This entire ledger/label gate invokes no financial writer');
  return result;
 };
 return suite;
}
function staticCheck(){
 assert.equal(ROWS.length,205);assert.equal(new Set(ROWS.map(row=>row.key)).size,205);assert.equal(ROWS[0].amount,0);assert.equal(ROWS[1].amount,-3);
 const args={p_from:MONTH.from,p_to:MONTH.to,p_group:null,p_subgroup:null,p_offset:0,p_limit:10000,p_query:null};
 const ledger=detail(args);assert.equal(ledger.row_count,205);assert.equal(ledger.total,sum(ROWS));assert.equal(ledger.next_offset,null);
 const data=monthly(MATRIX.from,MATRIX.to);assert.deepEqual(data.expense_groups.map(group=>group.label),['Assinatura','Assinaturas']);
 assert.deepEqual(data.expense_groups.map(group=>group.monthly.map(item=>item.amount)),[[100,0],[0,200]]);assert.equal(data.totals.expenses,300);
 assert.equal(detail({...args,p_from:'2026-01-01',p_to:'2026-01-31',p_group:'Assinatura',p_limit:500}).total,100);
 assert.equal(detail({...args,p_from:'2026-02-01',p_to:'2026-02-28',p_group:'Assinaturas',p_limit:500}).total,200);
 assert.equal(detail({...args,p_from:'2026-02-01',p_to:'2026-02-28',p_group:'Assinatura',p_limit:500}).total,0);
 return {pass:true,synthetic_rows:205,raw_partitions:['Assinatura','Assinaturas'],zero_collision:true,external_requests:0};
}
module.exports={createSuite,staticCheck};
if(require.main===module)console.log(JSON.stringify(staticCheck(),null,2));
