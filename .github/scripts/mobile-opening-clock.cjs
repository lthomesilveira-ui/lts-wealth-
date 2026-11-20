'use strict';
const assert = require('node:assert/strict');
const {chromium,webkit} = require('playwright');

async function run(engine) {
  const browser = await engine.launch();
  try {
    const page = await browser.newPage({viewport:{width:390,height:844},hasTouch:true});
    let release;
    const held = new Promise(resolve => {release=resolve});
    await page.route('**/mobile/current.json', async route => {
      await held;
      await route.fulfill({json:{release:'v492',entry:'../releases/v492/app.html'}});
    });
    await page.route('**/releases/v492/app.html', route => route.fulfill({
      contentType:'text/html',
      body:'<iframe id="shell" srcdoc="<body data-lts-boot-state=loading><button data-v225-refresh disabled>Consultando bancos…</button><div class=v225-freshness-bank data-bank=341 data-freshness=previous-day></div><div class=v337-bank><i class=bank-341></i><strong>100</strong></div>"></iframe>'
    }));
    await page.goto('http://127.0.0.1:8788/mobile/');
    await page.getByRole('button',{name:'Abrir Wealth'}).click();
    await page.getByText('1 s',{exact:true}).waitFor();
    await page.getByRole('button',{name:'Tentar novamente'}).waitFor({timeout:30000});
    release();
    await page.getByText('Carregando dados…',{exact:true}).waitFor();
    const body=page.frameLocator('#wealth').frameLocator('#shell').locator('body');
    assert.match(await body.evaluate(el=>getComputedStyle(el.querySelector('strong'),'::after').content),/Saldo de dia anterior/);
    await body.locator('[data-v225-refresh][data-wait]').waitFor();
    await body.evaluate(el=>{el.dataset.ltsBootState='data-error'});
    await page.locator('#openingStatus').waitFor({state:'hidden'});
    console.log(engine.name(),'mobile elapsed time, recovery, bank date and error handover passed');
  } finally { await browser.close(); }
}
Promise.all([run(chromium),run(webkit)]).catch(error=>{console.error(error);process.exitCode=1});
