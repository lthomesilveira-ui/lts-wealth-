"""Native PG17: exact source/date/amount exclusion; no incoming leg is created."""
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
ID='00000000-0000-0000-0000-000000000002'
class OwnOut(base.Native):
 test_exact_rows_guards_security_and_lifecycle=None
 @classmethod
 def setUpClass(cls):
  super().setUpClass()
  try:
   cls.sql(f"""TRUNCATE public.fixture_rows;
    CREATE TABLE public.lts_open_finance_staging(id uuid,user_id uuid,institution_code text,provider_account_ref text,resource_type text,currency text,provider_deleted_at timestamptz,signed_amount numeric,posting_date date,normalized_payload jsonb,raw_payload jsonb);
    CREATE TABLE public.lts_v178_review_decision(user_id uuid,source_table text,source_ref text,category_label text);
    CREATE TABLE public.lts_workbook_nonspend_source_v343(user_id uuid,source_table text,source_ref text,nature text,evidence_date date,amount numeric);
    CREATE TABLE public.lts_category_binding_v290(user_id uuid,raw_category text,category_key text);
    CREATE TABLE public.lts_category_catalog(user_id uuid,category_key text,category text);
    CREATE FUNCTION public.lts_expense_rows_pre_categories_v290(uuid,date,date) RETURNS TABLE({base.COLS}) LANGUAGE sql STABLE AS $f$
     SELECT {','.join('r.'+c.strip().split()[0] for c in base.COLS.split(','))} FROM public.fixture_rows r WHERE r.user_id=$1 AND r.event_date BETWEEN $2 AND $3 $f$;
    INSERT INTO public.lts_v178_review_decision VALUES('{OWNER}','lts_open_finance_staging','{ID}','Transferência própria');
    INSERT INTO public.fixture_rows(user_id,row_key,event_date,transaction_date,competence_month,amount,category,source_table,source_ref,coverage_mode,identity_status)
     VALUES('{OWNER}','exact',current_date,current_date,current_date,123.45,'Transferência própria','lts_open_finance_staging','{ID}','bank_observed_individual','identified'),
      ('{OWNER}','other-date',current_date-1,current_date-1,current_date,123.45,'Transferência própria','lts_open_finance_staging','{ID}','bank_observed_individual','identified'),
      ('{OWNER}','other-kind',current_date,current_date,current_date,123.45,'Transferência própria','lts_open_finance_staging','{ID}','card_observed_pending','identified'),
      ('{OWNER}','other-source',current_date,current_date,current_date,123.45,'Transferência própria','financial_events','{ID}','bank_observed_individual','identified'),
      ('{OWNER}','other-amount',current_date,current_date,current_date,999.99,'Transferência própria','lts_open_finance_staging','{ID}','bank_observed_individual','identified'),
      ('{OTHER}','other-owner',current_date,current_date,current_date,123.45,'Transferência própria','lts_open_finance_staging','{ID}','bank_observed_individual','identified');
    INSERT INTO public.lts_open_finance_staging VALUES
     ('{ID}','{OWNER}','341','sender','transaction','BRL',NULL,-123.45,current_date,'{{"status":"POSTED","account_type":"CHECKING_ACCOUNT"}}',
      '{{"operationType":"PIX","paymentData":{{"paymentMethod":"PIX","payer":{{"documentNumber":{{"type":"CPF","value":"123.456.789-00"}}}},"receiver":{{"routingNumber":"237","documentNumber":{{"type":"CPF","value":"12345678900"}}}}}}}}'),
     ('00000000-0000-0000-0000-000000000010','{OWNER}','341','sender','balance','BRL',NULL,0,current_date,'{{"account_type":"CHECKING_ACCOUNT"}}','{{"taxNumber":"12345678900"}}'),
     ('00000000-0000-0000-0000-000000000011','{OWNER}','237','destination','balance','BRL',NULL,0,current_date,'{{"account_type":"SAVINGS_ACCOUNT"}}','{{"taxNumber":"12345678900"}}');
    """)
   for sig,file in [(build.EXPENSE,'expense-original.sql'),(build.PROFILE,'profile-original.sql')]:
    cls.sql(build.original(file));cls.sql(f'ALTER FUNCTION {sig} OWNER TO postgres;REVOKE ALL ON FUNCTION {sig} FROM PUBLIC,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION {sig} TO service_role;')
  except BaseException:cls.tearDownClass();raise
 def rows(self,owner=OWNER):
  return json.loads(self.sql(f"SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY row_key),'[]') FROM public.lts_v229_expense_rows('{owner}','2013-10-10',current_date)r;"))
 def test_exact_evidenced_outbound_only_and_lifecycle(self):
  old=self.rows();other=self.rows(OTHER)
  metadata=f"SELECT jsonb_agg(jsonb_build_array(oid::regprocedure::text,proacl,proconfig,prosecdef,proowner) ORDER BY oid) FROM pg_proc WHERE oid IN('{build.EXPENSE}'::regprocedure,'{build.PROFILE}'::regprocedure);"
  meta=self.sql(metadata);facts=self.sql('SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.lts_open_finance_staging s;')
  self.sql('SET ROLE postgres;'+(ROOT/'install.sql').read_text());self.sql('SET ROLE postgres;'+(ROOT/'install.sql').read_text())
  self.assertEqual(meta,self.sql(metadata));self.assertEqual(self.rows(),[r for r in old if r['row_key']!='exact']);self.assertEqual(self.rows(OTHER),other)
  self.assertEqual(facts,self.sql('SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.lts_open_finance_staging s;'),'No bank leg or balance altered')
  self.assertEqual(self.sql(f"SELECT md5(pg_get_functiondef('{build.HELPER}'::regprocedure));"),build.md5(build.helper()))
  # Neither a matching name/amount nor a single wrong identity/state can exclude a spend.
  variations=[("normalized_payload=jsonb_set(normalized_payload,'{status}','\"PENDING\"')",'status'),
   ("currency='USD'",'currency'),("signed_amount=123.45",'credit'),("provider_deleted_at=now()",'deleted'),
   ("posting_date=current_date+1",'future'),("resource_type='card_transaction'",'card'),
   ("normalized_payload=jsonb_set(normalized_payload,'{account_type}','\"CREDIT_CARD\"')",'account type'),
   ("raw_payload=jsonb_set(raw_payload,'{operationType}','\"PAYMENT\"')",'operation'),
   ("raw_payload=jsonb_set(raw_payload,'{paymentData,paymentMethod}','\"BOLETO\"')",'method'),
   ("raw_payload=jsonb_set(raw_payload,'{paymentData,receiver,documentNumber,value}','\"99999999999\"')",'receiver'),
   ("raw_payload=jsonb_set(raw_payload,'{paymentData,payer,documentNumber,type}','\"CNPJ\"')",'payer type'),
   ("raw_payload=jsonb_set(raw_payload,'{paymentData,receiver,routingNumber}','\"999\"')",'unconnected bank'),
   ("provider_account_ref='different'",'origin account')]
  for statement,label in variations:
   with self.subTest(label=label):
    self.assertEqual(self.sql(f"BEGIN;UPDATE public.lts_open_finance_staging SET {statement} WHERE id='{ID}';SELECT count(*) FROM {build.NS}.documented_own_out_v450('{OWNER}');ROLLBACK;"),'0')
  self.assertEqual(self.sql(f"BEGIN;UPDATE public.lts_v178_review_decision SET category_label='Other';SELECT count(*) FROM {build.NS}.documented_own_out_v450('{OWNER}');ROLLBACK;"),'0')
  self.assertEqual(self.sql(f"BEGIN;UPDATE public.lts_open_finance_staging SET user_id='{OTHER}' WHERE resource_type='balance';SELECT count(*) FROM {build.NS}.documented_own_out_v450('{OWNER}');ROLLBACK;"),'0')
  for role in ['anon','authenticated']:self.sql(f"SET ROLE {role};SELECT * FROM {build.NS}.documented_own_out_v450('{OWNER}');",error='permission denied')
  self.sql((ROOT/'rollback.sql').read_text());self.assertEqual(self.rows(),old);self.assertEqual(meta,self.sql(metadata))
  self.sql((ROOT/'install.sql').read_text())
  changed=build.expense().replace('WITH rows AS','-- concurrent edit\nWITH rows AS')
  self.sql(changed);self.sql((ROOT/'install.sql').read_text(),error='own-out reader changed concurrently');self.sql((ROOT/'rollback.sql').read_text(),error='own-out reader changed concurrently')
if __name__=='__main__':unittest.main(verbosity=2)
