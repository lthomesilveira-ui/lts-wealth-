CREATE OR REPLACE FUNCTION public.lts_v229_expense_rows_pre_v238(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(row_key text, event_date date, transaction_date date, competence_month date, amount numeric, category text, beneficiary text, description text, account_source text, source_table text, source_ref text, coverage_mode text, raw_category text, raw_reference text, purchase_date date, identity_status text, management_group text, management_subgroup text, property_code text, property_component text)
 LANGUAGE sql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH r AS MATERIALIZED(SELECT * FROM public.lts_expense_rows_v230_baseline(p_user_id,p_from,p_to)),
e AS MATERIALIZED(SELECT * FROM public.lts_workbook_identity_evidence_v232 WHERE user_id=p_user_id)
SELECT r.row_key,r.event_date,r.transaction_date,r.competence_month,r.amount,
r.category,
CASE WHEN r.management_group IN ('Larissa','Larissa — despesas') THEN 'Larissa' ELSE r.beneficiary END,
CASE WHEN e.source_ref IS NOT NULL AND r.description IN ('Não identificado','Descrição pendente')
 THEN e.original_description ELSE r.description END,
r.account_source,r.source_table,r.source_ref,r.coverage_mode,r.raw_category,r.raw_reference,r.purchase_date,
CASE WHEN r.coverage_mode='card_detail_workbook_exact' AND EXISTS(SELECT 1 FROM public.lts_card_workbook_evidence_v226 w JOIN public.lts_card_formula_resolution_v237 f ON f.user_id=w.user_id AND f.family=w.family AND f.reference_month=w.reference_month AND f.source_hash=w.source_hash WHERE w.user_id=p_user_id AND w.source_hash||':'||w.source_sheet||':'||w.source_row=r.source_ref AND w.category=r.category AND w.amount=r.amount) THEN 'identified'
 WHEN e.source_ref IS NOT NULL AND r.management_group IN ('Moradia — imóvel a confirmar','Outras saídas familiares — a revisar')
 AND r.property_component IS DISTINCT FROM 'A revisar' THEN 'identified' ELSE r.identity_status END,
CASE WHEN r.coverage_mode='card_invoice_aggregate_fallback' THEN 'Faturas sem composição individual'
 WHEN r.management_group IN ('Larissa','Larissa — despesas') THEN 'Larissa'
 WHEN e.source_ref IS NOT NULL AND r.management_group IN ('Moradia — imóvel a confirmar','Outras saídas familiares — a revisar')
 THEN e.original_category ELSE r.management_group END,
r.management_subgroup,r.property_code,r.property_component
FROM r LEFT JOIN e ON e.source_table=r.source_table AND e.source_ref=r.source_ref
 AND e.event_date=r.event_date AND round(e.amount,2)=round(r.amount,2)
 AND pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(e.original_category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')=pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(r.category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')
$function$
