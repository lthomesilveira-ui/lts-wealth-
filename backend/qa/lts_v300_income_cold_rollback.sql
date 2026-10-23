-- Run manually in a private administrative SQL session; never publish the payload.
-- Only disposable owner read memos are made ineligible, inside this transaction.
-- Shared PostgreSQL buffers and structural history read models may remain warm.
BEGIN;
SET LOCAL timezone='America/Sao_Paulo';
SET LOCAL lock_timeout='1s';
DO $$ BEGIN
 PERFORM set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text
 FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
 IF EXISTS(SELECT 1 FROM public.lts_v229_read_cache WHERE user_id=public.lts_open_finance_pilot_owner_v1()
  GROUP BY kind,from_date,to_date HAVING count(*)>1) THEN RAISE EXCEPTION 'V300 disposable memo identity collision'; END IF;
END $$;
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
UPDATE public.lts_v229_read_cache SET as_of='2000-01-01',source_fingerprint='v300-income-cold-rollback',refreshed_at='2000-01-01'
WHERE user_id=public.lts_open_finance_pilot_owner_v1();
SET LOCAL ROLE authenticated;
SET LOCAL statement_timeout='8s';
WITH started AS MATERIALIZED(SELECT clock_timestamp() t),answer AS MATERIALIZED(
 SELECT t,public.lts_browser_income_review_queue_v296('2013-10-10',current_date,0,25,null) j FROM started)
SELECT round(extract(epoch FROM(clock_timestamp()-t))*1000) elapsed_ms,j AS payload,
 md5(j::text) queue_digest,current_user AS role,current_setting('statement_timeout') AS statement_timeout
FROM answer;
ROLLBACK;
