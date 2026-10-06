BEGIN;
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',c.user_id,'email',a.email,'role','authenticated')::text FROM public.lts_open_finance_connection c JOIN auth.users a ON a.id=c.user_id LIMIT 1),true);
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

DO $check$ DECLARE u uuid:=public.lts_browser_assert_user_v1();j jsonb;expected jsonb;k text;original_claims text:=current_setting('request.jwt.claims');denied boolean:=false;
BEGIN
 j:=public.lts_browser_flow_v241(current_date,make_date(extract(year from current_date)::int+1,12,31));
 SELECT source_fingerprint INTO k FROM public.lts_v229_read_cache WHERE user_id=u AND kind='flow_v241_exact_v254' AND from_date=current_date AND to_date=make_date(extract(year from current_date)::int+1,12,31);
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;
 expected:=public.lts_flow_v241_engine_v254(current_date,make_date(extract(year from current_date)::int+1,12,31));
 j:=public.lts_browser_flow_v241(current_date,make_date(extract(year from current_date)::int+1,12,31));
 IF j IS DISTINCT FROM expected THEN RAISE EXCEPTION 'V254_INVALIDATION_CORE_PARITY_FAILED';END IF;
 IF k IS NOT DISTINCT FROM(SELECT source_fingerprint FROM public.lts_v229_read_cache WHERE user_id=u AND kind='flow_v241_exact_v254' AND from_date=current_date AND to_date=make_date(extract(year from current_date)::int+1,12,31)) THEN RAISE EXCEPTION 'V254_REUSED_OLD_GENERATION';END IF;
 PERFORM set_config('request.jwt.claims','{}',true);
 BEGIN PERFORM public.lts_browser_flow_v241(current_date,make_date(extract(year from current_date)::int+1,12,31));EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'V254_AUTH_CACHE_LEAK';END IF;
 PERFORM set_config('request.jwt.claims',original_claims,true);denied:=false;
 BEGIN PERFORM public.lts_browser_flow_v241(current_date,current_date-1);EXCEPTION WHEN SQLSTATE 'P0001' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'V254_INVALID_RANGE_ACCEPTED';END IF;
 IF has_function_privilege('anon','public.lts_browser_flow_v241(date,date)','EXECUTE') THEN RAISE EXCEPTION 'V254_ANON_API_EXPOSED';END IF;
 IF (SELECT proacl::text FROM pg_proc WHERE oid='public.lts_browser_flow_v241(date,date)'::regprocedure)<>'{postgres=X/postgres,service_role=X/postgres,authenticated=X/postgres}' THEN RAISE EXCEPTION 'V254_CALLER_ACL_CHANGED';END IF;
 PERFORM set_config('lts.v254_security_receipt',jsonb_build_object('status','PASS','source_epoch_invalidation',true,'new_generation_exact_core_equal',true,'authentication_on_cache_hit',true,'invalid_range_guard',true,'caller_acl_preserved',true)::text,true);
END $check$;
SELECT current_setting('lts.v254_security_receipt')::jsonb AS receipt;
ROLLBACK;