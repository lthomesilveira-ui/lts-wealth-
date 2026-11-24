'use strict';
const assert = require('node:assert/strict');
const {chromium, webkit} = require('playwright');
const {setup} = require('./lts_v382_browser.cjs');
const {product} = require('./lts_v379_fixtures.cjs');
const base = process.env.LTS_BROWSER_BASE || 'http://127.0.0.1:8788';
const pending={state:'running',required:true,cached_available:false,request_version:'2',completed_version:'1'};
const ready={...pending,state:'ready',required:false,cached_available:true,completed_version:'2'};
async function run(browser,width,scenario){
 const {ctx,page}=await setup(browser,width,850);
 let releaseCash,releaseProduct,fresh=false,polls=0;
 const cashGate=new Promise(resolve=>{releaseCash=resolve});
 const productGate=new Promise(resolve=>{releaseProduct=resolve});
 const cash={status:'complete',as_of:'2026-10-30',cash:150,bank_positions:[{institution:'Banco A',balance:150,as_of:'2026-10-29'}]};
 try{
  await ctx.route('**/rpc/lts_browser_product_v1',async route=>{
   if(scenario==='early')await productGate;
   await route.fulfill({json:{ok:true,mvp:fresh?product():null,refresh:fresh?ready:pending}});
  });
  await ctx.route('**/rpc/lts_browser_product_refresh_status_v415',route=>{
   polls++;return route.fulfill({json:{ok:true,refresh:fresh?ready:pending}});
  });
  await ctx.route('**/rpc/lts_browser_cash_today_v242',async route=>{
   await cashGate;await route.fulfill({json:scenario==='invalid'?{...cash,cash:999}:cash});
  });
  await page.goto(base+'/mobile/?source=home-screen',{waitUntil:'domcontentloaded'});
  const frame=page.frameLocator('#wealth').frameLocator('#shell');
  const panel=frame.locator('#ltsBootRecovery .opening-position');
  if(scenario!=='early')await frame.locator('body[data-lts-boot-state="preparing"]').waitFor();
  if(scenario==='logout'){
   await frame.getByRole('button',{name:'Sair',exact:true}).click();
   releaseCash();await frame.getByRole('button',{name:'Entrar',exact:true}).waitFor();
   assert.equal(await panel.count(),0);return;
  }
  releaseCash();
  if(scenario==='invalid'){
   await page.waitForFunction(()=>document.querySelector('#wealth').contentDocument?.querySelector('#shell')?.contentDocument?.querySelector('[data-lts-refresh-observation]')?.getAttribute('data-lts-refresh-observation')?.includes('"polls":1'));
   assert.equal(await panel.count(),0);
  }else{
   await panel.getByText('29/10/2026').waitFor();
   assert.match(await panel.innerText(),/150,00/);
   let details=panel.locator('details');
   await details.locator('summary').click();
   releaseProduct();
   await frame.locator('body[data-lts-boot-state="preparing"]').waitFor();
   await page.waitForFunction(()=>document.querySelector('#wealth').contentDocument?.querySelector('#shell')?.contentDocument?.querySelector('[data-lts-refresh-observation]')?.getAttribute('data-lts-refresh-observation')?.includes('"polls":1'));
   assert.equal(await details.getAttribute('open'),null,'polling preserves collapsed balances');
   assert.equal(await panel.isVisible(),true);
   assert(polls>=1);
  }
  fresh=true;releaseProduct();
  await frame.locator('body[data-lts-boot-state="ready"] #app').waitFor();
  const flow=frame.locator('#nav [data-v="Fluxo Diário"]:visible,#dx1MobileNav [data-mobile-route="Fluxo Diário"]:visible').first();
  await flow.click();
  await frame.locator('[data-a="Itaú"]:visible').first().waitFor();
  assert.equal(await panel.isVisible(),false);
 }finally{releaseProduct();releaseCash();await ctx.close()}
}
(async()=>{
 const engines=process.env.LTS_TEST_CHROMIUM_ONLY?[chromium]:[chromium,webkit];
 for(const engine of engines){
  const b=await engine.launch({executablePath:engine===chromium?process.env.LTS_TEST_CHROMIUM:undefined});
  try{for(const [w,s] of [[390,'early'],[1366,'late'],[390,'invalid'],[390,'logout']]){
   await run(b,w,s);console.log(engine.name(),w,s,'passed');
  }}finally{await b.close()}
 }
})().catch(e=>{console.error(e);process.exitCode=1});
