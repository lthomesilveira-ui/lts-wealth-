'use strict';
const assert = require('node:assert/strict');
const { chromium, webkit } = require('playwright');
const { setup } = require('./lts_v382_browser.cjs');
const { product } = require('./lts_v379_fixtures.cjs');
const base = process.env.LTS_BROWSER_BASE || 'http://127.0.0.1:8788';
const release = process.env.LTS_MOBILE_RELEASE || 'v482';
const cash = { status:'complete', as_of:'2026-11-18', cash:27.25,
  bank_positions:[{institution:'Banco de teste', balance:27.25}] };
async function run(browser, width, scenario) {
  const { ctx, page } = await setup(browser, width, 820);
  let finishProduct, finishCash;
  const productGate = new Promise(r => { finishProduct = r; });
  const cashGate = new Promise(r => { finishCash = r; });
  try {
    if (process.env.LTS_BROWSER_FIXTURE_RELEASE) await ctx.route('**/mobile/current.json', route =>
      route.fulfill({json:{release,entry:'../releases/'+release+'/app.html'}}));
    await ctx.route('**/rpc/lts_browser_cash_today_v242', async route => {
      if (scenario === 'late') await cashGate;
      await route.fulfill({json: scenario === 'incomplete' ? {...cash,cash:null} : cash});
    });
    await ctx.route('**/rpc/lts_browser_product_v1', async route => {
      await productGate;
      await route.fulfill({json:{ok:true,mvp:product(),refresh:{state:'ready',required:false,cached_available:true,request_version:'2',completed_version:'2'}}});
    });
    await page.goto(base+'/mobile/?source=home-screen',{waitUntil:'domcontentloaded'});
    const frame=page.frameLocator('#wealth').frameLocator('#shell');
    const panel=frame.locator('#ltsBootRecovery .opening-position');
    if (scenario === 'fast') {
      await panel.getByText('Banco de teste',{exact:true}).waitFor();
      assert.match(await panel.innerText(),/27,25/);
      await panel.locator('summary').click();
      assert.equal(await panel.getByText('Banco de teste').isVisible(),false);
    } else {
      await frame.getByText('Carregando seu LTS',{exact:true}).waitFor();
      assert.equal(await panel.isVisible(),false);
    }
    finishProduct();
    try { await frame.locator('body[data-lts-boot-state="ready"] #app').waitFor(); }
    catch (err) { err.message += ' Rendered: '+(await frame.locator('body').innerText()).slice(0,420); throw err; }
    finishCash();
    assert.equal(await panel.isVisible(),false);
    assert.equal(await frame.getByRole('button',{name:'Alterar senha',exact:true}).count(),1);
  } finally { finishProduct(); finishCash(); await ctx.close(); }
}
(async()=>{
  for (const engine of [chromium,webkit]) {
    const browser=await engine.launch({executablePath:engine===chromium?process.env.LTS_TEST_CHROMIUM:undefined});
    try {
      for (const [width,scenario] of [[360,'fast'],[1366,'fast'],[360,'incomplete'],[1366,'late']]) {
        await run(browser,width,scenario);
        console.log(engine.name(),width,scenario,'passed');
      }
    } finally { await browser.close(); }
  }
})().catch(e=>{console.error(e);process.exitCode=1;});
