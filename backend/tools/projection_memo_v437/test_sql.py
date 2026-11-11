#!/usr/bin/env python3
"""Disposable PG17 checks of the exact V437 migration and memo boundaries."""
from pathlib import Path
import importlib.util

ROOT=Path(__file__).resolve().parents[3]
source=ROOT/'backend/tools/projection_performance_v413/test_sql.py'
spec=importlib.util.spec_from_file_location('v413_fixture',source)
fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)

def compose():
    # Reuse the normalized synthetic source adapters and existing projection engine.
    # No production source data, accounts, credentials or user identifiers are used.
    prefix=fixture.compose().split('CREATE SCHEMA qa_v413;',1)[0]
    migrations=list((ROOT/'supabase/migrations').glob('*_v437_statement_projection_memo.sql'))
    assert len(migrations)==1
    predecessor=(ROOT/'backend/qa/fixtures/v437/build_before.sql').read_text()
    migration=migrations[0].read_text()
    parts=[prefix,predecessor,"""
CREATE SCHEMA qa_v437;
CREATE SCHEMA lts_product_refresh_private_v415;
CREATE FUNCTION lts_product_refresh_private_v415.card_source_key(uuid)RETURNS text LANGUAGE sql STABLE AS $$
 SELECT 'synthetic:'||qa_v412.financial_hash()
$$;
ALTER FUNCTION lts_projection_private_v412.monthly_source_facts_v412(uuid,date,date,jsonb)
 RENAME TO monthly_source_facts_before_v437;
CREATE FUNCTION lts_projection_private_v412.monthly_source_facts_v412(uuid,date,date,jsonb)
RETURNS TABLE(series_key text,month date,amount_brl numeric,coverage text,source_kind text,
 source_refs jsonb,raw_hashes jsonb,observed_days jsonb) LANGUAGE plpgsql STABLE AS $$
BEGIN
 PERFORM set_config('qa.v437_computations',(coalesce(nullif(current_setting('qa.v437_computations',true),''),'0')::int+1)::text,true);
 RETURN QUERY SELECT * FROM lts_projection_private_v412.monthly_source_facts_before_v437($1,$2,$3,$4);
END $$;
CREATE TABLE qa_v437.attributes(before_value jsonb);
INSERT INTO qa_v437.attributes SELECT to_jsonb(p)-'prosrc' FROM pg_proc p
 WHERE p.oid='lts_projection_private_v412.build(uuid,date)'::regprocedure;
DO $$BEGIN EXECUTE replace(pg_get_functiondef('lts_projection_private_v412.build(uuid,date)'::regprocedure),
 'FUNCTION lts_projection_private_v412.build(', 'FUNCTION lts_projection_private_v412.build_before_v437(');END$$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.build_before_v437(uuid,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.build_before_v437(uuid,date) TO service_role;
""",migration,"""
SELECT qa_v412.assert('V437 preserves every catalog attribute except body',
 (SELECT before_value FROM qa_v437.attributes)=(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p
 WHERE p.oid='lts_projection_private_v412.build(uuid,date)'::regprocedure));
""",migration,"""
SELECT qa_v412.assert('replay is idempotent and preserves attributes',
 (SELECT before_value FROM qa_v437.attributes)=(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p
 WHERE p.oid='lts_projection_private_v412.build(uuid,date)'::regprocedure));
CREATE FUNCTION qa_v437.computations()RETURNS int LANGUAGE sql AS $$
 SELECT coalesce(nullif(current_setting('qa.v437_computations',true),''),'0')::int
$$;
DO $checks$
DECLARE a jsonb;b jsonb;c jsonb;memo text;key_before text;h text;n int;
 u uuid:=qa_v412.owner();v uuid:=qa_v412.owner(2);d date:='2020-11-04';
BEGIN
 PERFORM qa_v412.reset();
 PERFORM qa_v412.set_policy(qa_v412.policy('fixed','{"amount_brl":120,"due_day":15}'));
 h:=qa_v412.financial_hash();
 a:=lts_projection_private_v412.build_before_v437(u,d);
 PERFORM set_config('qa.v437_computations','0',true);
 PERFORM set_config('lts.projection_memo_v437','',true);
 b:=lts_projection_private_v412.build(u,d);
 PERFORM qa_v412.assert('cold result is exactly equal to unchanged full builder',a=b);
 PERFORM qa_v412.assert('cold result computes once',qa_v437.computations()=1);
 c:=lts_projection_private_v412.build(u,d);
 PERFORM qa_v412.assert('same state reuses byte-identical result without calculation',b=c AND qa_v437.computations()=1);
 PERFORM qa_v412.assert('memo creates no financial writes',h=qa_v412.financial_hash());
 memo:=current_setting('lts.projection_memo_v437',true);
 PERFORM set_config('lts.projection_memo_v437','{malformed',true);
 c:=lts_projection_private_v412.build(u,d);
 PERFORM qa_v412.assert('malformed optional memo recomputes safely',c=b AND qa_v437.computations()=2);
 PERFORM set_config('lts.projection_memo_v437',jsonb_set(memo::jsonb,'{digest}','"wrong"')::text,true);
 c:=lts_projection_private_v412.build(u,d);
 PERFORM qa_v412.assert('changed payload digest recomputes safely',c=b AND qa_v437.computations()=3);
 c:=lts_projection_private_v412.build(u,d+1);
 PERFORM qa_v412.assert('different as-of date cannot reuse prior result',
  c=lts_projection_private_v412.build_before_v437(u,d+1) AND qa_v437.computations()>=4);
 c:=lts_projection_private_v412.build(v,d);
 PERFORM qa_v412.assert('owner without policy never inherits another owner result',c->>'enabled'='false');
 PERFORM qa_v412.set_policy(qa_v412.policy('fixed','{"amount_brl":999,"due_day":15}'),v);
 c:=lts_projection_private_v412.build(v,d);
 PERFORM qa_v412.assert('different owner policy produces independent exact result',
  c=lts_projection_private_v412.build_before_v437(v,d) AND c<>b);
 PERFORM qa_v412.set_policy(qa_v412.policy('fixed','{"amount_brl":220,"due_day":15}'));
 c:=lts_projection_private_v412.build(u,d);
 PERFORM qa_v412.assert('policy mutation invalidates memo within the same statement',
  c=lts_projection_private_v412.build_before_v437(u,d) AND c<>b);
 n:=qa_v437.computations();
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1;
 c:=lts_projection_private_v412.build(u,d);
 PERFORM qa_v412.assert('source epoch invalidates memo even without output change',qa_v437.computations()=n+1);
 n:=qa_v437.computations();
 INSERT INTO qa_v412.raw_flow(event_date,account,description,signed_amount,source,source_ref,confidence)
 VALUES('2020-11-15','Itaú','synthetic',-20,'document','synthetic-receipt','confirmed');
 c:=lts_projection_private_v412.build(u,d);
 PERFORM qa_v412.assert('receipt fingerprint invalidates without an epoch increment',
  c=lts_projection_private_v412.build_before_v437(u,d) AND qa_v437.computations()>=n+2);
 n:=qa_v437.computations();
 PERFORM qa_v412.set_reference(qa_v412.reference());
 c:=lts_projection_private_v412.build(u,d);
 PERFORM qa_v412.assert('reference mutation invalidates within the statement',
  c=lts_projection_private_v412.build_before_v437(u,d) AND qa_v437.computations()>=n+2);
 PERFORM set_config('lts.product_refresh_claim',jsonb_build_object('user_id',u)::text,true);
 PERFORM set_config('lts.projection_summary_v418','',true);
 b:=lts_projection_private_v412.build(u,current_date);
 a:=nullif(current_setting('lts.projection_summary_v418',true),'')::jsonb;
 PERFORM set_config('lts.projection_summary_v418','',true);
 n:=qa_v437.computations();c:=lts_projection_private_v412.build(u,current_date);
 PERFORM qa_v412.assert('cache hit preserves the existing worker summary hook',
  b=c AND qa_v437.computations()=n
   AND a=nullif(current_setting('lts.projection_summary_v418',true),'')::jsonb);
 PERFORM set_config('lts.product_refresh_claim','',true);
END $checks$;
SELECT qa_v412.assert('private schema and ACL do not grant browser access',
 NOT has_schema_privilege('anon','lts_projection_private_v412','USAGE')
 AND NOT has_function_privilege('authenticated','lts_projection_private_v412.build(uuid,date)','EXECUTE'));
COMMIT;
BEGIN READ ONLY;
DO $read_only$
DECLARE a jsonb;b jsonb;
BEGIN
 PERFORM set_config('lts.projection_memo_v437','',true);
 a:=lts_projection_private_v412.build(qa_v412.owner(),'2020-11-04');
 b:=lts_projection_private_v412.build(qa_v412.owner(),'2020-11-04');
 IF a IS DISTINCT FROM b THEN RAISE EXCEPTION 'Read-only memo differs';END IF;
 PERFORM set_config('qa.v437_read_only','true',false);
END $read_only$;
COMMIT;
SELECT qa_v412.assert('read-only transaction can reuse the projection',
 current_setting('qa.v437_read_only',true)='true');
SELECT qa_v412.assert('projection memo never survives transaction completion',
 nullif(current_setting('lts.projection_memo_v437',true),'') IS NULL);
SELECT jsonb_build_object('pass',bool_and(pass),'checks',count(*),'runtime',version(),
 'scope','Synthetic memo boundaries, exact migration, no real sessions or device certification',
 'cases',jsonb_agg(name ORDER BY name)) FROM qa_v412.results;
"""]
    return '\n'.join(parts)

if __name__=='__main__': print(compose())
