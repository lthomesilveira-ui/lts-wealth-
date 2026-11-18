'use strict';
process.env.LTS_FLOW_RELEASE = 'v471';
const assert = require('node:assert/strict');
const {chromium, webkit} = require('playwright');
const {setup, open} = require('./lts_v382_browser.cjs');
const {fixture} = require('./lts_v471_projection_test.cjs');
const {product} = require('./lts_v379_fixtures.cjs');

async function run(browser, width, malformed) {
  const session = await setup(browser, width, 980, '2026-11-17T17:00:00Z');
  try {
    const input = fixture();
    if (malformed) input.series[0].coverage[0].known_brl = null;
    const refresh = {state: 'ready', required: false, cached_available: true, request_version: '2', completed_version: '2'};
    const reply = data => route => route.fulfill({json: data});
    await session.ctx.route('**/rpc/lts_browser_product_v1', reply({ok: true, mvp: product(), refresh}));
    await session.ctx.route('**/rpc/lts_browser_product_refresh_status_v415', reply({ok: true, refresh}));
    await session.ctx.route('**/rpc/lts_browser_projection_policy_v412', reply(input));
    const frame = await open(session, 'v471', true);
    await frame.waitForFunction(status => window.__LTS_V412_PROJECTION?.status === status, malformed ? 'error' : 'ready');
    await frame.locator('#nav [data-v="Fluxo Diário"]:visible,#dx1MobileNav [data-mobile-route="Fluxo Diário"]:visible').click();
    const panel = frame.locator('[data-v412-policy="flow"]');
    await panel.waitFor({state:'attached'});
    if (malformed) {
      await frame.getByText('Não foi possível atualizar a previsão.', {exact:true}).waitFor({state:'visible'});
    } else {
      assert.equal(await frame.getByText('Não foi possível atualizar a previsão.', {exact:true}).count(), 0);
      const options = frame.getByLabel('Opções do Fluxo');
      await options.click();
      await panel.locator('.v412-origin > summary').click();
      await panel.getByText('Média de 24 meses.', {exact:false}).waitFor({state:'visible'});
      await panel.getByText('Valor mensal definido.', {exact:false}).waitFor({state:'visible'});
      assert.equal(await frame.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 2), true);
    }
    assert.deepEqual(session.writes, []);
  } finally { await session.ctx.close(); }
}
(async () => {
  for (const type of [chromium, webkit]) {
    const browser = await type.launch();
    try {
      for (const width of [393, 1366]) await run(browser, width, false);
      await run(browser, 393, true);
    } finally { await browser.close(); }
  }
  console.log('Verified accepted and incomplete projections in both browsers, desktop and mobile.');
})().catch(error => { console.error(error); process.exitCode = 1; });
