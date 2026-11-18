'use strict';

const assert = require('node:assert/strict');
const { chromium, webkit } = require('playwright');
const { setup } = require('./lts_v382_browser.cjs');
const base = process.env.LTS_BROWSER_BASE || 'http://127.0.0.1:8788';

async function verifyEmptyProfile(browser, width) {
  const { ctx, page, writes } = await setup(browser, width, 820);
  const sessionId = '00000000-0000-4000-8000-000000000001';
  const refresh = { state: 'pending', required: true, cached_available: false,
    request_version: '1', completed_version: '0', attempts: 0 };
  let changes = 0;
  try {
    await ctx.route('**/rpc/lts_browser_product_v1', route =>
      route.fulfill({ json: { ok: true, mvp: null, refresh } }));
    await ctx.route('**/rpc/lts_browser_product_refresh_status_v415', route =>
      route.fulfill({ json: { ok: true, refresh } }));
    await ctx.route('**/auth/v1/user', route => {
      const request = route.request();
      if (request.method() === 'PUT') {
        assert.equal(request.headers().authorization, 'Bearer synthetic-only-access');
        assert.deepEqual(request.postDataJSON(), { current_password: 'sample-before', password: 'sample-after' });
        changes++;
      }
      return route.fulfill({ json: { id: sessionId } });
    });
    await page.goto(base + '/mobile/?source=home-screen');
    const frame = page.frameLocator('#wealth').frameLocator('#shell');
    const open = frame.getByRole('button', { name: 'Alterar senha', exact: true });
    const dialog = frame.getByRole('dialog', { name: 'Alterar senha' });
    await frame.getByRole('heading', { name: 'Preparando seus dados' }).waitFor();
    await open.click();
    await dialog.waitFor({ state: 'visible', timeout: 5000 });
    const current = dialog.getByLabel('Senha atual', { exact: true });
    await current.fill('sample-before');
    // A background refresh ends with no complete financial snapshot.
    Object.assign(refresh, { state: 'failed', attempts: 3, error_code: 'refresh_failed' });
    await frame.locator('#ltsBootRecovery h1').filter({ hasText: 'Não foi possível preparar seus dados' })
      .waitFor({ state: 'attached', timeout: 35000 });
    assert(await dialog.isVisible(), 'the background change must preserve the open account form');
    assert.equal(await current.inputValue(), 'sample-before');
    await dialog.getByLabel('Nova senha', { exact: true }).fill('sample-after');
    await dialog.getByLabel('Confirmar nova senha', { exact: true }).fill('sample-after');
    await dialog.getByRole('button', { name: 'Salvar senha' }).click();
    await dialog.getByRole('status').filter({ hasText: 'Senha alterada.' }).waitFor();
    assert.equal(changes, 1);
    assert.deepEqual(writes, []);
    await dialog.getByRole('button', { name: 'Fechar' }).click();
    await open.click();
    assert.equal(await current.inputValue(), '');
    await dialog.getByRole('button', { name: 'Cancelar' }).click();
    await frame.getByRole('button', { name: 'Sair', exact: true }).click();
    await frame.locator('#signin').waitFor({ state: 'visible' });
    assert.equal(await open.isVisible(), false);
    console.log('OK empty profile', browser.browserType().name(), width);
  } finally {
    await ctx.close();
  }
}

(async () => {
  for (const engine of [chromium, webkit]) {
    const executablePath = engine === chromium ? process.env.LTS_TEST_CHROMIUM : undefined;
    const browser = await engine.launch({ headless: true, executablePath });
    try { await Promise.all([360, 1366].map(width => verifyEmptyProfile(browser, width))); }
    finally { await browser.close(); }
  }
})().catch(error => { console.error(error.message); process.exitCode = 1; });
