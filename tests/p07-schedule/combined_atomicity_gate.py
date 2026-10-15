"""Reviewed combined DDL/economic transaction gate. Default is offline only.

Uses the existing, unchanged SQL files and fixtures. PostgreSQL execution is
opt-in, local-only, and creates/drops only this process's generated QA database.
The epoch observer is synthetic instrumentation outside guarded finance tables.
The reviewed joint guard still requires its disposable PostgreSQL CI gate.
"""
from pathlib import Path
from datetime import timedelta
import argparse
import hashlib
import json
import os
import re
import unittest
import uuid

from connection_config import local_connection_options
from combined_state_guard import guard_sql, ORIGINAL_READER_MD5, CANDIDATE_READER_MD5

P = Path(__file__).resolve().parent
F = json.loads((P/'fixtures.json').read_text())
PLANNED_IDS = [row['id'] for row in F['new']]
PUBLIC_SQL_HASHES = {
    'apply.review.sql': '04bd8fd7425075208a26e4c308f04d31f8462e5b6a238eb5d6d042df47eb4b8a',
    'recovery.review.sql': '5258a1bbfab6636248e1e5c213b2d2e199b57fc475d334fcb1270ad5cd204217',
    'documentary_reader_original.sql': '9f368715839915bc52c21a919350a0d1c1a014a2d4e4541a0d641023b0411dd4',
    'documentary_reader_candidate.sql': '17bbe70c3ccee34963f046c8ff7de55004e8f9631f5076f35ce56a706204d57c',
}

def read_sql(name):
    return (P/name).read_text()

def guard(mode):
    return guard_sql(mode, PLANNED_IDS, F['rule']['id'])

def document_schema_without_duplicate_auth():
    text = read_sql('documentary_position_gate.sql')
    for statement in ['CREATE SCHEMA auth;\n', 'CREATE TABLE auth.users (id uuid PRIMARY KEY);\n']:
        if text.count(statement) != 1:
            raise AssertionError('Reviewed documentary schema bootstrap changed')
        text = text.replace(statement, '', 1)
    return text

def reader_sql(mode):
    return read_sql('documentary_reader_candidate.sql' if mode == 'apply' else 'documentary_reader_original.sql')

def reader_hash(mode):
    return CANDIDATE_READER_MD5 if mode == 'apply' else ORIGINAL_READER_MD5

class OfflineCombinedContract(unittest.TestCase):
    def test_existing_sql_is_byte_identical(self):
        for name, expected in PUBLIC_SQL_HASHES.items():
            self.assertEqual(hashlib.sha256((P/name).read_bytes()).hexdigest(), expected, name)
    def test_generic_reader_md5_matches_canonical_definition(self):
        # pg_get_functiondef omits the final CREATE statement semicolon.
        for mode in ['apply', 'recovery']:
            statement = reader_sql(mode)
            self.assertTrue(statement.rstrip().endswith('$function$;'))
            canonical = statement.rstrip()[:-1] + '\n'
            self.assertEqual(hashlib.md5(canonical.encode()).hexdigest(), reader_hash(mode))
    def test_guards_are_exact_generated_synthetic_files(self):
        for mode in ['apply', 'recovery']:
            self.assertEqual(read_sql(f'combined-{mode}-guard.sql'), guard(mode))
            self.assertIn('WHERE user_id=v_owner AND id IN(', guard(mode))
            self.assertIn('is_suppressed IS FALSE', guard(mode))
            self.assertIn('is_suppressed IS TRUE', guard(mode))
            self.assertNotIn('CREATE OR REPLACE FUNCTION', guard(mode))
    def test_bad_guard_inputs_are_rejected(self):
        for mode, ids in [('invalid',PLANNED_IDS),('apply',PLANNED_IDS[:-1]),('recovery',[PLANNED_IDS[0]]*24)]:
            with self.assertRaises(ValueError): guard_sql(mode,ids,F['rule']['id'])
    def test_reused_document_schema_only_removes_shared_auth_bootstrap(self):
        text=document_schema_without_duplicate_auth()
        for table in ['lts_debt_position','lts_commitment_documentary_schedule']:
            self.assertIn('CREATE TABLE public.'+table,text)
        self.assertNotIn('CREATE SCHEMA auth',text)
        self.assertNotIn('CREATE TABLE auth.users',text)


def build_suite(core, doc, psycopg, sql, Jsonb):
    doc.Jsonb = Jsonb
    class CombinedContract(core.TransactionContract):
        def setUp(self):
            super().setUp()
            self.db.execute(document_schema_without_duplicate_auth())
            self.today=self.db.execute('SELECT '+doc.day_expression()).fetchone()[0]
            # Reuse the documentary fixture insertion helper, with the same owner
            # as the financial fixtures and wholly synthetic source labels.
            for delta, balance, label in [(-10,900,'Synthetic combined old'),(0,800,'Synthetic combined current'),(10,700,'Synthetic combined future')]:
                doc.PostgreSQLContract.insert_position(self,'qa_combined',self.today+timedelta(days=delta),balance,label,{'schedule_subject_to_TR':True},owner=F['owner'])
            self.db.execute("INSERT INTO lts_commitment_documentary_schedule (user_id,commitment_id,installment_number,due_date,amount_total,principal,interest,balance_after,status) VALUES (%s,'qa_combined',1,%s,11,10,1,789,'scheduled')",(F['owner'],self.today+timedelta(days=30)))
            self.db.execute(read_sql('documentary_reader_original.sql'))
            self.db.execute('REVOKE EXECUTE ON FUNCTION public.lts_documentary_commitments_v1(uuid) FROM PUBLIC')
            self.original_function_state=self.function_state()
            self.original_definition=self.original_function_state[0]
            self.original_oid=self.original_function_state[1]
            self.assertIsNotNone(self.original_function_state[3], 'Fixture must exercise an explicit ACL')
            self.doc_before=self.document_rows()
            self.db.execute('CREATE TABLE qa_expected_new(id uuid PRIMARY KEY)')
            for identity in PLANNED_IDS:self.db.execute('INSERT INTO qa_expected_new VALUES (%s)',(identity,))
            self.db.execute('CREATE TABLE qa_epoch_observation(epoch bigint,reader_definition text,reader_oid oid,planned_row_count bigint,transaction_id bigint)')
            self.db.execute("""CREATE FUNCTION public.qa_observe_epoch() RETURNS trigger LANGUAGE plpgsql AS $$
            BEGIN
              INSERT INTO public.qa_epoch_observation
              SELECT NEW.epoch,pg_get_functiondef('public.lts_documentary_commitments_v1(uuid)'::regprocedure),
                'public.lts_documentary_commitments_v1(uuid)'::regprocedure::oid,
                (SELECT count(*) FROM public.financial_events f JOIN public.qa_expected_new n ON n.id=f.id),txid_current();
              RETURN NULL;
            END $$;
            CREATE TRIGGER qa_observe_epoch AFTER UPDATE ON public.lts_read_cache_epoch_v242
              FOR EACH ROW EXECUTE FUNCTION public.qa_observe_epoch();""")
        def function_state(self):
            return self.db.execute("SELECT pg_get_functiondef(p.oid),p.oid,p.proowner,p.proacl,p.proconfig FROM pg_proc p WHERE p.oid='public.lts_documentary_commitments_v1(uuid)'::regprocedure").fetchone()
        def document_rows(self):
            result={}
            for table in ['lts_debt_position','lts_commitment_documentary_schedule']:
                result[table]=self.db.execute(sql.SQL('SELECT to_jsonb(t) FROM {} t ORDER BY id').format(sql.Identifier(table))).fetchall()
            return result
        def combined_snapshot(self):
            return {'economic':self.snapshot(),'documentary_rows':self.document_rows(),'function':self.function_state(),'epoch_observations':self.observations()}
        def observations(self):
            return self.db.execute('SELECT epoch,reader_definition,reader_oid,planned_row_count,transaction_id FROM qa_epoch_observation ORDER BY epoch').fetchall()
        def set_reader(self,mode):self.db.execute(reader_sql(mode))
        def run_combined(self,mode,late_error=False,after_ddl_error=False):
            with self.db.transaction():
                self.db.execute('SET TRANSACTION ISOLATION LEVEL SERIALIZABLE')
                self.db.execute("SET LOCAL statement_timeout='15s'; SET LOCAL lock_timeout='2s';")
                self.db.execute(guard(mode))
                self.db.execute(reader_sql(mode))
                expected=reader_hash(mode)
                actual=self.db.execute("SELECT md5(pg_get_functiondef('public.lts_documentary_commitments_v1(uuid)'::regprocedure))").fetchone()[0]
                if actual != expected:
                    self.db.execute("DO $$ BEGIN RAISE EXCEPTION 'P07_DOCUMENTARY_CANDIDATE_MISMATCH'; END $$")
                if after_ddl_error:self.db.execute("DO $$ BEGIN RAISE EXCEPTION 'QA_AFTER_DDL_ABORT'; END $$")
                # Execute the existing DO block without any statement rewriting.
                self.db.execute(core.candidate(mode))
                if late_error:self.db.execute("DO $$ BEGIN RAISE EXCEPTION 'QA_LATE_COMBINED_ABORT'; END $$")
        def reject_combined(self,mode,error='P07_COMBINED_STATE_MISMATCH'):
            before=self.combined_snapshot()
            with self.assertRaisesRegex(psycopg.Error,error):self.run_combined(mode)
            self.assertEqual(self.combined_snapshot(),before)
        def read_payload(self):
            return self.db.execute('SELECT lts_documentary_commitments_v1(%s::uuid)',(F['owner'],)).fetchone()[0]
        def test_combined_apply_defines_reader_before_both_invalidations(self):
            old=self.old_rows();before_payload=self.read_payload();self.run_combined('apply')
            self.assertEqual(hashlib.md5(self.function_state()[0].encode()).hexdigest(),CANDIDATE_READER_MD5)
            self.assertEqual(self.function_state()[1:],self.original_function_state[1:])
            self.assertEqual(self.old_rows(),old);self.assertEqual(self.document_rows(),self.doc_before)
            self.assertEqual([row[0] for row in self.new_rows()],F['new'])
            actual_rule=self.rule();self.assertEqual(actual_rule['date_to'],F['rule_after']['date_to'])
            self.assertEqual(actual_rule['updated_at'],actual_rule['evidence']['schedule_extension']['applied_at'])
            self.assertEqual(self.epoch(),102)
            observations=self.observations();self.assertEqual(len(observations),2)
            self.assertEqual([row[0] for row in observations],[101,102])
            for row in observations:
                self.assertEqual(row[1],self.function_state()[0]);self.assertEqual(row[2],self.original_oid);self.assertEqual(row[3],24)
            self.assertEqual(len({row[4] for row in observations}),1)
            after_payload=self.read_payload();self.assertEqual(len(before_payload['items']),3);self.assertEqual(len(after_payload['items']),2)
            self.assertEqual(after_payload['items'][0]['source_label'],'Synthetic combined current · cronograma sujeito à TR')
        def test_combined_recovery_restores_exact_function_and_rule_suppresses_only_24(self):
            self.run_combined('apply');old=self.old_rows();self.run_combined('recovery')
            self.assertEqual(self.function_state(),self.original_function_state)
            self.assertEqual(self.old_rows(),old);self.assertEqual(self.document_rows(),self.doc_before)
            self.assertEqual(self.rule(),F['rule'])
            self.assertEqual([row[0] for row in self.new_rows()],[r|{'is_suppressed':True,'suppression_reason':'recovery:qa_extension_2040_2041'} for r in F['new']])
            self.assertEqual(self.epoch(),104)
            for row in self.observations()[-2:]:self.assertEqual(row[1],self.original_definition)
        def test_combined_recovery_failures_roll_back_function_rows_rule_and_cache(self):
            self.run_combined('apply')
            for stage in ['after_ddl','after_economy']:
                with self.subTest(stage=stage):
                    before=self.combined_snapshot()
                    with self.assertRaisesRegex(psycopg.Error,'QA_AFTER_DDL_ABORT|QA_LATE_COMBINED_ABORT'):
                        self.run_combined('recovery',after_ddl_error=stage=='after_ddl',late_error=stage=='after_economy')
                    self.assertEqual(self.combined_snapshot(),before)
        def test_combined_owner_bound_count_does_not_accept_foreign_identities(self):
            for row in F['new']:self.insert_event(row,user=F['other_owner'])
            # The count is owner-bound: zero owned IDs is initially eligible.
            # The complete economic block then rejects the global UUID collision.
            self.db.execute(guard('apply'))
            self.reject_combined('apply','duplicate key value violates unique constraint')
        def reset_fixture(self):
            self.db.close()
            self.setUp()
        def test_combined_apply_failures_rollback_ddl_and_all_late_writes(self):
            for stage in ['after_ddl','after_economy']:
                with self.subTest(stage=stage):
                    before=self.combined_snapshot()
                    with self.assertRaisesRegex(psycopg.Error,'QA_AFTER_DDL_ABORT|QA_LATE_COMBINED_ABORT'):
                        self.run_combined('apply',after_ddl_error=stage=='after_ddl',late_error=stage=='after_economy')
                    self.assertEqual(self.combined_snapshot(),before)
        def test_combined_repetitions_preserve_warm_caches_and_epoch(self):
            self.run_combined('apply')
            self.db.execute("INSERT INTO lts_v229_read_cache VALUES (4,%s,'{\"synthetic_warm\":true}')",(F['owner'],))
            before=self.combined_snapshot();self.run_combined('apply');self.assertEqual(self.combined_snapshot(),before)
            self.run_combined('recovery')
            self.db.execute("INSERT INTO lts_v229_read_cache VALUES (4,%s,'{\"synthetic_warm\":true}')",(F['owner'],))
            before=self.combined_snapshot();self.run_combined('recovery');self.assertEqual(self.combined_snapshot(),before)
        def test_combined_crossed_states_abort_before_ddl(self):
            scenarios=[('original','live','apply'),('candidate','initial','apply'),
                       ('original','live','recovery'),('candidate','suppressed','recovery'),
                       ('original','suppressed','apply'),('candidate','partial','recovery'),
                       ('candidate','mixed','recovery'),('unknown','initial','apply')]
            for index,(reader,economy,mode) in enumerate(scenarios):
                if index:self.reset_fixture()
                with self.subTest(reader=reader,economy=economy,mode=mode):
                    if economy in {'live','suppressed','mixed'}:self.apply()
                    if economy=='suppressed':self.recovery()
                    if economy=='partial':self.insert_event(F['new'][0])
                    if economy=='mixed':self.db.execute('UPDATE financial_events SET is_suppressed=true WHERE id=%s',(PLANNED_IDS[0],))
                    if reader=='candidate':self.set_reader('apply')
                    if reader=='unknown':self.db.execute("CREATE OR REPLACE FUNCTION public.lts_documentary_commitments_v1(p_user_id uuid) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$ SELECT '{}'::jsonb $$")
                    self.reject_combined(mode)
        def test_combined_coarse_state_cannot_bypass_integral_economic_guards(self):
            for index,mutation in enumerate(['rule','new_row','old_backup']):
                if index:self.reset_fixture()
                with self.subTest(mutation=mutation):
                    if mutation=='old_backup':
                        self.db.execute('UPDATE financial_events SET amount=amount+1 WHERE id=%s',(F['old'][0]['id'],))
                        self.reject_combined('apply','P07_EXISTING_ROWS_CHANGED')
                    else:
                        self.apply();self.set_reader('apply')
                        if mutation=='rule':self.db.execute("UPDATE lts_projection_replacement_rule SET reason='Synthetic changed rule'")
                        else:self.db.execute('UPDATE financial_events SET amount=amount+1 WHERE id=%s',(PLANNED_IDS[0],))
                        self.reject_combined('apply','P07_PARTIAL_OR_CONFLICTING_STATE')
                        self.reject_combined('recovery','P07_RECOVERY_CONCURRENT_CHANGE')
    # Only the new combined tests; the 38 base economic tests remain separate.
    names=sorted(name for name in CombinedContract.__dict__ if name.startswith('test_combined_'))
    return unittest.TestSuite(CombinedContract(name) for name in names)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--postgres',action='store_true')
    args=parser.parse_args()
    offline=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(OfflineCombinedContract))
    if not offline.wasSuccessful():return 1
    if not args.postgres:
        print('OFFLINE PASS. Combined PostgreSQL atomicity and concurrency NOT EXECUTED. Joint guard remains review-only.')
        return 0
    if os.environ.get('P07_QA_ALLOW_DISPOSABLE')!='1':parser.error('Explicit disposable-local-service opt-in required')
    import psycopg
    from psycopg import sql
    from psycopg.types.json import Jsonb
    import test_postgres as core
    import documentary_position_gate as doc
    core.DB='p07_qa_'+uuid.uuid4().hex[:24]
    admin=psycopg.connect(**local_connection_options(),dbname='postgres',autocommit=True)
    created=False
    try:
        version=int(admin.execute('SHOW server_version_num').fetchone()[0])
        if not 160000<=version<170000:raise RuntimeError('PostgreSQL 16 required')
        admin.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(core.DB)));created=True
        result=unittest.TextTestRunner(verbosity=2).run(build_suite(core,doc,psycopg,sql,Jsonb))
        return 0 if result.wasSuccessful() else 1
    finally:
        if created:admin.execute(sql.SQL('DROP DATABASE {} WITH (FORCE)').format(sql.Identifier(core.DB)))
        admin.close()
if __name__=='__main__':raise SystemExit(main())
