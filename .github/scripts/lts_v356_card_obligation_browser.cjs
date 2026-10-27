'use strict';
// Real V353 UI with native-PostgreSQL-produced synthetic card projections.
const {chromium}=require('playwright'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const fixtures=require('./lts_v309_fixtures.cjs'),base=process.env.LTS_TEST_BASE||'http://127.0.0.1:8788',out=path.resolve('qa/v356');
const packet=JSON.parse(fs.readFileSync(path.join(out,'native-card-projection.json')));assert(packet.pass&&packet.version===355);
const session={access_token:'synthetic-only-access',refresh_token:'synthetic-only-refresh',expires_at:4102444800,user:{id:'00000000-0000-4000-8000-000000000001',email:'viewer@example.invalid'}};
async function run(browser,viewport,label){
 const ctx=await browser.newContext({viewport,isMobile:viewport.width<600,hasTouch:viewport.width<600,serviceWorkers:'block'});
 await ctx.addInitScript(s=>{const NativeDate=Date;window.__qaCardNow='2026-10-26T22:00:00Z';window.Date=class extends NativeDate{constructor(...a){super(...(a.length?a:[window.__qaCardNow]));}static now(){return NativeDate.parse(window.__qaCardNow);}};localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s));sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));},session);
 const page=await ctx.newPage();page.setDefaultTimeout(25000);const errors=[],writes=[],detailCalls=[];let mode='october';
 page.on('pageerror',e=>errors.push(String(e)));
 const projection=()=>structuredClone(mode==='paid'?packet.synthetic_after_payment_projection:mode==='zero'?packet.synthetic_zero_projection:mode==='credit'?packet.synthetic_credit_projection:mode==='partial'?packet.synthetic_partial_projection:mode==='november'?packet.synthetic_rollover_projection:packet.synthetic_projection);
 const cards=()=>{const c=structuredClone(packet.synthetic_cards);c.active_billing_accounts=c.cards.length;if(mode==='paid')c.cards[1].cycles[0].settlement_confirmed=true;if(mode==='zero')c.cards[1].cycles[0].amount=0;if(mode==='credit')c.cards[1].cycles[0].amount=-25;if(mode==='partial')c.cards[1].cycles[0].payment_status='partial';return c;};
 await ctx.route('**/*',async route=>{
  const req=route.request(),url=new URL(req.url());if(url.origin===new URL(base).origin)return route.continue();
  if(url.origin!=='https://tadhkamnwtsbdozwkyut.supabase.co')return route.abort();
  const name=url.pathname.split('/').pop(),args=JSON.parse(req.postData()||'{}'),send=x=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(x)});
  if(url.pathname==='/auth/v1/token')return send(session);if(url.pathname==='/auth/v1/logout')return send({});
  if(name==='lts_browser_product_v1'){const p=fixtures.product();p.card_operating={...p.card_operating,...projection()};p.dashboard_cockpit={...p.dashboard_cockpit,cards:projection()};return send({ok:true,mvp:p});}
  if(name==='lts_browser_dashboard_cockpit_v1')return send({...fixtures.response(name,args),cards:projection()});
  if(name==='lts_browser_card_cycles_v229')return send(cards());
  if(name==='lts_browser_card_detail_v226'){
   detailCalls.push(args);const c=cards().cards.find(x=>x.family===args.p_family),cycle=c?.cycles.find(x=>x.month===args.p_month);
   assert(cycle,'Exact requested canonical cycle exists');return send({family:c.family,month:cycle.month,card_name:c.name,amount:cycle.amount,invoice_amount:cycle.amount,detail_total:cycle.amount,basis:'open_finance_composition',complete:true,invoice_composition_complete:true,items:[{source_id:'synthetic-item',description:'Compra sintética do ciclo',amount:cycle.amount,category:'Alimentação',category_basis:'source',purchase_date:'2026-10-01',last4:'1234'}]});
  }
  if(/income_review_queue_|card_review_queue_|expense_review_queue_/.test(name))return send({ok:true,rows:[],row_count:0,offset:0,next_offset:null,category_options:[]});
  if(name==='lts_browser_open_finance_status_v1')return send({connections:[],last_syncs:[]});
  if(name==='lts_browser_future_bank_v293')return send({rows:[],card_future_received:0});
  if(/_decision_|_save_|_apply_|_delete_|_refresh_|_confirm_|_upload_|_mutate_|_classify_|_classification_|_create_|_update_/.test(name)){writes.push(name);return route.abort();}
  return send(fixtures.response(name,args));
 });
 try{
  await page.goto(base+'/releases/v356/app.html',{waitUntil:'domcontentloaded'});
  let frame;for(let i=0;i<200;i++){frame=page.frames().find(f=>f.url().includes('/releases/v356/index.html'));if(frame)break;await page.waitForTimeout(50);}assert(frame);
  await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='ready'&&window.__LTS_V226?.installed);
  const route=async(v,tab)=>{await frame.evaluate(({v,tab})=>{V=v;if(tab)window.__LTS_V168_STATE.expense.tab=tab;renderNav();render();},{v,tab});};
  const target=()=>frame.locator('.v226-upcoming [data-v226-family="aeternum"][data-v226-month="2026-10-01"]');
  const assertProjection=async()=>{
   const p=projection(),panel=frame.locator('.v226-upcoming');
   await panel.locator('[data-v356-next]').waitFor({state:'visible'});
   assert.equal(await panel.locator('[data-v356-next]').getAttribute('data-v356-next'),p.next_due.family+'|'+p.next_due.month);
   for(const t of p.targets){const first=panel.locator('.v226-card-line').filter({has:frame.locator('[data-v226-family="'+t.family+'"]')}).locator('[data-v226-family="'+t.family+'"]');assert(await first.count()>0);for(const m of await first.evaluateAll(es=>es.map(e=>e.dataset.v226Month)))assert.equal(m,t.month,'First rendered payable cycle matches native projection');}
   const values=await panel.locator('.v226-totals>div strong').allTextContents();const money=v=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(v).replace(/\s/g,' ');
   assert.equal(values[0].replace(/\s/g,' '),money(p.next_obligations_total));assert.equal(values[1].replace(/\s/g,' '),money(p.following_cycles_total));
   const box=await panel.locator('[data-v356-next]').evaluate(el=>({width:el.clientWidth,scroll:el.scrollWidth}));assert(box.scroll<=box.width+2,'Target fits mobile width');
  };
  await route('Dashboard');await target().first().waitFor({state:'visible'});await assertProjection();
  assert.deepEqual(await frame.evaluate(()=>window.__LTS_V226.cycles.cards[0].cycles),cards().cards[0].cycles,'Selection does not mutate received cycle order');
  await frame.locator('[data-v356-next]').scrollIntoViewIfNeeded();
  assert.equal(await frame.locator('.v226-upcoming [data-v226-family="c6"][data-v226-month="2026-10-01"]').count(),0);
  assert(await frame.locator('.v226-upcoming [data-v226-family="c6"][data-v226-month="2026-11-01"]').count()>0);
  await page.screenshot({path:path.join(out,label+'-dashboard-obligations.png')});
  await route('Despesas','cards');await target().first().waitFor({state:'visible'});await target().first().click();
  await frame.locator('#v226-detail').getByText('Compra sintética do ciclo',{exact:false}).waitFor({state:'visible'});assert(detailCalls.some(x=>x.p_family==='aeternum'&&x.p_month==='2026-10-01'));
  assert.match(await frame.locator('#v226-detail').innerText(),/Compra sintética do ciclo/);await frame.locator('#v226-detail [data-v226-close]').click();
  await assertProjection();await frame.locator('[data-v356-next]').scrollIntoViewIfNeeded();await page.screenshot({path:path.join(out,label+'-invoice-obligations.png')});
  await route('Fluxo Diário');await frame.waitForFunction(()=>!FLOWLOADING);
  await frame.evaluate(()=>openCardSettlement({source:'card_invoice',source_ref:'Visa Aeternum|2026-10',account:'Bradesco',event_date:'2026-10-25',signed_amount:-100}));
  await frame.locator('#v226-detail').getByText('Compra sintética do ciclo',{exact:false}).waitFor({state:'visible'});assert.match(await frame.locator('#v226-detail').innerText(),/Compra sintética do ciclo/);await frame.locator('#v226-detail [data-v226-close]').click();
  await page.screenshot({path:path.join(out,label+'-flow.png')});
  mode='november';for(const f of page.frames())await f.evaluate(()=>{window.__qaCardNow='2026-11-01T15:00:00Z';});
  await route('Despesas','cards');await frame.locator('.v226-upcoming [data-v226-retry]').click();await target().first().waitFor({state:'visible'});
  await frame.waitForFunction(()=>window.__LTS_V226.loadedDay==='2026-11-01'&&!window.__LTS_V226.loading);
  assert(await target().count()>0,'Unpaid October cycle survives November');await assertProjection();
  for(const current of ['zero','credit','partial']){
   mode=current;await frame.locator('.v226-upcoming [data-v226-retry]').click();await frame.waitForFunction(()=>!window.__LTS_V226.loading);await assertProjection();
   if(current!=='partial')assert.equal(await target().count(),0,'Zero and credit cycles are not payable targets');
   else {assert(await target().count()>0);assert.match(await frame.locator('[data-v356-next]').innerText(),/Saldo restante a confirmar/);assert.match(await frame.locator('[data-v356-next]').innerText(),/100,00/);await frame.locator('[data-v356-next]').scrollIntoViewIfNeeded();await page.screenshot({path:path.join(out,label+'-partial-obligation.png')});}
  }
  mode='paid';await frame.locator('.v226-upcoming [data-v226-retry]').click();await frame.waitForFunction(()=>!window.__LTS_V226.loading&&window.__LTS_V226.cycles?.cards?.[1]?.cycles?.[0]?.settlement_confirmed===true);
  assert.equal(await target().count(),0,'Only documentary settlement removes the payable target');await assertProjection();assert.equal(writes.length,0);assert.deepEqual(errors,[]);
  return {pass:true,label,native_projection_consumed:true,first_per_card_and_global_target_match:true,source_order_preserved:true,zero_and_credit_not_payable:true,partial_balance_not_invented:true,paid_cycle_excluded:true,unpaid_cycle_survives_rollover:true,exact_flow_composition:true,no_financial_writes:true,synthetic_session:true,private_http:false,physical_device:false};
 }finally{await ctx.close();}
}
(async()=>{const browser=await chromium.launch({headless:true});try{const results=[];for(const [label,viewport]of [['desktop',{width:1440,height:1000}],['mobile-390',{width:390,height:844}],['mobile-360',{width:360,height:800}]])results.push(await run(browser,viewport,label));fs.writeFileSync(path.join(out,'card-obligation-browser-results.json'),JSON.stringify(results));console.log(JSON.stringify(results));}finally{await browser.close();}})().catch(e=>{console.error(e);process.exit(1);});
