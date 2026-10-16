'use strict';
// Prepared gate only. Run in CI against a complete local release; never against production.
const {chromium}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const fixture=require('./lts_boot_recovery_fixtures.cjs');
const release=process.env.LTS_RELEASE;
assert(release&&/^[a-zA-Z0-9_-]+$/.test(release),'Set LTS_RELEASE to the combined local candidate release');
const BASE=process.env.LTS_BOOT_BASE||'http://127.0.0.1:8788';
const baseURL=new URL(BASE);assert.equal(baseURL.protocol,'http:');assert(['127.0.0.1','localhost','[::1]'].includes(baseURL.hostname),'Loopback only');
const root=path.resolve('releases',release),appPath=path.join(root,'app.html'),indexPath=path.join(root,'index.html');
const appText=fs.readFileSync(appPath,'utf8'),indexText=fs.readFileSync(indexPath,'utf8');
assert(indexText.includes("const BOOT={generation:0"),'Candidate boot runtime missing');
const candidateHash=crypto.createHash('sha256').update(indexText).digest('hex');
if(process.env.LTS_BOOT_EXPECTED_SHA256)assert.equal(candidateHash,process.env.LTS_BOOT_EXPECTED_SHA256);
const scriptSources=html=>[...html.matchAll(/<script\b[^>]*\bsrc="([^"]+)"[^>]*>/g)].map(x=>x[1]);
const expectedOuter=scriptSources(appText),expectedInner=scriptSources(indexText);
for(const src of [...expectedOuter,...expectedInner]){assert(!/^https?:/.test(src),'Release scripts must be local');assert(fs.existsSync(path.resolve(root,src.split('?')[0])),'Missing real release script: '+src);}
const qa=path.resolve(process.env.LTS_BOOT_QA_DIR||'qa/boot-recovery');fs.mkdirSync(qa,{recursive:true});
const syntheticSession={access_token:'synthetic-only-not-a-real-credential',refresh_token:'synthetic-only-refresh',token_type:'bearer',expires_in:3600,expires_at:4102444800,user:{id:'synthetic-viewer',email:'viewer@example.invalid'}};
const wait=ms=>new Promise(r=>setTimeout(r,ms));
async function run(browser,viewport,label,initialSession){
 const context=await browser.newContext({viewport});
 await context.addInitScript(({session,initialSession})=>{
  const NativeDate=Date;class TestDate extends NativeDate{constructor(...args){super(...(args.length?args:['2026-10-16T13:00:00Z']));}static now(){return NativeDate.parse('2026-10-16T13:00:00Z');}}window.Date=TestDate;
  // Seed only a fictitious session, once per same-origin browser context. Never inspect real storage.
  sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now())); // Synthetic recent collection avoids unrelated auto-refresh writes.
  if(!sessionStorage.getItem('boot-fixture-seeded')){sessionStorage.setItem('boot-fixture-seeded','yes');initialSession?localStorage.setItem('lts_supabase_session_v1',JSON.stringify(session)):localStorage.removeItem('lts_supabase_session_v1');}
  // Shorten only the candidate boot deadline. All real scripts/transport remain in order and intact.
  const nativeTimeout=window.setTimeout;window.setTimeout=function(fn,ms,...args){if(ms===30000&&typeof fn==='function'&&String(fn).includes('bootCurrent(run)'))ms=1500;return nativeTimeout.call(this,fn,ms,...args);};
 },{session:syntheticSession,initialSession});
 const page=await context.newPage();page.setDefaultTimeout(20000);
 const errors=[],blocked=[],badAssets=[],scriptResponses=new Set(),calls=[],pending=[],pendingCycles=[];let mode=initialSession?'error':'success',revision=1,authGeneration=0,holdCycles=false,frame;
 page.on('pageerror',e=>errors.push(String(e.stack||e)));
 page.on('response',response=>{const url=new URL(response.url());if(url.origin===baseURL.origin&&/\.js(?:\?|$)/.test(url.pathname+url.search)){if(response.status()!==200)badAssets.push({path:url.pathname,status:response.status()});else scriptResponses.add(url.pathname+url.search);}});
 await context.route('**/*',async route=>{
  const request=route.request(),url=new URL(request.url());
  if(url.origin===baseURL.origin)return route.continue();
  if(url.origin!=='https://tadhkamnwtsbdozwkyut.supabase.co'){blocked.push({origin:url.origin,path:url.pathname});return route.abort('blockedbyclient');}
  const name=url.pathname.split('/').pop();let args={};try{args=JSON.parse(request.postData()||'{}');}catch{}
  calls.push({name,args: name==='token'?{grant:url.searchParams.get('grant_type')}:args});
  const fulfill=(status,data)=>route.fulfill({status,contentType:'application/json',body:JSON.stringify(data)});
  if(url.pathname==='/auth/v1/token')return fulfill(200,{...syntheticSession,access_token:'synthetic-session-'+(++authGeneration),refresh_token:'synthetic-refresh-'+authGeneration});
  if(url.pathname==='/auth/v1/logout')return fulfill(200,{});
  if(!url.pathname.startsWith('/rest/v1/rpc/')||/_decision_|_save_|_apply_|_delete_|_confirm_|_mutate_|_classify_|_classification_|_refresh_|_update_|_create_|_upload_/.test(name)){blocked.push({origin:url.origin,path:url.pathname});return route.abort('blockedbyclient');}
  if(name==='lts_browser_product_v1'){
   if(mode==='error')return fulfill(500,{message:'statement timeout; SYNTHETIC_PRIVATE_DETAIL_DO_NOT_RENDER'});
   if(mode==='malformed')return fulfill(200,{ok:true});
   if(mode==='hold')return new Promise(resolve=>pending.push(async(data)=>{try{await fulfill(200,data);}catch{}finally{resolve();}}));
   return fulfill(200,{ok:true,mvp:fixture.product(revision)});
  }
  if(name==='lts_browser_card_cycles_v229'&&holdCycles)return new Promise(resolve=>pendingCycles.push(async()=>{try{await fulfill(200,fixture.response(name,args));}catch{}finally{resolve();}}));
  return fulfill(200,fixture.response(name,args));
 });
 const countProduct=()=>calls.filter(c=>c.name==='lts_browser_product_v1').length;
 const findFrame=async()=>{for(let i=0;i<200;i++){const f=page.frames().find(f=>new URL(f.url()||'about:blank').pathname.endsWith('/index.html'));if(f)return f;await wait(50);}throw Error('Release iframe missing');};
 const phase=async p=>{frame=await findFrame();await frame.waitForFunction(p=>document.body?.dataset.ltsBootState===p,p);};
 const installed=async()=>{await frame.waitForFunction(()=>window.__LTS_V183_CORE_LOADING_GUARD?.installed&&window.__LTS_V178_REVIEW?.installed&&window.__LTS_V225?.installed&&window.__LTS_V226&&window.__LTS_V227_TRANSPORT?.installed);};
 const assertStack=async()=>{
  assert.deepEqual(await page.locator('script[src]').evaluateAll(els=>els.map(e=>e.getAttribute('src'))),expectedOuter,'All real outer scripts in original DOM order');
  const inner=await frame.locator('script[src]').evaluateAll(els=>els.map(e=>e.getAttribute('src')));assert.deepEqual(inner.slice(0,expectedInner.length),expectedInner,'Original inner script order preserved');
  for(const src of expectedOuter){const u=new URL(src,BASE+'/releases/'+release+'/app.html');assert(scriptResponses.has(u.pathname+u.search),'Real outer script not loaded: '+src);}assert.deepEqual(badAssets,[]);
 };
 const capture=async name=>{
  const panel=frame.locator('#ltsBootRecovery');assert(await panel.isVisible(),'Recovery panel visible');
  const dimensions=await frame.locator('html').evaluate(e=>({client:e.clientWidth,scroll:e.scrollWidth}));assert(dimensions.scroll<=dimensions.client+2,'Recovery page horizontal overflow '+JSON.stringify(dimensions));
  const box=await panel.boundingBox();assert(box&&box.x>=-1&&box.x+box.width<=viewport.width+1,'Recovery panel fits '+JSON.stringify(box));
  const button=panel.locator('button').first();if(await button.count()){await button.scrollIntoViewIfNeeded();const b=await button.boundingBox();assert(b&&b.y>=0&&b.y+b.height<=viewport.height,'Recovery action inside viewport');await button.focus();assert(await button.evaluate(e=>document.activeElement===e),'Recovery action focusable; no stale modal inertness');}
  assert.equal(await frame.locator('#app').getAttribute('aria-hidden'),'true');assert(await frame.locator('#app').isHidden());assert(await frame.locator('#nav').isHidden());
  if(await frame.locator('#dx1MobileNav').count())assert(await frame.locator('#dx1MobileNav').isHidden(),'Mobile navigation hidden');
  await page.screenshot({path:path.join(qa,label+'-'+name+'.png')});
 };
 const invalidate=()=>frame.evaluate(()=>window.__LTS_V227_TRANSPORT?.invalidate(false));
 const startLoad=()=>frame.evaluate(()=>{load();});
 const ready=async()=>{await phase('ready');await installed();assert(await frame.locator('#ltsBootRecovery').isHidden());assert.equal(await frame.locator('#app').getAttribute('aria-hidden'),null);assert.equal(await frame.evaluate(()=>D.__bootFixtureRevision),revision);};
 const signIn=async()=>{await frame.locator('#email').fill('viewer@example.invalid');await frame.locator('#password').fill('synthetic-fixture-only');await frame.locator('#signin').click();await ready();};
 try{
  await page.goto(BASE+'/releases/'+release+'/app.html',{waitUntil:'domcontentloaded'});frame=await findFrame();
  if(!initialSession){
   await phase('signed-out');await installed();assert.equal(countProduct(),0,'Missing session cannot fetch product');await capture('missing-session');await assertStack();
   await signIn();assert.equal(countProduct(),1,'Session return loads product once');await page.screenshot({path:path.join(qa,label+'-session-return.png')});
  }else{
   await phase('data-error');await installed();await assertStack();await capture('statement-timeout');
   assert.equal(await frame.locator('#ltsBootRecovery .login').count(),0,'Product failure must not ask for login');assert.doesNotMatch(await frame.locator('#ltsBootRecovery').innerText(),/SYNTHETIC_PRIVATE_DETAIL|statement timeout/);
   const failed=countProduct();await wait(500);assert.equal(countProduct(),failed,'No automatic product retry loop');assert.equal(failed,1);
   mode='success';revision++;await frame.locator('#ltsBootRetry').evaluate(button=>{button.click();button.click();});await ready();assert.equal(countProduct(),failed+1,'Double retry admits one product read');
   // Real legacy drawer/dialog APIs, not substitute renderers.
   await frame.evaluate(()=>{window.__LTS_V178_REVIEW.openDetail('Categoria de teste',null,{from:'2026-01-01',to:'2026-10-16'},100);});await frame.waitForSelector('#v178Drawer');
   await frame.evaluate(()=>window.__LTS_V226.openDetail('itau_mastercard','2026-10-01'));await frame.waitForSelector('dialog#v226-detail[open]');
   mode='error';await invalidate();await startLoad();await phase('data-error');await capture('overlays-closed');assert.equal(await frame.locator('dialog[open]').count(),0);assert.equal(await frame.locator('#v178Drawer').count(),0,'Drawer API clears old detail');
   mode='success';revision++;await frame.locator('#ltsBootRetry').click();await ready();assert.equal(await frame.locator('#v178Drawer').count(),0,'Old drawer cannot return after ready');assert.equal(await frame.locator('dialog[open]').count(),0);
   // Unresolved RPC: logical timeout, no concurrent memory retry, stale result ignored.
   mode='hold';await invalidate();const before=countProduct();await startLoad();await phase('timeout');assert.equal(countProduct(),before+1);await capture('never-resolving');
   await startLoad();assert.equal(countProduct(),before+1,'Blocked memory retry after timeout');assert.equal(pending.length,1);await pending.shift()({ok:true,mvp:fixture.product(-1)});await wait(150);assert.equal(await frame.evaluate(()=>D),null);assert.equal(await frame.evaluate(()=>document.body.dataset.ltsBootState),'timeout');
   mode='success';revision++;const urlBefore=frame.url();await frame.locator('#ltsBootRetry').click();await ready();assert.equal(frame.url(),urlBefore,'Explicit reload keeps the same route/URL');assert.equal(countProduct(),before+2);
   // 200-invalid payload is already cacheable in the old transport: reload must discard it.
   mode='malformed';await invalidate();const malformedBefore=countProduct();await startLoad();await phase('data-error');await capture('malformed-product');assert.match(await frame.locator('#ltsBootRecovery').innerText(),/incompletos/);
   mode='success';revision++;await frame.locator('#ltsBootRetry').click();await ready();assert.equal(countProduct(),malformedBefore+2,'Malformed cached body cannot trap explicit retry');
   // Logout while product is pending invalidates the old generation before auth returns.
   mode='hold';await invalidate();await startLoad();await phase('loading');for(let i=0;!pending.length&&i<100;i++)await wait(20);assert.equal(pending.length,1);
   await frame.locator('#logout').click();await phase('signed-out');await capture('logout-during-load');await pending.shift()({ok:true,mvp:fixture.product(-2)});await wait(150);assert.equal(await frame.evaluate(()=>D),null);assert.equal(await frame.evaluate(()=>document.body.dataset.ltsBootState),'signed-out');
   mode='success';revision++;await signIn();assert.equal(await frame.locator('#v178Drawer').count(),0);assert.equal(await frame.locator('dialog[open]').count(),0);
   // Regression: openDetail awaiting expired cycles must not create a top-layer modal after logout.
   await frame.waitForFunction(()=>window.__LTS_V226?.cycles?.cards?.length===1&&!window.__LTS_V226.loading);
   holdCycles=true;await invalidate();await frame.evaluate(()=>{window.__LTS_V226.loadedAt=0;window.__bootTestPendingModal=window.__LTS_V226.openDetail('itau_mastercard','2026-10-01');});
   for(let i=0;!pendingCycles.length&&i<150;i++)await wait(20);assert.equal(pendingCycles.length,1,'Expired cycles read is actually pending');assert.equal(await frame.locator('dialog[open]').count(),0);
   await frame.locator('#logout').click();await phase('signed-out');holdCycles=false;await pendingCycles.shift()();await frame.evaluate(()=>window.__bootTestPendingModal);await frame.waitForFunction(()=>!window.__LTS_V226.loading);
   assert.equal(await frame.locator('dialog[open]').count(),0,'Late cycles response must not create modal after logout');assert.equal(await frame.locator('#v226-detail').count(),0);
   await capture('late-modal-after-logout');await frame.locator('#email').focus();assert(await frame.locator('#email').evaluate(e=>document.activeElement===e),'Login stays interactive after late modal response');
   revision++;await signIn();
   // Generation-specific regression: a new session can be ready before the old cycles read ends.
   holdCycles=true;await invalidate();await frame.evaluate(()=>{window.__LTS_V226.loadedAt=0;window.__bootTestPendingModal=window.__LTS_V226.openDetail('itau_mastercard','2026-10-01');});
   for(let i=0;!pendingCycles.length&&i<150;i++)await wait(20);assert.equal(pendingCycles.length,1,'One old-session cycles read is pending');
   await frame.locator('#logout').click();await phase('signed-out');revision++;await signIn();
   holdCycles=false;await pendingCycles.shift()();await frame.evaluate(()=>window.__bootTestPendingModal);await frame.waitForFunction(()=>!window.__LTS_V226.loading);
   assert.equal(await frame.evaluate(()=>document.body.dataset.ltsBootState),'ready');assert.equal(await frame.evaluate(()=>D.__bootFixtureRevision),revision);assert.equal(await frame.locator('dialog[open]').count(),0,'Old-session cycles response cannot open a modal in the new session');
   await page.screenshot({path:path.join(qa,label+'-old-modal-new-session.png')});
   await frame.evaluate(()=>window.__LTS_V226.openDetail('itau_mastercard','2026-10-01'));await frame.waitForSelector('dialog#v226-detail[open]');assert(await frame.locator('dialog#v226-detail').isVisible(),'Normal modal opening preserved after recovery');await frame.locator('[data-v226-close]').click();await frame.waitForSelector('#v226-detail',{state:'detached'});
   // The Flow settlement wrapper has its own awaited cycles path and must reject an older boot generation too.
   await frame.evaluate(()=>{V='Fluxo Diário';renderNav();render();});
   holdCycles=true;await invalidate();await frame.evaluate(()=>{window.__LTS_V226.loadedAt=0;window.__bootTestPendingSettlement=openCardSettlement({source:'card_invoice',source_ref:'synthetic-old-flow-invoice',event_date:'2026-10-25',account:'Itaú',signed_amount:-100,description:'Fatura fictícia'});});
   for(let i=0;!pendingCycles.length&&i<150;i++)await wait(20);assert.equal(pendingCycles.length,1,'One old-session settlement cycles read is pending');assert.equal(await frame.locator('dialog[open]').count(),0);
   await frame.locator('#logout').click();await phase('signed-out');revision++;await signIn();
   await frame.evaluate(()=>{V='Fluxo Diário';renderNav();render();});assert.equal(await frame.evaluate(()=>V),'Fluxo Diário','Same Flow route ensures generation, not route mismatch, blocks the old settlement');
   holdCycles=false;await pendingCycles.shift()();await frame.evaluate(()=>window.__bootTestPendingSettlement);await frame.waitForFunction(()=>!window.__LTS_V226.loading);
   assert.equal(await frame.evaluate(()=>document.body.dataset.ltsBootState),'ready');assert.equal(await frame.evaluate(()=>D.__bootFixtureRevision),revision);assert.equal(await frame.locator('dialog[open]').count(),0,'Old-session openCardSettlement response cannot open a modal after a new login');assert.equal(await frame.locator('#v226-detail').count(),0);
   await frame.locator('#logout').focus();assert(await frame.locator('#logout').evaluate(e=>document.activeElement===e),'Recovered page stays interactive after late settlement response');
   await page.screenshot({path:path.join(qa,label+'-old-settlement-new-session.png')});
   await page.screenshot({path:path.join(qa,label+'-recovered.png')});
  }
  await assertStack();assert.deepEqual(errors,[],'No uncaught errors in full ordered stack');assert.deepEqual(blocked,[],'No unmatched or mutating external requests');
  return {label,viewport,initial_session:initialSession,pass:true,product_reads:countProduct(),real_outer_scripts:expectedOuter.length,real_inner_scripts:expectedInner.length,financial_data:'entirely synthetic'};
 }catch(error){await page.screenshot({path:path.join(qa,label+'-failure.png'),fullPage:true}).catch(()=>{});throw Object.assign(error,{bootEvidence:{label,errors,blocked,badAssets,product_reads:countProduct(),phase:await frame?.evaluate(()=>document.body.dataset.ltsBootState).catch(()=>null)}});}
 finally{const cleanup=[...pending.splice(0).map(release=>release({ok:true,mvp:fixture.product(-99)})),...pendingCycles.splice(0).map(release=>release())];await Promise.race([Promise.allSettled(cleanup),wait(2000)]);await context.close();}
}
(async()=>{
 const result={status:'running',candidate_sha256:candidateHash,release,network:'all external requests intercepted; loopback release assets only',deadline_test_override:{production_ms:30000,test_ms:1500,selector:'only timeout callbacks whose source includes bootCurrent(run)',other_timers_unchanged:true},results:[]};
 const browser=await chromium.launch({headless:true,...(process.env.LTS_CHROMIUM_PATH?{executablePath:process.env.LTS_CHROMIUM_PATH}:{})});
 try{for(const [label,viewport] of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:844}],['narrow',{width:320,height:760}]]){result.results.push(await run(browser,viewport,label,true));result.results.push(await run(browser,viewport,label+'-no-session',false));}result.status='passed';console.log(JSON.stringify(result,null,2));}
 catch(error){result.status='failed';result.error=String(error.stack||error);result.evidence=error.bootEvidence||null;console.error(JSON.stringify(result,null,2));process.exitCode=1;}
 finally{fs.writeFileSync(path.join(qa,'boot-fullstack-result.json'),JSON.stringify(result,null,2)+'\n');await browser.close();}
})();
