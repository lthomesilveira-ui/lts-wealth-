BEGIN;
SET LOCAL statement_timeout='120s';
DO $lease$ BEGIN
IF md5(pg_get_functiondef('public.lts_card_document_matches_v234(uuid)'::regprocedure))<>'2fcdc53c715b808b6d7fdf3e02edd363' THEN RAISE EXCEPTION 'Source lease changed: lts_card_document_matches_v234.sql'; END IF;
IF md5(pg_get_functiondef('public.lts_card_source_rows_pre_v262(uuid)'::regprocedure))<>'3124fb388c7ba327a1197dda96d296b4' THEN RAISE EXCEPTION 'Source lease changed: lts_card_source_rows_pre_v262.sql'; END IF;
IF md5(pg_get_functiondef('public.lts_card_invoice_amounts_v230_engine_v243(uuid)'::regprocedure))<>'f03bbb2e8af0dd2ba3124396f7eb6ee6' THEN RAISE EXCEPTION 'Source lease changed: lts_card_invoice_amounts_v230_engine_v243.sql'; END IF;
IF md5(pg_get_functiondef('public.lts_card_cycles_v226(uuid)'::regprocedure))<>'77efe46f9b6a5e3c117434eb233464b9' THEN RAISE EXCEPTION 'Source lease changed: lts_card_cycles_v226.sql'; END IF;
IF md5(pg_get_functiondef('public.lts_card_invoices_effective_v226(uuid)'::regprocedure))<>'86c8d7c225436171c8059c75676d7626' THEN RAISE EXCEPTION 'Source lease changed: lts_card_invoices_effective_v226.sql'; END IF;
IF md5(pg_get_functiondef('public.lts_browser_card_detail_v226(text,date)'::regprocedure))<>'c4c73a09b7a29ec5a5cc3d0d12a2e921' THEN RAISE EXCEPTION 'Source lease changed: lts_browser_card_detail_v226.sql'; END IF;
IF to_regprocedure('public.lts_c6_cycle_identity_v269(uuid)') IS NOT NULL THEN RAISE EXCEPTION 'New helper already exists; inspect concurrent change'; END IF;
END $lease$;
-- Candidate, not applied. Resolve only the documented C6 one-month forecast/due offset.
-- A projected snapshot contributes cycle identity, never official invoice amount/status.
CREATE OR REPLACE FUNCTION public.lts_c6_cycle_identity_v269(p_user_id uuid)
RETURNS TABLE(source_id uuid,reference_month date,due_date date,cycle_basis text)
LANGUAGE sql STABLE SET search_path='' SET "TimeZone"='America/Sao_Paulo'
AS $function$
WITH unique_account AS MATERIALIZED (
 SELECT min(provider_account_ref) provider_account_ref FROM public.lts_open_finance_staging
 WHERE user_id=p_user_id AND institution_code='336' AND resource_type='credit_card' AND provider_deleted_at IS NULL
 HAVING count(DISTINCT provider_account_ref)=1 AND count(*) FILTER(WHERE nullif(provider_account_ref,'') IS NULL)=0
), documented AS MATERIALIZED (
 SELECT ci.reference_month,ci.due_date,
  coalesce((sd.metadata->>'closing_date')::date,(ci.metadata->>'bank_statement_closing_date')::date) closing_date,
  sd.metadata->'existing_source_items' items
 FROM public.card_invoices ci JOIN public.source_documents sd
  ON sd.id::text=ci.metadata->>'bank_statement_document_id' AND sd.user_id=ci.user_id
 WHERE ci.user_id=p_user_id AND public.lts_card_family_v226(ci.card_name,sd.institution)='c6'
  AND ci.status='closed' AND ci.metadata->>'bank_statement_closed'='true'
  AND ci.metadata->>'bank_statement_full_composition'='true'
  AND sd.document_type='credit_card_statement' AND sd.processing_status='processed'
  AND sd.sha256=ci.metadata->>'bank_statement_sha256'
  AND sd.metadata->>'all_source_lines_matched'='true'
  AND (sd.metadata->>'statement_amount')::numeric=ci.amount
  AND (sd.metadata->>'due_date')::date=ci.due_date
), closed_rows AS MATERIALIZED (
 SELECT d.reference_month,d.due_date,d.closing_date,s.provider_account_ref,
  CASE WHEN s.raw_payload#>>'{creditCardMetadata,billForecastDate}' ~ '^[0-9]{4}-[0-9]{2}$'
   THEN (s.raw_payload#>>'{creditCardMetadata,billForecastDate}'||'-01')::date END forecast
 FROM documented d CROSS JOIN LATERAL jsonb_array_elements(d.items) e
 JOIN public.lts_open_finance_staging s ON s.user_id=p_user_id AND s.id::text=e->>'source_id'
  AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL AND s.institution_code='336'
 WHERE NOT coalesce((e->>'is_payment')::boolean,false) AND nullif(s.provider_account_ref,'') IS NOT NULL
), anchors AS MATERIALIZED (
 SELECT provider_account_ref,reference_month,min(due_date) due_date,min(closing_date) closing_date,min(forecast) forecast
 FROM closed_rows GROUP BY provider_account_ref,reference_month
 HAVING count(DISTINCT due_date)=1 AND count(DISTINCT closing_date)=1
  AND count(forecast)=count(*) AND count(DISTINCT forecast)=1
  AND min(forecast)=(reference_month-interval '1 month')::date
  AND min(forecast)=date_trunc('month',min(closing_date))::date
), candidates AS MATERIALIZED (
 SELECT a.provider_account_ref,a.closing_date,a.forecast,(a.reference_month+interval '1 month')::date reference_month,
  min(ci.due_date) due_date
 FROM anchors a JOIN unique_account ua ON ua.provider_account_ref=a.provider_account_ref
 JOIN public.card_invoices ci ON ci.user_id=p_user_id
  AND public.lts_card_family_v226(ci.card_name,ci.card_name)='c6'
  AND ci.reference_month=(a.reference_month+interval '1 month')::date
  AND ci.due_date>=ci.reference_month AND ci.due_date<(ci.reference_month+interval '1 month')::date
 GROUP BY a.provider_account_ref,a.closing_date,a.forecast,a.reference_month
 HAVING count(DISTINCT ci.due_date)=1
), resolved AS (
 SELECT s.id source_id,c.reference_month,c.due_date
 FROM public.lts_open_finance_staging s JOIN candidates c ON c.provider_account_ref=s.provider_account_ref
 WHERE s.user_id=p_user_id AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL
  AND s.institution_code='336' AND s.normalized_payload->>'status' IN('PENDING','POSTED')
  AND NOT EXISTS(SELECT 1 FROM public.lts_open_finance_staging b WHERE b.user_id=s.user_id
   AND b.institution_code=s.institution_code AND b.resource_type='invoice' AND b.provider_deleted_at IS NULL
   AND b.normalized_payload->>'provider_id'=s.raw_payload#>>'{creditCardMetadata,billId}')
  AND s.raw_payload#>>'{creditCardMetadata,billForecastDate}'=to_char(c.forecast+interval '1 month','YYYY-MM')
  AND s.posting_date>c.closing_date AND s.posting_date<c.due_date
  AND NOT(coalesce(s.raw_payload->>'operationType','')='PAGAMENTO_FATURA'
 OR coalesce(s.raw_payload->>'category','')='Credit card payment'
 OR public.lts_v178_norm(s.description_raw) ~ '^(inclusao de pagamento ciclo corrente|pagamento recebido|pagto fatura)')
  AND NOT EXISTS(SELECT 1 FROM documented d CROSS JOIN LATERAL jsonb_array_elements(d.items) e WHERE e->>'source_id'=s.id::text)
)
SELECT source_id,min(reference_month),min(due_date),'documented_forecast_offset_and_successor'::text
FROM resolved GROUP BY source_id HAVING count(DISTINCT reference_month)=1 AND count(DISTINCT due_date)=1
$function$;
REVOKE ALL ON FUNCTION public.lts_c6_cycle_identity_v269(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_c6_cycle_identity_v269(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_card_document_matches_v234(p_user_id uuid)
 RETURNS TABLE(document_id uuid, provider_id uuid)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 WITH identities AS MATERIALIZED (SELECT * FROM public.lts_c6_cycle_identity_v269(p_user_id)), documents AS MATERIALIZED (
  SELECT * FROM public.lts_card_document_supplement_v234 WHERE user_id=p_user_id
 ), candidates AS MATERIALIZED (
  SELECT d.id document_id,s.id provider_id
  FROM documents d JOIN public.lts_open_finance_staging s ON s.user_id=d.user_id
  AND s.institution_code=d.institution_code AND s.provider_account_ref=d.provider_account_ref
  AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL
  AND coalesce(s.raw_payload#>>'{creditCardMetadata,cardNumber}',s.normalized_payload->>'last4')
      IN (d.last4,d.metadata->>'original_card_last4')
  AND public.lts_card_merchant_key_v226(s.description_raw)=public.lts_card_merchant_key_v226(d.description)
  AND abs(-s.signed_amount-d.amount)<=0.15
  AND s.raw_payload#>>'{creditCardMetadata,installmentNumber}'=d.installment_number::text
  AND s.raw_payload#>>'{creditCardMetadata,totalInstallments}'=d.total_installments::text
  AND CASE WHEN left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
      THEN abs(left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10)::date-d.purchase_date)<=2 ELSE false END
  AND (EXISTS(SELECT 1 FROM identities ci WHERE ci.source_id=s.id AND ci.reference_month=d.reference_month AND ci.due_date=d.due_date)
   OR s.raw_payload#>>'{creditCardMetadata,billForecastDate}'=to_char(d.reference_month,'YYYY-MM')
   OR EXISTS(SELECT 1 FROM public.lts_open_finance_staging b
    WHERE b.user_id=s.user_id AND b.institution_code=s.institution_code AND b.resource_type='invoice'
    AND b.provider_deleted_at IS NULL AND b.normalized_payload->>'provider_id'=s.raw_payload#>>'{creditCardMetadata,billId}'
    AND date_trunc('month',b.posting_date)::date=d.reference_month))
 ), unique_candidates AS (
  SELECT *,count(*) OVER(PARTITION BY document_id) dc,count(*) OVER(PARTITION BY provider_id) pc FROM candidates
 )
 SELECT document_id,provider_id FROM unique_candidates WHERE dc=1 AND pc=1
$function$;

CREATE OR REPLACE FUNCTION public.lts_card_source_rows_pre_v262(p_user_id uuid)
 RETURNS TABLE(source_id uuid, bank text, family text, card_name text, last4 text, billing_last4 text, posting_date date, purchase_date date, reference_month date, due_date date, provider_status text, amount numeric, description text, category text, category_basis text, installment_number integer, total_installments integer, is_payment boolean, bill_id text, observed_at timestamp with time zone)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH provider_rows(source_id,bank,family,card_name,last4,billing_last4,posting_date,purchase_date,reference_month,due_date,provider_status,amount,description,category,category_basis,installment_number,total_installments,is_payment,bill_id,observed_at) AS MATERIALIZED (
with installment_decisions as materialized (
 select public.lts_card_installment_key_v231(s) purchase_key,
 case when count(distinct d.category_label)=1 and count(distinct coalesce(d.beneficiary,''))=1 then min(d.category_label) end category,
 case when count(distinct d.category_label)=1 and count(distinct coalesce(d.beneficiary,''))=1 then min(d.beneficiary) end person
 from public.lts_open_finance_staging s join public.lts_v178_review_decision d
 on d.user_id=s.user_id and d.source_table='lts_open_finance_staging' and d.source_ref=s.id::text
 where s.user_id=p_user_id and s.provider_deleted_at is null and d.category_label is not null
 group by public.lts_card_installment_key_v231(s)
), evidence as materialized (
 select public.lts_card_merchant_key_v226(p.description_raw) k,round(p.installment_amount,2) amount,
 coalesce(d.category_label,p.category) category,p.card_final last4,p.installments,
 p.invoice_due_date evidence_date,d.beneficiary person
 from public.lts_card_purchase_detail p left join public.lts_v178_review_decision d
 on d.user_id=p.user_id and d.source_table='card_purchase_detail' and d.source_ref=p.line_key
 where p.user_id=p_user_id
 union all
 select public.lts_card_merchant_key_v226(a.description_norm),round(a.amount,2),a.category,null,null,a.event_date,null
 from public.lts_semantic_amount_signature a where a.user_id=p_user_id and a.source_kind='card'
), exact_categories as materialized (
 -- Broad merchant/amount evidence may establish a nature, never a beneficiary.
 select k,amount,case when count(distinct category)=1 then
 nullif(regexp_replace(min(category),'^(Lucas|Larissa|Benjamin|Rafiki)([[:space:]]*[-—–][[:space:]]*|[[:space:]]*$)','','i'),'') end category,
 null::text person
 from evidence where pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') not in ('','a classificar','nao identificado','sem categoria','—')
 group by k,amount
), nature_categories as materialized (
 select k,case when count(distinct regexp_replace(category,'^(Lucas|Larissa|Benjamin|Rafiki)([[:space:]]*[-—–][[:space:]]*|[[:space:]]*$)','','i'))=1
 then nullif(min(regexp_replace(category,'^(Lucas|Larissa|Benjamin|Rafiki)([[:space:]]*[-—–][[:space:]]*|[[:space:]]*$)','','i')),'') end category
 from evidence where pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') not in ('','a classificar','nao identificado','sem categoria','—')
 and k !~ 'mercado|amazon|shop|pagseguro|merpago' group by k
), rule_keys as materialized (
 select public.lts_card_merchant_key_v226(r.match_value) k,r.category,r.center_cost person,
 case when r.confidence='user_confirmed' then 0 else 1 end priority
 from public.lts_semantic_rule r where r.user_id=p_user_id and r.active and r.match_type='exact'
 and r.confidence in ('high','alta','system_high','user_confirmed')
), rule_categories as materialized (
 select k,case when count(distinct category)=1 then min(category) end category,case when count(distinct person)=1 then min(person) end person
 from (select *,dense_rank() over(partition by k order by priority) rank from rule_keys where k !~ '^(mercado|shopee|pagseguro|merpago)')q where rank=1 group by k
), src as materialized (
 select s.*,case s.institution_code when '237' then 'Bradesco' when '341' then 'Itaú' when '336' then 'C6' end bank,
 public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) family,
 public.lts_card_merchant_key_v226(s.description_raw) merchant_key,
 public.lts_card_installment_key_v231(s) purchase_key,
 s.raw_payload#>>'{creditCardMetadata,billId}' raw_bill_id,
 case when s.raw_payload#>>'{creditCardMetadata,billForecastDate}' ~ '^[0-9]{4}-[0-9]{2}$'
 then (s.raw_payload#>>'{creditCardMetadata,billForecastDate}'||'-01')::date end forecast,
 (coalesce(s.raw_payload->>'operationType','')='PAGAMENTO_FATURA'
 or coalesce(s.raw_payload->>'category','')='Credit card payment'
 or pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(s.description_raw,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^(inclusao de pagamento ciclo corrente|pagamento recebido|pagto fatura)') payment
 from public.lts_open_finance_staging s where s.user_id=p_user_id and s.resource_type='card_transaction'
 and s.provider_deleted_at is null
), open_cards as materialized (
 select distinct on (family) family,reference_month,due_date from (
  select public.lts_card_family_v226(i.card_name,case when i.card_name ~* 'c6' then 'C6' when i.card_name ~* 'aeternum|bradesco|prime' then 'Bradesco' else 'Itaú' end) family,i.reference_month,i.due_date
  from public.card_invoices i where i.user_id=p_user_id and i.status='open' and i.due_date>=current_date
 )q order by family,due_date
), documented_cycles AS MATERIALIZED (
 SELECT (e->>'source_id')::uuid source_id,min(ci.reference_month) reference_month,min(ci.due_date) due_date
 FROM public.card_invoices ci JOIN public.source_documents sd
  ON sd.id::text=ci.metadata->>'bank_statement_document_id' AND sd.user_id=ci.user_id
 CROSS JOIN LATERAL jsonb_array_elements(sd.metadata->'existing_source_items') e
 WHERE ci.user_id=p_user_id AND ci.status='closed'
  AND ci.metadata->>'bank_statement_closed'='true'
  AND ci.metadata->>'bank_statement_full_composition'='true'
  AND sd.document_type='credit_card_statement' AND sd.processing_status='processed'
  AND sd.sha256=ci.metadata->>'bank_statement_sha256'
  AND sd.metadata->>'all_source_lines_matched'='true'
  AND (sd.metadata->>'statement_amount')::numeric=ci.amount
  AND (sd.metadata->>'due_date')::date=ci.due_date
 GROUP BY e->>'source_id' HAVING count(DISTINCT ci.reference_month)=1 AND count(DISTINCT ci.due_date)=1
), dated as materialized (
 select s.*,coalesce(dc.due_date,b.posting_date,ci.due_date) bill_due,
 case when dc.source_id is not null then dc.reference_month
 when b.id is not null then date_trunc('month',b.posting_date)::date
 when ci.source_id is not null then ci.reference_month
 -- C6 reports the purchase month for its current open cycle. The document supplies the due month.
 when s.institution_code='336' and s.normalized_payload->>'status'='PENDING'
 and s.forecast<=date_trunc('month',current_date)::date then coalesce(c.reference_month,s.forecast)
 else s.forecast end cycle,
 c.due_date open_due
 from src s left join documented_cycles dc on dc.source_id=s.id
 left join public.lts_c6_cycle_identity_v269(p_user_id) ci on ci.source_id=s.id
 left join public.lts_open_finance_staging b on b.user_id=s.user_id
 and b.institution_code=s.institution_code and b.resource_type='invoice'
 and b.normalized_payload->>'provider_id'=s.raw_bill_id
 left join open_cards c on c.family=s.family
), classified as (
 select s.*,coalesce(d.category_label,ic.category,ec.category,sr.category,nc.category) known_category,case
 -- A source-specific person-only decision remains explicit evidence. A category
 -- decision with no beneficiary must keep NULL, not borrow a lower-priority person.
 when d.category_label is not null or d.beneficiary is not null then d.beneficiary
 when ic.category is not null then ic.person
 when ec.category is not null then null::text
 when sr.category is not null then sr.person
 else null::text end known_person,
 case when d.category_label is not null then case when d.decision_basis like 'workbook_restore_v226%' then 'historical_workbook' else 'user_decision' end
 when ic.category is not null then 'confirmed_same_purchase_installments'
 when ec.category is not null then 'same_merchant_and_amount'
 when sr.category is not null then 'restored_explicit_rule'
 when nc.category is not null then 'historical_merchant_nature' end known_basis
 from dated s left join installment_decisions ic on ic.purchase_key=s.purchase_key
 left join exact_categories ec on ec.k=s.merchant_key and ec.amount=round(-s.signed_amount,2)
 left join nature_categories nc on nc.k=s.merchant_key
 left join rule_categories sr on sr.k=s.merchant_key
 left join public.lts_v178_review_decision d on d.user_id=p_user_id and d.source_table='lts_open_finance_staging' and d.source_ref=s.id::text
), provider_classification as (
 select c.*,case
 when c.raw_payload->>'category' in ('Credit card fees','Bank fees') then 'Tarifas bancárias'
 when c.raw_payload->>'category'='Tax on financial operations' then 'IOF'
 when c.merchant_key ~ '^(ifd|ifood)' and c.raw_payload->>'category' in ('Food delivery','Restaurants','Eating out','Groceries') then 'Ifood'
 when c.raw_payload->>'category'='Pharmacy' and c.merchant_key ~ 'drog|pharma|farma' then 'Farmácia'
 when c.raw_payload->>'category'='Groceries' and c.merchant_key ~ 'paodeacucar|obahortifruti|supermercado' then 'Mercado'
 when c.raw_payload->>'category' in ('Restaurants','Eating out') then 'Restaurantes'
 when c.raw_payload#>>'{creditCardMetadata,payeeMCC}'='5812' and c.merchant_key ~ 'bbq|restaur' then 'Restaurantes'
 when c.raw_payload->>'category'='Gas stations' and c.merchant_key ~ 'posto' then 'Combustível'
 when c.raw_payload->>'category'='Parking' and c.merchant_key ~ 'park|vallet|estacion' then 'Estacionamento e Pedágio'
 when c.raw_payload->>'category'='Healthcare' and c.merchant_key ~ '^(dr|clinica)' then 'Saúde'
 when c.raw_payload->>'category'='Clothing' and c.merchant_key ~ 'minimalclub|^ecreise|^paypalfrancagrif' then 'Vestuário'
 when c.raw_payload->>'category'='Tickets' and c.merchant_key ~ '^fevercandlelight' then 'Passeios'
 end provider_category from classified c
)
select s.id,s.bank,s.family,s.normalized_payload->>'card_name',
 coalesce(nullif(s.raw_payload#>>'{creditCardMetadata,cardNumber}',''),s.normalized_payload->>'last4'),
 s.normalized_payload->>'last4',s.posting_date,
 case when s.raw_payload#>>'{creditCardMetadata,purchaseDate}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T.*(Z|[+-][0-9]{2}:[0-9]{2})$'
 then ((s.raw_payload#>>'{creditCardMetadata,purchaseDate}')::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date
 when s.raw_payload#>>'{creditCardMetadata,purchaseDate}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
 then left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10)::date else s.posting_date end,
 s.cycle,coalesce(s.bill_due,case when date_trunc('month',s.open_due)::date=s.cycle then s.open_due end),
 s.normalized_payload->>'status',-s.signed_amount,s.description_raw,
 coalesce(case when s.known_person in ('Lucas','Larissa','Benjamin','Rafiki') and s.known_category is not null and s.known_category !~* '^(Lucas|Larissa|Benjamin|Rafiki)' then s.known_person||' — '||s.known_category else s.known_category end,s.provider_category,'A classificar'),
 coalesce(s.known_basis,case when s.provider_category is null then 'unresolved' when s.raw_payload->>'category' in ('Credit card fees','Bank fees','Tax on financial operations') then 'explicit_fee_type' else 'merchant_and_provider_category' end),
 case when s.raw_payload#>>'{creditCardMetadata,installmentNumber}' ~ '^[0-9]+$' then (s.raw_payload#>>'{creditCardMetadata,installmentNumber}')::integer end,
 case when s.raw_payload#>>'{creditCardMetadata,totalInstallments}' ~ '^[0-9]+$' then (s.raw_payload#>>'{creditCardMetadata,totalInstallments}')::integer end,
 s.payment,s.raw_bill_id,s.last_seen_at
from provider_classification s
), documented_decisions AS MATERIALIZED (
 SELECT m.provider_id,d.category_label,d.beneficiary
 FROM public.lts_card_document_matches_v234(p_user_id) m
 JOIN public.lts_v178_review_decision d ON d.user_id=p_user_id
  AND d.source_table='lts_card_document_supplement_v234' AND d.source_ref=m.document_id::text
 WHERE d.category_label IS NOT NULL
)
SELECT p.source_id,p.bank,p.family,p.card_name,p.last4,p.billing_last4,p.posting_date,p.purchase_date,p.reference_month,p.due_date,
 p.provider_status,p.amount,p.description,
 coalesce(CASE WHEN d.beneficiary IN ('Larissa','Benjamin','Rafiki') THEN d.beneficiary||' — '||d.category_label ELSE d.category_label END,p.category),
 CASE WHEN d.category_label IS NOT NULL THEN 'user_decision_document' ELSE p.category_basis END,
 p.installment_number,p.total_installments,p.is_payment,p.bill_id,p.observed_at
FROM provider_rows p LEFT JOIN documented_decisions d ON d.provider_id=p.source_id
UNION ALL SELECT * FROM public.lts_card_document_rows_v234(p_user_id)

$function$;

CREATE OR REPLACE FUNCTION public.lts_card_invoice_amounts_v230_engine_v243(p_user_id uuid)
 RETURNS TABLE(user_id uuid, card_name text, reference_month date, due_date date, status text, amount numeric, source text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH c6_eligible AS MATERIALIZED (
 SELECT ci.source_id FROM (
 SELECT * FROM public.lts_c6_cycle_identity_v269(p_user_id)
 UNION ALL SELECT tx.id,date_trunc('month',b.posting_date)::date,b.posting_date,'received_bill_identity'::text
 FROM public.lts_open_finance_staging tx JOIN public.lts_open_finance_staging b
 ON b.user_id=tx.user_id AND b.institution_code=tx.institution_code AND b.resource_type='invoice'
 AND b.provider_deleted_at IS NULL AND b.provider_account_ref=tx.provider_account_ref
 AND b.normalized_payload->>'provider_id'=tx.raw_payload#>>'{creditCardMetadata,billId}'
 WHERE tx.user_id=p_user_id AND tx.institution_code='336' AND tx.resource_type='card_transaction'
 AND tx.provider_deleted_at IS NULL
 ) ci JOIN public.card_invoices open_cycle ON open_cycle.user_id=p_user_id
 AND public.lts_card_family_v226(open_cycle.card_name,open_cycle.card_name)='c6'
 AND open_cycle.reference_month=ci.reference_month AND open_cycle.due_date=ci.due_date
 AND open_cycle.status IN('open','projected')
), baseline AS MATERIALIZED (
WITH documented_families AS MATERIALIZED (
 SELECT DISTINCT family FROM public.lts_card_document_supplement_v234 WHERE user_id=p_user_id
), src AS MATERIALIZED (
 SELECT s.id,s.user_id,s.institution_code,s.signed_amount,
 public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) family,
 s.raw_payload#>>'{creditCardMetadata,billId}' raw_bill_id,
 CASE WHEN s.raw_payload#>>'{creditCardMetadata,billForecastDate}' ~ '^[0-9]{4}-[0-9]{2}$'
 THEN (s.raw_payload#>>'{creditCardMetadata,billForecastDate}'||'-01')::date END forecast,
 CASE WHEN s.raw_payload#>>'{creditCardMetadata,installmentNumber}' ~ '^[0-9]+$'
 THEN (s.raw_payload#>>'{creditCardMetadata,installmentNumber}')::integer END installment_number,
 CASE WHEN s.raw_payload#>>'{creditCardMetadata,totalInstallments}' ~ '^[0-9]+$'
 THEN (s.raw_payload#>>'{creditCardMetadata,totalInstallments}')::integer END total_installments
 FROM public.lts_open_finance_staging s WHERE s.user_id=p_user_id AND s.resource_type='card_transaction'
 AND s.provider_deleted_at IS NULL AND (s.normalized_payload->>'status'='PENDING' OR (s.normalized_payload->>'status'='POSTED' AND s.id IN (SELECT source_id FROM c6_eligible)))
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
 coalesce(b.posting_date,ci.due_date,CASE WHEN date_trunc('month',c.due_date)::date=s.forecast THEN c.due_date END) due_date,
 CASE WHEN b.id IS NOT NULL THEN date_trunc('month',b.posting_date)::date
 WHEN ci.source_id IS NOT NULL THEN ci.reference_month
 WHEN s.institution_code='336' AND s.forecast<=date_trunc('month',current_date)::date
 THEN coalesce(c.reference_month,s.forecast) ELSE s.forecast END reference_month
 FROM src s LEFT JOIN public.lts_open_finance_staging b ON b.user_id=s.user_id AND b.institution_code=s.institution_code
 AND b.resource_type='invoice' AND b.normalized_payload->>'provider_id'=s.raw_bill_id
 LEFT JOIN public.lts_c6_cycle_identity_v269(p_user_id) ci ON ci.source_id=s.id
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
), received_bills AS MATERIALIZED (
 SELECT b.* FROM public.lts_current_received_card_bills_v263(p_user_id) b
 WHERE (b.due_date>=current_date OR EXISTS(
 SELECT 1 FROM public.card_invoices open_cycle
 WHERE open_cycle.user_id=p_user_id
 AND open_cycle.status IN('open','projected')
 AND open_cycle.reference_month=b.reference_month
 AND open_cycle.due_date=b.due_date
 AND public.lts_card_family_v226(open_cycle.card_name,open_cycle.card_name)=b.family))
 AND NOT EXISTS(SELECT 1 FROM public.card_invoices i WHERE i.user_id=p_user_id
 AND i.reference_month=b.reference_month
 AND public.lts_card_family_v226(i.card_name,i.card_name)=b.family
 AND (i.status NOT IN('open','projected') OR i.due_date IS DISTINCT FROM b.due_date
 OR (CASE WHEN i.metadata->>'as_of' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 THEN (i.metadata->>'as_of')::date ELSE '-infinity'::date END)
 >(b.source_updated_at AT TIME ZONE 'America/Sao_Paulo')::date))
)
SELECT r.user_id,r.card_name,r.reference_month,r.due_date,
 CASE WHEN b.payment_status='paid' AND r.status IN('open','projected') THEN 'paid' ELSE r.status END status,
 CASE WHEN b.invoice_source_id IS NOT NULL AND r.status IN('open','projected') THEN b.amount ELSE r.amount END amount,
 CASE WHEN b.invoice_source_id IS NOT NULL AND r.status IN('open','projected') THEN 'open_finance_invoice_v263' ELSE r.source END source
FROM baseline r LEFT JOIN received_bills b ON r.reference_month=b.reference_month AND r.due_date=b.due_date
AND public.lts_card_family_v226(r.card_name,r.card_name)=b.family
UNION ALL
SELECT p_user_id,b.card_name,b.reference_month,b.due_date,
 CASE WHEN b.payment_status='paid' THEN 'paid' ELSE 'open' END,b.amount,'open_finance_invoice_v263'
FROM received_bills b WHERE NOT EXISTS(SELECT 1 FROM baseline r
 WHERE r.reference_month=b.reference_month AND public.lts_card_family_v226(r.card_name,r.card_name)=b.family)
$function$;

CREATE OR REPLACE FUNCTION public.lts_card_cycles_v226(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with c6_eligible AS MATERIALIZED (
 SELECT ci.source_id FROM (
 SELECT * FROM public.lts_c6_cycle_identity_v269(p_user_id)
 UNION ALL SELECT tx.id,date_trunc('month',b.posting_date)::date,b.posting_date,'received_bill_identity'::text
 FROM public.lts_open_finance_staging tx JOIN public.lts_open_finance_staging b
 ON b.user_id=tx.user_id AND b.institution_code=tx.institution_code AND b.resource_type='invoice'
 AND b.provider_deleted_at IS NULL AND b.provider_account_ref=tx.provider_account_ref
 AND b.normalized_payload->>'provider_id'=tx.raw_payload#>>'{creditCardMetadata,billId}'
 WHERE tx.user_id=p_user_id AND tx.institution_code='336' AND tx.resource_type='card_transaction'
 AND tx.provider_deleted_at IS NULL
 ) ci JOIN public.card_invoices open_cycle ON open_cycle.user_id=p_user_id
 AND public.lts_card_family_v226(open_cycle.card_name,open_cycle.card_name)='c6'
 AND open_cycle.reference_month=ci.reference_month AND open_cycle.due_date=ci.due_date
 AND open_cycle.status IN('open','projected')
), rows as materialized (select * from public.lts_card_source_rows_v226(p_user_id)),
accounts as materialized (
 select s.institution_name bank,public.lts_card_family_v226(s.normalized_payload->>'name',s.institution_name) family,
 s.normalized_payload->>'name' name,s.normalized_payload->>'last4' last4,
 s.raw_payload#>>'{creditData,status}' status,s.raw_payload#>'{creditData,additionalCards}' additional_cards,
 nullif(s.normalized_payload->>'due_date','')::date last_due,s.last_seen_at observed_at
 from public.lts_open_finance_staging s where s.user_id=p_user_id and s.resource_type='credit_card' and s.provider_deleted_at is null
), pending as materialized (
 select family,reference_month,min(due_date) due_date,count(*) n,round(sum(amount),2) amount,
 count(*) filter(where category_basis='unresolved') unclassified,max(observed_at) observed_at,
 jsonb_agg((to_jsonb(r)-'bank'-'family'-'card_name'-'billing_last4'-'bill_id')||coalesce((SELECT jsonb_build_object('source_document',jsonb_build_object('file_ref',d.source_file_ref,'sha256',d.source_sha256,'page',d.source_page,'line',d.source_line,'as_of',d.source_as_of,'amount',d.amount)) FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=p_user_id AND (d.id=r.source_id OR d.id=(SELECT m.document_id FROM public.lts_card_document_matches_v234(p_user_id) m WHERE m.provider_id=r.source_id))),'{}'::jsonb) order by posting_date desc,description,source_id) items
 from rows r where not is_payment and (r.provider_status IN ('PENDING','DOCUMENTED') OR (r.provider_status='POSTED' AND r.source_id IN (SELECT source_id FROM c6_eligible))) and reference_month>=date_trunc('month',current_date)::date group by family,reference_month
), first_cycles as materialized (select family,min(reference_month) AS month from pending group by family),
installments as materialized (
 select r.family,(r.reference_month+make_interval(months=>n))::date reference_month,r.amount,r.category_basis,r.observed_at,
 to_jsonb(r)||coalesce((SELECT jsonb_build_object('source_document',jsonb_build_object('file_ref',d.source_file_ref,'sha256',d.source_sha256,'page',d.source_page,'line',d.source_line,'as_of',d.source_as_of,'amount',d.amount)) FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=p_user_id AND (d.id=r.source_id OR d.id=(SELECT m.document_id FROM public.lts_card_document_matches_v234(p_user_id) m WHERE m.provider_id=r.source_id))),'{}'::jsonb)||jsonb_build_object('reference_month',(r.reference_month+make_interval(months=>n))::date,'installment_number',r.installment_number+n,'provider_status','PROJECTED','projection_basis','remaining_installments_of_received_purchase') item
 from rows r join first_cycles f on f.family=r.family and f.month=r.reference_month
 cross join lateral generate_series(1,least(120,r.total_installments-r.installment_number)) n
 where not r.is_payment and (r.provider_status IN ('PENDING','DOCUMENTED') OR (r.provider_status='POSTED' AND r.source_id IN (SELECT source_id FROM c6_eligible))) and r.amount>0 and r.installment_number>0 and r.total_installments>r.installment_number
), projected as materialized (
 select family,reference_month,count(*) n,round(sum(amount),2) amount,count(*) filter(where category_basis='unresolved') unclassified,
 max(observed_at) observed_at,jsonb_agg(item order by item->>'description',item->>'source_id') items from installments group by family,reference_month
), composition as materialized (
 select coalesce(p.family,j.family) family,coalesce(p.reference_month,j.reference_month) reference_month,p.due_date,
 coalesce(p.n,j.n) n,coalesce(p.amount,j.amount) amount,coalesce(p.unclassified,j.unclassified) unclassified,
 coalesce(p.observed_at,j.observed_at) observed_at,coalesce(p.items,j.items) items,
 case when p.n>0 and p.reference_month=f.month AND EXISTS(SELECT 1 FROM rows r WHERE r.family=p.family AND r.reference_month=p.reference_month AND r.provider_status='DOCUMENTED') then 'bank_document_composition' when p.n>0 and p.reference_month=f.month then 'open_finance_composition' when p.n>0 then 'provider_installments' else 'derived_current_installments' end basis
 from pending p full join projected j on j.family=p.family and j.reference_month=p.reference_month
 left join first_cycles f on f.family=coalesce(p.family,j.family)
), docs as materialized (
 select i.*,public.lts_card_family_v226(i.card_name,case when i.card_name ~* 'c6' then 'C6' when i.card_name ~* 'aeternum|bradesco|prime' then 'Bradesco' else 'Itaú' end) family
 from public.card_invoices i where i.user_id=p_user_id and i.due_date>=current_date and i.status<>'paid'
), cycles0 as (
 select coalesce(p.family,d.family) family,coalesce(p.reference_month,d.reference_month) AS month,
 coalesce(p.due_date,d.due_date) due_date,
 case when p.basis='derived_current_installments' then greatest(p.amount,coalesce(d.amount,0)) else coalesce(p.amount,d.amount) end amount,
 case when p.basis='derived_current_installments' and d.amount>p.amount then 'documented_floor_partial_detail'
 else coalesce(p.basis,case when d.source='derived_installments' then 'contracted_installments' else 'documented_snapshot' end) end basis,
 coalesce(p.n,0) item_count,coalesce(p.unclassified,0) unclassified,coalesce(p.items,'[]'::jsonb) items,p.observed_at,d.amount documentary_amount,
 case when d.metadata->>'as_of' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then d.metadata->>'as_of' end documentary_as_of
 from composition p full join docs d on d.family=p.family and d.reference_month=p.reference_month
), received_bills AS MATERIALIZED (
 SELECT b.* FROM public.lts_current_received_card_bills_v263(p_user_id) b
 WHERE (b.due_date>=current_date OR EXISTS(
 SELECT 1 FROM public.card_invoices open_cycle
 WHERE open_cycle.user_id=p_user_id
 AND open_cycle.status IN('open','projected')
 AND open_cycle.reference_month=b.reference_month
 AND open_cycle.due_date=b.due_date
 AND public.lts_card_family_v226(open_cycle.card_name,open_cycle.card_name)=b.family))
 AND NOT EXISTS(SELECT 1 FROM public.card_invoices i WHERE i.user_id=p_user_id
 AND i.reference_month=b.reference_month
 AND public.lts_card_family_v226(i.card_name,i.card_name)=b.family
 AND (i.status NOT IN('open','projected') OR i.due_date IS DISTINCT FROM b.due_date
 OR (CASE WHEN i.metadata->>'as_of' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 THEN (i.metadata->>'as_of')::date ELSE '-infinity'::date END)
 >(b.source_updated_at AT TIME ZONE 'America/Sao_Paulo')::date))
), current_cycles AS (
 SELECT coalesce(c.family,b.family) family,coalesce(c.month,b.reference_month) AS month,coalesce(b.due_date,c.due_date) due_date,
 coalesce(b.amount,c.amount) amount,CASE WHEN b.invoice_source_id IS NOT NULL
 THEN 'open_finance_invoice_v263' ELSE c.basis END basis,
 CASE WHEN b.invoice_source_id IS NOT NULL THEN t.n ELSE c.item_count END item_count,
 CASE WHEN b.invoice_source_id IS NOT NULL THEN t.unclassified ELSE c.unclassified END unclassified,
 CASE WHEN b.invoice_source_id IS NOT NULL THEN coalesce(t.items,'[]'::jsonb) ELSE c.items END items,
 coalesce(b.source_updated_at,c.observed_at) observed_at,
 c.documentary_amount,c.documentary_as_of,b.invoice_source_id,b.source_updated_at invoice_source_updated_at,
 b.received_at invoice_received_at,b.payment_status,b.reported_payment_amount,
 CASE WHEN b.invoice_source_id IS NOT NULL THEN b.amount-coalesce(t.amount,0) END invoice_composition_difference,
 CASE WHEN b.invoice_source_id IS NOT NULL THEN abs(b.amount-coalesce(t.amount,0))<0.005 END invoice_composition_complete
 FROM cycles0 c FULL JOIN received_bills b ON b.family=c.family AND b.reference_month=c.month
 LEFT JOIN public.lts_open_finance_staging sb ON sb.id=b.invoice_source_id AND sb.user_id=p_user_id
 LEFT JOIN LATERAL (
 SELECT count(*) n,coalesce(sum(br.amount),0) amount,
 count(*) FILTER(WHERE br.category_basis='unresolved') unclassified,
 jsonb_agg((to_jsonb(br)-'bank'-'family'-'card_name'-'billing_last4'-'bill_id')||coalesce((SELECT jsonb_build_object('source_document',jsonb_build_object('file_ref',d.source_file_ref,'sha256',d.source_sha256,'page',d.source_page,'line',d.source_line,'as_of',d.source_as_of,'amount',d.amount))
 FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=p_user_id AND (d.id=br.source_id OR d.id=(SELECT m.document_id FROM public.lts_card_document_matches_v234(p_user_id) m WHERE m.provider_id=br.source_id))),'{}'::jsonb)
 ORDER BY br.posting_date DESC,br.description,br.source_id) items
 FROM rows br WHERE br.family=b.family AND br.reference_month=b.reference_month
 AND br.bill_id=sb.normalized_payload->>'provider_id' AND NOT br.is_payment
 AND br.provider_status IN('POSTED','PENDING','DOCUMENTED')
 AND EXISTS(SELECT 1 FROM public.lts_open_finance_staging tx
 WHERE tx.user_id=p_user_id AND tx.id=br.source_id AND tx.currency='BRL')
 )t ON true
), card_rows as (
 select a.*,coalesce((select jsonb_agg(to_jsonb(c)-'family' order by month) from current_cycles c where c.family=a.family),'[]'::jsonb) cycles from accounts a
)
select jsonb_build_object('version','card-cycles-v226','as_of',current_date,'computed_at',clock_timestamp(),
 'active_billing_accounts',(select count(*) from accounts where status='ACTIVE'),
 'cards',coalesce((select jsonb_agg(to_jsonb(c) order by bank,name) from card_rows c),'[]'::jsonb),
 'financial_effect','none','provider_balance_used_as_invoice',false)
$function$;

CREATE OR REPLACE FUNCTION public.lts_card_invoices_effective_v226(p_user_id uuid)
 RETURNS SETOF card_invoices
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with rows as materialized (
 select * from public.lts_card_source_rows_v226(p_user_id) where not is_payment and provider_status='PENDING' and reference_month>=date_trunc('month',current_date)::date
), composition as materialized (
 select family,reference_month,round(sum(amount),2) amount,max(observed_at) observed_at,
 jsonb_agg(to_jsonb(r)||jsonb_build_object('source_line',source_id,'card_final',last4) order by posting_date,description,source_id) items
 from rows r group by family,reference_month
), effective as materialized (
 select to_jsonb(i)||case when c.items is not null and i.status='open' and i.due_date>=current_date then
 jsonb_build_object('amount',c.amount,'source','open_finance_composition_v226','metadata',coalesce(i.metadata,'{}'::jsonb)||jsonb_build_object(
 'items',c.items,'open_finance_observed_at',c.observed_at,'documentary_snapshot',jsonb_build_object('amount',i.amount,'source',i.source,'as_of',i.metadata->'as_of')))
 else '{}'::jsonb end value
 from public.card_invoices i left join composition c on c.reference_month=i.reference_month
 and c.family=public.lts_card_family_v226(i.card_name,case when i.card_name ~* 'c6' then 'C6' when i.card_name ~* 'aeternum|bradesco|prime' then 'Bradesco' else 'Itaú' end)
 where i.user_id=p_user_id
)
select r.* from effective e
 LEFT JOIN public.lts_card_invoice_amounts_v230(p_user_id) a ON public.lts_card_family_v226(e.value->>'card_name',e.value->>'card_name')='c6'
 AND public.lts_card_family_v226(a.card_name,a.card_name)='c6'
 AND (e.value->>'reference_month')::date=a.reference_month AND (e.value->>'due_date')::date=a.due_date
 AND e.value->>'status' IN('open','projected')
 cross join lateral jsonb_populate_record(null::public.card_invoices,e.value||CASE WHEN a.reference_month IS NOT NULL THEN
 jsonb_build_object('amount',a.amount,'source',a.source) ELSE '{}'::jsonb END)r
$function$;

CREATE OR REPLACE FUNCTION public.lts_browser_card_detail_v226(p_family text, p_month date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare u uuid:=public.lts_browser_assert_user_v1(); result jsonb; alternative jsonb; official record; matched boolean;
begin
 if p_family not in ('aeternum','bradesco_prime','itau_mastercard','itau_visa','c6') or p_month is null then raise exception 'invalid card cycle'; end if;
 with r as materialized(select * from public.lts_card_source_rows_v226(u) where family=p_family and reference_month=date_trunc('month',p_month)::date and not is_payment),
 b as(select s.* from public.lts_open_finance_staging s where s.user_id=u and s.resource_type='invoice' and s.provider_deleted_at is null
 and public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name)=p_family
 and date_trunc('month',s.posting_date)::date=date_trunc('month',p_month)::date),
 d as(select reported_invoice_total,due_date,source_as_of from public.lts_card_document_supplement_v234 where user_id=u and family=p_family and reference_month=date_trunc('month',p_month)::date order by source_as_of desc,created_at desc limit 1),
 t as(select count(*) n,coalesce(sum(amount),0) amount,count(*) filter(where category_basis='unresolved') pending from r)
 select jsonb_build_object('version','card-detail-v226','family',p_family,'month',date_trunc('month',p_month)::date,
 'amount',(select amount from t),'item_count',(select n from t),'unclassified',(select pending from t),
 'invoice_amount',coalesce((select signed_amount from b limit 1),(select reported_invoice_total from d)),'due_date',coalesce((select posting_date from b limit 1),(select due_date from d),(select min(due_date) from r)),
 'difference',coalesce((select signed_amount from b limit 1),(select reported_invoice_total from d))-(select amount from t),
 'basis',case when exists(select 1 from r where provider_status='DOCUMENTED') then 'bank_document_composition' else null end,
 'source_note',case when exists(select 1 from r where provider_status='DOCUMENTED') then 'Composição do banco complementada pelas parcelas comprovadas na fatura parcial.' else null end,
 'items',coalesce((select jsonb_agg(to_jsonb(r)||coalesce((SELECT jsonb_build_object('source_document',jsonb_build_object('file_ref',d.source_file_ref,'sha256',d.source_sha256,'page',d.source_page,'line',d.source_line,'as_of',d.source_as_of,'amount',d.amount)) FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=u AND (d.id=r.source_id OR d.id=(SELECT m.document_id FROM public.lts_card_document_matches_v234(u) m WHERE m.provider_id=r.source_id))),'{}'::jsonb) order by posting_date desc,description,source_id) from r),'[]'::jsonb),
 'financial_effect','none') into result;
 if (result->>'item_count')::int=0 or abs(coalesce((result->>'difference')::numeric,0))>=0.005 then
  select w into alternative from jsonb_array_elements(public.lts_card_workbook_cycles_v226(u)||public.lts_card_document_cycles_v226(u))w
  where w->>'family'=p_family and (w->>'reference_month')::date=date_trunc('month',p_month)::date
  and (result->>'invoice_amount' is null or (w->>'amount')::numeric=(result->>'invoice_amount')::numeric)
  and (result->>'invoice_amount' is null or abs((w->>'difference')::numeric)<abs((result->>'difference')::numeric))
  order by abs((w->>'difference')::numeric),case when w->>'source'='document_reconciled' then 0 else 1 end limit 1;
  if alternative is not null then
   result:=result||alternative||jsonb_build_object('version','card-detail-v226','invoice_amount',(alternative->>'amount')::numeric,
    'due_date',coalesce(result->>'due_date',alternative->>'due_date'),'amount',(alternative->>'detail_total')::numeric,
    'alternative_items',result->'items','alternative_note','Itens também recebidos do banco para esta mesma fatura. São outra fonte de consulta, não despesas adicionais; não somar novamente.',
    'source_note',case when alternative->>'source'='document_reconciled' then 'Composição do documento importado, conferida com o total desta fatura.'
     else 'Composição da planilha por categoria, valor e mês de referência. Estabelecimento e dia da compra não estão informados nessa fonte. A diferença, quando houver, permanece explícita.' end);
  end if;
 end if;
 result:=result||jsonb_build_object(
  'unclassified',(select count(*) from jsonb_array_elements(result->'items')x where x->>'category_basis'='unresolved'),
  'categories',(select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) from (select x->>'category' category,count(*) n,sum((x->>'amount')::numeric) amount from jsonb_array_elements(result->'items')x group by x->>'category')q),
  'instruments',(select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) from (select x->>'last4' last4,count(*) n,sum((x->>'amount')::numeric) amount from jsonb_array_elements(result->'items')x group by x->>'last4')q)
 );

 SELECT ci.amount,ci.due_date,sd.id source_document_id,sd.sha256,sd.storage_path,sd.metadata,
  coalesce((sd.metadata->>'closing_date')::date,(ci.metadata->>'bank_statement_closing_date')::date) closing_date
 INTO official
 FROM public.card_invoices ci JOIN public.source_documents sd
  ON sd.id::text=ci.metadata->>'bank_statement_document_id' AND sd.user_id=ci.user_id
 WHERE ci.user_id=u AND public.lts_card_family_v226(ci.card_name,sd.institution)=p_family
  AND ci.reference_month=date_trunc('month',p_month)::date AND ci.status='closed'
  AND ci.metadata->>'bank_statement_closed'='true'
  AND ci.metadata->>'bank_statement_full_composition'='true'
  AND sd.document_type='credit_card_statement' AND sd.processing_status='processed'
  AND sd.sha256=ci.metadata->>'bank_statement_sha256'
  AND sd.metadata->>'all_source_lines_matched'='true'
  AND (sd.metadata->>'statement_amount')::numeric=ci.amount
  AND (sd.metadata->>'due_date')::date=ci.due_date
 ORDER BY ci.created_at DESC LIMIT 1;
 IF FOUND THEN
  SELECT count(*)=(official.metadata->>'nonpayment_detail_lines')::int
   AND NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(official.metadata->'existing_source_items') e
    WHERE NOT coalesce((e->>'is_payment')::boolean,false)
     AND NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(result->'items') i
      WHERE i->>'source_id'=e->>'source_id'
       AND (i->>'amount')::numeric=(e->>'amount')::numeric
       AND i->>'last4' IS NOT DISTINCT FROM e->>'last4'
       AND i->>'purchase_date' IS NOT DISTINCT FROM e->>'purchase_date'
       AND i->>'installment_number' IS NOT DISTINCT FROM e->>'installment_number'
       AND i->>'total_installments' IS NOT DISTINCT FROM e->>'total_installments'))
  INTO matched FROM jsonb_array_elements(result->'items');
  result:=result||jsonb_build_object(
   'invoice_amount',official.amount,'due_date',official.due_date,
   'difference',official.amount-(result->>'amount')::numeric,
   'basis','bank_document_composition',
   'source_note',CASE WHEN matched AND official.amount=(result->>'amount')::numeric
    THEN 'Fatura oficial fechada em '||to_char(official.closing_date,'DD/MM/YYYY')||'; itens conferidos com o documento e diferença zero.'
    ELSE 'Fatura oficial recebida; a correspondência dos itens ou a diferença requer revisão.' END,
   'document_items_matched',matched,
   'invoice_document',jsonb_build_object('source_document_id',official.source_document_id,
    'file_ref',coalesce(official.metadata->>'library_file_id',official.storage_path),
    'sha256',official.sha256,'pages',official.metadata->'pages',
    'closing_date',official.closing_date,'document_date',official.metadata->'document_date'),
   'financial_effect','none');
 END IF;

 return result;
end
$function$;

-- Install together with the authorized private source import and its transaction-level assertions.
ROLLBACK;
