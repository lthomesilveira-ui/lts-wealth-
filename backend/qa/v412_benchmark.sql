-- Read-only performance checks after the guarded policy seed.
-- psql -v owner_uuid='<explicit authorized owner>' -f backend/qa/v412_benchmark.sql
-- Keep the EXPLAIN results private. They are timings, not a bank-balance proof.
BEGIN READ ONLY;
EXPLAIN(ANALYZE,BUFFERS,FORMAT JSON)
SELECT lts_projection_private_v412.build(:'owner_uuid'::uuid,current_date);
EXPLAIN(ANALYZE,BUFFERS,FORMAT JSON)
SELECT count(*) FROM public.lts_corrected_cashflow_operational_v1(
 :'owner_uuid'::uuid,current_date+1,lts_projection_private_v412.horizon_end(current_date));
EXPLAIN(ANALYZE,BUFFERS,FORMAT JSON)
SELECT public.lts_daily_flow_fix86_v13(:'owner_uuid'::uuid,current_date,
 lts_projection_private_v412.horizon_end(current_date));
ROLLBACK;
