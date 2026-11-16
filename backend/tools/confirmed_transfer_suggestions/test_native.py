"""Actual SQL function and lifecycle on invented, socket-only PostgreSQL17 data."""
import json,os,re,subprocess,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parent
OWNER='00000000-0000-0000-0000-000000000001'
TARGET='00000000-0000-0000-0000-000000000002'
PRIOR='00000000-0000-0000-0000-000000000003'
SCHEMA="""
CREATE FUNCTION public.lts_v178_norm(text) RETURNS text LANGUAGE sql IMMUTABLE AS 'SELECT lower(trim($1))';
CREATE FUNCTION public.lts_card_merchant_key_v226(text) RETURNS text LANGUAGE sql IMMUTABLE AS 'SELECT lower(trim($1))';
CREATE FUNCTION public.lts_bank_merchant_key_v231(text) RETURNS text LANGUAGE sql IMMUTABLE AS 'SELECT lower(trim($1))';
CREATE TABLE public.lts_open_finance_staging(id uuid PRIMARY KEY,user_id uuid,resource_type text,signed_amount numeric,
 normalized_payload jsonb,raw_payload jsonb,provider_deleted_at timestamptz,posting_date date,description_raw text,
 provider text,institution_code text,provider_account_ref text,currency text);
CREATE TABLE public.lts_v178_review_decision(user_id uuid,source_table text,source_ref text,category_label text,
 beneficiary text,property_code text,decision_basis text);
CREATE TABLE public.lts_category_catalog(user_id uuid,category text,active boolean);
CREATE TABLE public.lts_card_purchase_detail(user_id uuid,line_key text,description_raw text,category text,
 installment_amount numeric,invoice_due_date date,purchase_date date,card_final text,installments int);
CREATE TABLE public.financial_events(user_id uuid,id uuid,description_raw text,category text,amount numeric,
 event_date date,metadata jsonb,is_suppressed boolean,is_projection boolean);
CREATE TABLE public.lts_document_card_purchase(user_id uuid,id uuid,description text,category text,amount numeric,
 purchase_date date,metadata jsonb,cost_center text,status text);
CREATE TABLE public.lts_manual_card_purchase(LIKE public.lts_document_card_purchase INCLUDING ALL);
CREATE TABLE public.lts_card_history_recovered_purchase(user_id uuid,source_hash text,description_raw text,
 canonical_category text,category_raw text,amount numeric,invoice_due_date date,card_final text,evidence jsonb);
CREATE TABLE public.card_invoices(user_id uuid,id uuid,due_date date,metadata jsonb);
CREATE TABLE public.historico_analitico(usuario_id uuid,idx int,dados jsonb);
CREATE TABLE public.lts_semantic_rule(user_id uuid,id text,active boolean,confidence text,category text,
 center_cost text,match_type text,match_value text);
CREATE TABLE public.lts_v229_review_suggestion(user_id uuid,source_table text,source_ref text,category text,
 basis text,note text,source_url text);
CREATE TABLE public.lts_merchant_research_v231(user_id uuid,merchant_key text,category text,note text,source_url text);
"""
class NativeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bin=Path(os.environ.get('LTS_INSTALLER_PG_BIN','/usr/lib/postgresql/17/bin'))
        if not (cls.bin/'initdb').is_file():raise RuntimeError('PostgreSQL17 required; no remote fallback')
        cls.tmp=tempfile.TemporaryDirectory(prefix='lts-repeat-suggestion-');cls.root=Path(cls.tmp.name)
        cls.data=cls.root/'data';cls.sock=cls.root/'socket';cls.sock.mkdir()
        cls.env={k:v for k,v in os.environ.items() if not k.startswith('PG')}
        cls.env.update({'LC_ALL':'C','LANG':'C','PGTZ':'America/Sao_Paulo'})
        subprocess.run([str(cls.bin/'initdb'),'-D',str(cls.data),'-A','trust','--no-locale','-U','fixture_admin'],check=True,env=cls.env,capture_output=True)
        cls.started=False
        try:
            subprocess.run([str(cls.bin/'pg_ctl'),'-D',str(cls.data),'-l',str(cls.root/'server.log'),'-o',f"-k {cls.sock} -c listen_addresses='' -c shared_preload_libraries=''",'-w','start'],check=True,env=cls.env,capture_output=True);cls.started=True
            cls.sql(SCHEMA)
        except BaseException:cls.tearDownClass();raise
    @classmethod
    def tearDownClass(cls):
        if getattr(cls,'started',False):subprocess.run([str(cls.bin/'pg_ctl'),'-D',str(cls.data),'-m','immediate','-w','stop'],env=cls.env,capture_output=True)
        if hasattr(cls,'tmp'):cls.tmp.cleanup()
    @classmethod
    def sql(cls,text,error=None):
        r=subprocess.run([str(cls.bin/'psql'),'-X','-A','-t','-q','-v','ON_ERROR_STOP=1','-h',str(cls.sock),'-U','fixture_admin','-d','postgres'],input=text,text=True,capture_output=True,env=cls.env)
        if error:
            if not r.returncode or error not in r.stderr:raise AssertionError((error,r.returncode,r.stderr))
        elif r.returncode:raise AssertionError(r.stderr)
        return r.stdout.strip()
    def seed(self):
        self.sql('TRUNCATE public.lts_open_finance_staging,public.lts_v178_review_decision,public.lts_category_catalog;')
        self.sql(f"""INSERT INTO public.lts_open_finance_staging VALUES
        ('{TARGET}','{OWNER}','transaction',-123.45,'{{"account_type":"CHECKING_ACCOUNT","status":"POSTED","operation_type":"PIX"}}',
        '{{"paymentData":{{"receiver":{{"documentNumber":{{"type":"CPF","value":"11111111111"}}}}}}}}',null,current_date-2,'Fixture recipient','fixture','001','fixture-account','BRL'),
        ('{PRIOR}','{OWNER}','transaction',-123.45,'{{"account_type":"CHECKING_ACCOUNT","status":"POSTED","operation_type":"PIX"}}',
        '{{"paymentData":{{"receiver":{{"documentNumber":{{"type":"CPF","value":"11111111111"}}}}}}}}',null,current_date-22,'Fixture recipient','fixture','001','fixture-account','BRL');
        INSERT INTO public.lts_v178_review_decision VALUES('{OWNER}','lts_open_finance_staging','{PRIOR}','Fixture health',null,null,'authenticated_user_v229');
        INSERT INTO public.lts_category_catalog VALUES('{OWNER}','Fixture health',true),('{OWNER}','Fixture other',true);""")
    def query(self,override="'{}'::jsonb",owner=OWNER):
        return json.loads(self.sql(f"""SELECT suggestion::text FROM public.lts_review_suggestions_v231('{owner}',
        (SELECT jsonb_build_array(jsonb_build_object('source_table','lts_open_finance_staging','source_ref',id,
        'description',description_raw,'amount',abs(signed_amount),'event_date',posting_date,
        'category','A classificar','question_kind','classification')||{override}) FROM public.lts_open_finance_staging WHERE id='{TARGET}'));"""))
    def test_confirmed_repeat_and_lifecycle(self):
        original=(ROOT/'original.sql').read_text();self.sql(original);self.seed()
        self.assertEqual(self.query()['basis'],'recipient_does_not_establish_purpose')
        self.sql((ROOT/'install.sql').read_text());self.sql((ROOT/'install.sql').read_text())
        installed=self.sql("SELECT pg_get_functiondef('public.lts_review_suggestions_v231(uuid,jsonb)'::regprocedure);")
        before=self.sql('SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.lts_open_finance_staging s;')
        decision_before=self.sql('SELECT md5(jsonb_agg(to_jsonb(d))::text) FROM public.lts_v178_review_decision d;')
        result=self.query();self.assertEqual(result['category'],'Fixture health')
        self.assertEqual(result['basis'],'confirmed_recipient_amount_history')
        self.assertTrue(result['requires_confirmation']);self.assertIsNone(result.get('beneficiary'))
        self.assertEqual(result['evidence']['source_ref'],PRIOR)
        self.assertNotIn('11111111111',json.dumps(result))
        self.assertEqual(before,self.sql('SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.lts_open_finance_staging s;'))
        self.assertEqual(decision_before,self.sql('SELECT md5(jsonb_agg(to_jsonb(d))::text) FROM public.lts_v178_review_decision d;'))
        changes=["signed_amount=-123.46","signed_amount=123.45","provider='different'","institution_code='999'",
         "provider_account_ref='other-account'","currency='USD'","posting_date=current_date-500","posting_date=current_date+1",
         "provider_deleted_at=now()","user_id='00000000-0000-0000-0000-000000000099'",
         "normalized_payload=jsonb_set(normalized_payload,'{status}','\"PENDING\"')",
         "normalized_payload=jsonb_set(normalized_payload,'{operation_type}','\"TED\"')",
         "raw_payload=jsonb_set(raw_payload,'{paymentData,receiver,documentNumber,value}','\"22222222222\"')"]
        for change in changes:
            with self.subTest(change=change):
                self.seed();self.sql(f"UPDATE public.lts_open_finance_staging SET {change} WHERE id='{PRIOR}';")
                self.assertNotEqual(self.query().get('basis'),'confirmed_recipient_amount_history')
        self.seed();self.sql("UPDATE public.lts_v178_review_decision SET decision_basis='verified_merchant_activity_v999:fixture';")
        self.assertIsNone(self.query().get('category'))
        self.seed();self.sql("UPDATE public.lts_category_catalog SET active=false WHERE category='Fixture health';")
        self.assertIsNone(self.query().get('category'))
        self.seed();self.sql(f"""INSERT INTO public.lts_open_finance_staging SELECT '00000000-0000-0000-0000-000000000004',user_id,resource_type,signed_amount,normalized_payload,raw_payload,provider_deleted_at,posting_date-1,description_raw,provider,institution_code,provider_account_ref,currency FROM public.lts_open_finance_staging WHERE id='{PRIOR}';
        INSERT INTO public.lts_v178_review_decision VALUES('{OWNER}','lts_open_finance_staging','00000000-0000-0000-0000-000000000004','Fixture other',null,null,'authenticated_detail_v232');""")
        self.assertIsNone(self.query().get('category'))
        for override in ["'{\"amount\":123.46}'::jsonb","'{\"description\":\"fake recipient\"}'::jsonb"]:
            self.seed();self.assertNotEqual(self.query(override).get('basis'),'confirmed_recipient_amount_history')
        self.seed();self.assertNotEqual(self.query(owner='00000000-0000-0000-0000-000000000099').get('basis'),'confirmed_recipient_amount_history')
        self.sql((ROOT/'rollback.sql').read_text())
        self.assertEqual(self.query()['basis'],'recipient_does_not_establish_purpose')
        self.sql((ROOT/'install.sql').read_text())
        self.sql(installed.replace("'confirmed_recipient_amount_history'","'fixture concurrent edit'"))
        self.sql((ROOT/'install.sql').read_text(),error='changed concurrently')
        self.sql((ROOT/'rollback.sql').read_text(),error='changed concurrently')

if __name__=='__main__':unittest.main(verbosity=2)
