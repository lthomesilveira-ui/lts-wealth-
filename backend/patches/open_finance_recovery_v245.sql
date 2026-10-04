CREATE TABLE IF NOT EXISTS public.lts_of_recovery_attempt_v245 (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 institution_code text NOT NULL CHECK(institution_code IN('341','237','336')),
 requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 http_request_id bigint NOT NULL
);
ALTER TABLE public.lts_of_recovery_attempt_v245 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_of_recovery_attempt_v245 FROM PUBLIC,anon,authenticated;

-- Read-only bank ingestion recovery. A successful cron enqueue alone is not
-- evidence of a completed bank sync; inspect the connection's finished success.
CREATE OR REPLACE FUNCTION public.lts_recover_stale_bank_sync_v245()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE uid uuid:=public.lts_open_finance_pilot_owner_v1(); code text; requested jsonb;
BEGIN
 IF NOT pg_try_advisory_xact_lock(hashtextextended('lts-of-recovery-v245',0)) THEN
  RETURN jsonb_build_object('ok',true,'already_running',true); END IF;
 SELECT c.institution_code INTO code FROM public.lts_open_finance_connection c
 WHERE c.user_id=uid AND c.provider='pluggy' AND c.status='connected'
 AND c.institution_code IN('341','237','336')
 AND (c.consent_expires_at IS NULL OR c.consent_expires_at>clock_timestamp())
 AND coalesce(c.last_success_at,'epoch'::timestamptz)<clock_timestamp()-interval '70 minutes'
 AND NOT EXISTS(SELECT 1 FROM public.lts_open_finance_sync_run r WHERE r.connection_id=c.id
  AND r.status='running' AND r.started_at>clock_timestamp()-interval '10 minutes')
 AND NOT EXISTS(SELECT 1 FROM public.lts_of_recovery_attempt_v245 a WHERE a.institution_code=c.institution_code
  AND a.requested_at>clock_timestamp()-interval '10 minutes')
 ORDER BY c.last_success_at NULLS FIRST,c.institution_code LIMIT 1;
 IF code IS NULL THEN RETURN jsonb_build_object('ok',true,'requested',false);END IF;
 requested:=public.lts_open_finance_enqueue_bank_v1(code,'sync');
 INSERT INTO public.lts_of_recovery_attempt_v245(institution_code,http_request_id)
 VALUES(code,(requested->>'http_request_id')::bigint);
 RETURN jsonb_build_object('ok',true,'requested',true,'institution_code',code);
END $fn$;
REVOKE ALL ON FUNCTION public.lts_recover_stale_bank_sync_v245() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_recover_stale_bank_sync_v245() TO service_role;
DO $cron$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='lts_of_recovery_v245') THEN
  PERFORM cron.schedule('lts_of_recovery_v245','2-57/5 * * * *','select public.lts_recover_stale_bank_sync_v245();');
 END IF;
END $cron$;
