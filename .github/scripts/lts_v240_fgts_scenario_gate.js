'use strict';
const {chromium}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const {product,cockpit,wealth}=require('./lts_v165_executive_ux_gate.js');
const session={access_token:'daily-liquidity-fixture',refresh_token:'fixture',expires_at:4102444800,user:{id:'fixture-user'}};
const shift=(d,n)=>{const x=new Date(d+'T12:00:00Z');x.setUTCDate(x.getUTCDate()+n);return x.toISOString().slice(0,10)};
function row(date){
 const cash=date==='2026-12-30'?-1700:date==='2027-01-12'?-3100:date==='2027-01-30'?-5000:600;
 const accrual=(Number(date>='2026-11-30')+Number(date>='2026-12-31'))*1200;
 return{date,is_today:date==='2026-10-04',Itaú:{balance:cash,net:0},Bradesco:{balance:0,net:0},C6:{balance:0,net:0},Consolidado:{bank_balance:cash,economic_net:0},summary:{events:0,Consolidado:{entries:0,exits:0}},fix86_columns:{saldo_anterior:cash,saldo_final:cash,entradas:0,saidas:0,liq_d0_1_recurso:400,rsus_vested:200,fgts:50+accrual,fgts_documental:50,fgts_aportes_projetados:accrual,saldo_apos_d0_1:cash+400,saldo_apos_rsu:cash+600,saldo_apos_fgts:cash+650+accrual,saldo_apos_fgts_documental:cash+650}};
}
function flow(from,to){const days=[];for(let d=from;d<=to;d=shift(d,1))days.push(row(d));return{ok:true,flow:{from,to,fgts_projection_contract:{enabled:true,monthly_estimate_brl:1200},historical:{days:[],events:[]},current_future:{days,events:[]}}};}
async function run(browser,width){
 const ctx=await browser.newContext({viewport:{width,height:1000}});await ctx.addInitScript(s=>{localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s));const N=Date;class Fixed extends N{constructor(...a){super(...(a.length?a:['2026-10-04T13:00:00Z']))}static now(){return N.parse('2026-10-04T13:00:00Z')}}window.Date=Fixed;},session);
 const page=await ctx.newPage(),errors=[],calls=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
  const req=route.request(),name=new URL(req.url()).pathname.split('/').pop();let a={};try{a=JSON.parse(req.postData()||'{}')}catch{}calls.push(name);let data={ok:true,rows:[],items:[]},status=200;
  if(name==='token')data=session;
  else if(name==='lts_browser_product_v1')data={ok:true,mvp:product()};
  else if(name==='lts_browser_dashboard_cockpit_v1')data=cockpit;
  else if(name==='lts_browser_cash_today_v178')data={version:'cash-today-v179-current-canonical',status:'complete',as_of:'2026-10-04',cash:600,d0:400,brokerage_available:200,available_total:1200,fgts:50,day:row('2026-10-04')};
  else if(name.startsWith('lts_browser_wealth_detail'))data=wealth;
  else if(/^lts_browser_flow_v/.test(name))data=flow(a.p_from,a.p_to);
  else if(name==='lts_browser_planning_ui_contract_v240')data={version:'planning-ui-contract-v2',period_to:'2027-12-31',d01_first_need:'2026-12-30',rsu_first_need:'2026-12-30',fgts_first_negative:'2026-12-30',labels:{d01:'Caixa após D0 em 30/12/2026',rsu:'RSUs e vestings em 30/12/2026',fgts:'Mesmo com FGTS, a primeira falta ocorre em 30/12/2026'}};
  else if(/^lts_browser_expenses_|^lts_browser_expense_executive_/.test(name))data={summary:{selected_total:10},period:{from:a.p_from,to:a.p_to}};
  else if(name==='lts_browser_open_finance_refresh_v1'){status=503;data={message:'fixture sync disabled'};}
  else if(name==='lts_browser_open_finance_status_v1')data={connected:true,connections:[]};
  else if(name==='lts_browser_open_finance_pending_v225')data={transaction_count:0,rows:[]};
  else if(name==='lts_browser_card_cycles_v229')data={cards:[]};
  await route.fulfill({status,contentType:'application/json',body:JSON.stringify(data)});
 });
 try{
  await page.goto('http://127.0.0.1:8788/releases/'+(process.env.LTS_RELEASE||'v240')+'/app.html');
  let f;for(let i=0;i<200;i++){f=page.frames().find(x=>x.url().includes('/index.html'));if(f&&await f.evaluate(()=>!!window.__LTS_V226).catch(()=>false))break;await page.waitForTimeout(100)}assert(f);
  await f.waitForSelector('[data-v239-fgts-summary]');await f.waitForFunction(()=>!window.__LTS_V168_STATE.dashboard.loading&&window.__LTS_V178_STATE?.forecast?.status==='ready'&&window.__LTS_V178_STATE?.dashboardReport?.status==='ready'&&window.__LTS_V178_STATE?.cash?.status==='ready');
  const text=await f.locator('[data-v239-fgts-summary]').innerText();assert.match(text,/FGTS projetado: primeiro déficit em 12\/01\/2027/);assert.match(text,/mínimo.*1\.950,00.*30\/01\/2027/);
  assert.equal(await f.locator('[data-v239-first-negative]').getAttribute('data-v239-first-negative'),'2027-01-12');
  const documented=await f.locator('[data-v240-documental-summary]').innerText();assert.match(documented,/primeiro déficit em 30\/12\/2026/);assert.match(documented,/mínimo.*4\.350,00.*30\/01\/2027/);assert.match(documented,/1\.200,00 por mês/);
  const path=await f.locator('.v168-chart path.fgts').getAttribute('d');assert(path.split('L').length>=450,'daily points, not monthly endpoints');
  assert((await f.locator('.v168-chart path.fgts-documental').getAttribute('d')).split('L').length>=450,'documentary comparison also daily');
  assert.match(await f.locator('.v168-legend').innerText(),/Com FGTS projetado/);assert.match(text,/Depósitos projetados não são saldo recebido/);
  assert(calls.includes('lts_browser_flow_v240'));assert(!calls.includes('lts_browser_flow_v229'),'frozen documentary reader must not be used for the projected scenario');
  assert(!(await f.locator('#app').innerText()).includes('Somente posições já disponíveis entram neste cenário.'));
  const points=await f.evaluate(()=>window.__LTS_V168_STATE.dashboard.data.flow.flow.current_future.days);assert.equal(points.at(-1).date,'2027-12-31');assert(points.find(x=>x.date==='2026-12-31').fix86_columns.saldo_apos_fgts>0,'positive month-end must not hide Dec30');
  assert(!calls.some(x=>/mutate|classify|create_future/.test(x)));assert.deepEqual(errors,[]);
  // Dashboard can repaint after a secondary reader completes. Re-resolve the chart;
  // a DOM-detachment during capture must not be confused with a failed assertion.
  await f.evaluate(()=>document.querySelector('.v168-chart').scrollIntoView({block:'center'}));
  await page.waitForTimeout(150);
  const box=await f.locator('.v168-chart').boundingBox();assert(box&&box.width>0&&box.height>0);
  await page.screenshot({path:'qa/v240-'+width+'-liquidity-chart.png',clip:box});
  await page.screenshot({path:'qa/v240-'+width+'-daily-liquidity.png',fullPage:true});return{width,pass:true,daily_points:points.length,negative_before_positive_month_end:true,first_negative_and_daily_minimum:true,conditional_vestings_disclosed:true,no_financial_write:true};
 }finally{await ctx.close()}
}
(async()=>{fs.mkdirSync('qa',{recursive:true});const b=await chromium.launch();try{const results=[];for(const width of[1440,390])results.push(await run(b,width));fs.writeFileSync('qa/v240-daily-liquidity.json',JSON.stringify(results,null,2));console.log(JSON.stringify(results));}finally{await b.close()}})().catch(e=>{console.error(e);process.exitCode=1});
