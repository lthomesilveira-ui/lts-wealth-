-- Recovery rehearsal only. Ends in ROLLBACK; no persistent restoration by default.
BEGIN;
DO $restore_v289$
DECLARE prior_oid oid; prior_owner oid; prior_acl aclitem[]; prior_config text[]; prior_security boolean;
BEGIN
 SELECT p.oid,p.proowner,p.proacl,p.proconfig,p.prosecdef INTO prior_oid,prior_owner,prior_acl,prior_config,prior_security FROM pg_proc p WHERE p.oid='public.lts_expense_effective_rows_v176(uuid,date,date)'::regprocedure;
 IF md5(pg_get_functiondef(prior_oid))<>'21af2733b8d46a42325233fa8e37257b' THEN RAISE EXCEPTION 'V289 restoration lease changed'; END IF;
 EXECUTE $original_definition$CREATE OR REPLACE FUNCTION public.lts_expense_effective_rows_v176(p_user_id uuid, p_from date DEFAULT '2013-10-10'::date, p_to date DEFAULT CURRENT_DATE)
 RETURNS TABLE(event_date date, transaction_date date, competence_month date, amount numeric, category text, center_cost text, counterparty text, origin_type text, origin_name text, source_table text, source_ref text, coverage_mode text, is_property boolean, is_financing boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH base AS MATERIALIZED(SELECT * FROM public.lts_expense_effective_rows_pre_v268(p_user_id,p_from,p_to)),
cert AS MATERIALIZED(
 SELECT a.competence_month,a.origin_name,a.ledger_source_table,a.ledger_source_ref,max(a.ledger_total) ledger_total,
 sum(a.amount) allocation_total,count(*) allocation_rows
 FROM public.lts_card_historical_category_allocation a
 JOIN public.lts_card_historical_validation_registry r ON r.user_id=a.user_id AND r.origin_name=a.origin_name AND r.competence_month=a.competence_month
 WHERE a.user_id=p_user_id AND a.source_snapshot LIKE 'original_card_signed_categories_v268_%'
 AND a.allocation_status='certified_exact' AND a.reconciliation_delta=0
 AND r.validation_status='source_category_composition_reconciled'
 AND r.composition_status='original_signed_category_rows_reconciled'
 GROUP BY 1,2,3,4
 HAVING count(*)>0 AND abs(sum(a.amount)-max(a.ledger_total))<.005
), eligible AS MATERIALIZED(
 SELECT c.*,b.event_date,b.transaction_date,b.origin_type,b.origin_name base_origin_name
 FROM cert c JOIN base b ON b.source_table=c.ledger_source_table AND b.source_ref=c.ledger_source_ref
 AND b.competence_month=c.competence_month AND b.origin_name=c.origin_name
 AND b.coverage_mode='card_invoice_aggregate_fallback' AND abs(b.amount-c.ledger_total)<.005
 WHERE (SELECT count(*) FROM base x WHERE x.source_table=b.source_table AND x.source_ref=b.source_ref AND x.competence_month=b.competence_month)=1
), retained AS (
 SELECT b.* FROM base b WHERE NOT EXISTS(SELECT 1 FROM eligible e
 WHERE b.source_table=e.ledger_source_table AND b.source_ref=e.ledger_source_ref AND b.competence_month=e.competence_month)
), recovered AS (
 SELECT e.event_date,e.transaction_date,a.competence_month,a.amount,a.category,
 CASE WHEN a.category_raw LIKE 'Benjamin - %' THEN 'Benjamin'
 WHEN a.category_raw LIKE 'Larissa - %' THEN 'Larissa'
 WHEN lower(trim(a.category_raw))='rafiki' THEN 'Rafiki' ELSE 'Não atribuído' END::text center_cost,
 'Composição histórica da fatura'::text counterparty,'cartão'::text origin_type,e.base_origin_name origin_name,
 'lts_card_historical_category_allocation'::text source_table,a.ledger_source_ref||':'||a.id::text source_ref,
 'card_category_allocated_history'::text coverage_mode,false is_property,false is_financing
 FROM public.lts_card_historical_category_allocation a JOIN eligible e
 ON e.competence_month=a.competence_month AND e.origin_name=a.origin_name
 AND e.ledger_source_table=a.ledger_source_table AND e.ledger_source_ref=a.ledger_source_ref
 WHERE a.user_id=p_user_id AND a.source_snapshot LIKE 'original_card_signed_categories_v268_%' AND a.allocation_status='certified_exact'
)
SELECT * FROM retained UNION ALL SELECT * FROM recovered
$function$
$original_definition$;
 IF md5(pg_get_functiondef(prior_oid))<>'13b18a77b393aa74e679b6b71094f698' OR 'public.lts_expense_effective_rows_v176(uuid,date,date)'::regprocedure::oid<>prior_oid
 OR EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=prior_oid AND (p.proowner<>prior_owner OR p.proacl IS DISTINCT FROM prior_acl OR p.proconfig IS DISTINCT FROM prior_config OR p.prosecdef IS DISTINCT FROM prior_security))
 THEN RAISE EXCEPTION 'V289 original restoration mismatch'; END IF;
END $restore_v289$;
DO $restore_v289$
DECLARE prior_oid oid; prior_owner oid; prior_acl aclitem[]; prior_config text[]; prior_security boolean;
BEGIN
 SELECT p.oid,p.proowner,p.proacl,p.proconfig,p.prosecdef INTO prior_oid,prior_owner,prior_acl,prior_config,prior_security FROM pg_proc p WHERE p.oid='public.lts_expense_effective_rows_pre_v268(uuid,date,date)'::regprocedure;
 IF md5(pg_get_functiondef(prior_oid))<>'c8c716093de7f247be51f6ed6f34bd8f' THEN RAISE EXCEPTION 'V289 restoration lease changed'; END IF;
 EXECUTE $original_definition$CREATE OR REPLACE FUNCTION public.lts_expense_effective_rows_pre_v268(p_user_id uuid, p_from date DEFAULT '2013-10-10'::date, p_to date DEFAULT CURRENT_DATE)
 RETURNS TABLE(event_date date, transaction_date date, competence_month date, amount numeric, category text, center_cost text, counterparty text, origin_type text, origin_name text, source_table text, source_ref text, coverage_mode text, is_property boolean, is_financing boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
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
 THEN public.lts_card_family_v226(b.origin_name,b.origin_name) END family FROM restored b
), replaced AS MATERIALIZED(
 SELECT c.* FROM complete c LEFT JOIN scoped b ON b.competence_month=c.reference_month AND b.family=c.family
 WHERE NOT EXISTS(SELECT 1 FROM scoped workbook WHERE workbook.competence_month=c.reference_month
 AND workbook.coverage_mode='card_category_allocated_workbook_v176')
 GROUP BY c.family,c.reference_month,c.amount HAVING abs(coalesce(sum(b.amount),0)-c.amount)>.005
)
SELECT b.event_date,b.transaction_date,b.competence_month,coalesce(a.source_signed_amount,b.amount),
 CASE WHEN a.source_signed_amount<0 THEN 'Ajustes de fatura conforme planilha' ELSE b.category END,b.center_cost,b.counterparty,
 b.origin_type,b.origin_name,b.source_table,b.source_ref,
 CASE WHEN a.source_signed_amount<0 THEN 'card_workbook_signed_adjustment_v235' ELSE b.coverage_mode END,b.is_property,b.is_financing
FROM scoped b LEFT JOIN public.lts_card_history_source_audit_v235 a
 ON a.user_id=p_user_id AND a.source_table=b.source_table AND a.source_ref=b.source_ref
 AND a.event_date=b.event_date AND a.competence_month=b.competence_month
 AND a.source_signed_amount<0 AND a.ledger_amount=round(b.amount,2)
 AND b.coverage_mode='card_invoice_aggregate_fallback'
WHERE NOT EXISTS(SELECT 1 FROM replaced c WHERE c.reference_month=b.competence_month AND c.family=b.family)
UNION ALL
SELECT c.reference_month,c.posting_date,c.reference_month,c.amount,c.category,'Não atribuído',c.description,
 'cartão',c.card_name,'lts_open_finance_staging',c.source_id::text,'card_bank_closed_complete',false,false
FROM bank_items c JOIN replaced r USING(family,reference_month)
$function$
$original_definition$;
 IF md5(pg_get_functiondef(prior_oid))<>'de945f60b8211ab7f0c723938098e897' OR 'public.lts_expense_effective_rows_pre_v268(uuid,date,date)'::regprocedure::oid<>prior_oid
 OR EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=prior_oid AND (p.proowner<>prior_owner OR p.proacl IS DISTINCT FROM prior_acl OR p.proconfig IS DISTINCT FROM prior_config OR p.prosecdef IS DISTINCT FROM prior_security))
 THEN RAISE EXCEPTION 'V289 original restoration mismatch'; END IF;
END $restore_v289$;
ROLLBACK;
