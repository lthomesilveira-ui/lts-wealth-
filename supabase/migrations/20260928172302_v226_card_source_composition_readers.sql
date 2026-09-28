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
 select regexp_replace(regexp_replace(public.lts_v178_norm(p_name),'[[:space:]]*[0-9]{1,2}/[0-9]{1,2}$','','g'),'[^a-z0-9]','','g')
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
 p.invoice_due_date evidence_date
 from public.lts_card_purchase_detail p left join public.lts_v178_review_decision d
 on d.user_id=p.user_id and d.source_table='card_purchase_detail' and d.source_ref=p.line_key
 where p.user_id=p_user_id
), exact_categories as materialized (
 select k,amount,case when count(distinct category)=1 then min(category) end category
 from evidence where public.lts_v178_norm(category) not in ('','a classificar','nao identificado','sem categoria','—')
 group by k,amount
), nature_categories as materialized (
 select k,case when count(distinct regexp_replace(category,'^(Lucas|Larissa|Benjamin)[[:space:]]*[-—][[:space:]]*','','i'))=1
 then min(regexp_replace(category,'^(Lucas|Larissa|Benjamin)[[:space:]]*[-—][[:space:]]*','','i')) end category
 from evidence where public.lts_v178_norm(category) not in ('','a classificar','nao identificado','sem categoria','—')
 and k !~ 'mercado|amazon|shop|pagseguro|merpago' group by k
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
 select s.*,coalesce(d.category_label,ec.category,nc.category) known_category,
 case when d.category_label is not null then 'user_decision'
 when ec.category is not null then 'same_merchant_and_amount'
 when nc.category is not null then 'historical_merchant_nature' end known_basis
 from dated s left join exact_categories ec on ec.k=s.merchant_key and ec.amount=round(-s.signed_amount,2)
 left join nature_categories nc on nc.k=s.merchant_key
 left join public.lts_v178_review_decision d on d.user_id=p_user_id and d.source_table='lts_open_finance_staging' and d.source_ref=s.id::text
)
select s.id,s.bank,s.family,s.normalized_payload->>'card_name',
 coalesce(nullif(s.raw_payload#>>'{creditCardMetadata,cardNumber}',''),s.normalized_payload->>'last4'),
 s.normalized_payload->>'last4',s.posting_date,
 case when s.raw_payload#>>'{creditCardMetadata,purchaseDate}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
 then left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10)::date else s.posting_date end,
 s.cycle,coalesce(s.bill_due,case when date_trunc('month',s.open_due)::date=s.cycle then s.open_due end),
 s.normalized_payload->>'status',-s.signed_amount,s.description_raw,
 coalesce(s.known_category,case
 when s.raw_payload->>'category' in ('Credit card fees','Bank fees') then 'Tarifas bancárias'
 when s.raw_payload->>'category'='Tax on financial operations' then 'IOF'
 else 'A classificar' end),
 coalesce(s.known_basis,case when s.raw_payload->>'category' in ('Credit card fees','Bank fees','Tax on financial operations') then 'explicit_fee_type' else 'unresolved' end),
 case when s.raw_payload#>>'{creditCardMetadata,installmentNumber}' ~ '^[0-9]+$' then (s.raw_payload#>>'{creditCardMetadata,installmentNumber}')::integer end,
 case when s.raw_payload#>>'{creditCardMetadata,totalInstallments}' ~ '^[0-9]+$' then (s.raw_payload#>>'{creditCardMetadata,totalInstallments}')::integer end,
 s.payment,s.raw_bill_id,s.last_seen_at
from classified s
$f$;

CREATE OR REPLACE FUNCTION public.lts_card_cycles_v226(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
with rows as materialized (select * from public.lts_card_source_rows_v226(p_user_id)),
accounts as materialized (
 select s.institution_name bank,public.lts_card_family_v226(s.normalized_payload->>'name',s.institution_name) family,
 s.normalized_payload->>'name' name,s.normalized_payload->>'last4' last4,
 s.raw_payload#>>'{creditData,status}' status,s.raw_payload#>'{creditData,additionalCards}' additional_cards,
 nullif(s.normalized_payload->>'due_date','')::date last_due,s.last_seen_at observed_at
 from public.lts_open_finance_staging s where s.user_id=p_user_id and s.resource_type='credit_card'
 and s.provider_deleted_at is null
), pending as materialized (
 select family,reference_month,min(due_date) due_date,count(*) n,round(sum(amount),2) amount,
 count(*) filter(where category_basis='unresolved') unclassified,
 max(observed_at) observed_at,
 jsonb_agg(to_jsonb(r)-'bank'-'family'-'card_name'-'billing_last4'-'bill_id' order by posting_date desc,description,source_id) items
 from rows r where not is_payment and provider_status='PENDING' and reference_month>=date_trunc('month',current_date)::date
 group by family,reference_month
), docs as materialized (
 select i.*,public.lts_card_family_v226(i.card_name,case when i.card_name ~* 'c6' then 'C6' when i.card_name ~* 'aeternum|bradesco|prime' then 'Bradesco' else 'Itaú' end) family
 from public.card_invoices i where i.user_id=p_user_id and i.due_date>=current_date
), cycles as (
 select coalesce(p.family,d.family) family,coalesce(p.reference_month,d.reference_month) AS month,
 coalesce(p.due_date,d.due_date) due_date,coalesce(p.amount,d.amount) amount,
 case when p.n>0 then 'open_finance_composition' when d.source='derived_installments' then 'contracted_installments' else 'documented_snapshot' end basis,
 coalesce(p.n,0) item_count,coalesce(p.unclassified,0) unclassified,
 coalesce(p.items,'[]'::jsonb) items,p.observed_at,d.amount documentary_amount,
 case when d.metadata->>'as_of' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then d.metadata->>'as_of' end documentary_as_of
 from pending p full join docs d on d.family=p.family and d.reference_month=p.reference_month
), card_rows as (
 select a.*,coalesce((select jsonb_agg(to_jsonb(c)-'family' order by month) from cycles c where c.family=a.family),'[]'::jsonb) cycles
 from accounts a
)
select jsonb_build_object('version','card-cycles-v226','as_of',current_date,'computed_at',clock_timestamp(),
 'active_billing_accounts',(select count(*) from accounts where status='ACTIVE'),
 'cards',coalesce((select jsonb_agg(to_jsonb(c) order by bank,name) from card_rows c),'[]'::jsonb),
 'financial_effect','none','provider_balance_used_as_invoice',false)
$f$;

CREATE OR REPLACE FUNCTION public.lts_browser_card_cycles_v226()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
declare u uuid:=public.lts_browser_assert_user_v1(); begin return public.lts_card_cycles_v226(u); end
$f$;

REVOKE ALL ON FUNCTION public.lts_card_source_rows_v226(uuid),public.lts_card_cycles_v226(uuid),public.lts_browser_card_cycles_v226() FROM public,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_card_cycles_v226() TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.lts_card_source_rows_v226(uuid),public.lts_card_cycles_v226(uuid) TO service_role;
