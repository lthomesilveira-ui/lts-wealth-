#!/usr/bin/env python3
"""Compose V415's exact migration over disposable, synthetic PostgreSQL fixtures.

The guarded predecessors are exact read-only function-definition snapshots. No
production function guard is relaxed. Heavy dependencies are replaced only after
the exact migration has passed its predecessor and metadata checks.
"""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
QA = ROOT / "backend/qa"


def original_browser() -> str:
    text = (ROOT / "backend/patches/v357/readers.sql").read_text()
    prefix = "CREATE OR REPLACE FUNCTION public.lts_browser_product_v1()"
    start = text.index(prefix)
    body = text.index("AS $function$", start) + len("AS $function$")
    end = text.index("$function$", body) + len("$function$")
    return text[start:end] + ";\n"


def fixture() -> str:
    predecessors = (QA / "fixtures/v415_guarded_predecessors.sql").read_text()
    if original_browser().strip().removesuffix(";") not in predecessors:
        raise SystemExit("Browser predecessor must match the immutable V357 patch")
    return "\n".join([
        (QA / "fixtures/v415_durable_refresh_setup.sql").read_text(),
        (ROOT / "backend/patches/v269/lts_flow_card_completeness_v269.sql").read_text(),
        predecessors,
        """
REVOKE ALL ON FUNCTION public.lts_browser_product_v1() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_browser_product_v1() TO authenticated,service_role;
CREATE TABLE qa_v415.original_functions(signature text PRIMARY KEY,definition text,attributes jsonb,body_md5 text);
INSERT INTO qa_v415.original_functions
SELECT p.oid::regprocedure::text,pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc',md5(pg_get_functiondef(p.oid))
FROM pg_proc p WHERE p.oid IN('public.lts_browser_product_v1()'::regprocedure,
 'lts_projection_private_v412.invalidate_reads(uuid)'::regprocedure,
 'lts_projection_private_v412.refresh()'::regprocedure,
 'public.lts_product_read_cached_v1(uuid)'::regprocedure,
 'public.lts_recurring_maintenance_v366()'::regprocedure,
 'public.lts_refresh_product_read_cache_operational_v5(uuid)'::regprocedure,
 'public.lts_refresh_product_read_cache_v2(uuid)'::regprocedure,
 'public.lts_c6_completeness_state_v269(uuid)'::regprocedure,
 'public.lts_has_card_presentation_v269()'::regprocedure,
 'public.lts_product_card_completeness_v269(jsonb,jsonb)'::regprocedure);
""",
    ])


def migration_file() -> Path:
    files = list((ROOT / "supabase/migrations").glob("*_v415*.sql"))
    if len(files) != 1:
        raise SystemExit("Expected exactly one reviewed V415 migration")
    return files[0]


def compose(*, setup_only: bool = False, fixture_only: bool = False) -> str:
    parts = [fixture()]
    if fixture_only:
        return "\n".join(parts)
    migration = migration_file()
    text = migration.read_text()
    source = (ROOT / "backend/patches/v415/durable_product_refresh.sql").read_text()
    if source != text:
        raise SystemExit("V415 migration and reviewed patch must be byte-identical")
    replay = "\n".join(line for line in text.splitlines() if line.strip() not in {"BEGIN;", "COMMIT;"})
    # The cron command literals also contain BEGIN/COMMIT; preserve those exact
    # strings by removing only the migration's leading/trailing transaction pair.
    first_begin = text.index("\nBEGIN;")
    final_commit = text.rindex("\nCOMMIT;")
    replay = text[:first_begin] + text[first_begin:].replace("\nBEGIN;", "", 1)
    replay = replay[:replay.rindex("\nCOMMIT;")] + replay[replay.rindex("\nCOMMIT;") + len("\nCOMMIT;"):]
    literal = "'" + replay.replace("'", "''") + "'"
    if not setup_only:
        parts.append("""
DO $predecessor_guard$
DECLARE ec text;em text;definition text;BEGIN
 BEGIN
  SELECT replace(o.definition,'AS $function$','AS $function$'||E'\\n-- synthetic predecessor divergence')
   INTO definition FROM qa_v415.original_functions o WHERE signature='lts_browser_product_v1()';
  EXECUTE definition;
  EXECUTE """ + literal + """;
 EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS ec=RETURNED_SQLSTATE,em=MESSAGE_TEXT;END;
 PERFORM qa_v415.check('predecessor mismatch rejects whole migration without mutation',
  ec='P0001' AND em='Unexpected V415 predecessor: public.lts_browser_product_v1()'
  AND to_regnamespace('lts_product_refresh_private_v415') IS NULL
  AND(SELECT bool_and(body_md5=md5(pg_get_functiondef(signature::regprocedure))) FROM qa_v415.original_functions),
  jsonb_build_object('error_code',ec));
END $predecessor_guard$;
""")
    parts += [text, """
CREATE TABLE qa_v415.installed_functions AS
SELECT p.oid::regprocedure::text AS signature,pg_get_functiondef(p.oid) AS definition,
 to_jsonb(p)-'prosrc' AS attributes,md5(pg_get_functiondef(p.oid)) AS body_md5
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='lts_product_refresh_private_v415'
 OR p.oid IN('public.lts_browser_product_v1()'::regprocedure,
  'lts_projection_private_v412.invalidate_reads(uuid)'::regprocedure,
  'public.lts_browser_product_refresh_status_v415()'::regprocedure,
  'public.lts_browser_product_refresh_request_v415()'::regprocedure)
 OR p.oid IN(SELECT signature::regprocedure FROM qa_v415.original_functions);
"""]
    if not setup_only:
        parts.append("""
DO $replay_guard$
DECLARE ec text;em text;BEGIN
 BEGIN EXECUTE """ + literal + """;
 EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS ec=RETURNED_SQLSTATE,em=MESSAGE_TEXT;END;
 PERFORM qa_v415.check('reapplication is rejected with all installed functions intact',
  ec='P0001' AND em='V415 namespace already exists'
  AND(SELECT bool_and(body_md5=md5(pg_get_functiondef(signature::regprocedure))) FROM qa_v415.installed_functions),
  jsonb_build_object('error_code',ec));
END $replay_guard$;
""")
    parts.append("""
DO $synthetic_dependencies$
DECLARE r record;BEGIN
 FOR r IN SELECT definition FROM qa_v415.stub_functions LOOP EXECUTE r.definition;END LOOP;
END $synthetic_dependencies$;
""")
    checks = (QA / "v415_durable_refresh_checks.sql").read_text()
    parts.append(checks.split("DO $metadata$", 1)[0] if setup_only else checks)
    return "\n".join(parts)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--setup-only", action="store_true", help="Install fixture and exact migration for native multi-session checks")
    parser.add_argument("--fixture-only", action="store_true", help="Check fixture syntax before the reviewed migration is available")
    parser.add_argument("--manifest", action="store_true", help="Print reproducible source hashes, not SQL")
    args = parser.parse_args()
    if args.manifest:
        migration = migration_file()
        paths = [migration, Path(__file__), QA / "fixtures/v415_durable_refresh_setup.sql", QA / "fixtures/v415_guarded_predecessors.sql", QA / "v415_durable_refresh_checks.sql"]
        print(json.dumps({"files": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}}, indent=2))
    else:
        print(compose(setup_only=args.setup_only, fixture_only=args.fixture_only))
