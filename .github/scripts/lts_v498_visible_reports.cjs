'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const {chromium, webkit} = require('playwright');
const {setup} = require('./lts_v382_browser.cjs');
const model = require('../../releases/v498/lts-v333-actions-model.js');
const base = process.env.LTS_BROWSER_BASE || 'http://127.0.0.1:8788';

function checkInvoiceReview() {
  const cycle = {month:'2030-01-01', due_date:'2030-01-25', amount:123.45, basis:'documented_snapshot'};
  const data = {asOf:'2030-01-02', cockpit:{}, recurring:{}, cards:{cards:[{family:'aeternum', cycles:[cycle]}]}};
  assert.equal(model.build(data).items.length, 1);
  cycle.official_invoice_received = true;
  assert.equal(model.build(data).items.length, 0);
}

async function run(browser, width) {
  const {ctx, page} = await setup(browser, width, 850);
  try {
    await ctx.route(base + '/releases/v498/**', route => route.fulfill({
      path:path.join('releases', 'v498', path.basename(new URL(route.request().url()).pathname))
    }));
    await ctx.route('**/rpc/lts_browser_expenses_v229', route => {
      const {p_from:from,p_to:to} = route.request().postDataJSON();
      return route.fulfill({json:{
        version:'expense-executive-v229-consistent-comparisons',
        period:{from,to,months_in_selection:2},
        summary:{selected_total:150,card_total:50,account_total:100,monthly_average:75,rows:2,last_12m:150},
        management_groups:[],
        monthly_detail:[{month:'2026-09-01',total:100},{month:'2026-10-01',total:50}],
        yearly_detail:[{year:2026,months:2,total:150,monthly_average:75}],
        comparison:{current_total:50,previous_total:100,partial:true,variation_pct:-50}
      }});
    });
    await page.goto(base + '/releases/v498/app.html');
    const app = page.frames().find(frame => frame.url().includes('/index.html'));
    await app.locator('#nav [data-v="Despesas"]:visible,#dx1MobileNav [data-mobile-route="Despesas"]:visible').first().click();
    await app.locator('button.v231-number-detail').first().waitFor();
    const order = await app.evaluate(async () => {
      const hold = window.__LTS_V227_TRANSPORT.holdHeavyReads();
      await hold.ready;
      const endpoint = 'https://tadhkamnwtsbdozwkyut.supabase.co/rest/v1/rpc/lts_browser_expenses_v229';
      const seen = [];
      const read = from => fetch(endpoint, {method:'POST',headers:{'Content-Type':'application/json'},
        body:JSON.stringify({p_from:from,p_to:'2026-10-30'})}).then(response=>response.json()).then(()=>seen.push(from));
      const background = read('2025-01-01'), visible = read('2026-01-01');
      try {
        await new Promise(resolve=>setTimeout(resolve,80));
        if(seen.length)throw Error('A manual refresh let reporting reads run');
        hold.allowVisibleFlow();
        await Promise.race([visible,new Promise((_,reject)=>setTimeout(()=>reject(Error('Visible read blocked')),2500))]);
        if(seen.length!==1)throw Error('Unrelated period ran before the bank collection finished');
      } finally { hold.release(); }
      await Promise.all([background,visible]);return seen;
    });
    assert.deepEqual(order,['2026-01-01','2025-01-01']);
    const comparison = app.locator('summary[aria-label*="dois períodos"]');
    for (const [index,from] of ['2026-10-01','2026-09-01'].entries()) {
      const buttons = comparison.locator('..').getByRole('button');
      if(!await buttons.nth(index).isVisible())await comparison.click();
      await buttons.nth(index).click();
      await app.locator('#v178Drawer').waitFor();
      assert.equal(await app.evaluate(()=>window.__LTS_V178_STATE.detail.range.from),from);
      await app.locator('#v178Drawer .v178-close').first().click();
    }
    await app.getByRole('button',{name:'Desde 2013',exact:true}).click();
    await app.locator('[data-expense-year="2026"]').click();
    await app.locator('#v178Drawer').waitFor();
    assert.equal(await app.evaluate(()=>window.__LTS_V178_STATE.detail.expected),150);
    console.log(width,'foreground period, both comparison totals and annual detail passed');
  } finally { await ctx.close(); }
}

(async()=>{
  checkInvoiceReview();
  for(const engine of process.env.LTS_CHROMIUM_PATH?[chromium]:[chromium,webkit]){
    const browser=await engine.launch(engine===chromium?{executablePath:process.env.LTS_CHROMIUM_PATH}:{});
    try { for(const width of [390,1366])await run(browser,width); }
    finally { await browser.close(); }
  }
})().catch(error=>{console.error(error);process.exitCode=1});
