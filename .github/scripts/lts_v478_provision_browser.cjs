'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const {chromium, webkit} = require('playwright');
const release = process.env.LTS_MOBILE_RELEASE || 'v478';
process.env.LTS_FLOW_RELEASE = release;
const {setup} = require('./lts_v382_browser.cjs');
const {product} = require('./lts_v379_fixtures.cjs');
const {response} = require('./lts_boot_recovery_fixtures.cjs');
const day = '2026-11-23', openDay = '2026-11-20';
const outDir = 'qa/v478-provision';
function event(date, account, key, description, signed_amount, source='planning_projection_v412') {
  return {event_date:date, account, source_ref:key+':'+date, description, signed_amount, source};
}
const entries = [
  event(openDay,'Bradesco','example:statement','Fatura identificada',-27,'documented'),
  event(day,'Bradesco','projection:v469:owner_food','Mercado · provisão · Visa Aeternum',-6.65),
  event(day,'Itaú','projection:v412:netflix','Estimativa de serviço',-1.25),
  event(day,'Bradesco','projection:v469:sub_example','Serviço de exemplo · assinatura prevista · Visa Aeternum',-3.35),
  event(day,'Bradesco','example:purchase','Compra identificada',-2.68,'documented')
];
async function test(browser, engine, width) {
  const s = await setup(browser,width,820,'2026-11-18T11:00:00Z');
  const refresh = {state:'ready',required:false,cached_available:true,request_version:'2',completed_version:'2'};
  try {
    await s.ctx.route('**/rpc/lts_browser_product_v1', r=>r.fulfill({json:{ok:true,mvp:product(),refresh}}));
    await s.ctx.route('**/rpc/lts_browser_product_refresh_status_v415', r=>r.fulfill({json:{ok:true,refresh}}));
    await s.ctx.route(/\/rpc\/lts_browser_flow_v\d+$/, r=>{
      const args=r.request().postDataJSON();
      const payload=response('lts_browser_flow_v242', args);
      const flow=payload.flow.current_future;
      flow.events=entries.filter(e=>e.event_date>=args.p_from && e.event_date<=args.p_to);
      for(const d of flow.days) {
        const rows=flow.events.filter(e=>e.event_date===d.date);
        d.summary.events=rows.length;
        d.fix86_columns.saidas=rows.reduce((sum,e)=>sum+Math.round(-e.signed_amount*100),0)/100;
        d.summary.Consolidado.exits=d.fix86_columns.saidas;
      }
      return r.fulfill({json:payload});
    });
    await s.page.goto('http://127.0.0.1:8788/mobile/?source=home-screen',{waitUntil:'domcontentloaded'});
    await s.page.waitForFunction(()=>document.querySelector('#wealth')?.contentDocument?.querySelector('#shell')?.contentDocument?.body?.dataset.ltsBootState==='ready');
    const frame=s.page.frames().find(f=>new URL(f.url()).pathname.endsWith('/releases/'+release+'/index.html'));
    assert.ok(frame);
    await frame.locator('#nav [data-v="Fluxo Diário"]:visible,#dx1MobileNav [data-mobile-route="Fluxo Diário"]:visible').click();
    await frame.evaluate(()=>loadFlowRange('2026-11-18','2026-12-01'));
    await frame.locator('.exp[data-d="'+openDay+'"]').click();
    const current=frame.locator('#d-'+openDay+'+.fx89-details');
    await current.getByText('Fatura identificada',{exact:true}).waitFor();
    assert.equal(await current.locator('.v478-invoice').count(),0);
    await frame.locator('.exp[data-d="'+day+'"]').click();
    const detail=frame.locator('#d-'+day+'+.fx89-details');
    const invoice=detail.locator('.v478-invoice');
    await invoice.locator('summary').waitFor();
    assert.equal(await invoice.count(),1);
    assert.equal(await invoice.evaluate(e=>e.open),false);
    assert.match(await invoice.locator('summary').innerText(),/10,00/);
    assert.equal(await detail.locator('.fx89-detail-row:visible').count(),2);
    await detail.getByText('Provisão Netflix',{exact:true}).waitFor();
    await detail.getByText('Compra identificada',{exact:true}).waitFor();
    assert.doesNotMatch(await detail.innerText(),/source_ref|planning_projection|payload/);
    fs.mkdirSync(outDir,{recursive:true});
    await invoice.screenshot({path:outDir+'/'+engine+'-'+width+'-closed.png'});
    await invoice.locator('summary').click();
    await invoice.getByText('Mercado',{exact:true}).waitFor();
    assert.deepEqual(await invoice.locator('li b').allTextContents().then(values=>values.map(v=>v.replace(/\s/g,''))), ['R$6,65','R$3,35']);
    await frame.evaluate(()=>render());
    await invoice.getByText('Serviço de exemplo',{exact:true}).waitFor();
    assert.ok(await invoice.evaluate(e=>e.open && e.scrollWidth<=e.clientWidth+2));
    await invoice.screenshot({path:outDir+'/'+engine+'-'+width+'-open.png'});
    assert.deepEqual(s.writes,[]);
  } finally { await s.ctx.close(); }
}
(async()=>{
  for (const [engine,type] of [['chromium',chromium],['webkit',webkit]]) {
    const browser=await type.launch();
    try { for (const width of [360,1366]) await test(browser,engine,width); }
    finally { await browser.close(); }
  }
})().catch(err=>{console.error(err); process.exitCode=1;});
