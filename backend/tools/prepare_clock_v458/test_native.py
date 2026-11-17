from pathlib import Path
import subprocess, os, json, time
P=Path(__file__).resolve().parent
subprocess.run(['createdb','lts_prepare_clock_v458'],check=True)
cmd=['psql','-X','-d','lts_prepare_clock_v458','-At','-v','ON_ERROR_STOP=1']
def sql(s):
 return subprocess.check_output(cmd+['-c',s],text=True).strip()
def claim(): return json.loads(sql('select lts_product_refresh_private_v415.prepare(false)'))['claimed']
def reset(): sql('truncate lts_product_refresh_private_v415.queue')
sql((P/'setup.sql').read_text())
original=(P/'prepare-original.sql').read_text()
candidate=(P/'prepare-candidate.sql').read_text()
sql(original); reset(); assert not claim(); print('PASS original missed same-pass claim')
sql(candidate); reset(); assert claim(); print('PASS candidate immediate claim')
assert not claim(); print('PASS active lease preserved')
sql("update lts_product_refresh_private_v415.queue set state='pending',next_attempt_at=clock_timestamp()+interval '120 seconds'")
assert not claim(); print('PASS retry backoff')
sql("update lts_product_refresh_private_v415.queue set next_attempt_at=null,attempts=3")
assert not claim(); assert sql('select state from lts_product_refresh_private_v415.queue')=='failed'; print('PASS attempt budget')
sql("update lts_product_refresh_private_v415.queue set state='running',attempts=1,lease_expires_at=clock_timestamp()-interval '1 second'")
assert claim(); print('PASS expired lease')
# Two real sessions: hold exact per-owner advisory lock in A, claim in B.
sql("update lts_product_refresh_private_v415.queue set state='pending',next_attempt_at=null,attempts=0")
lock="begin; select pg_advisory_xact_lock(hashtextextended('00000000-0000-0000-0000-000000000001',415)); select pg_sleep(3); commit;"
p=subprocess.Popen(cmd+['-c',lock],stdout=subprocess.PIPE,text=True)
time.sleep(.5); assert not claim(); p.communicate(timeout=5); assert p.returncode==0
assert claim(); print('PASS native advisory contention skips, then claims after release')
# Two real sessions: row lock held by A; B respects SKIP LOCKED.
sql("update lts_product_refresh_private_v415.queue set state='pending',next_attempt_at=null,attempts=0")
p=subprocess.Popen(cmd+['-c',"begin; select user_id from lts_product_refresh_private_v415.queue for update; select pg_sleep(3); commit;"],stdout=subprocess.PIPE,text=True)
time.sleep(.5); assert not claim(); p.communicate(timeout=5); assert claim(); print('PASS native row lock skips, then claims after release')
sql('begin; '+original+'; rollback;'); assert 't:=clock_timestamp();\n FOR q' in sql("select pg_get_functiondef('lts_product_refresh_private_v415.prepare(boolean)'::regprocedure)"); print('PASS definition rollback atomic')
# Preserve ACL and attributes on CREATE OR REPLACE.
sql('DO $$ BEGIN CREATE ROLE service_role; EXCEPTION WHEN duplicate_object THEN NULL; END $$; revoke all on function lts_product_refresh_private_v415.prepare(boolean) from public; grant execute on function lts_product_refresh_private_v415.prepare(boolean) to service_role')
meta="select json_build_array(proowner,proacl::text,prosecdef,proconfig)::text from pg_proc where oid='lts_product_refresh_private_v415.prepare(boolean)'::regprocedure"
before=sql(meta); sql(candidate); assert sql(meta)==before; print('PASS owner ACL security and config unchanged')
sql(original); sql("update lts_product_refresh_private_v415.queue set state='ready'")
sql((P/'install.sql').read_text()); assert sql(meta)==before
sql((P/'rollback.sql').read_text()); assert sql(meta)==before
print('PASS guarded installation and rollback')
def rejects(s,expected):
 r=subprocess.run(cmd+['-c',s],text=True,capture_output=True)
 assert r.returncode and expected in r.stderr,r.stderr
sql("update lts_product_refresh_private_v415.queue set state='running'")
rejects((P/'install.sql').read_text(),'Active worker'); print('PASS installer rejects active worker')
sql("update lts_product_refresh_private_v415.queue set state='ready'"); sql(candidate)
rejects((P/'install.sql').read_text(),'Predecessor differs'); print('PASS installer rejects drift')
print('13 native tests passed; synthetic dependencies, not real browser acceptance')
