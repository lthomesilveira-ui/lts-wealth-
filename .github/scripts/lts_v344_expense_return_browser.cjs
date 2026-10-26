'use strict';
const {chromium}=require('playwright'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const release=process.env.LTS_RELEASE||'v344',expectMissing=process.env.LTS_EXPECT_MISSING_RETURN==='true';assert(['v342','v344'].includes(release));
const fixture=require('./lts_v309_fixtures.cjs'),base='http://127.0.0.1:8788',out=path.resolve('qa/v344');fs.mkdirSync(out,{recursive:true});
const session={access_token:'synthetic-only-access',refresh_token:'synthetic-only-refresh',expires_at:4102444800,user:{id:'00000000-0000-4000-8000-000000000001',email:'viewer@example.invalid'}};
const group='Apartamento · CIPÓ 396',range={from:'2024-04-01',to:'2024-08-31'};
const acquisitions=Array.from({length:40},(_,i)=>({key:'acquisition-'+i,date_kind:'day',date:'2024-04-10',period:'2024-04-01',description:'Aquisição fictícia '+i,amount:1,account_source:'Conta fictícia',beneficiary:null,component:'Aquisição do imóvel'}));
const works=Array.from({length:30},(_,i)=>({key:'work-'+i,date_kind:'day',date:'2024-05-10',period:'2024-05-01',description:'Obra fictícia '+i,amount:2,account_source:'Conta fictícia',beneficiary:null,component:'Obra e reforma'}));
const components=[{name:'Aquisição do imóvel',total:40},{name:'Obra e reforma',total:60}];
async function run(browser,viewport,label){
 const context=await browser.newContext({viewport,isMobile:viewport.width<600,hasTouch:viewport.width<600,serviceWorkers:'block'});
 await context.addInitScript(session=>{const NativeDate=Date;window.Date=class extends NativeDate{constructor(...args){super(...(args.length?args:['2026-10-16T22:00:00Z']));}static now(){return NativeDate.parse('2026-10-16T22:00:00Z');}};localStorage.setItem('lts_supabase_session_v1',JSON.stringify(session));sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));},session);
 const page=await context.newPage();page.setDefaultTimeout(25000);const errors=[],writes=[],blocked=[],requests=[];let hold=false,held,releaseHeld;
 const heldStarted=new Promise(resolve=>held=resolve),gate=new Promise(resolve=>releaseHeld=resolve);
 page.on('pageerror',e=>errors.push(String(e)));
 await context.route('**/*',async route=>{
  const req=route.request(),u=new URL(req.url());if(u.origin===base)return route.continue();
  if(u.origin!=='https://tadhkamnwtsbdozwkyut.supabase.co'){blocked.push(u.origin+u.pathname);return route.abort();}
  const name=u.pathname.split('/').pop(),args=JSON.parse(req.postData()||'{}'),send=data=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(data)});
  if(u.pathname==='/auth/v1/token')return send(session);
  if(u.pathname==='/auth/v1/logout')return send({});
  if(name==='lts_browser_product_v1')return send({ok:true,mvp:fixture.product()});
  if(name==='lts_browser_expense_detail_v229'){
   requests.push(args);let rows=args.p_subgroup==='Aquisição do imóvel'?acquisitions:args.p_subgroup==='Obra e reforma'?works:[...acquisitions,...works];
   if(hold&&args.p_subgroup==='Obra e reforma'){hold=false;held();await gate;}
   return send({revision:'synthetic-navigation-v1',offset:0,next_offset:null,row_count:rows.length,total:rows.reduce((n,r)=>n+r.amount,0),rows,components});
  }
  if(name==='lts_browser_property_archive_v178')return send({rows:[{key:'archive-1',date_kind:'historical',description:'Arquivo fictício A',component:'Obra',amount:10},{key:'archive-2',date_kind:'historical',description:'Arquivo fictício B',component:'Consórcio',amount:20}]});
  if(name==='lts_browser_cash_today_v242')return send({...fixture.response(name,args),bank_positions:[{institution_code:'341',balance:600},{institution_code:'237',balance:400},{institution_code:'336',balance:0}]});
  if(name==='lts_browser_income_review_queue_v296'||name==='lts_browser_card_review_queue_v312'||name==='lts_browser_expense_review_queue_v229')return send({ok:true,row_count:0,matched_count:0,additional_count:0,offset:0,next_offset:null,rows:[],category_options:['Farmácia']});
  if(name==='lts_browser_open_finance_status_v1')return send({connections:[],last_syncs:[]});
  if(name==='lts_browser_future_bank_v293')return send({rows:[],card_future_received:0});
  if(/_decision_|_save_|_apply_|_delete_|_refresh_|_confirm_|_upload_|_mutate_|_classify_|_classification_|_create_|_update_/.test(name)){writes.push(name);return route.abort();}
  return send(fixture.response(name,args));
 });
 let frame;
 try{
  await page.goto(base+'/releases/'+release+'/app.html',{waitUntil:'domcontentloaded'});
  for(let i=0;i<200;i++){frame=page.frames().find(f=>f.url().includes('/releases/'+release+'/index.html'));if(frame)break;await page.waitForTimeout(50);}assert(frame);
  await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='ready'&&window.__LTS_V178_REVIEW?.installed);
  await frame.evaluate(({group,range})=>{V='Despesas';window.__LTS_V168_STATE.expense.key='custom';window.__LTS_V168_STATE.expense.customFrom=range.from;window.__LTS_V168_STATE.expense.customTo=range.to;render();window.__LTS_V178_REVIEW.openDetail(group,null,range,100);},{group,range});
  const drawer=frame.locator('#v178Drawer'),ready=()=>frame.waitForFunction(()=>window.__LTS_V178_STATE.detail&&!window.__LTS_V178_STATE.detail.loading&&!window.__LTS_V178_STATE.detail.error);
  await ready();await drawer.locator('[data-component="Aquisição do imóvel"]').click();await ready();assert.equal(await drawer.locator('h2').innerText(),'Aquisição do imóvel');
  if(expectMissing){assert.equal(await drawer.locator('.v344-back').count(),0);return{pass:true,release,prior_missing_parent_return_reproduced:true,synthetic_http:true};}
  await drawer.locator('.v344-back').click();await ready();assert.equal(await drawer.locator('h2').innerText(),group);
  await drawer.locator('.v178-all-rows').click();const input=drawer.locator('.v178-filter input');await input.fill('Obra');
  assert.equal(await drawer.locator('tbody tr').count(),30);
  await drawer.locator('.v178-detail-scroll').evaluate(e=>e.scrollTop=150);
  const scroll=await drawer.locator('.v178-detail-scroll').evaluate(e=>e.scrollTop);
  await drawer.locator('[data-component="Aquisição do imóvel"]').click();await ready();assert.equal(await drawer.locator('tbody tr').count(),40);
  assert.match(await drawer.locator('.v344-back').getAttribute('aria-label'),/Apartamento/);
  assert.equal(await drawer.locator('.v344-context').innerText(),group);
  assert.equal((await drawer.locator('header').innerText()).match(/01\/04\/2024/g).length,1,'One visible period; parent context stays visible');
  const backBox=await drawer.locator('.v344-back').boundingBox();assert(backBox&&backBox.y>=0&&backBox.y+backBox.height<=viewport.height);
  await page.screenshot({path:path.join(out,label+'-acquisition-return.png')});
  await drawer.locator('.v344-back').click();await ready();assert.equal(await input.inputValue(),'Obra');assert.equal(await drawer.locator('tbody tr').count(),30);assert.equal(await drawer.locator('.v178-detail-scroll').evaluate(e=>e.scrollTop),scroll);
  assert.equal(await drawer.locator('.v178-detail-scroll').isVisible(),true);assert.match(await drawer.locator('header').innerText(),/01\/04\/2024 a 31\/08\/2024/);
  await drawer.locator('.v178-archive').click();await ready();assert.equal(await drawer.locator('h2').innerText(),'Histórico completo de investimentos');
  await drawer.locator('[data-archive-component="Obra"]').click();await ready();assert.equal(await drawer.locator('tbody tr').count(),1);
  await drawer.locator('.v344-back').click();await ready();assert.equal(await drawer.locator('tbody tr').count(),2);
  await drawer.locator('.v344-back').click();await ready();assert.equal(await drawer.locator('h2').innerText(),group);assert.equal(await input.inputValue(),'Obra');
  await drawer.locator('.v344-back').click();assert.equal(await drawer.count(),0);
  assert.deepEqual(await frame.evaluate(()=>({key:window.__LTS_V168_STATE.expense.key,from:window.__LTS_V168_STATE.expense.customFrom,to:window.__LTS_V168_STATE.expense.customTo})),{key:'custom',from:range.from,to:range.to});
  // Invalidate the transport cache before holding the first response for this child.
  await frame.evaluate(()=>window.__LTS_V227_TRANSPORT.invalidate(false));
  await frame.evaluate(({group,range})=>window.__LTS_V178_REVIEW.openDetail(group,null,range,100),{group,range});await ready();
  hold=true;await drawer.locator('[data-component="Obra e reforma"]').click();await heldStarted;
  await drawer.locator('.v344-back').click();await ready();releaseHeld();await page.waitForTimeout(150);assert.equal(await drawer.locator('h2').innerText(),group);assert.equal(await drawer.locator('tbody tr').count(),70);
  await drawer.locator('[data-component="Aquisição do imóvel"]').click();await ready();await frame.evaluate(()=>window.dispatchEvent(new Event('lts:data-invalidated')));assert.equal(await drawer.count(),0);
  await frame.evaluate(({group,range})=>window.__LTS_V178_REVIEW.openDetail(group,null,range,100),{group,range});await ready();await frame.evaluate(()=>{V='Dashboard';render();});assert.equal(await drawer.count(),0);
  await frame.evaluate(({group,range})=>{V='Despesas';render();window.__LTS_V178_REVIEW.openDetail(group,null,range,100);},{group,range});await ready();await frame.evaluate(()=>S.auth.signOut());assert.equal(await drawer.count(),0);
  assert(requests.every(r=>r.p_from===range.from&&r.p_to===range.to));assert.deepEqual(errors,[]);assert.deepEqual(writes,[]);assert.deepEqual(blocked,[]);
  return{pass:true,release,label,viewport,parent_return:true,root_return:true,archive_return:true,period_preserved:true,query_preserved:true,scroll_and_list_mode_preserved:true,late_child_rejected:true,invalidation_closes_history:true,route_change_closes_history:true,signout_closes_history:true,synthetic_http:true,private_session:false,physical_device:false};
 }catch(e){await page.screenshot({path:path.join(out,label+'-expense-return-failure.png')});console.error({label,errors,writes,blocked,requests});throw e;}finally{releaseHeld();await context.close();}
}
(async()=>{const browser=await chromium.launch({headless:true});try{const results=[];for(const [viewport,label]of(expectMissing?[[{width:1440,height:1000},'v342']]:[[{width:1440,height:1000},'desktop'],[{width:390,height:844},'mobile-390'],[{width:360,height:800},'mobile-360']]))results.push(await run(browser,viewport,label));fs.writeFileSync(path.join(out,expectMissing?'v342-missing-return.json':'expense-return-results.json'),JSON.stringify({pass:true,results},null,2));console.log(JSON.stringify({pass:true,results}));}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
