-- Expense read model only: no bank/cash event, financial fact or source update.
CREATE OR REPLACE FUNCTION public.lts_card_observed_expense_eligible_v1(p_card jsonb,p_today date,p_first_month date)
RETURNS boolean LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path TO ''
AS $eligible$
SELECT coalesce(p_today IS NOT NULL AND p_first_month IS NOT NULL
 AND NOT coalesce((p_card->>'is_payment')::boolean,true)
 AND p_card->>'provider_status' IN ('PENDING','POSTED','DOCUMENTED')
 AND (p_card->>'amount')::numeric<>0
 AND (p_card->>'posting_date')::date<=p_today
 AND (p_card->>'purchase_date')::date<=p_today
 AND coalesce((p_card->>'reference_month')::date,date_trunc('month',(p_card->>'purchase_date')::date)::date)
 BETWEEN p_first_month AND date_trunc('month',p_today)::date,false);
$eligible$;
REVOKE ALL ON FUNCTION public.lts_card_observed_expense_eligible_v1(jsonb,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_observed_expense_eligible_v1(jsonb,date,date) TO service_role;
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
 AND NOT EXISTS(SELECT 1 FROM covered_cycles k WHERE k.family=c.family AND k.competence_month=c.reference_month)
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
$function$;
CREATE OR REPLACE FUNCTION public.lts_v229_review_rows(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(row_key text, event_date date, transaction_date date, competence_month date, amount numeric, category text, beneficiary text, description text, account_source text, source_table text, source_ref text, coverage_mode text, raw_category text, raw_reference text, purchase_date date, identity_status text, management_group text, management_subgroup text, property_code text, property_component text)
 LANGUAGE sql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH expense AS MATERIALIZED(SELECT * FROM public.lts_v229_expense_rows(p_user_id,p_from,p_to)), cards AS MATERIALIZED(
 SELECT * FROM public.lts_card_source_rows_v226(p_user_id) WHERE NOT is_payment AND amount>0 AND reference_month>=date_trunc('month',current_date)::date
 AND purchase_date BETWEEN p_from AND least(p_to,current_date) AND public.lts_v178_norm(category) IN ('a classificar','sem categoria','nao identificado')
)
SELECT * FROM expense
UNION ALL
SELECT CASE WHEN doc.id IS NOT NULL THEN 'lts_card_document_supplement_v234:' ELSE 'lts_open_finance_staging:' END||c.source_id::text,c.purchase_date,c.posting_date,coalesce(c.reference_month,date_trunc('month',c.purchase_date)::date),
 c.amount,c.category,null,c.description,c.card_name,CASE WHEN doc.id IS NOT NULL THEN 'lts_card_document_supplement_v234' ELSE 'lts_open_finance_staging' END,c.source_id::text,'card_observed_purchase',c.category,null,c.purchase_date,'pending','A classificar',c.category,null,null
FROM cards c LEFT JOIN public.lts_card_document_supplement_v234 doc ON doc.user_id=p_user_id AND doc.id=c.source_id WHERE NOT EXISTS(SELECT 1 FROM expense e WHERE e.source_table=CASE WHEN doc.id IS NOT NULL THEN 'lts_card_document_supplement_v234' ELSE 'lts_open_finance_staging' END AND e.source_ref=c.source_id::text)
$function$;
DO $tests$
DECLARE c jsonb:=jsonb_build_object('is_payment',false,'provider_status','PENDING','amount',42,'posting_date','2000-02-02','purchase_date','2000-02-02','reference_month','2000-02-01'); t date:=date '2000-02-03'; b date:=date '2000-01-01';
BEGIN
 ASSERT public.lts_card_observed_expense_eligible_v1(c,t,b),'received purchase excluded';
 ASSERT public.lts_card_observed_expense_eligible_v1(c||'{"provider_status":"POSTED"}',t,b),'posted replacement excluded';
 ASSERT public.lts_card_observed_expense_eligible_v1(c||'{"provider_status":"DOCUMENTED"}',t,b),'document source excluded';
 ASSERT public.lts_card_observed_expense_eligible_v1(c||'{"amount":-42}',t,b),'refund sign lost';
 ASSERT NOT public.lts_card_observed_expense_eligible_v1(c||'{"is_payment":true}',t,b),'payment became expense';
 ASSERT NOT public.lts_card_observed_expense_eligible_v1(c||'{"posting_date":"2000-03-02","reference_month":"2000-03-01"}',t,b),'future installment became expense';
 ASSERT NOT public.lts_card_observed_expense_eligible_v1(c||'{"purchase_date":"2000-03-02"}',t,b),'future purchase became expense';
 ASSERT NOT public.lts_card_observed_expense_eligible_v1(c||'{"provider_status":"CANCELLED"}',t,b),'cancelled purchase retained';
 ASSERT NOT public.lts_card_observed_expense_eligible_v1(c||'{"amount":0}',t,b),'zero retained';
 ASSERT NOT public.lts_card_observed_expense_eligible_v1(c||'{"posting_date":null}',t,b),'missing date became actual';
 ASSERT NOT public.lts_card_observed_expense_eligible_v1(c,t,null),'missing boundary invented';
END $tests$;
