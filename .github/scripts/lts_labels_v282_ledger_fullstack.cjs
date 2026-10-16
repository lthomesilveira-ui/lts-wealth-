'use strict';
// Synthetic-only, real ordered-stack regression. No production database is contacted.
// From a repository root served on loopback: node this-file.cjs
// --static-check validates release bytes and fixture/barrier contracts without Playwright/network.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const {EventEmitter} = require('node:events');
const fixture = require('./lts_labels_v282_synthetic_fixture.cjs');
const labelOverlay = require('./lts_labels_v282_overlay.cjs');
const labelScenarios = require('./lts_labels_v282_scenarios.cjs');

const RELEASE = process.env.LTS_RELEASE || 'v282';
const BASELINE = process.env.LTS_LEDGER_BASELINE || 'v281';
for (const id of [RELEASE, BASELINE]) assert(/^[a-zA-Z0-9_-]+$/.test(id), 'Safe release identifier');
const BASE = new URL(process.env.LTS_LEDGER_BASE || 'http://127.0.0.1:8788');
assert.equal(BASE.protocol, 'http:');
assert(['127.0.0.1', 'localhost', '[::1]'].includes(BASE.hostname), 'Loopback only');
assert(!BASE.username && !BASE.password && !BASE.search && !BASE.hash);
const ORIGIN = 'https://tadhkamnwtsbdozwkyut.supabase.co';
const QA = path.resolve(process.env.LTS_LEDGER_QA_DIR || 'qa/canonical-ledger');
const NOW = '2026-10-16T13:00:00Z';
const DETAIL = 'lts_browser_expense_detail_v229';
const CANDIDATE_SHA = labelOverlay.allowlist.assets.find(item => item.asset === 'lts-v183-v168-feedback-safe.js').candidate_sha256;
const LIMITATION = 'Synthetic declared-revision, key, count and signed-sum checks only. The backend revision does not cover every date/account field and does not certify a transactionally consistent multipage snapshot.';
const DAILY = {from:'2026-10-16', to:'2026-10-16'};
const MONTH = {from:'2026-10-01', to:'2026-10-16'};
const EMPTY = {from:'2026-09-01', to:'2026-09-30'};
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const sources = html => [...html.matchAll(/<script\b[^>]*\bsrc=["']([^"']+)["'][^>]*>/g)].map(match => match[1]);
const session = {
  access_token:'synthetic-ledger-token-0', refresh_token:'synthetic-ledger-refresh-0',
  token_type:'bearer', expires_in:3600, expires_at:4102444800,
  user:{id:'synthetic-ledger-viewer', email:'viewer@example.invalid'}
};

function descriptor(id, rootOverride, urlOverride) {
  const root = path.resolve(rootOverride || path.join('releases', id));
  const appURL = new URL(urlOverride || '/releases/'+id+'/app.html', BASE);
  assert.equal(appURL.origin, BASE.origin);
  const app = fs.readFileSync(path.join(root, 'app.html'), 'utf8');
  const index = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.json')));
  const model = fs.readFileSync(path.join(root, 'lts-dashboard-executive-v1.js'), 'utf8').match(/const MODEL_SRC=['"]([^'"]+)['"]/);
  assert(model, 'Dynamic dashboard model is identified');
  const expected = {outer:sources(app), inner:sources(index), dynamic:[model[1]]};
  const hashes = {};
  // Verify every manifest file, not just the changed asset or requested scripts.
  for (const [file, expectedHash] of Object.entries(manifest.files)) {
    const filename = path.resolve(root, file);
    assert(filename.startsWith(root+path.sep) && !/^(?:https?:)?\/\//.test(file));
    hashes[file] = hash(fs.readFileSync(filename));
    assert.equal(hashes[file], expectedHash, 'Manifest bytes: '+id+'/'+file);
  }
  for (const src of ['app.html', 'index.html', ...expected.outer, ...expected.inner, ...expected.dynamic]) {
    assert(!/^(?:https?:)?\/\//.test(src), 'Scripts are local release assets');
    assert(hashes[src.split('?')[0]], 'Every script/HTML is in the manifest: '+src);
  }
  return {id, root, appURL:appURL.href, expected, hashes};
}
const builds = {
  baseline:descriptor(BASELINE, process.env.LTS_LEDGER_BASELINE_ROOT, process.env.LTS_LEDGER_BASELINE_PATH),
  candidate:descriptor(RELEASE, process.env.LTS_LEDGER_RELEASE_ROOT, process.env.LTS_LEDGER_APP_PATH)
};
builds.candidate = labelOverlay.overlayBuild(builds.candidate);
assert.equal(builds.candidate.hashes['lts-v183-v168-feedback-safe.js'], CANDIDATE_SHA, 'Reviewed ledger candidate');
assert.deepEqual(builds.candidate.expected, builds.baseline.expected, 'Release script order is preserved');

const row = (key, date, amount, extra={}) => ({
  key, date, event_date:date, transaction_date:date, period:date.slice(0,7)+'-01', date_kind:'day',
  description:'Despesa sintética '+key, account_source:'Conta de teste', beneficiary:null,
  amount, category:'Casa', current_category:'Impostos do Imóvel', subgroup:'Imóvel sintético',
  status:'identified', source_table:'lts_open_finance_staging', source_ref:key,
  coverage_mode:'bank_observed_individual', ...extra
});
const NORMAL_ROWS = [
  row('observed-a', '2026-10-16', 125.25),
  row('credit-b', '2026-10-16', -20.25, {current_category:'Ajuste sintético'}),
  row('monthly-c', '2026-10-01', 45, {
    date:null, transaction_date:null, date_kind:'month',
    coverage_mode:'card_invoice_aggregate_fallback', source_table:'card_synthetic',
    current_category:'Fatura sem composição'
  })
];
function selectedRows(args, spec={}) {
  if (spec.kind === 'bulk') return Array.from({length:10005}, (_, i) => row('bulk-'+i, args.p_to, 1));
  if (spec.prefix) return [70.25, -3.25, 11].map((amount, i) => row(spec.prefix+'-'+i, args.p_to, amount));
  return NORMAL_ROWS.filter(item => item.event_date >= args.p_from && item.event_date <= args.p_to);
}
function detail(args, spec={}) {
  const selected = selectedRows(args, spec), offset = args.p_offset || 0;
  const limit = spec.kind === 'bulk' ? args.p_limit : 2;
  const sum = selected.reduce((total, item) => total+item.amount, 0);
  // Equal total/matched_total makes the sum-mismatch probe reach final reconciliation.
  const total = sum+(spec.kind === 'sum-mismatch' ? 1 : 0);
  return {
    version:'synthetic-detail', from:args.p_from, to:args.p_to, group:args.p_group,
    subgroup:null, total, row_count:selected.length, matched_count:selected.length,
    matched_total:total, offset,
    next_offset:offset+limit < selected.length ? offset+limit : null,
    revision:(spec.prefix || 'revision')+(spec.kind === 'revision-drift' && offset ? '-2' : '-1'),
    rows:selected.slice(offset, offset+limit), components:[]
  };
}
function matchingRange(args, range) { return args.p_from === range.from && args.p_to === range.to; }
const datasetKey = (auth, range) => auth+'|'+range.from+'|'+range.to;

// V168 owns the expense header/period on every tab. V175 only demands its
// category report on overview/categories; Apply deliberately retires that slot
// on transactions. Never wait for a report that this real screen does not request.
function reportSettled(range, observed) {
  const state = observed || {a:window.__LTS_V168_STATE.expense, b:window.__LTS_V175_STATE.expense, tab:window.__LTS_V168_STATE.expense.tab};
  const {a, b, tab} = state;
  if (!a || !b || a.loading !== false || a.error !== null || b.loading !== false || b.error !== null) return false;
  const matches = data => data?.period?.from === range.from && data?.period?.to === range.to;
  const demanded = ['overview','categories'].includes(tab);
  const currentV175 = b.key === range.from+'|'+range.to && matches(b.data);
  const dormantV175 = b.key === '' && b.data === null;
  return matches(a.data) && (demanded ? currentV175 : currentV175 || dormantV175);
}

class Barriers {
  constructor() { this.events = new EventEmitter(); this.pending = new Map(); this.used = new Set(); }
  async hold(label, fulfill, body, status=200) {
    assert(!this.used.has(label), 'Unique barrier: '+label);
    this.used.add(label);
    await new Promise(resolve => { this.pending.set(label, {fulfill, body, status, resolve}); this.events.emit(label); });
  }
  async seen(label) {
    if (this.pending.has(label)) return;
    await new Promise((resolve, reject) => {
      const onSeen = () => { clearTimeout(timer); resolve(); };
      const timer = setTimeout(() => { this.events.off(label, onSeen); reject(Error('Barrier not reached: '+label)); }, 15000);
      this.events.once(label, onSeen);
    });
  }
  async release(label, body, status) {
    await this.seen(label);
    const item = this.pending.get(label); assert(item, 'Held response exists: '+label);
    this.pending.delete(label);
    try { await item.fulfill(status ?? item.status, body ?? item.body); }
    finally { item.resolve(); }
  }
  async close() { for (const label of [...this.pending.keys()]) await this.release(label).catch(() => {}); }
}

async function staticCheck() {
  const args = {p_from:MONTH.from, p_to:MONTH.to, p_group:null, p_subgroup:null, p_offset:0, p_limit:10000, p_query:null};
  const one = detail(args), two = detail({...args, p_offset:one.next_offset});
  assert.equal(one.rows.length, 2); assert.equal(one.next_offset, 2);
  assert.equal(two.rows.length, 1); assert.equal(two.next_offset, null);
  assert.equal([...one.rows, ...two.rows].reduce((sum, item) => sum+item.amount, 0), 150);
  assert.equal(detail({...args, p_from:DAILY.from}).total, 105);
  assert.equal(detail({...args, p_from:EMPTY.from, p_to:EMPTY.to}).row_count, 0);
  const bulk = detail(args, {kind:'bulk'}), bulkTail = detail({...args, p_offset:10000}, {kind:'bulk'});
  assert.equal(bulk.rows.length, 10000); assert.equal(bulk.next_offset, 10000);
  assert.equal(bulkTail.rows.length, 5); assert.equal(bulkTail.next_offset, null);
  assert.equal(bulk.total, 10005); assert.equal(bulkTail.total, 10005);
  assert.notEqual(detail(args, {kind:'revision-drift'}).revision, detail({...args, p_offset:2}, {kind:'revision-drift'}).revision);
  const inconsistent = detail(args, {kind:'sum-mismatch'});
  assert.equal(inconsistent.total, inconsistent.matched_total); assert.equal(inconsistent.total, 151);
  const a = {loading:false, error:null, data:{period:DAILY}};
  const dormant = {loading:false, error:null, key:'', data:null};
  const active = {...dormant, key:DAILY.from+'|'+DAILY.to, data:{period:DAILY}};
  assert(reportSettled(DAILY, {a,b:dormant,tab:'transactions'}), 'Ledger tab admits the intentionally dormant V175 slot');
  assert(reportSettled(DAILY, {a,b:active,tab:'transactions'}), 'A current previously demanded V175 report is also valid');
  assert(reportSettled(DAILY, {a,b:active,tab:'categories'}), 'Category tab requires the real current V175 report');
  assert(!reportSettled(DAILY, {a,b:dormant,tab:'categories'}), 'Missing demanded V175 report must block');
  assert(!reportSettled(DAILY, {a,b:{...active,data:{period:MONTH}},tab:'transactions'}), 'A stale V175 report is never accepted');
  assert(!reportSettled(DAILY, {a,b:{...dormant,loading:true},tab:'transactions'}), 'An in-flight V175 read must settle');
  assert(!reportSettled(DAILY, {a:{...a,data:{period:MONTH}},b:dormant,tab:'transactions'}), 'A stale V168 period must block');
  assert(!reportSettled(DAILY, {a,b:{key:'',data:null},tab:'transactions'}), 'Absent loading/error flags do not prove dormancy');
  assert(!reportSettled(DAILY, {a,b:{...dormant,error:'synthetic-error'},tab:'transactions'}), 'A failed V175 slot is not dormant');
  for (const build of Object.values(builds)) assert(fs.readFileSync(path.join(build.root, 'lts-v183-expense-history-candidate.js'),'utf8').includes("if(['overview','categories'].includes(tab)"), 'V175 ownership predicate remains the inspected production contract');
  const barriers = new Barriers(), received = [];
  const pending = barriers.hold('self-test', async (status, body) => received.push({status, body}), {synthetic:true});
  await barriers.seen('self-test'); assert.equal(received.length, 0);
  await barriers.release('self-test'); await pending;
  assert.deepEqual(received, [{status:200, body:{synthetic:true}}]); assert.equal(barriers.pending.size, 0);
  return {status:'static-check-passed', browser_started:false, network_used:false, candidate_sha:CANDIDATE_SHA,
    label_fixture:labelScenarios.staticCheck(), label_overlay:labelOverlay.summary(), fixture_contracts:['daily-signed-sum','monthly-two-pages','empty','10005-two-pages','declared-revision-drift','final-sum-mismatch'], report_readiness_contracts:9, barrier_contract:true, limitation:LIMITATION, builds};
}

async function run(browser, build, viewport, label, isBaseline) {
  const context = await browser.newContext({viewport, serviceWorkers:'block', reducedMotion:'reduce'});
  const overlayAudit = isBaseline ? null : labelOverlay.audit(context, BASE.href);
  const labelSuite = labelScenarios.createSuite();
  await context.addInitScript(({session, now}) => {
    const NativeDate = Date;
    class FixedDate extends NativeDate {
      constructor(...args) { super(...(args.length ? args : [now])); }
      static now() { return NativeDate.parse(now); }
    }
    window.Date = FixedDate;
    // Never reseed a logged-out/replaced session during a frame navigation.
    if (!sessionStorage.getItem('ledger-fixture-seeded')) {
      sessionStorage.setItem('ledger-fixture-seeded', 'yes');
      localStorage.setItem('lts_supabase_session_v1', JSON.stringify(session));
    }
    sessionStorage.setItem('lts_of_open_refresh_at', String(Date.now()));
  }, {session, now:NOW});
  const page = await context.newPage();
  page.setDefaultTimeout(20000); page.setDefaultNavigationTimeout(20000);
  const calls = [], errors = [], consoleErrors = [], expectedHttpErrors = [], blocked = [], routeErrors = [];
  const assetErrors = [], assetAudits = [], checkpoints = [], geometry = [], plans = [];
  const served = new Set(), barriers = new Barriers(), datasets = new Map();
  let frame, phase = 'boot', authSerial = 0, mode = 'normal', marker = 0;
  const mark = name => { phase = name; checkpoints.push({phase, callStart:calls.length}); };
  const getSpec = (auth, args) => datasets.get(datasetKey(auth, {from:args.p_from, to:args.p_to})) || {kind:mode};
  const ledgerCalls = (start=0) => calls.slice(start).filter(call => call.name === DETAIL);
  page.on('pageerror', error => errors.push(String(error.stack || error)));
  page.on('console', message => {
    if (message.type() !== 'error') return;
    const entry = {text:message.text(), location:message.location(), phase};
    // Intentional mocked HTTP errors are recorded separately, never silently discarded.
    const url = entry.location.url;
    if (/^Failed to load resource: the server responded with a status of 503\b/.test(entry.text) &&
        calls.some(call => call.url === url && call.status === 503 && call.expectedFailure)) expectedHttpErrors.push(entry);
    else consoleErrors.push(entry);
  });
  page.on('response', response => {
    const url = new URL(response.url());
    if (url.origin !== BASE.origin) return;
    const name = path.basename(url.pathname);
    if (!/\.(?:js|css|html)$/.test(name)) return;
    const expectedHash = build.hashes[name];
    assetAudits.push(response.body().then(body => {
      assert.equal(response.status(), 200, 'Asset HTTP status: '+url.pathname);
      assert(expectedHash, 'Unexpected script/style/HTML: '+url.pathname);
      assert.equal(hash(body), expectedHash, 'Served immutable bytes: '+name);
      served.add(url.pathname+url.search);
    }).catch(error => assetErrors.push(String(error.stack || error))));
  });
  await context.route('**/*', async route => {
    try {
      const request = route.request(), url = new URL(request.url());
      if (url.origin === BASE.origin && ['GET', 'HEAD'].includes(request.method())) return overlayAudit ? overlayAudit.serve(route) : route.continue();
      if (url.origin !== ORIGIN) { blocked.push({url:url.href, method:request.method()}); return route.abort('blockedbyclient'); }
      const name = url.pathname.split('/').pop();
      let args = {}; try { args = JSON.parse(request.postData() || '{}'); } catch {}
      const auth = Number((request.headers().authorization || '').match(/synthetic-ledger-token-(\d+)$/)?.[1] ?? -1);
      const call = {name, url:url.href, args:name === 'token' ? {grant:url.searchParams.get('grant_type')} : args,
        auth_session:auth, phase, status:null, marker:null, expectedFailure:false};
      calls.push(call);
      const fulfill = async (status, body) => {
        call.status = status;
        return route.fulfill({status, contentType:'application/json', body:JSON.stringify(body)});
      };
      if (url.pathname === '/auth/v1/token' && request.method() === 'POST') {
        assert.equal(url.searchParams.get('grant_type'), 'password', 'Only explicit synthetic login');
        assert.deepEqual(args, {email:'viewer@example.invalid', password:'synthetic-fixture-only'});
        authSerial++;
        return fulfill(200, {...session, access_token:'synthetic-ledger-token-'+authSerial, refresh_token:'synthetic-ledger-refresh-'+authSerial});
      }
      if (url.pathname === '/auth/v1/logout' && request.method() === 'POST') {
        assert(auth >= 0, 'Synthetic logout only'); return fulfill(200, {});
      }
      if (!url.pathname.startsWith('/rest/v1/rpc/') || request.method() !== 'POST' ||
          !/^lts_browser_[a-z0-9_]+$/.test(name) ||
          /_decision_|_save_|_apply_|_delete_|_confirm_|_mutate_|_classify_|_classification_|_refresh_|_update_|_create_|_upload_/.test(name)) {
        blocked.push({url:url.href, method:request.method()}); return route.abort('blockedbyclient');
      }
      assert(auth >= 0, 'All RPC credentials are synthetic');
      let data = name === 'lts_browser_product_v1' ? {ok:true, mvp:fixture.product(authSerial+1)} : fixture.response(name, args);
      if (name === 'lts_browser_transactions_v2') data = {ok:true, total:0, rows:[]};
      const labelResponse = labelSuite.response(name, args);
      if (labelResponse.handled) return fulfill(200, labelResponse.data);
      if (name === DETAIL) {
        assert.deepEqual(Object.keys(args).sort(), ['p_from','p_group','p_limit','p_offset','p_query','p_subgroup','p_to']);
        assert.equal(args.p_group, null); assert.equal(args.p_subgroup, null); assert.equal(args.p_query, null);
        assert.equal(args.p_limit, 10000, 'Canonical backend page size');
        const spec = getSpec(auth, args);
        data = {...detail(args, spec), __ledgerFixtureMarker:++marker}; call.marker = data.__ledgerFixtureMarker;
        const index = plans.findIndex(plan => plan.auth === auth && matchingRange(args, plan.range) && plan.offset === args.p_offset);
        const plan = index < 0 ? null : plans.splice(index, 1)[0];
        if (plan) { call.hold = plan.label; call.expectedFailure = plan.failure === 'error'; return barriers.hold(plan.label, fulfill, data); }
        if (spec.kind === 'http-error') { call.expectedFailure = true; return fulfill(503, {message:'Falha sintética de leitura.'}); }
      }
      return fulfill(200, data);
    } catch (error) {
      routeErrors.push(String(error.stack || error)); await route.abort('failed').catch(() => {});
    }
  });

  const settle = () => frame.evaluate(async () => {
    await Promise.resolve(); await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  });
  const nav = name => viewport.width <= 520 ? frame.locator('#dx1MobileNav [data-mobile-route="'+name+'"]') : frame.locator('.nav [data-v="'+name+'"]');
  const transactions = () => frame.evaluate(() => {
    const s = window.__LTS_V168_STATE.transactions;
    return {loading:s.loading, token:s.token, rangeKey:s.rangeKey, rows:s.rows, error:s.error,
      count:s.count, total:s.total, revision:s.revision, pageIndex:s.pageIndex, detailOpen:!!s.detail?.isConnected};
  });
  const financial = () => frame.evaluate(() => ({
    position:D.dashboard.position, cash:D.dashboard_cockpit.liquidity,
    wealth:D.wealth_executive.summary, planning:D.planning_executive.summary,
    card:{open:D.card_operating.open_cycles_total, closed:D.card_operating.closed_or_due_total},
    flow:D.flow.days.map(day => ({date:day.date, consolidated:day.Consolidado, columns:day.fix86_columns}))
  }));
  const reportReady = async range => {
    await frame.waitForFunction(reportSettled, range); await settle();
  };
  const ready = async (count, range) => {
    await frame.waitForFunction(({count, range}) => {
      const s = window.__LTS_V168_STATE.transactions;
      return !s.loading && !s.error && s.rows?.length === count && (!s.rangeKey || s.rangeKey === range.from+'|'+range.to);
    }, {count, range}); await reportReady(range);
  };
  const setRange = async range => {
    // Test-only transport cache retirement, same public hook used by the V280 gate.
    await frame.evaluate(() => window.__LTS_V227_TRANSPORT.invalidate(false));
    await frame.locator('[data-v168-exp-range="custom"]').click();
    await frame.locator('#v168ExpenseFrom').fill(range.from);
    await frame.locator('#v168ExpenseTo').fill(range.to);
    await frame.getByRole('button', {name:'Aplicar período', exact:true}).click();
  };
  const assertStack = async () => {
    await Promise.all(assetAudits);
    assert.deepEqual(await page.locator('script[src]').evaluateAll(nodes => nodes.map(node => node.getAttribute('src'))), build.expected.outer, 'Outer script order');
    assert.deepEqual(await frame.locator('script[src]').evaluateAll(nodes => nodes.map(node => node.getAttribute('src'))), [...build.expected.inner, ...build.expected.dynamic], 'Iframe/dynamic script order');
    for (const [scripts, documentURL] of [[build.expected.outer, build.appURL], [[...build.expected.inner, ...build.expected.dynamic], frame.url()]]) {
      for (const src of scripts) { const url = new URL(src, documentURL); assert(served.has(url.pathname+url.search), 'Every expected script was served: '+src); }
    }
    assert.deepEqual(errors, [], 'Zero page errors'); assert.deepEqual(consoleErrors, [], 'Zero unexpected console errors');
    assert.deepEqual(assetErrors, [], 'Zero asset/hash errors'); assert.deepEqual(blocked, [], 'Zero forbidden requests');
    assert.deepEqual(routeErrors, [], 'Zero route/fixture errors');
  };
  const capture = async (name, selector='[data-v281-expense-transactions-list]') => {
    const surface = frame.locator(selector); await surface.scrollIntoViewIfNeeded(); await settle();
    const measurement = await surface.evaluate(element => {
      const box = node => { const rect = node.getBoundingClientRect(); return {left:rect.left, right:rect.right, width:rect.width, height:rect.height, scroll:node.scrollWidth, client:node.clientWidth}; };
      return {viewport:innerWidth, document:document.documentElement.scrollWidth, surface:box(element),
        controls:[...element.querySelectorAll('button,input')].filter(node => !node.closest('[hidden]') && !node.closest('.v168-tablewrap,.v175-tablewrap,.v178-detail-scroll')).map(box),
        scrollers:[...element.querySelectorAll('.v168-tablewrap,.v175-tablewrap,.v178-detail-scroll')].map(node => ({...box(node), overflow:getComputedStyle(node).overflowX}))};
    });
    assert(measurement.document <= measurement.viewport+2, 'No document horizontal overflow');
    for (const box of [measurement.surface, ...measurement.controls, ...measurement.scrollers]) {
      assert(box.left >= -1 && box.right <= viewport.width+2 && box.width > 0 && box.height > 0, 'Visible geometry fits viewport: '+JSON.stringify(box));
    }
    for (const box of measurement.controls) assert(box.scroll <= box.client+2, 'Controls do not clip');
    for (const box of measurement.scrollers) if (box.scroll > box.client+2) assert(['auto','scroll'].includes(box.overflow), 'Wide table is locally scrollable');
    geometry.push({name, ...measurement});
    await page.screenshot({path:path.join(QA, label+'-'+name+'.png')});
  };
  const observe = async () => frame.evaluate(() => {
    const test = window.__LEDGER_TEST__ = {reads:[], renders:[]};
    const snapshot = () => {
      const s = window.__LTS_V168_STATE.transactions;
      return {loading:s.loading, token:s.token, rangeKey:s.rangeKey, rows:s.rows, error:s.error,
        count:s.count, total:s.total, revision:s.revision, pageIndex:s.pageIndex, detailOpen:!!s.detail?.isConnected};
    };
    test.snapshot = snapshot;
    // Pass-through observation only. No response, promise, state slot or handler is replaced.
    const nativeFetch = window.fetch.bind(window), nativeJSON = Response.prototype.json, finalResponses = new WeakMap(), responseIds = new WeakMap();
    let responseSerial = 0;
    window.fetch = function(input, init) {
      const url = typeof input === 'string' ? input : input?.url || '';
      if (!url.endsWith('/lts_browser_expense_detail_v229')) return nativeFetch(input, init);
      const headers = new Headers(init?.headers || input?.headers);
      const read = {id:test.reads.length+1, args:JSON.parse(init?.body || '{}'), generation:BOOT.generation,
        auth_session:Number((headers.get('Authorization') || '').match(/synthetic-ledger-token-(\d+)$/)?.[1] ?? -1), parsed:false, status:null};
      test.reads.push(read);
      const promise = nativeFetch(input, init);
      promise.then(response => { read.status = response.status;
        if (!responseIds.has(response)) responseIds.set(response, ++responseSerial);
        read.responseIdentity = responseIds.get(response); finalResponses.set(response, read); }, error => { read.fetchError = String(error); });
      return promise;
    };
    Response.prototype.json = function() {
      const read = finalResponses.get(this), stack = new Error('ledger-response-consumed').stack;
      const promise = nativeJSON.call(this);
      if (read) promise.then(body => { read.parsed = true; read.parsedGeneration = BOOT.generation;
        read.marker = body?.__ledgerFixtureMarker ?? null; read.message = body?.message ?? null; read.parseStack = stack; }, error => { read.parseError = String(error); });
      return promise;
    };
    const originalRender = render;
    render = function() {
      test.renders.push({generation:BOOT.generation, stack:new Error('ledger-render').stack});
      return originalRender.apply(this, arguments);
    };
  });

  async function staleScenario(kind, heldOffset, failure) {
    const tag = kind+'-page'+(heldOffset === 0 ? '1' : '2')+'-'+failure;
    mark(tag);
    const oldAuth = authSerial, newAuth = kind === 'session' ? oldAuth+1 : oldAuth;
    const oldRange = MONTH, newRange = kind === 'session' ? MONTH : DAILY;
    const oldPrefix = 'old-'+tag, newPrefix = 'new-'+tag;
    datasets.set(datasetKey(oldAuth, oldRange), {prefix:oldPrefix});
    const oldLabel = tag+'-old', newLabel = tag+'-new', start = calls.length;
    const consumerStart = await frame.evaluate(() => window.__LEDGER_TEST__.reads.length);
    plans.push({label:oldLabel, range:oldRange, auth:oldAuth, offset:heldOffset, failure});
    await setRange(oldRange); await barriers.seen(oldLabel); await reportReady(oldRange);
    await frame.waitForFunction(({auth, range, offset, after}) => window.__LEDGER_TEST__.reads.some(read =>
      read.id > after && read.auth_session === auth && read.args.p_from === range.from && read.args.p_to === range.to && read.args.p_offset === offset),
      {auth:oldAuth, range:oldRange, offset:heldOffset, after:consumerStart});
    const oldConsumer = await frame.evaluate(({auth, range, offset, after}) => window.__LEDGER_TEST__.reads.find(read =>
      read.id > after && read.auth_session === auth && read.args.p_from === range.from && read.args.p_to === range.to && read.args.p_offset === offset),
      {auth:oldAuth, range:oldRange, offset:heldOffset, after:consumerStart});
    assert(!oldConsumer.parsed && oldConsumer.status === null, 'Old real consumer is genuinely unresolved');
    const partial = await transactions();
    assert.equal(partial.loading, true); assert.equal(partial.rows, null, 'No partial first page is committed');
    assert.equal(await frame.locator('[data-v281-expense-row-key]').count(), 0);
    const oldCalls = ledgerCalls(start).filter(call => call.auth_session === oldAuth && matchingRange(call.args, oldRange));
    assert.deepEqual(oldCalls.map(call => call.args.p_offset), heldOffset === 0 ? [0] : [0, 2], 'Requested page barrier actually reached');
    if (heldOffset === 2) {
      assert.equal(oldCalls[0].status, 200, 'First backend page really completed');
      assert(await frame.evaluate(id => window.__LEDGER_TEST__.reads.some(read => read.id > id && read.args.p_offset === 0 && read.parsed), consumerStart));
    }
    datasets.set(datasetKey(newAuth, newRange), {prefix:newPrefix});
    plans.push({label:newLabel, range:newRange, auth:newAuth, offset:0});
    if (kind === 'session') {
      await frame.locator('#logout').click();
      await frame.waitForFunction(() => document.body.dataset.ltsBootState === 'signed-out');
      assert(await frame.locator('#app').isHidden());
      assert.equal(await frame.locator('#app').getAttribute('aria-hidden'), 'true');
      assert.equal(await frame.locator('#app').evaluate(node => getComputedStyle(node).display), 'none');
      assert(await frame.locator('#email').isVisible() && await frame.locator('#signin').isVisible());
      await frame.locator('#email').fill('viewer@example.invalid');
      await frame.locator('#password').fill('synthetic-fixture-only');
      await frame.locator('#signin').click();
      await frame.waitForFunction(() => document.body.dataset.ltsBootState === 'ready');
      assert.equal(authSerial, newAuth);
      if (await frame.evaluate(() => V !== 'Despesas')) await nav('Despesas').click();
      if (await frame.evaluate(() => window.__LTS_V168_STATE.expense.tab !== 'transactions')) await frame.getByRole('tab', {name:'Lançamentos', exact:true}).click();
    } else await setRange(newRange);
    await barriers.seen(newLabel); await reportReady(newRange); await settle();
    const before = await frame.evaluate(() => {
      const test = window.__LEDGER_TEST__; test.newSlot = window.__LTS_V168_STATE.transactions;
      test.renderStart = test.renders.length;
      return {generation:BOOT.generation, state:test.snapshot()};
    });
    assert(before.state.loading && before.state.rows === null && before.state.error === null, 'New reader is held before atomic commit');
    assert(before.state.token > partial.token, 'New request owns a newer token');
    if (kind === 'session') assert(before.generation > oldConsumer.generation, 'Login advances the real boot generation');
    const oldRequest = calls.find(call => call.hold === oldLabel);
    if (failure === 'error') await barriers.release(oldLabel, {message:'Erro sintético anterior.', __ledgerFixtureMarker:oldRequest.marker}, 503);
    else await barriers.release(oldLabel);
    // Observe the exact consumer, then drain its microtasks and paint callbacks.
    await frame.waitForFunction(id => window.__LEDGER_TEST__.reads.find(read => read.id === id)?.parsed, oldConsumer.id);
    await settle();
    const after = await frame.evaluate(id => {
      const test = window.__LEDGER_TEST__;
      return {sameIdentity:test.newSlot === window.__LTS_V168_STATE.transactions, state:test.snapshot(),
        oldConsumer:test.reads.find(read => read.id === id), renders:test.renders.slice(test.renderStart).filter(item => /ensureTransactions/.test(item.stack))};
    }, oldConsumer.id);
    assert(after.sameIdentity, 'Old response cannot replace the current transaction slot');
    assert.deepEqual(after.state, before.state, 'Old '+failure+' cannot change current rows/error/loading/token/total');
    assert.deepEqual(after.renders, [], 'Old transaction callback cannot repaint');
    assert.equal(after.oldConsumer.status, failure === 'error' ? 503 : 200);
    assert.equal(after.oldConsumer.id, oldConsumer.id);
    assert.equal(after.oldConsumer.auth_session, oldAuth);
    assert.equal(after.oldConsumer.generation, oldConsumer.generation);
    assert.deepEqual(after.oldConsumer.args, oldConsumer.args);
    assert(Number.isInteger(after.oldConsumer.responseIdentity) && after.oldConsumer.responseIdentity > 0, 'The exact final Response was parsed by the captured old consumer');
    // V179 normalizes executive-report errors, but passes detail reads through.
    // The causal identity assertion above is retained if a known error envelope removes a marker.
    if (failure === 'success' || after.oldConsumer.marker !== null) assert.equal(after.oldConsumer.marker, oldRequest.marker, 'Stale response marker');
    else assert.equal(after.oldConsumer.message, 'Não foi possível atualizar este relatório.', 'Only the known production error normalization can omit the marker');
    assert.match(after.oldConsumer.parseStack, /(?:directRpc|\breq\b)/, 'Production reader parsed the response');
    if (kind === 'session') assert(after.oldConsumer.parsedGeneration > after.oldConsumer.generation);
    assert.equal(ledgerCalls(start).filter(call => call.auth_session === oldAuth && matchingRange(call.args, oldRange) && call.hold !== newLabel).length,
      heldOffset === 0 ? 1 : 2, 'Superseded response schedules neither retries nor a following page');
    assert(!(await frame.locator('.v168-expenses').innerText()).includes(oldPrefix), 'Old synthetic rows never appear');
    await barriers.release(newLabel); await ready(3, newRange);
    const current = await transactions();
    assert.deepEqual(current.rows.map(item => item.key), [0,1,2].map(index => newPrefix+'-'+index));
    assert.equal(current.total, 78); assert.equal(current.count, 3); assert.equal(current.revision, newPrefix+'-1');
    const newCalls = ledgerCalls(start).filter(call => call.auth_session === newAuth && matchingRange(call.args, newRange) &&
      (kind === 'session' || call.hold === newLabel || call.marker > calls.find(item => item.hold === newLabel).marker));
    assert.deepEqual(newCalls.map(call => call.args.p_offset), [0,2], 'Replacement reader completes both canonical pages');
    await capture(tag);
    checkpoints.push({phase:tag+'-verified', oldAuth, newAuth, heldOffset, oldConsumer:after.oldConsumer,
      before, after:{sameIdentity:after.sameIdentity, state:after.state, renders:after.renders}, newKeys:current.rows.map(item => item.key)});
    datasets.clear();
  }

  try {
    await page.goto(build.appURL, {waitUntil:'domcontentloaded'});
    frame = await (await page.waitForSelector('#shell')).contentFrame(); assert(frame);
    await frame.waitForFunction(() => document.body.dataset.ltsBootState === 'ready' &&
      window.__LTS_V175_EXPENSE_AUDIT?.installed && window.__LTS_V178_REVIEW?.installed &&
      window.__LTS_V225?.installed && window.__LTS_V257_UI_STATE?.installed && window.__LTS_FLOW_OVERDUE_PROJECTIONS?.installed);
    await frame.evaluate(() => window.__LTS_V178_REVIEW.ready());
    await frame.waitForFunction(() => !window.__LTS_V225.statusRead && !window.__LTS_V225.loading && !window.__LTS_V226.loading);
    await nav('Despesas').click();
    await reportReady({from:'2026-01-01', to:DAILY.to});
    const financialBefore = await financial();
    if (!isBaseline) await observe();
    await frame.getByRole('tab', {name:'Lançamentos', exact:true}).click();
    mark('daily'); await setRange(DAILY); await ready(isBaseline ? 0 : 2, DAILY);
    const daily = await transactions();
    if (isBaseline) {
      assert(calls.some(call => call.name === 'lts_browser_transactions_v2' && call.args.p_direction === 'saida' && matchingRange(call.args, DAILY)), 'V281 reproduces the old expense cash-reader route');
      assert.equal(ledgerCalls().length, 0);
      await capture('baseline-empty-daily', 'article.v168-card:has(h2:text-is("Despesas do período"))');
      await assertStack(); assert.deepEqual(await financial(), financialBefore);
      return {pass:true, baseline_reproduced:true, id:build.id, label, viewport, daily, financial:financialBefore,
        calls, geometry, served:[...served], errors, consoleErrors, expectedHttpErrors};
    }
    assert.equal(daily.rows.reduce((sum, item) => sum+item.amount, 0), 105);
    assert.equal(daily.total, 105); assert.equal(daily.count, 2);
    assert(daily.rows.some(item => item.amount === -20.25), 'Credit keeps its signed value');
    assert.match(await frame.locator('[data-v281-expense-row-key="credit-b"] .num').innerText(), /-.*20,25/, 'Credit is also signed in the rendered list');
    await capture('daily');
    mark('month'); await setRange(MONTH); await ready(3, MONTH);
    const monthly = await transactions();
    assert.equal(monthly.rows.reduce((sum, item) => sum+item.amount, 0), 150);
    assert.equal(monthly.total, 150); assert.equal(monthly.rows.find(item => item.key === 'monthly-c').date_kind, 'month');
    const monthText = await frame.locator('[data-v281-expense-row-key="monthly-c"] td').first().innerText();
    assert.match(monthText, /competência/); assert(!monthText.includes('01/10/2026'), 'Month-only source is not given an invented day');
    await capture('monthly');
    mark('detail'); const beforeDetail = calls.length;
    await frame.locator('[data-v281-expense-transaction-detail="0"]').click();
    const modal = frame.locator('[data-v281-expense-transaction-modal]'); await modal.waitFor({state:'visible'});
    assert((await modal.innerText()).includes('Despesa sintética observed-a'));
    assert.equal(await frame.evaluate(() => V), 'Despesas');
    await capture('detail', '[data-v281-expense-transaction-modal] .v168-modal');
    assert.equal(calls.length, beforeDetail, 'Canonical row detail makes no network read');
    await frame.getByRole('button', {name:'Fechar', exact:true}).last().click();
    for (const failure of ['http-error','revision-drift','sum-mismatch']) {
      mark(failure); mode = failure; const before = ledgerCalls().length;
      await setRange(MONTH);
      await frame.waitForFunction(() => !window.__LTS_V168_STATE.transactions.loading && !!window.__LTS_V168_STATE.transactions.error);
      await settle();
      const invalid = await transactions();
      assert.equal(invalid.rows, null); assert.equal(invalid.total, null); assert.equal(invalid.count, null); assert.equal(invalid.revision, null);
      assert.equal(await frame.locator('[data-v281-expense-row-key]').count(), 0, 'No incomplete page is rendered');
      assert.equal(ledgerCalls().length-before, failure === 'http-error' ? 3 : 2, 'Bounded real reader attempts');
      if (failure === 'sum-mismatch') assert.match(invalid.error, /não fechou com o total/);
      if (failure === 'revision-drift') assert.match(invalid.error, /mudaram durante a leitura/);
      await frame.locator('[data-v281-expense-transactions-retry]').waitFor({state:'visible'});
      await capture(failure);
      const beforeRerender = ledgerCalls().length;
      await frame.getByRole('tab', {name:'Categorias', exact:true}).click();
      await frame.getByRole('tab', {name:'Lançamentos', exact:true}).click(); await settle();
      assert.equal(ledgerCalls().length, beforeRerender, 'Terminal failure does not auto-retry after rerender');
      mode = 'normal'; await frame.locator('[data-v281-expense-transactions-retry]').click(); await ready(3, MONTH);
      assert.equal(ledgerCalls().length-beforeRerender, 2, 'Explicit retry restarts offset zero and finishes both pages');
      checkpoints.push({phase:failure+'-recovered', invalid, offsets:ledgerCalls().slice(beforeRerender).map(call => call.args.p_offset)});
    }
    mark('bulk'); mode = 'bulk'; const bulkStart = calls.length;
    await setRange(MONTH); await ready(10005, MONTH);
    assert.deepEqual(ledgerCalls(bulkStart).map(call => call.args.p_offset), [0,10000], '10,005 rows require exactly two backend RPCs');
    const bulk = await transactions(); assert.equal(bulk.total, 10005); assert.equal(bulk.count, 10005);
    assert.equal(new Set(bulk.rows.map(item => item.key)).size, 10005);
    assert.equal(await frame.locator('[data-v281-expense-row-key]').count(), 100);
    assert(await frame.locator('[data-v281-expense-transactions-page="prev"]').isDisabled());
    await capture('bulk-first');
    const pageStart = calls.length;
    await frame.locator('[data-v281-expense-transactions-page="next"]').click(); await settle();
    assert.equal(await frame.locator('[data-v281-expense-row-key]').count(), 100);
    assert.equal(await frame.locator('[data-v281-expense-row-key]').first().getAttribute('data-v281-expense-row-key'), 'bulk-100');
    await capture('bulk-second');
    await frame.locator('[data-v281-expense-transactions-page="prev"]').click(); await settle();
    assert.equal(await frame.locator('[data-v281-expense-row-key]').first().getAttribute('data-v281-expense-row-key'), 'bulk-0');
    assert.equal(calls.length, pageStart, '100-row UI paging performs zero RPCs');
    mode = 'normal';
    for (const kind of ['period','session']) for (const offset of [0,2]) for (const failure of ['success','error']) {
      await staleScenario(kind, offset, failure);
      assert.deepEqual(await financial(), financialBefore, 'Financial source facts preserved after '+kind+' boundary');
    }
    mark('empty'); await setRange(EMPTY); await ready(0, EMPTY);
    assert.match(await frame.locator('[data-v281-expense-transactions-list]').innerText(), /Nenhum lançamento no período selecionado/);
    assert.equal((await transactions()).total, 0); await capture('empty');
    assert(!calls.some(call => call.name === 'lts_browser_transactions_v2' && ['expense','saida'].includes(call.args.p_direction)), 'Candidate never queries expense cash movements for this ledger');
    const labelResults = await labelSuite.run({frame,page,nav,setRange,ready,reportReady,capture,settle,calls,mark});
    const overlayResult = await overlayAudit.assertComplete();
    assert.deepEqual(await financial(), financialBefore, 'Financial source facts remain unchanged');
    assert.equal(plans.length, 0); assert.equal(barriers.pending.size, 0);
    await assertStack();
    return {pass:true, baseline:false, id:build.id, label, viewport, daily, monthly,
      financial:financialBefore, auth_sessions:authSerial, labelResults, overlay:overlayResult, checkpoints, calls, geometry,
      served:[...served], errors, consoleErrors, expectedHttpErrors,
      consumerReads:await frame.evaluate(() => window.__LEDGER_TEST__.reads), limitation:LIMITATION};
  } catch (error) {
    await page.screenshot({path:path.join(QA, label+'-failure.png')}).catch(() => {});
    error.ledgerEvidence = {id:build.id, label, phase, calls, errors, consoleErrors, expectedHttpErrors,
      blocked, assetErrors, routeErrors, plans, pending:[...barriers.pending.keys()],
      state:await Promise.resolve().then(transactions).catch(() => null),
      reports:await frame?.evaluate(() => {
        const snapshot = s => s ? {loading:s.loading,error:s.error,key:s.key,token:s.token,period:s.data?.period ?? null,dataPresent:s.data != null} : null;
        return {tab:window.__LTS_V168_STATE?.expense?.tab, v168:snapshot(window.__LTS_V168_STATE?.expense),v175:snapshot(window.__LTS_V175_STATE?.expense)};
      }).catch(() => null), body:await frame?.locator('body').innerText().catch(() => null),
      observation:await frame?.evaluate(() => window.__LEDGER_TEST__ ? {reads:window.__LEDGER_TEST__.reads, renders:window.__LEDGER_TEST__.renders.slice(-30)} : null).catch(() => null)};
    throw error;
  } finally { await barriers.close(); await context.close(); }
}

(async () => {
  if (process.argv.includes('--static-check')) { console.log(JSON.stringify(await staticCheck(), null, 2)); return; }
  fs.mkdirSync(QA, {recursive:true});
  const result = {status:'running', scope:'Full immutable local release stack, all requests intercepted or loopback assets; invented financial/session fixtures only', limitation:LIMITATION, builds, results:[]};
  let browser;
  try {
    const {chromium} = require('playwright');
    browser = await chromium.launch({headless:true, ...(process.env.LTS_CHROMIUM_PATH ? {executablePath:process.env.LTS_CHROMIUM_PATH} : {})});
    for (const [name, viewport] of [['desktop',{width:1440,height:1000}], ['mobile',{width:390,height:844}], ['narrow',{width:320,height:760}]]) {
      const baseline = await run(browser, builds.baseline, viewport, name+'-baseline', true);
      result.results.push(baseline);
      const candidate = await run(browser, builds.candidate, viewport, name+'-candidate', false);
      assert.deepEqual(candidate.financial, baseline.financial, 'Candidate and V281 have identical synthetic financial source facts');
      result.results.push(candidate);
    }
    assert.equal(result.results.filter(item => !item.baseline_reproduced).flatMap(item => item.checkpoints.filter(point => /^(period|session)-page[12]-(success|error)-verified$/.test(point.phase))).length, 24, 'All inherited stale-response scenarios remain covered');
    result.status = 'passed';
  } catch (error) {
    result.status = 'failed'; result.error = String(error.stack || error); result.evidence = error.ledgerEvidence || null; process.exitCode = 1;
  } finally {
    fs.writeFileSync(path.join(QA, 'result.json'), JSON.stringify(result, null, 2)+'\n');
    console.log(JSON.stringify(result, null, 2)); await browser?.close();
  }
})().catch(error => { console.error(error.stack || error); process.exitCode = 1; });
