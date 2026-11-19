'use strict';
const { chromium, webkit } = require('playwright');
const assert = require('node:assert/strict');
const { setup } = require('./lts_v382_browser.cjs');
const release = process.env.LTS_OPENING_TEST_RELEASE || 'v489';
const base = process.env.LTS_BROWSER_BASE || 'http://127.0.0.1:8788';

(async () => {
  for (const type of [chromium, webkit]) {
    const browser = await type.launch({executablePath:type===chromium?process.env.LTS_TEST_CHROMIUM:undefined});
    try {
      const {ctx,page} = await setup(browser,390,844);
      await ctx.route('**/mobile/current.json', route => route.fulfill({json:{release,entry:'../releases/'+release+'/app.html'}}));
      await page.goto(base+'/mobile/?source=home-screen',{waitUntil:'commit'});
      const frame = page.frameLocator('#wealth').frameLocator('#shell');
      const button = frame.locator('#dx1MobileNav [data-mobile-route="Fluxo Diário"]');
      await button.waitFor({state:'visible'});
      const stable = await button.evaluate(el => {
        const label=el.querySelector('span');
        render();
        return el.isConnected && label.isConnected && el.contains(label);
      });
      assert.equal(stable,true,'Dashboard rendering must retain the button and touch target');
      await button.evaluate(el => el.addEventListener('touchstart', () => render(), {once:true,passive:true}));
      await button.tap();
      await frame.locator('.v382-period').waitFor();
      await ctx.close();
      console.log(type.name(), 'native mobile touch survives an in-flight render');
    } finally { await browser.close(); }
  }
})().catch(err=>{console.error(err);process.exitCode=1;});
