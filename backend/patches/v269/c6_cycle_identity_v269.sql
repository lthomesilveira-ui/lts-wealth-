-- Candidate, not applied. Resolve only the documented C6 one-month forecast/due offset.
-- A projected snapshot contributes cycle identity, never official invoice amount/status.
CREATE OR REPLACE FUNCTION public.lts_c6_cycle_identity_v269(p_user_id uuid)
RETURNS TABLE(source_id uuid,reference_month date,due_date date,cycle_basis text)
LANGUAGE sql STABLE SET search_path='' SET "TimeZone"='America/Sao_Paulo'
AS $function$
WITH unique_account AS MATERIALIZED (
 SELECT min(provider_account_ref) provider_account_ref FROM public.lts_open_finance_staging
 WHERE user_id=p_user_id AND institution_code='336' AND resource_type='credit_card' AND provider_deleted_at IS NULL
 HAVING count(DISTINCT provider_account_ref)=1 AND count(*) FILTER(WHERE nullif(provider_account_ref,'') IS NULL)=0
), documented AS MATERIALIZED (
 SELECT ci.reference_month,ci.due_date,
  coalesce((sd.metadata->>'closing_date')::date,(ci.metadata->>'bank_statement_closing_date')::date) closing_date,
  sd.metadata->'existing_source_items' items
 FROM public.card_invoices ci JOIN public.source_documents sd
  ON sd.id::text=ci.metadata->>'bank_statement_document_id' AND sd.user_id=ci.user_id
 WHERE ci.user_id=p_user_id AND public.lts_card_family_v226(ci.card_name,sd.institution)='c6'
  AND ci.status IN ('closed','paid') AND ci.metadata->>'bank_statement_closed'='true'
  AND ci.metadata->>'bank_statement_full_composition'='true'
  AND sd.document_type='credit_card_statement' AND sd.processing_status='processed'
  AND sd.sha256=ci.metadata->>'bank_statement_sha256'
  AND sd.metadata->>'all_source_lines_matched'='true'
  AND (sd.metadata->>'statement_amount')::numeric=ci.amount
  AND (sd.metadata->>'due_date')::date=ci.due_date
), closed_rows AS MATERIALIZED (
 SELECT d.reference_month,d.due_date,d.closing_date,s.provider_account_ref,
  CASE WHEN s.raw_payload#>>'{creditCardMetadata,billForecastDate}' ~ '^[0-9]{4}-[0-9]{2}$'
   THEN (s.raw_payload#>>'{creditCardMetadata,billForecastDate}'||'-01')::date END forecast
 FROM documented d CROSS JOIN LATERAL jsonb_array_elements(d.items) e
 JOIN public.lts_open_finance_staging s ON s.user_id=p_user_id AND s.id::text=e->>'source_id'
  AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL AND s.institution_code='336'
 WHERE NOT coalesce((e->>'is_payment')::boolean,false) AND nullif(s.provider_account_ref,'') IS NOT NULL
), documentary_anchors AS MATERIALIZED (
 SELECT provider_account_ref,reference_month,min(due_date) due_date,min(closing_date) closing_date,min(forecast) forecast
 FROM closed_rows GROUP BY provider_account_ref,reference_month
 HAVING count(DISTINCT due_date)=1 AND count(DISTINCT closing_date)=1
  AND count(forecast)=count(*) AND count(DISTINCT forecast)=1
  AND min(forecast)=(reference_month-interval '1 month')::date
  AND min(forecast)=date_trunc('month',min(closing_date))::date
), provider_rows AS MATERIALIZED (
 SELECT b.provider_account_ref,date_trunc('month',b.posting_date)::date reference_month,b.posting_date due_date,
 CASE WHEN b.normalized_payload->>'closing_date' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN (b.normalized_payload->>'closing_date')::date END closing_date,
 b.id bill_source_id,b.signed_amount invoice_amount,
 CASE WHEN tx.raw_payload#>>'{creditCardMetadata,billForecastDate}' ~ '^[0-9]{4}-[0-9]{2}$'
 THEN (tx.raw_payload#>>'{creditCardMetadata,billForecastDate}'||'-01')::date END forecast,-tx.signed_amount amount
 FROM public.lts_open_finance_staging b JOIN public.lts_open_finance_staging tx
 ON tx.user_id=b.user_id AND tx.institution_code=b.institution_code AND tx.provider_account_ref=b.provider_account_ref
 AND tx.resource_type='card_transaction' AND tx.provider_deleted_at IS NULL AND tx.normalized_payload->>'status'='POSTED'
 AND tx.raw_payload#>>'{creditCardMetadata,billId}'=b.normalized_payload->>'provider_id'
 WHERE b.user_id=p_user_id AND b.institution_code='336' AND b.resource_type='invoice' AND b.provider_deleted_at IS NULL
 AND b.currency='BRL' AND tx.currency='BRL' AND b.signed_amount>=0
 AND coalesce(jsonb_array_length(b.normalized_payload->'warnings'),0)=0
 AND NOT(coalesce(tx.raw_payload->>'operationType','')='PAGAMENTO_FATURA'
 OR coalesce(tx.raw_payload->>'category','')='Credit card payment'
 OR public.lts_v178_norm(tx.description_raw) ~ '^(inclusao de pagamento ciclo corrente|pagamento recebido|pagto fatura)')
), provider_anchors AS MATERIALIZED (
 SELECT provider_account_ref,reference_month,min(due_date) due_date,min(closing_date) closing_date,
 CASE WHEN count(forecast)=count(*) AND count(DISTINCT forecast)=1 THEN min(forecast) END forecast
 FROM provider_rows GROUP BY provider_account_ref,reference_month,bill_source_id,invoice_amount
 HAVING count(DISTINCT due_date)=1 AND count(closing_date)=count(*) AND count(DISTINCT closing_date)=1
 AND min(closing_date)<=current_date AND min(closing_date)<min(due_date)
 AND round(sum(amount),2)=invoice_amount
), anchor_groups AS MATERIALIZED (
 -- Keep conflicting observations: they prevent older calibration from silently
 -- winning for later cycles. A later observation cannot erase an earlier cycle.
 -- If same-month closing dates differ, require posting after BOTH boundaries.
 -- This conservative cutoff does not rewrite either source closing date.
 SELECT provider_account_ref,reference_month,min(due_date) due_date,
  max(closing_date) closing_date,min(forecast) forecast,
  (count(DISTINCT due_date)=1 AND count(due_date)=count(*)
   AND count(closing_date)=count(*) AND max(closing_date)-min(closing_date)<=1
   AND count(DISTINCT forecast)=1 AND count(forecast)=count(*)
   AND bool_and(forecast=(reference_month-interval '1 month')::date
    AND forecast=date_trunc('month',closing_date)::date)) AS calibration_valid
 FROM (SELECT * FROM documentary_anchors UNION ALL SELECT * FROM provider_anchors) observations
 GROUP BY provider_account_ref,reference_month
), candidates AS MATERIALIZED (
 SELECT a.provider_account_ref,a.closing_date,a.forecast,ci.reference_month,
  min(ci.due_date) due_date
 FROM anchor_groups a JOIN unique_account ua ON ua.provider_account_ref=a.provider_account_ref
 JOIN public.card_invoices ci ON ci.user_id=p_user_id
  AND public.lts_card_family_v226(ci.card_name,ci.card_name)='c6'
  AND ci.reference_month>a.reference_month
  AND ci.due_date>=ci.reference_month AND ci.due_date<(ci.reference_month+interval '1 month')::date
 WHERE a.calibration_valid
  AND NOT EXISTS(SELECT 1 FROM anchor_groups newer
   WHERE newer.provider_account_ref=a.provider_account_ref
    AND newer.reference_month>a.reference_month
    AND newer.reference_month<ci.reference_month)
 GROUP BY a.provider_account_ref,a.closing_date,a.forecast,ci.reference_month
 HAVING count(DISTINCT ci.due_date)=1
), resolved AS (
 SELECT s.id source_id,c.reference_month,c.due_date
 FROM public.lts_open_finance_staging s JOIN candidates c ON c.provider_account_ref=s.provider_account_ref
 WHERE s.user_id=p_user_id AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL
  AND s.institution_code='336' AND s.normalized_payload->>'status' IN('PENDING','POSTED')
  AND NOT EXISTS(SELECT 1 FROM public.lts_open_finance_staging b WHERE b.user_id=s.user_id
   AND b.institution_code=s.institution_code AND b.resource_type='invoice' AND b.provider_deleted_at IS NULL
   AND b.normalized_payload->>'provider_id'=s.raw_payload#>>'{creditCardMetadata,billId}')
  AND s.raw_payload#>>'{creditCardMetadata,billForecastDate}'=to_char(c.reference_month-interval '1 month','YYYY-MM')
  AND coalesce(CASE WHEN s.raw_payload#>>'{creditCardMetadata,billPostDate}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN (s.raw_payload#>>'{creditCardMetadata,billPostDate}')::date END,s.posting_date)>c.closing_date
  AND coalesce(CASE WHEN s.raw_payload#>>'{creditCardMetadata,billPostDate}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN (s.raw_payload#>>'{creditCardMetadata,billPostDate}')::date END,s.posting_date)<c.due_date
  AND NOT(coalesce(s.raw_payload->>'operationType','')='PAGAMENTO_FATURA'
 OR coalesce(s.raw_payload->>'category','')='Credit card payment'
 OR public.lts_v178_norm(s.description_raw) ~ '^(inclusao de pagamento ciclo corrente|pagamento recebido|pagto fatura)')
  AND NOT EXISTS(SELECT 1 FROM documented d CROSS JOIN LATERAL jsonb_array_elements(d.items) e WHERE e->>'source_id'=s.id::text)
), unique_resolved AS (
 SELECT source_id,min(reference_month) reference_month,min(due_date) due_date,
 'verified_account_forecast_offset_and_due_calendar'::text cycle_basis
 FROM resolved GROUP BY source_id HAVING count(DISTINCT reference_month)=1 AND count(DISTINCT due_date)=1
)
SELECT * FROM unique_resolved
UNION ALL
SELECT s.id source_id,NULL::date reference_month,NULL::date due_date,'unresolved'::text cycle_basis FROM public.lts_open_finance_staging s
 WHERE s.user_id=p_user_id AND s.institution_code='336' AND s.resource_type='card_transaction'
 AND s.provider_deleted_at IS NULL AND s.normalized_payload->>'status' IN('PENDING','POSTED')
 AND s.raw_payload#>>'{creditCardMetadata,billForecastDate}' ~ '^[0-9]{4}-[0-9]{2}$'
 AND EXISTS(SELECT 1 FROM public.card_invoices ci WHERE ci.user_id=p_user_id
 AND public.lts_card_family_v226(ci.card_name,ci.card_name)='c6'
 AND ci.reference_month=((s.raw_payload#>>'{creditCardMetadata,billForecastDate}'||'-01')::date+interval '1 month')::date
 AND (ci.due_date>=current_date OR ci.status IN('open','projected')))
 AND NOT EXISTS(SELECT 1 FROM unique_resolved r WHERE r.source_id=s.id)
 AND NOT EXISTS(SELECT 1 FROM public.lts_open_finance_staging b WHERE b.user_id=s.user_id AND b.institution_code=s.institution_code
 AND b.provider_account_ref=s.provider_account_ref AND b.resource_type='invoice' AND b.provider_deleted_at IS NULL
 AND b.normalized_payload->>'provider_id'=s.raw_payload#>>'{creditCardMetadata,billId}')
 AND NOT EXISTS(SELECT 1 FROM documented d CROSS JOIN LATERAL jsonb_array_elements(d.items)e WHERE e->>'source_id'=s.id::text)
 AND NOT(coalesce(s.raw_payload->>'operationType','')='PAGAMENTO_FATURA' OR coalesce(s.raw_payload->>'category','')='Credit card payment'
 OR public.lts_v178_norm(s.description_raw) ~ '^(inclusao de pagamento ciclo corrente|pagamento recebido|pagto fatura)');
$function$;
REVOKE ALL ON FUNCTION public.lts_c6_cycle_identity_v269(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_c6_cycle_identity_v269(uuid) TO service_role;
