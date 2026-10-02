-- Keep already person-prefixed catalogue labels exactly once in management display.
-- This changes only a repeated display prefix, not source data, beneficiary, category or money.
CREATE OR REPLACE FUNCTION public.lts_v229_expense_rows(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(row_key text, event_date date, transaction_date date, competence_month date, amount numeric, category text, beneficiary text, description text, account_source text, source_table text, source_ref text, coverage_mode text, raw_category text, raw_reference text, purchase_date date, identity_status text, management_group text, management_subgroup text, property_code text, property_component text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
WITH base_rows AS MATERIALIZED (
WITH existing AS MATERIALIZED(SELECT * FROM public.lts_v229_expense_rows_pre_v238(p_user_id,p_from,p_to))
SELECT * FROM existing
UNION ALL
SELECT 'financial_events:'||v.financial_event_id::text||':'||v.event_date::text||':'||v.category,
 v.event_date,v.event_date,date_trunc('month',v.event_date)::date,abs(v.signed_amount),v.category,v.beneficiary,
 v.description,v.bank,'financial_events',v.financial_event_id::text,'bank_posted_documentary_reconciled',
 f.category,f.description_raw,null::date,'identified',v.management_group,v.management_subgroup,v.property_code,v.property_component
FROM public.lts_realized_bank_sources_v238(p_user_id) v JOIN public.financial_events f ON f.id=v.financial_event_id
WHERE v.event_date BETWEEN p_from AND p_to AND v.signed_amount<0
AND NOT EXISTS(SELECT 1 FROM existing e WHERE
 (e.source_table='financial_events' AND e.source_ref IN(v.financial_event_id::text,v.legacy_id))
 OR (e.source_table='lts_open_finance_staging' AND e.source_ref=v.staging_id::text))
)
SELECT row_key,
 event_date,
 transaction_date,
 competence_month,
 amount,
 case when public.lts_v178_norm(category) in ('organon','organon despesas','despesas organon') then public.lts_canonical_category_v1(p_user_id,category) else category end category,
 beneficiary,
 description,
 account_source,
 source_table,
 source_ref,
 coverage_mode,
 raw_category,
 raw_reference,
 purchase_date,
 identity_status,
 case when management_group=beneficiary||' — '||category and category like beneficiary||' - %' then category
 when public.lts_v178_norm(management_group) in ('organon','organon despesas','despesas organon') then public.lts_canonical_category_v1(p_user_id,management_group) else management_group end management_group,
 case when public.lts_v178_norm(management_subgroup) in ('organon','organon despesas','despesas organon') then public.lts_canonical_category_v1(p_user_id,management_subgroup) else management_subgroup end management_subgroup,
 property_code,
 property_component
FROM base_rows
$function$
