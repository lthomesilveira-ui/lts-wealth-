"""Actual leased audit body, with isolated synthetic dependencies and owner decisions."""
from pathlib import Path
import subprocess,sys
R=Path(__file__).resolve().parents[2]
base=subprocess.run([sys.executable,str(R/'backend/qa/lts_v334_ci_sql.py')],check=True,capture_output=True,text=True).stdout
assert base.rstrip().endswith('ROLLBACK;')
print(base[:base.rindex('ROLLBACK;')])
print(r'''
CREATE TABLE v303_fixture.lts_projection_replacement_rule(id text,user_id uuid,source_table text,description_exact text,account_exact text,
date_from date,date_to date,action text,replacement_source text,replacement_ref text,reason text,evidence jsonb,active boolean);
INSERT INTO v303_fixture.evento_base VALUES('00000000-0000-4000-8000-000000000001',80,'{"dia":"2020-05-01","desc":"English Class","conta":"Itaú","efeito":"saida","valor":680}');
INSERT INTO v303_fixture.lts_projection_replacement_rule VALUES('synthetic-cancel','00000000-0000-4000-8000-000000000001','evento_base','English Class','Itaú','2020-05-01','2020-05-01','suppress_legacy','owner_confirmation','evento_base:80','One original occurrence cancelled','{"scope":"one_original_occurrence","legacy_ref":"evento_base:80"}',true);
CREATE OR REPLACE FUNCTION v303_fixture.lts_recurring_future_gap_audit_v4(uuid,date)
RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"items":[{"description":"English Class","direction":"expense","review_kind":"planning_review","recurrence_pattern":"frequent_monthly"},{"description":"netflix","direction":"expense","review_kind":"planning_review","recurrence_pattern":"frequent_monthly"}],"covered_count":0}'::jsonb $$;
-- This dependency double represents an occurrence already removed by the existing flow rule.
CREATE OR REPLACE FUNCTION v303_fixture.lts_corrected_cashflow_operational_v1(uuid,date,date)
RETURNS TABLE(event_date date,description text,source text,source_ref text,confidence text,signed_amount numeric,account text)
LANGUAGE sql AS $$ SELECT (dados->>'dia')::date,dados->>'desc','legacy_fix86','evento_base:'||idx,
'legacy_projection_adjusted',CASE WHEN dados->>'efeito'='entrada' THEN 1 ELSE -1 END*(dados->>'valor')::numeric,dados->>'conta'
FROM v303_fixture.evento_base WHERE usuario_id=$1 AND idx<>80 AND (dados->>'dia')::date BETWEEN $2 AND $3 $$;
CREATE TEMP TABLE v360_before AS SELECT v303_fixture.lts_recurring_future_gap_audit_v6('00000000-0000-4000-8000-000000000001','2020-04-20','2020-06-30')j;
CREATE TEMP TABLE v360_attrs AS SELECT to_jsonb(p)-'prosrc' j FROM pg_proc p WHERE oid='v303_fixture.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure;
CREATE TEMP TABLE v360_raw AS SELECT jsonb_build_object('raw',(SELECT jsonb_agg(to_jsonb(x)ORDER BY idx)FROM v303_fixture.evento_base x),
'rules',(SELECT jsonb_agg(to_jsonb(x)ORDER BY id)FROM v303_fixture.lts_projection_replacement_rule x),
'financial',(SELECT jsonb_agg(to_jsonb(x)ORDER BY id)FROM v303_fixture.financial_events x),
'staging',(SELECT jsonb_agg(to_jsonb(x)ORDER BY id)FROM v303_fixture.lts_open_finance_staging x))j;
''')
patch=(R/'backend/patches/v360/confirmed_cancelled_occurrences.sql').read_text().replace('public.','v303_fixture.')
patch=patch.replace('md5(definition)',"md5(replace(definition,'v303_fixture.','public.'))").replace('md5(restored)',"md5(replace(restored,'v303_fixture.','public.'))")
print(patch)
print(r'''
DO $test$DECLARE j jsonb;x jsonb;y jsonb;period jsonb;BEGIN
j:=v303_fixture.lts_recurring_future_gap_audit_v6('00000000-0000-4000-8000-000000000001','2020-04-20','2020-06-30');
IF(j-'horizon_checks')IS DISTINCT FROM(SELECT b.j-'horizon_checks'FROM v360_before b)THEN RAISE EXCEPTION 'Unrelated top-level data changed';END IF;
FOR x IN SELECT value FROM jsonb_array_elements(j->'horizon_checks')LOOP
 SELECT value INTO y FROM v360_before b CROSS JOIN LATERAL jsonb_array_elements(b.j->'horizon_checks')WHERE value->>'key'=x->>'key';
 IF x->>'key'<>'english class'AND x IS DISTINCT FROM y THEN RAISE EXCEPTION 'Other series changed';END IF;
 IF x->>'key'='english class'THEN
  IF(x->>'gap_count')::int<>(y->>'gap_count')::int-1 OR(x->'missing_months')?'2020-05'OR NOT((x->'missing_months')?'2020-06')
  OR jsonb_array_length(x->'owner_confirmed_exceptions')<>1 THEN RAISE EXCEPTION 'Exact exception not separated';END IF;
  SELECT value INTO period FROM jsonb_array_elements(x->'period_coverage')WHERE value->>'period_start'='2020-05-01';
  IF period->>'status'<>'cancelled_by_owner'OR period->>'actual_events'<>'0'OR period->>'future_events'<>'0'
  OR period#>>'{confirmed_exceptions,0,source_ref}'<>'evento_base:80' THEN RAISE EXCEPTION 'Cancellation confused with payment';END IF;
  IF(SELECT jsonb_agg(v)FROM jsonb_array_elements(x->'period_coverage')v WHERE v->>'period_start'<>'2020-05-01')
  IS DISTINCT FROM(SELECT jsonb_agg(v)FROM jsonb_array_elements(y->'period_coverage')v WHERE v->>'period_start'<>'2020-05-01')THEN RAISE EXCEPTION 'Other month changed';END IF;
 END IF;
END LOOP;
END $test$;
CREATE TEMP TABLE v360_cases(name text,mutation text);
INSERT INTO v360_cases VALUES
('inactive',$q$UPDATE v303_fixture.lts_projection_replacement_rule SET active=false$q$),
('other owner',$q$UPDATE v303_fixture.lts_projection_replacement_rule SET user_id='00000000-0000-4000-8000-000000000099'$q$),
('wrong source',$q$UPDATE v303_fixture.lts_projection_replacement_rule SET source_table='other'$q$),
('inferred decision',$q$UPDATE v303_fixture.lts_projection_replacement_rule SET replacement_source='inferred'$q$),
('wrong reference',$q$UPDATE v303_fixture.lts_projection_replacement_rule SET replacement_ref='evento_base:999'$q$),
('broad scope',$q$UPDATE v303_fixture.lts_projection_replacement_rule SET evidence=jsonb_set(evidence,'{scope}','"all_future"')$q$),
('conflicting proof',$q$UPDATE v303_fixture.lts_projection_replacement_rule SET evidence=jsonb_set(evidence,'{legacy_ref}','"evento_base:999"')$q$),
('broader dates',$q$UPDATE v303_fixture.lts_projection_replacement_rule SET date_from='2020-04-01'$q$),
('changed description',$q$UPDATE v303_fixture.evento_base SET dados=jsonb_set(dados,'{desc}','"Another class"')WHERE idx=80$q$),
('changed account',$q$UPDATE v303_fixture.evento_base SET dados=jsonb_set(dados,'{conta}','"Other bank"')WHERE idx=80$q$),
('income',$q$UPDATE v303_fixture.evento_base SET dados=jsonb_set(dados,'{efeito}','"entrada"')WHERE idx=80$q$),
('zero',$q$UPDATE v303_fixture.evento_base SET dados=jsonb_set(dados,'{valor}','0')WHERE idx=80$q$),
('ambiguous raw',$q$INSERT INTO v303_fixture.evento_base SELECT*FROM v303_fixture.evento_base WHERE idx=80$q$);
DO $test$DECLARE r record;j jsonb;BEGIN
FOR r IN SELECT*FROM v360_cases LOOP
 BEGIN EXECUTE r.mutation;
  j:=v303_fixture.lts_recurring_future_gap_audit_v6('00000000-0000-4000-8000-000000000001','2020-04-20','2020-06-30');
  IF j IS DISTINCT FROM(SELECT b.j FROM v360_before b)THEN RAISE EXCEPTION 'Unqualified cancellation accepted: %',r.name;END IF;
  RAISE EXCEPTION USING ERRCODE='V3600',MESSAGE='rollback fixture';
 EXCEPTION WHEN SQLSTATE'V3600'THEN NULL;END;
END LOOP;
IF(SELECT a.j FROM v360_attrs a)IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid='v303_fixture.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure)THEN RAISE EXCEPTION 'Attributes changed';END IF;
IF(SELECT a.j FROM v360_raw a)IS DISTINCT FROM(SELECT jsonb_build_object('raw',(SELECT jsonb_agg(to_jsonb(x)ORDER BY idx)FROM v303_fixture.evento_base x),
'rules',(SELECT jsonb_agg(to_jsonb(x)ORDER BY id)FROM v303_fixture.lts_projection_replacement_rule x),
'financial',(SELECT jsonb_agg(to_jsonb(x)ORDER BY id)FROM v303_fixture.financial_events x),
'staging',(SELECT jsonb_agg(to_jsonb(x)ORDER BY id)FROM v303_fixture.lts_open_finance_staging x)))THEN RAISE EXCEPTION 'Sources mutated';END IF;
END $test$;
CREATE TEMP TABLE v360_replay AS SELECT pg_get_functiondef('v303_fixture.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure)definition;
''')
print(patch)
print(r'''
DO $test$BEGIN IF(SELECT definition FROM v360_replay)IS DISTINCT FROM pg_get_functiondef('v303_fixture.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure)THEN RAISE EXCEPTION 'Replay changed definition';END IF;END $test$;
SELECT jsonb_build_object('pass',true,'version',360,'invalid_cases',(SELECT count(*)FROM v360_cases),'raw_preserved',true,'attributes_preserved',true,
'other_series_periods_exact',true,'cancellation_not_payment',true,'replay_noop',true,
'projection',v303_fixture.lts_recurring_future_gap_audit_v6('00000000-0000-4000-8000-000000000001','2020-04-20','2020-06-30'));
ROLLBACK;
''')
