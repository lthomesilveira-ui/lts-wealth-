'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {chromium, webkit} = require('playwright');

const release = process.env.LTS_MOBILE_RELEASE || 'v477';
process.env.LTS_FLOW_RELEASE = release;
const {setup} = require('./lts_v382_browser.cjs');
const {product} = require('./lts_v379_fixtures.cjs');
const output = path.resolve('qa/v477-document-continuity');

async function verify(browser, engine, width) {
  const session = await setup(browser, width, 820, '2026-11-18T11:00:00Z');
  const bytes = Buffer.from('%PDF-1.4\nSynthetic document review\n%%EOF');
  const objectPath = '00000000-0000-4000-8000-000000000001/documents/example.pdf';
  const item = {
    inbox_id: '00000000-0000-4000-8000-000000000002',
    original_name: 'Exemplo.pdf',
    updated_at: '2026-11-18T11:00:00Z',
    phase: 'needs_decision',
    document_association: {note: 'Conferir com a fatura.'}
  };
  let releaseRead;
  const mayRead = new Promise(resolve => { releaseRead = resolve; });
  let metadataReads = 0;
  let downloads = 0;
  try {
    const refresh = {state:'ready', required:false, cached_available:true, request_version:'2', completed_version:'2'};
    await session.ctx.route('**/rpc/lts_browser_product_v1', route =>
      route.fulfill({json:{ok:true, mvp:product(), refresh}}));
    await session.ctx.route('**/rpc/lts_browser_product_refresh_status_v415', route =>
      route.fulfill({json:{ok:true, refresh}}));
    await session.ctx.route('**/rpc/lts_browser_document_review_queue_v1', route =>
      route.fulfill({json:{
        contract:'v149-evidence-review-readonly-canonical-v1', queue_documents:1, items:[item],
        write_allowed:false, financial_writer_called:false
      }}));
    await session.ctx.route('**/rpc/lts_browser_document_meta_v1', route => {
      assert.equal(route.request().postDataJSON().p_inbox_id, item.inbox_id);
      metadataReads++;
      return route.fulfill({json:{ok:true, storage_path:objectPath, original_name:item.original_name, mime_type:'application/pdf'}});
    });
    await session.ctx.route('**/storage/v1/object/authenticated/lts-documents/**', async route => {
      assert.equal(route.request().method(), 'GET');
      downloads++;
      await mayRead;
      await route.fulfill({contentType:'application/pdf', body:bytes});
    });

    await session.page.goto('http://127.0.0.1:8788/mobile/?source=home-screen', {waitUntil:'domcontentloaded'});
    await session.page.waitForFunction(() => document.querySelector('#wealth')?.contentDocument
      ?.querySelector('#shell')?.contentDocument?.body?.dataset.ltsBootState === 'ready');
    const frame = session.page.frames().find(candidate =>
      new URL(candidate.url()).pathname.endsWith('/releases/'+release+'/index.html'));
    assert.ok(frame, 'normal entry reached the selected release');
    await frame.waitForFunction(() => window.__LTS_V407_DOCUMENTS?.installed);
    await frame.locator('#nav [data-v="Atualizações"]:visible,#dx1MobileNav [data-mobile-route="Atualizações"]:visible').click();
    const panel = frame.locator('#v407Documents');
    await panel.waitFor({state:'visible'});
    assert.equal(await panel.evaluate(node => node.open), false);
    fs.mkdirSync(output, {recursive:true});
    const screenshot = state => panel.screenshot({path:path.join(output, engine+'-'+width+'-'+state+'.png')});
    await screenshot('closed');
    await panel.getByText('Enviar e consultar documentos', {exact:true}).click();
    await panel.getByRole('heading', {name:item.original_name}).waitFor();
    const details = panel.locator('.v407-document details');
    await details.locator('summary').click();
    const readStarted = session.page.waitForRequest(request =>
      new URL(request.url()).pathname === '/storage/v1/object/authenticated/lts-documents/'+objectPath);
    await panel.getByRole('button', {name:'Ver arquivo'}).click();
    await readStarted;
    await frame.evaluate(() => render());
    assert.equal(await details.evaluate(node => node.open), true, 'background redraw preserves the open receipt');
    assert.equal(await panel.getByText('Abrindo arquivo…').isVisible(), true, 'pending download stays in the active panel');
    releaseRead();

    const link = panel.getByRole('link', {name:'Baixar arquivo'});
    await link.waitFor({state:'visible'});
    const firstUrl = await link.getAttribute('href');
    await frame.evaluate(() => render());
    assert.equal(await link.getAttribute('href'), firstUrl);
    assert.equal(await panel.getByText(item.document_association.note, {exact:true}).isVisible(), true);
    const received = await link.evaluate(async node => Array.from(new Uint8Array(await (await fetch(node.href)).arrayBuffer())));
    assert.deepEqual(received, Array.from(bytes));
    assert.deepEqual([metadataReads, downloads], [1, 1]);
    assert.equal(await panel.count(), 1);
    assert.ok(await panel.evaluate(node => node.getBoundingClientRect().width <= innerWidth + 1));
    assert.doesNotMatch(await panel.innerText(), /SQLSTATE|payload|source_ref|storage_path/);
    await screenshot('open');
    await frame.evaluate(() => S.auth.signOut());
    assert.equal(await frame.locator('#v407Documents .v407-document').count(), 0);
    assert.deepEqual(session.writes, []);
  } finally {
    releaseRead();
    await session.ctx.close();
  }
}

module.exports = {verify};
if (require.main === module) {
  (async () => {
    for (const [engine, type] of [['chromium', chromium], ['webkit', webkit]]) {
      const browser = await type.launch();
      try {
        for (const width of [360, 1366]) await verify(browser, engine, width);
      } finally {
        await browser.close();
      }
    }
  })().catch(error => { console.error(error); process.exitCode = 1; });
}
