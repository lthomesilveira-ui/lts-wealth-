const fs = require('node:fs');
const assert = require('node:assert/strict');

const textPatch = fs.readFileSync('backend/patches/text_key_inlining_v267.sql', 'utf8');
const planPatch = fs.readFileSync('backend/patches/paid_identity_prepared_plan_v267.sql', 'utf8');
const probe = fs.readFileSync('backend/qa/lts_v267_reader_probe_rollback.sql', 'utf8');
const identity = fs.readFileSync('backend/qa/lts_v267_paid_identity_rollback.sql', 'utf8');
const corpus = fs.readFileSync('backend/qa/lts_v267_text_corpus.sql', 'utf8');
const readme = fs.readFileSync('backend/patches/README_v267.md', 'utf8');
let checks = 0;
const check = (condition, message) => { assert.ok(condition, message); checks++; };

for (const patch of [textPatch, planPatch]) {
  check(/definition lease changed/.test(patch), 'definition lease required');
  check(/proacl IS DISTINCT FROM original_acl/.test(patch), 'ACL preservation required');
  check(/proowner IS DISTINCT FROM original_owner/.test(patch), 'owner preservation required');
  check(/has_function_privilege\('anon'/.test(patch), 'anonymous denial required');
  check(/has_function_privilege\('authenticated'/.test(patch), 'authenticated helper denial required');
  check(!/^\s*(?:INSERT|UPDATE|DELETE|TRUNCATE|DROP|GRANT|REVOKE)\b/im.test(patch), 'no source mutation or new grants');
}
check(textPatch.includes('8bd38f36cd64245bdf8a84464a298839'), 'normalization baseline');
check(textPatch.includes('ef89d710865b5103d08187c39226e53f'), 'merchant baseline');
check(textPatch.includes("'pg_catalog.regexp_replace('"), 'explicit built-in binding');
check(textPatch.includes("ARRAY['search_path=\"\"']::text[]"), 'only the expected pure-helper setting may be reset');
check(textPatch.includes('OR prosecdef OR proisstrict'), 'no definer/strict semantic change');
check(planPatch.includes('ebc2055bc7319d791799ef9b33e3120e'), 'paid identity baseline');
check(planPatch.includes('force_generic_plan'), 'reusable prepared plan');
check(planPatch.includes('NOT prosecdef'), 'existing privileged execution retained');
check(planPatch.includes('search_path=""'), 'paid identity path fixed');
check(!planPatch.includes('lts_v229_read_cache'), 'no payment-result memoization');
check(planPatch.includes('SELECT CASE WHEN count(*)=1'), 'unique-source identity retained');
for (const sql of [probe, identity]) {
  check(/^BEGIN;/m.test(sql) && /ROLLBACK;\s*$/.test(sql), 'transactional QA required');
}
check(probe.includes('epoch=epoch+1'), 'source-invalidated QA, not a cached pass');
check(probe.includes('md5(j::text)'), 'complete reader comparison');
check(probe.includes("-'computed_at'"), 'only the wealth calculation clock excluded');
check(probe.includes('count(DISTINCT row_key)'), 'expense identity grain');
for (const guard of ['caller_plan_mode_restored', 'deleted_invoice_rejected', 'pending_debit_rejected', 'foreign_owner_result']) {
  check(identity.includes(guard), `negative proof ${guard}`);
}
check(corpus.includes('norm_mismatches') && corpus.includes('merchant_mismatches'), 'expression equivalence receipt');
check(readme.includes('function_search_path_mutable'), 'intentional static-lint observations disclosed');
check(readme.includes('P13 remains open'), 'cold/device performance not falsely closed');
console.log(`V267 source contracts: ${checks} checks passed. Database receipts remain separate evidence.`);
