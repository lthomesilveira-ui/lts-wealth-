const fs = require('fs');
const assert = require('assert');
const patch = fs.readFileSync('backend/patches/linear_observed_guard_v256.sql','utf8');
assert(patch.includes('8824224c21aaf1cc83623d9bd4294ac2'));
assert(patch.includes('d7b44020c937ef74e4698437af9497a9'));
assert(patch.includes('V256_GUARD_SOURCE_CHANGED') && patch.includes('V256_CLASSIFICATION_SOURCE_CHANGED'));
assert(patch.includes('day_rows_v256:=array_append(day_rows_v256,d)'));
assert(patch.includes("to_jsonb(day_rows_v256)"));
assert(patch.includes("WHERE x->>'open_finance_id' IS NOT NULL OFFSET 0"));
assert(!/ALTER TABLE|DROP TABLE|DELETE FROM|UPDATE public|GRANT |cron\.schedule/i.test(patch));
for (const name of ['lts_v256_full_cold_rollback.sql','lts_v256_ranges_rollback.sql','lts_v256_guard_fixtures_rollback.sql','lts_v256_crossover_rollback.sql']) {
 const qa = fs.readFileSync('backend/qa/'+name,'utf8');
 assert(qa.trim().endsWith('ROLLBACK;'));
 assert(!/INSERT INTO public\.financial_events|UPDATE public\.financial_events|DELETE FROM public\./i.test(qa));
}
console.log('V256 guarded linear assembly, classification barrier and rollback contracts PASS');
