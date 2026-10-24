-- Reuse a proved bank contract identity and exact numbered installments. No writes.
CREATE OR REPLACE FUNCTION public.lts_documentary_contract_payments_v310(p_user_id uuid,p_as_of date)
RETURNS TABLE(financial_event_id uuid,staging_id uuid,paid_date date,paid_amount numeric)
LANGUAGE sql STABLE SET search_path='' AS $fn$
WITH eligible AS MATERIALIZED (
 SELECT f.*,
 CASE WHEN pg_catalog.pg_input_is_valid(f.metadata->>'documentary_schedule_due_date','date')
  THEN (f.metadata->>'documentary_schedule_due_date')::date ELSE f.event_date END nominal_due
 FROM public.financial_events f
 JOIN public.accounts a ON a.id=f.account_id AND a.user_id=f.user_id
 WHERE f.user_id=p_user_id AND f.metadata->>'contract_ref'='volvo_financing_2026'
 AND NOT f.is_suppressed AND NOT f.is_internal_transfer AND f.nature='expense'
 AND f.status IN('scheduled','confirmed')
 AND f.metadata->>'account_assignment_status'='user_confirmed'
 AND a.institution=f.metadata->>'account_assignment'
 AND f.metadata->>'installment_number' ~ '^[1-9][0-9]{0,2}$'
 AND f.metadata->>'installments_total' ~ '^[1-9][0-9]{0,2}$'
), posted AS MATERIALIZED (
 SELECT s.*,substring(s.description_raw FROM '(?i)CONTR[[:space:]]+([0-9]+)') bank_contract,
 substring(s.description_raw FROM '(?i)PARC[[:space:]]+([0-9]+/[0-9]+)') bank_installment
 FROM public.lts_bank_posted_rows_v231(p_user_id) s
 WHERE s.user_id=p_user_id AND s.signed_amount<0 AND s.occurred_at<=current_timestamp
 AND s.raw_hash ~ '^[0-9a-f]{64}$'
 AND EXISTS(
  SELECT 1 FROM public.lts_open_finance_staging b
  WHERE b.user_id=p_user_id AND b.resource_type='balance' AND b.currency='BRL'
  AND b.provider_deleted_at IS NULL AND b.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
  AND b.institution_code=s.institution_code
  AND b.normalized_payload->>'provider_account_id'=s.normalized_payload->>'provider_account_id'
  AND CASE WHEN pg_catalog.pg_input_is_valid(b.normalized_payload->>'as_of','timestamp with time zone')
   THEN (b.normalized_payload->>'as_of')::timestamptz END>=s.occurred_at
 )
), bindings AS MATERIALIZED (
 SELECT f.metadata->>'contract_ref' series,f.account_id,dm.bank,s.institution_code,
 s.normalized_payload->>'provider_account_id' provider_account,f.metadata->>'installments_total' term,s.bank_contract,
 count(*) OVER(PARTITION BY f.id) event_claims,count(*) OVER(PARTITION BY s.id) source_claims
 FROM eligible f
 JOIN public.lts_v229_documentary_match dm ON dm.user_id=f.user_id AND dm.source_ref IN(f.id::text,f.legacy_id)
 JOIN posted s ON s.id=dm.staging_id AND s.user_id=dm.user_id
 WHERE dm.bank=f.metadata->>'account_assignment'
 AND dm.bank=CASE s.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END
 AND dm.signed_amount=f.amount AND dm.signed_amount=s.signed_amount AND dm.canonical_date=f.nominal_due
 AND dm.evidence->>'basis'='owner_confirmed_exact_obligation'
 AND dm.evidence->>'no_new_cash_event'='true' AND dm.evidence->>'raw_hash'=s.raw_hash
 AND dm.evidence->>'nominal_due_date'=f.nominal_due::text
 AND dm.evidence->>'actual_posting_date'=s.posting_date::text
 AND dm.evidence->>'contract' ~ '^[0-9]+$' AND dm.evidence->>'contract'=s.bank_contract
 AND dm.evidence->>'installment'=lpad(f.metadata->>'installment_number',3,'0')||'/'||lpad(f.metadata->>'installments_total',3,'0')
 AND dm.evidence->>'installment'=s.bank_installment
), anchors AS MATERIALIZED (
 SELECT DISTINCT series,account_id,bank,institution_code,provider_account,term,bank_contract
 FROM bindings WHERE event_claims=1 AND source_claims=1
), unambiguous_anchors AS MATERIALIZED (
 SELECT * FROM(SELECT a.*,count(*) OVER(PARTITION BY series,account_id) identity_count FROM anchors a) q
 WHERE identity_count=1
), payments AS (
 SELECT f.id financial_event_id,s.id staging_id,s.posting_date paid_date,-s.signed_amount paid_amount,
 count(*) OVER(PARTITION BY f.id) event_claims,count(*) OVER(PARTITION BY s.id) source_claims
 FROM eligible f JOIN unambiguous_anchors a ON a.series=f.metadata->>'contract_ref' AND a.account_id=f.account_id
 JOIN posted s ON s.bank_contract=a.bank_contract AND s.institution_code=a.institution_code
 AND s.normalized_payload->>'provider_account_id'=a.provider_account AND s.signed_amount=f.amount
 AND f.metadata->>'installments_total'=a.term
 AND s.bank_installment=lpad(f.metadata->>'installment_number',3,'0')||'/'||lpad(a.term,3,'0')
 WHERE s.posting_date<=p_as_of
)
SELECT financial_event_id,staging_id,paid_date,paid_amount FROM payments
WHERE event_claims=1 AND source_claims=1;
$fn$;
REVOKE ALL ON FUNCTION public.lts_documentary_contract_payments_v310(uuid,date) FROM PUBLIC,anon,authenticated;
