"""Synthetic V303 dependencies plus complete JSON parity for V306."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
base = subprocess.run([sys.executable, str(ROOT / 'backend/qa/lts_v303_ci_sql.py')],
                      check=True, capture_output=True, text=True).stdout
footer = "SELECT current_setting('lts.v303.synthetic_receipt')::jsonb receipt; ROLLBACK;"
assert footer in base
base = base[:base.rindex(footer)]
patch = (ROOT / 'backend/patches/v306/materialized_audit_coverage.sql').read_text()
# Normalize only the isolated test schema for the actual inspected-definition lease.
patch = patch.replace('public.', 'v303_fixture.')
patch = patch.replace('md5(d)', "md5(replace(d,'v303_fixture.','public.'))")
print(base)
print("""
CREATE TEMP TABLE v306_cases(as_of date,horizon date,payload jsonb);
INSERT INTO v306_cases(as_of,horizon) VALUES
 ('2020-04-11','2020-06-30'),('2020-04-12','2020-06-30'),
 ('2020-04-15','2020-06-30'),('2020-04-20','2020-06-30'),
 ('2020-04-20','2020-04-21'),('2020-12-31','2021-12-31'),(NULL,NULL);
UPDATE v306_cases SET payload=v303_fixture.lts_recurring_future_gap_audit_v6(
 '00000000-0000-4000-8000-000000000001',as_of,horizon);
CREATE TEMP TABLE v306_attributes AS SELECT jsonb_build_object('oid',oid,'owner',proowner,'acl',proacl,
 'config',proconfig,'definer',prosecdef,'volatility',provolatile) j FROM pg_proc
 WHERE oid='v303_fixture.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure;
""")
print(patch)
print("""
DO $verify$ BEGIN
 IF EXISTS(SELECT 1 FROM v306_cases WHERE payload IS DISTINCT FROM
 v303_fixture.lts_recurring_future_gap_audit_v6('00000000-0000-4000-8000-000000000001',as_of,horizon))
 THEN RAISE EXCEPTION 'Complete audit JSON changed';END IF;
 IF (SELECT j FROM v306_attributes) IS DISTINCT FROM(SELECT jsonb_build_object('oid',oid,'owner',proowner,'acl',proacl,
 'config',proconfig,'definer',prosecdef,'volatility',provolatile) FROM pg_proc
 WHERE oid='v303_fixture.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure)
 THEN RAISE EXCEPTION 'Audit security or identity attributes changed';END IF;
END $verify$;
CREATE TEMP TABLE v306_replay AS SELECT pg_get_functiondef(
 'v303_fixture.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure) definition;
""")
print(patch)
print("""
DO $verify$ BEGIN
 IF (SELECT definition FROM v306_replay) IS DISTINCT FROM pg_get_functiondef(
 'v303_fixture.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure)
 THEN RAISE EXCEPTION 'Replay changed definition';END IF;
END $verify$;
SELECT jsonb_build_object('status','PASS','complete_response_cases',(SELECT count(*) FROM v306_cases),
 'original_attributes_exact',true,'replay_noop',true,
 'v303_dependency_doubles_not_receipt_certification',current_setting('lts.v303.synthetic_receipt')::jsonb) receipt;
ROLLBACK;
""")
