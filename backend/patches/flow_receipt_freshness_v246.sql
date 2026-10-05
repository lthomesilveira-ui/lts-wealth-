CREATE OR REPLACE FUNCTION public.lts_flow_bank_freshness_key_v246(p_user_id uuid)
RETURNS text LANGUAGE sql STABLE SET search_path='' AS $fn$
SELECT md5(jsonb_agg(jsonb_build_object('bank',p->>'bank','as_of',p->>'as_of',
 'fresh',(p->>'as_of')::timestamptz BETWEEN current_timestamp-interval '24 hours' AND current_timestamp)
 ORDER BY p->>'bank')::text) FROM jsonb_array_elements(public.lts_open_finance_checking_positions_v1(p_user_id)) p;
$fn$;
REVOKE ALL ON FUNCTION public.lts_flow_bank_freshness_key_v246(uuid) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.lts_browser_flow_v242(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '45s'
 SET jit TO 'off'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); cached jsonb; j jsonb; f jsonb; cache_epoch bigint; freshness_key text;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_to-p_from>12000 THEN RAISE EXCEPTION 'invalid range'; END IF;
 SELECT epoch INTO cache_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 freshness_key:=public.lts_flow_bank_freshness_key_v246(u);
 SELECT payload INTO cached FROM public.lts_v229_read_cache WHERE user_id=u AND kind='flow_v242' AND as_of=current_date
 AND from_date<=p_from AND to_date>=p_to AND source_fingerprint='v246.1:'||cache_epoch||':'||freshness_key AND refreshed_at>clock_timestamp()-interval '30 minutes'
 ORDER BY to_date-from_date,refreshed_at DESC LIMIT 1;
 IF FOUND THEN RETURN public.lts_flow_slice_v242(cached,p_from,p_to); END IF;
 -- Keep the original bank and historical arithmetic, including unknown positions.
 j:=public.lts_browser_flow_v241(least(p_from,current_date),p_to);
 f:=public.lts_flow_liquidity_adjustments_v242(u,j->'flow',current_date);
 j:=j||jsonb_build_object('flow',f,'reader_revision','v245-dated-resources-and-movement-identity');
 j:=public.lts_flow_slice_v242(j,p_from,p_to);
 IF cache_epoch<>(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read'; END IF;
 INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
 VALUES(u,'flow_v242',current_date,p_from,p_to,j,clock_timestamp(),'v246.1:'||cache_epoch||':'||freshness_key)
 ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
 RETURN j;
END $function$
;

-- Background materialization of the two calendar years. Only the fixed pilot
-- and server roles may invoke this; callers cannot supply an owner identity.
CREATE OR REPLACE FUNCTION public.lts_warm_flow_cache_v245()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' SET statement_timeout='45s' AS $fn$
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
END $fn$;
REVOKE ALL ON FUNCTION public.lts_warm_flow_cache_v245() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_warm_flow_cache_v245() TO service_role;

