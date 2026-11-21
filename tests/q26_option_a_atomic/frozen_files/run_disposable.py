#!/usr/bin/env python3
"""PG17 disposable fixture runner. No production lease, remote upload or deployment."""
import os,sys,subprocess,json,time,re,hashlib
from pathlib import Path
D=Path(__file__).resolve().parent;OUT=D/'results'
for k in ('PGHOSTADDR','PGSERVICE','PGSERVICEFILE','PGSYSCONFDIR','PGOPTIONS','DATABASE_URL','SUPABASE_DB_URL','SUPABASE_URL','SUPABASE_SERVICE_ROLE_KEY'):
 if os.environ.get(k):raise SystemExit('refused external connection/config variable: '+k)
if os.environ.get('OPTION_A_SYNTHETIC_DISPOSABLE')!='YES':raise SystemExit('explicit disposable opt-in required')
if os.environ.get('PGHOST') not in ('127.0.0.1','localhost'):raise SystemExit('loopback host required')
if not re.fullmatch(r'[0-9]{1,5}',os.environ.get('PGPORT','')) or not 1<=int(os.environ['PGPORT'])<=65535:raise SystemExit('explicit port required')
if not re.fullmatch(r'fixture_option_a_atomic_[a-z0-9_]+',os.environ.get('PGDATABASE','')):raise SystemExit('dedicated fixture database required')
if not re.fullmatch(r'[a-z_][a-z0-9_]*',os.environ.get('PGUSER','')):raise SystemExit('explicit database user required')
manifest=json.loads((D/'PUBLIC_MANIFEST.json').read_text())
for f in manifest['files']:
 p=D/f['name'];b=p.read_bytes()
 if hashlib.sha256(b).hexdigest()!=f['sha256'] or len(b)!=f['bytes']:raise SystemExit('manifest mismatch: '+f['name'])
OUT.mkdir(exist_ok=True)
BASE=['psql','-X','--no-psqlrc','-v','ON_ERROR_STOP=1','-A','-t','-h',os.environ['PGHOST'],'-p',os.environ['PGPORT'],'-U',os.environ['PGUSER'],'-d',os.environ['PGDATABASE']]
PREFIX="SET ROLE fixture_owner;SET search_path=pg_catalog,public;SET TimeZone='UTC';SET statement_timeout='30s';SET fixture.uid='11111111-1111-4111-8111-111111111111';SET fixture.email='owner@example.invalid';"
def call(sql,owner=True,ok=True,timeout=40):
 r=subprocess.run(BASE,input=(PREFIX if owner else '')+sql,text=True,capture_output=True,timeout=timeout)
 if ok and r.returncode:raise RuntimeError('psql failed: '+r.stderr)
 return r
def value(sql,owner=True):
 r=call(sql,owner=owner);ls=[x for x in r.stdout.splitlines() if x.startswith('{') or x.startswith('[')]
 if not ls:raise RuntimeError('missing JSON result')
 return json.loads(ls[-1])
def spawn(sql,name):
 p=subprocess.Popen(BASE,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
 p.stdin.write("SET application_name='"+name+"';"+PREFIX+sql);p.stdin.close();p.stdin=None
 return p
def finish(p,ok=True):
 out,err=p.communicate(timeout=40)
 if ok and p.returncode:raise RuntimeError('worker failed: '+err)
 return {'returncode':p.returncode,'stdout':out,'stderr':err}
def wait_lock(name,relation,granted=True):
 end=time.monotonic()+10
 while time.monotonic()<end:
  j=value("SELECT jsonb_build_object('present',EXISTS(SELECT 1 FROM pg_locks l JOIN pg_stat_activity a ON a.pid=l.pid WHERE a.application_name='"+name+"' AND l.relation='public."+relation+"'::regclass AND l.granted="+str(granted).lower()+(" AND a.wait_event='PgSleep'" if granted else "")+"));",owner=False)
  if j['present']:return
  time.sleep(.02)
 raise RuntimeError('lock barrier not observed: '+name)
def reset():call('SELECT public.fixture_atomic_reset();')
labels=[];workers=[];committed=False;result_record=None;cleanup_verified=False
expected=json.loads((D/'EXPECTED_RESULTS.json').read_text())
try:
 # Guard-only contraproofs create an object inside a transaction and must reject setup.
 # Each connection closes on the expected error, rolling its own fixture object back.
 guard=(D/'empty_instance_guard.sql').read_text()
 empty_guard_results=[]
 for name,ddl in [
  ('standalone function',"CREATE FUNCTION public.preexisting_fixture_function() RETURNS integer LANGUAGE sql AS 'SELECT 1';"),
  ('standalone sequence','CREATE SEQUENCE public.preexisting_fixture_sequence;'),
  ('standalone enum',"CREATE TYPE public.preexisting_fixture_enum AS ENUM ('synthetic');"),
  ('standalone domain','CREATE DOMAIN public.preexisting_fixture_domain AS integer;')]:
  rr=call('BEGIN;'+ddl+guard+'ROLLBACK;',owner=False,ok=False)
  assert rr.returncode and 'public contains preexisting objects' in rr.stderr
  empty_guard_results.append(name)
 (OUT/'empty-instance-guard.json').write_text(json.dumps({'rejected_before_setup':empty_guard_results,'count':len(empty_guard_results)},indent=2)+'\n')
 # Entire setup and functional suite are one transaction with ROLLBACK.
 r=subprocess.run(BASE+['-f',str(D/'atomic_setup.sql'),'-f',str(D/'atomic_functional.sql')],text=True,capture_output=True,timeout=180)
 (OUT/'functional.log').write_text(r.stdout);(OUT/'functional.stderr').write_text(r.stderr)
 if r.returncode:raise RuntimeError('functional gate failed; inspect functional.stderr')
 rows=[json.loads(s) for s in r.stdout.splitlines() if s.startswith('{')]
 result=next(x for x in rows if x.get('kind')=='atomic_functional_results')
 if result['count']!=expected['functional_count'] or result['labels']!=expected['functional_labels']:raise RuntimeError('functional labels/count mismatch')
 compiled=next(x for x in rows if x.get('kind')=='compiled_definitions');(OUT/'compiled-definitions.json').write_text(json.dumps(compiled,indent=2)+'\n')
 empty=call("SELECT jsonb_build_object('tables',(SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind IN('r','p','v','m','f')),'auth',to_regnamespace('auth') IS NOT NULL,'fixture_roles',(SELECT count(*) FROM pg_roles WHERE rolname IN('fixture_owner','service_role','anon','authenticated')));",owner=False)
 ej=json.loads(next(s for s in empty.stdout.splitlines() if s.startswith('{')))
 if ej!={'tables':0,'auth':False,'fixture_roles':0}:raise RuntimeError('functional rollback left objects')
 # Multi-session gate necessarily commits only the disposable setup and then removes it.
 setup=(D/'atomic_setup.sql').read_text()+'\nCOMMIT;\n'
 rr=call(setup,owner=False,timeout=180);committed=True
 (OUT/'concurrency-setup.log').write_text(rr.stdout)
 # Ordering 1: independent different-ID insert commits before apply acquires evidence lock.
 reset();before=value('SELECT public.fixture_atomic_snapshot();')
 p=spawn("BEGIN;SELECT public.fixture_atomic_competitor();SELECT pg_sleep(1.2);COMMIT;",'atomic_competitor_first');workers.append(p)
 wait_lock('atomic_competitor_first','lts_reconciliation_evidence')
 rr=call("SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));",ok=False)
 finish(p);assert rr.returncode and ('partial' in rr.stderr or 'conflicting' in rr.stderr)
 labels.append('competitor first apply rejected')
 after=value('SELECT public.fixture_atomic_snapshot();')
 assert len(after['lts_reconciliation_evidence'])==1 and after['lts_reconciliation_evidence'][0]['id']=='66666666-6666-4666-8666-666666666666'
 assert after['lts_access_audit']==[] and after['lts_v178_review_decision']==before['lts_v178_review_decision'] and after['lts_open_finance_staging']==before['lts_open_finance_staging'] and after['catalog']==before['catalog'] and after['lts_read_cache_epoch_v242'][0]['epoch']==101
 labels.append('competitor first preserves committed edit')
 # Ordering 2: apply holds the table lock; competing insert waits, then remains legal after commit.
 reset();original=value('SELECT public.fixture_capture();')
 p=spawn("BEGIN;SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));SELECT pg_sleep(1.5);COMMIT;",'atomic_apply_first');workers.append(p)
 wait_lock('atomic_apply_first','lts_reconciliation_evidence')
 q=spawn('SELECT public.fixture_atomic_competitor();','atomic_insert_waiter');workers.append(q)
 wait_lock('atomic_insert_waiter','lts_reconciliation_evidence',False)
 labels.append('apply first blocks competing insert')
 finish(p);finish(q)
 assert value('SELECT public.fixture_capture();')==original
 post=value('SELECT public.fixture_atomic_snapshot();');assert len(post['lts_reconciliation_evidence'])==2 and post['lts_read_cache_epoch_v242'][0]['epoch']==103
 labels.append('postcommit competitor allowed and consumers conservative')
 # Rollback holds the same evidence lock. A competing writer has an independent short lock timeout.
 reset();call("SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));")
 p=spawn("BEGIN;SELECT public.fixture_atomic_exec('rollback',public.fixture_atomic_lease('rollback'));SELECT pg_sleep(1.0);COMMIT;",'atomic_rollback_holder');workers.append(p)
 wait_lock('atomic_rollback_holder','lts_reconciliation_evidence')
 rr=call("SET lock_timeout='200ms';SELECT public.fixture_atomic_competitor();",ok=False)
 assert rr.returncode and 'lock timeout' in rr.stderr;finish(p)
 labels.append('rollback competing insert lock timeout')
 # Receipt row is protected even while rollback waits for the global epoch row.
 reset();call("SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));")
 receipt_before=value("SELECT to_jsonb(a) FROM public.lts_access_audit a WHERE action='option_a_nominal_apply_v1';")
 p=spawn("BEGIN;SELECT 1 FROM public.lts_read_cache_epoch_v242 WHERE singleton FOR UPDATE;SELECT pg_sleep(1.5);ROLLBACK;",'atomic_audit_epoch_holder');workers.append(p)
 wait_lock('atomic_audit_epoch_holder','lts_read_cache_epoch_v242')
 q=spawn("SELECT public.fixture_atomic_exec('rollback',public.fixture_atomic_lease('rollback'));",'atomic_receipt_protected');workers.append(q)
 deadline=time.monotonic()+10
 while True:
  waiting=value("SELECT jsonb_build_object('waiting',EXISTS(SELECT 1 FROM pg_stat_activity a WHERE a.application_name='atomic_receipt_protected' AND a.wait_event_type='Lock' AND EXISTS(SELECT 1 FROM pg_locks l WHERE l.pid=a.pid AND l.relation='public.lts_access_audit'::regclass AND l.granted)));",owner=False)
  if waiting['waiting']:break
  if time.monotonic()>deadline:raise RuntimeError('receipt-lock/epoch-wait barrier absent')
  time.sleep(.02)
 rr=call("SET lock_timeout='200ms';UPDATE public.lts_access_audit SET meta=meta||'{\"concurrent_edit\":true}' WHERE action='option_a_nominal_apply_v1';",ok=False)
 assert rr.returncode and 'lock timeout' in rr.stderr
 finish(p);finish(q)
 assert value("SELECT to_jsonb(a) FROM public.lts_access_audit a WHERE action='option_a_nominal_apply_v1';")==receipt_before
 labels.append('rollback receipt CAS protected while epoch wait')
 # Expiry after a table-lock wait and immediately before mutation after an epoch-row wait.
 for kind,rel,holder_sql,label in [
  ('apply','lts_reconciliation_evidence','LOCK TABLE public.lts_reconciliation_evidence IN SHARE ROW EXCLUSIVE MODE;','expiry after evidence lock wait apply'),
  ('rollback','lts_reconciliation_evidence','LOCK TABLE public.lts_reconciliation_evidence IN SHARE ROW EXCLUSIVE MODE;','expiry after evidence lock wait rollback'),
  ('apply','lts_read_cache_epoch_v242','SELECT 1 FROM public.lts_read_cache_epoch_v242 WHERE singleton FOR UPDATE;','expiry at epoch lock boundary apply'),
  ('rollback','lts_read_cache_epoch_v242','SELECT 1 FROM public.lts_read_cache_epoch_v242 WHERE singleton FOR UPDATE;','expiry at epoch lock boundary rollback')]:
  reset()
  if kind=='rollback':call("SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));")
  before=value('SELECT public.fixture_atomic_snapshot();')
  p=spawn('BEGIN;'+holder_sql+'SELECT pg_sleep(1.0);ROLLBACK;','atomic_expiry_holder');workers.append(p);wait_lock('atomic_expiry_holder',rel)
  rr=call("SELECT public.fixture_atomic_exec('"+kind+"',jsonb_set(public.fixture_atomic_lease('"+kind+"'),'{expires_at}',to_jsonb(clock_timestamp()+interval '250 milliseconds')));",ok=False)
  finish(p);assert rr.returncode and 'lease expired' in rr.stderr
  assert value('SELECT public.fixture_atomic_snapshot();')==before;labels.append(label)
 assert sorted(labels)==sorted(expected['concurrency_labels'])
 result_record={'postgres':value("SELECT jsonb_build_object('version',version(),'version_num',current_setting('server_version_num'));") ,'functional_count':result['count'],'functional_labels':result['labels'],'concurrency_count':len(labels),'concurrency_labels':labels,'functional_rollback_empty':ej,'empty_instance_guard_count':len(empty_guard_results),'scope':'same DO controls under declared synthetic bindings; full consumers with declared ancestors; no production lease or external timer proof'}
finally:
 for p in workers:
  if p.poll() is None:p.terminate();p.wait(timeout=10)
 if committed:
  # This runner accepted only an initially empty, explicitly named loopback disposable database.
  call("DROP SCHEMA public CASCADE;DROP SCHEMA auth CASCADE;CREATE SCHEMA public;DROP ROLE fixture_owner,service_role,anon,authenticated;",owner=False)
  clean=call("SELECT jsonb_build_object('remaining_relations',(SELECT count(*) FROM pg_class WHERE relnamespace=to_regnamespace('public')),'remaining_functions',(SELECT count(*) FROM pg_proc WHERE pronamespace=to_regnamespace('public')),'remaining_types',(SELECT count(*) FROM pg_type WHERE typnamespace=to_regnamespace('public')),'remaining_namespace_dependencies',(SELECT count(*) FROM pg_depend WHERE refclassid='pg_namespace'::regclass AND refobjid=to_regnamespace('public')),'auth',to_regnamespace('auth') IS NOT NULL,'fixture_roles',(SELECT count(*) FROM pg_roles WHERE rolname IN('fixture_owner','service_role','anon','authenticated')));",owner=False)
  cleanup_result=json.loads(next(x for x in clean.stdout.splitlines() if x.startswith('{')))
  cleanup_expected={'remaining_relations':0,'remaining_functions':0,'remaining_types':0,'remaining_namespace_dependencies':0,'auth':False,'fixture_roles':0}
  cleanup_verified=cleanup_result==cleanup_expected
  (OUT/'cleanup.json').write_text(json.dumps({'actual':cleanup_result,'expected':cleanup_expected,'verified':cleanup_verified},indent=2)+'\n')
  if not cleanup_verified:raise RuntimeError('disposable cleanup equality failed; no successful result emitted')
if result_record is None or not cleanup_verified:raise RuntimeError('no verified completion')
result_record['cleanup_verified']=True
(OUT/'result.json').write_text(json.dumps(result_record,indent=2)+'\n')
print('functional',expected['functional_count'],'concurrency',len(labels),'PASS; disposable objects removed')
