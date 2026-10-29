"""Run the real V366 writer with the V376 patch in PostgreSQL 17.

Only synthetic users and financial records are used. The existing writer suite
continues to cover validity, cancellation, variable rules, ACLs and owner RLS.
"""
import contextlib
import io
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
with contextlib.redirect_stdout(io.StringIO()) as output:
    runpy.run_path(str(ROOT / "backend/qa/lts_v366_ci_sql.py"))
base = output.getvalue()
base = base.replace("CREATE SCHEMA v366_fixture;", "")
base = base.replace("SCHEMA v366_fixture TO", "SCHEMA public TO")
base = base.replace("v366_fixture.", "public.")
base = base.replace("ns.nspname='v366_fixture'", "ns.nspname='public'")
marker = "SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);"
prefix, tail = base.split(marker, 1)
patch = (ROOT / "backend/patches/v376/full_five_year_horizon.sql").read_text()
tail = tail.replace("IF n<40 OR n>60", "IF n<60 OR n>72")
tail = tail.replace("extract(year FROM next_year)+4", "extract(year FROM next_year)+5")
print(prefix)
print("""
CREATE TEMP TABLE v376_meta AS
SELECT to_jsonb(p)-'prosrc' metadata,pg_get_functiondef(p.oid) definition
FROM pg_proc p WHERE p.oid='public.lts_recurring_materialize_v366(uuid,date)'::regprocedure;
""")
print(patch)
print("""
DO $test$
DECLARE scope date;r jsonb;u uuid:='00000000-0000-4000-8000-000000000001';
BEGIN
 FOR scope IN SELECT unnest(ARRAY[
  current_date,
  make_date(extract(year FROM current_date)::integer+1,1,1),
  make_date(extract(year FROM current_date)::integer+1,12,31),
  make_date(extract(year FROM current_date)::integer+2,1,1),
  '2040-02-29'::date
 ]) LOOP
  r:=public.lts_recurring_materialize_v366(u,scope);
  IF (r->>'horizon_end')::date<(scope+interval '5 years')::date
   OR (r->>'horizon_end')::date<>(date_trunc('year',scope)+interval '6 years'-interval '1 day')::date
   OR (r->>'created')::integer<>0
  THEN RAISE EXCEPTION 'Full five-year boundary failed: %, %',scope,r;END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM public.evento_base)
 OR EXISTS(SELECT 1 FROM public.lts_recurring_plan_v366)
 OR EXISTS(SELECT 1 FROM public.lts_recurring_occurrence_v366)
 OR EXISTS(SELECT 1 FROM public.audit_log) THEN RAISE EXCEPTION 'Empty rules wrote financial state';END IF;
 IF (SELECT metadata FROM v376_meta) IS DISTINCT FROM
  (SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid='public.lts_recurring_materialize_v366(uuid,date)'::regprocedure)
 THEN RAISE EXCEPTION 'Worker metadata or ACL changed';END IF;
END $test$;
CREATE TEMP TABLE v376_replay AS
SELECT pg_get_functiondef('public.lts_recurring_materialize_v366(uuid,date)'::regprocedure) definition;
""")
print(patch)
print("""
DO $test$BEGIN
 IF (SELECT definition FROM v376_replay) IS DISTINCT FROM
 pg_get_functiondef('public.lts_recurring_materialize_v366(uuid,date)'::regprocedure)
 THEN RAISE EXCEPTION 'Replay changed worker';END IF;
END $test$;
""")
print("DO $drift$\nDECLARE definition text;rejected boolean:=false;\nBEGIN\n")
print(" SELECT pg_get_functiondef('public.lts_recurring_materialize_v366(uuid,date)'::regprocedure) INTO definition;")
print(" BEGIN\n  EXECUTE replace(definition,'Invalid recurrence scope','Synthetic scope drift');")
print("  EXECUTE $patch_text$" + patch + "$patch_text$;")
print(""" EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'V376 recurrence worker changed after installation' THEN RAISE;END IF;
  rejected:=true;
 END;
 IF NOT rejected THEN RAISE EXCEPTION 'Unexpected worker drift accepted';END IF;
 IF definition IS DISTINCT FROM pg_get_functiondef('public.lts_recurring_materialize_v366(uuid,date)'::regprocedure)
 THEN RAISE EXCEPTION 'Drift rejection left altered worker';END IF;
END $drift$;
""")
extra = """
SELECT jsonb_build_object(
 'version',376,'pass',true,'at_least_five_full_future_years',true,
 'year_start_end_and_leap_day',true,'native_real_worker',true,
 'existing_writer_suite',true,'empty_rules_no_financial_writes',true,
 'metadata_and_acl_unchanged',true,'patch_replay_noop',true,
 'drift_rejected',true,'synthetic_native',true);
ROLLBACK;
"""
assert tail.count("ROLLBACK;") == 1
print(marker + tail.replace("ROLLBACK;", extra))
