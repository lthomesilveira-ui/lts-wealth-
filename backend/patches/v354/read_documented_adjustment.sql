-- A valid documentary adjustment changes eligibility, retaining every cached source row.
DO $patch$
DECLARE d text;a jsonb;t regprocedure:='public.lts_v229_expense_rows(uuid,date,date)'::regprocedure;
BEGIN
 SELECT pg_get_functiondef(oid),to_jsonb(p)-'prosrc'INTO d,a FROM pg_proc p WHERE oid=t;
 IF md5(d)<>'677206c160d69996306509c6ff84c136'THEN RAISE EXCEPTION 'V354_CANONICAL_SOURCE_CHANGED';END IF;
 EXECUTE $newdef$CREATE OR REPLACE FUNCTION public.lts_v229_expense_rows(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(row_key text, event_date date, transaction_date date, competence_month date, amount numeric, category text, beneficiary text, description text, account_source text, source_table text, source_ref text, coverage_mode text, raw_category text, raw_reference text, purchase_date date, identity_status text, management_group text, management_subgroup text, property_code text, property_component text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
WITH rows AS MATERIALIZED (
 SELECT * FROM public.lts_expense_rows_pre_categories_v290(p_user_id,p_from,p_to)
), documented_adjustments AS MATERIALIZED (
 SELECT r.source_table,r.source_ref
 FROM rows r JOIN public.lts_workbook_nonspend_source_v343 e
 ON e.user_id=p_user_id AND e.source_table=r.source_table AND e.source_ref=r.source_ref
 AND e.nature='receipt_adjustment'
 GROUP BY r.source_table,r.source_ref
 HAVING count(*)=1 AND bool_and(r.coverage_mode='direct_cash'
 AND r.event_date=e.evidence_date AND r.amount=e.amount)
), dictionary AS MATERIALIZED (
 SELECT b.raw_category,min(c.category) category
 FROM public.lts_category_binding_v290 b
 JOIN public.lts_category_catalog c USING(user_id,category_key)
 WHERE b.user_id=p_user_id
 GROUP BY b.raw_category HAVING count(DISTINCT b.category_key)=1
)
SELECT r.row_key,
 r.event_date,
 r.transaction_date,
 r.competence_month,
 r.amount,
 c.category,
 r.beneficiary,
 r.description,
 r.account_source,
 r.source_table,
 r.source_ref,
 r.coverage_mode,
 r.raw_category,
 r.raw_reference,
 r.purchase_date,
 r.identity_status,
 CASE WHEN r.management_group=r.category THEN c.category ELSE r.management_group END,
 CASE WHEN r.management_subgroup=r.category THEN c.category ELSE r.management_subgroup END,
 r.property_code,
 r.property_component
FROM rows r LEFT JOIN dictionary d ON d.raw_category=r.category
CROSS JOIN LATERAL (SELECT CASE
 WHEN r.beneficiary IS NULL AND r.category ~ '^(Lucas|Larissa|Benjamin|Rafiki)[[:space:]]*[-—–]'
 THEN r.category ELSE coalesce(d.category,r.category) END category)c
WHERE NOT EXISTS(SELECT 1 FROM documented_adjustments e
 WHERE e.source_table=r.source_table AND e.source_ref=r.source_ref)
$function$
$newdef$;
 IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid=t)THEN RAISE EXCEPTION 'V354_READER_ATTRIBUTES_CHANGED';END IF;
END $patch$;
