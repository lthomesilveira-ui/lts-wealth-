'use strict';
// Synthetic HTTP only; the signed-source projection comes from native PostgreSQL.
const {chromium}=require('playwright'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const fixture=require('./lts_v309_fixtures.cjs'),f=require('./lts_v359_fixtures.cjs'),base='http://127.0.0.1:8788',out=path.resolve('qa/v359');
const packet=JSON.parse(fs.readFileSync(path.join(out,'native-source-result.json')));assert(packet.pass&&packet.version===358);
const rows=f.rows(),wealth=f.wealth(packet.synthetic_projection),session={access_token:'synthetic-only-access',refresh_token:'synthetic-only-refresh',expires_at:4102444800,user:{id:'00000000-0000-4000-8000-000000000001',email:'viewer@example.invalid'}};
async function run(browser,viewport,label){
 const ctx=await browser.newContext({viewport,isMobile:viewport.width<600,hasTouch:viewport.width<600,serviceWorkers:'block'});
 await ctx.addInitScript(s=>{const NativeDate=Date;window.Date=class extends NativeDate{constructor(...a){super(...(a.length?a:['2026-10-27T15:00:00Z']));}static now(){return NativeDate.parse('2026-10-27T15:00:00Z');}};localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s));sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));},session);
 const page=await ctx.newPage();page.setDefaultTimeout(25000);const errors=[],writes=[],reads=[];let failNext=false,hold=false,started,release,holdGate;
 page.on('pageerror',e=>errors.push(String(e)));
 await ctx.route('**/*',async route=>{
  const req=route.request(),url=new URL(req.url());if(url.origin===new URL(base).origin)return route.continue();if(url.origin!=='https://tadhkamnwtsbdozwkyut.supabase.co')return route.abort();
  const name=url.pathname.split('/').pop(),args=JSON.parse(req.postData()||'{}'),send=j=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(j)});
  if(url.pathname==='/auth/v1/token')return send(session);if(url.pathname==='/auth/v1/logout')return send({});
  if(name==='lts_browser_product_v1')return send({ok:true,mvp:fixture.product()});
  if(/^lts_browser_wealth_detail_/.test(name))return send(wealth);
  if(name==='lts_browser_expense_detail_v353'){
   reads.push(args);if(hold){started?.();await holdGate;}if(failNext){failNext=false;return route.fulfill({status:503,contentType:'application/json',body:JSON.stringify({message:'synthetic failure'})});}
   const selected=rows.filter(r=>f.matches(r,args.p_scope||{},args.p_from,args.p_to)),offset=args.p_offset||0,limit=Math.min(120,args.p_limit||500);
   return send({version:'expense-detail-v353',revision:'synthetic-v359',from:args.p_from,to:args.p_to,total:f.total(selected),row_count:selected.length,offset,next_offset:offset+limit<selected.length?offset+limit:null,rows:selected.slice(offset,offset+limit),components:[]});
  }
  if(name==='lts_browser_expense_composition_v346')return send({status:'complete',total:3.1043333333333,identified_total:3.1043333333333,residual_total:0,count:2,rows:[1,2.1043333333333].map((amount,i)=>({key:'child-'+i,amount,original_amount:amount,date:'2026-10-01',date_kind:'source',description:'Compra original '+i,account_source:'Cartão fictício',category:'Serviços',original_category:'Serviços',period:'2026-10-01',source:{file:'Synthetic.xlsm',sheet:'Cartão fictício',row:i+1,date:'2026-10-01',date_cell:'C'+(i+1),amount_cell:'D'+(i+1),description:'Compra original '+i,amount}}))});
  if(/income_review_queue_|card_review_queue_|expense_review_queue_/.test(name))return send({ok:true,rows:[],row_count:0,offset:0,next_offset:null,category_options:[]});
  if(name==='lts_browser_open_finance_status_v1')return send({connections:[],last_syncs:[]});
  if(name==='lts_browser_future_bank_v293')return send({rows:[],card_future_received:0});
  if(/_decision_|_save_|_apply_|_delete_|_refresh_|_confirm_|_upload_|_mutate_|_classify_|_classification_|_create_|_update_/.test(name)){writes.push(name);return route.abort();}
  return send(fixture.response(name,args));
 });
 try{
  await page.goto(base+'/releases/v359/app.html',{waitUntil:'domcontentloaded'});let frame;
  for(let i=0;i<200;i++){frame=page.frames().find(f=>f.url().includes('/releases/v359/index.html'));if(frame)break;await page.waitForTimeout(50);}assert(frame);
  await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='ready'&&typeof window.__LTS_V178_REVIEW?.openCipoReconciliation==='function'&&typeof D!=='undefined'&&D&&!N.classList.contains('hidden'));
  await page.waitForLoadState('networkidle');
  await frame.evaluate(w=>{window.__LTS_V168_STATE.wealth.data=w;window.__LTS_V168_STATE.wealth.tab='assets';V='Patrimônio';renderNav();render();},wealth);
  await frame.locator('[data-v168-cipo]').click();
  const modal=frame.locator('#v359Cipo');await modal.getByRole('heading',{name:'Da aquisição no Excel aos gastos classificados'}).waitFor();
  assert.equal(await modal.locator('.v359-group').count(),4);assert.match(await modal.locator('.v359-gap').innerText(),/2,00/);
  assert.equal(await modal.locator('details[open]').count(),0);
  assert.equal(await modal.locator('.v359-source-cash tbody tr').count(),6,'copies counted once');
  const primaryHeight=await modal.locator('.v359-property').evaluate(el=>({height:el.getBoundingClientRect().height,screen:innerHeight,width:el.scrollWidth,client:el.clientWidth}));assert(primaryHeight.height<=primaryHeight.screen&&primaryHeight.width<=primaryHeight.client+2);
  await page.screenshot({path:path.join(out,label+'-property-comparison.png')});
  await modal.locator('.v359-source-cash > summary').click();assert.match(await modal.locator('.v359-source-cash').innerText(),/-.*5,00/);assert.match(await modal.locator('.v359-source-cash').innerText(),/Linha sem valor movimentado/);assert(!await modal.locator('.v359-source-cash').innerText().then(t=>t.includes('Synthetic.xlsm')),'source closed');
  await modal.locator('.v359-source-cash .v359-origin').first().locator('summary').click();assert.match(await modal.locator('.v359-source-cash').innerText(),/Synthetic.xlsm/);
  await modal.locator('.v359-source-cash > summary').click();
  await modal.locator('.v359-unlinked > summary').click();assert.equal(await modal.locator('.v359-unlinked tbody tr').count(),2);await modal.locator('.v359-unlinked').evaluate(el=>el.scrollIntoView({block:'center',behavior:'instant'}));await page.screenshot({path:path.join(out,label+'-unlinked-source.png')});
  for(const id of [0,2,3]){
   await modal.locator('.v359-group').nth(id).locator('button').first().click();const drawer=frame.locator('#v178Drawer');await drawer.locator('footer span').filter({hasText:'lista completa'}).waitFor();
   const expected=[4,350,1,1][id];assert.match(await drawer.locator('.v178-detail-summary').innerText(),new RegExp(String(expected)));assert.equal(await drawer.locator('tbody tr').count(),expected);
   await drawer.locator('.v344-back').click();await modal.locator('.v359-group').first().waitFor();
  }
  await modal.locator('.v359-group').nth(1).locator('details > summary').click();await modal.locator('.v359-group').nth(1).getByRole('button',{name:/Serviços/}).click();
  const drawer=frame.locator('#v178Drawer');await drawer.locator('.v353-more').waitFor();assert.equal(await drawer.locator('tbody tr').count(),300);
  await drawer.locator('.v353-more').click();assert.equal(await drawer.locator('tbody tr').count(),350);
  await drawer.locator('input').fill('work-349');assert.equal(await drawer.locator('tbody tr').count(),1);await drawer.locator('input').fill('');
  await drawer.locator('.v346-open-composition').click();await drawer.locator('footer span').filter({hasText:'registros'}).waitFor();assert.match(await drawer.locator('tbody').innerText(),/Compra original 0/);await drawer.locator('.v344-back').click();await drawer.locator('footer span').filter({hasText:'350'}).waitFor();await drawer.locator('.v344-back').click();await modal.locator('.v359-group').first().waitFor();
  const prefix=modal.getByRole('button',{name:/Parcelas incluídas/});await prefix.click();await drawer.locator('footer span').filter({hasText:'lista completa'}).waitFor();assert.equal(await drawer.locator('tbody tr').count(),1);assert.match(await drawer.locator('tbody').innerText(),/prefix/);await drawer.locator('.v344-back').click();await modal.locator('.v359-group').first().waitFor();
  await modal.locator('.v359-close').click();
  failNext=true;await frame.evaluate(w=>window.__LTS_V178_REVIEW.openCipoReconciliation(w,true),wealth);await modal.locator('.v359-retry').waitFor();await modal.locator('.v359-retry').click();await modal.locator('.v359-group').first().waitFor();await modal.locator('.v359-close').click();
  const holdStarted=new Promise(r=>started=r);holdGate=new Promise(r=>release=r);hold=true;
  await frame.evaluate(w=>{window.__LTS_V178_REVIEW.openCipoReconciliation(w,true)},wealth);await Promise.race([holdStarted,new Promise((_,reject)=>setTimeout(()=>reject(Error('Held source request not observed')),10000))]);
  await frame.evaluate(()=>{V='Dashboard';renderNav();render();});release();hold=false;await page.waitForLoadState('networkidle');assert.equal(await modal.count(),0);
  await frame.evaluate(w=>{V='Patrimônio';render();window.__LTS_V178_REVIEW.openCipoReconciliation(w,true)},wealth);await modal.locator('.v359-group').first().waitFor();await frame.evaluate(()=>S.auth.signOut());assert.equal(await modal.count(),0);assert.equal(await drawer.count(),0);
  assert.deepEqual(errors,[]);assert.deepEqual(writes,[]);assert(reads.some(r=>r.p_offset===240));
  return{pass:true,label,native_source_projection_consumed:true,groups:4,all_pages_loaded:true,category_drilldown:true,return_context:true,source_copies_counted_once:true,negative_zero_preserved:true,material_gap_visible:true,sources_closed:true,retry_verified:true,late_response_rejected:true,signout_clears_source:true,synthetic_session:true,private_http:false,physical_device:false};
 }catch(e){await page.screenshot({path:path.join(out,label+'-failure.png')});console.error({label,errors,writes,lastReads:reads.slice(-8)});throw e;}finally{release?.();await ctx.close();}
}
(async()=>{const browser=await chromium.launch({headless:true});try{const results=[];for(const[label,v]of[['desktop',{width:1440,height:1000}],['mobile-390',{width:390,height:844}],['mobile-360',{width:360,height:800}]])results.push(await run(browser,v,label));fs.writeFileSync(path.join(out,'property-browser-results.json'),JSON.stringify(results,null,2));console.log(JSON.stringify(results));}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
