#!/usr/bin/env python3
"""Two-session lock test. DISPOSABLE localhost PG17 only; never production."""
from pathlib import Path
import argparse,hashlib,json,os,select,subprocess,time
p=argparse.ArgumentParser();p.add_argument('--coordinator-approved-synthetic-sql',action='store_true');p.add_argument('--port',type=int,default=55432);a=p.parse_args()
if not a.coordinator_approved_synthetic_sql or os.environ.get('Q26_DISPOSABLE_FIXTURE')!='I_CREATED_AN_EMPTY_LOCAL_PG17':raise SystemExit('Disposable fixture attestation required; synthetic PR159 execution is already authorized.')
if not 1024<=a.port<=65535:raise SystemExit('Invalid local fixture port')
setup=Path(__file__).with_name('pg17_envelope_lock_setup.sql')
if hashlib.sha256(setup.read_bytes()).hexdigest()!='90bce1b58944b544f88957a7496e0bb274f496d907906d0cbdeadae45b3b8552':raise SystemExit('Frozen setup hash mismatch')
env={'PATH':os.environ.get('PATH','/usr/bin:/bin'),'PGPASSWORD':'q26_local_disposable_only','PGCONNECT_TIMEOUT':'5','PGSSLMODE':'disable','PGAPPNAME':'q26_two_session_disposable'}
cmd=['psql','-X','--no-psqlrc','-q','-A','-t','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',str(a.port),'-U','postgres','-d','q26_synthetic_nominal_20261016']
created=subprocess.run(cmd+['-f',str(setup)],env=env,text=True,capture_output=True,timeout=60)
if created.returncode:raise SystemExit(created.stdout+created.stderr)
results=[]
for label,query in [('epoch',"PERFORM 1 FROM public.lts_read_cache_epoch_v242 WHERE singleton FOR UPDATE"),('nominal_source',"PERFORM 1 FROM public.lts_open_finance_staging WHERE id='22222222-2222-4222-8222-222222222222' FOR UPDATE")]:
 holder=subprocess.Popen(cmd,env=env,text=True,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,bufsize=1)
 try:
  holder.stdin.write("BEGIN; SET LOCAL ROLE q26_fixture_owner; DO $held$ BEGIN "+query+"; END $held$; SELECT 'LOCK_READY';\n");holder.stdin.flush()
  deadline=time.monotonic()+10;ready=False
  while time.monotonic()<deadline:
   if holder.poll() is not None:raise RuntimeError('Holder exited: '+holder.stderr.read())
   readable,_,_=select.select([holder.stdout],[],[],max(0,deadline-time.monotonic()))
   if readable and holder.stdout.readline().strip()=='LOCK_READY':ready=True;break
  if not ready:raise RuntimeError('Holder did not confirm exact row lock')
  statement="""BEGIN; SET LOCAL statement_timeout='15s'; SET LOCAL ROLE q26_fixture_owner;
 SELECT public.fixture_expect_failure(public.fixture_envelope('apply'),'lock timeout','two session __LABEL__ lock timeout');
 SELECT jsonb_build_object('label','__LABEL__','namespace_absent',to_regnamespace('lts_q26_private') IS NULL,'epoch',(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton),'decisions',(SELECT count(*) FROM public.lts_v178_review_decision));
 ROLLBACK;""".replace('__LABEL__',label)
  started=time.monotonic();attempt=subprocess.run(cmd+['-c',statement],env=env,text=True,capture_output=True,timeout=25);elapsed=time.monotonic()-started
  if attempt.returncode:raise RuntimeError(attempt.stdout+attempt.stderr)
  payloads=[json.loads(line) for line in attempt.stdout.splitlines() if line.strip().startswith('{')]
  if len(payloads)!=1 or payloads[0].get('namespace_absent') is not True or payloads[0].get('epoch')!=100 or payloads[0].get('decisions')!=1:raise RuntimeError('Atomic state after timeout mismatch: '+attempt.stdout)
  if not 1.5<=elapsed<=15:raise RuntimeError('Unexpected measured lock wait: '+str(elapsed))
  results.append(dict(label=label,elapsed_seconds=round(elapsed,3),lock_timeout_observed=True,atomic_state_preserved=True))
 finally:
  if holder.poll() is None:
   holder.stdin.write('ROLLBACK;\n');holder.stdin.close();holder.wait(timeout=5)
print(json.dumps(dict(two_session_checks_passed=len(results),results=results,external_apply_migration_timer_proved=False,cleanup='Dedicated disposable instance must be discarded by its CI owner after this test.'),indent=2))
