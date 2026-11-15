"""Synthetic PostgreSQL installer contract only; never accepts a remote DB URL.
Requires PostgreSQL 17 binaries; starts a new temporary Unix-socket-only cluster.
The only install.sql substitution is its frozen baseline hash, computed from the
synthetic baseline. Helper and three integration replacements remain unchanged.
"""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent
FROZEN = '24c9b55478e02403bdca12003f5f22fe'
USER = '00000000-0000-0000-0000-000000000001'
BASELINE = """
CREATE OR REPLACE FUNCTION public.lts_expense_rows_v230_baseline(p_user_id uuid,p_from date,p_to date)
RETURNS jsonb LANGUAGE sql AS $baseline$
WITH new_bank_raw as materialized(select * from public.lts_v229_new_bank_rows(p_user_id,p_from,p_to)),
new_bank AS (SELECT * FROM new_bank_raw),
sources(source_table,source_ref,description,category,beneficiary,property_code,meta,priority) AS (
select 'lts_open_finance_staging',n.id::text,n.description,n.category,null,null,'{}'::jsonb,1 from new_bank n
), b AS (SELECT source_table,source_ref FROM sources),
d AS (SELECT NULL::text beneficiary,NULL::text property_code,NULL::text category_label)
SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) FROM (
SELECT s.description,s.beneficiary,s.meta,
d.beneficiary person_decision,d.property_code property_decision,d.category_label category_decision
FROM b JOIN sources s USING(source_ref) CROSS JOIN d) x;
$baseline$;
"""
SCHEMA = """
CREATE ROLE anon; CREATE ROLE authenticated;
CREATE TABLE public.accounts(user_id uuid,institution text,is_active boolean,metadata jsonb);
CREATE TABLE public.lts_open_finance_staging(id uuid,user_id uuid,institution_code text,provider_account_ref text,
 raw_payload jsonb,normalized_payload jsonb,posting_date date,signed_amount numeric,description_raw text,
 resource_type text,currency text,provider_deleted_at timestamptz);
CREATE TABLE public.lts_v229_documentary_match(user_id uuid,staging_id uuid);
CREATE TABLE public.financial_events(user_id uuid,id uuid,legacy_id text);
CREATE TABLE public.lts_semantic_rule(user_id uuid,category text,match_type text,match_value text,active boolean,
 confidence text,is_internal_transfer boolean,is_asset_movement boolean);
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY,epoch bigint);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,10);
CREATE TABLE public.fixture_events(event jsonb);
CREATE TABLE public.fixture_existing(source_ref text);
CREATE FUNCTION public.lts_bank_posted_rows_v231(uuid) RETURNS SETOF public.lts_open_finance_staging
 LANGUAGE sql AS 'SELECT * FROM public.lts_open_finance_staging WHERE user_id=$1';
CREATE FUNCTION public.lts_owner_confirmed_transfer_pairs_v263(uuid) RETURNS TABLE(debit_id uuid,credit_id uuid)
 LANGUAGE sql AS 'SELECT NULL::uuid,NULL::uuid WHERE false';
CREATE FUNCTION public.lts_posted_own_transfer_out_v304(uuid) RETURNS TABLE(source_id uuid)
 LANGUAGE sql AS 'SELECT NULL::uuid WHERE false';
CREATE FUNCTION public.lts_bank_description_key_v229(text) RETURNS text LANGUAGE sql AS 'SELECT lower($1)';
CREATE FUNCTION public.lts_flow_operational_read_v229(uuid,date,date) RETURNS jsonb
 LANGUAGE sql AS 'SELECT coalesce(jsonb_agg(event),''[]''::jsonb) FROM public.fixture_events';
CREATE FUNCTION public.lts_card_settlement_contract_v273(uuid,uuid) RETURNS jsonb LANGUAGE sql AS 'SELECT NULL::jsonb';
CREATE FUNCTION public.lts_expense_effective_rows_v176(uuid,date,date) RETURNS TABLE(source_ref text)
 LANGUAGE sql AS 'SELECT source_ref FROM public.fixture_existing';
CREATE FUNCTION public.lts_v229_new_bank_rows(uuid,date,date)
 RETURNS TABLE(id uuid,event_date date,signed_amount numeric,description text,bank text,category text)
 LANGUAGE sql AS 'SELECT NULL::uuid,NULL::date,NULL::numeric,NULL::text,NULL::text,NULL::text WHERE false';
CREATE FUNCTION public.lts_realized_bank_sources_v238(uuid) RETURNS TABLE(staging_id uuid)
 LANGUAGE sql AS 'SELECT NULL::uuid WHERE false';
CREATE FUNCTION public.lts_bank_known_classification_v231(uuid,uuid) RETURNS jsonb LANGUAGE sql AS 'SELECT NULL::jsonb';
CREATE FUNCTION public.lts_v178_norm(text) RETURNS text LANGUAGE sql AS 'SELECT lower($1)';
"""
DATA = f"""
INSERT INTO public.accounts VALUES('{USER}','Itaú',true,jsonb_build_object('balance_as_of',current_date-30,'evidence_sha256','synthetic'));
INSERT INTO public.lts_open_finance_staging VALUES('00000000-0000-0000-0000-000000000002','{USER}','341','fixture',
 '{{}}',jsonb_build_object('status','POSTED','account_type','CHECKING_ACCOUNT','reconciliation',
 jsonb_build_object('candidates',jsonb_build_array(jsonb_build_object('ref','current_event:fixture-event','date',current_date::text,'amount',-123.45,'delta',0)))),
 current_date,-123.45,'Synthetic merchant','transaction','BRL',null);
INSERT INTO public.fixture_events VALUES(jsonb_build_object('source','current_event','source_ref','fixture-event','account','Itaú',
 'event_date',current_date,'signed_amount',-123.45,'description','Synthetic classified expense','category','Synthetic category',
 'center_cost','Lucas','property_code','synthetic-property'));
"""

class InstallerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bin = Path(os.environ.get('LTS_INSTALLER_PG_BIN','/usr/lib/postgresql/17/bin'))
        if not (cls.bin/'initdb').is_file():
            raise RuntimeError('PostgreSQL 17 binaries required: set LTS_INSTALLER_PG_BIN; no remote fallback')
        version=subprocess.run([str(cls.bin/'postgres'),'--version'],check=True,text=True,capture_output=True).stdout
        if not re.search(r'PostgreSQL\) 17\.',version): raise RuntimeError('PostgreSQL 17 required')
        cls.tmp = tempfile.TemporaryDirectory(prefix='lts-synthetic-installer-')
        cls.root=Path(cls.tmp.name); cls.data=cls.root/'data'; cls.sock=cls.root/'socket'; cls.sock.mkdir()
        # Do not inherit host/database/password/service options.
        cls.env={k:v for k,v in os.environ.items() if not k.startswith('PG')}
        cls.env.update({'LC_ALL':'C','LANG':'C'})
        subprocess.run([str(cls.bin/'initdb'),'-D',str(cls.data),'-A','trust','--no-locale','-U','fixture_admin'],check=True,env=cls.env,capture_output=True)
        cls.started=False
        try:
            subprocess.run([str(cls.bin/'pg_ctl'),'-D',str(cls.data),'-l',str(cls.root/'server.log'),'-o',
                f"-k {cls.sock} -c listen_addresses='' -c shared_preload_libraries=''",'-w','start'],check=True,env=cls.env,capture_output=True)
            cls.started=True
            cls.sql(SCHEMA+BASELINE+DATA)
            original=(ROOT/'install.sql').read_text()
            assert original.count(FROZEN)==1
            md5=cls.sql("SELECT md5(pg_get_functiondef('public.lts_expense_rows_v230_baseline(uuid,date,date)'::regprocedure));").strip()
            assert re.fullmatch('[0-9a-f]{32}',md5)
            cls.install=original.replace(FROZEN,md5)
        except BaseException:
            cls.tearDownClass()
            raise

    @classmethod
    def tearDownClass(cls):
        if getattr(cls,'started',False):
            subprocess.run([str(cls.bin/'pg_ctl'),'-D',str(cls.data),'-m','immediate','-w','stop'],env=cls.env,capture_output=True)
        if hasattr(cls,'tmp'): cls.tmp.cleanup()

    @classmethod
    def sql(cls,source,expect_error=None):
        r=subprocess.run([str(cls.bin/'psql'),'-X','-A','-t','-q','-v','ON_ERROR_STOP=1','-h',str(cls.sock),'-U','fixture_admin','-d','postgres'],
            input=source,text=True,capture_output=True,env=cls.env)
        if expect_error:
            if r.returncode==0 or expect_error not in r.stderr:
                raise AssertionError(f'Expected {expect_error!r}: code={r.returncode}, stderr={r.stderr}')
        elif r.returncode: raise AssertionError(r.stderr)
        return r.stdout

    def test_installer_lifecycle(self):
        # A failure after first baseline replacement must roll back all DDL.
        initial=self.sql("SELECT pg_get_functiondef('public.lts_expense_rows_v230_baseline(uuid,date,date)'::regprocedure);")
        self.sql('DELETE FROM public.lts_read_cache_epoch_v242;')
        self.sql(self.install,expect_error='Missing derived-read epoch')
        self.assertEqual(self.sql("SELECT to_regprocedure('public.lts_expense_matched_bank_rows_v445(uuid,date,date)') IS NULL;").strip(),'t')
        self.assertEqual(self.sql("SELECT pg_get_functiondef('public.lts_expense_rows_v230_baseline(uuid,date,date)'::regprocedure);"),initial)
        self.sql('INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,10);')
        # PostgreSQL actually parses/validates the unmodified helper body.
        self.sql(self.install)
        self.assertEqual(self.sql('SELECT epoch FROM public.lts_read_cache_epoch_v242;').strip(),'11')
        self.assertEqual(self.sql(f"SELECT count(*) FROM public.lts_expense_matched_bank_rows_v445('{USER}',current_date-1,current_date);").strip(),'1')
        self.assertEqual(self.sql(f"SELECT public.lts_expense_rows_v230_baseline('{USER}',current_date-1,current_date)->0->>'description';").strip(),'Synthetic classified expense')
        self.assertEqual(self.sql(f"SELECT public.lts_expense_rows_v230_baseline('{USER}',current_date-1,current_date)->0->>'property_decision';").strip(),'synthetic-property')
        self.assertEqual(self.sql("SELECT has_function_privilege('anon','public.lts_expense_matched_bank_rows_v445(uuid,date,date)','EXECUTE') OR has_function_privilege('authenticated','public.lts_expense_matched_bank_rows_v445(uuid,date,date)','EXECUTE');").strip(),'f')
        self.assertEqual(self.sql("SELECT prosecdef FROM pg_proc WHERE oid='public.lts_expense_matched_bank_rows_v445(uuid,date,date)'::regprocedure;").strip(),'f')
        self.sql(f"SET ROLE anon; SELECT * FROM public.lts_expense_matched_bank_rows_v445('{USER}',current_date,current_date);",expect_error='permission denied')
        baseline=self.sql("SELECT pg_get_functiondef('public.lts_expense_rows_v230_baseline(uuid,date,date)'::regprocedure);")
        self.sql(self.install)
        self.assertEqual(self.sql('SELECT epoch FROM public.lts_read_cache_epoch_v242;').strip(),'12')
        self.assertEqual(self.sql("SELECT pg_get_functiondef('public.lts_expense_rows_v230_baseline(uuid,date,date)'::regprocedure);"),baseline)
        # Missing epoch must rollback helper replacement and any baseline changes.
        self.sql('DELETE FROM public.lts_read_cache_epoch_v242;')
        helper=self.sql("SELECT pg_get_functiondef('public.lts_expense_matched_bank_rows_v445(uuid,date,date)'::regprocedure);")
        self.sql(self.install,expect_error='Missing derived-read epoch')
        self.assertEqual(self.sql("SELECT pg_get_functiondef('public.lts_expense_matched_bank_rows_v445(uuid,date,date)'::regprocedure);"),helper)
        self.sql('INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,12);')
        # Existing marker but incomplete integration is rejected, not silently accepted.
        partial=baseline.replace("coalesce(d.property_code,case when b.source_table='lts_open_finance_staging' then s.meta->>'property_code' end) property_decision",'d.property_code property_decision')
        self.assertNotEqual(partial,baseline)
        self.sql(partial)
        self.sql(self.install,expect_error='Partial prior integration')
        self.assertEqual(self.sql('SELECT epoch FROM public.lts_read_cache_epoch_v242;').strip(),'12')
        # Drifted baseline fails frozen hash guard; helper CREATE OR REPLACE is rolled back.
        self.sql("CREATE OR REPLACE FUNCTION public.lts_expense_rows_v230_baseline(p_user_id uuid,p_from date,p_to date) RETURNS jsonb LANGUAGE sql AS $$SELECT '[]'::jsonb$$;")
        self.sql("CREATE OR REPLACE FUNCTION public.lts_expense_matched_bank_rows_v445(p_user_id uuid,p_from date,p_to date) RETURNS TABLE(id uuid,event_date date,signed_amount numeric,description text,bank text,category text,operational_event jsonb) LANGUAGE sql AS $$SELECT NULL::uuid,NULL::date,NULL::numeric,NULL::text,NULL::text,NULL::text,NULL::jsonb WHERE false$$;")
        before=self.sql("SELECT pg_get_functiondef('public.lts_expense_matched_bank_rows_v445(uuid,date,date)'::regprocedure);")
        self.sql(self.install,expect_error='Expense baseline changed')
        self.assertEqual(self.sql("SELECT pg_get_functiondef('public.lts_expense_matched_bank_rows_v445(uuid,date,date)'::regprocedure);"),before)
        self.assertEqual(self.sql('SELECT epoch FROM public.lts_read_cache_epoch_v242;').strip(),'12')
        self.assertEqual(self.sql('SELECT count(*) FROM public.lts_open_finance_staging;').strip(),'1')

if __name__=='__main__': unittest.main(verbosity=2)
