"""Two real PostgreSQL sessions; synthetic identities only."""
import json,os,subprocess

UID='11111111-1111-4111-8111-111111111111'
def query(sql):
 return subprocess.run(['psql','-XAt','-v','ON_ERROR_STOP=1','-c',sql],text=True,capture_output=True,check=True).stdout.strip()
def holder(shared=False):
 mode='pg_advisory_xact_lock_shared'if shared else'pg_advisory_xact_lock'
 p=subprocess.Popen(['psql','-XAt','-v','ON_ERROR_STOP=1'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
 p.stdin.write(f"BEGIN;SELECT {mode}(hashtextextended('lts-maintenance-v403:{UID}',0));SELECT 'READY';\n");p.stdin.flush()
 while p.stdout.readline().strip()!='READY':
  if p.poll()is not None:raise RuntimeError('lock holder failed')
 return p
def release(p):
 p.stdin.write('ROLLBACK;\n');p.stdin.close();p.wait(timeout=5);assert p.returncode==0

query('TRUNCATE public.lts_backup_supplement_v380;')
p=holder(True)
try:
 r=json.loads(query(f"select public.lts_backup_scheduled_v403('{UID}');"));assert r['deferred'] and not r['ok'];assert query('select count(*)from public.lts_backup_supplement_v380')=='0'
finally:release(p)
p=holder(False)
try:
 r=json.loads(query("select public.lts_open_finance_enqueue_bank_v1('341','sync');"));assert r['deferred'];assert query('select count(*)from public.qa_http_requests')=='0'
 for fn,args in [('lts_open_finance_begin_itau_v1',f"'{UID}','bad','{{}}','aaaaaaaa-aaaa-4aaa-8aaa-000000009999'"),('lts_open_finance_begin_bank_v1',f"'{UID}','bad','{{}}','aaaaaaaa-aaaa-4aaa-8aaa-000000009999','237','Synthetic'")]:
  r=subprocess.run(['psql','-XAt','-v','ON_ERROR_STOP=1','-c',f'select public.{fn}({args});'],text=True,capture_output=True)
  assert r.returncode!=0 and 'BACKUP_IN_PROGRESS_RETRY_LATER'in r.stderr
finally:release(p)
query(f"INSERT INTO public.lts_open_finance_sync_run(id,user_id,connection_id,status)VALUES('aaaaaaaa-aaaa-4aaa-8aaa-000000009999','{UID}','33333333-3333-4333-8333-333333333333','running');")
r=json.loads(query(f"select public.lts_backup_scheduled_v403('{UID}');"));assert r['reason']=='active_or_queued_sync'
query("UPDATE public.lts_open_finance_sync_run SET status='failed',finished_at=clock_timestamp()WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-000000009999';")
r=json.loads(query(f"select public.lts_backup_scheduled_v403('{UID}');"));assert r['inserted'] and r['exclusion_guard']
r=json.loads(query(f"select public.lts_backup_scheduled_v403('{UID}');"));assert r['already_complete'] and not r['inserted']
print(json.dumps({'concurrency_checks':7,'sync_transaction_defers_backup':True,'backup_defers_enqueue_without_http':True,'both_begin_routes_blocked':True,'running_run_defers_backup':True,'completed_capture_not_repeated':True}))
