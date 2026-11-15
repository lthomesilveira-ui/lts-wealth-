'use strict';process.env.LTS_FLOW_RELEASE='v448';
const {chromium,webkit}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const {setup}=require('./lts_v382_browser.cjs'),fixture=require('./lts_v379_fixtures.cjs');const out='qa/v448';fs.mkdirSync(out,{recursive:true});
const status=state=>({state,required:state!=='ready',cached_available:true,request_version:'2',completed_version:'2',cached_refreshed_at:'2026-11-15T17:00:00Z'});
async function run(browser,engine,width){
 const h=await setup(browser,width,980,'2026-11-15T17:00:00Z'),label=engine+'-'+width;let products=0,statuses=0,frame,failNextAudit=false;
 const send=(route,value)=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(value)});
 await h.ctx.route('**/rest/v1/rpc/lts_browser_product_v1',route=>{products++;return send(route,{ok:true,mvp:fixture.product(),refresh:{...status('ready'),request_version:products===1?'2':'3',completed_version:products===1?'2':'3'}})});
 await h.ctx.route('**/rest/v1/rpc/lts_browser_product_refresh_status_v415',route=>send(route,{ok:true,refresh:{...status(++statuses===1?'pending':'ready'),request_version:'3',completed_version:statuses===1?'2':'3'}}));
 await h.ctx.route('**/rest/v1/rpc/lts_browser_recurring_future_gap_audit_v5',route=>{if(failNextAudit){failNextAudit=false;return route.fulfill({status:500,contentType:'application/json',body:JSON.stringify({code:'57014',message:'synthetic timeout'})})}return route.fallback()});
 await h.ctx.route('**/rest/v1/rpc/lts_browser_budget_read_v441',route=>send(route,require('./lts_v441_fixture.cjs')()));
 try{
  await h.page.goto((process.env.LTS_BROWSER_BASE||'http://127.0.0.1:8788')+'/releases/v448/app.html',{waitUntil:'domcontentloaded'});await h.page.waitForFunction(()=>document.getElementById('shell')?.contentDocument?.body?.dataset.ltsBootState==='ready');
  frame=h.page.frames().find(f=>f.url().includes('/releases/v448/index.html'));assert(frame);await frame.getByRole('heading',{name:'Dashboard',exact:true}).waitFor();await h.page.waitForLoadState('networkidle');
  const financial=await frame.evaluate(()=>JSON.stringify(D));failNextAudit=true;const failure=await frame.evaluate(()=>S.rpc('lts_browser_recurring_future_gap_audit_v5',{p_as_of:'2026-11-15',p_horizon_end:'2031-12-31'}));assert(failure.error,'Actual transport received the 5xx response');
  await frame.locator('#ltsRefreshStatusV415').getByText('Atualizando seus dados',{exact:true}).waitFor();await h.page.screenshot({path:out+'/'+label+'-invalidated.png'});
  await frame.waitForFunction(()=>__LTS_V415_REFRESH.snapshot().pending===false);await h.page.waitForLoadState('networkidle');
  assert.equal(products,2,'One new complete product after a deferred reader failure');assert.equal(statuses,2);assert.equal(await frame.locator('#ltsRefreshStatusV415').isVisible(),false);
  const diagnostic=JSON.parse(await frame.locator('#ltsRefreshStatusV415').getAttribute('data-lts-refresh-observation'));assert.equal(diagnostic.error,null);assert.equal(diagnostic.pending,false);
  assert.equal(await frame.evaluate(()=>JSON.stringify(D)),financial);await h.page.screenshot({path:out+'/'+label+'-recovered.png'});
  await frame.locator('#v337Overview details').first().locator('summary').click();await h.page.screenshot({path:out+'/'+label+'-origin.png'});await frame.locator('#v337Overview details').first().locator('summary').click();
  assert(await frame.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2));const text=await frame.locator('body').innerText();assert(!/SQLSTATE|source_ref|source_fingerprint|RPC|cache state/.test(text));assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);
  return{pass:true,engine,width,http_failure_rechecks_existing_job:true,no_new_refresh_request:true,financial_content_unchanged:true,duplicate_product_reads:false,synthetic:true,private_session:false,physical_device:false};
 }catch(error){await h.page.screenshot({path:out+'/'+label+'-failure.png',fullPage:true}).catch(()=>{});fs.writeFileSync(out+'/'+label+'-failure.json',JSON.stringify({error:error.stack,products,statuses,reads:h.reads,errors:h.errors,body:frame?await frame.locator('body').innerText():null},null,2));throw error}
 finally{await h.ctx.close()}
}
(async()=>{const results=[];for(const[engine,type]of[['chromium',chromium],['webkit',webkit]]){const b=await type.launch({headless:true});try{for(const width of[393,1366]){const r=await run(b,engine,width);results.push(r);console.log(JSON.stringify(r))}}finally{await b.close()}}fs.writeFileSync(out+'/browser-result.json',JSON.stringify({pass:results.length===4&&results.every(x=>x.pass),results},null,2))})().catch(e=>{console.error(e);process.exitCode=1});
