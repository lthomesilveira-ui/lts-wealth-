'use strict';
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {chromium, webkit} = require('playwright');
const release = process.env.LTS_MOBILE_RELEASE || 'v476';
process.env.LTS_FLOW_RELEASE = release;
const {setup} = require('./lts_v382_browser.cjs');
const {product} = require('./lts_v379_fixtures.cjs');

async function verify(browser, width) {
  const session = await setup(browser, width, 820, '2026-11-18T11:00:00Z');
  const sample = Buffer.from('%PDF-1.4\nSynthetic input\n%%EOF');
  const digest = crypto.createHash('sha256').update(sample).digest('hex');
  const objectPath = '00000000-0000-4000-8000-000000000001/documents/' + digest;
  let uploads = 0, receipts = 0, fileExists = false, interrupt = true;
  try {
    await session.ctx.addInitScript(()=>{
      const original=window.fetch;
      window.fetch=async function(resource,init) {
        if(init?.method==='POST' && String(resource).includes('/storage/v1/object/lts-documents/')){
          window.testSubmittedDocument=Array.from(new Uint8Array(await init.body.arrayBuffer()));
        }
        return original.apply(this,arguments);
      };
    });
    const refresh={state:'ready',required:false,cached_available:true,request_version:'2',completed_version:'2'};
    await session.ctx.route('**/rpc/lts_browser_product_v1',route=>route.fulfill({json:{ok:true,mvp:product(),refresh}}));
    await session.ctx.route('**/rpc/lts_browser_product_refresh_status_v415',route=>route.fulfill({json:{ok:true,refresh}}));
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
      assert.equal(new URL(route.request().url()).pathname, '/storage/v1/object/lts-documents/'+objectPath);
      uploads++; fileExists = true;
      return route.fulfill({json:{Key:objectPath}});
    });
    await session.ctx.route('**/rpc/lts_browser_document_review_queue_v1', route =>
      route.fulfill({json:{contract:'v149-evidence-review-readonly-canonical-v1',queue_documents:receipts,
        items:receipts?[{inbox_id:'sample-receipt',original_name:'Example.pdf',phase:'received'}]:[],
        write_allowed:false,financial_writer_called:false}}));
    await session.page.goto('http://127.0.0.1:8788/mobile/?source=home-screen',{waitUntil:'domcontentloaded'});
    await session.page.waitForFunction(()=>document.querySelector('#wealth')?.contentDocument
      ?.querySelector('#shell')?.contentDocument?.body?.dataset.ltsBootState==='ready');
    const frame=session.page.frames().find(f=>new URL(f.url()).pathname.endsWith('/releases/'+release+'/index.html'));
    assert(frame,'published route reached the candidate');
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
    assert.deepEqual(await frame.evaluate(()=>window.testSubmittedDocument),Array.from(sample));
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
