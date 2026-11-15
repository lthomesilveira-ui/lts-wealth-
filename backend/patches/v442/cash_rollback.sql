DO $rollback$ BEGIN IF md5(pg_get_functiondef('public.lts_corrected_cashflow_fix86_v1(uuid,date,date)'::regprocedure))<>'206c6ae57f42d3872a5526b6074bb9f2' THEN RAISE EXCEPTION 'V442 cash changed since installation';END IF;EXECUTE $previous$CREATE OR REPLACE FUNCTION public.lts_corrected_cashflow_fix86_v1(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE memo jsonb; source_epoch bigint; fingerprint text; cache_from date; cache_to date;
 statement_memo_v442 jsonb; statement_key_v442 text;
BEGIN
 IF p_user_id IS NULL OR p_from IS NULL OR p_to IS NULL OR p_from>p_to THEN
  RETURN QUERY SELECT * FROM public.lts_corrected_cashflow_fix86_v1_engine_v247(p_user_id,p_from,p_to); RETURN;
 END IF;
 SELECT epoch INTO source_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton;
 -- Share one source evaluation across nested ranges. Keep timezone/business-day semantics.
 cache_from:=least(p_from,date '2013-10-10');
 cache_to:=greatest(p_to,make_date(extract(year from current_date)::integer+1,12,31));
 fingerprint:='cash-base-v268:'||source_epoch||':'||current_setting('TimeZone')||':'||(current_timestamp AT TIME ZONE 'America/Sao_Paulo')::date;

 statement_key_v442:=encode(sha256(convert_to(jsonb_build_array(
  p_user_id,current_user,auth.uid(),pg_backend_pid(),statement_timestamp(),
  pg_current_snapshot()::text,current_date,current_setting('TimeZone'),source_epoch,
  lts_product_refresh_private_v415.card_source_key(p_user_id)
 )::text,'UTF8')),'hex');
 BEGIN
  statement_memo_v442:=nullif(current_setting('lts.cash_base_memo_v442',true),'')::jsonb;
 EXCEPTION WHEN invalid_text_representation THEN statement_memo_v442:=NULL;
 END;
 IF statement_memo_v442->>'key'=statement_key_v442
  AND jsonb_typeof(statement_memo_v442->'payload')='array'
  AND statement_memo_v442->>'from'~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND statement_memo_v442->>'to'~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND statement_memo_v442->>'from'<=cache_from::text AND statement_memo_v442->>'to'>=cache_to::text
  AND statement_memo_v442->>'digest'=encode(sha256(convert_to((statement_memo_v442->'payload')::text,'UTF8')),'hex') THEN
  memo:=statement_memo_v442->'payload';
 END IF;
 IF memo IS NULL THEN
 SELECT c.payload INTO memo FROM public.lts_v229_read_cache c WHERE c.user_id=p_user_id
 AND c.kind='corrected_cash_v1_v268' AND c.as_of=current_date AND c.from_date<=cache_from AND c.to_date>=cache_to
 AND c.source_fingerprint=fingerprint AND c.refreshed_at>clock_timestamp()-interval '5 minutes'
 ORDER BY c.to_date-c.from_date,c.refreshed_at DESC LIMIT 1;
 END IF;
 IF memo IS NULL THEN
  SELECT coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) INTO memo
  FROM public.lts_corrected_cashflow_fix86_v1_engine_v247(p_user_id,cache_from,cache_to) r;
  IF source_epoch IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton) THEN
   RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
  END IF;
  IF NOT current_setting('transaction_read_only')::boolean THEN
   BEGIN
    PERFORM lts_read_private_v430.try_cache_put(p_user_id,'corrected_cash_v1_v268',current_date,cache_from,cache_to,memo,fingerprint); /* optional_memo_v430 */
   EXCEPTION WHEN read_only_sql_transaction THEN NULL;
   END;
  END IF;
 END IF;
 PERFORM set_config('lts.cash_base_memo_v442',jsonb_build_object(
  'key',statement_key_v442,'from',cache_from,'to',cache_to,'payload',memo,
  'digest',encode(sha256(convert_to(memo::text,'UTF8')),'hex'))::text,true);
 RETURN QUERY SELECT r.event_date,r.account,r.description,r.signed_amount,r.source,r.source_ref,r.confidence,r.account_assignment,r.legacy_index,r.original_date,r.displaced
 FROM jsonb_array_elements(memo) WITH ORDINALITY a(j,ord)
 CROSS JOIN LATERAL jsonb_to_record(a.j) r(event_date date,account text,description text,signed_amount numeric,source text,source_ref text,confidence text,account_assignment text,legacy_index integer,original_date date,displaced boolean)
 -- The original engine excludes legacy rows by original_date before displacement.
 -- Retain that request-specific cutoff when slicing a shared wider evaluation.
 WHERE r.event_date BETWEEN p_from AND p_to
 AND (r.source IS DISTINCT FROM 'legacy_fix86' OR r.original_date<=p_to)
 ORDER BY a.ord;
END $function$
$previous$;END $rollback$;
