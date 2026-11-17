"""Actual proof reader and guarded realized-source patch on native PostgreSQL."""
import json
import subprocess
import unittest
from pathlib import Path
import build

ROOT=Path(__file__).resolve().parent
DB='lts_realized_series_v459'
U='00000000-0000-4000-8000-000000000001'
F='00000000-0000-4000-8000-000000000102'
S='00000000-0000-4000-8000-000000000202'


def sql(query,error=None):
    p=subprocess.run(['psql','-XAtq','-v','ON_ERROR_STOP=1','-d',DB],input=query,text=True,capture_output=True)
    if error:
        assert p.returncode and error in p.stderr,(error,p.stderr)
        return p.stderr
    if p.returncode:raise AssertionError(p.stderr)
    return p.stdout.strip()


def rows(owner=U,prefix=''):
    return json.loads(sql(prefix+f"SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY financial_event_id),'[]') FROM public.lts_realized_bank_sources_v238('{owner}')r;"))


def attrs(sig):
    return sql(f"SELECT (to_jsonb(p)-'prosrc')::text FROM pg_proc p WHERE oid='{sig}'::regprocedure;")


class RealizedSeries(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        build.build();subprocess.run(['createdb',DB],check=True,capture_output=True)
        sql((ROOT/'setup.sql').read_text());sql((ROOT/'proof.sql').read_text())
        sql((ROOT/'source-original.sql').read_text());sql((ROOT/'profile-original.sql').read_text());sql((ROOT/'seed.sql').read_text())
        cls.old=rows();assert len(cls.old)==1 and cls.old[0]['legacy_id']=='fixture_numeric'
        cls.profile=json.loads(sql('SELECT lts_product_refresh_private_v415.review_profile_v450();'))
        cls.source_attrs=attrs(build.SOURCE);cls.profile_attrs=attrs(build.PROFILE)
        sql((ROOT/'install.sql').read_text());cls.expected=rows();assert len(cls.expected)==2

    def setUp(self):sql((ROOT/'seed.sql').read_text())

    def test_01_original_numeric_rows_and_new_stable_series(self):
        actual=rows();self.assertEqual(actual,self.expected);self.assertEqual(actual[1:],self.old)
        self.assertEqual(actual[0]['legacy_id'],'fixture_paid');self.assertEqual(actual[0]['signed_amount'],-123.4567)
        self.assertIsNone(actual[0]['beneficiary'])
        self.assertEqual(sql(f"SELECT metadata->>'contract_ref' FROM financial_events WHERE id='{F}';"),'volvo_financing_2026')

    def test_02_every_outer_source_guard_is_preserved(self):
        changes=[f"UPDATE financial_events SET is_projection=true WHERE id='{F}'",f"UPDATE financial_events SET is_suppressed=true WHERE id='{F}'",f"UPDATE financial_events SET event_date=event_date+1 WHERE id='{F}'",f"UPDATE financial_events SET amount=amount-1 WHERE id='{F}'",f"UPDATE lts_open_finance_staging SET signed_amount=signed_amount-1 WHERE id='{S}'",f"UPDATE lts_open_finance_staging SET posting_date=posting_date+1 WHERE id='{S}'",f"UPDATE lts_open_finance_staging SET provider_deleted_at=now() WHERE id='{S}'",f"UPDATE lts_open_finance_staging SET resource_type='card_transaction' WHERE id='{S}'",f"UPDATE lts_open_finance_staging SET currency='USD' WHERE id='{S}'",f"UPDATE lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{{status}}','\"PENDING\"') WHERE id='{S}'",f"UPDATE lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{{account_type}}','\"CREDIT\"') WHERE id='{S}'",f"UPDATE lts_realized_bank_event_v238 SET bank='Itaú' WHERE financial_event_id='{F}'"]
        for change in changes:
            with self.subTest(change=change):self.assertEqual(rows(prefix='BEGIN;'+change+';'),self.old)

    def test_03_receipt_hash_contract_installment_and_event_metadata_are_required(self):
        changes=[f"UPDATE lts_realized_bank_event_v238 SET evidence=jsonb_set(evidence,'{{bank_raw_hash}}','\"bad\"') WHERE financial_event_id='{F}'",f"UPDATE lts_realized_bank_event_v238 SET evidence=jsonb_set(evidence,'{{contract_ref}}','\"9999999\"') WHERE financial_event_id='{F}'",f"UPDATE lts_realized_bank_event_v238 SET evidence=jsonb_set(evidence,'{{installment}}','\"003/060\"') WHERE financial_event_id='{F}'",f"UPDATE financial_events SET metadata=metadata-'bank_staging_id' WHERE id='{F}'",f"UPDATE financial_events SET metadata=jsonb_set(metadata,'{{bank_reconciliation_evidence,bank_raw_hash}}','\"bad\"') WHERE id='{F}'"]
        for change in changes:
            with self.subTest(change=change):self.assertEqual(rows(prefix='BEGIN;'+change+';'),self.old)

    def test_04_actual_existing_proof_reader_and_unambiguous_anchor_required(self):
        for change in ["DELETE FROM lts_v229_documentary_match", "UPDATE lts_v229_documentary_match SET evidence=jsonb_set(evidence,'{raw_hash}','\"bad\"')",f"UPDATE financial_events SET metadata=jsonb_set(metadata,'{{installment_number}}','3') WHERE id='{F}'", "UPDATE lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{as_of}',to_jsonb((now()-interval '100 days')::text)) WHERE resource_type='balance'"]:
            with self.subTest(change=change):self.assertEqual(rows(prefix='BEGIN;'+change+';'),self.old)
        self.assertEqual(sql(f"SELECT count(*) FROM public.lts_documentary_contract_payments_v310('{U}',current_date) WHERE financial_event_id='{F}';"),'1')

    def test_05_owner_isolation_and_read_only_results(self):
        self.assertEqual(rows('00000000-0000-4000-8000-000000000099'),[])
        self.assertEqual(rows(prefix='BEGIN READ ONLY;'),self.expected)
        self.assertEqual(rows(prefix=f"BEGIN;UPDATE lts_open_finance_staging SET user_id='00000000-0000-4000-8000-000000000099' WHERE id='{S}';"),self.old)
        self.assertEqual(rows(prefix=f"BEGIN;INSERT INTO public.lts_open_finance_staging SELECT (jsonb_populate_record(NULL::public.lts_open_finance_staging,to_jsonb(s)||jsonb_build_object('id','00000000-0000-4000-8000-000000000204'))).* FROM public.lts_open_finance_staging s WHERE s.id='{S}';"),self.old)

    def test_06_exact_function_metadata_and_one_profile_pin_only(self):
        self.assertEqual(attrs(build.SOURCE),self.source_attrs);self.assertEqual(attrs(build.PROFILE),self.profile_attrs)
        expected=json.loads(json.dumps(self.profile).replace(build.OLD_SOURCE,build.md5(build.definition('source-after.sql'))))
        self.assertEqual(json.loads(sql('SELECT lts_product_refresh_private_v415.review_profile_v450();')),expected)

    def test_07_install_rollback_and_reapplication(self):
        sql((ROOT/'install.sql').read_text());sql((ROOT/'rollback.sql').read_text())
        self.assertEqual(rows(),self.old);self.assertEqual(json.loads(sql('SELECT lts_product_refresh_private_v415.review_profile_v450();')),self.profile)
        sql((ROOT/'install.sql').read_text());self.assertEqual(rows(),self.expected)

    def test_08_active_worker_and_dependency_drift_refused(self):
        sql("UPDATE lts_product_refresh_private_v415.queue SET state='running';")
        sql((ROOT/'install.sql').read_text(),error='V459_WORKER_ACTIVE')
        sql("UPDATE lts_product_refresh_private_v415.queue SET state='ready';")
        sql(build.definition('proof.sql').replace('WITH eligible AS MATERIALIZED','WITH /* drift */ eligible AS MATERIALIZED'))
        sql((ROOT/'install.sql').read_text(),error='V459_PROOF_READER_CHANGED');sql((ROOT/'proof.sql').read_text())

    def test_09_target_drift_cannot_overwrite_an_unrecognized_reader(self):
        sql(build.definition('source-original.sql').replace('SELECT f.id,s.id','SELECT /* drift */ f.id,s.id'))
        sql((ROOT/'install.sql').read_text(),error='V459_PREDECESSOR_CHANGED')
        sql((ROOT/'source-original.sql').read_text());sql((ROOT/'install.sql').read_text());self.assertEqual(rows(),self.expected)


if __name__=='__main__':unittest.main(verbosity=2)
