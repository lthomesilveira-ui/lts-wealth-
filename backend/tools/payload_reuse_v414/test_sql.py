#!/usr/bin/env python3
"""Compose disposable exact-migration tests of V414 full payload parity and call counts."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
QA = ROOT / "backend/qa"


def compose():
    parts = [(QA / "fixtures/v414_payload_reuse_setup.sql").read_text()]
    migrations = list((ROOT / "supabase/migrations").glob("*_v414_payload_single_evaluation.sql"))
    if len(migrations) != 1:
        raise SystemExit("Expected exactly one V414 payload migration")
    migration = migrations[0].read_text()
    source = (ROOT / "backend/patches/v414/payload_reuse.sql").read_text().strip()
    if migration.count(source) != 1:
        raise SystemExit("V414 migration must contain exactly the reviewed source")
    replay = "\n".join(line for line in migration.splitlines() if line.strip() not in {"BEGIN;", "COMMIT;"})
    literal = "'" + replay.replace("'", "''") + "'"
    parts.append("""
CREATE ROLE v414_other_definer;
DO $definer_guard$
DECLARE ec text;em text;BEGIN
 BEGIN
  ALTER FUNCTION public.lts_dashboard_horizon_v1(uuid) OWNER TO v414_other_definer;
  EXECUTE """ + literal + """;
  RAISE EXCEPTION 'V414 differing definer owners unexpectedly accepted';
 EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS ec=RETURNED_SQLSTATE,em=MESSAGE_TEXT;END;
 INSERT INTO qa_v414.migration_checks
 SELECT 'different definer owners rejected and original metadata restored',
  ec='P0001' AND em='V414 horizon and MVP definer owners must match'
  AND bool_and(before_md5=md5(pg_get_functiondef(signature::regprocedure)))
  AND bool_and(before_attributes=(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=signature::regprocedure))
 FROM qa_v414.installed;
END $definer_guard$;
""")
    parts += [migration, """
UPDATE qa_v414.installed i SET after_attributes=to_jsonb(p)-'prosrc',after_md5=md5(pg_get_functiondef(p.oid))
FROM pg_proc p WHERE p.oid=i.signature::regprocedure;
INSERT INTO qa_v414.migration_checks
SELECT 'all function attributes preserved: '||signature,before_attributes=after_attributes FROM qa_v414.installed;
INSERT INTO qa_v414.migration_checks
SELECT 'standalone horizon body unchanged',before_md5=after_md5 FROM qa_v414.installed
WHERE signature='lts_dashboard_horizon_v1(uuid)';
"""]
    parts.append("""
DO $replay_guard$
DECLARE ec text;em text;BEGIN
 BEGIN EXECUTE """ + literal + """;
 EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS ec=RETURNED_SQLSTATE,em=MESSAGE_TEXT;END;
 INSERT INTO qa_v414.migration_checks
 SELECT 'predecessor-only replay rejected without mutation',
  ec='P0001' AND em='V414 payload predecessor differs: public.lts_product_payload_fix86_v2(uuid); review before applying'
  AND bool_and(after_md5=md5(pg_get_functiondef(signature::regprocedure)))
  AND bool_and(after_attributes=(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=signature::regprocedure))
 FROM qa_v414.installed;
END $replay_guard$;
""")
    parts.append((QA / "v414_payload_reuse_checks.sql").read_text())
    return "\n".join(parts)


if __name__ == "__main__":
    print(compose())
