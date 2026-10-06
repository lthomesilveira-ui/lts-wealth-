DO $lease$ BEGIN
 IF md5(btrim(pg_get_functiondef('public.lts_browser_flow_v241(date,date)'::regprocedure),E' \t\r\n'))<>'308119cfa3dd2eab7eb0473c7f37e84b'
 THEN RAISE EXCEPTION 'V254_SOURCE_LEASE_CHANGED';END IF;
END $lease$;
CREATE OR REPLACE FUNCTION public.lts_flow_v241_engine_v254(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '45s'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); j jsonb;
BEGIN
 j:=public.lts_browser_flow_v240(p_from,p_to);
 RETURN j||jsonb_build_object('flow',public.lts_flow_fgts_owner_policy_v241(j->'flow',current_date),
  'reader_revision','v241-documentary-fgts-owner-policy');
END $function$;
REVOKE ALL ON FUNCTION public.lts_flow_v241_engine_v254(date,date) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.lts_browser_flow_v241(p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' SET "TimeZone" TO 'America/Sao_Paulo' SET statement_timeout TO '45s'
AS $fn$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); j jsonb; epoch_before bigint; k text;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_to-p_from>12000 THEN RAISE EXCEPTION 'invalid range';END IF;
 SELECT epoch INTO epoch_before FROM public.lts_read_cache_epoch_v242 WHERE singleton;
 k:='flow-v241-exact-v254:'||epoch_before||':'||public.lts_flow_bank_freshness_key_v246(u);
 SELECT payload INTO j FROM public.lts_v229_read_cache
 WHERE user_id=u AND kind='flow_v241_exact_v254' AND as_of=current_date
 AND from_date=p_from AND to_date=p_to AND source_fingerprint=k
 AND refreshed_at>clock_timestamp()-interval '30 minutes';
 IF FOUND THEN RETURN j;END IF;
 j:=public.lts_flow_v241_engine_v254(p_from,p_to);
 IF epoch_before IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
 END IF;
 IF NOT current_setting('transaction_read_only')::boolean THEN
  BEGIN
   INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
   VALUES(u,'flow_v241_exact_v254',current_date,p_from,p_to,j,k,clock_timestamp())
   ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET
    payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;
  EXCEPTION WHEN read_only_sql_transaction THEN NULL;
  END;
 END IF;
 RETURN j;
END $fn$;
DO $lease$ BEGIN
 IF md5(btrim(pg_get_functiondef('public.lts_warm_flow_cache_v245()'::regprocedure),E' \t\r\n'))<>'2d3dbd28b69d942ec8fc0c868f72e5b9' THEN RAISE EXCEPTION 'V254_WARM_SOURCE_LEASE_CHANGED';END IF;
END $lease$;
CREATE OR REPLACE FUNCTION public.lts_warm_flow_cache_v245()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '45s'
AS $function$
DECLARE uid uuid:=public.lts_open_finance_pilot_owner_v1(); mail text;
 previous_claims text:=current_setting('request.jwt.claims',true); j jsonb; cache_epoch bigint; started timestamptz:=clock_timestamp(); freshness_key text;
 from_day date:=date_trunc('year',current_date)::date; to_day date:=make_date(extract(year from current_date)::int+1,12,31);
BEGIN
 IF NOT pg_try_advisory_xact_lock(hashtextextended('lts-flow-warm-v245',0)) THEN RETURN jsonb_build_object('ok',true,'already_running',true);END IF;
 SELECT email INTO mail FROM auth.users WHERE id=uid;
 IF mail IS NULL THEN RAISE EXCEPTION 'pilot owner unavailable';END IF;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',uid,'email',mail,'role','service_role')::text,true);
 BEGIN
  j:=public.lts_browser_flow_v242(from_day,to_day);
  PERFORM public.lts_browser_flow_v241(current_date,to_day);
 EXCEPTION WHEN OTHERS THEN
  PERFORM set_config('request.jwt.claims',coalesce(previous_claims,''),true);RAISE;
 END;
 PERFORM set_config('request.jwt.claims',coalesce(previous_claims,''),true);
 SELECT epoch INTO cache_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 freshness_key:=public.lts_flow_bank_freshness_key_v246(uid);
 UPDATE public.lts_v229_read_cache SET refreshed_at=clock_timestamp()
 WHERE user_id=uid AND kind='flow_v242' AND as_of=current_date AND from_date=from_day AND to_date=to_day
 AND source_fingerprint='v246.1:'||cache_epoch||':'||freshness_key;
 RETURN jsonb_build_object('ok',true,'from',from_day,'to',to_day,'days',
  jsonb_array_length(j#>'{flow,historical,days}')+jsonb_array_length(j#>'{flow,current_future,days}'),
  'elapsed_ms',round(extract(epoch from(clock_timestamp()-started))*1000,1));
END $function$;
