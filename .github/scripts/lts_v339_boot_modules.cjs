'use strict';
// Isolated fault injection into an actual immutable release. No production calls.
const {chromium}=require('playwright'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const fixture=require('./lts_v309_fixtures.cjs'),release=process.env.LTS_RELEASE||'v337',complete=process.env.LTS_EXPECT_COMPLETE==='true',delay=45000;
assert(['v337','v339'].includes(release));
const base='http://127.0.0.1:8788',out=path.resolve('qa/v339');fs.mkdirSync(out,{recursive:true});
const session={access_token:'synthetic-only-access',refresh_token:'synthetic-only-refresh',expires_at:4102444800,user:{id:'00000000-0000-4000-8000-000000000001',email:'viewer@example.invalid'}};
const flags=['__LTS_V178_REVIEW','__LTS_V178_REVIEW_ACTIONS','__LTS_V181_REGRESSION_CLOSURE','__LTS_V182_FEEDBACK','__LTS_V183_INCOME_REVIEW','__LTS_V183_SEARCH_COMPLETE','__LTS_V183_EXACT_FLOW_NAVIGATION','__LTS_V183_FLOW_PERIOD_STATE','__LTS_V183_WEALTH_INTEGRITY','__LTS_V225','__LTS_V226','__LTS_V257_UI_STATE','__LTS_V290_SOURCES','__LTS_V296_CLASSIFICATIONS','__LTS_V308_REVIEW_LAYOUT','__LTS_V312_CARD_REVIEW','__LTS_V337_MONTH'];
async function run(browser,viewport,label){
 const context=await browser.newContext({viewport,serviceWorkers:'block'}),page=await context.newPage();page.setDefaultTimeout(20000);
 await context.addInitScript(({session,delay})=>{
  const NativeDate=Date;window.Date=class extends NativeDate{constructor(...args){super(...(args.length?args:['2026-10-16T22:00:00Z']));}static now(){return NativeDate.parse('2026-10-16T22:00:00Z');}};
  localStorage.setItem('lts_supabase_session_v1',JSON.stringify(session));sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));
  const append=Node.prototype.appendChild;let held=false;
  Node.prototype.appendChild=function(node){
   if(!held&&node.tagName==='SCRIPT'&&node.id==='v178-runtime'){
    held=true;const host=this,doc=host.ownerDocument,view=doc.defaultView;view.__v339DelayHeld=true;const placeholder=doc.createElement('script');placeholder.id=node.id;placeholder.type='application/x-lts-synthetic-delay';append.call(host,placeholder);
    setTimeout(()=>{placeholder.remove();append.call(host,node);view.__v339DelayReleased=true;},delay);
    return node;
   }
   return append.call(this,node);
  };
 },{session,delay});
 const errors=[],writes=[],blocked=[],calls=[];
 page.on('pageerror',e=>errors.push(String(e)));
 await context.route('**/*',async route=>{
  const req=route.request(),url=new URL(req.url());if(url.origin===base)return route.continue();
  if(url.origin!=='https://tadhkamnwtsbdozwkyut.supabase.co'){blocked.push(url.origin);return route.abort();}
  const name=url.pathname.split('/').pop(),args=JSON.parse(req.postData()||'{}'),send=data=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(data)});calls.push(name);
  if(url.pathname==='/auth/v1/token')return send(session);
  if(name==='lts_browser_product_v1')return send({ok:true,mvp:fixture.product()});
  if(/_decision_|_save_|_apply_|_delete_|_refresh_|_confirm_|_upload_|_mutate_|_classify_|_classification_|_create_|_update_/.test(name)){writes.push(name);return route.abort();}
  if(name==='lts_browser_monthly_v229')return send(fixture.monthly(args.p_from,args.p_to));
  if(name==='lts_browser_cash_today_v242')return send({...fixture.response(name,args),bank_positions:[{institution_code:'341',balance:600},{institution_code:'237',balance:400},{institution_code:'336',balance:0}]});
  if(name==='lts_browser_income_review_queue_v296'||name==='lts_browser_card_review_queue_v312'||name==='lts_browser_expense_review_queue_v229')return send({ok:true,row_count:0,matched_count:0,additional_count:0,offset:0,next_offset:null,rows:[],category_options:['Farmácia']});
  if(name==='lts_browser_open_finance_status_v1')return send({connections:[],last_syncs:[]});
  if(name==='lts_browser_future_bank_v293')return send({rows:[],card_future_received:0});
  return send(fixture.response(name,args));
 });
 let frame;
 try{
  await page.goto(base+'/releases/'+release+'/app.html',{waitUntil:'domcontentloaded'});
  frame=page.frames().find(f=>f.url().includes('/releases/'+release+'/index.html'));assert(frame);
  await frame.waitForFunction(()=>window.__v339DelayHeld);
  await frame.waitForFunction(()=>window.__v339DelayReleased,{},{timeout:60000});
  if(complete)await frame.waitForFunction(flags=>flags.every(k=>window[k]?.installed),flags);
  else await page.waitForTimeout(2500);
  const installed=await frame.evaluate(flags=>Object.fromEntries(flags.map(k=>[k,window[k]?.installed===true])),flags),missing=Object.keys(installed).filter(k=>!installed[k]);
  assert(installed.__LTS_V178_REVIEW,'The actual delayed runtime eventually installed');
  if(complete){
   assert.deepEqual(missing,[],'Every late consumer recovers without a reload');
   await frame.waitForFunction(()=>window.__LTS_V337_MONTH.state.status==='ready'&&window.__LTS_V178_REVIEW.cashComplete(window.__LTS_V178_STATE.cash));
   assert.equal(await frame.locator('#v337Overview .v337-bank:not(.total)').count(),3);
   assert.deepEqual((await frame.locator('#v337Overview .v337-metric strong').allTextContents()).map(x=>x.replace(/[^0-9,-]/g,'')),['150,00','100,00','50,00']);
   assert.match(await frame.locator('.v168-dashboard .v168-kpi').filter({hasText:'Total disponível hoje'}).innerText(),/1\.500,00/);
   const size=await frame.locator('html').evaluate(x=>({w:x.clientWidth,s:x.scrollWidth}));assert(size.s<=size.w+2);
  }else{
   assert.equal(installed.__LTS_V178_REVIEW_ACTIONS,false,'Baseline expires while the prerequisite is held');
   assert.equal(installed.__LTS_V337_MONTH,false,'Baseline visibly lacks the monthly summary');
   assert.equal(await frame.locator('#v337Overview').count(),0);
  }
  await page.screenshot({path:path.join(out,label+'-'+release+'-late-component.png')});
  assert.deepEqual(errors,[]);assert.deepEqual(writes,[]);assert.deepEqual(blocked,[]);
  return{pass:true,release,label,viewport,synthetic_delay_ms:delay,real_release_modules:true,missing,production_session:false,physical_device:false,reload_count:0,financial_writes:0,product_reads:calls.filter(x=>x==='lts_browser_product_v1').length};
 }catch(error){console.error({label,release,errors,writes,blocked,state:await frame?.evaluate(()=>({boot:document.body.dataset.ltsBootState,held:!!window.__v339DelayHeld,released:!!window.__v339DelayReleased,scripts:[...document.querySelectorAll('script[id]')].map(x=>x.id)})).catch(()=>null)});await page.screenshot({path:path.join(out,label+'-'+release+'-failure.png')});throw error;}finally{await context.close();}
}
(async()=>{const browser=await chromium.launch({headless:true});try{const result=await run(browser,{width:1440,height:1000},'desktop');fs.writeFileSync(path.join(out,release+'-late-component.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
