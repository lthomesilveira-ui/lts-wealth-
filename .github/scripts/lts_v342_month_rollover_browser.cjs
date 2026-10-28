'use strict';
// Real immutable release, browser controls and a synthetic clock/data source.
const {chromium}=require('playwright'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const release=process.env.LTS_RELEASE||'v342',expectStale=process.env.LTS_EXPECT_STALE_MONTH==='true';assert(['v341','v342','v344','v346','v352','v353','v356','v359','v365','v368','v371'].includes(release));
const fixture=require('./lts_v309_fixtures.cjs'),base='http://127.0.0.1:8788',out=path.resolve('qa/'+release);fs.mkdirSync(out,{recursive:true});
const session={access_token:'synthetic-only-access',refresh_token:'synthetic-only-refresh',expires_at:4102444800,user:{id:'00000000-0000-4000-8000-000000000001',email:'viewer@example.invalid'}};
async function run(browser,viewport,label){
 const context=await browser.newContext({viewport,isMobile:viewport.width<600,hasTouch:viewport.width<600,serviceWorkers:'block'});
 await context.addInitScript(session=>{const NativeDate=Date;window.__syntheticMonthClock=NativeDate.parse('2026-10-31T23:59:00Z');window.Date=class extends NativeDate{constructor(...args){super(...(args.length?args:[window.__syntheticMonthClock]));}static now(){return window.__syntheticMonthClock;}};localStorage.setItem('lts_supabase_session_v1',JSON.stringify(session));sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));},session);
 const page=await context.newPage();page.setDefaultTimeout(30000);const errors=[],writes=[],blocked=[],monthly=[];let held=false,releaseHeld,reportHeld;
 const gate=new Promise(resolve=>releaseHeld=resolve),started=new Promise(resolve=>reportHeld=resolve);
 page.on('pageerror',e=>errors.push(String(e)));
 await context.route('**/*',async route=>{
  const req=route.request(),u=new URL(req.url());if(u.origin===base)return route.continue();
  if(u.origin!=='https://tadhkamnwtsbdozwkyut.supabase.co'){blocked.push(u.origin+u.pathname);return route.abort();}
  const name=u.pathname.split('/').pop(),args=JSON.parse(req.postData()||'{}'),send=data=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(data)});
  if(u.pathname==='/auth/v1/token')return send(session);
  if(name==='lts_browser_product_v1')return send({ok:true,mvp:fixture.product()});
  if(name==='lts_browser_monthly_v229'){
   monthly.push({...args});const month=args.p_from.slice(0,7),revenue=held?777:month==='2026-11'?211:111,expenses=10;
   const row={month:month+'-01',revenue,extraordinary:0,expenses,cash_after_extraordinary:revenue-expenses};
   const response={window_integrity:{from:args.p_from,to:args.p_to},monthly_totals:[row],totals:{...row}};
   if(held){held=false;reportHeld();await gate;}return send(response);
  }
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
  const ready=month=>frame.waitForFunction(month=>window.__LTS_V337_MONTH?.state.status==='ready'&&window.__LTS_V337_MONTH.state.data?.month===month,month);
  const overview=frame.locator('#v337Overview'),choice=()=>overview.getByLabel('Mês do resumo');
  const changeDay=async date=>{const time=Date.parse(date);for(const f of page.frames())await f.evaluate(time=>window.__syntheticMonthClock=time,time);await frame.evaluate(()=>window.__LTS_V227_TRANSPORT.invalidate());};
  await ready('2026-10');assert.equal(await choice().inputValue(),'2026-10');
  await changeDay('2026-11-01T00:01:00Z');await ready('2026-10');assert.match(await overview.locator('.v337-period').innerText(),/31\/10\/2026/);
  await changeDay('2026-11-01T03:01:00Z');await ready(expectStale?'2026-10':'2026-11');
  if(expectStale){
   assert.equal(await choice().inputValue(),'2026-10');assert(monthly.some(x=>x.p_from==='2026-10-01'&&x.p_to==='2026-10-31'));assert(!monthly.some(x=>x.p_from==='2026-11-01'));
   await overview.evaluate(el=>el.scrollIntoView({block:'center'}));await page.screenshot({path:path.join(out,'v341-month-rollover-reproduced.png')});
   return {pass:true,release,label,old_month_reproduced:true,expected_default_month:'2026-11',observed_month:'2026-10',business_timezone:'America/Sao_Paulo'};
  }
  assert.equal(await choice().inputValue(),'2026-11');assert.match(await overview.locator('.v337-period').innerText(),/01\/11\/2026 a 01\/11\/2026/);assert.match(await overview.locator('.v337-metric').first().innerText(),/211,00/);
  await overview.evaluate(el=>el.scrollIntoView({block:'center'}));await page.screenshot({path:path.join(out,label+'-new-month.png')});
  await choice().fill('2026-09');await ready('2026-09');await changeDay('2026-12-01T03:01:00Z');await ready('2026-09');assert.equal(await choice().inputValue(),'2026-09');assert.match(await overview.locator('.v337-period').innerText(),/30\/09\/2026/);
  await choice().fill('2026-12');await ready('2026-12');await changeDay('2027-01-01T03:01:00Z');await ready('2027-01');assert.equal(await choice().inputValue(),'2027-01');
  await frame.evaluate(()=>{window.__syntheticStaleMonthPainted=false;new MutationObserver(()=>{if(document.querySelector('#v337Overview .v337-metrics')?.textContent.includes('777,00'))window.__syntheticStaleMonthPainted=true;}).observe(document.body,{subtree:true,childList:true,characterData:true});});
  held=true;await frame.evaluate(()=>window.__LTS_V227_TRANSPORT.invalidate());
  let startTimer;try{await Promise.race([started,new Promise((_,reject)=>{startTimer=setTimeout(()=>reject(Error('Held monthly request was not observed')),10000);})]);}finally{clearTimeout(startTimer);}
  await changeDay('2027-02-01T03:01:00Z');await choice().waitFor();assert.equal(await choice().inputValue(),'2027-02');releaseHeld();await ready('2027-02');
  assert.equal(await frame.evaluate(()=>window.__syntheticStaleMonthPainted),false);assert.doesNotMatch(await overview.innerText(),/777,00/);
  const size=await overview.evaluate(e=>({width:e.clientWidth,scroll:e.scrollWidth}));assert(size.scroll<=size.width+2);
  for(const detail of await overview.locator('details').all())assert.equal(await detail.getAttribute('open'),null);
  assert.doesNotMatch(await overview.innerText(),/private SQL|source_ref|RPC|backend/);
  assert.deepEqual(errors,[]);assert.deepEqual(writes,[]);assert.deepEqual(blocked,[]);
  return {pass:true,release,label,viewport,default_follows_local_month:true,utc_midnight_preserved:true,historical_choice_preserved:true,current_choice_resumes_following:true,year_boundary:true,late_response_rejected:true,compact_sources_closed:true,no_global_overflow:true,synthetic_http:true,production_session:false,physical_device:false};
 }catch(e){await page.screenshot({path:path.join(out,label+'-rollover-failure.png')});console.error({label,errors,writes,blocked,monthly});throw e;}finally{releaseHeld();await context.close();}
}
(async()=>{const browser=await chromium.launch({headless:true});try{const results=[];const cases=expectStale?[[{width:1440,height:1000},'desktop']]:[[{width:1440,height:1000},'desktop'],[{width:390,height:844},'mobile-390'],[{width:360,height:800},'mobile-360']];for(const [viewport,label]of cases)results.push(await run(browser,viewport,label));fs.writeFileSync(path.join(out,expectStale?'v341-month-rollover-reproduction.json':'month-rollover-results.json'),JSON.stringify({pass:true,results},null,2));console.log(JSON.stringify({pass:true,results}));}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
