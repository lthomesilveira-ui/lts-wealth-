'use strict';process.env.LTS_FLOW_RELEASE='v445';
const {chromium,webkit}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const {setup}=require('./lts_v382_browser.cjs'),fixture=require('./lts_v379_fixtures.cjs'),projection=require('./lts_v412_projection_fixtures.cjs');
const out='qa/v445';fs.mkdirSync(out,{recursive:true});
async function run(browser,engine,width){
 const h=await setup(browser,width,980,'2026-11-15T17:00:00Z'),label=engine+'-'+width,audits=[];
 let releasePolicy,firstAudit,frame;const policyWait=new Promise(r=>releasePolicy=r),auditWait=new Promise(r=>firstAudit=r);
 const policy=projection.policy();policy.as_of='2026-11-15';
 const send=(route,value)=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(value)});
 await h.ctx.route('**/rest/v1/rpc/lts_browser_projection_policy_v412',async route=>{await policyWait;return send(route,policy)});
 await h.ctx.route('**/rest/v1/rpc/lts_browser_recurring_future_gap_audit_v5',async route=>{
  const args=JSON.parse(route.request().postData());audits.push(args);firstAudit();
  return send(route,{...fixture.recurring(),as_of:args.p_as_of,future_horizon_end:args.p_horizon_end,horizon_checks:[]});
 });
 await h.ctx.route('**/rest/v1/rpc/lts_browser_budget_read_v441',route=>send(route,require('./lts_v441_fixture.cjs')()));
 try{
  await h.page.goto((process.env.LTS_BROWSER_BASE||'http://127.0.0.1:8788')+'/releases/v445/app.html',{waitUntil:'domcontentloaded'});
  await h.page.waitForFunction(()=>document.getElementById('shell')?.contentDocument?.body?.dataset.ltsBootState==='ready');
  frame=h.page.frames().find(f=>f.url().includes('/releases/v445/index.html'));assert(frame);await auditWait;
  assert.equal(audits[0].p_horizon_end,'2031-12-31','Opening audit must match the scenario before policy arrives');
  const token=await frame.evaluate(()=>__LTS_V168_STATE.dashboard.token),financial=await frame.evaluate(()=>JSON.stringify(D));
  releasePolicy();await frame.waitForFunction(()=>__LTS_V412_PROJECTION?.status==='ready');await h.page.waitForLoadState('networkidle');
  assert.equal(await frame.evaluate(()=>__LTS_V168_STATE.dashboard.token),token,'Aligned policy must not restart the dashboard');
  assert(audits.every(a=>a.p_horizon_end==='2031-12-31'));assert.equal(audits.length,1,'One opening audit, no superseded four-year fallback');
  assert.equal(await frame.evaluate(()=>JSON.stringify(D)),financial);assert.equal(await frame.locator('#ltsRefreshStatusV415').isVisible(),false);
  await h.page.screenshot({path:out+'/'+label+'-dashboard.png'});
  await frame.locator('#v337Overview details').first().locator('summary').click();await h.page.screenshot({path:out+'/'+label+'-origin.png'});await frame.locator('#v337Overview details').first().locator('summary').click();
  await frame.locator('#nav [data-v="Fluxo Diário"]:visible,#dx1MobileNav [data-mobile-route="Fluxo Diário"]:visible').click();
  await frame.waitForFunction(()=>!FLOWLOADING&&FLOWQ&&__LTS_V441_FLOW);await h.page.waitForLoadState('networkidle');
  assert.equal(await frame.locator('.v382-tools[open]').count(),0);await h.page.screenshot({path:out+'/'+label+'-flow.png'});
  await frame.getByLabel('Opções do Fluxo').click();assert(await frame.locator('#v441FlowPremises').isVisible());await h.page.screenshot({path:out+'/'+label+'-flow-options.png'});
  assert(await frame.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2));const text=await frame.locator('body').innerText();assert(!/SQLSTATE|source_ref|source_fingerprint|RPC|cache state/.test(text));assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);
  return{pass:true,engine,width,delayed_policy_horizon_aligned:true,opening_audit_count:audits.length,screen_owner_preserved:true,financial_content_unchanged:true,synthetic:true,private_session:false,physical_device:false};
 }catch(error){await h.page.screenshot({path:out+'/'+label+'-failure.png',fullPage:true}).catch(()=>{});fs.writeFileSync(out+'/'+label+'-failure.json',JSON.stringify({error:error.stack,reads:h.reads,errors:h.errors,audits,body:frame?await frame.locator('body').innerText():null},null,2));throw error}
 finally{releasePolicy();await h.ctx.close()}
}
(async()=>{const results=[];for(const[engine,type]of[['chromium',chromium],['webkit',webkit]]){const browser=await type.launch({headless:true});try{for(const width of[393,1366]){const r=await run(browser,engine,width);results.push(r);console.log(JSON.stringify(r))}}finally{await browser.close()}}fs.writeFileSync(out+'/browser-result.json',JSON.stringify({pass:results.length===4&&results.every(x=>x.pass),results},null,2))})().catch(e=>{console.error(e);process.exitCode=1});
