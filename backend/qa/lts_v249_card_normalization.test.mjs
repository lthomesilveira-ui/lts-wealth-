import test from 'node:test';
import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';
import { normalize, cardTransactionLayer, cardTransactionIdentity } from '../open_finance/v249/core.mjs';
if (!globalThis.crypto) globalThis.crypto = webcrypto;
const ctx = { item: { id: 'synthetic-item', lastUpdatedAt: '2026-10-05T15:00:00Z' },
  institutionName: 'Synthetic bank', institutionBasis: 'synthetic',
  account: { id: 'synthetic-account', number: '****1111', name: 'Synthetic card', subtype: 'CREDIT_CARD', currencyCode: 'BRL' } };
const raw = overrides => ({ id: 'synthetic-transaction', accountId: ctx.account.id,
  amount: 12.34, currencyCode: 'BRL', date: '2026-10-03T15:00:00Z',
  description: 'Synthetic purchase', type: 'DEBIT', status: 'PENDING', operationType: 'PAGAMENTO',
  creditCardMetadata: { cardNumber: '****2222', installmentNumber: 1, totalInstallments: 10 }, ...overrides });
test('generic PAGAMENTO is consumption, including a posted purchase', async () => {
  for (const status of ['PENDING', 'POSTED']) {
    const n = (await normalize('card_transaction', raw({ status }), ctx)).normalized_payload;
    assert.equal(n.layer, 'card_consumption'); assert.equal(n.amount, -12.34);
    assert.equal(n.status, status); assert.equal(n.official_effect, false);
    assert.equal(n.normalization_revision, 'v249-card-identity-and-layer');
  }
});
test('only exact PAGAMENTO_FATURA identifies bill payment evidence', () => {
  assert.equal(cardTransactionLayer({ operationType: 'PAGAMENTO_FATURA' }), 'card_payment_evidence');
  for (const operationType of [null, undefined, '', 'PAGAMENTO', 'PAGAMENTO_FATURA_PARCIAL', 'PAGAMENTO_PIX', 'ESTORNO', 'CASHBACK', 'TARIFA', 'OUTROS'])
    assert.equal(cardTransactionLayer({ operationType }), 'card_consumption');
});
test('bill payment credit keeps its sign and cannot become income', async () => {
  const r = await normalize('card_transaction', raw({ amount: -99.99, type: 'CREDIT', status: 'POSTED', operationType: 'PAGAMENTO_FATURA' }), ctx);
  assert.equal(r.signed_amount, 99.99); assert.equal(r.normalized_payload.layer, 'card_payment_evidence');
  assert.equal(r.normalized_payload.official_effect, false);
});
test('contradictory bill-payment direction is warned, not repaired', async () => {
  const r = await normalize('card_transaction', raw({ operationType: 'PAGAMENTO_FATURA' }), ctx);
  assert.equal(r.signed_amount, -12.34); assert.ok(r.normalized_payload.warnings.includes('bill_payment_direction_disagreement'));
});
test('pending bill payment stays pending and unofficial', async () => {
  const r = await normalize('card_transaction', raw({ amount: -5, type: 'CREDIT', operationType: 'PAGAMENTO_FATURA' }), ctx);
  assert.equal(r.normalized_payload.status, 'PENDING'); assert.equal(r.normalized_payload.official_effect, false);
});
test('transaction card wins; account identity is retained separately', async () => {
  const n = (await normalize('card_transaction', raw(), ctx)).normalized_payload;
  assert.equal(n.last4, '2222'); assert.equal(n.account_last4, '1111'); assert.equal(n.account_number, '****1111');
  assert.equal(n.provider_account_id, ctx.account.id); assert.equal(n.card_number_basis, 'provider_transaction_card_number');
  assert.ok(n.warnings.includes('transaction_card_differs_from_account_card'));
});
test('account fallback is explicit when transaction metadata is absent', () => {
  for (const value of [null, undefined, '']) {
    const n = cardTransactionIdentity({ creditCardMetadata: { cardNumber: value } }, ctx.account);
    assert.equal(n.last4, '1111'); assert.equal(n.card_number_basis, 'provider_account_number');
  }
});
test('invalid supplied transaction identity does not silently use account identity', () => {
  for (const value of ['123', 'invalid2222', '1'.repeat(20), 1234567890123456, {}, []]) {
    const n = cardTransactionIdentity({ creditCardMetadata: { cardNumber: value } }, ctx.account);
    assert.equal(n.last4, null); assert.equal(n.card_number_basis, 'unresolved_transaction_card_number');
  }
});
test('masked, last-four, safe numeric-last-four and PAN string identities', () => {
  for (const value of ['2222', 'XXXX-2222', '•••• 2222', '1234 5678 9012 2222', 2222])
    assert.equal(cardTransactionIdentity({ creditCardMetadata: { cardNumber: value } }, ctx.account).last4, '2222');
  assert.equal(cardTransactionIdentity({ creditCardMetadata: { cardNumber: '0000' } }, ctx.account).last4, '0000');
});
test('matching transaction/account card produces no identity mismatch warning', () => {
  assert.deepEqual(cardTransactionIdentity({ creditCardMetadata: { cardNumber: '1111' } }, ctx.account).warnings, []);
});
test('installments, date, currency, raw identity and raw payload are preserved', async () => {
  const source = raw(); const copy = structuredClone(source); const r = await normalize('card_transaction', source, ctx);
  assert.deepEqual(source, copy); assert.deepEqual(r.raw_payload, copy);
  assert.equal(r.posting_date, '2026-10-03'); assert.equal(r.currency, 'BRL'); assert.equal(r.occurred_at, source.date);
  assert.equal(r.provider_record_id, ctx.item.id + ':' + source.id);
  assert.equal(r.normalized_payload.installment_number, 1); assert.equal(r.normalized_payload.total_installments, 10);
});
test('account-currency conversion remains unchanged', async () => {
  const r = await normalize('card_transaction', raw({ amount: 5, amountInAccountCurrency: 27.12, currencyCode: 'USD' }), ctx);
  assert.equal(r.signed_amount, -27.12); assert.equal(r.currency, 'BRL'); assert.equal(r.normalized_payload.provider_amount, 5);
});
test('bank cash is not reclassified as a card payment', async () => {
  const n = (await normalize('transaction', raw({ operationType: 'ENCARGOS_JUROS_CHEQUE_ESPECIAL' }), ctx)).normalized_payload;
  assert.equal(n.layer, 'bank_cash'); assert.equal(n.operation_type, 'ENCARGOS_JUROS_CHEQUE_ESPECIAL');
  assert.equal(n.last4, null); assert.equal(n.account_last4, undefined);
});
test('unreported amount remains unknown, not zero', async () => {
  const r = await normalize('card_transaction', raw({ amount: null }), ctx);
  assert.equal(r.signed_amount, null); assert.ok(r.normalized_payload.warnings.includes('unresolved_amount_or_sign'));
});
test('cross-item and cross-account scope guards remain active', async () => {
  await assert.rejects(normalize('card_transaction', raw({ itemId: 'other-item' }), ctx), /PROVIDER_ITEM_SCOPE/);
  await assert.rejects(normalize('card_transaction', raw({ accountId: 'other-account' }), ctx), /PROVIDER_ACCOUNT_SCOPE/);
});
test('secret-bearing raw payload is rejected', async () => {
  await assert.rejects(normalize('card_transaction', raw({ password: 'synthetic' }), ctx), /UNEXPECTED_SECRET_FIELD/);
});
