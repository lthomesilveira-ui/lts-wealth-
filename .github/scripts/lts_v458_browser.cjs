'use strict';process.env.LTS_FLOW_RELEASE='v458';
const {chromium,webkit}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const {setup}=require('./lts_v382_browser.cjs'),fixture=require('./lts_v379_fixtures.cjs');
const out='qa/v458';fs.mkdirSync(out,{recursive:true});
const now='2026-11-17T17:00:00Z',base=process.env.LTS_BROWSER_BASE||'http://127.0.0.1:8788';
const status=(phase='ready',v='2')=>({state:phase,required:phase!=='ready',cached_available:true,request_version:v,completed_version:phase==='ready'?v:'2',cached_refreshed_at:'2026-11-17T16:59:00Z'});
const banks=time=>({connections:['341','237','336'].map(code=>({id:'fixture-'+code,provider:'fixture',institution_code:code,last_success_at:time,last_attempt_at:time,last_error_code:null}))});
async function go(frame,view){await frame.locator('#nav [data-v="'+view+'"]:visible,#dx1MobileNav [data-mobile-route="'+view+'"]:visible').click();await frame.waitForFunction(v=>V===v,view)}
async function ready(frame){await frame.waitForFunction(()=>window.__LTS_V178_STATE&&['wealth','forecast','awards','dashboardReport'].every(k=>__LTS_V178_STATE[k].status==='ready')&&!['idle','loading'].includes(__LTS_V178_STATE.cash.status))}
async function readers(frame){return frame.evaluate(()=>Object.fromEntries(['cash','wealth','forecast','awards','dashboardReport'].map(k=>[k,{status:__LTS_V178_STATE[k].status,date:__LTS_V178_STATE[k].date,data:__LTS_V178_STATE[k].data}])))}
async function run(browser,engine,width){
 const h=await setup(browser,width,980,now),label=engine+'-'+width;let frame,ingested=false,job=status(),products=0,statuses=0,bankRequests=0,productRequests=0;
 const send=(r,j)=>r.fulfill({status:200,contentType:'application/json',body:JSON.stringify(j)});
 await h.ctx.route('**/rest/v1/rpc/lts_browser_product_v1',r=>{products++;return send(r,{ok:true,mvp:fixture.product(),refresh:job})});
 await h.ctx.route('**/rest/v1/rpc/lts_browser_product_refresh_status_v415',r=>{statuses++;return send(r,{ok:true,refresh:job})});
 await h.ctx.route('**/rest/v1/rpc/lts_browser_product_refresh_request_v415',r=>{productRequests++;return r.abort()});
 await h.ctx.route('**/rest/v1/rpc/lts_browser_open_finance_status_v1',r=>send(r,banks(ingested?now:'2026-11-17T16:50:00Z')));
 await h.ctx.route('**/rest/v1/rpc/lts_browser_open_finance_refresh_v1',r=>{bankRequests++;ingested=true;job=status('running','3');return send(r,{ok:true,requested_at:now})});
 await h.ctx.route('**/rest/v1/rpc/lts_browser_budget_read_v441',r=>send(r,require('./lts_v441_fixture.cjs')()));
 await h.ctx.route('**/rest/v1/rpc/lts_browser_cash_today_v242',r=>send(r,require('./lts_v458_cash_fixture.cjs')(now)));
 try{
  await h.page.goto(base+'/releases/v458/app.html',{waitUntil:'domcontentloaded'});
  await h.page.waitForFunction(()=>document.getElementById('shell')?.contentDocument?.body?.dataset.ltsBootState==='ready');
  frame=h.page.frames().find(f=>f.url().includes('/releases/v458/index.html'));assert(frame);
  await ready(frame);await h.page.waitForLoadState('networkidle');
  const financial=await frame.evaluate(()=>JSON.stringify(D)),before=await readers(frame);
  assert.equal(before.cash.status,'ready');assert.equal(before.cash.data.cash,1000);assert.equal(before.cash.data.available_total,1500);
  const revision=await frame.evaluate(()=>__LTS_V227_TRANSPORT.revision);
  await h.page.screenshot({path:out+'/'+label+'-dashboard-before.png',fullPage:true});
  await frame.getByRole('button',{name:'Atualizar contas',exact:true}).click();
  await frame.waitForFunction(()=>!__LTS_V225.syncing&&__LTS_V415_REFRESH.snapshot().refresh.request_version==='3');
  await h.page.waitForLoadState('networkidle');
  assert.equal(bankRequests,1);assert.equal(products,1);assert.equal(productRequests,0);
  assert.equal(await frame.evaluate(()=>__LTS_V227_TRANSPORT.revision),revision,'No speculative heavy invalidation');
  assert.deepEqual(await readers(frame),before,'Verified financial reader data retained');
  await frame.evaluate(()=>{for(let i=0;i<20;i++)window.dispatchEvent(new Event('lts:deferred-read-failed'))});
  assert.equal(await frame.evaluate(()=>__LTS_V415_REFRESH.snapshot().deferredRecoveries),0);
  assert.equal(products,1);assert(await frame.locator('#ltsRefreshStatusV415').isVisible());
  const pendingHeight=await frame.locator('#ltsRefreshStatusV415').evaluate(e=>e.getBoundingClientRect().height);
  assert(pendingHeight>0&&pendingHeight<=90,'Compact material update warning: '+pendingHeight);
  const pendingText=await frame.locator('body').innerText();assert(!/SQLSTATE|source_ref|source_fingerprint|RPC|cache state|backend|payload/.test(pendingText));
  await h.page.screenshot({path:out+'/'+label+'-dashboard-pending.png',fullPage:true});
  job=status('ready','3');await frame.evaluate(()=>__LTS_V415_REFRESH.poll());
  await frame.waitForFunction(()=>!__LTS_V415_REFRESH.snapshot().pending);await ready(frame);await h.page.waitForLoadState('networkidle');
  assert.equal(products,2);assert.equal(productRequests,0);assert.equal(await frame.evaluate(()=>JSON.stringify(D)),financial);
  assert.deepEqual(await readers(frame),before);assert(!(await frame.locator('#ltsRefreshStatusV415').isVisible()));
  const text=await frame.locator('body').innerText();assert(!/SQLSTATE|source_ref|source_fingerprint|RPC|cache state|backend|payload/.test(text));
  assert.equal(await frame.locator('.v337-source[open],.v412-origin[open]').count(),0);
  assert(await frame.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2));
  await h.page.screenshot({path:out+'/'+label+'-dashboard-ready.png',fullPage:true});
  const origin=frame.locator('#v337Overview details').first();await origin.locator('summary').click();
  await h.page.screenshot({path:out+'/'+label+'-dashboard-origin.png',fullPage:true});await origin.locator('summary').click();
  await go(frame,'Fluxo Diário');await frame.waitForFunction(()=>!FLOWLOADING&&FLOWQ&&__LTS_V441_FLOW);
  await frame.evaluate(()=>window.scrollTo(0,0));
  const flow=await frame.evaluate(()=>JSON.stringify(FLOWQ));assert.equal(await frame.locator('#v441FlowPremises').isVisible(),false);
  await h.page.screenshot({path:out+'/'+label+'-flow-closed.png',fullPage:true});
  await frame.getByLabel('Opções do Fluxo').click();
  await h.page.screenshot({path:out+'/'+label+'-flow-options.png',fullPage:true});
  assert.equal(await frame.evaluate(()=>JSON.stringify(FLOWQ)),flow);
  assert(await frame.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2));
  await frame.getByLabel('Opções do Fluxo').press('Escape');
  await go(frame,'Despesas');await h.page.waitForLoadState('networkidle');
  await frame.waitForFunction(()=>!__LTS_V296_CLASSIFICATIONS.state.loading&&!__LTS_V296_CLASSIFICATIONS.state.error);
  await h.page.screenshot({path:out+'/'+label+'-expenses.png',fullPage:true});
  assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);
  return{pass:true,engine,width,height:980,synthetic:true,private_session:false,physical_device:false,
   bank_requests:bankRequests,product_requests:productRequests,complete_products:products,status_checks:statuses,
   bank_collection_did_not_restart_reports:true,pending_reader_burst_did_not_spend_full_retry_budget:true,
   financial_data_and_dates_unchanged:true,compact_pending_height:pendingHeight,default_and_expanded_states_rendered:true};
 }catch(error){await h.page.screenshot({path:out+'/'+label+'-failure.png',fullPage:true}).catch(()=>{});fs.writeFileSync(out+'/'+label+'-failure.json',JSON.stringify({error:error.stack,products,statuses,bankRequests,productRequests,reads:h.reads,errors:h.errors,body:frame?await frame.locator('body').innerText():null},null,2));throw error}
 finally{await h.ctx.close()}
}
(async()=>{const results=[];for(const[engine,type]of[['chromium',chromium],['webkit',webkit]]){const b=await type.launch({headless:true});try{for(const width of[393,1366]){const r=await run(b,engine,width);results.push(r);console.log(JSON.stringify(r))}}finally{await b.close()}}fs.writeFileSync(out+'/browser-result.json',JSON.stringify({pass:results.length===4&&results.every(r=>r.pass),results},null,2))})().catch(e=>{console.error(e);process.exitCode=1});
