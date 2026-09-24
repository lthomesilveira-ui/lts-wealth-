'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const sql=fs.readFileSync('supabase/migrations/20260924112500_v183_bank_evidence_freshness.sql','utf8');
test('freshness accepts only valid, non-future, checksum-backed statement evidence',()=>{
 assert.match(sql,/pg_input_is_valid/);assert.match(sql,/evidence_sha256/);assert.match(sql,/\^\[0-9a-fA-F\]\{64\}\$/);
 assert.match(sql,/statement\|extrato/);assert.match(sql,/::date<=current_date/);assert.match(sql,/jsonb_array_length/);
 assert.match(sql,/greatest\(max\(e\.evidence_date\)/);assert.match(sql,/e\.status='documented'/);
 assert.equal((sql.match(/UNION ALL SELECT m/g)||[]).length,8);assert.match(sql,/Statement provenance fixture failed/);
});
test('maintenance correction preserves account facts, other checks and access rules',()=>{
 assert.match(sql,/before_accounts IS DISTINCT FROM after_accounts/);assert.match(sql,/before_other_checks IS DISTINCT FROM after_other_checks/);
 assert.match(sql,/Maintenance reader changed/);assert.match(sql,/EXECUTE replace\(definition,expected_fragment,replacement_fragment\)/);
 assert.doesNotMatch(sql,/\b(?:INSERT INTO|UPDATE|DELETE FROM|TRUNCATE|GRANT|REVOKE|ALTER POLICY)\b/);
 assert.doesNotMatch(sql,/set_config\(|request\.jwt/);
});
