'use strict';
const assert = require('node:assert/strict');
const { chromium, webkit } = require('playwright');
const { setup } = require('./lts_v382_browser.cjs');
const release = process.env.LTS_OPENING_TEST_RELEASE || 'v490';
const base = process.env.LTS_BROWSER_BASE || 'http://127.0.0.1:8788';

async function verify(browser, width) {
  const { ctx, page } = await setup(browser, width, width === 390 ? 844 : 900);
  let releaseForecast;
  const forecast = new Promise(resolve => { releaseForecast = resolve; });
  const order = [];
  let confirmed = false;
  try {
    await ctx.route('**/mobile/current.json', route => route.fulfill({json:{release,entry:'../releases/'+release+'/app.html'}}));
    await ctx.route('**/rpc/lts_browser_flow_v242', async route => {
      if (route.request().postDataJSON().p_to > '2027-12-31') await forecast;
      return route.fallback();
    });
    for (const name of ['lts_browser_wealth_detail_v242','lts_browser_awards_v178']) {
      await ctx.route('**/rpc/'+name, route => {
        order.push(name);
        return route.fallback();
      });
    }
    await ctx.route('**/rpc/lts_browser_open_finance_refresh_v1', route => {
      order.push('collection');
      return route.fulfill({json:{ok:true,requested_at:'2026-10-30T14:59:59Z'}});
    });
    await ctx.route('**/rpc/lts_browser_open_finance_status_v1', route => {
      const connections = ['341','237','336'].map(code => ({
        id:'test-'+code, provider:'fixture', institution_code:code,
        last_success_at:confirmed?'2026-10-30T15:00:00Z':'2026-10-30T14:58:00Z',
        provider_item_updated_at:'2026-10-30T14:50:00Z'
      }));
      return route.fulfill({json:{ok:true,connections}});
    });
    await page.goto(base+'/mobile/?source=home-screen',{waitUntil:'commit'});
    const frame = page.frameLocator('#wealth').frameLocator('#shell');
    await frame.getByRole('button',{name:'Atualizar contas',exact:true}).first().click();
    await frame.getByRole('button',{name:'Preparando consulta…',exact:true}).waitFor();
    releaseForecast();
    await frame.getByRole('button',{name:'Consultando bancos…',exact:true}).waitFor();
    assert.deepEqual(order,['collection'],'bank reconciliation must precede optional summary reads');
    assert.equal(await frame.locator('.lts-update-details').count()>0,true,'dated position details remain available');
    confirmed = true;
    await frame.getByText('Consulta concluída. Confira em Atualização a data de cada saldo.',{exact:true}).waitFor();
    await frame.locator('body').evaluate(() => window.__LTS_V178_REVIEW.ready());
    assert.ok(order.includes('lts_browser_wealth_detail_v242') && order.includes('lts_browser_awards_v178'),'optional readers resume');
    assert.equal(order.filter(x=>x==='collection').length,1);
  } finally {
    releaseForecast();
    await ctx.close();
  }
}
(async () => {
  for (const type of [chromium, webkit]) {
    const browser = await type.launch({executablePath:type===chromium?process.env.LTS_TEST_CHROMIUM:undefined});
    try {
      for (const width of [390,1280]) {
        await verify(browser,width);
        console.log(type.name(),width,'bank request precedes secondary reads and completes once');
      }
    } finally { await browser.close(); }
  }
})().catch(error=>{console.error(error);process.exitCode=1;});
