CREATE OR REPLACE FUNCTION public.lts_flow_read_source_key_v247(p_user_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE memo jsonb; key_value text; source_epoch bigint; freshness_key text; cache_key text;
BEGIN
 SELECT epoch INTO source_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 SELECT md5(jsonb_agg(jsonb_build_object('bank',p->>'bank','as_of',p->>'as_of',
 'fresh',(p->>'as_of')::timestamptz BETWEEN current_timestamp-interval '24 hours' AND current_timestamp)
 ORDER BY p->>'bank')::text) INTO freshness_key
 FROM jsonb_array_elements(public.lts_open_finance_checking_positions_v1(p_user_id)) p;
 cache_key:='flow-key-v293:'||source_epoch||':'||freshness_key||':'||public.lts_scheduled_transfer_revision_v293(p_user_id);
 SELECT payload INTO memo FROM public.lts_v229_read_cache c
 WHERE c.user_id=p_user_id AND c.kind='flow_source_key_v243' AND c.as_of=current_date
 AND c.from_date=current_date AND c.to_date=current_date AND c.source_fingerprint=cache_key
 AND c.refreshed_at>clock_timestamp()-interval '5 minutes';
 IF memo IS NOT NULL THEN RETURN memo#>>'{}'; END IF;
 key_value:=md5(public.lts_flow_read_key_engine_v243(p_user_id)||':schedules-v293:'||public.lts_scheduled_transfer_revision_v293(p_user_id));
 IF source_epoch IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
 END IF;
 IF NOT current_setting('transaction_read_only')::boolean THEN
  IF NOT current_setting('transaction_read_only')::boolean THEN
 BEGIN
 INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
 VALUES(p_user_id,'flow_source_key_v243',current_date,current_date,current_date,to_jsonb(key_value),cache_key,clock_timestamp())
 ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;
 EXCEPTION WHEN read_only_sql_transaction THEN NULL;
 END;
 END IF;
  END IF;
 RETURN key_value;
END $function$;
