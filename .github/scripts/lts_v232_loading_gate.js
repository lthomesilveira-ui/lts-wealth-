'use strict';
const {chromium}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const {product,cockpit,wealth}=require('./lts_v165_executive_ux_gate.js');
const session={access_token:'loading-fixture',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};
const day=date=>({date,summary:{events:0,Consolidado:{entries:0,exits:0}},Consolidado:{bank_balance:600,economic_net:0},Itaú:{balance:600,net:0},Bradesco:{balance:0,net:0},C6:{balance:0,net:0},fix86_columns:{saldo_anterior:600,entradas:0,saidas:0,saldo_final:600,liq_d0_1_recurso:400,rsus_vested:200,fgts:50,saldo_apos_d0_1:1000,saldo_apos_rsu:1200,saldo_apos_fgts:1250}});
function flow(from,to){const days=[];for(let d=new Date(from+'T12:00:00Z');d.toISOString().slice(0,10)<=to;d.setUTCDate(d.getUTCDate()+1))days.push(day(d.toISOString().slice(0,10)));return{ok:true,flow:{historical:{days:[],events:[]},current_future:{days,events:[]}}};}
async function run(browser,width){
 const ctx=await browser.newContext({viewport:{width,height:1000}});
 await ctx.addInitScript(s=>{localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s));const Native=Date;window.__qaNow='2026-10-01T13:00:00Z';class Fixed extends Native{constructor(...a){super(...(a.length?a:[window.__qaNow]))}static now(){return Native.parse(window.__qaNow)}}window.Date=Fixed;
 window.__qaIntl=0;const Formatter=Intl.DateTimeFormat;Intl.DateTimeFormat=new Proxy(Formatter,{construct(t,a){window.__qaIntl++;return Reflect.construct(t,a);}});},session);
 const page=await ctx.newPage(),errors=[],calls=[];let updated=false,active=0,maxActive=0;
 page.on('pageerror',e=>errors.push(String(e)));
 const heavy=/^lts_browser_(?:expenses_|expense_executive_|expense_review_queue_|planning_ui_|flow_v|card_cycles_|open_finance_pending_|recurring_future_gap_)/;
 const report=(a)=>({period:{from:a.p_from,to:a.p_to},summary:{selected_total:10,card_total:5,account_total:5,monthly_average:10,rows:1,pending_identification:26},management_groups:[],monthly_detail:[],coverage_disclosure:{total:0,rows:0}});
 await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
  const req=route.request(),name=new URL(req.url()).pathname.split('/').pop();let a={};try{a=JSON.parse(req.postData()||'{}')}catch{}calls.push({name,args:a});
  const expensive=heavy.test(name);if(expensive){maxActive=Math.max(maxActive,++active);await new Promise(r=>setTimeout(r,100));}
  let status=200,data={ok:true,rows:[],items:[]};
  if(name==='token')data=session;
  else if(name==='lts_browser_product_v1')data={ok:true,mvp:product()};
  else if(name==='lts_browser_dashboard_cockpit_v1')data=cockpit;
  else if(name==='lts_browser_cash_today_v178')data={version:'cash-today-v179-current-canonical',status:'complete',as_of:'2026-10-01',cash:600,d0:400,brokerage_available:200,available_total:1200,day:day('2026-10-01')};
  else if(name.startsWith('lts_browser_wealth_detail'))data=wealth;
  else if(/^lts_browser_flow_v/.test(name))data=flow(a.p_from,a.p_to);
  else if(/^lts_browser_expenses_|^lts_browser_expense_executive_/.test(name))data=report(a);
  else if(name==='lts_browser_card_cycles_v229'){
   const amount=updated?12345.67:8765.43;
   data={version:'card-cycles-v226',as_of:'2026-10-01',active_billing_accounts:1,cards:[{bank:'Bradesco',family:'aeternum',last4:'1234',source_updated_at:updated?'2026-10-01T13:01:00Z':'2026-10-01T12:00:00Z',cycles:[{month:'2026-10-01',due_date:'2026-10-25',basis:'open_finance_composition',amount,items:[{source_id:'pending-card',amount,description:'Compra nova',category:'A classificar',category_basis:'unresolved',posting_date:'2026-10-01',purchase_date:'2026-10-01'}]}]}]};
  }else if(name==='lts_browser_card_category_options_v226')data={categories:['Mercado','Presentes']};
  else if(name==='lts_browser_expense_review_queue_v229'){
   const all=Array.from({length:26},(_,i)=>({key:'row-'+i,source_table:'lts_open_finance_staging',source_ref:'id-'+i,date:'2026-10-01',period:'2026-10-01',amount:10+i,category:'A classificar',description:'Compra sem identificação '+i,question_kind:'classification',review_question:'Qual é a classificação correta?'})),xs=all.slice(a.p_offset,a.p_offset+a.p_limit);
   data={row_count:26,matched_count:26,offset:a.p_offset,next_offset:a.p_offset+xs.length<26?a.p_offset+xs.length:null,rows:xs,queue_breakdown:{classification_needed:26,historical_context:0},pending_projections:[],category_options:['Mercado']};
  }else if(name==='lts_browser_open_finance_status_v1')data={connected:true,connections:['341','237','336'].map(institution_code=>({institution_code,status:'connected',last_success_at:updated?'2026-10-01T13:01:00Z':'2026-10-01T12:00:00Z'}))};
  else if(name==='lts_browser_open_finance_refresh_v1'){status=503;data={message:'fixture bank sync disabled'};}
  else if(name==='lts_browser_open_finance_pending_v225')data={version:'pending-expense-v225',transaction_count:26,unclassified_count:26,net_expense:260,rows:[]};
  if(expensive)active--;
  await route.fulfill({status,contentType:'application/json',body:JSON.stringify(data)});
 });
 try{
  await page.goto('http://127.0.0.1:8788/releases/v232/app.html');
  let f;for(let i=0;i<200;i++){f=page.frames().find(x=>x.url().includes('/index.html'));if(f&&await f.evaluate(()=>!!window.__LTS_V226).catch(()=>false))break;await page.waitForTimeout(100);}assert(f);f.setDefaultTimeout(25000);
  await f.waitForFunction(()=>window.__LTS_V178_STATE.forecast.status==='ready'&&window.__LTS_V178_STATE.dashboardReport.status==='ready'&&window.__LTS_V226.cycles);
  const density=await f.evaluate(()=>window.__LTS_V178_STATE.forecast.data.flow.current_future.days.length);assert(density>=457);
  const render=await f.evaluate(()=>{const intl=window.__qaIntl,t=performance.now();for(let i=0;i<3;i++)render();return{ms:performance.now()-t,formatters:window.__qaIntl-intl};});assert(render.ms<2500,JSON.stringify(render));assert(render.formatters<100,'date formatters scale with renders, not horizon days');
  await f.locator('.v226-upcoming [data-v226-family="aeternum"]').first().click();await f.waitForSelector('[data-v226-item]');assert.match(await f.locator('#v226-detail').innerText(),/8\.765,43/);await f.locator('[data-v226-close]').click();
  updated=true;await f.evaluate(()=>window.__LTS_V225.readStatus());await f.waitForFunction(()=>window.__LTS_V226.cycles?.cards[0].cycles[0].amount===12345.67);
  assert.match(await f.locator('.v226-upcoming').innerText(),/12\.345,67/);assert.match(await f.locator('.v232-source-stamp').first().innerText(),/01\/10\/2026/);
  await f.locator('.v226-upcoming [data-v226-family="aeternum"]').first().click();await f.waitForSelector('[data-v226-item]');assert.match(await f.locator('#v226-detail').innerText(),/12\.345,67/);await f.locator('[data-v226-close]').click();
  await f.evaluate(()=>{V='Atualizações';renderNav();render();});await f.waitForSelector('[data-v181-review-key]');assert.equal(await f.locator('[data-v181-review-key]').count(),25);await f.locator('[data-v181-review-next]').click();await f.waitForFunction(()=>window.__LTS_V181_STATE.review.data?.offset===25);assert.equal(await f.locator('[data-v181-review-key]').count(),1);
  assert(!calls.some(x=>x.name==='lts_browser_recurring_future_gap_audit_v4'),'superseded hidden audit is not requested');assert.equal(maxActive,1,'shared expensive read admission');
  await f.evaluate(()=>{V='Fluxo Diário';renderNav();render();});await f.waitForFunction(()=>!FLOWLOADING&&FLOWQ&&!FLOWQ.error);await page.screenshot({path:'qa/v232-'+width+'-flow.png',fullPage:true});
  assert.deepEqual(errors,[]);return{width,pass:true,density,three_render_ms:Math.round(render.ms),new_date_formatters:render.formatters,bank_refresh_invoice_and_detail:true,source_time:true,all_unidentified_pages:true,expensive_max_concurrent:maxActive,flow_open:true};
 }catch(e){await page.screenshot({path:'qa/v232-'+width+'-failure.png',fullPage:true});throw e;}finally{await ctx.close();}
}
(async()=>{fs.mkdirSync('qa',{recursive:true});const b=await chromium.launch();try{const result=[];for(const w of[1440,390])result.push(await run(b,w));fs.writeFileSync('qa/v232-loading-regression.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));}finally{await b.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
