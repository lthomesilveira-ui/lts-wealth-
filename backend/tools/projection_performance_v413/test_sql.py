#!/usr/bin/env python3
"""Compose disposable PG17 tests of the exact V413 migration and full builder parity."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
QA=ROOT/"backend/qa"

def compose():
    parts=[]
    def add(sql):
        parts.append(sql.rstrip()+"\n")
    for name in ["fixtures/v412_source_adapter_setup.sql","v412_fixture.sql",
                 "fixtures/v366_series_key.sql","fixtures/v412_predecessors.sql"]:
        add((QA/name).read_text())
    add("""
REVOKE ALL ON FUNCTION public.lts_corrected_cashflow_operational_v1(uuid,date,date),
 public.lts_recurring_maintenance_v366() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_corrected_cashflow_operational_v1(uuid,date,date),
 public.lts_recurring_maintenance_v366() TO service_role;
INSERT INTO qa_v412.protected_before
SELECT p.oid::regprocedure::text,p.proacl::text,p.proowner,p.proconfig,p.prosecdef,md5(pg_get_functiondef(p.oid))
FROM pg_proc p WHERE p.oid IN('public.lts_corrected_cashflow_operational_v1(uuid,date,date)'::regprocedure,
 'public.lts_recurring_maintenance_v366()'::regprocedure);
""")
    add((ROOT/"supabase/migrations/20261104192749_v412_owner_projection_policy.sql").read_text())
    add("""
CREATE SCHEMA qa_v413;
CREATE TABLE qa_v413.migration_checks(name text PRIMARY KEY,pass boolean NOT NULL CHECK(pass));
CREATE TABLE qa_v413.installed(before_attributes jsonb,after_definition_md5 text,after_attributes jsonb);
INSERT INTO qa_v413.installed(before_attributes)
SELECT to_jsonb(p)-'prosrc' FROM pg_proc p
WHERE p.oid='lts_projection_private_v412.build(uuid,date)'::regprocedure;
DO $copy$
DECLARE definition text:=pg_get_functiondef('lts_projection_private_v412.build(uuid,date)'::regprocedure);
BEGIN
 IF position('FUNCTION lts_projection_private_v412.build(' IN definition)=0
  THEN RAISE EXCEPTION 'Unexpected original builder signature';END IF;
 EXECUTE replace(definition,'FUNCTION lts_projection_private_v412.build(',
  'FUNCTION lts_projection_private_v412.build_before_v413(');
END $copy$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.build_before_v413(uuid,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.build_before_v413(uuid,date) TO service_role;
""")
    migrations=list((ROOT/"supabase/migrations").glob("*_v413_bootstrap_projection_performance.sql"))
    if len(migrations)!=1:
        raise SystemExit("Expected exactly one V413 bootstrap migration")
    migration=migrations[0].read_text()
    builder_source=(ROOT/"backend/patches/v413/build.sql").read_text().strip()
    if migration.count(builder_source)!=1:
        raise SystemExit("V413 migration must contain exactly the reviewed builder source")
    add(migration)
    add("""
UPDATE qa_v413.installed SET
 after_definition_md5=md5(pg_get_functiondef('lts_projection_private_v412.build(uuid,date)'::regprocedure)),
 after_attributes=(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p
  WHERE p.oid='lts_projection_private_v412.build(uuid,date)'::regprocedure);
INSERT INTO qa_v413.migration_checks
SELECT 'exact migration preserves every function attribute including ACL owner STABLE and config',
 before_attributes=after_attributes FROM qa_v413.installed;
""")
    replay="\n".join(line for line in migration.splitlines()
                     if line.strip() not in {"BEGIN;","COMMIT;"})
    replay_literal="'"+replay.replace("'","''")+"'"
    add("""
DO $replay_guard$
DECLARE error_code text;error_message text;
BEGIN
 BEGIN EXECUTE """+replay_literal+""";
 EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS
  error_code=RETURNED_SQLSTATE,error_message=MESSAGE_TEXT;END;
 INSERT INTO qa_v413.migration_checks
 SELECT 'predecessor-only guard rejects replay and preserves the installed function',
  error_code='P0001'
  AND error_message='V413 projection builder predecessor differs; review before applying'
  AND after_definition_md5=md5(pg_get_functiondef('lts_projection_private_v412.build(uuid,date)'::regprocedure))
  AND after_attributes=(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p
   WHERE p.oid='lts_projection_private_v412.build(uuid,date)'::regprocedure)
 FROM qa_v413.installed;
END $replay_guard$;
ALTER FUNCTION lts_projection_private_v412.build(uuid,date) RENAME TO build_candidate_v413;
CREATE TABLE qa_v413.results(name text PRIMARY KEY, pass boolean NOT NULL CHECK(pass), old_error text,
 old_ms numeric, candidate_ms numeric, output_sha256 text, events int);
CREATE FUNCTION qa_v413.compare(p_user uuid,p_as_of date)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' SET TimeZone='America/Sao_Paulo' AS $f$
DECLARE a jsonb;b jsonb;ac text;am text;bc text;bm text;
BEGIN
 BEGIN a:=lts_projection_private_v412.build_before_v413(p_user,p_as_of);
 EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS ac=RETURNED_SQLSTATE,am=MESSAGE_TEXT;END;
 BEGIN b:=lts_projection_private_v412.build_candidate_v413(p_user,p_as_of);
 EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS bc=RETURNED_SQLSTATE,bm=MESSAGE_TEXT;END;
 IF ac IS DISTINCT FROM bc OR am IS DISTINCT FROM bm OR a IS DISTINCT FROM b THEN
  RAISE EXCEPTION 'V413 differential mismatch, as_of %, old error % %, new error % %',
   p_as_of,ac,am,bc,bm USING DETAIL=jsonb_build_object('old',a,'candidate',b)::text;
 END IF;
 IF ac IS NOT NULL THEN RAISE EXCEPTION USING ERRCODE=ac,MESSAGE=am;END IF;
 RETURN b;
END $f$;
CREATE FUNCTION lts_projection_private_v412.build(p_user_id uuid,p_as_of date)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' SET TimeZone='America/Sao_Paulo' AS $f$
 SELECT qa_v413.compare(p_user_id,p_as_of)
$f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.build(uuid,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.build(uuid,date) TO service_role;
CREATE FUNCTION qa_v413.check_case(p_name text,p_as_of date,p_owner uuid DEFAULT qa_v412.owner())
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE a jsonb;b jsonb;ac text;am text;bc text;bm text;old_ms numeric;new_ms numeric;t timestamptz;h text;
BEGIN
 h:=qa_v412.financial_hash();t:=clock_timestamp();
 BEGIN a:=lts_projection_private_v412.build_before_v413(p_owner,p_as_of);
 EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS ac=RETURNED_SQLSTATE,am=MESSAGE_TEXT;END;
 old_ms:=extract(epoch FROM clock_timestamp()-t)*1000;t:=clock_timestamp();
 BEGIN b:=lts_projection_private_v412.build_candidate_v413(p_owner,p_as_of);
 EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS bc=RETURNED_SQLSTATE,bm=MESSAGE_TEXT;END;
 new_ms:=extract(epoch FROM clock_timestamp()-t)*1000;
 IF ac IS DISTINCT FROM bc OR am IS DISTINCT FROM bm OR a IS DISTINCT FROM b OR h<>qa_v412.financial_hash() THEN
  RAISE EXCEPTION 'V413 differential mismatch: %, old error % %, new error % %',p_name,ac,am,bc,bm
   USING DETAIL=jsonb_build_object('old',a,'candidate',b)::text;
 END IF;
 INSERT INTO qa_v413.results VALUES(p_name,true,ac,old_ms,new_ms,
  encode(sha256(convert_to(b::text,'UTF8')),'hex'),jsonb_array_length(b->'events'));
END $f$;
""")
    add((QA/"v412_verify.sql").read_text())
    add((QA/"v413_builder_differential_edges.sql").read_text())
    add("""
SELECT jsonb_build_object(
 'pass',(SELECT bool_and(pass) FROM qa_v412.results)
  AND(SELECT bool_and(pass) FROM qa_v413.results)
  AND(SELECT bool_and(pass) FROM qa_v413.migration_checks),
 'runtime',version(),'scope','Disposable synthetic PostgreSQL; exact migration and full JSONB differential builder verification',
 'installed_builder_definition_md5',(SELECT after_definition_md5 FROM qa_v413.installed),
 'migration_checks',(SELECT count(*) FROM qa_v413.migration_checks),
 'v412_behavior_checks',(SELECT count(*) FROM qa_v412.results),
 'edge_cases',(SELECT count(*) FROM qa_v413.results),
 'equal_json_payload_cases',(SELECT count(*) FROM qa_v413.results WHERE old_error IS NULL),
 'equal_error_cases',(SELECT count(*) FROM qa_v413.results WHERE old_error IS NOT NULL),
 'migration',(SELECT jsonb_agg(to_jsonb(r) ORDER BY name) FROM qa_v413.migration_checks r),
 'original_behavior',(SELECT jsonb_agg(to_jsonb(r)-'detail' ORDER BY name) FROM qa_v412.results r),
 'differential',(SELECT jsonb_agg(to_jsonb(r) ORDER BY name) FROM qa_v413.results r));
""")
    return "\n".join(parts)

if __name__=="__main__":
    print(compose())
