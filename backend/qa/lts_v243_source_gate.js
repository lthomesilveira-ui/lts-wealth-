'use strict';
const fs=require('fs'),assert=require('assert');
const dir='backend/patches/';
const names=['checking_observation_index_v243.sql','historical_cash_memo_v243.sql','flow_source_key_memo_v243.sql','historical_cash_cover_v243.sql','repeated_sources_memo_v243.sql','linear_bank_carry_v243.sql'];
for(const name of names){const sql=fs.readFileSync(dir+name,'utf8');assert(!/GRANT[^;]+(?:anon|authenticated)/i.test(sql),name+' may not expose a helper');assert(!/DROP TABLE|TRUNCATE|DELETE FROM public\.(?:financial_events|evento_base|lts_open_finance_observation)/i.test(sql),name+' may not remove source facts');}
const index=fs.readFileSync(dir+names[0],'utf8');
assert.match(index,/user_id,connection_id/);assert.match(index,/resource_type='balance'/);
for(const name of names.slice(1,5)){const sql=fs.readFileSync(dir+name,'utf8');assert.match(sql,/source_epoch|source_fingerprint/);assert.match(sql,/WHERE c\.user_id=p_user_id/);assert.match(sql,/REVOKE ALL/);}
const repeated=fs.readFileSync(dir+names[4],'utf8');assert.equal((repeated.match(/#variable_conflict use_column/g)||[]).length,2);assert.match(repeated,/ORDER BY a\.ord/);
const cover=fs.readFileSync(dir+names[3],'utf8');assert.match(cover,/c\.from_date<=p_from AND c\.to_date=p_to/);assert.match(cover,/r\.event_date BETWEEN p_from AND p_to/);assert.match(cover,/ALTER FUNCTION public\.lts_browser_flow_v242\(date,date\) SET jit='off'/);
const linear=fs.readFileSync(dir+names[5],'utf8');assert.match(linear,/projected_rows_v243:=array_append/);assert.match(linear,/newdays:=to_jsonb\(projected_rows_v243\)/);assert.match(linear,/future source arithmetic is incomplete/);assert.match(linear,/future bank closing does not carry/);
console.log('PASS V243 private caching, exact source retention, scoped index/configuration and preserved guardrails');
