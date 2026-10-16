from pathlib import Path
p=Path(__file__).parent
s=(p/'synthetic-presentation-test.sql').read_text()
acl=r'''
-- Disposable roles and privileges; no production relations or authentication.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
DO $schema$ BEGIN EXECUTE format('GRANT USAGE ON SCHEMA %I TO anon,authenticated,service_role',(SELECT nspname FROM pg_namespace WHERE oid=pg_my_temp_schema())); END $schema$;
REVOKE ALL ON FUNCTION pg_temp.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION pg_temp.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date) TO service_role;
REVOKE ALL ON FUNCTION pg_temp.lts_card_documentary_payment_presentation_v272(uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION pg_temp.lts_card_documentary_payment_presentation_v272(uuid,jsonb) TO service_role;
REVOKE ALL ON pg_temp.lts_card_documentary_payment_link_v272,pg_temp.lts_card_settlement_expense_contract_v273,pg_temp.lts_open_finance_staging FROM PUBLIC,anon,authenticated;
CREATE TEMP TABLE annotation_acl_checks(label text,pass boolean);
GRANT INSERT ON annotation_acl_checks TO service_role,authenticated;
GRANT SELECT ON pg_temp.annotation_cases,pg_temp.lts_card_documentary_payment_link_v272,pg_temp.lts_card_settlement_expense_contract_v273,pg_temp.lts_open_finance_staging TO service_role;
INSERT INTO annotation_acl_checks VALUES
('client_projector_denied',NOT has_function_privilege('anon','pg_temp.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)','EXECUTE') AND NOT has_function_privilege('authenticated','pg_temp.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)','EXECUTE')),
('client_presentation_denied',NOT has_function_privilege('anon','pg_temp.lts_card_documentary_payment_presentation_v272(uuid,jsonb)','EXECUTE') AND NOT has_function_privilege('authenticated','pg_temp.lts_card_documentary_payment_presentation_v272(uuid,jsonb)','EXECUTE')),
('client_contract_table_denied',NOT has_any_column_privilege('anon','pg_temp.lts_card_settlement_expense_contract_v273','SELECT,INSERT,UPDATE,REFERENCES') AND NOT has_any_column_privilege('authenticated','pg_temp.lts_card_settlement_expense_contract_v273','SELECT,INSERT,UPDATE,REFERENCES')),
('service_contract_read_only',has_table_privilege('service_role','pg_temp.lts_card_settlement_expense_contract_v273','SELECT') AND NOT has_table_privilege('service_role','pg_temp.lts_card_settlement_expense_contract_v273','INSERT,UPDATE,DELETE')),
('projector_is_private_invoker',EXISTS(SELECT 1 FROM pg_proc WHERE oid='pg_temp.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)'::regprocedure AND NOT prosecdef AND provolatile='i' AND proconfig=ARRAY['search_path=""'])),
('presentation_is_invoker',EXISTS(SELECT 1 FROM pg_proc WHERE oid='pg_temp.lts_card_documentary_payment_presentation_v272(uuid,jsonb)'::regprocedure AND NOT prosecdef AND provolatile='s'));
CREATE FUNCTION pg_temp.annotation_invoker() RETURNS boolean LANGUAGE sql SET search_path TO '' AS $f$
 SELECT pg_temp.lts_card_documentary_payment_presentation_v272('11111111-1111-4111-8111-111111111111','{"cards":[{"cycles":[{"invoice_source_id":"33333333-3333-4333-8333-333333333333","due_date":"2026-10-12","amount":100}]}]}'::jsonb)#>>'{cards,0,cycles,0,documentary_payment_evidence,basis}'='reviewed_original_link_and_exact_issuer_refresh'
$f$;
REVOKE ALL ON FUNCTION pg_temp.annotation_invoker() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION pg_temp.annotation_invoker() TO service_role;
SET LOCAL ROLE service_role;
INSERT INTO annotation_acl_checks VALUES('service_role_invoker_chain',pg_temp.annotation_invoker());
RESET ROLE;
CREATE FUNCTION pg_temp.annotation_browser_entry() RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $f$
BEGIN
 IF current_setting('synthetic.authenticated_user',true) IS DISTINCT FROM '11111111-1111-4111-8111-111111111111' THEN RAISE EXCEPTION 'synthetic auth required'; END IF;
 RETURN pg_temp.annotation_invoker();
END $f$;
REVOKE ALL ON FUNCTION pg_temp.annotation_browser_entry() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION pg_temp.annotation_browser_entry() TO authenticated;
SET LOCAL synthetic.authenticated_user='11111111-1111-4111-8111-111111111111';
SET LOCAL ROLE authenticated;
INSERT INTO annotation_acl_checks VALUES('authenticated_definer_chain',pg_temp.annotation_browser_entry());
DO $direct$ DECLARE blocked boolean:=false; BEGIN
 BEGIN PERFORM pg_temp.lts_card_payment_refresh_annotation_v273(NULL,NULL,NULL,NULL,NULL,NULL); EXCEPTION WHEN insufficient_privilege THEN blocked:=true; END;
 INSERT INTO annotation_acl_checks VALUES('direct_client_execution_fails',blocked);
END $direct$;
SET LOCAL synthetic.authenticated_user='';
DO $auth$ DECLARE blocked boolean:=false; BEGIN
 BEGIN PERFORM pg_temp.annotation_browser_entry(); EXCEPTION WHEN raise_exception THEN blocked:=true; END;
 INSERT INTO annotation_acl_checks VALUES('unauthenticated_entry_fails',blocked);
END $auth$;
RESET ROLE;
DO $acl$ BEGIN IF EXISTS(SELECT 1 FROM annotation_acl_checks WHERE pass IS DISTINCT FROM true) THEN RAISE EXCEPTION 'synthetic annotation privilege chain failed'; END IF; END $acl$;
SELECT jsonb_build_object('stage','acl','cases',count(*),'passed',count(*) FILTER(WHERE pass)) FROM annotation_acl_checks;
'''
assert s.count('DO $integration$')==1
s=s.replace('DO $integration$',acl+'\nDO $integration$',1)
(p/'synthetic-presentation-acl-test.sql').write_text(s)
