'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const recurrence = 'lts_browser_recurring_future_gap_audit_v5';
const finance = 'lts_browser_open_finance_status_v1';
const cardQueue = 'lts_browser_card_review_queue_v312';
const recurringValue = {items: [{key: 'synthetic', amount: 123.45}]};
const cardValue = {ok: true, row_count: 1, additional_count: 1, matched_count: 1, rows: [{amount: 45.67}]};

function loadFunction(release, asset, start, end, globals) {
  const source = fs.readFileSync('releases/' + release + '/' + asset, 'utf8');
  const from = source.indexOf('async function ' + start + '(');
  const to = source.indexOf(end, from);
  assert(from >= 0 && to > from, start);
  const context = vm.createContext({Date, Error, Promise, Object, Array, Number, Math, queueMicrotask, ...globals});
  vm.runInContext(source.slice(from, to), context);
  return context;
}

async function checkActions(release, recovers) {
  const state = {loading: false, recurring: null, openFinance: null, error: null};
  const reads = [];
  const renderedWarnings = [];
  let fail = true;
  const context = loadFunction(release, 'lts-v183-v168-feedback-safe.js', 'ensureUpdates',
    '    async function ensureInvoices', {
      V: 'Dashboard', D: {}, window: {}, st: {updates: state, dashboard: {}},
      today: () => '2026-11-09', syncActionsOwner: () => {}, expenseDraftGeneration: () => 1,
      render: () => renderedWarnings.push(!!state.error),
      rpcRead: async (name, args, retries) => {
        reads.push({name, args, retries});
        if (name === recurrence && fail) throw new Error('Synthetic timeout');
        return name === recurrence ? recurringValue : {connections: []};
      }
    });
  await context.ensureUpdates();
  assert(state.error);
  assert(state.openFinance);
  context.V = 'Atualizações';
  await context.ensureUpdates();
  assert.equal(reads.filter(x => x.name === recurrence).length, recovers ? 2 : 1);
  assert(state.error, 'a failed retry must preserve the warning');
  assert(renderedWarnings.at(-1));
  await context.ensureUpdates();
  assert.equal(reads.filter(x => x.name === recurrence).length, recovers ? 2 : 1, 'no render loop after failure');
  assert.equal(reads.filter(x => x.name === finance).length, 1, 'do not re-read the successful part');
  fail = false;
  await context.ensureUpdates(true);
  assert.strictEqual(state.recurring, recurringValue);
  assert.equal(state.error, null);
  assert(reads.filter(x => x.name === recurrence).every(x => x.args.p_as_of === '2026-11-09' && x.retries === 1));
}

async function checkCards(release, recovers) {
  const state = {generation: 1, sequence: 0, loading: false, error: false, data: null, readAt: 0, query: '', offset: 0};
  const reads = [];
  let fail = true;
  const context = loadFunction(release, 'lts-v312-card-review.js', 'load', '  function panel', {
    state, V: 'Dashboard', D: {}, N: {classList: {contains: () => false}},
    session: () => {}, current: () => 1, today: () => '2026-11-09',
    render: () => {}, renderNav: () => {}, notice: () => {},
    S: {rpc: async (name, args) => {
      assert.equal(name, cardQueue);
      reads.push(args);
      return fail ? {error: {code: '57014'}} : {data: cardValue};
    }}
  });
  await context.load();
  assert.equal(state.data, null);
  assert(state.error);
  context.V = 'Atualizações';
  fail = false;
  await context.load();
  assert.equal(reads.length, recovers ? 2 : 1);
  assert.strictEqual(state.data, recovers ? cardValue : null);
  if (!recovers) return;
  fail = true;
  await context.load(true);
  assert.strictEqual(state.data, cardValue);
  assert(state.error, 'a failed refresh keeps the prior list with a warning');
  await context.load();
  assert.equal(reads.length, 3, 'an error on the visible screen does not keep reissuing the read');
  fail = false;
  await context.load(true);
  assert(!state.error);
  assert.deepEqual(reads.map(x => JSON.stringify(x)), Array(4).fill(JSON.stringify(reads[0])));
}

(async () => {
  for (const [release, recovers] of [['v433', false], ['v436', true]]) {
    await checkActions(release, recovers);
    await checkCards(release, recovers);
  }
  console.log(JSON.stringify({pass: true, predecessor_failure_reproduced: true,
    bounded_foreground_retry: true, stale_warning_preserved: true, arguments_unchanged: true}));
})().catch(error => { console.error(error); process.exitCode = 1; });
