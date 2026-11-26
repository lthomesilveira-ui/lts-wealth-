-- A bank-confirmed posting can precede the rescheduled cash reservation.
-- Keep the obligation and its review history intact, and count the posted
-- movement once in historical cash flow while formal reconciliation is pending.
CREATE OR REPLACE FUNCTION public.lts_posted_contract_reservations_v498(
  p_user_id uuid, p_from date, p_to date
) RETURNS TABLE(source_ref text)
LANGUAGE sql STABLE SET search_path = ''
AS $sql$
  SELECT f.legacy_id
  FROM public.financial_events f
  JOIN public.accounts a ON a.id = f.account_id AND a.user_id = f.user_id
  JOIN LATERAL (
    SELECT o.operation, o.payload
    FROM public.lts_flow_event_operation o
    WHERE o.user_id = f.user_id AND o.target_event_id = f.id AND o.active
    ORDER BY o.op_seq DESC LIMIT 1
  ) edit ON edit.operation = 'edit'
  JOIN LATERAL (
    SELECT s.id, s.provider_account_ref, s.occurred_at, s.posting_date, s.signed_amount,
           count(*) OVER () AS postings
    FROM public.lts_open_finance_staging s
    WHERE s.user_id = f.user_id AND s.resource_type = 'transaction'
      AND s.provider_deleted_at IS NULL AND s.institution_code = '237' AND s.currency = 'BRL'
      AND s.normalized_payload->>'account_type' = 'CHECKING_ACCOUNT'
      AND s.normalized_payload->>'status' = 'POSTED' AND s.signed_amount < 0
      AND s.description_raw = 'PRESTACAO DE CRED IMOB - DOCTO: ' || (f.metadata->>'contract_ref')
      AND s.posting_date >= date_trunc('month', f.event_date)::date
      AND s.posting_date < (date_trunc('month', f.event_date) + interval '1 month')::date
  ) debit ON debit.postings = 1
  WHERE f.user_id = p_user_id AND a.institution = 'Bradesco' AND a.account_type = 'checking'
    AND f.source = 'documented_contract_schedule' AND f.is_projection AND NOT f.is_suppressed
    AND NOT f.is_internal_transfer AND f.amount < 0 AND f.legacy_id IS NOT NULL
    AND f.metadata->>'contract_ref' ~ '^[0-9]{5,20}$' AND f.metadata->>'installment_number' ~ '^[0-9]+$'
    AND edit.payload->>'account' = a.institution
    AND CASE WHEN edit.payload->>'amount' ~ '^[0-9]+([.][0-9]+)?$'
             THEN (edit.payload->>'amount')::numeric END = -debit.signed_amount
    AND CASE WHEN edit.payload->>'event_date' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
             THEN (edit.payload->>'event_date')::date END
        BETWEEN greatest(p_from,debit.posting_date) AND least(p_to,current_date,debit.posting_date+7)
    AND debit.posting_date BETWEEN f.event_date AND f.event_date + 7
    AND NOT EXISTS (
      SELECT 1 FROM public.financial_events other
      WHERE other.user_id = f.user_id AND other.account_id = f.account_id
        AND other.id <> f.id AND NOT other.is_suppressed
        AND other.metadata->>'contract_ref' = f.metadata->>'contract_ref'
        AND other.event_date >= date_trunc('month', f.event_date)::date
        AND other.event_date < (date_trunc('month', f.event_date) + interval '1 month')::date
    )
    AND EXISTS (
      SELECT 1 FROM public.lts_realized_bank_event_v238 prior
      JOIN public.financial_events pf ON pf.id = prior.financial_event_id AND pf.user_id = prior.user_id
      JOIN public.lts_open_finance_staging ps ON ps.id = prior.staging_id AND ps.user_id = prior.user_id
      WHERE prior.user_id = f.user_id AND pf.account_id = f.account_id
        AND pf.metadata->>'contract_ref' = f.metadata->>'contract_ref' AND pf.event_date < f.event_date
        AND ps.provider_account_ref = debit.provider_account_ref
    )
    AND EXISTS (
      SELECT 1 FROM public.lts_open_finance_staging b
      WHERE b.user_id = f.user_id AND b.resource_type = 'balance'
        AND b.institution_code = '237' AND b.provider_account_ref = debit.provider_account_ref
        AND b.provider_deleted_at IS NULL AND b.normalized_payload->>'account_type' = 'CHECKING_ACCOUNT'
        AND (b.normalized_payload->>'as_of')::timestamptz >= debit.occurred_at
    )
$sql$;
REVOKE ALL ON FUNCTION public.lts_posted_contract_reservations_v498(uuid,date,date) FROM PUBLIC,anon,authenticated;
DO $migration$
DECLARE
 definition text := pg_get_functiondef('public.lts_corrected_cashflow_fix86_v4(uuid,date,date)'::regprocedure);
 anchor text := 'select * from operated_current;';
BEGIN
 IF strpos(definition,'lts_posted_contract_reservations_v498') > 0 THEN RETURN; END IF;
 IF strpos(definition,anchor) = 0 THEN RAISE EXCEPTION 'Unexpected current cash-flow definition'; END IF;
 EXECUTE replace(definition,anchor,'select o.* from operated_current o
 where not exists (select 1 from public.lts_posted_contract_reservations_v498(p_user_id,p_from,p_to) matched
                   where matched.source_ref=o.source_ref);');
END
$migration$;
-- Refresh only affected owners' previously calculated flow reports.
WITH owners AS MATERIALIZED (
  SELECT DISTINCT c.user_id FROM public.lts_v229_read_cache c
  WHERE c.kind IN ('flow_v241_exact_v254','flow_v242','long_flow_raw_v450')
), affected AS MATERIALIZED (
  SELECT DISTINCT o.user_id FROM owners o
  CROSS JOIN LATERAL public.lts_posted_contract_reservations_v498(o.user_id,date '1900-01-01',current_date) r
)
DELETE FROM public.lts_v229_read_cache c USING affected a
WHERE c.user_id=a.user_id AND c.kind IN ('flow_v241_exact_v254','flow_v242','long_flow_raw_v450','flow_source_key_v243');
