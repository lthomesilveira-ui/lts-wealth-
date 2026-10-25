"""Exercise the leased audit body with exact synthetic posted-receipt cases."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
base = subprocess.run([sys.executable, str(ROOT / 'backend/qa/lts_v306_ci_sql.py')],
                      check=True, capture_output=True, text=True).stdout
footer = "SELECT jsonb_build_object('status','PASS','complete_response_cases'"
assert footer in base
print(base[:base.rindex(footer)])
print("""
CREATE OR REPLACE FUNCTION v303_fixture.lts_recurring_future_gap_audit_v4(uuid,date)
RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"items":[{"description":"netflix","direction":"expense","review_kind":"planning_review","recurrence_pattern":"frequent_monthly"}],"covered_count":0}'::jsonb $$;
INSERT INTO v303_fixture.lts_open_finance_staging VALUES
('00000000-0000-4000-8000-000000000040','00000000-0000-4000-8000-000000000001','2020-04-14',-15,'transaction','BRL',NULL,
'{"status":"POSTED","account_type":"CHECKING_ACCOUNT"}','341','Itaú','Débito automático DEB AUTOR NETFLIX.COM');
CREATE TEMP TABLE v334_baseline(as_of date,horizon date,payload jsonb);
INSERT INTO v334_baseline(as_of,horizon) VALUES('2020-04-13','2020-06-30'),('2020-04-14','2020-06-30'),('2020-04-20','2020-06-30');
UPDATE v334_baseline SET payload=v303_fixture.lts_recurring_future_gap_audit_v6('00000000-0000-4000-8000-000000000001',as_of,horizon);
CREATE TEMP TABLE v334_attributes AS SELECT to_jsonb(p)-'prosrc' j FROM pg_proc p WHERE oid='v303_fixture.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure;
CREATE TEMP TABLE v334_sources AS SELECT jsonb_build_object(
 'staging',(SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM v303_fixture.lts_open_finance_staging t),
 'projections',(SELECT jsonb_agg(to_jsonb(t) ORDER BY idx) FROM v303_fixture.evento_base t)) j;
""")
patch = (ROOT / 'backend/patches/v334/received_merchant_alias.sql').read_text()
patch = patch.replace('public.', 'v303_fixture.')
patch = patch.replace('md5(definition)', "md5(replace(definition,'v303_fixture.','public.'))")
patch = patch.replace('md5(replace(definition,replacement,anchor))',
                      "md5(replace(replace(definition,replacement,anchor),'v303_fixture.','public.'))")
print(patch)
print("""
DO $test$
DECLARE b record;j jsonb;x jsonb;y jsonb;
BEGIN
 FOR b IN SELECT * FROM v334_baseline LOOP
  j:=v303_fixture.lts_recurring_future_gap_audit_v6('00000000-0000-4000-8000-000000000001',b.as_of,b.horizon);
  IF b.as_of<'2020-04-14' AND j IS DISTINCT FROM b.payload THEN RAISE EXCEPTION 'Future source counted early';END IF;
  IF (j-'horizon_checks') IS DISTINCT FROM (b.payload-'horizon_checks') THEN RAISE EXCEPTION 'Unrelated response changed';END IF;
  FOR x IN SELECT value FROM jsonb_array_elements(j->'horizon_checks') LOOP
   SELECT value INTO y FROM jsonb_array_elements(b.payload->'horizon_checks') WHERE value->>'key'=x->>'key';
   IF x->>'key'<>'netflix' AND x IS DISTINCT FROM y THEN RAISE EXCEPTION 'Unrelated series changed';END IF;
   IF x->>'key'='netflix' THEN
    IF (SELECT jsonb_agg(p) FROM jsonb_array_elements(x->'period_coverage')p WHERE p->>'period_start'>'2020-04-01')
    IS DISTINCT FROM(SELECT jsonb_agg(p) FROM jsonb_array_elements(y->'period_coverage')p WHERE p->>'period_start'>'2020-04-01')
    THEN RAISE EXCEPTION 'Future coverage changed';END IF;
    IF b.as_of>='2020-04-14' AND (x#>>'{period_coverage,0,actual_events}'<>'1' OR x#>>'{period_coverage,0,status}'<>'covered')
    THEN RAISE EXCEPTION 'Exact posted receipt not counted';END IF;
   END IF;
  END LOOP;
 END LOOP;
END $test$;
CREATE TEMP TABLE v334_cases(name text,mutation text);
INSERT INTO v334_cases VALUES
('pending',$q$UPDATE v303_fixture.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{status}','"PENDING"') WHERE id::text LIKE '%0040'$q$),
('deleted',$q$UPDATE v303_fixture.lts_open_finance_staging SET provider_deleted_at=now() WHERE id::text LIKE '%0040'$q$),
('other owner',$q$UPDATE v303_fixture.lts_open_finance_staging SET user_id='00000000-0000-4000-8000-000000000099' WHERE id::text LIKE '%0040'$q$),
('currency',$q$UPDATE v303_fixture.lts_open_finance_staging SET currency='USD' WHERE id::text LIKE '%0040'$q$),
('refund',$q$UPDATE v303_fixture.lts_open_finance_staging SET signed_amount=15 WHERE id::text LIKE '%0040'$q$),
('card source',$q$UPDATE v303_fixture.lts_open_finance_staging SET resource_type='card_transaction' WHERE id::text LIKE '%0040'$q$),
('nonchecking',$q$UPDATE v303_fixture.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{account_type}','"CREDIT"') WHERE id::text LIKE '%0040'$q$),
('future date',$q$UPDATE v303_fixture.lts_open_finance_staging SET posting_date='2020-04-21' WHERE id::text LIKE '%0040'$q$),
('similar text',$q$UPDATE v303_fixture.lts_open_finance_staging SET description_raw='Netflix purchase through another merchant' WHERE id::text LIKE '%0040'$q$),
('explicit context',$q$CREATE OR REPLACE FUNCTION v303_fixture.lts_bank_known_classification_v231(uuid,uuid) RETURNS jsonb LANGUAGE sql AS $f$ SELECT '{"beneficiary":"Benjamin","category":"Saúde"}'::jsonb $f$$q$);
DO $test$
DECLARE r record;j jsonb;n integer;
BEGIN
 FOR r IN SELECT * FROM v334_cases LOOP
  BEGIN
   EXECUTE r.mutation;
   j:=v303_fixture.lts_recurring_future_gap_audit_v6('00000000-0000-4000-8000-000000000001','2020-04-20','2020-06-30');
   SELECT (x#>>'{period_coverage,0,actual_events}')::int INTO n FROM jsonb_array_elements(j->'horizon_checks')x WHERE x->>'key'='netflix';
   IF n<>0 THEN RAISE EXCEPTION 'Rejected source counted: %',r.name;END IF;
   RAISE EXCEPTION USING ERRCODE='V3340',MESSAGE='rollback synthetic mutation';
  EXCEPTION WHEN SQLSTATE 'V3340' THEN NULL;
  END;
 END LOOP;
 IF (SELECT a.j FROM v334_attributes a) IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE oid='v303_fixture.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure)
 THEN RAISE EXCEPTION 'Function attributes changed';END IF;
 IF (SELECT a.j FROM v334_sources a) IS DISTINCT FROM(SELECT jsonb_build_object(
 'staging',(SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM v303_fixture.lts_open_finance_staging t),
 'projections',(SELECT jsonb_agg(to_jsonb(t) ORDER BY idx) FROM v303_fixture.evento_base t)))
 THEN RAISE EXCEPTION 'Source records changed';END IF;
END $test$;
CREATE TEMP TABLE v334_replay AS SELECT pg_get_functiondef('v303_fixture.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure) definition;
""")
print(patch)
print("""
DO $test$ BEGIN
IF (SELECT definition FROM v334_replay) IS DISTINCT FROM pg_get_functiondef('v303_fixture.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure)
THEN RAISE EXCEPTION 'Replay changed audit';END IF;
END $test$;
SELECT jsonb_build_object('pass',true,'rejection_cases',(SELECT count(*) FROM v334_cases),'complete_response_cases',3,
'future_coverage_preserved',true,'attributes_exact',true,'source_records_unchanged',true,'replay_noop',true,'isolated_dependency_doubles',true) receipt;
ROLLBACK;
""")
