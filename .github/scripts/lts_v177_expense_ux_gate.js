'use strict';

const {chromium}=require('playwright');
const fs=require('node:fs');
const {cockpit,wealth:baseWealth,product:baseProduct,expensePayload,semantic}=require('./lts_v165_executive_ux_gate.js');

const BASE='http://127.0.0.1:'+(process.env.LTS_V177_PORT||8787);
const session={access_token:'fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};
const brl=v=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(v);

function productFixture(){
  const p=baseProduct();
  p.card_operating={...(p.card_operating||{}),open_cycles:[],closed_or_due:[],contracted_installment_floor_months:[],classification_review:{}};
  return p;
}
function expenseFixture(from,to){
  const x=expensePayload(from,to);
  x.version='expense-executive-v19-v177-property-rollup';
  x.summary={...(x.summary||{}),selected_total:8671698.01};
  x.management_groups=[
    {name:'Apartamento · CIPÓ 396',total:4529057.60,rows:4,detail_key:'apartment',subgroups:[
      {name:'Aquisição do imóvel',total:288747.56},
      {name:'Financiamento imobiliário',total:1700952.62},
      {name:'Obra e reforma',total:2174777.52},
      {name:'Custos recorrentes de moradia',total:364579.90,children:[
        {name:'Condomínio',total:236934.10},{name:'IPTU e impostos do imóvel',total:69235.37},
        {name:'Energia elétrica',total:57052.03},{name:'Seguro residencial',total:1358.40}
      ]}
    ]},
    {name:'Empréstimos',total:651990.34,rows:126,subgroups:[
      {name:'Histórico pago · Itaú',total:267441.25,rows:20},
      {name:'Histórico pago · CooperMSD',total:224164.59,rows:57},
      {name:'Empréstimo consignado · Coopharma',total:84569.38,rows:19}
    ]},
    {name:'Família — saídas',total:263909.54,rows:202,subgroups:[{name:'Família',total:263909.54,rows:202}]},
    {name:'Saúde',total:169200.12,rows:159,subgroups:[
      {name:'Saúde geral / não atribuído',total:114349.92,rows:105},
      {name:'Benjamin',total:37335.20,rows:45},{name:'Larissa',total:17515,rows:9}
    ]},
    {name:'Restaurantes',total:107000,rows:250,subgroups:[{name:'Restaurantes',total:107000,rows:250}]}
  ];
  x.coverage_disclosure={total:100000,rows:24,months:24};
  x.property_improvement_reconciliation={workbook_summary_brl:2177714.78,duplicate_source_brl:2937.26,reconciled_unique_brl:2174777.52};
  x.property_rollup={version:'property-rollup-v1-v177',name:'Apartamento · CIPÓ 396',total_cash:4529057.60};
  return x;
}
function detailFixture(group,subgroup){
  if(group==='Família — saídas')return{
    version:'expense-group-detail-v1-v177',group,subgroup,total:263909.54,row_count:3,reconciles:true,
    rows:[
      {date:'2026-08-13',date_label:'13/08/2026',description:'Larissa',account_source:'Itaú',counterparty:'Larissa',center_cost:'Larissa',amount:700,row_kind:'transaction',component:group},
      {date:'2026-07-31',date_label:'31/07/2026',description:'Larissa',account_source:'Itaú',counterparty:'Larissa',center_cost:'Larissa',amount:3600,row_kind:'transaction',component:group},
      {date:'2016-08-05',date_label:'05/08/2016',description:'Família',account_source:'Conta',counterparty:'Família',center_cost:'Não atribuído',amount:259609.54,row_kind:'transaction',component:group}
    ]
  };
  if(group==='Apartamento · CIPÓ 396'){
    if(subgroup==='Custos recorrentes de moradia')return{
      version:'expense-group-detail-v1-v177',group,subgroup,total:364579.90,row_count:4,reconciles:true,
      rows:[
        {date:'2026-09-08',date_label:'08/09/2026',description:'Condomínio O Parque',account_source:'Itaú',counterparty:'Condomínio O Parque',center_cost:'Casa',amount:236934.10,row_kind:'transaction',component:subgroup},
        {date:'2026-09-01',date_label:'09/2026',description:'IPTU e impostos do imóvel',account_source:'Itaú',counterparty:'Prefeitura',center_cost:'Casa',amount:69235.37,row_kind:'monthly_category_total',component:subgroup},
        {date:'2026-09-09',date_label:'09/09/2026',description:'Enel - O Parque',account_source:'Itaú',counterparty:'Enel',center_cost:'Casa',amount:57052.03,row_kind:'transaction',component:subgroup},
        {date:'2026-06-01',date_label:'06/2026',description:'Seguro residencial',account_source:'Cartão',counterparty:'Seguros',center_cost:'Casa',amount:1358.40,row_kind:'monthly_category_total',component:subgroup}
      ]
    };
    return{
      version:'expense-group-detail-v1-v177',group,subgroup,total:4529057.60,row_count:6,reconciles:true,
      rows:[
        {date:null,date_label:'Histórico',description:'Aquisição do imóvel',account_source:'Conta',counterparty:null,center_cost:'Casa',amount:288747.56,row_kind:'historical_component',component:'Aquisição do imóvel'},
        {date:'2026-06-01',date_label:'01/06/2026',description:'Financiamento imobiliário',account_source:'Bradesco',counterparty:'Bradesco',center_cost:'Casa',amount:1700952.62,row_kind:'transaction',component:'Financiamento imobiliário'},
        {date:null,date_label:'Histórico',description:'Projeto Arquitetura',account_source:'conta corrente, Mastercard',counterparty:null,center_cost:'Casa',amount:2174777.52,row_kind:'historical_component',component:'Obra e reforma'},
        {date:'2026-09-08',date_label:'08/09/2026',description:'Condomínio',account_source:'Itaú',counterparty:'Condomínio O Parque',center_cost:'Casa',amount:236934.10,row_kind:'transaction',component:'Custos recorrentes de moradia'},
        {date:'2026-09-09',date_label:'09/09/2026',description:'Energia elétrica',account_source:'Itaú',counterparty:'Enel',center_cost:'Casa',amount:57052.03,row_kind:'transaction',component:'Custos recorrentes de moradia'},
        {date:'2026-09-01',date_label:'09/2026',description:'IPTU e seguro residencial',account_source:'Itaú / cartão',counterparty:'Prefeitura / Seguros',center_cost:'Casa',amount:70593.77,row_kind:'monthly_category_total',component:'Custos recorrentes de moradia'}
      ]
    };
  }
  return{version:'expense-group-detail-v1-v177',group,subgroup,total:0,row_count:0,reconciles:true,rows:[]};
}
function wealthFixture(){return{...baseWealth,wealth:{...(baseWealth.wealth||{}),summary:{known_debt_total:450000},liquidity:{bank_cash:10000,d0:0},assets:{}},pensions:{total_gross_brl:0,positions:[]},rsu_summary:{available_total_brl:0,future_considered_total_brl:0},morgan_statement:{available_total_brl:0,future_components:{future_after_reserve_brl:0}},financing:{summary:{commitments:[]},documentary:{items:[]}}}}
function flowFixture(from,to){return{ok:true,flow:{from,to,historical:{days:[],events:[]},current_future:{days:[],events:[]}}}}

async function frameReady(page,label){
  for(let i=0;i<300;i++){
    const f=page.frames().find(x=>{try{return new URL(x.url()).pathname.endsWith('/index.html')}catch{return false}});
    if(f&&await f.evaluate(()=>Boolean(window.__LTS_V177_EXPENSE_UX?.installed&&document.querySelector('.v168-dashboard'))).catch(()=>false))return f;
    await page.waitForTimeout(100);
  }
  await page.screenshot({path:'v177-'+label+'-failure.png',fullPage:true});throw Error(label+': V177 frame not ready');
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
    else if(name==='lts_browser_expense_executive_v10')body=expenseFixture(args.p_from,args.p_to);
    else if(/^lts_browser_expense_executive_v/.test(name))body=expenseFixture(args.p_from,args.p_to);
    else if(name==='lts_browser_expense_group_detail_v1')body=detailFixture(args.p_group,args.p_subgroup);
    else if(/^lts_browser_monthly_balance_v/.test(name))body={version:'monthly-balance-v6-v176-window-integrity',months:[],monthly_totals:[],totals:{},revenue_groups:[],expense_groups:[],extraordinary_groups:[],expense_unclassified_card_coverage:{total:0,monthly:[]}};
    else if(/^lts_browser_flow_v/.test(name))body=flowFixture(args.p_from,args.p_to);
    else if(/^lts_browser_wealth_detail_v/.test(name))body=wealthFixture();
    else if(name==='lts_browser_recurring_future_gap_audit_v5')body={horizon_checks:[],items:[]};
    else if(name==='lts_browser_open_finance_status_v1')body={status:'not_connected'};
    else if(name==='lts_browser_transactions_v2')body={rows:[]};
    else if(name==='lts_browser_expense_context_lens_v1'||name==='lts_browser_expense_context_nature_v1')body={contexts:[],natures:[],summary:{}};
    await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)});
  });

  await page.goto(BASE+'/wip35-v177-candidate.html',{waitUntil:'domcontentloaded'});
  const frame=await frameReady(page,label),nav=n=>viewport.width<=520?frame.locator('#dx1MobileNav [data-mobile-route="'+n+'"]'):frame.locator('.nav [data-v="'+n+'"]');
  await nav('Despesas').click();
  await frame.locator('[data-v168-exp-range="all"]').click();
  await frame.waitForFunction(()=>window.__LTS_V175_STATE?.expense?.data?.version==='expense-executive-v19-v177-property-rollup');
  await frame.locator('.v168-tabs [data-v168-exp-tab="categories"]').click();await frame.locator('.v175-categories').waitFor();
  await frame.locator('.v175-categories details').evaluateAll(ns=>ns.forEach(n=>n.open=true));
  let text=semantic(await frame.locator('.v175-categories').innerText());
  for(const phrase of [semantic('Apartamento · CIPÓ 396'),semantic('Aquisição do imóvel'),semantic('Financiamento imobiliário'),semantic('Obra e reforma'),semantic('Custos recorrentes de moradia'),semantic(brl(4529057.60)),semantic(brl(263909.54))])
    if(!text.includes(phrase))throw Error(label+': category UX missing '+phrase);
  for(const forbidden of ['fonte reconciliada','planilha original','duplicidade móveis'])
    if(text.includes(semantic(forbidden)))throw Error(label+': technical reconciliation leaked '+forbidden);

  const familyRow=frame.locator('.v175-rankrow').filter({hasText:'Família — saídas'}).first();
  await familyRow.locator(':scope > strong').click();
  await page.waitForTimeout(100);
  await frame.evaluate(()=>Boolean(window.__LTS_V177_STATE?.detail?.open));
  const drawer=frame.locator('#v177ExpenseDrawer .v177-drawer');
  await drawer.waitFor();
  text=semantic(await drawer.innerText());
  for(const phrase of [semantic('Família — saídas'),semantic(brl(263909.54)),'13/08/2026','larissa','itaú'])
    if(!text.includes(phrase))throw Error(label+': family drawer missing '+phrase);
  if(!calls.some(x=>x.name==='lts_browser_expense_group_detail_v1'&&x.args.p_group==='Família — saídas'))throw Error(label+': family detail RPC missing');
  await drawer.locator('[data-v177-close]').click();

  const apartmentRow=frame.locator('.v175-rankrow').filter({hasText:'Apartamento · CIPÓ 396'}).first();
  await apartmentRow.locator(':scope > strong').click();await frame.locator('#v177ExpenseDrawer .v177-drawer').waitFor();
  text=semantic(await frame.locator('#v177ExpenseDrawer .v177-drawer').innerText());
  for(const phrase of [semantic(brl(4529057.60)),semantic('Aquisição do imóvel'),semantic('Financiamento imobiliário'),semantic('Obra e reforma'),semantic('Custos recorrentes de moradia')])
    if(!text.includes(phrase))throw Error(label+': apartment drawer missing '+phrase);
  await frame.locator('#v177ExpenseDrawer [data-v177-close]').first().click();

  const subgroup=apartmentRow.locator('details em').filter({hasText:'Custos recorrentes de moradia'}).first();
  await subgroup.click();await frame.locator('#v177ExpenseDrawer .v177-drawer').waitFor();
  text=semantic(await frame.locator('#v177ExpenseDrawer .v177-drawer').innerText());
  for(const phrase of [semantic(brl(364579.90)),'condomínio','energia elétrica','seguro residencial'])
    if(!text.includes(semantic(phrase)))throw Error(label+': recurring-housing detail missing '+phrase);
  await frame.locator('#v177ExpenseDrawer [data-v177-close]').first().click();

  await nav('Dashboard').click();await page.waitForTimeout(900);
  text=semantic(await frame.locator('.v168-dashboard').innerText());
  if(!text.includes(semantic('Apartamento · CIPÓ 396')))throw Error(label+': dashboard did not adopt apartment roll-up');
  if(text.includes(semantic('fonte reconciliada')))throw Error(label+': dashboard leaked technical badge');

  const dims=await frame.locator('html').evaluate(e=>({s:e.scrollWidth,c:e.clientWidth}));if(dims.s>dims.c+3)throw Error(label+': horizontal overflow '+JSON.stringify(dims));
  if(errors.length)throw Error(label+': page errors '+JSON.stringify(errors));
  await page.screenshot({path:'v177-'+label+'-final.png',fullPage:true});
  await context.close();
  return{label,pass:true,detailCalls:calls.filter(x=>x.name==='lts_browser_expense_group_detail_v1').length};
}

(async()=>{
  const browser=await chromium.launch({headless:true});
  try{
    const results=[await run(browser,{width:1440,height:1000},'desktop'),await run(browser,{width:390,height:844},'mobile')];
    const out={pass:true,version:'v177-expense-ux',data:'controlled-fixture-not-user-data-validation',results};
    fs.writeFileSync('v177-expense-ux-result.json',JSON.stringify(out,null,2));console.log(JSON.stringify(out,null,2));
  }catch(error){
    const out={pass:false,error:String(error.stack||error)};fs.writeFileSync('v177-expense-ux-result.json',JSON.stringify(out,null,2));console.error(out.error);process.exitCode=1;
  }finally{await browser.close()}
})();