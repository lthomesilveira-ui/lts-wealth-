BEGIN;
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',c.user_id,'email',a.email,'role','authenticated')::text FROM public.lts_open_finance_connection c JOIN auth.users a ON a.id=c.user_id LIMIT 1),true);
CREATE TEMP TABLE v254_proofs(label text,lo date,hi date,expected jsonb,prior_ms numeric) ON COMMIT DROP;
DO $baseline$ DECLARE r record;j jsonb;t timestamptz;
BEGIN
 FOR r IN SELECT * FROM(VALUES('dashboard_horizon',current_date,make_date(extract(year from current_date)::int+1,12,31)),('year_2027',date '2027-01-01',date '2027-12-31'),('july_boundary',date '2026-06-30',date '2026-07-14'))v(label,lo,hi) LOOP
  t:=clock_timestamp();j:=public.lts_browser_flow_v241(r.lo,r.hi);
  INSERT INTO v254_proofs VALUES(r.label,r.lo,r.hi,j,extract(epoch from clock_timestamp()-t)*1000);
 END LOOP;
END $baseline$;
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

DO $verify$ DECLARE r record;j jsonb;t timestamptz;metrics jsonb:='[]';n int;u uuid:=public.lts_browser_assert_user_v1();denied boolean:=false;
BEGIN
 FOR r IN SELECT * FROM v254_proofs ORDER BY label LOOP
  j:=public.lts_browser_flow_v241(r.lo,r.hi);
  IF j IS DISTINCT FROM r.expected THEN RAISE EXCEPTION 'V254_FULL_JSON_CHANGED: %',r.label;END IF;
  t:=clock_timestamp();j:=public.lts_browser_flow_v241(r.lo,r.hi);
  IF j IS DISTINCT FROM r.expected THEN RAISE EXCEPTION 'V254_REPEAT_CHANGED: %',r.label;END IF;
  metrics:=metrics||jsonb_build_array(jsonb_build_object('range',r.label,'prior_ms',r.prior_ms,'cached_ms',extract(epoch from clock_timestamp()-t)*1000,'exact_json_equal',true,'digest',md5(j::text)));
 END LOOP;
 IF has_function_privilege('anon','public.lts_flow_v241_engine_v254(date,date)','EXECUTE') OR has_function_privilege('authenticated','public.lts_flow_v241_engine_v254(date,date)','EXECUTE') OR has_function_privilege('service_role','public.lts_flow_v241_engine_v254(date,date)','EXECUTE') THEN RAISE EXCEPTION 'V254_ENGINE_EXPOSED';END IF;
 -- Exact argument reuse has just been compared independently across all three ranges.
 UPDATE public.lts_v229_read_cache SET refreshed_at=clock_timestamp()-interval '31 minutes' WHERE user_id=u AND kind='flow_v241_exact_v254';
 SELECT count(*) INTO n FROM public.lts_v229_read_cache WHERE kind='flow_v241_exact_v254';
 PERFORM set_config('transaction_read_only','on',true);
 FOR r IN SELECT * FROM v254_proofs LOOP
  IF public.lts_browser_flow_v241(r.lo,r.hi) IS DISTINCT FROM r.expected THEN RAISE EXCEPTION 'V254_READ_ONLY_OUTPUT_CHANGED';END IF;
 END LOOP;
 IF n<>(SELECT count(*) FROM public.lts_v229_read_cache WHERE kind='flow_v241_exact_v254') THEN RAISE EXCEPTION 'V254_READ_ONLY_WROTE';END IF;
 PERFORM set_config('lts.v254_receipt',jsonb_build_object('status','PASS','full_output_parity',metrics,'private_engine',true,'read_only_stale_miss',true)::text,true);
END $verify$;
SELECT current_setting('lts.v254_receipt')::jsonb AS receipt;
ROLLBACK;