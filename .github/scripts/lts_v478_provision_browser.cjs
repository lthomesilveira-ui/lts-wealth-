'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const {chromium, webkit} = require('playwright');
const release = process.env.LTS_MOBILE_RELEASE || 'v478';
process.env.LTS_FLOW_RELEASE = release;
const {setup} = require('./lts_v382_browser.cjs');
const {product} = require('./lts_v379_fixtures.cjs');
const {response} = require('./lts_boot_recovery_fixtures.cjs');
const groupedItau = Number(release.slice(1)) >= 482;
const base = process.env.LTS_BROWSER_BASE || 'http://127.0.0.1:8788';
const day = '2026-11-23', openDay = '2026-11-20';
const outDir = 'qa/v478-provision';
const policy = {
  version:'projection-policy-v412', enabled:true, schema_version:1, as_of:'2026-11-18',
  horizon_end:'2031-12-31', next_review_on:'2027-01-01',
  history_window:{from:'2025-11-01',to:'2026-10-31'}, warnings:[],
  card_method:'total_budget_floor', outliers_excluded:false, missing_months_assumed_zero:false,
  financial_sources_modified:false, current_year_partial:true,
  series:[{
    series_key:'owner_food',description:'Mercado',method:'fixed',direction:'expense',account:'Bradesco',
    uses_history:false,reference_stale:false,expected_months:12,reference_amount_brl:10,
    reference_window:null,coverage_months:null,warnings:[],
    coverage:[
      {event_date:openDay,trusted:true,status:'open_cycle_known_only',budget_total_brl:2.50,known_brl:2.50,additional_brl:0},
      {event_date:day,trusted:true,budget_total_brl:10,known_brl:3.35,additional_brl:6.65}
    ],annual_totals:[{year:2026,budget_total_brl:12.50,additional_brl:6.65,partial_year:true}]
  }]
};
const projectionModel = require('../../releases/'+release+'/lts-v412-projection-policy.js');
assert.ok(projectionModel.build(policy));
for (const invalid of [{additional_brl:1},{known_brl:null},{budget_total_brl:10},{trusted:false}]) {
  const broken=structuredClone(policy);
  Object.assign(broken.series[0].coverage[0],invalid);
  assert.throws(()=>projectionModel.build(broken));
}

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
if (groupedItau) entries.push(
  event(day,'Itaú','projection:v468:apple_monthly_19_90','Apple · assinatura prevista',-19.90),
  event(day,'Itaú','projection:v468:google_ai_plus','Google AI Plus · assinatura prevista',-4.10),
  event(day,'Itaú','statement','Fatura de teste',-18,'card_invoice')
);
async function test(browser, engine, width) {
  const s = await setup(browser,width,820,'2026-11-18T11:00:00Z');
  const refresh = {state:'ready',required:false,cached_available:true,request_version:'2',completed_version:'2'};
  try {
    await s.ctx.route('**/rpc/lts_browser_product_v1', r=>r.fulfill({json:{ok:true,mvp:product(),refresh}}));
    await s.ctx.route('**/rpc/lts_browser_product_refresh_status_v415', r=>r.fulfill({json:{ok:true,refresh}}));
    await s.ctx.route('**/rpc/lts_browser_projection_policy_v412', r=>r.fulfill({json:policy}));
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
    if (process.env.LTS_BROWSER_FIXTURE_RELEASE) await s.ctx.route('**/mobile/current.json', route=>route.fulfill({json:{release,entry:'../releases/'+release+'/app.html'}}));
    await s.page.goto(base+'/mobile/?source=home-screen',{waitUntil:'domcontentloaded'});
    await s.page.waitForFunction(()=>document.querySelector('#wealth')?.contentDocument?.querySelector('#shell')?.contentDocument?.body?.dataset.ltsBootState==='ready');
    const frame=s.page.frames().find(f=>new URL(f.url()).pathname.endsWith('/releases/'+release+'/index.html'));
    assert.ok(frame);
    await frame.locator('#nav [data-v="Fluxo Diário"]:visible,#dx1MobileNav [data-mobile-route="Fluxo Diário"]:visible').click();
    await frame.waitForFunction(()=>window.__LTS_V412_PROJECTION?.status==='ready');
    await frame.waitForFunction(()=>!FLOWLOADING && !!FLOWQ?.current_future);
    await frame.locator('.v382-period summary').click();
    await frame.getByLabel('Data inicial do Fluxo',{exact:true}).fill('2026-11-18');
    await frame.getByLabel('Data final do Fluxo',{exact:true}).fill('2026-12-01');
    await frame.locator('#flowApply').click();
    await frame.waitForFunction(()=>!FLOWLOADING && FLOWQ?.from==='2026-11-18' && FLOWQ?.to==='2026-12-01');
    assert.ok(await frame.locator('#d-'+openDay).count(),
      JSON.stringify({errors:s.errors,report:await frame.evaluate(()=>({
        rows:document.querySelectorAll('.fx87-row[id]').length, drawn:document.querySelector('.fx87-row[id]')?.id,
        days:FLOWQ.current_future.days.length, events:FLOWQ.current_future.events.length,
        target:FLOWQ.current_future.days.find(x=>x.date==='2026-11-20')?.summary,
        selectedRange:[FLOWFROM,FLOWTO], view:V
      }))}));
    await frame.locator('.exp[data-d="'+openDay+'"]').click();
    const current=frame.locator('#d-'+openDay+'+.fx89-details');
    await current.getByText('Fatura identificada',{exact:true}).waitFor();
    assert.equal(await current.locator('.v478-invoice').count(),0);
    await frame.locator('.exp[data-d="'+day+'"]').click();
    const detail=frame.locator('#d-'+day+'+.fx89-details');
    const invoice=detail.locator('.v478-invoice').filter({hasText:'Provisão Visa Aeternum'});
    await invoice.locator('summary').waitFor();
    assert.equal(await invoice.count(),1);
    assert.equal(await invoice.evaluate(e=>e.open),false);
    assert.match(await invoice.locator('summary').innerText(),/10,00/);
    assert.equal(await detail.locator('.fx89-detail-row:visible').count(),groupedItau ? 3 : 2);
    if (groupedItau) {
      const itau=detail.locator('.v478-invoice').filter({hasText:'Provisão cartão Itaú'});
      await itau.locator('summary').click();
      assert.match(await itau.locator('summary').innerText(),/24,00/);
      await itau.getByText('Google AI Plus',{exact:true}).waitFor();
      await detail.getByText('Fatura de teste',{exact:true}).waitFor();
      assert.equal(await itau.locator('li').count(),2);
      assert.equal(await invoice.evaluate(e=>e.open),false);
    }
    await detail.getByText('Provisão Netflix',{exact:true}).waitFor();
    await detail.getByText('Compra identificada',{exact:true}).waitFor();
    assert.doesNotMatch(await detail.innerText(),/source_ref|planning_projection|payload/);
    fs.mkdirSync(outDir,{recursive:true});
    await invoice.screenshot({path:outDir+'/'+engine+'-'+width+'-closed.png'});
    await Promise.all([
      invoice.evaluate(el=>new Promise(resolve=>el.addEventListener('toggle',resolve,{once:true}))),
      invoice.locator('summary').click()
    ]);
    await invoice.getByText('Mercado',{exact:true}).waitFor();
    assert.deepEqual(await invoice.locator('li b').allTextContents().then(values=>values.map(v=>v.replace(/\s/g,''))), ['R$6,65','R$3,35']);
    await frame.evaluate(()=>render());
    await invoice.getByText('Serviço de exemplo',{exact:true}).waitFor();
    assert.ok(await invoice.evaluate(e=>e.open && e.scrollWidth<=e.clientWidth+2));
    await invoice.screenshot({path:outDir+'/'+engine+'-'+width+'-open.png'});
    if (groupedItau) {
      await frame.locator('[data-a="Itaú"]:visible').first().click();
      const expand=frame.locator('.exp[data-d="'+day+'"]');
      if (!(await detail.isVisible())) await expand.click();
      const itau=detail.locator('.v478-invoice');
      assert.equal(await itau.count(),1);
      assert.match(await itau.locator('summary').innerText(),/Provisão cartão Itaú[\s\S]+24,00/);
      await detail.getByText('Provisão Netflix',{exact:true}).waitFor();
    }
    assert.deepEqual(s.writes,[]);
  } finally { await s.ctx.close(); }
}
(async()=>{
  for (const [engine,type] of [['chromium',chromium],['webkit',webkit]]) {
    const browser=await type.launch({executablePath:engine==='chromium'?process.env.LTS_TEST_CHROMIUM:undefined});
    try { for (const width of [360,1366]) await test(browser,engine,width); }
    finally { await browser.close(); }
  }
})().catch(err=>{console.error(err); process.exitCode=1;});
