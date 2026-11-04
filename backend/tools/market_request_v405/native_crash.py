"""Crash only the synthetic GitHub Actions PostgreSQL 17 service, then verify reuse."""
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
container = os.environ.get('V405_POSTGRES_CONTAINER', '')
if (os.environ.get('GITHUB_ACTIONS') != 'true'
        or os.environ.get('PGHOST') not in ('localhost', '127.0.0.1')
        or os.environ.get('PGDATABASE') != 'v405_restart'
        or not re.fullmatch(r'[a-f0-9]{12,64}', container)):
    raise SystemExit('Refusing crash test outside the dedicated local synthetic CI service.')


def run(args, *, text=None):
    result = subprocess.run(args, input=text, text=True, capture_output=True, timeout=40, check=True)
    return result.stdout.strip()


image = run(['docker', 'inspect', '--format', '{{.Config.Image}}', container])
if image != 'postgres:17':
    raise SystemExit('Refusing crash test for an unexpected container image.')


def sql(query):
    return run(['psql', '-X', '-v', 'ON_ERROR_STOP=1', '-At', '-c', query])


def read(query):
    return json.loads(sql(query))


def assert_true(name, passed):
    if not passed:
        raise AssertionError(name)
    checks.append(name)


checks = []
fixture = run(['python3', str(ROOT / 'backend/tools/market_request_v405/setup.py')])
run(['psql', '-X', '-v', 'ON_ERROR_STOP=1'], text=fixture)
migration = ROOT / 'backend/patches/v405/market_request_generations.sql'
run(['psql', '-X', '-v', 'ON_ERROR_STOP=1', '--single-transaction', '-f', str(migration)])
sql("SELECT setval('net.http_request_queue_id_seq',1,false)")
assert_true('two_requests_before_crash', len(read('SELECT public.lts_market_request_quotes_v290()')) == 2)

snapshot_sql = """SELECT jsonb_build_object(
 'generation',pg_postmaster_start_time(),
 'rows',(SELECT count(*) FROM public.lts_market_request_v290),
 'history_hash',(SELECT md5(jsonb_agg(to_jsonb(r) ORDER BY request_generation,request_id)::text) FROM public.lts_market_request_v290 r),
 'quote_hash',(SELECT md5(jsonb_agg(to_jsonb(q) ORDER BY id)::text) FROM public.lts_market_quote_v290 q))"""
before = read(snapshot_sql)
sql('CHECKPOINT')
run(['docker', 'kill', '--signal=KILL', container])
run(['docker', 'start', container])
for _ in range(60):
    available = subprocess.run(['pg_isready', '-q'], capture_output=True, timeout=5)
    if available.returncode == 0:
        break
    time.sleep(0.5)
else:
    raise AssertionError('Synthetic PostgreSQL did not restart within 30 seconds')

after = read(snapshot_sql)
transport = read("""SELECT jsonb_build_object(
 'last_value',last_value,'is_called',is_called,
 'queued',(SELECT count(*)FROM net.http_request_queue),
 'responses',(SELECT count(*)FROM net._http_response))FROM net.http_request_queue_id_seq""")
assert_true('postmaster_generation_actually_changed', before['generation'] != after['generation'])
assert_true('unlogged_transport_sequence_actually_reset', transport['last_value'] == 1 and not transport['is_called'])
assert_true('unlogged_request_and_response_tables_cleared', transport['queued'] == 0 and transport['responses'] == 0)
assert_true('durable_requests_survived_crash_unchanged', before['rows'] == after['rows'] and before['history_hash'] == after['history_hash'])
assert_true('durable_quotes_survived_crash_unchanged', before['quote_hash'] == after['quote_hash'])
fresh = read('SELECT public.lts_market_request_quotes_v290()')
assert_true('both_recycled_ids_enqueue_in_new_generation',
            [(r['symbol'], r['request_id']) for r in fresh] == [('OGN', 1), ('USD/BRL', 2)])
sql("""INSERT INTO net._http_response(id,status_code,content,created)
 SELECT request_id,200,public.qa_body_v405(symbol,CASE symbol WHEN 'OGN' THEN 42 ELSE 5.75 END)::text,clock_timestamp()
 FROM public.lts_market_request_v290 WHERE request_generation=pg_postmaster_start_time() AND processed_at IS NULL""")
collected = read('SELECT public.lts_market_collect_quotes_v290()')
assert_true('only_new_generation_responses_are_accepted', collected['accepted'] == 2)
summary = read("""SELECT jsonb_build_object(
 'interrupted',count(*)FILTER(WHERE request_generation<>pg_postmaster_start_time() AND error_code='request_interrupted_by_restart'),
 'current_complete',count(*)FILTER(WHERE request_generation=pg_postmaster_start_time() AND processed_at IS NOT NULL AND error_code IS NULL),
 'rows',count(*),
 'quotes_preserved',NOT EXISTS(SELECT 1 FROM public.qa_quotes_before_v405 b LEFT JOIN public.lts_market_quote_v290 q ON q.id=b.id WHERE to_jsonb(b)IS DISTINCT FROM to_jsonb(q)))
 FROM public.lts_market_request_v290""")
assert_true('old_pending_requests_retained_and_interrupted', summary['interrupted'] == 3)
assert_true('both_current_requests_completed', summary['current_complete'] == 2)
assert_true('all_request_generations_retained', summary['rows'] == before['rows'] + 2)
assert_true('original_quotation_observations_preserved', summary['quotes_preserved'])
assert_true('collection_after_restart_remains_idempotent',
            read('SELECT public.lts_market_collect_quotes_v290()') == {'accepted': 0, 'valuation_revision_changed': False})
prior_replay = read(snapshot_sql)
run(['psql', '-X', '-v', 'ON_ERROR_STOP=1', '--single-transaction', '-f', str(migration)])
assert_true('migration_replay_after_real_crash_preserves_history', read(snapshot_sql) == prior_replay)
print(json.dumps({'engine': sql('SELECT version()'), 'actual_postmaster_crash_test': True,
                  'transport': 'synthetic pg_net-compatible unlogged queue and sequence; no network',
                  'checks': checks, 'financial_data_used': False}, indent=2))
