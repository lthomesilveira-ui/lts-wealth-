"""Native PG17: exact function, real two-session locks, synthetic facts only."""
import json
import subprocess
import time
import unittest
from pathlib import Path

import build

ROOT = Path(__file__).resolve().parent
OWNER = '00000000-0000-4000-8000-000000000001'
OTHER = '00000000-0000-4000-8000-000000000002'
DATABASE = 'lts_flow_memo_v455'


def command(sql, error=None):
    result = subprocess.run(['psql', '-XAtq', '-v', 'ON_ERROR_STOP=1', '-d', DATABASE],
                            input=sql, text=True, capture_output=True)
    if error:
        assert result.returncode and error in result.stderr, (error, result.stderr)
    elif result.returncode:
        raise AssertionError(result.stderr)
    return result.stdout.strip()


def call(owner=OWNER, prefix=''):
    return command(prefix + f"SELECT public.lts_flow_read_source_key_v247('{owner}');")


def hold(sql):
    proc = subprocess.Popen(['psql', '-XAtq', '-v', 'ON_ERROR_STOP=1', '-d', DATABASE],
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True)
    proc.stdin.write("BEGIN;" + sql + "; SELECT 'held'; SELECT pg_sleep(2); COMMIT;\n")
    proc.stdin.close()
    while True:
        line = proc.stdout.readline()
        if not line:
            raise AssertionError('lock holder failed: ' + proc.stderr.read())
        if line.strip() == 'held':
            return proc


def finish(proc):
    proc.wait(timeout=5)
    error = proc.stderr.read()
    proc.stdout.close()
    proc.stderr.close()
    assert proc.returncode == 0, error


class FlowMemo(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        build.build()
        subprocess.run(['createdb', DATABASE], check=True, capture_output=True)
        assert command('SHOW TimeZone;') == 'America/Sao_Paulo', 'Fixture must use the product calendar'
        setup = (ROOT / 'setup.sql').read_text()
        # CI's service may already have the fixture-only roles from another job.
        for role in ['service_role', 'anon', 'authenticated']:
            setup = setup.replace(f'CREATE ROLE {role} NOLOGIN;',
                                  f"DO $$BEGIN IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='{role}') THEN CREATE ROLE {role} NOLOGIN; END IF; END$$;")
        command(setup)
        command((ROOT / 'helper.sql').read_text() + (ROOT / 'flow-original.sql').read_text())
        command(f"REVOKE ALL ON FUNCTION {build.TARGET} FROM PUBLIC; GRANT EXECUTE ON FUNCTION {build.TARGET} TO service_role;"
                f"REVOKE ALL ON FUNCTION {build.HELPER} FROM PUBLIC; GRANT EXECUTE ON FUNCTION {build.HELPER} TO service_role;")
        cls.attrs = command(f"SELECT (to_jsonb(p)-'prosrc')::text FROM pg_proc p WHERE oid='{build.TARGET}'::regprocedure;")
        cls.expected = call()
        command("UPDATE public.lts_v229_read_cache SET refreshed_at=now()-interval '10minutes';")
        locker = hold("UPDATE public.lts_v229_read_cache SET refreshed_at=refreshed_at")
        began = time.monotonic()
        command(f"SET statement_timeout='700ms'; SELECT public.lts_flow_read_source_key_v247('{OWNER}');", error='statement timeout')
        cls.baseline_ms = round((time.monotonic()-began)*1000,1)
        finish(locker)
        command((ROOT / 'install.sql').read_text())

    def setUp(self):
        command('TRUNCATE public.lts_v229_read_cache; UPDATE fixture_calls SET n=0;')

    def test_01_exact_result_and_metadata(self):
        self.assertEqual(call(), self.expected)
        self.assertEqual(self.attrs, command(f"SELECT (to_jsonb(p)-'prosrc')::text FROM pg_proc p WHERE oid='{build.TARGET}'::regprocedure;"))
        self.assertEqual(command('SELECT count(*) FROM fixture_sources;'), '2')

    def test_02_hit_and_five_minute_expiration(self):
        self.assertEqual(call(), self.expected)
        self.assertEqual(call(), self.expected)
        self.assertEqual(command('SELECT n FROM fixture_calls;'), '1')
        command("UPDATE lts_v229_read_cache SET refreshed_at=clock_timestamp()-interval '5minutes';")
        self.assertEqual(call(), self.expected)
        self.assertEqual(command('SELECT n FROM fixture_calls;'), '2')

    def test_03_owner_day_range_and_fingerprint_isolation(self):
        self.assertNotEqual(call(OTHER), self.expected)
        self.assertEqual(call(), self.expected)
        for mutate in ["as_of=current_date-1", "from_date=current_date-1", "to_date=current_date+1", "source_fingerprint='different'"]:
            command(f"UPDATE lts_v229_read_cache SET {mutate},payload='\"wrong\"' WHERE user_id='{OWNER}';")
            self.assertEqual(call(), self.expected)
            command("DELETE FROM lts_v229_read_cache WHERE payload='\"wrong\"';")

    def test_04_epoch_freshness_and_schedule_invalidation(self):
        call()
        command('UPDATE lts_read_cache_epoch_v242 SET epoch=epoch+1;')
        self.assertEqual(call(), self.expected)
        command(f"UPDATE fixture_sources SET as_of=as_of-interval '25hours' WHERE owner='{OWNER}';")
        self.assertEqual(call(), self.expected)
        command(f"UPDATE fixture_sources SET revision='changed' WHERE owner='{OWNER}';")
        changed = call()
        self.assertNotEqual(changed, self.expected)
        command(f"UPDATE fixture_sources SET revision='schedule-one',as_of=now() WHERE owner='{OWNER}';")
        self.assertEqual(command('SELECT n FROM fixture_calls;'), '4')

    def test_05_read_only_hit_and_miss(self):
        self.assertEqual(call(prefix='BEGIN READ ONLY;'), self.expected)
        self.assertEqual(command('SELECT count(*) FROM lts_v229_read_cache;'), '0')
        call()
        self.assertEqual(call(prefix='BEGIN READ ONLY;'), self.expected)
        self.assertEqual(command('SELECT n FROM fixture_calls;'), '1')

    def test_06_source_change_and_error_fail_closed(self):
        command(f"SET fixture.change='yes'; SELECT public.lts_flow_read_source_key_v247('{OWNER}');", error='source changed during read')
        command(f"SET fixture.error='yes'; SELECT public.lts_flow_read_source_key_v247('{OWNER}');", error='fixture source unavailable')
        self.assertEqual(command('SELECT count(*) FROM lts_v229_read_cache;'), '0')

    def test_07_row_write_contention_returns_identical_key(self):
        call()
        command("UPDATE lts_v229_read_cache SET refreshed_at=now()-interval '10minutes';")
        locker = hold('UPDATE lts_v229_read_cache SET refreshed_at=refreshed_at')
        began = time.monotonic()
        try:
            observed = command(f"SET statement_timeout='1300ms';SET lock_timeout='2s';SELECT public.lts_flow_read_source_key_v247('{OWNER}');SHOW lock_timeout;").splitlines()
            self.assertEqual(observed, [self.expected, '2s'])
            elapsed = round((time.monotonic()-began)*1000,1)
            self.assertLess(elapsed, 1000)
            print(json.dumps({'case':'real_row_lock','baseline_timeout_ms':self.baseline_ms,'after_ms':elapsed,'identical_result':True}), flush=True)
        finally:
            finish(locker)

    def test_08_cooperating_advisory_writer_is_skipped(self):
        locker = hold(f"SELECT pg_advisory_xact_lock(hashtextextended(concat_ws('|','lts:optional-memo-v430','{OWNER}','flow_source_key_v243',current_date::text,current_date::text,current_date::text),430))")
        began = time.monotonic()
        try:
            self.assertEqual(call(prefix="SET statement_timeout='1300ms';"), self.expected)
            self.assertLess(time.monotonic()-began, 1)
            self.assertEqual(command('SELECT count(*) FROM lts_v229_read_cache;'), '0')
        finally:
            finish(locker)

    def test_09_lock_deadline_is_restored_and_not_increased(self):
        for value in ['0', '50ms', '2s']:
            out = call(prefix=f"SET lock_timeout='{value}';")
            self.assertEqual(out, self.expected)
            value_after = command(f"SET lock_timeout='{value}'; SELECT public.lts_flow_read_source_key_v247('{OTHER}'); SHOW lock_timeout;").splitlines()[-1]
            self.assertEqual(value_after, value)

    def test_10_access_stays_private(self):
        for role in ['anon', 'authenticated']:
            command(f"SET ROLE {role};SELECT public.lts_flow_read_source_key_v247('{OWNER}');", error='permission denied')

    def test_11_reapply_rollback_and_predecessor_guard(self):
        command((ROOT / 'install.sql').read_text())
        command((ROOT / 'rollback.sql').read_text())
        self.assertEqual(call(), self.expected)
        command((ROOT / 'install.sql').read_text())
        command(build.definition('flow-original.sql').replace('RETURN key_value;', "RETURN key_value || 'divergent';"))
        command((ROOT / 'install.sql').read_text(), error='V455_PREDECESSOR_CHANGED')
        command((ROOT / 'rollback.sql').read_text(), error='V455_PREDECESSOR_CHANGED')
        command((ROOT / 'flow-original.sql').read_text())
        command((ROOT / 'install.sql').read_text())
        helper = build.definition('helper.sql')
        command(helper.replace('RETURN true;', 'RETURN false;'))
        command((ROOT / 'install.sql').read_text(), error='V455_OPTIONAL_MEMO_HELPER_CHANGED')
        command(helper)


if __name__ == '__main__':
    unittest.main(verbosity=2)
