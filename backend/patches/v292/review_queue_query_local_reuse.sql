-- V292: reuse query-local C6 rows/calendars and avoid planning tiny SQL helpers per expense.
-- No source records, classification decisions, financial events, timeouts or shared caches are changed.
-- Atomic before/after parity includes every canonical row and its multiplicity, full queue JSON and C6 identities.
SET LOCAL timezone='America/Sao_Paulo';
SET LOCAL statement_timeout='55s';
CREATE TEMP TABLE review_before_v292(user_id uuid PRIMARY KEY,expenses jsonb,queue jsonb,c6 jsonb) ON COMMIT DROP;
CREATE TEMP TABLE helper_privileges_v292 ON COMMIT DROP AS
SELECT oid,proowner,proacl,proconfig,prosecdef,provolatile
FROM pg_proc WHERE oid IN('public.lts_c6_cycle_identity_v269(uuid)'::regprocedure,
'public.lts_card_merchant_key_v226(text)'::regprocedure,
'public.lts_expense_management_group_v3(text,text,text,text,text)'::regprocedure);
DO $lease$ BEGIN
 IF md5(pg_get_functiondef('public.lts_c6_cycle_identity_v269(uuid)'::regprocedure))<>'e657d011e0a1fe91cf7efd6375766479'
 OR md5(pg_get_functiondef('public.lts_card_merchant_key_v226(text)'::regprocedure))<>'46c223dd59a6a02614bf04c2bbf02f3b'
 OR md5(pg_get_functiondef('public.lts_expense_management_group_v3(text,text,text,text,text)'::regprocedure))<>'a804bd72eab38d4131b8874a8a458f62'
 THEN RAISE EXCEPTION 'V292 source definitions changed; inspect before applying'; END IF;
END $lease$;
DO $before$ DECLARE u uuid; BEGIN
 FOR u IN SELECT DISTINCT c.user_id FROM public.lts_product_read_cache c JOIN auth.users a ON a.id=c.user_id LOOP
  PERFORM set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=u),true);
  INSERT INTO review_before_v292 SELECT u,
   (SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]') FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date) x),
   public.lts_browser_expense_review_queue_v229('2013-10-10',current_date,0,25,null),
   (SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]') FROM public.lts_c6_cycle_identity_v269(u) x);
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM review_before_v292) THEN RAISE EXCEPTION 'No baseline owners found'; END IF;
END $before$;
CREATE TEMP TABLE merchant_before_v292 ON COMMIT DROP AS
WITH names AS(
 SELECT description_raw name FROM public.lts_open_finance_staging
 UNION SELECT description_raw FROM public.financial_events
 UNION SELECT name FROM(VALUES(NULL::text),(''),('PG *NUVEM ZACCA'),('Loja 03/10'),
 ('ÁÉÍÓÚ ç Café 1/12'),(repeat('x',22)||repeat(' ',15)||'BRA'),('ABC BRA'),
 ('A'||chr(9)||'B 01/02'),('   '),('Não cartão 1/120'))v(name)
) SELECT name,public.lts_card_merchant_key_v226(name) merchant FROM names;
CREATE TEMP TABLE groups_before_v292 ON COMMIT DROP AS
WITH inputs AS(
 SELECT category,NULL::text center,NULL::text counterparty,NULL::text origin,NULL::text coverage
 FROM public.lts_category_catalog
 UNION ALL SELECT category,center,counterparty,origin,coverage FROM(VALUES
 (NULL::text,NULL::text,NULL::text,NULL::text,NULL::text),
 ('','Benjamin','','',''),('Educação','Benjamin','','',''),
 ('Educação','Larissa','','',''),('Saúde','Rafiki','','',''),
 ('Móveis e Decoração','','O Parque','',''),('Enel O Parque','','O Parque','',''),
 ('Obra e Reforma','','','',''),('Assinatura','','','',''),
 ('Energia','','','','card_invoice_aggregate_fallback'),
 ('Financiamento veículo','','','',''),('Financiamento Imobiliário','','','',''),
 ('Cipó 396','','','',''),('  outra categoria  ','','','','')
 )v(category,center,counterparty,origin,coverage)
) SELECT *,public.lts_expense_management_group_v3(category,center,counterparty,origin,coverage) mg FROM inputs;
CREATE OR REPLACE FUNCTION public.lts_c6_cycle_identity_v269(p_user_id uuid)
 RETURNS TABLE(source_id uuid, reference_month date, due_date date, cycle_basis text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH source_rows_v292 AS MATERIALIZED (
 SELECT * FROM public.lts_open_finance_staging WHERE user_id=p_user_id
 AND institution_code='336' AND resource_type='card_transaction' AND provider_deleted_at IS NULL
 AND normalized_payload->>'status' IN('PENDING','POSTED')
), invoice_calendar_v292 AS MATERIALIZED (
 SELECT * FROM public.card_invoices WHERE user_id=p_user_id
 AND public.lts_card_family_v226(card_name,card_name)='c6'
), unique_account AS MATERIALIZED (
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
  AND ci.status IN ('closed','paid') AND ci.metadata->>'bank_statement_closed'='true'
  AND ci.metadata->>'bank_statement_full_composition'='true'
  AND sd.document_type='credit_card_statement' AND sd.processing_status='processed'
  AND sd.sha256=ci.metadata->>'bank_statement_sha256'
  AND sd.metadata->>'all_source_lines_matched'='true'
  AND (sd.metadata->>'statement_amount')::numeric=ci.amount
  AND (sd.metadata->>'due_date')::date=ci.due_date
), documented_item_ids_v292 AS MATERIALIZED (
 SELECT e->>'source_id' source_id FROM documented d CROSS JOIN LATERAL jsonb_array_elements(d.items) e
), closed_rows AS MATERIALIZED (
 SELECT d.reference_month,d.due_date,d.closing_date,s.provider_account_ref,
  CASE WHEN s.raw_payload#>>'{creditCardMetadata,billForecastDate}' ~ '^[0-9]{4}-[0-9]{2}$'
   THEN (s.raw_payload#>>'{creditCardMetadata,billForecastDate}'||'-01')::date END forecast
 FROM documented d CROSS JOIN LATERAL jsonb_array_elements(d.items) e
 JOIN public.lts_open_finance_staging s ON s.user_id=p_user_id AND s.id::text=e->>'source_id'
  AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL AND s.institution_code='336'
 WHERE NOT coalesce((e->>'is_payment')::boolean,false) AND nullif(s.provider_account_ref,'') IS NOT NULL
), documentary_anchors AS MATERIALIZED (
 SELECT provider_account_ref,reference_month,min(due_date) due_date,min(closing_date) closing_date,min(forecast) forecast
 FROM closed_rows GROUP BY provider_account_ref,reference_month
 HAVING count(DISTINCT due_date)=1 AND count(DISTINCT closing_date)=1
  AND count(forecast)=count(*) AND count(DISTINCT forecast)=1
  AND min(forecast)=(reference_month-interval '1 month')::date
  AND min(forecast)=date_trunc('month',min(closing_date))::date
), provider_rows AS MATERIALIZED (
 SELECT b.provider_account_ref,date_trunc('month',b.posting_date)::date reference_month,b.posting_date due_date,
 CASE WHEN b.normalized_payload->>'closing_date' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN (b.normalized_payload->>'closing_date')::date END closing_date,
 b.id bill_source_id,b.signed_amount invoice_amount,
 CASE WHEN tx.raw_payload#>>'{creditCardMetadata,billForecastDate}' ~ '^[0-9]{4}-[0-9]{2}$'
 THEN (tx.raw_payload#>>'{creditCardMetadata,billForecastDate}'||'-01')::date END forecast,-tx.signed_amount amount
 FROM public.lts_open_finance_staging b JOIN public.lts_open_finance_staging tx
 ON tx.user_id=b.user_id AND tx.institution_code=b.institution_code AND tx.provider_account_ref=b.provider_account_ref
 AND tx.resource_type='card_transaction' AND tx.provider_deleted_at IS NULL AND tx.normalized_payload->>'status'='POSTED'
 AND tx.raw_payload#>>'{creditCardMetadata,billId}'=b.normalized_payload->>'provider_id'
 WHERE b.user_id=p_user_id AND b.institution_code='336' AND b.resource_type='invoice' AND b.provider_deleted_at IS NULL
 AND b.currency='BRL' AND tx.currency='BRL' AND b.signed_amount>=0
 AND coalesce(jsonb_array_length(b.normalized_payload->'warnings'),0)=0
 AND NOT(coalesce(tx.raw_payload->>'operationType','')='PAGAMENTO_FATURA'
 OR coalesce(tx.raw_payload->>'category','')='Credit card payment'
 OR public.lts_v178_norm(tx.description_raw) ~ '^(inclusao de pagamento ciclo corrente|pagamento recebido|pagto fatura)')
), provider_anchors AS MATERIALIZED (
 SELECT provider_account_ref,reference_month,min(due_date) due_date,min(closing_date) closing_date,
 CASE WHEN count(forecast)=count(*) AND count(DISTINCT forecast)=1 THEN min(forecast) END forecast
 FROM provider_rows GROUP BY provider_account_ref,reference_month,bill_source_id,invoice_amount
 HAVING count(DISTINCT due_date)=1 AND count(closing_date)=count(*) AND count(DISTINCT closing_date)=1
 AND min(closing_date)<=current_date AND min(closing_date)<min(due_date)
 AND round(sum(amount),2)=invoice_amount
), anchor_groups AS MATERIALIZED (
 -- Keep conflicting observations: they prevent older calibration from silently
 -- winning for later cycles. A later observation cannot erase an earlier cycle.
 -- If same-month closing dates differ, require posting after BOTH boundaries.
 -- This conservative cutoff does not rewrite either source closing date.
 SELECT provider_account_ref,reference_month,min(due_date) due_date,
  max(closing_date) closing_date,min(forecast) forecast,
  (count(DISTINCT due_date)=1 AND count(due_date)=count(*)
   AND count(closing_date)=count(*) AND max(closing_date)-min(closing_date)<=1
   AND count(DISTINCT forecast)=1 AND count(forecast)=count(*)
   AND bool_and(forecast=(reference_month-interval '1 month')::date
    AND forecast=date_trunc('month',closing_date)::date)) AS calibration_valid
 FROM (SELECT * FROM documentary_anchors UNION ALL SELECT * FROM provider_anchors) observations
 GROUP BY provider_account_ref,reference_month
), candidates AS MATERIALIZED (
 SELECT a.provider_account_ref,a.closing_date,a.forecast,ci.reference_month,
  min(ci.due_date) due_date
 FROM anchor_groups a JOIN unique_account ua ON ua.provider_account_ref=a.provider_account_ref
 JOIN invoice_calendar_v292 ci ON ci.user_id=p_user_id
  AND public.lts_card_family_v226(ci.card_name,ci.card_name)='c6'
  AND ci.reference_month>a.reference_month
  AND ci.due_date>=ci.reference_month AND ci.due_date<(ci.reference_month+interval '1 month')::date
 WHERE a.calibration_valid
  AND NOT EXISTS(SELECT 1 FROM anchor_groups newer
   WHERE newer.provider_account_ref=a.provider_account_ref
    AND newer.reference_month>a.reference_month
    AND newer.reference_month<ci.reference_month)
 GROUP BY a.provider_account_ref,a.closing_date,a.forecast,ci.reference_month
 HAVING count(DISTINCT ci.due_date)=1
), resolved AS (
 SELECT s.id source_id,c.reference_month,c.due_date
 FROM source_rows_v292 s JOIN candidates c ON c.provider_account_ref=s.provider_account_ref
 WHERE s.user_id=p_user_id AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL
  AND s.institution_code='336' AND s.normalized_payload->>'status' IN('PENDING','POSTED')
  AND NOT EXISTS(SELECT 1 FROM public.lts_open_finance_staging b WHERE b.user_id=s.user_id
   AND b.institution_code=s.institution_code AND b.resource_type='invoice' AND b.provider_deleted_at IS NULL
   AND b.normalized_payload->>'provider_id'=s.raw_payload#>>'{creditCardMetadata,billId}')
  AND s.raw_payload#>>'{creditCardMetadata,billForecastDate}'=to_char(c.reference_month-interval '1 month','YYYY-MM')
  AND coalesce(CASE WHEN s.raw_payload#>>'{creditCardMetadata,billPostDate}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN (s.raw_payload#>>'{creditCardMetadata,billPostDate}')::date END,s.posting_date)>c.closing_date
  AND coalesce(CASE WHEN s.raw_payload#>>'{creditCardMetadata,billPostDate}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN (s.raw_payload#>>'{creditCardMetadata,billPostDate}')::date END,s.posting_date)<c.due_date
  AND NOT(coalesce(s.raw_payload->>'operationType','')='PAGAMENTO_FATURA'
 OR coalesce(s.raw_payload->>'category','')='Credit card payment'
 OR public.lts_v178_norm(s.description_raw) ~ '^(inclusao de pagamento ciclo corrente|pagamento recebido|pagto fatura)')
  AND NOT EXISTS(SELECT 1 FROM documented_item_ids_v292 d WHERE d.source_id=s.id::text)
), unique_resolved AS (
 SELECT source_id,min(reference_month) reference_month,min(due_date) due_date,
 'verified_account_forecast_offset_and_due_calendar'::text cycle_basis
 FROM resolved GROUP BY source_id HAVING count(DISTINCT reference_month)=1 AND count(DISTINCT due_date)=1
)
SELECT * FROM unique_resolved
UNION ALL
SELECT s.id source_id,NULL::date reference_month,NULL::date due_date,'unresolved'::text cycle_basis FROM source_rows_v292 s
 WHERE s.user_id=p_user_id AND s.institution_code='336' AND s.resource_type='card_transaction'
 AND s.provider_deleted_at IS NULL AND s.normalized_payload->>'status' IN('PENDING','POSTED')
 AND s.raw_payload#>>'{creditCardMetadata,billForecastDate}' ~ '^[0-9]{4}-[0-9]{2}$'
 AND EXISTS(SELECT 1 FROM invoice_calendar_v292 ci WHERE ci.user_id=p_user_id
 AND public.lts_card_family_v226(ci.card_name,ci.card_name)='c6'
 AND ci.reference_month=((s.raw_payload#>>'{creditCardMetadata,billForecastDate}'||'-01')::date+interval '1 month')::date
 AND (ci.due_date>=current_date OR ci.status IN('open','projected')))
 AND NOT EXISTS(SELECT 1 FROM unique_resolved r WHERE r.source_id=s.id)
 AND NOT EXISTS(SELECT 1 FROM public.lts_open_finance_staging b WHERE b.user_id=s.user_id AND b.institution_code=s.institution_code
 AND b.provider_account_ref=s.provider_account_ref AND b.resource_type='invoice' AND b.provider_deleted_at IS NULL
 AND b.normalized_payload->>'provider_id'=s.raw_payload#>>'{creditCardMetadata,billId}')
 AND NOT EXISTS(SELECT 1 FROM documented_item_ids_v292 d WHERE d.source_id=s.id::text)
 AND NOT(coalesce(s.raw_payload->>'operationType','')='PAGAMENTO_FATURA' OR coalesce(s.raw_payload->>'category','')='Credit card payment'
 OR public.lts_v178_norm(s.description_raw) ~ '^(inclusao de pagamento ciclo corrente|pagamento recebido|pagto fatura)');
$function$;

CREATE OR REPLACE FUNCTION public.lts_card_merchant_key_v226(p_name text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
BEGIN
 RETURN regexp_replace(regexp_replace(public.lts_v178_norm(case when length(p_name)=40 and p_name ~ '[[:space:]]{2,}BRA$' then left(p_name,22) else p_name end),'[[:space:]]*[0-9]{1,2}/[0-9]{1,2}$','','g'),'[^a-z0-9]','','g');
END
$function$;

CREATE OR REPLACE FUNCTION public.lts_expense_management_group_v3(p_category text, p_center_cost text, p_counterparty text, p_origin_name text, p_coverage_mode text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
BEGIN
 RETURN case
  when coalesce(p_coverage_mode,'')='card_invoice_aggregate_fallback'
    then 'Faturas conciliadas pelo total'
  when coalesce(p_category,'') ~* '^Financiamento Imobili[aá]rio'
    then 'Financiamento imobiliário'
  when coalesce(p_category,'') ~* '^Financiamento ve[ií]culo'
    then 'Financiamento de veículo'
  when coalesce(p_category,'') ~* '^(Empr[eé]stimos|Compromissos Financeiros)'
    then 'Empréstimos'
  when coalesce(p_category,'') ~* '^(Energia|Enel)'
    then 'Energia'
  when coalesce(p_category,'') ~* '^Condom'
    then 'Condomínio'
  when coalesce(p_category,'') ~* '^(IPTU|Impostos do Im[oó]vel)'
    then 'Impostos do imóvel'
  when coalesce(p_category,'') ~* '^Educa[cç][aã]o$' and coalesce(p_center_cost,'') ~* '^Benjamin$'
    then 'Benjamin — Educação'
  when coalesce(p_category,'') ~* '^Educa[cç][aã]o$'
    then 'Educação'
  when coalesce(p_category,'') ~* '^(Rafiki|Pet)$' or coalesce(p_center_cost,'') ~* '^Rafiki$'
    then 'Rafiki'
  when coalesce(p_category,'') ~* '^Fam[ií]lia$'
    then 'Família — saídas'
  when coalesce(p_category,'') ~* '^Restaurantes( e Lazer)?$'
    then 'Restaurantes'
  when coalesce(p_category,'') ~* '^Assinatura$'
    then 'Assinaturas'
  when coalesce(p_category,'') ~* '^(Cons[oó]rcio.*O Parque|Cart[oó]rio.*O Parque|Cip[oó] 396)$'
    then 'Investimento no imóvel — aquisição e histórico'
  when (
      coalesce(p_category,'') ~* '^Obra e Reforma$'
      or coalesce(p_category,'') ~* 'O Parque'
      or (coalesce(p_category,'') ~* '^M[oó]veis e Decora[cç][aã]o$' and coalesce(p_counterparty,'') ~* 'O Parque')
    )
    and coalesce(p_category,'') !~* '^(Condom|Enel|Energia|IPTU|Impostos|Cons[oó]rcio|Cart[oó]rio|Financiamento)'
    then 'Investimentos no imóvel — obra e reforma'
  else coalesce(nullif(trim(p_category),''),'A classificar')
end;
END
$function$;

DO $parity$ DECLARE r record; expenses jsonb; queue jsonb; c6 jsonb; BEGIN
 IF EXISTS(SELECT 1 FROM helper_privileges_v292 b LEFT JOIN pg_proc p ON p.oid=b.oid
 WHERE p.oid IS NULL OR p.proowner<>b.proowner OR p.proacl IS DISTINCT FROM b.proacl
 OR p.proconfig IS DISTINCT FROM b.proconfig OR p.prosecdef<>b.prosecdef OR p.provolatile<>b.provolatile)
 THEN RAISE EXCEPTION 'V292 helper identity, stability or privileges changed'; END IF;
 IF EXISTS(SELECT 1 FROM merchant_before_v292 b WHERE public.lts_card_merchant_key_v226(b.name) IS DISTINCT FROM b.merchant)
 THEN RAISE EXCEPTION 'Merchant normalization changed'; END IF;
 IF EXISTS(SELECT 1 FROM groups_before_v292 b WHERE public.lts_expense_management_group_v3(b.category,b.center,b.counterparty,b.origin,b.coverage) IS DISTINCT FROM b.mg)
 THEN RAISE EXCEPTION 'Management group semantics changed'; END IF;
 FOR r IN SELECT * FROM review_before_v292 LOOP
  PERFORM set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=r.user_id),true);
  SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]') INTO expenses
  FROM public.lts_v229_expense_rows(r.user_id,'2013-10-10',current_date) x;
  queue:=public.lts_browser_expense_review_queue_v229('2013-10-10',current_date,0,25,null);
  SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]') INTO c6 FROM public.lts_c6_cycle_identity_v269(r.user_id) x;
  IF expenses IS DISTINCT FROM r.expenses OR queue IS DISTINCT FROM r.queue OR c6 IS DISTINCT FROM r.c6
  THEN RAISE EXCEPTION 'V292 canonical expenses, queue or C6 identities changed'; END IF;
 END LOOP;
END $parity$;

