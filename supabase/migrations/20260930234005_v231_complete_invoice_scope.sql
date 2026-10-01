CREATE OR REPLACE FUNCTION public.lts_expense_effective_rows_v176(p_user_id uuid,p_from date DEFAULT '2013-10-10',p_to date DEFAULT CURRENT_DATE)
RETURNS TABLE(event_date date,transaction_date date,competence_month date,amount numeric,category text,center_cost text,counterparty text,origin_type text,origin_name text,source_table text,source_ref text,coverage_mode text,is_property boolean,is_financing boolean)
LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $$
WITH base AS MATERIALIZED(SELECT * FROM public.lts_expense_effective_rows_v225_baseline(p_user_id,p_from,p_to)),
recovery AS MATERIALIZED(
 SELECT r.* FROM public.lts_card_exact_recovery_v226(p_user_id,p_from,p_to) r JOIN base b
 ON b.source_table=r.replaced_source_table AND b.source_ref=r.replaced_source_ref AND b.coverage_mode='card_invoice_aggregate_fallback'
), restored AS MATERIALIZED(
 SELECT b.* FROM base b WHERE NOT EXISTS(SELECT 1 FROM recovery r WHERE b.source_table=r.replaced_source_table AND b.source_ref=r.replaced_source_ref)
 UNION ALL SELECT event_date,transaction_date,competence_month,amount,category,center_cost,counterparty,origin_type,origin_name,source_table,source_ref,coverage_mode,is_property,is_financing FROM recovery
), bank_items AS MATERIALIZED(
 SELECT * FROM public.lts_card_source_rows_v226(p_user_id) WHERE NOT is_payment AND provider_status='POSTED'
 AND reference_month BETWEEN p_from AND p_to
), official AS MATERIALIZED(
 SELECT public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) family,
 date_trunc('month',s.posting_date)::date reference_month,
 CASE WHEN count(distinct (s.normalized_payload->>'amount')::numeric)=1 THEN max((s.normalized_payload->>'amount')::numeric) END amount
 FROM public.lts_open_finance_staging s WHERE s.user_id=p_user_id AND s.resource_type='invoice'
 AND s.provider_deleted_at IS NULL AND date_trunc('month',s.posting_date)::date BETWEEN p_from AND p_to
 GROUP BY 1,2
), complete AS MATERIALIZED(
 SELECT c.family,c.reference_month,sum(c.amount) amount
 FROM bank_items c JOIN official o USING(family,reference_month)
 GROUP BY c.family,c.reference_month,o.amount HAVING abs(sum(c.amount)-o.amount)<.005
), scoped AS MATERIALIZED(
 SELECT b.*,CASE WHEN b.origin_type='cartão' AND b.competence_month IN(SELECT reference_month FROM complete)
 THEN public.lts_card_family_v226(b.origin_name,null) END family FROM restored b
), replaced AS MATERIALIZED(
 SELECT c.* FROM complete c LEFT JOIN scoped b ON b.competence_month=c.reference_month AND b.family=c.family
 WHERE NOT EXISTS(SELECT 1 FROM scoped workbook WHERE workbook.competence_month=c.reference_month
 AND workbook.coverage_mode='card_category_allocated_workbook_v176')
 GROUP BY c.family,c.reference_month,c.amount HAVING abs(coalesce(sum(b.amount),0)-c.amount)>.005
)
SELECT b.event_date,b.transaction_date,b.competence_month,b.amount,b.category,b.center_cost,b.counterparty,
 b.origin_type,b.origin_name,b.source_table,b.source_ref,b.coverage_mode,b.is_property,b.is_financing
FROM scoped b WHERE NOT EXISTS(SELECT 1 FROM replaced c WHERE c.reference_month=b.competence_month AND c.family=b.family)
UNION ALL
SELECT c.reference_month,c.posting_date,c.reference_month,c.amount,c.category,'Não atribuído',c.description,
 'cartão',c.card_name,'lts_open_finance_staging',c.source_id::text,'card_bank_closed_complete',false,false
FROM bank_items c JOIN replaced r USING(family,reference_month)
$$;

NOTIFY pgrst,'reload schema';
