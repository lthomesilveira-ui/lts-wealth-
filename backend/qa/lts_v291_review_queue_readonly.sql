-- Set lts.qa_user_id before running. Authenticated production limit remains eight seconds.
BEGIN;
DO $$ BEGIN
 PERFORM set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text
 FROM auth.users WHERE id=current_setting('lts.qa_user_id')::uuid),true);
END $$;
SET LOCAL ROLE authenticated;
SET LOCAL statement_timeout='8s';
WITH started AS MATERIALIZED(SELECT clock_timestamp() t), answer AS MATERIALIZED(
 SELECT t,public.lts_browser_expense_review_queue_v229('2013-10-10',current_date,0,25,null) j FROM started
)
SELECT round(extract(epoch FROM (clock_timestamp()-t))*1000) elapsed_ms,
 j->'row_count' row_count,jsonb_array_length(j->'category_options') category_options,
 j->'pending_projections' pending_projections,current_setting('statement_timeout') statement_timeout
FROM answer;
ROLLBACK;
