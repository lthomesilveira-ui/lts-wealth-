-- Propagate the shared classification registry into every canonical expense row.
-- Keep raw labels, row keys, amounts, dates and explicit beneficiary fields unchanged.
DO $guard$ BEGIN
 IF md5(pg_get_functiondef('public.lts_v229_expense_rows(uuid,date,date)'::regprocedure))<>'79f8b2f50f89299be50171dc8ad93917' THEN
 RAISE EXCEPTION 'Expense reader changed before category normalization'; END IF;
END $guard$;
CREATE OR REPLACE FUNCTION public.lts_expense_rows_pre_categories_v290(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(row_key text, event_date date, transaction_date date, competence_month date, amount numeric, category text, beneficiary text, description text, account_source text, source_table text, source_ref text, coverage_mode text, raw_category text, raw_reference text, purchase_date date, identity_status text, management_group text, management_subgroup text, property_code text, property_component text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
WITH q26_original AS MATERIALIZED (
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
 case when p_user_id='c1b23404-210f-4095-b3c7-7b8664e64f4c'::uuid AND beneficiary IN ('Lucas','Larissa','Benjamin','Rafiki') AND management_group=beneficiary||' — '||category AND category ~ ('^'||beneficiary||'[[:space:]]*—[[:space:]]+') then category
  when management_group=beneficiary||' — '||category and category like beneficiary||' - %' then category
 when public.lts_v178_norm(management_group) in ('organon','organon despesas','despesas organon') then public.lts_canonical_category_v1(p_user_id,management_group) else management_group end management_group,
 case when p_user_id='c1b23404-210f-4095-b3c7-7b8664e64f4c'::uuid AND beneficiary IN ('Lucas','Larissa','Benjamin','Rafiki') AND management_group=beneficiary||' — '||category AND category ~ ('^'||beneficiary||'[[:space:]]*—[[:space:]]+') AND management_subgroup=category then pg_catalog.regexp_replace(category,'^(Lucas|Larissa|Benjamin|Rafiki)[[:space:]]*—[[:space:]]+','','i')
  when public.lts_v178_norm(management_subgroup) in ('organon','organon despesas','despesas organon') then public.lts_canonical_category_v1(p_user_id,management_subgroup) else management_subgroup end management_subgroup,
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
), q26_pins(evidence_id,fingerprint,evidence_type) AS (VALUES ('427c2c64-fae8-4482-b8b1-f34718bfb715'::uuid,'cbcf7eb409fe9b5bf054513e79afe7e4181701c0bc4a4da43d594cb362bd8154','owner_confirmed_card_observation_pair_v1'),('2cd8a014-f082-47be-8744-956c8bd295f2'::uuid,'b5754492b75446626a75624c7a0d1b07c61020555d6ff7e79dfdeea64a1c0ff5','verified_card_observation_pair_v1'),('3e951cec-5901-4aab-a635-5e47199f071b'::uuid,'971a5fe5cafaee9ea8d90a628b25c653636102f2d4fad78ecfc436431c1b1458','verified_card_observation_pair_v1'),('694b3e46-8d4a-4ae9-af51-c02df8f2453f'::uuid,'def7e0132ef9e91258edfc4b5cc22b702f47b9de58c6967cb056753281cbc45d','verified_card_observation_pair_v1'),('862b5a99-245f-44e6-9585-b997a6e99a4d'::uuid,'d5f74624cdbaacac9c5c04911971afb092e1fe84ceacd0ccbdef3634ae33ac49','verified_card_observation_pair_v1'),('d318b9c7-d9b5-4273-8910-acb6285f62a0'::uuid,'fcfbf0353cbc7332a2b93a85557e84750df28367b7bfcf89d444c9abc78d4adc','verified_card_observation_pair_v1'),('d4f9ee3b-6619-4f7e-b0ef-6e8a2b47eaaf'::uuid,'65076d65b4c32619e593e3d18e2ad7f85c6593c72718c6ffc3ca750d07a893cd','verified_card_observation_pair_v1'),('fb10a7b9-7e98-47f8-8e70-09458b296a39'::uuid,'19a841ca493b9c1ba9b2a5da75a28778515f23e6f56fa30a768f296f30e3e481','verified_card_observation_pair_v1')), q26_scoped AS MATERIALIZED (
 SELECT e.*,e.metadata->'contract' AS c,e.metadata->'state' AS st
 FROM public.lts_reconciliation_evidence e
 WHERE e.user_id=p_user_id AND (e.evidence_type IN('owner_confirmed_card_observation_pair_v1','verified_card_observation_pair_v1') OR e.id IN(SELECT evidence_id FROM q26_pins) OR e.source_ref IN(SELECT evidence_type||':'||evidence_id::text FROM q26_pins) OR e.metadata#>>'{contract,operation_id}' IN(SELECT evidence_id::text FROM q26_pins))
), q26_shapes AS MATERIALIZED (
 SELECT x.*,coalesce(((jsonb_typeof(x.metadata)='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof(x.metadata)='object' THEN x.metadata ELSE '{}'::jsonb END) AS z(k))=3 AND x.metadata ?& ARRAY['contract','immutable_fingerprint','state']::text[])
 AND jsonb_typeof(x.metadata->'immutable_fingerprint')='string'
 AND x.metadata->>'immutable_fingerprint' ~ '^[0-9a-f]{64}$'
 AND ((jsonb_typeof(x.c)='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof(x.c)='object' THEN x.c ELSE '{}'::jsonb END) AS z(k))=24 AND x.c ?& ARRAY['amount','card_last4','competence_month','currency','evidence_id','family','identity_basis','installment_number','institution_code','invoice_anchor_id','invoice_anchor_identity','operation_id','owner_id','prior_card_identity','prior_expense_identity','prior_id','prior_identity','provider_account_ref','representative_card_identity','representative_expense_identity','representative_id','representative_identity','total_installments','version']::text[]) AND
   (jsonb_typeof((x.c->'version'))='number' AND ((x.c->'version'))::text ~ '^-?[0-9]+$') AND
   jsonb_typeof((x.c->'operation_id'))='string' AND
   jsonb_typeof((x.c->'evidence_id'))='string' AND
   jsonb_typeof((x.c->'owner_id'))='string' AND
   jsonb_typeof((x.c->'representative_id'))='string' AND
   jsonb_typeof((x.c->'prior_id'))='string' AND
   jsonb_typeof((x.c->'invoice_anchor_id'))='string' AND
   jsonb_typeof((x.c->'competence_month'))='string' AND
   jsonb_typeof((x.c->'amount'))='number' AND
   jsonb_typeof((x.c->'currency'))='string' AND
   jsonb_typeof((x.c->'family'))='string' AND
   jsonb_typeof((x.c->'institution_code'))='string' AND
   jsonb_typeof((x.c->'provider_account_ref'))='string' AND
   jsonb_typeof((x.c->'card_last4'))='string' AND
   (jsonb_typeof((x.c->'installment_number'))='number' AND ((x.c->'installment_number'))::text ~ '^-?[0-9]+$') AND
   (jsonb_typeof((x.c->'total_installments'))='number' AND ((x.c->'total_installments'))::text ~ '^-?[0-9]+$') AND
   ((jsonb_typeof((x.c->'representative_identity'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof((x.c->'representative_identity'))='object' THEN (x.c->'representative_identity') ELSE '{}'::jsonb END) AS z(k))=13 AND (x.c->'representative_identity') ?& ARRAY['currency','id','institution_code','normalized_payload','posting_date','provider','provider_account_ref','provider_deleted_at','provider_record_id','raw_payload','resource_type','signed_amount','user_id']::text[]) AND
   jsonb_typeof(((x.c->'representative_identity')->'id'))='string' AND
   jsonb_typeof(((x.c->'representative_identity')->'user_id'))='string' AND
   jsonb_typeof(((x.c->'representative_identity')->'provider'))='string' AND
   jsonb_typeof(((x.c->'representative_identity')->'currency'))='string' AND
   jsonb_typeof(((x.c->'representative_identity')->'posting_date'))='string' AND
   jsonb_typeof(((x.c->'representative_identity')->'resource_type'))='string' AND
   jsonb_typeof(((x.c->'representative_identity')->'signed_amount'))='number' AND
   jsonb_typeof(((x.c->'representative_identity')->'institution_code'))='string' AND
   jsonb_typeof(((x.c->'representative_identity')->'provider_record_id'))='string' AND
   jsonb_typeof(((x.c->'representative_identity')->'provider_deleted_at'))='null' AND
   jsonb_typeof(((x.c->'representative_identity')->'provider_account_ref'))='string' AND
   ((jsonb_typeof(((x.c->'representative_identity')->'raw_payload'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof(((x.c->'representative_identity')->'raw_payload'))='object' THEN ((x.c->'representative_identity')->'raw_payload') ELSE '{}'::jsonb END) AS z(k))=8 AND ((x.c->'representative_identity')->'raw_payload') ?& ARRAY['accountId','amount','creditCardMetadata','currencyCode','date','id','status','type']::text[]) AND
   jsonb_typeof((((x.c->'representative_identity')->'raw_payload')->'id'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'raw_payload')->'date'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'raw_payload')->'type'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'raw_payload')->'amount'))='number' AND
   jsonb_typeof((((x.c->'representative_identity')->'raw_payload')->'status'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'raw_payload')->'accountId'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'raw_payload')->'currencyCode'))='string' AND
   ((jsonb_typeof((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata'))='object' THEN (((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata') ELSE '{}'::jsonb END) AS z(k))=7 AND (((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata') ?& ARRAY['billId','billPostDate','cardNumber','installmentNumber','purchaseDate','totalInstallments','transactionDateTime']::text[]) AND
   jsonb_typeof(((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata')->'billId'))='string' AND
   jsonb_typeof(((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata')->'cardNumber'))='string' AND
   jsonb_typeof(((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata')->'billPostDate'))='string' AND
   jsonb_typeof(((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata')->'purchaseDate'))='string' AND
   (jsonb_typeof(((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata')->'installmentNumber'))='number' AND (((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata')->'installmentNumber'))::text ~ '^-?[0-9]+$') AND
   (jsonb_typeof(((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata')->'totalInstallments'))='number' AND (((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata')->'totalInstallments'))::text ~ '^-?[0-9]+$') AND
   jsonb_typeof(((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata')->'transactionDateTime'))='string')) AND
   ((jsonb_typeof(((x.c->'representative_identity')->'normalized_payload'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof(((x.c->'representative_identity')->'normalized_payload'))='object' THEN ((x.c->'representative_identity')->'normalized_payload') ELSE '{}'::jsonb END) AS z(k))=14 AND ((x.c->'representative_identity')->'normalized_payload') ?& ARRAY['account_last4','account_type','amount','bill_id','currency','date','installment_number','last4','layer','provider_account_id','provider_civil_date','provider_id','status','total_installments']::text[]) AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'date'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'last4'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'layer'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'amount'))='number' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'status'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'bill_id'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'currency'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'account_type'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'account_last4'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'provider_account_id'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'provider_id'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'provider_civil_date'))='string' AND
   (jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'installment_number'))='number' AND ((((x.c->'representative_identity')->'normalized_payload')->'installment_number'))::text ~ '^-?[0-9]+$') AND
   (jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'total_installments'))='number' AND ((((x.c->'representative_identity')->'normalized_payload')->'total_installments'))::text ~ '^-?[0-9]+$'))) AND
   ((jsonb_typeof((x.c->'prior_identity'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof((x.c->'prior_identity'))='object' THEN (x.c->'prior_identity') ELSE '{}'::jsonb END) AS z(k))=13 AND (x.c->'prior_identity') ?& ARRAY['currency','id','institution_code','normalized_payload','posting_date','provider','provider_account_ref','provider_deleted_at','provider_record_id','raw_payload','resource_type','signed_amount','user_id']::text[]) AND
   jsonb_typeof(((x.c->'prior_identity')->'id'))='string' AND
   jsonb_typeof(((x.c->'prior_identity')->'user_id'))='string' AND
   jsonb_typeof(((x.c->'prior_identity')->'provider'))='string' AND
   jsonb_typeof(((x.c->'prior_identity')->'currency'))='string' AND
   jsonb_typeof(((x.c->'prior_identity')->'posting_date'))='string' AND
   jsonb_typeof(((x.c->'prior_identity')->'resource_type'))='string' AND
   jsonb_typeof(((x.c->'prior_identity')->'signed_amount'))='number' AND
   jsonb_typeof(((x.c->'prior_identity')->'institution_code'))='string' AND
   jsonb_typeof(((x.c->'prior_identity')->'provider_record_id'))='string' AND
   jsonb_typeof(((x.c->'prior_identity')->'provider_deleted_at'))='null' AND
   jsonb_typeof(((x.c->'prior_identity')->'provider_account_ref'))='string' AND
   ((jsonb_typeof(((x.c->'prior_identity')->'raw_payload'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof(((x.c->'prior_identity')->'raw_payload'))='object' THEN ((x.c->'prior_identity')->'raw_payload') ELSE '{}'::jsonb END) AS z(k))=8 AND ((x.c->'prior_identity')->'raw_payload') ?& ARRAY['accountId','amount','creditCardMetadata','currencyCode','date','id','status','type']::text[]) AND
   jsonb_typeof((((x.c->'prior_identity')->'raw_payload')->'id'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'raw_payload')->'date'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'raw_payload')->'type'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'raw_payload')->'amount'))='number' AND
   jsonb_typeof((((x.c->'prior_identity')->'raw_payload')->'status'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'raw_payload')->'accountId'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'raw_payload')->'currencyCode'))='string' AND
   ((jsonb_typeof((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata'))='object' THEN (((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata') ELSE '{}'::jsonb END) AS z(k))=7 AND (((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata') ?& ARRAY['billId','billPostDate','cardNumber','installmentNumber','purchaseDate','totalInstallments','transactionDateTime']::text[]) AND
   jsonb_typeof(((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata')->'billId'))='null' AND
   jsonb_typeof(((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata')->'cardNumber'))='string' AND
   jsonb_typeof(((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata')->'billPostDate'))='null' AND
   jsonb_typeof(((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata')->'purchaseDate'))='string' AND
   (jsonb_typeof(((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata')->'installmentNumber'))='number' AND (((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata')->'installmentNumber'))::text ~ '^-?[0-9]+$') AND
   (jsonb_typeof(((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata')->'totalInstallments'))='number' AND (((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata')->'totalInstallments'))::text ~ '^-?[0-9]+$') AND
   jsonb_typeof(((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata')->'transactionDateTime'))='null')) AND
   ((jsonb_typeof(((x.c->'prior_identity')->'normalized_payload'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof(((x.c->'prior_identity')->'normalized_payload'))='object' THEN ((x.c->'prior_identity')->'normalized_payload') ELSE '{}'::jsonb END) AS z(k))=14 AND ((x.c->'prior_identity')->'normalized_payload') ?& ARRAY['account_last4','account_type','amount','bill_id','currency','date','installment_number','last4','layer','provider_account_id','provider_civil_date','provider_id','status','total_installments']::text[]) AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'date'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'last4'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'layer'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'amount'))='number' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'status'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'bill_id'))='null' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'currency'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'account_type'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'account_last4'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'provider_account_id'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'provider_id'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'provider_civil_date'))='string' AND
   (jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'installment_number'))='number' AND ((((x.c->'prior_identity')->'normalized_payload')->'installment_number'))::text ~ '^-?[0-9]+$') AND
   (jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'total_installments'))='number' AND ((((x.c->'prior_identity')->'normalized_payload')->'total_installments'))::text ~ '^-?[0-9]+$'))) AND
   ((jsonb_typeof((x.c->'invoice_anchor_identity'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof((x.c->'invoice_anchor_identity'))='object' THEN (x.c->'invoice_anchor_identity') ELSE '{}'::jsonb END) AS z(k))=10 AND (x.c->'invoice_anchor_identity') ?& ARRAY['currency','id','institution_code','provider','provider_account_ref','provider_deleted_at','provider_record_id','raw_payload','resource_type','user_id']::text[]) AND
   jsonb_typeof(((x.c->'invoice_anchor_identity')->'id'))='string' AND
   jsonb_typeof(((x.c->'invoice_anchor_identity')->'user_id'))='string' AND
   jsonb_typeof(((x.c->'invoice_anchor_identity')->'provider'))='string' AND
   jsonb_typeof(((x.c->'invoice_anchor_identity')->'currency'))='string' AND
   jsonb_typeof(((x.c->'invoice_anchor_identity')->'resource_type'))='string' AND
   jsonb_typeof(((x.c->'invoice_anchor_identity')->'institution_code'))='string' AND
   jsonb_typeof(((x.c->'invoice_anchor_identity')->'provider_record_id'))='string' AND
   jsonb_typeof(((x.c->'invoice_anchor_identity')->'provider_deleted_at'))='null' AND
   jsonb_typeof(((x.c->'invoice_anchor_identity')->'provider_account_ref'))='string' AND
   ((jsonb_typeof(((x.c->'invoice_anchor_identity')->'raw_payload'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof(((x.c->'invoice_anchor_identity')->'raw_payload'))='object' THEN ((x.c->'invoice_anchor_identity')->'raw_payload') ELSE '{}'::jsonb END) AS z(k))=2 AND ((x.c->'invoice_anchor_identity')->'raw_payload') ?& ARRAY['id','totalAmountCurrencyCode']::text[]) AND
   jsonb_typeof((((x.c->'invoice_anchor_identity')->'raw_payload')->'id'))='string' AND
   jsonb_typeof((((x.c->'invoice_anchor_identity')->'raw_payload')->'totalAmountCurrencyCode'))='string')) AND
   ((jsonb_typeof((x.c->'representative_expense_identity'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof((x.c->'representative_expense_identity'))='object' THEN (x.c->'representative_expense_identity') ELSE '{}'::jsonb END) AS z(k))=7 AND (x.c->'representative_expense_identity') ?& ARRAY['amount','competence_month','event_date','purchase_date','source_ref','source_table','transaction_date']::text[]) AND
   jsonb_typeof(((x.c->'representative_expense_identity')->'source_table'))='string' AND
   jsonb_typeof(((x.c->'representative_expense_identity')->'source_ref'))='string' AND
   jsonb_typeof(((x.c->'representative_expense_identity')->'event_date'))='string' AND
   jsonb_typeof(((x.c->'representative_expense_identity')->'transaction_date'))='string' AND
   jsonb_typeof(((x.c->'representative_expense_identity')->'competence_month'))='string' AND
   jsonb_typeof(((x.c->'representative_expense_identity')->'amount'))='number' AND
   jsonb_typeof(((x.c->'representative_expense_identity')->'purchase_date'))='string') AND
   ((jsonb_typeof((x.c->'prior_expense_identity'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof((x.c->'prior_expense_identity'))='object' THEN (x.c->'prior_expense_identity') ELSE '{}'::jsonb END) AS z(k))=7 AND (x.c->'prior_expense_identity') ?& ARRAY['amount','competence_month','event_date','purchase_date','source_ref','source_table','transaction_date']::text[]) AND
   jsonb_typeof(((x.c->'prior_expense_identity')->'source_table'))='string' AND
   jsonb_typeof(((x.c->'prior_expense_identity')->'source_ref'))='string' AND
   jsonb_typeof(((x.c->'prior_expense_identity')->'event_date'))='string' AND
   jsonb_typeof(((x.c->'prior_expense_identity')->'transaction_date'))='string' AND
   jsonb_typeof(((x.c->'prior_expense_identity')->'competence_month'))='string' AND
   jsonb_typeof(((x.c->'prior_expense_identity')->'amount'))='number' AND
   jsonb_typeof(((x.c->'prior_expense_identity')->'purchase_date'))='string') AND
   ((jsonb_typeof((x.c->'representative_card_identity'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof((x.c->'representative_card_identity'))='object' THEN (x.c->'representative_card_identity') ELSE '{}'::jsonb END) AS z(k))=10 AND (x.c->'representative_card_identity') ?& ARRAY['amount','installment_number','is_payment','last4','posting_date','provider_status','purchase_date','reference_month','source_id','total_installments']::text[]) AND
   jsonb_typeof(((x.c->'representative_card_identity')->'source_id'))='string' AND
   jsonb_typeof(((x.c->'representative_card_identity')->'provider_status'))='string' AND
   jsonb_typeof(((x.c->'representative_card_identity')->'amount'))='number' AND
   jsonb_typeof(((x.c->'representative_card_identity')->'reference_month'))='string' AND
   (jsonb_typeof(((x.c->'representative_card_identity')->'installment_number'))='number' AND (((x.c->'representative_card_identity')->'installment_number'))::text ~ '^-?[0-9]+$') AND
   (jsonb_typeof(((x.c->'representative_card_identity')->'total_installments'))='number' AND (((x.c->'representative_card_identity')->'total_installments'))::text ~ '^-?[0-9]+$') AND
   jsonb_typeof(((x.c->'representative_card_identity')->'last4'))='string' AND
   jsonb_typeof(((x.c->'representative_card_identity')->'posting_date'))='string' AND
   jsonb_typeof(((x.c->'representative_card_identity')->'purchase_date'))='string' AND
   jsonb_typeof(((x.c->'representative_card_identity')->'is_payment'))='boolean') AND
   ((jsonb_typeof((x.c->'prior_card_identity'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof((x.c->'prior_card_identity'))='object' THEN (x.c->'prior_card_identity') ELSE '{}'::jsonb END) AS z(k))=10 AND (x.c->'prior_card_identity') ?& ARRAY['amount','installment_number','is_payment','last4','posting_date','provider_status','purchase_date','reference_month','source_id','total_installments']::text[]) AND
   jsonb_typeof(((x.c->'prior_card_identity')->'source_id'))='string' AND
   jsonb_typeof(((x.c->'prior_card_identity')->'provider_status'))='string' AND
   jsonb_typeof(((x.c->'prior_card_identity')->'amount'))='number' AND
   jsonb_typeof(((x.c->'prior_card_identity')->'reference_month'))='string' AND
   (jsonb_typeof(((x.c->'prior_card_identity')->'installment_number'))='number' AND (((x.c->'prior_card_identity')->'installment_number'))::text ~ '^-?[0-9]+$') AND
   (jsonb_typeof(((x.c->'prior_card_identity')->'total_installments'))='number' AND (((x.c->'prior_card_identity')->'total_installments'))::text ~ '^-?[0-9]+$') AND
   jsonb_typeof(((x.c->'prior_card_identity')->'last4'))='string' AND
   jsonb_typeof(((x.c->'prior_card_identity')->'posting_date'))='string' AND
   jsonb_typeof(((x.c->'prior_card_identity')->'purchase_date'))='string' AND
   jsonb_typeof(((x.c->'prior_card_identity')->'is_payment'))='boolean') AND
   jsonb_typeof((x.c->'identity_basis'))='string')
 AND x.evidence_type IN('owner_confirmed_card_observation_pair_v1','verified_card_observation_pair_v1') AND x.status='documented'
 AND x.c->'version'='2'::jsonb AND (jsonb_typeof(x.st)='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof(x.st)='object' THEN x.st ELSE '{}'::jsonb END) z(k))=3 AND x.st ?& ARRAY['active','revocation_operation_id','revoked_at']::text[]
 AND jsonb_typeof(x.st->'active')='boolean'
 AND ((x.st->'active'='true'::jsonb AND x.st->'revoked_at'='null'::jsonb AND x.st->'revocation_operation_id'='null'::jsonb)
 OR (x.st->'active'='false'::jsonb AND jsonb_typeof(x.st->'revoked_at')='string' AND length(x.st->>'revoked_at')>0
 AND jsonb_typeof(x.st->'revocation_operation_id')='string' AND x.st->>'revocation_operation_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')))),false) AS shape_ok
 FROM q26_scoped x
), q26_selected AS MATERIALIZED (
 SELECT x.* FROM q26_shapes x JOIN q26_pins pins ON pins.evidence_id=x.id AND pins.evidence_type=x.evidence_type
 WHERE x.shape_ok
 AND (SELECT count(*) FROM q26_scoped y WHERE y.id=x.id)=1
 AND x.c->>'operation_id'=x.id::text AND x.c->'evidence_id'=to_jsonb(x.id)
 AND x.c->'owner_id'=to_jsonb(x.user_id) AND x.st->'active'='true'::jsonb
 AND x.c->>'representative_id'<>x.c->>'prior_id'
 AND x.c->>'invoice_anchor_id' NOT IN(x.c->>'representative_id',x.c->>'prior_id')
 AND x.metadata->>'immutable_fingerprint'=pins.fingerprint
 AND pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to((jsonb_build_object('schema','q26-evidence-immutable-v2','evidence',jsonb_build_object('id',x.id,'user_id',x.user_id,'evidence_date',x.evidence_date,'account',x.account,'amount',x.amount,'description',x.description,'evidence_type',x.evidence_type,'source_ref',x.source_ref,'status',x.status),'contract',x.c))::text,'UTF8')),'hex')=pins.fingerprint
 AND NOT EXISTS(SELECT 1 FROM q26_shapes y WHERE y.id<>x.id AND (
   NOT y.shape_ok OR y.c->>'operation_id'=x.c->>'operation_id'
   OR (y.st->'active'='true'::jsonb AND (
    (y.c->>'representative_id'=x.c->>'representative_id' AND y.c->>'prior_id'=x.c->>'prior_id')
    OR (y.c->>'representative_id'=x.c->>'prior_id' AND y.c->>'prior_id'=x.c->>'representative_id')))))
), q26_pair AS MATERIALIZED (
 SELECT x.c,x.id AS evidence_id FROM q26_selected x
 JOIN public.lts_open_finance_staging r ON r.user_id=x.user_id AND r.id::text=x.c->>'representative_id'
 JOIN public.lts_open_finance_staging o ON o.user_id=x.user_id AND o.id::text=x.c->>'prior_id'
 JOIN public.lts_open_finance_staging b ON b.user_id=x.user_id AND b.id::text=x.c->>'invoice_anchor_id'
 WHERE (SELECT count(*) FROM public.lts_open_finance_staging z WHERE z.user_id=x.user_id AND z.id::text=x.c->>'representative_id')=1
 AND (SELECT count(*) FROM public.lts_open_finance_staging z WHERE z.user_id=x.user_id AND z.id::text=x.c->>'prior_id')=1
 AND (SELECT count(*) FROM public.lts_open_finance_staging z WHERE z.user_id=x.user_id AND z.id::text=x.c->>'invoice_anchor_id')=1
 AND ((SELECT jsonb_object_agg(k,to_jsonb(r)->k) FROM unnest(ARRAY['id','user_id','provider','currency','posting_date','resource_type','signed_amount','institution_code','provider_record_id','provider_deleted_at','provider_account_ref']::text[]) z(k))||jsonb_build_object('raw_payload',(SELECT jsonb_object_agg(k,(r.raw_payload)->k) FROM unnest(ARRAY['id','date','type','amount','status','accountId','currencyCode']::text[]) z(k))||jsonb_build_object('creditCardMetadata',(SELECT jsonb_object_agg(k,(r.raw_payload->'creditCardMetadata')->k) FROM unnest(ARRAY['billId','cardNumber','billPostDate','purchaseDate','installmentNumber','totalInstallments','transactionDateTime']::text[]) z(k))),'normalized_payload',(SELECT jsonb_object_agg(k,(r.normalized_payload)->k) FROM unnest(ARRAY['date','last4','layer','amount','status','bill_id','currency','account_type','account_last4','provider_account_id','provider_id','provider_civil_date','installment_number','total_installments']::text[]) z(k))))=x.c->'representative_identity'
 AND ((SELECT jsonb_object_agg(k,to_jsonb(o)->k) FROM unnest(ARRAY['id','user_id','provider','currency','posting_date','resource_type','signed_amount','institution_code','provider_record_id','provider_deleted_at','provider_account_ref']::text[]) z(k))||jsonb_build_object('raw_payload',(SELECT jsonb_object_agg(k,(o.raw_payload)->k) FROM unnest(ARRAY['id','date','type','amount','status','accountId','currencyCode']::text[]) z(k))||jsonb_build_object('creditCardMetadata',(SELECT jsonb_object_agg(k,(o.raw_payload->'creditCardMetadata')->k) FROM unnest(ARRAY['billId','cardNumber','billPostDate','purchaseDate','installmentNumber','totalInstallments','transactionDateTime']::text[]) z(k))),'normalized_payload',(SELECT jsonb_object_agg(k,(o.normalized_payload)->k) FROM unnest(ARRAY['date','last4','layer','amount','status','bill_id','currency','account_type','account_last4','provider_account_id','provider_id','provider_civil_date','installment_number','total_installments']::text[]) z(k))))=x.c->'prior_identity'
 AND ((SELECT jsonb_object_agg(k,to_jsonb(b)->k) FROM unnest(ARRAY['id','user_id','provider','currency','resource_type','institution_code','provider_record_id','provider_deleted_at','provider_account_ref']::text[]) z(k))||jsonb_build_object('raw_payload',(SELECT jsonb_object_agg(k,(b.raw_payload)->k) FROM unnest(ARRAY['id','totalAmountCurrencyCode']::text[]) z(k))))=x.c->'invoice_anchor_identity'
 AND r.provider_deleted_at IS NULL AND o.provider_deleted_at IS NULL AND b.provider_deleted_at IS NULL
 AND r.normalized_payload->>'status'='POSTED' AND o.normalized_payload->>'status'='PENDING'
 AND r.raw_payload#>>'{creditCardMetadata,billId}'=b.raw_payload->>'id'
 AND o.raw_payload#>>'{creditCardMetadata,billId}' IS NULL
 AND x.c->'amount'=to_jsonb(abs(r.signed_amount)) AND x.c->'amount'=to_jsonb(abs(o.signed_amount))
 AND x.c->'currency'=to_jsonb(r.currency) AND x.c->'currency'=to_jsonb(o.currency)
 AND x.c->'currency'=to_jsonb(b.currency)
), q26_resolvable AS MATERIALIZED (
 SELECT p.c FROM q26_pair p
 -- Count every UUID/competence occurrence BEFORE any economic-mask matching.
 WHERE (SELECT count(*) FROM q26_original x WHERE x.source_ref=p.c->>'representative_id' AND to_jsonb(x.competence_month)=p.c->'competence_month')=1
 AND (SELECT count(*) FROM q26_original x WHERE x.source_ref=p.c->>'prior_id' AND to_jsonb(x.competence_month)=p.c->'competence_month')=1
 AND EXISTS(SELECT 1 FROM q26_original x WHERE x.source_ref=p.c->>'representative_id' AND to_jsonb(x.competence_month)=p.c->'competence_month' AND to_jsonb(x) @> (p.c->'representative_expense_identity'))
 AND EXISTS(SELECT 1 FROM q26_original x WHERE x.source_ref=p.c->>'prior_id' AND to_jsonb(x.competence_month)=p.c->'competence_month' AND to_jsonb(x) @> (p.c->'prior_expense_identity'))
)
SELECT x.* FROM q26_original x
WHERE NOT EXISTS(SELECT 1 FROM q26_resolvable p WHERE x.source_ref=p.c->>'prior_id' AND to_jsonb(x.competence_month)=p.c->'competence_month')
$function$
;
REVOKE ALL ON FUNCTION public.lts_expense_rows_pre_categories_v290(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_expense_rows_pre_categories_v290(uuid,date,date) TO service_role;
CREATE OR REPLACE FUNCTION public.lts_v229_expense_rows(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(row_key text, event_date date, transaction_date date, competence_month date, amount numeric, category text, beneficiary text, description text, account_source text, source_table text, source_ref text, coverage_mode text, raw_category text, raw_reference text, purchase_date date, identity_status text, management_group text, management_subgroup text, property_code text, property_component text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
WITH rows AS MATERIALIZED (
 SELECT * FROM public.lts_expense_rows_pre_categories_v290(p_user_id,p_from,p_to)
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
$function$;
-- Replacing the existing function retains its OID, owner, ACL and configuration.

DO $parity$ DECLARE u uuid; old_digest text; new_digest text; BEGIN
 FOR u IN SELECT user_id FROM public.lts_product_read_cache LOOP
  SELECT md5(jsonb_agg(to_jsonb(r)-'category'-'management_group'-'management_subgroup' ORDER BY (to_jsonb(r)-'category'-'management_group'-'management_subgroup')::text)::text)
  INTO old_digest FROM public.lts_expense_rows_pre_categories_v290(u,date '2013-10-10',current_date)r;
  SELECT md5(jsonb_agg(to_jsonb(r)-'category'-'management_group'-'management_subgroup' ORDER BY (to_jsonb(r)-'category'-'management_group'-'management_subgroup')::text)::text)
  INTO new_digest FROM public.lts_v229_expense_rows(u,date '2013-10-10',current_date)r;
  IF old_digest IS DISTINCT FROM new_digest THEN RAISE EXCEPTION 'Non-category financial fields changed'; END IF;
 END LOOP;
END $parity$;

-- Invalidate dependent read models without changing their freshness timestamps.
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
