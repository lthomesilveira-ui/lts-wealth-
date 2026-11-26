'use strict';
const assert = require('node:assert/strict');
const { chromium, webkit } = require('playwright');
const { setup } = require('./lts_v382_browser.cjs');
const base = process.env.LTS_BROWSER_BASE || 'http://127.0.0.1:8788';

async function verify(browser, width) {
  const { ctx, page } = await setup(browser, width, 850);
  let finishContext;
  const pendingContext = new Promise(resolve => { finishContext = resolve; });
  let contextRequested = false;
  try {
    await ctx.route('**/rpc/lts_browser_expense_context_lens_v1', async route => {
      contextRequested = true;
      await pendingContext;
      await route.fulfill({ status: 503, json: { message: 'Context unavailable' } }).catch(() => {});
    });
    await ctx.route('**/rpc/lts_browser_expenses_v229', route => {
      const { p_from: from, p_to: to } = route.request().postDataJSON();
      return route.fulfill({ json: {
        version: 'expense-executive-v229-consistent-comparisons',
        period: { from, to, last_available: '2026-10-16' },
        summary: { selected_total: 1234.56, monthly_average: 123.46, rows: 2 },
        monthly_detail: [], management_groups: [], yearly_detail: []
      } });
    });
    await page.goto(base + '/releases/v500/app.html');
    const app = page.frameLocator('#shell');
    await app.locator('#nav [data-v="Despesas"]:visible,#dx1MobileNav [data-mobile-route="Despesas"]:visible').first().click();
    const total = app.getByRole('button', { name: 'Ver composição: Despesas acumuladas no período' }).filter({ hasText: '1.234,56' });
    await total.waitFor({ timeout: 8000 });
    const frame = page.frames().find(f => f.url().includes('/releases/v500/index.html'));
    await frame.waitForFunction(() => window.__LTS_V168_STATE?.expense?.data?.summary?.selected_total === 1234.56, null, {timeout:3000});
    assert.equal(await total.isVisible(), true);
    const response = page.waitForResponse(r => r.url().endsWith('/rpc/lts_browser_expense_context_lens_v1') && r.request().method() === 'POST');
    finishContext();
    await response;
    assert.equal(contextRequested, true);
    assert.match(await total.innerText(), /1\.234,56/);
  } finally {
    finishContext();
    await ctx.close();
  }
}

(async () => {
  const engines = process.env.LTS_CHROMIUM_PATH ? [chromium] : [chromium, webkit];
  for (const engine of engines) {
    const browser = await engine.launch(engine === chromium && process.env.LTS_CHROMIUM_PATH ? {executablePath:process.env.LTS_CHROMIUM_PATH} : {});
    try { for (const width of [390,1366]) await verify(browser, width); }
    finally { await browser.close(); }
  }
})().catch(error => {console.error(error);process.exitCode = 1;});
