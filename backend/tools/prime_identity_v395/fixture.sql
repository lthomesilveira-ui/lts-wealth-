-- Invented data in disposable PostgreSQL only. No JWT, login or financial source promotion.
CREATE SCHEMA qa;
CREATE TABLE public.lts_card_due_rule_v290(user_id uuid,family text,effective_from date,due_day int);
CREATE TABLE public.card_invoices(user_id uuid,card_name text,reference_month date,due_date date);
CREATE TABLE public.lts_open_finance_staging(id uuid PRIMARY KEY,user_id uuid,resource_type text,institution_code text,
 currency text,provider_deleted_at timestamptz,provider_account_ref text,normalized_payload jsonb);
CREATE TABLE qa.rows(user_id uuid,source_id uuid,bank text,family text,reference_month date,provider_status text,is_payment boolean,amount numeric);
CREATE TABLE qa.bills(user_id uuid,family text,reference_month date,due_date date);
CREATE TABLE qa.forecast(user_id uuid,reference_month date,due_date date,amount numeric);
CREATE FUNCTION public.lts_card_source_rows_v226(uuid) RETURNS TABLE(source_id uuid,bank text,family text,reference_month date,provider_status text,is_payment boolean,amount numeric)
 LANGUAGE sql STABLE AS $$SELECT source_id,bank,family,reference_month,provider_status,is_payment,amount FROM qa.rows WHERE user_id=$1$$;
CREATE FUNCTION public.lts_current_received_card_bills_v263(uuid) RETURNS TABLE(family text,reference_month date,due_date date)
 LANGUAGE sql STABLE AS $$SELECT family,reference_month,due_date FROM qa.bills WHERE user_id=$1$$;
CREATE FUNCTION public.lts_aeternum_forecast_cycles_v311(uuid) RETURNS TABLE(reference_month date,due_date date,amount numeric)
 LANGUAGE sql STABLE AS $$SELECT reference_month,due_date,amount FROM qa.forecast WHERE user_id=$1$$;
\i backend/qa/fixtures/v396_family_actual.sql
CREATE FUNCTION public.lts_card_projection_date_v370(uuid,text,date,date,date DEFAULT NULL) RETURNS date LANGUAGE sql STABLE AS $$SELECT $4$$;
CREATE FUNCTION qa.owner(i integer) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$SELECT ('00000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid$$;
CREATE FUNCTION qa.month() RETURNS date LANGUAGE sql STABLE AS $$SELECT date_trunc('month',current_date)::date$$;
INSERT INTO public.lts_card_due_rule_v290 SELECT qa.owner(i),'bradesco_prime',qa.month(),20 FROM generate_series(1,10)i;
INSERT INTO qa.rows SELECT qa.owner(i),qa.owner(100+i),'Bradesco','bradesco_prime',qa.month(),'PENDING',false,12.34 FROM generate_series(1,10)i;
INSERT INTO public.lts_open_finance_staging SELECT qa.owner(100+i),qa.owner(i),'card_transaction','237','BRL',NULL,'account-'||i,'{}' FROM generate_series(1,10)i;
INSERT INTO public.lts_open_finance_staging SELECT qa.owner(200+i),qa.owner(i),'invoice','237','BRL',NULL,'account-'||i,
 jsonb_build_object('card_name','VISA INFINITE PRIME','due_date',(qa.month()-interval '1 month'+interval '19 days')::date) FROM generate_series(1,10)i;
-- Rejection cases: wrong account, wrong bank, deleted history, absent account, invalid date, other family.
UPDATE public.lts_open_finance_staging SET provider_account_ref='wrong-account' WHERE id=qa.owner(202);
UPDATE public.lts_open_finance_staging SET institution_code='341' WHERE id=qa.owner(203);
UPDATE public.lts_open_finance_staging SET provider_deleted_at=now() WHERE id=qa.owner(204);
UPDATE public.lts_open_finance_staging SET provider_account_ref=NULL WHERE id=qa.owner(105);
UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{due_date}','"invalid"') WHERE id=qa.owner(206);
UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{card_name}','"Other family"') WHERE id=qa.owner(210);
-- The promoted identity has priority; a received current bill removes the projection.
INSERT INTO public.card_invoices VALUES(qa.owner(7),'Bradesco Stored VISA PRIME',qa.month()-interval '1 month',qa.month()-1);
INSERT INTO qa.bills VALUES(qa.owner(8),'bradesco_prime',qa.month(),qa.month()+19);
-- Current payment rows and another owner must never inflate the expense.
INSERT INTO qa.rows VALUES(qa.owner(1),qa.owner(999),'Bradesco','bradesco_prime',qa.month(),'PENDING',true,-9999);
INSERT INTO qa.rows VALUES(qa.owner(1),qa.owner(998),'Bradesco','bradesco_prime',qa.month(),'POSTED',false,8888);
DELETE FROM public.lts_card_due_rule_v290 WHERE user_id=qa.owner(9);
-- Preserve the other-family and Aeternum branches byte-for-byte in behavior.
INSERT INTO public.lts_card_due_rule_v290 VALUES(qa.owner(1),'itau_mastercard',qa.month(),16);
INSERT INTO qa.rows VALUES(qa.owner(1),qa.owner(997),'Itaú','itau_mastercard',qa.month(),'DOCUMENTED',false,23.45);
INSERT INTO public.card_invoices VALUES(qa.owner(1),'Itaú Mastercard Black',qa.month()-interval '1 month',qa.month()-1);
INSERT INTO public.card_invoices VALUES(qa.owner(1),'Bradesco AETERNUM',qa.month()-interval '1 month',qa.month()-1);
INSERT INTO qa.forecast VALUES(qa.owner(1),qa.month()+interval '1 month',qa.month()+interval '1 month'+interval '2 days',34.56);
\i backend/qa/fixtures/v395_projection_before.sql
DO $negative$ BEGIN
 ASSERT NOT EXISTS(SELECT 1 FROM public.lts_card_projection_rows_v290(qa.owner(1)) WHERE card_name ILIKE '%PRIME%');
 RAISE NOTICE 'Reproduced Prime missing from cash despite matching received identity and explicit planning rule';
END $negative$;
