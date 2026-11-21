'use strict';
const assert = require('node:assert/strict');
const { chromium, webkit } = require('playwright');
const { setup } = require('./lts_v382_browser.cjs');
const fixture = require('./lts_v379_fixtures.cjs');
const projection = require('./lts_v412_projection_fixtures.cjs');

async function verify(browser, width, engine) {
  const height = width === 390 ? 844 : 900;
  const h = await setup(browser, width, height, '2026-11-21T18:00:00Z');
  try {
    const policy = projection.policy();
    policy.as_of = '2026-11-21';
    await h.ctx.route('**/rpc/lts_browser_projection_policy_v412', route => route.fulfill({ json: policy }));
    await h.ctx.route('**/rpc/lts_browser_flow_v242', route => {
      const args = route.request().postDataJSON();
      const result = fixture.response('lts_browser_flow_v242', args);
      const { days, events } = result.flow.current_future;
      for (let i = 0; i < days.length; i += 4) {
        events.push({ source: 'current_event', source_ref: 'fixture-' + i, event_date: days[i].date,
          description: 'Movimento de teste', signed_amount: -10, account: 'Itaú', category: 'Teste' });
      }
      return route.fulfill({ json: result });
    });
    const base = process.env.LTS_BROWSER_BASE || 'http://127.0.0.1:8788';
    await h.page.goto(base + '/mobile/?source=home-screen');
    const app = h.page.frameLocator('#wealth').frameLocator('#shell');
    const nav = app.locator('#nav [data-v="Fluxo Diário"]:visible,#dx1MobileNav [data-mobile-route="Fluxo Diário"]:visible');
    await nav.waitFor();
    const inner = h.page.frames().find(frame => new URL(frame.url()).pathname.endsWith('/v492/index.html'));
    assert(inner, 'V492 application frame');
    await inner.waitForFunction(() => V === 'Dashboard' && D && window.__LTS_V382_FLOW_LAYOUT?.installed);
    await app.getByText('Total disponível hoje', { exact: true }).first().waitFor();
    const started = performance.now();
    await nav.click();
    await inner.waitForFunction(() => V === 'Fluxo Diário' && !FLOWLOADING && FLOWQ?.to === '2031-12-31'
      && document.querySelector('.v382-period:not([open])') && document.querySelector('[data-d]'));
    const elapsed = Math.round(performance.now() - started);
    const metrics = await inner.evaluate(() => ({
      from: FLOWFROM, to: FLOWTO, days: FLOWQ.current_future.days.length,
      rows: document.querySelectorAll('[data-d]').length,
      overflow: document.documentElement.scrollWidth - innerWidth,
      controlsHeight: Math.round(document.querySelector('.flow-sticky-controls').getBoundingClientRect().height)
    }));
    assert.equal(metrics.from, '2026-11-16');
    assert(metrics.days >= 1867 && metrics.rows > 300, 'full calendar and material movements are navigable');
    assert(metrics.overflow <= 2 && metrics.controlsHeight > 0, 'collapsed controls fit the screen');
    await app.locator('.v382-period summary').click();
    await app.locator('#flowFrom').waitFor({ state: 'visible' });
    await app.locator('.v382-period summary').click();
    await app.locator('[data-d]').first().click();
    await app.locator('.fx89-details').first().waitFor({ state: 'visible' });
    assert.deepEqual(h.errors, []);
    console.log(JSON.stringify({ engine, width, clickToFlowMs: elapsed, ...metrics }));
  } finally {
    await h.ctx.close();
  }
}

(async () => {
  for (const [name, type] of Object.entries({ chromium, webkit })) {
    const browser = await type.launch();
    try {
      for (const width of [390, 1366]) await verify(browser, width, name);
    } finally {
      await browser.close();
    }
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
