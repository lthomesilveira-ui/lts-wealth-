'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const sql=fs.readFileSync('supabase/migrations/20260924110149_v183_historical_source_lookup.sql','utf8');
test('lookup index matches the user-scoped reference expression and partial predicate',()=>{
 assert.match(sql,/ON public\.evento_base \(usuario_id, \(idx::text\)\)/);assert.match(sql,/WHERE dados \? 'dia'/);
 assert.doesNotMatch(sql,/CREATE UNIQUE INDEX/);assert.match(sql,/SET LOCAL lock_timeout = '2s'/);
});
test('the migration compares full historical outputs and never changes source facts or ACLs',()=>{
 assert.match(sql,/before_rows IS DISTINCT FROM after_rows/);assert.match(sql,/Historical source output changed/);
 assert.equal((sql.match(/public\.lts_historical_effective_cash_v3\(/g)||[]).length,2);
 assert.doesNotMatch(sql,/\b(?:UPDATE|DELETE FROM|INSERT INTO|TRUNCATE|GRANT|REVOKE|ALTER POLICY)\b/);
});
