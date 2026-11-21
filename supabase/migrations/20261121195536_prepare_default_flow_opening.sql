-- The foreground opens five preceding days through the end of year + 5.
-- Use the existing owner-scoped warmer and the exact same financial reader.
DO $guard$
BEGIN
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.lts_warm_flow_cache_v245()'::regprocedure)
       IS DISTINCT FROM '2d056a28b30de4437c79d0515e033d9a'
     OR (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.lts_browser_flow_v242(date,date)'::regprocedure)
       IS DISTINCT FROM 'f5e81a78304316331dcbbe9dcca86627' THEN
    RAISE EXCEPTION 'Review the current Flow read contract before installation';
  END IF;
END $guard$;

CREATE FUNCTION lts_product_refresh_private_v415.warm_flow_window_v493(opening boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO '' SET timezone TO 'America/Sao_Paulo'
AS $warm$
DECLARE
  uid uuid := public.lts_open_finance_pilot_owner_v1();
  mail text;
  previous_claims text := current_setting('request.jwt.claims',true);
  from_day date := date_trunc('year',current_date)::date;
  to_day date := make_date(extract(year from current_date)::int+1,12,31);
  started timestamptz := clock_timestamp();
  cache_epoch bigint;
  freshness_key text;
  result jsonb;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtextextended('lts-flow-warm-v245',0)) THEN
    RETURN jsonb_build_object('ok',true,'already_running',true);
  END IF;
  IF opening THEN
    from_day := current_date-5;
    to_day := lts_projection_private_v412.horizon_end(current_date);
  END IF;
  SELECT email INTO STRICT mail FROM auth.users WHERE id=uid;
  IF mail IS NULL THEN RAISE EXCEPTION 'pilot owner unavailable'; END IF;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',uid,'email',mail,'role','service_role')::text,true);
  BEGIN
    result := public.lts_browser_flow_v242(from_day,to_day);
    IF NOT opening THEN
      PERFORM public.lts_browser_flow_v241(current_date,to_day);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims',coalesce(previous_claims,''),true);
    RAISE;
  END;
  PERFORM set_config('request.jwt.claims',coalesce(previous_claims,''),true);
  IF NOT opening THEN
    -- Retain the existing short-window warmer's behavior.
    SELECT epoch INTO cache_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton;
    freshness_key := public.lts_flow_bank_freshness_key_v246(uid);
    UPDATE public.lts_v229_read_cache SET refreshed_at=clock_timestamp()
      WHERE user_id=uid AND kind='flow_v242' AND as_of=current_date AND from_date=from_day AND to_date=to_day
        AND source_fingerprint='v246.1:'||cache_epoch||':'||freshness_key;
  END IF;
  RETURN jsonb_build_object('ok',true,'from',from_day,'to',to_day,'days',
    jsonb_array_length(result#>'{flow,historical,days}')+jsonb_array_length(result#>'{flow,current_future,days}'),
    'elapsed_ms',round(extract(epoch from(clock_timestamp()-started))*1000,1));
END $warm$;
REVOKE ALL ON FUNCTION lts_product_refresh_private_v415.warm_flow_window_v493(boolean) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.lts_warm_flow_cache_v245()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO '' SET timezone TO 'America/Sao_Paulo' SET statement_timeout TO '45s'
AS 'SELECT lts_product_refresh_private_v415.warm_flow_window_v493(false)';

CREATE FUNCTION lts_product_refresh_private_v415.prepare_flow_opening_v493()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO '' SET timezone TO 'America/Sao_Paulo'
AS $prepare$
DECLARE
  uid uuid := public.lts_open_finance_pilot_owner_v1();
  from_day date := current_date-5;
  to_day date := lts_projection_private_v412.horizon_end(current_date);
  fingerprint text;
  refreshed timestamptz;
BEGIN
  IF EXISTS (SELECT 1 FROM lts_product_refresh_private_v415.queue WHERE user_id=uid AND state IN ('pending','running'))
     OR NOT pg_try_advisory_xact_lock(hashtextextended('lts-flow-warm-v245',0)) THEN
    RETURN jsonb_build_object('deferred',true);
  END IF;
  SELECT 'v246.1:'||epoch||':'||public.lts_flow_bank_freshness_key_v246(uid)
    INTO STRICT fingerprint FROM public.lts_read_cache_epoch_v242 WHERE singleton;
  SELECT refreshed_at INTO refreshed FROM public.lts_v229_read_cache
    WHERE user_id=uid AND kind='flow_v242' AND as_of=current_date
      AND from_date=from_day AND to_date=to_day AND source_fingerprint=fingerprint;
  IF refreshed > clock_timestamp()-interval '22 minutes' THEN
    RETURN jsonb_build_object('ready',true);
  END IF;
  -- Rebuild before the 30-minute reader TTL. Other sessions continue to see
  -- the previous committed rows throughout the rebuild. Rollback restores both.
  DELETE FROM public.lts_v229_read_cache WHERE user_id=uid AND as_of=current_date
    AND from_date=from_day AND to_date=to_day AND kind IN ('flow_v242','flow_v241_exact_v254')
    AND refreshed_at<=clock_timestamp()-interval '22 minutes';
  RETURN lts_product_refresh_private_v415.warm_flow_window_v493(true);
END $prepare$;
REVOKE ALL ON FUNCTION lts_product_refresh_private_v415.prepare_flow_opening_v493() FROM PUBLIC,anon,authenticated,service_role;

-- Run after the existing minute worker commits, so the expensive projection
-- never holds up publication of the dashboard or a bank receipt.
DO $schedule$
DECLARE job cron.job%ROWTYPE;
BEGIN
  SELECT * INTO STRICT job FROM cron.job WHERE jobname='lts_product_refresh_pending_v415';
  IF md5(job.command) <> '9cc0ccc7b3208fe200ebef2035fa75c3' THEN
    RAISE EXCEPTION 'Review the current product refresh schedule';
  END IF;
  PERFORM cron.alter_job(job.jobid,command:=job.command||$command$
BEGIN;
SET LOCAL statement_timeout='90s';
SET LOCAL lock_timeout='500ms';
SELECT lts_product_refresh_private_v415.prepare_flow_opening_v493();
COMMIT;
$command$);
END $schedule$;
