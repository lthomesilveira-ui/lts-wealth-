'use strict';
const assert = require('node:assert/strict');
const { chromium, webkit } = require('playwright');
const { setup } = require('./lts_v382_browser.cjs');
const fixtures = require('./lts_v379_fixtures.cjs');

const release = 'v484';
const base = process.env.LTS_BROWSER_BASE || 'http://127.0.0.1:8788';
const today = '2026-10-30';
function gate() {
  let open;
  const pending = new Promise(resolve => { open = resolve; });
  return { pending, open };
}
async function run(engine, scenario) {
  const {ctx,page} = await setup(engine,390,844);
  const product = gate();
  const forecast = gate();
  const forecastStarted = gate();
  try {
    await ctx.route('**/mobile/current.json', route => route.fulfill({json:{release,entry:'../releases/v484/app.html'}}));
    await ctx.route('**/rpc/lts_browser_product_v1', async route => {
      await product.pending;
      return route.fulfill({json:{ok:true,mvp:fixtures.product()}});
    });
    const cash = {...fixtures.response('lts_browser_cash_today_v242',{}),as_of:today,status:'complete',version:'cash-today-v179-current-canonical',
      cash:50,d0:30,brokerage_available:20,available_total:100,bank_positions:[{institution:'Banco de teste',balance:50}]};
    if (scenario === 'stale') cash.as_of = '2026-10-29';
    if (scenario === 'mismatch') cash.available_total = 150;
    await ctx.route('**/rpc/lts_browser_cash_today_v242', route => route.fulfill({json:cash}));
    await ctx.route('**/rpc/lts_browser_flow_v242', async route => {
      const args = route.request().postDataJSON();
      if (args.p_to > '2027-12-31') { forecastStarted.open(); await forecast.pending; }
      return route.fallback();
    });
    await page.goto(base+'/mobile/?source=home-screen',{waitUntil:'commit'});
    const frame = page.frameLocator('#wealth').frameLocator('#shell');
    const boot = frame.locator('.opening-position');
    await boot.getByText('Banco de teste',{exact:true}).waitFor();
    const title = boot.getByRole('heading',{name:'Total disponível hoje',exact:true});
    if (scenario !== 'complete') {
      assert.equal(await title.count(),0);
      return;
    }
    await title.waitFor();
    assert.match(await boot.innerText(),/100,00/);
    product.open();
    const groups = frame.locator('[data-v178-scope="dashboard"]');
    await groups.getByRole('button',{name:'Categoria de teste',exact:true}).waitFor();
    assert.match(await groups.innerText(),/100,00/);
    // Forecast remains automatically scheduled even when its response is slow.
    let timeout;
    try { await Promise.race([forecastStarted.pending,new Promise((_,reject)=>{timeout=setTimeout(()=>reject(Error('multi-year forecast did not start')),15000);})]); }
    finally {clearTimeout(timeout);}
  } finally {
    product.open(); forecast.open(); await ctx.close();
  }
}
(async()=>{
  for(const type of [chromium,webkit]){
    const b=await type.launch({executablePath:type===chromium?process.env.LTS_TEST_CHROMIUM:undefined});
    try {for (const scenario of ['complete','stale','mismatch']) {await run(b,scenario);console.log(type.name(),scenario,'passed');}}
    finally {await b.close();}
  }
})().catch(e=>{console.error(e);process.exitCode=1;});
