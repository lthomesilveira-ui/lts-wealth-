"""Native function/installer contracts with invented data and a socket-only DB."""
import importlib.util, os, re, subprocess, tempfile, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parent
USER='00000000-0000-0000-0000-000000000001'
OTHER='00000000-0000-0000-0000-000000000099'
TARGET='00000000-0000-0000-0000-000000000002'
SCHEMA="""
CREATE SCHEMA auth;
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql AS $$SELECT '{"email":"fixture@example.invalid"}'::jsonb$$;
CREATE FUNCTION public.lts_browser_assert_user_v1() RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE u uuid:=nullif(current_setting('fixture.user',true),'')::uuid;
BEGIN IF u IS NULL THEN RAISE EXCEPTION 'Authentication required';END IF;RETURN u;END$$;
CREATE FUNCTION public.lts_v178_norm(text) RETURNS text LANGUAGE sql AS 'SELECT lower(trim($1))';
CREATE FUNCTION public.lts_category_name_v290(uuid,text) RETURNS text LANGUAGE sql AS 'SELECT $2';
CREATE TABLE public.lts_open_finance_staging(id uuid PRIMARY KEY,user_id uuid,resource_type text,
 provider_deleted_at timestamptz,normalized_payload jsonb,raw_payload jsonb,posting_date date);
CREATE TABLE public.lts_card_document_supplement_v234(id uuid,user_id uuid,purchase_date date);
CREATE TABLE public.evento_base(idx int,usuario_id uuid,dados jsonb);
CREATE TABLE public.historico_analitico(idx int,usuario_id uuid,dados jsonb);
CREATE TABLE public.lts_card_purchase_detail(user_id uuid,line_key text,purchase_key text,invoice_due_date date);
CREATE TABLE public.lts_category_catalog(user_id uuid,category text,active boolean);
CREATE TABLE public.lts_product_read_cache(user_id uuid,payload jsonb);
CREATE TABLE public.lts_v178_review_decision(user_id uuid,source_table text,source_ref text,
 beneficiary text,property_code text,category_label text,decision_basis text,decided_at timestamptz DEFAULT now(),
 PRIMARY KEY(user_id,source_table,source_ref));
CREATE TABLE public.lts_access_audit(user_id uuid,email text,action text,meta jsonb);
CREATE TABLE public.fixture_occurrence(user_id uuid,source_table text,source_ref text,event_date date,
 category_needed boolean,person_needed boolean,property_needed boolean);
CREATE TABLE public.fixture_calls(kind text,from_day date,to_day date);
CREATE FUNCTION public.lts_browser_card_category_options_v226() RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN INSERT INTO public.fixture_calls(kind) VALUES('options');RETURN '{"categories":["Historical allowed"]}'::jsonb;END$$;
CREATE FUNCTION public.lts_v229_review_rows(u uuid,f date,t date)
RETURNS TABLE(source_table text,source_ref text,event_date date,identity_status text,
 category text,management_group text,management_subgroup text) LANGUAGE plpgsql AS $$
BEGIN
 INSERT INTO public.fixture_calls VALUES('rows',f,t);
 RETURN QUERY SELECT o.source_table,o.source_ref,o.event_date,
 CASE WHEN (o.category_needed AND d.category_label IS NULL) OR (o.person_needed AND d.beneficiary IS NULL)
 OR(o.property_needed AND d.property_code IS NULL) THEN 'pending' ELSE 'resolved' END,
 coalesce(d.category_label,'Unspecified'),'Fixture group'::text,'Fixture subgroup'::text
 FROM public.fixture_occurrence o LEFT JOIN public.lts_v178_review_decision d
 ON d.user_id=o.user_id AND d.source_table=o.source_table AND d.source_ref=o.source_ref
 WHERE o.user_id=u AND o.event_date BETWEEN f AND t;
END$$;
"""

class NativeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bin=Path(os.environ.get('LTS_INSTALLER_PG_BIN','/usr/lib/postgresql/17/bin'))
        if not (cls.bin/'initdb').is_file():raise RuntimeError('PostgreSQL17 required; no remote fallback')
        if not re.search(r'PostgreSQL\) 17\.',subprocess.check_output([str(cls.bin/'postgres'),'--version'],text=True)):
            raise RuntimeError('PostgreSQL17 required')
        cls.tmp=tempfile.TemporaryDirectory(prefix='lts-review-decision-');cls.root=Path(cls.tmp.name)
        cls.data=cls.root/'data';cls.sock=cls.root/'socket';cls.sock.mkdir()
        cls.env={k:v for k,v in os.environ.items() if not k.startswith('PG')};cls.env.update({'LC_ALL':'C','LANG':'C'})
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
        p=subprocess.run([str(cls.bin/'psql'),'-X','-A','-t','-q','-v','ON_ERROR_STOP=1','-h',str(cls.sock),'-U','fixture_admin','-d','postgres'],input=text,text=True,capture_output=True,env=cls.env)
        if error:
            if p.returncode==0 or error not in p.stderr:raise AssertionError((error,p.returncode,p.stderr))
        elif p.returncode:raise AssertionError(p.stderr)
        return p.stdout.strip()
    def seed(self,resource='transaction',status='POSTED',deleted=False,needs_person=False,needs_property=False):
        self.sql("TRUNCATE public.lts_v178_review_decision,public.lts_access_audit,public.fixture_occurrence,public.fixture_calls,public.lts_open_finance_staging,public.lts_category_catalog,public.lts_product_read_cache;")
        self.sql(f"""INSERT INTO public.lts_open_finance_staging VALUES('{TARGET}','{USER}','{resource}',{'now()' if deleted else 'null'},
        '{{"account_type":"CHECKING_ACCOUNT","status":"{status}"}}','{{}}',current_date-3);
        INSERT INTO public.fixture_occurrence VALUES('{USER}','lts_open_finance_staging','{TARGET}',current_date-3,true,{str(needs_person).lower()},{str(needs_property).lower()});
        INSERT INTO public.lts_category_catalog VALUES('{USER}','Known active',true),('{USER}','Inactive',false);""")
    def call(self,category='Known active',person='NULL',property='NULL',user=USER,error=None,ref=TARGET):
        return self.sql(f"SET fixture.user='{user}';SELECT public.lts_browser_expense_review_decision_v229('lts_open_finance_staging','{ref}',{person},{property},'{category}')->>'resolved';",error)
    def test_actual_function_and_guarded_lifecycle(self):
        original=(ROOT/'original.sql').read_text();self.sql(original)
        original_hash=self.sql("SELECT md5(pg_get_functiondef('public.lts_browser_expense_review_decision_v229(text,text,text,text,text)'::regprocedure));")
        self.assertEqual(original_hash,'56e9806983eab4effd105fdf5ee302e8')
        # The original body demonstrably reads the whole month and options.
        self.seed();self.assertEqual(self.call(),'true')
        self.assertEqual(self.sql("SELECT count(*)>0 FROM public.fixture_calls WHERE kind='options';"),'t')
        self.sql((ROOT/'install.sql').read_text())
        installed=self.sql("SELECT pg_get_functiondef('public.lts_browser_expense_review_decision_v229(text,text,text,text,text)'::regprocedure);")
        self.sql((ROOT/'install.sql').read_text())
        self.assertEqual(self.sql("SELECT pg_get_functiondef('public.lts_browser_expense_review_decision_v229(text,text,text,text,text)'::regprocedure);"),installed)
        self.seed();source=self.sql('SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.lts_open_finance_staging s;')
        self.assertEqual(self.call(),'true')
        self.assertEqual(self.sql("SELECT count(*) FROM public.fixture_calls WHERE kind='rows' AND from_day=current_date-3 AND to_day=current_date-3;"),'2')
        self.assertEqual(self.sql("SELECT count(*) FROM public.fixture_calls WHERE kind='options';"),'0')
        self.assertEqual(self.sql('SELECT count(*) FROM public.lts_access_audit;'),'1')
        self.assertEqual(self.sql('SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.lts_open_finance_staging s;'),source)
        self.call(error='pending review item not found')
        self.assertEqual(self.sql('SELECT count(*) FROM public.lts_v178_review_decision;'),'1')
        # Original broader scope and legacy allowlist alternatives remain valid.
        for resource,status,deleted in [('card_transaction','POSTED',False),('transaction','PENDING',False),('transaction','POSTED',True)]:
            self.seed(resource,status,deleted);self.assertEqual(self.call(),'true')
            self.assertEqual(self.sql("SELECT count(*) FROM public.fixture_calls WHERE kind='rows' AND from_day=date_trunc('month',current_date-3)::date AND to_day=current_date;"),'2')
        self.seed();self.assertEqual(self.call('Historical allowed'),'true')
        self.seed();self.sql(f"INSERT INTO public.lts_product_read_cache VALUES('{USER}','{{\"card_classification_review\":{{\"category_options\":[\"Cached allowed\"]}}}}');")
        self.assertEqual(self.call('Cached allowed'),'true')
        for category,person,property,error in [('Inactive','NULL','NULL','Categoria desativada'),('Unknown','NULL','NULL','unknown category'),('Known active',"'Stranger'",'NULL','invalid beneficiary'),('Known active','NULL',"'unknown-property'",'invalid property')]:
            self.seed();self.call(category,person,property,error=error)
            self.assertEqual(self.sql('SELECT count(*) FROM public.lts_v178_review_decision;'),'0')
        self.seed();self.call(user=OTHER,error='pending review item not found')
        self.sql("SET fixture.user='';SELECT public.lts_browser_expense_review_decision_v229('x','y',NULL,NULL,'Known active');",error='Authentication required')
        self.seed(needs_person=True);self.call(error='A decisão não resolveu')
        self.assertEqual(self.sql('SELECT count(*) FROM public.lts_v178_review_decision;'),'0')
        self.assertEqual(self.call(person="'Benjamin'"),'true')
        self.seed(needs_property=True);self.call(error='A decisão não resolveu')
        self.assertEqual(self.call(property="'cipo396'"),'true')
        self.sql((ROOT/'rollback.sql').read_text())
        self.assertEqual(self.sql("SELECT md5(pg_get_functiondef('public.lts_browser_expense_review_decision_v229(text,text,text,text,text)'::regprocedure));"),original_hash)
        self.sql((ROOT/'install.sql').read_text())
        self.sql("COMMENT ON FUNCTION public.lts_browser_expense_review_decision_v229(text,text,text,text,text) IS 'fixture';")
        # A concurrent body edit must block both installation and rollback.
        altered=installed.replace("'source required'","'fixture concurrent body'")
        self.sql(altered)
        self.sql((ROOT/'install.sql').read_text(),error='changed concurrently')
        self.sql((ROOT/'rollback.sql').read_text(),error='changed concurrently')

if __name__=='__main__':unittest.main(verbosity=2)
