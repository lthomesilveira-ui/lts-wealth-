#!/usr/bin/env python3
"""Compose disposable native-PG17 tests; never connects to a database.

The main gate installs the exact checked migration. Normalized source adapters
are replaced only inside the disposable core fixture; the actual source adapters
have a separate isolated database and their own negative coverage checks.
"""
from pathlib import Path
import argparse

ROOT = Path(__file__).resolve().parents[3]
PATCH = ROOT / "backend/patches/v412"
QA = ROOT / "backend/qa"
MIGRATION = ROOT / "supabase/migrations/20261104192749_v412_owner_projection_policy.sql"
ORDER = ["schema.sql", "cache.sql", "base_flow.sql", "source_adapter.sql",
         "calculation.sql", "reference_state.sql", "orchestration.sql", "integration.sql"]


def read(path):
    return Path(path).read_text()


def quote(value):
    return "'" + value.replace("'", "''") + "'"


def without_transaction(sql):
    return "\n".join(line for line in sql.splitlines()
                     if line.strip() not in {"BEGIN;", "COMMIT;"})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-adapter-only", action="store_true")
    parser.add_argument("--patches", action="store_true",
                        help="Local development only: compose current source parts before artifact freeze")
    args = parser.parse_args()
    setup = read(QA / "fixtures/v412_source_adapter_setup.sql")
    if args.source_adapter_only:
        print(setup)
        print(read(PATCH / "source_adapter.sql"))
        print(read(QA / "v412_source_adapter_checks.sql"))
        return
    migration = ("BEGIN;\n" + "\n".join(read(PATCH / part) for part in ORDER) + "\nCOMMIT;"
                 if args.patches else read(MIGRATION))
    print(setup)
    print(read(QA / "v412_fixture.sql"))
    print(read(QA / "fixtures/v366_series_key.sql"))
    print(read(QA / "fixtures/v412_predecessors.sql"))
    print("""
REVOKE ALL ON FUNCTION public.lts_corrected_cashflow_operational_v1(uuid,date,date),
 public.lts_recurring_maintenance_v366() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_corrected_cashflow_operational_v1(uuid,date,date),
 public.lts_recurring_maintenance_v366() TO service_role;
INSERT INTO qa_v412.protected_before
SELECT p.oid::regprocedure::text,p.proacl::text,p.proowner,p.proconfig,p.prosecdef,md5(pg_get_functiondef(p.oid))
FROM pg_proc p WHERE p.oid IN('public.lts_corrected_cashflow_operational_v1(uuid,date,date)'::regprocedure,
 'public.lts_recurring_maintenance_v366()'::regprocedure);
""")
    print(migration)
    print("""
INSERT INTO qa_v412.installed_definitions
SELECT p.oid::regprocedure::text,md5(pg_get_functiondef(p.oid)) FROM pg_proc p
WHERE p.pronamespace='lts_projection_private_v412'::regnamespace
 OR p.oid IN('public.lts_corrected_cashflow_operational_v1(uuid,date,date)'::regprocedure,
 'public.lts_recurring_maintenance_v366()'::regprocedure,
 'public.lts_browser_projection_policy_v412()'::regprocedure,
 'public.lts_browser_projection_refresh_v412()'::regprocedure);
""")
    print(migration)
    print("""
SELECT qa_v412.assert('exact migration replay preserves installed functions',NOT EXISTS(
 SELECT 1 FROM qa_v412.installed_definitions d
 WHERE d.md5 IS DISTINCT FROM md5(pg_get_functiondef(to_regprocedure(d.signature)))));
SELECT qa_v412.assert('generic migration creates no owner policy audit or forecast',
 (SELECT count(*) FROM public.legacy_namespace)=0 AND(SELECT count(*) FROM public.audit_log)=0
 AND(SELECT count(*) FROM qa_v412.raw_flow)=0);
""")
    print(read(QA / "v412_price_checks.sql"))
    print(read(QA / "v412_verify.sql"))
    rollback = read(PATCH / "rollback.sql")
    print(rollback)
    print("""
SELECT qa_v412.assert('rollback restores both predecessor definitions',NOT EXISTS(
 SELECT 1 FROM qa_v412.protected_before b
 WHERE b.md5 IS DISTINCT FROM md5(pg_get_functiondef(to_regprocedure(b.signature)))));
SELECT qa_v412.assert('rollback disables both public projection RPCs',
 public.lts_browser_projection_policy_v412()->>'enabled'='false'
 AND public.lts_browser_projection_refresh_v412()->>'enabled'='false');
SELECT qa_v412.assert('rollback preserves evidence policy reference audit and financial sources',
 (SELECT value FROM qa_v412.saved WHERE name='metadata_before_rollback')=jsonb_build_object(
 'namespace',(SELECT coalesce(jsonb_agg(to_jsonb(n)ORDER BY id),'[]')FROM public.legacy_namespace n),
 'audit',(SELECT coalesce(jsonb_agg(to_jsonb(a)ORDER BY id),'[]')FROM public.audit_log a),
 'financial_hash',qa_v412.financial_hash()));
""")
    print(migration)
    print("""
SELECT qa_v412.assert('reinstall after rollback restores the exact generic reader',NOT EXISTS(
 SELECT 1 FROM qa_v412.installed_definitions d
 WHERE d.md5 IS DISTINCT FROM md5(pg_get_functiondef(to_regprocedure(d.signature)))));
""")
    install = read(PATCH / "integration.sql")
    for signature, label in [
        ("public.lts_corrected_cashflow_operational_v1(uuid,date,date)", "operational reader"),
        ("public.lts_recurring_maintenance_v366()", "maintenance"),
    ]:
        print(f"""
DO $drift$
DECLARE original text:=pg_get_functiondef({quote(signature)}::regprocedure);
BEGIN
 EXECUTE replace(original,'-- lts-projection-v412:','-- synthetic-drift-v412:');
 PERFORM qa_v412.expect_error({quote('install refuses drift in '+label)},{quote(install)});
 PERFORM qa_v412.expect_error({quote('rollback refuses drift in '+label)},
  {quote(without_transaction(rollback))});
 EXECUTE original;
END $drift$;
""")
    print("""
SELECT jsonb_build_object('pass',bool_and(pass),'checks',count(*),
 'runtime',version(),'scope','Synthetic PG17 core, actual migration, source adapters tested separately',
 'tests',jsonb_agg(jsonb_build_object('name',name,'pass',pass)ORDER BY name))FROM qa_v412.results;
""")


if __name__ == "__main__":
    main()

