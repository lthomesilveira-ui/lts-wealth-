'use strict';
const {chromium}=require('playwright');
const fs=require('node:fs');
const {cockpit,wealth:baseWealth,product:baseProduct,expensePayload}=require('./lts_v165_executive_ux_gate.js');
const BASE='http://127.0.0.1:'+(process.env.LTS_V176_PORT||8786);
const session={access_token:'fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};
const semantic=v=>String(v||'').replace(/\s+/g,' ').trim().toLocaleLowerCase('pt-BR');
const brl=v=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(v);

function productFixture(){
 const p=baseProduct();
 p.card_operating={...(p.card_operating||{}),open_cycles:[],closed_or_due:[],contracted_installment_floor_months:[],classification_review:{}};
 return p;
}
function expenseFixture(from,to){
 const x=expensePayload(from,to),six=from==='2026-04-01';
 x.version='expense-executive-v18-v176-window-integrity';
 x.management_groups=[
  {name:'Saúde',total:six?56307.56:105050.49,rows:61,subgroups:[
   {name:'Saúde geral / não atribuído',total:six?36146.23:63800.29,rows:40},
   {name:'Larissa',total:six?10515:17515,rows:5},
   {name:'Benjamin',total:six?9646.33:23735.2,rows:16}
  ]},
  {name:'Empréstimos',total:six?38691.93:109227.39,rows:six?7:19,subgroups:[
   {name:'Histórico pago · Itaú',total:six?20887.85:64717.19,rows:six?3:9},
   {name:'Empréstimo consignado · Coopharma',total:six?17804.08:44510.2,rows:six?4:10}
  ]}
 ];
 x.coverage_disclosure={total:0,rows:0,months:0};
 x.window_integrity={from,to,no_workbook_month_outside_range:true,workbook_months_used:six?['2026-04-01','2026-05-01','2026-06-01']:['2025-11-01','2025-12-01','2026-01-01','2026-02-01','2026-03-01','2026-04-01','2026-05-01','2026-06-01']};
 return x;
}
function wealthFixture(){return{...baseWealth,wealth:{...(baseWealth.wealth||{}),summary:{known_debt_total:450000},liquidity:{bank_cash:10000,d0:0},assets:{}},pensions:{total_gross_brl:0,positions:[]},rsu_summary:{available_total_brl:15913.44,future_considered_total_brl:0},morgan_statement:{available_total_brl:15913.44,future_components:{future_after_reserve_brl:0}},financing:{summary:{commitments:[]},documentary:{items:[]}}}}
function flowFixture(from,to){
 const day=(date,entries,exits,bank,rsu)=>({date,is_today:false,summary:{events:(entries||exits)?1:0,transfers:0,Consolidado:{entries,exits},asset_movements:0},Consolidado:{bank_balance:bank,economic_net:entries-exits,unassigned_net:0},Itaú:{net:0,balance:5642.16},Bradesco:{net:exits?-exits:0,balance:-62001.79},C6:{net:0,balance:-1486.38},fix86_columns:{saldo_anterior:bank-(entries-exits),entradas:entries,saidas:exits,saldo_final:bank,liq_d0_1_recurso:43016.64,saldo_apos_d0_1:bank+43016.64,rsus_vested:rsu,saldo_apos_rsu:bank+43016.64+rsu,fgts:29832.31,saldo_apos_fgts:bank+43016.64+rsu+29832.31}});
 const days=[
  day('2026-11-07',0,0,-53559.58,15913.44),
  day('2026-11-08',0,2886.43,-56446.01,37659.42),
  day('2026-11-09',0,1400,-57846.01,37659.42),
  day('2026-11-10',0,0,-57846.01,54970.37),
  day('2026-11-11',0,0,-57846.01,54970.37)
 ];
 const events=[
  {source:'future_award_vesting_marker',account:'Corretora',category:'RSU',event_date:'2026-11-07',description:'Vesting RSU',signed_amount:0,non_cash_marker:true},
  {source:'future_rsu_available',account:'Corretora',category:'RSU',event_date:'2026-11-08',description:'RSU disponível após liquidação',signed_amount:21745.98,liquidity_layer:'D+3'},
  {source:'current_event',account:'Bradesco',category:'Financiamento veículo',event_date:'2026-11-08',description:'Parcela financiamento Volvo',signed_amount:-2886.43,source_ref:'volvo_financing_2026_p03',confidence:'user_flow_editable'},
  {source:'legacy_fix86',account:'Itaú',category:'Energia',event_date:'2026-11-09',description:'Enel - O Parque',signed_amount:-1400,source_ref:'evento_base:3448'},
  {source:'future_rsu_available',account:'Corretora',category:'RSU',event_date:'2026-11-10',description:'RSU disponível após liquidação',signed_amount:17310.95,liquidity_layer:'D+3'}
 ];
 return{ok:true,flow:{from,to,available_year_from:2013,available_year_to:2041,historical:{days:[],events:[]},current_future:{from,to,days,events}}};
}
async function ready(page,label){
 for(let i=0;i<300;i++){const f=page.frames().find(x=>{try{return new URL(x.url()).pathname.endsWith('/index.html')}catch{return false}});if(f&&await f.evaluate(()=>Boolean(window.__LTS_V176_FLOW_EXPENSE_AUDIT?.installed&&document.querySelector('.v168-dashboard'))).catch(()=>false))return f;await page.waitForTimeout(100)}
 await page.screenshot({path:'v176-'+label+'-failure.png',fullPage:true});throw Error(label+': frame not ready');
}
async function run(browser,viewport,label){
 const context=await browser.newContext({viewport});
 await context.addInitScript(f=>{const N=Date,ms=N.parse(f);class F extends N{constructor(...a){super(...(a.length?a:[ms]))}static now(){return ms}}window.Date=F},'2026-09-18T12:00:00Z');
 await context.addInitScript(v=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(v)),session);
 const page=await context.newPage();page.setDefaultTimeout(30000);const calls=[],errors=[];page.on('pageerror',e=>errors.push(String(e.message||e)));
 await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
  const req=route.request(),name=new URL(req.url()).pathname.split('/').pop();let args={};try{args=JSON.parse(req.postData()||'{}')}catch{}calls.push({name,args});
  let body={ok:true,rows:[],items:[]};
  if(name==='token')body=session;
  else if(name==='lts_browser_product_v1')body={ok:true,mvp:productFixture()};
  else if(name==='lts_browser_dashboard_cockpit_v1')body=cockpit;
  else if(name==='lts_browser_expense_executive_v9')body=expenseFixture(args.p_from,args.p_to);
  else if(/^lts_browser_expense_executive_v/.test(name))body=expenseFixture(args.p_from,args.p_to);
  else if(/^lts_browser_monthly_balance_v/.test(name))body={version:'monthly-balance-v6-v176-window-integrity',months:[],monthly_totals:[],totals:{},revenue_groups:[],expense_groups:[],extraordinary_groups:[],expense_unclassified_card_coverage:{total:0,monthly:[]}};
  else if(/^lts_browser_flow_v/.test(name))body=flowFixture(args.p_from,args.p_to);
  else if(/^lts_browser_wealth_detail_v/.test(name))body=wealthFixture();
  else if(name==='lts_browser_recurring_future_gap_audit_v5')body={horizon_checks:[],items:[]};
  else if(name==='lts_browser_open_finance_status_v1')body={status:'not_connected'};
  else if(name==='lts_browser_transactions_v2')body={rows:[]};
  else if(name==='lts_browser_expense_context_lens_v1'||name==='lts_browser_expense_context_nature_v1')body={contexts:[],natures:[],summary:{}};
  await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)});
 });
 await page.goto(BASE+'/wip35-v176-candidate.html',{waitUntil:'domcontentloaded'});
 const frame=await ready(page,label),nav=n=>viewport.width<=520?frame.locator('#dx1MobileNav [data-mobile-route="'+n+'"]'):frame.locator('.nav [data-v="'+n+'"]');

 await nav('Fluxo de caixa').click().catch(async()=>{await nav('Fluxo Diário').click()});
 await frame.evaluate(()=>loadFlowRange('2026-11-07','2026-11-11'));
 await frame.waitForSelector('#d-2026-11-10');
 let row8=frame.locator('#d-2026-11-08'),cells=row8.locator('.fx87-cell');
 const entry8=semantic(await cells.nth(2).innerText()),exit8=semantic(await cells.nth(3).innerText()),rsu8=semantic(await cells.nth(7).innerText());
 if(!entry8.includes(semantic(brl(0))))throw Error(label+': RSU leaked into Entradas '+entry8);
 if(!exit8.includes(semantic(brl(2886.43))))throw Error(label+': cash exit lost '+exit8);
 if(!rsu8.includes(semantic(brl(21745.98))))throw Error(label+': RSU delta not shown in RSU column '+rsu8);
 await row8.locator('.exp').click();const detail8=semantic(await frame.locator('.fx89-details').filter({has:frame.locator('text=Financiamento')}).first().innerText().catch(()=>''));if(detail8.includes('corretora')||detail8.includes('rsu disponivel'))throw Error(label+': non-cash RSU remains in cash detail '+detail8);
 const zero=frame.locator('#flowZero');await zero.click();await frame.waitForTimeout(100);
 if(await frame.locator('#d-2026-11-10').count())throw Error(label+': RSU-only day survived hide-zero');
 if(await frame.locator('#d-2026-11-07').count())throw Error(label+': marker-only day survived hide-zero');
 if(await frame.locator('#d-2026-11-11').count())throw Error(label+': carried-balance day survived hide-zero');
 if(!(await frame.locator('#d-2026-11-08').count())||!(await frame.locator('#d-2026-11-09').count()))throw Error(label+': real cash days were hidden');
 const filterState=await frame.evaluate(()=>({SHOWZERO,FLOWFORCEZERO}));if(filterState.SHOWZERO||filterState.FLOWFORCEZERO)throw Error(label+': hide-zero state wrong '+JSON.stringify(filterState));

 await nav('Despesas').click();
 await frame.locator('[data-v168-exp-range="6m"]').click();
 await frame.waitForFunction(()=>window.__LTS_V175_STATE?.expense?.data?.version==='expense-executive-v18-v176-window-integrity');
 await frame.locator('.v168-tabs [data-v168-exp-tab="categories"]').click();await frame.locator('.v175-categories').waitFor();
 await frame.locator('.v175-categories details').evaluateAll(ns=>ns.forEach(n=>n.open=true));
 let text=semantic(await frame.locator('.v175-categories').innerText());
 for(const p of [semantic(brl(56307.56)),semantic(brl(38691.93)),semantic('Saúde geral / não atribuído'),semantic('Histórico pago · Itaú')])if(!text.includes(p))throw Error(label+': 6m audit missing '+p);
 if(text.includes(semantic(brl(92359.98))))throw Error(label+': inflated 6m Saúde remains');
 if(!calls.some(x=>x.name==='lts_browser_expense_executive_v9'&&x.args.p_from==='2026-04-01'))throw Error(label+': V176 expense reader was not used for 6m');

 await frame.locator('[data-v168-exp-range="12m"]').click();
 await frame.waitForFunction(()=>window.__LTS_V175_STATE?.expense?.data?.version==='expense-executive-v18-v176-window-integrity'&&window.__LTS_V175_STATE.expense.key.startsWith('2025-10-01'));
 await frame.locator('.v168-tabs [data-v168-exp-tab="categories"]').click();await frame.locator('.v175-categories').waitFor();
 text=semantic(await frame.locator('.v175-categories').innerText());
 for(const p of [semantic(brl(105050.49)),semantic(brl(109227.39))])if(!text.includes(p))throw Error(label+': 12m audit missing '+p);

 const dims=await frame.locator('html').evaluate(e=>({s:e.scrollWidth,c:e.clientWidth}));if(dims.s>dims.c+3)throw Error(label+': horizontal overflow '+JSON.stringify(dims));
 if(errors.length)throw Error(label+': page errors '+JSON.stringify(errors));
 await page.screenshot({path:'v176-'+label+'-final.png',fullPage:true});
 await context.close();
 return{label,pass:true,filterState};
}
(async()=>{const browser=await chromium.launch({headless:true});try{const results=[await run(browser,{width:1440,height:1000},'desktop'),await run(browser,{width:390,height:844},'mobile')],out={pass:true,version:'v176',results};fs.writeFileSync('v176-flow-expense-audit-result.json',JSON.stringify(out,null,2));console.log(JSON.stringify(out,null,2))}catch(e){const out={pass:false,error:String(e.stack||e)};fs.writeFileSync('v176-flow-expense-audit-result.json',JSON.stringify(out,null,2));console.error(out.error);process.exitCode=1}finally{await browser.close()}})();