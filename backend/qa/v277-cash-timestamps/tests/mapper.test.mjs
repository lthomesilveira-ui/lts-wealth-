import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const base = new URL('../', import.meta.url);
const beforeSQL = readFileSync(new URL('baseline/lts_browser_cash_today_v178.sql', base), 'utf8');
const afterSQL = readFileSync(new URL('candidate/lts_browser_cash_today_v178.sql', base), 'utf8');
const addition = "  'bank_positions',positions->'accounts',\n";
// This is a mapper oracle, not a substitute for executing PostgreSQL. The SQL
// harness separately exercises the entire before/after functions and wrapper.
const addPositions = (cash, positions) => ({ ...structuredClone(cash), bank_positions: structuredClone(positions.accounts ?? null) });
const fixture = () => ({ accounts: [
  { institution: 'Itaú', institution_code: '341', balance: 1234.56, as_of: '2031-02-13T06:13:11.456-03:00', source_id: '00000000-0000-0000-0000-000000000011' },
  { institution: 'Bradesco', institution_code: '237', balance: -13.21, as_of: '2031-02-14T03:00:00-03:00', source_id: '00000000-0000-0000-0000-000000000012' },
  { institution: 'C6', institution_code: '336', balance: 0, as_of: '2031-02-12T23:59:59.999-03:00', source_id: '00000000-0000-0000-0000-000000000013' }
], bank_cash: 1221.35 });
const oldCash = () => ({ version: 'cash-today-v179-current-canonical', as_of: '2031-02-14', computed_at: '2031-02-14T06:15:00-03:00', cash: 1221.35, d0: 12.34,
  brokerage_available: 78.90, available_total: 1312.59, fgts: 45.67,
  day: { position_only: true, Itaú: { balance: 1234.56, net: null }, Bradesco: { balance: -13.21, net: null }, C6: { balance: 0, net: null },
    summary: { Consolidado: { entries: null, exits: null } }, fix86_columns: { saldo_anterior: null, entradas: null, saidas: null, saldo_final: 1221.35 } },
  position_dates: { d0: '2031-01-29', brokerage: '2031-02-01', fgts: '2031-01-30' }, reader_revision: 'v230-independent-current-position' });

test('SQL change is exactly one additive return property; no declarations, formulas or privileges changed', () => {
  assert.equal(afterSQL.split(addition).length, 2);
  assert.equal(afterSQL.replace(addition, ''), beforeSQL);
  assert.doesNotMatch(addition, /GRANT|REVOKE|SECURITY|ALTER|UPDATE|INSERT|DELETE/i);
});
test('all existing output fields, figures, nulls and revisions are deeply identical', () => {
  const before = oldCash(), after = addPositions(before, fixture());
  const { bank_positions, ...rest } = after;
  assert.deepEqual(rest, before);
  assert.equal(after.day.summary.Consolidado.entries, null);
  assert.equal(after.day.Itaú.net, null);
  assert.equal(bank_positions.length, 3);
});
test('per-account timestamps retain their source identity, precision, order and offset', () => {
  const p = fixture(), mapped = addPositions(oldCash(), p).bank_positions;
  assert.deepEqual(mapped, p.accounts);
  assert.equal(mapped[0].as_of, '2031-02-13T06:13:11.456-03:00');
  assert.notEqual(mapped[0].as_of, mapped[1].as_of);
  assert.deepEqual(mapped.map(x => x.institution_code), ['341', '237', '336']);
});
test('timestamps never fall back to computed_at, the page date, item sync or another account', () => {
  const p = fixture(); p.accounts[1].as_of = null;
  const mapped = addPositions(oldCash(), { ...p, item_sync: '2099-01-01' });
  assert.equal(mapped.bank_positions[1].as_of, null);
  assert.equal(mapped.bank_positions[0].as_of, p.accounts[0].as_of);
});
test('no synthetic current position is created when the optional contract is missing', () => {
  assert.equal(addPositions(oldCash(), {}).bank_positions, null);
});
test('new timestamp with unchanged balance and old timestamp with changed balance pass through without inference', () => {
  const p = fixture(); p.accounts[0].as_of = '2031-02-14T06:00:00-03:00';
  const a = addPositions(oldCash(), p); assert.equal(a.bank_positions[0].balance, 1234.56);
  p.accounts[0].balance = 999.99;
  const b = addPositions(oldCash(), p); assert.equal(b.bank_positions[0].as_of, a.bank_positions[0].as_of);
  assert.equal(b.cash, a.cash); // mapper never recomputes or substitutes any current figure
});
test('dates cross BRT midnight and future dates are preserved for UI assessment', () => {
  const p = fixture(); p.accounts[0].as_of = '2031-02-14T02:59:59Z'; p.accounts[2].as_of = '2099-01-01T00:00:00Z';
  const a = addPositions(oldCash(), p);
  assert.equal(a.bank_positions[0].as_of, p.accounts[0].as_of);
  assert.equal(a.bank_positions[2].as_of, p.accounts[2].as_of);
});
test('only existing safe source projection is carried, no account_ref/raw/normalized/hash', () => {
  const accounts = addPositions(oldCash(), fixture()).bank_positions;
  const expected = ['as_of', 'balance', 'institution', 'institution_code', 'source_id'];
  for (const a of accounts) assert.deepEqual(Object.keys(a).sort(), expected);
  const reader = readFileSync(new URL('baseline/lts_open_finance_current_bank_position_v1.sql', base), 'utf8');
  assert.doesNotMatch(reader, /'account_ref'|'payload'|'source_hash'|'raw_payload'|'normalized_payload'/);
});
test('mapper does not mutate existing structures', () => {
  const old = oldCash(), positions = fixture(), saved = structuredClone({ old, positions });
  const mapped = addPositions(old, positions); mapped.bank_positions[0].balance = 0;
  assert.deepEqual({ old, positions }, saved);
});
test('cash242 merges new root property unchanged while applying existing adjustments', () => {
  const cash = addPositions(oldCash(), fixture());
  const merge = { ...cash, brokerage_available: 70, available_total: 1303.69, reader_revision: 'v242-settled-resource-transfers' };
  assert.deepEqual(merge.bank_positions, cash.bank_positions);
  const wrapper = readFileSync(new URL('baseline/lts_browser_cash_today_v242.sql', base), 'utf8');
  assert.match(wrapper, /RETURN j\|\|jsonb_build_object/);
  assert.doesNotMatch(wrapper, /bank_positions/);
});
