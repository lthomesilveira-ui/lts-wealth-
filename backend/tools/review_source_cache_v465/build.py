"""Memoize exactly the original primary-input hashes under complete DML/DDL guards."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SCHEMA = 'lts_product_refresh_private_v415'
PROFILE = '3344fae485b34b6cf29a939801ab492e'
ORIGINAL = '47af1960816e108d7fa90e3c8917de44'
GUARD = SCHEMA + '.review_guard_v450(uuid)'
TABLES = json.loads((ROOT/'source-tables.json').read_text())
md5 = lambda s: hashlib.md5(s.encode()).hexdigest()
shape = """SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text)"""

def trigger_name(t): return 'lts_review_input_v465_' + md5(t['schema']+'.'+t['name'])[:12]

def build():
 original=(ROOT/'guard-original.sql').read_text()
 assert md5(original)==ORIGINAL
 trigger_body="""
BEGIN
 UPDATE lts_product_refresh_private_v415.review_input_epoch_v465 SET revision=revision+1 WHERE singleton;
 IF NOT FOUND THEN RAISE EXCEPTION 'review input revision unavailable';END IF;
 RETURN NULL;
END
"""
 trigger=f"""CREATE OR REPLACE FUNCTION {SCHEMA}.review_input_changed_v465() RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function${trigger_body}$function$;
REVOKE ALL ON FUNCTION {SCHEMA}.review_input_changed_v465() FROM PUBLIC,anon,authenticated,service_role;
"""
 contract_body=f"""
DECLARE item jsonb; c record; target_oid oid; actual text; seen integer:=0;
BEGIN
 IF current_user<>'postgres' OR current_setting('session_replication_role')<>'origin' THEN RETURN false;END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang
  WHERE p.oid=to_regprocedure('{SCHEMA}.review_input_changed_v465()')
  AND md5(p.prosrc)='{md5(trigger_body)}' AND p.prosecdef AND p.provolatile='v'
  AND pg_get_userbyid(p.proowner)='postgres' AND l.lanname='plpgsql'
  AND p.proconfig=ARRAY['search_path=""']::text[]) THEN RETURN false;END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(p_profile->'tables') LOOP
  SELECT * INTO c FROM {SCHEMA}.review_input_contract_v465 x
   WHERE x.schema_name=item->>'schema' AND x.table_name=item->>'name';
  IF NOT FOUND OR item->>'kind'<>'r' OR (item->>'epoch')::boolean IS DISTINCT FROM false THEN RETURN false;END IF;
  target_oid:=to_regclass(format('%I.%I',c.schema_name,c.table_name));
  IF target_oid IS DISTINCT FROM c.relation_oid THEN RETURN false;END IF;
  IF EXISTS(SELECT 1 FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid) THEN RETURN false;END IF;
  {shape} INTO actual;
  IF actual IS DISTINCT FROM c.shape_hash THEN RETURN false;END IF;
  SELECT md5(t.oid::text||':'||t.xmin::text||':'||pg_get_triggerdef(t.oid)) INTO actual FROM pg_trigger t
   WHERE t.tgrelid=target_oid AND t.tgname=c.trigger_name AND t.tgenabled='A' AND NOT t.tgisinternal;
  IF actual IS DISTINCT FROM c.trigger_hash THEN RETURN false;END IF;
  seen:=seen+1;
 END LOOP;
 RETURN seen={len(TABLES)} AND seen=(SELECT count(*) FROM {SCHEMA}.review_input_contract_v465)
  AND EXISTS(SELECT 1 FROM {SCHEMA}.review_input_epoch_v465 WHERE singleton);
EXCEPTION WHEN undefined_table OR undefined_column OR undefined_function OR insufficient_privilege THEN RETURN false;
END
"""
 contract=f"""CREATE OR REPLACE FUNCTION {SCHEMA}.review_input_contract_ok_v465(p_profile jsonb) RETURNS boolean
 LANGUAGE plpgsql STABLE SET search_path TO '' AS $function${contract_body}$function$;
REVOKE ALL ON FUNCTION {SCHEMA}.review_input_contract_ok_v465(jsonb) FROM PUBLIC,anon,authenticated,service_role;
"""
 old_decl='rel regclass; owner_column text;'
 new_decl=old_decl+" reuse boolean:=false; cache_hit boolean:=false; input_revision bigint; input_epoch bigint; found_hashes jsonb; old_lock text;"
 assert original.count(old_decl)==1
 after=original.replace(old_decl,new_decl)
 point=" FOR item IN SELECT value FROM jsonb_array_elements(profile->'tables') LOOP"
 start=after.index(point); end=after.index(" RETURN jsonb_build_object('owner'",start)
 loop=after[start:end]
 before=f""" -- Reuse only exact full-row hashes, under a pinned producer profile and a
 -- complete statement-trigger/schema contract. All original checks above run.
 IF current_user='postgres' AND md5(profile::text)='{PROFILE}' AND EXISTS(
  SELECT 1 FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang
  WHERE p.oid=to_regprocedure('{SCHEMA}.review_input_contract_ok_v465(jsonb)')
  AND md5(p.prosrc)='{md5(contract_body)}' AND NOT p.prosecdef AND p.provolatile='s'
  AND pg_get_userbyid(p.proowner)='postgres' AND l.lanname='plpgsql'
  AND p.proconfig=ARRAY['search_path=""']::text[]) THEN
  reuse:={SCHEMA}.review_input_contract_ok_v465(profile);
 END IF;
 IF reuse THEN
  SELECT revision INTO input_revision FROM {SCHEMA}.review_input_epoch_v465 WHERE singleton;
  SELECT epoch INTO input_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton;
  SELECT c.hashes INTO found_hashes FROM {SCHEMA}.review_input_hash_cache_v465 c
   WHERE c.user_id=p_user_id AND c.source_revision=input_revision AND c.financial_epoch=input_epoch
   AND c.as_of=current_date AND c.profile_hash=md5(profile::text)
   AND jsonb_typeof(c.hashes)='object' AND c.digest=md5(c.hashes::text);
  IF FOUND AND (SELECT count(*) FROM jsonb_object_keys(found_hashes))=jsonb_array_length(profile->'tables')
   AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(profile->'tables') x
    WHERE NOT coalesce((found_hashes->>(x->>'schema'||'.'||(x->>'name'))) ~ '^[0-9a-f]{{32}}$',false)) THEN
   primary_hashes:=found_hashes;cache_hit:=true;
  END IF;
 END IF;
 IF NOT cache_hit THEN
"""
 tail=f"""  IF reuse AND NOT current_setting('transaction_read_only')::boolean
   AND input_revision=(SELECT revision FROM {SCHEMA}.review_input_epoch_v465 WHERE singleton)
   AND input_epoch=(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton) THEN
   old_lock:=current_setting('lock_timeout');
   BEGIN
    IF old_lock::interval=interval '0' OR old_lock::interval>interval '100 milliseconds' THEN PERFORM set_config('lock_timeout','100ms',true);END IF;
    INSERT INTO {SCHEMA}.review_input_hash_cache_v465(user_id,source_revision,financial_epoch,as_of,profile_hash,hashes,digest)
    VALUES(p_user_id,input_revision,input_epoch,current_date,md5(profile::text),primary_hashes,md5(primary_hashes::text))
    ON CONFLICT(user_id) DO UPDATE SET source_revision=excluded.source_revision,financial_epoch=excluded.financial_epoch,
     as_of=excluded.as_of,profile_hash=excluded.profile_hash,hashes=excluded.hashes,digest=excluded.digest;
    PERFORM set_config('lock_timeout',old_lock,true);
   EXCEPTION WHEN lock_not_available OR read_only_sql_transaction THEN NULL;END;
  END IF;
 END IF;
"""
 after=after[:start]+before+loop+tail+after[end:]
 # Any observed revision race disables this call's cached result, exactly as a
 # concurrent source change disables the caller's original end-of-read guard.
 check=f""" IF cache_hit AND (input_revision IS DISTINCT FROM (SELECT revision FROM {SCHEMA}.review_input_epoch_v465 WHERE singleton)
  OR input_epoch IS DISTINCT FROM(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Review sources changed during read';
 END IF;
"""
 pos=after.index(" RETURN jsonb_build_object('owner'");after=after[:pos]+check+after[pos:]
 setup=f"""CREATE TABLE {SCHEMA}.review_input_epoch_v465(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),revision bigint NOT NULL);
INSERT INTO {SCHEMA}.review_input_epoch_v465 VALUES(true,0);
CREATE TABLE {SCHEMA}.review_input_contract_v465(schema_name text,table_name text,relation_oid oid NOT NULL,shape_hash text NOT NULL,trigger_name text NOT NULL,trigger_hash text NOT NULL,PRIMARY KEY(schema_name,table_name));
CREATE TABLE {SCHEMA}.review_input_hash_cache_v465(user_id uuid PRIMARY KEY,source_revision bigint NOT NULL,financial_epoch bigint NOT NULL,as_of date NOT NULL,profile_hash text NOT NULL,hashes jsonb NOT NULL,digest text NOT NULL);
REVOKE ALL ON {SCHEMA}.review_input_epoch_v465,{SCHEMA}.review_input_contract_v465,{SCHEMA}.review_input_hash_cache_v465 FROM PUBLIC,anon,authenticated,service_role;
"""
 install_start=f"""BEGIN;
SET LOCAL search_path TO '';
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='10s';
DO $check$DECLARE u uuid;BEGIN
 IF md5(pg_get_functiondef('{GUARD}'::regprocedure))<>'{ORIGINAL}' OR md5({SCHEMA}.review_profile_v450()::text)<>'{PROFILE}' THEN RAISE EXCEPTION 'V465 original source contract changed';END IF;
 IF EXISTS(SELECT 1 FROM {SCHEMA}.queue WHERE state IN('pending','running')) THEN RAISE EXCEPTION 'Existing refresh must finish first';END IF;
 FOR u IN SELECT user_id FROM {SCHEMA}.queue LOOP IF NOT pg_try_advisory_xact_lock(hashtextextended(u::text,415)) THEN RAISE EXCEPTION 'V465 worker lock busy';END IF;END LOOP;
END $check$;
"""
 statements=[]
 for t in TABLES:
  name=trigger_name(t);relation=t['schema']+'.'+t['name']
  statements.append(f'CREATE TRIGGER {name} AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON {relation} FOR EACH STATEMENT EXECUTE FUNCTION {SCHEMA}.review_input_changed_v465();')
  statements.append(f'ALTER TABLE {relation} ENABLE ALWAYS TRIGGER {name};')
  statements.append(f"DO $capture$DECLARE target_oid oid:='{relation}'::regclass; actual text;BEGIN {shape} INTO actual;INSERT INTO {SCHEMA}.review_input_contract_v465 VALUES('{t['schema']}','{t['name']}',target_oid,actual,'{name}',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='{name}'));END $capture$;")
 install=install_start+setup+trigger+'\n'+'\n'.join(statements)+'\n'+contract+'\n'+after+';\nCOMMIT;\n'
 rollback="BEGIN;\nSET LOCAL search_path TO '';\n"+original+';\n'
 for t in TABLES:rollback+=f"DROP TRIGGER {trigger_name(t)} ON {t['schema']}.{t['name']};\n"
 rollback+=f"DROP FUNCTION {SCHEMA}.review_input_contract_ok_v465(jsonb);\nDROP FUNCTION {SCHEMA}.review_input_changed_v465();\nDROP TABLE {SCHEMA}.review_input_hash_cache_v465,{SCHEMA}.review_input_contract_v465,{SCHEMA}.review_input_epoch_v465;\nCOMMIT;\n"
 files={'guard-after.sql':after,'trigger.sql':trigger,'contract.sql':contract,'setup-cache.sql':setup,'install.sql':install,'rollback.sql':rollback}
 for name,content in files.items():(ROOT/name).write_text(content)
 manifest={'version':'v465','profile_json_md5':PROFILE,'original_guard_md5':ORIGINAL,'primary_source_tables':len(TABLES),'source_hash_algorithm_unchanged':True,'owner_bound':True,'financial_source_writes':False,'authentication_changed':False,'timeouts_changed':False,'fallback_on_unknown_contract':True,'files':{n:hashlib.sha256(c.encode()).hexdigest()for n,c in files.items()}}
 (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 return files

if __name__=='__main__':build();print(json.dumps({'pass':True,'version':'v465','primary_source_tables':len(TABLES)}))
