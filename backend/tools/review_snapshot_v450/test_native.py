"""Native PG17 fixtures. No live identities, financial facts or credentials."""
import hashlib,json,os,subprocess,tempfile,unittest
from pathlib import Path
import build
ROOT=Path(__file__).resolve().parent
NS=build.NS
OWNER='00000000-0000-0000-0000-000000000001'
OTHER='00000000-0000-0000-0000-000000000099'
COLS=(ROOT/'row-columns.txt').read_text().strip()
class Native(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.bin=Path(os.environ.get('LTS_INSTALLER_PG_BIN','/usr/lib/postgresql/17/bin'))
  if not (cls.bin/'initdb').is_file():raise RuntimeError('Native PG17 required; no live fallback')
  cls.tmp=tempfile.TemporaryDirectory(prefix='lts-review-snapshot-');cls.root=Path(cls.tmp.name);cls.sock=cls.root/'socket';cls.sock.mkdir();cls.data=cls.root/'data'
  cls.env={k:v for k,v in os.environ.items() if not k.startswith('PG')};cls.env.update(LC_ALL='C',LANG='C',PGTZ='America/Sao_Paulo')
  subprocess.run([str(cls.bin/'initdb'),'-D',str(cls.data),'-A','trust','--no-locale','-U','fixture_admin'],check=True,env=cls.env,capture_output=True)
  cls.started=False
  try:
   subprocess.run([str(cls.bin/'pg_ctl'),'-D',str(cls.data),'-l',str(cls.root/'server.log'),'-o',f"-k {cls.sock} -c listen_addresses=''",'-w','start'],check=True,env=cls.env,capture_output=True);cls.started=True
   cls.sql(f"""CREATE ROLE postgres SUPERUSER NOLOGIN;CREATE ROLE service_role NOLOGIN;CREATE ROLE anon NOLOGIN;CREATE ROLE authenticated NOLOGIN;
    CREATE SCHEMA {NS} AUTHORIZATION postgres;GRANT USAGE ON SCHEMA {NS} TO service_role;
    CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean,epoch bigint);INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);
    CREATE TABLE public.lts_v229_read_cache(user_id uuid,kind text,as_of date,from_date date,to_date date,payload jsonb,refreshed_at timestamptz,source_fingerprint text,PRIMARY KEY(user_id,kind,as_of,from_date,to_date));
    CREATE TABLE public.fixture_rows(user_id uuid,{COLS});CREATE TABLE public.fixture_calls(n integer);INSERT INTO public.fixture_calls VALUES(0);
    CREATE TABLE public.fixture_receipts(owner uuid,key text);INSERT INTO public.fixture_receipts VALUES('{OWNER}','receipt-one'),('{OTHER}','receipt-other');
    CREATE TABLE {NS}.queue(user_id uuid,request_version bigint,completed_version bigint,state text,reason text,attempts int,requested_at timestamptz,started_at timestamptz,completed_at timestamptz,next_attempt_at timestamptz,lease_expires_at timestamptz,last_error_code text,claim_token uuid,claimed_version bigint,claimed_epoch bigint,invalidate_caches boolean);
    CREATE FUNCTION {NS}.card_source_key(uuid) RETURNS text LANGUAGE sql STABLE AS 'SELECT key FROM public.fixture_receipts WHERE owner=$1';
    CREATE FUNCTION public.lts_browser_assert_user_v1() RETURNS uuid LANGUAGE plpgsql AS $$BEGIN IF nullif(current_setting('fixture.owner',true),'') IS NULL THEN RAISE EXCEPTION 'fixture owner required';END IF;RETURN current_setting('fixture.owner')::uuid;END$$;
    CREATE FUNCTION public.lts_browser_card_category_options_v226() RETURNS jsonb LANGUAGE sql AS $$SELECT '{{"categories":["Fixture category","Educação"]}}'::jsonb$$;
    CREATE FUNCTION public.lts_pending_projections_v233(uuid) RETURNS jsonb LANGUAGE sql AS $$SELECT '[{{"source":"fixture-unpaid","signed_amount":-123.45}}]'::jsonb$$;
    CREATE FUNCTION public.lts_v178_norm(text) RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT lower(coalesce($1,''))$$;
    CREATE FUNCTION public.lts_review_suggestions_v231(uuid,jsonb) RETURNS TABLE(source_table text,source_ref text,suggestion jsonb) LANGUAGE sql AS $$SELECT null::text,null::text,null::jsonb WHERE false$$;
    CREATE FUNCTION public.lts_v229_review_rows(uuid,date,date) RETURNS TABLE({COLS}) LANGUAGE plpgsql AS $$BEGIN
     UPDATE public.fixture_calls SET n=n+1;
     IF current_setting('fixture.change',true)='yes' THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1;END IF;
     RETURN QUERY SELECT {','.join('r.'+c.strip().split()[0] for c in COLS.split(','))} FROM public.fixture_rows r WHERE r.user_id=$1 AND r.event_date BETWEEN $2 AND $3;END$$;
    INSERT INTO public.fixture_rows(user_id,row_key,event_date,competence_month,amount,category,description,source_table,source_ref,identity_status,beneficiary,management_group)
    VALUES('{OWNER}','one',current_date,current_date,123.456789,'Educação','Fixture school','fixture','one','pending',NULL,'Educação'),
     ('{OWNER}','two',current_date-1,current_date,-8.25,'Fixture category','Fixture credit','fixture','two','pending','Fixture person','Fixture group'),
     ('{OWNER}','known',current_date,current_date,700,'Fixture category','Known fixture','fixture','known','identified',NULL,'Fixture group'),
     ('{OTHER}','other',current_date,current_date,999,'Fixture category','Other owner','fixture','other','pending',NULL,'Fixture group');
    INSERT INTO public.fixture_rows SELECT * FROM public.fixture_rows WHERE row_key='two';
    SET fixture.owner='{OWNER}';""")
   for signature,file in [(build.QUEUE,'queue-original.sql'),(build.WORKER,'worker-original.sql')]:
    cls.sql(build.get_original(file));cls.sql(f'ALTER FUNCTION {signature} OWNER TO postgres;REVOKE ALL ON FUNCTION {signature} FROM PUBLIC,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION {signature} TO service_role;')
   cls.sql(f'GRANT EXECUTE ON FUNCTION {build.QUEUE} TO authenticated;')
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
 def queue(self,offset=0,limit=25,query=None,owner=OWNER):
  q='NULL' if query is None else "'"+query.replace("'","''")+"'"
  return json.loads(self.sql(f"SET fixture.owner='{owner}';SELECT public.lts_browser_expense_review_queue_v229('2013-10-10',current_date,{offset},{limit},{q});"))
 def profile(self):
  # Only fixture providers differ: the production guard and pending reader are exact.
  deps=json.loads(self.sql("SET search_path='';SELECT jsonb_agg(jsonb_build_object('signature',s,'md5',md5(pg_get_functiondef(s::regprocedure)))) FROM unnest(ARRAY['public.lts_v229_review_rows(uuid,date,date)'])s;"))
  p={'producers':deps,'views':[],'epoch_tables':[],'tables':[{'schema':'public','name':'fixture_rows','owner':'user_id'}]}
  self.sql(f"CREATE OR REPLACE FUNCTION {NS}.review_profile_v450() RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $$SELECT '{json.dumps(p)}'::jsonb$$;")
 def pending(self,owner=OWNER):
  return self.sql(f"SELECT count(*) FROM {NS}.expense_review_pending_v450('{owner}','2013-10-10',current_date);")
 def test_exact_rows_guards_security_and_lifecycle(self):
  variants=[(0,25,None,OWNER),(1,1,None,OWNER),(0,25,'school',OWNER),(0,25,None,OTHER)]
  before=[self.queue(*v) for v in variants];self.assertEqual(before[0]['row_count'],3);self.assertEqual(before[0]['pending_projections'][0]['signed_amount'],-123.45)
  metadata=f"SELECT jsonb_agg(jsonb_build_array(oid::regprocedure::text,proacl,proconfig,prosecdef,proowner) ORDER BY oid) FROM pg_proc WHERE oid IN('{build.QUEUE}'::regprocedure,'{build.WORKER}'::regprocedure);"
  oldmeta=self.sql(metadata)
  self.sql('SET ROLE postgres;'+(ROOT/'install.sql').read_text());self.sql('SET ROLE postgres;'+(ROOT/'install.sql').read_text());self.assertEqual(oldmeta,self.sql(metadata))
  self.sql('SET ROLE postgres;'+(ROOT/'helpers.sql').read_text())
  self.profile();self.sql('UPDATE public.fixture_calls SET n=0;')
  for v,expected in zip(variants,before):self.assertEqual(self.queue(*v),expected)
  self.assertEqual(self.sql('SELECT n FROM public.fixture_calls;'),'2','Once per owner, independent of query and paging')
  self.assertEqual(self.pending(),'3');self.assertEqual(self.sql('SELECT n FROM public.fixture_calls;'),'2')
  self.sql("UPDATE public.lts_v229_read_cache SET payload=jsonb_set(payload,'{rows}','[]') WHERE user_id='"+OWNER+"';")
  self.assertEqual(self.pending(),'3');self.assertEqual(self.sql('SELECT n FROM public.fixture_calls;'),'3','Invalid digest rebuilds original rows')
  self.sql("UPDATE public.fixture_rows SET amount=amount+1 WHERE row_key='one';")
  self.pending();self.assertEqual(self.sql('SELECT n FROM public.fixture_calls;'),'4','Unguarded primary inputs are hashed')
  self.sql('UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1;');self.pending();self.assertEqual(self.sql('SELECT n FROM public.fixture_calls;'),'5')
  self.sql("UPDATE public.fixture_receipts SET key='receipt-two' WHERE owner='"+OWNER+"';");self.pending();self.assertEqual(self.sql('SELECT n FROM public.fixture_calls;'),'6')
  self.sql(f"SET fixture.change='yes';UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1;SELECT * FROM {NS}.expense_review_pending_v450('{OWNER}','2013-10-10',current_date);",error='Review sources changed during read')
  for role in ['anon','authenticated']:
   self.sql(f"SET ROLE {role};SELECT * FROM {NS}.expense_review_pending_v450('{OWNER}','2013-10-10',current_date);",error='permission denied')
  self.sql("SET ROLE authenticated;SELECT public.lts_browser_expense_review_queue_v229('2013-10-10',current_date);",error='fixture owner required')
  self.assertEqual(self.sql(f"SET fixture.owner='{OTHER}';SET ROLE authenticated;SELECT public.lts_browser_expense_review_queue_v229('2013-10-10',current_date)->>'row_count';"),'1')
  # Source changes unknown to this reviewed profile fall back without a false zero.
  original=self.sql("SELECT pg_get_functiondef('public.lts_v229_review_rows(uuid,date,date)'::regprocedure);")
  self.sql(original.replace('UPDATE public.fixture_calls','-- changed producer\n     UPDATE public.fixture_calls'))
  self.assertEqual(self.pending(),'3');self.assertEqual(self.pending(),'3')
  self.sql(original);self.sql('SET ROLE postgres;'+(ROOT/'helpers.sql').read_text())
  self.sql((ROOT/'rollback.sql').read_text());self.assertEqual(oldmeta,self.sql(metadata));self.sql((ROOT/'install.sql').read_text())
  self.sql("CREATE OR REPLACE FUNCTION "+NS+".review_profile_v450() RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $$SELECT '{}'::jsonb$$;")
  self.sql((ROOT/'install.sql').read_text(),error='review helper changed concurrently')
  self.assertIn('No extra job',build.WNEW)
  worker=build.patch(build.get_original('worker-original.sql'),build.WOLD,build.WNEW)
  self.assertLess(worker.index("UPDATE lts_product_refresh_private_v415.queue SET state='ready'"),worker.index('expense_review_pending_v450(u,'))
if __name__=='__main__':unittest.main(verbosity=2)
