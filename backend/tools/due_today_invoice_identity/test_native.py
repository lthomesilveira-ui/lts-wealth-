"""PostgreSQL17: exact live reconciliation blocks and version-guarded lifecycle."""
import importlib.util,json,sys,unittest
from pathlib import Path
import build as identity
ROOT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('due_base_tests',ROOT.parent/'due_today_invoice'/'test_native.py')
base_tests=importlib.util.module_from_spec(spec)
saved=sys.modules['build'];sys.modules['build']=identity.base
try:spec.loader.exec_module(base_tests)
finally:sys.modules['build']=saved

class IdentityTest(base_tests.NativeTest):
 def make_identity_block(self,name,text):
  body=identity.base.block(text)
  self.sql(f"""CREATE OR REPLACE FUNCTION public.{name}(p_rows jsonb,p_owner uuid) RETURNS jsonb LANGUAGE plpgsql AS $fixture$
   DECLARE u uuid:=p_owner;recent jsonb:=p_rows;pending_predictions jsonb;
    anchors jsonb:=jsonb_build_array(jsonb_build_object('bank','Itaú','date',current_date-10),jsonb_build_object('bank','Bradesco','date',current_date-10));
   BEGIN {body} RETURN jsonb_build_object('events',recent,'pending',pending_predictions);END $fixture$;""")
 def set_pending(self,rows):
  value=json.dumps(rows,ensure_ascii=False).replace("'","''")
  self.sql(f"TRUNCATE public.fixture_pending;INSERT INTO public.fixture_pending VALUES('{base_tests.OWNER}','{value}'::jsonb);")
 def test_due_today_and_guarded_lifecycle(self):
  self.sql("""CREATE TABLE public.fixture_pending(user_id uuid,payload jsonb);
   CREATE OR REPLACE FUNCTION public.lts_pending_projections_v233(uuid) RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT coalesce((SELECT payload FROM public.fixture_pending WHERE user_id=$1),'[]')$$;""")
  for target in identity.TARGETS:
   self.sql(identity.before(target));signature=target['signature']
   self.sql(f"ALTER FUNCTION {signature} OWNER TO postgres;REVOKE ALL ON FUNCTION {signature} FROM PUBLIC,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION {signature} TO service_role;")
  metadata="""SELECT jsonb_agg(jsonb_build_array(oid::regprocedure::text,proacl,proconfig,prosecdef,proowner) ORDER BY oid::regprocedure::text)
   FROM pg_proc WHERE oid IN('public.lts_flow_cache_pre_v240(uuid,date,date)'::regprocedure,'public.lts_browser_flow_pre_v238(date,date)'::regprocedure);"""
  before_meta=self.sql(metadata)
  self.sql((ROOT/'install.sql').read_text());self.sql((ROOT/'install.sql').read_text())
  self.assertEqual(before_meta,self.sql(metadata))
  for target in identity.TARGETS:
   self.make_identity_block('identity_old',identity.before(target));self.make_identity_block('identity_new',identity.patch(identity.before(target)))
   self.seed();source=self.row();pending={**source,'category':'Fixture received card','center_cost':'Not assigned'}
   self.set_pending([pending]);facts=self.facts_hash()
   old=self.query('identity_old',[source]);new=self.query('identity_new',[source])
   self.assertEqual(len(old['events']),1);self.assertEqual(old['pending'],[pending])
   self.assertEqual(new['events'],old['events']);self.assertEqual(new['pending'],[])
   self.assertEqual(sum(x['signed_amount'] for x in new['events']+new['pending']),-123.45)
   self.assertEqual(facts,self.facts_hash())
   today=source['event_date'];yesterday=self.sql("SELECT (current_date-1)::text;")
   for change in [{'signed_amount':-123.46},{'source_ref':'other-invoice'},{'account':'Bradesco'},
    {'event_date':yesterday},{'source':'current_event'}]:
    with self.subTest(target=target['signature'],different=change):
     row={**pending,**change};self.set_pending([row])
     self.assertEqual(self.query('identity_new',[source])['pending'],[row],'Distinct/ambiguous obligations remain visible')
   self.set_pending([pending]);self.sql("UPDATE public.fixture_bills SET payment_status='partially_paid',reported_payment_amount=1;")
   result=self.query('identity_new',[source]);self.assertEqual(result['events'],[]);self.assertEqual(result['pending'],[pending])
   self.seed();self.set_pending([pending]);posted=self.row(source='open_finance',source_ref='posted-fixture',confidence='bank_posted',bank_confirmed=True)
   result=self.query('identity_new',[posted]);self.assertEqual(result['events'],[posted]);self.assertEqual(result['pending'],[pending])
   self.assertEqual(self.query('identity_new',[source],base_tests.OTHER)['pending'],[])
  for role in ['anon','authenticated']:
   self.sql(f"SET ROLE {role};SELECT public.lts_browser_flow_pre_v238(current_date,current_date);",error='permission denied')
  self.sql((ROOT/'rollback.sql').read_text())
  for target in identity.TARGETS:
   self.assertEqual(self.sql(f"SELECT md5(pg_get_functiondef('{target['signature']}'::regprocedure));"),identity.md5(identity.before(target)))
  self.sql((ROOT/'install.sql').read_text())
  target=identity.TARGETS[0];installed=self.sql(f"SELECT pg_get_functiondef('{target['signature']}'::regprocedure);")+"\n"
  self.sql(installed.replace('Current bank positions stay exact.','Fixture concurrent edit.'))
  self.sql((ROOT/'install.sql').read_text(),error='changed concurrently')
  self.sql((ROOT/'rollback.sql').read_text(),error='changed concurrently')
if __name__=='__main__':unittest.main(verbosity=2)
