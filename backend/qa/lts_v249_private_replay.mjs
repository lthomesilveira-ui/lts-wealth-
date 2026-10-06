// Offline owner-scoped replay. Original exports are read only, never rewritten.
// Usage: node THIS baseline-core.mjs private-report.json original-export.json [...]
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
import { webcrypto } from 'node:crypto';
import { normalize as next } from '../open_finance/v249/core.mjs';
if (!globalThis.crypto) globalThis.crypto = webcrypto;
const [baselinePath, outputPath, ...sourcePaths] = process.argv.slice(2);
assert.ok(baselinePath && outputPath && sourcePaths.length, 'baseline, private output and original exports required');
assert.ok(!sourcePaths.map(x => path.resolve(x)).includes(path.resolve(outputPath)), 'do not overwrite a source');
const { normalize: before } = await import(pathToFileURL(path.resolve(baselinePath)).href);
const result = { sources: sourcePaths.length, rows: 0, card_rows: 0, semantic_changes: 0, identity_changes: 0,
  pending_consumption: 0, financial_field_parity: true, raw_sources_unchanged: true, database_restore_test: 'NOT_RUN', deployed: false };
let owner = null;
for (const sourcePath of sourcePaths) {
  const originalBytes = fs.readFileSync(sourcePath);
  const source = JSON.parse(originalBytes);
  assert.ok(source.owner_id && Array.isArray(source.rows), 'owner-scoped source export required');
  owner ??= source.owner_id; assert.equal(source.owner_id, owner, 'mixed owners');
  assert.equal(source.rows.length, source.row_count, 'source row count mismatch');
  const decoded = source.rows.map(row => ({ row, raw: typeof row.raw_payload === 'string' ? JSON.parse(row.raw_payload) : row.raw_payload,
    norm: typeof row.normalized_payload === 'string' ? JSON.parse(row.normalized_payload) : row.normalized_payload }));
  const accounts = new Map(decoded.filter(x => ['account', 'balance', 'credit_card'].includes(x.row.resource_type)).map(x => [x.raw.id, x.raw]));
  const investments = new Map(decoded.filter(x => x.row.resource_type === 'investment').map(x => [x.raw.id, x.raw]));
  for (const { row, raw, norm } of decoded) {
    const ctx = { item: { id: norm.item_id, lastUpdatedAt: norm.source_sync_at },
      institutionName: norm.institution, institutionBasis: norm.institution_basis,
      account: accounts.get(raw.accountId ?? norm.provider_account_id), investment: investments.get(norm.investment_id) };
    const rawText = JSON.stringify(raw);
    const old = await before(row.resource_type, raw, ctx), current = await next(row.resource_type, raw, ctx);
    const oldN = old.normalized_payload, nextN = current.normalized_payload;
    const allowed = row.resource_type === 'card_transaction' ? new Set(['layer', 'last4', 'warnings', 'account_last4', 'card_number_basis']) : new Set();
    for (const key of new Set([...Object.keys(oldN), ...Object.keys(nextN)])) if (!allowed.has(key)) assert.deepEqual(nextN[key], oldN[key], 'normalized financial/source field changed: ' + key);
    for (const key of Object.keys(old)) if (key !== 'normalized_payload') assert.deepEqual(current[key], old[key], 'outer economic/source field changed: ' + key);
    assert.equal(JSON.stringify(raw), rawText); assert.equal(nextN.official_effect, false);
    if (row.resource_type === 'card_transaction') {
      result.card_rows++;
      if (oldN.layer !== nextN.layer) result.semantic_changes++;
      if (oldN.last4 !== nextN.last4) result.identity_changes++;
      if (nextN.status === 'PENDING' && nextN.layer === 'card_consumption') result.pending_consumption++;
    }
    result.rows++;
  }
  assert.deepEqual(fs.readFileSync(sourcePath), originalBytes, 'original source was changed');
}
fs.writeFileSync(outputPath, JSON.stringify(result, null, 2) + '\n', { flag: 'wx', mode: 0o600 });
console.log(JSON.stringify(result));
