'use strict';
const {chromium}=require('playwright');
const fs=require('node:fs');
const PORT=process.env.LTS_V164_PORT||'8780';
const BASE=`http://127.0.0.1:${PORT}`;

const cockpit={
  as_of:'2026-09-15',
  liquidity:{bank_cash:21781.29,d0:43016.64,through_d3:77627.90,d3_vested:12829.97,fgts_d30:22432.31,accounts:[{institution:'Itaú',balance:21735.75},{institution:'Bradesco',balance:45.54},{institution:'C6',balance:0}]},
  planning_audited:{first_negative_date:'2027-01-30',first_uncovered_gap_date:'2027-01-30',worst_before_brl:-26692.30,worst_before_date:'2027-01-30',management_point_date:'2026-12-30',fgts_request_by:'2026-11-30',worst_after_brl:-4259.99,covers_horizon:false,fgts_future_accrual_estimated:false},
  horizons:[
    {id:'30d',label:'30 dias',date:'2026-10-15',current_liquidity_balance:39911.55,conditional_rsu_balance:39911.55,restricted_total_balance:62343.86},
    {id:'90d',label:'90 dias',date:'2026-12-14',current_liquidity_balance:-33468.56,conditional_rsu_balance:5588.37,restricted_total_balance:28020.68},
    {id:'year_end',label:'Fim de 2026',date:'2026-12-31',current_liquidity_balance:-37401.58,conditional_rsu_balance:1655.35,restricted_total_balance:24087.66}
  ],
  expenses:{current_month:{spend:46458.15,top_categories:[{category:'Financiamentos',amount:18250},{category:'Saúde',amount:7200},{category:'Educação',amount:5912},{category:'Moradia',amount:5000}]},previous_month:{spend:50896.09}},
  cards:{open_cycles_total:24390.64,closed_or_due_total:0,next_due:{due_date:'2026-09-25',amount:24390.64,card_name:'Visa Aeternum'}},
  work:{actionable_count:2,top_actions:[{title:'Atualizar posição bancária',description:'Novo extrato disponível para conferência.'},{title:'Revisar documento',description:'Uma evidência aguarda sua confirmação.'}]}
};

const planning={
  period:{from:'2026-09-15',to:'2027-03-31'},
  summary:{first_real_gap_date:'2026-12-30',worst_balance:-26692.30,gap_episode_count:5,fgts_amount:22432.31,fgts_request_by:'2026-11-30',first_negative_even_with_fgts:'2027-01-30',fgts_covers_horizon:false},
  fgts_access:{amount_brl:22432.31,request_by_date:'2026-11-30',first_negative_even_with_fgts:'2027-01-30'},
  layers:[
    {order:1,label:'Caixa',liquidity:'imediato',starting_amount:21781.29,first_need_next_layer:'2026-09-25'},
    {order:2,label:'Cofrinho / D+0',liquidity:'D+0/D+1',starting_amount:43016.64,first_need_next_layer:'2026-10-25'},
    {order:3,label:'RSU disponível',liquidity:'D+3',starting_amount:12829.97,first_need_next_layer:'2026-11-08'},
    {order:4,label:'Novos vestings',liquidity:'condicional',starting_amount:0,first_need_next_layer:'2026-12-30'},
    {order:5,label:'FGTS',liquidity:'restrito D+30',starting_amount:22432.31,first_need_next_layer:'2027-01-30'}
  ],
  gap_episodes:[
    {start_date:'2026-12-30',end_date:'2026-12-30',days:1,recovery_date:'2026-12-31',worst_balance:-4202.26},
    {start_date:'2027-01-05',end_date:'2027-01-14',days:10,recovery_date:'2027-01-15',worst_balance:-15680.11},
    {start_date:'2027-01-20',end_date:'2027-01-30',days:11,recovery_date:'2027-01-31',worst_balance:-26692.30}
  ]
};

function product(){
  return {
    dashboard_cockpit:cockpit,planning_executive:planning,
    updates:{items:[],maintenance_checks:[],freshness:{position_as_of:'2026-09-15'}},semantic_review:{pending_groups:0,items:[]},card_classification_review:{pending_groups:0,pending_lines:0,pending_value:0,category_options:[],items:[]},
    card_operating:{as_of:'2026-09-15',closed_or_due_total:0,closed_or_due:[],open_cycles_total:24390.64,open_cycles:[{card_name:'Visa Aeternum',amount:24390.64,due_date:'2026-09-25',detail_preview:[{description:'Despesa documentada',amount:420}]}],next_due:cockpit.cards.next_due,contracted_installment_floor_total:43989.34,contracted_installment_floor_last_month:'2027-05-01',contracted_installment_floor_months:[{reference_month:'2026-10-01',amount:8200,detail:[{card_name:'Visa Aeternum',amount:8200,due_date:'2026-10-25'}]}],detail_coverage:{reconciled_invoices:8,detail_lines:118,zero_delta_invoices:8},classification_review:{pending_lines:0,pending_value:0,safe_suggestion_groups:0}},
    card_history:{monthly:Array.from({length:12},(_,i)=>({month:`2025-${String(i+10).padStart(2,'0')}-01`.replace('2025-13','2026-01').replace('2025-14','2026-02').replace('2025-15','2026-03').replace('2025-16','2026-04').replace('2025-17','2026-05').replace('2025-18','2026-06').replace('2025-19','2026-07').replace('2025-20','2026-08').replace('2025-21','2026-09'),total:22000+i*900}))},
    expense_drilldown:{rows:[{is_card:true,card_name:'Visa Aeternum',competence_month:'2026-09-01',category:'Saúde',amount:420}]},
    wealth_executive:{as_of:'2026-09-15',summary:{net_worth_central:3575688.83,net_worth_low:2950688.83,net_worth_high:4205688.83,assets_central:5470060.21,known_debt_total:1894371.38,known_debt_to_assets_pct:34.6,liquidity_through_d3:77627.90,restricted_contingency:22432.31,cipo_share_of_assets_pct:95},liquidity:{bank_cash:21781.29,d0:43016.64,d3:12829.97,fgts_contingency:22432.31,future_awards_excluded:1710218.18},assets:{cipo_396:{market_central:5200000,market_low:4600000,market_high:5900000,documentary_debt:1783878.57,equity_central:3416121.43,historical_purchase_plus_reform:3858960,asking_price:5900000,contract_final_due:'2041-01-20',loaded_exact_schedule_through:'2027-02-20',valuation_evidence:[]},volvo_xc40:{market_central:170000,market_low:145000,market_high:195000,documented_financed_balance:110492.81,equity_central:59507.19,future_schedule_total:170299.37,valuation_evidence:[]}},guardrails:[],scheduled_commitments_not_counted_as_current_debt:[]},
    duplicate_quality_gate:{},flow:{days:[],events:[]},expenses:{},wealth:{},planning:{},commitments:{commitments:[]},commitment_schedules:{contracts:[]},documentary_commitments:{items:[]}
  };
}

function expensePayload(from,to){
  const amount=value=>Math.round((Number(value)+Number.EPSILON)*100)/100;
  const monthly=[['2026-01-01',41000],['2026-02-01',43800],['2026-03-01',45500],['2026-04-01',47100],['2026-05-01',46200],['2026-06-01',48800],['2026-07-01',49600],['2026-08-01',50896.09],['2026-09-01',46458.15]].map(([month,total])=>{const account=amount(total*.55);return {month,total,account_total:account,card_total:amount(total-account),rows:12,is_partial:month==='2026-09-01',top_categories:[{name:'Financiamentos',total:amount(total*.4)},{name:'Saúde',total:amount(total*.2)}],category_detail_pct:76,transaction_detail_pct:70}});
  const selected=monthly.reduce((n,x)=>n+x.total,0);
  const window=(count)=>{const rows=monthly.slice(-count),total=amount(rows.reduce((n,x)=>n+x.total,0)),known=amount(total*.76);return {total,monthly_average:amount(total/rows.length),financing_total:amount(total*.4),known_category_total:known,category_known_total:known,category_unallocated_total:amount(total-known),category_detail_pct:76,transaction_detail_pct:70,top_categories:[{name:'Financiamentos',total:amount(total*.4)},{name:'Saúde',total:amount(total*.2)},{name:'Educação',total:amount(total*.12)}]}};
  const selectedAccount=amount(selected*.55),selectedKnown=amount(selected*.76);
  return {version:'expense-executive-v12-cached-effective-contract',period:{from,to,last_available:'2026-09-15',months_in_selection:monthly.length},summary:{selected_total:selected,account_total:selectedAccount,card_total:amount(selected-selectedAccount),monthly_average:amount(selected/monthly.length),history_total:752104.87},monthly_detail:monthly,yearly_detail:[{year:2025,total:580000,monthly_average:48333,comparison_pct:5,financing_total:170000,top_categories:[],category_detail_pct:72,transaction_detail_pct:66},{year:2026,total:selected,monthly_average:amount(selected/monthly.length),comparison_pct:-3,financing_total:amount(selected*.4),top_categories:[],category_detail_pct:76,transaction_detail_pct:70,is_partial_year:true}],rolling_windows:{'3m':window(3),'6m':window(6),'12m':window(9)},category_trends_12m:[],data_quality:{selected_category_unallocated_total:amount(selected-selectedKnown),selected_category_detail_pct:76,selected_transaction_detail_pct:70,selected_category_allocated_history_total:selectedKnown},source_precision:{notice:''}};
}

function flow(){
  const projectedGapDay={date:'2026-09-14',historical:true,reconciliation_gaps:{'Itaú':9828.72},'Itaú':{documentary_anchor_date:'2026-09-11',balance_basis:'documentary_close_plus_effective_movements'},Consolidado:{},fix86_columns:{}};
  return {from:'2026-09-10',to:'2026-10-15',available_year_from:2013,available_year_to:2041,historical:{days:[projectedGapDay],events:[]},current_future:{days:[],events:[]},bank_evidence_as_of:[{bank:'Itaú',date:'2026-09-11'}],version:'v164-fixture'};
}

async function frameReady(page,label){
  let frame;
  for(let i=0;i<200;i++){
    frame=page.frames().find(f=>{try{return new URL(f.url()).pathname.endsWith('/index.html')}catch{return false}});
    if(frame&&await frame.evaluate(()=>Boolean(document.querySelector('.v164-answer')&&window.__LTS_EXECUTIVE_VISUAL_SYSTEM?.installed)).catch(()=>false))return frame;
    await page.waitForTimeout(100);
  }
  await page.screenshot({path:`v164-${label}-failure.png`,fullPage:true});
  throw new Error(`${label} V164 frame not ready`);
}

async function run(browser,viewport,label,{loginAfterLoad=false}={}){
  const context=await browser.newContext({viewport});
  const session={access_token:'fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};
  if(!loginAfterLoad)await context.addInitScript(value=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(value)),session);
  const page=await context.newPage();
  page.setDefaultTimeout(15000);
  const errors=[],requested=[];page.on('pageerror',e=>errors.push(String(e.message||e)));
  await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
    const request=route.request(),name=new URL(request.url()).pathname.split('/').pop();requested.push(name);let body={ok:true};
    if(name==='token')body=session;
    else if(name==='lts_browser_product_v1')body={ok:true,mvp:product()};
    else if(name==='lts_browser_dashboard_cockpit_v1')body=cockpit;
    else if(name==='lts_browser_flow_v11')body={ok:true,flow:flow()};
    else if(name==='lts_browser_expense_executive_v3'){let args={};try{args=JSON.parse(request.postData()||'{}')}catch{}body=expensePayload(args.p_from||'2026-01-01',args.p_to||'2026-09-15')}
    else if(name==='lts_browser_expense_context_nature_v1')body={summary:{},contexts:[],categories:[],unassigned_states:[]};
    await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)});
  });
  await page.goto(`${BASE}/wip35-v164-candidate.html`,{waitUntil:'domcontentloaded',timeout:20000});
  if(loginAfterLoad){
    const loginFrame=page.frames().find(frame=>{try{return new URL(frame.url()).pathname.endsWith('/index.html')}catch{return false}});
    if(!loginFrame)throw new Error(`${label} login frame missing`);
    await loginFrame.locator('.login').waitFor({state:'visible',timeout:10000});
    if(await loginFrame.locator('.v164-dashboard').count())throw new Error(`${label} dashboard visible before login`);
    await loginFrame.locator('#email').fill('fixture@example.test');
    await loginFrame.locator('#password').fill('fixture-password');
    await loginFrame.locator('#signin').click();
  }
  const frame=await frameReady(page,label);
  const text=await frame.locator('.v164-dashboard').innerText();
  const normalizedText=text.toLocaleLowerCase('pt-BR');
  const answerMetrics=await frame.locator('.v164-answer-metrics .v164-metric').allInnerTexts();
  await page.screenshot({path:`v164-${label}.png`,fullPage:true});
  for(const needle of ['Tenho dinheiro suficiente?','Até 29/12/2026, sim. Depois, é preciso agir.','Sim · 30/12/2026','Com o FGTS','Falta em 30/01/2027','Data para agir','30/11/2026','Dinheiro em contas','Planejamento incorporado','Quando falta dinheiro e quando recupera'])if(!normalizedText.includes(needle.toLocaleLowerCase('pt-BR')))throw new Error(`${label} missing ${needle}; answer metrics=${JSON.stringify(answerMetrics)}; dashboard=${JSON.stringify(text.slice(0,1800))}`);
  if(answerMetrics.length!==4)throw new Error(`${label} expected four answer metrics, received ${JSON.stringify(answerMetrics)}`);
  if(await frame.locator('.v164-kpi').count()!==5)throw new Error(`${label} expected five KPIs`);
  const nav=label==='mobile'?frame.locator('#dx1MobileNav'):frame.locator('.nav');
  if(await nav.locator('button').count()!==6)throw new Error(`${label} navigation must have six routes`);
  if(await nav.getByText('Planejamento').count())throw new Error(`${label} duplicate Planning route visible`);
  const helper=await frame.evaluate(()=>({projected:window.__LTS_RECONCILIATION_NOTICE_ELIGIBLE({date:'2026-09-14',Itaú:{documentary_anchor_date:'2026-09-11',balance_basis:'documentary_close_plus_effective_movements'}},'Itaú',9828.72),sameDay:window.__LTS_RECONCILIATION_NOTICE_ELIGIBLE({date:'2026-09-11',Itaú:{documentary_anchor_date:'2026-09-11',balance_basis:'documentary_close'}},'Itaú',12.34)}));
  if(helper.projected!==false||helper.sameDay!==true)throw new Error(`${label} reconciliation notice gate ${JSON.stringify(helper)}`);
  const routeButton=route=>(label==='mobile'?frame.locator(`#dx1MobileNav [data-mobile-route="${route}"]`):frame.locator(`.nav [data-v="${route}"]`));
  await routeButton('Fluxo Diário').click();await frame.waitForFunction(()=>V==='Fluxo Diário');if(await frame.locator('#ltsReconciliationWarning').count())throw new Error(`${label} projected Itaú gap shown as documentary warning`);
  await routeButton('Despesas').click();
  try{await frame.locator('.v164-expenses .ex135-page').waitFor({state:'visible'});await frame.locator('.ex135-main').waitFor({state:'visible'})}
  catch(error){
    await page.screenshot({path:`v164-${label}-expenses-failure.png`,fullPage:true});
    const diagnostic=await frame.evaluate(()=>({route:typeof V==='undefined'?null:V,expenseStatus:window.__LTS_EXPENSE_SCREEN_ALIGNMENT||null,expenseState:window.EX135||null,main:document.getElementById('main')?.innerText?.slice(0,2200)||''}));
    throw new Error(`${label} Despesas did not load; requested=${JSON.stringify(requested)}; diagnostic=${JSON.stringify(diagnostic)}; cause=${String(error)}`);
  }
  if(label!=='post-login')await page.screenshot({path:`v164-${label}-expenses.png`,fullPage:true});
  await routeButton('Cartões').click();await frame.locator('.v164-cards .c111-head').waitFor({state:'visible'});if(!(await frame.locator('.v164-cards').innerText()).includes('Cada cartão em um lugar.'))throw new Error(`${label} rich Cards cockpit missing`);
  if(label!=='post-login')await page.screenshot({path:`v164-${label}-cards.png`,fullPage:true});
  await routeButton('Patrimônio').click();await frame.locator('.v164-wealth .v136').waitFor({state:'visible'});if(!(await frame.locator('.v164-wealth').innerText()).includes('Quanto você tem, quanto deve e quanto sobra.'))throw new Error(`${label} wealth cockpit missing`);
  if(label!=='post-login')await page.screenshot({path:`v164-${label}-wealth.png`,fullPage:true});
  await routeButton('Dashboard').click();await frame.locator('.v164-answer').waitFor({state:'visible'});
  const dims=await frame.locator('html').evaluate(el=>({scroll:el.scrollWidth,client:el.clientWidth}));if(dims.scroll>dims.client+3)throw new Error(`${label} horizontal overflow ${JSON.stringify(dims)}`);
  if(label==='desktop'){const rail=await frame.locator('.hdr').evaluate(el=>el.getBoundingClientRect().width);if(rail<220)throw new Error(`desktop rail too small ${rail}`)}
  await page.reload({waitUntil:'domcontentloaded'});const reloaded=await frameReady(page,label+'-reload');if(!await reloaded.locator('.v164-answer').isVisible())throw new Error(`${label} reload did not return to Dashboard`);
  if(errors.length)throw new Error(`${label} page errors ${JSON.stringify(errors)}`);
  await context.close();return {label,pass:true,viewport,dims,routes:6,dashboard_flow_reports_dashboard:true,reload:true,reconciliation_projection_warning:false,login_transition:loginAfterLoad?'signed-out-to-dashboard-without-reload':'preauthenticated',requested:[...new Set(requested)]};
}

(async()=>{
  const executablePath=process.env.LTS_CHROMIUM_EXECUTABLE||undefined;
  const browser=await chromium.launch({headless:true,...(executablePath?{executablePath}:{})});
  try{
    const results=[await run(browser,{width:1440,height:1000},'desktop'),await run(browser,{width:390,height:844},'mobile'),await run(browser,{width:1440,height:1000},'post-login',{loginAfterLoad:true})];
    const output={pass:true,version:'v164-complete-visual-cockpits',data:'controlled-fixture-not-user-data-validation',results};
    fs.writeFileSync('v164-complete-visual-result.json',JSON.stringify(output,null,2));console.log(JSON.stringify(output,null,2));
  }catch(error){const output={pass:false,error:String(error.stack||error),data:'controlled-fixture-not-user-data-validation'};fs.writeFileSync('v164-complete-visual-result.json',JSON.stringify(output,null,2));console.error(output.error);process.exitCode=1}
  finally{await browser.close()}
})();
