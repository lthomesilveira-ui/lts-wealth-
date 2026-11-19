'use strict';
const assert = require('node:assert/strict');
const { chromium, webkit } = require('playwright');
const { setup } = require('./lts_v382_browser.cjs');
const fixtures = require('./lts_v379_fixtures.cjs');

const release = process.env.LTS_OPENING_TEST_RELEASE || 'v484';
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
  const secondCash = gate();
  let cashReads = 0;
  const flowRanges = [];
  const firstFlow = gate();
  const forecast = gate();
  const forecastStarted = gate();
  try {
    await ctx.route('**/mobile/current.json', route => route.fulfill({json:{release,entry:'../releases/'+release+'/app.html'}}));
    await ctx.route('**/rpc/lts_browser_product_v1', async route => {
      await product.pending;
      return route.fulfill({json:{ok:true,mvp:fixtures.product()}});
    });
    const cash = {...fixtures.response('lts_browser_cash_today_v242',{}),as_of:today,status:'complete',version:'cash-today-v179-current-canonical',
      cash:50,d0:30,brokerage_available:20,available_total:100,bank_positions:[{institution:'Banco de teste',balance:50}]};
    if (scenario === 'stale') cash.as_of = '2026-10-29';
    if (scenario === 'mismatch') cash.available_total = 150;
    await ctx.route('**/rpc/lts_browser_cash_today_v242', async route => {
      if (++cashReads > 1 && scenario === 'groups-before-cash') await secondCash.pending;
      return route.fulfill({json:cash});
    });
    if (scenario === 'first-flow') {
      await ctx.route('**/rpc/lts_browser_projection_policy_v412', route => route.fulfill({status:503,json:{message:'Fixture unavailable'}}));
    }
    await ctx.route('**/rpc/lts_browser_flow_v242', async route => {
      const args = route.request().postDataJSON();
      flowRanges.push(args);
      if (args.p_from === '2026-10-25' && args.p_to === '2031-12-31') firstFlow.open();
      if (scenario !== 'first-flow' && args.p_to > '2027-12-31') { forecastStarted.open(); await forecast.pending; }
      return route.fallback();
    });
    await page.goto(base+'/mobile/?source=home-screen',{waitUntil:'commit'});
    const frame = page.frameLocator('#wealth').frameLocator('#shell');
    const boot = frame.locator('.opening-position');
    await boot.getByText('Banco de teste',{exact:true}).waitFor();
    const title = boot.getByRole('heading',{name:'Total disponível hoje',exact:true});
    if (scenario === 'stale' || scenario === 'mismatch') {
      assert.equal(await title.count(),0);
      return;
    }
    await title.waitFor();
    assert.match(await boot.innerText(),/100,00/);
    if (scenario === 'first-flow') {
      await frame.locator('body').evaluate(el => {
        const doc=el.ownerDocument;
        const events=[];
        doc.defaultView.__openingTouchEvents=events;
        for(const type of ['pointerdown','touchstart','pointerup','touchend','click']){
          doc.addEventListener(type,e=>{
            const button=e.target.closest?.('button');
            const pt=e.changedTouches?.[0]||e;
            const row={type,tag:e.target.tagName,id:e.target.id,route:button?.dataset.mobileRoute||button?.dataset.v,
              text:button?.textContent?.trim()?.slice(0,45),x:pt.clientX,y:pt.clientY,
              phase:doc.body.dataset.ltsBootState,view:V,width:innerWidth,visualWidth:visualViewport?.width};
            events.push(row);queueMicrotask(()=>{row.after=V});
          },true);
        }
      });
    }
    product.open();
    if (scenario === 'first-flow') {
      const target=frame.locator('#dx1MobileNav [data-mobile-route="Fluxo Diário"]');
      await target.tap();
      try {
        await frame.locator('.v382-period').filter({hasText:'31/12/2031'}).waitFor();
      } catch (error) {
        const state = await frame.locator('body').evaluate(el => ({
          heading: el.querySelector('main h1')?.textContent, period: el.querySelector('.v382-period')?.textContent,
          route: V, from: FLOWFROM, to: FLOWTO, events:window.__openingTouchEvents, navBox:el.querySelector('#dx1MobileNav [data-mobile-route="Fluxo Diário"]')?.getBoundingClientRect().toJSON(), defaultOpened: window.__LTS_V172_STATE?.flowNavigationOpened
        }));
        throw Error('Initial mobile Flow: '+JSON.stringify({state,flowRanges}),{cause:error});
      }
      await Promise.race([firstFlow.pending,new Promise((_,reject)=>{const t=setTimeout(()=>reject(Error('canonical Flow was never requested')),12000);t.unref();})]);
      assert.ok(flowRanges.some(q => q.p_from === '2026-10-25' && q.p_to === '2031-12-31'));
      assert.ok(!flowRanges.some(q => q.p_from === '2026-10-25' && q.p_to === '2030-12-31'));
      return;
    }
    const groups = frame.locator('[data-v178-scope="dashboard"]');
    await groups.getByRole('button',{name:'Categoria de teste',exact:true}).waitFor();
    assert.match(await groups.innerText(),/100,00/);
    if (scenario === 'groups-before-cash') {
      assert.ok(cashReads > 1, 'the normal balance refresh should already be in progress');
      secondCash.open();
    }
    // Forecast remains automatically scheduled even when its response is slow.
    let timeout;
    try { await Promise.race([forecastStarted.pending,new Promise((_,reject)=>{timeout=setTimeout(()=>reject(Error('multi-year forecast did not start')),15000);})]); }
    finally {clearTimeout(timeout);}
  } finally {
    product.open(); secondCash.open(); forecast.open(); await ctx.close();
  }
}
(async()=>{
  for(const type of [chromium,webkit]){
    const b=await type.launch({executablePath:type===chromium?process.env.LTS_TEST_CHROMIUM:undefined});
    try {for (const scenario of (release==='v484'?['complete','stale','mismatch']:['groups-before-cash','first-flow','stale','mismatch'])) {const samples=scenario==='first-flow'&&type===webkit?Number(process.env.LTS_FIRST_TOUCH_SAMPLES||1):1;for(let i=0;i<samples;i++)await run(b,scenario);console.log(type.name(),scenario,'passed',samples);}}
    finally {await b.close();}
  }
})().catch(e=>{console.error(e);process.exitCode=1;});
