from pathlib import Path
import hashlib
p=Path(__file__).parent
original=(p/'prepare-original.sql').read_text().rstrip()+'\n'
candidate=(p/'prepare-candidate.sql').read_text().rstrip()+'\n'
# pg_get_functiondef includes exactly one trailing newline.
for name,before,after in [('install',original,candidate),('rollback',candidate,original)]:
 h=hashlib.md5(before.encode()).hexdigest()
 sql=f'''DO $guard$
DECLARE old_def text; old_meta jsonb; new_meta jsonb; u uuid;
BEGIN
 PERFORM set_config('lock_timeout','1s',true);
 LOCK TABLE lts_product_refresh_private_v415.queue IN ACCESS EXCLUSIVE MODE NOWAIT;
 IF EXISTS(SELECT 1 FROM lts_product_refresh_private_v415.queue WHERE state='running') THEN
  RAISE EXCEPTION 'Active worker; no change';
 END IF;
 FOR u IN SELECT user_id FROM lts_product_refresh_private_v415.queue LOOP
  IF NOT pg_try_advisory_xact_lock(hashtextextended(u::text,415)) THEN RAISE EXCEPTION 'Worker lock busy; no change'; END IF;
 END LOOP;
 SELECT pg_get_functiondef(oid),jsonb_build_array(proowner,proacl::text,prosecdef,proconfig) INTO old_def,old_meta FROM pg_proc WHERE oid='lts_product_refresh_private_v415.prepare(boolean)'::regprocedure;
 IF md5(old_def)<>'{h}' THEN RAISE EXCEPTION 'Predecessor differs; no change'; END IF;
 EXECUTE $replacement${after}$replacement$;
 SELECT jsonb_build_array(proowner,proacl::text,prosecdef,proconfig) INTO new_meta FROM pg_proc WHERE oid='lts_product_refresh_private_v415.prepare(boolean)'::regprocedure;
 IF new_meta IS DISTINCT FROM old_meta THEN RAISE EXCEPTION 'Security metadata changed'; END IF;
END $guard$;
'''
 (p/(name+'.sql')).write_text(sql)
 print(name,h)
