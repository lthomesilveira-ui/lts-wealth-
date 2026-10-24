'use strict';
// Native PostgreSQL classification payloads, rendered through the actual V312 application.
const {chromium}=require('playwright'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const fixture=require('./lts_v309_fixtures.cjs'),qa=path.resolve('qa/v312'),native=JSON.parse(fs.readFileSync(path.join(qa,'native-before.json'))),after=JSON.parse(fs.readFileSync(path.join(qa,'native-after.json'))),saved=JSON.parse(fs.readFileSync(path.join(qa,'native-save.json')));
const BASE='http://127.0.0.1:8788',root=path.resolve('releases/v312'),manifest=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'))),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const session={access_token:'synthetic-only-access',refresh_token:'synthetic-only-refresh',expires_at:4102444800,user:{id:'00000000-0000-4000-8000-000000000001',email:'viewer@example.invalid'}};
async function run(browser,viewport,label){
 const context=await browser.newContext({viewport,isMobile:viewport.width<600,hasTouch:viewport.width<600,serviceWorkers:'block'});
 await context.addInitScript(session=>{localStorage.setItem('lts_supabase_session_v1',JSON.stringify(session));sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));},session);
 const page=await context.newPage();page.setDefaultTimeout(30000);const errors=[],blocked=[],assets=new Set(),reads=[],writes=[];let classified=false,failQueue=false;
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('response',r=>{const u=new URL(r.url()),name=path.basename(u.pathname);if(u.origin===BASE&&u.pathname.startsWith('/releases/v312/')&&manifest.files[name])reads.push(r.body().then(bytes=>{assert.equal(r.status(),200);assert.equal(hash(bytes),manifest.files[name]);assets.add(name);}));});
 await context.route('**/*',async route=>{
  const req=route.request(),u=new URL(req.url());if(u.origin===BASE)return route.continue();
  if(u.origin!=='https://tadhkamnwtsbdozwkyut.supabase.co'){blocked.push(u.origin+u.pathname);return route.abort();}
  const name=u.pathname.split('/').pop(),args=JSON.parse(req.postData()||'{}'),send=data=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(data)});
  if(u.pathname==='/auth/v1/token')return send(session);
  if(name==='lts_browser_product_v1')return send({ok:true,mvp:fixture.product()});
  if(name==='lts_browser_card_review_queue_v312'){
   if(failQueue)return route.fulfill({status:500,contentType:'application/json',body:JSON.stringify({message:'source_ref synthetic SQL must never be rendered'})});
   const source=classified?after:native,q=String(args.p_query||'').toLocaleLowerCase('pt-BR'),filtered=source.rows.filter(r=>!q||r.description.toLocaleLowerCase('pt-BR').includes(q)),offset=Number(args.p_offset||0),limit=Number(args.p_limit||10);
   return send({...source,offset,matched_count:filtered.length,next_offset:offset+limit<filtered.length?offset+limit:null,rows:filtered.slice(offset,offset+limit)});
  }
  if(name==='lts_browser_card_review_save_v312'){
   assert.equal(args.p_source_id,'00000000-0000-4000-8000-000000000001');assert.equal(args.p_expected_raw_hash,'a'.repeat(64));assert.equal(args.p_category,'Farmácia');assert.equal(args.p_beneficiary,null);
   writes.push({name,args});classified=true;return send(saved);
  }
  if(name==='lts_browser_card_category_options_v226')return send({categories:native.category_options,aliases:{}});
  if(name==='lts_browser_expense_review_queue_v229')return send({row_count:0,matched_count:0,offset:0,next_offset:null,category_options:native.category_options,rows:[]});
  if(/_save_|_create_|_mutate_|_delete_|_confirm_|_classify_/.test(name)){blocked.push(name);return route.abort();}
  if(name==='lts_browser_open_finance_status_v1')return send({connections:[],last_syncs:[]});
  if(name==='lts_browser_future_bank_v293')return send({rows:[],card_future_received:0});
  if(name==='lts_browser_income_review_queue_v296')return send({ok:true,row_count:0,matched_count:0,offset:0,next_offset:null,rows:[]});
  if(/recurring_future_gap/.test(name))return send(fixture.recurring());
  return send(fixture.response(name,args));
 });
 try{
  await page.goto(BASE+'/releases/v312/app.html',{waitUntil:'domcontentloaded'});
  let frame;for(let n=0;n<200;n++){frame=page.frames().find(f=>f.url().includes('/releases/v312/index.html'));if(frame)break;await page.waitForTimeout(50);}assert(frame);
  await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='ready'&&window.__LTS_V168_STATE);
  await frame.waitForFunction(()=>window.__LTS_V312_CARD_REVIEW?.installed&&window.__LTS_V312_CARD_REVIEW.state.data?.row_count===9);
  await frame.locator(viewport.width<820?'[data-mobile-route="Atualizações"]':'[data-v="Atualizações"]').first().click();
  const panel=frame.locator('#v312CardReview');await panel.waitFor();
  assert.equal(await panel.locator('[data-v312-count]').innerText(),'9');
  assert.equal(await panel.locator('.lts-card-review-row').count(),9);
  assert.equal(await panel.locator('details[open]').count(),0,'Source details stay closed');
  const search=panel.locator('[name=card-query]');await search.fill('Farmácia');await search.press('Enter');
  await frame.waitForFunction(()=>window.__LTS_V312_CARD_REVIEW.state.data?.matched_count===2);
  await panel.locator('.lts-card-review-row').nth(1).waitFor();assert.equal(await panel.locator('.lts-card-review-row').count(),2);
  await panel.locator('[name=card-query]').fill('');await panel.locator('[name=card-query]').press('Enter');
  await frame.waitForFunction(()=>window.__LTS_V312_CARD_REVIEW.state.data?.matched_count===9);
  await panel.locator('.lts-card-review-row').nth(8).waitFor();
  const row=panel.locator('.lts-card-review-row').filter({hasText:'Farmácia de teste'}).first();
  await row.getByRole('button',{name:'Revisar',exact:true}).click();
  let dialog=frame.locator('#v312CardDialog'),select=dialog.locator('[name=category]');
  assert.equal(await select.inputValue(),'Farmácia');
  assert.equal(await dialog.locator('[name=beneficiary]').inputValue(),'');
  assert.equal(writes.length,0,'A suggestion never saves itself');
  await select.selectOption('');await select.focus();
  assert(await dialog.getByRole('button',{name:'Confirmar classificação',exact:true}).isDisabled());
  const preserved=await select.evaluate(el=>{el.dataset.kept='yes';render();return el.isConnected&&document.activeElement===el;});assert(preserved,'Native picker must survive a background render');
  assert.equal(await select.inputValue(),'');assert.equal(await select.getAttribute('data-kept'),'yes');
  await select.selectOption('Farmácia');
  await dialog.getByRole('button',{name:'Confirmar classificação',exact:true}).click();
  await frame.waitForFunction(()=>window.__LTS_V312_CARD_REVIEW.state.data?.row_count===8);
  assert.equal(writes.length,1);assert.equal(await frame.locator('#v312CardReview [data-v312-count]').innerText(),'8');
  const learned=frame.locator('#v312CardReview .lts-card-review-row').filter({hasText:'Farmácia de teste'});
  assert.equal(await learned.count(),1);await learned.getByRole('button',{name:'Revisar',exact:true}).click();
  dialog=frame.locator('#v312CardDialog');assert.equal(await dialog.locator('[name=category]').inputValue(),'Farmácia');
  assert.equal(await dialog.locator('details[open]').count(),0);
  await dialog.locator('summary').click();assert.match(await dialog.locator('details').innerText(),/Mesmo estabelecimento e valor no histórico/);
  await dialog.locator('summary').click();
  await dialog.locator('[data-v312-close]').click();
  await page.screenshot({path:path.join(qa,label+'-card-review.png')});
  for(const view of ['Dashboard','Fluxo Diário','Despesas','Patrimônio','Atualizações']){
   await frame.evaluate(view=>{V=view;renderNav();render();},view);await page.waitForTimeout(150);
   const size=await frame.locator('html').evaluate(el=>({width:el.clientWidth,scroll:el.scrollWidth}));assert(size.scroll<=size.width+2,view+' page overflow');
  }
  failQueue=true;await frame.evaluate(()=>{window.__LTS_V312_CARD_REVIEW.refresh();});
  await frame.locator('#v312CardReview [role=alert]').waitFor();
  assert.equal(await frame.locator('#v312CardReview [data-v312-count]').innerText(),'8','An unavailable read cannot masquerade as zero pending');
  assert.doesNotMatch(await frame.locator('#v312CardReview').innerText(),/source_ref|synthetic SQL/);
  const dims=await frame.locator('html').evaluate(el=>({width:el.clientWidth,scroll:el.scrollWidth}));assert(dims.scroll<=dims.width+2);
  await Promise.all(reads);assert.deepEqual(errors,[]);assert.deepEqual(blocked,[]);
  return{pass:true,label,viewport,real_assets_verified:assets.size,fixture_engine:'postgresql17',native_postgresql_fixture:true,production_session:false};
 }catch(error){await page.screenshot({path:path.join(qa,label+'-failure.png')});console.error({label,errors,blocked});throw error;}finally{await context.close();}
}
(async()=>{const browser=await chromium.launch({headless:true});try{const results=[];for(const [viewport,label]of [[{width:1440,height:1000},'desktop'],[{width:390,height:844},'mobile-390'],[{width:360,height:800},'mobile-360']])results.push(await run(browser,viewport,label));const result={pass:true,results};fs.writeFileSync(path.join(qa,'browser-results.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));}finally{await browser.close();}})().catch(error=>{console.error(error);process.exitCode=1;});
