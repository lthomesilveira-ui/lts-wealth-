'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const {chromium} = require('playwright');
const {setup} = require('./lts_v382_browser.cjs');
const fixture = require('./lts_v379_fixtures.cjs');
const base = process.env.LTS_BROWSER_BASE || 'http://127.0.0.1:8788';

async function run(browser, width) {
  const {ctx, page} = await setup(browser, width, 860);
  try {
    await ctx.route(base + '/releases/v497/**', async route => {
      const file = path.basename(new URL(route.request().url()).pathname);
      await route.fulfill({path: path.join('releases/v497', file)});
    });
    await ctx.route('**/rpc/lts_browser_card_cycles_v229', route => {
      const packet = fixture.cards();
      const cycle = packet.cards[0].cycles[0];
      Object.assign(cycle, {month:'2026-11-01', basis:'documented_snapshot', documentary_amount:cycle.amount});
      return route.fulfill({json:packet});
    });
    await ctx.route('**/rpc/lts_browser_card_detail_v226', route => {
      const args = route.request().postDataJSON();
      const items = args.p_month === '2026-12-01' ? [{description:'Compra de teste',amount:2299.31,category:'Mercado'}] : [];
      return route.fulfill({json:{family:args.p_family,month:args.p_month,due_date:'2026-12-03',invoice_amount:2299.31,items}});
    });
    const start = Date.now();
    await page.goto(base + '/releases/v497/app.html');
    const frame = page.frames().find(f => f.url().includes('/index.html'));
    const nav = name => frame.locator('#nav [data-v="'+name+'"]:visible,#dx1MobileNav [data-mobile-route="'+name+'"]:visible').first();
    await nav('Despesas').waitFor();
    const menuMs = Date.now() - start;
    for (const name of ['Fluxo Diário','Patrimônio','Atualizações','Despesas']) {
      await nav(name).click();
      try { await frame.waitForFunction(name => V === name, name,{timeout:5000}); }
      catch (err) { throw Error(width+' px: '+name+' → '+await frame.evaluate(()=>V)+'; '+err.message); }
    }
    await frame.getByRole('tab',{name:'Cartões e faturas'}).click();
    await frame.locator('button[data-v226-family="aeternum"][data-v226-month="2026-11-01"]').first().click();
    await frame.getByText('Compra de teste',{exact:true}).first().waitFor();
    assert.equal(await frame.locator('#v226-detail [data-v226-item]').count(), 1);
    await frame.locator('#v226-detail [data-v226-close]').click();
    console.log(JSON.stringify({width,menuMs,invoiceDetail:true}));
  } finally { await ctx.close(); }
}
(async () => {
  const browser = await chromium.launch({executablePath:process.env.LTS_CHROMIUM_PATH, headless:true});
  try { for (const width of [390,1366]) await run(browser,width); }
  finally { await browser.close(); }
})().catch(err => { console.error(err); process.exitCode=1; });
