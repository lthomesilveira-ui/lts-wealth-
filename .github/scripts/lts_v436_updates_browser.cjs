'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const {chromium, webkit} = require('playwright');
const fixture = require('./lts_v379_fixtures.cjs');
const {setup, open} = require('./lts_v382_browser.cjs');
const out = 'qa/v436';
const card = 'lts_browser_card_review_queue_v312';
const recurring = 'lts_browser_recurring_future_gap_audit_v5';
const expectedCard = {
  ok: true, row_count: 1, additional_count: 1, matched_count: 1, offset: 0,
  next_offset: null, checked_at: '2026-11-09T15:00:00Z', category_options: ['Mercado'],
  rows: [{source_ref: 'synthetic-card', event_date: '2026-11-08', amount: 43.21,
    description: 'Compra de teste', account_source: 'Cartão de teste', last4: '0001'}]
};

async function run(browser, engine, width, release) {
  const h = await setup(browser, width, width < 1000 ? 852 : 1000, '2026-11-09T15:00:00Z');
  const calls = [];
  let failing = true;
  for (const [name, payload] of [[card, expectedCard], [recurring, fixture.recurring()]]) {
    await h.ctx.route('**/rest/v1/rpc/' + name, route => {
      calls.push({name, args: JSON.parse(route.request().postData())});
      return route.fulfill({
        status: failing ? 500 : 200, contentType: 'application/json',
        body: JSON.stringify(failing ? {code: '57014', message: 'synthetic statement timeout'} : payload)
      });
    });
  }
  try {
    const f = await open(h, release, false);
    await f.waitForFunction(() => __LTS_V168_STATE.updates.error && window.__LTS_V312_CARD_REVIEW?.state.error);
    assert.equal(await f.evaluate(() => V), 'Dashboard');
    const productBefore = await f.evaluate(() => JSON.stringify(D));
    const initialCalls = calls.length;
    failing = false;
    await f.locator('#nav [data-v="Atualizações"]:visible,#dx1MobileNav [data-mobile-route="Atualizações"]:visible').click();
    const panel = f.locator('#v312CardReview');
    await panel.waitFor();
    if (release === 'v433') {
      assert.equal(await panel.locator('[data-v312-count]').innerText(), '—');
      assert(await panel.locator('[data-v312-retry]').isVisible());
      assert.equal(calls.length, initialCalls);
      return;
    }
    await f.waitForFunction(() => __LTS_V168_STATE.updates.recurring && !__LTS_V168_STATE.updates.error
      && window.__LTS_V312_CARD_REVIEW.state.data?.row_count === 1 && !window.__LTS_V312_CARD_REVIEW.state.error);
    assert.equal(await panel.locator('[data-v312-count]').innerText(), '1');
    assert.match(await panel.innerText(), /Compra de teste/);
    assert.equal(await panel.locator('details[open]').count(), 0);
    await panel.locator('summary').click();
    assert.equal(await panel.locator('details[open]').count(), 1);
    assert.match(await panel.locator('details').innerText(), /Conferido em/);
    await h.page.screenshot({path: out + '/' + engine + '-' + width + '-details.png'});
    await panel.locator('summary').click();
    assert.equal(await panel.locator('details[open]').count(), 0);
    for (const name of [card, recurring]) {
      const original = calls.find(x => x.name === name);
      const recovered = calls.slice(initialCalls).filter(x => x.name === name);
      assert.equal(recovered.length, 1);
      assert.deepEqual(recovered[0].args, original.args);
    }
    const after = await f.evaluate(() => JSON.stringify(D));
    assert.equal(after, productBefore, 'the financial product payload was not replaced');
    const dimensions = await f.locator('html').evaluate(el => ({width: el.clientWidth, scroll: el.scrollWidth}));
    assert(dimensions.scroll <= dimensions.width + 2);
    assert.doesNotMatch(await f.locator('.v168-updates').innerText(), /57014|statement timeout|SQLSTATE|source_ref/);
    await h.page.screenshot({path: out + '/' + engine + '-' + width + '-ready.png'});

    failing = true;
    await f.evaluate(() => {
      __LTS_V227_TRANSPORT.invalidate(false);
      window.__LTS_V312_CARD_REVIEW.refresh();
    });
    await panel.locator('[role="alert"]').waitFor();
    assert.equal(await panel.locator('[data-v312-count]').innerText(), '1');
    const height = await panel.locator('[role="alert"]').evaluate(el => el.getBoundingClientRect().height);
    assert(height < 150);
    await h.page.screenshot({path: out + '/' + engine + '-' + width + '-stale.png'});
    assert.deepEqual(h.errors, []);
    assert.deepEqual(h.writes, []);
  } finally {
    await h.ctx.close();
  }
}

(async () => {
  fs.mkdirSync(out, {recursive: true});
  const results = [];
  for (const [engine, type] of [['chromium', chromium], ['webkit', webkit]]) {
    const browser = await type.launch({headless: true});
    try {
      if (engine === 'chromium') await run(browser, engine, 393, 'v433');
      for (const width of [320, 393, 1366]) {
        await run(browser, engine, width, 'v436');
        results.push({pass: true, engine, width});
      }
    } finally {
      await browser.close();
    }
  }
  const proof = {pass: true, results, predecessor_reproduced: true, authentic_session: false, physical_iphone: false};
  fs.writeFileSync(out + '/result.json', JSON.stringify(proof, null, 2) + '\n');
  console.log(JSON.stringify(proof));
})().catch(error => { console.error(error); process.exitCode = 1; });
