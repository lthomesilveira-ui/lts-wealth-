"""Emit disposable PostgreSQL tests for the actual V307 memo bodies.

The card-cycle dependency is a deliberate double. Full native Flow parity is
verified by lts_v307_live_rollback.py, never inferred from this fixture.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
patch = (ROOT / 'backend/patches/v307/native_history_performance.sql').read_text()
previous = (ROOT / 'backend/qa/v307_memo_previous.sql').read_text()
helper = re.search(r"EXECUTE \$helper\$([\s\S]*?)\$helper\$;", patch).group(1)
state = re.search(r"\|\|\$state\$([\s\S]*?)\$state\$\|\|", patch).group(1)
previous = previous.replace('public.', 'v307_fixture.')
helper = helper.replace('public.', 'v307_fixture.')
state = state.replace('public.', 'v307_fixture.')
print(r"""
BEGIN;
CREATE SCHEMA v307_fixture;
CREATE TABLE v307_fixture.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY,epoch bigint);
INSERT INTO v307_fixture.lts_read_cache_epoch_v242 VALUES(true,1);
CREATE TABLE v307_fixture.lts_v229_read_cache(
 user_id uuid NOT NULL,kind text,as_of date,from_date date,to_date date,payload jsonb,
 refreshed_at timestamptz DEFAULT clock_timestamp(),source_fingerprint text,
 PRIMARY KEY(user_id,kind,as_of,from_date,to_date));
CREATE TABLE v307_fixture.lts_open_finance_staging(
 id uuid PRIMARY KEY,user_id uuid,institution_code text,resource_type text,
 sync_run_id uuid,last_seen_at timestamptz,updated_at timestamptz,amount numeric);
CREATE TABLE v307_fixture.card_invoices(id uuid PRIMARY KEY,user_id uuid,card_name text);
CREATE TABLE v307_fixture.lts_card_document_supplement_v234(id uuid PRIMARY KEY,user_id uuid,family text,metadata jsonb);
CREATE TABLE v307_fixture.lts_card_documentary_payment_link_v272(id uuid PRIMARY KEY,user_id uuid,active boolean);
CREATE TABLE v307_fixture.lts_card_settlement_expense_contract_v273(user_id uuid,payment_source_id uuid,revision text,active boolean);
CREATE TABLE v307_fixture.lts_card_due_rule_v290(user_id uuid,family text,due_day integer);
CREATE FUNCTION v307_fixture.lts_card_family_v226(text,text) RETURNS text LANGUAGE sql IMMUTABLE
 AS $$SELECT CASE WHEN lower($1) LIKE '%c6%' THEN 'c6' ELSE 'bradesco' END$$;
CREATE FUNCTION v307_fixture.lts_card_cycles_v226(p_user_id uuid) RETURNS jsonb LANGUAGE plpgsql STABLE AS $cycles$
BEGIN
 PERFORM set_config('lts.v307.native_calls',(coalesce(nullif(current_setting('lts.v307.native_calls',true),''),'0')::int+1)::text,false);
 RETURN jsonb_build_object('owner',p_user_id,'complete',true,'incomplete_families','[]'::jsonb,
 'cards',coalesce((SELECT jsonb_agg(to_jsonb(s) ORDER BY s.id) FROM v307_fixture.lts_open_finance_staging s WHERE s.user_id=p_user_id),'[]'),
 'links',(SELECT jsonb_agg(to_jsonb(l) ORDER BY l.id) FROM v307_fixture.lts_card_documentary_payment_link_v272 l WHERE l.user_id=p_user_id),
 'contracts',(SELECT jsonb_agg(to_jsonb(c) ORDER BY c.payment_source_id) FROM v307_fixture.lts_card_settlement_expense_contract_v273 c WHERE c.user_id=p_user_id),
 'due_rules',(SELECT jsonb_agg(to_jsonb(d) ORDER BY d.family) FROM v307_fixture.lts_card_due_rule_v290 d WHERE d.user_id=p_user_id));
END $cycles$;
""")
print(previous)
print(r"""
CREATE TRIGGER source_insert AFTER INSERT ON v307_fixture.lts_open_finance_staging
 REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION v307_fixture.lts_v246_invalidate_finance_cache();
CREATE TRIGGER source_update AFTER UPDATE ON v307_fixture.lts_open_finance_staging
 REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION v307_fixture.lts_v246_invalidate_finance_cache();
CREATE TRIGGER source_delete AFTER DELETE ON v307_fixture.lts_open_finance_staging
 REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION v307_fixture.lts_v246_invalidate_finance_cache();
CREATE TRIGGER source_truncate AFTER TRUNCATE ON v307_fixture.lts_open_finance_staging
 FOR EACH STATEMENT EXECUTE FUNCTION v307_fixture.lts_v246_invalidate_finance_cache();
INSERT INTO v307_fixture.lts_open_finance_staging VALUES
 ('00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000001','237','card_transaction',NULL,'2020-01-01','2020-01-01',11),
 ('00000000-0000-4000-8000-000000000012','00000000-0000-4000-8000-000000000002','336','card_transaction',NULL,'2020-01-01','2020-01-01',22);
INSERT INTO v307_fixture.lts_card_documentary_payment_link_v272 VALUES
 ('00000000-0000-4000-8000-000000000021','00000000-0000-4000-8000-000000000001',true);
INSERT INTO v307_fixture.lts_card_settlement_expense_contract_v273 VALUES
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000021','fixture',true);
CREATE TABLE v307_fixture.old_state AS SELECT
 v307_fixture.lts_c6_completeness_state_v269('00000000-0000-4000-8000-000000000001')->'complete' complete;
""")
print("CREATE OR REPLACE FUNCTION v307_fixture.lts_c6_completeness_state_v269(p_user_id uuid)"
      " RETURNS jsonb LANGUAGE plpgsql SET search_path TO '' SET \"TimeZone\" TO 'America/Sao_Paulo'"
      " AS $function$" + state + "$function$;")
print(helper)
print(r"""
REVOKE ALL ON SCHEMA v307_fixture FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA v307_fixture FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION v307_fixture.lts_prepared_card_cycles_v307(uuid) FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA v307_fixture TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION v307_fixture.lts_prepared_card_cycles_v307(uuid) TO service_role;
CREATE FUNCTION v307_fixture.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $assert$
BEGIN
 IF NOT coalesce(ok,false) THEN RAISE EXCEPTION 'V307 assertion failed: %',label; END IF;
 PERFORM set_config('lts.v307.assertions',(coalesce(nullif(current_setting('lts.v307.assertions',true),''),'0')::int+1)::text,false);
END $assert$;
SELECT v307_fixture.assert_true(
 NOT has_function_privilege('authenticated','v307_fixture.lts_prepared_card_cycles_v307(uuid)','EXECUTE')
 AND NOT has_function_privilege('anon','v307_fixture.lts_prepared_card_cycles_v307(uuid)','EXECUTE'),'helper private');
SELECT v307_fixture.assert_true(
 NOT has_table_privilege('authenticated','v307_fixture.lts_v229_read_cache','SELECT')
 AND NOT has_table_privilege('authenticated','v307_fixture.lts_v229_read_cache','INSERT'),'memo private');
SELECT set_config('lts.v307.native_calls','0',false);
DO $tests$
DECLARE u uuid:='00000000-0000-4000-8000-000000000001';other_u uuid:='00000000-0000-4000-8000-000000000002';
 a jsonb;b jsonb;state jsonb;e bigint;n int;
BEGIN
 state:=v307_fixture.lts_c6_completeness_state_v269(u);
 PERFORM v307_fixture.assert_true(state->'complete'=(SELECT complete FROM v307_fixture.old_state),'old flag parity');
 PERFORM v307_fixture.assert_true((SELECT count(*) FROM jsonb_object_keys(state))=4,'small public state shape');
 a:=v307_fixture.lts_prepared_card_cycles_v307(u);
 b:=v307_fixture.lts_prepared_card_cycles_v307(u);
 PERFORM v307_fixture.assert_true(a=b AND current_setting('lts.v307.native_calls')::int=1,'compute once and reuse');
 b:=v307_fixture.lts_prepared_card_cycles_v307(other_u);
 PERFORM v307_fixture.assert_true(b->>'owner'=other_u::text AND b IS DISTINCT FROM a,'owner partition');
 SELECT epoch INTO e FROM v307_fixture.lts_read_cache_epoch_v242;
 UPDATE v307_fixture.lts_open_finance_staging SET last_seen_at=last_seen_at+interval '1 second' WHERE user_id=u;
 PERFORM v307_fixture.assert_true(e=(SELECT epoch FROM v307_fixture.lts_read_cache_epoch_v242),'receipt update does not advance financial epoch');
 n:=current_setting('lts.v307.native_calls')::int;
 b:=v307_fixture.lts_prepared_card_cycles_v307(u);
 PERFORM v307_fixture.assert_true(b IS DISTINCT FROM a AND current_setting('lts.v307.native_calls')::int=n+1,'non-C6 receipt refresh rebuilds');
 a:=b;
 UPDATE v307_fixture.lts_open_finance_staging SET amount=amount+.01 WHERE user_id=u;
 PERFORM v307_fixture.assert_true(e+1=(SELECT epoch FROM v307_fixture.lts_read_cache_epoch_v242),'financial trigger advances epoch');
 b:=v307_fixture.lts_prepared_card_cycles_v307(u);
 PERFORM v307_fixture.assert_true(b IS DISTINCT FROM a AND (b#>>'{cards,0,amount}')::numeric=11.01,'non-C6 financial input refreshes');
 a:=b;e:=(SELECT epoch FROM v307_fixture.lts_read_cache_epoch_v242);
 UPDATE v307_fixture.lts_card_documentary_payment_link_v272 SET active=false WHERE user_id=u;
 b:=v307_fixture.lts_prepared_card_cycles_v307(u);
 PERFORM v307_fixture.assert_true(b IS DISTINCT FROM a AND e=(SELECT epoch FROM v307_fixture.lts_read_cache_epoch_v242),'untriggered settlement link refreshes');
 a:=b;
 UPDATE v307_fixture.lts_card_settlement_expense_contract_v273 SET active=false WHERE user_id=u;
 b:=v307_fixture.lts_prepared_card_cycles_v307(u);
 PERFORM v307_fixture.assert_true(b IS DISTINCT FROM a,'untriggered settlement contract refreshes');
 UPDATE v307_fixture.lts_v229_read_cache SET payload='[]' WHERE user_id=u AND kind='card_cycles_snapshot_v307';
 a:=v307_fixture.lts_prepared_card_cycles_v307(u);
 PERFORM v307_fixture.assert_true(a=b,'malformed memo falls back to native cycles');
 a:=v307_fixture.lts_prepared_card_cycles_v307(NULL);
 PERFORM v307_fixture.assert_true(a->>'owner' IS NULL AND a->'cards'='[]'::jsonb,'null owner retains native behavior');
 DELETE FROM v307_fixture.lts_open_finance_staging WHERE user_id=u;
 a:=v307_fixture.lts_prepared_card_cycles_v307(u);
 PERFORM v307_fixture.assert_true(a->'cards'='[]'::jsonb,'deleted source invalidates');
 INSERT INTO v307_fixture.lts_open_finance_staging VALUES
 ('00000000-0000-4000-8000-000000000013',u,'237','card_transaction',NULL,'2020-01-01','2020-01-01',33);
 a:=v307_fixture.lts_prepared_card_cycles_v307(u);
 PERFORM v307_fixture.assert_true((a#>>'{cards,0,amount}')::numeric=33,'inserted source invalidates');
 TRUNCATE v307_fixture.lts_open_finance_staging;
 a:=v307_fixture.lts_prepared_card_cycles_v307(u);
 PERFORM v307_fixture.assert_true(a->'cards'='[]'::jsonb,'truncated source invalidates');
END $tests$;
CREATE TABLE v307_fixture.readonly_before AS SELECT md5(string_agg(to_jsonb(c)::text,'|' ORDER BY user_id,kind)) hash
 FROM v307_fixture.lts_v229_read_cache c;
SELECT jsonb_build_object('status','PASS','scope','synthetic memo dependency tests; not browser certification',
 'checks',current_setting('lts.v307.assertions')::int,'source_epoch_trigger','actual V246 body','new_invoker_helper_private',true) receipt;
COMMIT;
""")

