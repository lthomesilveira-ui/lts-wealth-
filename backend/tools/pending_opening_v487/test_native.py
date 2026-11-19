"""A read must not block on the worker, and missing work must still be enqueued."""
import json
from pathlib import Path
import subprocess

def sql(query):
    return subprocess.run(['psql','-XAtq','-v','ON_ERROR_STOP=1'],input=query,
                          capture_output=True,text=True,check=True).stdout.strip()

schema = 'lts_product_refresh_private_v415'
sql(f"""
CREATE SCHEMA {schema};
CREATE TABLE fixture_status(data jsonb);
INSERT INTO fixture_status VALUES ('{{"state":"pending","request_version":"12","completed_version":"11"}}');
CREATE TABLE fixture_enqueue(calls int);
INSERT INTO fixture_enqueue VALUES(0);
CREATE FUNCTION {schema}.enqueue(uuid,text,boolean) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
 UPDATE fixture_enqueue SET calls=calls+1;
 RETURN (SELECT data FROM fixture_status);
END $$;
CREATE FUNCTION public.lts_browser_product_v1() RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE refresh jsonb; v_uid uuid;
BEGIN
 SELECT data INTO refresh FROM fixture_status;
 IF refresh->>'state' IS DISTINCT FROM 'ready' THEN
  refresh:={schema}.enqueue(v_uid,'cache_read',false);
 END IF;
 RETURN refresh;
END $$;
""")
original = sql("SET search_path=''; SELECT md5(pg_get_functiondef('public.lts_browser_product_v1()'::regprocedure))")
migration = (Path(__file__).parent/'install.sql').read_text().replace('51ac0b37b9a93a93ccfe29f00b4b82ff',original)
sql(migration)
for state,requested,completed,expected_calls in [
    ('pending',12,11,0),('running',12,11,0),('ready',12,12,0),
    ('pending',0,0,1),('pending',12,12,1),('failed',12,11,1),
]:
    payload = dict(state=state,request_version=str(requested),completed_version=str(completed))
    sql("UPDATE fixture_status SET data='"+json.dumps(payload)+"'; UPDATE fixture_enqueue SET calls=0")
    assert json.loads(sql("SELECT public.lts_browser_product_v1()")) == payload
    assert int(sql('SELECT calls FROM fixture_enqueue')) == expected_calls
# Simulate the worker holding the row that a redundant enqueue would update.
sql("""UPDATE fixture_status SET data='{"state":"running","request_version":"21","completed_version":"20"}'""")
worker = subprocess.Popen(['psql','-XAtq','-v','ON_ERROR_STOP=1'],stdin=subprocess.PIPE,
                          stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
try:
    worker.stdin.write("BEGIN; SELECT calls FROM fixture_enqueue FOR UPDATE; SELECT 'locked';\n")
    worker.stdin.flush()
    assert worker.stdout.readline().strip() in ('0','1')
    assert worker.stdout.readline().strip() == 'locked'
    assert json.loads(sql("SET statement_timeout='500ms'; SELECT public.lts_browser_product_v1()"))['state']=='running'
finally:
    worker.communicate('ROLLBACK;\n',timeout=5)
print('Verified pending, running, ready, absent, stale and failed states, and a read during an independent worker lock.')
