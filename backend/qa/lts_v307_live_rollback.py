"""Emit the complete transactional native-reader comparison; executes no network calls."""
from pathlib import Path
import argparse
ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--case', choices=['year','early','c6','anchor','recent'], default='year')
case = parser.parse_args().case
bounds = {'year':('2019-01-01','2019-12-31'),'early':('2013-10-10','2013-10-12'),
          'c6':('2024-05-10','2024-05-14'),'anchor':('2026-07-06','2026-07-10'),
          'recent':('2026-10-01','2026-10-23')}[case]
patch = (ROOT / 'backend/patches/v307/native_history_performance.sql').read_text()
print("""
BEGIN ISOLATION LEVEL REPEATABLE READ;
SET LOCAL timezone='America/Sao_Paulo';
SET LOCAL statement_timeout='25s';SET LOCAL lock_timeout='2s';
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text
 FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
CREATE FUNCTION pg_temp.v307_source_fingerprint() RETURNS jsonb LANGUAGE plpgsql AS $sources$
DECLARE r record;j jsonb;result jsonb:='{}';
BEGIN
 FOR r IN SELECT * FROM(VALUES
 ('financial_events','user_id'),('accounts','user_id'),
 ('evento_base','usuario_id'),('historico_analitico','usuario_id'),('evento_usuario','usuario_id'),
 ('projecao_op','usuario_id'),('deslocamento','usuario_id'),
 ('card_invoices','user_id'),('lts_open_finance_staging','user_id'),
 ('lts_reconciliation_evidence','user_id'),('lts_v178_review_decision','user_id'),
 ('lts_semantic_rule','user_id'),('lts_fact_confirmation','user_id'),
 ('lts_card_document_supplement_v234','user_id'),
 ('lts_card_documentary_payment_link_v272','user_id'),('lts_card_settlement_expense_contract_v273','user_id'),
 ('lts_card_due_rule_v290','user_id'),('source_documents','user_id'),
 ('lts_liquidity_movement','user_id'),('lts_future_liquidity_schedule','user_id')
 ) x(table_name,owner_column) LOOP
  EXECUTE format('SELECT jsonb_build_object(''rows'',count(*),''hash'',md5(coalesce(string_agg(to_jsonb(t)::text,''|'' ORDER BY to_jsonb(t)::text),''empty''))) FROM public.%I t WHERE %I=public.lts_open_finance_pilot_owner_v1()',r.table_name,r.owner_column) INTO j;
  result:=result||jsonb_build_object(r.table_name,j);
 END LOOP;
 RETURN result;
END $sources$;
CREATE TEMP TABLE v307_sources AS SELECT pg_temp.v307_source_fingerprint() before;
CREATE TEMP TABLE v307_attributes AS SELECT p.oid,jsonb_build_object('oid',p.oid,'owner',p.proowner,'acl',p.proacl,
 'config',p.proconfig,'definer',p.prosecdef,'volatility',p.provolatile) j
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
 AND p.proname IN('lts_browser_flow_v3','lts_flow_classification_source_overlay_v1',
 'lts_flow_historical_balance_truth_overlay_v1','lts_flow_documentary_close_overlay_v1',
 'lts_flow_historical_relative_balance_overlay_v1','lts_workbook_first_c6_date_v253',
 'lts_daily_flow_full_query_v4','lts_c6_completeness_state_v269',
 'lts_card_invoice_amounts_v230_engine_v243','lts_browser_flow_v242','lts_card_cycles_v226');
CREATE TEMP TABLE v307_cases(from_date date,to_date date,before_payload jsonb,after_payload jsonb,before_ms numeric,after_ms numeric);
INSERT INTO v307_cases(from_date,to_date) VALUES
 ('__FROM__','__TO__');
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;
UPDATE public.lts_v229_read_cache SET source_fingerprint='v307-rollback-before',refreshed_at='2000-01-01'
 WHERE user_id=public.lts_open_finance_pilot_owner_v1();
GRANT SELECT,UPDATE ON v307_cases TO authenticated;
SET LOCAL ROLE authenticated;
WITH t AS MATERIALIZED(SELECT clock_timestamp() started),
r AS MATERIALIZED(SELECT started,public.lts_browser_flow_v242('__FROM__','__TO__') payload FROM t)
UPDATE v307_cases SET before_payload=r.payload,before_ms=extract(epoch FROM clock_timestamp()-r.started)*1000 FROM r;
RESET ROLE;
""".replace('__FROM__',bounds[0]).replace('__TO__',bounds[1]))
print(patch)
print("""
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;
UPDATE public.lts_v229_read_cache SET source_fingerprint='v307-rollback-after',refreshed_at='2000-01-01'
 WHERE user_id=public.lts_open_finance_pilot_owner_v1();
SET LOCAL statement_timeout='__AFTER_TIMEOUT__';
SET LOCAL ROLE authenticated;
WITH t AS MATERIALIZED(SELECT clock_timestamp() started),
r AS MATERIALIZED(SELECT started,public.lts_browser_flow_v242('__FROM__','__TO__') payload FROM t)
UPDATE v307_cases SET after_payload=r.payload,after_ms=extract(epoch FROM clock_timestamp()-r.started)*1000 FROM r;
RESET ROLE;
SET LOCAL statement_timeout='25s';
DO $verify$ BEGIN
 IF (SELECT before FROM v307_sources) IS DISTINCT FROM pg_temp.v307_source_fingerprint()
 THEN RAISE EXCEPTION 'V307 source or financial rows changed';END IF;
 IF EXISTS(SELECT 1 FROM v307_cases WHERE before_payload IS DISTINCT FROM after_payload)
 THEN RAISE EXCEPTION 'V307 complete native response changed';END IF;
 IF EXISTS(SELECT 1 FROM v307_attributes a JOIN pg_proc p ON p.oid=a.oid
 WHERE a.j IS DISTINCT FROM jsonb_build_object('oid',p.oid,'owner',p.proowner,'acl',p.proacl,
 'config',p.proconfig,'definer',p.prosecdef,'volatility',p.provolatile))
 THEN RAISE EXCEPTION 'V307 existing attributes changed';END IF;
END $verify$;
SELECT jsonb_build_object('status','PASS','full_native_cases',(SELECT count(*) FROM v307_cases),
 'complete_json_exact',true,'existing_attributes_exact',true,'source_tables_exact',20,'transaction','ROLLBACK',
 'case','__CASE__','after_timeout','__AFTER_TIMEOUT__','role','authenticated','cold_memos',true,
 'before_ms',(SELECT before_ms FROM v307_cases),'after_ms',(SELECT after_ms FROM v307_cases),
 'days',(SELECT jsonb_array_length(after_payload#>'{flow,historical,days}') FROM v307_cases),
 'before_checksum',(SELECT md5(before_payload::text) FROM v307_cases),
 'after_checksum',(SELECT md5(after_payload::text) FROM v307_cases),
 'source_fingerprints',(SELECT before FROM v307_sources)) receipt;
ROLLBACK;
""".replace('__FROM__',bounds[0]).replace('__TO__',bounds[1])
   .replace('__AFTER_TIMEOUT__','8s' if case=='year' else '25s').replace('__CASE__',case))

