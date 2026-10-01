-- Read invoice amounts without building category reports or purchase-detail JSON.
CREATE OR REPLACE FUNCTION public.lts_card_invoice_amounts_v230(p_user_id uuid)
RETURNS TABLE(user_id uuid,card_name text,reference_month date,due_date date,status text,amount numeric,source text)
LANGUAGE sql STABLE SET search_path='' SET TimeZone='America/Sao_Paulo' AS $f$
WITH documented_families AS MATERIALIZED (
 SELECT DISTINCT family FROM public.lts_card_document_supplement_v234 WHERE user_id=p_user_id
), src AS MATERIALIZED (
 SELECT s.user_id,s.institution_code,s.signed_amount,
 public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) family,
 s.raw_payload#>>'{creditCardMetadata,billId}' raw_bill_id,
 CASE WHEN s.raw_payload#>>'{creditCardMetadata,billForecastDate}' ~ '^[0-9]{4}-[0-9]{2}$'
 THEN (s.raw_payload#>>'{creditCardMetadata,billForecastDate}'||'-01')::date END forecast,
 CASE WHEN s.raw_payload#>>'{creditCardMetadata,installmentNumber}' ~ '^[0-9]+$'
 THEN (s.raw_payload#>>'{creditCardMetadata,installmentNumber}')::integer END installment_number,
 CASE WHEN s.raw_payload#>>'{creditCardMetadata,totalInstallments}' ~ '^[0-9]+$'
 THEN (s.raw_payload#>>'{creditCardMetadata,totalInstallments}')::integer END total_installments
 FROM public.lts_open_finance_staging s WHERE s.user_id=p_user_id AND s.resource_type='card_transaction'
 AND s.provider_deleted_at IS NULL AND s.normalized_payload->>'status'='PENDING'
 AND NOT(coalesce(s.raw_payload->>'operationType','')='PAGAMENTO_FATURA'
 OR coalesce(s.raw_payload->>'category','')='Credit card payment'
 OR public.lts_v178_norm(s.description_raw) ~ '^(inclusao de pagamento ciclo corrente|pagamento recebido|pagto fatura)')
), open_cards AS MATERIALIZED (
 SELECT DISTINCT ON(family) family,reference_month,due_date FROM(
 SELECT public.lts_card_family_v226(i.card_name,CASE WHEN i.card_name ~* 'c6' THEN 'C6'
 WHEN i.card_name ~* 'aeternum|bradesco|prime' THEN 'Bradesco' ELSE 'Itaú' END) family,i.reference_month,i.due_date
 FROM public.card_invoices i WHERE i.user_id=p_user_id AND i.status='open' AND i.due_date>=current_date
 )q ORDER BY family,due_date
), dated AS MATERIALIZED (
 SELECT s.family,-s.signed_amount amount,s.installment_number,s.total_installments,
 coalesce(b.posting_date,CASE WHEN date_trunc('month',c.due_date)::date=s.forecast THEN c.due_date END) due_date,
 CASE WHEN b.id IS NOT NULL THEN date_trunc('month',b.posting_date)::date
 WHEN s.institution_code='336' AND s.forecast<=date_trunc('month',current_date)::date
 THEN coalesce(c.reference_month,s.forecast) ELSE s.forecast END reference_month
 FROM src s LEFT JOIN public.lts_open_finance_staging b ON b.user_id=s.user_id AND b.institution_code=s.institution_code
 AND b.resource_type='invoice' AND b.normalized_payload->>'provider_id'=s.raw_bill_id
 LEFT JOIN open_cards c ON c.family=s.family
), composition AS MATERIALIZED (
 SELECT family,reference_month,round(sum(amount),2) amount FROM dated
 WHERE reference_month>=date_trunc('month',current_date)::date GROUP BY family,reference_month
), base AS MATERIALIZED (
 SELECT i.user_id,i.card_name,i.reference_month,i.due_date,i.status,
 CASE WHEN c.family IS NOT NULL AND i.status='open' AND i.due_date>=current_date THEN c.amount ELSE i.amount END amount,
 CASE WHEN c.family IS NOT NULL AND i.status='open' AND i.due_date>=current_date THEN 'open_finance_composition_v226' ELSE i.source END source
 FROM public.card_invoices i LEFT JOIN composition c ON c.reference_month=i.reference_month
 AND c.family=public.lts_card_family_v226(i.card_name,CASE WHEN i.card_name ~* 'c6' THEN 'C6'
 WHEN i.card_name ~* 'aeternum|bradesco|prime' THEN 'Bradesco' ELSE 'Itaú' END) WHERE i.user_id=p_user_id
), rows AS MATERIALIZED (
 SELECT family,reference_month,due_date,amount,installment_number,total_installments,false documented
 FROM dated WHERE family IN(SELECT family FROM documented_families)
 UNION ALL
 SELECT d.family,d.reference_month,d.due_date,d.amount,d.installment_number,d.total_installments,true
 FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=p_user_id
 AND NOT EXISTS(SELECT 1 FROM public.lts_card_document_matches_v234(p_user_id)m WHERE m.document_id=d.id)
), pending AS MATERIALIZED (
 SELECT family,reference_month,min(due_date) due_date,round(sum(amount),2) amount,bool_or(documented) documented
 FROM rows WHERE reference_month>=date_trunc('month',current_date)::date GROUP BY family,reference_month
), first_cycles AS MATERIALIZED (
 SELECT family,min(reference_month) AS month FROM pending GROUP BY family
), projected AS MATERIALIZED (
 SELECT r.family,(r.reference_month+make_interval(months=>n))::date reference_month,round(sum(r.amount),2) amount
 FROM rows r JOIN first_cycles f ON f.family=r.family AND f.month=r.reference_month
 CROSS JOIN LATERAL generate_series(1,least(120,r.total_installments-r.installment_number))n
 WHERE r.amount>0 AND r.installment_number>0 AND r.total_installments>r.installment_number
 GROUP BY r.family,(r.reference_month+make_interval(months=>n))::date
), composed AS MATERIALIZED (
 SELECT coalesce(p.family,j.family) family,coalesce(p.reference_month,j.reference_month) reference_month,
 p.due_date,coalesce(p.amount,j.amount) amount,
 CASE WHEN p.amount IS NULL THEN 'derived_current_installments'
 WHEN p.reference_month=f.month AND p.documented THEN 'bank_document_composition'
 WHEN p.reference_month=f.month THEN 'open_finance_composition' ELSE 'provider_installments' END basis
 FROM pending p FULL JOIN projected j ON j.family=p.family AND j.reference_month=p.reference_month
 LEFT JOIN first_cycles f ON f.family=coalesce(p.family,j.family)
), accounts AS MATERIALIZED (
 SELECT public.lts_card_family_v226(s.normalized_payload->>'name',s.institution_name) family,
 s.normalized_payload->>'name' card_name,nullif(s.normalized_payload->>'due_date','')::date last_due
 FROM public.lts_open_finance_staging s WHERE s.user_id=p_user_id AND s.resource_type='credit_card' AND s.provider_deleted_at IS NULL
), reconciled AS MATERIALIZED (
 SELECT c.family,c.reference_month,coalesce(c.due_date,b.due_date,
 make_date(extract(year FROM c.reference_month)::int,extract(month FROM c.reference_month)::int,
 least(extract(day FROM a.last_due)::int,extract(day FROM(c.reference_month+interval '1 month -1 day'))::int))) due_date,
 CASE WHEN c.basis='derived_current_installments' THEN greatest(c.amount,coalesce(b.amount,0)) ELSE c.amount END amount,
 CASE WHEN c.basis='derived_current_installments' AND b.amount>c.amount THEN 'documented_floor_partial_detail' ELSE c.basis END basis,
 coalesce(b.card_name,a.card_name) card_name
 FROM composed c LEFT JOIN base b ON b.reference_month=c.reference_month AND b.status<>'paid'
 AND public.lts_card_family_v226(b.card_name,b.card_name)=c.family
 JOIN accounts a ON a.family=c.family
)
SELECT b.user_id,b.card_name,b.reference_month,b.due_date,b.status,
 CASE WHEN r.family IS NOT NULL AND b.status IN('open','projected') AND b.due_date>=current_date THEN r.amount ELSE b.amount END,
 CASE WHEN r.family IS NOT NULL AND b.status IN('open','projected') AND b.due_date>=current_date THEN
 CASE WHEN r.basis='bank_document_composition' THEN 'bank_document_composition_v234'
 WHEN r.basis IN('derived_current_installments','documented_floor_partial_detail') THEN 'derived_installments_v234'
 ELSE 'open_finance_composition_v226' END ELSE b.source END
FROM base b LEFT JOIN reconciled r ON r.reference_month=b.reference_month AND public.lts_card_family_v226(b.card_name,b.card_name)=r.family
UNION ALL
SELECT p_user_id,r.card_name,r.reference_month,r.due_date,
 CASE WHEN r.reference_month>date_trunc('month',current_date)::date THEN 'projected' ELSE 'open' END,r.amount,'derived_installments_v234'
FROM reconciled r WHERE r.due_date IS NOT NULL AND NOT EXISTS(SELECT 1 FROM base b WHERE b.reference_month=r.reference_month
 AND public.lts_card_family_v226(b.card_name,b.card_name)=r.family)
$f$;
