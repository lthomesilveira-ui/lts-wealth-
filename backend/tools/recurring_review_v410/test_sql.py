"""Emit bounded synthetic SQL for PostgreSQL17; all inputs come from versioned code."""
from pathlib import Path
import hashlib

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
old=(ROOT/'backend/patches/v371/confirmed_calendar_coverage.sql').read_text().split('new_definition text:=$new_definition$',1)[1].split('$new_definition$;',1)[0]
assert hashlib.md5(old.encode()).hexdigest()=='8b1e3201ebed90f75659a02c20c2bba9'
foundation=(ROOT/'backend/qa/lts_v303_fixture.sql').read_text().split('INSERT INTO',1)[0]
foundation=foundation.replace('CREATE SCHEMA v303_fixture;','').replace('v303_fixture.','public.')
print('BEGIN;')
print("DO $$ BEGIN IF NOT EXISTS(SELECT1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role; END IF; END $$;".replace('SELECT1','SELECT 1'))
print(foundation)
print((ROOT/'backend/qa/fixtures/v366_series_key.sql').read_text())
print((HERE/'setup.sql').read_text())
print(old+';')
print("REVOKE ALL ON FUNCTION public.lts_recurring_future_gap_audit_v6(uuid,date,date) FROM PUBLIC; GRANT EXECUTE ON FUNCTION public.lts_recurring_future_gap_audit_v6(uuid,date,date) TO service_role;")
print("CREATE TEMP TABLE v410_before AS SELECT public.lts_recurring_future_gap_audit_v6('00000000-0000-4000-8000-000000000001','2026-11-04','2031-12-31')payload;")
print("CREATE TEMP TABLE v410_other_before AS SELECT public.lts_recurring_future_gap_audit_v6('00000000-0000-4000-8000-000000000002','2026-11-04','2031-12-31')payload;")
print("CREATE TEMP TABLE v410_attributes AS SELECT to_jsonb(p)-'prosrc'-'prolang' attributes FROM pg_proc p WHERE oid='public.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure;")
print((ROOT/'backend/patches/v410/persistent_review_scope.sql').read_text())
print((HERE/'verify.sql').read_text())
print((ROOT/'backend/patches/v410/persistent_review_scope.sql').read_text())
print((ROOT/'backend/patches/v410/rollback.sql').read_text())
print("DO $$ BEGIN IF md5(pg_get_functiondef('public.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure))<>'8b1e3201ebed90f75659a02c20c2bba9' THEN RAISE EXCEPTION 'Rollback definition differs'; END IF; END $$;")
print("SELECT '{\"replay_and_rollback\":true}'::jsonb AS v410_replay_proof; ROLLBACK;")
