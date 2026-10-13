'use strict';
const {chromium,webkit}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const {product,cockpit,wealth}=require('./lts_v165_executive_ux_gate.js');
const session={access_token:'v268-fixture',refresh_token:'fixture',expires_at:4102444800,user:{id:'fixture-user'}};
const shift=(d,n)=>{const x=new Date(d+'T12:00:00Z');x.setUTCDate(x.getUTCDate()+n);return x.toISOString().slice(0,10)};
function day(date){return {date,Consolidado:{bank_balance:1234.56,economic_net:0},Itaú:{balance:1200,net:0},Bradesco:{balance:34.56,net:0},C6:{balance:0,net:0},summary:{events:0,Consolidado:{entries:0,exits:0}},fix86_columns:{saldo_anterior:1234.56,saldo_final:1234.56,entradas_operacionais:0,saidas_operacionais:0,liq_d0_1_recurso:0,saldo_apos_d0_1:1234.56,rsus_vested:null,saldo_apos_rsu:null,fgts:20,saldo_apos_fgts:1254.56}};}
function flow(from,to){const days=[];for(let d=from;d<=to;d=shift(d,1))days.push(day(d));return {ok:true,flow:{from,to,historical:{days:[],events:[]},current_future:{days,events:[]}}};}
const period=(month,status,actual_events=0,future_events=0)=>({period_start:month+'-01',period_end:month+'-28',status,actual_events,future_events});
const audit={items:[],horizon_review_count:1,horizon_checks:[{key:'fixture-composition',title:'Compromisso de teste',direction:'expense',cadence:'monthly',period_coverage:[period('2026-10','covered',1),period('2026-11','covered',0,1),period('2026-12','awaiting_payment_evidence'),period('2027-01','review'),period('2031-12','review')]}]};
async function run(browser,width,engine){
 const ctx=await browser.newContext({viewport:{width,height:1000}});
 await ctx.addInitScript(s=>{localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s));const N=Date;class Fixed extends N{constructor(...a){super(...(a.length?a:['2026-10-13T13:00:00Z']))}static now(){return N.parse('2026-10-13T13:00:00Z')}}window.Date=Fixed;Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async text=>{window.__qaClipboard=text;}}});},session);
 const page=await ctx.newPage(),errors=[],calls=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
  const req=route.request(),name=new URL(req.url()).pathname.split('/').pop();let a={};try{a=JSON.parse(req.postData()||'{}')}catch{}calls.push({name,args:a});let data={ok:true,rows:[],items:[]};
  if(name==='token')data=session;
  else if(name==='lts_browser_product_v1')data={ok:true,mvp:product()};
  else if(name==='lts_browser_dashboard_cockpit_v1')data=cockpit;
  else if(/^lts_browser_cash_today/.test(name))data={version:'cash-today-v179-current-canonical',status:'complete',as_of:'2026-10-13',cash:1234.56,d0:0,brokerage_available:null,available_total:1234.56,fgts:20,day:day('2026-10-13')};
  else if(/^lts_browser_wealth_detail/.test(name))data=wealth;
  else if(/^lts_browser_flow_v/.test(name))data=flow(a.p_from,a.p_to);
  else if(name==='lts_browser_recurring_future_gap_audit_v5')data=audit;
  else if(/^lts_browser_expenses_|^lts_browser_expense_executive_/.test(name))data={period:{from:a.p_from,to:a.p_to},summary:{selected_total:10,card_total:5,account_total:5,monthly_average:10,rows:1,pending_identification:0},monthly_detail:[],management_groups:[],coverage_disclosure:{total:0,rows:0}};
  else if(name==='lts_browser_open_finance_status_v1')data={connected:true,connections:[]};
  else if(/^lts_browser_open_finance_refresh/.test(name))data={ok:true};
  else if(name==='lts_browser_card_cycles_v229')data={version:'card-cycles-v226',as_of:'2026-10-13',cards:[]};
  await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(data)});
 });
 try{
  await page.goto('http://127.0.0.1:8788/releases/v268/app.html');
  await page.waitForFunction(()=>document.getElementById('shell')?.contentWindow?.__LTS_V268_READ_TOOLS?.installed);
  const f=page.frames().find(x=>x.url().includes('/index.html'));assert(f);page.setDefaultTimeout(30000);
  await f.waitForFunction(()=>window.__LTS_V178_STATE?.forecast?.status==='ready'&&window.__LTS_V178_STATE?.dashboardReport?.status==='ready');
  const nav=name=>width<520?f.locator('#dx1MobileNav [data-mobile-route="'+name+'"]'):f.locator('.nav [data-v="'+name+'"]');
  await nav('Fluxo Diário').click();await f.waitForFunction(()=>!FLOWLOADING&&FLOWQ&&!FLOWQ.error);
  await f.locator('#flowFrom').fill('2026-10-12');await f.locator('#flowTo').fill('2026-10-13');await f.locator('#flowApply').click();await f.waitForFunction(()=>!FLOWLOADING&&FLOWFROM==='2026-10-12'&&FLOWTO==='2026-10-13');
  await f.locator('[data-a="Bradesco"]').click();
  const before=await f.evaluate(()=>({bank:ACC,from:FLOWFROM,to:FLOWTO,showZero:SHOWZERO,expanded:[...EXP]}));
  await f.locator('#flowCopyConsolidated').click();await f.waitForFunction(()=>!!window.__qaClipboard);
  const exported=await f.evaluate(()=>window.__qaClipboard);assert.equal(exported.split('\n').length,3);assert.match(exported,/2026-10-12\t1234,56\t0,00\t0,00\t1234,56/);assert.match(exported,/Não comprovado/);
  assert.deepEqual(await f.evaluate(()=>({bank:ACC,from:FLOWFROM,to:FLOWTO,showZero:SHOWZERO,expanded:[...EXP]})),before);
  await f.evaluate(()=>{FLOWLOADING=true;render();});assert(await f.locator('#flowCopyConsolidated').isDisabled());await f.evaluate(()=>{FLOWLOADING=false;FLOWQ={error:'fixture failure'};render();});assert(await f.locator('#flowCopyConsolidated').isDisabled());
  await f.evaluate(()=>{FLOWQ=null;render();});assert.match(await f.locator('#app').innerText(),/Carregando Fluxo/);
  await f.evaluate(async()=>{await loadFlowRange('2026-10-12','2026-10-13');});
  await nav('Atualizações').click();await f.waitForSelector('#v237CoverageYear');
  const area=f.locator('#v237CoverageAudit');assert.match(await area.innerText(),/1 realizado\(s\) · 1 previsão\(ões\) · 1 pagamento\(s\) a confirmar · 0 sem previsão/);assert.equal(await area.locator('[data-period-state="actual"]').count(),1);assert.equal(await area.locator('[data-period-state="forecast"]').count(),1);assert.equal(await area.locator('[data-period-state="awaiting"]').count(),1);assert(!/ocorrência registrada/.test(await area.innerText()));
  await f.locator('#v237CoverageYear').selectOption('2031');assert.equal(await area.locator('[data-period-state="gap"]').count(),1);
  await page.screenshot({path:'qa/v268-'+engine+'-'+width+'-states.png',fullPage:true});
  await f.locator('[data-v237-coverage-from="2031-12-01"]').first().click();await f.waitForFunction(()=>!FLOWLOADING&&FLOWFROM==='2031-12-01'&&FLOWTO==='2031-12-28');
  const overflow=await f.evaluate(()=>document.documentElement.scrollWidth>innerWidth+2);assert(!overflow,'page must fit viewport');
  assert(!calls.some(c=>/mutate|create_future|classify|apply_natural|feedback|create_internal_transfer/.test(c.name)),'read-only actions must not write financial facts');assert.deepEqual(errors,[]);
  return {engine,width,pass:true,states_distinct:true,clipboard_selected_range:true,bank_and_filters_unchanged:true,loading_and_error_guard:true,exact_month_navigation:true,no_financial_write:true};
 }catch(e){await page.screenshot({path:'qa/v268-'+engine+'-'+width+'-failure.png',fullPage:true});fs.writeFileSync('qa/v268-'+engine+'-'+width+'-failure.json',JSON.stringify({error:String(e),errors,calls},null,2));throw e;}finally{await ctx.close();}
}
(async()=>{fs.mkdirSync('qa',{recursive:true});const results=[];for(const [engine,launcher]of [['chromium',chromium],['webkit',webkit]]){const b=await launcher.launch();try{for(const width of [1440,390])results.push(await run(b,width,engine));}finally{await b.close();}}fs.writeFileSync('qa/v268-homologation.json',JSON.stringify(results,null,2));console.log(JSON.stringify(results));})().catch(e=>{console.error(e);process.exitCode=1;});
