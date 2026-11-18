'use strict';

const assert = require('node:assert/strict');
const { chromium, webkit } = require('playwright');
const release = process.env.LTS_FLOW_RELEASE || 'v480';
process.env.LTS_FLOW_RELEASE = release;
const { setup } = require('./lts_v382_browser.cjs');
const { product } = require('./lts_v379_fixtures.cjs');
const base = process.env.LTS_BROWSER_BASE || 'http://127.0.0.1:8788';

async function verify(browser, width) {
  const ownerId = '00000000-0000-4000-8000-000000000001';
  const { ctx, page, writes } = await setup(browser, width, 820);
  const exampleOld = 'sample-current-only';
  const exampleNew = 'sample-new-only';
  let outcome = 'rejected';
  const requests = [];
  let identityReads = 0;
  try {
    const refresh = { state: 'ready', required: false, cached_available: true,
      request_version: '2', completed_version: '2' };
    await ctx.route('**/rpc/lts_browser_product_v1', route => route.fulfill({ json: {ok:true, mvp:product(), refresh} }));
    await ctx.route('**/rpc/lts_browser_product_refresh_status_v415', route => route.fulfill({ json: {ok:true, refresh} }));
    await ctx.route('**/auth/v1/user', async route => {
      const req = route.request();
      if (req.method() === 'GET') {
        identityReads++;
        return route.fulfill({ json:{id:ownerId} });
      }
      const data = req.postDataJSON();
      requests.push({
        method: req.method(),
        identity: req.headers().authorization === 'Bearer synthetic-only-access',
        previous: data.current_password === exampleOld,
        newValue: data.password === exampleNew,
        onlyPassword: Object.keys(data).sort().join('|') === 'current_password|password'
      });
      if (outcome === 'failed') return route.abort();
      if (outcome === 'rejected') return route.fulfill({ status:422, json:{error_code:'weak_password'} });
      return route.fulfill({ json: {id:ownerId} });
    });
    await page.goto(base + '/mobile/?source=home-screen', {waitUntil:'domcontentloaded'});
    await page.waitForFunction(() => document.querySelector('#wealth')?.contentDocument?.querySelector('#shell')?.contentDocument?.body?.dataset.ltsBootState === 'ready');
    const frame = page.frames().find(f => new URL(f.url()).pathname.endsWith('/releases/' + release + '/index.html'));
    assert(frame);
    const open = frame.getByRole('button', {name:'Alterar senha', exact:true});
    const dialog = frame.getByRole('dialog', {name:'Alterar senha'});
    assert(await open.isVisible());
    assert(await open.evaluate(el => {
      const box = el.getBoundingClientRect();
      const target = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);
      return target === el || el.contains(target);
    }), 'the account action has a clear pointer target');

    if (width === 360) {
      await frame.evaluate(() => {
        const key = 'lts_supabase_session_v1';
        const olderSession = JSON.parse(localStorage.getItem(key));
        delete olderSession.user;
        localStorage.setItem(key, JSON.stringify(olderSession));
      });
    }
    await open.click();
    const current = dialog.getByLabel('Senha atual', {exact:true});
    const next = dialog.getByLabel('Nova senha', {exact:true});
    const repeat = dialog.getByLabel('Confirmar nova senha', {exact:true});
    const save = dialog.getByRole('button', {name:'Salvar senha'});
    const status = dialog.getByRole('status');
    assert(await dialog.evaluate(el => el.getBoundingClientRect().left >= 0 && el.getBoundingClientRect().right <= innerWidth));
    const fill = async confirm => {
      await current.fill(exampleOld);
      await next.fill(exampleNew);
      await repeat.fill(confirm);
    };
    await fill('different-sample');
    await save.click();
    assert.equal(requests.length, 0);
    await repeat.fill(exampleNew);
    await save.click();
    await status.filter({hasText:'Escolha uma senha mais forte e tente novamente.'}).waitFor();

    outcome = 'failed';
    await save.click();
    await status.filter({hasText:/A conexão foi interrompida/}).waitFor();
    await dialog.getByRole('button',{name:'Fechar'}).click();
    await open.click();
    assert.equal(await current.inputValue(), '');
    assert.equal(await next.inputValue(), '');

    outcome = 'confirmed';
    await fill(exampleNew);
    await save.click();
    await status.filter({hasText:'Senha alterada. Use a nova senha no próximo acesso.'}).waitFor();
    assert.equal(await current.inputValue(), '');
    assert.equal(await next.inputValue(), '');
    assert.equal(await repeat.inputValue(), '');
    assert.equal(await save.isVisible(),false);
    assert.equal(requests.length,3);
    if (width === 360) assert(identityReads > 0, 'older session verified by the provider');
    for (const req of requests) assert.deepEqual(req,{method:'PUT',identity:true,previous:true,newValue:true,onlyPassword:true});
    assert.deepEqual(writes, []);
    await dialog.getByRole('button',{name:'Fechar'}).click();
    await frame.locator('#logout').click();
    await frame.locator('#signin').waitFor({state:'visible'});
    assert.equal(await open.isVisible(),false);
    console.log('OK', browser.browserType().name(), width);
  } finally {
    await ctx.close();
  }
}

(async () => {
  for (const engine of [chromium, webkit]) {
    const executablePath = engine === chromium ? process.env.LTS_TEST_CHROMIUM : undefined;
    const browser = await engine.launch({headless:true, executablePath});
    try { for (const width of [360, 1366]) await verify(browser,width); }
    finally { await browser.close(); }
  }
})().catch(error => { console.error(error.message); process.exitCode=1; });
