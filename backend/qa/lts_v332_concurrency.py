"""Native PostgreSQL fixtures for best-effort derived memo writes, not a restore."""
from pathlib import Path
import json,os,subprocess,time

ROOT=Path(__file__).resolve().parents[2]
assert os.environ.get('PGHOST') in ('localhost','127.0.0.1'), 'Local fixture database only'
env=dict(os.environ,PGDATABASE='lts_v332_fixture')
def sql(text,ok=True):
    p=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1'],input='\\set VERBOSITY verbose\n'+text,text=True,capture_output=True,env=env)
    if ok and p.returncode:raise AssertionError(p.stderr)
    if not ok:assert p.returncode,p.stdout
    return p.stdout.strip() if ok else p.stderr

subprocess.run(['createdb','lts_v332_fixture'],check=True,capture_output=True)
U='00000000-0000-4000-8000-000000000332'
OTHER='00000000-0000-4000-8000-000000000333'
sql("""
DO $$BEGIN CREATE ROLE anon;EXCEPTION WHEN duplicate_object THEN NULL;END$$;
DO $$BEGIN CREATE ROLE authenticated;EXCEPTION WHEN duplicate_object THEN NULL;END$$;
DO $$BEGIN CREATE ROLE service_role;EXCEPTION WHEN duplicate_object THEN NULL;END$$;
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY,epoch bigint);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);
CREATE TABLE public.lts_v229_read_cache(user_id uuid NOT NULL,kind text,as_of date,from_date date,to_date date,payload jsonb,refreshed_at timestamptz,source_fingerprint text,
 PRIMARY KEY(user_id,kind,as_of,from_date,to_date));
CREATE TABLE public.financial_events(id integer PRIMARY KEY,amount numeric);
CREATE TABLE public.source_documents(id integer PRIMARY KEY,content text);
INSERT INTO public.financial_events VALUES(1,17.23),(2,-4.56);
INSERT INTO public.source_documents VALUES(1,'original fixture document');
CREATE FUNCTION public.lts_operational_source_key_pre_v242(p_user_id uuid) RETURNS text LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF current_setting('fixture.epoch_drift',true)='on' THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1;END IF;
 RETURN md5(p_user_id::text||(SELECT epoch::text FROM public.lts_read_cache_epoch_v242 WHERE singleton));
END$$;
""")
old=(ROOT/'backend/qa/v332_operational_key_previous.sql').read_text()
patch=(ROOT/'backend/patches/v332/opportunistic_operational_memo.sql').read_text()
sql(old+"REVOKE ALL ON FUNCTION public.lts_operational_source_key_v238(uuid) FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION public.lts_operational_source_key_v238(uuid) TO service_role;")
attributes="SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE oid='public.lts_operational_source_key_v238(uuid)'::regprocedure;"
before_attrs=sql(attributes)
finger="SELECT jsonb_build_object('events',(SELECT md5(jsonb_agg(t ORDER BY id)::text) FROM public.financial_events t),'documents',(SELECT md5(jsonb_agg(t ORDER BY id)::text) FROM public.source_documents t));"
before_data=sql(finger)
key=f"SELECT public.lts_operational_source_key_v238('{U}');"
expected=sql(f"SELECT md5('{U}'||(SELECT epoch::text FROM public.lts_read_cache_epoch_v242 WHERE singleton));")
reset="DELETE FROM public.lts_v229_read_cache;"
stale=f"INSERT INTO public.lts_v229_read_cache VALUES('{U}','operational_key_v242',current_date,current_date,current_date,'{{\"value\":\"stale\"}}',now(),'stale');"

def locker(tag,body):
    proc=subprocess.Popen(['psql','-X','-qAt','-v','ON_ERROR_STOP=1'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env=env)
    proc.stdin.write(f"SET application_name='{tag}';BEGIN;{body}SELECT pg_sleep(4);ROLLBACK;");proc.stdin.close()
    deadline=time.monotonic()+3
    while time.monotonic()<deadline:
        if sql(f"SELECT count(*) FROM pg_stat_activity WHERE application_name='{tag}' AND wait_event='PgSleep';")=='1':return proc
        time.sleep(.02)
    raise AssertionError('Locker did not reach its hold point')
def release(proc):
    proc.wait(timeout=6)
    assert proc.returncode==0,proc.stderr.read()
def still_holding(tag):
    assert sql(f"SELECT count(*) FROM pg_stat_activity WHERE application_name='{tag}' AND wait_event='PgSleep';")=='1','Reader waited for the locker to finish'

sql(reset+stale)
held=locker('v332_previous',f"UPDATE public.lts_v229_read_cache SET refreshed_at=now() WHERE user_id='{U}';")
error=sql("SET lock_timeout='200ms';"+key,False)
assert '55P03' in error,error
release(held)

sql(patch)
assert sql(attributes)==before_attrs
assert sql(finger)==before_data
measurements=[]
for limit in ('0','20ms','2s'):
    sql(reset+stale)
    held=locker('v332_row_lock',f"UPDATE public.lts_v229_read_cache SET refreshed_at=now() WHERE user_id='{U}';")
    started=time.monotonic()
    result=sql(f"BEGIN;SET LOCAL lock_timeout='{limit}';"+key+"SHOW lock_timeout;ROLLBACK;").splitlines()
    elapsed=(time.monotonic()-started)*1000
    assert result==[expected,limit],result
    still_holding('v332_row_lock')
    measurements.append({'caller_lock_timeout':limit,'elapsed_ms':round(elapsed,2)})
    release(held)

sql(reset)
held=locker('v332_cooperating',key)
started=time.monotonic()
assert sql(key)==expected
still_holding('v332_cooperating')
measurements.append({'cooperating_reader_ms':round((time.monotonic()-started)*1000,2)})
assert sql(f"SELECT public.lts_operational_source_key_v238('{OTHER}');")!=expected
release(held)
assert sql(key)==expected
assert sql(f"SELECT payload->>'value' FROM public.lts_v229_read_cache WHERE user_id='{U}';")==expected
cached=sql('SELECT jsonb_agg(t ORDER BY user_id) FROM public.lts_v229_read_cache t;')
assert sql(key)==expected
assert sql('SELECT jsonb_agg(t ORDER BY user_id) FROM public.lts_v229_read_cache t;')==cached,'A cache hit rewrote the row'

sql(reset)
assert sql('BEGIN READ ONLY;'+key+'ROLLBACK;')==expected
assert sql('SELECT count(*) FROM public.lts_v229_read_cache;')=='0'
assert '40001' in sql("SET fixture.epoch_drift='on';"+key,False)
assert sql('SELECT epoch FROM public.lts_read_cache_epoch_v242;')=='1'
sql("ALTER TABLE public.lts_v229_read_cache ADD CONSTRAINT fixture_write_error CHECK(source_fingerprint='deliberately-impossible');")
assert '23514' in sql(key,False),'Unrelated write failures must not be masked'
sql('ALTER TABLE public.lts_v229_read_cache DROP CONSTRAINT fixture_write_error;')

definition=sql("SELECT pg_get_functiondef('public.lts_operational_source_key_v238(uuid)'::regprocedure);")
sql(patch)
assert sql("SELECT pg_get_functiondef('public.lts_operational_source_key_v238(uuid)'::regprocedure);")==definition
assert sql(attributes)==before_attrs
assert sql("SELECT has_function_privilege('anon','public.lts_operational_source_key_v238(uuid)','EXECUTE'),has_function_privilege('authenticated','public.lts_operational_source_key_v238(uuid)','EXECUTE');")=='f|f'
assert sql(finger)==before_data
sql(definition.replace('\n RETURN result;','\n -- fixture definition drift\n RETURN result;',1))
assert 'Operational key definition changed' in sql(patch,False)
result={'passed':True,'engine':'PostgreSQL native','previous_timeout_reproduced':True,'contended_read_returns_computed_key':True,'caller_timeouts_preserved':True,'read_only_supported':True,'source_drift_rejected':True,'unrelated_errors_propagate':True,'replay_exact':True,'attributes_grants_and_financial_fixtures_exact':True,'measurements':measurements,'production_session':False,'source_worker':'bounded deterministic fixture'}
qa=ROOT/'qa/v332';qa.mkdir(parents=True,exist_ok=True)
(qa/'concurrency-result.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result))
