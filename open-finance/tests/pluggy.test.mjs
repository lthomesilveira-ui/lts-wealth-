import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Pluggy, SafeError, normalize, hash, brazilDay, reconcile, collect, enforceOneToOne } from '../../supabase/functions/lts-open-finance-itau/core.mjs';
import { makeHandler } from '../../supabase/functions/lts-open-finance-itau/handler.mjs';

// Synthetic fixtures only. No personal data or real provider identifiers.
const item = { id: '11111111-1111-4111-8111-111111111111', connector: { name: 'MeuPluggy' }, status: 'UPDATED', executionStatus: 'SUCCESS', lastUpdatedAt: '2026-09-24T12:00:00Z' };
const bank = { id: 'bank-fixture', itemId: item.id, type: 'BANK', subtype: 'CHECKING_ACCOUNT', name: 'Itaú fixture', number: '0000/00000-0', balance: 0, currencyCode: 'BRL', bankData: { transferNumber: '341/0000/00000-0' } };
const card = { id: 'card-fixture', type: 'CREDIT', subtype: 'CREDIT_CARD', name: 'Synthetic card', number: '9999', currencyCode: 'BRL', balance: 80 };
const context = { item, account: bank, institutionBasis: 'test' };
const tx = { id: 'tx-fixture', accountId: bank.id, date: '2026-09-24T12:00:00Z', amount: -12.34, currencyCode: 'BRL', type: 'DEBIT', status: 'POSTED', description: 'Synthetic merchant' };
const response = (data, status = 200) => new Response(JSON.stringify(data), { status });

test('stable hash ignores key order, preserves numeric change and null', async () => {
  assert.equal(await hash({ b: 2, a: null }), await hash({ a: null, b: 2 }));
  assert.notEqual(await hash({ a: 0 }), await hash({ a: null }));
});
test('bank debit, card purchase and card payment retain distinct economic layers', async () => {
  assert.equal((await normalize('transaction', tx, context)).signed_amount, -12.34);
  const purchase = await normalize('card_transaction', { ...tx, accountId: card.id, amount: 12.34 }, { ...context, account: card });
  assert.equal(purchase.signed_amount, -12.34); assert.equal(purchase.normalized_payload.layer, 'card_consumption');
  const payment = await normalize('card_transaction', { ...tx, accountId: card.id, amount: -12.34, operationType: 'PAGAMENTO_FATURA' }, { ...context, account: card });
  assert.equal(payment.signed_amount, 12.34); assert.equal(payment.normalized_payload.layer, 'card_payment_evidence');
  assert.equal(payment.normalized_payload.official_effect, false);
});
test('investment net, gross, withdrawal and unknown liquidity are independent', async () => {
  const n = (await normalize('investment', { id: 'inv-fixture', itemId: item.id, balance: 90, amount: 100, amountWithdrawal: 0, date: '2026-09-23T12:00:00Z', currencyCode: 'BRL' }, { item })).normalized_payload;
  assert.deepEqual([n.net_valuation, n.gross_valuation, n.withdrawal_available, n.liquidity], [90, 100, 0, null]);
  const missing = (await normalize('investment', { id: 'inv-fixture', currencyCode: 'BRL' }, { item })).normalized_payload;
  assert.equal(missing.amount, null); assert.equal(missing.withdrawal_available, null); assert.equal(missing.as_of, null);
});
test('loan outstanding balance never falls back to original principal', async () => {
  const n = (await normalize('loan', { id: 'loan-fixture', contractAmount: 10000, currencyCode: 'BRL' }, { item })).normalized_payload;
  assert.equal(n.amount, null); assert.equal(n.contract_amount, 10000);
});
test('UTC date shift is explicit; date-only fields remain civil dates', async () => {
  assert.equal(brazilDay('2026-09-24T00:00:00Z'), '2026-09-23');
  assert.equal(brazilDay('2026-09-24'), '2026-09-24');
  assert.equal(brazilDay('2026-09-24T00:00:00'), null);
  const n = (await normalize('transaction', { ...tx, date: '2026-09-24T00:00:00Z' }, context)).normalized_payload;
  assert.ok(n.warnings.includes('utc_date_differs_from_brazil_day')); assert.equal(n.provider_civil_date, '2026-09-24');
});
test('scope mismatch and unexpected credential fields are rejected', async () => {
  await assert.rejects(normalize('transaction', { ...tx, accountId: 'another-account' }, context), /PROVIDER_ACCOUNT_SCOPE/);
  await assert.rejects(normalize('investment', { id: 'fixture', nested: { clientSecret: 'not-a-real-secret' } }, { item }), /UNEXPECTED_SECRET_FIELD/);
});
test('cursor paginates using returned query string exactly', async () => {
  const paths = [];
  const p = new Pluggy('fake-id', 'fake-secret', async (url, opts) => {
    paths.push(new URL(url).pathname + new URL(url).search);
    if (url.endsWith('/auth')) return response({ apiKey: 'fake-key' });
    assert.equal(opts.method, 'GET');
    return response(paths.length === 2 ? { results: [{ id: 'a' }], next: '?accountId=acct&after=a%2Bb' } : { results: [{ id: 'b' }], next: null });
  });
  assert.equal((await p.list('/v2/transactions', { accountId: 'acct' }, 'cursor')).length, 2);
  assert.equal(paths[2], '/v2/transactions?accountId=acct&after=a%2Bb');
});
test('looped cursors, foreign scope, missing completion and incomplete page totals fail closed', async () => {
  for (const next of ['?accountId=other&after=x', '?accountId=acct', undefined]) {
    const p = new Pluggy('fake', 'fake', async url => response(url.endsWith('/auth') ? { apiKey: 'fake' } : { results: [], next }));
    await assert.rejects(p.list('/v2/transactions', { accountId: 'acct' }, 'cursor'), SafeError);
  }
  const p = new Pluggy('fake', 'fake', async url => response(url.endsWith('/auth') ? { apiKey: 'fake' } : { results: [], page: 1, totalPages: 1, total: 2 }));
  await assert.rejects(p.list('/investments', { itemId: item.id }), /INCOMPLETE_PAGE_SET/);
});
test('API auth refresh retries once without leaking provider errors', async () => {
  let auths = 0, reads = 0;
  const p = new Pluggy('fake-id', 'fake-secret', async url => {
    if (url.endsWith('/auth')) { auths++; return response({ apiKey: 'fake-key-' + auths }); }
    reads++; return reads === 1 ? response({ leaked: 'secret-body' }, 401) : response({ results: [], page: 1, totalPages: 0, total: 0 });
  });
  await p.list('/accounts', { itemId: item.id }, 'single'); assert.equal(auths, 2);
  const broken = new Pluggy('fake-id', 'fake-secret', async () => response({ clientSecret: 'secret-body' }, 403));
  await assert.rejects(broken.request('/accounts'), e => e.message === 'PROVIDER_HTTP_403' && !e.message.includes('secret-body'));
});
test('Item discovery uses the existing proxy and never creates consent', async () => {
  const methods = [];
  const p = new Pluggy('fake', 'fake', async (url, opts) => {
    methods.push([new URL(url).pathname, opts.method]);
    return response(url.endsWith('/auth') ? { apiKey: 'fake' } : url.includes('/v2/items') ? { results: [item], next: null } : item);
  });
  assert.equal((await p.existingItem()).id, item.id);
  assert.deepEqual(methods.filter(x => x[1] !== 'GET'), [['/auth', 'POST']]);
  const disabled = new Pluggy('fake', 'fake', async url => url.endsWith('/auth') ? response({ apiKey: 'fake' }) : response({}, 403));
  await assert.rejects(disabled.existingItem(), /ITEM_LIST_NOT_AVAILABLE/);
});
test('collection reports unavailable loans, complete pagination and card layers', async () => {
  let bound = 0;
  const p = { list: async (path) => {
    if (path === '/accounts') return [bank, card];
    if (path === '/loans') throw new SafeError('PROVIDER_HTTP_403');
    return [];
  }, request: async () => item };
  const c = await collect(p, item, false, async () => { bound++; });
  assert.equal(bound, 1); assert.equal(c.status, 'partial');
  assert.deepEqual(c.records.map(r => r.resource_type), ['account', 'balance', 'credit_card']);
  assert.equal(c.coverage.find(c => c.product === 'loans').count, null);
});
test('collection rejects changed snapshots and another bank', async () => {
  const p = { list: async path => path === '/accounts' ? [bank] : [], request: async () => ({ ...item, lastUpdatedAt: 'changed' }) };
  await assert.rejects(collect(p, item), /PROVIDER_CHANGED_DURING_SYNC/);
  p.list = async () => [{ ...bank, bankData: { transferNumber: '999/0000/0000' } }];
  await assert.rejects(collect(p, item, true), /INSTITUTION_CONFLICT/);
});
test('same amount on another date/bank is not an exact match', async () => {
  const r = await normalize('transaction', tx, context);
  const base = { kind: 'transaction', table: 'source', ref: '1', institution: 'Itaú', currency: 'BRL', amount: -12.34, date: '2026-09-24', description: 'Synthetic merchant' };
  assert.equal(reconcile(r, [{ ...base, date: '2026-09-23' }]).classification, 'new');
  assert.equal(reconcile(r, [{ ...base, institution: 'Another bank' }]).classification, 'new');
  assert.equal(reconcile(r, [base]).classification, 'candidate');
  assert.equal(reconcile(r, [{ ...base, amount: -13 }]).classification, 'conflict');
  assert.equal(reconcile(r, [{ ...base, provider_id: tx.id }]).classification, 'exact');
});
test('different position dates, missing values and many-to-one matches require review', async () => {
  const r = await normalize('investment', { id: 'i', code: 'CDB-TEST', name: 'Test CDB', balance: 90, currencyCode: 'BRL', date: '2026-09-24' }, { item });
  assert.equal(reconcile(r, [{ kind: 'investment', table: 'asset_positions', ref: 'p', institution: 'Itaú', code: 'CDB-TEST', currency: 'BRL', amount: 90, date: '2026-09-23' }]).classification, 'candidate');
  const a = await normalize('transaction', tx, context), b = await normalize('transaction', { ...tx, id: 'second' }, context);
  const match = { classification: 'candidate', candidates: [{ table: 'source', ref: 'one' }] };
  a.reconciliation = structuredClone(match); b.reconciliation = structuredClone(match);
  enforceOneToOne([a,b]); assert.equal(a.reconciliation.classification, 'conflict');
  r.normalized_payload.amount = null; assert.equal(reconcile(r, []).classification, 'conflict');
});
test('handler rejects anonymous, wrong owner, wrong origin and unrequested mutations', async () => {
  const env = k => ({ SUPABASE_URL: 'https://example.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'fake-service' })[k];
  const h = makeHandler(env, async url => response(url.endsWith('/auth/v1/user') ? { id: 'other' } : 'owner'));
  assert.equal((await h(new Request('https://example', { method: 'POST', body: '{}' }))).status, 401);
  assert.equal((await h(new Request('https://example', { method: 'POST', headers: { Authorization: 'Bearer fake-user' }, body: '{}' }))).status, 403);
  assert.equal((await h(new Request('https://example', { method: 'POST', headers: { Origin: 'https://evil.example', Authorization: 'Bearer fake-service' }, body: '{}' }))).status, 403);
  const response4 = await h(new Request('https://example', { method: 'POST', headers: { Authorization: 'Bearer fake-service' }, body: JSON.stringify({ action: 'sync', clientSecret: 'should-not-be-accepted' }) }));
  assert.equal(response4.status, 400); assert.equal((await response4.json()).error, 'UNSUPPORTED_INPUT_FIELD');
});
test('missing provider credentials block sync before provider requests or database writes', async () => {
  const calls = [];
  const h = makeHandler(k => ({ SUPABASE_URL: 'https://example.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'fake-service' })[k], async url => { calls.push(url); return response('owner'); });
  const r = await h(new Request('https://example', { method: 'POST', headers: { Authorization: 'Bearer fake-service' }, body: '{"action":"sync"}' }));
  assert.equal(r.status, 409); assert.equal((await r.json()).error, 'PLUGGY_SECRETS_REQUIRED');
  assert.equal(calls.length, 1); assert.ok(calls[0].endsWith('/lts_open_finance_pilot_owner_v1'));
});
test('job authentication is bound to an owner and action, and cannot replace provider secrets', async () => {
  const h = makeHandler(k => ({ SUPABASE_URL: 'https://example.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'fake-service' })[k], async url => response(url.endsWith('/lts_open_finance_consume_job_v1') ? { user_id: 'owner', action: 'status' } : 'owner'));
  const r = await h(new Request('https://example', { method: 'POST', headers: { Authorization: 'Bearer fake-anon', 'x-lts-of-job': 'a'.repeat(64) }, body: '{"action":"sync"}' }));
  assert.equal(r.status, 403); assert.equal((await r.json()).error, 'JOB_ACTION_MISMATCH');
});

test('complete handler pipeline stages and reconciles without a canonical write', async () => {
  const writes = [], staged = [];
  const env = k => ({ SUPABASE_URL: 'https://example.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'fake-service',
    PLUGGY_CLIENT_ID: 'fake-id', PLUGGY_CLIENT_SECRET: 'fake-secret', PLUGGY_ITAU_ITEM_ID: item.id })[k];
  const h = makeHandler(env, async (url, options) => {
    const path = new URL(url).pathname;
    if (url.startsWith('https://api.pluggy.ai')) {
      if (path === '/auth') return response({ apiKey: 'fake-key' });
      if (path.startsWith('/items/')) return response(item);
      if (path === '/accounts') return response({ results: [{ ...bank, updatedAt: item.lastUpdatedAt }], page: 1, total: 1, totalPages: 1 });
      if (path === '/v2/transactions') return response({ results: [tx], next: null });
      return response({ results: [], page: 1, total: 0, totalPages: 0 });
    }
    const rpc = path.split('/').at(-1), body = JSON.parse(options.body ?? '{}'); writes.push(rpc);
    if (rpc === 'lts_open_finance_pilot_owner_v1') return response('owner');
    if (rpc === 'lts_open_finance_begin_itau_v1') return response({ connection_id: 'connection', run_id: 'run' });
    if (rpc === 'lts_open_finance_sources_v1') return response({ complete_for_consulted_sources: true, rows: [], source_as_of: '2026-09-22' });
    if (rpc === 'lts_open_finance_stage_batch_v1') { staged.push(...body.p_records); return response({ observations_inserted: body.p_records.length }); }
    if (rpc === 'lts_open_finance_finish_itau_v1') return response({ status: body.p_status, promotion_enabled: false });
    throw new Error('Unexpected database operation');
  });
  const result = await h(new Request('https://example', { method: 'POST', headers: { Authorization: 'Bearer fake-service' }, body: '{"action":"sync"}' }));
  assert.equal(result.status, 200); assert.equal((await result.json()).status, 'success');
  assert.equal(staged.length, 3); assert.ok(staged.every(r => r.raw_hash.length === 64 && r.reconciliation.classification === 'new'));
  assert.ok(writes.every(w => w.startsWith('lts_open_finance_')));
});
