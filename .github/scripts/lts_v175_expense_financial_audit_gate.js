'use strict';

const {chromium}=require('playwright');
const fs=require('node:fs');
const {cockpit,wealth:baseWealth,product:baseProduct,expensePayload,semantic}=require('./lts_v165_executive_ux_gate.js');

const BASE='http://127.0.0.1:'+(process.env.LTS_V175_PORT||8785);
const session={access_token:'fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};
const norm=v=>String(v||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
const brl=v=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(v);

function monthKeys(from,to){
  const out=[],d=new Date(from.slice(0,7)+'-01T12:00:00Z'),end=to.slice(0,7);
  while(d.toISOString().slice(0,7)<=end){out.push(d.toISOString().slice(0,7)+'-01');d.setUTCMonth(d.getUTCMonth()+1)}
  return out;
}
function productFixture(){
  const p=baseProduct();
  p.card_operating={
    ...(p.card_operating||{}),
    open_cycles:[{card_name:'Visa Aeternum',due_date:'2026-09-25',amount:24390.64,state:'open'}],
    closed_or_due:[],
    paid_recent:[],
    contracted_installment_floor_months:[
      {reference_month:'2026-10-01',detail:[{card_name:'Visa Aeternum',amount:5318.86},{card_name:'C6 Carbon · grupo 7873/8304',amount:743.19}]},
      {reference_month:'2026-11-01',detail:[{card_name:'Visa Aeternum',amount:4529.78},{card_name:'C6 Carbon · grupo 7873/8304',amount:743.19}]}
    ],
    classification_review:{}
  };
  return p;
}
function expenseFixture(from,to){
  const x=expensePayload(from,to);
  x.version='expense-executive-v17-v175-financial-audit';
  x.summary={...(x.summary||{}),selected_total:8671698.01,history_total:8671698.01,property_total:2174777.52};
  x.coverage_disclosure={label:'Faturas conciliadas pelo total',total:1517852.17,rows:295,months:144};
  x.property_improvement_reconciliation={
    version:'cipo-improvement-browser-v2-v175',workbook_summary_brl:2177714.78,
    duplicate_source_brl:2937.26,reconciled_unique_brl:2174777.52,historical_card_coverage_gap_brl:942462.49
  };
  x.loan_audit={version:'loan-audit-v1',historical_paid_total:651990.34,source_split:[
    {lender:'Itaú',rows:20,paid_history:267441.25},
    {lender:'CooperMSD',rows:57,paid_history:224164.59},
    {lender:'Coopharma',rows:19,paid_history:84569.38},
    {lender:'CGI',rows:14,paid_history:50569.72},{lender:'CEF',rows:9,paid_history:20345.4},{lender:'Funcef',rows:7,paid_history:4900}
  ]};
  x.management_groups=[
    {name:'Investimentos no imóvel — obra e reforma',total:2174777.52,rows:23,source_reconciled:true,subgroups:[
      {name:'Projeto Arquitetura',total:411410.3,rows:2,origins:'conta corrente, Mastercard'},
      {name:'Marcenaria e Projeto',total:300000,rows:2,origins:'conta corrente, Mastercard'},
      {name:'Móveis',total:91807.72,rows:4,origins:'conta corrente, Mastercard, Visa Bradesco, Visa Infinite'}
    ]},
    {name:'Financiamento imobiliário',total:1700952.62,rows:90,subgroups:[{name:'Financiamento imobiliário',total:1700952.62,rows:90}]},
    {name:'Empréstimos',total:651990.34,rows:126,subgroups:[
      {name:'Histórico pago · Itaú',total:267441.25,rows:20},{name:'Histórico pago · CooperMSD',total:224164.59,rows:57},
      {name:'Empréstimo consignado · Coopharma',total:84569.38,rows:19},{name:'Histórico pago · CGI',total:50569.72,rows:14},
      {name:'Histórico pago · CEF',total:20345.4,rows:9},{name:'Histórico pago · Funcef',total:4900,rows:7}
    ]},
    {name:'Família — saídas',total:263909.54,rows:202,subgroups:[{name:'Família',total:263909.54,rows:202}]},
    {name:'Restaurantes',total:100000,rows:200,subgroups:[{name:'Restaurantes',total:100000,rows:200}]},
    {name:'Rafiki',total:50000,rows:100,subgroups:[{name:'Rafiki',total:50000,rows:100}]},
    {name:'Financiamento de veículo',total:14813.73,rows:12,subgroups:[{name:'Financiamento Carro',total:11927.3,rows:11},{name:'Volvo XC40',total:2886.43,rows:1}]}
  ];
  return x;
}
const special={
  '2025-12-01':{restaurant:8696,ifood:2791.62,rafiki:1862.4,sale:36403.12},
  '2026-01-01':{restaurant:2274.69,ifood:515.6,rafiki:1706.17,sale:9903.59},
  '2026-02-01':{restaurant:708.7,ifood:1848.76,rafiki:1651.89,sale:14609.78},
  '2026-03-01':{restaurant:1284.7,ifood:2263.38,rafiki:3302.19,sale:21924.71},
  '2026-04-01':{restaurant:2751.09,ifood:2943.13,rafiki:2606.36,sale:0},
  '2026-05-01':{restaurant:4269.15,ifood:2130.92,rafiki:7554.86,sale:19154.73},
  '2026-06-01':{restaurant:4051.72,ifood:2665.96,rafiki:5312.54,sale:19699.64},
  '2026-07-01':{restaurant:9361.01,ifood:1485.3,rafiki:3340.72,sale:19566.43},
  '2026-08-01':{restaurant:5564.53,ifood:55.55,rafiki:4007.06,sale:19095.04},
  '2026-09-01':{restaurant:3190.46,ifood:1809.83,rafiki:4007.06,sale:18808.69}
};
function monthlyArray(months,key){return months.map(m=>({month:m,amount:special[m]?.[key]||0}))}
function monthlyFixture(from,to){
  const months=monthKeys(from,to),annualYears=[...new Set(months.map(x=>x.slice(0,4)))];
  const saleMonthly=monthlyArray(months,'sale'),saleTotal=saleMonthly.reduce((s,x)=>s+x.amount,0);
  const restaurant=monthlyArray(months,'restaurant'),ifood=monthlyArray(months,'ifood'),rafiki=monthlyArray(months,'rafiki');
  const fillers=Array.from({length:55},(_,i)=>({
    label:'Grupo teste '+String(i+1).padStart(2,'0'),source_rows:12,
    monthly:months.map(m=>({month:m,amount:m.startsWith('2026-')?(i+1)*10:0}))
  })).map(g=>({...g,total:g.monthly.reduce((s,x)=>s+x.amount,0)}));
  const monthlyTotals=months.map(m=>{
    const revenue=100000,expenses=90000,extraordinary=special[m]?.sale||0;
    return{month:m,revenue,expenses,operating_balance:revenue-expenses,extraordinary,cash_after_extraordinary:revenue-expenses+extraordinary};
  });
  const totals=monthlyTotals.reduce((o,x)=>{for(const k of ['revenue','expenses','operating_balance','extraordinary','cash_after_extraordinary'])o[k]+=x[k];return o},{revenue:0,expenses:0,operating_balance:0,extraordinary:0,cash_after_extraordinary:0});
  return{
    version:'monthly-balance-v5-v175-financial-audit',from,to,months,monthly_totals,totals,
    revenue_groups:[{label:'Salário',source_rows:months.length,total:100000*months.length,monthly:months.map(m=>({month:m,amount:100000}))}],
    extraordinary_groups:saleTotal?[{label:'Venda de ações, RSUs e outros ativos',total:saleTotal,source_rows:14,monthly:saleMonthly}]:[],
    expense_groups:[
      {label:'Restaurantes',total:restaurant.reduce((s,x)=>s+x.amount,0),source_rows:55,monthly:restaurant},
      {label:'Ifood',total:ifood.reduce((s,x)=>s+x.amount,0),source_rows:26,monthly:ifood},
      {label:'Rafiki',total:rafiki.reduce((s,x)=>s+x.amount,0),source_rows:26,monthly:rafiki},
      ...fillers
    ],
    expense_unclassified_card_coverage:{
      label:'Faturas conciliadas pelo total',total:1500000,source_rows:200,
      monthly:months.map(m=>({month:m,amount:m.startsWith('2019-')?5000:0}))
    },
    stock_sale_supplement:{total:saleTotal,monthly:saleMonthly.map(x=>({...x,source_rows:x.amount?1:0})),confirmed_source_addition:18808.69},
    open_audit_issues:[{issue_id:'stock_sale_2026_04_missing_source',status:'open',title:'Venda de ações de abril/2026 sem fonte localizada',detail:'Venda reportada pelo usuário; valor não localizado nas fontes preservadas e não contabilizado por hipótese.'}],
    recurring_gap_audit:{version:'recurring-gap-audit-v1',open_zero_count:0,items:[]}
  };
}
function cardFlowFixture(){
  return{
    version:'card-flow-schedule-v2-v175',
    from:'2026-09-18',to:'2027-12-31',
    events:[
      {event_date:'2026-09-25',card_name:'Visa Aeternum',description:'Fatura Visa Aeternum',account:'Bradesco',amount:24390.64,source:'card_invoice'},
      {event_date:'2026-10-25',card_name:'Visa Aeternum Bradesco',description:'Visa Aeternum',account:'Bradesco',amount:11202.03,source:'legacy_fix86'},
      {event_date:'2026-10-05',card_name:'C6 Carbon',description:'Cartão c6Master',account:'C6',amount:743.19,source:'legacy_fix86'}
    ],
    inventory:{version:'card-inventory-v1',cards:[
      {bank:'Bradesco',card_name:'Visa Aeternum',first_seen:'2025-08-10',last_seen:'2026-09-25',status:'current_or_recent'},
      {bank:'Bradesco',card_name:'Visa Infinite Prime',last4:'3980',first_seen:'2022-05-20',last_seen:'2026-08-20',status:'current_or_recent'},
      {bank:'Itaú',card_name:'Mastercard Black Itaú',first_seen:'2013-11-01',last_seen:'2026-07-12',status:'current_or_recent'},
      {bank:'Itaú',card_name:'Visa Itaú',first_seen:'2013-11-01',last_seen:'2021-11-01',status:'historical'},
      {bank:'Itaú',card_name:'Visa Infinite Itaú',first_seen:'2024-02-15',last_seen:'2026-05-20',status:'historical'},
      {bank:'C6',card_name:'C6 histórico',last4:'6610',first_seen:'2022-04-01',last_seen:'2024-03-01',status:'historical'},
      {bank:'C6',card_name:'C6 Carbon',last4:'7873',first_seen:'2024-04-01',last_seen:'2026-08-01',status:'current_or_recent'},
      {bank:'C6',card_name:'C6 Carbon',last4:'8304',first_seen:'2025-01-01',last_seen:'2026-08-01',status:'current_or_recent'}
    ]}
  };
}
function wealthFixture(){return{...baseWealth,wealth:{...(baseWealth.wealth||{}),summary:{known_debt_total:450000},liquidity:{bank_cash:10000,d0:0},assets:{cipo_396:{market_central:1700000,documentary_debt:400000},volvo_xc40:{market_central:120000,documented_financed_balance:50000}}},pensions:{total_gross_brl:0,positions:[]},rsu_summary:{available_total_brl:0,future_considered_total_brl:0},morgan_statement:{available_total_brl:0,future_components:{future_after_reserve_brl:0}},financing:{summary:{commitments:[]},documentary:{items:[]}}}}
function flowFixture(from,to){return{ok:true,flow:{from,to,historical:{days:[],events:[]},current_future:{days:[],events:[]}}}}

async function frameReady(page,label){
  for(let i=0;i<300;i++){
    const frame=page.frames().find(f=>{try{return new URL(f.url()).pathname.endsWith('/index.html')}catch{return false}});
    if(frame&&await frame.evaluate(()=>Boolean(window.__LTS_V175_EXPENSE_AUDIT?.installed&&document.querySelector('.v168-dashboard'))).catch(()=>false))return frame;
    await page.waitForTimeout(100);
  }
  await page.screenshot({path:'v175-'+label+'-failure.png',fullPage:true});throw Error(label+': V175 frame not ready');
}
async function run(browser,viewport,label){
  const context=await browser.newContext({viewport});
  await context.addInitScript(fixed=>{const Native=Date,ms=Native.parse(fixed);class Fixed extends Native{constructor(...a){super(...(a.length?a:[ms]))}static now(){return ms}}window.Date=Fixed},'2026-09-18T12:00:00Z');
  await context.addInitScript(v=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(v)),session);
  const page=await context.newPage();page.setDefaultTimeout(30000);const errors=[],calls=[];
  page.on('pageerror',e=>errors.push(String(e.message||e)));
  await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
    const req=route.request(),name=new URL(req.url()).pathname.split('/').pop();let args={};try{args=JSON.parse(req.postData()||'{}')}catch{}calls.push({name,args});
    let body={ok:true,rows:[],items:[]};
    if(name==='token')body=session;
    else if(name==='lts_browser_product_v1')body={ok:true,mvp:productFixture()};
    else if(name==='lts_browser_dashboard_cockpit_v1')body=cockpit;
    else if(/^lts_browser_expense_executive_v/.test(name))body=expenseFixture(args.p_from,args.p_to);
    else if(/^lts_browser_monthly_balance_v/.test(name))body=monthlyFixture(args.p_from,args.p_to);
    else if(/^lts_browser_card_flow_schedule_v/.test(name))body=cardFlowFixture();
    else if(name==='lts_browser_expense_context_lens_v1'||name==='lts_browser_expense_context_nature_v1')body={contexts:[],natures:[],summary:{}};
    else if(/^lts_browser_wealth_detail_v/.test(name))body=wealthFixture();
    else if(name==='lts_browser_recurring_future_gap_audit_v5')body={horizon_checks:[],items:[]};
    else if(name==='lts_browser_open_finance_status_v1')body={status:'not_connected'};
    else if(name==='lts_browser_flow_v11'||name==='lts_browser_flow_v12')body=flowFixture(args.p_from,args.p_to);
    else if(name==='lts_browser_transactions_v2')body={rows:[]};
    await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)});
  });

  await page.goto(BASE+'/wip35-v175-candidate.html',{waitUntil:'domcontentloaded'});
  const frame=await frameReady(page,label),route=n=>viewport.width<=520?frame.locator('#dx1MobileNav [data-mobile-route="'+n+'"]'):frame.locator('.nav [data-v="'+n+'"]');
  await route('Despesas').click();
  await frame.locator('[data-v168-exp-range="all"]').click();
  await frame.waitForFunction(()=>window.__LTS_V175_STATE?.expense?.data?.version==='expense-executive-v17-v175-financial-audit');

  await frame.locator('.v168-tabs [data-v168-exp-tab="categories"]').click();await frame.locator('.v175-categories').waitFor();
  await frame.locator('.v175-categories details').evaluateAll(nodes=>nodes.forEach(n=>n.open=true));
  let text=semantic(await frame.locator('.v175-categories').innerText());
  for(const phrase of [semantic(brl(2174777.52)),semantic(brl(267441.25)),semantic('Histórico pago · CooperMSD'),semantic('Empréstimo consignado · Coopharma'),semantic('Família — saídas')])
    if(!text.includes(phrase))throw Error(label+': category audit missing '+phrase);
  if(text.includes(semantic(brl(567420.96))))throw Error(label+': old false Itaú total is still displayed as subgroup');
  if(label==='desktop')await page.screenshot({path:'v175-desktop-categories.png',fullPage:true});

  await frame.locator('.v168-tabs [data-v168-exp-tab="monthly"]').click();
  await frame.waitForFunction(()=>window.__LTS_V175_STATE?.monthly?.data?.version==='monthly-balance-v5-v175-financial-audit'&&!window.__LTS_V175_STATE?.monthly?.loading,{timeout:30000});
  const monthlyState=await frame.evaluate(()=>({months:window.__LTS_V175_STATE.monthly.data.months.length,mode:window.__LTS_V175_STATE.monthly.mode,year:window.__LTS_V175_STATE.monthly.year}));
  if(monthlyState.months!==156||monthlyState.year!=='2026')throw Error(label+': full history not loaded '+JSON.stringify(monthlyState));
  const monthlyCalls=calls.filter(x=>x.name==='lts_browser_monthly_balance_v5');
  if(monthlyCalls.length>5)throw Error(label+': monthly reader made too many calls '+monthlyCalls.length);
  if(calls.some(x=>/^lts_browser_monthly_balance_v[123]$/.test(x.name)))throw Error(label+': legacy monthly RPC escaped V175 mapping');
  text=semantic(await frame.locator('.v175-monthly').innerText());
  for(const phrase of [semantic('Venda de ações, RSUs e outros ativos'),semantic('Venda de ações de abril/2026 sem fonte localizada'),semantic(brl(18808.69)),semantic(brl(2274.69)),semantic(brl(708.7)),semantic(brl(1284.7))])
    if(!text.includes(phrase))throw Error(label+': monthly audit missing '+phrase);
  const cellCount=await frame.locator('.v175-monthly th,.v175-monthly td').count();
  if(cellCount>3500)throw Error(label+': full-history DOM is unbounded '+cellCount);
  await frame.locator('[data-v175-year]').selectOption('2025');
  text=semantic(await frame.locator('.v175-monthly').innerText());
  for(const phrase of [semantic(brl(8696)),semantic(brl(2791.62)),semantic(brl(1862.4))])if(!text.includes(phrase))throw Error(label+': Dec/2025 recovered category missing '+phrase);
  if(label==='desktop')await page.screenshot({path:'v175-desktop-monthly.png',fullPage:true});

  await frame.locator('.v168-tabs [data-v168-exp-tab="cards"]').click();
  await frame.waitForFunction(()=>window.__LTS_V175_STATE?.cards?.data?.version==='card-flow-schedule-v2-v175'&&!window.__LTS_V175_STATE?.cards?.loading);
  text=semantic(await frame.locator('.v175-cards').innerText());
  for(const phrase of [semantic('Visa · final 3980'),semantic('Mastercard Black Itaú'),semantic('Visa Itaú'),semantic('C6 histórico · final 6610'),semantic('C6 Carbon · final 7873'),semantic('C6 Carbon · final 8304'),semantic(brl(5318.86)),semantic(brl(11202.03))])
    if(!text.includes(phrase))throw Error(label+': cards audit missing '+phrase);
  if(label==='desktop')await page.screenshot({path:'v175-desktop-cards.png',fullPage:true});

  const dims=await frame.locator('html').evaluate(e=>({scroll:e.scrollWidth,client:e.clientWidth}));
  if(dims.scroll>dims.client+3)throw Error(label+': page horizontal overflow '+JSON.stringify(dims));
  if(errors.length)throw Error(label+': page errors '+JSON.stringify(errors));
  await page.screenshot({path:'v175-'+label+'-final.png',fullPage:true});
  await context.close();
  return{label,pass:true,months:monthlyState.months,monthlyCalls:monthlyCalls.length,cellCount};
}

(async()=>{
  const browser=await chromium.launch({headless:true});
  try{
    const results=[await run(browser,{width:1440,height:1000},'desktop'),await run(browser,{width:390,height:844},'mobile')];
    const out={pass:true,version:'v175-expense-financial-audit',data:'controlled-fixture-not-user-data-validation',results};
    fs.writeFileSync('v175-expense-financial-audit-result.json',JSON.stringify(out,null,2));console.log(JSON.stringify(out,null,2));
  }catch(error){
    const out={pass:false,error:String(error.stack||error)};fs.writeFileSync('v175-expense-financial-audit-result.json',JSON.stringify(out,null,2));console.error(out.error);process.exitCode=1;
  }finally{await browser.close()}
})();