#!/usr/bin/env python3
"""Standalone opt-in PG17 marker-installer gate; no private source inputs or production credentials."""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess,sys
HERE=Path(__file__).resolve().parent;GEN=HERE/'generated';DB='wealth_synthetic_marker_installer'
BASE='public.lts_expense_rows_v230_baseline(uuid,date,date)';USER='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
REPORT={'status':'not-run','production_validated':False,'database_tests_executed':False,'tests':[]};RESULT=None
lit=lambda v:"'"+str(v).replace("'","''")+"'"
js=lambda v:json.dumps(v,ensure_ascii=False,separators=(',',':'))
def main():
 global RESULT
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--allow-fresh-synthetic-postgres17',action='store_true');p.add_argument('--port',type=int,default=5432);p.add_argument('--results-dir',type=Path,default=HERE/'results');a=p.parse_args()
 if not a.allow_fresh_synthetic_postgres17:p.error('Explicit disposable-cluster opt-in required; no database was contacted')
 if not 1024<=a.port<=65535:p.error('Only unprivileged loopback ports accepted')
 RESULT=a.results_dir/'result.json'
 env=dict(PATH=os.environ.get('PATH','/usr/bin:/bin'),LANG='C.UTF-8',PGHOST='127.0.0.1',PGPORT=str(a.port),PGDATABASE=DB,PGUSER=DB,PGPASSWORD='synthetic-ci-only',PGCONNECT_TIMEOUT='5',PSQLRC='/dev/null')
 cmd=['psql','-X','-q','-A','-t','--set=ON_ERROR_STOP=1']
 def sql(s,expect=None):
  r=subprocess.run(cmd,input=s,env=env,text=True,capture_output=True,timeout=180)
  if expect is not None:
   if r.returncode==0 or expect not in r.stderr:raise AssertionError(f'Expected {expect!r}; return={r.returncode}; {r.stderr}')
  elif r.returncode:raise RuntimeError(r.stderr)
  return r.stdout.strip()
 def query(s):return json.loads(sql(s))
 def add(name,**kw):REPORT['tests'].append(dict(case=name,passed=True,**kw))
 manifest=json.loads((GEN/'manifest.json').read_text())
 if not manifest['synthetic_only'] or manifest['postgresql_executed_during_generation']:raise AssertionError('Synthetic templates required')
 for n,h in manifest['files'].items():
  if hashlib.sha256((GEN/n).read_bytes()).hexdigest()!=h:raise AssertionError('Artifact hash changed: '+n)
 pre=query("SELECT jsonb_build_object('version',current_setting('server_version_num')::int,'database',current_database(),'user',current_user,'superuser',(SELECT rolsuper FROM pg_roles WHERE rolname=current_user),'objects',(SELECT count(*) FROM pg_class WHERE relnamespace='public'::regnamespace),'functions',(SELECT count(*) FROM pg_proc WHERE pronamespace='public'::regnamespace),'roles',(SELECT count(*) FROM pg_roles WHERE rolname IN('fixture_owner','fixture_reader','fixture_other')));")
 if not(170000<=pre['version']<180000 and pre['database']==DB and pre['user']==DB and pre['superuser'] and pre['objects']==pre['functions']==pre['roles']==0):raise RuntimeError('Fresh dedicated PG17 cluster required: '+js(pre))
 REPORT['database_tests_executed']=True
 sql('SET check_function_bodies=on;\n'+(GEN/'bootstrap-synthetic.sql').read_text())
 def measure():return query((GEN/'measure-lease-synthetic.sql').read_text())
 sql((GEN/'reset-synthetic.sql').read_text());original=measure()
 old_def=original['baseline_definition'];old_md5=next(f['definition_md5'] for f in original['functions'] if f['signature']==BASE[7:])
 def rows():return query(f"SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY row_key),'[]') FROM public.lts_v229_expense_rows('{USER}'::uuid,'2000-01-01','2099-01-01') e;")
 before_rows=rows()
 sql('SET check_function_bodies=on;\n'+(GEN/'baseline-candidate-synthetic.sql').read_text());installed=measure();after_rows=rows()
 new_def=installed['baseline_definition'];new_md5=next(f['definition_md5'] for f in installed['functions'] if f['signature']==BASE[7:])
 if len(before_rows)!=8 or len(after_rows)!=8:raise AssertionError('Full baseline fixture count mismatch')
 changed=[]
 for b,c in zip(before_rows,after_rows):
  if {k:v for k,v in b.items() if k!='identity_status'}!={k:v for k,v in c.items() if k!='identity_status'}:raise AssertionError('Full baseline changed protected field')
  if b['identity_status']!=c['identity_status']:
   if not(b['identity_status']=='pending' and c['identity_status']=='identified' and b['category'] in ('Saúde','Vestuário') and b['beneficiary'] is None):raise AssertionError('Unexpected full baseline transition')
   changed.append(b['source_ref'])
 if set(changed)!={'1','2'}:raise AssertionError('Generic transition identity mismatch: '+js(changed))
 add('full-sanitized-baseline-compiles-and-runs-with-declared-stubs',rows=8,changed=2,protected_fields=19,check_function_bodies=True,upstream_production_integration=False)
 sql(old_def+';')
 # All metadata placeholders are measured from these synthetic objects, not from private leases.
 today=sql("SELECT (now() AT TIME ZONE 'America/Sao_Paulo')::date;")
 def render(action,enabled=True):
  s=(GEN/(action+'-synthetic.sql')).read_text()
  replacements={'__FUNCTIONS_ORIGINAL__':js(original['functions']),'__FUNCTIONS_INSTALLED__':js(installed['functions']),'__RELATIONS__':js(original['relations']),'__ORIGINAL_MD5__':old_md5,'__CANDIDATE_MD5__':new_md5}
  for token,value in replacements.items():
   if token not in s:raise AssertionError('Missing expected template literal '+token)
   s=s.replace(lit(token),lit(value))
  # Replace only the one exact SQL definition, preserving canonical production pg_get_functiondef check.
  raw_old=(GEN/'baseline-original-synthetic.sql').read_text().removesuffix(';\n')
  raw_new=(GEN/'baseline-candidate-synthetic.sql').read_text().removesuffix(';\n')
  s=s.replace(lit(raw_old),lit(old_def)).replace('$definition$'+raw_old+'$definition$','$definition$'+old_def+'$definition$').replace('$definition$'+raw_new+'$definition$','$definition$'+new_def+'$definition$')
  if s.count("current_date<>DATE '2099-01-01'")!=1:raise AssertionError('Expiry template mismatch')
  s=s.replace("current_date<>DATE '2099-01-01'","current_date<>DATE "+lit(today))
  if s.count('ready constant boolean:=false;')!=1:raise AssertionError('Published readiness guard missing')
  if enabled:s=s.replace('ready constant boolean:=false;','ready constant boolean:=true;')
  if '__FUNCTION' in s or '__RELATIONS' in s or '__ORIGINAL_' in s or '__CANDIDATE_' in s:raise AssertionError('Unresolved synthetic placeholder')
  return s
 apply=render('apply');rollback=render('rollback')
 def reset():
  sql(old_def+';\n'+(GEN/'reset-synthetic.sql').read_text())
 def snapshot():
  # Ignore volatile capture time; record metadata, data, definitions, outputs and known cache effects.
  m=measure();m.pop('captured_at',None)
  data=query("SELECT jsonb_build_object('audit',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') FROM public.lts_access_audit x),'flow',(SELECT jsonb_agg(to_jsonb(x) ORDER BY source_ref) FROM public.fixture_flow x),'review',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY user_id,source_table,source_ref),'[]') FROM public.lts_v178_review_decision x),'cache',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY user_id),'[]') FROM public.lts_v229_read_cache x));")
  return dict(metadata=m,data=data,rows=rows())
 def reject(name,statement,error,setup='',restore=''):
  reset()
  if setup:sql(setup)
  before=snapshot();sql(statement,expect=error);after=snapshot()
  if after!=before:raise AssertionError(name+' failed atomic pre-attempt restoration')
  if restore:sql(restore)
  add(name,expected_rejection=error)
 reject('published-ready-false-refuses',render('apply',False),'marker installer blocked')
 reset();before=snapshot();sql(apply);after=snapshot()
 if after['metadata']['functions']!=installed['functions'] or after['metadata']['relations']!=original['relations']:raise AssertionError('OID/ACL/owner/config or relation properties changed')
 if after['metadata']['epoch']!=701 or len(after['data']['audit'])!=2:raise AssertionError('Apply epoch/audit count mismatch')
 receipt=after['data']['audit'][-1]['meta']
 if not receipt['global_homologation_invalidated'] or len(receipt['required_fresh_stages'])!=5:raise AssertionError('Five-stage invalidation missing')
 if after['data']['flow']!=before['data']['flow'] or after['data']['review']!=before['data']['review']:raise AssertionError('Source/decision data changed')
 if len(after['data']['cache'])!=1 or after['data']['cache'][0]['user_id'] is not None:raise AssertionError('Global nonnull-user cache invalidation mismatch')
 add('real-apply-envelope-only-two-statuses-preserves-all-object-properties',baseline_transitions=receipt['baseline_transitions'],final_transitions=receipt['final_transitions'],homologation_stages_invalidated=5)
 sql(rollback);restored=snapshot()
 if restored['metadata']['functions']!=original['functions'] or restored['rows']!=before['rows'] or restored['metadata']['epoch']!=702:raise AssertionError('Rollback not exact')
 if len(restored['data']['audit'])!=3:raise AssertionError('Rollback audit missing')
 add('real-rollback-envelope-restores-exact-definition-output-properties')
 # Repeated operations must be rejected without mutation even though lease check may reject first.
 before_retry=snapshot();sql(apply,expect='marker operation already recorded')
 if snapshot()!=before_retry:raise AssertionError('Repeated apply mutated state')
 add('duplicate-apply-refused-after-rollback')
 reject('missing-five-overlay-audit-refused',apply,'five exact overlays must be applied',"DELETE FROM public.lts_access_audit;")
 reject('rolled-back-overlay-audit-refused',apply,'five exact overlays must be applied',f"INSERT INTO public.lts_access_audit(user_id,action,meta) VALUES('{USER}','agent_restore_exact_classifications_20261016_rollback','{{\"operation_id\":\"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb\"}}');")
 reject('baseline-acl-drift-before-refused',apply,'function OID owner ACL config or definition lease changed',f'GRANT EXECUTE ON FUNCTION {BASE} TO fixture_other;',f'REVOKE EXECUTE ON FUNCTION {BASE} FROM fixture_other;')
 reject('baseline-owner-drift-before-refused',apply,'function OID owner ACL config or definition lease changed',f'ALTER FUNCTION {BASE} OWNER TO fixture_other;',f'ALTER FUNCTION {BASE} OWNER TO fixture_owner;')
 reject('baseline-config-drift-before-refused',apply,'function OID owner ACL config or definition lease changed',f'ALTER FUNCTION {BASE} SET statement_timeout=1234;',f'ALTER FUNCTION {BASE} RESET statement_timeout;')
 reject('relation-acl-drift-before-refused',apply,'relation schema ACL RLS view or trigger lease changed','GRANT SELECT ON public.fixture_flow TO fixture_other;','REVOKE SELECT ON public.fixture_flow FROM fixture_other;')
 reject('dependency-definition-drift-before-refused',apply,'function OID owner ACL config or definition lease changed',"CREATE OR REPLACE FUNCTION public.lts_v178_norm(v text) RETURNS text LANGUAGE sql STABLE AS $f$ SELECT 'synthetic changed'; $f$;",None)
 # Restore exact dependency definition from original catalog bootstrap (without replacing all objects).
 norm_sql=re.search(r'CREATE FUNCTION public\.lts_v178_norm\(.*?\$stub\$;', (GEN/'bootstrap-synthetic.sql').read_text(),re.S).group().replace('CREATE FUNCTION','CREATE OR REPLACE FUNCTION',1)
 sql(norm_sql)
 for mode,error in [('financial_after','marker changed one of nineteen protected fields'),('bad_transition','marker transition outside generic health clothing scope'),('drift_acl_after','postinstall function identity ACL or dependency lease changed'),('drift_relation_after','postinstall relation schema or permission changed')]:
  reject('atomic-post-ddl-'+mode,"SET fixture."+mode+"='on';\n"+apply,error)
 # A later function body must block rollback without replacing it.
 reset();sql(apply);sql(f'ALTER FUNCTION {BASE} SET statement_timeout=1234;');before=snapshot();sql(rollback,expect='function OID owner ACL config or definition lease changed')
 if snapshot()!=before:raise AssertionError('Later function setting was overwritten')
 sql(f'ALTER FUNCTION {BASE} RESET statement_timeout;');add('rollback-blocked-by-later-function-change')
 reset();sql(apply);before=snapshot();sql("SET fixture.rollback_financial='on';\n"+rollback,expect='marker changed one of nineteen protected fields')
 if snapshot()!=before:raise AssertionError('Rollback post-DDL failure was not atomic')
 add('rollback-post-ddl-failure-restores-candidate-and-cache')
 REPORT.update(status='passed',passed=len(REPORT['tests']),server_version_num=pre['version'],source_installer_sha256=manifest['source_installer_sha256'],template_files=manifest['files'],baseline_original_md5=old_md5,baseline_candidate_md5=new_md5,full_sanitized_baseline_compilation=True,full_baseline_execution_with_stubs=True,production_reader_integration=False,private_or_published_ready_guard_changed=False)
 RESULT.parent.mkdir(parents=True,exist_ok=True);RESULT.write_text(json.dumps(REPORT,indent=2,sort_keys=True)+'\n');print(json.dumps(REPORT,indent=2,sort_keys=True));return 0
if __name__=='__main__':
 try:sys.exit(main())
 except Exception as exc:
  REPORT.update(status='failed',error=str(exc),passed=len(REPORT['tests']))
  if RESULT is not None:RESULT.parent.mkdir(parents=True,exist_ok=True);RESULT.write_text(json.dumps(REPORT,indent=2,sort_keys=True)+'\n')
  print(json.dumps(REPORT,sort_keys=True),file=sys.stderr);sys.exit(1)
