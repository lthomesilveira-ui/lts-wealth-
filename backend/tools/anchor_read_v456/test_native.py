"""Exact predecessor/replacement, real PG17 locks, synthetic-only payloads."""
import json
import subprocess
import time
import unittest
from pathlib import Path

import build

ROOT=Path(__file__).resolve().parent
OWNER='00000000-0000-4000-8000-000000000001'
DATABASE='lts_anchor_read_v456'


def sql(query,error=None):
    p=subprocess.run(['psql','-XAtq','-v','ON_ERROR_STOP=1','-d',DATABASE],input=query,text=True,capture_output=True)
    if error:
        assert p.returncode and error in p.stderr,(error,p.stderr)
    elif p.returncode:
        raise AssertionError(p.stderr)
    return p.stdout.strip()


def call():
    return json.loads(sql(f"SELECT public.lts_apply_current_liquidity_anchor_v1('{OWNER}');"))


def seed(current=True):
    sql(f"""TRUNCATE lts_product_read_cache;UPDATE fixture_calls SET n=0;
    INSERT INTO lts_product_read_cache(user_id,payload,refreshed_at,source)
    VALUES('{OWNER}','{{"fixture":"base","unknown":null}}',now()-interval '1hour','fixture');
    UPDATE lts_product_read_cache SET payload=payload||jsonb_build_object('canonical_summary',jsonb_build_object(
      'source_key','{'source-one' if current else 'stale'}','payload_key',public.lts_dashboard_payload_key_v240(payload)));
    """)


def hold(query):
    p=subprocess.Popen(['psql','-XAtq','-v','ON_ERROR_STOP=1','-d',DATABASE],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    p.stdin.write("BEGIN;"+query+";SELECT 'held';SELECT pg_sleep(2);COMMIT;\n")
    p.stdin.close()
    while True:
        line=p.stdout.readline()
        if not line:raise AssertionError(p.stderr.read())
        if line.strip()=='held':return p


def finish(p):
    p.wait(timeout=5)
    error=p.stderr.read();p.stdout.close();p.stderr.close()
    assert p.returncode==0,error


class Anchor(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        build.build()
        subprocess.run(['createdb',DATABASE],check=True,capture_output=True)
        assert sql('SHOW TimeZone;')=='America/Sao_Paulo'
        sql((ROOT/'setup.sql').read_text()+(ROOT/'anchor-original.sql').read_text())
        for role in ['service_role','anon','authenticated']:
            sql(f"DO $$BEGIN IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='{role}')THEN CREATE ROLE {role} NOLOGIN;END IF;END$$;")
        sql(f'REVOKE ALL ON FUNCTION {build.TARGET} FROM PUBLIC;GRANT EXECUTE ON FUNCTION {build.TARGET} TO service_role;')
        cls.attrs=sql(f"SELECT (to_jsonb(p)-'prosrc')::text FROM pg_proc p WHERE oid='{build.TARGET}'::regprocedure;")
        seed(True)
        cls.expected_hit=call()
        locker=hold('UPDATE lts_product_read_cache SET source=source')
        began=time.monotonic()
        # The predecessor overrides statement_timeout; use its caller's lock deadline.
        sql(f"SET lock_timeout='700ms';SELECT public.lts_apply_current_liquidity_anchor_v1('{OWNER}');",error='lock timeout')
        cls.before_ms=round((time.monotonic()-began)*1000,1)
        finish(locker)
        seed(False)
        cls.expected_miss=call()
        cls.expected_payload=sql('SELECT payload::text FROM lts_product_read_cache;')
        sql((ROOT/'install.sql').read_text())

    def setUp(self):
        seed(True)

    def test_01_hit_result_metadata_and_no_write(self):
        before=sql('SELECT to_jsonb(c)::text FROM lts_product_read_cache c;')
        self.assertEqual(call(),self.expected_hit)
        self.assertEqual(before,sql('SELECT to_jsonb(c)::text FROM lts_product_read_cache c;'))
        self.assertEqual(self.attrs,sql(f"SELECT (to_jsonb(p)-'prosrc')::text FROM pg_proc p WHERE oid='{build.TARGET}'::regprocedure;"))
        self.assertEqual(sql('SELECT n FROM fixture_calls;'),'0')

    def test_02_current_hit_does_not_wait_for_writer(self):
        locker=hold('UPDATE lts_product_read_cache SET source=source')
        began=time.monotonic()
        try:
            result=json.loads(sql(f"SET lock_timeout='700ms';SELECT public.lts_apply_current_liquidity_anchor_v1('{OWNER}');"))
            elapsed=round((time.monotonic()-began)*1000,1)
            self.assertEqual(result,self.expected_hit)
            self.assertLess(elapsed,500)
            print(json.dumps({'case':'validated_hit_during_writer','before_timeout_ms':self.before_ms,'after_ms':elapsed,'identical_result':True}),flush=True)
        finally:finish(locker)

    def test_03_miss_retains_complete_payload_and_rebuild(self):
        seed(False)
        self.assertEqual(call(),self.expected_miss)
        self.assertEqual(sql('SELECT payload::text FROM lts_product_read_cache;'),self.expected_payload)
        self.assertEqual(sql('SELECT n FROM fixture_calls;'),'1')
        self.assertEqual(call(),self.expected_hit)

    def test_04_both_fingerprints_are_required(self):
        sql("UPDATE lts_product_read_cache SET payload=jsonb_set(payload,'{canonical_summary,payload_key}','\"invalid\"');")
        self.assertFalse(call()['cache_hit'])
        seed(True)
        sql("UPDATE fixture_sources SET source_key='source-two';")
        self.assertFalse(call()['cache_hit'])
        sql("UPDATE fixture_sources SET source_key='source-one';")

    def test_05_stale_result_still_requires_write_lock(self):
        seed(False)
        locker=hold('UPDATE lts_product_read_cache SET source=source')
        try:
            sql(f"SET lock_timeout='700ms';SELECT public.lts_apply_current_liquidity_anchor_v1('{OWNER}');",error='lock timeout')
            self.assertEqual(sql('SELECT n FROM fixture_calls;'),'0')
        finally:finish(locker)

    def test_06_recheck_after_a_writer_finishes(self):
        seed(False)
        locker=hold("UPDATE lts_product_read_cache SET payload=jsonb_set(payload,'{canonical_summary,source_key}','\"source-one\"')")
        try:
            self.assertEqual(call(),self.expected_hit)
            self.assertEqual(sql('SELECT n FROM fixture_calls;'),'0')
        finally:finish(locker)

    def test_07_missing_cache_stays_unavailable(self):
        sql('TRUNCATE lts_product_read_cache;')
        sql(f"SELECT public.lts_apply_current_liquidity_anchor_v1('{OWNER}');",error='product cache unavailable')

    def test_08_read_only_hit_and_miss(self):
        self.assertEqual(json.loads(sql(f"BEGIN READ ONLY;SELECT public.lts_apply_current_liquidity_anchor_v1('{OWNER}');COMMIT;")),self.expected_hit)
        seed(False)
        sql(f"BEGIN READ ONLY;SELECT public.lts_apply_current_liquidity_anchor_v1('{OWNER}');",error='read-only transaction')

    def test_09_private_access_and_owner_isolation(self):
        for role in ['anon','authenticated']:
            sql(f"SET ROLE {role};SELECT public.lts_apply_current_liquidity_anchor_v1('{OWNER}');",error='permission denied')
        sql("SELECT public.lts_apply_current_liquidity_anchor_v1('00000000-0000-4000-8000-000000000099');",error='product cache unavailable')

    def test_10_idempotence_rollback_and_drift_guard(self):
        sql((ROOT/'install.sql').read_text())
        sql((ROOT/'rollback.sql').read_text())
        self.assertEqual(call(),self.expected_hit)
        sql((ROOT/'install.sql').read_text())
        sql(build.definition('anchor-original.sql').replace('DECLARE c record;','DECLARE c record; /* divergent */'))
        sql((ROOT/'install.sql').read_text(),error='V456_PREDECESSOR_CHANGED')
        sql((ROOT/'rollback.sql').read_text(),error='V456_PREDECESSOR_CHANGED')
        sql((ROOT/'anchor-original.sql').read_text())
        sql((ROOT/'install.sql').read_text())


if __name__=='__main__':
    unittest.main(verbosity=2)
