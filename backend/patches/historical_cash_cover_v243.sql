CREATE OR REPLACE FUNCTION public.lts_historical_effective_cash_v4(p_user_id uuid,p_from date,p_to date)
RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean, internal_transfer boolean, category text, counterparty text, center_cost text, excluded_from_spend boolean) LANGUAGE plpgsql SECURITY DEFINER
SET search_path='' SET "TimeZone"='America/Sao_Paulo'
AS $function$
DECLARE memo jsonb; source_epoch bigint;
BEGIN
 IF p_user_id IS NULL OR p_from IS NULL OR p_to IS NULL OR p_from>p_to THEN
  RETURN QUERY SELECT * FROM public.lts_historical_cash_engine_v243(p_user_id,p_from,p_to); RETURN;
 END IF;
 SELECT epoch INTO source_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 SELECT payload INTO memo FROM public.lts_v229_read_cache c
 WHERE c.user_id=p_user_id AND c.kind='historical_cash_v4_v243'
 AND c.as_of=current_date AND c.from_date<=p_from AND c.to_date=p_to
 AND c.source_fingerprint='cash-v243:'||source_epoch
 AND c.refreshed_at>clock_timestamp()-interval '5 minutes'
 ORDER BY c.to_date-c.from_date,c.refreshed_at DESC LIMIT 1;
 IF memo IS NULL THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO memo
  FROM public.lts_historical_cash_engine_v243(p_user_id,p_from,p_to) x;
  IF source_epoch IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN
   RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
  END IF;
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
  VALUES(p_user_id,'historical_cash_v4_v243',current_date,p_from,p_to,memo,'cash-v243:'||source_epoch,clock_timestamp())
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;
 END IF;
 RETURN QUERY SELECT r.event_date,r.account,r.description,r.signed_amount,r.source,r.source_ref,r.confidence,r.account_assignment,r.legacy_index,r.original_date,r.displaced,r.internal_transfer,r.category,r.counterparty,r.center_cost,r.excluded_from_spend FROM jsonb_array_elements(memo) WITH ORDINALITY AS a(j,ord)
 CROSS JOIN LATERAL jsonb_to_record(a.j) AS r(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean, internal_transfer boolean, category text, counterparty text, center_cost text, excluded_from_spend boolean)
 WHERE r.event_date BETWEEN p_from AND p_to ORDER BY a.ord;
END $function$;
REVOKE ALL ON FUNCTION public.lts_historical_cash_engine_v243(uuid,date,date) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_historical_effective_cash_v4(uuid,date,date) FROM PUBLIC,anon,authenticated;

-- Scope execution configuration to this authenticated reader, never the database.
ALTER FUNCTION public.lts_browser_flow_v242(date,date) SET jit='off';
