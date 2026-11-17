"""Native PostgreSQL proof guards, closed-profile additions and reversible DDL."""
import json
import subprocess
import unittest
from pathlib import Path
import build

ROOT=Path(__file__).resolve().parent
DB='lts_utility_receipts_v460'
U='00000000-0000-4000-8000-000000000001'
S='00000000-0000-4000-8000-000000000002'
P='00000000-0000-4000-8000-000000000003'

def sql(q,error=None):
    # Each isolated psql connection must defer validation of the preserved old
    # branches whose unrelated payroll/card dependencies are outside this fixture.
    p=subprocess.run(['psql','-XAtq','-v','ON_ERROR_STOP=1','-d',DB],input='SET check_function_bodies=off;'+q,text=True,capture_output=True)
    if error:
        assert p.returncode and error in p.stderr,(error,p.stderr)
        return p.stderr
    if p.returncode:raise AssertionError(p.stderr)
    return p.stdout.strip()

def count(prefix='',owner=U,asof='2026-11-17'):
    return int(sql(prefix+f"SELECT count(*) FROM lts_receipt_private_v460.utility_receipts('{owner}','{asof}');"))

def attrs(sig):return sql(f"SELECT (to_jsonb(p)-'prosrc')::text FROM pg_proc p WHERE oid='{sig}'::regprocedure;")

class UtilityReceipts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        build.build();subprocess.run(['createdb',DB],check=True,capture_output=True)
        sql((ROOT/'setup.sql').read_text());sql((ROOT/'source-original.sql').read_text());sql((ROOT/'profile-original.sql').read_text());sql((ROOT/'seed.sql').read_text())
        cls.source_attrs=attrs(build.SOURCE);cls.profile_attrs=attrs(build.PROFILE)
        cls.profile=json.loads(sql('SELECT lts_product_refresh_private_v415.review_profile_v450();'))
        sql((ROOT/'install.sql').read_text())

    def setUp(self):sql((ROOT/'seed.sql').read_text())

    def test_01_variable_amount_receipt_and_exact_legacy_identity(self):
        self.assertEqual(count(),1)
        r=json.loads(sql(f"SELECT to_jsonb(x) FROM lts_receipt_private_v460.utility_receipts('{U}','2026-11-17')x;"))
        self.assertEqual(r['actual_amount'],-123.45);self.assertEqual(r['projection_ref'],'evento_base:1')
        self.assertEqual(r['projection_date'],'2026-11-09');self.assertEqual(r['actual_date'],'2026-11-11')

    def test_02_posted_checking_currency_owner_and_source_hash(self):
        changes=["normalized_payload=jsonb_set(normalized_payload,'{status}','\"PENDING\"')","normalized_payload=jsonb_set(normalized_payload,'{account_type}','\"CREDIT\"')","raw_hash=repeat('d',64)","currency='USD'","institution_code='237'","provider_deleted_at=now()","resource_type='card_transaction'","signed_amount=123.45","occurred_at=now()+interval '1 day'","posting_date='2026-11-12'"]
        for change in changes:
            with self.subTest(change=change):self.assertEqual(count(f"BEGIN;UPDATE lts_open_finance_staging SET {change} WHERE id='{S}';"),0)
        self.assertEqual(count(owner='00000000-0000-4000-8000-000000000099'),0)

    def test_03_archived_original_forecast_and_occurrence_scope(self):
        changes=["dados=jsonb_set(dados,'{escopo}','\"serie\"')","dados=jsonb_set(dados,'{status}','\"revertida\"')","dados=jsonb_set(dados,'{depois,cancelada}','false')","dados=jsonb_set(dados,'{reconciliation,basis}','\"unproved\"')","dados=jsonb_set(dados,'{reconciliation,actual_signed_amount}','-140')","dados=jsonb_set(dados,'{reconciliation,original_forecast,valor}','999')"]
        for change in changes:
            with self.subTest(change=change):self.assertEqual(count('BEGIN;UPDATE projecao_op SET '+change+';'),0)
        self.assertEqual(count("BEGIN;UPDATE evento_base SET dados=jsonb_set(dados,'{valor}','999');"),0)

    def test_04_prior_authenticated_identity_payee_and_property(self):
        changes=[f"DELETE FROM lts_v178_review_decision WHERE source_ref='{P}'",f"UPDATE lts_v178_review_decision SET decision_basis='unconfirmed' WHERE source_ref='{P}'",f"UPDATE lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{{paymentData,receiver,documentNumber,value}}','\"different-payee\"') WHERE id='{P}'",f"UPDATE lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{{provider_account_id}}','\"different-account\"') WHERE id='{P}'",f"UPDATE lts_v178_review_decision SET property_code='other-property' WHERE source_ref='{P}'"]
        for change in changes:
            with self.subTest(change=change):self.assertEqual(count('BEGIN;'+change+';'),0)

    def test_05_ambiguity_balance_coverage_and_month_scope(self):
        self.assertEqual(count('BEGIN;INSERT INTO projecao_op(usuario_id,dados) SELECT usuario_id,dados FROM projecao_op;'),0)
        self.assertEqual(count(f"BEGIN;INSERT INTO lts_open_finance_staging SELECT (jsonb_populate_record(NULL::lts_open_finance_staging,to_jsonb(s)||jsonb_build_object('id','00000000-0000-4000-8000-000000000005'))).* FROM lts_open_finance_staging s WHERE s.id='{S}';"),0)
        self.assertEqual(count("BEGIN;DELETE FROM lts_open_finance_staging WHERE resource_type='balance';"),0)
        self.assertEqual(count(asof='2026-12-17'),0);self.assertEqual(count(asof='2026-11-10'),0)

    def test_06_read_only_exact_metadata_and_closed_profile(self):
        self.assertEqual(count('BEGIN READ ONLY;'),1)
        self.assertEqual(attrs(build.SOURCE),self.source_attrs);self.assertEqual(attrs(build.PROFILE),self.profile_attrs)
        profile=json.loads(sql('SELECT lts_product_refresh_private_v415.review_profile_v450();'))
        self.assertEqual(profile['producers'][:-2],self.profile['producers'])
        self.assertEqual({k:v for k,v in profile.items() if k!='producers'},{k:v for k,v in self.profile.items() if k!='producers'})
        self.assertEqual([x['signature'] for x in profile['producers'][-2:]],[build.SOURCE,build.HELPER])

    def test_07_private_permissions_and_no_new_public_endpoint(self):
        for role in ['anon','authenticated']:
            self.assertEqual(sql(f"SELECT has_schema_privilege('{role}','lts_receipt_private_v460','USAGE') OR has_function_privilege('{role}','{build.HELPER}','EXECUTE');"),'f')
        self.assertEqual(sql(f"SELECT prosecdef FROM pg_proc WHERE oid='{build.HELPER}'::regprocedure;"),'f')

    def test_08_install_rollback_and_reapplication(self):
        sql((ROOT/'install.sql').read_text());sql((ROOT/'rollback.sql').read_text(),error='V460_UTILITY_RECEIPTS_IN_USE')
        sql('DELETE FROM projecao_op;');sql((ROOT/'rollback.sql').read_text())
        self.assertEqual(sql(f"SELECT md5(pg_get_functiondef('{build.SOURCE}'::regprocedure));"),build.OLD_SOURCE)
        self.assertEqual(sql(f"SELECT md5(pg_get_functiondef('{build.PROFILE}'::regprocedure));"),build.OLD_PROFILE)
        sql((ROOT/'install.sql').read_text())

    def test_09_worker_and_unknown_predecessor_refused(self):
        sql("UPDATE lts_product_refresh_private_v415.queue SET state='running';")
        sql((ROOT/'install.sql').read_text(),error='V460_WORKER_ACTIVE');sql("UPDATE lts_product_refresh_private_v415.queue SET state='ready';")
        sql(build.definition('source-original.sql').replace('WITH payroll AS (','WITH /* drift */ payroll AS ('))
        sql((ROOT/'install.sql').read_text(),error='V460_PREDECESSOR_CHANGED')
        sql((ROOT/'source-original.sql').read_text());sql((ROOT/'install.sql').read_text())

if __name__=='__main__':unittest.main(verbosity=2)
