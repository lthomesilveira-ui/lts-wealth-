#!/usr/bin/env python3
"""Run only allowlisted synthetic SQL on an explicitly opted-in fresh loopback PostgreSQL17 cluster."""
from __future__ import annotations
import argparse, hashlib, json, os, select, subprocess, sys, time
from pathlib import Path
HERE=Path(__file__).resolve().parent; GEN=HERE/'generated'
DB='wealth_synthetic_classifications'
REPORT={'status':'not-run','database_tests_executed':False,'production_validated':False,'tests':[]}
RESULT=None

def lit(v):return "'"+str(v).replace("'","''")+"'"
def main():
 global RESULT
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--allow-fresh-synthetic-postgres17',action='store_true')
 p.add_argument('--port',type=int,default=5432)
 p.add_argument('--results-dir',type=Path,default=HERE/'results')
 args=p.parse_args()
 if not args.allow_fresh_synthetic_postgres17:p.error('Explicit disposable-cluster opt-in required; no database was contacted')
 if not 1024<=args.port<=65535:p.error('Only unprivileged loopback ports are accepted')
 RESULT=args.results_dir/'result.json'
 env=dict(PATH=os.environ.get('PATH','/usr/bin:/bin'),LANG='C.UTF-8',PGHOST='127.0.0.1',PGPORT=str(args.port),PGDATABASE=DB,PGUSER=DB,PGPASSWORD='synthetic-ci-only',PGCONNECT_TIMEOUT='5',PSQLRC='/dev/null',PGAPPNAME='synthetic-classification-gate')
 command=['psql','-X','-q','-A','-t','--set=ON_ERROR_STOP=1']
 def sql(text,expect=None):
  r=subprocess.run(command,input=text,env=env,text=True,capture_output=True,timeout=90)
  if expect is not None:
   if r.returncode==0 or expect not in r.stderr:raise AssertionError(f'Expected {expect!r}; code={r.returncode}; {r.stderr}')
  elif r.returncode:raise RuntimeError(r.stderr)
  return r.stdout.strip()
 def query(text):return json.loads(sql(text))
 manifest=json.loads((GEN/'manifest.json').read_text()); fixture=json.loads((GEN/'fixtures-synthetic.json').read_text())
 if not manifest['synthetic_only'] or manifest['database_tests_executed']:raise AssertionError('Only pinned synthetic templates accepted')
 for n,h in manifest['files'].items():
  if hashlib.sha256((GEN/n).read_bytes()).hexdigest()!=h:raise AssertionError('Hash mismatch: '+n)
 pre=query("SELECT jsonb_build_object('version',current_setting('server_version_num')::int,'database',current_database(),'user',current_user,'superuser',(SELECT rolsuper FROM pg_roles WHERE rolname=current_user),'objects',(SELECT count(*) FROM pg_class WHERE relnamespace='public'::regnamespace),'functions',(SELECT count(*) FROM pg_proc WHERE pronamespace='public'::regnamespace));")
 if not(170000<=pre['version']<180000 and pre['database']==DB and pre['user']==DB and pre['superuser'] and pre['objects']==0 and pre['functions']==0):raise RuntimeError('Fresh dedicated PostgreSQL17 required: '+json.dumps(pre))
 REPORT['database_tests_executed']=True
 sql((GEN/'bootstrap-synthetic.sql').read_text())
 sql("""CREATE FUNCTION public.fixture_side_effect() RETURNS trigger LANGUAGE plpgsql AS $f$ BEGIN
 IF EXISTS(SELECT 1 FROM new_rows WHERE source_table='lts_open_finance_staging') THEN
 IF current_setting('fixture.mutate_source',true)='on' THEN UPDATE public.lts_open_finance_staging SET raw_hash='synthetic-mutated-after-write' WHERE id='11111111-1111-4111-8111-000000000001'; END IF;
 IF current_setting('fixture.mutate_origin',true)='on' THEN UPDATE public.lts_v178_review_decision SET decision_basis='synthetic-mutated-origin' WHERE source_table='synthetic_document'; END IF;
 IF current_setting('fixture.mutate_hidden',true)='on' THEN INSERT INTO public.lts_v178_review_decision VALUES('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','synthetic_hidden','hidden',NULL,NULL,'hidden','synthetic',now()); END IF;
 END IF; RETURN NULL; END $f$;
 CREATE TRIGGER fixture_side_effect AFTER INSERT ON public.lts_v178_review_decision REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION public.fixture_side_effect();""")
 measured={sig:sql('SELECT md5(pg_get_functiondef('+lit('public.'+sig)+'::regprocedure));') for sig in fixture['leases']}
 today=sql("SELECT (now() AT TIME ZONE 'America/Sao_Paulo')::date;")
 def parameterize(name):
  s=(GEN/name).read_text()
  for sig,h in fixture['leases'].items():
   if s.count(lit(h))!=2:raise AssertionError('Expected two complete lease literal placeholders: '+sig)
   s=s.replace(lit(h),lit(measured[sig]))
  if name.startswith('apply'):
   if s.count("current_date <> date '2099-01-01'")!=1:raise AssertionError('Expiry placeholder not unique')
   s=s.replace("current_date <> date '2099-01-01'","current_date <> date "+lit(today))
  return s
 apply=parameterize('apply-synthetic.sql');rollback=parameterize('rollback-synthetic.sql')
 reset_text=(GEN/'reset-synthetic.sql').read_text()
 def reset():sql(reset_text)
 snap_sql="""SELECT jsonb_build_object(
 'decisions',(SELECT coalesce(jsonb_agg(to_jsonb(d) ORDER BY user_id,source_table,source_ref),'[]') FROM public.lts_v178_review_decision d),
 'audit',(SELECT coalesce(jsonb_agg(to_jsonb(a) ORDER BY id),'[]') FROM public.lts_access_audit a),
 'staging',(SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY id),'[]') FROM public.lts_open_finance_staging s),
 'expenses',(SELECT jsonb_agg(to_jsonb(e) ORDER BY id) FROM public.fixture_expense e),
 'epoch',(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton),
 'cache',(SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY user_id,cache_key),'[]') FROM public.lts_v229_read_cache c));"""
 def snap():return query(snap_sql)
 def add(name,**details):REPORT['tests'].append(dict(case=name,passed=True,**details))
 def reject(name,statement,error,setup='',restore=''):
  reset()
  if setup:sql(setup)
  before=snap();sql(statement,expect=error)
  if snap()!=before:raise AssertionError(name+' did not restore exact transactional pre-attempt state')
  if restore:sql(restore)
  add(name,expected_rejection=error)
 reset()
 # The original fixture used January 2000 -03 while Sao Paulo was on DST -02.
 # Prove the database's real JSON serialization before any application is attempted.
 timestamp_proof=query("SET TIME ZONE 'America/Sao_Paulo'; SELECT jsonb_build_object('old_serialized',to_jsonb('2000-01-01T00:00:00-03:00'::timestamptz),'winter_serialized',to_jsonb('2000-07-01T00:00:00-03:00'::timestamptz));")
 if timestamp_proof!={'old_serialized':'2000-01-01T01:00:00-02:00','winter_serialized':'2000-07-01T00:00:00-03:00'}:raise AssertionError('Unexpected historical timezone serialization: '+json.dumps(timestamp_proof))
 actual_origins=query("SET TIME ZONE 'America/Sao_Paulo'; SELECT jsonb_agg(to_jsonb(d) ORDER BY source_ref) FROM public.lts_v178_review_decision d WHERE source_table='synthetic_document';")
 expected_origins=sorted([t['origin_decision'] for t in fixture['targets'] if t['origin_decision']],key=lambda d:d['source_ref'])
 if actual_origins!=expected_origins:raise AssertionError('Synthetic origin row does not round-trip exactly: '+json.dumps(actual_origins))
 add('synthetic-origin-timestamptz-json-roundtrip',historical_timezone_proof=timestamp_proof)
 before=snap();sql(apply);after=snap()
 if len(after['decisions'])-len(before['decisions'])!=5 or len(after['audit'])!=1 or after['epoch']!=701:raise AssertionError('Apply did not create exactly five decisions, one receipt and one cache epoch')
 if after['staging']!=before['staging'] or after['expenses']!=before['expenses']:raise AssertionError('Source fixtures mutated')
 if after['cache']!=[{'user_id':None,'cache_key':'synthetic-null-owner'}]:raise AssertionError('Known global nonnull-user cache deletion mismatch')
 output=query('SELECT jsonb_agg(to_jsonb(e) ORDER BY source_ref) FROM public.lts_v229_expense_rows('+lit(fixture['owner'])+"::uuid,'2000-01-01','2099-01-01') e;")
 for t in fixture['targets']:
  matched=[r for r in output if r['source_ref']==t['source_ref']]
  if len(matched)!=1 or matched[0]['category']!=t['category'] or matched[0]['beneficiary']!=t['beneficiary'] or matched[0]['identity_status']!='identified':raise AssertionError('Target final classification mismatch')
 add('success-five-overlays-financial-invariance-and-known-global-cache')
 sql(apply,expect='operation already recorded')
 if snap()!=after:raise AssertionError('Apply retry changed state')
 add('idempotency-rejects-second-apply-without-effects')
 sql(rollback);restored=snap()
 for key in ['decisions','staging','expenses']:
  if restored[key]!=before[key]:raise AssertionError('Rollback did not restore '+key)
 if restored['epoch']!=702 or len(restored['audit'])!=2:raise AssertionError('Rollback audit/cache mismatch')
 add('rollback-exact-decisions-and-financial-state-retains-audit')
 sql(rollback,expect='rollback already recorded')
 if snap()!=restored:raise AssertionError('Rollback retry changed state')
 add('idempotency-rejects-second-rollback-without-effects')
 first=lit(fixture['targets'][0]['source_ref'])
 reject('source-hash-change-blocked',apply,'source changed',f'UPDATE public.lts_open_finance_staging SET raw_hash=\'synthetic-changed\' WHERE id={first}::uuid;')
 reject('source-card-metadata-change-with-same-hash-blocked',apply,'source changed',f"UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{{creditCardMetadata,installmentNumber}}','99') WHERE id={first}::uuid;")
 reject('origin-change-blocked',apply,'original decision changed',"UPDATE public.lts_v178_review_decision SET decision_basis='synthetic-origin-changed' WHERE source_ref='synthetic-origin-1';")
 reject('future-installment-key-propagation-blocked',apply,'installment blast radius changed',f"INSERT INTO public.lts_open_finance_staging SELECT 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'::uuid,user_id,raw_hash,resource_type,'synthetic-later-record',provider_account_ref,institution_code,description_raw,signed_amount,currency,'2100-01-01',normalized_payload,provider_deleted_at,raw_payload FROM public.lts_open_finance_staging WHERE id={first}::uuid;")
 reject('disabled-cache-trigger-blocked',apply,'cache trigger binding changed',"ALTER TABLE public.lts_v178_review_decision DISABLE TRIGGER lts_v246_read_i;","ALTER TABLE public.lts_v178_review_decision ENABLE TRIGGER lts_v246_read_i;")
 reject('before-image-drift-blocked',apply,'final before-image changed',"UPDATE public.fixture_expense SET payload=jsonb_set(payload,'{amount}','123') WHERE id=1;")
 for mode,error in [('outside','unrelated output changed'),('null_outside','unrelated output changed'),('amount','financial projection changed'),('raw_reference','financial projection changed'),('classification','classification did not propagate'),('missing','expense cardinality changed'),('mutate_source','source changed'),('mutate_origin','original decision changed'),('mutate_hidden','out-of-scope decisions changed')]:
  reject('atomic-post-write-'+mode,"SET fixture."+mode+"='on';\n"+apply,error)
 reject('lease-change-blocked',apply.replace(lit(next(iter(measured.values()))),lit('0'*32)),'reader lease changed')
 reset();sql("SET fixture.warm_cache='on';\n"+apply);warm=snap()
 if warm['epoch']!=701 or {r['cache_key'] for r in warm['cache']}!={'synthetic-null-owner','synthetic-reader-warm'}:raise AssertionError('Known reader cache warming mismatch')
 add('known-reader-cache-warming-without-extra-epoch')
 # Preserve later decisions; compare timestamps/basis in full JSON postimages.
 reset();sql(apply);sql("UPDATE public.lts_v178_review_decision SET decision_basis='SYNTHETIC LATER DECISION' WHERE source_table='lts_open_finance_staging' AND source_ref="+first+';');later=snap();sql(rollback,expect='concurrent decision change')
 if snap()!=later:raise AssertionError('Later decision was damaged')
 add('rollback-blocked-by-later-decision')
 reset();sql(apply);sql("UPDATE public.fixture_expense SET payload=jsonb_set(payload,'{amount}','999') WHERE id=1;");later=snap();sql(rollback,expect='target output changed')
 if snap()!=later:raise AssertionError('Changed target output was damaged')
 add('rollback-blocked-by-later-target-output')
 # Post-delete reader failure must also roll back deletes/cache/audit atomically.
 reset();sql(apply)
 sql("CREATE FUNCTION public.fixture_delete_fault() RETURNS trigger LANGUAGE plpgsql AS $f$ BEGIN IF current_setting('fixture.rollback_fault',true)='on' THEN UPDATE public.fixture_expense SET payload=jsonb_set(payload,'{amount}','999') WHERE id=6; END IF; RETURN NULL; END $f$; CREATE TRIGGER fixture_delete_fault AFTER DELETE ON public.lts_v178_review_decision FOR EACH STATEMENT EXECUTE FUNCTION public.fixture_delete_fault();")
 before=snap();sql("SET fixture.rollback_fault='on';\n"+rollback,expect='financial projection changed')
 if snap()!=before:raise AssertionError('Post-delete failure not atomic')
 add('rollback-post-delete-failure-atomic')
 # Real two-session contention: first application holds its transaction until second is observed blocked.
 reset()
 holder=subprocess.Popen(command,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env={**env,'PGAPPNAME':'synthetic-holder'},bufsize=1)
 contender=None
 try:
  holder.stdin.write('BEGIN;\n'+apply+'\n\\echo SYNTHETIC_HELD\n');holder.stdin.flush()
  readable,_,_=select.select([holder.stdout],[],[],15)
  if not readable or holder.stdout.readline().strip()!='SYNTHETIC_HELD':raise AssertionError('Holder failed to reach transaction barrier')
  contender=subprocess.Popen(command,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env={**env,'PGAPPNAME':'synthetic-contender'})
  contender.stdin.write(apply);contender.stdin.close();contender.stdin=None
  deadline=time.monotonic()+3; blocked=False
  while time.monotonic()<deadline:
   blocked=sql("SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='synthetic-contender' AND wait_event_type='Lock');")=='t'
   if blocked:break
   time.sleep(0.05)
  if not blocked:raise AssertionError('Contender never reached a real PostgreSQL lock wait')
  holder.stdin.write('COMMIT;\n\\q\n');holder.stdin.flush();holder.stdin.close();holder.stdin=None
  hout,herr=holder.communicate(timeout=15);cout,cerr=contender.communicate(timeout=15)
  if holder.returncode or contender.returncode==0 or 'operation already recorded' not in cerr:raise AssertionError('Concurrent double-apply did not serialize safely: '+herr+cerr)
  result=snap()
  if result['epoch']!=701 or len(result['audit'])!=1 or len([d for d in result['decisions'] if d['source_table']=='lts_open_finance_staging'])!=5:raise AssertionError('Concurrent apply produced duplicate effects')
  add('two-session-apply-serialization-real-lock-wait')
 finally:
  for proc in [holder,contender]:
   if proc is not None and proc.poll() is None:proc.kill();proc.wait()
 reset()
 marker=HERE/'marker/marker_runner.py'
 if not marker.exists():raise AssertionError('Marker gate is required')
 import importlib.util
 spec=importlib.util.spec_from_file_location('synthetic_marker_runner',marker);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 marker_result=module.run_marker(sql)
 REPORT['marker']=marker_result
 REPORT.update(status='passed',passed=len(REPORT['tests']),server_version_num=pre['version'],template_hashes=manifest['files'],measured_fixture_leases=measured,private_candidate_hashes=manifest['source_sha256'],production_validated=False)
 RESULT.parent.mkdir(parents=True,exist_ok=True);RESULT.write_text(json.dumps(REPORT,indent=2,sort_keys=True)+'\n');print(json.dumps(REPORT,indent=2,sort_keys=True));return 0
if __name__=='__main__':
 try:sys.exit(main())
 except Exception as exc:
  REPORT.update(status='failed',error=str(exc),passed=len(REPORT['tests']))
  if RESULT is not None:RESULT.parent.mkdir(parents=True,exist_ok=True);RESULT.write_text(json.dumps(REPORT,indent=2,sort_keys=True)+'\n')
  print(json.dumps(REPORT,sort_keys=True),file=sys.stderr);sys.exit(1)
