'use strict';process.env.LTS_FLOW_RELEASE='v454';
const {chromium,webkit}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const {setup}=require('./lts_v382_browser.cjs'),fixture=require('./lts_v379_fixtures.cjs');
const out='qa/v454';fs.mkdirSync(out,{recursive:true});
async function run(browser,engine,width,month){
 const now=month==='november'?'2026-11-16T17:00:00Z':'2026-12-01T17:00:00Z';
 const h=await setup(browser,width,980,now),reply=JSON.parse(fs.readFileSync(out+'/fixture-'+month+'.json','utf8'));
 const send=(r,j)=>r.fulfill({status:200,contentType:'application/json',body:JSON.stringify(j)});
 const ready={state:'ready',required:false,cached_available:true,request_version:'4',completed_version:'4',cached_refreshed_at:now};
 await h.ctx.route('**/rest/v1/rpc/lts_browser_product_v1',r=>send(r,{ok:true,mvp:fixture.product(),refresh:ready}));
 await h.ctx.route('**/rest/v1/rpc/lts_browser_product_refresh_status_v415',r=>send(r,{ok:true,refresh:ready}));
 await h.ctx.route('**/rest/v1/rpc/lts_browser_projection_policy_v412',r=>send(r,reply));
 let frame;
 try{
  await h.page.goto((process.env.LTS_BROWSER_BASE||'http://127.0.0.1:8788')+'/releases/v454/app.html',{waitUntil:'domcontentloaded'});
  await h.page.waitForFunction(()=>document.getElementById('shell')?.contentDocument?.body?.dataset.ltsBootState==='ready');
  frame=h.page.frames().find(f=>f.url().includes('/releases/v454/index.html'));assert(frame);
  await frame.getByRole('heading',{name:'Dashboard',exact:true}).waitFor();await h.page.waitForLoadState('networkidle');
  await frame.waitForFunction(()=>__LTS_V412_PROJECTION.status==='ready');
  const model=await frame.evaluate(()=>__LTS_V412_PROJECTION.model);
  assert(model.series.find(r=>r.key==='card_aeternum').newSpendProvision.rolling);
  await frame.locator('#nav [data-v="Fluxo Diário"]:visible,#dx1MobileNav [data-mobile-route="Fluxo Diário"]:visible').click();
  await frame.waitForFunction(()=>!FLOWLOADING&&FLOWQ&&__LTS_V441_FLOW);
  const original=await frame.evaluate(()=>JSON.stringify(FLOWQ));
  assert.equal(await frame.locator('#v441FlowPremises').isVisible(),false);
  const closed=await frame.locator('body').innerText();
  assert(!closed.includes('A janela avança a cada mês'));
  assert(!/SQLSTATE|source_ref|source_fingerprint|RPC|cache state/.test(closed));
  await h.page.screenshot({path:out+'/'+engine+'-'+width+'-'+month+'-closed.png'});
  await frame.getByLabel('Opções do Fluxo').click();
  assert(await frame.locator('#v441FlowPremises').isVisible());
  const premises=await frame.locator('#v441FlowPremises').innerText();
  assert(premises.includes('desde o terceiro mês à frente'));
  assert(!premises.includes('a partir de fevereiro de 2027'));
  await h.page.screenshot({path:out+'/'+engine+'-'+width+'-'+month+'-options.png'});
  assert.equal(await frame.evaluate(()=>JSON.stringify(FLOWQ)),original);
  assert(await frame.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2));
  await frame.getByLabel('Opções do Fluxo').press('Escape');
  await frame.locator('#nav [data-v="Atualizações"]:visible,#dx1MobileNav [data-mobile-route="Atualizações"]:visible').click();
  await frame.waitForFunction(()=>V==='Atualizações');
  const section=frame.locator('.v412-rule').filter({hasText:'Fixture card_aeternum'});
  const origin=section.locator('xpath=..');
  await origin.locator('summary').click();
  const copy=await section.innerText();
  assert(copy.includes('3º mês à frente'));assert(!copy.includes('Média de'));
  const expected=month==='november'?'01/02/2027':'01/03/2027';assert(copy.includes(expected),copy);
  assert.equal((copy.match(/Novos gastos:/g)||[]).length,1,'One provision explanation');
  await h.page.screenshot({path:out+'/'+engine+'-'+width+'-'+month+'-rule.png'});
  assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);
  return {engine,width,month,pass:true,synthetic:true,real_owner:false,physical_device:false,options_closed_by_default:true,rolling_copy:true,financial_payload_unchanged:true};
 }catch(e){await h.page.screenshot({path:out+'/'+engine+'-'+width+'-'+month+'-failure.png'}).catch(()=>{});fs.writeFileSync(out+'/'+engine+'-'+width+'-'+month+'-failure.json',JSON.stringify({error:e.stack,message:e.message,body:frame?await frame.locator('body').innerText():null,errors:h.errors,reads:h.reads},null,2));throw e}
 finally{await h.ctx.close()}
}
(async()=>{const results=[];for(const [engine,type]of[['chromium',chromium],['webkit',webkit]]){if(process.env.LTS_BROWSER_ENGINES&&!process.env.LTS_BROWSER_ENGINES.split(',').includes(engine))continue;const b=await type.launch({headless:true,...(engine==='chromium'&&process.env.LTS_SYSTEM_CHROMIUM?{executablePath:process.env.LTS_SYSTEM_CHROMIUM}:{})});try{for(const width of [393,1366])for(const month of ['november','december']){const r=await run(b,engine,width,month);results.push(r);console.log(JSON.stringify(r));}}finally{await b.close()}}fs.writeFileSync(out+'/browser-result.json',JSON.stringify({pass:true,results},null,2));})().catch(e=>{console.error(e);process.exitCode=1});
