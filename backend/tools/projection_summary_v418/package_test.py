#!/usr/bin/env python3
"""Native atomic rollout checks over generic predecessors and invented rows."""
import argparse
import json
import subprocess
from pathlib import Path
from package import compose

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--database', required=True)
options = parser.parse_args()
if not options.database.startswith('v418_') or not options.database.replace('_', '').isalnum():
    raise SystemExit('Only disposable v418_ databases are accepted')


def sql(statement, expect_success=True):
    result = subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',options.database,'-c',statement],capture_output=True,text=True,timeout=12)
    if (result.returncode == 0) != expect_success:
        raise AssertionError(result.stderr or 'Expected the guarded transaction to be refused')
    return result.stdout if expect_success else result.stderr


def query(statement):
    return json.loads(sql(statement).strip().splitlines()[-1])


def snapshot():
    return query("SELECT jsonb_build_object('sources',qa_v415.source_hash(),"
        "'cron',(SELECT md5(jsonb_agg(to_jsonb(j) ORDER BY jobid)::text) FROM cron.job j),"
        "'attributes',(SELECT jsonb_agg(to_jsonb(p)-'prosrc' ORDER BY p.oid) FROM pg_proc p "
        "WHERE p.oid IN ('lts_projection_private_v412.build(uuid,date)'::regprocedure,"
        "'lts_projection_private_v412.read_policy()'::regprocedure,"
        "'lts_product_refresh_private_v415.run_claimed()'::regprocedure)),"
        "'bodies',(SELECT jsonb_agg(md5(pg_get_functiondef(p.oid)) ORDER BY p.oid) FROM pg_proc p "
        "WHERE p.oid IN ('lts_projection_private_v412.build(uuid,date)'::regprocedure,"
        "'lts_projection_private_v412.read_policy()'::regprocedure,"
        "'lts_product_refresh_private_v415.run_claimed()'::regprocedure)));")


sql("CREATE FUNCTION lts_projection_private_v412.owner_policy(uuid) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{\"enabled\":true}'::jsonb $$; "
    "SELECT qa_v415.reset(true); "
    "SELECT lts_product_refresh_private_v415.enqueue(qa_v415.owner(1),'manual',false); "
    "UPDATE lts_product_refresh_private_v415.queue SET state='running' WHERE user_id=qa_v415.owner(1);")
before = snapshot()
error = sql(compose(), expect_success=False)
assert 'existing refresh claim is running' in error
assert snapshot() == before
sql("UPDATE lts_product_refresh_private_v415.queue SET state='ready' WHERE user_id=qa_v415.owner(1);")
sql(compose())
after = snapshot()
assert {k:v for k,v in before.items() if k!='bodies'} == {k:v for k,v in after.items() if k!='bodies'}
assert before['bodies'] != after['bodies']
queue = query('SELECT to_jsonb(q) FROM lts_product_refresh_private_v415.queue q WHERE user_id=qa_v415.owner(1);')
assert queue['state']=='pending' and queue['request_version']==2 and queue['invalidate_caches'] is False
error = sql(compose(), expect_success=False)
assert 'Unexpected predecessor' in error
assert snapshot() == after
assert query('SELECT to_jsonb(q) FROM lts_product_refresh_private_v415.queue q WHERE user_id=qa_v415.owner(1);') == queue
print(json.dumps({'pass':True,'checks':4,'scope':['busy claim refuses whole package','exact package preserves sources cron and execution attributes','one existing queue request without cache invalidation','reapplication rejected without mutation']}))
