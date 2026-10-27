'use strict';
// Local fixture app only; this does not certify an owner's HTTP session.
const {chromium}=require('playwright'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const fixture=require('./lts_v309_fixtures.cjs'),base='http://127.0.0.1:8788',out=path.resolve('qa/v352');fs.mkdirSync(out,{recursive:true});
const session={access_token:'synthetic-only-access',refresh_token:'synthetic-only-refresh',expires_at:4102444800,user:{id:'00000000-0000-4000-8000-000000000001',email:'viewer@example.invalid'}};
const reference={institution:'Morgan Stanley',received_on:'2026-10-26',position_as_of:null,status:'documentary_reference_pending_reconciliation',total_gross_brl:1000,available_total_brl:.03,unavailable_total_brl:999.97,source_file:'Synthetic <img src=x onerror=unsafe()>.png',source_sha256:'a'.repeat(64),metadata:{quantities:{regular_rsu_total:34,regular_rsu_available:0,cash_rsu_total:8,cash_rsu_available:0},available_components:{long_share_holdings_brl:.02},unavailable_components:{regular_rsu_brl:null,cash_rsu_brl:null},quote:{share_price_usd:1.01,usd_brl:5.123456}},included_in_current_liquidity:false};
function wealth(){
 const j=fixture.contracts(structuredClone(fixture.response('lts_browser_wealth_detail_v242')));
 j.morgan_statement={as_of:'2020-10-01',gross_total_brl:103,available_total_brl:3,available_components:{vested_shares_brl:0,brokerage_cash_brl:3},future_components:{regular_rsu_gross_brl:60,cash_rsu_gross_brl:40,cash_rsu_after_reserve_brl:28,future_after_reserve_brl:88},quantities:{},planning_schedule_reconciliation:{}};
 j.current_awards={as_of:'2020-10-01',vested_shares:0,brokerage_cash:3};j.current_liquidity.brokerage_available=3;
 j.rsu_summary={as_of:'2020-10-01',available_total_brl:3,future_regular_brl:60,future_cash_net_brl:28,future_considered_total_brl:88};
 j.wealth.assets={cipo_396:{market_central:2000,documentary_debt:900,equity_central:1100},volvo_xc40:{market_central:500,documented_financed_balance:100}};
 j.brokerage_reference=reference;return j;
}
async function run(browser,viewport,label){
 const ctx=await browser.newContext({viewport,isMobile:viewport.width<600,hasTouch:viewport.width<600,serviceWorkers:'block'});
 await ctx.addInitScript(s=>{const NativeDate=Date;window.Date=class extends NativeDate{constructor(...a){super(...(a.length?a:['2026-10-26T22:00:00Z']));}static now(){return NativeDate.parse('2026-10-26T22:00:00Z');}};localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s));sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));},session);
 const page=await ctx.newPage();page.setDefaultTimeout(25000);const errors=[],writes=[];page.on('pageerror',e=>errors.push(String(e)));
 await ctx.route('**/*',async route=>{
  const req=route.request(),url=new URL(req.url());if(url.origin===new URL(base).origin)return route.continue();
  if(url.origin!=='https://tadhkamnwtsbdozwkyut.supabase.co')return route.abort();
  const n=url.pathname.split('/').pop(),args=JSON.parse(req.postData()||'{}'),send=j=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(j)});
  if(url.pathname==='/auth/v1/token')return send(session);if(url.pathname==='/auth/v1/logout')return send({});
  if(n==='lts_browser_product_v1')return send({ok:true,mvp:fixture.product()});
  if(/^lts_browser_wealth_detail_/.test(n))return send(wealth());
  if(/income_review_queue_|card_review_queue_|expense_review_queue_/.test(n))return send({ok:true,rows:[],row_count:0,offset:0,next_offset:null,category_options:[]});
  if(n==='lts_browser_open_finance_status_v1')return send({connections:[],last_syncs:[]});
  if(n==='lts_browser_future_bank_v293')return send({rows:[],card_future_received:0});
  if(/_decision_|_save_|_apply_|_delete_|_refresh_|_confirm_|_upload_|_mutate_|_classify_|_classification_|_create_|_update_/.test(n)){writes.push(n);return route.abort();}
  return send(fixture.response(n,args));
 });
 try{
  await page.goto(base+'/releases/v352/app.html',{waitUntil:'domcontentloaded'});
  const frame=page.frames().find(f=>f.url().includes('/releases/v352/index.html'))||await page.waitForEvent('framenavigated',{predicate:f=>f.url().includes('/releases/v352/index.html')});assert(frame);
  await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='ready'&&window.__LTS_V183_WEALTH_INTEGRITY?.installed);
  const paint=async(tab,data=wealth())=>frame.evaluate(({tab,data})=>{window.__LTS_V168_STATE.wealth.data=data;window.__LTS_V168_STATE.wealth.tab=tab;V='Patrimônio';render();},{tab,data});
  await paint('rsu');const card=frame.locator('.v352-brokerage-reference');assert.equal(await card.count(),1);
  const text=await card.innerText();for(const v of ['26/10/2026','não mostra a data','1.000,00','0,03','999,97','pendente'])assert(text.includes(v),v);
  assert.equal(await card.locator('details[open]').count(),0);assert(!text.includes('SHA256'));assert((await card.boundingBox()).height<440,'Collapsed reference is compact');
  await card.locator('summary').click();const detail=await card.innerText();for(const v of ['34','8','0,01','QUANTIDADE','SHA256','Synthetic <img'])assert(detail.includes(v),v);
  assert.equal(await card.locator('img').count(),0);assert.equal(await frame.evaluate(()=>typeof unsafe),'undefined');
  const finance=await frame.evaluate(()=>({available:window.__LTS_V168_STATE.wealth.data.current_liquidity.brokerage_available,dated:window.__LTS_V168_STATE.wealth.data.morgan_statement.as_of}));assert.deepEqual(finance,{available:3,dated:'2020-10-01'});
  assert(await frame.locator('.v172-morgan').innerText().then(t=>t.includes('3,00')));
  await page.screenshot({path:path.join(out,label+'-reference.png')});
  await paint('assets');const property=frame.locator('.v168-asset').filter({has:frame.locator('h3',{hasText:'CIPÓ 396'})});
  assert.match(await property.innerText(),/Pagamentos de aquisição no Excel histórico/);assert.match(await property.innerText(),/02\/09\/2020/);assert(!/Compra paga/.test(await property.innerText()));
  const width=await frame.evaluate(()=>({screen:innerWidth,scroll:document.documentElement.scrollWidth}));assert(width.scroll<=width.screen+2,'No horizontal document overflow');
  await page.screenshot({path:path.join(out,label+'-property.png')});
  const next=wealth();delete next.brokerage_reference;await paint('rsu',next);assert.equal(await card.count(),0,'Another owner or missing reference cannot retain the previous card');
  for(const route of ['Dashboard','Fluxo Diário']){
   await frame.evaluate(v=>{V=v;render();},route);assert.equal(await card.count(),0);const body=await frame.locator('body').innerText();assert(body.includes(route==='Dashboard'?'Dashboard':'Fluxo'),'Route rendered');assert(!body.includes('SHA256'),'Source detail cannot leak into other routes');
  }
  assert.deepEqual(errors,[]);assert.deepEqual(writes,[]);
  return{pass:true,label,viewport,unknown_position_date_visible:true,origin_collapsed:true,prior_dated_available_preserved:true,acquisition_label_correct:true,no_financial_writes:true,synthetic_session:true,private_http:false,physical_device:false};
 }catch(e){await page.screenshot({path:path.join(out,label+'-failure.png')});console.error({errors,writes});throw e;}finally{await ctx.close();}
}
(async()=>{const b=await chromium.launch({headless:true});try{const r=[];for(const[v,l]of[[{width:1440,height:1000},'desktop'],[{width:390,height:844},'mobile-390'],[{width:360,height:800},'mobile-360']])r.push(await run(b,v,l));fs.writeFileSync(path.join(out,'brokerage-browser-results.json'),JSON.stringify(r,null,2));console.log(JSON.stringify(r));}finally{await b.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
