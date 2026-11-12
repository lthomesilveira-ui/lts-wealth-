DO $rollback$ BEGIN IF md5(pg_get_functiondef('public.lts_historical_effective_cash_v4(uuid,date,date)'::regprocedure))<>'b5d0f51f32e389f903e2b6e2785cf63f' THEN RAISE EXCEPTION 'V442 history changed since installation';END IF;EXECUTE $previous$CREATE OR REPLACE FUNCTION public.lts_historical_effective_cash_v4(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean, internal_transfer boolean, category text, counterparty text, center_cost text, excluded_from_spend boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE saved_v442 jsonb; memo_key_v442 text; memo jsonb; source_epoch bigint;
BEGIN
 IF p_user_id IS NULL OR p_from IS NULL OR p_to IS NULL OR p_from>p_to THEN
  RETURN QUERY SELECT * FROM public.lts_historical_cash_engine_v243(p_user_id,p_from,p_to); RETURN;
 END IF;
 SELECT epoch INTO source_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;

 memo_key_v442:=encode(sha256(convert_to(jsonb_build_array(p_user_id,p_from,p_to,current_user,auth.uid(),pg_backend_pid(),statement_timestamp(),pg_current_snapshot()::text,current_date,current_setting('TimeZone'),source_epoch,lts_product_refresh_private_v415.card_source_key(p_user_id))::text,'UTF8')),'hex');
 BEGIN saved_v442:=nullif(current_setting('lts.history_memo_v442',true),'')::jsonb;
 EXCEPTION WHEN invalid_text_representation THEN saved_v442:=NULL;END;
 IF saved_v442->>'key'=memo_key_v442 AND jsonb_typeof(saved_v442->'payload')='array'
 AND saved_v442->>'digest'=encode(sha256(convert_to((saved_v442->'payload')::text,'UTF8')),'hex') THEN memo:=saved_v442->'payload';END IF;
 IF memo IS NULL THEN
 SELECT payload INTO memo FROM public.lts_v229_read_cache c
 WHERE c.user_id=p_user_id AND c.kind='historical_cash_v4_v243'
 AND c.as_of=current_date AND c.from_date<=p_from AND c.to_date=p_to
 AND c.source_fingerprint='cash-v243:'||source_epoch
 AND c.refreshed_at>clock_timestamp()-interval '5 minutes'
 ORDER BY c.to_date-c.from_date,c.refreshed_at DESC LIMIT 1;
 END IF;
 IF memo IS NULL THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO memo
  FROM public.lts_historical_cash_engine_v243(p_user_id,p_from,p_to) x;
  IF source_epoch IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN
   RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
  END IF;
  IF NOT current_setting('transaction_read_only')::boolean THEN
  IF NOT current_setting('transaction_read_only')::boolean THEN
 BEGIN
 PERFORM lts_read_private_v430.try_cache_put(p_user_id,'historical_cash_v4_v243',current_date,p_from,p_to,memo,'cash-v243:'||source_epoch); /* optional_memo_v442 */
 EXCEPTION WHEN read_only_sql_transaction THEN NULL;
 END;
 END IF;
  END IF;
 END IF;
 PERFORM set_config('lts.history_memo_v442',jsonb_build_object('key',memo_key_v442,'payload',memo,'digest',encode(sha256(convert_to(memo::text,'UTF8')),'hex'))::text,true);
 RETURN QUERY SELECT r.event_date,r.account,r.description,r.signed_amount,r.source,r.source_ref,r.confidence,r.account_assignment,r.legacy_index,r.original_date,r.displaced,r.internal_transfer,r.category,r.counterparty,r.center_cost,r.excluded_from_spend FROM jsonb_array_elements(memo) WITH ORDINALITY AS a(j,ord)
 CROSS JOIN LATERAL jsonb_to_record(a.j) AS r(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean, internal_transfer boolean, category text, counterparty text, center_cost text, excluded_from_spend boolean)
 WHERE r.event_date BETWEEN p_from AND p_to ORDER BY a.ord;
END $function$
$previous$;END $rollback$;
