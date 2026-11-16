"""Native PG17: an exact reviewed mode transition; all other guards remain."""
import copy,importlib.util,json,sys,unittest
from pathlib import Path
import build
ROOT=Path(__file__).resolve().parent;SNAP=ROOT.parent/'review_snapshot_v450'
spec=importlib.util.spec_from_file_location('snapshot_build',SNAP/'build.py');snap=importlib.util.module_from_spec(spec);spec.loader.exec_module(snap)
spec=importlib.util.spec_from_file_location('snapshot_tests',SNAP/'test_native.py');base=importlib.util.module_from_spec(spec)
saved=sys.modules['build'];sys.modules['build']=snap
try:spec.loader.exec_module(base)
finally:sys.modules['build']=saved
U=base.OWNER
def uid(n):return f'10000000-0000-4000-8000-{n:012d}'
def fixture(reviewed=False):
 pay={'id':'issuer-payment-one','paymentDate':'2026-02-05T00:00:00.000Z','valueType':'OTHER_PAYMENT','amount':100,'paymentMode':'DEBIT_ACCOUNT','currencyCode':'BRL'}
 link={'id':uid(3),'user_id':U,'active':True,'institution_code':'336','provider_item_id':'fixture-item','invoice_source_id':uid(1),'payment_source_id':uid(2),'invoice_account_ref':'fixture-card','payment_account_ref':'fixture-checking','expected_amount':100,'expected_due_date':'2026-02-05','expected_closing_date':'2026-01-25','expected_payment_date':'2026-02-05','invoice_raw_hash':'a'*64,'payment_raw_hash':'b'*64,'documentary_sources':[{'source':'fixture-invoice'},{'source':'fixture-bank'}]}
 canonical={'id':'fixture-invoice','totalAmount':100,'payments':[pay]}
 contract={'active':True,'user_id':U,'invoice_id':uid(1),'payment_id':uid(2),'amount':100,'link_contract':copy.deepcopy(link),'issuer_payments':[copy.deepcopy(pay)],'settlement_manifest':[copy.deepcopy(pay)],'issuer_settlement_policy':'one_c6_other_payment_in_cycle_v351','invoice_evidence_policy':'raw_except_updatedAt_v1','invoice_current_hash':'a'*64,'invoice_canonical_payload':copy.deepcopy(canonical),'reviewed_other_payment':{'basis':'one_c6_cycle_and_exact_posted_bank_debit','invoice_id':uid(1),'payment_id':uid(2),'bank_description':'PGTO FAT CARTAO C6','issuer_payment_id':pay['id']}}
 common={'user_id':U,'currency':'BRL','provider_deleted_at':None,'institution_code':'336'}
 invoice={**common,'id':uid(1),'resource_type':'invoice','provider_record_id':'fixture-item:invoice','provider_account_ref':'fixture-card','signed_amount':100,'normalized_payload':{'due_date':'2026-02-05','closing_date':'2026-01-25'},'raw_payload':{**copy.deepcopy(canonical),'updatedAt':'2026-02-20T00:00:00.000Z'}}
 bank={**common,'id':uid(2),'resource_type':'transaction','provider_record_id':'fixture-item:bank','provider_account_ref':'fixture-checking','signed_amount':-100,'posting_date':'2026-02-05','raw_hash':'b'*64,'description_raw':'PGTO FAT CARTAO C6','normalized_payload':{'status':'POSTED','account_type':'CHECKING_ACCOUNT'},'raw_payload':{'status':'POSTED'}}
 if reviewed:
  changed={**pay,'paymentMode':'BANK_SLIP'}
  mode={'version':'reviewed-c6-mode-v450','user_id':U,'link_id':uid(3),'invoice_id':uid(1),'payment_id':uid(2),'invoice_prior_raw_hash':'a'*64,'invoice_current_raw_hash':'c'*64,'bank_payment_raw_hash':'b'*64,'prior_payment':copy.deepcopy(pay),'current_payment':changed}
  contract.update(reviewed_issuer_payment_mode_v450=mode,issuer_payments=[changed],settlement_manifest=[changed]);contract['invoice_canonical_payload']['payments']=[changed]
  invoice['raw_payload']['payments']=[changed]
 return {'link':link,'invoice':invoice,'payment':bank,'contract':contract}
class C6Mode(base.Native):
 test_exact_rows_guards_security_and_lifecycle=None
 @classmethod
 def setUpClass(cls):
  super().setUpClass()
  try:
   cls.sql("CREATE FUNCTION public.lts_card_cycle_settlement_v301(jsonb,jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$SELECT NULL::jsonb$$;")
   for sig,name in [(build.CYCLE,'cycle-original.sql'),(build.ANNOTATION,'annotation-original.sql'),(build.PROFILE,'profile-original.sql')]:
    cls.sql(build.original(name));cls.sql(f'ALTER FUNCTION {sig} OWNER TO postgres;REVOKE ALL ON FUNCTION {sig} FROM PUBLIC,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION {sig} TO service_role;')
   cls.sql(build.original('later-original.sql'))
  except BaseException:cls.tearDownClass();raise
 def read(self,f,expression):
  return self.sql("WITH f AS(SELECT $fixture$"+json.dumps(f)+"$fixture$::jsonb j) SELECT "+expression+" FROM f;")
 def annotation(self,f):
  return self.read(f,f"public.lts_card_payment_refresh_annotation_v273('{U}',j->'link',j->'invoice',j->'payment',j->'contract','2026-02-28') IS NOT NULL")
 def test_exact_reviewed_mode_and_lifecycle(self):
  normal=fixture();updated=fixture(True)
  self.assertEqual(self.annotation(normal),'t');self.assertEqual(self.annotation(updated),'f')
  no_review=copy.deepcopy(updated);del no_review['contract']['reviewed_issuer_payment_mode_v450']
  meta=f"SELECT jsonb_agg(jsonb_build_array(oid::regprocedure::text,proacl,proconfig,prosecdef,proowner) ORDER BY oid) FROM pg_proc WHERE oid IN('{build.CYCLE}'::regprocedure,'{build.ANNOTATION}'::regprocedure,'{build.PROFILE}'::regprocedure);"
  before_meta=self.sql(meta)
  self.sql('SET ROLE postgres;'+(ROOT/'install.sql').read_text());self.sql('SET ROLE postgres;'+(ROOT/'install.sql').read_text());self.assertEqual(before_meta,self.sql(meta))
  self.assertEqual(self.sql("SET search_path='';SELECT md5(pg_get_functiondef('"+build.HELPER+"'::regprocedure));"),build.md5(build.original('helper.sql')))
  self.assertEqual(self.annotation(normal),'t');self.assertEqual(self.annotation(no_review),'f');self.assertEqual(self.annotation(updated),'t')
  mutations=[('user_id',base.OTHER),('link_id',uid(90)),('invoice_id',uid(91)),('payment_id',uid(92)),('invoice_prior_raw_hash','wrong'),('bank_payment_raw_hash','wrong'),('invoice_current_raw_hash','missing'),('version','unknown')]
  for key,value in mutations:
   f=copy.deepcopy(updated);f['contract']['reviewed_issuer_payment_mode_v450'][key]=value;self.assertEqual(self.annotation(f),'f',key)
  for key,value in [('amount',99),('id','another-payment'),('paymentDate','2026-02-06T00:00:00.000Z'),('currencyCode','USD'),('valueType','PARTIAL_PAYMENT')]:
   f=copy.deepcopy(updated);f['contract']['reviewed_issuer_payment_mode_v450']['prior_payment'][key]=value;self.assertEqual(self.annotation(f),'f',key)
  for path,value in [(('payment','raw_hash'),'changed'),(('payment','signed_amount'),-99),(('payment','posting_date'),'2026-02-06'),(('payment','user_id'),base.OTHER)]:
   f=copy.deepcopy(updated);f[path[0]][path[1]]=value;self.assertEqual(self.annotation(f),'f',str(path))
  f=copy.deepcopy(updated);f['payment']['normalized_payload']['status']='PENDING';self.assertEqual(self.annotation(f),'f')
  f=copy.deepcopy(updated);f['contract']['issuer_payments']*=2;self.assertEqual(self.annotation(f),'f','Duplicate receipt stays rejected')
  later={'id':'future-payment','paymentDate':'2026-02-20T00:00:00.000Z','valueType':'OTHER_PAYMENT','paymentMode':'DEBIT_ACCOUNT','currencyCode':'BRL','amount':150}
  f=copy.deepcopy(updated);f['invoice']['raw_payload']['payments'].append(later);self.assertEqual(self.annotation(f),'t','Existing permitted later receipt remains separate')
  f['invoice']['raw_payload']['payments'][1]['paymentMode']='BANK_SLIP';self.assertEqual(self.annotation(f),'f','Unreviewed other BANK_SLIP is not authorized')
  for role in ['anon','authenticated']:
   self.sql(f"SET ROLE {role};SELECT {build.NS}.reviewed_c6_mode_v450('{{}}','{{}}','{{}}');",error='permission denied')
  self.sql((ROOT/'rollback.sql').read_text());self.assertEqual(self.annotation(updated),'f');self.assertEqual(self.annotation(normal),'t');self.assertEqual(before_meta,self.sql(meta))
  self.sql((ROOT/'install.sql').read_text());self.sql(build.cycle().replace('DECLARE x jsonb;','DECLARE changed_concurrently integer; x jsonb;',1))
  self.sql((ROOT/'install.sql').read_text(),error='C6 reviewed reader changed concurrently')
if __name__=='__main__':unittest.main(verbosity=2)
