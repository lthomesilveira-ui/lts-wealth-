"""Exact production definitions in isolated native PG17; invented owners and facts."""
import concurrent.futures,json,os,subprocess,tempfile,unittest
from pathlib import Path
import build
ROOT=Path(__file__).resolve().parent
NS='lts_product_refresh_private_v415'
U='00000000-0000-4000-8000-000000000001';OTHER='00000000-0000-4000-8000-000000000002'
class Readiness(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.bin=Path(os.environ.get('LTS_INSTALLER_PG_BIN','/usr/lib/postgresql/17/bin'))
  if not (cls.bin/'initdb').is_file():raise RuntimeError('Native PG17 required; no live fallback')
  cls.tmp=tempfile.TemporaryDirectory(prefix='lts-readiness-');cls.root=Path(cls.tmp.name);cls.sock=cls.root/'socket';cls.sock.mkdir();cls.data=cls.root/'data'
  cls.env={k:v for k,v in os.environ.items() if not k.startswith('PG')};cls.env.update(LC_ALL='C',LANG='C',PGTZ='America/Sao_Paulo')
  subprocess.run([str(cls.bin/'initdb'),'-D',str(cls.data),'-A','trust','--no-locale','-U','fixture_admin'],check=True,env=cls.env,capture_output=True);cls.started=False
  try:
   subprocess.run([str(cls.bin/'pg_ctl'),'-D',str(cls.data),'-l',str(cls.root/'server.log'),'-o',f"-k {cls.sock} -c listen_addresses=''",'-w','start'],check=True,env=cls.env,capture_output=True);cls.started=True
   cls.sql(f'''CREATE ROLE postgres SUPERUSER NOLOGIN;CREATE ROLE service_role NOLOGIN;CREATE ROLE anon NOLOGIN;CREATE ROLE authenticated NOLOGIN;
    CREATE SCHEMA {NS} AUTHORIZATION postgres;GRANT USAGE ON SCHEMA {NS} TO service_role;
    CREATE SCHEMA lts_projection_private_v412 AUTHORIZATION postgres;
    CREATE TABLE {NS}.queue(user_id uuid PRIMARY KEY,state text DEFAULT 'pending',reason text,request_version bigint DEFAULT 1,completed_version bigint DEFAULT 0,attempts int DEFAULT 0,requested_at timestamptz,started_at timestamptz,completed_at timestamptz,next_attempt_at timestamptz,lease_expires_at timestamptz,last_error_code text,claim_token uuid,claimed_version bigint,claimed_epoch bigint,invalidate_caches boolean DEFAULT false);
    CREATE TABLE public.lts_product_read_cache(user_id uuid PRIMARY KEY,payload_version text,payload jsonb,refreshed_at timestamptz);
    CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean,epoch bigint);INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,7);
    CREATE TABLE public.legacy_namespace(usuario_id uuid,chave text,sha256 text);
    CREATE TABLE public.fixture_receipts(user_id uuid,key text);
    CREATE TABLE public.financial_facts(user_id uuid,amount numeric,event_date date);INSERT INTO public.financial_facts VALUES('{U}',123.45,current_date),('{OTHER}',900.01,current_date);
    CREATE FUNCTION {NS}.allowed_owner(uuid) RETURNS boolean LANGUAGE sql STABLE AS $$SELECT $1 IN('{U}'::uuid,'{OTHER}'::uuid)$$;
    CREATE FUNCTION {NS}.compatible(text,jsonb) RETURNS boolean LANGUAGE sql IMMUTABLE AS $$SELECT $1='fixture-v1' AND jsonb_typeof($2)='object'$$;
    CREATE FUNCTION {NS}.card_source_key(uuid) RETURNS text LANGUAGE sql STABLE AS $$SELECT key FROM public.fixture_receipts WHERE user_id=$1$$;
    CREATE FUNCTION {NS}.card_state_cached(uuid) RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT jsonb_build_object('current_card_key',key) FROM public.fixture_receipts WHERE user_id=$1$$;
    CREATE FUNCTION lts_projection_private_v412.owner_policy(uuid) RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT '{{}}'::jsonb FROM public.legacy_namespace WHERE usuario_id=$1 AND chave='lts_owner_projection_policy_v412'$$;
    CREATE FUNCTION public.lts_browser_assert_user_v1() RETURNS uuid LANGUAGE plpgsql AS $$DECLARE u uuid:=nullif(current_setting('fixture.owner',true),'')::uuid;BEGIN IF u IS NULL OR NOT {NS}.allowed_owner(u) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='fixture owner required';END IF;RETURN u;END$$;
    INSERT INTO public.fixture_receipts VALUES('{U}','receipt-two'),('{OTHER}','receipt-other');
    INSERT INTO {NS}.queue(user_id,state,request_version,completed_version) VALUES('{U}','ready',4,4),('{OTHER}','ready',4,4);
    INSERT INTO public.legacy_namespace SELECT u,chave,sha FROM unnest(ARRAY['{U}'::uuid,'{OTHER}'::uuid])u CROSS JOIN (VALUES('lts_owner_projection_policy_v412','policy-one'),('lts_projection_reference_v412','reference-one'))p(chave,sha);
    INSERT INTO public.lts_product_read_cache SELECT u,'fixture-v1',jsonb_build_object('canonical_summary',jsonb_build_object('as_of',current_date),'updates',jsonb_build_object('freshness',jsonb_build_object('today',current_date),'document_change_summary_version','document-change-summary-v1'),'flow',jsonb_build_object('days',jsonb_build_array(jsonb_build_object('date',current_date))),'projection_summary_v418',jsonb_build_object('user_id',u,'as_of',current_date,'summary',jsonb_build_object('enabled',true),'guard',jsonb_build_object('request_version','4','source_epoch','7','card_source_key',CASE WHEN u='{U}'::uuid THEN 'receipt-one' ELSE 'receipt-other' END,'policy_sha256','policy-one','reference_sha256','reference-one'))),clock_timestamp() FROM unnest(ARRAY['{U}'::uuid,'{OTHER}'::uuid])u;''')
   for name in ['private-status-original.sql','enqueue-original.sql','cache-info-original.sql','status-original.sql']:cls.sql(build.read(name))
   for sig,_,_ in build.FUNCTIONS:
    cls.sql(f'ALTER FUNCTION {sig} OWNER TO postgres;REVOKE ALL ON FUNCTION {sig} FROM PUBLIC,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION {sig} TO service_role;')
   cls.sql(f'GRANT EXECUTE ON FUNCTION {build.STATUS} TO authenticated;')
  except BaseException:cls.tearDownClass();raise
 @classmethod
 def tearDownClass(cls):
  if getattr(cls,'started',False):subprocess.run([str(cls.bin/'pg_ctl'),'-D',str(cls.data),'-m','immediate','-w','stop'],env=cls.env,capture_output=True)
  if hasattr(cls,'tmp'):cls.tmp.cleanup()
 @classmethod
 def sql(cls,text,error=None):
  p=subprocess.run([str(cls.bin/'psql'),'-XAtq','-v','ON_ERROR_STOP=1','-h',str(cls.sock),'-U','fixture_admin','-d','postgres'],input=text,text=True,capture_output=True,env=cls.env)
  if error:
   if p.returncode==0 or error not in p.stderr:raise AssertionError((error,p.returncode,p.stderr))
  elif p.returncode:raise AssertionError(p.stderr)
  return p.stdout.strip()
 def status(self,owner=U):return json.loads(self.sql(f"SET fixture.owner='{owner}';SET ROLE authenticated;SELECT public.lts_browser_product_refresh_status_v415()->'refresh';"))
 def test_projection_readiness_coalescing_guards_and_lifecycle(self):
  self.assertEqual(self.status()['state'],'ready','Reproduce obsolete projection certified by fresh card cache')
  source_hash=self.sql('SELECT md5(jsonb_agg(to_jsonb(f) ORDER BY user_id)::text) FROM public.financial_facts f;')
  attrs="SELECT jsonb_agg(jsonb_build_array(oid::regprocedure::text,proacl,proconfig,prosecdef,proowner) ORDER BY oid) FROM pg_proc WHERE oid IN('"+build.CACHE+"'::regprocedure,'"+build.STATUS+"'::regprocedure);"
  metadata=self.sql(attrs)
  for _ in range(2):self.sql('SET ROLE postgres;'+build.read('install.sql'))
  self.assertEqual(metadata,self.sql(attrs))
  # Both requests observe the old state; row-locking enqueue(false) creates one version.
  with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:self.status(),range(2)))
  self.assertTrue(all(r['state']=='pending' and r['request_version']=='5' for r in results))
  self.assertEqual(self.sql(f"SELECT request_version||'|'||completed_version||'|'||state FROM {NS}.queue WHERE user_id='{U}';"),'5|4|pending')
  self.assertEqual(self.status()['request_version'],'5','Pending job is joined, not replaced')
  self.sql(f"UPDATE {NS}.queue SET state='running',claim_token='00000000-0000-4000-8000-000000000005',claimed_version=5 WHERE user_id='{U}';")
  self.assertEqual(self.status()['request_version'],'5');self.assertEqual(self.status()['state'],'running')
  self.assertEqual(self.status(OTHER)['state'],'ready','Other owner unaffected')
  self.sql(f"UPDATE {NS}.queue SET state='ready',completed_version=request_version WHERE user_id='{U}';UPDATE public.lts_product_read_cache SET payload=jsonb_set(jsonb_set(payload,'{{projection_summary_v418,guard,request_version}}','\"5\"'),'{{projection_summary_v418,guard,card_source_key}}','\"receipt-two\"') WHERE user_id='{U}';")
  self.assertEqual(self.status()['state'],'ready');self.assertEqual(self.status()['request_version'],'5')
  guard_faults={'owner':('{user_id}',json.dumps(OTHER)),'day':('{as_of}',json.dumps('2000-01-01')),'epoch':('{guard,source_epoch}',json.dumps('6')),'version':('{guard,request_version}',json.dumps('4')),'card':('{guard,card_source_key}',json.dumps('receipt-old')),'policy':('{guard,policy_sha256}',json.dumps('other')),'reference':('{guard,reference_sha256}',json.dumps('other')),'enabled':('{summary,enabled}','false')}
  for label,(path,value) in guard_faults.items():
   result=json.loads(self.sql(f"BEGIN;UPDATE public.lts_product_read_cache SET payload=jsonb_set(payload,'{{projection_summary_v418}}',jsonb_set(payload->'projection_summary_v418','{path}','{value}')) WHERE user_id='{U}';SET fixture.owner='{U}';SET ROLE authenticated;SELECT public.lts_browser_product_refresh_status_v415()->'refresh';ROLLBACK;"))
   self.assertEqual((result['state'],result['request_version']),('pending','6'),label)
  self.assertEqual(self.sql(f"BEGIN;DELETE FROM public.legacy_namespace WHERE usuario_id='{U}' AND chave='lts_owner_projection_policy_v412';SELECT {NS}.projection_current_v452('{U}');ROLLBACK;"),'t')
  for role in ['anon','authenticated']:self.sql(f"SET ROLE {role};SELECT {NS}.projection_current_v452('{U}');",error='permission denied')
  self.sql('SET ROLE anon;SELECT public.lts_browser_product_refresh_status_v415();',error='permission denied')
  self.sql('SET ROLE authenticated;SELECT public.lts_browser_product_refresh_status_v415();',error='fixture owner required')
  self.sql("SET fixture.owner='00000000-0000-4000-8000-000000000099';SET ROLE authenticated;SELECT public.lts_browser_product_refresh_status_v415();",error='fixture owner required')
  self.assertEqual(source_hash,self.sql('SELECT md5(jsonb_agg(to_jsonb(f) ORDER BY user_id)::text) FROM public.financial_facts f;'))
  self.sql('SET ROLE postgres;'+build.read('rollback.sql'));self.assertEqual(metadata,self.sql(attrs))
  self.assertEqual(self.sql(f"SELECT to_regprocedure('{build.HELPER}') IS NULL;"),'t')
  self.sql('SET ROLE postgres;'+build.read('install.sql'))
  changed=build.status().replace(' refresh:=',' /* concurrent change */ refresh:=',1);self.sql(changed)
  self.sql('SET ROLE postgres;'+build.read('install.sql'),error='Projection readiness changed concurrently')
if __name__=='__main__':unittest.main(verbosity=2)
