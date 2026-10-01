-- Documented purchases supplement an incomplete provider cycle; never create a fake provider transaction.
CREATE TABLE public.lts_card_document_supplement_v234 (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL,
 institution_code text NOT NULL,
 bank text NOT NULL,
 family text NOT NULL CHECK (family IN ('aeternum','bradesco_prime','itau_mastercard','itau_visa','c6')),
 card_name text NOT NULL,
 provider_account_ref text NOT NULL,
 billing_last4 text NOT NULL CHECK (billing_last4 ~ '^[0-9]{4}$'),
 last4 text NOT NULL CHECK (last4 ~ '^[0-9]{4}$'),
 reference_month date NOT NULL,
 due_date date NOT NULL,
 purchase_date date NOT NULL,
 amount numeric(18,2) NOT NULL CHECK (amount>0),
 description text NOT NULL,
 installment_number integer NOT NULL CHECK (installment_number>0),
 total_installments integer NOT NULL CHECK (total_installments>=installment_number AND total_installments<=120),
 category text,
 source_as_of timestamptz NOT NULL,
 source_file_ref text NOT NULL,
 source_sha256 text NOT NULL CHECK (source_sha256 ~ '^[0-9a-f]{64}$'),
 source_page integer NOT NULL CHECK (source_page>0),
 source_line integer NOT NULL CHECK (source_line>0),
 reported_invoice_total numeric(18,2) NOT NULL,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(user_id,source_sha256,source_line),
 CHECK (date_trunc('month',due_date)::date=reference_month)
);
ALTER TABLE public.lts_card_document_supplement_v234 ENABLE ROW LEVEL SECURITY;
CREATE POLICY lts_card_document_supplement_v234_service ON public.lts_card_document_supplement_v234 TO service_role USING (true) WITH CHECK (true);
REVOKE ALL ON public.lts_card_document_supplement_v234 FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.lts_card_document_supplement_v234 TO service_role;
CREATE INDEX lts_card_document_supplement_v234_scope ON public.lts_card_document_supplement_v234(user_id,family,reference_month);
COMMENT ON TABLE public.lts_card_document_supplement_v234 IS 'Immutable source lines from a supplied bank statement, including file hash/page/line. Decisions remain separate. No inferred provider rows or cash payments.';

CREATE FUNCTION public.lts_card_document_matches_v234(p_user_id uuid)
RETURNS TABLE(document_id uuid,provider_id uuid)
LANGUAGE sql STABLE SET search_path='' AS $f$
 WITH documents AS MATERIALIZED (
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
  AND (s.raw_payload#>>'{creditCardMetadata,billForecastDate}'=to_char(d.reference_month,'YYYY-MM')
   OR EXISTS(SELECT 1 FROM public.lts_open_finance_staging b
    WHERE b.user_id=s.user_id AND b.institution_code=s.institution_code AND b.resource_type='invoice'
    AND b.provider_deleted_at IS NULL AND b.normalized_payload->>'provider_id'=s.raw_payload#>>'{creditCardMetadata,billId}'
    AND date_trunc('month',b.posting_date)::date=d.reference_month))
 ), unique_candidates AS (
  SELECT *,count(*) OVER(PARTITION BY document_id) dc,count(*) OVER(PARTITION BY provider_id) pc FROM candidates
 )
 SELECT document_id,provider_id FROM unique_candidates WHERE dc=1 AND pc=1
$f$;
REVOKE ALL ON FUNCTION public.lts_card_document_matches_v234(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_document_matches_v234(uuid) TO service_role;

CREATE FUNCTION public.lts_card_document_rows_v234(p_user_id uuid)
RETURNS TABLE(source_id uuid, bank text, family text, card_name text, last4 text, billing_last4 text, posting_date date, purchase_date date, reference_month date, due_date date, provider_status text, amount numeric, description text, category text, category_basis text, installment_number integer, total_installments integer, is_payment boolean, bill_id text, observed_at timestamp with time zone)
LANGUAGE sql STABLE SET search_path='' SET TimeZone='America/Sao_Paulo' AS $f$
 SELECT p.id,p.bank,p.family,p.card_name,p.last4,p.billing_last4,p.source_as_of::date,p.purchase_date,
 p.reference_month,p.due_date,'DOCUMENTED'::text,p.amount,p.description,
 coalesce(CASE WHEN d.category_label IS NOT NULL AND d.beneficiary IN ('Larissa','Benjamin','Rafiki')
  THEN d.beneficiary||' — '||d.category_label ELSE d.category_label END,p.category,'A classificar'),
 CASE WHEN d.category_label IS NOT NULL THEN 'user_decision_document'
  WHEN p.category IS NOT NULL THEN 'same_documented_purchase' ELSE 'unresolved' END,
 p.installment_number,p.total_installments,false,NULL::text,p.source_as_of
 FROM public.lts_card_document_supplement_v234 p
 LEFT JOIN public.lts_v178_review_decision d ON d.user_id=p.user_id
  AND d.source_table='lts_card_document_supplement_v234' AND d.source_ref=p.id::text
 WHERE p.user_id=p_user_id AND NOT EXISTS(
  SELECT 1 FROM public.lts_card_document_matches_v234(p_user_id) m WHERE m.document_id=p.id)
$f$;
REVOKE ALL ON FUNCTION public.lts_card_document_rows_v234(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_document_rows_v234(uuid) TO service_role;

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
 case when s.raw_payload#>>'{creditCardMetadata,purchaseDate}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
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

$function$;

CREATE OR REPLACE FUNCTION public.lts_card_cycles_v226(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with rows as materialized (select * from public.lts_card_source_rows_v226(p_user_id)),
accounts as materialized (
 select s.institution_name bank,public.lts_card_family_v226(s.normalized_payload->>'name',s.institution_name) family,
 s.normalized_payload->>'name' name,s.normalized_payload->>'last4' last4,
 s.raw_payload#>>'{creditData,status}' status,s.raw_payload#>'{creditData,additionalCards}' additional_cards,
 nullif(s.normalized_payload->>'due_date','')::date last_due,s.last_seen_at observed_at
 from public.lts_open_finance_staging s where s.user_id=p_user_id and s.resource_type='credit_card' and s.provider_deleted_at is null
), pending as materialized (
 select family,reference_month,min(due_date) due_date,count(*) n,round(sum(amount),2) amount,
 count(*) filter(where category_basis='unresolved') unclassified,max(observed_at) observed_at,
 jsonb_agg(to_jsonb(r)-'bank'-'family'-'card_name'-'billing_last4'-'bill_id' order by posting_date desc,description,source_id) items
 from rows r where not is_payment and provider_status IN ('PENDING','DOCUMENTED') and reference_month>=date_trunc('month',current_date)::date group by family,reference_month
), first_cycles as materialized (select family,min(reference_month) AS month from pending group by family),
installments as materialized (
 select r.family,(r.reference_month+make_interval(months=>n))::date reference_month,r.amount,r.category_basis,r.observed_at,
 to_jsonb(r)||jsonb_build_object('reference_month',(r.reference_month+make_interval(months=>n))::date,'installment_number',r.installment_number+n,'provider_status','PROJECTED','projection_basis','remaining_installments_of_received_purchase') item
 from rows r join first_cycles f on f.family=r.family and f.month=r.reference_month
 cross join lateral generate_series(1,least(120,r.total_installments-r.installment_number)) n
 where not r.is_payment and r.provider_status IN ('PENDING','DOCUMENTED') and r.amount>0 and r.installment_number>0 and r.total_installments>r.installment_number
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
), card_rows as (
 select a.*,coalesce((select jsonb_agg(to_jsonb(c)-'family' order by month) from cycles0 c where c.family=a.family),'[]'::jsonb) cycles from accounts a
)
select jsonb_build_object('version','card-cycles-v226','as_of',current_date,'computed_at',clock_timestamp(),
 'active_billing_accounts',(select count(*) from accounts where status='ACTIVE'),
 'cards',coalesce((select jsonb_agg(to_jsonb(c) order by bank,name) from card_rows c),'[]'::jsonb),
 'financial_effect','none','provider_balance_used_as_invoice',false)
$function$;

CREATE OR REPLACE FUNCTION public.lts_card_invoice_amounts_v230(p_user_id uuid)
 RETURNS TABLE(user_id uuid, card_name text, reference_month date, due_date date, status text, amount numeric, source text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH base(user_id,card_name,reference_month,due_date,status,amount,source) AS MATERIALIZED (
WITH src AS MATERIALIZED (
 SELECT s.user_id,s.institution_code,s.signed_amount,
 public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) family,
 s.raw_payload#>>'{creditCardMetadata,billId}' raw_bill_id,
 CASE WHEN s.raw_payload#>>'{creditCardMetadata,billForecastDate}' ~ '^[0-9]{4}-[0-9]{2}$'
 THEN (s.raw_payload#>>'{creditCardMetadata,billForecastDate}'||'-01')::date END forecast
 FROM public.lts_open_finance_staging s
 WHERE s.user_id=p_user_id AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL
 AND s.normalized_payload->>'status'='PENDING'
 AND NOT (coalesce(s.raw_payload->>'operationType','')='PAGAMENTO_FATURA'
 OR coalesce(s.raw_payload->>'category','')='Credit card payment'
 OR public.lts_v178_norm(s.description_raw) ~ '^(inclusao de pagamento ciclo corrente|pagamento recebido|pagto fatura)')
), open_cards AS MATERIALIZED (
 SELECT DISTINCT ON (family) family,reference_month,due_date FROM (
 SELECT public.lts_card_family_v226(i.card_name,CASE WHEN i.card_name ~* 'c6' THEN 'C6'
 WHEN i.card_name ~* 'aeternum|bradesco|prime' THEN 'Bradesco' ELSE 'Itaú' END) family,
 i.reference_month,i.due_date FROM public.card_invoices i
 WHERE i.user_id=p_user_id AND i.status='open' AND i.due_date>=current_date
 ) q ORDER BY family,due_date
), dated AS MATERIALIZED (
 SELECT s.family,-s.signed_amount amount,
 CASE WHEN b.id IS NOT NULL THEN date_trunc('month',b.posting_date)::date
 WHEN s.institution_code='336' AND s.forecast<=date_trunc('month',current_date)::date
 THEN coalesce(c.reference_month,s.forecast) ELSE s.forecast END reference_month
 FROM src s LEFT JOIN public.lts_open_finance_staging b ON b.user_id=s.user_id
 AND b.institution_code=s.institution_code AND b.resource_type='invoice'
 AND b.normalized_payload->>'provider_id'=s.raw_bill_id
 LEFT JOIN open_cards c ON c.family=s.family
), composition AS MATERIALIZED (
 SELECT family,reference_month,round(sum(amount),2) amount
 FROM dated WHERE reference_month>=date_trunc('month',current_date)::date
 GROUP BY family,reference_month
)
SELECT i.user_id,i.card_name,i.reference_month,i.due_date,i.status,
CASE WHEN c.family IS NOT NULL AND i.status='open' AND i.due_date>=current_date THEN c.amount ELSE i.amount END,
CASE WHEN c.family IS NOT NULL AND i.status='open' AND i.due_date>=current_date THEN 'open_finance_composition_v226' ELSE i.source END
FROM public.card_invoices i LEFT JOIN composition c ON c.reference_month=i.reference_month
AND c.family=public.lts_card_family_v226(i.card_name,CASE WHEN i.card_name ~* 'c6' THEN 'C6'
WHEN i.card_name ~* 'aeternum|bradesco|prime' THEN 'Bradesco' ELSE 'Itaú' END)
WHERE i.user_id=p_user_id
), documented_families AS MATERIALIZED (
 SELECT DISTINCT family FROM public.lts_card_document_supplement_v234 WHERE user_id=p_user_id
), reconciled AS MATERIALIZED (
 SELECT c->>'family' family,c->>'name' card_name,c->>'last_due' last_due,
 (x->>'month')::date reference_month,(x->>'due_date')::date due_date,(x->>'amount')::numeric amount,x->>'basis' basis
 FROM jsonb_array_elements(public.lts_card_cycles_v226(p_user_id)->'cards') c
 CROSS JOIN LATERAL jsonb_array_elements(c->'cycles') x
 WHERE c->>'family' IN(SELECT family FROM documented_families)
), dated AS MATERIALIZED (
 SELECT r.*,coalesce(r.due_date,make_date(extract(year FROM r.reference_month)::int,extract(month FROM r.reference_month)::int,
  least(extract(day FROM r.last_due::date)::int,extract(day FROM (r.reference_month+interval '1 month -1 day'))::int))) projected_due FROM reconciled r
)
SELECT b.user_id,b.card_name,b.reference_month,b.due_date,b.status,
 CASE WHEN r.family IS NOT NULL AND b.status='open' AND b.due_date>=current_date THEN r.amount ELSE b.amount END,
 CASE WHEN r.family IS NOT NULL AND b.status='open' AND b.due_date>=current_date THEN
  CASE WHEN r.basis='bank_document_composition' THEN 'bank_document_composition_v234'
   WHEN r.basis IN ('derived_current_installments','documented_floor_partial_detail') THEN 'derived_installments_v234' ELSE 'open_finance_composition_v226' END
 ELSE b.source END
FROM base b LEFT JOIN dated r ON r.reference_month=b.reference_month
 AND r.family=public.lts_card_family_v226(b.card_name,CASE WHEN b.card_name ~* 'c6' THEN 'C6' WHEN b.card_name ~* 'aeternum|bradesco|prime' THEN 'Bradesco' ELSE 'Itaú' END)
UNION ALL
SELECT p_user_id,r.card_name,r.reference_month,r.projected_due,'open',r.amount,'derived_installments_v234'
FROM dated r WHERE r.reference_month>=date_trunc('month',current_date)::date AND r.projected_due IS NOT NULL
AND NOT EXISTS(SELECT 1 FROM base b WHERE b.reference_month=r.reference_month
 AND public.lts_card_family_v226(b.card_name,b.card_name)=r.family)

$function$;

CREATE OR REPLACE FUNCTION public.lts_browser_card_cycles_v229()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); j jsonb; cards jsonb;
BEGIN
 j:=public.lts_browser_card_cycles_v226();
 WITH source_dates AS MATERIALIZED (
 SELECT public.lts_card_family_v226(s.normalized_payload->>'name',s.institution_name) family,
 max(coalesce(nullif(s.normalized_payload->>'as_of',''),nullif(s.normalized_payload->>'provider_updated_at',''),nullif(s.raw_payload->>'updatedAt',''))::timestamptz) source_updated_at,
 max(s.last_seen_at) received_at
 FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.resource_type='credit_card' AND s.provider_deleted_at IS NULL GROUP BY 1
 ) SELECT jsonb_agg(c||jsonb_build_object('source_updated_at',sd.source_updated_at,'received_at',sd.received_at,'source_time_basis','provider_resource_update')||jsonb_build_object('document_source_as_of',doc.as_of,'document_source_file',doc.source_file,'documented_supplement_items',doc.n)||CASE WHEN coalesce(jsonb_array_length(c->'cycles'),0)=0 AND hint.amount IS NOT NULL THEN jsonb_build_object(
 'cycles',jsonb_build_array(jsonb_build_object('month',(date_trunc('month',current_date)+interval '1 month')::date,'due_date',null,
 'amount',hint.amount,'basis','user_confirmed_recurring_estimate','items',hint.items))) ELSE '{}'::jsonb END ORDER BY ord) INTO cards
 FROM jsonb_array_elements(j->'cards') WITH ORDINALITY src(c,ord)
 LEFT JOIN source_dates sd ON sd.family=c->>'family'
 LEFT JOIN LATERAL(SELECT max(d.source_as_of) as_of,min(d.source_file_ref) source_file,count(*) n
 FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=u AND d.family=c->>'family'
 AND d.reference_month=date_trunc('month',current_date)::date) doc ON true
 LEFT JOIN LATERAL(SELECT sum(h.amount) amount,jsonb_agg(jsonb_build_object('description',h.description,'amount',h.amount,'last4',c->>'last4','category',h.category,'category_basis','user_confirmed_recurring_estimate')) items
 FROM public.lts_v229_card_recurring_commitment h WHERE h.user_id=u AND h.active AND h.family=c->>'family') hint ON true;
 RETURN j||jsonb_build_object('cards',cards,'recurring_estimates_separate',true);
END $function$;

CREATE OR REPLACE FUNCTION public.lts_browser_card_detail_v226(p_family text, p_month date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare u uuid:=public.lts_browser_assert_user_v1(); result jsonb; alternative jsonb;
begin
 if p_family not in ('aeternum','bradesco_prime','itau_mastercard','itau_visa','c6') or p_month is null then raise exception 'invalid card cycle'; end if;
 with r as materialized(select * from public.lts_card_source_rows_v226(u) where family=p_family and reference_month=date_trunc('month',p_month)::date and not is_payment),
 b as(select s.* from public.lts_open_finance_staging s where s.user_id=u and s.resource_type='invoice' and s.provider_deleted_at is null
 and public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name)=p_family
 and date_trunc('month',s.posting_date)::date=date_trunc('month',p_month)::date),
 t as(select count(*) n,coalesce(sum(amount),0) amount,count(*) filter(where category_basis='unresolved') pending from r)
 select jsonb_build_object('version','card-detail-v226','family',p_family,'month',date_trunc('month',p_month)::date,
 'amount',(select amount from t),'item_count',(select n from t),'unclassified',(select pending from t),
 'invoice_amount',(select signed_amount from b limit 1),'due_date',coalesce((select posting_date from b limit 1),(select min(due_date) from r)),
 'difference',(select signed_amount from b limit 1)-(select amount from t),
 'items',coalesce((select jsonb_agg(to_jsonb(r) order by posting_date desc,description,source_id) from r),'[]'::jsonb),
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
 return result;
end
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
FROM cards c LEFT JOIN public.lts_card_document_supplement_v234 doc ON doc.user_id=p_user_id AND doc.id=c.source_id WHERE NOT EXISTS(SELECT 1 FROM expense e WHERE e.source_table='lts_open_finance_staging' AND e.source_ref=c.source_id::text)
$function$;

CREATE OR REPLACE FUNCTION public.lts_browser_card_classify_v226(p_source_id uuid, p_category text, p_beneficiary text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=public.lts_browser_assert_user_v1(); before_row jsonb; cat text:=nullif(trim(p_category),''); person text:=nullif(trim(p_beneficiary),''); target record; v_st text:='lts_open_finance_staging';
begin
 if cat is null or length(cat)>120 or public.lts_v178_norm(cat) in ('a classificar','nao identificado','sem categoria') then raise exception 'Escolha uma categoria.'; end if;
 if person is not null and person not in ('Lucas','Larissa','Benjamin','Rafiki') then raise exception 'Beneficiário inválido.'; end if;
 select * into target from public.lts_open_finance_staging s where s.id=p_source_id and s.user_id=u and s.resource_type='card_transaction' and s.provider_deleted_at is null;
 if not found then
  IF NOT EXISTS(SELECT 1 FROM public.lts_card_document_supplement_v234 p WHERE p.user_id=u AND p.id=p_source_id)
  THEN raise exception 'Compra não encontrada.'; END IF;
  v_st:='lts_card_document_supplement_v234';
 end if;
 if not exists(select 1 from public.lts_product_read_cache c cross join lateral jsonb_array_elements_text(coalesce(c.payload#>'{card_classification_review,category_options}','[]'::jsonb)) x where c.user_id=u and x=cat) then raise exception 'Categoria não disponível.'; end if;
 select to_jsonb(d) into before_row from public.lts_v178_review_decision d where d.user_id=u and d.source_table=v_st and d.source_ref=p_source_id::text;
 insert into public.lts_v178_review_decision(user_id,source_table,source_ref,category_label,beneficiary,decision_basis)
 values(u,v_st,p_source_id::text,cat,person,'authenticated_user_v226')
 on conflict(user_id,source_table,source_ref) do update set category_label=excluded.category_label,beneficiary=coalesce(excluded.beneficiary,lts_v178_review_decision.beneficiary),decision_basis=excluded.decision_basis,decided_at=now();
 insert into public.lts_access_audit(user_id,email,action,meta) values(u,lower(coalesce(auth.jwt()->>'email','')),'browser_card_classify_v226',jsonb_build_object('source_id',p_source_id,'before',before_row,'after',jsonb_build_object('category',cat,'beneficiary',person),'financial_effect','none'));
 return jsonb_build_object('ok',true,'source_id',p_source_id,'category',cat,'beneficiary',person);
end $function$;

CREATE OR REPLACE FUNCTION public.lts_browser_expense_review_decision_v229(p_source_table text, p_source_ref text, p_beneficiary text DEFAULT NULL::text, p_property_code text DEFAULT NULL::text, p_category_label text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid:=public.lts_browser_assert_user_v1();
  v_email text:=lower(coalesce(auth.jwt()->>'email',''));
  v_source_table text:=nullif(trim(coalesce(p_source_table,'')),'');
  v_source_ref text:=nullif(trim(coalesce(p_source_ref,'')),'');
  v_beneficiary text:=nullif(trim(coalesce(p_beneficiary,'')),'');
  v_property text:=nullif(trim(coalesce(p_property_code,'')),'');
  v_category text:=nullif(trim(coalesce(p_category_label,'')),'');
  v_before jsonb;
  v_target record;
  v_resolved boolean;
  v_scope_from date:=date '2013-10-10'; v_source_date date;
begin
  if v_source_table is null or v_source_ref is null then raise exception 'source required'; end if;
  if v_beneficiary is null and v_property is null and v_category is null then raise exception 'decision required'; end if;
  if v_beneficiary is not null and v_beneficiary not in ('Lucas','Larissa','Benjamin','Rafiki') then raise exception 'invalid beneficiary'; end if;
  if v_property is not null and v_property not in ('cipo396','other_property','not_property') then raise exception 'invalid property'; end if;
  if v_category is not null and length(v_category)>120 then raise exception 'invalid category'; end if;

  -- Resolve the requested occurrence in its own dated scope. The authorization,
  -- category allowlist, audit and post-write resolution checks are unchanged.
  IF v_source_table='lts_open_finance_staging' THEN
    SELECT least(s.posting_date,CASE WHEN left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
      THEN left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10)::date ELSE s.posting_date END)
    INTO v_source_date FROM public.lts_open_finance_staging s WHERE s.user_id=v_uid AND s.id::text=v_source_ref;
  ELSIF v_source_table='lts_card_document_supplement_v234' THEN
    SELECT d.purchase_date INTO v_source_date FROM public.lts_card_document_supplement_v234 d
    WHERE d.user_id=v_uid AND d.id::text=v_source_ref;
  ELSIF v_source_table='evento_base' THEN
    SELECT (e.dados->>'dia')::date INTO v_source_date FROM public.evento_base e WHERE e.usuario_id=v_uid AND e.idx::text=v_source_ref;
  ELSIF v_source_table='historico_analitico' THEN
    SELECT (e.dados->>'dia')::date INTO v_source_date FROM public.historico_analitico e WHERE e.usuario_id=v_uid AND e.idx::text=v_source_ref;
  ELSIF v_source_table='card_purchase_detail' THEN
    SELECT e.invoice_due_date INTO v_source_date FROM public.lts_card_purchase_detail e WHERE e.user_id=v_uid AND (e.line_key=v_source_ref OR e.purchase_key=v_source_ref) LIMIT 1;
  END IF;
  IF v_source_date IS NOT NULL THEN v_scope_from:=greatest(date '2013-10-10',date_trunc('month',v_source_date)::date); END IF;

  select * into v_target
  from public.lts_v229_review_rows(v_uid,v_scope_from,current_date) r
  where r.source_table=v_source_table and r.source_ref=v_source_ref and r.identity_status='pending'
  order by r.event_date desc
  limit 1;
  if not found then raise exception 'pending review item not found'; end if;

  if v_category is not null and not exists (
    select 1 from public.lts_product_read_cache c
    cross join lateral jsonb_array_elements_text(coalesce(c.payload#>'{card_classification_review,category_options}','[]'::jsonb)) x(value)
    where c.user_id=v_uid and x.value=v_category
  ) and not exists (
    select 1 from public.lts_v229_review_rows(v_uid,v_scope_from,current_date) r
    where r.category=v_category or r.management_group=v_category or r.management_subgroup=v_category
  ) then raise exception 'unknown category'; end if;

  select to_jsonb(d) into v_before
  from public.lts_v178_review_decision d
  where d.user_id=v_uid and d.source_table=v_source_table and d.source_ref=v_source_ref;

  insert into public.lts_v178_review_decision(
    user_id,source_table,source_ref,beneficiary,property_code,category_label,decision_basis,decided_at
  ) values (
    v_uid,v_source_table,v_source_ref,v_beneficiary,v_property,v_category,'authenticated_user_v229',now()
  )
  on conflict(user_id,source_table,source_ref) do update set
    beneficiary=coalesce(excluded.beneficiary,lts_v178_review_decision.beneficiary),
    property_code=coalesce(excluded.property_code,lts_v178_review_decision.property_code),
    category_label=coalesce(excluded.category_label,lts_v178_review_decision.category_label),
    decision_basis=excluded.decision_basis,
    decided_at=excluded.decided_at;

  select not exists(
    select 1 from public.lts_v229_review_rows(v_uid,v_scope_from,current_date) r
    where r.source_table=v_source_table and r.source_ref=v_source_ref and r.identity_status='pending'
  ) into v_resolved;
  if not v_resolved then raise exception 'A decisão não resolveu a pendência; nenhuma alteração foi mantida.'; end if;

  insert into public.lts_access_audit(user_id,email,action,meta)
  values(v_uid,v_email,'browser_expense_review_decision_v181',jsonb_build_object(
    'source_table',v_source_table,'source_ref',v_source_ref,
    'before',v_before,
    'after',jsonb_build_object('beneficiary',v_beneficiary,'property_code',v_property,'category_label',v_category),
    'resolved',v_resolved
  ));

  return jsonb_build_object(
    'ok',true,'resolved',v_resolved,'source_table',v_source_table,'source_ref',v_source_ref,
    'display_contract',case when v_beneficiary='Lucas' then 'owner_category_without_prefix' else 'named_person_when_explicit' end
  );
end
$function$;
