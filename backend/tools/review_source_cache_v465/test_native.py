"""Native PostgreSQL parity, invalidation, privilege and race tests; invented data only."""
import json
import subprocess
import unittest
from pathlib import Path
import build

ROOT=Path(__file__).resolve().parent
DB='lts_review_source_cache_v465'
U='00000000-0000-4000-8000-000000000001'
V='00000000-0000-4000-8000-000000000002'
S=build.SCHEMA

def sql(query,error=None):
 p=subprocess.run(['psql','-XAtq','-v','ON_ERROR_STOP=1','-d',DB],input=query,text=True,capture_output=True)
 if error:
  assert p.returncode and error in p.stderr,(error,p.stderr)
  return p.stderr
 if p.returncode:raise AssertionError(p.stderr)
 return p.stdout.strip()

def guard(owner=U,prefix=''):return json.loads(sql(prefix+f"SELECT {S}.review_guard_v450('{owner}');") or 'null')
def compare(owner=U,prefix=''):
 row=json.loads(sql(prefix+f"SELECT jsonb_build_array({S}.review_guard_v450('{owner}'),{S}.review_guard_baseline_v465('{owner}'));"))
 assert row[0]==row[1],row
 return row[0]

class SourceGuardCache(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  build.build();subprocess.run(['createdb',DB],check=True,capture_output=True)
  setup=f"CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;CREATE SCHEMA {S};CREATE SCHEMA lts_projection_private_v412;GRANT USAGE ON SCHEMA {S} TO service_role;"
  setup+="CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY,epoch bigint);INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);"
  for t in build.TABLES:
   setup+=f"CREATE TABLE {t['schema']}.{t['name']}(id bigserial PRIMARY KEY,user_id uuid,payload jsonb,state text DEFAULT 'ready');"
  setup+=f"CREATE TABLE {S}.fixture_profile(j jsonb);"
  setup+=f"CREATE FUNCTION {S}.review_profile_v450() RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT j FROM {S}.fixture_profile$$;"
  setup+=f"CREATE FUNCTION {S}.card_source_key(uuid) RETURNS text LANGUAGE sql STABLE AS $$SELECT 'synthetic-card:'||$1::text$$;"
  setup+="CREATE FUNCTION public.v465_fixture_producer() RETURNS integer LANGUAGE sql AS $$SELECT 1$$;"
  setup+=f"INSERT INTO {S}.fixture_profile SELECT jsonb_build_object('tables','{json.dumps(build.TABLES)}'::jsonb,'epoch_tables','[]'::jsonb,'views','[]'::jsonb,'producers',jsonb_build_array(jsonb_build_object('signature','public.v465_fixture_producer()','md5',md5(pg_get_functiondef('public.v465_fixture_producer()'::regprocedure)))));"
  sql(setup);sql((ROOT/'guard-original.sql').read_text())
  sql((ROOT/'guard-original.sql').read_text().replace('review_guard_v450(p_user_id','review_guard_baseline_v465(p_user_id',1))
  sql(f"REVOKE ALL ON FUNCTION {S}.review_guard_v450(uuid) FROM PUBLIC;GRANT EXECUTE ON FUNCTION {S}.review_guard_v450(uuid),{S}.review_profile_v450(),{S}.card_source_key(uuid) TO service_role;GRANT SELECT ON ALL TABLES IN SCHEMA public,{S} TO service_role;")
  cls.attrs=sql(f"SELECT (to_jsonb(p)-'prosrc')::text FROM pg_proc p WHERE oid='{S}.review_guard_v450(uuid)'::regprocedure;")
  fixture_hash=sql(f"SELECT md5({S}.review_profile_v450()::text);")
  # Only the recognized fixture profile digest differs from production. Source
  # hash algorithm, DML/DDL contract, privileges, cache and original guard stay exact.
  cls.install=(ROOT/'install.sql').read_text().replace(build.PROFILE,fixture_hash)
  sql(cls.install)

 def setUp(self):
  q=f"TRUNCATE {S}.review_input_hash_cache_v465;UPDATE public.lts_read_cache_epoch_v242 SET epoch=1;"
  for t in build.TABLES:q+=f"TRUNCATE {t['schema']}.{t['name']} RESTART IDENTITY;INSERT INTO {t['schema']}.{t['name']}(user_id,payload) VALUES('{U}','{{\"amount\":100,\"semantic\":\"original\"}}'),('{V}','{{\"amount\":50}}');"
  sql(q)

 def test_01_full_original_guard_parity_and_actual_reuse(self):
  first=compare();stamp=sql(f"SELECT xmin::text FROM {S}.review_input_hash_cache_v465 WHERE user_id='{U}';")
  self.assertTrue(stamp);self.assertEqual(compare(),first)
  self.assertEqual(sql(f"SELECT xmin::text FROM {S}.review_input_hash_cache_v465 WHERE user_id='{U}';"),stamp)
  self.assertEqual(first['owner'],U)

 def test_02_every_primary_table_invalidates_on_update(self):
  for t in build.TABLES:
   with self.subTest(table=t['name']):
    before=compare();sql(f"UPDATE {t['schema']}.{t['name']} SET payload=payload||'{{\"changed\":true}}' WHERE user_id='{U}';")
    self.assertNotEqual(compare(),before)

 def test_03_insert_delete_truncate_and_owner_reassignment(self):
  table='public.lts_open_finance_sync_run';before=compare()
  sql(f"INSERT INTO {table}(user_id,payload) VALUES('{U}','{{\"new\":1}}');");self.assertNotEqual(compare(),before)
  sql(f"DELETE FROM {table} WHERE payload->>'new'='1';");self.assertEqual(compare(),before)
  sql(f"UPDATE {table} SET user_id='{V}' WHERE user_id='{U}';");self.assertNotEqual(compare(),before)
  sql(f"TRUNCATE {table};");self.assertNotEqual(compare(V)['primary_hashes'][table],before['primary_hashes'][table])

 def test_04_all_row_fields_including_collection_status_still_count(self):
  before=compare();sql(f"UPDATE public.lts_open_finance_sync_run SET state='failed' WHERE user_id='{U}';")
  self.assertNotEqual(compare(),before)
  sql(f"UPDATE public.lts_open_finance_sync_run SET payload=payload||'{{\"future_unknown_field\":2}}' WHERE user_id='{U}';")
  self.assertNotEqual(compare(),before)

 def test_05_financial_epoch_and_calendar_and_owner_isolate_cache(self):
  a=compare();b=compare(V);self.assertNotEqual(a,b)
  sql('UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1;');self.assertNotEqual(compare(),a)
  sql(f"UPDATE {S}.review_input_hash_cache_v465 SET as_of=current_date-1;");self.assertEqual(compare()['owner'],U)

 def test_06_disabled_trigger_falls_back_to_exact_hashing(self):
  table=build.TABLES[0];relation=table['schema']+'.'+table['name'];name=build.trigger_name(table)
  before=compare()
  after=compare(prefix=f"BEGIN;ALTER TABLE {relation} DISABLE TRIGGER {name};UPDATE {relation} SET payload='{{\"untracked\":1}}' WHERE user_id='{U}';ALTER TABLE {relation} ENABLE ALWAYS TRIGGER {name};")
  self.assertNotEqual(after,before)
  self.assertEqual(compare(),before)

 def test_07_replica_mode_does_not_reuse_hidden_changes(self):
  before=compare();after=compare(prefix=f"BEGIN;SET LOCAL session_replication_role='replica';UPDATE public.audit_log SET payload='{{\"changed\":2}}' WHERE user_id='{U}';")
  self.assertNotEqual(after,before)
  sql(f"BEGIN;SET LOCAL session_replication_role='replica';UPDATE public.audit_log SET payload='{{\"replica_committed\":true}}' WHERE user_id='{U}';COMMIT;")
  self.assertNotEqual(compare(),before)

 def test_08_ddl_shape_and_new_columns_disable_reuse(self):
  before=compare()
  after=compare(prefix="BEGIN;ALTER TABLE public.audit_log ADD COLUMN new_semantic_field text DEFAULT 'new';")
  self.assertNotEqual(after,before)
  self.assertEqual(compare(),before)

 def test_09_unknown_producer_keeps_original_fail_closed_result(self):
  compare();self.assertIsNone(guard(prefix='BEGIN;CREATE OR REPLACE FUNCTION public.v465_fixture_producer() RETURNS integer LANGUAGE sql AS $$SELECT 2$$;'))

 def test_10_corrupted_or_incomplete_cache_is_never_an_empty_result(self):
  good=compare();sql(f"UPDATE {S}.review_input_hash_cache_v465 SET digest='bad';")
  self.assertEqual(compare(),good)
  sql(f"UPDATE {S}.review_input_hash_cache_v465 SET hashes='{{}}',digest=md5('{{}}');")
  self.assertEqual(compare(),good)

 def test_11_read_only_hits_and_misses_do_not_write(self):
  compare();self.assertEqual(compare(prefix='BEGIN READ ONLY;')['owner'],U)
  sql(f'TRUNCATE {S}.review_input_hash_cache_v465;');compare(prefix='BEGIN READ ONLY;')
  self.assertEqual(sql(f'SELECT count(*) FROM {S}.review_input_hash_cache_v465;'),'0')

 def test_12_native_privileges_and_guard_metadata_preserved(self):
  self.assertEqual(sql(f"SELECT (to_jsonb(p)-'prosrc')::text FROM pg_proc p WHERE oid='{S}.review_guard_v450(uuid)'::regprocedure;"),self.attrs)
  for role in ('anon','authenticated','service_role'):
   sql(f'SET ROLE {role};SELECT * FROM {S}.review_input_hash_cache_v465;',error='permission denied')

 def test_13_real_concurrent_commit_does_not_hide_source_change(self):
  before=compare()
  p=subprocess.Popen(['psql','-XAtq','-v','ON_ERROR_STOP=1','-d',DB],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
  p.stdin.write(f"BEGIN;UPDATE public.audit_log SET payload='{{\"concurrent\":true}}' WHERE user_id='{U}';SELECT 'changed';SELECT pg_sleep(0.3);COMMIT;\n");p.stdin.close()
  self.assertEqual(p.stdout.readline().strip(),'changed');self.assertEqual(compare(),before)
  p.wait(timeout=10);self.assertEqual(p.returncode,0,p.stderr.read());self.assertNotEqual(compare(),before)

 def test_14_table_replacement_and_contract_drift_cannot_reuse(self):
  before=compare()
  after=compare(prefix="BEGIN;ALTER TABLE public.audit_log RENAME TO old_audit;CREATE TABLE public.audit_log(LIKE public.old_audit INCLUDING ALL);INSERT INTO public.audit_log(user_id,payload) VALUES('"+U+"','{\"replacement\":true}');")
  self.assertNotEqual(after,before)

 def test_15_rollback_preserves_sources_and_original_definition(self):
  before=compare();sql((ROOT/'rollback.sql').read_text());self.assertEqual(guard(),before)
  self.assertEqual(sql(f"SELECT md5(pg_get_functiondef('{S}.review_guard_v450(uuid)'::regprocedure));"),build.ORIGINAL)
  sql(self.install)

if __name__=='__main__':unittest.main(verbosity=2)
