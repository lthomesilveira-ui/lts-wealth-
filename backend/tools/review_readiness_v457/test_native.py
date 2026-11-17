"""Native PG17 readiness lifecycle and exact review rows, synthetic data only."""
import json
import subprocess
import time
import unittest
from pathlib import Path

import build

ROOT=Path(__file__).resolve().parent
DATABASE='lts_review_readiness_v457'
OWNER='00000000-0000-4000-8000-000000000001'
OTHER='00000000-0000-4000-8000-000000000099'
COLS=(ROOT.parent/'review_snapshot_v450/row-columns.txt').read_text().strip()
NAMES=','.join('r.'+c.strip().split()[0] for c in COLS.split(','))


def sql(query,error=None):
    p=subprocess.run(['psql','-XAtq','-v','ON_ERROR_STOP=1','-d',DATABASE],input=query,text=True,capture_output=True)
    if error:
        assert p.returncode and error in p.stderr,(error,p.stderr)
        return p.stderr
    if p.returncode:raise AssertionError(p.stderr)
    return p.stdout.strip()


def rows(owner=OWNER,prefix=''):
    return json.loads(sql(prefix+f"SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY row_key,amount),'[]') FROM lts_product_refresh_private_v415.expense_review_pending_v450('{owner}','2013-10-10',current_date)r;"))


def phase(state,request=2,complete=1,owner=OWNER):
    sql(f"UPDATE lts_product_refresh_private_v415.queue SET state='{state}',request_version={request},completed_version={complete},claim_token=NULL,claimed_version=NULL,claimed_epoch=NULL WHERE user_id='{owner}';")


class Review(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        build.build()
        subprocess.run(['createdb',DATABASE],check=True,capture_output=True)
        assert sql('SHOW TimeZone;')=='America/Sao_Paulo'
        sql(f"""
        CREATE SCHEMA lts_product_refresh_private_v415;
        CREATE TABLE public.lts_v229_read_cache(user_id uuid,kind text,as_of date,from_date date,to_date date,payload jsonb,refreshed_at timestamptz,source_fingerprint text,PRIMARY KEY(user_id,kind,as_of,from_date,to_date));
        CREATE TABLE lts_product_refresh_private_v415.queue(user_id uuid PRIMARY KEY,state text,request_version bigint,completed_version bigint,claim_token uuid,claimed_version bigint,claimed_epoch bigint);
        INSERT INTO lts_product_refresh_private_v415.queue(user_id,state,request_version,completed_version) VALUES('{OWNER}','ready',1,1),('{OTHER}','ready',1,1);
        CREATE TABLE public.fixture_rows(user_id uuid,{COLS});
        INSERT INTO public.fixture_rows(user_id,row_key,event_date,amount,category,identity_status,source_ref)
        VALUES('{OWNER}','one',current_date,123.456789,'fixture','pending','one'),
        ('{OWNER}','two',current_date,-8.765432,NULL,'pending','two'),
        ('{OWNER}','known',current_date,999,'fixture','identified','known'),
        ('{OTHER}','other',current_date,4.56789,'fixture','pending','other');
        INSERT INTO public.fixture_rows SELECT * FROM public.fixture_rows WHERE row_key='two';
        CREATE TABLE public.fixture_calls(n integer);INSERT INTO public.fixture_calls VALUES(0);
        CREATE TABLE public.fixture_epoch(n integer);INSERT INTO public.fixture_epoch VALUES(1);
        CREATE FUNCTION lts_product_refresh_private_v415.review_guard_v450(uuid) RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $f$
         SELECT CASE WHEN current_setting('fixture.no_guard',true)='yes' THEN NULL ELSE jsonb_build_object(
          'owner',$1,'day',current_date,'epoch',(SELECT n FROM public.fixture_epoch),
          'queue',(SELECT to_jsonb(q) FROM lts_product_refresh_private_v415.queue q WHERE user_id=$1),
          'rows',(SELECT md5(jsonb_agg(to_jsonb(r) ORDER BY row_key,amount)::text) FROM public.fixture_rows r WHERE user_id=$1)) END $f$;
        CREATE FUNCTION public.lts_v229_review_rows(uuid,date,date) RETURNS TABLE({COLS}) LANGUAGE plpgsql SET search_path='' AS $f$ BEGIN
         IF NOT current_setting('transaction_read_only')::boolean THEN UPDATE public.fixture_calls SET n=n+1;END IF;
         IF current_setting('fixture.change',true)='yes' THEN UPDATE public.fixture_epoch SET n=n+1;END IF;
         RETURN QUERY SELECT {NAMES} FROM public.fixture_rows r WHERE r.user_id=$1 AND r.event_date BETWEEN $2 AND $3;
        END $f$;
        """)
        sql((ROOT/'review-original.sql').read_text())
        for role in ['service_role','anon','authenticated']:
            sql(f"DO $$BEGIN IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='{role}')THEN CREATE ROLE {role} NOLOGIN;END IF;END$$;")
        sql(f'REVOKE ALL ON FUNCTION {build.TARGET} FROM PUBLIC;GRANT USAGE ON SCHEMA lts_product_refresh_private_v415 TO anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION {build.TARGET} TO service_role;')
        cls.attrs=sql(f"SELECT (to_jsonb(p)-'prosrc')::text FROM pg_proc p WHERE oid='{build.TARGET}'::regprocedure;")
        cls.expected=rows();cls.expected_other=rows(OTHER)
        sql('TRUNCATE public.lts_v229_read_cache;UPDATE fixture_calls SET n=0;')
        phase('pending')
        cls.before_pending=rows()
        cls.before_calls=int(sql('SELECT n FROM fixture_calls;'))
        assert cls.before_pending==cls.expected and cls.before_calls==1
        sql((ROOT/'install.sql').read_text())

    def setUp(self):
        sql('TRUNCATE public.lts_v229_read_cache;UPDATE fixture_calls SET n=0;')
        phase('ready',1,1);phase('ready',1,1,OTHER)

    def test_01_exact_ready_rows_nulls_duplicates_and_cache(self):
        self.assertEqual(rows(),self.expected)
        self.assertEqual(rows(),self.expected)
        self.assertEqual(len(self.expected),3)
        self.assertIsNone(self.expected[1]['category'])
        self.assertEqual(sql('SELECT n FROM fixture_calls;'),'1')
        self.assertEqual(self.attrs,sql(f"SELECT (to_jsonb(p)-'prosrc')::text FROM pg_proc p WHERE oid='{build.TARGET}'::regprocedure;"))

    def test_02_pending_and_running_do_not_rebuild_or_return_false_zero(self):
        for state in ['pending','running']:
            phase(state)
            start=time.monotonic()
            error=sql(f"\\set VERBOSITY verbose\nSELECT * FROM lts_product_refresh_private_v415.expense_review_pending_v450('{OWNER}','2013-10-10',current_date);",error='Expense review is waiting for the existing product refresh')
            self.assertIn('55000',error)
            self.assertEqual(sql('SELECT n FROM fixture_calls;'),'0')
            self.assertEqual(sql('SELECT count(*) FROM lts_v229_read_cache;'),'0')
            self.assertLess(time.monotonic()-start,1)
        print(json.dumps({'old_pending_history_rebuilds':self.before_calls,'new_pending_history_rebuilds':0,'false_empty_results':0,'existing_supported_sqlstate':'55000'}),flush=True)

    def test_03_waiting_does_not_reuse_prior_snapshot(self):
        self.assertEqual(rows(),self.expected)
        phase('running')
        sql(f"SELECT * FROM lts_product_refresh_private_v415.expense_review_pending_v450('{OWNER}','2013-10-10',current_date);",error='Expense review is waiting')
        self.assertEqual(sql('SELECT n FROM fixture_calls;'),'1')

    def test_04_worker_ready_update_warms_in_same_transaction(self):
        phase('running')
        token='00000000-0000-4000-8000-000000000055'
        sql(f"UPDATE lts_product_refresh_private_v415.queue SET claim_token='{token}',claimed_version=2,claimed_epoch=17 WHERE user_id='{OWNER}';")
        claim=json.dumps({'user_id':OWNER,'token':token,'version':2,'epoch':17})
        # The operational refresh invokes the browser review reader indirectly
        # before its final ready update. Preserve that exact claimed-worker path.
        self.assertEqual(rows(prefix=f"SET lts.product_refresh_claim='{claim}';"),self.expected)
        self.assertEqual(sql('SELECT n FROM fixture_calls;'),'1')
        sql('TRUNCATE lts_v229_read_cache;UPDATE fixture_calls SET n=0;')
        output=rows(prefix=f"BEGIN;UPDATE lts_product_refresh_private_v415.queue SET state='ready',completed_version=request_version WHERE user_id='{OWNER}';")
        self.assertEqual(output,self.expected)
        # The test connection closes without COMMIT; its warm was allowed using
        # the worker's own ready update, but no partial transaction leaks.
        self.assertEqual(sql('SELECT n FROM fixture_calls;'),'0')
        phase('ready',2,2)
        self.assertEqual(rows(),self.expected)
        self.assertEqual(rows(),self.expected)
        self.assertEqual(sql('SELECT n FROM fixture_calls;'),'1')

    def test_05_source_changes_still_fail_closed(self):
        sql(f"SET fixture.change='yes';SELECT * FROM lts_product_refresh_private_v415.expense_review_pending_v450('{OWNER}','2013-10-10',current_date);",error='Review sources changed during read')
        self.assertEqual(sql('SELECT count(*) FROM lts_v229_read_cache;'),'0')

    def test_06_other_owners_failed_or_missing_requests(self):
        phase('running',2,1,OTHER)
        self.assertEqual(rows(),self.expected)
        phase('failed')
        self.assertEqual(rows(),self.expected)
        sql(f"DELETE FROM lts_product_refresh_private_v415.queue WHERE user_id='{OWNER}';")
        self.assertEqual(rows(),self.expected)
        sql(f"INSERT INTO lts_product_refresh_private_v415.queue(user_id,state,request_version,completed_version) VALUES('{OWNER}','ready',1,1);")

    def test_07_private_access_read_only_and_guard_fallback(self):
        for role in ['anon','authenticated']:
            sql(f"SET ROLE {role};SELECT * FROM lts_product_refresh_private_v415.expense_review_pending_v450('{OWNER}','2013-10-10',current_date);",error='permission denied')
        self.assertEqual(rows(prefix='BEGIN READ ONLY;'),self.expected)
        self.assertEqual(sql('SELECT count(*) FROM lts_v229_read_cache;'),'0')
        self.assertEqual(rows(prefix="SET fixture.no_guard='yes';"),self.expected)

    def test_08_digest_and_range_invalidation_remain(self):
        rows()
        sql("UPDATE lts_v229_read_cache SET payload=jsonb_set(payload,'{rows}','[]');")
        self.assertEqual(rows(),self.expected)
        self.assertEqual(sql('SELECT n FROM fixture_calls;'),'2')
        sql('UPDATE lts_v229_read_cache SET to_date=current_date-1;')
        self.assertEqual(rows(),self.expected)
        self.assertEqual(sql('SELECT n FROM fixture_calls;'),'3')

    def test_09_rollback_reapply_and_drift_guard(self):
        sql((ROOT/'install.sql').read_text())
        sql((ROOT/'rollback.sql').read_text())
        self.assertEqual(rows(),self.expected)
        sql((ROOT/'install.sql').read_text())
        sql(build.definition('review-original.sql').replace('DECLARE source_guard jsonb;','DECLARE source_guard jsonb; /* divergent */'))
        sql((ROOT/'install.sql').read_text(),error='V457_PREDECESSOR_CHANGED')
        sql((ROOT/'rollback.sql').read_text(),error='V457_PREDECESSOR_CHANGED')
        sql((ROOT/'review-original.sql').read_text())
        sql((ROOT/'install.sql').read_text())

    def test_10_wrong_or_stale_claim_does_not_bypass_wait(self):
        phase('running')
        token='00000000-0000-4000-8000-000000000055'
        sql(f"UPDATE lts_product_refresh_private_v415.queue SET claim_token='{token}',claimed_version=2,claimed_epoch=17 WHERE user_id='{OWNER}';")
        correct={'user_id':OWNER,'token':token,'version':2,'epoch':17}
        for field,value in [('user_id',OTHER),('token',OTHER),('version',1),('epoch',16)]:
            claim=json.dumps(correct|{field:value})
            sql(f"SET lts.product_refresh_claim='{claim}';SELECT * FROM lts_product_refresh_private_v415.expense_review_pending_v450('{OWNER}','2013-10-10',current_date);",error='Expense review is waiting')
        self.assertEqual(sql('SELECT n FROM fixture_calls;'),'0')


if __name__=='__main__':
    unittest.main(verbosity=2)
