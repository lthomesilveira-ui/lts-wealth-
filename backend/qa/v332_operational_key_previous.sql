CREATE OR REPLACE FUNCTION public.lts_operational_source_key_v238(p_user_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE e bigint; result text;
BEGIN
 SELECT epoch INTO e FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 SELECT payload->>'value' INTO result FROM public.lts_v229_read_cache WHERE user_id=p_user_id AND kind='operational_key_v242' AND as_of=current_date AND from_date=current_date AND to_date=current_date AND source_fingerprint=e::text AND refreshed_at>clock_timestamp()-interval '30 minutes';
 IF FOUND THEN RETURN result; END IF;
 result:=public.lts_operational_source_key_pre_v242(p_user_id);
 IF e<>(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read'; END IF;
 IF NOT current_setting('transaction_read_only')::boolean THEN
 BEGIN
 INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
 VALUES(p_user_id,'operational_key_v242',current_date,current_date,current_date,jsonb_build_object('value',result),clock_timestamp(),e::text)
 ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
 EXCEPTION WHEN read_only_sql_transaction THEN NULL;
 END;
 END IF;
 RETURN result;
END $function$
