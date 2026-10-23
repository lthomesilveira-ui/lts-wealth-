-- Compare the entire JSON with both private cold receipts, not only row counts.
-- This is the real RPC under the unchanged authenticated statement limit.
BEGIN;
SET LOCAL timezone='America/Sao_Paulo';
DO $$ BEGIN
 PERFORM set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text
 FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
END $$;
SET LOCAL ROLE authenticated;
SET LOCAL statement_timeout='8s';
WITH started AS MATERIALIZED(SELECT clock_timestamp() t),answer AS MATERIALIZED(
 SELECT t,public.lts_browser_income_review_queue_v296('2013-10-10',current_date,0,25,null) j FROM started)
SELECT round(extract(epoch FROM(clock_timestamp()-t))*1000) elapsed_ms,j AS payload,
 md5(j::text) queue_digest,current_user AS role,current_setting('statement_timeout') AS statement_timeout
FROM answer;
ROLLBACK;
