'use strict';
const test = require('node:test'), assert = require('node:assert/strict');
const api = require('../../lts-v415-product-refresh.js');
const flush = async () => { for (let i = 0; i < 30; i++) await Promise.resolve(); };
const deferred = () => { let resolve, reject; const promise = new Promise((a, b) => { resolve = a; reject = b; }); return { promise, resolve, reject }; };
const status = (state = 'pending', extra = {}) => ({ state, required: state !== 'ready', cached_available: true,
  request_version: '2', completed_version: state === 'ready' ? '2' : '1', cached_refreshed_at: '2026-11-05T21:00:00Z', ...extra });
const product = (refresh = status(), mvp = { balance: 1234.56, rows: [{ amount: -90.5, date: '2026-11-06' }] }) => ({ ok: true, mvp, refresh });
function harness(t) {
  let visible = true, id = 0;
  const timers = new Map(), calls = [], installed = [], completed = [], states = [], handlers = new Map();
  const c = api.create({
    visible: () => visible,
    setTimeout: (fn, ms) => { timers.set(++id, { fn, ms }); return id; }, clearTimeout: key => timers.delete(key),
    rpc: (name, args, signal) => { calls.push({ name, args, signal }); const fn = handlers.get(name); assert(fn, 'Unexpected RPC: ' + name); return fn(); },
    onProduct: (payload, metadata) => installed.push({ payload, metadata }), onReady: s => completed.push(s), onState: s => states.push(s)
  });
  t.after(() => c.dispose());
  return { c, timers, calls, installed, completed, states,
    visible(value) { visible = value; },
    respond(name, value) { handlers.set(name, typeof value === 'function' ? value : () => ({ data: structuredClone(value) })); },
    async tick() { assert.equal(timers.size, 1, 'One bounded timer'); const [key, task] = timers.entries().next().value; timers.delete(key); task.fn(); await flush(); return task.ms; }
  };
}

test('new protocol rejects unsafe, missing and malformed versions; only absent envelope is legacy', () => {
  for (const value of [undefined, null, -1, 1.5, Number.MAX_SAFE_INTEGER + 1, '', '1.2', 'NaN', {}, '1e9']) {
    assert.throws(() => api.normalize(status('ready', { request_version: value })), /Invalid refresh status/);
    assert.throws(() => api.normalize(status('ready', { completed_version: value })), /Invalid refresh status/);
  }
  assert(!api.ready({ state: 'ready', required: false, cached_available: true, legacy: true }));
  assert(api.ready(api.normalize(null, {}, true)));
  assert(api.ready(api.normalize(status('ready', { request_version: '900719925474099300', completed_version: '900719925474099301' }))));
  assert(!api.ready(api.normalize(status('ready', { request_version: '3', completed_version: '2' }))));
  assert(!api.ready(api.normalize(status('ready'), { refresh_required: true }, true)));
});

test('fresh product remains unchanged, without a timer or healthy banner', async t => {
  const h = harness(t), payload = product(status('ready')), original = structuredClone(payload);
  h.c.acceptProduct(payload);
  assert.equal(h.c.snapshot().pending, false); assert.equal(h.timers.size, 0); assert.equal(h.calls.length, 0);
  assert.deepEqual(payload, original); assert.equal(h.installed.length, 0);
});

test('pending snapshots poll only lightweight status, back off 10/20/30s and fetch one ready product', async t => {
  const h = harness(t), fresh = product(status('ready'));
  h.respond(api.STATUS_RPC, { ok: true, refresh: status('running') }); h.respond(api.PRODUCT_RPC, fresh);
  h.c.acceptProduct(product());
  assert.equal(await h.tick(), 10000); assert.equal(await h.tick(), 20000); assert.equal(await h.tick(), 30000);
  assert.deepEqual(h.calls.map(x => x.name), Array(3).fill(api.STATUS_RPC)); assert.equal(h.installed.length, 0);
  h.respond(api.STATUS_RPC, { ok: true, refresh: status('ready') }); await h.tick();
  assert.equal(h.calls.filter(x => x.name === api.PRODUCT_RPC).length, 1); assert.equal(h.timers.size, 0);
  assert.deepEqual(h.installed[0].payload, fresh); assert.equal(h.completed.length, 1); assert.equal(h.c.snapshot().pending, false);
  await Promise.all([h.c.poll(), h.c.poll(), h.c.poll()]);
  assert.equal(h.calls.filter(x => x.name === api.PRODUCT_RPC).length, 1, 'Ready same version is never fetched twice');
});

test('initializing has no synthetic financial object and installs the complete product only when ready', async t => {
  const h = harness(t); h.c.acceptProduct(product(status('pending', { cached_available: false }), null));
  assert.equal(h.c.snapshot().hasProduct, false); assert.equal(h.c.snapshot().pending, true);
  h.respond(api.STATUS_RPC, { ok: true, refresh: status('ready') }); h.respond(api.PRODUCT_RPC, product(status('ready')));
  await h.tick(); assert.equal(h.installed.length, 1); assert.equal(h.c.snapshot().hasProduct, true);
});

test('backend failure remains actionable and simultaneous retry clicks coalesce one request', async t => {
  const h = harness(t), waiting = deferred(); h.c.acceptProduct(product(status('failed')));
  h.respond(api.REQUEST_RPC, () => waiting.promise);
  const first = h.c.retry(), second = h.c.retry(); assert.equal(first, second); await flush();
  assert.equal(h.calls.length, 1); assert.equal(h.calls[0].name, api.REQUEST_RPC); assert.deepEqual(h.calls[0].args, {});
  waiting.resolve({ data: { ok: true, refresh: status('pending', { request_version: '3' }) } }); await first;
  assert.equal(h.c.snapshot().refresh.state, 'pending'); assert.equal(h.installed.length, 0);
});

test('network status failure stops polling; explicit retry verifies before fetching', async t => {
  const h = harness(t); h.c.acceptProduct(product()); h.respond(api.STATUS_RPC, () => ({ error: { code: 'NETWORK', status: 503 } }));
  await h.tick(); assert.equal(h.c.snapshot().error, 'status'); assert.equal(h.timers.size, 0);
  h.respond(api.STATUS_RPC, { ok: true, refresh: status('ready') }); h.respond(api.PRODUCT_RPC, product(status('ready')));
  await h.c.retry(); assert.equal(h.installed.length, 1); assert.equal(h.c.snapshot().pending, false);
  assert.equal(h.calls.filter(x => x.name === api.REQUEST_RPC).length, 0);
});

test('status calls are coalesced while in flight', async t => {
  const h = harness(t), waiting = deferred(); h.c.acceptProduct(product()); h.respond(api.STATUS_RPC, () => waiting.promise);
  const first = h.c.poll(), second = h.c.poll(); assert.equal(first, second); await flush(); assert.equal(h.calls.length, 1);
  waiting.resolve({ data: { ok: true, refresh: status('running') } }); await first; assert.equal(h.timers.size, 1);
});

test('ready then hidden during product fetch retries the same version and ignores aborted late data', async t => {
  const h = harness(t), first = deferred(), second = deferred(); let products = 0;
  h.c.acceptProduct(product()); h.respond(api.STATUS_RPC, { ok: true, refresh: status('ready') });
  h.respond(api.PRODUCT_RPC, () => (++products === 1 ? first : second).promise);
  const originalPoll = h.c.poll(); await flush();
  assert.equal(products, 1); assert.equal(h.c.snapshot().pending, true, 'Old snapshot remains visibly pending during replacement');
  const oldSignal = h.calls.find(x => x.name === api.PRODUCT_RPC).signal;
  h.visible(false); h.c.pause(); await flush(); assert.equal(oldSignal.aborted, true); assert.equal(h.timers.size, 0);
  h.visible(true); h.c.resume(); await flush(); assert.equal(products, 2, 'Resume fetches unfinished version');
  first.resolve({ data: product(status('ready'), { balance: 999999 }) }); await originalPoll; await flush(); assert.equal(h.installed.length, 0);
  second.resolve({ data: product(status('ready')) }); await flush(); assert.equal(h.installed.length, 1);
  assert.equal(h.installed[0].payload.mvp.balance, 1234.56); assert.equal(h.c.snapshot().pending, false);
});

test('logout and unmount cancel in-flight work and late responses cannot install data', async t => {
  const h = harness(t), waiting = deferred(); h.c.acceptProduct(product()); h.respond(api.STATUS_RPC, () => waiting.promise);
  const poll = h.c.poll(); await flush(); h.c.stop(); await flush(); assert.equal(h.calls[0].signal.aborted, true);
  waiting.resolve({ data: { ok: true, refresh: status('ready') } }); await poll;
  assert.equal(h.c.snapshot().active, false); assert.equal(h.installed.length, 0); assert.equal(h.timers.size, 0);
  h.c.dispose(); h.c.resume(); assert.equal(h.calls.length, 1);
});

test('automatic polling has an attempt cap and a user action can resume it', async t => {
  const h = harness(t); h.c.acceptProduct(product()); h.respond(api.STATUS_RPC, { ok: true, refresh: status('running') });
  for (let i = 0; i < api.MAX_STATUS_POLLS; i++) await h.tick();
  assert.equal(h.calls.length, api.MAX_STATUS_POLLS); assert.equal(h.c.snapshot().error, 'waiting'); assert.equal(h.timers.size, 0);
  await h.c.retry(); assert.equal(h.calls.length, api.MAX_STATUS_POLLS + 1); assert.equal(h.c.snapshot().pollAttempts, 1);
  assert.equal(h.timers.size, 1);
});

test('hanging network calls have a deadline and are aborted without background full reads', async t => {
  const h = harness(t), waiting = deferred(); h.c.acceptProduct(product()); h.respond(api.STATUS_RPC, () => waiting.promise);
  const call = h.c.poll(); await flush(); assert.equal(await h.tick(), 10000); await call;
  assert.equal(h.calls[0].signal.aborted, true); assert.equal(h.c.snapshot().error, 'status'); assert.equal(h.timers.size, 0);
});

test('fresh focus checks do not exhaust the pending job budget or fetch heavy payloads', async t => {
  const h = harness(t); h.c.acceptProduct(product(status('ready'))); h.respond(api.STATUS_RPC, { ok: true, refresh: status('ready') });
  for (let i = 0; i < 25; i++) { h.c.resume(); await flush(); }
  assert.equal(h.calls.length, 25); assert.equal(h.c.snapshot().pollAttempts, 0); assert.equal(h.c.snapshot().pending, false);
  assert.equal(h.installed.length, 0);
});

test('a ready status followed by contradictory pending product stops instead of full-payload polling', async t => {
  const h = harness(t); h.c.acceptProduct(product()); h.respond(api.STATUS_RPC, { ok: true, refresh: status('ready') }); h.respond(api.PRODUCT_RPC, product());
  await h.c.poll(); assert.equal(h.c.snapshot().error, 'confirmation'); assert.equal(h.installed.length, 0); assert.equal(h.timers.size, 0);
  assert.equal(h.calls.filter(x => x.name === api.PRODUCT_RPC).length, 1);
});

test('a new job can supersede a completed job while product is loading; obsolete snapshots are rejected', async t => {
  const h = harness(t), waiting = deferred(); h.c.acceptProduct(product()); h.respond(api.STATUS_RPC, { ok: true, refresh: status('ready') });
  h.respond(api.PRODUCT_RPC, () => waiting.promise); const call = h.c.poll(); await flush();
  h.c.observeRefresh(status('pending', { request_version: '3', completed_version: '2' }));
  waiting.resolve({ data: product(status('ready')) }); await call;
  assert.equal(h.installed.length, 0); assert.equal(h.c.snapshot().refresh.request_version, '3'); assert.equal(h.c.snapshot().pending, true);
});

test('legacy cache flags request verification instead of silently presenting a stale snapshot as fresh', t => {
  const h = harness(t); h.c.acceptProduct({ ok: true, mvp: { balance: 7 }, cache: { refresh_required: true } });
  assert.equal(h.c.snapshot().pending, true); assert.equal(h.timers.size, 1);
});

test('a complete healthy legacy response does not call endpoints absent from its protocol', async t => {
  const h = harness(t); h.c.acceptProduct({ ok: true, mvp: { balance: 7 } });
  await h.c.poll(); h.c.resume(); await flush(); assert.equal(h.calls.length, 0); assert.equal(h.c.snapshot().pending, false);
});
