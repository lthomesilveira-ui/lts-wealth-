'use strict';
const {chromium}=require('playwright');
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {product:baseProduct,cockpit,wealth:baseWealth}=require('./lts_v165_executive_ux_gate.js');
const BASE='http://127.0.0.1:'+(process.env.LTS_V178_PORT||8788);
const session={access_token:'controlled-fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};
const currentSource=['v236','v240','v241','v242','v244','v245','v257','v258','v259','v260','v261','v262','v264','v269','v270','v271','v276','v277'].includes(process.env.LTS_RELEASE);
const planningReader=['v240','v241','v242','v244','v245','v257','v258','v259','v260','v261','v262','v264','v269','v270','v271','v276','v277'].includes(process.env.LTS_RELEASE)?'lts_browser_planning_ui_contract_'+(['v244','v245','v257','v258','v259','v260','v261','v262','v264','v269','v270','v271','v276','v277'].includes(process.env.LTS_RELEASE)?'v242':process.env.LTS_RELEASE):'lts_browser_planning_ui_contract_v1';
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
 const events=[{source:'future_award_vesting_marker',event_date:'2026-11-05',account:'Corretora',category:'RSU',description:'Vesting',signed_amount:0},{source:'future_rsu_available',event_date:'2026-11-08',account:'Corretora',category:'RSU',description:'RSU disponível',signed_amount:500},{source:'future_rsu_available',event_date:'2026-11-10',account:'Corretora',category:'RSU',description:'RSU disponível',signed_amount:700},{source:'legacy_fix86',source_ref:'cash-1',event_date:'2026-11-05',account:'Itaú',category:'Despesas',description:'Saída comprovada',signed_amount:-100},{source:'legacy_fix86',source_ref:'cash-2',event_date:'2026-11-09',account:'Itaú',category:'Receitas',description:'Entrada comprovada',signed_amount:300},{source:'card_invoice',source_ref:'Mastercard Black|2026-10',event_date:'2026-11-09',account:'Itaú',category:'A classificar',description:'Fatura sintética',signed_amount:-300}].filter(e=>e.event_date>=from&&e.event_date<=to);
 for(const d of ds){d.Itaú.net=12;d.summary.events=12;d.summary.Consolidado={entries:18,exits:6};d.Consolidado.economic_net=12;d.fix86_columns.entradas=18;d.fix86_columns.saidas=6;
 for(let i=0;i<12;i++)events.push({source:'current_event',source_ref:'fixture-'+d.date+'-'+i,event_date:d.date,account:['Itaú','Bradesco','C6'][i%3],description:'Synthetic event '+i,category:'Mercado',signed_amount:i%2?3:-1,status:'scheduled',is_projection:true});}
 return{ok:true,flow:{from,to,available_year_from:2013,available_year_to:2041,historical_balance_truth_contract:{consolidated_first_complete_opening:'2026-09-01',itau_first_documentary_opening:'2026-09-01',bradesco_first_documentary_opening:'2026-09-01',c6_first_documentary_opening:'2026-09-01'},historical:{days:[],events:[]},current_future:{from,to,days:ds,events}}}
}
function awards(){return{version:'awards-v178',as_of:'2026-09-17',vested_shares:1000,brokerage_cash:100,brokerage_available:1100,events:[{id:'award1',type:'RSU',regular_rsu:true,vesting_date:'2026-11-05',available_date:'2026-11-08',value:500},{id:'award2',type:'RSU',regular_rsu:true,vesting_date:'2026-11-07',available_date:'2026-11-10',value:700}]}}

// All values, source IDs and card numbers below are synthetic.
function fixtureHistory(){return Array.from({length:80},(_,i)=>({source_id:'history-'+i,description:'Compra sintética '+(i+1),amount:i===79?-10:10,last4:i%2?'1111':'2222',purchase_date:'2026-06-15',category:'Mercado',category_basis:'historical_workbook'}))}
function fixtureCycles(classified=false, stale=false){
 const sample=(id,amount,cat='Rafiki — Vestuário')=>({source_id:id,description:'Compra sintética '+id,amount,last4:'1111',purchase_date:'2026-09-18',installment_number:1,total_installments:3,category:cat,category_basis:cat==='A classificar'?'unresolved':'user_decision'});
 const entries=[['Bradesco','aeternum',1200,'1111'],['Bradesco','bradesco_prime',null,'2222'],['Itaú','itau_mastercard',800,'3333'],['Itaú','itau_visa',null,'4444'],['C6','c6',100,'5555']];
 return {version:'card-cycles-v226',active_billing_accounts:5,as_of:'2026-09-20',cards:entries.map(([bank,family,amount,last4])=>({bank,family,name:family,last4,status:'ACTIVE',cycles:amount==null?[]:[{month:'2026-10-01',due_date:'2026-10-12',amount,basis:'open_finance_composition',payment_status:'payment_not_reported',...(family==='itau_mastercard'?{documentary_payment_evidence:stale?{status:'source_changed',cash_effect:'none'}:{status:'identified_in_statement',cash_effect:'none',currency:'BRL',amount:800,payment_date:'2026-09-19'}}:{}),items:[sample('a-'+family,amount/2),sample('b-'+family,amount/2,!classified&&family==='aeternum'?'A classificar':'Saúde')]},{month:'2026-11-01',due_date:null,amount:100,basis:'derived_current_installments',items:[{...sample('future-'+family,100),installment_number:2}]}]}))};
}

async function run(browser,viewport,label){
 label=label+'-'+(process.env.PROFILE_MODE||'baseline');
 const context=await browser.newContext({viewport});
 await context.addInitScript(()=>{const Native=Date;window.__TEST_NOW__='2026-09-20T13:00:00Z';class TestDate extends Native{constructor(...args){super(...(args.length?args:[Native.parse(window.__TEST_NOW__)]))}static now(){return Native.parse(window.__TEST_NOW__)}}window.Date=TestDate});
 await context.addInitScript(s=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s)),session);
 await context.addInitScript(()=>{
 const OriginalMO=MutationObserver,raf=requestAnimationFrame.bind(window);let serial=0;
 const stats=window.__FLOW_PROFILE={observers:[],rafScheduled:0,rafExecuted:0,renderCount:0};
 window.MutationObserver=class extends OriginalMO{constructor(cb){const item={id:++serial,callback:String(cb).slice(0,240),count:0,records:0,ms:0};stats.observers.push(item);super((records,self)=>{const start=performance.now();item.count++;item.records+=records.length;try{return cb(records,self)}finally{item.ms+=performance.now()-start}})}};
 window.requestAnimationFrame=cb=>{stats.rafScheduled++;return raf(t=>{stats.rafExecuted++;return cb(t)})};
 });
 const page=await context.newPage();page.setDefaultTimeout(20000);const errors=[],calls=[];
 const captureTarget=async(locator,name)=>{await locator.scrollIntoViewIfNeeded();const box=await locator.boundingBox();assert(box&&box.x>=-1&&box.y>=-1&&box.x+box.width<=viewport.width+1&&box.y+box.height<=viewport.height+1,'target inside viewport '+JSON.stringify({name,box,viewport}));await page.screenshot({path:'qa/v277-'+label+'-'+name+'.png'});};
 const cardNames=['Bradesco Visa','VISA AETERNUM','Itaú Mastercard Black','Itaú Visa','C6'];
 const flags={reviewDone:false,manualDescription:null,manualDeleted:false,cashFail:false,forecastFail:false,cardFail:false,date:'2026-09-20',cash:-1000,incomplete:false,pageFailure:false,cyclesFail:false,cardClassified:false,paymentStale:false,expenseFail:false,contextHang:false,expenseDelayFrom:null,balanceScenario:false,overdueMode:1,bankPositions:true,accountAsOf:'2026-09-19T18:00:00Z',statusReceipt:'2026-09-20T12:15:00Z',statusOrigin:'2026-09-19T18:00:00Z',allOrigins:false,refreshOk:false,requestedAt:'2026-09-20T12:30:00Z'};
 page.on('pageerror',e=>errors.push(String(e.stack||e)));
 if(process.env.PROFILE_MODE==='candidate')for(const name of ['lts-v183-v168-feedback-safe.js','lts-v170-v169-review.js'])await page.route('**/releases/v277/'+name+'*',route=>route.fulfill({contentType:'application/javascript',body:fs.readFileSync('.github/fixtures/flow-observer-candidate/'+name,'utf8')}));
 await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
  const req=route.request(),name=new URL(req.url()).pathname.split('/').pop();let a={};try{a=JSON.parse(req.postData()||'{}')}catch{}calls.push({name,args:a});let data={ok:true,items:[],rows:[]},status=200;
  if(name==='token')data=session;
  else if(name==='lts_browser_product_v1')data={ok:true,mvp:baseProduct()};
  else if(name==='lts_browser_dashboard_cockpit_v1')data=cockpit;
  else if(name===planningReader)data={version:'planning-ui-contract-v2',period_to:'2027-12-31',fgts_covers_horizon:true,fgts_first_negative:null,labels:{d01:'Cobertura de teste',rsu:'Cobertura de teste',fgts:'Com FGTS, sem ruptura até 31/12/2027'}};
  else if(name==='lts_browser_card_cycles_v229'){
   if(flags.cyclesFail){status=503;data={message:'fixture card unavailable'}}else data=fixtureCycles(flags.cardClassified,flags.paymentStale);
  }
  else if(name==='lts_browser_card_history_v226')data={version:'card-history-v226',invoices:[{bank:'Itaú',family:'itau_mastercard',card_name:'Mastercard Black',reference_month:'2026-07-01',due_date:'2026-07-12',amount:780,detail_total:780,difference:0,item_count:80,detail_complete:true},...(a.p_from<='2024-01-01'&&a.p_to>='2024-01-31'?[{bank:'Itaú',family:'itau_mastercard',reference_month:'2024-01-01',due_date:null,amount:30,detail_total:30,difference:0,item_count:3,detail_complete:true,source:'workbook_reconciled'}]:[])]};
  else if(name==='lts_browser_card_detail_v226')data=a.p_month==='2024-01-01'?{invoice_amount:30,alternative_note:'Outra fonte da mesma fatura; não somar novamente.',alternative_items:[{description:'Compra bancária complementar',purchase_date:'2023-12-20',amount:20,last4:'1111',category:'Mercado'}],source_note:'Composição reconciliada da planilha; estabelecimento e dia da compra não informados.',items:Array.from({length:3},(_,i)=>({description:'Linha '+(i+1)+' da planilha · estabelecimento não informado',amount:10,last4:'1111',category:'Mercado',category_basis:'historical_workbook',date_kind:'reference_month',reference_month:'2024-01-01'}))}:{invoice_amount:780,items:fixtureHistory()};
  if(name==='lts_browser_card_detail_v226'&&a.p_month==='2024-01-01'&&currentSource){data.detail_total=30;data.formula_resolution={source_note:'Composição conciliada pela fórmula original.',raw_item_count:4,raw_detail_total:40,excluded_items:[{source_sheet:'Cartão',source_row:4,category:'Categoria não incluída',amount:10}],formula_evidence:[{file:'Composição_teste.xlsx',total_cell:'Z4',total_formula:'=SUM(Z7,Z18)',category_formula:'=SUMIFS(D:D,B:B,G12)'}]};}
  if(name==='lts_browser_card_category_options_v226')data={categories:['Mercado','Saúde','Presentes','Lucas — Vestuário']};
  else if(name==='lts_browser_card_classify_v226'){assert.equal(a.p_category,'Saúde');assert.equal(a.p_beneficiary,'Lucas');flags.cardClassified=true;data={ok:true};}
  else if(name==='lts_browser_open_finance_status_v1')data={connections:['341','237','336'].map((code,i)=>({id:'synthetic-connection-'+i,provider:'synthetic-provider',institution_code:code,status:'connected',last_success_at:flags.statusReceipt,...(i!==1||flags.allOrigins?{provider_item_updated_at:flags.statusOrigin}:{}),...(i===2?{last_error_code:'fixture_error',last_attempt_at:'2026-09-20T12:30:00Z'}:{})}))};
  else if(name==='lts_browser_open_finance_pending_v225')data={version:'pending-expense-v225',transaction_count:0,net_expense:0,rows:[]};
  else if(name==='lts_browser_open_finance_refresh_v1'){if(flags.refreshOk)data={ok:true,requested_at:flags.requestedAt};else{status=503;data={message:'deliberate sync failure'};}}
  else if((name==='lts_browser_cash_today_v178'||name==='lts_browser_cash_today_v242')){
   if(flags.cashFail){data={message:'deliberate cash failure'};status=503}else data={version:'cash-today-v179-current-canonical',status:'complete',as_of:flags.date,cash:flags.incomplete?null:flags.cash,d0:100,brokerage_available:1100,fgts:5000,available_total:flags.incomplete?1200:flags.cash+1200,day:dayRow(flags.date,0,0,flags.cash)};if(flags.balanceScenario&&data.day){data.day.Itaú.balance=700.30;data.day.C6.balance=500;}if(flags.bankPositions&&data.day)data.bank_positions=[['341','Itaú'],['237','Bradesco'],['336','C6']].map(([institution_code,institution],i)=>({institution_code,institution,balance:data.day[institution].balance,as_of:flags.accountAsOf,source_id:'synthetic-position-'+i}));
  }
  else if(name==='lts_browser_expenses_v229'||/^lts_browser_expense_executive_v/.test(name)){
   if(a.p_to>flags.date){status=400;data={message:'invalid expense range'}}
   else if(flags.expenseFail&&a.p_from==='2026-09-02'){status=503;data={message:'temporary expense fixture'}}
   else {if(a.p_from===flags.expenseDelayFrom)await new Promise(resolve=>setTimeout(resolve,700));data=report(a.p_from,a.p_to)}
  }
  else if(name==='lts_browser_expense_detail_v229'){
   if(flags.pageFailure&&a.p_offset===500){data={message:'deliberate page failure'};status=503;flags.pageFailure=false}else{await new Promise(r=>setTimeout(r,a.p_group==='Rafiki'?80:5));data=details(a)}
  }
  else if(name==='lts_browser_card_flow_schedule_v2'){if(flags.cardFail){status=503;data={message:'deliberate card failure'}}else data={inventory:{cards:cardNames.map((card_name,i)=>({bank:i<2?'Bradesco':i<4?'Itaú':'C6',card_name,first_seen:'2020-01-01',last_seen:'2026-09-20'}))},months:[],summary:{}};}
  else if(name==='lts_browser_invoice_documentary_only_v1'||name==='lts_browser_legacy_invoice_gap_v183')data={financial_effect:'none',invoices:[]};
  else if(name==='lts_browser_invoice_flow_reconciliation_v183')data={rows:a.p_from<='2026-09-15'&&a.p_to>='2026-09-15'?[{card_name:'VISA AETERNUM',reference_month:'2026-09-01',due_date:'2026-09-15',documented_amount:100,flow_amount:100,difference:0,reconciliation_status:'reconciled'}]:[]};
  else if(name==='lts_browser_card_settlement_detail_v3')data={matched:true,due_date:'2026-09-15',invoice_total:100,payment_documented:true,cash_effect_date:'2026-09-15'};
  else if(name==='lts_browser_flow_event_editor_v1')data={editable:true,event_date:a.p_event_date,source:a.p_source,source_ref:a.p_source_ref,description:flags.manualDescription||'Despesa manual sintética',amount:flags.manualDescription?101:100,account:'Itaú'};
  else if(/^lts_browser_flow_mutate_v/.test(name)){if(a.p_action==='edit')flags.manualDescription=a.p_payload.description;if(a.p_action==='cancel')flags.manualDeleted=true;data={ok:true};}
  else if(name==='lts_browser_expense_review_queue_v229'){assert.equal(a.p_from,'2013-10-10','Updates queue is independent of the expense filter');data={row_count:flags.reviewDone?2:3,matched_count:flags.reviewDone?2:3,offset:0,next_offset:null,category_options:['Mercado'],beneficiary_options:[{value:'Lucas',label:'Minha / sem prefixo'}],rows:[...(flags.reviewDone?[]:[{key:'pending-fixture',source_table:'lts_open_finance_staging',source_ref:'pending-fixture',date:'2026-09-19',description:'Pagamento sintético para conferir',amount:57,category:'A classificar',account_source:'Itaú',question_kind:'classification',suggestion:{category:'Mercado',note:'Sugestão baseada no histórico; confirme.'}}]),{key:'uncertain-fixture',source_table:'lts_open_finance_staging',source_ref:'uncertain-fixture',date:'2026-09-18',description:'Compra sem identificação suficiente',amount:23,category:'A classificar',question_kind:'classification',suggestion:{category:null,note:'Confirme a finalidade.'}},{key:'context-fixture',source_table:'evento_base',source_ref:'context-fixture',date:'2026-09-01',description:'Contexto de despesa já categorizada',amount:31,category:'Família',question_kind:'classification'}]};}
  else if(name==='lts_browser_expense_review_decision_v229'){assert.equal(a.p_category_label,'Mercado');flags.reviewDone=true;data={ok:true,resolved:true};}
  else if(name==='lts_browser_property_archive_v178')data={rows:[{key:'component1',description:'Obra documentada',amount:10000,component:'Obra e reforma',date_kind:'historical'},{key:'component2',description:'Consórcio documentado',amount:500,component:'Consórcio',date_kind:'historical'}]};
  else if(name==='lts_browser_awards_v178')data=awards();
  else if(name==='lts_browser_monthly_v229'||/^lts_browser_monthly_balance_v/.test(name))data=monthly(a.p_from,a.p_to);
  else if(/^lts_browser_flow_v/.test(name)){
   if(flags.forecastFail){data={message:'deliberate forecast failure'};status=503}else {data=flow(a.p_from,a.p_to);if(flags.overdueMode){
 data.flow.current_future.current_anchor_date=flags.date;
 data.flow.observed_bank_movements={pending_projections:[{source:'current_event',source_ref:'synthetic-overdue-tax',event_date:'2026-09-19',account:'Itaú',signed_amount:-150.25,status:'scheduled',is_projection:true,description:'Tributo sintético pendente'}]};
 }if(flags.balanceScenario){
 const row=data.flow.current_future.days.find(d=>d.date===flags.date);
 if(row){Object.assign(row,dayRow(flags.date,400,150,1450.30));row.Itaú.balance=950.30;row.C6.balance=500;}
 data.flow.current_future.events.push(...[{source:'current_event',source_ref:'synthetic-reimbursement',event_date:flags.date,account:'Itaú',signed_amount:400,status:'expected',is_projection:true,description:'Reembolso previsto'},{source:'current_event',source_ref:'synthetic-tax',event_date:flags.date,account:'Itaú',signed_amount:-150,status:'scheduled',is_projection:true,description:'IPTU previsto'}].filter(e=>e.event_date>=a.p_from&&e.event_date<=a.p_to));
 }data.flow.current_future.events=data.flow.current_future.events.filter(e=>!flags.manualDeleted||e.source_ref!=='cash-1').map(e=>e.source_ref==='cash-1'&&flags.manualDescription?{...e,description:flags.manualDescription}:e);}
  }
  else if(/^lts_browser_wealth_detail_v/.test(name))data={...baseWealth,pensions:{positions:[],total_gross_brl:0},current_liquidity:{brokerage_available:1100},current_awards:awards(),morgan_statement:{as_of:'2026-09-17',gross_total_brl:51000,available_total_brl:1500,available_components:{vested_shares_brl:1400,brokerage_cash_brl:100},future_components:{regular_rsu_gross_brl:40000,cash_rsu_after_reserve_brl:7000,future_after_reserve_brl:47000},considered_total_after_reserve_brl:48500}};
  else if(name==='lts_browser_recurring_future_gap_audit_v5')data={horizon_checks:[],items:[]};
  else if(/expense_context/.test(name)){if(flags.contextHang&&a.p_from==='2026-09-05')await new Promise(()=>{});data={contexts:[],natures:[],summary:{}};}
  await route.fulfill({status,contentType:'application/json',body:JSON.stringify(data)});
 });
 let frame;const results=[];
 try{
 await page.goto(BASE+'/releases/v277/app.html',{waitUntil:'domcontentloaded'});
 for(let i=0;i<200;i++){frame=page.frames().find(f=>f.url().includes('/index.html'));if(frame&&await frame.evaluate(()=>!!window.__LTS_V225?.installed&&!!window.__LTS_V228_FLOW).catch(()=>false))break;await page.waitForTimeout(100)}
 await frame.waitForFunction(()=>window.__LTS_V178_STATE?.cash.status==='ready'&&window.__LTS_V178_STATE?.forecast.status==='ready');
 await frame.evaluate(()=>{const old=render;render=function(){const s=performance.now();try{return old.apply(this,arguments)}finally{__FLOW_PROFILE.renderCount++;__FLOW_PROFILE.lastRenderMs=performance.now()-s}}});
 await frame.evaluate(()=>{V='Fluxo Diário';ACC='Consolidado';renderNav();render()});
 await frame.waitForFunction(()=>!FLOWLOADING&&FLOWQ?.current_future?.days?.length>0);await page.waitForTimeout(800);
 const snapshot=()=>frame.evaluate(()=>({...JSON.parse(JSON.stringify(__FLOW_PROFILE)),route:V,account:ACC,days:typeof mergedFlowDays==='function'?mergedFlowDays().length:0,events:typeof mergedFlowEvents==='function'?mergedFlowEvents().length:0,domNodes:document.querySelectorAll('*').length,rows:document.querySelectorAll('.fx87-row[id]').length,loading:FLOWLOADING}));
 for(const range of [{name:'five_days',from:'2026-09-16',to:'2026-09-20'},{name:'default_horizon',from:'2026-09-15',to:'2027-12-31'}]){
 await frame.locator('[data-a="Consolidado"]').click();
 await frame.locator('#flowFrom').fill(range.from);await frame.locator('#flowTo').fill(range.to);await frame.locator('#flowApply').click();
 await frame.waitForFunction(r=>!FLOWLOADING&&FLOWFROM===r.from&&FLOWTO===r.to&&FLOWQ?.from===r.from&&FLOWQ?.to===r.to,range); 
 await frame.waitForFunction(()=>!FLOWLOADING);await page.waitForTimeout(1000);
 const before=await snapshot();await page.waitForTimeout(2000);const idle=await snapshot();
 const start=performance.now();await frame.locator('[data-a="Itaú"]').click({timeout:15000});const clickMs=performance.now()-start;
 const after=await snapshot();await page.waitForTimeout(2000);const afterIdle=await snapshot();
 results.push({range,clickMs,before,idle,after,afterIdle});fs.writeFileSync('qa/flow-profile-'+label+'.json',JSON.stringify({results,errors},null,2));
 }
 return {label,results,errors};
 }catch(e){fs.writeFileSync('qa/flow-profile-'+label+'-failure.json',JSON.stringify({error:String(e.stack||e),results,errors,calls:calls.map(c=>c.name)},null,2));throw e}
 finally{await context.close()}
}
(async()=>{fs.mkdirSync('qa',{recursive:true});const browser=await chromium.launch({headless:true});try{const results=[await run(browser,{width:1440,height:1000},'desktop'),await run(browser,{width:390,height:844},'mobile')];fs.writeFileSync('qa/flow-profile-summary-'+(process.env.PROFILE_MODE||'baseline')+'.json',JSON.stringify(results,null,2));console.log(JSON.stringify(results,null,2))}finally{await browser.close()}})().catch(e=>{console.error(e);process.exitCode=1});
