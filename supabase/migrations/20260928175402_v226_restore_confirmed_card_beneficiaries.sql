-- V226: source-backed card composition. No ledger, bank-balance or invoice writes.
CREATE OR REPLACE FUNCTION public.lts_card_family_v226(p_name text, p_bank text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
select case when n like '%aeternum%' then 'aeternum'
 when n like '%c6%' or n like '%bandeirado%' then 'c6'
 when n like '%visa%' and b like '%itau%' then 'itau_visa'
 when n like '%visa%' and b like '%bradesco%' then 'bradesco_prime'
 when n like '%mastercard%' or n like '%mc black%' or n like '%personnalite%' then 'itau_mastercard'
 end from (select public.lts_v178_norm(p_name) n,public.lts_v178_norm(p_bank) b)x
$f$;

CREATE OR REPLACE FUNCTION public.lts_card_merchant_key_v226(p_name text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 select regexp_replace(regexp_replace(public.lts_v178_norm(case when p_name ~ '[[:space:]]{2,}BRA$' then left(p_name,21) else p_name end),'[[:space:]]*[0-9]{1,2}/[0-9]{1,2}$','','g'),'[^a-z0-9]','','g')
$f$;

CREATE OR REPLACE FUNCTION public.lts_card_source_rows_v226(p_user_id uuid)
RETURNS TABLE(source_id uuid,bank text,family text,card_name text,last4 text,billing_last4 text,
 posting_date date,purchase_date date,reference_month date,due_date date,provider_status text,
 amount numeric,description text,category text,category_basis text,installment_number integer,
 total_installments integer,is_payment boolean,bill_id text,observed_at timestamptz)
LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
with evidence as materialized (
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
 from evidence where public.lts_v178_norm(category) not in ('','a classificar','nao identificado','sem categoria','—')
 group by k,amount
), nature_categories as materialized (
 select k,case when count(distinct regexp_replace(category,'^(Lucas|Larissa|Benjamin)[[:space:]]*[-—][[:space:]]*','','i'))=1
 then min(regexp_replace(category,'^(Lucas|Larissa|Benjamin)[[:space:]]*[-—][[:space:]]*','','i')) end category
 from evidence where public.lts_v178_norm(category) not in ('','a classificar','nao identificado','sem categoria','—')
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
 s.raw_payload#>>'{creditCardMetadata,billId}' raw_bill_id,
 case when s.raw_payload#>>'{creditCardMetadata,billForecastDate}' ~ '^[0-9]{4}-[0-9]{2}$'
 then (s.raw_payload#>>'{creditCardMetadata,billForecastDate}'||'-01')::date end forecast,
 (coalesce(s.raw_payload->>'operationType','')='PAGAMENTO_FATURA'
 or coalesce(s.raw_payload->>'category','')='Credit card payment'
 or public.lts_v178_norm(s.description_raw) ~ '^(inclusao de pagamento ciclo corrente|pagamento recebido|pagto fatura)') payment
 from public.lts_open_finance_staging s where s.user_id=p_user_id and s.resource_type='card_transaction'
 and s.provider_deleted_at is null
), dated as materialized (
 select s.*,b.posting_date bill_due,
 case when b.id is not null then date_trunc('month',b.posting_date)::date
 -- C6 reports the purchase month for its current open cycle. The document supplies the due month.
 when s.institution_code='336' and s.normalized_payload->>'status'='PENDING'
 and s.forecast<=date_trunc('month',current_date)::date then coalesce(c.reference_month,s.forecast)
 else s.forecast end cycle,
 c.due_date open_due
 from src s left join public.lts_open_finance_staging b on b.user_id=s.user_id
 and b.institution_code=s.institution_code and b.resource_type='invoice'
 and b.normalized_payload->>'provider_id'=s.raw_bill_id
 left join lateral (select i.reference_month,i.due_date from public.card_invoices i
 where i.user_id=p_user_id and i.status='open' and i.due_date>=current_date
 and public.lts_card_family_v226(i.card_name,s.bank)=s.family order by i.due_date limit 1)c on true
), classified as (
 select s.*,coalesce(d.category_label,ec.category,sr.category,nc.category) known_category,coalesce(d.beneficiary,ec.person,sr.person) known_person,
 case when d.category_label is not null then case when d.decision_basis like 'workbook_restore_v226%' then 'historical_workbook' else 'user_decision' end
 when ec.category is not null then 'same_merchant_and_amount'
 when sr.category is not null then 'restored_explicit_rule'
 when nc.category is not null then 'historical_merchant_nature' end known_basis
 from dated s left join exact_categories ec on ec.k=s.merchant_key and ec.amount=round(-s.signed_amount,2)
 left join nature_categories nc on nc.k=s.merchant_key
 left join rule_categories sr on sr.k=s.merchant_key
 left join public.lts_v178_review_decision d on d.user_id=p_user_id and d.source_table='lts_open_finance_staging' and d.source_ref=s.id::text
)
select s.id,s.bank,s.family,s.normalized_payload->>'card_name',
 coalesce(nullif(s.raw_payload#>>'{creditCardMetadata,cardNumber}',''),s.normalized_payload->>'last4'),
 s.normalized_payload->>'last4',s.posting_date,
 case when s.raw_payload#>>'{creditCardMetadata,purchaseDate}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
 then left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10)::date else s.posting_date end,
 s.cycle,coalesce(s.bill_due,case when date_trunc('month',s.open_due)::date=s.cycle then s.open_due end),
 s.normalized_payload->>'status',-s.signed_amount,s.description_raw,
 coalesce(case when s.known_person in ('Lucas','Larissa','Benjamin') and s.known_category is not null and s.known_category !~* '^(Lucas|Larissa|Benjamin)' then s.known_person||' — '||s.known_category else s.known_category end,case
 when s.raw_payload->>'category' in ('Credit card fees','Bank fees') then 'Tarifas bancárias'
 when s.raw_payload->>'category'='Tax on financial operations' then 'IOF'
 when s.merchant_key ~ '^(ifd|ifood)' and s.raw_payload->>'category' in ('Food delivery','Restaurants','Eating out') then 'Ifood'
 when s.raw_payload->>'category'='Pharmacy' and s.merchant_key ~ 'drog|pharma|farma' then 'Farmácia'
 when s.raw_payload->>'category'='Groceries' and s.merchant_key ~ 'paodeacucar|obahortifruti|supermercado' then 'Mercado'
 when s.raw_payload->>'category'='Restaurants' and s.merchant_key ~ 'restaur|bbq|heladeria|santograo' then 'Restaurantes'
 when s.raw_payload->>'category'='Gas stations' and s.merchant_key ~ 'posto' then 'Combustível'
 else 'A classificar' end),
 coalesce(s.known_basis,case when s.raw_payload->>'category' in ('Credit card fees','Bank fees','Tax on financial operations') then 'explicit_fee_type'
 when (s.merchant_key ~ '^(ifd|ifood)' and s.raw_payload->>'category' in ('Food delivery','Restaurants','Eating out'))
 or (s.raw_payload->>'category'='Pharmacy' and s.merchant_key ~ 'drog|pharma|farma')
 or (s.raw_payload->>'category'='Groceries' and s.merchant_key ~ 'paodeacucar|obahortifruti|supermercado')
 or (s.raw_payload->>'category'='Restaurants' and s.merchant_key ~ 'restaur|bbq|heladeria|santograo')
 or (s.raw_payload->>'category'='Gas stations' and s.merchant_key ~ 'posto') then 'merchant_and_provider_category' else 'unresolved' end),
 case when s.raw_payload#>>'{creditCardMetadata,installmentNumber}' ~ '^[0-9]+$' then (s.raw_payload#>>'{creditCardMetadata,installmentNumber}')::integer end,
 case when s.raw_payload#>>'{creditCardMetadata,totalInstallments}' ~ '^[0-9]+$' then (s.raw_payload#>>'{creditCardMetadata,totalInstallments}')::integer end,
 s.payment,s.raw_bill_id,s.last_seen_at
from classified s
$f$;

