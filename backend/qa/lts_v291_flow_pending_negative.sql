-- Transaction-only negative control: a link with invalid source proof cannot settle its forecast.
-- Caller sets request.jwt.claims, lts.qa_user_id and lts.qa_forecast_ref for one existing obligation.
BEGIN;
DO $qa$ DECLARE n integer; BEGIN
 UPDATE public.lts_v229_documentary_match
 SET evidence=jsonb_set(evidence,'{raw_hash}',to_jsonb(repeat('0',64)),true)
 WHERE user_id=current_setting('lts.qa_user_id')::uuid AND source_ref=current_setting('lts.qa_forecast_ref');
 GET DIAGNOSTICS n=ROW_COUNT;IF n<>1 THEN RAISE EXCEPTION 'Unexpected negative control scope';END IF;
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
END $qa$;
WITH pending AS MATERIALIZED(SELECT public.lts_pending_projections_v233(current_setting('lts.qa_user_id')::uuid)j)
SELECT jsonb_build_object('unverified_link_keeps_forecast',EXISTS(SELECT 1 FROM pending,jsonb_array_elements(j)x
 WHERE x->>'source_ref'=current_setting('lts.qa_forecast_ref')),'pending_count',jsonb_array_length(j))receipt FROM pending;
ROLLBACK;
