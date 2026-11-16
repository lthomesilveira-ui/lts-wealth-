CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.long_flow_raw_v450(p_user_id uuid, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE before_key text; after_key text; cached jsonb; result jsonb; old_lock text;
BEGIN
 IF p_to IS NULL OR p_to<current_date OR p_to-current_date>12030 THEN RAISE EXCEPTION 'invalid long flow range'; END IF;
 before_key:=lts_product_refresh_private_v415.long_flow_guard_v450(p_user_id);
 IF before_key IS NOT NULL THEN
  SELECT payload INTO cached FROM public.lts_v229_read_cache
   WHERE user_id=p_user_id AND kind='long_flow_raw_v450' AND as_of=current_date
    AND from_date=current_date AND to_date=p_to AND source_fingerprint=before_key;
  IF cached IS NOT NULL AND jsonb_typeof(cached->'raw')='object'
   AND cached->>'digest'=md5((cached->'raw')::text) THEN
   IF before_key IS DISTINCT FROM lts_product_refresh_private_v415.long_flow_guard_v450(p_user_id) THEN
    RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Long flow sources changed during read';
   END IF;
   RETURN cached->'raw';
  END IF;
 END IF;
 -- Exact same engine, exact same range and JSON. No slicing, invoice overlay,
 -- D+30 calculation, rounding or financial-source mutation is introduced here.
 result:=public.lts_daily_flow_fix86_v20(p_user_id,current_date,p_to);
 after_key:=lts_product_refresh_private_v415.long_flow_guard_v450(p_user_id);
 IF before_key IS DISTINCT FROM after_key THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Long flow sources changed during read';
 END IF;
 IF before_key IS NOT NULL AND NOT current_setting('transaction_read_only')::boolean THEN
  old_lock:=current_setting('lock_timeout');
  BEGIN
   PERFORM set_config('lock_timeout','100ms',true);
   INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
    VALUES(p_user_id,'long_flow_raw_v450',current_date,current_date,p_to,
     jsonb_build_object('raw',result,'digest',md5(result::text)),clock_timestamp(),before_key)
    ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,
     refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
  EXCEPTION WHEN read_only_sql_transaction OR lock_not_available THEN NULL;
  END;
  PERFORM set_config('lock_timeout',old_lock,true);
 END IF;
 IF before_key IS DISTINCT FROM lts_product_refresh_private_v415.long_flow_guard_v450(p_user_id) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Long flow sources changed during read';
 END IF;
 RETURN result;
END
$function$
