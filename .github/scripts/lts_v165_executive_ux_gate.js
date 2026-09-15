'use strict';
const {chromium}=require('playwright');
const fs=require('node:fs');
const PORT=process.env.LTS_V165_PORT||'8781';
const BASE=`http://127.0.0.1:${PORT}`;

const cockpit={
  as_of:'2030-06-15',
  liquidity:{bank_cash:48000,d0:12000,through_d3:78000,d3_vested:18000,fgts_d30:25000,accounts:[{institution:'Banco principal',balance:36000},{institution:'Banco secundário',balance:12000}]},
  planning_audited:{first_negative_date:'2031-01-25',first_uncovered_gap_date:'2031-01-25',worst_before_brl:-18000,worst_before_date:'2031-01-25',management_point_date:'2030-12-20',fgts_request_by:'2030-11-20',worst_after_brl:-3000,covers_horizon:false,fgts_future_accrual_estimated:false},
  horizons:[
    {id:'30d',label:'30 dias',date:'2030-07-15',current_liquidity_balance:52000,conditional_rsu_balance:52000,restricted_total_balance:77000},
    {id:'90d',label:'90 dias',date:'2030-09-13',current_liquidity_balance:27000,conditional_rsu_balance:39000,restricted_total_balance:64000},
    {id:'year_end',label:'Fim de 2030',date:'2030-12-31',current_liquidity_balance:-12000,conditional_rsu_balance:6000,restricted_total_balance:31000}
  ],
  expenses:{current_month:{spend:32000,top_categories:[{category:'Financiamentos',amount:12000},{category:'Saúde',amount:5000},{category:'Benjamin - Educação',amount:4200},{category:'Moradia',amount:3800}]},previous_month:{spend:35000}},
  cards:{open_cycles_total:9000,closed_or_due_total:0,next_due:{due_date:'2030-06-25',amount:9000,card_name:'Cartão principal'}},
  work:{actionable_count:2,top_actions:[{title:'Atualizar posição bancária',description:'Novo extrato disponível para conferência.'},{title:'Revisar documento',description:'Uma evidência aguarda sua confirmação.'}]}
};

const planning={
  period:{from:'2030-06-15',to:'2031-03-31'},
  summary:{first_real_gap_date:'2030-12-20',worst_balance:-18000,gap_episode_count:3,fgts_amount:25000,fgts_request_by:'2030-11-20',first_negative_even_with_fgts:'2031-01-25',fgts_covers_horizon:false},
  fgts_access:{amount_brl:25000,request_by_date:'2030-11-20',first_negative_even_with_fgts:'2031-01-25'},
  gap_episodes:[{start_date:'2030-12-20',end_date:'2030-12-20',days:1,recovery_date:'2030-12-21',worst_balance:-4000}]
};

const wealth={
  version:'wealth-detail-v3-private-awards-v165',as_of:'2030-06-15',
  wealth:{as_of:'2030-06-15',summary:{net_worth_central:1450000,net_worth_low:1250000,net_worth_high:1650000,assets_central:1900000,known_debt_total:450000,known_debt_to_assets_pct:23.7,liquidity_through_d3:78000,restricted_contingency:25000,future_awards_excluded:420000},liquidity:{bank_cash:48000,d0:12000,d3:18000,fgts_contingency:25000},assets:{cipo_396:{market_central:1700000,market_low:1500000,market_high:1900000,documentary_debt:400000,equity_central:1300000,historical_purchase_plus_reform:900000},volvo_xc40:{market_central:120000,market_low:105000,market_high:135000,documented_financed_balance:50000,equity_central:70000,future_schedule_total:76000}}},
  rsu:{vested_positions:[{asset_name:'Ações adquiridas',as_of:'2030-06-15',units:120,unit_price:25,fx_rate:5,value_brl:15000,liquidity_class:'D+3'}],future_schedule:[
    {group_key:'rsu:2030-11-02',award_ids:['award-a'],asset_type:'RSU',eligibility_date:'2030-11-02',available_date:'2030-11-05',quantity:180,gross_value_brl:22500,net_value_brl:22500,unit_price_usd:25,fx_rate:5},
    {group_key:'rsu:2030-11-09',award_ids:['award-b'],asset_type:'RSU',eligibility_date:'2030-11-09',available_date:'2030-11-12',quantity:220,gross_value_brl:27500,net_value_brl:27500,unit_price_usd:25,fx_rate:5},
    {group_key:'rsu:2031-03-10',award_ids:['award-c'],asset_type:'RSU',eligibility_date:'2031-03-10',available_date:'2031-03-13',quantity:240,gross_value_brl:30000,net_value_brl:30000,unit_price_usd:25,fx_rate:5},
    {group_key:'rsu:2031-03-15',award_ids:['award-d','award-e'],asset_type:'RSU',eligibility_date:'2031-03-15',available_date:'2031-03-18',quantity:600,gross_value_brl:75000,net_value_brl:75000,unit_price_usd:25,fx_rate:5},
    {group_key:'rsu:2031-11-02',award_ids:['award-f'],asset_type:'RSU',eligibility_date:'2031-11-02',available_date:'2031-11-05',quantity:180,gross_value_brl:22500,net_value_brl:22500,unit_price_usd:25,fx_rate:5},
    {group_key:'rsu:2032-03-15',award_ids:['award-g','award-h'],asset_type:'RSU',eligibility_date:'2032-03-15',available_date:'2032-03-18',quantity:650,gross_value_brl:81250,net_value_brl:81250,unit_price_usd:25,fx_rate:5},
    {group_key:'rsu:2033-03-15',award_ids:['award-i'],asset_type:'RSU',eligibility_date:'2033-03-15',available_date:'2033-03-18',quantity:500,gross_value_brl:62500,net_value_brl:62500,unit_price_usd:25,fx_rate:5},
    {group_key:'cash_rsu:2031-02-10',award_ids:['cash-a'],asset_type:'Cash RSU',eligibility_date:'2031-02-10',available_date:'2031-02-13',quantity:300,gross_value_brl:37500,net_value_brl:26250,unit_price_usd:25,fx_rate:5},
    {group_key:'cash_rsu:2032-02-10',award_ids:['cash-b'],asset_type:'Cash RSU',eligibility_date:'2032-02-10',available_date:'2032-02-13',quantity:300,gross_value_brl:37500,net_value_brl:26250,unit_price_usd:25,fx_rate:5},
    {group_key:'cash_rsu:2033-02-10',award_ids:['cash-c'],asset_type:'Cash RSU',eligibility_date:'2033-02-10',available_date:'2033-02-13',quantity:300,gross_value_brl:37500,net_value_brl:26250,unit_price_usd:25,fx_rate:5}
  ],future_schedule_count:10},
  employment_awards:{retention:{label:'Retention Award',gross_total_brl:90000,installments:[{sequence:1,label:'1/3 no Closing',detail:'pagamento em até 30 dias',share:0.3333333333},{sequence:2,label:'1/3 após 4,5 meses',detail:'contados do Closing',share:0.3333333333},{sequence:3,label:'1/3 após 9 meses',detail:'contados do Closing',share:0.3333333334}],note:'O Fluxo mantém somente as parcelas documentadas.'},retention_projected_events:[{id:'event-a',date:'2031-01-31',amount:21000},{id:'event-b',date:'2031-06-30',amount:21000},{id:'event-c',date:'2031-11-30',amount:21000}]},
  volvo_financing:{installment_amount:2000,next_due:'2030-07-08',remaining_installments:38,future_schedule_total:76000},
  documentary_commitments:{items:[{commitment_id:'home',label:'Imóvel · banco',debt_balance:400000,schedule_loaded:{next_date:'2030-07-20',next_amount:6500}}]}
};

function product(){return {
  dashboard_cockpit:cockpit,planning_executive:planning,wealth_executive:wealth.wealth,
  updates:{items:[{id:'bank-update',priority:1,type:'document_request',title:'Atualizar posição bancária',detail:'Novo extrato disponível para conferência.'}],maintenance_checks:[],freshness:{position_as_of:'2030-06-14'}},
  semantic_review:{pending_groups:0,items:[]},card_classification_review:{pending_groups:0,pending_lines:0,pending_value:0,category_options:[],items:[]},expense_universe_qa:{bank_documented_through:'2030-06-14'},
  card_operating:{as_of:'2030-06-15',closed_or_due_total:0,closed_or_due:[],open_cycles_total:9000,open_cycles:[{card_name:'Cartão principal',amount:9000,due_date:'2030-06-25',detail_preview:[{description:'Despesa documentada',amount:300}]}],next_due:cockpit.cards.next_due,contracted_installment_floor_total:16000,contracted_installment_floor_last_month:'2031-02-01',contracted_installment_floor_months:[{reference_month:'2030-07-01',amount:3000,detail:[{card_name:'Cartão principal',amount:3000,due_date:'2030-07-25'}]},{reference_month:'2030-08-01',amount:900,detail:[{card_name:'Cartão secundário',amount:900,due_date:'2030-08-08'}]}],detail_coverage:{reconciled_invoices:6,detail_lines:72,zero_delta_invoices:6},classification_review:{pending_lines:0,pending_value:0,safe_suggestion_groups:0}},
  card_history:{monthly:[['2029-07-01',21000],['2029-08-01',23500],['2029-09-01',22000],['2029-10-01',24500],['2029-11-01',23000],['2029-12-01',25500],['2030-01-01',24000],['2030-02-01',26000],['2030-03-01',22500],['2030-04-01',27000],['2030-05-01',25000],['2030-06-01',24000]].map(([month,total])=>({month,total}))},
  expense_drilldown:{rows:[{event_date:'2030-06-03',transaction_date:'2030-06-03',is_card:true,card_name:'Cartão principal',category:'Benjamin - Educação',center_cost:'Benjamin',counterparty:'Escola',amount:4200}]},
  wealth:{asset_layers:{derived_future_schedule:wealth.rsu.future_schedule}},flow:{days:[],events:[]},expenses:{},commitments:{commitments:[]},documentary_commitments:wealth.documentary_commitments
}};

function expensePayload(from,to){
  const round=value=>Math.round((Number(value)+Number.EPSILON)*100)/100;
  const monthly=[['2029-10-01',28000],['2029-11-01',29500],['2029-12-01',31000],['2030-01-01',30000],['2030-02-01',32000],['2030-03-01',30500],['2030-04-01',33500],['2030-05-01',35000],['2030-06-01',32000]].map(([month,total])=>{const account=round(total*.55);return {month,total,account_total:account,card_total:round(total-account),rows:12,is_partial:month==='2030-06-01',top_categories:[{name:'Financiamento imobiliário',total:round(total*.4)},{name:'Saúde',total:round(total*.2)},{name:'Benjamin - Educação',total:round(total*.12)}],category_detail_pct:76,transaction_detail_pct:70}});
  const selected=round(monthly.reduce((sum,row)=>sum+row.total,0));
  const window=count=>{const rows=monthly.slice(-count),sum=round(rows.reduce((value,row)=>value+row.total,0)),known=round(sum*.76);return {total:sum,monthly_average:round(sum/rows.length),financing_total:round(sum*.4),known_category_total:known,category_known_total:known,category_unallocated_total:round(sum-known),category_detail_pct:76,transaction_detail_pct:70,top_categories:[{name:'Financiamento imobiliário',total:round(sum*.4)},{name:'Saúde',total:round(sum*.2)},{name:'Benjamin - Educação',total:round(sum*.12)},{name:'Moradia',total:round(sum*.08)}]}};
  const account=round(selected*.55),known=round(selected*.76);
  return {version:'expense-executive-v12-cached-effective-contract',period:{from,to,last_available:'2030-06-15',months_in_selection:monthly.length},summary:{selected_total:selected,account_total:account,card_total:round(selected-account),monthly_average:round(selected/monthly.length),history_total:400000},monthly_detail:monthly,yearly_detail:[],rolling_windows:{'3m':window(3),'6m':window(6),'12m':window(9)},category_trends_12m:[],data_quality:{selected_category_unallocated_total:round(selected-known),selected_category_detail_pct:76,selected_transaction_detail_pct:70,selected_category_allocated_history_total:known},source_precision:{notice:''}};
}

function flow(){return {from:'2030-06-10',to:'2030-07-15',available_year_from:2013,available_year_to:2041,historical:{days:[{date:'2030-06-14',historical:true,reconciliation_gaps:{'Itaú':4321.09},'Itaú':{documentary_anchor_date:'2030-06-14',balance_basis:'documentary_close_plus_effective_movements'},Consolidado:{},fix86_columns:{}}],events:[]},current_future:{days:[],events:[]},bank_evidence_as_of:[{bank:'Itaú',date:'2030-06-14'}],version:'v165-fixture'};}

async function frameReady(page,label){
  for(let attempt=0;attempt<240;attempt++){
    const frame=page.frames().find(candidate=>{try{return new URL(candidate.url()).pathname.endsWith('/index.html')}catch{return false}});
    if(frame&&await frame.evaluate(()=>Boolean(document.querySelector('.v165-dashboard')&&window.__LTS_EXECUTIVE_VISUAL_SYSTEM_V2?.installed)).catch(()=>false))return frame;
    await page.waitForTimeout(100);
  }
  await page.screenshot({path:`v165-${label}-failure.png`,fullPage:true});throw new Error(`${label}: V165 frame not ready`);
}

async function run(browser,viewport,label,{loginAfterLoad=false}={}){
  const context=await browser.newContext({viewport});
  const session={access_token:'fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};
  if(!loginAfterLoad)await context.addInitScript(value=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(value)),session);
  const page=await context.newPage();page.setDefaultTimeout(18000);const errors=[],requested=[];page.on('pageerror',error=>errors.push(String(error.message||error)));
  await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
    const request=route.request(),name=new URL(request.url()).pathname.split('/').pop();requested.push(name);let body={ok:true};
    if(name==='token')body=session;
    else if(name==='lts_browser_product_v1')body={ok:true,mvp:product()};
    else if(name==='lts_browser_dashboard_cockpit_v1')body=cockpit;
    else if(name==='lts_browser_flow_v11')body={ok:true,flow:flow()};
    else if(name==='lts_browser_expense_executive_v3'){let args={};try{args=JSON.parse(request.postData()||'{}')}catch{}body=expensePayload(args.p_from||'2030-01-01',args.p_to||'2030-06-15')}
    else if(name==='lts_browser_expense_context_nature_v1')body={summary:{},contexts:[],categories:[],unassigned_states:[]};
    else if(name==='lts_browser_wealth_detail_v2')body=wealth;
    else if(name==='lts_browser_transactions_v2')body={ok:true,total:3,rows:[{date:'2031-11-30',description:'Retention Award',account:'Conta principal',category:'Receita futura',center_cost:'Trabalho',amount:21000},{date:'2031-06-30',description:'Retention Award',account:'Conta principal',category:'Receita futura',center_cost:'Trabalho',amount:21000},{date:'2031-01-31',description:'Retention Award',account:'Conta principal',category:'Receita futura',center_cost:'Trabalho',amount:21000}]};
    else if(name==='lts_browser_save_vesting_anticipation_v1')body={ok:true,saved:true,group_key:'rsu:2030-11-02',anticipated_date:'2030-10-15',scenario:{current_model:{first_negative_date:'2030-12-20',worst_balance:-18000},scenario:{first_negative_date:'2031-01-05',worst_balance:-9000},selected_amount_brl:22500,guardrail:'cenário somente'}};
    await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)});
  });
  await page.goto(`${BASE}/wip35-v165-candidate.html`,{waitUntil:'domcontentloaded',timeout:20000});
  if(loginAfterLoad){const loginFrame=page.frames().find(frame=>{try{return new URL(frame.url()).pathname.endsWith('/index.html')}catch{return false}});if(!loginFrame)throw Error(`${label}: login frame missing`);await loginFrame.locator('.login').waitFor({state:'visible'});await loginFrame.locator('#email').fill('fixture@example.test');await loginFrame.locator('#password').fill('fixture-password');await loginFrame.locator('#signin').click()}
  const frame=await frameReady(page,label);
  const dashboardText=await frame.locator('.v165-dashboard').innerText();
  const dashboardKpis=await frame.locator('.v165-dashboard .v165-kpi').allInnerTexts();
  await page.screenshot({path:`v165-${label}-dashboard.png`,fullPage:true});
  for(const phrase of ['Coberto até 19/12/2030','primeiro dia negativo em 20/12/2030','Resgatar FGTS até 20/11/2030','nova falta em 25/01/2031','Dinheiro em contas','Contas + curto prazo','RSUs vested','FGTS','Despesas do mês','Dados até 14/06/2030'])if(!dashboardText.includes(phrase))throw Error(`${label}: dashboard missing ${phrase}; kpis=${JSON.stringify(dashboardKpis)}`);
  for(const forbidden of ['Tenho dinheiro suficiente?','Cenário-base operacional','Planejamento incorporado'])if(dashboardText.includes(forbidden))throw Error(`${label}: dashboard leaked ${forbidden}`);
  if(await frame.locator('.v165-kpis>.v165-kpi').count()!==5)throw Error(`${label}: dashboard KPI count`);
  if(await frame.locator('.v165-grid.dashboard-main>.v165-card').count()!==3)throw Error(`${label}: reference main row missing`);
  if(await frame.locator('.v165-grid.dashboard-lower>.v165-card').count()!==3)throw Error(`${label}: reference lower row missing`);
  const nav=label==='mobile'?frame.locator('#dx1MobileNav'):frame.locator('.nav');if(await nav.locator('button').count()!==5)throw Error(`${label}: expected five navigation routes`);
  if(await nav.getByText('Cartões',{exact:true}).count()||await nav.getByText('Planejamento',{exact:true}).count())throw Error(`${label}: duplicate top-level route`);
  if(!(await frame.locator('.brand small').innerText()).includes('V165'))throw Error(`${label}: visible V165 missing`);
  const route=routeName=>label==='mobile'?frame.locator(`#dx1MobileNav [data-mobile-route="${routeName}"]`):frame.locator(`.nav [data-v="${routeName}"]`);
  await route('Fluxo Diário').click();await frame.waitForFunction(()=>V==='Fluxo Diário');if(await frame.locator('#ltsReconciliationWarning').count())throw Error(`${label}: projected Itaú warning visible`);
  await route('Despesas').click();await frame.locator('.v165-expenses').waitFor({state:'visible'});await frame.locator('.v165-expenses .v165-kpi').first().waitFor({state:'visible'});let text=await frame.locator('.v165-expenses').innerText();for(const phrase of ['Visão geral','Categorias','Cartões','Lançamentos','Classificação revisada','100%','cobertura documental'])if(!text.includes(phrase))throw Error(`${label}: expenses missing ${phrase}`);
  await frame.locator('[data-v165-expense-tab="categories"]').click();text=await frame.locator('.v165-expenses').innerText();if(!text.includes('Benjamin')||!text.includes('Educação'))throw Error(`${label}: Benjamin hierarchy missing`);
  await frame.locator('[data-v165-expense-tab="cards"]').click();text=await frame.locator('.v165-expenses').innerText();for(const phrase of ['Faturas abertas','Uso mensal dos cartões','Cartão principal','Uma compra, uma despesa.'])if(!text.includes(phrase))throw Error(`${label}: cards-in-expenses missing ${phrase}`);
  if(label!=='post-login')await page.screenshot({path:`v165-${label}-expenses.png`,fullPage:true});
  await route('Patrimônio').click();await frame.locator('.v165-wealth').waitFor({state:'visible'});await frame.locator('[data-v165-wealth-tab="rsu"]').click();await frame.locator('.v165-award').first().waitFor({state:'visible'});text=await frame.locator('.v165-wealth').innerText();for(const phrase of ['RSUs e awards','RSU já vested','Cash RSUs · líquido','70% após imposto de 30%','100% bruto; sem corte automático','02/11/2030','10/02/2031','15/03/2033','Retention Award','R$ 90.000,00','Tratamento separado.'])if(!text.includes(phrase))throw Error(`${label}: wealth missing ${phrase}`);
  if(await frame.locator('.v165-award').count()!==10)throw Error(`${label}: expected ten vesting rows`);
  if(label==='desktop'){const first=frame.locator('.v165-award').first(),input=first.locator('input[type="date"]');await input.fill('2030-10-15');await first.locator('[data-v165-award-save]').click();await first.locator('.v165-scenario-result').waitFor({state:'visible'});if(!(await first.innerText()).includes('Com antecipação'))throw Error('desktop: anticipation result missing')}
  if(label!=='post-login')await page.screenshot({path:`v165-${label}-wealth.png`,fullPage:true});
  await route('Atualizações').click();await frame.locator('#v165SearchInput').fill('retention');await frame.waitForFunction(()=>window.__LTS_V165_STATE?.search?.loading===false&&window.__LTS_V165_STATE?.search?.total===3);text=await frame.locator('.v165-updates').innerText();for(const phrase of ['Encontre sem saber a data','Data e valor são opcionais','Retention Award','R$ 21.000,00','Classificação concluída no escopo revisado'])if(!text.includes(phrase))throw Error(`${label}: updates search missing ${phrase}`);
  if(await frame.locator('.v165-search input[type="date"]').count())throw Error(`${label}: search incorrectly requires date`);
  if(label!=='post-login')await page.screenshot({path:`v165-${label}-updates.png`,fullPage:true});
  const dims=await frame.locator('html').evaluate(element=>({scroll:element.scrollWidth,client:element.clientWidth}));if(dims.scroll>dims.client+3)throw Error(`${label}: horizontal overflow ${JSON.stringify(dims)}`);
  if(label==='desktop'){const rail=await frame.locator('.hdr').evaluate(element=>element.getBoundingClientRect().width),dashboardHeight=await frame.locator('.v165-dashboard').evaluate(element=>element.getBoundingClientRect().height);if(rail<215||rail>225)throw Error(`desktop: rail ${rail}`);if(dashboardHeight>1160)throw Error(`desktop: dashboard too verbose ${dashboardHeight}`)}
  await page.reload({waitUntil:'domcontentloaded'});const reloaded=await frameReady(page,label+'-reload');if(!await reloaded.locator('.v165-dashboard').isVisible())throw Error(`${label}: reload did not return Dashboard`);
  if(errors.length)throw Error(`${label}: page errors ${JSON.stringify(errors)}`);
  await context.close();return {label,pass:true,viewport,routes:5,reference_structure:true,flow_preserved:true,search_without_date:true,rsu_rules:true,reload:true,login_transition:loginAfterLoad?'signed-out-to-dashboard-without-reload':'preauthenticated',requested:[...new Set(requested)]};
}

(async()=>{
  const executablePath=process.env.LTS_CHROMIUM_EXECUTABLE||undefined,browser=await chromium.launch({headless:true,...(executablePath?{executablePath}:{})});
  try{const results=[await run(browser,{width:1440,height:1000},'desktop'),await run(browser,{width:390,height:844},'mobile'),await run(browser,{width:1440,height:1000},'post-login',{loginAfterLoad:true})],output={pass:true,version:'v165-executive-ux-rsu',data:'controlled-fixture-not-user-data-validation',results};fs.writeFileSync('v165-executive-ux-result.json',JSON.stringify(output,null,2));console.log(JSON.stringify(output,null,2))}
  catch(error){const output={pass:false,error:String(error.stack||error),data:'controlled-fixture-not-user-data-validation'};fs.writeFileSync('v165-executive-ux-result.json',JSON.stringify(output,null,2));console.error(output.error);process.exitCode=1}
  finally{await browser.close()}
})();
