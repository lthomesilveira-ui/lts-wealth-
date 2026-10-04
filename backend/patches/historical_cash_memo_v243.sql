CREATE OR REPLACE FUNCTION public.lts_historical_cash_engine_v243(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean, internal_transfer boolean, category text, counterparty text, center_cost text, excluded_from_spend boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH paid AS MATERIALIZED(SELECT public.lts_c6_paid_identity_v237(p_user_id) j),
base AS MATERIALIZED(SELECT * FROM public.lts_historical_effective_cash_v4_pre_v237(p_user_id,p_from-7,p_to+7)),
effective AS MATERIALIZED(
 SELECT e.evidence_date,f.id::text fact_id
 FROM public.lts_reconciliation_evidence e JOIN public.financial_events f
 ON f.user_id=e.user_id AND f.event_date::text=e.metadata->>'posting_date'
 AND f.amount=e.amount AND lower(trim(f.description_raw))=lower(trim(e.description))
 JOIN public.accounts a ON a.id=f.account_id AND a.user_id=f.user_id
 AND translate(lower(trim(a.institution)),'ú','u')=translate(lower(trim(e.account)),'ú','u')
 WHERE e.user_id=p_user_id AND e.evidence_type='bank_statement' AND e.status='documented'
 AND e.metadata->>'cash_effect'='statement_fact_not_new_projection'
 AND e.metadata->>'balance_effective_date'=e.evidence_date::text AND e.metadata->>'initiated_date'=e.evidence_date::text
 AND f.event_date>e.evidence_date AND f.event_date<=e.evidence_date+7
 AND f.metadata->>'documented_statement_fact'='true' AND NOT f.is_projection AND NOT f.is_suppressed AND f.status<>'cancelled'
 AND e.evidence_date BETWEEN p_from-7 AND p_to+7
 GROUP BY e.id,e.evidence_date,f.id,a.institution
 HAVING (SELECT count(*) FROM public.financial_events fx JOIN public.accounts ax ON ax.id=fx.account_id
 WHERE fx.user_id=e.user_id AND fx.event_date=f.event_date AND fx.amount=e.amount
 AND lower(trim(fx.description_raw))=lower(trim(e.description)) AND ax.institution=a.institution
 AND NOT fx.is_projection AND NOT fx.is_suppressed AND fx.status<>'cancelled')=1
), displaced AS(
 SELECT CASE WHEN b.source='legacy_fix86' AND b.source_ref IN('evento_base:'||(paid.j->>'transfer_idx'),'evento_base:'||(paid.j->>'receipt_idx'))
 THEN (paid.j->>'paid_date')::date ELSE coalesce(e.evidence_date,b.event_date) END event_date,
 b.account,b.description,b.signed_amount,b.source,b.source_ref,
 CASE WHEN e.fact_id IS NOT NULL THEN 'documented_statement_balance_effective_date'
 WHEN b.source='legacy_fix86' AND b.source_ref IN('evento_base:'||(paid.j->>'transfer_idx'),'evento_base:'||(paid.j->>'receipt_idx')) THEN 'bank_documented_settlement_date' ELSE b.confidence END confidence,
 b.account_assignment,b.legacy_index,b.original_date,
 b.displaced OR e.fact_id IS NOT NULL OR coalesce((b.source='legacy_fix86' AND b.source_ref IN('evento_base:'||(paid.j->>'transfer_idx'),'evento_base:'||(paid.j->>'receipt_idx'))),false) displaced,
 CASE WHEN b.source='legacy_fix86' AND b.source_ref IN('evento_base:'||(paid.j->>'transfer_idx'),'evento_base:'||(paid.j->>'receipt_idx')) THEN true ELSE b.internal_transfer END internal_transfer,
 b.category,b.counterparty,b.center_cost,b.excluded_from_spend
 FROM base b CROSS JOIN paid LEFT JOIN effective e ON b.source IN('current_event','financial_events','confirmed_fact') AND b.source_ref IN(e.fact_id,'financial_events:'||e.fact_id)
), recovered AS(
 SELECT (j->>'paid_date')::date event_date,'C6'::text account,'Pagamento fatura C6 · liquidação bancária'::text description,
 -(j->>'amount')::numeric signed_amount,'bank_documented_card_settlement'::text source,'evento_base:'||(j->>'payment_idx') source_ref,
 'invoice_and_checking_settlement_identity'::text confidence,'documented_bank_account'::text account_assignment,(j->>'payment_idx')::int legacy_index,
 date '2026-07-05' original_date,true displaced,false internal_transfer,'Pagamento de fatura'::text category,'C6 Bank'::text counterparty,
 'Não atribuído'::text center_cost,true excluded_from_spend FROM paid
 WHERE j IS NOT NULL AND NOT EXISTS(SELECT 1 FROM base b WHERE b.source_ref='evento_base:'||(j->>'payment_idx'))
)
SELECT * FROM displaced WHERE event_date BETWEEN p_from AND p_to
UNION ALL SELECT * FROM recovered WHERE event_date BETWEEN p_from AND p_to;
$function$
;
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
 AND c.as_of=current_date AND c.from_date=p_from AND c.to_date=p_to
 AND c.source_fingerprint='cash-v243:'||source_epoch
 AND c.refreshed_at>clock_timestamp()-interval '5 minutes';
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
 RETURN QUERY SELECT r.* FROM jsonb_to_recordset(memo) AS r(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean, internal_transfer boolean, category text, counterparty text, center_cost text, excluded_from_spend boolean);
END $function$;
REVOKE ALL ON FUNCTION public.lts_historical_cash_engine_v243(uuid,date,date) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_historical_effective_cash_v4(uuid,date,date) FROM PUBLIC,anon,authenticated;
