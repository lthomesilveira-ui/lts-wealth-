'use strict';
// Consume native PostgreSQL output in the published V356 interface.
const {chromium}=require('playwright'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const fixture=require('./lts_v309_fixtures.cjs'),base='http://127.0.0.1:8788',out=path.resolve('qa/v357');
const packet=JSON.parse(fs.readFileSync(path.join(out,'native-debt-projection.json'))),native=packet.after_readers;
assert(packet.pass&&packet.version===357);
const session={access_token:'synthetic-only-access',refresh_token:'synthetic-only-refresh',expires_at:4102444800,user:{id:'00000000-0000-4000-8000-000000000001',email:'viewer@example.invalid'}};
function wealth(){
 const b=fixture.contracts(structuredClone(fixture.response('lts_browser_wealth_detail_v242'))),n=structuredClone(native.wealth);
 return {...b,...n,financing:{...b.financing,...n.financing},wealth:{...b.wealth,...n.wealth}};
}
async function run(browser,viewport,label){
 const ctx=await browser.newContext({viewport,isMobile:viewport.width<600,hasTouch:viewport.width<600,serviceWorkers:'block'});
 await ctx.addInitScript(s=>{const NativeDate=Date;window.Date=class extends NativeDate{constructor(...a){super(...(a.length?a:['2026-10-27T15:00:00Z']));}static now(){return NativeDate.parse('2026-10-27T15:00:00Z');}};localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s));sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));},session);
 const page=await ctx.newPage();page.setDefaultTimeout(25000);const errors=[],writes=[];page.on('pageerror',e=>errors.push(String(e)));
 await ctx.route('**/*',async route=>{
  const req=route.request(),url=new URL(req.url());if(url.origin===new URL(base).origin)return route.continue();
  if(url.origin!=='https://tadhkamnwtsbdozwkyut.supabase.co')return route.abort();
  const name=url.pathname.split('/').pop(),args=JSON.parse(req.postData()||'{}'),send=j=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(j)});
  if(url.pathname==='/auth/v1/token')return send(session);if(url.pathname==='/auth/v1/logout')return send({});
  if(name==='lts_browser_product_v1'){
   const p=fixture.product();p.wealth_executive=structuredClone(native.product.mvp.wealth_executive);
   p.dashboard_cockpit={...p.dashboard_cockpit,wealth:structuredClone(native.product.mvp.dashboard_cockpit.wealth)};
   return send({ok:true,mvp:p});
  }
  if(name==='lts_browser_dashboard_cockpit_v1')return send({...fixture.response(name,args),wealth:structuredClone(native.cockpit.wealth)});
  if(/^lts_browser_wealth_detail_/.test(name))return send(wealth());
  if(/income_review_queue_|card_review_queue_|expense_review_queue_/.test(name))return send({ok:true,rows:[],row_count:0,offset:0,next_offset:null,category_options:[]});
  if(name==='lts_browser_open_finance_status_v1')return send({connections:[],last_syncs:[]});
  if(name==='lts_browser_future_bank_v293')return send({rows:[],card_future_received:0});
  if(/_decision_|_save_|_apply_|_delete_|_refresh_|_confirm_|_upload_|_mutate_|_classify_|_classification_|_create_|_update_/.test(name)){writes.push(name);return route.abort();}
  return send(fixture.response(name,args));
 });
 try{
  await page.goto(base+'/releases/v356/app.html',{waitUntil:'domcontentloaded'});
  let frame;for(let i=0;i<200;i++){frame=page.frames().find(f=>f.url().includes('/releases/v356/index.html'));if(frame)break;await page.waitForTimeout(50);}assert(frame);
  await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='ready'&&window.__LTS_V183_WEALTH_INTEGRITY?.installed&&typeof D!=='undefined'&&D&&typeof N!=='undefined'&&!N.classList.contains('hidden'));
  await page.waitForLoadState('networkidle');
  const paint=async(tab)=>frame.evaluate(({tab,data})=>{window.__LTS_V168_STATE.wealth.data=data;window.__LTS_V168_STATE.wealth.tab=tab;V='Patrimônio';renderNav();render();},{tab,data:wealth()});
  await paint('overview');await frame.locator('.v172-debts').waitFor({state:'visible'});
  const kpis=frame.locator('.v168-wealth .v168-kpis .v168-kpi');
  assert.match(await kpis.nth(0).innerText(),/Patrimônio líquido em apuração/);
  assert.equal((await kpis.nth(0).locator('strong').innerText()).trim(),'—');
  assert.match(await kpis.nth(2).innerText(),/Dívidas com saldo documental/);
  assert.match(await kpis.nth(2).locator('strong').innerText(),/900,00/);
  const debts=frame.locator('.v172-debts');assert.match(await debts.innerText(),/02\/09\/2026/);
  assert.equal(await debts.getByText('Aguardando extrato',{exact:true}).count(),3);
  assert.equal(await frame.evaluate(()=>window.__LTS_V183_WEALTH_INTEGRITY.documented_count),1);
  assert.deepEqual(await frame.evaluate(()=>window.__LTS_V183_WEALTH_INTEGRITY.missing),['volvo','coopharma','pai_mae']);
  await page.screenshot({path:path.join(out,label+'-dated-debt-overview.png')});
  await paint('assets');const vehicle=frame.locator('.v168-asset').filter({has:frame.locator('h3',{hasText:'Volvo XC40'})});
  assert.match(await vehicle.innerText(),/Patrimônio líquido em apuração/);
  const initial=vehicle.locator('.v168-fact').filter({hasText:'Financiamento na contratação'});
  assert.equal(await initial.count(),1);assert.match(await initial.innerText(),/100,00/);
  assert.match(await vehicle.innerText(),/não é o saldo devedor de hoje/);
  const pos=await frame.evaluate(()=>window.__LTS_V168_STATE.wealth.data.wealth.assets.volvo_xc40);
  assert.equal(pos.equity_central,null);assert.equal(pos.documented_financed_balance,100);assert.equal(pos.future_schedule_total,580);
  await page.screenshot({path:path.join(out,label+'-vehicle-initial-reference.png')});
  for(const route of ['Dashboard','Fluxo Diário']){
   await frame.evaluate(v=>{V=v;renderNav();render();},route);
   if(route==='Dashboard')await frame.waitForFunction(()=>{const s=window.__LTS_V178_STATE;return s&&['cash','forecast','wealth','awards','dashboardReport'].every(k=>s[k]?.status==='ready');});
   else await frame.waitForFunction(()=>!FLOWLOADING);
   assert.match(await frame.locator('body').innerText(),route==='Dashboard'?/Dashboard/:/Fluxo/);
   assert(!/NaN|undefined|V357_/.test(await frame.locator('body').innerText()));
   await page.screenshot({path:path.join(out,label+'-'+(route==='Dashboard'?'dashboard':'flow')+'.png')});
  }
  const width=await frame.evaluate(()=>({screen:innerWidth,scroll:document.documentElement.scrollWidth}));assert(width.scroll<=width.screen+2);
  assert.deepEqual(errors,[]);assert.deepEqual(writes,[]);
  return{pass:true,label,native_projection_consumed:true,missing_debt_not_zero:true,initial_contract_and_schedule_preserved:true,dated_subtotal_visible:true,synthetic_session:true,private_http:false,physical_device:false};
 }catch(e){await page.screenshot({path:path.join(out,label+'-failure.png')});console.error({label,errors,writes});throw e;}finally{await ctx.close();}
}
(async()=>{const browser=await chromium.launch({headless:true});try{const r=[];for(const[label,v]of[['desktop',{width:1440,height:1000}],['mobile-390',{width:390,height:844}],['mobile-360',{width:360,height:800}]])r.push(await run(browser,v,label));fs.writeFileSync(path.join(out,'debt-browser-results.json'),JSON.stringify(r));console.log(JSON.stringify(r));}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
