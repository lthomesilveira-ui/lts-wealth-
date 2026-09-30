'use strict';
const {chromium}=require('playwright');
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {product:baseProduct,cockpit,wealth:baseWealth}=require('./lts_v165_executive_ux_gate.js');
const BASE='http://127.0.0.1:'+(process.env.LTS_V178_PORT||8788);
const session={access_token:'controlled-fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};
const groups=[['Apartamento · CIPÓ 396',804,10],['Rafiki',1207,1],['Benjamin — Saúde',3,20],['Larissa — Saúde',2,30],['Lucas — Saúde',4,40],['Saúde — pessoa a confirmar',1,80],['Benjamin — Educação',5,50],['Lucas — Educação',2,60],['Benjamin — Vestuário',2,9],['Lucas — Vestuário',1,70],['Larissa — despesas',2,100],['Empréstimos',2,200]];
const components=['Aquisição do imóvel','Obra e reforma','Custos de moradia','Impostos do imóvel'];
const sum=xs=>xs.reduce((a,b)=>a+b,0);
const money=x=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(x).replace(/\s+/g,' ');
const semantic=x=>String(x||'').replace(/\s+/g,' ').trim();
function records(group){const spec=groups.find(g=>g[0]===group);if(!spec)return[];return Array.from({length:spec[1]},(_,i)=>({key:group+':'+i,date:'2026-09-01',period:'2026-09-01',date_kind:i%13===0?'month':'day',description:'Registro sintético '+String(i+1).padStart(4,'0'),account_source:i%2?'Cartão de teste':'Conta de teste',beneficiary:group.includes('Benjamin')?'Benjamin':group.includes('Larissa')?'Larissa':group.includes('Lucas')?'Lucas':null,amount:spec[2],category:group,component:group===groups[0][0]?components[i%4]:null,subgroup:group===groups[0][0]?components[i%4]:group,status:group.includes('confirmar')?'pending':'identified'}))}
function details(args){const all=records(args.p_group).filter(r=>!args.p_subgroup||r.subgroup===args.p_subgroup),offset=args.p_offset||0,limit=args.p_limit||500;return{version:'expense-detail-v178',from:args.p_from,to:args.p_to,group:args.p_group,subgroup:args.p_subgroup,total:sum(all.map(r=>r.amount)),row_count:all.length,matched_count:all.length,offset,next_offset:offset+limit<all.length?offset+limit:null,revision:'stable-'+args.p_group+args.p_subgroup,rows:all.slice(offset,offset+limit),components:args.p_group===groups[0][0]?components.map(n=>({name:n,total:2010,rows:201})):[]}}
function report(from,to){const total=sum(groups.map(g=>g[1]*g[2]));return{version:'expense-executive-v20-v178-review',as_of:to,period:{from,to,last_available:to,months_in_selection:9},summary:{selected_total:total,card_total:total/2,account_total:total/2,monthly_average:total/9,rows:sum(groups.map(g=>g[1])),pending_identification:1},management_groups:groups.map(([name,n,value])=>({name,total:n*value,rows:n,subgroups:name===groups[0][0]?components.map(n=>({name:n,total:2010,rows:201})):[]})),monthly_detail:[{month:to.slice(0,7)+'-01',total}],coverage_disclosure:{total:0,rows:0}}}
function months(from,to){const d=new Date(from.slice(0,7)+'-01T12:00:00Z'),out=[];while(d.toISOString().slice(0,7)<=to.slice(0,7)){out.push(d.toISOString().slice(0,10));d.setUTCMonth(d.getUTCMonth()+1)}return out}
function monthly(from,to){const m=months(from,to),amount=sum(groups.map(g=>g[1]*g[2])),mt=m.map((key,i)=>({month:key,revenue:10000,expenses:i===m.length-1?amount:0,operating_balance:10000-(i===m.length-1?amount:0),extraordinary:0,cash_after_extraordinary:10000-(i===m.length-1?amount:0)}));return{version:'monthly-v178-person-integrity',from,to,months:m,monthly_totals:mt,totals:{revenue:10000*m.length,expenses:amount,operating_balance:10000*m.length-amount,extraordinary:0,cash_after_extraordinary:10000*m.length-amount},expense_groups:groups.map(g=>({label:g[0],total:g[1]*g[2],source_rows:g[1],monthly:m.map((key,i)=>({month:key,amount:i===m.length-1?g[1]*g[2]:0}))})),revenue_groups:[{label:'Renda sintética',total:10000*m.length,monthly:m.map(month=>({month,amount:10000}))}],extraordinary_groups:[],expense_unclassified_card_coverage:{total:0,monthly:m.map(k=>({month:k,amount:0}))},stock_sale_supplement:{total:0,monthly:[]},open_audit_issues:[]}}
function dayRow(date,en=0,ex=0,cash=-1000,available=1100){return{date,historical:false,summary:{events:en||ex?1:0,Consolidado:{entries:en,exits:ex}},Consolidado:{bank_balance:cash,economic_net:en-ex},Itaú:{net:en-ex,balance:cash},Bradesco:{net:0,balance:0},C6:{net:0,balance:0},fix86_columns:{saldo_anterior:cash-en+ex,entradas:en,saidas:ex,saldo_final:cash,liq_d0_1_recurso:100,rsus_vested:available,fgts:5000,saldo_apos_d0_1:cash+100,saldo_apos_rsu:cash+100+available,saldo_apos_fgts:cash+5100+available}}}
function flow(from,to){
 const ds=[];for(let d=new Date(from+'T12:00:00Z');d.toISOString().slice(0,10)<=to;d.setUTCDate(d.getUTCDate()+1)){const date=d.toISOString().slice(0,10);ds.push(dayRow(date,date==='2026-11-09'?300:0,date==='2026-11-05'?100:date==='2026-11-09'?300:0,date>='2026-11-05'?-1100:-1000,date>='2026-11-10'?2300:date>='2026-11-08'?1600:1100))}
 const events=[{source:'future_award_vesting_marker',event_date:'2026-11-05',account:'Corretora',category:'RSU',description:'Vesting',signed_amount:0},{source:'future_rsu_available',event_date:'2026-11-08',account:'Corretora',category:'RSU',description:'RSU disponível',signed_amount:500},{source:'future_rsu_available',event_date:'2026-11-10',account:'Corretora',category:'RSU',description:'RSU disponível',signed_amount:700},{source:'legacy_fix86',source_ref:'cash-1',event_date:'2026-11-05',account:'Itaú',category:'Despesas',description:'Saída comprovada',signed_amount:-100},{source:'legacy_fix86',source_ref:'cash-2',event_date:'2026-11-09',account:'Itaú',category:'Receitas',description:'Entrada comprovada',signed_amount:300},{source:'legacy_fix86',source_ref:'cash-3',event_date:'2026-11-09',account:'Itaú',category:'Despesas',description:'Saída comprovada',signed_amount:-300}].filter(e=>e.event_date>=from&&e.event_date<=to);
 return{ok:true,flow:{from,to,available_year_from:2013,available_year_to:2041,historical_balance_truth_contract:{consolidated_first_complete_opening:'2026-09-01',itau_first_documentary_opening:'2026-09-01',bradesco_first_documentary_opening:'2026-09-01',c6_first_documentary_opening:'2026-09-01'},historical:{days:[],events:[]},current_future:{from,to,days:ds,events}}}
}
function awards(){return{version:'awards-v178',as_of:'2026-09-17',vested_shares:1000,brokerage_cash:100,brokerage_available:1100,events:[{id:'award1',type:'RSU',regular_rsu:true,vesting_date:'2026-11-05',available_date:'2026-11-08',value:500},{id:'award2',type:'RSU',regular_rsu:true,vesting_date:'2026-11-07',available_date:'2026-11-10',value:700}]}}

// All values, source IDs and card numbers below are synthetic.
function fixtureHistory(){return Array.from({length:80},(_,i)=>({source_id:'history-'+i,description:'Compra sintética '+(i+1),amount:i===79?-10:10,last4:i%2?'1111':'2222',purchase_date:'2026-06-15',category:'Mercado',category_basis:'historical_workbook'}))}
function fixtureCycles(classified=false){
 const sample=(id,amount,cat='Mercado')=>({source_id:id,description:'Compra sintética '+id,amount,last4:'1111',purchase_date:'2026-09-18',installment_number:1,total_installments:3,category:cat,category_basis:cat==='A classificar'?'unresolved':'user_decision'});
 const entries=[['Bradesco','aeternum',1200,'1111'],['Bradesco','bradesco_prime',null,'2222'],['Itaú','itau_mastercard',800,'3333'],['Itaú','itau_visa',null,'4444'],['C6','c6',100,'5555']];
 return {version:'card-cycles-v226',active_billing_accounts:5,as_of:'2026-09-20',cards:entries.map(([bank,family,amount,last4])=>({bank,family,name:family,last4,status:'ACTIVE',cycles:amount==null?[]:[{month:'2026-10-01',due_date:'2026-10-12',amount,basis:'open_finance_composition',items:[sample('a-'+family,amount/2),sample('b-'+family,amount/2,!classified&&family==='aeternum'?'A classificar':'Saúde')]},{month:'2026-11-01',due_date:null,amount:100,basis:'derived_current_installments',items:[{...sample('future-'+family,100),installment_number:2}]}]}))};
}

async function run(browser,viewport,label){
 const context=await browser.newContext({viewport});
 await context.addInitScript(()=>{const Native=Date;window.__TEST_NOW__='2026-09-20T13:00:00Z';class TestDate extends Native{constructor(...args){super(...(args.length?args:[Native.parse(window.__TEST_NOW__)]))}static now(){return Native.parse(window.__TEST_NOW__)}}window.Date=TestDate});
 await context.addInitScript(s=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s)),session);
 const page=await context.newPage();page.setDefaultTimeout(20000);const errors=[],calls=[];
 const cardNames=['Bradesco Visa','VISA AETERNUM','Itaú Mastercard Black','Itaú Visa','C6'];
 const flags={reviewDone:false,manualDescription:null,manualDeleted:false,cashFail:true,forecastFail:true,cardFail:true,date:'2026-09-20',cash:-1000,incomplete:false,pageFailure:false,cyclesFail:false,cardClassified:false};
 page.on('pageerror',e=>errors.push(String(e.stack||e)));
 await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
  const req=route.request(),name=new URL(req.url()).pathname.split('/').pop();let a={};try{a=JSON.parse(req.postData()||'{}')}catch{}calls.push({name,args:a});let data={ok:true,items:[],rows:[]},status=200;
  if(name==='token')data=session;
  else if(name==='lts_browser_product_v1')data={ok:true,mvp:baseProduct()};
  else if(name==='lts_browser_dashboard_cockpit_v1')data=cockpit;
  else if(name==='lts_browser_planning_ui_contract_v1')data={version:'planning-ui-contract-v2',period_to:'2027-12-31',fgts_covers_horizon:true,fgts_first_negative:null,labels:{d01:'Cobertura de teste',rsu:'Cobertura de teste',fgts:'Com FGTS, sem ruptura até 31/12/2027'}};
  else if(name==='lts_browser_card_cycles_v229'){
   if(flags.cyclesFail){status=503;data={message:'fixture card unavailable'}}else data=fixtureCycles(flags.cardClassified);
  }
  else if(name==='lts_browser_card_history_v226')data={version:'card-history-v226',invoices:[{bank:'Itaú',family:'itau_mastercard',card_name:'Mastercard Black',reference_month:'2026-07-01',due_date:'2026-07-12',amount:780,detail_total:780,difference:0,item_count:80,detail_complete:true},...(a.p_from<='2024-01-01'&&a.p_to>='2024-01-31'?[{bank:'Itaú',family:'itau_mastercard',reference_month:'2024-01-01',due_date:null,amount:30,detail_total:30,difference:0,item_count:3,detail_complete:true,source:'workbook_reconciled'}]:[])]};
  else if(name==='lts_browser_card_detail_v226')data=a.p_month==='2024-01-01'?{invoice_amount:30,alternative_note:'Outra fonte da mesma fatura; não somar novamente.',alternative_items:[{description:'Compra bancária complementar',purchase_date:'2023-12-20',amount:20,last4:'1111',category:'Mercado'}],source_note:'Composição reconciliada da planilha; estabelecimento e dia da compra não informados.',items:Array.from({length:3},(_,i)=>({description:'Linha '+(i+1)+' da planilha · estabelecimento não informado',amount:10,last4:'1111',category:'Mercado',category_basis:'historical_workbook',date_kind:'reference_month',reference_month:'2024-01-01'}))}:{invoice_amount:780,items:fixtureHistory()};
  else if(name==='lts_browser_card_category_options_v226')data={categories:['Mercado','Saúde','Presentes']};
  else if(name==='lts_browser_card_classify_v226'){assert.equal(a.p_category,'Saúde');assert.equal(a.p_beneficiary,'Lucas');flags.cardClassified=true;data={ok:true};}
  else if(name==='lts_browser_open_finance_pending_v225')data={version:'pending-expense-v225',transaction_count:0,net_expense:0,rows:[]};
  else if(name==='lts_browser_open_finance_refresh_v1'){status=503;data={message:'deliberate sync failure'};}
  else if(name==='lts_browser_cash_today_v178'){
   if(flags.cashFail){data={message:'deliberate cash failure'};status=503}else data={version:'cash-today-v179-current-canonical',status:'complete',as_of:flags.date,cash:flags.incomplete?null:flags.cash,d0:100,brokerage_available:1100,fgts:5000,available_total:flags.incomplete?1200:flags.cash+1200,day:dayRow(flags.date,0,0,flags.cash)};
  }
  else if(name==='lts_browser_expenses_v229'||/^lts_browser_expense_executive_v/.test(name))data=report(a.p_from,a.p_to);
  else if(name==='lts_browser_expense_detail_v229'){
   if(flags.pageFailure&&a.p_offset===500){data={message:'deliberate page failure'};status=503;flags.pageFailure=false}else{await new Promise(r=>setTimeout(r,a.p_group==='Rafiki'?80:5));data=details(a)}
  }
  else if(name==='lts_browser_card_flow_schedule_v2'){if(flags.cardFail){status=503;data={message:'deliberate card failure'}}else data={inventory:{cards:cardNames.map((card_name,i)=>({bank:i<2?'Bradesco':i<4?'Itaú':'C6',card_name,first_seen:'2020-01-01',last_seen:'2026-09-20'}))},months:[],summary:{}};}
  else if(name==='lts_browser_invoice_documentary_only_v1'||name==='lts_browser_legacy_invoice_gap_v183')data={financial_effect:'none',invoices:[]};
  else if(name==='lts_browser_invoice_flow_reconciliation_v183')data={rows:a.p_from<='2026-09-15'&&a.p_to>='2026-09-15'?[{card_name:'VISA AETERNUM',reference_month:'2026-09-01',due_date:'2026-09-15',documented_amount:100,flow_amount:100,difference:0,reconciliation_status:'reconciled'}]:[]};
  else if(name==='lts_browser_card_settlement_detail_v3')data={matched:true,due_date:'2026-09-15',invoice_total:100,payment_documented:true,cash_effect_date:'2026-09-15'};
  else if(name==='lts_browser_flow_event_editor_v1')data={editable:true,event_date:a.p_event_date,source:a.p_source,source_ref:a.p_source_ref,description:flags.manualDescription||'Despesa manual sintética',amount:flags.manualDescription?101:100,account:'Itaú'};
  else if(/^lts_browser_flow_mutate_v/.test(name)){if(a.p_action==='edit')flags.manualDescription=a.p_payload.description;if(a.p_action==='cancel')flags.manualDeleted=true;data={ok:true};}
  else if(name==='lts_browser_expense_review_queue_v229'){assert.equal(a.p_from,'2013-10-10','Updates queue is independent of the expense filter');data={row_count:flags.reviewDone?0:1,matched_count:flags.reviewDone?0:1,offset:0,next_offset:null,category_options:['Mercado'],rows:flags.reviewDone?[]:[{key:'pending-fixture',source_table:'lts_open_finance_staging',source_ref:'pending-fixture',date:'2026-09-19',description:'Pagamento sintético para conferir',amount:57,category:'A classificar',account_source:'Itaú',question_kind:'classification'}]};}
  else if(name==='lts_browser_expense_review_decision_v229'){assert.equal(a.p_category_label,'Mercado');flags.reviewDone=true;data={ok:true,resolved:true};}
  else if(name==='lts_browser_property_archive_v178')data={rows:[{key:'component1',description:'Obra documentada',amount:10000,component:'Obra e reforma',date_kind:'historical'},{key:'component2',description:'Consórcio documentado',amount:500,component:'Consórcio',date_kind:'historical'}]};
  else if(name==='lts_browser_awards_v178')data=awards();
  else if(name==='lts_browser_monthly_v229'||/^lts_browser_monthly_balance_v/.test(name))data=monthly(a.p_from,a.p_to);
  else if(/^lts_browser_flow_v/.test(name)){
   if(flags.forecastFail){data={message:'deliberate forecast failure'};status=503}else {data=flow(a.p_from,a.p_to);data.flow.current_future.events=data.flow.current_future.events.filter(e=>!flags.manualDeleted||e.source_ref!=='cash-1').map(e=>e.source_ref==='cash-1'&&flags.manualDescription?{...e,description:flags.manualDescription}:e);}
  }
  else if(/^lts_browser_wealth_detail_v/.test(name))data={...baseWealth,pensions:{positions:[],total_gross_brl:0},current_liquidity:{brokerage_available:1100},current_awards:awards(),morgan_statement:{as_of:'2026-09-17',gross_total_brl:51000,available_total_brl:1500,available_components:{vested_shares_brl:1400,brokerage_cash_brl:100},future_components:{regular_rsu_gross_brl:40000,cash_rsu_after_reserve_brl:7000,future_after_reserve_brl:47000},considered_total_after_reserve_brl:48500}};
  else if(name==='lts_browser_recurring_future_gap_audit_v5')data={horizon_checks:[],items:[]};
  else if(/expense_context/.test(name))data={contexts:[],natures:[],summary:{}};
  await route.fulfill({status,contentType:'application/json',body:JSON.stringify(data)});
 });
 let frame;
 try{
  await page.goto(BASE+'/releases/'+(process.env.LTS_RELEASE||'v225')+'/app.html',{waitUntil:'domcontentloaded'});
  for(let i=0;i<180;i++){frame=page.frames().find(f=>f.url().includes('/index.html'));if(frame&&await frame.evaluate(()=>!!window.__LTS_V178_REVIEW?.installed).catch(()=>false))break;await page.waitForTimeout(100)}
  assert(await frame.evaluate(()=>!!window.__LTS_V178_REVIEW?.installed),'V178 installed');
  const nav=n=>viewport.width<=520?frame.locator('#dx1MobileNav [data-mobile-route="'+n+'"]'):frame.locator('.nav [data-v="'+n+'"]');
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='error'&&window.__LTS_V178_STATE.forecast.status==='error');
  const kpi=label=>frame.locator('.v168-kpi').filter({has:frame.locator('span').filter({hasText:new RegExp('^'+label+'$')})});
  assert.equal(semantic(await kpi('Total disponível hoje').locator('strong').innerText()),'—','partial sum must not masquerade as complete');
  assert((await frame.locator('.v168-dashboard').innerText()).includes('Projeção indisponível'),'failed forecast is not stale risk date');
  flags.cashFail=false;flags.forecastFail=false;
  await frame.locator('.v178-refresh').first().click();
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='ready'&&window.__LTS_V178_STATE.forecast.status==='ready');
  assert.equal(semantic(await kpi('Total disponível hoje').locator('strong').innerText()),money(200),'negative cash is included');
  flags.cash=0;await frame.evaluate(()=>window.__LTS_V178_REVIEW.refresh());await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='ready'&&window.__LTS_V178_STATE.cash.data.cash===0);
  assert.equal(semantic(await kpi('Total disponível hoje').locator('strong').innerText()),money(1200),'zero cash is valid');
  flags.incomplete=true;await frame.evaluate(()=>window.__LTS_V178_REVIEW.refresh());await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='ready'&&window.__LTS_V178_STATE.cash.data.cash===null);
  assert.equal(semantic(await kpi('Total disponível hoje').locator('strong').innerText()),'—','null cash blocks total');
  flags.incomplete=false;flags.cash=-1000;await frame.evaluate(()=>window.__LTS_V178_REVIEW.refresh());await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='ready'&&window.__LTS_V178_STATE.cash.data.cash===-1000);
  await frame.locator('.v178-open.amount[data-group="Rafiki"]').first().click();
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail?.rows.length===1207&&!window.__LTS_V178_STATE.detail.loading);
  assert.equal(await frame.locator('#v178Drawer tbody tr').count(),1207);
  const scroll=frame.locator('.v178-detail-scroll');await scroll.evaluate(e=>e.scrollTop=e.scrollHeight);await page.waitForTimeout(100);
  const geometry=await scroll.evaluate(e=>({top:e.scrollTop,height:e.clientHeight,scroll:e.scrollHeight,bottom:e.getBoundingClientRect().bottom,last:e.querySelector('tbody tr:last-child').getBoundingClientRect().bottom}));
  assert(geometry.top>0&&geometry.height>0&&geometry.last<=geometry.bottom+2,'last detail row visible '+JSON.stringify(geometry));
  const before=geometry.top;await frame.evaluate(()=>render());assert.equal(await scroll.evaluate(e=>e.scrollTop),before,'background render must preserve scroll');
  await page.screenshot({path:'qa/v229-'+label+'-last-row.png'});
  await frame.locator('.v178-filter input').fill('1207');assert.equal(await frame.locator('#v178Drawer tbody tr').count(),1,'search full list including last row');
  await frame.locator('.v178-close').click();
  const group=groups[0][0];await frame.locator('.v178-open.amount[data-group="'+group+'"]').first().click();await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail?.rows.length===804&&!window.__LTS_V178_STATE.detail.loading);
  assert(await frame.locator('.v178-detail-scroll').isHidden(),'apartment starts by components, not mixed list');
  await frame.locator('[data-component="Custos de moradia"]').click();await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail?.subgroup==='Custos de moradia'&&!window.__LTS_V178_STATE.detail.loading);
  assert.equal(await frame.locator('#v178Drawer tbody tr').count(),201);assert(await scroll.isVisible());await frame.locator('.v178-close').click();
  await frame.evaluate(()=>{window.__LTS_V178_REVIEW.openDetail('Rafiki',null,{from:'2020-01-01',to:'2026-09-20'},1207);setTimeout(()=>window.__LTS_V178_REVIEW.openDetail('Benjamin — Educação',null,{from:'2020-01-01',to:'2026-09-20'},250),5)});
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail?.group==='Benjamin — Educação'&&!window.__LTS_V178_STATE.detail.loading);await page.waitForTimeout(150);assert.equal(await frame.locator('#v178Drawer tbody tr').count(),5,'late previous response discarded');await frame.locator('.v178-close').click();
  flags.pageFailure=true;await frame.evaluate(()=>window.__LTS_V178_REVIEW.openDetail('Rafiki',null,{from:'2021-01-01',to:'2026-09-20'},1207));await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail?.error);
  assert.equal(await frame.locator('#v178Drawer tbody tr').count(),500,'partial data remains visible');assert(await frame.locator('.v178-retry').isVisible());await frame.locator('.v178-retry').click();await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail?.rows.length===1207&&!window.__LTS_V178_STATE.detail.loading);assert.equal(await frame.locator('#v178Drawer tbody tr').count(),1207);await frame.locator('.v178-close').click();
  await nav('Despesas').click();
  await frame.waitForFunction(()=>window.__LTS_V168_STATE.expense.data?.summary&&!window.__LTS_V168_STATE.expense.loading);
  assert.equal(semantic(await kpi('Último mês disponível').locator('strong').innerText()),money(sum(groups.map(g=>g[1]*g[2]))),'final selected month in YYYY-MM-DD format remains visible');
  assert((await frame.locator('.v168-expenses').innerText()).includes('set de 26'),'final month appears in the expense overview');
  await frame.locator('[data-v168-exp-range="6m"]').click();await frame.locator('.v168-tabs [data-v168-exp-tab="categories"]').click();await frame.waitForSelector('.v181-category-panel');
  await frame.locator('[data-v181-detail-group="Benjamin — Saúde"]').click();await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail&&!window.__LTS_V178_STATE.detail.loading);assert.equal(await frame.evaluate(()=>window.__LTS_V178_STATE.detail.range.from),'2026-04-01');assert.equal(await frame.locator('#v178Drawer tbody tr').count(),3);await frame.locator('.v178-close').click();
  await frame.locator('[data-v168-exp-range="all"]').click();await frame.locator('.v168-tabs [data-v168-exp-tab="monthly"]').click();await frame.waitForFunction(()=>window.__LTS_V175_STATE.monthly.data?.months?.length===156&&!window.__LTS_V175_STATE.monthly.loading);
  assert((await frame.locator('.v175-monthly').innerText()).includes('Benjamin — Educação'));
  const monthlyDims=await frame.locator('html').evaluate(e=>({width:e.clientWidth,scroll:e.scrollWidth}));assert(monthlyDims.scroll<=monthlyDims.width+3,'monthly tables do not expand the page '+JSON.stringify(monthlyDims));
  await frame.locator('.v168-tabs [data-v168-exp-tab="cards"]').click();
  await frame.waitForSelector('[data-v175-card-retry]');
  await frame.waitForSelector('.v226-upcoming [data-v226-overview="next"]');
  assert(await frame.locator('.v226-history').isVisible(),'source composition remains available when the legacy Flow comparison fails');
  const failedCardCalls=calls.filter(x=>x.name==='lts_browser_card_flow_schedule_v2').length;
  await frame.evaluate(()=>render());await page.waitForTimeout(250);assert.equal(calls.filter(x=>x.name==='lts_browser_card_flow_schedule_v2').length,failedCardCalls,'card failure remains visible without an automatic retry loop');
  flags.cardFail=false;await frame.locator('[data-v175-card-retry]').click();
  await frame.waitForFunction(()=>window.__LTS_V183_CARD_PERIOD.status==='ready'&&window.__LTS_V175_STATE.cards.data?.inventory?.cards?.length===5);
  const inventory=await frame.locator('.v183-card-families').innerText();for(const name of cardNames)assert(inventory.includes(name),'historical card retained: '+name);
  assert(!inventory.includes('Visa Eternum'),'AETERNUM spelling preserved');
  await frame.waitForFunction(()=>document.querySelector('[data-v183-payment-status]')?.innerText.includes('Pagamento documentado'));
  await page.screenshot({path:'qa/v229-'+label+'-cards.png'});
  await nav('Atualizações').click();await frame.waitForSelector('[data-v181-review-key="pending-fixture"]');
  await frame.locator('[data-v181-review-key="pending-fixture"] [data-v181-category]').selectOption('Mercado');
  await frame.locator('[data-v181-review-key="pending-fixture"] [data-v181-review-save]').click();
  await frame.waitForFunction(()=>window.__LTS_V181_STATE.review.data?.row_count===0);
  assert.equal(await frame.locator('[data-v181-review-key="pending-fixture"]').count(),0,'confirmed item is removed after persistence');
  await nav('Patrimônio').click();await frame.waitForSelector('.v172-wealth-overview');
  const currentMorgan=frame.locator('.v172-value-list>div').filter({hasText:'Morgan Stanley · disponível'});assert.equal(semantic(await currentMorgan.locator('b').innerText()),money(1100),'wealth uses the current validated position');
  await frame.locator('[data-v168-wealth-tab="rsu"]').click();
  assert.equal(semantic(await kpi('Disponível agora').locator('strong').innerText()),money(1100));
  assert.equal(semantic(await kpi('Total bruto do extrato').locator('strong').innerText()),money(51000),'documentary gross remains unchanged');
  assert.equal(semantic(await kpi('Total líquido projetado').locator('strong').innerText()),money(48100),'current position plus future net');
  assert.equal(semantic(await frame.locator('.v172-morgan-components article').first().locator('dd').first().innerText()),money(1000),'vested shares use the validated component');
  await page.screenshot({path:'qa/v229-'+label+'-wealth.png'});
  await frame.locator('[data-v168-wealth-tab="assets"]').click();const asset=frame.locator('.v168-asset').filter({has:frame.getByRole('heading',{name:'RSUs e corretora',exact:true})});
  assert.equal(semantic(await asset.locator('strong').innerText()),money(1100));
  assert.equal(semantic(await asset.locator('.v168-fact').filter({hasText:'Disponível agora'}).locator('b').innerText()),money(1100));
  assert.equal(semantic(await asset.locator('.v168-fact').filter({hasText:'Futuro líquido projetado'}).locator('b').innerText()),money(47000));
  await nav('Dashboard').click();await frame.locator('.v178-open.amount[data-group="Larissa — despesas"]').first().click();await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail&&!window.__LTS_V178_STATE.detail.loading);assert.equal(await frame.evaluate(()=>window.__LTS_V178_STATE.detail.range.from),'2026-01-01','Dashboard detail uses own YTD, not all-history expense filter');await frame.locator('.v178-close').click();
  const flowTimings={};let started=Date.now();
  await nav('Fluxo Diário').click();await frame.waitForFunction(()=>!FLOWLOADING&&document.querySelector('.fx87-row[id^="d-"]'));
  flowTimings.initial_ms=Date.now()-started;
  started=Date.now();await frame.locator('#flowFrom').fill('2026-09-14');await frame.locator('#flowTo').fill('2027-12-31');await frame.locator('#flowApply').click();await frame.waitForSelector('#d-2027-12-31');
  flowTimings.period_change_ms=Date.now()-started;
  const profiler=await context.newCDPSession(page);
  await profiler.send('Profiler.enable');await profiler.send('Profiler.start');
  started=Date.now();await frame.locator('[data-a="Itaú"]').click();await frame.waitForSelector('.fx87-row.fx87-bank[id^="d-"]');
  flowTimings.bank_change_ms=Date.now()-started;
  const {profile}=await profiler.send('Profiler.stop');await profiler.detach();
  const parents=new Map(),nodes=new Map(profile.nodes.map(n=>[n.id,n]));
  for(const n of profile.nodes)for(const child of n.children||[])parents.set(child,n.id);
  const totals=new Map();
  for(let i=0;i<(profile.samples||[]).length;i++){
   let id=profile.samples[i];const us=profile.timeDeltas?.[i]||0;
   while(id!=null){const n=nodes.get(id),key=n?.callFrame?.functionName||'(anonymous)';
    totals.set(key,(totals.get(key)||0)+us);id=parents.get(id);}
  }
  console.log('FLOW_BANK_PROFILE '+JSON.stringify({label,elapsed_ms:flowTimings.bank_change_ms,
   top:[...totals].sort((a,b)=>b[1]-a[1]).slice(0,24).map(([name,us])=>({name,ms:Math.round(us/1000)}))}));
  await frame.locator('[data-a="Consolidado"]').click();
  const val=async(date,index)=>semantic(await frame.locator('#d-'+date+' .fx87-cell').nth(index).innerText());
  assert.equal(await val('2026-11-05',2),money(0));assert.equal(await val('2026-11-05',7),money(1100));assert.equal(await val('2026-11-07',7),money(1100));assert.equal(await val('2026-11-08',7),money(1600),'first award enters on its availability date');assert.equal(await val('2026-11-10',2),money(0));
  assert.equal(await frame.locator('.v176-rsu-delta').count(),0,'no extra inline vesting row');
  const arithmetic=await frame.locator('.fx87-row.fx87-cons[id^="d-"]').evaluateAll(rows=>rows.map(row=>{
   const n=i=>Number(row.children[i].textContent.replace(/[^0-9,-]/g,'').replace(',','.'));
   return {date:row.id,cash:Math.abs(n(1)+n(2)-n(3)-n(4)),d0:Math.abs(n(4)+n(5)-n(6)),rsu:Math.abs(n(6)+n(7)-n(8)),total:Math.abs(n(8)+n(9)-n(10))};
  }));
  assert(arithmetic.length>300,'complete date range is audited');
  assert(arithmetic.every(x=>[x.cash,x.d0,x.rsu,x.total].every(v=>Number.isFinite(v)&&v<0.005)),JSON.stringify(arithmetic.filter(x=>Math.max(x.cash,x.d0,x.rsu,x.total)>=0.005).slice(0,5)));
  assert.equal(await val('2026-11-10',7),money(2300),'second availability propagates');
  assert.equal(await val('2026-11-11',7),money(2300),'following day carries the same position');

  const h=await frame.locator('#d-2026-11-05').evaluate(e=>e.getBoundingClientRect().height),h2=await frame.locator('#d-2026-11-06').evaluate(e=>e.getBoundingClientRect().height);assert(Math.abs(h-h2)<1,'RSU does not change row height');
  await frame.locator('#d-2026-11-05 .exp').click();assert.equal(await frame.locator('.v178-award-detail').count(),1);assert((await frame.locator('.v178-award-detail').innerText()).includes('08/11/2026'));
  await frame.locator('#flowZero').click();await page.waitForTimeout(50);assert.equal(await frame.locator('#d-2026-11-07').count(),0);assert.equal(await frame.locator('#d-2026-11-08').count(),0);assert.equal(await frame.locator('#d-2026-11-09').count(),1,'real in and out with zero net must remain');assert.equal(await frame.locator('#d-2026-11-05').count(),1);
  await page.screenshot({path:'qa/v229-'+label+'-flow.png'});
  await frame.locator('.floweditbtn[data-mode="edit"]').first().click();
  await frame.locator('#flowEditDesc').fill('Despesa manual sintética ajustada');
  await frame.locator('#flowEditAmount').fill('101');
  await frame.locator('#flowEditSave').click();
  await frame.waitForFunction(()=>!FLOWEDIT&&FLOWQ.current_future.events.some(e=>e.source_ref==='cash-1'&&e.description==='Despesa manual sintética ajustada'));
  await frame.locator('.floweditbtn[data-mode="edit"]').first().click();
  assert.equal(await frame.locator('#flowEditDesc').inputValue(),'Despesa manual sintética ajustada');
  assert.equal(await frame.locator('#flowEditAmount').inputValue(),'101');
  await frame.locator('#flowEditClose').click();
  const edit=calls.find(x=>/^lts_browser_flow_mutate_v/.test(x.name)&&x.args.p_action==='edit');assert.equal(edit.args.p_payload.amount,101);assert.equal(edit.args.p_source_ref,'cash-1');
  page.once('dialog',dialog=>dialog.accept());await frame.locator('.flowdeletebtn').first().click();
  await frame.waitForFunction(()=>!FLOWQ.current_future.events.some(e=>e.source_ref==='cash-1'));
  assert.equal(await frame.locator('.flowdeletebtn').count(),0,'deleted entry disappears from visible day details');
  assert(calls.some(x=>/^lts_browser_flow_mutate_v/.test(x.name)&&x.args.p_action==='cancel'),'manual deletion reaches existing audited writer');
  await nav('Dashboard').click();started=Date.now();await nav('Fluxo Diário').click();await frame.waitForFunction(()=>!FLOWLOADING&&document.querySelector('.fx87-row[id^="d-"]'));flowTimings.return_ms=Date.now()-started;
  assert(Object.values(flowTimings).every(ms=>ms<4000),'controlled browser rendering must complete promptly '+JSON.stringify(flowTimings));
  await nav('Dashboard').click();flags.date='2026-09-21';await frame.evaluate(()=>{window.__TEST_NOW__='2026-09-21T13:00:00Z';render()});assert.equal(semantic(await kpi('Total disponível hoje').locator('strong').innerText()),'—','day rollover does not present stale complete total');await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.data?.as_of==='2026-09-21'&&window.__LTS_V178_STATE.cash.status==='ready');
  await frame.waitForFunction(()=>window.__LTS_V226?.cycles?.cards.length===5);
  assert.equal(await frame.locator('.v182-expand-mark').count(),0,'redundant plus removed');
  if(viewport.width<=520)assert.equal(await nav('Patrimônio').innerText(),'Patrimônio','mobile label restored');
  assert.equal(await frame.locator('.v226-banks section').count(),3,'bank grouping');
  assert.equal(await frame.locator('.v226-card-line').count(),5,'five billing accounts, not additional-card duplicates');
  assert.match(await frame.locator('.v226-totals').first().innerText(),/2\.100,00/,'next invoice sum');
  await frame.locator('[data-v226-overview="next"]').click();
  assert.equal(await frame.locator('#v226-detail [data-v226-overview-row]').count(),3,'summary total opens every component');
  assert.match(await frame.locator('#v226-detail tfoot').innerText(),/2\.100,00/);
  await frame.locator('#v226-detail [data-v226-close]').click();
  assert.match(await frame.locator('.v226-card-line').filter({hasText:'Visa Infinite Prime'}).innerText(),/Sem fatura aberta informada/,'unreported is not zero debt');
  await frame.locator('[data-v226-family="aeternum"][data-v226-month="2026-10-01"]').first().click();
  await frame.waitForSelector('#v226-detail [data-v226-item]');
  assert.equal(await frame.locator('#v226-detail [data-v226-item]').count(),2);
  await frame.locator('#v226-detail .v226-classify summary').click();
  await frame.locator('#v226-detail select[name="category"]').selectOption('Saúde');
  await frame.locator('#v226-detail select[name="beneficiary"]').selectOption('Lucas');
  await frame.locator('#v226-detail button[type="submit"]').click();
  await frame.waitForFunction(()=>!document.querySelector('#v226-detail [data-v226-classify]'));
  assert(calls.some(c=>c.name==='lts_browser_card_classify_v226'),'classification persisted through audited writer');
  await frame.locator('#v226-detail [data-v226-close]').click();
  await frame.waitForFunction(()=>window.__LTS_V226.cycles?.cards.length===5);
  await frame.locator('.v226-future summary').click();
  await frame.locator('[data-v226-family="aeternum"][data-v226-month="2026-11-01"]').first().click();
  await frame.waitForSelector('#v226-detail [data-v226-item]');
  assert.match(await frame.locator('#v226-detail').innerText(),/2\/3/,'future installment opens individual composition');
  await frame.locator('#v226-detail [data-v226-close]').click();
  await nav('Despesas').click();await frame.locator('.v168-tabs [data-v168-exp-tab="cards"]').click();
  await frame.waitForSelector('.v226-history [data-v226-family]');
  await frame.locator('.v226-history [data-v226-family="itau_mastercard"]').first().click();
  await frame.waitForFunction(()=>document.querySelectorAll('#v226-detail [data-v226-item]').length===80);
  assert.match(await frame.locator('#v226-detail').innerText(),/780,00/,'historical detail includes credit without truncation');
  await frame.locator('#v226-detail [data-v226-search]').fill('sintética 80');
  assert.equal(await frame.locator('#v226-detail [data-v226-item]:visible').count(),1,'search reaches last purchase');
  await page.screenshot({path:'qa/v226-'+label+'-invoice-detail.png'});
  await frame.locator('#v226-detail [data-v226-close]').click();
  await frame.locator('[data-v168-exp-range="all"]').click();
  await frame.waitForSelector('.v226-history [data-v226-month="2024-01-01"]');
  await frame.locator('.v226-history [data-v226-month="2024-01-01"]').first().click();
  await frame.waitForSelector('#v226-detail [data-v226-item]');
  assert.equal(await frame.locator('#v226-detail [data-v226-item]').count(),3,'all reconciled workbook rows available');
  assert.match(await frame.locator('#v226-detail').innerText(),/estabelecimento e dia da compra não informados/);
  assert.match(await frame.locator('#v226-detail [data-v226-item] td').first().innerText(),/jan.*2024/,'month is not presented as an invented purchase day');
  await frame.locator('#v226-detail .v226-alternative summary').click();
  assert.equal(await frame.locator('#v226-detail [data-v226-alternative-item]').count(),1,'bank merchant details remain available alongside monthly evidence');
  assert.match(await frame.locator('#v226-detail .v226-alternative').innerText(),/não somar novamente/);
  assert.match(await frame.locator('#v226-detail .v226-totals').innerText(),/30,00/,'alternative source is not added to the invoice total');
  await frame.locator('#v226-detail [data-v226-close]').click();
  await nav('Patrimônio').click();await frame.getByRole('tab',{name:'Visão geral',exact:true}).click();assert.equal(await frame.locator('.v226-upcoming').count(),0,'overview is not displaced by cards');await frame.getByRole('tab',{name:'RSUs e awards',exact:true}).click();assert.equal(await frame.locator('.v226-upcoming').count(),0,'RSUs are not displaced by cards');await frame.getByRole('tab',{name:'Bens e dívidas',exact:true}).click();await frame.waitForSelector('.v226-upcoming');
  assert.match(await frame.locator('.v226-totals').innerText(),/2\.100,00/,'same totals in Wealth');
  await nav('Dashboard').click();
  flags.cyclesFail=true;await frame.locator('[data-v226-retry]').click();
  await frame.waitForFunction(()=>Boolean(window.__LTS_V226.error));
  const failedCount=calls.filter(c=>c.name==='lts_browser_card_cycles_v229').length;
  await frame.evaluate(()=>render());await page.waitForTimeout(150);
  assert.equal(calls.filter(c=>c.name==='lts_browser_card_cycles_v229').length,failedCount,'no retry loop on card outage');
  flags.cyclesFail=false;await frame.locator('[data-v226-retry]').click();
  await frame.waitForFunction(()=>window.__LTS_V226.cycles?.cards.length===5);
  const dims=await frame.locator('html').evaluate(e=>({width:e.clientWidth,scroll:e.scrollWidth}));assert(dims.scroll<=dims.width+3,'no horizontal page overflow');
  const order=await frame.locator('.v168-dashboard').evaluate(root=>{const rect=s=>root.querySelector(s).getBoundingClientRect().top;return [rect('.current'),rect('.v227-liquidity'),rect('.v227-expenses')]});assert(order[0]<order[1]&&order[1]<order[2],'balances, liquidity, expenses order');assert.equal(await frame.locator('.v227-expenses .v226-upcoming').count(),1);assert.equal(await frame.locator('.v227-expenses .v171-expense-total').count(),1);
  assert.deepEqual(errors,[],'no uncaught errors');await page.screenshot({path:'qa/v229-'+label+'-dashboard.png'});
  return{label,pass:true,expense_last_month:true,card_inventory:true,payment_status:true,manual_edit_delete:true,scroll:geometry,flow_render_timings:flowTimings,calls:calls.length,financial_data:'synthetic fixtures; live SQL checks separate'};
 }catch(error){console.error('ORIGINAL FAILURE',String(error.stack||error));await page.screenshot({path:'qa/v229-'+label+'-failure.png'}).catch(e=>console.error('SCREENSHOT FAILED',e.message));console.error(JSON.stringify({label,error:String(error.stack||error),errors,calls:calls.slice(-15),state:await frame?.evaluate(()=>({cash:window.__LTS_V178_STATE?.cash,monthly:{error:window.__LTS_V175_STATE?.monthly?.error,count:window.__LTS_V175_STATE?.monthly?.data?.months?.length},detail:window.__LTS_V178_STATE?.detail?{group:window.__LTS_V178_STATE.detail.group,error:window.__LTS_V178_STATE.detail.error,rows:window.__LTS_V178_STATE.detail.rows.length}:null})).catch(()=>null)}));throw error}
 finally{await context.close()}
}
(async()=>{
 const hash=crypto.createHash('sha256').update(fs.readFileSync('index.html')).digest('hex');assert.equal(hash,'cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b');
 const browser=await chromium.launch({headless:true,...(process.env.LTS_CHROMIUM_PATH?{executablePath:process.env.LTS_CHROMIUM_PATH}:{} )});
 try{const results=[await run(browser,{width:1440,height:1000},'desktop'),await run(browser,{width:390,height:844},'mobile')];const out={pass:true,version:'v226',results};fs.writeFileSync('qa/v229-functional-result.json',JSON.stringify(out,null,2));console.log(JSON.stringify(out,null,2))}
 catch(e){fs.writeFileSync('qa/v229-functional-result.json',JSON.stringify({pass:false,error:String(e.stack||e)},null,2));process.exitCode=1}
 finally{await browser.close()}
})();
