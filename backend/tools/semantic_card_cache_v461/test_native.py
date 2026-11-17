"""Native PostgreSQL tests of reuse, invalidation and unchanged DDL contracts."""
import json
import subprocess
import unittest
from pathlib import Path
import build

ROOT=Path(__file__).resolve().parent
DB='lts_semantic_card_cache_v461'
U='00000000-0000-4000-8000-000000000001'
S='00000000-0000-4000-8000-000000000002'
OTHER='00000000-0000-4000-8000-000000000099'

def sql(q,error=None):
    p=subprocess.run(['psql','-XAtq','-v','ON_ERROR_STOP=1','-d',DB],input=q,text=True,capture_output=True)
    if error:
        assert p.returncode and error in p.stderr,(error,p.stderr)
        return p.stderr
    if p.returncode: raise AssertionError(p.stderr)
    return p.stdout.strip()

def attrs(sig): return sql(f"SELECT (to_jsonb(p)-'prosrc')::text FROM pg_proc p WHERE oid='{sig}'::regprocedure;")
def key(prefix='',owner=U):return sql(prefix+f"SELECT lts_product_refresh_private_v415.card_source_key('{owner}');")
def state(prefix=''):return json.loads(sql(prefix+f"SELECT public.lts_c6_completeness_state_v269('{U}');"))

class SemanticCardCache(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        build.build();subprocess.run(['createdb',DB],check=True,capture_output=True)
        sql((ROOT/'setup.sql').read_text())
        for name in ('source','consumer','profile'): sql((ROOT/(name+'-original.sql')).read_text())
        # The old functions' existing privileges are preserved byte for byte.
        sql(f"REVOKE ALL ON FUNCTION {build.SOURCE},{build.CONSUMER},{build.PROFILE} FROM PUBLIC;GRANT EXECUTE ON FUNCTION {build.CONSUMER} TO authenticated;")
        cls.attributes={sig:attrs(sig) for sig in build.OLD}
        cls.profile=json.loads(sql('SELECT lts_product_refresh_private_v415.review_profile_v450();'))
        sql((ROOT/'seed.sql').read_text());sql((ROOT/'install.sql').read_text())

    def setUp(self):sql((ROOT/'seed.sql').read_text())

    def test_01_all_bookkeeping_changes_reuse_same_key_and_cached_state(self):
        before=key();first=state();stamp=sql("SELECT refreshed_at FROM lts_v229_read_cache WHERE kind='card_completeness_v269';")
        sql("UPDATE lts_open_finance_staging SET sync_run_id='00000000-0000-4000-8000-000000000004',last_seen_at=last_seen_at+interval '1 hour',updated_at=updated_at+interval '1 hour';")
        self.assertEqual(key(),before);self.assertEqual(state(),first)
        self.assertEqual(sql("SELECT refreshed_at FROM lts_v229_read_cache WHERE kind='card_completeness_v269';"),stamp)

    def test_02_semantic_changes_invalidate_without_relying_on_epoch(self):
        before=key()
        changes=["signed_amount=-999","posting_date='2026-11-18'","currency='USD'","provider_deleted_at=now()","raw_hash='changed'","raw_payload='{\"payment\":{\"status\":\"REVERSED\"}}'","normalized_payload='{\"status\":\"PENDING\",\"payments\":[]}'","resource_type='bank_transaction'","institution_code='other'","future_semantic_field='{\"future\":2}'"]
        for change in changes:
            with self.subTest(change=change):self.assertNotEqual(key('BEGIN;UPDATE lts_open_finance_staging SET '+change+';'),before)
        self.assertEqual(sql('SELECT epoch FROM lts_read_cache_epoch_v242;'),'1')

    def test_03_add_remove_and_reassign_invalidate_and_isolate_owners(self):
        before=key();other=key(owner=OTHER)
        self.assertNotEqual(key('BEGIN;DELETE FROM lts_open_finance_staging;'),before)
        self.assertNotEqual(key(f"BEGIN;UPDATE lts_open_finance_staging SET user_id='{OTHER}';"),before)
        sql(f"INSERT INTO lts_open_finance_staging(id,user_id,normalized_payload) VALUES('{OTHER}','{OTHER}','{{\"amount\":1}}');")
        self.assertEqual(key(),before);self.assertNotEqual(key(owner=OTHER),other)

    def test_04_invoices_documents_settlements_and_epoch_still_invalidate(self):
        before=key()
        for table in ['card_invoices','lts_card_document_supplement_v234','lts_card_documentary_payment_link_v272','lts_card_settlement_expense_contract_v273']:
            with self.subTest(table=table):self.assertNotEqual(key(f"BEGIN;INSERT INTO public.{table} VALUES('{S}','{U}','{{\"amount\":1}}');"),before)
        self.assertNotEqual(key('BEGIN;UPDATE lts_read_cache_epoch_v242 SET epoch=2;'),before)

    def test_05_producer_consumer_agree_and_preserve_incomplete_cards(self):
        r=state("SET lts_test.complete='false';")
        self.assertFalse(r['complete']);self.assertEqual(r['incomplete_families'],['synthetic'])
        self.assertEqual(r['source_revision'],key());self.assertEqual(r['source_epoch'],1)
        self.assertEqual(sql('SELECT bool_and(source_fingerprint=payload->>\'source_revision\') FROM lts_v229_read_cache WHERE kind=\'card_completeness_v269\';'),'t')
        self.assertEqual(sql("SELECT count(*) FROM lts_v229_read_cache WHERE kind='card_cycles_snapshot_v307';"),'1')

    def test_06_read_only_and_lock_timeout_unchanged(self):
        r=state('BEGIN READ ONLY;');self.assertEqual(r['source_revision'],key())
        self.assertEqual(sql('SELECT count(*) FROM lts_v229_read_cache;'),'0')
        for timeout in ['0','50ms','1s']:
            self.assertEqual(sql(f"SET lock_timeout='{timeout}';SELECT public.lts_c6_completeness_state_v269('{U}') IS NOT NULL;SHOW lock_timeout;").splitlines()[-1],timeout)
            sql('TRUNCATE lts_v229_read_cache;')

    def test_07_concurrent_financial_epoch_change_fails_closed(self):
        sql(f"SET lts_test.epoch_race='on';SELECT public.lts_c6_completeness_state_v269('{U}');",error='source changed during read')
        self.assertEqual(sql('SELECT count(*) FROM lts_v229_read_cache;'),'0')

    def test_08_exact_metadata_permissions_and_only_two_profile_pins(self):
        for sig in build.OLD:self.assertEqual(attrs(sig),self.attributes[sig])
        profile=json.loads(sql('SELECT lts_product_refresh_private_v415.review_profile_v450();'))
        for p in profile['producers']:
            if p['signature'] in (build.SOURCE,build.CONSUMER):p['md5']=build.OLD[p['signature']]
        self.assertEqual(profile,self.profile)

    def test_09_idempotent_install_rollback_and_reapplication(self):
        sql((ROOT/'install.sql').read_text());sql((ROOT/'rollback.sql').read_text())
        for sig,expected in build.OLD.items():self.assertEqual(sql(f"SELECT md5(pg_get_functiondef('{sig}'::regprocedure));"),expected)
        sql((ROOT/'rollback.sql').read_text());sql((ROOT/'install.sql').read_text())

    def test_10_worker_active_and_unknown_predecessor_refused_atomically(self):
        sql("UPDATE lts_product_refresh_private_v415.queue SET state='running';")
        sql((ROOT/'install.sql').read_text(),error='V461_WORKER_ACTIVE');sql("UPDATE lts_product_refresh_private_v415.queue SET state='ready';")
        sql(build.definition('consumer-original.sql').replace('DECLARE previous_cache_lock_timeout','DECLARE /* drift */ previous_cache_lock_timeout'))
        sql((ROOT/'install.sql').read_text(),error='V461_PREDECESSOR_CHANGED')
        sql((ROOT/'consumer-original.sql').read_text());sql((ROOT/'install.sql').read_text())

if __name__=='__main__':unittest.main(verbosity=2)
