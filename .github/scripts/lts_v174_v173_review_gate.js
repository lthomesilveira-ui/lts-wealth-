'use strict';

const {chromium}=require('playwright');
const fs=require('node:fs');
const {cockpit,wealth:baseWealth,product:baseProduct,expensePayload,semantic}=require('./lts_v165_executive_ux_gate.js');
const BASE='http://127.0.0.1:'+(process.env.LTS_V174_PORT||8784);
const session={access_token:'fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};
const brl=v=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(v);
const norm=v=>String(v||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();

function productFixture(){
  const p=baseProduct();
  p.card_operating={
    ...(p.card_operating||{}),
    open_cycles:[{card_name:'Visa Aeternum',due_date:'2026-09-25',amount:24390.64,state:'open'}],
    closed_or_due:[],
    paid_recent:[],
    contracted_installment_floor_months:[
      {reference_month:'2026-09-01',detail:[]},
      {reference_month:'2026-10-01',detail:[{card_name:'Visa Aeternum',amount:5318.86},{card_name:'C6 Carbon · grupo 7873/8304',amount:743.19}]},
      {reference_month:'2026-11-01',detail:[{card_name:'Visa Aeternum',amount:4529.78},{card_name:'C6 Carbon · grupo 7873/8304',amount:743.19}]}
    ],
    classification_review:{}
  };
  return p;
}
function groups(all){
  const rows=[
    {name:'Financiamento imobiliário',total:1700952.62,rows:90,subgroups:[{name:'Casa',total:1680231.96,rows:89},{name:'CIPÓ 396',total:20720.66,rows:1}]},
    {name:'Investimentos no imóvel — obra e reforma',total:1228896.23,rows:302,subgroups:[{name:'Obra e Reforma',total:705851.96,rows:143},{name:'Eletrodomésticos',total:107908.91,rows:22}]},
    {name:'Empréstimos e consignado',total:651990.34,rows:126,subgroups:[{name:'Empréstimo · Itaú',total:567420.96,rows:107},{name:'Consignado · Coopharma',total:84569.38,rows:19}]},
    {name:'Família — saídas',total:263909.54,rows:202,subgroups:[{name:'Família',total:263909.54,rows:202}]},
    {name:'Rafiki',total:29769.84,rows:52,subgroups:[{name:'Rafiki',total:28569.84,rows:51},{name:'Pet',total:1200,rows:1}]},
    {name:'Restaurantes',total:65124.92,rows:105,subgroups:[{name:'Restaurantes',total:65124.92,rows:105}]},
    {name:'Ifood',total:20682.32,rows:77,subgroups:[{name:'Ifood',total:20682.32,rows:77}]},
    {name:'Financiamento de veículo',total:14813.73,rows:12,subgroups:[{name:'Financiamento Carro',total:11927.3,rows:11},{name:'Não identificado',total:2886.43,rows:1}]},
    {name:'Investimento no imóvel — aquisição e histórico',total:288747.56,rows:39,subgroups:[{name:'Cipó 396',total:288747.56,rows:39}]}
  ];
  return rows;
}
function expenseFixture(from,to){
  const x=expensePayload(from,to);
  x.version='expense-executive-v16-v174-audited';
  x.summary={...(x.summary||{}),selected_total:8671698.01,card_total:3696809.34,account_total:4974888.67};
  x.management_groups=groups(from==='2013-10-10');
  x.coverage_disclosure={total:270849.19,rows:24,by_origin:[]};
  x.property_improvement_reconciliation=from==='2013-10-10'?{
    version:'cipo-improvement-browser-v1',
    workbook_summary_brl:2177714.78,reconciled_unique_brl:2174777.52,duplicate_source_brl:2937.26,
    historical_card_coverage_gap_brl:942669.02,dated_reader_brl:1228896.23
  }:{};
  return x;
}
function monthKeys(from,to){
  const out=[],d=new Date(from.slice(0,7)+'-01T12:00:00Z'),end=to.slice(0,7);
  while(d.toISOString().slice(0,7)<=end){out.push(d.toISOString().slice(0,7)+'-01');d.setUTCMonth(d.getUTCMonth()+1)}
  return out;
}
function monthlyFixture(from,to){
  const months=monthKeys(from,to),monthly=(fn)=>months.map(m=>({month:m,amount:fn(m)}));
  const sale=m=>m==='2026-01-01'?9903.59:m==='2026-02-01'?14609.78:m==='2026-03-01'?21924.71:m==='2026-05-01'?19154.73:m==='2026-06-01'?19699.64:m==='2026-07-01'?19566.43:m==='2026-08-01'?19095.04:0;
  const sales=months.reduce((s,m)=>s+sale(m),0),count=months.length;
  const cov=m=>m==='2026-01-01'||m==='2026-02-01'?5000:0;
  const coverTotal=months.reduce((s,m)=>s+cov(m),0);
  const baseExtra=months.map(m=>({month:m,revenue:100000,expenses:90000,operating_balance:10000,extraordinary:sale(m),cash_after_extraordinary:10000+sale(m)}));
  return{
    version:'monthly-balance-v3-v174-audited',from,to,months,
    totals:{revenue:100000*count,expenses:90000*count,operating_balance:10000*count,extraordinary:sales,cash_after_extraordinary:10000*count+sales},
    monthly_totals:baseExtra,
    revenue_groups:[{label:'Salário',total:100000*count,source_rows:count,monthly:monthly(()=>100000)}],
    extraordinary_groups:sales?[{label:'Venda de bens e ativos',total:sales,source_rows:8,monthly:monthly(sale)}]:[],
    expense_groups:[
      {label:'Restaurantes',total:12000,source_rows:20,monthly:monthly(m=>m==='2026-01-01'?0:(/^2026-/.test(m)?1500:0))},
      {label:'Ifood',total:6000,source_rows:15,monthly:monthly(m=>m==='2026-02-01'?0:(/^2026-/.test(m)?700:0))},
      {label:'Rafiki',total:15023.62,source_rows:21,monthly:monthly(m=>m==='2026-01-01'?0:(/^2026-/.test(m)?1200:0))},
      {label:'Família — saídas',total:14219.8,source_rows:9,monthly:monthly(m=>m==='2026-01-01'?1900:0)}
    ],
    expense_unclassified_card_coverage:{label:'Compras de cartão ainda sem categoria',total:coverTotal,source_rows:2,monthly:monthly(cov)},
    stock_sale_supplement:{total:sales,monthly:monthly(sale)}
  };
}
function wealthFixture(){return{...baseWealth,wealth:{...(baseWealth.wealth||{}),summary:{known_debt_total:450000},liquidity:{bank_cash:10000,d0:0},assets:{cipo_396:{market_central:1700000,documentary_debt:400000},volvo_xc40:{market_central:120000,documented_financed_balance:50000}}},pensions:{total_gross_brl:0,positions:[]},rsu_summary:{available_total_brl:0,future_considered_total_brl:0},morgan_statement:{available_total_brl:0,future_components:{future_after_reserve_brl:0}},financing:{summary:{commitments:[]},documentary:{items:[]}}}}
function cardFlow(){return{version:'card-flow-schedule-v1',from:'2026-09-18',to:'2027-12-31',events:[
  {event_date:'2026-09-25',card_name:'Visa Aeternum',description:'Fatura Visa Aeternum',account:'Bradesco',amount:24390.64,source:'card_invoice'},
  {event_date:'2026-10-25',card_name:'Visa Aeternum Bradesco',description:'Visa Aeternum',account:'Bradesco',amount:11202.03,source:'legacy_fix86'},
  {event_date:'2026-10-05',card_name:'C6 Carbon',description:'Cartão c6Master',account:'C6',amount:743.19,source:'legacy_fix86'}
]}}
function flowFixture(from,to){return{ok:true,flow:{from,to,historical:{days:[],events:[]},current_future:{days:[],events:[]}}}}

async function frameReady(page,label){
  for(let i=0;i<300;i++){
    const f=page.frames().find(x=>{try{return new URL(x.url()).pathname.endsWith('/index.html')}catch{return false}});
    if(f&&await f.evaluate(()=>Boolean(window.__LTS_V174_V173_REVIEW?.installed&&document.querySelector('.v168-dashboard'))).catch(()=>false))return f;
    await page.waitForTimeout(100);
  }
  await page.screenshot({path:'v174-'+label+'-failure.png',fullPage:true});throw Error(label+': V174 frame not ready');
}
async function run(browser,viewport,label){
  const context=await browser.newContext({viewport});
  await context.addInitScript(fixed=>{const N=Date,ms=N.parse(fixed);class F extends N{constructor(...a){super(...(a.length?a:[ms]))}static now(){return ms}}window.Date=F},'2026-09-18T12:00:00Z');
  await context.addInitScript(v=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(v)),session);
  const page=await context.newPage();page.setDefaultTimeout(30000);const errors=[],calls=[];
  page.on('pageerror',e=>errors.push(String(e.message||e)));
  await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
    const req=route.request(),name=new URL(req.url()).pathname.split('/').pop();let args={};try{args=JSON.parse(req.postData()||'{}')}catch{}calls.push({name,args});
    let body={ok:true,rows:[],items:[]};
    if(name==='token')body=session;
    else if(name==='lts_browser_product_v1')body={ok:true,mvp:productFixture()};
    else if(name==='lts_browser_dashboard_cockpit_v1')body=cockpit;
    else if(name==='lts_browser_expense_executive_v7')body=expenseFixture(args.p_from,args.p_to);
    else if(/^lts_browser_expense_executive_v/.test(name))body=expenseFixture(args.p_from,args.p_to);
    else if(name==='lts_browser_expense_context_lens_v1'||name==='lts_browser_expense_context_nature_v1')body={contexts:[],natures:[],summary:{}};
    else if(name==='lts_browser_monthly_balance_v3')body=monthlyFixture(args.p_from,args.p_to);
    else if(name==='lts_browser_card_flow_schedule_v1')body=cardFlow();
    else if(/^lts_browser_wealth_detail_v/.test(name))body=wealthFixture();
    else if(name==='lts_browser_recurring_future_gap_audit_v5')body={horizon_checks:[],items:[]};
    else if(name==='lts_browser_open_finance_status_v1')body={status:'not_connected'};
    else if(name==='lts_browser_flow_v11'||name==='lts_browser_flow_v12')body=flowFixture(args.p_from,args.p_to);
    else if(name==='lts_browser_transactions_v2')body={rows:[]};
    await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)});
  });
  await page.goto(BASE+'/wip35-v174-candidate.html',{waitUntil:'domcontentloaded'});
  const frame=await frameReady(page,label),route=n=>viewport.width<=520?frame.locator('#dx1MobileNav [data-mobile-route="'+n+'"]'):frame.locator('.nav [data-v="'+n+'"]');
  await route('Despesas').click();await frame.waitForFunction(()=>window.__LTS_V168_STATE?.expense?.data?.version==='expense-executive-v16-v174-audited');
  await frame.locator('[data-v168-exp-range="all"]').click();await frame.waitForFunction(()=>window.__LTS_V168_STATE?.expense?.key==='all'&&window.__LTS_V168_STATE?.expense?.data?.property_improvement_reconciliation?.reconciled_unique_brl===2174777.52);
  await frame.locator('.v168-tabs [data-v168-exp-tab="categories"]').click();await frame.locator('.v174-categories').waitFor();
  await frame.locator('.v174-categories details').evaluateAll(nodes=>nodes.forEach(node=>node.open=true));
  let text=semantic(await frame.locator('.v174-categories').innerText());
  for(const phrase of ['reformas e melhorias · reconciliado',semantic(brl(2174777.52)),'duplicidade confirmada na fonte','família — saídas','histórico pago · itaú','empréstimo consignado · coopharma','investimento no imóvel — aquisição e histórico'])if(!text.includes(phrase))throw Error(label+': categories missing '+phrase);
  if(text.includes('financiamento imobiliário — casa'))throw Error(label+': duplicate mortgage composition returned');
  if(label==='desktop')await page.screenshot({path:'v174-desktop-categories.png',fullPage:true});

  await frame.locator('.v168-tabs [data-v168-exp-tab="monthly"]').click();
  await frame.waitForTimeout(3500);
  const monthlyDiag=await frame.evaluate(()=>({V,tab:window.__LTS_V168_STATE?.expense?.tab,expenseKey:window.__LTS_V168_STATE?.expense?.key,monthly:window.__LTS_V169_STATE?.monthly,v174:window.__LTS_V174_STATE}));
  if(!monthlyDiag.monthly?.data||monthlyDiag.monthly?.loading)throw Error(label+': monthly did not settle '+JSON.stringify(monthlyDiag)+' rpc='+JSON.stringify(calls.filter(x=>x.name.includes('monthly'))));
  const ms={version:monthlyDiag.monthly.data.version,months:monthlyDiag.monthly.data.months,calls:monthlyDiag.v174.monthlyChunkCalls,key:monthlyDiag.monthly.key,error:monthlyDiag.monthly.error};
  if(ms.version!=='monthly-balance-v4-v174-resilient-chunked')throw Error(label+': monthly version/range wrong '+JSON.stringify(ms));
  if(ms.months[0]!=='2013-10-01'||ms.months.at(-1)!=='2026-09-01'||ms.calls<10)throw Error(label+': all-history monthly failed '+JSON.stringify(ms));
  text=semantic(await frame.locator('.v174-monthly').innerText());
  for(const phrase of ['venda de ações recuperada no período','venda de ações, rsus e outros ativos','família — saídas','—* não significa despesa zero'])if(!text.includes(phrase))throw Error(label+': monthly missing '+phrase);
  if(await frame.locator('.v174-unknown').count()<1)throw Error(label+': incomplete card months falsely shown as zero');
  if(label==='desktop')await page.screenshot({path:'v174-desktop-monthly.png',fullPage:true});

  await frame.locator('.v168-tabs [data-v168-exp-tab="cards"]').click();await frame.waitForFunction(()=>window.__LTS_V174_STATE?.cardFlow?.version==='card-flow-schedule-v1');
  await frame.locator('.v174-cards').waitFor();text=semantic(await frame.locator('.v174-cards').innerText());
  for(const phrase of [semantic(brl(24390.64)),semantic(brl(5318.86)),semantic(brl(11202.03)),'valor no fluxo','parcelas já contratadas'])if(!text.includes(phrase))throw Error(label+': cards missing '+phrase);
  if(label==='desktop')await page.screenshot({path:'v174-desktop-cards.png',fullPage:true});
  const dims=await frame.locator('html').evaluate(e=>({s:e.scrollWidth,c:e.clientWidth}));if(dims.s>dims.c+3)throw Error(label+': horizontal overflow '+JSON.stringify(dims));
  if(errors.length)throw Error(label+': page errors '+JSON.stringify(errors));
  await context.close();return{label,pass:true,monthlyMonths:ms.months.length,monthlyChunks:ms.calls};
}
(async()=>{const browser=await chromium.launch({headless:true});try{const results=[await run(browser,{width:1440,height:1000},'desktop'),await run(browser,{width:390,height:844},'mobile')],out={pass:true,version:'v174-v173-review',data:'controlled-fixture-not-user-data-validation',results};fs.writeFileSync('v174-v173-review-result.json',JSON.stringify(out,null,2));console.log(JSON.stringify(out,null,2))}catch(e){const out={pass:false,error:String(e.stack||e)};fs.writeFileSync('v174-v173-review-result.json',JSON.stringify(out,null,2));console.error(out.error);process.exitCode=1}finally{await browser.close()}})();