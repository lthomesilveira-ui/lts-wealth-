-- Preserve classifications demonstrated by the original workbook. Evidence is
-- private, loaded separately; no owner IDs or financial records in this file.
CREATE TABLE public.lts_workbook_identity_evidence_v232 (
 user_id uuid NOT NULL REFERENCES auth.users(id),
 source_table text NOT NULL,
 source_ref text NOT NULL,
 event_date date NOT NULL,
 amount numeric NOT NULL,
 original_category text NOT NULL,
 original_description text NOT NULL,
 source_sha256 text NOT NULL CHECK(length(source_sha256)=64),
 source_sheet text NOT NULL,
 source_rows jsonb NOT NULL CHECK(jsonb_typeof(source_rows)='array'),
 evidence jsonb NOT NULL DEFAULT '{}',
 verified_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,source_table,source_ref)
);
ALTER TABLE public.lts_workbook_identity_evidence_v232 ENABLE ROW LEVEL SECURITY;
CREATE POLICY owner_read ON public.lts_workbook_identity_evidence_v232 FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
REVOKE ALL ON public.lts_workbook_identity_evidence_v232 FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.lts_workbook_identity_evidence_v232 TO authenticated;
GRANT ALL ON public.lts_workbook_identity_evidence_v232 TO service_role;

ALTER FUNCTION public.lts_v229_expense_rows(uuid,date,date) RENAME TO lts_expense_rows_v230_baseline;
CREATE FUNCTION public.lts_v229_expense_rows(p_user_id uuid,p_from date,p_to date)
RETURNS TABLE(row_key text,event_date date,transaction_date date,competence_month date,amount numeric,
category text,beneficiary text,description text,account_source text,source_table text,source_ref text,
coverage_mode text,raw_category text,raw_reference text,purchase_date date,identity_status text,
management_group text,management_subgroup text,property_code text,property_component text)
LANGUAGE sql SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
WITH r AS MATERIALIZED(SELECT * FROM public.lts_expense_rows_v230_baseline(p_user_id,p_from,p_to)),
e AS MATERIALIZED(SELECT * FROM public.lts_workbook_identity_evidence_v232 WHERE user_id=p_user_id)
SELECT r.row_key,r.event_date,r.transaction_date,r.competence_month,r.amount,
r.category,
CASE WHEN r.management_group IN ('Larissa','Larissa — despesas') THEN 'Larissa' ELSE r.beneficiary END,
CASE WHEN e.source_ref IS NOT NULL AND r.description IN ('Não identificado','Descrição pendente')
 THEN e.original_description ELSE r.description END,
r.account_source,r.source_table,r.source_ref,r.coverage_mode,r.raw_category,r.raw_reference,r.purchase_date,
CASE WHEN e.source_ref IS NOT NULL AND r.management_group IN ('Moradia — imóvel a confirmar','Outras saídas familiares — a revisar')
 AND r.property_component IS DISTINCT FROM 'A revisar' THEN 'identified' ELSE r.identity_status END,
CASE WHEN r.coverage_mode='card_invoice_aggregate_fallback' THEN 'Faturas sem composição individual'
 WHEN r.management_group IN ('Larissa','Larissa — despesas') THEN 'Larissa'
 WHEN e.source_ref IS NOT NULL AND r.management_group IN ('Moradia — imóvel a confirmar','Outras saídas familiares — a revisar')
 THEN e.original_category ELSE r.management_group END,
r.management_subgroup,r.property_code,r.property_component
FROM r LEFT JOIN e ON e.source_table=r.source_table AND e.source_ref=r.source_ref
 AND e.event_date=r.event_date AND round(e.amount,2)=round(r.amount,2)
 AND public.lts_v178_norm(e.original_category)=public.lts_v178_norm(r.category)
$f$;
REVOKE ALL ON FUNCTION public.lts_v229_expense_rows(uuid,date,date),public.lts_expense_rows_v230_baseline(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_v229_expense_rows(uuid,date,date),public.lts_expense_rows_v230_baseline(uuid,date,date) TO service_role;

-- Same filtered rows own the headline, its total and every page of detail.
CREATE OR REPLACE FUNCTION public.lts_browser_expense_detail_v229(
 p_from date,p_to date,p_group text DEFAULT NULL,p_subgroup text DEFAULT NULL,
 p_offset integer DEFAULT 0,p_limit integer DEFAULT 500,p_query text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_to>current_date OR p_from<date '2013-10-10' OR p_offset<0 OR p_limit NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'invalid detail range'; END IF;
 WITH r AS MATERIALIZED(
  SELECT * FROM public.lts_v229_expense_rows(u,p_from,p_to) x
  WHERE (p_group IS NULL OR x.management_group=p_group
    OR (p_group='Faturas conciliadas pelo total' AND x.coverage_mode='card_invoice_aggregate_fallback')
    OR (p_group='Identificações pendentes' AND x.identity_status='pending')
    OR (p_group='__card_total__' AND (x.source_table LIKE '%card%' OR x.coverage_mode LIKE 'card_%'))
    OR (p_group='__account_total__' AND NOT(x.source_table LIKE '%card%' OR x.coverage_mode LIKE 'card_%')))
   AND (p_subgroup IS NULL OR x.management_subgroup=p_subgroup)
 ), filtered AS MATERIALIZED(
  SELECT * FROM r WHERE nullif(trim(p_query),'') IS NULL OR strpos(public.lts_v178_norm(concat_ws(' ',description,account_source,beneficiary,raw_reference,category)),public.lts_v178_norm(trim(p_query)))>0
 ), page AS MATERIALIZED(SELECT * FROM filtered ORDER BY event_date DESC,amount DESC,row_key OFFSET p_offset LIMIT p_limit)
 SELECT jsonb_build_object('version','expense-detail-v178','from',p_from,'to',p_to,'group',p_group,'subgroup',p_subgroup,
  'total',(SELECT round(coalesce(sum(amount),0),2) FROM r),'row_count',(SELECT count(*) FROM r),
  'matched_count',(SELECT count(*) FROM filtered),'matched_total',(SELECT round(coalesce(sum(amount),0),2) FROM filtered),'offset',p_offset,
  'next_offset',CASE WHEN p_offset+p_limit<(SELECT count(*) FROM filtered) THEN p_offset+p_limit END,
  'revision',(SELECT md5(coalesce(string_agg(row_key||':'||amount::text||':'||description||':'||category||':'||management_group||':'||coalesce(beneficiary,''),'|' ORDER BY row_key),'')) FROM r),
  'rows',coalesce((SELECT jsonb_agg(jsonb_build_object(
   'key',p.row_key,'date',CASE WHEN p.source_table LIKE '%card%' OR p.coverage_mode LIKE 'card_%' THEN p.purchase_date ELSE p.event_date END,
   'event_date',p.event_date,'transaction_date',p.transaction_date,'period',p.competence_month,
   'date_kind',CASE WHEN (p.source_table LIKE '%card%' OR p.coverage_mode LIKE 'card_%') AND p.purchase_date IS NULL THEN 'month' ELSE 'day' END,
   'description',p.description,'account_source',p.account_source,'beneficiary',p.beneficiary,'reference',p.raw_reference,
   'amount',p.amount,'category',p.management_group,'current_category',p.category,'component',p.property_component,
   'subgroup',p.management_subgroup,'status',p.identity_status,'property_code',p.property_code,'source_table',p.source_table,'source_ref',p.source_ref,
   'coverage_mode',p.coverage_mode,'can_classify',p.coverage_mode<>'card_invoice_aggregate_fallback',
   'invoice_family',CASE WHEN p.source_table LIKE '%card%' OR p.coverage_mode LIKE 'card_%' THEN public.lts_card_family_v226(p.account_source,p.account_source) END,
   'invoice_month',CASE WHEN p.source_table LIKE '%card%' OR p.coverage_mode LIKE 'card_%' THEN p.competence_month END,
   'document_status',CASE WHEN p.coverage_mode='card_invoice_aggregate_fallback' THEN 'composition_missing' END,
   'source_identity',CASE WHEN e.source_ref IS NOT NULL THEN jsonb_build_object('category',e.original_category,'description',e.original_description,'sheet',e.source_sheet,'rows',e.source_rows,'note','Classificação original preservada. A planilha não especifica pessoa ou imóvel adicional.') END,
   'review_question',CASE WHEN p.identity_status='pending' THEN 'Confirme a classificação deste lançamento.' END
  ) ORDER BY p.event_date DESC,p.amount DESC,p.row_key) FROM page p LEFT JOIN public.lts_workbook_identity_evidence_v232 e ON e.user_id=u AND e.source_table=p.source_table AND e.source_ref=p.source_ref),'[]'::jsonb),
  'components',coalesce((SELECT jsonb_agg(x ORDER BY total DESC,name) FROM (SELECT management_subgroup name,round(sum(amount),2) total,count(*) rows FROM r GROUP BY 1)x),'[]'::jsonb)
 ) INTO result;
 RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.lts_browser_expense_detail_v229(date,date,text,text,integer,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_expense_detail_v229(date,date,text,text,integer,integer,text) TO authenticated,service_role;

-- Explicit, audited correction from the detail of an existing expense. An
-- invoice total is documentary coverage, never a classifiable purchase.
CREATE FUNCTION public.lts_browser_expense_classification_v232(
 p_from date,p_to date,p_row_key text,p_category text DEFAULT NULL,
 p_beneficiary text DEFAULT NULL,p_property_code text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); r record; before_value jsonb;
 cat text:=nullif(trim(p_category),''); person text:=nullif(trim(p_beneficiary),''); prop text:=nullif(trim(p_property_code),'');
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<date '2013-10-10' OR p_to>current_date THEN RAISE EXCEPTION 'invalid range'; END IF;
 IF cat IS NULL AND person IS NULL AND prop IS NULL THEN RAISE EXCEPTION 'classification required'; END IF;
 IF person IS NOT NULL AND person NOT IN ('Lucas','Larissa','Benjamin','Rafiki') THEN RAISE EXCEPTION 'invalid beneficiary'; END IF;
 IF prop IS NOT NULL AND prop NOT IN ('cipo396','other_property','not_property') THEN RAISE EXCEPTION 'invalid property'; END IF;
 SELECT * INTO r FROM public.lts_v229_expense_rows(u,p_from,p_to) WHERE row_key=p_row_key;
 IF NOT FOUND THEN RAISE EXCEPTION 'expense not found in selected period'; END IF;
 IF r.coverage_mode='card_invoice_aggregate_fallback' THEN RAISE EXCEPTION 'Identifique as compras da fatura, não o pagamento total.'; END IF;
 IF cat IS NOT NULL AND (length(cat)>120 OR public.lts_v178_norm(cat) IN ('a classificar','sem categoria','nao identificado')) THEN RAISE EXCEPTION 'invalid category'; END IF;
 IF cat IS NOT NULL AND cat<>r.category AND NOT EXISTS(
  SELECT 1 FROM public.lts_product_read_cache c CROSS JOIN LATERAL jsonb_array_elements_text(coalesce(c.payload#>'{card_classification_review,category_options}','[]')) a(value)
  WHERE c.user_id=u AND a.value=cat
 ) AND NOT EXISTS(SELECT 1 FROM public.lts_v229_expense_rows(u,p_from,p_to) x WHERE cat IN (x.category,x.management_subgroup)) THEN RAISE EXCEPTION 'unknown category'; END IF;
 SELECT to_jsonb(d) INTO before_value FROM public.lts_v178_review_decision d WHERE d.user_id=u AND d.source_table=r.source_table AND d.source_ref=r.source_ref;
 INSERT INTO public.lts_v178_review_decision(user_id,source_table,source_ref,beneficiary,property_code,category_label,decision_basis,decided_at)
 VALUES(u,r.source_table,r.source_ref,person,prop,cat,'authenticated_detail_v232',now())
 ON CONFLICT(user_id,source_table,source_ref) DO UPDATE SET
  beneficiary=coalesce(excluded.beneficiary,lts_v178_review_decision.beneficiary),
  property_code=coalesce(excluded.property_code,lts_v178_review_decision.property_code),
  category_label=coalesce(excluded.category_label,lts_v178_review_decision.category_label),decision_basis=excluded.decision_basis,decided_at=excluded.decided_at;
 IF NOT EXISTS(SELECT 1 FROM public.lts_v229_expense_rows(u,r.event_date,r.event_date) x
   WHERE x.source_table=r.source_table AND x.source_ref=r.source_ref
    AND (cat IS NULL OR x.category=cat) AND (person IS NULL OR x.beneficiary=person)
    AND (prop IS NULL OR x.property_code=prop)) THEN RAISE EXCEPTION 'classification did not propagate'; END IF;
 INSERT INTO public.lts_access_audit(user_id,email,action,meta) VALUES(u,lower(coalesce(auth.jwt()->>'email','')),'expense_detail_classification_v232',
  jsonb_build_object('source_table',r.source_table,'source_ref',r.source_ref,'before',before_value,'after',jsonb_build_object('category',cat,'beneficiary',person,'property_code',prop),'original',to_jsonb(r)));
 RETURN jsonb_build_object('ok',true,'source_table',r.source_table,'source_ref',r.source_ref);
END $f$;
REVOKE ALL ON FUNCTION public.lts_browser_expense_classification_v232(date,date,text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_expense_classification_v232(date,date,text,text,text,text) TO authenticated,service_role;
