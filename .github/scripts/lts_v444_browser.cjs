'use strict';process.env.LTS_FLOW_RELEASE='v444';
const {chromium,webkit}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
const fixture=require('./lts_v379_fixtures.cjs'),{setup}=require('./lts_v382_browser.cjs');
const out='qa/v444';fs.mkdirSync(out,{recursive:true});
const status=state=>({state,required:state!=='ready',cached_available:true,request_version:'2',completed_version:state==='ready'?'2':'1',cached_refreshed_at:'2026-11-15T15:00:00Z'});
async function run(browser,engine,width){
 const h=await setup(browser,width,980,'2026-11-15T17:00:00Z'),label=engine+'-'+width;let products=0,statuses=0,f;
 const send=(route,value,code=200)=>route.fulfill({status:code,contentType:'application/json',body:JSON.stringify(value)});
 await h.ctx.route('**/rest/v1/rpc/lts_browser_product_v1',route=>send(route,{ok:true,mvp:fixture.product(),refresh:status(++products===1?'pending':'ready')}));
 await h.ctx.route('**/rest/v1/rpc/lts_browser_product_refresh_status_v415',route=>++statuses===1?send(route,{message:'Temporary fixture failure'},503):send(route,{ok:true,refresh:status('ready')}));
 await h.ctx.route('**/rest/v1/rpc/lts_browser_budget_read_v441',route=>send(route,require('./lts_v441_fixture.cjs')()));
 try{
  await h.page.goto((process.env.LTS_BROWSER_BASE||'http://127.0.0.1:8788')+'/releases/v444/app.html',{waitUntil:'domcontentloaded'});
  await h.page.waitForFunction(()=>document.getElementById('shell')?.contentDocument?.body?.dataset.ltsBootState==='ready');
  f=h.page.frames().find(x=>x.url().includes('/releases/v444/index.html'));assert(f);
  await f.getByRole('heading',{name:'Dashboard',exact:true}).waitFor();
  await h.page.waitForLoadState('networkidle');const financial=await f.evaluate(()=>JSON.stringify(D));
  assert(await f.getByRole('heading',{name:'Dashboard',exact:true}).isVisible());
  assert.match(await f.locator('#ltsRefreshStatusV415').innerText(),/Atualizando seus dados/);
  await h.page.screenshot({path:out+'/'+label+'-pending.png'});
  await f.locator('#ltsRefreshStatusV415').getByRole('button',{name:'Tentar novamente',exact:true}).waitFor();
  assert.match(await f.locator('#ltsRefreshStatusV415').innerText(),/Não foi possível concluir a atualização/);
  const warning=await f.locator('#ltsRefreshStatusV415').boundingBox();assert(warning.height<160,'Short actionable warning');
  await h.page.screenshot({path:out+'/'+label+'-failed.png'});
  await f.waitForFunction(()=>__LTS_V415_REFRESH.snapshot().pending===false);
  assert.equal(products,2);assert.equal(statuses,2);assert.equal(await f.locator('#ltsRefreshStatusV415').isVisible(),false);
  assert.equal(await f.evaluate(()=>JSON.stringify(D)),financial,'Recovery cannot alter financial content');
  const text=await f.locator('body').innerText();assert(!/SQLSTATE|source_ref|source_fingerprint|RPC|cache state|Request unavailable/.test(text));
  assert(await f.getByRole('heading',{name:'Resumo do mês',exact:true}).isVisible());
  await h.page.screenshot({path:out+'/'+label+'-ready.png'});
  const disclosure=f.locator('#v337Overview details').first();await disclosure.locator('summary').click();
  await h.page.screenshot({path:out+'/'+label+'-origin.png'});await disclosure.locator('summary').click();
  assert.equal(await f.locator('#v337Overview details[open]').count(),0);
  const flow=f.locator('#nav [data-v="Fluxo Diário"]:visible,#dx1MobileNav [data-mobile-route="Fluxo Diário"]:visible');await flow.click();
  await f.waitForFunction(()=>!FLOWLOADING&&FLOWQ&&__LTS_V441_FLOW);await h.page.waitForLoadState('networkidle');
  assert.equal(await f.locator('.v382-tools[open]').count(),0);await h.page.screenshot({path:out+'/'+label+'-flow.png'});
  await f.getByLabel('Opções do Fluxo').click();assert(await f.locator('#v441FlowPremises').isVisible());await h.page.screenshot({path:out+'/'+label+'-flow-options.png'});
  assert(await f.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2));assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);
  return{pass:true,engine,width,automatic_transient_recovery:true,full_financial_content_unchanged:true,collapsed_and_expanded:true,synthetic:true,private_session:false,physical_device:false};
 }catch(error){await h.page.screenshot({path:out+'/'+label+'-failure.png',fullPage:true}).catch(()=>{});fs.writeFileSync(out+'/'+label+'-failure.json',JSON.stringify({error:error.stack,reads:h.reads,errors:h.errors,body:f?await f.locator('body').innerText():await h.page.locator('body').innerText()},null,2));throw error}
 finally{await h.ctx.close()}
}
(async()=>{const results=[],engines=process.env.LTS_BROWSER_ENGINES?.split(',')||['chromium','webkit'];for(const[engine,type]of[['chromium',chromium],['webkit',webkit]]){if(!engines.includes(engine))continue;const browser=await type.launch({headless:true,...(engine==='chromium'&&process.env.LTS_CHROMIUM_EXECUTABLE?{executablePath:process.env.LTS_CHROMIUM_EXECUTABLE}:{})});try{for(const width of[393,1366]){const r=await run(browser,engine,width);results.push(r);console.log(JSON.stringify(r))}}finally{await browser.close()}}fs.writeFileSync(out+'/browser-result.json',JSON.stringify({pass:results.length===engines.length*2&&results.every(x=>x.pass),results},null,2))})().catch(e=>{console.error(e);process.exitCode=1});
