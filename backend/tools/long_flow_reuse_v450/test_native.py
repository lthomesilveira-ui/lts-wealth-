"""Native PG17: exact raw/full-flow parity, invalidation, read-only and CAS."""
import importlib.util,json,sys,unittest
from pathlib import Path
import build
ROOT=Path(__file__).resolve().parent
SNAP=ROOT.parent/'review_snapshot_v450'
spec=importlib.util.spec_from_file_location('snapshot_build',SNAP/'build.py');snap=importlib.util.module_from_spec(spec);spec.loader.exec_module(snap)
spec=importlib.util.spec_from_file_location('snapshot_tests',SNAP/'test_native.py');base=importlib.util.module_from_spec(spec)
saved=sys.modules['build'];sys.modules['build']=snap
try:spec.loader.exec_module(base)
finally:sys.modules['build']=saved
OWNER=base.OWNER;OTHER=base.OTHER
class LongFlow(base.Native):
 test_exact_rows_guards_security_and_lifecycle=None
 @classmethod
 def setUpClass(cls):
  super().setUpClass()
  try:
   cls.sql(f"""CREATE FUNCTION public.lts_flow_read_source_key_v247(uuid) RETURNS text LANGUAGE sql STABLE SET search_path='' AS $f$ SELECT key FROM public.fixture_receipts WHERE owner=$1 $f$;
    CREATE FUNCTION public.lts_daily_flow_fix86_v20(p_user_id uuid,p_from date,p_to date) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
    DECLARE days jsonb; BEGIN
     IF NOT current_setting('transaction_read_only')::boolean THEN UPDATE public.fixture_calls SET n=n+1;END IF;
     IF current_setting('fixture.change',true)='yes' THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1;END IF;
     SELECT jsonb_agg(jsonb_build_object('date',d::date,'Itaú',jsonb_build_object('balance',100.123456,'net',0),
      'Bradesco',jsonb_build_object('balance',200,'net',0),'C6',jsonb_build_object('balance',300,'net',0),
      'Consolidado',jsonb_build_object('economic_net',CASE WHEN d::date=current_date+100 THEN NULL ELSE 1.234567 END),
      'fix86_columns',jsonb_build_object('saldo_anterior',600.123456,'saldo_final',600.123456,'liq_d0_1',600.123456,'liq_d30',-88.987654)) ORDER BY d)
      INTO days FROM generate_series(p_from,p_to,interval '1 day')d;
     RETURN jsonb_build_object('from',p_from,'to',p_to,'version','fixture-engine','days',days,
      'events',jsonb_build_array(jsonb_build_object('event_date',current_date,'source_ref',p_user_id,'signed_amount',-123.456789)),
      'unknown',NULL,'exact_precision',123.456789);
    END $f$;
    CREATE FUNCTION public.lts_flow_future_read_slice_v9(uuid,date,date) RETURNS jsonb LANGUAGE sql AS $f$ SELECT public.lts_daily_flow_fix86_v20($1,$2,$3+30) $f$;
    CREATE FUNCTION public.lts_open_finance_current_bank_position_v1(uuid) RETURNS jsonb LANGUAGE sql AS $f$
     SELECT '{{"accounts":[{{"institution_code":"341","balance":100.123456}},{{"institution_code":"237","balance":200}},{{"institution_code":"336","balance":300}}]}}'::jsonb $f$;
    CREATE FUNCTION public.lts_dashboard_cash_ladder_from_flow_v229(uuid,date,date,jsonb)
     RETURNS TABLE(flow_date date,operational_cash numeric,d01_resource numeric,rsu_vested_scheduled numeric,fgts_projected numeric,balance_after_d01 numeric,balance_with_scheduled_vesting numeric,balance_with_fgts_projected numeric)
     LANGUAGE sql AS $f$ SELECT d::date,600.123456::numeric,0::numeric,0::numeric,NULL::numeric,600.123456::numeric,600.123456::numeric,NULL::numeric FROM generate_series($2,$3,interval '1 day')d $f$;
    """)
   for signature,name in [(build.FLOW,'flow-original.sql'),(build.WORKER,'worker-original.sql')]:
    cls.sql(build.original(name));cls.sql(f'ALTER FUNCTION {signature} OWNER TO postgres;REVOKE ALL ON FUNCTION {signature} FROM PUBLIC,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION {signature} TO service_role;')
  except BaseException:cls.tearDownClass();raise
 def raw(self,owner=OWNER,days=1930):return json.loads(self.sql(f"SELECT {build.NS}.long_flow_raw_v450('{owner}',current_date+{days});"))
 def test_exact_engine_and_full_flow_lifecycle(self):
  before=json.loads(self.sql(f"SELECT public.lts_current_flow_v229('{OWNER}',current_date,current_date+1900);"))
  metadata=f"SELECT jsonb_agg(jsonb_build_array(oid::regprocedure::text,proacl,proconfig,prosecdef,proowner) ORDER BY oid) FROM pg_proc WHERE oid IN('{build.FLOW}'::regprocedure,'{build.WORKER}'::regprocedure);"
  oldmeta=self.sql(metadata)
  self.sql('SET ROLE postgres;'+(ROOT/'install.sql').read_text());self.sql('SET ROLE postgres;'+(ROOT/'install.sql').read_text());self.assertEqual(oldmeta,self.sql(metadata))
  for sig,name in build.HELPERS:self.assertEqual(self.sql("SET search_path='';SELECT md5(pg_get_functiondef('"+sig+"'::regprocedure));"),build.md5(build.original(name)))
  self.profile();self.sql('UPDATE public.fixture_calls SET n=0;')
  source=self.sql('SELECT md5(jsonb_agg(to_jsonb(r) ORDER BY row_key)::text) FROM public.fixture_rows r;')
  expected=json.loads(self.sql(f"SELECT public.lts_daily_flow_fix86_v20('{OWNER}',current_date,current_date+1930);"))
  self.sql('UPDATE public.fixture_calls SET n=0;')
  self.assertEqual(self.raw(),expected);self.assertEqual(self.raw(),expected);self.assertEqual(self.sql('SELECT n FROM public.fixture_calls;'),'1')
  after=json.loads(self.sql(f"SELECT public.lts_current_flow_v229('{OWNER}',current_date,current_date+1900);"));self.assertEqual(after,before)
  self.assertEqual(source,self.sql('SELECT md5(jsonb_agg(to_jsonb(r) ORDER BY row_key)::text) FROM public.fixture_rows r;'))
  self.assertEqual(after['days'][80]['fix86_columns']['liq_d30'],None,'Unknown lookahead remains unknown')
  self.assertEqual(self.sql('SELECT n FROM public.fixture_calls;'),'1','Full current-flow reuses the identical raw range')
  self.assertEqual(json.loads(self.sql(f"BEGIN READ ONLY;SELECT {build.NS}.long_flow_raw_v450('{OWNER}',current_date+1930);ROLLBACK;")),expected)
  self.assertEqual(json.loads(self.sql(f"BEGIN READ ONLY;SELECT {build.NS}.long_flow_raw_v450('{OWNER}',current_date+1931);ROLLBACK;"))['to'],self.sql("SELECT (current_date+1931)::text;"))
  self.assertNotEqual(self.raw(OTHER)['events'][0]['source_ref'],expected['events'][0]['source_ref'])
  self.sql("UPDATE public.lts_v229_read_cache SET payload=jsonb_set(payload,'{digest}','\"corrupt\"') WHERE kind='long_flow_raw_v450';")
  self.assertEqual(self.raw(),expected)
  self.sql('UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1;');self.assertEqual(self.raw(),expected)
  self.sql("UPDATE public.fixture_receipts SET key='receipt-new' WHERE owner='"+OWNER+"';");self.assertEqual(self.raw(),expected)
  self.sql("SET fixture.change='yes';UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1;SELECT "+build.NS+".long_flow_raw_v450('"+OWNER+"',current_date+1930);",error='Long flow sources changed during read')
  # Code changed outside the review providers: the program fingerprint forces a miss.
  old_calls=int(self.sql('SELECT n FROM public.fixture_calls;'))
  self.sql("CREATE FUNCTION public.lts_fixture_new_callee() RETURNS int LANGUAGE sql AS $$SELECT 1$$;");self.assertEqual(self.raw(),expected)
  self.assertEqual(int(self.sql('SELECT n FROM public.fixture_calls;')),old_calls+1)
  self.sql('ALTER TABLE public.fixture_epoch_input DISABLE TRIGGER fixture_epoch;')
  self.assertEqual(self.sql(f"SELECT {build.NS}.long_flow_guard_v450('{OWNER}') IS NULL;"),'t')
  old_calls=int(self.sql('SELECT n FROM public.fixture_calls;'));self.assertEqual(self.raw(),expected);self.assertEqual(self.raw(),expected)
  self.assertEqual(int(self.sql('SELECT n FROM public.fixture_calls;')),old_calls+2,'Unknown guard bypasses reuse, never returns a false empty result')
  self.sql('ALTER TABLE public.fixture_epoch_input ENABLE TRIGGER fixture_epoch;')
  for role in ['anon','authenticated']:
   for sig in ['long_flow_guard_v450','long_flow_raw_v450']:
    args=f"'{OWNER}'"+(',current_date+1930' if 'raw' in sig else '')
    self.sql(f'SET ROLE {role};SELECT {build.NS}.{sig}({args});',error='permission denied')
  worker=build.worker();self.assertEqual(worker.count('long_flow_raw_v450(u,'),1)
  self.assertLess(worker.index('long_flow_raw_v450(u,'),worker.index('result:=public.lts_refresh_product_read_cache_operational_v5(u);'))
  self.assertIn('No extra job',worker);self.assertIn("WHEN SQLSTATE 'P0415'",worker)
  self.sql((ROOT/'rollback.sql').read_text());self.assertEqual(oldmeta,self.sql(metadata))
  self.sql((ROOT/'install.sql').read_text())
  edited=build.flow().replace('  raw jsonb;','  -- concurrent edit\n  raw jsonb;',1);self.assertNotEqual(edited,build.flow());self.sql(edited)
  self.sql((ROOT/'install.sql').read_text(),error='long flow reader changed concurrently')
if __name__=='__main__':unittest.main(verbosity=2)
