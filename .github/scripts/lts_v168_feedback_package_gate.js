'use strict';
const {chromium}=require('playwright');
const fs=require('node:fs');
const {BASE,cockpit,wealth,product,expensePayload,semantic}=require('./lts_v165_executive_ux_gate.js');

const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const session={access_token:'fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};

function flowFixture(){
  const row=(date,bank,base,vested,fgts)=>({date,Consolidado:{bank_balance:bank},fix86_columns:{saldo_apos_d0_1:base,saldo_apos_rsu:vested,saldo_apos_fgts:fgts}});
  return {ok:true,flow:{from:'2030-06-15',to:'2031-12-31',historical:{days:[],events:[]},current_future:{days:[
    row('2030-06-15',48000,60000,78000,103000),
    row('2030-09-30',42000,24000,44000,69000),
    row('2030-12-20',18000,-5000,12000,37000),
    row('2030-12-31',17000,-7000,9000,34000),
    row('2031-03-10',15000,-8000,-2000,23000),
    row('2031-06-30',14000,-9000,-3000,19000),
    row('2031-12-31',12000,-12000,-4000,11000)
  ],events:[
    {event_date:'2030-06-25',description:'Visa Aeternum',account:'Bradesco',signed_amount:-9000},
    {event_date:'2030-06-30',description:'Salário',account:'Itaú',signed_amount:21000}
  ]},bank_evidence_as_of:[{bank:'Itaú',date:'2030-06-15'}],version:'v168-fixture'}};
}

function expenseFixture(from,to){
  const base=expensePayload(from,to),years=[];
  for(let year=2013;year<=2030;year++)years.push({year,total:(year-2012)*12000,monthly_average:(year-2012)*1000,months:12});
  base.period={from,to,last_available:'2030-06-15',months_in_selection:base.monthly_detail.length||1};
  base.yearly_detail=years;
  base.rankings={categories:[
    {name:'Financiamento imobiliário',total:170000},
    {name:'Obra e reforma · CIPÓ 396',total:140000},
    {name:'Saúde',total:46000},
    {name:'Educação',total:42000}
  ],centers:[{name:'Casa',total:310000},{name:'Benjamin',total:77000},{name:'Lucas',total:39000}]};
  return base;
}

function contextFixture(){return {contexts:[
  {name:'Benjamin',total:77000,categories:[{name:'Educação',total:42000},{name:'Saúde',total:35000}]},
  {name:'Casa',total:310000,categories:[{name:'Financiamento imobiliário',total:170000},{name:'Obra e reforma · CIPÓ 396',total:140000}]},
  {name:'Lucas',total:39000,categories:[{name:'Saúde',total:11000},{name:'Outros',total:28000}]}
]};}

function wealthFixture(){
  const future=wealth.rsu.future_schedule;
  return {...wealth,
    as_of:'2030-06-15',
    wealth:{...wealth.wealth,liquidity:{bank_cash:48000,d0:12000,d3:18000,fgts_contingency:25000},summary:{...wealth.wealth.summary,restricted_contingency:25000},assets:{
      cipo_396:{market_central:1700000,documentary_debt:400000,equity_central:1300000,historical_purchase_plus_reform:900000},
      volvo_xc40:{market_central:120000,documented_financed_balance:50000,equity_central:70000}
    }},
    wealth_v167:{net_worth_central_including_pensions:1600000,assets_central_including_pensions:2050000},
    rsu_summary:{as_of:'2030-06-15',vested_shares_brl:15000,brokerage_cash_brl:2500,available_total_brl:17500,future_regular_brl:321250,future_cash_net_brl:78750,future_considered_total_brl:400000},
    pensions:{total_gross_brl:150000,positions:[
      {name:'Organon Multiprev',as_of:'2030-06-14',gross_balance_brl:100000,participant_balance_brl:60000,sponsor_balance_brl:40000,profile:'Moderado'},
      {name:'Novartis Previ Plano D',as_of:'2030-05-31',gross_balance_brl:50000,participant_balance_brl:30000,sponsor_balance_brl:20000,profile:'Moderado'}
    ]},
    rsu:{...wealth.rsu,future_schedule:future},
    financing:{summary:{commitments:[
      {id:'cipo_396',label:'CIPÓ 396',current_documentary_debt_balance:400000,current_debt_as_of:'2030-06-14',remaining_scheduled_outflow_current_terms:900000,total_events:360,remaining_events:300},
      {id:'volvo',label:'Volvo XC40',current_documentary_debt_balance:50000,current_debt_as_of:'2030-06-01',remaining_scheduled_outflow_current_terms:76000,total_events:48,remaining_events:38},
      {id:'coopharma',label:'Coopharma',current_documentary_debt_balance:null,remaining_scheduled_outflow_current_terms:30000,total_events:24,remaining_events:12},
      {id:'pai_mae',label:'Pai e Mãe',current_documentary_debt_balance:80000,current_debt_as_of:'2030-06-15',remaining_scheduled_outflow_current_terms:80000,total_events:20,remaining_events:10}
    ]},documentary:{items:[]}},
    cipo_detail:{historical_purchase_plus_reform_brl:900000,current_payoff_brl:400000,contractual_outflow_current_terms_brl:900000,components:[
      {component_class:'historical_basis_summary',description:'Compra Imóvel (pago)',source_paid:300000},
      {component_class:'historical_basis_summary',description:'Reformas',source_paid:600000},
      {component_class:'improvement',category:'Marcenaria',description:'Armários',source_paid:250000,origin:'Planilha de obra'},
      {component_class:'improvement',category:'Projeto',description:'Arquitetura',source_paid:150000,origin:'Planilha de obra'},
      {component_class:'improvement',category:'Mão de obra',description:'Execução',source_paid:200000,origin:'Planilha de obra'}
    ]}
  };
}

function productFixture(){
  const data=product();
  data.card_operating={as_of:'2030-06-15',open_cycles_total:18000,open_cycles:[
    {card_name:'Visa Aeternum',account:'Bradesco',amount:9000,due_date:'2030-06-25',detail_preview:[{description:'Assinatura',category:'Assinaturas',amount:300}]},
    {card_name:'Personnalite Black',account:'Itaú',amount:7000,due_date:'2030-07-08',detail_preview:[{description:'Mercado',category:'Alimentação',amount:700}]},
    {card_name:'Cartão C6',account:'C6',amount:2000,due_date:'2030-07-12',detail_preview:[{description:'Transporte',category:'Transporte',amount:200}]}
  ],closed_or_due_total:0,closed_or_due:[],paid_recent:[],contracted_installment_floor_total:6500,contracted_installment_floor_months:[
    {reference_month:'2030-07-01',amount:4000,detail:[{card_name:'Visa Aeternum'},{card_name:'Personnalite Black'}]},
    {reference_month:'2030-08-01',amount:2500,detail:[{card_name:'Cartão C6'}]}
  ],classification_review:{pending_lines:0,pending_value:0}};
  return data;
}

async function frameReady(page){
  for(let attempt=0;attempt<180;attempt++){
    const frame=page.frames().find(candidate=>{try{return new URL(candidate.url()).pathname.endsWith('/index.html')}catch{return false}});
    if(frame&&await frame.evaluate(()=>Boolean(window.__LTS_V168_COMPLETE_REVIEW?.installed&&document.querySelector('.v168-dashboard'))).catch(()=>false))return frame;
    await page.waitForTimeout(100);
  }
  throw new Error('V168 frame did not become ready');
}

async function run(browser,viewport,label){
  const context=await browser.newContext({viewport});
  await context.addInitScript(fixed=>{const NativeDate=Date,fixedMs=NativeDate.parse(fixed);class FixedDate extends NativeDate{constructor(...args){super(...(args.length?args:[fixedMs]))}static now(){return fixedMs}}window.Date=FixedDate},'2030-06-15T12:00:00Z');
  await context.addInitScript(value=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(value)),session);
  const page=await context.newPage();page.setDefaultTimeout(22000);const errors=[],requested=[],calls={};
  page.on('pageerror',error=>errors.push(String(error.message||error)));
  await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
    const request=route.request(),name=new URL(request.url()).pathname.split('/').pop();requested.push(name);calls[name]=(calls[name]||0)+1;let args={};try{args=JSON.parse(request.postData()||'{}')}catch{}let body={ok:true};
    if(name==='token')body=session;
    else if(name==='lts_browser_product_v1')body={ok:true,mvp:productFixture()};
    else if(name==='lts_browser_dashboard_cockpit_v1')body=cockpit;
    else if(name==='lts_browser_flow_v11'){
      if(calls[name]===1)return route.fulfill({status:503,contentType:'application/json',body:JSON.stringify({message:'temporary fixture failure'})});
      body=flowFixture();
    }
    else if(name==='lts_browser_expense_executive_v4'){
      if(String(args.p_from||'').startsWith('2030-01'))await wait(500);
      if(String(args.p_from||'').startsWith('2029-'))await wait(900);
      body=expenseFixture(args.p_from||'2030-01-01',args.p_to||'2030-06-15');
    }
    else if(name==='lts_browser_expense_executive_v3')body=expenseFixture(args.p_from||'2030-01-01',args.p_to||'2030-06-15');
    else if(name==='lts_browser_expense_context_lens_v1')body=contextFixture();
    else if(name==='lts_browser_expense_context_nature_v1')body={summary:{},contexts:[],categories:[],unassigned_states:[]};
    else if(name==='lts_browser_expense_drilldown_v1')body={summary:{total:77000},rows:[{event_date:'2030-05-10',description:'Escola',category:'Educação',center_cost:'Benjamin',amount:4200}]};
    else if(name==='lts_browser_wealth_detail_v3'||name==='lts_browser_wealth_detail_v2')body=wealthFixture();
    else if(name==='lts_browser_recurring_future_gap_audit_v5')body={horizon_checks:[],items:[]};
    else if(name==='lts_browser_open_finance_status_v1')body={status:'not_connected'};
    else if(name==='lts_browser_transactions_v2')body={ok:true,total:3,rows:[
      {date:'2030-06-25',description:'Fatura Visa Aeternum',account:'Bradesco',category:'Cartões',amount:-9000,source:'current_event',confidence:'user_flow_editable'},
      {date:'2030-07-08',description:'Fatura Personnalite Black',account:'Itaú',category:'Cartões',amount:-7000,source:'current_event',confidence:'user_flow_editable'},
      {date:'2030-07-12',description:'Fatura Cartão C6',account:'C6',category:'Cartões',amount:-2000,source:'current_event',confidence:'user_flow_editable'}
    ]};
    await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)});
  });
  await page.goto(`${BASE}/wip35-v168-candidate.html`,{waitUntil:'domcontentloaded',timeout:20000});
  const frame=await frameReady(page);
  await frame.waitForFunction(()=>window.__LTS_V168_STATE?.dashboard?.pending===0,{timeout:22000});
  let text=await frame.locator('.v168-dashboard').innerText(),lower=semantic(text);
  for(const phrase of ['recursos de hoje','posições futuras','recursos restritos e consumo','contas correntes hoje','com fgts, sem ruptura até 31/12/2031'])if(!lower.includes(phrase))throw new Error(`${label}: Dashboard missing ${phrase}`);
  if(lower.includes('25/01/2031'))throw new Error(`${label}: stale cockpit FGTS date leaked`);
  if((calls.lts_browser_flow_v11||0)<2)throw new Error(`${label}: read retry did not run`);
  const sourceLabels=await frame.locator('.v168-chart .axis-label').allTextContents();if(!sourceLabels.some(x=>String(x||'').includes('R$')))throw new Error(`${label}: chart axis is not formatted as money`);
  if(label==='desktop')await page.screenshot({path:'v168-desktop-dashboard.png',fullPage:true});

  const route=name=>viewport.width<=520?frame.locator(`#dx1MobileNav [data-mobile-route="${name}"]`):frame.locator(`.nav [data-v="${name}"]`);
  await route('Despesas').click();await frame.locator('.v168-expenses').waitFor({state:'visible'});await frame.waitForFunction(()=>window.__LTS_V168_STATE?.expense?.loading===false);
  if(label==='desktop'){
    await frame.locator('[data-v168-exp-range="6m"]').click();
    await frame.locator('[data-v168-exp-range="all"]').click();
    await frame.waitForFunction(()=>window.__LTS_V168_STATE?.expense?.key==='all'&&window.__LTS_V168_STATE?.expense?.loading===false);
    text=await frame.locator('.v168-expenses').innerText();lower=semantic(text);
    for(const phrase of ['desde 2013','média mensal por ano','2013','2030'])if(!lower.includes(phrase))throw new Error(`desktop: full expense history missing ${phrase}`);
    await frame.locator('[data-v168-exp-tab="categories"]').click();text=await frame.locator('.v168-expenses').innerText();lower=semantic(text);for(const phrase of ['benjamin · educação','benjamin · saúde','casa · obra e reforma'])if(!lower.includes(phrase))throw new Error(`desktop: hierarchy missing ${phrase}`);
    await frame.locator('[data-v168-exp-drill]').first().click();await frame.locator('.v168-modal .v168-table').waitFor({state:'visible'});if(!semantic(await frame.locator('.v168-modal').innerText()).includes('escola'))throw new Error('desktop: generic drilldown did not open');await frame.locator('[data-v168-close]').click();
    await frame.locator('[data-v168-exp-tab="cards"]').click();text=await frame.locator('.v168-expenses').innerText();lower=semantic(text);for(const phrase of ['bradesco','itaú','c6','compromissos já contratados'])if(!lower.includes(phrase))throw new Error(`desktop: cards missing ${phrase}`);
    await page.screenshot({path:'v168-desktop-expenses.png',fullPage:true});

    await route('Patrimônio').click();await frame.locator('.v168-wealth').waitFor({state:'visible'});await frame.waitForFunction(()=>window.__LTS_V168_STATE?.wealth?.loading===false);
    text=await frame.locator('.v168-wealth').innerText();lower=semantic(text);for(const phrase of ['ativos e dinheiro já disponíveis','compensação ainda não disponível','dívidas atuais conhecidas'])if(!lower.includes(phrase))throw new Error(`desktop: wealth overview missing ${phrase}`);if(lower.includes('schiavalli')||lower.includes('ski a vale'))throw new Error('desktop: invalid asset leaked');
    await frame.locator('[data-v168-wealth-tab="rsu"]').click();text=await frame.locator('.v168-wealth').innerText();lower=semantic(text);for(const phrase of ['total morgan stanley','retention award','fora deste total'])if(!lower.includes(phrase))throw new Error(`desktop: RSU reconciliation missing ${phrase}`);if(await frame.locator('.v168-award').count()!==10)throw new Error('desktop: vesting schedule incomplete');
    await frame.locator('[data-v168-wealth-tab="assets"]').click();text=await frame.locator('.v168-wealth').innerText();lower=semantic(text);for(const phrase of ['compra paga','obra e reforma','coopharma','aguardando extrato','pai e mãe'])if(!lower.includes(phrase))throw new Error(`desktop: assets/debts missing ${phrase}`);
    await frame.locator('[data-v168-cipo]').click();await frame.locator('.v168-modal').waitFor({state:'visible'});text=await frame.locator('.v168-modal').innerText();lower=semantic(text);for(const phrase of ['marcenaria','projeto','mão de obra','quitar agora'])if(!lower.includes(phrase))throw new Error(`desktop: CIPÓ detail missing ${phrase}`);await frame.locator('[data-v168-close]').click();
    await page.screenshot({path:'v168-desktop-wealth.png',fullPage:true});
  }
  const dims=await frame.locator('html').evaluate(element=>({scroll:element.scrollWidth,client:element.clientWidth}));if(dims.scroll>dims.client+3)throw new Error(`${label}: horizontal overflow ${JSON.stringify(dims)}`);
  if(errors.length)throw new Error(`${label}: page errors ${JSON.stringify(errors)}`);
  await context.close();return{label,pass:true,viewport,flowRetry:calls.lts_browser_flow_v11,requested:[...new Set(requested)]};
}

(async()=>{
  const executablePath=process.env.LTS_CHROMIUM_EXECUTABLE||undefined,browser=await chromium.launch({headless:true,...(executablePath?{executablePath}:{})});
  try{const results=[await run(browser,{width:1440,height:1000},'desktop'),await run(browser,{width:390,height:844},'mobile')],output={pass:true,version:'v168-feedback-package',data:'controlled-fixture-not-user-data-validation',results};fs.writeFileSync('v168-feedback-package-result.json',JSON.stringify(output,null,2));console.log(JSON.stringify(output,null,2))}
  catch(error){const output={pass:false,error:String(error.stack||error),data:'controlled-fixture-not-user-data-validation'};fs.writeFileSync('v168-feedback-package-result.json',JSON.stringify(output,null,2));console.error(output.error);process.exitCode=1}
  finally{await browser.close()}
})();
