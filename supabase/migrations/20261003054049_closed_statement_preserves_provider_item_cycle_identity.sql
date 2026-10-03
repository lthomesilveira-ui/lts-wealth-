CREATE OR REPLACE FUNCTION public.lts_card_source_rows_v226(p_user_id uuid)
 RETURNS TABLE(source_id uuid, bank text, family text, card_name text, last4 text, billing_last4 text, posting_date date, purchase_date date, reference_month date, due_date date, provider_status text, amount numeric, description text, category text, category_basis text, installment_number integer, total_installments integer, is_payment boolean, bill_id text, observed_at timestamp with time zone)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH provider_rows(source_id,bank,family,card_name,last4,billing_last4,posting_date,purchase_date,reference_month,due_date,provider_status,amount,description,category,category_basis,installment_number,total_installments,is_payment,bill_id,observed_at) AS MATERIALIZED (
with installment_decisions as materialized (
 select public.lts_card_installment_key_v231(s) purchase_key,
 case when count(distinct d.category_label)=1 and count(distinct d.beneficiary)<=1 then min(d.category_label) end category,
 case when count(distinct d.category_label)=1 and count(distinct d.beneficiary)=1 then min(d.beneficiary) end person
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
 select k,amount,case when count(distinct category)=1 then min(category) end category,case when count(distinct person)=1 then min(person) end person
 from evidence where pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') not in ('','a classificar','nao identificado','sem categoria','—')
 group by k,amount
), nature_categories as materialized (
 select k,case when count(distinct regexp_replace(category,'^(Lucas|Larissa|Benjamin)[[:space:]]*[-—][[:space:]]*','','i'))=1
 then min(regexp_replace(category,'^(Lucas|Larissa|Benjamin)[[:space:]]*[-—][[:space:]]*','','i')) end category
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
 select s.*,coalesce(dc.due_date,b.posting_date) bill_due,
 case when dc.source_id is not null then dc.reference_month
 when b.id is not null then date_trunc('month',b.posting_date)::date
 -- C6 reports the purchase month for its current open cycle. The document supplies the due month.
 when s.institution_code='336' and s.normalized_payload->>'status'='PENDING'
 and s.forecast<=date_trunc('month',current_date)::date then coalesce(c.reference_month,s.forecast)
 else s.forecast end cycle,
 c.due_date open_due
 from src s left join documented_cycles dc on dc.source_id=s.id
 left join public.lts_open_finance_staging b on b.user_id=s.user_id
 and b.institution_code=s.institution_code and b.resource_type='invoice'
 and b.normalized_payload->>'provider_id'=s.raw_bill_id
 left join open_cards c on c.family=s.family
), classified as (
 select s.*,coalesce(d.category_label,ic.category,ec.category,sr.category,nc.category) known_category,coalesce(d.beneficiary,ic.person,ec.person,sr.person) known_person,
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
 coalesce(case when s.known_person in ('Lucas','Larissa','Benjamin') and s.known_category is not null and s.known_category !~* '^(Lucas|Larissa|Benjamin)' then s.known_person||' — '||s.known_category else s.known_category end,s.provider_category,'A classificar'),
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

$function$
;

CREATE OR REPLACE FUNCTION public.lts_dashboard_source_key_v240(p_user_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
SELECT md5(jsonb_build_object(
 'revision','canonical-cache-v249-closed-source-identity','date',current_date,
 'operational',public.lts_operational_source_key_v238(p_user_id),
 'fact_confirmations',(select md5(coalesce(string_agg(to_jsonb(f)::text,'|' order by id),'empty')) from public.lts_fact_confirmation f where user_id=p_user_id),
 'bank',public.lts_open_finance_checking_positions_v1(p_user_id),
 'staging',(select md5(coalesce(string_agg(jsonb_build_array(id,resource_type,raw_hash,normalized_payload,posting_date,signed_amount,provider_deleted_at)::text,'|' order by id),'empty')) from public.lts_open_finance_staging where user_id=p_user_id),
 'decisions',(select md5(coalesce(string_agg(to_jsonb(d)::text,'|' order by source_table,source_ref),'empty')) from public.lts_v178_review_decision d where user_id=p_user_id),
 'assets',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.asset_positions a where user_id=p_user_id),
 'movements',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.lts_liquidity_movement a where user_id=p_user_id),
 'schedule',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.lts_future_liquidity_schedule a where user_id=p_user_id),
 'brokerage',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.lts_brokerage_position_snapshots a where user_id=p_user_id),
 'invoices',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.card_invoices a where user_id=p_user_id),
 'closed_statement_documents',(select md5(coalesce(string_agg(to_jsonb(d)::text,'|' order by d.id),'empty')) from public.source_documents d
  where d.user_id=p_user_id and exists(select 1 from public.card_invoices ci where ci.user_id=p_user_id and ci.metadata->>'bank_statement_document_id'=d.id::text)),
 'locks',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by lock_key),'empty')) from public.lts_validated_lock_registry a where superseded_at is null)
)::text)
$function$
;
