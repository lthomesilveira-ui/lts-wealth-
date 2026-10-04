-- Preserve read-only RPC semantics: compute exact results without storing a cache.
-- Existing grants, financial engines, epoch checks and owners remain unchanged.
CREATE OR REPLACE FUNCTION public.lts_card_invoice_amounts_v230(p_user_id uuid)
 RETURNS TABLE(user_id uuid, card_name text, reference_month date, due_date date, status text, amount numeric, source text)
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
#variable_conflict use_column
DECLARE memo jsonb; source_epoch bigint; fingerprint text;
BEGIN
 IF p_user_id IS NULL THEN RETURN QUERY SELECT * FROM public.lts_card_invoice_amounts_v230_engine_v243(p_user_id); RETURN;END IF;
 SELECT epoch INTO source_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 fingerprint:='source-v243:'||source_epoch;
 SELECT payload INTO memo FROM public.lts_v229_read_cache c WHERE c.user_id=p_user_id
 AND c.kind='lts_card_invoice_amounts_v230_v243' AND c.as_of=current_date AND c.from_date=current_date AND c.to_date=current_date
 AND c.source_fingerprint=fingerprint AND c.refreshed_at>clock_timestamp()-interval '5 minutes';
 IF memo IS NULL THEN
  SELECT coalesce(jsonb_agg(to_jsonb(r)),'[]') INTO memo FROM public.lts_card_invoice_amounts_v230_engine_v243(p_user_id) r;
  IF source_epoch IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN
   RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
  END IF;
  IF NOT current_setting('transaction_read_only')::boolean THEN
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
  VALUES(p_user_id,'lts_card_invoice_amounts_v230_v243',current_date,current_date,current_date,memo,fingerprint,clock_timestamp())
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;
  END IF;
 END IF;
 RETURN QUERY SELECT r.user_id,r.card_name,r.reference_month,r.due_date,r.status,r.amount,r.source FROM jsonb_array_elements(memo) WITH ORDINALITY a(j,ord)
 CROSS JOIN LATERAL jsonb_to_record(a.j) r(user_id uuid, card_name text, reference_month date, due_date date, status text, amount numeric, source text) ORDER BY a.ord;
END $function$;


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
 cache_key:='flow-key-v243:'||source_epoch||':'||freshness_key;
 SELECT payload INTO memo FROM public.lts_v229_read_cache c
 WHERE c.user_id=p_user_id AND c.kind='flow_source_key_v243' AND c.as_of=current_date
 AND c.from_date=current_date AND c.to_date=current_date AND c.source_fingerprint=cache_key
 AND c.refreshed_at>clock_timestamp()-interval '5 minutes';
 IF memo IS NOT NULL THEN RETURN memo#>>'{}'; END IF;
 key_value:=public.lts_flow_read_key_engine_v243(p_user_id);
 IF source_epoch IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
 END IF;
 IF NOT current_setting('transaction_read_only')::boolean THEN
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
 VALUES(p_user_id,'flow_source_key_v243',current_date,current_date,current_date,to_jsonb(key_value),cache_key,clock_timestamp())
 ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;
  END IF;
 RETURN key_value;
END $function$;


CREATE OR REPLACE FUNCTION public.lts_historical_effective_cash_v4(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean, internal_transfer boolean, category text, counterparty text, center_cost text, excluded_from_spend boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
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
  IF NOT current_setting('transaction_read_only')::boolean THEN
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
  VALUES(p_user_id,'historical_cash_v4_v243',current_date,p_from,p_to,memo,'cash-v243:'||source_epoch,clock_timestamp())
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;
  END IF;
 END IF;
 RETURN QUERY SELECT r.event_date,r.account,r.description,r.signed_amount,r.source,r.source_ref,r.confidence,r.account_assignment,r.legacy_index,r.original_date,r.displaced,r.internal_transfer,r.category,r.counterparty,r.center_cost,r.excluded_from_spend FROM jsonb_array_elements(memo) WITH ORDINALITY AS a(j,ord)
 CROSS JOIN LATERAL jsonb_to_record(a.j) AS r(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean, internal_transfer boolean, category text, counterparty text, center_cost text, excluded_from_spend boolean)
 WHERE r.event_date BETWEEN p_from AND p_to ORDER BY a.ord;
END $function$;


CREATE OR REPLACE FUNCTION public.lts_payroll_bank_matches_v231(p_user_id uuid)
 RETURNS TABLE(projection_ref text, projection_date date, projection_amount numeric, staging_id uuid, actual_date date, actual_amount numeric, bank text)
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
#variable_conflict use_column
DECLARE memo jsonb; source_epoch bigint; fingerprint text;
BEGIN
 IF p_user_id IS NULL THEN RETURN QUERY SELECT * FROM public.lts_payroll_bank_matches_v231_engine_v243(p_user_id); RETURN;END IF;
 SELECT epoch INTO source_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 fingerprint:='source-v243:'||source_epoch;
 SELECT payload INTO memo FROM public.lts_v229_read_cache c WHERE c.user_id=p_user_id
 AND c.kind='lts_payroll_bank_matches_v231_v243' AND c.as_of=current_date AND c.from_date=current_date AND c.to_date=current_date
 AND c.source_fingerprint=fingerprint AND c.refreshed_at>clock_timestamp()-interval '5 minutes';
 IF memo IS NULL THEN
  SELECT coalesce(jsonb_agg(to_jsonb(r)),'[]') INTO memo FROM public.lts_payroll_bank_matches_v231_engine_v243(p_user_id) r;
  IF source_epoch IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN
   RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
  END IF;
  IF NOT current_setting('transaction_read_only')::boolean THEN
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
  VALUES(p_user_id,'lts_payroll_bank_matches_v231_v243',current_date,current_date,current_date,memo,fingerprint,clock_timestamp())
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;
  END IF;
 END IF;
 RETURN QUERY SELECT r.projection_ref,r.projection_date,r.projection_amount,r.staging_id,r.actual_date,r.actual_amount,r.bank FROM jsonb_array_elements(memo) WITH ORDINALITY a(j,ord)
 CROSS JOIN LATERAL jsonb_to_record(a.j) r(projection_ref text, projection_date date, projection_amount numeric, staging_id uuid, actual_date date, actual_amount numeric, bank text) ORDER BY a.ord;
END $function$;
