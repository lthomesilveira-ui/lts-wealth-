-- Execution-only optimization. Financial source rows and engine are unchanged.
BEGIN;
DO $lease$ BEGIN
 IF md5(pg_get_functiondef('public.lts_corrected_cashflow_fix86_v1(uuid,date,date)'::regprocedure)) <> 'edeef1d7a23358dc3ab66265cdc8b444' THEN
  RAISE EXCEPTION 'V268 source definition changed; inspect before applying';
 END IF;
END $lease$;
CREATE OR REPLACE FUNCTION public.lts_corrected_cashflow_fix86_v1(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE memo jsonb; source_epoch bigint; fingerprint text; cache_from date; cache_to date;
BEGIN
 IF p_user_id IS NULL OR p_from IS NULL OR p_to IS NULL OR p_from>p_to THEN
  RETURN QUERY SELECT * FROM public.lts_corrected_cashflow_fix86_v1_engine_v247(p_user_id,p_from,p_to); RETURN;
 END IF;
 SELECT epoch INTO source_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton;
 -- Share one source evaluation across nested ranges. Keep timezone/business-day semantics.
 cache_from:=least(p_from,date '2013-10-10');
 cache_to:=greatest(p_to,make_date(extract(year from current_date)::integer+1,12,31));
 fingerprint:='cash-base-v268:'||source_epoch||':'||current_setting('TimeZone')||':'||(current_timestamp AT TIME ZONE 'America/Sao_Paulo')::date;
 SELECT c.payload INTO memo FROM public.lts_v229_read_cache c WHERE c.user_id=p_user_id
 AND c.kind='corrected_cash_v1_v268' AND c.as_of=current_date AND c.from_date<=cache_from AND c.to_date>=cache_to
 AND c.source_fingerprint=fingerprint AND c.refreshed_at>clock_timestamp()-interval '5 minutes'
 ORDER BY c.to_date-c.from_date,c.refreshed_at DESC LIMIT 1;
 IF memo IS NULL THEN
  SELECT coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) INTO memo
  FROM public.lts_corrected_cashflow_fix86_v1_engine_v247(p_user_id,cache_from,cache_to) r;
  IF source_epoch IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton) THEN
   RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
  END IF;
  IF NOT current_setting('transaction_read_only')::boolean THEN
   BEGIN
    INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
    VALUES(p_user_id,'corrected_cash_v1_v268',current_date,cache_from,cache_to,memo,fingerprint,clock_timestamp())
    ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE
    SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;
   EXCEPTION WHEN read_only_sql_transaction THEN NULL;
   END;
  END IF;
 END IF;
 RETURN QUERY SELECT r.event_date,r.account,r.description,r.signed_amount,r.source,r.source_ref,r.confidence,r.account_assignment,r.legacy_index,r.original_date,r.displaced
 FROM jsonb_array_elements(memo) WITH ORDINALITY a(j,ord)
 CROSS JOIN LATERAL jsonb_to_record(a.j) r(event_date date,account text,description text,signed_amount numeric,source text,source_ref text,confidence text,account_assignment text,legacy_index integer,original_date date,displaced boolean)
 -- The original engine excludes legacy rows by original_date before displacement.
 -- Retain that request-specific cutoff when slicing a shared wider evaluation.
 WHERE r.event_date BETWEEN p_from AND p_to
 AND (r.source IS DISTINCT FROM 'legacy_fix86' OR r.original_date<=p_to)
 ORDER BY a.ord;
END $function$
;
COMMIT;

