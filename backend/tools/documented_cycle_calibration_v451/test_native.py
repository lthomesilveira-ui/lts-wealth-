"""Actual C6 reader in disposable PG17; synthetic statements and source records."""
import importlib.util
import json
import sys
import unittest
from pathlib import Path

import build

ROOT=Path(__file__).resolve().parent
SNAP=ROOT.parent/'review_snapshot_v450'
spec=importlib.util.spec_from_file_location('snapshot_build',SNAP/'build.py')
snap=importlib.util.module_from_spec(spec);spec.loader.exec_module(snap)
spec=importlib.util.spec_from_file_location('snapshot_test',SNAP/'test_native.py')
base=importlib.util.module_from_spec(spec)
saved=sys.modules['build'];sys.modules['build']=snap
try:spec.loader.exec_module(base)
finally:sys.modules['build']=saved
U=base.OWNER
def uid(n):return f'20000000-0000-4000-8000-{n:012d}'

class DocumentedCycle(base.Native):
    test_exact_rows_guards_security_and_lifecycle=None

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        try:
            cls.sql('''CREATE TABLE public.lts_open_finance_staging(
                id uuid,user_id uuid,institution_code text,resource_type text,
                provider_deleted_at timestamptz,provider_account_ref text,
                normalized_payload jsonb,raw_payload jsonb,currency text,
                signed_amount numeric,posting_date date,description_raw text);
                CREATE TABLE public.card_invoices(id uuid,user_id uuid,card_name text,
                reference_month date,due_date date,status text,metadata jsonb,amount numeric);
                CREATE TABLE public.source_documents(id uuid,user_id uuid,document_type text,
                processing_status text,sha256 text,metadata jsonb);
                CREATE FUNCTION public.lts_card_family_v226(text,text) RETURNS text
                LANGUAGE sql IMMUTABLE AS $$SELECT CASE WHEN lower($1||$2) LIKE '%c6%' THEN 'c6' ELSE 'other' END$$;''')
            for sig,name in [(build.IDENTITY,'identity-original.sql'),(build.PROFILE,'profile-original.sql')]:
                cls.sql(build.original(name))
                cls.sql(f'ALTER FUNCTION {sig} OWNER TO postgres;REVOKE ALL ON FUNCTION {sig} FROM PUBLIC,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION {sig} TO service_role;')
            cls.fixture()
        except BaseException:cls.tearDownClass();raise

    @classmethod
    def fixture(cls):
        cls.sql(f'''INSERT INTO public.lts_open_finance_staging
            (id,user_id,institution_code,resource_type,provider_account_ref,normalized_payload,raw_payload,currency,signed_amount,posting_date,description_raw)
            SELECT '{uid(1)}'::uuid,'{U}'::uuid,'336','credit_card','fixture-card','{{}}'::jsonb,'{{}}'::jsonb,'BRL',NULL,NULL,'fixture account'
            UNION ALL SELECT '{uid(2)}','{U}','336','invoice','fixture-card',
              jsonb_build_object('provider_id','fixture-bill','closing_date',(date_trunc('month',current_date)-interval '1 month'+interval '28 days')::date,'warnings','[]'::jsonb),
              '{{}}','BRL',100,(date_trunc('month',current_date)+interval '4 days')::date,'fixture invoice'
            UNION ALL SELECT '{uid(3)}','{U}','336','card_transaction','fixture-card',jsonb_build_object('status','POSTED'),
              jsonb_build_object('creditCardMetadata',jsonb_build_object('billId','fixture-bill','billForecastDate',to_char(current_date-interval '1 month','YYYY-MM'))),
              'BRL',-60,(date_trunc('month',current_date)-interval '10 days')::date,'fixture known purchase'
            UNION ALL SELECT '{uid(4)}','{U}','336','card_transaction','fixture-card',jsonb_build_object('status','POSTED'),
              '{{"creditCardMetadata":{{"billId":"fixture-bill"}}}}','BRL',-40,(date_trunc('month',current_date)-interval '9 days')::date,'fixture missing forecast'
            UNION ALL SELECT '{uid(5)}','{U}','336','card_transaction','fixture-card',jsonb_build_object('status','PENDING'),
              jsonb_build_object('creditCardMetadata',jsonb_build_object('billForecastDate',to_char(current_date,'YYYY-MM'),'billPostDate',(date_trunc('month',current_date)+interval '8 days')::date)),
              'BRL',-19.9,(date_trunc('month',current_date)+interval '4 days')::date,'fixture next-cycle purchase';
            INSERT INTO public.card_invoices VALUES('{uid(6)}','{U}','C6 fixture',date_trunc('month',current_date)::date,(date_trunc('month',current_date)+interval '4 days')::date,'closed',
              jsonb_build_object('bank_statement_document_id','{uid(8)}','bank_statement_closed','true','bank_statement_full_composition','true','bank_statement_sha256','fixture-sha'),100),
              ('{uid(7)}','{U}','C6 fixture',(date_trunc('month',current_date)+interval '1 month')::date,(date_trunc('month',current_date)+interval '1 month 6 days')::date,'projected','{{}}',19.9);
            INSERT INTO public.source_documents VALUES('{uid(8)}','{U}','credit_card_statement','processed','fixture-sha',
              jsonb_build_object('closing_date',(date_trunc('month',current_date)-interval '1 month'+interval '27 days')::date,
              'existing_source_items',jsonb_build_array(jsonb_build_object('source_id','{uid(3)}'),jsonb_build_object('source_id','{uid(40)}')),
              'all_source_lines_matched','true','statement_amount',100,'due_date',(date_trunc('month',current_date)+interval '4 days')::date));''')

    def rows(self):
        return json.loads(self.sql(f"SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY source_id),'[]') FROM public.lts_c6_cycle_identity_v269('{U}')r;"))

    def test_corroboration_guards_and_lifecycle(self):
        before=self.rows()
        self.assertEqual(len(before),1)
        self.assertEqual(before[0]['cycle_basis'],'unresolved')
        meta=f"SELECT jsonb_agg(jsonb_build_array(oid::regprocedure::text,proacl,proconfig,prosecdef,proowner) ORDER BY oid) FROM pg_proc WHERE oid IN('{build.IDENTITY}'::regprocedure,'{build.PROFILE}'::regprocedure);"
        prior_meta=self.sql(meta)
        source_hash=self.sql("SELECT md5(jsonb_build_array((SELECT jsonb_agg(to_jsonb(s) ORDER BY id) FROM public.lts_open_finance_staging s),(SELECT jsonb_agg(to_jsonb(s) ORDER BY id) FROM public.card_invoices s),(SELECT jsonb_agg(to_jsonb(s) ORDER BY id) FROM public.source_documents s))::text);")
        for _ in range(2):self.sql('SET ROLE postgres;'+(ROOT/'install.sql').read_text())
        self.assertEqual(self.sql(meta),prior_meta)
        expected=self.rows()
        self.assertEqual(expected[0]['source_id'],uid(5))
        self.assertEqual(expected[0]['cycle_basis'],'verified_account_forecast_offset_and_due_calendar')
        self.assertEqual(expected[0]['due_date'],self.sql("SELECT (date_trunc('month',current_date)+interval '1 month 6 days')::date;"))
        self.assertEqual(source_hash,self.sql("SELECT md5(jsonb_build_array((SELECT jsonb_agg(to_jsonb(s) ORDER BY id) FROM public.lts_open_finance_staging s),(SELECT jsonb_agg(to_jsonb(s) ORDER BY id) FROM public.card_invoices s),(SELECT jsonb_agg(to_jsonb(s) ORDER BY id) FROM public.source_documents s))::text);"))
        variants={
          'unprocessed statement':"UPDATE public.source_documents SET processing_status='pending';",
          'different hash':"UPDATE public.source_documents SET sha256='changed';",
          'partial document':"UPDATE public.card_invoices SET metadata=jsonb_set(metadata,'{bank_statement_full_composition}','false');",
          'different owner':f"UPDATE public.source_documents SET user_id='{base.OTHER}';",
          'different amount':"UPDATE public.card_invoices SET amount=90 WHERE status='closed';UPDATE public.source_documents SET metadata=jsonb_set(metadata,'{statement_amount}','90');",
          'conflicting known forecast':f"UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{{creditCardMetadata,billForecastDate}}',to_jsonb(to_char(current_date,'YYYY-MM'))) WHERE id='{uid(4)}';",
          'no known forecast':f"UPDATE public.lts_open_finance_staging SET raw_payload='{{\"creditCardMetadata\":{{\"billId\":\"fixture-bill\"}}}}' WHERE id='{uid(3)}';",
          'closing mismatch':"UPDATE public.source_documents SET metadata=jsonb_set(metadata,'{closing_date}',to_jsonb((date_trunc('month',current_date)-interval '1 month'+interval '25 days')::date));",
          'due mismatch':f"UPDATE public.lts_open_finance_staging SET posting_date=posting_date+1 WHERE id='{uid(2)}';",
          'second billing account':f"INSERT INTO public.lts_open_finance_staging(id,user_id,institution_code,resource_type,provider_account_ref) VALUES('{uid(9)}','{U}','336','credit_card','different-account');",
          'posting after due date':f"UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{{creditCardMetadata,billPostDate}}',to_jsonb((date_trunc('month',current_date)+interval '1 month 7 days')::date)) WHERE id='{uid(5)}';",
        }
        for label,change in variants.items():
            value=self.sql('BEGIN;'+change+f"SELECT cycle_basis FROM public.lts_c6_cycle_identity_v269('{U}') WHERE source_id='{uid(5)}';ROLLBACK;")
            self.assertEqual(value,'unresolved',label)
        self.assertEqual(self.sql(f"SELECT count(*) FROM public.lts_c6_cycle_identity_v269('{base.OTHER}');"),'0')
        for role in ['anon','authenticated']:
            self.sql(f"SET ROLE {role};SELECT * FROM public.lts_c6_cycle_identity_v269('{U}');",error='permission denied')
        self.sql((ROOT/'rollback.sql').read_text());self.assertEqual(self.rows(),before);self.assertEqual(self.sql(meta),prior_meta)
        # Complete issuer metadata follows the exact previous path.
        self.sql(f"UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{{creditCardMetadata,billForecastDate}}',to_jsonb(to_char(current_date-interval '1 month','YYYY-MM'))) WHERE id='{uid(4)}';")
        complete_before=self.rows();self.sql((ROOT/'install.sql').read_text());self.assertEqual(self.rows(),complete_before)
        self.sql(build.identity().replace('STABLE','STABLE\n-- concurrent producer change',1))
        self.sql((ROOT/'install.sql').read_text(),error='Documented C6 cycle changed concurrently')

if __name__=='__main__':unittest.main(verbosity=2)
