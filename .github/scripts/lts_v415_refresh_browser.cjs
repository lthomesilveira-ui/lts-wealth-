'use strict';
process.env.LTS_FLOW_RELEASE = 'v415';
const fs = require('node:fs'), assert = require('node:assert/strict'), crypto = require('node:crypto');
const fixture = require('./lts_v379_fixtures.cjs'), baseResponse = fixture.response, projection = require('./lts_v412_projection_fixtures.cjs');
const { setup, open } = require('./lts_v382_browser.cjs'), { chromium, webkit } = require('playwright');
const out = 'qa/v415-refresh', base = process.env.LTS_BROWSER_BASE || 'http://127.0.0.1:8788';
fs.mkdirSync(out, { recursive: true });
fixture.response = (name, args) => {
  if (name === 'lts_browser_projection_policy_v412') return projection.policy();
  // V296's product fixture has four actions while its inherited cockpit RPC has
  // none. This parity scenario must provide the same source through both paths.
  if (name === 'lts_browser_dashboard_cockpit_v1') return structuredClone(fixture.product().dashboard_cockpit);
  return baseResponse(name, args);
};
const hash = value => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
function financialFlow(value) {
  const result = structuredClone(value);
  // The preserved legacy cachedFlow reader keeps the larger source window here.
  // Compare all other fields exactly, including requested from/to, every date,
  // monetary value, row, event and completeness flag.
  delete result.current_future.from; delete result.current_future.to;
  return result;
}
function assertWindowRows(value) {
  assert.equal(value.from, '2027-01-01'); assert.equal(value.to, '2027-01-31');
  for (const part of ['historical', 'current_future']) {
    for (const row of value[part].days) assert(row.date >= value.from && row.date <= value.to, 'Day inside requested window');
    for (const row of value[part].events) { const date = String(row.event_date).slice(0, 10); assert(date >= value.from && date <= value.to, 'Event inside requested window'); }
  }
}
const refresh = (state = 'pending', extra = {}) => ({ state, required: state !== 'ready', cached_available: true,
  request_version: '2', completed_version: state === 'ready' ? '2' : '1', attempts: 1,
  requested_at: '2026-11-05T21:01:00Z', started_at: null, completed_at: null, next_attempt_at: null, error_code: null,
  cached_refreshed_at: '2026-11-05T21:00:00Z', server_today: '2026-11-05', ...extra });
async function routes(h, initial) {
  const state = { refresh: initial, products: 0, statuses: 0, requests: 0, manual: 0, failStatus: false };
  const send = (route, value, code = 200) => route.fulfill({ status: code, contentType: 'application/json', body: JSON.stringify(value) });
  await h.ctx.route('**/rest/v1/rpc/lts_browser_product_v1', route => {
    state.products++;
    const withheld = !!state.nextProductMissing; state.nextProductMissing = false;
    if (state.nextProductRefresh) { state.refresh = state.nextProductRefresh; state.nextProductRefresh = null; }
    return send(route, { ok: true, mvp: state.refresh.cached_available && !withheld ? fixture.product() : null,
      refresh: state.refresh, cache: { refresh_required: state.refresh.required, is_stale: state.refresh.required, refreshed_at: state.refresh.cached_refreshed_at } });
  });
  await h.ctx.route('**/rest/v1/rpc/lts_browser_product_refresh_status_v415', route => {
    state.statuses++; assert.deepEqual(JSON.parse(route.request().postData() || '{}'), {});
    return state.failStatus ? send(route, { message: 'Synthetic unavailable' }, 503) : send(route, { ok: true, refresh: state.refresh });
  });
  await h.ctx.route('**/rest/v1/rpc/lts_browser_product_refresh_request_v415', route => {
    state.requests++; assert.deepEqual(JSON.parse(route.request().postData() || '{}'), {});
    state.refresh = { ...state.refresh, state: 'pending', required: true, request_version: String(BigInt(state.refresh.request_version) + 1n) };
    return send(route, { ok: true, refresh: state.refresh });
  });
  await h.ctx.route('**/rest/v1/rpc/lts_browser_projection_refresh_v412', route => {
    state.manual++; assert.deepEqual(JSON.parse(route.request().postData() || '{}'), {});
    state.refresh = refresh('pending', { request_version: String(BigInt(state.refresh.request_version) + 1n), completed_version: state.refresh.completed_version });
    return send(route, { ...projection.policy(), refreshed: true, refresh: state.refresh });
  });
  return state;
}
async function go(f, view) {
  await f.locator('#nav [data-v="' + view + '"]:visible,#dx1MobileNav [data-mobile-route="' + view + '"]:visible').click();
  await f.waitForFunction(v => V === v, view);
}
async function dashboardSnapshot(h, f) {
  // dashboard178 marks the superseded V168 loading flag false on each render.
  // Wait for the actual sequential readers before comparing their full output.
  await f.waitForFunction(() => ['wealth', 'forecast', 'awards', 'dashboardReport'].every(key => __LTS_V178_STATE[key].status === 'ready')
    && !['idle', 'loading'].includes(__LTS_V178_STATE.cash.status));
  await h.page.waitForLoadState('networkidle');
  return f.evaluate(() => ({
    product: structuredClone(D),
    readers: Object.fromEntries(['cash', 'wealth', 'forecast', 'awards', 'dashboardReport'].map(key => {
      const slot = __LTS_V178_STATE[key]; return [key, { status: slot.status, date: slot.date, data: structuredClone(slot.data) }];
    })),
    legacy: structuredClone(__LTS_V168_STATE.dashboard.data),
    visibleText: document.querySelector('.v168-dashboard').innerText
  }));
}
async function geometry(f) {
  return f.evaluate(() => ({ width: innerWidth, scroll: document.documentElement.scrollWidth,
    banner: document.querySelector('#ltsRefreshStatusV415').getBoundingClientRect().toJSON(),
    sourceOpen: document.querySelectorAll('.v337-source[open],.v412-origin[open]').length,
    controls: document.querySelector('.flow-sticky-controls')?.getBoundingClientRect().toJSON(),
    buttons: [...document.querySelectorAll('#ltsRefreshStatusV415 button')].map(x => x.getBoundingClientRect().toJSON()) }));
}
async function checkBanner(f, width, pending) {
  const banner = f.locator('#ltsRefreshStatusV415'), measured = await geometry(f);
  assert(measured.scroll <= width + 2, JSON.stringify(measured)); assert.equal(measured.sourceOpen, 0);
  if (pending) {
    assert(await banner.isVisible()); const text = await banner.innerText();
    assert.match(text, /Atualizando seus dados/); assert.match(text, /Última atualização: 05\/11/);
    assert(!/cache|worker|fila|payload|backend|posição de|SQL|RPC/i.test(text));
    assert(measured.banner.height <= 90, 'Compact pending banner: ' + measured.banner.height);
  } else { assert(!(await banner.isVisible())); assert.equal(measured.banner.height, 0, 'No healthy banner height'); }
  return measured;
}
async function recordFailure(h, f, label, error) {
  await h.page.screenshot({ path: out + '/' + label + '-failure.png', fullPage: true }).catch(() => {});
  fs.writeFileSync(out + '/' + label + '-failure.json', JSON.stringify({ error: error.stack, errors: h.errors,
    reads: h.reads.slice(-30),
    body: f ? await f.locator('body').innerText().catch(() => null) : null,
    state: f ? await f.evaluate(() => ({ boot: BOOT.phase, hasProduct: !!D, view: V, refresh: __LTS_V415_REFRESH.snapshot(),
      readers: Object.fromEntries(['cash', 'wealth', 'forecast', 'awards', 'dashboardReport'].map(key => {
        const slot = window.__LTS_V178_STATE?.[key]; return [key, slot && { status: slot.status, date: slot.date, token: slot.token, error: slot.error }];
      })) })).catch(() => null) : null }, null, 2));
}
async function runCached(browser, engine, width) {
  const h = await setup(browser, width, 980, '2026-11-05T21:02:00Z'), label = engine + '-' + width;
  const state = await routes(h, refresh()); let f;
  try {
    f = await open(h, 'v415', true);
    await f.waitForFunction(() => __LTS_V412_PROJECTION?.status === 'ready');
    const dashboardBefore = await dashboardSnapshot(h, f);
    const pendingDashboard = await checkBanner(f, width, true);
    await h.page.screenshot({ path: out + '/' + label + '-dashboard-pending.png' });
    await go(f, 'Fluxo Diário');
    await f.evaluate(() => loadFlowRange('2027-01-01', '2027-01-31'));
    await f.waitForFunction(() => !FLOWLOADING && FLOWQ?.to === '2027-01-31');
    const before = await f.evaluate(() => structuredClone(FLOWQ)), pendingFlow = await checkBanner(f, width, true);
    assertWindowRows(before);
    assert.deepEqual({ from: before.current_future.from, to: before.current_future.to }, { from: '2026-10-31', to: '2031-12-31' }, 'Explicit preserved legacy source coverage');
    assert(pendingFlow.controls.height < 450, JSON.stringify(pendingFlow));
    assert.equal(await f.locator('.v382-period[open]').count(), 0);
    await h.page.screenshot({ path: out + '/' + label + '-flow-pending.png' });
    const productsBefore = state.products;
    state.refresh = refresh('ready');
    // A fresh invalidation can occur after the lightweight readiness check.
    state.nextProductRefresh = refresh('pending', { request_version: '3', completed_version: '2', cached_available: true });
    state.nextProductMissing = true;
    await f.evaluate(() => __LTS_V415_REFRESH.poll());
    await f.waitForFunction(() => BOOT.phase === 'preparing' && D === null);
    assert(!(await f.locator('#app').isVisible()), 'Old numbers are withdrawn when current completeness cannot be proved');
    assert(await f.getByText('Preparando seus dados', { exact: true }).isVisible());
    assert.equal(state.products, productsBefore + 1);
    await h.page.screenshot({ path: out + '/' + label + '-rendered-to-preparing.png' });
    state.refresh = refresh('ready', { request_version: '3', completed_version: '3' });
    await f.evaluate(() => __LTS_V415_REFRESH.poll());
    await f.waitForFunction(() => !__LTS_V415_REFRESH.snapshot().pending && !FLOWLOADING && FLOWQ?.to === '2027-01-31');
    assert.equal(state.products, productsBefore + 2, 'Each verified completion is fetched once, including the superseded completion');
    assert.equal(await f.evaluate(() => V), 'Fluxo Diário', 'Recovery returns to the previously visible view');
    const after = await f.evaluate(() => FLOWQ);
    assertWindowRows(after);
    assert.deepEqual({ from: after.current_future.from, to: after.current_future.to }, { from: '2027-01-01', to: '2027-01-31' }, 'New reader coverage matches the exact requested period');
    fs.writeFileSync(out + '/' + label + '-flow-parity.json', JSON.stringify({ before, after }, null, 2));
    assert.deepEqual(financialFlow(after), financialFlow(before), 'Every financial field, requested date and completeness flag unchanged');
    assert.deepEqual(await f.evaluate(() => ({ from: FLOWFROM, to: FLOWTO })), { from: '2027-01-01', to: '2027-01-31' });
    const freshFlow = await checkBanner(f, width, false);
    await h.page.screenshot({ path: out + '/' + label + '-flow-fresh.png' });
    // Existing manual action queues maintenance; it cannot announce completed data.
    await f.waitForFunction(() => __LTS_V412_PROJECTION.status === 'ready');
    const manualProducts = state.products;
    await f.locator('[data-v412-policy="flow"] [data-v412-refresh]').click();
    await f.waitForFunction(() => __LTS_V412_PROJECTION.status === 'queued');
    assert.equal(state.manual, 1); assert.equal(state.products, manualProducts);
    assert.match(await f.locator('[data-v412-refresh]').innerText(), /Atualização em andamento/);
    assert(await f.locator('[data-v412-refresh]').isDisabled()); await checkBanner(f, width, true);
    state.refresh = { ...state.refresh, state: 'ready', required: false, completed_version: state.refresh.request_version,
      cached_refreshed_at: '2026-11-05T21:03:00Z' };
    await f.evaluate(() => __LTS_V415_REFRESH.poll());
    await f.waitForFunction(() => !__LTS_V415_REFRESH.snapshot().pending && !FLOWLOADING && __LTS_V412_PROJECTION.status === 'ready');
    const afterManual = await f.evaluate(() => FLOWQ); assertWindowRows(afterManual);
    assert.deepEqual({ from: afterManual.current_future.from, to: afterManual.current_future.to }, { from: '2027-01-01', to: '2027-01-31' });
    assert.equal(state.products, manualProducts + 1); assert.deepEqual(financialFlow(afterManual), financialFlow(before));
    await go(f, 'Dashboard');
    const dashboardAfter = await dashboardSnapshot(h, f);
    fs.writeFileSync(out + '/' + label + '-dashboard-parity.json', JSON.stringify({ before: dashboardBefore, after: dashboardAfter }, null, 2));
    assert.deepEqual(dashboardAfter.product, dashboardBefore.product, 'Complete product is unchanged');
    assert.deepEqual(dashboardAfter.readers, dashboardBefore.readers, 'Every active Dashboard financial reader is unchanged');
    for (const key of ['cockpit', 'wealth', 'expense']) assert.deepEqual(dashboardAfter.legacy[key], dashboardBefore.legacy[key], key);
    assert.equal(dashboardAfter.visibleText, dashboardBefore.visibleText, 'Every visible Dashboard value, date and warning is unchanged');
    const freshDashboard = await checkBanner(f, width, false);
    await h.page.screenshot({ path: out + '/' + label + '-dashboard-fresh.png' });
    assert.deepEqual(h.errors, []); assert.deepEqual(h.writes, []);
    return { pass: true, engine, width, scenario: 'cached', stable_mobile_entry: true,
      pending_dashboard_height: pendingDashboard.banner.height, pending_flow_height: pendingFlow.banner.height,
      healthy_dashboard_height: freshDashboard.banner.height, healthy_flow_height: freshFlow.banner.height,
      collapsed_flow_controls_height: pendingFlow.controls.height, exact_flow_range_preserved: true,
      rendered_snapshot_withdrawn_on_missing_current_completeness: true,
      financial_response_sha256: hash(financialFlow(before)), financial_response_unchanged: true, source_window_metadata_retained_by_legacy_cache: true, manual_request_queued: true,
      complete_product_unchanged: true, all_active_dashboard_readers_unchanged: true, all_dashboard_visible_text_unchanged: true,
      products: state.products, statuses: state.statuses, manual_refreshes: state.manual,
      synthetic_http: true, private_session: false, physical_iphone: false };
  } catch (error) { await recordFailure(h, f, label, error); throw error; }
  finally { await h.ctx.close(); }
}
async function runMissing(browser, engine, width) {
  const h = await setup(browser, width, 980, '2026-11-05T21:02:00Z'), label = engine + '-' + width + '-initializing';
  const state = await routes(h, refresh('pending', { cached_available: false, cached_refreshed_at: null })); let f;
  try {
    await h.page.goto(base + '/mobile/?source=home-screen', { waitUntil: 'domcontentloaded' });
    await h.page.waitForFunction(() => document.getElementById('wealth')?.contentDocument?.getElementById('shell')?.contentDocument?.body?.dataset.ltsBootState === 'preparing');
    f = h.page.frames().find(frame => new URL(frame.url()).pathname.endsWith('/releases/v415/index.html')); assert(f);
    await f.waitForFunction(() => __LTS_V365?.installed);
    assert.equal(await f.evaluate(() => D), null);
    assert(await f.getByText('Preparando seus dados', { exact: true }).isVisible());
    assert(!(await f.locator('#app').isVisible())); assert(!(await f.locator('#nav').isVisible()));
    const visibleText = await f.locator('#ltsBootRecovery').innerText();
    assert(!/R\$|0,00|Não foi possível carregar|cache|fila|SQL|RPC/i.test(visibleText));
    assert((await geometry(f)).scroll <= width + 2);
    await h.page.screenshot({ path: out + '/' + label + '.png' });
    state.refresh = { ...state.refresh, state: 'failed', error_code: 'refresh_timed_out' };
    await f.evaluate(() => __LTS_V415_REFRESH.poll());
    assert(await f.getByText('Não foi possível preparar seus dados', { exact: true }).isVisible());
    assert.equal(await f.evaluate(() => D), null);
    await h.page.screenshot({ path: out + '/' + label + '-failed.png' });
    await f.locator('#ltsBootRetry').click(); await f.waitForFunction(() => __LTS_V415_REFRESH.snapshot().refresh.state === 'pending');
    assert.equal(state.requests, 1); assert.equal(state.products, 1);
    state.refresh = refresh('ready', { request_version: state.refresh.request_version, completed_version: state.refresh.request_version });
    await f.evaluate(() => __LTS_V415_REFRESH.poll());
    await f.waitForFunction(() => BOOT.phase === 'ready' && D && !N.classList.contains('hidden'));
    await h.page.waitForLoadState('networkidle'); assert.equal(state.products, 2);
    await checkBanner(f, width, false); assert.deepEqual(h.errors, []); assert.deepEqual(h.writes, []);
    // The unchanged client reports a missing session with its exact local message.
    await f.evaluate(() => localStorage.removeItem('lts_supabase_session_v1'));
    await f.evaluate(() => __LTS_V415_REFRESH.poll());
    await f.waitForFunction(() => BOOT.phase === 'signed-out');
    assert(await f.getByText('Sua sessão terminou. Entre novamente.', { exact: true }).isVisible());
    assert.equal(await f.evaluate(() => __LTS_V415_REFRESH.snapshot().active), false);
    // Restore only the synthetic fixture session to exercise the existing logout.
    await f.evaluate(() => { localStorage.setItem('lts_supabase_session_v1', JSON.stringify({ access_token: 'synthetic-only-access', refresh_token: 'synthetic-only-refresh', expires_at: 4102444800, user: { id: '00000000-0000-4000-8000-000000000001', email: 'viewer@example.invalid' } })); return load(); });
    await f.waitForFunction(() => BOOT.phase === 'ready');
    await f.locator('#logout').focus(); await h.page.keyboard.press('Enter');
    await f.waitForFunction(() => BOOT.phase === 'signed-out');
    assert.equal(await f.evaluate(() => __LTS_V415_REFRESH.snapshot().active), false);
    return { pass: true, engine, width, scenario: 'missing', no_fabricated_financial_payload: true,
      preparing_visible: true, failure_retry_visible: true, one_coalesced_retry: true, recovered: true, expired_session_returns_to_login: true, logout_stops_refresh: true,
      products: state.products, requests: state.requests, synthetic_http: true, private_session: false, physical_iphone: false };
  } catch (error) { await recordFailure(h, f, label, error); throw error; }
  finally { await h.ctx.close(); }
}
(async () => {
  const results = [];
  for (const [engine, type] of [['chromium', chromium], ['webkit', webkit]]) {
    const browser = await type.launch({ headless: true });
    try {
      for (const width of [393, 1366]) for (const run of [runCached, runMissing]) {
        let result;
        try { result = await run(browser, engine, width); }
        catch (error) { result = { pass: false, engine, width, scenario: run === runCached ? 'cached' : 'missing', error: error.stack }; process.exitCode = 1; }
        results.push(result);
        fs.writeFileSync(out + '/result.json', JSON.stringify({ pass: false, completed_runs: results.length, results }, null, 2));
        console.log(JSON.stringify(result));
      }
    } finally { await browser.close(); }
  }
  fs.writeFileSync(out + '/result.json', JSON.stringify({ pass: results.length === 8 && results.every(result => result.pass), results }, null, 2));
})().catch(error => { console.error(error); process.exitCode = 1; });
