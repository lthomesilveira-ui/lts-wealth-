-- V265: realize proved legacy property bills in Expenses, once.
-- No cash events or raw evidence are changed. Existing category/person decisions remain authoritative.
DO $lease$
BEGIN
 IF md5(pg_get_functiondef('public.lts_v229_expense_rows(uuid,date,date)'::regprocedure))<>'df7d60f86e539acba776f8b31547e3b9'
 OR (SELECT proacl::text FROM pg_proc WHERE oid='public.lts_v229_expense_rows(uuid,date,date)'::regprocedure)<>'{postgres=X/postgres,service_role=X/postgres}'
 THEN RAISE EXCEPTION 'Expense reader definition or ACL changed'; END IF;
END $lease$;

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
), source_boundary AS (
 SELECT date_trunc('month',min(created_at))::date first_month FROM public.lts_open_finance_staging
 WHERE user_id=p_user_id AND resource_type='card_transaction'
), cards AS MATERIALIZED (
 SELECT c.*,CASE WHEN d.id IS NOT NULL THEN 'lts_card_document_supplement_v234' ELSE 'lts_open_finance_staging' END st
 FROM public.lts_card_source_rows_v226(p_user_id) c CROSS JOIN source_boundary b
 LEFT JOIN public.lts_card_document_supplement_v234 d ON d.user_id=p_user_id AND d.id=c.source_id
 LEFT JOIN public.lts_open_finance_staging s ON s.user_id=p_user_id AND s.id=c.source_id
 WHERE public.lts_card_observed_expense_eligible_v1(to_jsonb(c),current_date,b.first_month)
 AND (d.id IS NOT NULL OR (s.currency='BRL' AND s.provider_deleted_at IS NULL))
 AND coalesce(c.reference_month,date_trunc('month',c.purchase_date)::date) BETWEEN p_from AND p_to
), covered_cycles AS (
 SELECT public.lts_card_family_v226(e.account_source,e.account_source) family,e.competence_month
 FROM base_rows e JOIN public.card_invoices i ON i.user_id=p_user_id
 AND public.lts_card_family_v226(i.card_name,i.card_name)=public.lts_card_family_v226(e.account_source,e.account_source)
 AND i.reference_month=e.competence_month AND i.status='closed'
 WHERE e.coverage_mode LIKE 'card_%' AND e.coverage_mode<>'card_invoice_aggregate_fallback'
 GROUP BY 1,2,i.amount HAVING abs(sum(e.amount)-i.amount)<.005
), doc_matches AS MATERIALIZED (SELECT * FROM public.lts_card_document_matches_v234(p_user_id)),
extra_cards AS MATERIALIZED (
 SELECT c.* FROM cards c
 WHERE NOT EXISTS(SELECT 1 FROM base_rows e WHERE e.source_table=c.st AND e.source_ref=c.source_id::text)
 AND NOT EXISTS(SELECT 1 FROM doc_matches m JOIN base_rows e
 ON e.source_table='lts_card_document_supplement_v234' AND e.source_ref=m.document_id::text WHERE m.provider_id=c.source_id)
 AND NOT EXISTS(SELECT 1 FROM covered_cycles k WHERE k.family=c.family AND k.competence_month=c.reference_month
 -- New purchases after the proved statement closing are outside its composition.
 AND NOT EXISTS(SELECT 1 FROM public.card_invoices inv WHERE inv.user_id=p_user_id
  AND inv.reference_month=k.competence_month AND inv.status='closed'
  AND public.lts_card_family_v226(inv.card_name,inv.card_name)=k.family
  AND inv.metadata->>'bank_statement_closing_date' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND c.provider_status IN('PENDING','POSTED')
  AND c.bill_id IS NULL
  AND c.purchase_date>(inv.metadata->>'bank_statement_closing_date')::date
  AND c.purchase_date<=current_date))
 -- Do not count raw items on top of an unresolved invoice total.
 AND NOT EXISTS(SELECT 1 FROM base_rows e WHERE e.coverage_mode='card_invoice_aggregate_fallback'
 AND e.competence_month=c.reference_month AND public.lts_card_family_v226(e.account_source,e.account_source)=c.family)
), labeled_cards AS (
 SELECT c.*,coalesce(d.category_label,regexp_replace(c.category,'^(Lucas|Larissa|Benjamin|Rafiki)[[:space:]]*[-—][[:space:]]*','','i')) cat,
 coalesce(d.beneficiary,substring(c.category from '^(Lucas|Larissa|Benjamin|Rafiki)[[:space:]]*[-—]')) person,d.property_code prop
 FROM extra_cards c LEFT JOIN public.lts_v178_review_decision d
 ON d.user_id=p_user_id AND d.source_table=c.st AND d.source_ref=c.source_id::text
), observed_expenses AS (
 SELECT c.st||':'||c.source_id::text||':'||coalesce(c.reference_month,date_trunc('month',c.purchase_date)::date)::text row_key,
 coalesce(c.reference_month,date_trunc('month',c.purchase_date)::date) event_date,c.posting_date transaction_date,
 coalesce(c.reference_month,date_trunc('month',c.purchase_date)::date) competence_month,
 c.amount,public.lts_canonical_category_v1(p_user_id,c.cat) category,c.person beneficiary,c.description,c.card_name account_source,c.st source_table,c.source_id::text source_ref,
 'card_observed_'||lower(c.provider_status) coverage_mode,c.category raw_category,
 concat_ws(' · ',case when c.last4 is not null then 'Final '||c.last4 end,
 case when c.installment_number is not null then 'Parcela '||c.installment_number::text||'/'||coalesce(c.total_installments::text,'?') end) raw_reference,
 c.purchase_date,case when public.lts_v178_norm(c.cat) in ('','a classificar','nao identificado','sem categoria') then 'pending' else 'identified' end identity_status,
 case when c.prop='cipo396' then 'Apartamento · CIPÓ 396'
 when c.person in ('Larissa','Benjamin','Rafiki') and c.cat not like c.person||' - %'
 then c.person||' — '||public.lts_canonical_category_v1(p_user_id,c.cat)
 else public.lts_expense_management_group_v3(public.lts_canonical_category_v1(p_user_id,c.cat),c.person,c.description,c.card_name,'card_observed_purchase') end management_group,
 public.lts_canonical_category_v1(p_user_id,c.cat) management_subgroup,c.prop property_code,null::text property_component
 FROM labeled_cards c
), documented_legacy_properties AS MATERIALIZED (
 -- A matched legacy forecast is already excluded from "new bank" rows.
 -- Its posted, owner-confirmed property expense still needs a realized row.
 SELECT s.id staging_id,m.source_ref legacy_ref,s.posting_date,s.signed_amount,s.description_raw,
  m.bank,d.category_label,d.beneficiary,d.property_code,e.idx legacy_index
 FROM public.lts_v229_documentary_match m
 JOIN public.lts_bank_posted_rows_v231(p_user_id) s
  ON s.user_id=m.user_id AND s.id=m.staging_id
 JOIN public.lts_v178_review_decision d ON d.user_id=s.user_id
  AND d.source_table='lts_open_finance_staging' AND d.source_ref=s.id::text
 JOIN public.evento_base e ON e.usuario_id=s.user_id
  AND m.source_ref='evento_base:'||e.idx::text
 WHERE m.user_id=p_user_id
  AND m.evidence->>'basis'='owner_confirmed_exact_obligation'
  AND m.evidence->>'raw_hash'=s.raw_hash
  AND m.evidence->>'actual_posting_date'=s.posting_date::text
  AND m.signed_amount=s.signed_amount AND s.signed_amount<0
  AND m.bank=CASE s.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END
  AND s.posting_date BETWEEN p_from AND least(p_to,current_date)
  AND d.property_code='cipo396'
  AND public.lts_v178_norm(d.category_label) IN('condominio','energia')
  AND e.dados->>'efeito'='saida'
  -- Ambiguous bindings remain reviewable rather than duplicating a forecast.
  AND NOT EXISTS(SELECT 1 FROM public.lts_v229_documentary_match other
   WHERE other.user_id=m.user_id AND other.source_ref=m.source_ref AND other.staging_id<>m.staging_id)
  AND NOT EXISTS(SELECT 1 FROM base_rows r WHERE
   (r.source_table='lts_open_finance_staging' AND r.source_ref=s.id::text)
   OR r.source_ref=m.source_ref
   OR (r.source_table='evento_base' AND r.source_ref=e.idx::text))
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
UNION ALL SELECT * FROM observed_expenses
UNION ALL
SELECT 'lts_open_finance_staging:'||p.staging_id::text||':'||p.posting_date::text||':realized_property',
 p.posting_date,p.posting_date,date_trunc('month',p.posting_date)::date,abs(p.signed_amount),
 public.lts_canonical_category_v1(p_user_id,p.category_label),p.beneficiary,p.description_raw,p.bank,
 'lts_open_finance_staging',p.staging_id::text,'bank_posted_documentary_legacy_property',
 p.category_label,p.legacy_ref,null::date,'identified','Apartamento · CIPÓ 396',
 'Custos de moradia',p.property_code,'Custos de moradia'
FROM documented_legacy_properties p
$function$
;
-- CREATE OR REPLACE preserves the existing service-only privileges.
DO $acl$
BEGIN
 IF has_function_privilege('anon','public.lts_v229_expense_rows(uuid,date,date)','execute')
 OR has_function_privilege('authenticated','public.lts_v229_expense_rows(uuid,date,date)','execute')
 THEN RAISE EXCEPTION 'Private expense reader became externally callable'; END IF;
END $acl$;
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
