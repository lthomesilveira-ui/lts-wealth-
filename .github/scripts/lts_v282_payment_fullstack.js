'use strict';
const {chromium}=require('playwright');
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {product:baseProduct,cockpit,wealth:baseWealth}=require('./lts_v165_executive_ux_gate.js');
assert.equal(process.env.LTS_RELEASE,'v282','this gate certifies V282 stack only');
const BASE='http://127.0.0.1:'+(process.env.LTS_V178_PORT||8788);
const session={access_token:'controlled-fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};
const currentSource=['v236','v240','v241','v242','v244','v245','v257','v258','v259','v260','v261','v262','v264','v269','v270','v271','v276','v282'].includes(process.env.LTS_RELEASE);
const planningReader=['v240','v241','v242','v244','v245','v257','v258','v259','v260','v261','v262','v264','v269','v270','v271','v276','v282'].includes(process.env.LTS_RELEASE)?'lts_browser_planning_ui_contract_'+(['v244','v245','v257','v258','v259','v260','v261','v262','v264','v269','v270','v271','v276','v282'].includes(process.env.LTS_RELEASE)?'v242':process.env.LTS_RELEASE):'lts_browser_planning_ui_contract_v1';
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
 return{ok:true,flow:{from,to,available_year_from:2013,available_year_to:2041,historical_balance_truth_contract:{consolidated_first_complete_opening:'2026-09-01',itau_first_documentary_opening:'2026-09-01',bradesco_first_documentary_opening:'2026-09-01',c6_first_documentary_opening:'2026-09-01'},historical:{days:[],events:[]},current_future:{from,to,days:ds,events}}}
}
function awards(){return{version:'awards-v178',as_of:'2026-09-17',vested_shares:1000,brokerage_cash:100,brokerage_available:1100,events:[{id:'award1',type:'RSU',regular_rsu:true,vesting_date:'2026-11-05',available_date:'2026-11-08',value:500},{id:'award2',type:'RSU',regular_rsu:true,vesting_date:'2026-11-07',available_date:'2026-11-10',value:700}]}}

// All values, source IDs and card numbers below are synthetic.
function fixtureHistory(){return Array.from({length:80},(_,i)=>({source_id:'history-'+i,description:'Compra sintética '+(i+1),amount:i===79?-10:10,last4:i%2?'1111':'2222',purchase_date:'2026-06-15',category:'Mercado',category_basis:'historical_workbook'}))}
function fixtureCycles(classified=false, stale=false){
 const sample=(id,amount,cat='Rafiki — Vestuário')=>({source_id:id,description:'Compra sintética '+id,amount,last4:'1111',purchase_date:'2026-09-18',installment_number:1,total_installments:3,category:cat,category_basis:cat==='A classificar'?'unresolved':'user_decision'});
 const entries=[['Bradesco','aeternum',1200,'1111'],['Bradesco','bradesco_prime',null,'2222'],['Itaú','itau_mastercard',800,'3333'],['Itaú','itau_visa',null,'4444'],['C6','c6',100,'5555']];
 return {version:'card-cycles-v226',active_billing_accounts:5,as_of:'2026-09-20',cards:entries.map(([bank,family,amount,last4])=>({bank,family,name:family,last4,status:'ACTIVE',cycles:amount==null?[]:[{month:'2026-10-01',due_date:'2026-10-12',amount,basis:'open_finance_composition',payment_status:'payment_not_reported',...(family==='itau_mastercard'?{documentary_payment_evidence:stale?{status:'source_changed',cash_effect:'none'}:{status:'identified_in_statement',cash_effect:'none',currency:'BRL',amount:800,payment_date:'2026-09-19',bank_posting_date:'2026-09-19',bank_posting_status:'POSTED',issuer_payment_date:'2026-09-18',issuer_payment_type:'FULL_PAYMENT',basis:'reviewed_original_link_and_exact_issuer_refresh'}}:{}),items:[sample('a-'+family,amount/2),sample('b-'+family,amount/2,!classified&&family==='aeternum'?'A classificar':'Saúde')]},{month:'2026-11-01',due_date:null,amount:100,basis:'derived_current_installments',items:[{...sample('future-'+family,100),installment_number:2}]}]}))};
}

async function run(browser,viewport,label){
 const context=await browser.newContext({viewport});
 await context.addInitScript(()=>{const Native=Date;window.__TEST_NOW__='2026-09-20T13:00:00Z';class TestDate extends Native{constructor(...args){super(...(args.length?args:[Native.parse(window.__TEST_NOW__)]))}static now(){return Native.parse(window.__TEST_NOW__)}}window.Date=TestDate});
 await context.addInitScript(s=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s)),session);
 let candidateServed=0;const presentationGeometry=[];
 const page=await context.newPage();page.setDefaultTimeout(20000);const errors=[],calls=[];
 await page.route('**/releases/v282/lts-v226-card-composition.js*',async route=>{const response=await route.fetch();const body=await response.body();assert.equal(crypto.createHash('sha256').update(body).digest('hex'),'e76f4d63e81d435c16790fd0a9063bd895d96e042955f9bc3fe4ec5cc80bbf49');candidateServed++;return route.fulfill({response,body});});
 const checkPresentationGeometry=async(root,stage)=>{const g=await root.evaluate(el=>{const nodes=[...el.querySelectorAll('.v226-note,small')].filter(n=>/Emissor:|pagamento integral informado pelo emissor/.test(n.textContent));const rect=n=>{const r=n.getBoundingClientRect(),p=n.parentElement.getBoundingClientRect();return{text:n.textContent,left:r.left,right:r.right,top:r.top,bottom:r.bottom,parentLeft:p.left,parentRight:p.right,width:n.clientWidth,scroll:n.scrollWidth}};return{nodes:nodes.map(rect),documentWidth:document.documentElement.clientWidth,documentScroll:document.documentElement.scrollWidth}});assert(g.nodes.length>=(stage==='summary'?2:1),'note and status geometry');for(const n of g.nodes){assert(n.left>=-1&&n.right<=viewport.width+1,'note/badge inside viewport');assert(n.left>=n.parentLeft-1&&n.right<=n.parentRight+1,'note/badge inside parent');assert(n.scroll<=n.width+1,'note/badge text fits');}assert(g.documentScroll<=g.documentWidth+3,'document does not overflow during '+stage);presentationGeometry.push({stage,...g});};
 const captureTarget=async(locator,name)=>{await locator.scrollIntoViewIfNeeded();const box=await locator.boundingBox();assert(box&&box.x>=-1&&box.y>=-1&&box.x+box.width<=viewport.width+1&&box.y+box.height<=viewport.height+1,'target inside viewport '+JSON.stringify({name,box,viewport}));await page.screenshot({path:'qa/v281-'+label+'-'+name+'.png'});};
 const cardNames=['Bradesco Visa','VISA AETERNUM','Itaú Mastercard Black','Itaú Visa','C6'];
 const flags={reviewDone:false,manualDescription:null,manualDeleted:false,cashFail:true,forecastFail:true,cardFail:true,date:'2026-09-20',cash:-1000,incomplete:false,pageFailure:false,cyclesFail:false,cardClassified:false,paymentStale:false,expenseFail:false,contextHang:false,expenseDelayFrom:null,balanceScenario:false,overdueMode:1,bankPositions:true,accountAsOf:'2026-09-19T18:00:00Z',statusReceipt:'2026-09-20T12:15:00Z',statusOrigin:'2026-09-19T18:00:00Z',allOrigins:false,refreshOk:false,requestedAt:'2026-09-20T12:30:00Z'};
 page.on('pageerror',e=>errors.push(String(e.stack||e)));
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
  // Synthetic freshness checks: account-resource date, receipt and Item remain separate.
  const bankKpi=kpi('Contas correntes · posição recebida');
  const freshnessPanel=()=>frame.locator('.v225-balance-freshness');
  async function waitFreshnessDashboardReady(){
    // cash + forecast become ready before the sequential wealth/awards/report readers finish.
    // Await the application's current orchestration promise, then bootstrap/collection work
    // that may have queued a forced refresh behind that flight. Never retry a detached node.
    await frame.evaluate(()=>window.__LTS_V178_REVIEW.ready());
    await frame.waitForFunction(()=>{
      const state=window.__LTS_V178_STATE,collection=window.__LTS_V225;
      return V==='Dashboard'&&collection?.started&&!collection.syncing&&!collection.loading&&!collection.statusRead
        &&['cash','forecast','wealth','awards','dashboardReport'].every(key=>state?.[key]?.status==='ready')
        &&!window.__LTS_V226?.loading;
    });
    // A forced refresh can have been queued after the first promise. Await that exact
    // current flight too, then cross rendering frames so queued render microtasks finish.
    await frame.evaluate(async()=>{
      await window.__LTS_V178_REVIEW.ready();
      await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
    });
    await frame.waitForFunction(()=>{
      const state=window.__LTS_V178_STATE,collection=window.__LTS_V225;
      return V==='Dashboard'&&collection?.started&&!collection.syncing&&!collection.loading&&!collection.statusRead
        &&['cash','forecast','wealth','awards','dashboardReport'].every(key=>state?.[key]?.status==='ready')
        &&!window.__LTS_V226?.loading;
    });
  }
  await waitFreshnessDashboardReady();
  await freshnessPanel().waitFor({state:'visible'});
  assert.equal(await bankKpi.locator('.v225-balance-freshness').count(),0,'metadata does not stretch the numeric KPI');
  assert(await freshnessPanel().evaluate(panel=>panel.parentElement.matches('.v168-kpis')&&panel.previousElementSibling?.querySelector('span')?.textContent==='Contas correntes · posição recebida'),'provenance is the grid sibling immediately after checking-account balance');
  assert.equal(await freshnessPanel().locator('details').count(),0,'primary provenance never requires disclosure');
  assert.equal(await freshnessPanel().locator('.v225-freshness-bank').count(),3);
  assert.equal(semantic(await bankKpi.locator('strong').innerText()),money(-1000),'provenance never rewrites received amount');
  assert.match(await freshnessPanel().innerText(),/Contas correntes · posição do provedor \(BRT\)/);
  assert.match(await freshnessPanel().innerText(),/dia anterior/);
  assert.match(await freshnessPanel().locator('time').first().getAttribute('title'),/19\/09\/2026,? 15:00 BRT/);
  const provenanceGeometry=await freshnessPanel().evaluate(panel=>{
    const box=node=>{const r=node.getBoundingClientRect();return {top:r.top,bottom:r.bottom,left:r.left,right:r.right,width:r.width,height:r.height};};
    const grid=panel.parentElement,cards=[...grid.children].filter(node=>node.matches('.v168-kpi'));
    const heightsWithPanel=cards.map(node=>node.getBoundingClientRect().height);
    const display=panel.style.getPropertyValue('display'),priority=panel.style.getPropertyPriority('display');
    let heightsWithoutPanel;
    try{panel.style.setProperty('display','none','important');heightsWithoutPanel=cards.map(node=>node.getBoundingClientRect().height);}
    finally{if(display)panel.style.setProperty('display',display,priority);else panel.style.removeProperty('display');}
    return {panel:box(panel),grid:box(grid),cards:cards.map(box),banks:[...panel.querySelectorAll('.v225-freshness-bank')].map(box),bank:box(panel.previousElementSibling),nextCard:box(panel.nextElementSibling),heightsWithPanel,heightsWithoutPanel,rowGap:parseFloat(getComputedStyle(grid).rowGap),order:getComputedStyle(panel).order,overflow:panel.scrollWidth>panel.clientWidth+1,pageOverflow:document.documentElement.scrollWidth>innerWidth+1};
  });
  fs.writeFileSync('qa/v281-'+label+'-freshness-geometry.json',JSON.stringify(provenanceGeometry,null,2));
  assert.equal(provenanceGeometry.cards.length,5,'the five numeric KPIs stay separate from provenance');
  assert(!provenanceGeometry.overflow&&!provenanceGeometry.pageOverflow,'compact provenance fits '+label+' viewport');
  assert(provenanceGeometry.heightsWithPanel.every((height,i)=>Math.abs(height-provenanceGeometry.heightsWithoutPanel[i])<=1),'provenance must not stretch any KPI: '+JSON.stringify(provenanceGeometry));
  assert(Math.abs(provenanceGeometry.panel.left-provenanceGeometry.grid.left)<=1&&Math.abs(provenanceGeometry.panel.right-provenanceGeometry.grid.right)<=1,'provenance aligns with the full KPI grid');
  assert(provenanceGeometry.panel.height<=330,'primary provenance stays compact on '+label+' '+JSON.stringify(provenanceGeometry));
  if(viewport.width>520){
    assert.equal(provenanceGeometry.order,'1');
    assert(provenanceGeometry.panel.top>=Math.max(...provenanceGeometry.cards.map(card=>card.bottom)),'desktop provenance follows all five KPIs');
    assert(provenanceGeometry.banks.every(bank=>Math.abs(bank.top-provenanceGeometry.banks[0].top)<=1),'desktop banks align side by side');
    assert(provenanceGeometry.banks[0].right<=provenanceGeometry.banks[1].left&&provenanceGeometry.banks[1].right<=provenanceGeometry.banks[2].left,'desktop bank columns never overlap');
  }else{
    assert.equal(provenanceGeometry.order,'0');
    assert(Math.abs(provenanceGeometry.panel.top-provenanceGeometry.bank.bottom-provenanceGeometry.rowGap)<=1,'mobile metadata immediately follows bank balance with the normal grid gap');
    assert(Math.abs(provenanceGeometry.nextCard.top-provenanceGeometry.panel.bottom-provenanceGeometry.rowGap)<=1,'mobile metadata stays before the next numeric KPI');
  }
  console.log('FRESHNESS_GEOMETRY',JSON.stringify({label,...provenanceGeometry}));
  // Resolve a fresh locator after required readers and queued render work have settled.
  await waitFreshnessDashboardReady();
  const settledFreshnessPanel=frame.locator('.v225-balance-freshness');
  await captureTarget(settledFreshnessPanel,'freshness-near-balance');
  flags.bankPositions=false;await frame.evaluate(()=>window.__LTS_V178_REVIEW.refresh());
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='ready'&&!window.__LTS_V178_STATE.cash.data.bank_positions);
  assert.match(await freshnessPanel().innerText(),/indisponível/);
  assert.match(await freshnessPanel().innerText(),/Conexão:/,'Item remains labeled as connection when resource metadata is absent');
  assert.equal(semantic(await bankKpi.locator('strong').innerText()),money(-1000));
  flags.bankPositions=true;await frame.evaluate(()=>window.__LTS_V178_REVIEW.refresh());
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='ready'&&window.__LTS_V178_STATE.cash.data.bank_positions?.length===3);
  await frame.waitForFunction(()=>!window.__LTS_V225.syncing);
  flags.refreshOk=true;flags.allOrigins=true;flags.statusReceipt='2026-09-20T12:40:00Z';
  await frame.evaluate(()=>window.__LTS_V225.refresh());
  await waitFreshnessDashboardReady();
  assert.match(await frame.locator('.v225-sync').innerText(),/mesma origem de conexão/);
  assert.match(await frame.locator('.v225-sync').innerText(),/não confirma nova posição de saldo/);
  assert.match(await freshnessPanel().locator('time').first().getAttribute('title'),/19\/09\/2026/,'new receipt never becomes new resource date');
  // Item advances while the account resource remains old: connection freshness must not replace its date.
  flags.requestedAt='2026-09-20T12:42:00Z';flags.statusReceipt='2026-09-20T12:48:00Z';flags.statusOrigin='2026-09-20T12:44:00Z';
  await frame.evaluate(()=>window.__LTS_V225.refresh());
  await waitFreshnessDashboardReady();
  assert.match(await freshnessPanel().locator('time').first().getAttribute('title'),/19\/09\/2026,? 15:00 BRT/,'Item advance never replaces the old account-resource timestamp');
  assert.match(await freshnessPanel().innerText(),/dia anterior/);
  assert.doesNotMatch(await frame.locator('.v225-sync').innerText(),/saldo atualizado/);
  assert.equal(semantic(await bankKpi.locator('strong').innerText()),money(-1000),'Item-only advance preserves received amount');
  // Now advance the account timestamp too, while keeping its legitimate unchanged balance.
  flags.requestedAt='2026-09-20T12:50:00Z';flags.statusReceipt='2026-09-20T12:58:00Z';flags.statusOrigin='2026-09-20T12:55:00Z';flags.accountAsOf='2026-09-20T12:45:00Z';
  await frame.evaluate(()=>window.__LTS_V225.refresh());
  await waitFreshnessDashboardReady();
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.data.bank_positions?.[0]?.as_of==='2026-09-20T12:45:00Z');
  assert.match(await freshnessPanel().locator('time').first().getAttribute('title'),/20\/09\/2026,? 09:45 BRT/);
  assert.equal(semantic(await bankKpi.locator('strong').innerText()),money(-1000),'same balance with newer source timestamp is preserved');
  assert.doesNotMatch(await frame.locator('.v225-sync').innerText(),/saldo atualizado/);
  // Restore all existing fixture expectations for the remainder of the gate.
  flags.refreshOk=false;flags.allOrigins=false;flags.statusReceipt='2026-09-20T12:15:00Z';flags.statusOrigin='2026-09-19T18:00:00Z';flags.accountAsOf='2026-09-19T18:00:00Z';
  // Clear only synthetic test observation state so intentional fixture rollback is not treated as production regression.
  await frame.evaluate(()=>{window.__LTS_V225.status=null;window.__LTS_V225.observations=new Map();});
  await frame.evaluate(()=>window.__LTS_V225.readStatus());

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

  // Full ordered release stack, actual bindings and shared RPC transport; all network payloads synthetic.
  // Read-only diagnostic for an expense draft overwritten between input and Apply.
  // No sleeps, DOM writes, retries, or softened assertions are introduced here.
  await frame.evaluate(()=>{
   if(window.__LTS_EXPENSE_DRAFT_PROBE)return;
   const snapshot=()=>{const s=window.__LTS_V168_STATE?.expense,h=window.__LTS_V175_STATE?.expense,c=window.__LTS_V178_STATE?.cash;return{
    view:typeof V==='undefined'?null:V,selected_key:s?.key,custom_from:s?.customFrom,custom_to:s?.customTo,
    input_from:document.getElementById('v168ExpenseFrom')?.value??null,input_to:document.getElementById('v168ExpenseTo')?.value??null,
    active_element:document.activeElement?.id||null,visibility:document.visibilityState,
    expense:{loading:s?.loading,error:s?.error,token:s?.token,period:s?.data?.period},
    history:{loading:h?.loading,error:h?.error,key:h?.key,token:h?.token,period:h?.data?.period},
    cash:{status:c?.status,date:c?.date,token:c?.token,session_generation:c?.sessionGeneration},
    boot_generation:typeof BOOT==='undefined'?null:BOOT.generation,transport_revision:window.__LTS_V227_TRANSPORT?.revision};};
   const probe=window.__LTS_EXPENSE_DRAFT_PROBE={active:false,request:null,events:[],snapshot};
   probe.record=(phase,extra={})=>{if(!probe.active)return;probe.events.push({sequence:probe.events.length+1,at_ms:performance.now(),phase,request:probe.request,...extra,state:snapshot()});if(probe.events.length>2000)probe.events.shift();};
   for(const type of ['input','change'])document.addEventListener(type,event=>{if(['v168ExpenseFrom','v168ExpenseTo'].includes(event.target?.id))probe.record(type,{target:event.target.id,value:event.target.value});},true);
   document.addEventListener('click',event=>{const target=event.target?.closest?.('#v168ExpenseApply,[data-v168-exp-range]');if(target)probe.record('click-capture-before-handler',{target:target.id||target.dataset.v168ExpRange});},true);
   const originalRender=render;
   render=function(){const tracked=probe.active&&V==='Despesas';if(tracked)probe.record('before-render',{stack:new Error('expense-render-origin').stack});const result=originalRender.apply(this,arguments);if(tracked)probe.record('after-render');return result;};
  });
  const applyExpense=async(from,to)=>{
   await frame.evaluate(request=>{const p=window.__LTS_EXPENSE_DRAFT_PROBE;p.active=true;p.request=request;p.record('apply-helper-start');},{from,to});
   await frame.locator('[data-v168-exp-range="custom"]').click();
   await frame.locator('#v168ExpenseFrom').fill(from);
   await frame.locator('#v168ExpenseTo').fill(to);
   await frame.evaluate(()=>window.__LTS_EXPENSE_DRAFT_PROBE.record('before-playwright-apply-click'));
   await frame.locator('#v168ExpenseApply').click();
   await frame.evaluate(()=>window.__LTS_EXPENSE_DRAFT_PROBE.record('after-playwright-apply-click'));
   fs.writeFileSync('qa/v281-'+label+'-expense-draft-probe.json',JSON.stringify(await frame.evaluate(()=>({request:window.__LTS_EXPENSE_DRAFT_PROBE.request,events:window.__LTS_EXPENSE_DRAFT_PROBE.events,state:window.__LTS_EXPENSE_DRAFT_PROBE.snapshot()})),null,2));
  };
  const countMain=(from,to)=>calls.filter(c=>(c.name==='lts_browser_expenses_v229'||/^lts_browser_expense_executive_v/.test(c.name))&&c.args.p_from===from&&c.args.p_to===to).length;
  const expenseApplied=()=>frame.evaluate(()=>{const s=window.__LTS_V168_STATE.expense;return{key:s.key,customFrom:s.customFrom,customTo:s.customTo}});
  const draftError=()=>frame.locator('.v168-custom-range [data-v280-expense-draft-error][role="alert"]');
  const periodReads=()=>calls.filter(c=>Object.hasOwn(c.args,'p_from')||Object.hasOwn(c.args,'p_to'));
  const futureMessage='Despesas realizadas estão disponíveis até 20/09/2026. Para datas futuras, consulte o Fluxo Diário. O período escolhido foi preservado.';
  const rejectExpense=async(from,to,message)=>{
   const applied=await expenseApplied(),before=periodReads().length;
   await applyExpense(from,to);await draftError().waitFor({state:'visible'});
   assert.equal(semantic(await draftError().innerText()),message,'specific validation remains in the editor');
   assert.deepEqual(await expenseApplied(),applied,'invalid Apply preserves the previously applied period');
   assert.equal(await frame.locator('#v168ExpenseFrom').inputValue(),from,'invalid start input preserved');
   assert.equal(await frame.locator('#v168ExpenseTo').inputValue(),to,'invalid end input preserved');
   await frame.evaluate(async()=>{await Promise.resolve();await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))});
   assert.equal(periodReads().length,before,'open/edit/invalid Apply starts no period-based RPC');
   assert.equal(calls.filter(c=>c.args.p_from===from&&c.args.p_to===to).length,0,'invalid draft never reaches any RPC');
   assert.equal(await frame.locator('[data-v168-exp-retry]').count(),0,'invalid editor range has no misleading report retry');
  };
  await rejectExpense('2026-09-01','2026-09-30',futureMessage);
  await captureTarget(draftError(),'future-range');
  const futureApplied=await expenseApplied();
  await frame.locator('[role="tab"][data-v168-exp-tab="categories"]').click();
  await frame.waitForFunction(()=>!window.__LTS_V175_STATE.expense.rangeInvalid&&!window.__LTS_V175_STATE.expense.loading);
  assert.equal(semantic(await draftError().innerText()),futureMessage,'categories preserves future draft guidance');
  assert.deepEqual(await expenseApplied(),futureApplied,'categories uses the previously applied period');
  assert.equal(calls.filter(c=>c.args.p_from==='2026-09-01'&&c.args.p_to==='2026-09-30').length,0,'categories does not send future range');
  await frame.locator('[role="tab"][data-v168-exp-tab="overview"]').click();
  await rejectExpense('2026-09-10','2026-09-01','Informe um período válido.');
  await rejectExpense('2013-01-01','2013-02-01','O histórico de despesas começa em 10/10/2013. O período escolhido foi preservado.');
  flags.expenseFail=true;await applyExpense('2026-09-02','2026-09-20');
  await frame.waitForFunction(()=>window.__LTS_V168_STATE.expense.error==='Não foi possível atualizar este relatório.'&&!window.__LTS_V168_STATE.expense.loading);
  const failedReads=countMain('2026-09-02','2026-09-20');assert.equal(failedReads,1,'one main network read per failed attempt');
  await page.waitForTimeout(600);assert.equal(countMain('2026-09-02','2026-09-20'),failedReads,'error does not auto-retry on full-stack rerender');
  await captureTarget(frame.locator('[data-v168-exp-retry]'),'explicit-retry');
  flags.expenseFail=false;await frame.locator('[data-v168-exp-retry]').click();
  await frame.waitForFunction(()=>window.__LTS_V168_STATE.expense.data?.period?.from==='2026-09-02'&&!window.__LTS_V168_STATE.expense.loading);
  assert.equal(countMain('2026-09-02','2026-09-20'),failedReads+1,'explicit retry has exactly one request');
  flags.expenseDelayFrom='2026-09-03';await applyExpense('2026-09-03','2026-09-20');await applyExpense('2026-09-04','2026-09-20');
  await frame.waitForFunction(()=>window.__LTS_V168_STATE.expense.data?.period?.from==='2026-09-04'&&!window.__LTS_V168_STATE.expense.loading);
  await page.waitForTimeout(900);assert.equal(await frame.evaluate(()=>window.__LTS_V168_STATE.expense.data.period.from),'2026-09-04','old response discarded by actual layered renderers');
  flags.contextHang=true;await applyExpense('2026-09-05','2026-09-20');
  await frame.waitForFunction(()=>window.__LTS_V168_STATE.expense.data?.period?.from==='2026-09-05'&&!window.__LTS_V168_STATE.expense.loading,null,{timeout:40000});
  assert.equal(await frame.evaluate(()=>window.__LTS_V168_STATE.expense.context),null,'never-resolving optional context times out without losing main data');
  assert.equal(countMain('2026-09-05','2026-09-20'),1,'context timeout does not restart main report');flags.contextHang=false;
  flags.expenseDelayFrom='2026-09-06';await applyExpense('2026-09-06','2026-09-20');await nav('Dashboard').click();
  await frame.waitForSelector('.v168-dashboard');await page.waitForTimeout(900);assert(await frame.locator('.v168-dashboard').isVisible(),'late expense completion preserves current route');
  await nav('Despesas').click();await frame.waitForFunction(()=>window.__LTS_V168_STATE.expense.data?.period?.from==='2026-09-06'&&!window.__LTS_V168_STATE.expense.loading);
  flags.expenseDelayFrom=null;
  await frame.evaluate(()=>{window.__TEST_NOW__='2026-09-21T02:59:59Z'});await rejectExpense('2026-09-01','2026-09-21',futureMessage);
  assert.equal(countMain('2026-09-01','2026-09-21'),0,'BRT day boundary respected without committing the invalid draft');
  flags.date='2026-09-21';await frame.evaluate(()=>{window.__TEST_NOW__='2026-09-21T03:00:00Z'});await applyExpense('2026-09-01','2026-09-21');
  await frame.waitForFunction(()=>window.__LTS_V168_STATE.expense.data?.period?.to==='2026-09-21'&&!window.__LTS_V168_STATE.expense.loading);
  assert.equal(countMain('2026-09-01','2026-09-21'),1,'new BRT day accepted after explicit apply');
  flags.date='2026-09-20';await frame.evaluate(()=>{window.__TEST_NOW__='2026-09-20T13:00:00Z'});
  await frame.locator('[data-v168-exp-range="ytd"]').click();await frame.waitForFunction(()=>window.__LTS_V168_STATE.expense.data?.period?.from==='2026-01-01'&&!window.__LTS_V168_STATE.expense.loading);
  console.log('PASS_FULL_STACK_EXPENSE_FILTER',label);
  await frame.locator('[data-v168-exp-range="6m"]').click();await frame.locator('.v168-tabs [data-v168-exp-tab="categories"]').click();await frame.waitForSelector('.v181-category-panel');
  await frame.locator('[data-v181-detail-group="Benjamin — Saúde"]').click();await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail&&!window.__LTS_V178_STATE.detail.loading);assert.equal(await frame.evaluate(()=>window.__LTS_V178_STATE.detail.range.from),'2026-04-01');assert.equal(await frame.locator('#v178Drawer tbody tr').count(),3);await frame.locator('.v178-close').click();
  await frame.locator('[data-v168-exp-range="all"]').click();await frame.locator('.v168-tabs [data-v168-exp-tab="monthly"]').click();await frame.waitForFunction(()=>window.__LTS_V175_STATE.monthly.data?.months?.length===156&&!window.__LTS_V175_STATE.monthly.loading);
  assert((await frame.locator('.v175-monthly').innerText()).includes('Benjamin — Educação'));
  if(['v231','v235','v236','v240','v241','v242','v244','v245','v257','v258','v259','v260','v261','v262','v264','v269','v270','v271','v276','v282'].includes(process.env.LTS_RELEASE)){
   const matrix=frame.locator('.v175-section').filter({has:frame.getByRole('heading',{name:'Despesas por categoria',exact:true})});
   await matrix.locator('tbody tr').filter({has:frame.locator('th').filter({hasText:'Benjamin — Educação'})}).locator('td').last().locator('button').click();
   await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail&&!window.__LTS_V178_STATE.detail.loading);
   assert.equal(await frame.evaluate(()=>window.__LTS_V178_STATE.detail.group),'Benjamin — Educação');
   assert.equal(await frame.evaluate(()=>window.__LTS_V178_STATE.detail.total),250);
   await frame.locator('.v178-close').click();
  }
  const monthlyDims=await frame.locator('html').evaluate(e=>({width:e.clientWidth,scroll:e.scrollWidth}));assert(monthlyDims.scroll<=monthlyDims.width+3,'monthly tables do not expand the page '+JSON.stringify(monthlyDims));
  await frame.locator('.v168-tabs [data-v168-exp-tab="cards"]').click();
  await frame.waitForSelector('[data-v175-card-retry]');
  await frame.waitForSelector('.v226-upcoming [data-v226-overview="next"]');
  assert(await frame.locator('.v226-history').isVisible(),'source composition remains available when the legacy Flow comparison fails');
  const failedCardCalls=calls.filter(x=>x.name==='lts_browser_card_flow_schedule_v2').length;
  await frame.evaluate(()=>render());await page.waitForTimeout(250);assert.equal(calls.filter(x=>x.name==='lts_browser_card_flow_schedule_v2').length,failedCardCalls,'card failure remains visible without an automatic retry loop');
  flags.cardFail=false;await frame.locator('[data-v175-card-retry]').click();
  await frame.waitForFunction(()=>window.__LTS_V183_CARD_PERIOD.status==='ready'&&window.__LTS_V175_STATE.cards.data?.inventory?.cards?.length===5);
  await frame.waitForFunction(()=>{const el=document.querySelector('.v168-expenses .v226-banks>section');return el?.isConnected&&getComputedStyle(el).borderRadius==='14px'});
  const cardStyle=await frame.evaluate(()=>{const s=getComputedStyle(document.querySelector('.v168-expenses .v226-banks>section'));return{radius:s.borderRadius,border:s.borderTopWidth,padding:s.paddingTop}});
  assert.equal(cardStyle.radius,'14px','Expenses preserves the approved bank card presentation');assert.equal(cardStyle.border,'1px');assert(Number.parseFloat(cardStyle.padding)>=14);
  const inventory=await frame.locator('.v183-card-families').innerText();for(const name of cardNames)assert(inventory.includes(name),'historical card retained: '+name);
  assert(!inventory.includes('Visa Eternum'),'AETERNUM spelling preserved');
  await frame.waitForFunction(()=>document.querySelector('[data-v183-payment-status]')?.innerText.includes('Pagamento documentado'));
  await page.screenshot({path:'qa/v229-'+label+'-cards.png'});
  await nav('Atualizações').click();await frame.waitForSelector('[data-v181-review-key="pending-fixture"]');
  await frame.waitForFunction(()=>document.querySelector('.v168-openfinance')?.innerText.includes('19/09/2026'));
  const freshness=await frame.locator('.v168-openfinance').innerText();
  assert.match(freshness,/Dados recebidos pelo Wealth em/);assert.match(freshness,/Atualização da conexão na origem/);assert.match(freshness,/Essa data da conexão não confirma a atualização de cada saldo ou transação/);assert.match(freshness,/20\/09\/2026,? 09:15 BRT/);assert.match(freshness,/19\/09\/2026,? 15:00 BRT/);assert.match(freshness,/indisponível/);assert.match(freshness,/Falha na última coleta/);
  await page.screenshot({path:'qa/v281-'+label+'-collection-origin-updates.png',fullPage:true});
  await captureTarget(frame.locator('.v168-openfinance'),'collection-origin-updates-target');
  const banks=frame.locator('.v168-openfinance .v225-bank');
  assert.equal(await banks.count(),3);
  for(let i=0;i<3;i++){
   const bank=banks.nth(i);await bank.evaluate(el=>el.scrollIntoView({block:'center',inline:'nearest'}));
   const box=await bank.boundingBox();
   assert(box&&box.y>=60&&box.y+box.height<=viewport.height-75,'bank clear of fixed navigation '+JSON.stringify({i,box,viewport}));
   await page.screenshot({path:'qa/v281-'+label+'-collection-origin-bank-'+i+'-target.png'});
  }
  const contextRow=frame.locator('[data-v181-review-key="context-fixture"]');await contextRow.locator('[data-v181-beneficiary]').selectOption('Lucas');assert(await contextRow.locator('[data-v181-review-save]').isEnabled(),'context can be confirmed without replacing its existing category');
  const suggested=frame.locator('[data-v181-review-key="pending-fixture"]');
  assert.equal(await suggested.locator('[data-v181-category]').inputValue(),'Mercado','history suggestion is preselected');
  assert.equal(await suggested.locator('[data-v181-review-save]').innerText(),'Confirmar sugestão');
  assert.equal(calls.filter(x=>x.name==='lts_browser_expense_review_decision_v229').length,0,'suggestion never writes automatically');
  assert.equal(await frame.locator('[data-v181-review-key="uncertain-fixture"] [data-v181-category]').inputValue(),'');
  assert(await frame.locator('[data-v181-review-key="uncertain-fixture"] [data-v181-review-save]').isDisabled());
  // Observe the synchronous change handler before an unrelated background render replaces the old-release DOM.
  const blankChoice=await suggested.locator('[data-v181-category]').evaluate(select=>{select.value='';select.dispatchEvent(new Event('input',{bubbles:true}));select.dispatchEvent(new Event('change',{bubbles:true}));return{value:select.value,disabled:select.closest('[data-v181-review-key]').querySelector('[data-v181-review-save]').disabled};});
  assert.equal(blankChoice.value,'');assert.equal(blankChoice.disabled,true,'a blank category disables confirmation');
  if(currentSource){
   await frame.evaluate(()=>render());
   assert.equal(await suggested.locator('[data-v181-category]').inputValue(),'','a background repaint preserves the explicit blank choice');
   assert(await suggested.locator('[data-v181-review-save]').isDisabled(),'a suggestion is not restored over an unsaved choice');
   assert.equal(calls.filter(x=>x.name==='lts_browser_expense_review_decision_v229').length,0,'an unsaved draft never writes');
  }
  await frame.locator('[data-v181-review-key="pending-fixture"] [data-v181-category]').selectOption('Mercado');
  await frame.locator('[data-v181-review-key="pending-fixture"] [data-v181-review-save]').click();
  await frame.waitForFunction(()=>window.__LTS_V181_STATE.review.data?.row_count===2);
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
  // Received bank position and today's projected closing coexist without changing either.
  flags.balanceScenario=true;flags.cash=1200.30;
  await frame.evaluate(()=>window.__LTS_V178_REVIEW.refresh());
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='ready'&&window.__LTS_V178_STATE.cash.data.cash===1200.30);
  await frame.locator('#flowFrom').fill(flags.date);await frame.locator('#flowTo').fill(flags.date);await frame.locator('#flowApply').click();
  await frame.waitForFunction(()=>!FLOWLOADING&&document.querySelector('#v274ReceivedPosition')?.textContent.includes('1.200,30'));
  assert.match(await frame.locator('#v274ReceivedPosition').innerText(),/Não é uma consulta em tempo real/);
  const closing=frame.locator('#d-'+flags.date+' > div').nth(4);
  assert.equal(semantic(await closing.locator('b').innerText()),money(1450.30));
  assert.equal(await closing.locator('.v274-ending-label').innerText(),'Encerramento do fluxo');
  const balanceGeometry=await closing.evaluate(cell=>{const c=cell.getBoundingClientRect(),b=cell.querySelector('b').getBoundingClientRect(),tag=cell.querySelector('.v274-ending-label').getBoundingClientRect(),p=document.querySelector('#v274ReceivedPosition');return{cell:{left:c.left,right:c.right,top:c.top,bottom:c.bottom},number:{left:b.left,right:b.right,top:b.top,bottom:b.bottom},badge:{left:tag.left,right:tag.right,top:tag.top,bottom:tag.bottom},noteOverflow:p.scrollWidth>p.clientWidth+1,pageOverflow:document.documentElement.scrollWidth>innerWidth+1}});
  assert(balanceGeometry.badge.top>=balanceGeometry.number.bottom-1,'closing label is below amount');
  for(const part of [balanceGeometry.number,balanceGeometry.badge]){assert(part.left>=balanceGeometry.cell.left-1&&part.right<=balanceGeometry.cell.right+1,'closing text fits cell horizontally');assert(part.top>=balanceGeometry.cell.top-1&&part.bottom<=balanceGeometry.cell.bottom+1,'closing text fits cell vertically');}
  assert(!balanceGeometry.noteOverflow&&!balanceGeometry.pageOverflow,'received position fits flow viewport');
  await frame.evaluate(()=>{window.__LTS_V178_STATE.cash.status='error';render()});
  assert.match(await frame.locator('#v274ReceivedPosition').innerText(),/indisponível/);
  assert.doesNotMatch(await frame.locator('#v274ReceivedPosition').innerText(),/R\$\s*0,00/);
  await frame.evaluate(()=>{window.__LTS_V178_STATE.cash.status='ready';render()});
  await page.screenshot({path:'qa/v281-'+label+'-received-vs-closing.png',fullPage:true});
  for(const [account,expected] of [['Itaú',700.30],['Bradesco',0],['C6',500],['Consolidado',1200.30]]){
   const begin=Date.now();await frame.locator('[data-a="'+account+'"]').click();
   await frame.waitForFunction(({account})=>document.querySelector('#v274ReceivedPosition')?.textContent.includes(account==='Consolidado'?'todas as contas':account),{account});
   assert((Date.now()-begin)<2000,'current-day bank switching remains responsive');
   assert(semantic(await frame.locator('#v274ReceivedPosition').innerText()).includes(money(expected)));
   const visibleCodes=await freshnessPanel().locator('.v225-freshness-bank').evaluateAll(nodes=>nodes.map(node=>node.dataset.bank));
   assert.deepEqual(visibleCodes,account==='Consolidado'?['341','237','336']:[{'Itaú':'341','Bradesco':'237','C6':'336'}[account]],'date panel follows the selected bank without borrowing another account');

  }
  const projected=await frame.evaluate(()=>FLOWQ.current_future.events.filter(e=>e.is_projection===true).map(e=>[e.source_ref,e.signed_amount,e.status]));
  assert.deepEqual(projected,[['synthetic-reimbursement',400,'expected'],['synthetic-tax',-150,'scheduled']]);
  flags.balanceScenario=false;flags.cash=-1000;
  await frame.evaluate(()=>window.__LTS_V178_REVIEW.refresh());
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.data?.cash===-1000&&window.__LTS_V178_STATE.cash.status==='ready');

  // Overdue obligation remains visible without moving its date or changing cash.
  flags.overdueMode=1;
  await frame.locator('#flowFrom').fill(flags.date);await frame.locator('#flowTo').fill(flags.date);await frame.locator('#flowApply').click();
  await frame.waitForFunction(()=>!FLOWLOADING&&window.__LTS_FLOW_OVERDUE_PROJECTIONS?.last_status==='ready'&&document.querySelector('#ltsFlowOverdueProjections details'));
  const overdue=frame.locator('#ltsFlowOverdueProjections');
  assert.match(await overdue.innerText(),/1 previsão vencida ainda sem conciliação/);
  assert.equal(await frame.locator('#ltsFlowOverdueProjections').count(),1,'One overdue panel only');
  const beforeOverdue=await frame.evaluate(()=>JSON.stringify(FLOWQ));
  await overdue.locator('summary').click();
  assert.match(await overdue.innerText(),/19\/09\/2026/);
  assert.match(await overdue.innerText(),/baixa ainda não vinculada no LTS/);
  assert.match(await overdue.innerText(),/Podem incluir pagamentos já recebidos pelo banco e ainda não vinculados no LTS\./);
  assert.doesNotMatch(await overdue.innerText(),/pagamento não confirmado|recebimento não confirmado|realização não confirmada/);
  assert(semantic(await overdue.innerText()).includes(money(-150.25)));
  await frame.evaluate(()=>render());
  assert.equal(await overdue.locator('details').getAttribute('open'),'');
  assert.equal(await frame.evaluate(()=>JSON.stringify(FLOWQ)),beforeOverdue);
  await frame.evaluate(()=>{V='Dashboard';renderNav();render()});
  assert.equal(await frame.locator('#ltsFlowOverdueProjections').count(),0);
  await frame.evaluate(()=>{V='Fluxo Diário';renderNav();render()});
  assert.equal(await frame.locator('#ltsFlowOverdueProjections').count(),1);
  assert.equal(await overdue.locator('details').getAttribute('open'),'');
  const overdueGeometry=await overdue.evaluate(el=>{const box=el.getBoundingClientRect();return{left:box.left,right:box.right,width:innerWidth,overflow:el.scrollWidth>el.clientWidth+1,pageOverflow:document.documentElement.scrollWidth>innerWidth+1}});
  assert(overdueGeometry.left>=-1&&overdueGeometry.right<=overdueGeometry.width+1&&!overdueGeometry.overflow&&!overdueGeometry.pageOverflow,'overdue panel fits viewport');
  const overdueValueGeometry=await overdue.locator('li strong').evaluate(el=>{const v=el.getBoundingClientRect(),p=el.closest('section').getBoundingClientRect();return{left:v.left,right:v.right,top:v.top,bottom:v.bottom,pLeft:p.left,pRight:p.right,pTop:p.top,pBottom:p.bottom}});
  assert(overdueValueGeometry.left>=overdueValueGeometry.pLeft-1&&overdueValueGeometry.right<=overdueValueGeometry.pRight+1&&overdueValueGeometry.top>=overdueValueGeometry.pTop-1&&overdueValueGeometry.bottom<=overdueValueGeometry.pBottom+1,'Overdue amount fits expanded panel');
  await page.screenshot({path:'qa/v281-'+label+'-overdue-expanded.png',fullPage:true});
  await frame.locator('[data-a="Bradesco"]').click();
  assert.match(await overdue.innerText(),/Nenhuma previsão vencida nesta lista recebida para Bradesco/);
  await frame.locator('[data-a="Itaú"]').click();
  assert.match(await overdue.innerText(),/1 previsão vencida/);
  await frame.locator('[data-a="Consolidado"]').click();
  await frame.evaluate(()=>{delete FLOWQ.observed_bank_movements;render()});
  assert.match(await overdue.innerText(),/não trouxe a lista/);
  assert.doesNotMatch(await overdue.innerText(),/Nenhuma previsão/);
  await frame.evaluate(()=>{FLOWQ.observed_bank_movements={pending_projections:[]};render()});
  assert.match(await overdue.innerText(),/Nenhuma previsão vencida nesta lista recebida/);
  flags.overdueMode=0;
  // This audit checks every date, including deliberately hidden idle days.
  if(['v245','v257','v258','v259','v260','v261','v262','v264','v269','v270','v271','v276','v282'].includes(process.env.LTS_RELEASE)&&!await frame.evaluate(()=>SHOWZERO))await frame.locator('#flowZero').click();
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
  await frame.locator('#flowZero').click();await page.waitForTimeout(50);assert.equal(await frame.locator('#d-2026-11-07').count(),0);assert.equal(await frame.locator('#d-2026-11-08').count(),['v245','v257','v258','v259','v260','v261','v262','v264','v269','v270','v271','v276','v282'].includes(process.env.LTS_RELEASE)?1:0,'V245 retains a dated RSU resource change while hiding idle cash days');assert.equal(await frame.locator('#d-2026-11-09').count(),1,'real in and out with zero net must remain');assert.equal(await frame.locator('#d-2026-11-05').count(),1);
  await page.screenshot({path:'qa/v229-'+label+'-flow.png'});
  await frame.locator('#d-2026-11-09 .exp').click();
  const invoiceRow=frame.locator('.fx89-detail-row').filter({has:frame.getByText('Fatura sintética',{exact:true})});
  await invoiceRow.scrollIntoViewIfNeeded();assert.match(await invoiceRow.innerText(),/Consulte composição e eventuais pendências em Abrir fatura/);assert.equal(await invoiceRow.locator('.flow-unclassified-link').count(),0);assert.equal(await invoiceRow.locator('.carddetailbtn').count(),1,'invoice detail remains actionable');
  await page.screenshot({path:'qa/v270-'+label+'-invoice-aggregate.png',fullPage:true});
  const beforeTarget=await frame.evaluate(()=>({account:ACC,from:FLOWFROM,to:FLOWTO,expanded:[...EXP]}));
  const legacyBefore=calls.filter(x=>x.name==='lts_browser_card_settlement_detail_v2').length;
  await invoiceRow.locator('.carddetailbtn').click();
  const flowDialog=frame.locator('#v226-detail');await flowDialog.locator('[data-v226-item]').first().waitFor();
  assert.equal(await flowDialog.locator('[data-v226-item]').count(),2,'real Flow click opens canonical items');
  assert.match(await flowDialog.innerText(),/Mastercard Black/);
  assert.match(await flowDialog.locator('header').innerText(),/out.*2026/i,'competence from source_ref, not November payment');
  assert.match(await flowDialog.innerText(),/a-itau_mastercard/);
  assert.match(await flowDialog.innerText(),/Emissor: pagamento integral informado em 18\/09\/2026.*Banco: débito lançado no extrato em 19\/09\/2026/s);
  assert.equal(await frame.evaluate(()=>window.__LTS_V226.cycles.cards.find(c=>c.family==='itau_mastercard').cycles[0].payment_status),'payment_not_reported','documentary note does not change API status');
  assert.equal(calls.filter(x=>x.name==='lts_browser_card_settlement_detail_v2').length,legacyBefore,'modern click does not call legacy settlement');
  await page.screenshot({path:'qa/v281-'+label+'-flow-documentary-detail.png',fullPage:true});
  await captureTarget(flowDialog.locator('.v226-note').filter({hasText:'Emissor: pagamento integral informado'}),'documentary-detail-target');
  await checkPresentationGeometry(flowDialog,'detail');
  await flowDialog.locator('[data-v226-close]').click();
  assert.deepEqual(await frame.evaluate(()=>({account:ACC,from:FLOWFROM,to:FLOWTO,expanded:[...EXP]})),beforeTarget,'closing preserves Flow selection');
  // Synthetic ambiguity: two cards in the same canonical family must not select the first.
  await frame.evaluate(()=>{window.__flowTestCards=window.__LTS_V226.cycles.cards;window.__LTS_V226.cycles.cards=[...window.__flowTestCards,window.__flowTestCards.find(c=>c.family==='itau_mastercard')];});
  await invoiceRow.locator('.carddetailbtn').click();
  await flowDialog.getByRole('alert').waitFor();assert.equal(await flowDialog.locator('[data-v226-item]').count(),0);
  assert.match(await flowDialog.innerText(),/única fatura com segurança/);
  await flowDialog.locator('[data-v226-close]').click();
  await frame.evaluate(()=>{window.__LTS_V226.cycles.cards=window.__flowTestCards;delete window.__flowTestCards;});
  flags.cyclesFail=true;const beforeFailureRead=calls.filter(x=>x.name==='lts_browser_card_cycles_v229').length;await frame.evaluate(()=>{window.__LTS_V227_TRANSPORT.invalidate();window.__LTS_V226.invalidate();});
  await invoiceRow.locator('.carddetailbtn').click();await flowDialog.getByRole('alert').waitFor();
  assert(calls.filter(x=>x.name==='lts_browser_card_cycles_v229').length>beforeFailureRead,'failure injected at an actual source read');
  assert.equal(await flowDialog.locator('[data-v226-item]').count(),0,'failed fresh load does not reuse stale composition');
  await flowDialog.locator('[data-v226-close]').click();
  const beforeRecoveryRead=calls.filter(x=>x.name==='lts_browser_card_cycles_v229').length;flags.cyclesFail=false;
  await invoiceRow.locator('.carddetailbtn').click();await flowDialog.locator('[data-v226-item]').first().waitFor();
  assert(calls.filter(x=>x.name==='lts_browser_card_cycles_v229').length>beforeRecoveryRead,'second click reads source again');
  assert.equal(await flowDialog.locator('[data-v226-item]').count(),2,'new click recovers after source failure');
  await flowDialog.locator('[data-v226-close]').click();
  flags.paymentStale=true;
  await frame.evaluate(()=>{window.__LTS_V227_TRANSPORT.invalidate();window.__LTS_V226.invalidate();});
  await invoiceRow.locator('.carddetailbtn').click();await flowDialog.locator('[data-v226-item]').first().waitFor();
  assert.match(await flowDialog.innerText(),/A fonte do pagamento mudou/);
  assert.doesNotMatch(await flowDialog.innerText(),/Emissor: pagamento integral informado/);
  assert.equal(await flowDialog.locator('[data-v226-item]').count(),2);
  await page.screenshot({path:'qa/v281-'+label+'-documentary-stale.png',fullPage:true});
  await captureTarget(flowDialog.locator('.v226-note').filter({hasText:'A fonte do pagamento mudou'}),'documentary-stale-target');
  await flowDialog.locator('[data-v226-close]').click();
  flags.paymentStale=false;
  await frame.evaluate(()=>{window.__LTS_V227_TRANSPORT.invalidate();window.__LTS_V226.invalidate();});

  await frame.locator('#d-2026-11-09 .exp').click();

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
  if(['v229-1','v230','v231','v235','v236','v240','v241','v242','v244','v245','v257','v258','v259','v260','v261','v262','v264','v269','v270','v271','v276','v282'].includes(process.env.LTS_RELEASE))assert(flowTimings.bank_change_ms<2000,'bank switching must not repeatedly format the current date');
  assert(Object.values(flowTimings).every(ms=>ms<4000),'controlled browser rendering must complete promptly '+JSON.stringify(flowTimings));
  await nav('Dashboard').click();flags.date='2026-09-21';await frame.evaluate(()=>{window.__TEST_NOW__='2026-09-21T13:00:00Z';render()});assert.equal(semantic(await kpi('Total disponível hoje').locator('strong').innerText()),'—','day rollover does not present stale complete total');await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.data?.as_of==='2026-09-21'&&window.__LTS_V178_STATE.cash.status==='ready');
  await frame.waitForFunction(()=>window.__LTS_V226?.cycles?.cards.length===5);
  await frame.locator('.v225-bankstatus summary').click();
  assert.match(await frame.locator('.v225-bankstatus').innerText(),/Recebimento e origem por banco/);
  assert.match(await frame.locator('.v168-dashboard').innerText(),/Calculado para/);
  await page.screenshot({path:'qa/v281-'+label+'-collection-origin-dashboard.png',fullPage:true});
  assert.equal(await frame.locator('.v182-expand-mark').count(),0,'redundant plus removed');
  if(viewport.width<=520)assert.equal(await nav('Patrimônio').innerText(),'Patrimônio','mobile label restored');
  assert.equal(await frame.locator('.v226-banks section').count(),3,'bank grouping');
  assert.equal(await frame.locator('.v226-card-line').count(),5,'five billing accounts, not additional-card duplicates');
  assert.match(await frame.locator('.v226-banks').innerText(),/Emissor: pagamento integral informado/);
  await page.screenshot({path:'qa/v281-'+label+'-documentary-summary.png',fullPage:true});
  await captureTarget(frame.locator('.v226-card-line').filter({hasText:'Emissor: pagamento integral informado'}),'documentary-summary-target');
  const paymentLine=frame.locator('.v226-card-line').filter({hasText:'Emissor: pagamento integral informado'});
  assert.match(await paymentLine.innerText(),/pagamento integral informado pelo emissor/);
  assert.doesNotMatch(await paymentLine.innerText(),/Em aberto|pagamento não informado|precisa ser conferida novamente/);
  await checkPresentationGeometry(paymentLine,'summary');
  const noteGeometry=await paymentLine.locator('.v226-note').evaluate(el=>{const r=el.getBoundingClientRect(),p=el.parentElement.getBoundingClientRect();return {left:r.left,right:r.right,parentLeft:p.left,parentRight:p.right,scroll:el.scrollWidth,width:el.clientWidth}});
  assert(noteGeometry.left>=noteGeometry.parentLeft-1&&noteGeometry.right<=noteGeometry.parentRight+1&&noteGeometry.scroll<=noteGeometry.width+1,'payment note contained '+JSON.stringify(noteGeometry));
  assert.match(await frame.locator('.v226-totals').first().innerText(),/2\.100,00/,'next invoice sum');
  await frame.locator('[data-v226-overview="next"]').click();
  assert.equal(await frame.locator('#v226-detail [data-v226-overview-row]').count(),3,'summary total opens every component');
  assert.match(await frame.locator('#v226-detail tfoot').innerText(),/2\.100,00/);
  await frame.locator('#v226-detail [data-v226-close]').click();
  assert.match(await frame.locator('.v226-card-line').filter({hasText:'Visa Infinite Prime'}).innerText(),/Sem fatura aberta informada/,'unreported is not zero debt');
  await frame.locator('[data-v226-family="aeternum"][data-v226-month="2026-10-01"]').first().click();
  await frame.waitForSelector('#v226-detail [data-v226-item]');
  assert.equal(await frame.locator('#v226-detail [data-v226-item]').count(),2);
  assert.match(await frame.locator('#v226-detail').innerText(),/Rafiki — Imagem e cuidados pessoais/);
  await frame.locator('#v226-detail .v226-classify summary').click();
  assert.equal(await frame.locator('#v226-detail select[name="category"] option[value="Lucas — Vestuário"]').innerText(),'Imagem e cuidados pessoais','display does not replace stored option value');
  const displayContract=await frame.evaluate(()=>({ready:!!window.LTSCategoryDisplay,flow:flowSemanticTitle({description:'Synthetic clothing',category:'Vestuário',center_cost:'Lucas'}),duplicate:flowSemanticTitle({description:'Synthetic health',category:'Benjamin — Saúde',center_cost:'Benjamin'}),rafiki:window.__LTS_V183_PERSONAL_IMAGE_LABELS.label('Rafiki — Vestuário')}));
  assert.deepEqual(displayContract,{ready:true,flow:'Imagem e cuidados pessoais',duplicate:'Benjamin — Saúde',rafiki:'Rafiki — Imagem e cuidados pessoais'});

  await page.screenshot({path:'qa/v270-'+label+'-category-targets.png',fullPage:true});
  const aggregate=await frame.evaluate(()=>({invoice:flowClassificationBadge({source:'card_invoice',description:'Fatura C6',signed_amount:-100}),unknownPurchase:flowClassificationBadge({description:'Compra sintética',category:'A classificar',signed_amount:-10}),meta:flowSemanticMeta({source:'card_invoice',description:'Fatura C6',signed_amount:-100})}));
  assert.equal(aggregate.invoice,'');assert(!aggregate.invoice.includes('flow-unclassified-link'));assert.match(aggregate.unknownPurchase,/A classificar · revisar/);assert.match(aggregate.meta,/composição e eventuais pendências/);
  await frame.locator('#v226-detail select[name="category"]').selectOption('Saúde');
  await frame.locator('#v226-detail select[name="beneficiary"]').selectOption('Lucas');
  await frame.locator('#v226-detail button[type="submit"]').click();
  await frame.waitForFunction(()=>!document.querySelector('#v226-detail [data-v226-classify]'));
  assert(calls.some(c=>c.name==='lts_browser_card_classify_v226'),'classification persisted through audited writer');
  await frame.locator('#v226-detail [data-v226-close]').click();
  await frame.waitForFunction(()=>window.__LTS_V226.cycles?.cards.length===5);
  await frame.waitForFunction(()=>!window.__LTS_V226.loading&&[window.__LTS_V178_STATE?.cash,window.__LTS_V178_STATE?.forecast,window.__LTS_V178_STATE?.dashboardReport].filter(Boolean).every(state=>state.status!=='loading'));
  await frame.locator('.v226-future summary').click();
  if(['v257','v258','v259','v260','v261','v262','v264','v269','v270','v271','v276','v282'].includes(process.env.LTS_RELEASE)){
   await frame.waitForFunction(()=>window.__LTS_V257_UI_STATE?.installed);
   await frame.evaluate(()=>render());
   await frame.waitForFunction(()=>document.querySelector('details.v226-future')?.open);
  }
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
  if(currentSource){await frame.locator('[data-v237-formula] summary').click();assert.match(await frame.locator('[data-v237-formula]').innerText(),/40,00.*30,00/s);assert.match(await frame.locator('[data-v237-excluded]').innerText(),/10,00/);}
  await frame.locator('#v226-detail .v226-alternative').filter({has:frame.locator('[data-v226-alternative-item]')}).locator('summary').click();
  assert.equal(await frame.locator('#v226-detail [data-v226-alternative-item]').count(),1,'bank merchant details remain available alongside monthly evidence');
  assert.match(await frame.locator('#v226-detail .v226-alternative').filter({has:frame.locator('[data-v226-alternative-item]')}).innerText(),/não somar novamente/);
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
  // A forced card retry invalidates the shared transport and restarts Dashboard readers.
  // Wait for that existing orchestration promise, not an arbitrary delay or one old DOM frame.
  await frame.evaluate(()=>window.__LTS_V178_REVIEW.ready());
  await frame.waitForFunction(()=>['cash','forecast','wealth','awards','dashboardReport'].every(k=>!['idle','loading'].includes(window.__LTS_V178_STATE[k].status)));
  const dims=await frame.locator('html').evaluate(e=>({width:e.clientWidth,scroll:e.scrollWidth}));assert(dims.scroll<=dims.width+3,'no horizontal page overflow');
  await frame.waitForFunction(()=>{const root=document.querySelector('.v168-dashboard');if(!root)return false;const nodes=['.current','.v227-liquidity','.v227-expenses'].map(s=>root.querySelector(s));if(nodes.some(n=>!n))return false;const tops=nodes.map(n=>n.getBoundingClientRect().top);return tops[0]<tops[1]&&tops[1]<tops[2]});
  const geometryState=await frame.locator('.v168-dashboard').evaluate(root=>{const nodes=['.current','.v227-liquidity','.v227-expenses'].map(selector=>{const e=root.querySelector(selector),r=e.getBoundingClientRect(),s=getComputedStyle(e);return {selector,top:r.top,left:r.left,width:r.width,height:r.height,display:s.display,visibility:s.visibility,parent:e.parentElement.className,connected:e.isConnected}});return {order:nodes.map(n=>n.top),nodes,view:V,contract:window.__LTS_V269_COMPLETENESS?.(),blocked:document.getElementById('app')?.dataset.v269Blocked,readers:Object.fromEntries(['cash','forecast','wealth','awards','dashboardReport'].map(k=>[k,window.__LTS_V178_STATE[k].status]))}});console.log('ORDER_DIAGNOSTIC',JSON.stringify({label,...geometryState}));const order=geometryState.order;assert(order[0]<order[1]&&order[1]<order[2],'balances, liquidity, expenses order: '+JSON.stringify(geometryState));assert.equal(await frame.locator('.v227-expenses .v226-upcoming').count(),1);assert.equal(await frame.locator('.v227-expenses .v171-expense-total').count(),1);
  assert.deepEqual(errors,[],'no uncaught errors');await page.screenshot({path:'qa/v229-'+label+'-dashboard.png'});
  assert.equal(candidateServed,1,'one exact candidate asset served per viewport');
  return{label,pass:true,candidateServed,candidateSha:'e76f4d63e81d435c16790fd0a9063bd895d96e042955f9bc3fe4ec5cc80bbf49',presentationGeometry,expense_last_month:true,card_inventory:true,payment_status:true,manual_edit_delete:true,scroll:geometry,freshness_geometry:provenanceGeometry,flow_render_timings:flowTimings,calls:calls.length,financial_data:'synthetic fixtures; live SQL checks separate'};
 }catch(error){console.error('ORIGINAL FAILURE',String(error.stack||error));await page.screenshot({path:'qa/v229-'+label+'-failure.png',fullPage:true}).catch(e=>console.error('SCREENSHOT FAILED',e.message));const expenseProbe=await frame?.evaluate(()=>{const p=window.__LTS_EXPENSE_DRAFT_PROBE;return p?{request:p.request,events:p.events,state:p.snapshot()}:null;}).catch(()=>null);if(expenseProbe)fs.writeFileSync('qa/v281-'+label+'-expense-draft-probe.json',JSON.stringify(expenseProbe,null,2));console.error(JSON.stringify({label,error:String(error.stack||error),errors,calls:calls.slice(-15),expenseProbe,state:await frame?.evaluate(()=>({cash:window.__LTS_V178_STATE?.cash,monthly:{error:window.__LTS_V175_STATE?.monthly?.error,count:window.__LTS_V175_STATE?.monthly?.data?.months?.length},detail:window.__LTS_V178_STATE?.detail?{group:window.__LTS_V178_STATE.detail.group,error:window.__LTS_V178_STATE.detail.error,rows:window.__LTS_V178_STATE.detail.rows.length}:null})).catch(()=>null)}));throw error}
 finally{await context.close()}
}
(async()=>{
 const hash=crypto.createHash('sha256').update(fs.readFileSync('index.html')).digest('hex');assert.equal(hash,'cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b');
 const browser=await chromium.launch({headless:true,...(process.env.LTS_CHROMIUM_PATH?{executablePath:process.env.LTS_CHROMIUM_PATH}:{} )});
 try{const results=[await run(browser,{width:1440,height:1000},'desktop'),await run(browser,{width:390,height:844},'mobile'),await run(browser,{width:320,height:760},'narrow')];const out={pass:true,version:'p05-shared-policy-presentation-on-v281',results};fs.writeFileSync('qa/v229-functional-result.json',JSON.stringify(out,null,2));console.log(JSON.stringify(out,null,2))}
 catch(e){fs.writeFileSync('qa/v229-functional-result.json',JSON.stringify({pass:false,error:String(e.stack||e)},null,2));process.exitCode=1}
 finally{await browser.close()}
})();

