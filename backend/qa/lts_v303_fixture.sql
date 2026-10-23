-- Isolated synthetic dependencies. These doubles are not receipt certification.
CREATE SCHEMA v303_fixture;
CREATE TABLE v303_fixture.evento_base(usuario_id uuid,idx integer,dados jsonb);
CREATE TABLE v303_fixture.lts_open_finance_staging(id uuid,user_id uuid,posting_date date,signed_amount numeric,
 resource_type text,currency text,provider_deleted_at timestamptz,normalized_payload jsonb,
 institution_code text,institution_name text,description_raw text);
CREATE TABLE v303_fixture.lts_card_documentary_payment_link_v272(user_id uuid,invoice_source_id uuid,payment_source_id uuid,expected_due_date date,active boolean);
CREATE TABLE v303_fixture.lts_card_settlement_expense_contract_v273(user_id uuid,payment_source_id uuid,active boolean,payload jsonb);
CREATE TABLE v303_fixture.payroll_match(user_id uuid,projection_ref text,projection_date date,projection_amount numeric,
 staging_id uuid,actual_date date,actual_amount numeric,bank text);
CREATE TABLE v303_fixture.lts_v229_documentary_match(user_id uuid,staging_id uuid,source_ref text,bank text,signed_amount numeric);
CREATE TABLE v303_fixture.financial_events(id uuid,user_id uuid,is_projection boolean,is_suppressed boolean,legacy_id text,
 event_date date,description_normalized text,description_raw text,metadata jsonb,amount numeric);
CREATE FUNCTION v303_fixture.lts_v178_norm(text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
 SELECT translate(lower(trim($1)),'áàãâéêíóôõúç','aaaaeeiooouc') $$;
CREATE FUNCTION v303_fixture.lts_forecast_series_key_v1(text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
 SELECT CASE v303_fixture.lts_v178_norm($1) WHEN 'mastercard' THEN 'card_itau'
 WHEN 'adiantamento quinzenal' THEN 'salary_advance' WHEN 'salario' THEN 'salary'
 ELSE v303_fixture.lts_v178_norm($1) END $$;
CREATE FUNCTION v303_fixture.lts_card_family_v226(text,text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
 SELECT CASE WHEN $1='Mastercard' AND $2='Itaú' THEN 'itau_mastercard' ELSE 'other' END $$;
CREATE FUNCTION v303_fixture.lts_payroll_bank_matches_v231(uuid)
 RETURNS TABLE(projection_ref text,projection_date date,projection_amount numeric,staging_id uuid,actual_date date,actual_amount numeric,bank text)
 LANGUAGE sql AS $$ SELECT projection_ref,projection_date,projection_amount,staging_id,actual_date,actual_amount,bank
 FROM v303_fixture.payroll_match WHERE user_id=$1 $$;
CREATE FUNCTION v303_fixture.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)
 RETURNS jsonb LANGUAGE sql AS $$ SELECT CASE WHEN $5->>'proved'='true'
 AND $4->>'user_id'=$1::text AND ($4->>'posting_date')::date<=$6
 AND $3#>>'{normalized_payload,status}'='CLOSED' THEN '{"synthetic_proof":true}'::jsonb END $$;
CREATE FUNCTION v303_fixture.lts_recurring_future_gap_audit_v4(uuid,date) RETURNS jsonb LANGUAGE sql AS $$
 SELECT '{"items":[],"covered_count":0}'::jsonb $$;
CREATE FUNCTION v303_fixture.lts_historical_effective_cash_v4(uuid,date,date)
 RETURNS TABLE(event_date date,description text,signed_amount numeric,internal_transfer boolean,excluded_from_spend boolean,
 account text,source_ref text,source text,confidence text) LANGUAGE sql AS $$
 SELECT NULL::date,NULL::text,NULL::numeric,false,false,NULL::text,NULL::text,NULL::text,NULL::text WHERE false $$;
CREATE FUNCTION v303_fixture.lts_bank_posted_rows_v231(uuid) RETURNS SETOF v303_fixture.lts_open_finance_staging
 LANGUAGE sql AS $$ SELECT * FROM v303_fixture.lts_open_finance_staging WHERE user_id=$1 $$;
CREATE FUNCTION v303_fixture.lts_bank_known_classification_v231(uuid,uuid) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION v303_fixture.lts_documented_bank_event_identity_v242(uuid,uuid,jsonb) RETURNS boolean LANGUAGE sql AS $$ SELECT false $$;
CREATE FUNCTION v303_fixture.lts_corrected_cashflow_operational_v1(uuid,date,date)
 RETURNS TABLE(event_date date,description text,source text,source_ref text,confidence text,signed_amount numeric,account text)
 LANGUAGE sql AS $$ SELECT (dados->>'dia')::date,dados->>'desc','legacy_fix86','evento_base:'||idx,
 'legacy_projection_adjusted',CASE WHEN dados->>'efeito'='entrada' THEN 1 ELSE -1 END*(dados->>'valor')::numeric,dados->>'conta'
 FROM v303_fixture.evento_base WHERE usuario_id=$1 AND (dados->>'dia')::date BETWEEN $2 AND $3 $$;
INSERT INTO v303_fixture.evento_base VALUES
 ('00000000-0000-4000-8000-000000000001',1,'{"dia":"2020-04-10","desc":"Mastercard","conta":"Itaú","efeito":"saida","valor":1000}'),
 ('00000000-0000-4000-8000-000000000001',2,'{"dia":"2020-04-15","desc":"Adiantamento Quinzenal","conta":"Itaú","efeito":"entrada","valor":2000}');
INSERT INTO v303_fixture.lts_open_finance_staging VALUES
 ('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000001','2020-04-10',1200,'invoice','BRL',NULL,'{"card_name":"Mastercard","status":"CLOSED"}','341','Itaú','Issuer bill'),
 ('00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000001','2020-04-12',-1200,'transaction','BRL',NULL,'{"status":"POSTED","account_type":"CHECKING_ACCOUNT"}','341','Itaú','Raw card payment'),
 ('00000000-0000-4000-8000-000000000012','00000000-0000-4000-8000-000000000001','2020-04-15',2000,'transaction','BRL',NULL,'{"status":"POSTED","account_type":"CHECKING_ACCOUNT"}','341','Itaú','Raw employer payment');
INSERT INTO v303_fixture.lts_card_documentary_payment_link_v272 VALUES
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000011','2020-04-10',true);
INSERT INTO v303_fixture.lts_card_settlement_expense_contract_v273 VALUES
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000011',true,'{"proved":true}');
INSERT INTO v303_fixture.payroll_match VALUES
 ('00000000-0000-4000-8000-000000000001','evento_base:2','2020-04-15',2000,
 '00000000-0000-4000-8000-000000000012','2020-04-15',2000,'Itaú');
