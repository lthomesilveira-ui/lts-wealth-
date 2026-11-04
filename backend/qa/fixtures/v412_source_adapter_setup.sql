-- Isolated synthetic adapter fixture. Never load into an existing database.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon;END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated;END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role;END IF;
END $roles$;
CREATE SCHEMA lts_projection_private_v412;
CREATE TABLE public.lts_open_finance_staging(
 id uuid PRIMARY KEY,user_id uuid NOT NULL,resource_type text NOT NULL,
 provider_deleted_at timestamptz,currency text DEFAULT 'BRL',signed_amount numeric,
 raw_hash text,posting_date date,institution_code text,institution_name text,
 provider_account_ref text,normalized_payload jsonb DEFAULT '{}',raw_payload jsonb DEFAULT '{}',
 description_raw text);
CREATE TABLE public.lts_card_documentary_payment_link_v272(
 id uuid PRIMARY KEY,user_id uuid NOT NULL,active boolean,payment_source_id uuid,
 payment_raw_hash text,expected_payment_date date,expected_amount numeric,payment_account_ref text);
CREATE TABLE public.evento_base(id bigint PRIMARY KEY,usuario_id uuid,idx int,dados jsonb);
CREATE TABLE public.qa_adapter_expenses(
 user_id uuid,row_key text,event_date date,competence_month date,amount numeric,
 category text,beneficiary text,description text,source_table text,source_ref text,
 coverage_mode text,property_code text,identity_status text DEFAULT 'identified');
CREATE TABLE public.qa_adapter_cycles(user_id uuid PRIMARY KEY,payload jsonb);
CREATE FUNCTION public.lts_bank_posted_rows_v231(p_user_id uuid)
RETURNS SETOF public.lts_open_finance_staging LANGUAGE sql STABLE AS $f$
 SELECT s.* FROM public.lts_open_finance_staging s
 WHERE s.user_id=p_user_id AND s.resource_type='transaction' AND s.provider_deleted_at IS NULL
  AND s.currency='BRL' AND s.normalized_payload->>'status'='POSTED'
$f$;
CREATE FUNCTION public.lts_v229_expense_rows(p_user_id uuid,p_from date,p_to date)
RETURNS TABLE(row_key text,event_date date,competence_month date,amount numeric,
 category text,beneficiary text,description text,source_table text,source_ref text,
 coverage_mode text,property_code text,identity_status text) LANGUAGE sql STABLE AS $f$
 SELECT e.row_key,e.event_date,e.competence_month,e.amount,e.category,e.beneficiary,e.description,
  e.source_table,e.source_ref,e.coverage_mode,e.property_code,e.identity_status
 FROM public.qa_adapter_expenses e WHERE e.user_id=p_user_id AND e.event_date BETWEEN p_from AND p_to
$f$;
CREATE FUNCTION public.lts_card_family_v226(p_name text,p_bank text)
RETURNS text LANGUAGE sql IMMUTABLE AS $f$ SELECT lower(p_name) $f$;
CREATE FUNCTION public.lts_forecast_series_key_v1(p_text text)
RETURNS text LANGUAGE sql IMMUTABLE AS $f$ SELECT lower(p_text) $f$;
CREATE FUNCTION public.lts_bill_source_fields_v286(p_normalized jsonb,p_raw jsonb,p_fallback_due date)
RETURNS TABLE(header_valid boolean,due_date date,closing_date date,source_updated_at timestamptz,payments_valid boolean,reason text)
LANGUAGE sql STABLE AS $f$
 SELECT coalesce((p_normalized->>'valid')::boolean,false),
  coalesce((p_normalized->>'due_date')::date,p_fallback_due),
  (p_normalized->>'closing_date')::date,'2026-01-01Z'::timestamptz,true,NULL::text
$f$;
CREATE FUNCTION public.lts_card_cycles_v226(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE AS $f$
 SELECT q.payload FROM public.qa_adapter_cycles q WHERE q.user_id=p_user_id
$f$;

INSERT INTO public.lts_open_finance_staging(id,user_id,resource_type,posting_date,signed_amount,
 raw_hash,institution_code,institution_name,provider_account_ref,normalized_payload,description_raw)
SELECT md5('bank-'||n)::uuid,'00000000-0000-4000-8000-000000000001','transaction',
 make_date(2025,n,15),-100,repeat('a',64),'000','Synthetic bank','synthetic-checking',
 '{"status":"POSTED"}','OTHER' FROM generate_series(1,12)n;
INSERT INTO public.qa_adapter_expenses
SELECT '00000000-0000-4000-8000-000000000001','general:'||n,make_date(2025,n,15),make_date(2025,n,1),
 100,'General',NULL,'General expense','synthetic',n::text,'direct_cash',NULL FROM generate_series(1,12)n;
INSERT INTO public.qa_adapter_expenses
SELECT '00000000-0000-4000-8000-000000000001','card-care:'||n,make_date(2025,n,15),make_date(2025,n,1),
 999,'Care','Person A','Card care','card_purchase_detail',n::text,'card_detail_structured',NULL FROM generate_series(1,12)n;
INSERT INTO public.qa_adapter_expenses VALUES
 ('00000000-0000-4000-8000-000000000001','care:1','2025-01-06','2025-01-01',100,'Care','Person A','Care direct','synthetic','care-1','direct_cash',NULL),
 ('00000000-0000-4000-8000-000000000001','care:2','2025-03-06','2025-03-01',50,'Care','Person A','Care direct','synthetic','care-2','direct_cash',NULL),
 ('00000000-0000-4000-8000-000000000001','care:other','2025-03-06','2025-03-01',9999,'Care','Person B','Other person','synthetic','care-other','direct_cash',NULL),
 ('00000000-0000-4000-8000-000000000002','care:foreign','2025-03-06','2025-03-01',99999,'Care','Person A','Other owner','synthetic','care-foreign','direct_cash',NULL);
INSERT INTO public.qa_adapter_expenses VALUES
 ('00000000-0000-4000-8000-000000000001','care:general','2025-02-06','2025-02-01',75,'Care',NULL,
 'Identified general care','synthetic','care-general','direct_cash',NULL,'identified');
INSERT INTO public.lts_open_finance_staging(id,user_id,resource_type,posting_date,signed_amount,
 raw_hash,institution_code,institution_name,provider_account_ref,normalized_payload,description_raw)
SELECT md5('utility-'||n)::uuid,'00000000-0000-4000-8000-000000000001','transaction',make_date(2025,n,9),
 -(100+n),repeat('b',64),'000','Synthetic bank','synthetic-checking','{"status":"POSTED"}','UTILITY A'
FROM generate_series(1,12)n;
INSERT INTO public.lts_open_finance_staging VALUES
 ('00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000001','credit_card',NULL,'BRL',NULL,
 repeat('c',64),NULL,'000','Synthetic bank','synthetic-card','{"provider_account_id":"synthetic-card","name":"c6"}','{}',NULL);
INSERT INTO public.lts_open_finance_staging(id,user_id,resource_type,posting_date,signed_amount,raw_hash,
 institution_code,institution_name,provider_account_ref,normalized_payload,raw_payload)
SELECT md5('invoice-'||n)::uuid,'00000000-0000-4000-8000-000000000001','invoice',make_date(2025,n,5),500+n,
 repeat('d',64),'000','Synthetic bank','synthetic-card',jsonb_build_object('card_name','c6','valid',true,
 'due_date',make_date(2025,n,5),'closing_date',make_date(2025,n,1)),
 '{"payments":[{"amount":100000}],"purchases":[{"amount":999999}]}' FROM generate_series(1,12)n;
INSERT INTO public.lts_open_finance_staging(id,user_id,resource_type,posting_date,signed_amount,raw_hash,
 institution_code,institution_name,provider_account_ref,normalized_payload)
VALUES ('00000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000001','invoice','2025-01-05',99999,
 repeat('e',64),'000','Synthetic bank','not-owned-card','{"card_name":"c6","valid":true,"due_date":"2025-01-05"}');
INSERT INTO public.lts_open_finance_staging(id,user_id,resource_type,posting_date,signed_amount,raw_hash,
 provider_account_ref,normalized_payload,description_raw)
VALUES ('00000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000001','transaction','2025-10-20',-333,
 repeat('e',64),'synthetic-checking','{"status":"POSTED"}','CARD SETTLEMENT');
INSERT INTO public.lts_card_documentary_payment_link_v272 VALUES
 ('00000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-000000000001',true,
 '00000000-0000-4000-8000-000000000005',repeat('e',64),'2025-10-20',333,'synthetic-checking');
INSERT INTO public.qa_adapter_expenses VALUES
 ('00000000-0000-4000-8000-000000000001','settlement:1','2025-10-20','2025-10-01',333,'A classificar',NULL,
 'CARD SETTLEMENT','lts_open_finance_staging','00000000-0000-4000-8000-000000000005','bank_observed_individual',NULL);
INSERT INTO public.evento_base VALUES
 (1,'00000000-0000-4000-8000-000000000001',10,'{"dia":"2026-02-18","desc":"tax a","valor":100,"efeito":"saida"}'),
 (2,'00000000-0000-4000-8000-000000000001',11,'{"dia":"2026-03-16","desc":"tax a","valor":100,"efeito":"saida"}'),
 (3,'00000000-0000-4000-8000-000000000001',12,'{"dia":"2026-05-18","desc":"tax b","valor":20,"efeito":"saida"}'),
 (4,'00000000-0000-4000-8000-000000000001',13,'{"dia":"2029-02-20","desc":"annual income","valor":300,"efeito":"entrada"}'),
 (5,'00000000-0000-4000-8000-000000000002',14,'{"dia":"2026-02-18","desc":"tax a","valor":9999,"efeito":"saida"}'),
 (6,'00000000-0000-4000-8000-000000000001',15,'{"dia":"2029-02-20","desc":"utility","valor":9999,"efeito":"saida"}');
INSERT INTO public.qa_adapter_cycles VALUES
 ('00000000-0000-4000-8000-000000000001','{"complete":true,"cards":[{"family":"aeternum","cycles":[{"month":"2026-11-01","due_date":"2026-12-03","amount":200,"basis":"derived_current_installments"},{"month":"2026-12-01","due_date":"2027-01-03","amount":100,"basis":"derived_current_installments"}]},{"family":"c6","complete":false,"cycles":[{"month":"2026-11-01","due_date":"2026-11-05","amount":null,"complete":false}]},{"family":"itau_mastercard","cycles":[{"month":"2026-10-01","due_date":"2026-10-12","amount":500,"payment_status":"paid","settlement_confirmed":true}]}]}');
CREATE TABLE public.qa_adapter_policy(policy jsonb);
INSERT INTO public.qa_adapter_policy VALUES ('{"rules":[
 {"series_key":"person care","source_kind":"expense","expense_source":"classified_ledger","expense_scope":"non_card_cash","coverage_basis":"classified_ledger","category_aliases":["Care"],"beneficiary":"Person A"},
 {"series_key":"utility","source_kind":"expense","expense_source":"posted_bank","expense_scope":"non_card_cash","description_aliases":["utility a"],"method":"inflated_calendar","template_source":"history_mean","base_year":2026},
 {"series_key":"card_c6","source_kind":"card_invoice","card_family":"c6"},
 {"series_key":"tax a","method":"inflated_calendar","template_year":2026,"direction":"expense"},
 {"series_key":"tax b","method":"inflated_calendar","template_year":2026,"direction":"expense"},
 {"series_key":"annual income","method":"repeat_calendar","template_year":2029,"direction":"income"}
 ]}');
