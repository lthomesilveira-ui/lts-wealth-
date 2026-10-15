"""Synthetic documentary reader QA. Default: offline checks only.

Reviewed PostgreSQL 16 CI only:
  P07_QA_ALLOW_DISPOSABLE=1 python documentary_position_gate.py --postgres \
    --ui-source ../../releases/v271/index.html

Creates and drops only its own generated p07_qa_* database on explicit loopback.
No production DSN, application secrets, publication, migrations or live browser.
SQL execution is not claimed by the offline mode. PostgreSQL fixtures use the
actual local day of their transaction. Fixed boundary tests evaluate the exact
extracted clock expression with explicit instants; SET TIME ZONE is not a clock.
"""
from pathlib import Path
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo
import argparse
import hashlib
import json
import os
import re
import subprocess
import unittest
import uuid

from connection_config import local_connection_options

P = Path(__file__).resolve().parent
CANDIDATE = (P / 'documentary_reader_candidate.sql').read_text()
ORIGINAL = (P / 'documentary_reader_original.sql').read_text()
OWNER = 'f0000000-0000-4000-8000-000000000101'
OTHER = 'f0000000-0000-4000-8000-000000000102'
EMPTY = 'f0000000-0000-4000-8000-000000000103'
TR_LABEL = 'cronograma sujeito à TR'
FLAG_EXPR = "CASE WHEN d.metadata->'schedule_subject_to_TR'='true'::jsonb AND position('sujeito à TR' in coalesce(d.source_label,''))=0 THEN coalesce(d.source_label,'Documento')||' · cronograma sujeito à TR' ELSE d.source_label END"
UI_SOURCE = None
DB = None


def day_expression():
    matches = re.findall(r"\(current_timestamp AT TIME ZONE '[^']+'\)::date", CANDIDATE)
    if len(matches) != 1:
        raise AssertionError('Expected exactly one reviewed date expression')
    return matches[0]


def position(day, source, balance, **extra):
    return {'commitment_id': 'cipo_396', 'as_of_date': day.isoformat(),
            'source_label': source, 'debt_balance': balance,
            'metadata': {'remaining_installments': 2, 'final_due': '2042-12-20'},
            'schedule_loaded': {'rows': []}, **extra}


def render(payload, expected=None, fallback=False, selection='cipo_396', forbidden=()):
    command = ['node', str(P / 'documentary_renderer_gate.cjs')]
    if UI_SOURCE:
        command += ['--ui-source', str(UI_SOURCE)]
    result = subprocess.run(command, input=json.dumps({
        'payload': payload, 'expected': expected, 'fallback': fallback,
        'selection': selection, 'forbidden_sources': list(forbidden),
    }), text=True, capture_output=True, timeout=10, check=False)
    if result.returncode:
        raise AssertionError(result.stderr or result.stdout)
    receipt = json.loads(result.stdout)
    if UI_SOURCE and not receipt['actual_ui_source_checked']:
        raise AssertionError('Requested real UI source was not checked')
    return receipt


class OfflineContract(unittest.TestCase):
    def test_exact_reviewed_reader_sources(self):
        for name, expected in {
            'documentary_reader_candidate.sql': '17bbe70c3ccee34963f046c8ff7de55004e8f9631f5076f35ce56a706204d57c',
            'documentary_reader_original.sql': '9f368715839915bc52c21a919350a0d1c1a014a2d4e4541a0d641023b0411dd4',
        }.items():
            self.assertEqual(hashlib.sha256((P / name).read_bytes()).hexdigest(), expected)

    def test_candidate_has_exactly_three_reviewed_changes(self):
        rebuilt = ORIGINAL.replace(
            'from public.lts_debt_position where user_id=p_user_id',
            'from public.lts_debt_position where user_id=p_user_id AND as_of_date <= ' + day_expression(),
        ).replace("'source_label',d.source_label", "'source_label'," + FLAG_EXPR).replace(
            'order by d.commitment_id)', 'order by d.commitment_id,d.as_of_date desc nulls last)',
        )
        self.assertEqual(rebuilt, CANDIDATE)
        self.assertNotRegex(CANDIDATE, r'(?i)\b(?:insert|update|delete|truncate|alter\s+table)\b')
        self.assertNotIn('DISTINCT ON', CANDIDATE)
        self.assertIn('STABLE SECURITY DEFINER', CANDIDATE)
        self.assertIn("SET search_path TO 'public'", CANDIDATE)

    def test_schema_retains_not_null_and_unique(self):
        schema = (P / 'documentary_position_gate.sql').read_text()
        self.assertIn('as_of_date date NOT NULL', schema)
        self.assertIn('UNIQUE (user_id, commitment_id, as_of_date)', schema)

    def test_boundary_model_uses_explicit_instants(self):
        expression = day_expression()
        zone = re.search(r"AT TIME ZONE '([^']+)'", expression)[1]
        for instant, expected in [
            ('2042-10-15T01:00:00+00:00', '2042-10-14'),
            ('2042-10-15T03:00:00+00:00', '2042-10-15'),
        ]:
            self.assertEqual(datetime.fromisoformat(instant).astimezone(ZoneInfo(zone)).date().isoformat(), expected)

    def test_real_renderer_first_match_and_fallback(self):
        old = position(date(2042, 1, 1), 'Synthetic old source', 900)
        new = position(date(2042, 2, 1), 'Synthetic current source · ' + TR_LABEL, 800)
        render({'items': [old, new]}, old, forbidden=(new['source_label'],))
        render({'items': [new, old]}, new | {'tr_count': 1}, forbidden=(old['source_label'],))
        render({'items': []}, fallback=True)


def connect(name):
    return psycopg.connect(**local_connection_options(), dbname=name, autocommit=True)


class PostgreSQLContract(unittest.TestCase):
    def setUp(self):
        self.assertRegex(DB, r'^p07_qa_[0-9a-f]{24}$')
        self.db = connect(DB)
        self.addCleanup(self.db.close)
        # Keep fixtures and the real STABLE reader in the same real transaction.
        # PostgreSQL anchors current_timestamp itself; no fake clock is installed.
        self.db.execute('BEGIN')
        self.addCleanup(self.db.execute, 'ROLLBACK')
        self.db.execute('DROP SCHEMA public CASCADE; DROP SCHEMA IF EXISTS auth CASCADE; CREATE SCHEMA public;')
        self.db.execute((P / 'documentary_position_gate.sql').read_text())
        self.db.execute('INSERT INTO auth.users VALUES (%s),(%s),(%s)', (OWNER, OTHER, EMPTY))
        self.today = self.db.execute('SELECT ' + day_expression()).fetchone()[0]
        self.seed()
        self.db.execute(CANDIDATE)

    def insert_position(self, commitment, when, amount, source, metadata=None, owner=OWNER):
        self.db.execute('''INSERT INTO lts_debt_position
            (user_id,commitment_id,as_of_date,debt_balance,source_label,institution,contract_ref,metadata)
            VALUES (%s,%s,%s,%s,%s,'Synthetic institution','QA-ONLY',%s)''',
            (owner, commitment, when, amount, source, Jsonb(metadata or {})))

    def seed(self):
        old = self.today - timedelta(days=10)
        future = self.today + timedelta(days=1)
        self.insert_position('cipo_396', old, 900, 'Synthetic old source')
        self.insert_position('cipo_396', future, 700, 'Synthetic future source', {'schedule_subject_to_TR': True})
        self.insert_position('cipo_396', self.today, 800, 'Synthetic current source', {
            'schedule_subject_to_TR': True, 'remaining_installments': 2,
            'final_due': (self.today + timedelta(days=60)).isoformat(),
        })
        self.insert_position('cipo_396', self.today, 600, 'Synthetic other-owner source', owner=OTHER)
        self.insert_position('qa_beta', old, 500, 'Synthetic other-commitment source')
        for key, flag, source in [
            ('qa_false', False, 'Synthetic false source'),
            ('qa_missing', None, 'Synthetic missing source'),
            ('qa_string', 'true', 'Synthetic string flag source'),
            ('qa_null_flag', None, 'Synthetic null flag source'),
            ('qa_already', True, 'Synthetic prior note · ' + TR_LABEL),
            ('qa_no_label', True, None),
            ('qa_false_prior', False, 'Synthetic unchanged note · ' + TR_LABEL),
        ]:
            metadata = {} if key == 'qa_missing' else {'schedule_subject_to_TR': flag}
            self.insert_position(key, self.today, 400, source, metadata)
        self.insert_position('qa_future_only', future, 300, 'Synthetic future-only source')
        # Schedule dates are independent of eligible debt-position dates.
        for owner, installment, offset, amount, status in [
            (OWNER, 2, 60, 22, 'scheduled'), (OWNER, 1, 30, 11, 'scheduled'),
            (OWNER, 3, -1, 33, 'paid'), (OTHER, 1, 30, 99, 'scheduled'),
        ]:
            self.db.execute('''INSERT INTO lts_commitment_documentary_schedule
                (user_id,commitment_id,installment_number,due_date,amount_total,principal,interest,balance_after,status)
                VALUES (%s,'cipo_396',%s,%s,%s,%s,1,%s,%s)''',
                (owner, installment, self.today + timedelta(days=offset), amount, amount - 1, 800 - amount, status))

    def snapshot(self):
        result = {}
        for table in ('lts_debt_position', 'lts_commitment_documentary_schedule'):
            result[table] = self.db.execute(sql.SQL('SELECT to_jsonb(t) FROM {} t ORDER BY id').format(sql.Identifier(table))).fetchall()
            result[table + '_oid'] = self.db.execute('SELECT %s::regclass::oid', ('public.' + table,)).fetchone()[0]
        return result

    def read(self, owner=OWNER):
        return self.db.execute('SELECT public.lts_documentary_commitments_v1(%s::uuid)', (owner,)).fetchone()[0]

    def test_original_and_candidate_delta_and_tables_preserved(self):
        before = self.snapshot()
        self.db.execute(ORIGINAL)
        original = self.read()
        self.db.execute(CANDIDATE)
        candidate = self.read()
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(original['version'], candidate['version'])
        self.assertEqual(original['guardrail'], candidate['guardrail'])
        self.assertTrue(any(x['as_of_date'] > self.today.isoformat() for x in original['items']))
        self.assertFalse(any(x['as_of_date'] > self.today.isoformat() for x in candidate['items']))
        original_map = {(x['commitment_id'], x['as_of_date']): x for x in original['items']}
        for item in candidate['items']:
            previous = original_map[(item['commitment_id'], item['as_of_date'])]
            self.assertEqual({k: v for k, v in item.items() if k != 'source_label'},
                             {k: v for k, v in previous.items() if k != 'source_label'})
        self.assertEqual(len(original['items']) - len(candidate['items']), 2)

    def test_latest_position_reaches_real_renderer(self):
        before = self.snapshot()
        payload = self.read()
        items = payload['items']
        self.assertEqual(items, sorted(items, key=lambda x: (x['commitment_id'], -date.fromisoformat(x['as_of_date']).toordinal())))
        choices = [x for x in items if x['commitment_id'] == 'cipo_396']
        self.assertEqual(len(choices), 2, 'Older eligible snapshot must remain in the result')
        selected = choices[0]
        self.assertEqual(selected['as_of_date'], self.today.isoformat())
        self.assertEqual(selected['debt_balance'], 800)
        self.assertEqual(selected['source_label'], 'Synthetic current source · ' + TR_LABEL)
        self.assertEqual(selected['schedule_loaded']['remaining_loaded'], 2)
        self.assertEqual(selected['schedule_loaded']['future_loaded_total'], 33)
        self.assertEqual([x['amount'] for x in selected['schedule_loaded']['rows']], [11, 22])
        self.assertGreater(selected['schedule_loaded']['next_date'], self.today.isoformat())
        render(payload, selected | {'tr_count': 1}, forbidden=(
            'Synthetic old source', 'Synthetic future source', 'Synthetic other-owner source',
            'Synthetic other-commitment source', 'Synthetic future-only source'))
        self.assertEqual(self.snapshot(), before)

    def test_boolean_tr_only_and_no_duplication(self):
        before = self.snapshot()
        items = {x['commitment_id']: x for x in self.read()['items']}
        expected = {
            'qa_false': 'Synthetic false source', 'qa_missing': 'Synthetic missing source',
            'qa_string': 'Synthetic string flag source', 'qa_null_flag': 'Synthetic null flag source',
            'qa_already': 'Synthetic prior note · ' + TR_LABEL,
            'qa_no_label': 'Documento · ' + TR_LABEL,
            'qa_false_prior': 'Synthetic unchanged note · ' + TR_LABEL,
        }
        for key, label in expected.items():
            self.assertEqual(items[key]['source_label'], label, key)
            self.assertLessEqual(items[key]['source_label'].count(TR_LABEL), 1, key)
        self.assertEqual(self.snapshot(), before)

    def test_user_isolation_and_no_future_only_document(self):
        payload = self.read()
        self.assertNotIn('qa_future_only', [x['commitment_id'] for x in payload['items']])
        render(payload, fallback=True, selection='qa_future_only')
        other = self.read(OTHER)
        self.assertEqual(len(other['items']), 1)
        self.assertEqual(other['items'][0]['source_label'], 'Synthetic other-owner source')
        self.assertEqual(other['items'][0]['schedule_loaded']['future_loaded_total'], 99)
        self.assertEqual(self.read(EMPTY)['items'], [])
        self.assertEqual(self.read(None)['items'], [])
        render(self.read(EMPTY), fallback=True)

    def test_not_null_and_unique_constraints_reject_ambiguity(self):
        self.assertTrue(self.db.execute("SELECT attnotnull FROM pg_attribute WHERE attrelid='lts_debt_position'::regclass AND attname='as_of_date'").fetchone()[0])
        self.assertEqual(self.db.execute("SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid='lts_debt_position'::regclass AND contype='u'").fetchall(),
                         [('UNIQUE (user_id, commitment_id, as_of_date)',)])
        before = self.snapshot()
        with self.assertRaises(psycopg.errors.NotNullViolation):
            with self.db.transaction():  # Savepoint preserves the surrounding fixture transaction.
                self.insert_position('qa_null_date', None, 123, 'Synthetic invalid null date')
        with self.assertRaises(psycopg.errors.UniqueViolation):
            with self.db.transaction():
                self.insert_position('cipo_396', self.today, 123, 'Synthetic duplicate date')
        self.assertEqual(self.snapshot(), before)

    def test_boundary_exact_sql_expression_and_rendered_selection(self):
        # This evaluates an extracted expression, NOT a frozen execution of the
        # installed function. Explicit timestamps make both boundaries reproducible.
        expression = day_expression().replace('current_timestamp', '(%s::timestamptz)')
        self.assertNotIn('current_timestamp', expression)
        for instant, expected_day, expected_source, expected_balance in [
            ('2042-10-15T01:00:00+00:00', '2042-10-14', 'Synthetic boundary old', 900),
            ('2042-10-15T03:00:00+00:00', '2042-10-15', 'Synthetic boundary new', 800),
        ]:
            # Session timezone should not alter the explicitly zoned expression.
            for session_zone in ('UTC', 'Asia/Tokyo', 'America/Los_Angeles'):
                self.db.execute('SELECT set_config(%s,%s,false)', ('TimeZone', session_zone))
                day = self.db.execute('SELECT ' + expression, (instant,)).fetchone()[0]
                self.assertEqual(day.isoformat(), expected_day)
                query = '''WITH synthetic(as_of_date,source_label,debt_balance) AS (VALUES
                  (DATE '2042-10-14','Synthetic boundary old',900),
                  (DATE '2042-10-15','Synthetic boundary new',800),
                  (DATE '2042-10-16','Synthetic boundary future',700))
                  SELECT jsonb_build_object('items',coalesce(jsonb_agg(jsonb_build_object(
                    'commitment_id','cipo_396','as_of_date',as_of_date,
                    'source_label',source_label,'debt_balance',debt_balance)
                    ORDER BY as_of_date DESC NULLS LAST),'[]'::jsonb))
                  FROM synthetic WHERE as_of_date <= ''' + expression
                payload = self.db.execute(query, (instant,)).fetchone()[0]
                self.assertEqual(payload['items'][0]['as_of_date'], expected_day)
                render(payload, {'as_of_date': expected_day, 'source_label': expected_source,
                                 'debt_balance': expected_balance}, forbidden=('Synthetic boundary future',))


def main():
    global UI_SOURCE, DB, psycopg, sql, Jsonb
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--postgres', action='store_true', help='Run actual function only in a newly created disposable PostgreSQL 16 database')
    parser.add_argument('--ui-source', type=Path, help='Actual repository releases/v271/index.html; required for PostgreSQL integration')
    args = parser.parse_args()
    if args.ui_source:
        UI_SOURCE = args.ui_source.resolve(strict=True)
    offline = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(OfflineContract))
    if not offline.wasSuccessful():
        return 1
    if not args.postgres:
        print('OFFLINE PASS. PostgreSQL execution, live authorization, cache behavior and browser QA NOT RUN.')
        return 0
    if os.environ.get('P07_QA_ALLOW_DISPOSABLE') != '1':
        parser.error('Set P07_QA_ALLOW_DISPOSABLE=1 only for an approved disposable local PostgreSQL 16 service')
    if UI_SOURCE is None:
        parser.error('--postgres requires --ui-source pointing to the actual repository release HTML')
    # Imported only for integration mode. Offline verification has no dependency.
    import psycopg
    from psycopg import sql
    from psycopg.types.json import Jsonb
    DB = 'p07_qa_' + uuid.uuid4().hex[:24]
    admin = connect('postgres')
    created = False
    try:
        version = int(admin.execute('SHOW server_version_num').fetchone()[0])
        if not 160000 <= version < 170000:
            raise RuntimeError('This suite requires PostgreSQL 16')
        admin.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(DB)))
        created = True
        suite = unittest.defaultTestLoader.loadTestsFromTestCase(PostgreSQLContract)
        result = unittest.TextTestRunner(verbosity=2).run(suite)
        return 0 if result.wasSuccessful() else 1
    finally:
        if created:
            admin.execute(sql.SQL('DROP DATABASE {} WITH (FORCE)').format(sql.Identifier(DB)))
        admin.close()


if __name__ == '__main__':
    raise SystemExit(main())
