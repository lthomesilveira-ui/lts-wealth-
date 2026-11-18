'use strict';
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {chromium, webkit} = require('playwright');
const release = process.env.LTS_MOBILE_RELEASE || 'v476';
process.env.LTS_FLOW_RELEASE = release;
const {setup, open} = require('./lts_v382_browser.cjs');

async function verify(browser, width) {
  const session = await setup(browser, width, 820, '2026-11-18T11:00:00Z');
  const sample = Buffer.from('%PDF-1.4\nSynthetic input\n%%EOF');
  const digest = crypto.createHash('sha256').update(sample).digest('hex');
  const objectPath = '00000000-0000-4000-8000-000000000001/documents/' + digest;
  let uploads = 0, receipts = 0, fileExists = false, interrupt = true;
  try {
    await session.ctx.route('**/rpc/lts_browser_review_document_file_v476', async route => {
      const args = route.request().postDataJSON();
      assert.equal(args.p_sha256, digest);
      assert.equal(args.p_size_bytes, sample.length);
      assert.equal(args.p_document_type, 'other_financial_document');
      if (!fileExists) return route.fulfill({json:{ok:true,state:'upload_required',storage_path:objectPath}});
      if (!receipts) receipts++;
      if (interrupt) { interrupt = false; return route.abort('timedout'); }
      return route.fulfill({json:{ok:true,state:'received',inbox_id:'sample-receipt'}});
    });
    await session.ctx.route('**/storage/v1/object/lts-documents/**', async route => {
      assert.equal(route.request().method(), 'POST');
      assert.equal(route.request().headers()['x-upsert'], 'false');
      assert.deepEqual(route.request().postDataBuffer(), sample);
      assert.equal(new URL(route.request().url()).pathname, '/storage/v1/object/lts-documents/'+objectPath);
      uploads++; fileExists = true;
      return route.fulfill({json:{Key:objectPath}});
    });
    await session.ctx.route('**/rpc/lts_browser_document_review_queue_v1', route =>
      route.fulfill({json:{contract:'v149-evidence-review-readonly-canonical-v1',queue_documents:receipts,
        items:receipts?[{inbox_id:'sample-receipt',original_name:'Example.pdf',phase:'received'}]:[],
        write_allowed:false,financial_writer_called:false}}));
    const frame = await open(session, release);
    await frame.locator('#nav [data-v="Atualizações"]:visible,#dx1MobileNav [data-mobile-route="Atualizações"]:visible').click();
    const disclosure = frame.getByText('Enviar e consultar documentos',{exact:true});
    const form = frame.locator('.v476-upload');
    assert.equal(await form.isHidden(),true);
    await disclosure.click();
    const input = form.getByLabel('Arquivo'), submit = form.getByRole('button',{name:'Enviar para revisão'});
    await submit.click();
    await form.getByText('Escolha um arquivo.',{exact:true}).waitFor();
    assert.equal(await form.getByLabel('Tipo de documento').inputValue(),'other_financial_document');
    await input.setInputFiles({name:'Example.pdf',mimeType:'application/pdf',buffer:sample});
    await submit.click();
    await form.getByText(/Não foi possível confirmar o envio/).waitFor();
    await submit.click();
    await form.getByText('Este arquivo já foi recebido.',{exact:true}).waitFor();
    await frame.getByRole('heading',{name:'Example.pdf'}).waitFor();
    await input.setInputFiles({name:'Renamed.pdf',mimeType:'application/pdf',buffer:sample});
    await submit.click();
    await form.getByText('Este arquivo já foi recebido.',{exact:true}).waitFor();
    assert.deepEqual([uploads,receipts],[1,1]);
    assert.equal(await form.evaluate(el => Array.from(el.querySelectorAll('input,select,button')).every(control => {
      const rect = control.getBoundingClientRect();
      return rect.width > 0 && rect.left >= 0 && rect.right <= innerWidth+1;
    })),true);
    assert.deepEqual(session.writes,[]);
  } finally { await session.ctx.close(); }
}
(async () => {
  for (const engine of [chromium, webkit]) {
    const browser = await engine.launch();
    try { for (const width of [360,1366]) await verify(browser,width); }
    finally { await browser.close(); }
  }
})().catch(error => { console.error(error); process.exitCode=1; });
