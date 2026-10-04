'use strict';
const {chromium}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const {product,cockpit,wealth}=require('./lts_v165_executive_ux_gate.js');
const session={access_token:'balance-fixture',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};
const shift=(date,n)=>{const d=new Date(date+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10)};
function row(date){const change=date>='2026-10-02'?-100:0,itau=100+change,bradesco=200,c6=300,fin=itau+bradesco+c6;return{date,is_today:date==='2026-10-01',historical:date<'2026-10-01',Itaú:{balance:itau,net:date==='2026-10-02'?-100:0},Bradesco:{balance:bradesco,net:0},C6:{balance:c6,net:0},Consolidado:{bank_balance:fin,economic_net:date==='2026-10-02'?-100:0},summary:{events:date==='2026-10-02'?1:0,Consolidado:{entries:0,exits:date==='2026-10-02'?100:0}},fix86_columns:{saldo_anterior:date==='2026-10-02'?600:fin,entradas:0,saidas:date==='2026-10-02'?100:0,saldo_final:fin,liq_d0_1_recurso:400,rsus_vested:200,fgts:50,saldo_apos_d0_1:fin+400,saldo_apos_rsu:fin+600,saldo_apos_fgts:fin+650}};}
function flow(from,to){const days=[];for(let date=from;date<=to;date=shift(date,1))days.push(row(date));const events=from<='2026-10-02'&&to>='2026-10-02'?[{source:'current_event',source_ref:'future-known',event_date:'2026-10-02',account:'Itaú',signed_amount:-100,description:'Despesa prevista',category:'Seguros',confidence:'user_flow_editable'}]:[];return{ok:true,flow:{from,to,historical:{days:days.filter(d=>d.historical),events:[]},current_future:{days:days.filter(d=>!d.historical),events}}};}
async function run(browser,width){
 const ctx=await browser.newContext({viewport:{width,height:1000}});
 await ctx.addInitScript(s=>{localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s));const Native=Date;window.__qaNow='2026-10-01T13:00:00Z';class Fixed extends Native{constructor(...a){super(...(a.length?a:[window.__qaNow]))}static now(){return Native.parse(window.__qaNow)}}window.Date=Fixed;},session);
 const page=await ctx.newPage(),errors=[],calls=[];let f;page.on('pageerror',e=>errors.push(String(e)));let fail=false;
 await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
  const req=route.request(),name=new URL(req.url()).pathname.split('/').pop();let a={};try{a=JSON.parse(req.postData()||'{}')}catch{}calls.push({name,args:a});let data={ok:true,rows:[],items:[]},status=200;
  if(name==='token')data=session;
  else if(name==='lts_browser_product_v1'){const p=product(),bad=row('2026-10-01');bad.fix86_columns.saldo_final=-8888.88;bad.fix86_columns.saldo_anterior=-8888.88;bad.Consolidado.bank_balance=42;p.flow={days:[bad],events:[]};data={ok:true,mvp:p};}
  else if(name==='lts_browser_dashboard_cockpit_v1')data=cockpit;
  else if((name==='lts_browser_cash_today_v178'||name==='lts_browser_cash_today_v242'))data={version:'cash-today-v179-current-canonical',status:'complete',as_of:'2026-10-01',cash:600,d0:400,brokerage_available:200,available_total:1200,fgts:50,day:row('2026-10-01')};
  else if(name.startsWith('lts_browser_wealth_detail'))data=wealth;
  else if(/^lts_browser_flow_v/.test(name)){await new Promise(r=>setTimeout(r,150));if(fail){status=400;data={code:'22023',message:'fixture unavailable'};}else data=flow(a.p_from,a.p_to);}
  else if(/^lts_browser_expenses_|^lts_browser_expense_executive_/.test(name))data={period:{from:a.p_from,to:a.p_to},summary:{selected_total:10,card_total:5,account_total:5,monthly_average:10,rows:1,pending_identification:0},management_groups:[],monthly_detail:[],coverage_disclosure:{total:0,rows:0}};
  else if(name==='lts_browser_open_finance_refresh_v1'){status=503;data={message:'fixture bank sync disabled'};}
  else if(name==='lts_browser_open_finance_status_v1')data={connected:true,connections:['341','237','336'].map(institution_code=>({institution_code,status:'connected',last_success_at:'2026-10-01T12:00:00Z'}))};
  else if(name==='lts_browser_open_finance_pending_v225')data={transaction_count:0,rows:[]};
  else if(name==='lts_browser_card_cycles_v229')data={version:'card-cycles-v226',as_of:'2026-10-01',cards:[]};
  await route.fulfill({status,contentType:'application/json',body:JSON.stringify(data)});
 });
 try{
  await page.goto('http://127.0.0.1:8788/releases/'+(process.env.LTS_RELEASE||'v236')+'/app.html');
  for(let i=0;i<200;i++){f=page.frames().find(x=>x.url().includes('/index.html'));if(f&&await f.evaluate(()=>!!window.__LTS_V226).catch(()=>false))break;await page.waitForTimeout(100)}assert(f);page.setDefaultTimeout(30000);
  const nav=name=>width<520?f.locator('#dx1MobileNav [data-mobile-route="'+name+'"]'):f.locator('.nav [data-v="'+name+'"]');
  await f.waitForFunction(()=>window.__LTS_V178_STATE.forecast.status==='ready'&&window.__LTS_V178_STATE.dashboardReport.status==='ready');
  assert.match(await f.locator('.v168-kpi').filter({has:f.locator('span').filter({hasText:/^Contas correntes hoje$/})}).innerText(),/600,00/,'Dashboard uses the independently verified cash reader');
  // Exercise the uncached period path; V242 shared forecast reuse has its own gate.
  if(['v242','v244'].includes(process.env.LTS_RELEASE))await f.evaluate(()=>{window.__LTS_V178_REVIEW.cachedFlow=()=>null});
  // Reproduce the observed product path before a canonical period response exists.
  await f.evaluate(()=>{FLOWQ=null;FLOWLOADING=false;V='Fluxo Diário';renderNav();render();});
  assert.equal(await f.evaluate(()=>mergedFlowDays().length),0,'no period response may borrow old product balances');
  assert.equal(await f.locator('.fx87-row[id^="d-"]').count(),0,'legacy product rows are never rendered as current cash');
  assert(!(await f.locator('#app').innerText()).includes('8.888,88'),'wrong old closing never appears');
  assert.match(await f.locator('#app').innerText(),/Carregando (?:Fluxo|fluxo de caixa)/,'an explicit pending state replaces the old fallback');
  await nav('Fluxo Diário').click();await f.waitForFunction(()=>!FLOWLOADING&&FLOWQ&&!FLOWQ.error);
  assert.match(await f.locator('#d-2026-10-01').innerText(),/600,00/);
  assert.match(await f.locator('#d-2026-10-02').innerText(),/500,00/);
  for(const [bank,expected] of [['Itaú','100,00'],['Bradesco','200,00'],['C6','300,00'],['Consolidado','600,00']]){
   await f.locator('[data-a="'+bank+'"]').click();const text=await f.locator('#d-2026-10-01').innerText();assert(text.includes(expected),bank+' closes from the canonical period');
  }
  await f.evaluate(()=>loadFlowRange('2026-10-02','2026-10-03'));assert.match(await f.locator('#d-2026-10-02').innerText(),/500,00/,'a sliced future range retains the same anchor and cumulative movements');
  await f.evaluate(()=>{V='Dashboard';renderNav();render();});await nav('Fluxo Diário').click();await f.waitForFunction(()=>!FLOWLOADING&&FLOWQ&&!FLOWQ.error);assert.match(await f.locator('#app').innerText(),/Fluxo Diário/,'a cached navigation repaints the requested route');assert.match(await f.locator('#d-2026-10-02').innerText(),/500,00/,'returning from Dashboard preserves a canonical balance');
  await f.evaluate(async()=>{await Promise.all([loadFlowRange('2024-02-01','2024-02-03'),loadFlowRange('2025-02-01','2025-02-03')])});
  assert.equal(await f.evaluate(()=>FLOWFROM),'2025-02-01');assert.equal(await f.locator('#d-2024-02-01').count(),0,'an older response cannot repopulate a newer period');
  fail=true;await f.evaluate(()=>loadFlowRange('2026-11-01','2026-11-02'));assert.equal(await f.locator('.fx87-mesa:visible').count(),0,'failed period does not expose another response');assert(!(await f.locator('#app').innerText()).includes('8.888,88'));
  fail=false;await f.evaluate(()=>window.__LTS_V227_TRANSPORT.invalidate());await f.evaluate(()=>loadFlowRange('2026-10-01','2026-10-03'));assert.match(await f.locator('#d-2026-10-01').innerText(),/600,00/,'recovery returns canonical cash');
  await f.evaluate(()=>loadFlowRange('2018-01-01','2018-01-02'));
  for(const bank of ['Itaú','Bradesco','C6','Consolidado']){
   await f.locator('[data-a="'+bank+'"]').click();const cells=await f.locator('#d-2018-01-01').locator(':scope > *').allTextContents();assert.equal(cells[1].trim(),'—','unsupported opening stays unavailable for '+bank);assert.equal(cells[4].trim(),'—','unsupported closing stays unavailable for '+bank);
  }
  await f.locator('[data-a="Consolidado"]').click();await f.evaluate(()=>loadFlowRange('2026-10-01','2026-10-03'));
  await f.evaluate(()=>{FLOWQ=null;FLOWLOADING=false;render();});assert.equal(await f.locator('.fx87-row[id^="d-"]').count(),0,'refresh invalidation cannot resurrect product cash');
  await f.evaluate(()=>{window.__qaNow='2026-10-02T13:00:00Z'});await f.locator('#flowDefaultRange').click();await f.waitForFunction(()=>!FLOWLOADING&&FLOWFROM==='2026-09-27');assert.match(await f.locator('#d-2026-10-02').innerText(),/500,00/,'the next day retains the canonical ledger');
  await page.screenshot({path:'qa/v236-'+width+'-balances.png',fullPage:true});assert.deepEqual(errors,[]);return{width,pass:true,no_product_fallback:true,three_banks_and_consolidated:true,selected_range_independent:true,newer_period_wins:true,error_and_recovery:true,refresh_and_rollover:true};
 }catch(e){await page.screenshot({path:'qa/v236-'+width+'-balance-failure.png',fullPage:true});fs.writeFileSync('qa/v236-'+width+'-balance-failure.json',JSON.stringify({error:String(e),errors,calls,runtime:await f.evaluate(()=>({route:V,from:FLOWFROM,to:FLOWTO,loading:FLOWLOADING,dataFrom:FLOWQ?.from,dataTo:FLOWQ?.to,body:document.getElementById('app')?.innerText.slice(0,700)})).catch(()=>null)},null,2));throw e}finally{await ctx.close()}
}
(async()=>{fs.mkdirSync('qa',{recursive:true});const b=await chromium.launch();try{const result=[];for(const width of[1440,390])result.push(await run(b,width));fs.writeFileSync('qa/v236-balances.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));}finally{await b.close()}})().catch(e=>{console.error(e);process.exitCode=1});
