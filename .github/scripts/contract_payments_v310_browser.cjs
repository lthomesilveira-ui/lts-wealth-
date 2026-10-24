'use strict';
// The changed contract payload comes from real PostgreSQL with synthetic records.
const {chromium}=require('playwright'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const fixture=require('./lts_v309_fixtures.cjs'),qa=path.resolve('qa/v310'),native=JSON.parse(fs.readFileSync(path.join(qa,'native-wealth.json')));
const BASE='http://127.0.0.1:8788',root=path.resolve('releases/v309'),manifest=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'))),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const session={access_token:'synthetic-only-access',refresh_token:'synthetic-only-refresh',expires_at:4102444800,user:{id:'00000000-0000-4000-8000-000000000001',email:'viewer@example.invalid'}};
async function run(browser,viewport,label){
 const context=await browser.newContext({viewport,isMobile:viewport.width<600,hasTouch:viewport.width<600,serviceWorkers:'block'});
 await context.addInitScript(session=>{localStorage.setItem('lts_supabase_session_v1',JSON.stringify(session));sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));},session);
 const page=await context.newPage();page.setDefaultTimeout(30000);const errors=[],blocked=[],assets=new Set(),reads=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('response',r=>{const u=new URL(r.url()),name=path.basename(u.pathname);if(u.origin===BASE&&u.pathname.startsWith('/releases/v309/')&&manifest.files[name])reads.push(r.body().then(bytes=>{assert.equal(r.status(),200);assert.equal(hash(bytes),manifest.files[name]);assets.add(name);}));});
 await context.route('**/*',async route=>{
  const req=route.request(),u=new URL(req.url());if(u.origin===BASE)return route.continue();
  if(u.origin!=='https://tadhkamnwtsbdozwkyut.supabase.co'){blocked.push(u.origin+u.pathname);return route.abort();}
  const name=u.pathname.split('/').pop(),args=JSON.parse(req.postData()||'{}'),send=data=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(data)});
  if(u.pathname==='/auth/v1/token')return send(session);
  if(name==='lts_browser_product_v1')return send({ok:true,mvp:fixture.product()});
  if(/^lts_browser_wealth_detail_/.test(name)){const data=fixture.contracts(fixture.response(name,args));data.financing=native.financing;data.commitments=native.commitments;data.documentary_commitments=native.documentary_commitments;return send(data);}
  if(/_save_|_create_|_mutate_|_delete_|_confirm_|_classify_/.test(name)){blocked.push(name);return route.abort();}
  if(name==='lts_browser_open_finance_status_v1')return send({connections:[],last_syncs:[]});
  if(name==='lts_browser_future_bank_v293')return send({rows:[],card_future_received:0});
  if(name==='lts_browser_income_review_queue_v296')return send({row_count:0,matched_count:0,offset:0,next_offset:null,rows:[]});
  if(/recurring_future_gap/.test(name))return send(fixture.recurring());
  return send(fixture.response(name,args));
 });
 try{
  await page.goto(BASE+'/releases/v309/app.html',{waitUntil:'domcontentloaded'});
  let frame;for(let n=0;n<200;n++){frame=page.frames().find(f=>f.url().includes('/releases/v309/index.html'));if(frame)break;await page.waitForTimeout(50);}assert(frame);
  await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='ready'&&window.__LTS_V168_STATE);
  await frame.locator(viewport.width<820?'[data-mobile-route="Patrimônio"]':'[data-v="Patrimônio"]').first().click();
  await frame.getByRole('tab',{name:'Bens e dívidas',exact:true}).click();
  const vehicle=frame.locator('[data-v309-contract="volvo"]');await vehicle.waitFor();
  assert.match(await vehicle.innerText(),/Pagas comprovadas\s*1/);
  assert.match(await vehicle.innerText(),/Previstas\s*1/);
  assert.match(await vehicle.locator('[data-v309-unconfirmed]').innerText(),/1 parcela/);
  await vehicle.locator('[data-v168-loan]').click();
  const dialog=frame.getByRole('dialog'),payments=dialog.locator('[data-v309-payments]'),schedule=dialog.locator('[data-v309-schedule]');
  assert.equal(await payments.locator('tbody tr').count(),1);
  assert.match(await payments.locator('tbody tr').innerText(),/05\/10\/2020.*25,00.*06\/10\/2020.*25,00/);
  assert.equal(await schedule.locator('tbody tr').filter({hasText:'Pagamento a confirmar'}).count(),1);
  assert.equal(await schedule.locator('tbody tr').filter({hasText:'05/10/2020'}).count(),0,'Paid nominal installment must leave the unpaid list');
  if(viewport.width<600){const pan=await payments.evaluate(el=>{el.scrollLeft=el.scrollWidth;return{max:el.scrollWidth-el.clientWidth,actual:el.scrollLeft};});if(pan.max>1)assert(pan.actual>0,'Payment values must be reachable by horizontal scrolling');}
  await page.screenshot({path:path.join(qa,label+'-contract-payment.png')});
  await dialog.getByRole('button',{name:'Fechar',exact:true}).click();
  assert.equal(await frame.locator('[data-v309-contract="volvo"]').count(),1);
  const dims=await frame.locator('html').evaluate(el=>({width:el.clientWidth,scroll:el.scrollWidth}));assert(dims.scroll<=dims.width+2);
  await Promise.all(reads);assert.deepEqual(errors,[]);assert.deepEqual(blocked,[]);
  return{pass:true,label,viewport,real_assets_verified:assets.size,fixture_engine:process.env.LTS_V310_FIXTURE_ENGINE||'unspecified',native_postgresql_fixture:process.env.LTS_V310_FIXTURE_ENGINE==='postgresql17',production_session:false};
 }catch(error){await page.screenshot({path:path.join(qa,label+'-failure.png')});console.error({label,errors,blocked});throw error;}finally{await context.close();}
}
(async()=>{const browser=await chromium.launch({headless:true});try{const results=[];for(const [viewport,label]of [[{width:1440,height:1000},'desktop'],[{width:390,height:844},'mobile-390'],[{width:360,height:800},'mobile-360']])results.push(await run(browser,viewport,label));const result={pass:true,results};fs.writeFileSync(path.join(qa,'browser-results.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));}finally{await browser.close();}})().catch(error=>{console.error(error);process.exitCode=1;});
