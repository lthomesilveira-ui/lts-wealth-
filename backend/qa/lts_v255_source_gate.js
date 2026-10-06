const fs = require('fs');
const assert = require('assert');
const sql = fs.readFileSync('backend/patches/documentary_daily_aggregation_v255.sql','utf8');
assert(sql.includes("7f651e68c7aa0b88d5a6245231884555"));
assert(sql.includes("V255_SOURCE_LEASE_CHANGED"));
assert(sql.includes("GROUP BY r.dt,r.bank"));
assert(sql.includes("IS DISTINCT FROM 'relative_tracked_bank_ledger'"));
assert(sql.includes("h->>'source'<>'economic_withholding'"));
assert(sql.includes("r.amount>0") && sql.includes("r.amount<0"));
assert(sql.includes("day_keys_v255"));
assert(!/ALTER TABLE|DROP TABLE|DELETE FROM|UPDATE public|GRANT |cron\.schedule/i.test(sql));
for (const name of ['lts_v255_documentary_rollback.sql','lts_v255_documentary_fixtures_rollback.sql','lts_v255_full_cold_rollback.sql']) {
 const qa = fs.readFileSync('backend/qa/'+name,'utf8');
 assert(qa.trim().endsWith('ROLLBACK;'));
 assert(!/INSERT INTO public\.financial_events|UPDATE public\.financial_events|DELETE FROM public\./i.test(qa));
}
console.log('V255 guarded sources, exact aggregation and rollback checks PASS');
