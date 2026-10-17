#!/usr/bin/env python3
"""Run Q26's synthetic envelope on an opted-in fresh, isolated loopback PostgreSQL17 cluster."""
import argparse,hashlib,json,os,select,subprocess,time
from pathlib import Path
HERE=Path(__file__).resolve().parent; GEN=HERE/'generated'; DB='wealth_synthetic_q26'
REPORT=dict(status='not-run',database_tests_executed=False,production_validated=False,tests=[])
L=lambda v:"'"+str(v).replace("'","''")+"'"
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--allow-fresh-synthetic-postgres17',action='store_true');p.add_argument('--port',type=int,default=5432);p.add_argument('--results-dir',type=Path,default=HERE/'results');args=p.parse_args()
 if not args.allow_fresh_synthetic_postgres17:p.error('Explicit fresh disposable PostgreSQL17 opt-in required; no database contacted')
 if not 1024<=args.port<=65535:p.error('Unprivileged loopback port required')
 env=dict(PATH=os.environ.get('PATH','/usr/bin:/bin'),LANG='C.UTF-8',PGHOST='127.0.0.1',PGPORT=str(args.port),PGDATABASE=DB,PGUSER=DB,PGPASSWORD='synthetic-ci-only',PGCONNECT_TIMEOUT='5',PSQLRC='/dev/null',PGAPPNAME='synthetic-q26-gate')
 cmd=['psql','-X','-q','-A','-t','--set=ON_ERROR_STOP=1']
 def sql(s,error=None):
  r=subprocess.run(cmd,input=s,env=env,text=True,capture_output=True,timeout=90)
  if error:
   if not r.returncode or error not in r.stderr:raise AssertionError('Expected '+error+'; '+r.stderr)
  elif r.returncode:raise AssertionError(r.stderr)
  return r.stdout.strip()
 query=lambda s:json.loads(sql(s))
 manifest=json.loads((GEN/'manifest.json').read_text());fx=json.loads((GEN/'fixtures-synthetic.json').read_text())
 assert manifest['synthetic_only'] and not manifest['database_tests_executed']
 for n,h in manifest['files'].items():assert hashlib.sha256((GEN/n).read_bytes()).hexdigest()==h,n
 pre=query("SELECT jsonb_build_object('version',current_setting('server_version_num')::int,'db',current_database(),'user',current_user,'superuser',(SELECT rolsuper FROM pg_roles WHERE rolname=current_user),'objects',(SELECT count(*) FROM pg_class WHERE relnamespace='public'::regnamespace),'functions',(SELECT count(*) FROM pg_proc WHERE pronamespace='public'::regnamespace));")
 assert 170000<=pre['version']<180000 and pre['db']==DB and pre['user']==DB and pre['superuser'] and pre['objects']==0 and pre['functions']==0,pre
 REPORT['database_tests_executed']=True
 sql((GEN/'bootstrap-synthetic.sql').read_text())
 measured={sig:sql('SELECT md5(pg_get_functiondef('+L('public.'+sig)+'::regprocedure));') for sig in fx['leases']}
 today=sql("SELECT (now() AT TIME ZONE 'America/Sao_Paulo')::date;")
 def parameterize(action):
  s=(GEN/(action+'-synthetic.sql')).read_text()
  for sig,placeholder in fx['leases'].items():
   assert s.count(L(placeholder))==2,(action,sig)
   s=s.replace(L(placeholder),L(measured[sig]))
  return s.replace("current_date <> date '2099-01-01'","current_date <> date "+L(today))
 apply=parameterize('apply');rollback=parameterize('rollback');reset=lambda:sql((GEN/'reset-synthetic.sql').read_text())
 snap_sql="""SELECT jsonb_build_object('decisions',(SELECT jsonb_agg(to_jsonb(d) ORDER BY user_id,source_table,source_ref) FROM public.lts_v178_review_decision d),'audit',(SELECT jsonb_agg(to_jsonb(a) ORDER BY id) FROM public.lts_access_audit a),'staging',(SELECT jsonb_agg(to_jsonb(s) ORDER BY id) FROM public.lts_open_finance_staging s),'fixture_expense',(SELECT jsonb_agg(to_jsonb(f) ORDER BY id) FROM public.fixture_expense f),'epoch',(SELECT epoch FROM public.fixture_cache));"""
 snap=lambda:query(snap_sql)
 add=lambda case,**kw:REPORT['tests'].append(dict(case=case,passed=True,**kw))
 def reject(case,s,error,setup='',restore=''):
  reset()
  if setup:sql(setup)
  a=snap();sql(s,error);assert snap()==a,case+' left side effects'
  if restore:sql(restore)
  add(case,expected_rejection=error)
 target=L(fx['target']);pending=L(fx['pending'])
 reset()
 # Regression proof: January 2000 in Sao Paulo was DST -02, not -03.
 # PostgreSQL canonicalization must remain visible; never weaken exact JSON guards.
 timestamp_proof=query("SET TIME ZONE 'America/Sao_Paulo'; SELECT jsonb_build_object('old_serialized',to_jsonb('2000-01-01T00:00:00-03:00'::timestamptz),'winter_serialized',to_jsonb('2000-07-01T00:00:00-03:00'::timestamptz));")
 assert timestamp_proof=={'old_serialized':'2000-01-01T01:00:00-02:00','winter_serialized':'2000-07-01T00:00:00-03:00'},timestamp_proof
 actual_origins=query("SET TIME ZONE 'America/Sao_Paulo'; SELECT jsonb_agg(to_jsonb(d) ORDER BY user_id,source_table,source_ref) FROM public.lts_v178_review_decision d;")
 expected_origins=sorted(fx['origins'],key=lambda d:(d['user_id'],d['source_table'],d['source_ref']))
 assert actual_origins==expected_origins,('origin full-row JSON roundtrip failed',actual_origins)
 actual_audits=query("SET TIME ZONE 'America/Sao_Paulo'; SELECT jsonb_agg(to_jsonb(a) ORDER BY id) FROM public.lts_access_audit a;")
 expected_audits=sorted([dict(a,email=None) for a in fx['audits']],key=lambda a:a['id'])
 assert actual_audits==expected_audits,('origin audit full-row JSON roundtrip failed',actual_audits)
 add('historical-timezone-and-full-origin-audit-roundtrip',historical_timezone_proof=timestamp_proof,decision_rows_checked=len(actual_origins),audit_rows_checked=len(actual_audits))
 # The old timestamp is deliberately tested above; all live origin fixtures use July.
 before=snap();sql(apply);after=snap()
 assert len(after['decisions'])==len(before['decisions'])+1 and len(after['audit'])==len(before['audit'])+1 and after['epoch']==701
 assert after['staging']==before['staging'] and after['fixture_expense']==before['fixture_expense']
 assert [d for d in after['decisions'] if d['source_ref']!=fx['target']]==before['decisions']
 output=query('SELECT jsonb_agg(to_jsonb(e)) FROM public.lts_v229_expense_rows('+L(fx['owner'])+"::uuid,'2000-01-01','2099-01-01') e;")
 t=[r for r in output if r['source_ref']==fx['target']];assert len(t)==1 and t[0]['category']=='Synthetic Marketplace' and t[0]['beneficiary']=='Synthetic Person'
 receipt=next(a for a in after['audit'] if a['meta'].get('operation_id')==fx['operation'])
 assert receipt['meta']['before_decisions']==[] and len(receipt['meta']['staging_before'])==3 and receipt['meta']['official_provider_link'] is False
 add('success-one-overlay-preserves-pending-first-document-and-sources')
 sql(apply,'operation already recorded');assert snap()==after;add('repeat-apply-has-no-effects')
 sql(rollback);restored=snap()
 for k in ['decisions','staging','fixture_expense']:assert restored[k]==before[k],k
 assert restored['epoch']==702 and len(restored['audit'])==len(before['audit'])+2;add('rollback-restores-absence-and-output-preserves-audits')
 sql(rollback,'rollback already recorded');assert snap()==restored;add('repeat-rollback-has-no-effects')
 reject('uncleared-release-gate-blocked',apply.replace('"specific_production_authorization_verified":true','"specific_production_authorization_verified":false'),'Q26 release gates incomplete')
 reject('raw-hash-drift-blocked',apply,'Q26 witness source changed',f"UPDATE public.lts_open_finance_staging SET raw_hash='CHANGED' WHERE id={target}::uuid;")
 reject('one-ms-drift-with-identical-hash-blocked',apply,'Q26 witness source changed',f"UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{{creditCardMetadata,purchaseDate}}','\"2001-01-01T12:00:00.001Z\"') WHERE id={target}::uuid;")
 reject('source-status-drift-blocked',apply,'Q26 witness source changed',f"UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{{status}}','\"PENDING\"') WHERE id={target}::uuid;")
 reject('pending-decision-drift-blocked',apply,'Q26 lineage decision changed',f"UPDATE public.lts_v178_review_decision SET beneficiary=NULL WHERE source_ref={pending};")
 reject('lineage-audit-drift-blocked',apply,'Q26 lineage audit changed',"UPDATE public.lts_access_audit SET meta='{}' WHERE id=-1;")
 reject('new-same-key-even-outside-report-range-blocked',apply,'installment blast radius changed',f"INSERT INTO public.lts_open_finance_staging SELECT 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'::uuid,user_id,raw_hash,resource_type,provider_record_id,provider_account_ref,institution_code,description_raw,signed_amount,currency,'2100-01-01',normalized_payload,provider_deleted_at,raw_payload FROM public.lts_open_finance_staging WHERE id={target}::uuid;")
 reject('final-beforeimage-drift-blocked',apply,'final before-image changed',"UPDATE public.fixture_expense SET payload=jsonb_set(payload,'{amount}','12') WHERE id=1;")
 reject('cache-trigger-disabled-blocked',apply,'cache trigger binding changed',"ALTER TABLE public.lts_v178_review_decision DISABLE TRIGGER lts_v246_read_i;","ALTER TABLE public.lts_v178_review_decision ENABLE TRIGGER lts_v246_read_i;")
 reject('lease-drift-blocked',apply.replace(L(next(iter(measured.values()))),L('0'*32)),'reader lease changed')
 for mode,error in [('outside','unrelated output changed'),('amount','financial projection changed'),('raw_reference','financial projection changed'),('classification','classification did not propagate'),('missing','expense cardinality changed')]:reject('post-write-'+mode+'-atomic',"SET fixture."+mode+"='on';\n"+apply,error)
 reset();sql(apply);sql(f"UPDATE public.lts_v178_review_decision SET decision_basis='LATER' WHERE source_ref={target};");later=snap();sql(rollback,'concurrent decision change');assert snap()==later;add('rollback-preserves-later-decision')
 reset();sql(apply);sql("UPDATE public.fixture_expense SET payload=jsonb_set(payload,'{amount}','99') WHERE id=1;");later=snap();sql(rollback,'target output changed');assert snap()==later;add('rollback-preserves-later-output')
 reset();sql(apply);sql(f"UPDATE public.lts_open_finance_staging SET raw_payload=raw_payload||'{{\"administrative_sync\":true}}'::jsonb WHERE id={target}::uuid;");later=snap();sql(rollback,'Q26 pinned receipt or source mismatch');assert snap()==later;add('rollback-protects-entire-source-preimage')
 reset();sql(apply);sql("UPDATE public.lts_access_audit SET meta=jsonb_set(meta,'{targets,0,beneficiary}','\"OTHER\"') WHERE meta ? 'operation_id';");later=snap();sql(rollback,'Q26 pinned receipt or source mismatch');assert snap()==later;add('rollback-pins-receipt-manifest')
 # Real contender waits behind table locks, then sees operation receipt.
 reset();holder=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env={**env,'PGAPPNAME':'q26-holder'},bufsize=1);contender=None
 try:
  holder.stdin.write('BEGIN;\n'+apply+'\n\\echo Q26_HELD\n');holder.stdin.flush()
  ready,_,_=select.select([holder.stdout],[],[],15);assert ready and holder.stdout.readline().strip()=='Q26_HELD'
  contender=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env={**env,'PGAPPNAME':'q26-contender'})
  contender.stdin.write(apply);contender.stdin.close();contender.stdin=None
  deadline=time.monotonic()+3;blocked=False
  while time.monotonic()<deadline:
   blocked=sql("SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='q26-contender' AND wait_event_type='Lock');")=='t'
   if blocked:break
   time.sleep(.05)
  assert blocked;holder.stdin.write('COMMIT;\n\\q\n');holder.stdin.flush();holder.stdin.close();holder.stdin=None
  ho,he=holder.communicate(timeout=15);co,ce=contender.communicate(timeout=15)
  assert not holder.returncode and contender.returncode and 'operation already recorded' in ce,(he,ce)
  add('two-session-table-lock-serialization')
 finally:
  for proc in [holder,contender]:
   if proc and proc.poll() is None:proc.kill();proc.wait()
 REPORT.update(status='passed',passed=len(REPORT['tests']),server_version_num=pre['version'],private_candidate_hashes=manifest['source_sha256'],template_hashes=manifest['files'])
 args.results_dir.mkdir(parents=True,exist_ok=True);(args.results_dir/'result.json').write_text(json.dumps(REPORT,indent=2)+'\n');print(json.dumps(REPORT,indent=2))
if __name__=='__main__':
 try:main()
 except Exception as e:REPORT.update(status='failed',error=str(e),passed=len(REPORT['tests']));print(json.dumps(REPORT,indent=2));raise
