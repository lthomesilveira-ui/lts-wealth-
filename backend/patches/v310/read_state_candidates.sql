), documentary_payments AS MATERIALIZED (
 SELECT * FROM public.lts_documentary_contract_payments_v310(p_user_id,p_as_of)
), candidates AS MATERIALIZED (
 SELECT s.source_ref,s.origin,b.financial_event_id,b.staging_id,b.event_date paid_date,-b.signed_amount paid_amount
 FROM schedules s JOIN public.financial_events f ON f.user_id=p_user_id
 JOIN bank_sources b ON b.financial_event_id=f.id
 WHERE f.status='confirmed' AND f.nature='expense' AND NOT f.is_internal_transfer
 AND f.metadata->>'contract_ref'=s.contract_ref
 AND ((s.origin='financial_event' AND s.source_ref=f.id::text)
 OR (s.origin='documentary_schedule'
  AND f.metadata->>'installment_number'=s.installment_number::text
  AND f.metadata->>'documentary_schedule_due_date'=s.due_date::text
  AND CASE WHEN f.metadata->>'documentary_schedule_amount' ~ '^[0-9]+([.][0-9]+)?$'
   THEN (f.metadata->>'documentary_schedule_amount')::numeric END=s.amount_total))
 UNION
 SELECT s.source_ref,s.origin,d.financial_event_id,d.staging_id,d.paid_date,d.paid_amount
 FROM schedules s JOIN documentary_payments d ON s.origin='financial_event' AND s.source_ref=d.financial_event_id::text
), unique_bank_claims AS (
 SELECT financial_event_id FROM candidates GROUP BY financial_event_id HAVING count(*)=1
), unique_source_claims AS (
 SELECT staging_id FROM candidates GROUP BY staging_id HAVING count(*)=1
), unique_proofs AS (
 SELECT source_ref,origin,min(paid_date) paid_date,min(paid_amount) paid_amount
 FROM candidates WHERE financial_event_id IN(SELECT financial_event_id FROM unique_bank_claims)
 AND staging_id IN(SELECT staging_id FROM unique_source_claims)
 GROUP BY source_ref,origin HAVING count(*)=1
