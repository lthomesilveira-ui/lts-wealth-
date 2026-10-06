'use strict';
const {chromium}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const {product,cockpit,wealth}=require('./lts_v165_executive_ux_gate.js');
const session={access_token:'v242-fixture',refresh_token:'fixture',expires_at:4102444800,user:{id:'fixture-user'}};
const shift=(s,n)=>{const d=new Date(s+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10)};
async function run(browser,width){
 const ctx=await browser.newContext({viewport:{width,height:1000}});
 await ctx.addInitScript(s=>{localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s));const N=Date;class Fixed extends N{constructor(...a){super(...(a.length?a:['2026-10-04T13:00:00Z']))}static now(){return N.parse('2026-10-04T13:00:00Z')}}window.Date=Fixed;},session);
 const page=await ctx.newPage(),errors=[],calls=[],dialogs=[],writes=[];page.on('pageerror',e=>errors.push(String(e)));page.on('dialog',async d=>{dialogs.push(d.message());await d.accept()});
 let condo={date:'2026-10-05',amount:500},hold=true,release,slowYear=false,slowQueued=false;const held=new Promise(r=>release=r);
 const events=()=>[{source:'legacy_fix86',source_ref:'evento_base:fixture-condo',event_date:condo.date,description:'Condomínio · Exemplo',account:'Itaú',signed_amount:-condo.amount,direction:'saida',confidence:'legacy_projection_adjusted'}];
 function row(date){let cash=600+(date>='2026-10-08'?5010:0)-(date>=condo.date?condo.amount:0);if(date==='2027-01-12')cash=-3000;if(date==='2027-01-30')cash=-5000;const accrual=200*['2026-10-31','2026-11-30','2026-12-31','2027-01-31'].filter(d=>date>=d).length,restricted=date<'2026-10-08'?5010:0;return{date,is_today:date==='2026-10-04',Itaú:{balance:cash,net:0},Bradesco:{balance:0,net:0},C6:{balance:0,net:0},Consolidado:{bank_balance:cash,economic_net:0},summary:{events:date===condo.date?1:0,Consolidado:{entries:0,exits:date===condo.date?condo.amount:0}},fix86_columns:{saldo_anterior:cash,saldo_final:cash,entradas:0,saidas:date===condo.date?condo.amount:0,liq_d0_1_recurso:400,rsus_vested:200,fgts:restricted+accrual,fgts_documental:restricted,fgts_aportes_projetados:accrual,saldo_apos_d0_1:cash+400,saldo_apos_rsu:cash+600,saldo_apos_fgts:cash+600+restricted+accrual,saldo_apos_fgts_documental:cash+600+restricted}}}
 function flow(from,to){const days=[];for(let d=from;d<=to;d=shift(d,1))days.push(row(d));return{ok:true,flow:{from,to,fgts_projection_contract:{version:'owner-withdrawal-and-recomposition-v242',enabled:true,receipt_date:'2026-10-08',withdrawal_brl:5010,monthly_estimate_brl:200},historical:{days:days.filter(d=>d.date<'2026-10-04'),events:[]},current_future:{days:days.filter(d=>d.date>='2026-10-04'),events:events().filter(e=>e.event_date>=from&&e.event_date<=to)}}}}
 await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
  const req=route.request(),name=new URL(req.url()).pathname.split('/').pop();let a={};try{a=JSON.parse(req.postData()||'{}')}catch{}calls.push({name,args:a});let status=200,data={ok:true,rows:[],items:[]};
  if(slowQueued&&/^lts_browser_flow_v/.test(name)&&a.p_from==='2026-01-02')await new Promise(resolve=>setTimeout(resolve,27000));
  if(name==='token')data=session;
  else if(name==='lts_browser_product_v1')data={ok:true,mvp:product()};
  else if(name==='lts_browser_dashboard_cockpit_v1')data=cockpit;
  else if(name==='lts_browser_cash_today_v242')data={version:'cash-today-v179-current-canonical',status:'complete',as_of:'2026-10-04',cash:600,d0:400,brokerage_available:200,available_total:1200,fgts:5010,day:row('2026-10-04')};
  else if(/^lts_browser_wealth_detail/.test(name))data=wealth;
  else if(/^lts_browser_flow_v/.test(name)){if(hold)await held;if(slowYear&&a.p_from==='2027-01-01')await new Promise(r=>setTimeout(r,26000));data=flow(a.p_from,a.p_to)}
  else if(name==='lts_browser_flow_event_editor_v1')data={editable:true,kind:'legacy_projection',source:'legacy_fix86',source_ref:'evento_base:fixture-condo',event_date:condo.date,amount:condo.amount,display_amount:condo.amount,account:'Itaú',description:'Condomínio · Exemplo',direction:'saida',actions:['edit','duplicate','split','cancel'],parts:[]};
  else if(name==='lts_browser_flow_mutate_v2'){writes.push(a);if(writes.length===1){status=503;data={message:'DELETE requires a WHERE clause'}}else{condo={date:a.p_payload.event_date,amount:a.p_payload.amount};data={ok:true,action:'edit'}}}
  else if(/^lts_browser_expenses_|^lts_browser_expense_executive_/.test(name))data={period:{from:a.p_from,to:a.p_to},summary:{selected_total:10,card_total:5,account_total:5,rows:1},management_groups:[],monthly_detail:[],coverage_disclosure:{total:0,rows:0}};
  else if(name==='lts_browser_open_finance_refresh_v1'){status=503;data={message:'fixture sync disabled'}}
  else if(name==='lts_browser_open_finance_status_v1')data={connected:true,connections:[]};
  else if(name==='lts_browser_open_finance_pending_v225')data={transaction_count:0,rows:[]};
  else if(name==='lts_browser_card_cycles_v229')data={cards:[]};
  await route.fulfill({status,contentType:'application/json',body:JSON.stringify(data)});
 });
 let f;try{
  await page.goto('http://127.0.0.1:8788/releases/'+(process.env.LTS_RELEASE||'v242')+'/app.html');
  for(let i=0;i<200;i++){f=page.frames().find(x=>x.url().includes('/index.html'));if(f&&await f.evaluate(()=>!!window.__LTS_V178_REVIEW?.installed&&!!window.__LTS_V183_FLOW_PERIOD_STATE).catch(()=>false))break;await page.waitForTimeout(100)}assert(f);
  await f.waitForFunction(()=>window.__LTS_V178_STATE.forecast.status==='loading');assert.equal(await f.locator('.v168-chart svg').count(),0,'no stale chart fallback');
  await f.evaluate(()=>{V='Fluxo Diário';renderNav();render();window.__flowTest=loadFlowRange('2026-09-29','2026-12-31')});
  await f.waitForSelector('#v242-flow-loading');assert.equal(await f.locator('.fx87-mesa:visible').count(),0);assert.equal(await f.locator('#v242-flow-loading [aria-hidden="true"]').count(),1);
  hold=false;release();await f.waitForFunction(()=>!FLOWLOADING&&FLOWQ&&!FLOWQ.error);
  await f.locator('#flowTo').fill('2027-12-31');await f.evaluate(()=>render());assert.equal(await f.locator('#flowTo').inputValue(),'2027-12-31','background render must preserve typed final date');await f.locator('#flowApply').click();await f.waitForFunction(()=>!FLOWLOADING&&FLOWTO==='2027-12-31');
  await f.evaluate(()=>{V='Dashboard';renderNav();render()});await f.waitForFunction(()=>window.__LTS_V178_STATE.forecast.status==='ready'&&window.__LTS_V178_STATE.dashboardReport.status==='ready');
  await f.waitForSelector('#v242ChartYear');assert.equal(await f.locator('#v242ChartYear').inputValue(),'all');assert.equal(await f.locator('[data-v239-fgts-summary],#ltsFgtsScenarioNote,#v236-current-position-note').count(),0);
  assert(!calls.some(x=>x.name.startsWith('lts_browser_planning_ui_')),'the plan uses the same daily forecast');assert(calls.some(x=>x.name==='lts_browser_cash_today_v242'));
  await f.locator('#v242ChartYear').selectOption('2027');await f.waitForSelector('[data-v242-minimum="2027-01-30"]');assert.equal(await f.locator('[data-v242-minimum]').getAttribute('data-value'),'-3800');
  await f.locator('#v242ChartYear').selectOption('all');assert.equal(Number(await f.locator('.v168-chart svg').getAttribute('data-v242-points')),454);
  const path=await f.locator('.v168-chart path.fgts').getAttribute('d'),numbers=path.match(/[MC]|-?\d+(?:\.\d+)?/g);let i=0,previous;while(i<numbers.length){const op=numbers[i++];if(op==='M'){previous=[+numbers[i++],+numbers[i++]];continue}assert.equal(op,'C');const p1=[+numbers[i++],+numbers[i++]],p2=[+numbers[i++],+numbers[i++]],p3=[+numbers[i++],+numbers[i++]];for(let t=.1;t<1;t+=.1){const v=(1-t)**3*previous[1]+3*(1-t)**2*t*p1[1]+3*(1-t)*t*t*p2[1]+t**3*p3[1];assert(v>=Math.min(previous[1],p3[1])-.02&&v<=Math.max(previous[1],p3[1])+.02,'smooth path cannot invent an extremum')}previous=p3;}
  await f.locator('#v242ChartYear').selectOption('2026');await page.screenshot({path:'qa/v242-'+width+'-dashboard.png',fullPage:true});
  if(['v245','v257'].includes(process.env.LTS_RELEASE||'v242')){
   const svg=f.locator('.v168-chart svg');await svg.focus();await svg.press('End');
   assert.equal(await f.locator('#v244-chart-values').getAttribute('data-date'),'2026-12-31');
   assert((await f.locator('#v244-chart-values').innerText()).replace(/\s+/g,' ').includes('R$ 6.310,00'),'inspected values are exact source values');
   await svg.press('Home');assert.equal(await f.locator('#v244-chart-values').getAttribute('data-date'),'2026-10-04');
   assert.equal(await f.locator('[data-v244-axis-date]').first().getAttribute('data-v244-axis-date'),'2026-10-04');
   assert.equal(await f.locator('[data-v244-axis-date]').last().getAttribute('data-v244-axis-date'),'2026-12-31');
   await f.locator('.v168-chart').screenshot({path:'qa/v244-'+width+'-chart.png'});
   assert((await svg.boundingBox()).height>=200,'mobile daily chart is not shrunk into an unreadable thumbnail');
  }
  const before=calls.filter(x=>x.name==='lts_browser_flow_v242').length;
  await f.locator('[data-v168-go="Fluxo Diário"]').click();await f.waitForFunction(()=>!FLOWLOADING&&FLOWQ&&!FLOWQ.error);
  assert.equal(calls.filter(x=>x.name==='lts_browser_flow_v242').length,before,'default flow reuses the authenticated complete forecast');
  const closeFit=await f.locator('#flowCloseDetails').evaluate(e=>{const r=e.getBoundingClientRect();return{left:r.left,right:r.right,bottom:r.bottom,width:innerWidth}});assert(closeFit.left>=0&&closeFit.right<=closeFit.width&&closeFit.bottom<500,'close-details is visible in the initial desktop/mobile controls');
  assert.equal(await f.locator('#ltsFgtsScenarioNote,#ltsBankEvidence,#ltsReconciliationWarning,#v236-current-position-note').count(),0);
  if(['v245','v257'].includes(process.env.LTS_RELEASE||'v242')&&width===1440){slowYear=true;await f.evaluate(()=>{window.__LTS_V178_STATE.forecast.updatedAt=0});}
  await f.locator('#flowYear').selectOption('2027');
  if(slowYear){await f.waitForSelector('#v242-flow-loading');assert.equal(await f.locator('.fx87-mesa:visible').count(),0)}
  await f.waitForFunction(()=>!FLOWLOADING&&FLOWQ&&!FLOWQ.error&&FLOWFROM==='2027-01-01'&&FLOWTO==='2027-12-31',null,{timeout:60000});slowYear=false;
  assert.equal(await f.locator('#flowYear').inputValue(),'2027');
  assert.equal(await f.locator('.fx87-mesa:visible').count(),1,'selected 2027 table is visible');
  assert.equal(await f.evaluate(()=>mergedFlowDays().length),365,'2027 has all 365 source days');
  if(!await f.evaluate(()=>SHOWZERO))await f.locator('#flowZero').click();
  assert.equal(await f.locator('#d-2027-01-01:visible').count(),1);
  assert.equal(await f.locator('#d-2027-12-31:visible').count(),1);
  for(const account of ['Itaú','Bradesco','C6','Consolidado']){
   await f.locator('[data-a="'+account+'"]').click();
   assert.equal(await f.locator('#flowYear').inputValue(),'2027');
   assert.equal(await f.locator('#d-2027-01-01:visible').count(),1,'account keeps selected year');
  }
  await page.screenshot({path:'qa/v244-'+width+'-flow-2027.png',fullPage:false});
  await f.locator('#flowFrom').fill('2027-01-12');await f.locator('#flowTo').fill('2027-01-30');await f.locator('#flowApply').click();
  await f.waitForFunction(()=>!FLOWLOADING&&FLOWQ&&!FLOWQ.error&&FLOWFROM==='2027-01-12'&&FLOWTO==='2027-01-30');
  assert.equal(await f.locator('.fx87-mesa:visible').count(),1,'custom 2027 range is visible');
  await f.locator('#flowDefaultRange').click();
  await f.waitForFunction(()=>!FLOWLOADING&&FLOWQ&&!FLOWQ.error&&FLOWFROM==='2026-09-29'&&FLOWTO==='2027-12-31');
  assert.equal(await f.locator('#flowZero').innerText(),'Mostrar dias sem movimento');
  await f.locator('#d-2026-10-05 .exp').click();await f.locator('#d-2026-10-04 .exp').click();const period=await f.evaluate(()=>[FLOWFROM,FLOWTO,ACC,SHOWZERO]);await f.locator('#flowCloseDetails').click();assert.equal(await f.locator('.fx89-details').count(),0);assert.deepEqual(await f.evaluate(()=>[FLOWFROM,FLOWTO,ACC,SHOWZERO]),period);assert.equal(await f.evaluate(()=>EXP.size),0);await f.locator('#d-2026-10-05 .exp').click();await f.getByRole('button',{name:'Editar',exact:true}).first().click();await f.waitForSelector('#flowEditAmount');
  await f.locator('#flowEditAmount').fill('700');await f.locator('#flowEditDate').fill('2026-10-06');await f.locator('#flowEditSave').click();await f.waitForFunction(()=>!FLOWEDITSAVING);
  assert.equal(await f.locator('#flowEditAmount').inputValue(),'700');assert.equal(await f.locator('#flowEditDate').inputValue(),'2026-10-06');assert(dialogs.includes('Não foi possível salvar o lançamento. Tente novamente.'));assert(!dialogs.some(x=>x.includes('DELETE')));
  await f.locator('#flowEditSave').click();await f.waitForFunction(()=>!FLOWEDITSAVING&&!FLOWLOADING&&FLOWEDIT===null);assert.equal(writes.length,2);assert.equal(writes[0].p_idempotency_key,writes[1].p_idempotency_key,'an unchanged retry keeps its identity');
  const currentEvents=await f.evaluate(()=>FLOWQ.current_future.events);assert.equal(currentEvents.filter(e=>e.description==='Condomínio · Exemplo').length,1);assert.equal(currentEvents.find(e=>e.description==='Condomínio · Exemplo').event_date,'2026-10-06');assert.equal(currentEvents.find(e=>e.description==='Condomínio · Exemplo').signed_amount,-700);
  await page.screenshot({path:'qa/v242-'+width+'-flow.png',fullPage:true});
  for(const route of ['Dashboard','Despesas','Patrimônio','Atualizações']){await f.evaluate(r=>{V=r;renderNav();render()},route);assert((await f.locator('#app').innerText()).trim().length>20,route+' renders');}
  if(width===1440){
   slowQueued=true;
   await f.evaluate(()=>{window.__queuedRead=fetch(U+'/rest/v1/rpc/lts_browser_flow_v242',{method:'POST',headers:{apikey:K,Authorization:'Bearer v242-fixture','Content-Type':'application/json'},body:JSON.stringify({p_from:'2026-01-02',p_to:'2026-01-03'})});});
   await page.waitForFunction(()=>true);for(let n=0;n<50&&!calls.some(c=>/^lts_browser_flow_v/.test(c.name)&&c.args?.p_from==='2026-01-02');n++)await page.waitForTimeout(100);
   const queued=await f.evaluate(async()=>{const response=await fetch(U+'/rest/v1/rpc/lts_browser_expense_executive_v20',{method:'POST',headers:{apikey:K,Authorization:'Bearer v242-fixture','Content-Type':'application/json'},body:JSON.stringify({p_from:'2030-01-01',p_to:'2030-01-31'})});return{status:response.status,data:await response.json()}});
   assert.equal(queued.status,200,'expense execution budget starts after a 27-second flow queue');assert.equal(queued.data.summary.selected_total,10);
   const reads=JSON.parse(await f.locator('html').getAttribute('data-lts-v227-reads'));assert(reads.some(r=>r.name==='lts_browser_expenses_v229'&&r.queued_ms>22000&&r.status===200));
   await f.evaluate(()=>window.__queuedRead);slowQueued=false;
  }
  assert.deepEqual(errors,[]);return{width,pass:true,immediate_loader:true,flow_2027_year_and_custom_range:true,flow_2027_bank_tabs:true,forecast_reused:true,one_plan_source:true,professional_copy:true,daily_points:454,monotone_curve_no_false_extrema:true,edit_and_date_change:true,failed_input_preserved:true,writer_retry_idempotent:true,core_routes_render:true,queue_admission_budget_verified:width===1440};
 }catch(e){await page.screenshot({path:'qa/v242-'+width+'-failure.png',fullPage:true});fs.writeFileSync('qa/v242-'+width+'-failure.json',JSON.stringify({error:String(e),errors,calls,dialogs,state:await f?.evaluate(()=>({route:V,body:document.getElementById('app')?.innerText.slice(0,4000),forecast:window.__LTS_V178_STATE?.forecast?.status})).catch(()=>null)},null,2));throw e}finally{await ctx.close()}
}
(async()=>{fs.mkdirSync('qa',{recursive:true});const b=await chromium.launch(process.env.LTS_CHROMIUM?{executablePath:process.env.LTS_CHROMIUM,args:["--no-sandbox"]}:{});try{const results=[];for(const width of[1440,390])results.push(await run(b,width));fs.writeFileSync('qa/v242-flow-ux.json',JSON.stringify(results,null,2));console.log(JSON.stringify(results))}finally{await b.close()}})().catch(e=>{console.error(e);process.exitCode=1});
