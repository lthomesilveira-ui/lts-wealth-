'use strict';
const {chromium}=require('playwright'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const fixture=require('./lts_v309_fixtures.cjs'),qa=path.resolve('qa/v318'),before=JSON.parse(fs.readFileSync(path.join(qa,'native-before.json'))),after=JSON.parse(fs.readFileSync(path.join(qa,'native-after.json'))),manifest=JSON.parse(fs.readFileSync('releases/v312/manifest.json'));
const BASE='http://127.0.0.1:8788',session={access_token:'synthetic-only-access',refresh_token:'synthetic-only-refresh',expires_at:4102444800,user:{id:'00000000-0000-4000-8000-000000000001',email:'viewer@example.invalid'}};
async function run(browser,viewport,label){
 const context=await browser.newContext({viewport,isMobile:viewport.width<600,hasTouch:viewport.width<600,serviceWorkers:'block'});
 await context.addInitScript(s=>{localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s));sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));},session);
 const page=await context.newPage(),errors=[],blocked=[],reads=[],assets=new Set();let updated=false;
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('response',r=>{const u=new URL(r.url()),name=path.basename(u.pathname);if(u.origin===BASE&&u.pathname.startsWith('/releases/v312/')&&manifest.files[name])reads.push(r.body().then(b=>{assert.equal(r.status(),200);assert.equal(crypto.createHash('sha256').update(b).digest('hex'),manifest.files[name]);assets.add(name);}));});
 await context.route('**/*',async route=>{
  const req=route.request(),u=new URL(req.url());if(u.origin===BASE)return route.continue();
  if(u.origin!=='https://tadhkamnwtsbdozwkyut.supabase.co'){blocked.push(u.origin+u.pathname);return route.abort();}
  const name=u.pathname.split('/').pop(),args=JSON.parse(req.postData()||'{}'),send=data=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(data)});
  if(u.pathname==='/auth/v1/token')return send(session);
  if(name==='lts_browser_product_v1')return send({ok:true,mvp:fixture.product()});
  if(name==='lts_browser_card_review_queue_v312'){
   const data=updated?after:before,q=String(args.p_query||'').toLocaleLowerCase('pt-BR'),rows=data.rows.filter(r=>!q||r.description.toLocaleLowerCase('pt-BR').includes(q)),offset=Number(args.p_offset||0),limit=Number(args.p_limit||10);
   return send({...data,offset,matched_count:rows.length,next_offset:offset+limit<rows.length?offset+limit:null,rows:rows.slice(offset,offset+limit)});
  }
  if(/_save_|_create_|_mutate_|_delete_|_confirm_|_classify_|lts_apply_/.test(name)){blocked.push(name);return route.abort();}
  if(name==='lts_browser_card_category_options_v226')return send({categories:before.category_options,aliases:{}});
  if(name==='lts_browser_expense_review_queue_v229'||name==='lts_browser_income_review_queue_v296')return send({ok:true,row_count:0,matched_count:0,offset:0,next_offset:null,category_options:before.category_options,rows:[]});
  if(name==='lts_browser_open_finance_status_v1')return send({connections:[],last_syncs:[]});
  if(name==='lts_browser_future_bank_v293')return send({rows:[],card_future_received:0});
  if(/recurring_future_gap/.test(name))return send(fixture.recurring());
  return send(fixture.response(name,args));
 });
 try{
  await page.goto(BASE+'/releases/v312/app.html',{waitUntil:'domcontentloaded'});
  let frame;for(let i=0;i<200;i++){frame=page.frames().find(f=>f.url().includes('/releases/v312/index.html'));if(frame)break;await page.waitForTimeout(50);}assert(frame);
  await frame.waitForFunction(n=>window.__LTS_V312_CARD_REVIEW?.state.data?.row_count===n,before.row_count);
  await frame.evaluate(()=>{V='Atualizações';renderNav();render();});
  const panel=frame.locator('#v312CardReview');await panel.waitFor();
  async function search(q){const input=panel.locator('[name=card-query]');await input.fill(q);await input.press('Enter');await frame.waitForFunction(q=>!window.__LTS_V312_CARD_REVIEW.state.loading&&window.__LTS_V312_CARD_REVIEW.state.query===q,q);}
  for(const name of ['Aquario de teste','Brigaderia de teste','Grupo de teste','Astor de teste']){
   await search(name);assert.equal(await panel.locator('.lts-card-review-row').count(),1);
   await panel.getByRole('button',{name:'Revisar',exact:true}).click();
   const d=frame.locator('#v312CardDialog');assert.equal(await d.locator('[name=category]').inputValue(),'');
   assert.equal(await d.locator('[name=beneficiary]').inputValue(),'');
   const why=d.locator('details').filter({hasText:'Por que sugerimos'});await why.locator('summary').click();assert.match(await why.innerText(),/informações desta compra divergem/);
   await d.locator('[data-v312-close]').click();
  }
  await search('Medicamentos de teste');assert.equal(await panel.locator('.lts-card-review-row').count(),1);
  assert.doesNotMatch(await panel.innerText(),/Sugestão:.*Educação/);await panel.getByRole('button',{name:'Revisar',exact:true}).click();
  let dialog=frame.locator('#v312CardDialog');assert.equal(await dialog.locator('[name=category]').inputValue(),'');assert.equal(await dialog.locator('[name=beneficiary]').inputValue(),'');
  const reason=dialog.locator('details').filter({hasText:'Por que sugerimos'});assert.equal(await reason.getAttribute('open'),null);await reason.locator('summary').click();assert.match(await reason.innerText(),/informações desta compra divergem/);
  await dialog.locator('[data-v312-close]').click();
  updated=true;await frame.evaluate(()=>window.__LTS_V312_CARD_REVIEW.refresh());await frame.waitForFunction(n=>window.__LTS_V312_CARD_REVIEW.state.data?.row_count===n,after.row_count);
  await search('PETZ UNIDADE TESTE');assert.equal(await panel.locator('.lts-card-review-row').count(),1);
  await panel.getByRole('button',{name:'Revisar',exact:true}).click();const pet=frame.locator('#v312CardDialog');assert.equal(await pet.locator('[name=category]').inputValue(),'Cuidados com animais');assert.equal(await pet.locator('[name=beneficiary]').inputValue(),'');await pet.locator('[data-v312-close]').click();
  await search('RAIA9001');assert.equal(await panel.locator('.lts-card-review-row').count(),1,'Only the later source without full evidence remains');
  await panel.getByRole('button',{name:'Revisar',exact:true}).click();dialog=frame.locator('#v312CardDialog');assert.equal(await dialog.locator('[name=category]').inputValue(),'Farmácia');assert.equal(await dialog.locator('[name=beneficiary]').inputValue(),'');await dialog.locator('[data-v312-close]').click();
  await page.screenshot({path:path.join(qa,label+'-review.png')});
  for(const view of ['Dashboard','Fluxo Diário','Despesas','Patrimônio','Atualizações']){
   await frame.evaluate(v=>{V=v;renderNav();render();},view);await page.waitForTimeout(150);
   const size=await frame.locator('html').evaluate(el=>({width:el.clientWidth,scroll:el.scrollWidth}));assert(size.scroll<=size.width+2,view+' overflow');
   if(view==='Dashboard'||view==='Fluxo Diário')assert.match(await frame.locator('body').innerText(),/saldo|patrimônio|fluxo|despesas/i);
  }
  assert.doesNotMatch(await panel.innerText(),/raw_payload|source_ref|bank_activity_conflict|provider_category/);
  await Promise.all(reads);assert.deepEqual(errors,[]);assert.deepEqual(blocked,[]);
  return{passed:true,label,viewport,real_assets_verified:assets.size,engine:'postgresql17 synthetic payload',production_session:false};
 }catch(e){await page.screenshot({path:path.join(qa,label+'-failure.png')});throw e;}finally{await context.close();}
}
(async()=>{const browser=await chromium.launch({headless:true});try{const results=[];for(const [viewport,label]of [[{width:1440,height:1000},'desktop'],[{width:390,height:844},'mobile-390'],[{width:360,height:800},'mobile-360']])results.push(await run(browser,viewport,label));fs.writeFileSync(path.join(qa,'browser-result.json'),JSON.stringify({passed:true,results}));console.log(JSON.stringify({passed:true,results}));}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
