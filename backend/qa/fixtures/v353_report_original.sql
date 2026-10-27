CREATE OR REPLACE FUNCTION public.lts_browser_expenses_v229(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1(); result jsonb; source_epoch bigint;fingerprint text;
BEGIN
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<date '2013-10-10' OR p_to>current_date THEN RAISE EXCEPTION 'invalid expense range';END IF;
 SELECT epoch INTO source_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 fingerprint:='expenses-v251:'||source_epoch||':'||current_date::text;
 SELECT c.payload INTO result FROM public.lts_v229_read_cache c WHERE c.user_id=u AND c.kind='expenses_v251'
 AND c.as_of=current_date AND c.from_date=p_from AND c.to_date=p_to AND c.source_fingerprint=fingerprint
 AND c.refreshed_at>clock_timestamp()-interval '30 minutes';
 IF FOUND THEN RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,result);END IF;
 result:=public.lts_browser_expenses_v229_engine_v251(p_from,p_to);
 IF source_epoch IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
 END IF;
 IF NOT current_setting('transaction_read_only')::boolean THEN
  BEGIN
   INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
   VALUES(u,'expenses_v251',current_date,p_from,p_to,result,clock_timestamp(),fingerprint)
   ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
  EXCEPTION WHEN read_only_sql_transaction THEN NULL;
  END;
 END IF;
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,result);
END $function$
