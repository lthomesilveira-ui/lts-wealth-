-- Keep remaining documented installments as projections in every future cycle.
CREATE OR REPLACE FUNCTION public.lts_card_invoice_amounts_v230(p_user_id uuid)
 RETURNS TABLE(user_id uuid, card_name text, reference_month date, due_date date, status text, amount numeric, source text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH base(user_id,card_name,reference_month,due_date,status,amount,source) AS MATERIALIZED (
WITH src AS MATERIALIZED (
 SELECT s.user_id,s.institution_code,s.signed_amount,
 public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) family,
 s.raw_payload#>>'{creditCardMetadata,billId}' raw_bill_id,
 CASE WHEN s.raw_payload#>>'{creditCardMetadata,billForecastDate}' ~ '^[0-9]{4}-[0-9]{2}$'
 THEN (s.raw_payload#>>'{creditCardMetadata,billForecastDate}'||'-01')::date END forecast
 FROM public.lts_open_finance_staging s
 WHERE s.user_id=p_user_id AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL
 AND s.normalized_payload->>'status'='PENDING'
 AND NOT (coalesce(s.raw_payload->>'operationType','')='PAGAMENTO_FATURA'
 OR coalesce(s.raw_payload->>'category','')='Credit card payment'
 OR public.lts_v178_norm(s.description_raw) ~ '^(inclusao de pagamento ciclo corrente|pagamento recebido|pagto fatura)')
), open_cards AS MATERIALIZED (
 SELECT DISTINCT ON (family) family,reference_month,due_date FROM (
 SELECT public.lts_card_family_v226(i.card_name,CASE WHEN i.card_name ~* 'c6' THEN 'C6'
 WHEN i.card_name ~* 'aeternum|bradesco|prime' THEN 'Bradesco' ELSE 'Itaú' END) family,
 i.reference_month,i.due_date FROM public.card_invoices i
 WHERE i.user_id=p_user_id AND i.status='open' AND i.due_date>=current_date
 ) q ORDER BY family,due_date
), dated AS MATERIALIZED (
 SELECT s.family,-s.signed_amount amount,
 CASE WHEN b.id IS NOT NULL THEN date_trunc('month',b.posting_date)::date
 WHEN s.institution_code='336' AND s.forecast<=date_trunc('month',current_date)::date
 THEN coalesce(c.reference_month,s.forecast) ELSE s.forecast END reference_month
 FROM src s LEFT JOIN public.lts_open_finance_staging b ON b.user_id=s.user_id
 AND b.institution_code=s.institution_code AND b.resource_type='invoice'
 AND b.normalized_payload->>'provider_id'=s.raw_bill_id
 LEFT JOIN open_cards c ON c.family=s.family
), composition AS MATERIALIZED (
 SELECT family,reference_month,round(sum(amount),2) amount
 FROM dated WHERE reference_month>=date_trunc('month',current_date)::date
 GROUP BY family,reference_month
)
SELECT i.user_id,i.card_name,i.reference_month,i.due_date,i.status,
CASE WHEN c.family IS NOT NULL AND i.status='open' AND i.due_date>=current_date THEN c.amount ELSE i.amount END,
CASE WHEN c.family IS NOT NULL AND i.status='open' AND i.due_date>=current_date THEN 'open_finance_composition_v226' ELSE i.source END
FROM public.card_invoices i LEFT JOIN composition c ON c.reference_month=i.reference_month
AND c.family=public.lts_card_family_v226(i.card_name,CASE WHEN i.card_name ~* 'c6' THEN 'C6'
WHEN i.card_name ~* 'aeternum|bradesco|prime' THEN 'Bradesco' ELSE 'Itaú' END)
WHERE i.user_id=p_user_id
), documented_families AS MATERIALIZED (
 SELECT DISTINCT family FROM public.lts_card_document_supplement_v234 WHERE user_id=p_user_id
), reconciled AS MATERIALIZED (
 SELECT c->>'family' family,c->>'name' card_name,c->>'last_due' last_due,
 (x->>'month')::date reference_month,(x->>'due_date')::date due_date,(x->>'amount')::numeric amount,x->>'basis' basis
 FROM jsonb_array_elements(public.lts_card_cycles_v226(p_user_id)->'cards') c
 CROSS JOIN LATERAL jsonb_array_elements(c->'cycles') x
 WHERE c->>'family' IN(SELECT family FROM documented_families)
), dated AS MATERIALIZED (
 SELECT r.*,coalesce(r.due_date,make_date(extract(year FROM r.reference_month)::int,extract(month FROM r.reference_month)::int,
  least(extract(day FROM r.last_due::date)::int,extract(day FROM (r.reference_month+interval '1 month -1 day'))::int))) projected_due FROM reconciled r
)
SELECT b.user_id,b.card_name,b.reference_month,b.due_date,b.status,
 CASE WHEN r.family IS NOT NULL AND b.status IN ('open','projected') AND b.due_date>=current_date THEN r.amount ELSE b.amount END,
 CASE WHEN r.family IS NOT NULL AND b.status IN ('open','projected') AND b.due_date>=current_date THEN
  CASE WHEN r.basis='bank_document_composition' THEN 'bank_document_composition_v234'
   WHEN r.basis IN ('derived_current_installments','documented_floor_partial_detail') THEN 'derived_installments_v234' ELSE 'open_finance_composition_v226' END
 ELSE b.source END
FROM base b LEFT JOIN dated r ON r.reference_month=b.reference_month
 AND r.family=public.lts_card_family_v226(b.card_name,CASE WHEN b.card_name ~* 'c6' THEN 'C6' WHEN b.card_name ~* 'aeternum|bradesco|prime' THEN 'Bradesco' ELSE 'Itaú' END)
UNION ALL
SELECT p_user_id,r.card_name,r.reference_month,r.projected_due,CASE WHEN r.reference_month>date_trunc('month',current_date)::date THEN 'projected' ELSE 'open' END,r.amount,'derived_installments_v234'
FROM dated r WHERE r.reference_month>=date_trunc('month',current_date)::date AND r.projected_due IS NOT NULL
AND NOT EXISTS(SELECT 1 FROM base b WHERE b.reference_month=r.reference_month
 AND public.lts_card_family_v226(b.card_name,b.card_name)=r.family)

$function$;

