"""Native PostgreSQL17: exact live SQL blocks, installer guards and array parity.

Source helpers use invented fixture tables. This is not a production restoration.
"""
import json,os,subprocess,tempfile,time,unittest
from pathlib import Path
import build
ROOT=Path(__file__).resolve().parent
OWNER='00000000-0000-0000-0000-000000000001'
OTHER='00000000-0000-0000-0000-000000000099'
SCHEMA="""
CREATE ROLE postgres NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE TABLE public.financial_events(id uuid,user_id uuid,legacy_id text,is_projection boolean,is_suppressed boolean,event_date date,amount numeric);
CREATE TABLE public.card_invoices(user_id uuid,card_name text,reference_month date,due_date date,status text,amount numeric);
CREATE TABLE public.fixture_bills(user_id uuid,family text,reference_month date,due_date date,amount numeric,
 invoice_source_id uuid,payment_status text,reported_payment_amount numeric);
CREATE TABLE public.fixture_settlements(user_id uuid,card_name text,reference_month date,due_date date,amount numeric,status text);
CREATE FUNCTION public.lts_current_received_card_bills_v263(uuid)
 RETURNS TABLE(family text,reference_month date,due_date date,amount numeric,invoice_source_id uuid,payment_status text,reported_payment_amount numeric)
 LANGUAGE sql STABLE AS 'SELECT family,reference_month,due_date,amount,invoice_source_id,payment_status,reported_payment_amount FROM public.fixture_bills WHERE user_id=$1';
CREATE FUNCTION public.lts_card_family_v226(text,text) RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT CASE WHEN $1 LIKE '%Mastercard%' THEN 'itau_mastercard' ELSE 'other' END$$;
CREATE FUNCTION public.lts_card_invoice_account_v181(text) RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT CASE WHEN $1 LIKE '%Mastercard%' THEN 'Itaú' ELSE 'Bradesco' END$$;
CREATE FUNCTION public.lts_card_invoice_settled_v290(uuid,text,date,date,numeric) RETURNS boolean LANGUAGE sql STABLE AS $$
 SELECT EXISTS(SELECT FROM public.fixture_settlements WHERE user_id=$1 AND card_name=$2 AND reference_month=$3 AND due_date=$4 AND amount=$5 AND status='POSTED')$$;
CREATE FUNCTION public.lts_pending_projections_v233(uuid) RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT '[]'::jsonb$$;
"""
class NativeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bin=Path(os.environ.get('LTS_INSTALLER_PG_BIN','/usr/lib/postgresql/17/bin'))
        if not (cls.bin/'initdb').is_file():raise RuntimeError('PostgreSQL17 required; no remote fallback')
        cls.tmp=tempfile.TemporaryDirectory(prefix='lts-due-today-');cls.root=Path(cls.tmp.name)
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
        result=subprocess.run([str(cls.bin/'psql'),'-X','-A','-t','-q','-v','ON_ERROR_STOP=1','-h',str(cls.sock),'-U','fixture_admin','-d','postgres'],input=text,text=True,capture_output=True,env=cls.env)
        if error:
            if not result.returncode or error not in result.stderr:raise AssertionError((error,result.returncode,result.stderr))
        elif result.returncode:raise AssertionError(result.stderr)
        return result.stdout.strip()
    def seed(self):
        self.sql(f"""TRUNCATE public.financial_events,public.card_invoices,public.fixture_bills,public.fixture_settlements;
         INSERT INTO public.card_invoices VALUES('{OWNER}','Fixture Mastercard',date_trunc('month',current_date),current_date,'projected',100);
         INSERT INTO public.fixture_bills VALUES('{OWNER}','itau_mastercard',date_trunc('month',current_date),current_date,123.45,
          '00000000-0000-0000-0000-000000000002','payment_not_reported',0);""")
    def row(self,**changes):
        today=self.sql('SELECT current_date::text;');month=today[:7]
        return {'source':'card_invoice','source_ref':'Fixture Mastercard|'+month,'event_date':today,'original_date':today,
         'account':'Itaú','description':'Fixture invoice','signed_amount':-123.45,'confidence':'documented_projected_snapshot',**changes}
    def make_block(self,name,text):
        # The executable statements are extracted unchanged from each full live definition.
        body=build.block(text)
        self.sql(f"""CREATE OR REPLACE FUNCTION public.{name}(p_rows jsonb,p_owner uuid) RETURNS jsonb LANGUAGE plpgsql AS $fixture$
         DECLARE u uuid:=p_owner;recent jsonb:=p_rows;pending_predictions jsonb;
          anchors jsonb:=jsonb_build_array(jsonb_build_object('bank','Itaú','date',current_date-10),jsonb_build_object('bank','Bradesco','date',current_date-10));
         BEGIN {body} RETURN recent;END $fixture$;""")
    def query(self,name,rows,owner=OWNER):
        data=json.dumps(rows,ensure_ascii=False).replace("'","''")
        return json.loads(self.sql(f"SELECT public.{name}('{data}'::jsonb,'{owner}');"))
    def facts_hash(self):
        return self.sql("""SELECT md5(jsonb_build_array((SELECT jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text) FROM public.card_invoices x),
         (SELECT jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text) FROM public.fixture_bills x),
         (SELECT jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text) FROM public.financial_events x))::text);""")
    def test_due_today_and_guarded_lifecycle(self):
        for target in build.TARGETS:
            self.sql((ROOT/target['file']).read_text())
            signature=target['signature']
            self.sql(f"ALTER FUNCTION {signature} OWNER TO postgres;REVOKE ALL ON FUNCTION {signature} FROM PUBLIC,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION {signature} TO service_role;")
        before_meta=self.sql("""SELECT jsonb_agg(jsonb_build_array(oid::regprocedure::text,proacl,proconfig,prosecdef,proowner) ORDER BY oid::regprocedure::text)
         FROM pg_proc WHERE oid IN('public.lts_flow_cache_pre_v240(uuid,date,date)'::regprocedure,'public.lts_browser_flow_pre_v238(date,date)'::regprocedure);""")
        self.sql((ROOT/'install.sql').read_text());self.sql((ROOT/'install.sql').read_text())
        after_meta=self.sql("""SELECT jsonb_agg(jsonb_build_array(oid::regprocedure::text,proacl,proconfig,prosecdef,proowner) ORDER BY oid::regprocedure::text)
         FROM pg_proc WHERE oid IN('public.lts_flow_cache_pre_v240(uuid,date,date)'::regprocedure,'public.lts_browser_flow_pre_v238(date,date)'::regprocedure);""")
        self.assertEqual(before_meta,after_meta)
        for target in build.TARGETS:
            original=(ROOT/target['file']).read_text();replacement=build.patch(original,target['array'])
            self.make_block('fixture_old',original);self.make_block('fixture_new',replacement);self.seed()
            source=self.row();before=self.facts_hash()
            self.assertEqual(self.query('fixture_old',[source]),[])
            result=self.query('fixture_new',[source]);self.assertEqual(len(result),1)
            self.assertTrue(result[0]['unposted_current_projection'])
            self.assertEqual({k:v for k,v in result[0].items() if k!='unposted_current_projection'},source)
            self.assertEqual(before,self.facts_hash())
            self.assertEqual(sum(x['signed_amount'] for x in result if not x.get('unposted_current_projection')),0)
            self.assertEqual(sum(x['signed_amount'] for x in result if x.get('unposted_current_projection')),-123.45)
            yesterday=self.sql("SELECT (current_date-1)::text;");tomorrow=self.sql("SELECT (current_date+1)::text;")
            for change in [{'signed_amount':-123.46},{'signed_amount':123.45},{'account':'Bradesco'},
             {'source_ref':'Other Mastercard|'+source['event_date'][:7]}, {'source':'legacy_fix86'},
             {'event_date':yesterday},{'event_date':tomorrow}]:
                with self.subTest(target=target['file'],row_change=change):
                    self.assertEqual(self.query('fixture_new',[self.row(**change)]),[])
            self.assertEqual(self.query('fixture_new',[source],OTHER),[])
            changes=["UPDATE public.card_invoices SET status='paid'", "UPDATE public.card_invoices SET user_id='"+OTHER+"'",
             "UPDATE public.fixture_bills SET due_date=current_date-1", "UPDATE public.fixture_bills SET due_date=current_date+1",
             "UPDATE public.fixture_bills SET amount=123.46", "UPDATE public.fixture_bills SET payment_status='partially_paid',reported_payment_amount=1",
             "UPDATE public.fixture_bills SET invoice_source_id=null", "INSERT INTO public.fixture_bills SELECT * FROM public.fixture_bills",
             "DELETE FROM public.fixture_bills"]
            for change in changes:
                with self.subTest(target=target['file'],source_change=change):
                    self.seed();self.sql(change);self.assertEqual(self.query('fixture_new',[source]),[])
            self.seed();posted=self.row(source='open_finance',source_ref='fixture-posted',confidence='bank_posted',bank_confirmed=True)
            self.sql(f"INSERT INTO public.fixture_settlements VALUES('{OWNER}','Fixture Mastercard',date_trunc('month',current_date),current_date,123.45,'PENDING');")
            self.assertEqual(len(self.query('fixture_new',[source])),1,'Pending is not settlement')
            self.sql("UPDATE public.fixture_settlements SET status='POSTED';")
            self.assertEqual(self.query('fixture_new',[source,posted]),[posted],'One posted debit, no second projection')
            self.seed();current=self.row(source='current_event',source_ref='fixture-current',confidence='user_flow_editable')
            self.sql(f"INSERT INTO public.financial_events VALUES('00000000-0000-0000-0000-000000000003','{OWNER}','fixture-current',true,false,current_date,-123.45);")
            self.assertEqual(self.query('fixture_old',[current]),self.query('fixture_new',[current]))
            self.assertTrue(self.query('fixture_new',[current])[0]['unposted_current_projection'])
        for role in ['anon','authenticated']:
            self.sql(f"SET ROLE {role};SELECT public.lts_browser_flow_pre_v238(current_date,current_date);",error='permission denied')
        self.sql((ROOT/'rollback.sql').read_text())
        for target in build.TARGETS:
            self.assertEqual(self.sql(f"SELECT md5(pg_get_functiondef('{target['signature']}'::regprocedure));"),target['md5'])
        self.sql((ROOT/'install.sql').read_text())
        target=build.TARGETS[0];installed=self.sql(f"SELECT pg_get_functiondef('{target['signature']}'::regprocedure);")+"\n"
        self.sql(installed.replace('Current bank positions stay exact.','Fixture concurrent edit.'))
        self.sql((ROOT/'install.sql').read_text(),error='changed concurrently')
        self.sql((ROOT/'rollback.sql').read_text(),error='changed concurrently')
    def test_native_array_assembly_parity(self):
        old=build.ARRAY_CHANGES[2][0].strip();new=build.ARRAY_CHANGES[2][1].strip()
        self.sql(f"""CREATE FUNCTION public.fixture_array(p_count integer,p_new boolean) RETURNS jsonb LANGUAGE plpgsql AS $fixture$
         DECLARE outdays jsonb:='[]';out_day_rows jsonb[]:=ARRAY[]::jsonb[];d jsonb;i integer;
         BEGIN FOR i IN 1..p_count LOOP
          d:=jsonb_build_object('date',current_date+i,'amount',i/100.0,'unknown',null,'nested',jsonb_build_object('complete',i%2=0));
          IF p_new THEN {new} ELSE {old} END IF;
         END LOOP;IF p_new THEN RETURN to_jsonb(out_day_rows);END IF;RETURN outdays;END $fixture$;""")
        for count in [0,1,13,442,1872]:
            with self.subTest(count=count):
                self.assertEqual(self.sql(f"SELECT public.fixture_array({count},false)=public.fixture_array({count},true);"),'t')
        timings={}
        for flag in ['false','true']:
            started=time.monotonic();self.sql(f"SELECT jsonb_array_length(public.fixture_array(1872,{flag}));")
            timings[flag]=round((time.monotonic()-started)*1000,2)
        print(json.dumps({'synthetic_array_1872_days_ms':timings,'physical_iops_measured':False,'production_performance_certified':False}))

if __name__=='__main__':unittest.main(verbosity=2)
