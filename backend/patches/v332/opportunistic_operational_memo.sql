-- Opportunistic memo writes; return the same computed source key on contention.
DO $lease$
DECLARE target regprocedure:='public.lts_operational_source_key_v238(uuid)'::regprocedure;
 definition text;attributes jsonb;
BEGIN
 SELECT pg_get_functiondef(target),to_jsonb(p)-'prosrc' INTO definition,attributes FROM pg_proc p WHERE p.oid=target;
 IF md5(definition) NOT IN('5d1ad053f889a52adc2f26ab579874fa','4df73b4ad0cafadc367377e48c5ca251') THEN
  RAISE EXCEPTION 'Operational key definition changed';
 END IF;
 IF md5(definition)='5d1ad053f889a52adc2f26ab579874fa' THEN
  EXECUTE $definition$CREATE OR REPLACE FUNCTION public.lts_operational_source_key_v238(p_user_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE e bigint; result text; prior_lock_timeout text;
BEGIN
 SELECT epoch INTO e FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 SELECT payload->>'value' INTO result FROM public.lts_v229_read_cache WHERE user_id=p_user_id AND kind='operational_key_v242' AND as_of=current_date AND from_date=current_date AND to_date=current_date AND source_fingerprint=e::text AND refreshed_at>clock_timestamp()-interval '30 minutes';
 IF FOUND THEN RETURN result; END IF;
 result:=public.lts_operational_source_key_pre_v242(p_user_id);
 IF e<>(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read'; END IF;
 IF NOT current_setting('transaction_read_only')::boolean THEN
 BEGIN
 -- A derived memo must not serialize otherwise independent financial reads.
 IF pg_try_advisory_xact_lock(hashtextextended('lts:operational-key:'||coalesce(p_user_id::text,'null')||':'||current_date::text,332)) THEN
  prior_lock_timeout:=current_setting('lock_timeout');
  IF prior_lock_timeout::interval=interval '0' OR prior_lock_timeout::interval>interval '100 milliseconds' THEN
   PERFORM set_config('lock_timeout','100ms',true);
  END IF;
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
  VALUES(p_user_id,'operational_key_v242',current_date,current_date,current_date,jsonb_build_object('value',result),clock_timestamp(),e::text)
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
  PERFORM set_config('lock_timeout',prior_lock_timeout,true);
 END IF;
 EXCEPTION WHEN read_only_sql_transaction OR lock_not_available THEN NULL;
 END;
 END IF;
 RETURN result;
END $function$
$definition$;
 END IF;
 IF md5(pg_get_functiondef(target))<>'4df73b4ad0cafadc367377e48c5ca251' OR attributes IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target) THEN
  RAISE EXCEPTION 'Operational key attributes changed';
 END IF;
END $lease$;
