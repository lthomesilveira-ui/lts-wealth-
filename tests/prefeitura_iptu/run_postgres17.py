#!/usr/bin/env python3
"""Synthetic PostgreSQL17 acceptance gate. Explicit opt-in; fresh loopback only."""
import argparse,copy,hashlib,json,os,select,subprocess,time
from pathlib import Path
from build_sql import catalog_sql,render
from fixture import OWNER,OTHER,SOURCE,TARGET,PENDING,EVENTS,ACCOUNT,EXTRA,OTHER_EVENT,OP,L,reset_sql,base_contract
H=Path(__file__).resolve().parent; DB='wealth_synthetic_iptu'
REPORT=dict(status='not-run',database_tests_executed=False,production_validated=False,tests=[])
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--allow-fresh-synthetic-postgres17',action='store_true');p.add_argument('--port',type=int,default=5432);p.add_argument('--results-dir',type=Path,default=H/'results');a=p.parse_args()
 if not a.allow_fresh_synthetic_postgres17:p.error('Explicit fresh synthetic PostgreSQL17 opt-in is required; no database contacted')
 if not 1024<=a.port<=65535:p.error('Use an unprivileged loopback port')
 env=dict(PATH=os.environ.get('PATH','/usr/bin:/bin'),LANG='C.UTF-8',PGHOST='127.0.0.1',PGPORT=str(a.port),PGDATABASE=DB,PGUSER=DB,PGPASSWORD='synthetic-ci-only',PGCONNECT_TIMEOUT='5',PSQLRC='/dev/null',PGAPPNAME='synthetic-iptu-gate')
 cmd=['psql','-X','-q','-A','-t','--set=ON_ERROR_STOP=1']
 def sql(s,error=None):
  r=subprocess.run(cmd,input=s,env=env,text=True,capture_output=True,timeout=90)
  if error:
   if not r.returncode or error not in r.stderr:raise AssertionError(('expected',error,'actual',r.stderr))
  elif r.returncode:raise AssertionError(r.stderr)
  return r.stdout.strip()
 query=lambda s:json.loads(sql(s))
 manifest=json.loads((H/'manifest.json').read_text())
 assert manifest['synthetic_only'] and not manifest['production_validated']
 for n,h in manifest['files'].items():assert hashlib.sha256((H/n).read_bytes()).hexdigest()==h,n
 pre=query("SELECT jsonb_build_object('version',current_setting('server_version_num')::int,'db',current_database(),'user',current_user,'superuser',(SELECT rolsuper FROM pg_roles WHERE rolname=current_user),'objects',(SELECT count(*) FROM pg_class WHERE relnamespace='public'::regnamespace),'functions',(SELECT count(*) FROM pg_proc WHERE pronamespace='public'::regnamespace));")
 assert 170000<=pre['version']<180000 and pre['db']==pre['user']==DB and pre['superuser'] and pre['objects']==pre['functions']==0,pre
 sql((H/'bootstrap.sql').read_text());REPORT['database_tests_executed']=True
 cfg=json.loads((H/'catalog-config.json').read_text())
 def contract():
  c=base_contract();c['catalog_config']=cfg;c['catalog']=query("SET search_path=pg_catalog,public;"+catalog_sql(cfg)+';')
  c['original_event']=query("SET TIME ZONE 'UTC';SELECT to_jsonb(e) FROM public.financial_events e WHERE id="+L(TARGET)+"::uuid;")
  c['original_event_md5']=sql("SET TIME ZONE 'UTC';SELECT md5(to_jsonb(e)::text) FROM public.financial_events e WHERE id="+L(TARGET)+"::uuid;")
  c['source_lease']=query("SET TIME ZONE 'UTC';SELECT jsonb_build_object('id',s.id,'user_id',s.user_id,'row_md5',md5(to_jsonb(s)::text),'stable_md5',md5((to_jsonb(s)-ARRAY['sync_run_id','last_seen_at','updated_at'])::text),'raw_hash',s.raw_hash,'institution_code',s.institution_code,'provider_account_ref',s.provider_account_ref,'provider_record_id',s.provider_record_id,'connection_id',s.connection_id) FROM public.lts_open_finance_staging s WHERE id="+L(SOURCE)+"::uuid;")
  c['protected_events']=query("SET TIME ZONE 'UTC';SELECT jsonb_agg(jsonb_build_object('id',e.id,'row_md5',md5(to_jsonb(e)::text)) ORDER BY id) FROM public.financial_events e WHERE id IN ("+','.join(L(i)+'::uuid' for i in EVENTS)+");")
  c['protected_sources']=query("SET TIME ZONE 'UTC';SELECT jsonb_agg(jsonb_build_object('id',s.id,'row_md5',md5(to_jsonb(s)::text),'stable_md5',md5((to_jsonb(s)-ARRAY['sync_run_id','last_seen_at','updated_at'])::text)) ORDER BY id) FROM public.lts_open_finance_staging s WHERE id IN ("+','.join(L(i)+'::uuid' for i in [SOURCE]+PENDING)+");")
  c['account']=query("SET TIME ZONE 'UTC';SELECT jsonb_build_object('id',a.id,'institution',a.institution,'row_md5',md5(to_jsonb(a)::text)) FROM public.accounts a WHERE id="+L(ACCOUNT)+"::uuid;")
  return c
 def reset():sql(reset_sql());return contract()
 tables=['accounts','financial_events','lts_open_finance_staging','lts_v178_review_decision','lts_reconciliation_link','lts_flow_event_operation','lts_access_audit','lts_read_cache_epoch_v242','lts_v229_read_cache']
 snapquery="SET TIME ZONE 'UTC';SELECT jsonb_build_object("+','.join(L(t)+",(SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]') FROM public."+t+" t)" for t in tables)+");"
 snap=lambda:query(snapquery)
 sequences=lambda:query("SELECT jsonb_build_object('link',(SELECT last_value FROM public.lts_reconciliation_link_id_seq),'audit',(SELECT last_value FROM public.lts_access_audit_id_seq));")
 epoch=lambda:int(sql('SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton;'))
 add=lambda name,**kw:REPORT['tests'].append(dict(case=name,passed=True,**kw))
 def inverse(c):
  d=copy.deepcopy(c);d['rollback']=dict(authorized=True,committed_receipt_verified=True,receipt_md5=sql("SET TIME ZONE 'UTC';SELECT md5(to_jsonb(a)::text) FROM public.lts_access_audit a WHERE meta->>'operation_id'="+L(OP)+";"));return render(d,'rollback')
 def reject(name,setup='',expected='changed',mutate=None,restore=''):
  c=reset();s=render(mutate(c) if mutate else c,'apply')
  if setup:sql(setup)
  b=snap();sql(s,expected);assert snap()==b,name+' left transactional side effects'
  if restore:sql(restore)
  add(name,expected_rejection=expected)
 c=reset()
 # BIGINT catalog values must survive JSON intermediaries implemented with IEEE754 numbers.
 # They are contract text, never rounded numeric JSON.
 assert c['catalog']['sequences']
 for seq in c['catalog']['sequences']:
  for key in ['start','increment','max','min','cache']:assert isinstance(seq[key],str),(key,seq)
  assert seq['max']=='9223372036854775807',seq
 assert json.loads(json.dumps(c['catalog']))==c['catalog']
 add('catalog-bigint-sequence-limits-are-lossless-text')
 t=query("SET TIME ZONE 'America/Sao_Paulo';SELECT jsonb_build_object('historical',to_jsonb('2000-01-01T00:00:00-03:00'::timestamptz),'winter',to_jsonb('2000-07-01T00:00:00-03:00'::timestamptz));")
 assert t==dict(historical='2000-01-01T01:00:00-02:00',winter='2000-07-01T00:00:00-03:00'),t
 assert query("SET TIME ZONE 'UTC';SELECT to_jsonb(jsonb_populate_record(NULL::public.financial_events,"+L(json.dumps(c['original_event']))+"::jsonb));")==c['original_event'];add('UTC-full-event-roundtrip-and-historical-DST-counterexample')
 b=snap();sql(render(c,'apply'));after=snap();assert epoch()==103
 assert len(after['lts_v178_review_decision'])==len(after['lts_reconciliation_link'])==len(after['lts_access_audit'])==1
 ev=next(e for e in after['financial_events'] if e['id']==TARGET);orig=c['original_event'];assert ev['is_suppressed']
 for k in set(orig)-{'metadata','is_suppressed','suppression_reason'}:assert ev[k]==orig[k],k
 assert {k:v for k,v in ev['metadata'].items() if k!=c['marker']}==orig['metadata']
 for t in ['accounts','lts_open_finance_staging','lts_flow_event_operation']:assert after[t]==b[t]
 assert [e for e in after['financial_events'] if e['id']!=TARGET]==[e for e in b['financial_events'] if e['id']!=TARGET]
 out=query("SELECT jsonb_agg(to_jsonb(x)) FROM public.lts_v229_expense_rows("+L(OWNER)+"::uuid,'2000-01-01','2000-12-31') x;")
 assert len(out)==1 and out[0]['amount']==13.37 and out[0]['posting_date']=='2000-07-16' and out[0]['property_code']=='synthetic_property' and out[0]['beneficiary'] is None and out[0]['identity_status']=='identified' and out[0]['property_component']=='Synthetic property tax'
 assert sql("SELECT public.lts_flow_current_effective_v1("+L(OWNER)+"::uuid,'2000-07-01','2000-07-31');")=='0';add('atomic-one-overlay-one-link-one-suppression-preserves-all-other-fixture-rows')
 sq=sequences();sql(render(c,'apply'));assert snap()==after and sequences()==sq;add('exact-retry-zero-DML-audit-epoch-and-sequence')
 sql("UPDATE public.lts_open_finance_staging SET updated_at='2001-01-01',last_seen_at='2001-01-01',sync_run_id='99999999-9999-4999-8999-999999999998';")
 polled=snap();sq=sequences();sql(render(c,'apply'));assert snap()==polled and sequences()==sq;add('administrative-polling-only-retry-no-write')
 undo=inverse(c);sql(undo);restored=snap();assert epoch()==106
 assert restored['financial_events']==b['financial_events'] and restored['lts_v178_review_decision']==restored['lts_reconciliation_link']==[] and len(restored['lts_access_audit'])==2
 sq=sequences();sql(undo);assert snap()==restored and sequences()==sq;add('guarded-joint-inverse-and-exact-inverse-retry-preserves-durable-audit')
 sql(render(c,'apply'),'operation was reversed');assert snap()==restored;add('no-reapply-after-inverse')
 reject('ready-false-before-work',expected='release gates incomplete',mutate=lambda c:{**c,'ready':False})
 reject('missing-approval-gate',expected='release gates incomplete',mutate=lambda c:{**c,'gates':{**c['gates'],'exact_candidate_authorized':False}})
 reject('missing-nominal-account-context-gate',expected='release gates incomplete',mutate=lambda c:{**c,'gates':{**c['gates'],'nominal_account_context_verified':False}})
 reject('legacy-account-mapping-gate-is-not-equivalent',expected='release gates incomplete',mutate=lambda c:{**c,'gates':{**{k:v for k,v in c['gates'].items() if k!='nominal_account_context_verified'},'account_mapping_verified':True}})
 reject('missing-pending-stable-hash',expected='protected bank source materially changed',mutate=lambda c:{**c,'protected_sources':[{**x,'stable_md5':None} for x in c['protected_sources']]})
 reject('initial-polling-requires-full-renewal',"UPDATE public.lts_open_finance_staging SET updated_at='2001-01-01' WHERE id="+L(SOURCE)+"::uuid;",'first apply full source lease expired')
 for col,val in [('signed_amount','-99'),('posting_date',"'2000-07-17'"),('currency',"'USD'"),('user_id',L(OTHER)+'::uuid'),('raw_hash',"'changed'")]:
  reject('source-'+col+'-drift',f"UPDATE public.lts_open_finance_staging SET {col}={val} WHERE id={L(SOURCE)}::uuid;",'protected bank source materially changed')
 reject('source-status-pending',f"UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{{status}}','\"PENDING\"') WHERE id={L(SOURCE)}::uuid;",'protected bank source materially changed')
 reject('protected-pending-material-drift',f"UPDATE public.lts_open_finance_staging SET signed_amount=-99 WHERE id={L(PENDING[0])}::uuid;",'protected bank source materially changed')
 reject('protected-november-event-drift',f"UPDATE public.financial_events SET amount=-99 WHERE id={L(EVENTS[1])}::uuid;",'protected forecast changed')
 reject('target-later-edit',f"UPDATE public.financial_events SET metadata=metadata||'{{\"later\":true}}' WHERE id={L(TARGET)}::uuid;",'partial state has no exact receipt')
 reject('conflicting-existing-decision',f"INSERT INTO public.lts_v178_review_decision(user_id,source_table,source_ref,category_label,decision_basis) VALUES({L(OWNER)},'lts_open_finance_staging',{L(SOURCE)},'Conflicting','synthetic');",'partial state has no exact receipt')
 reject('operation-before-apply',f"INSERT INTO public.lts_flow_event_operation(target_event_id,operation) VALUES({L(TARGET)},'synthetic');",'unexpected event operation')
 reject('source-reused-by-other-owner',f"INSERT INTO public.lts_reconciliation_link(user_id,target_event_id,candidate_source_table,candidate_source_ref,candidate_event_date,candidate_amount) VALUES({L(OTHER)},{L(EVENTS[0])},'lts_open_finance_staging',{L(SOURCE)},'2000-07-16',-13.37);",'endpoint reused or conflicting link across owners')
 reject('schema-new-column',"ALTER TABLE public.lts_access_audit ADD COLUMN unexpected text;",'catalog ACL RLS trigger function or sequence lease changed',restore='ALTER TABLE public.lts_access_audit DROP COLUMN unexpected;')
 reject('disabled-cache-trigger',"ALTER TABLE public.lts_reconciliation_link DISABLE TRIGGER cache_i;",'catalog ACL RLS trigger function or sequence lease changed',restore='ALTER TABLE public.lts_reconciliation_link ENABLE TRIGGER cache_i;')
 reject('cache-table-RLS-drift',"ALTER TABLE public.lts_v229_read_cache ENABLE ROW LEVEL SECURITY;",'catalog ACL RLS trigger function or sequence lease changed',restore='ALTER TABLE public.lts_v229_read_cache DISABLE ROW LEVEL SECURITY;')
 reject('operation-FK-deferrable',"ALTER TABLE public.lts_flow_event_operation ALTER CONSTRAINT lts_flow_event_operation_target_event_id_fkey DEFERRABLE;",'operation FK contract changed',restore='ALTER TABLE public.lts_flow_event_operation ALTER CONSTRAINT lts_flow_event_operation_target_event_id_fkey NOT DEFERRABLE;')
 # Failure after all three business mutations demonstrates atomic rollback, not sequence rollback.
 c=reset();c['expected_epoch_delta']=3;c['catalog']['session_role']='wrong';b=snap();sql(render(c,'apply'),'catalog ACL');assert snap()==b;add('role-lease-fail-closed')
 c=reset();base=sql("SELECT pg_get_functiondef('public.lts_v246_invalidate_finance_cache()'::regprocedure);")
 sql("CREATE OR REPLACE FUNCTION public.lts_v246_invalidate_finance_cache() RETURNS trigger LANGUAGE plpgsql AS $f$ BEGIN DELETE FROM public.lts_v229_read_cache; UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+2 WHERE singleton; RETURN NULL; END $f$;")
 c=contract();b=snap();sq=sequences();sql(render(c,'apply'),'unexpected cache epoch delta');assert snap()==b and sequences()['link']>=sq['link'];sql(base);add('late-cache-delta-failure-atomic-business-rollback-sequences-not-rewound')
 for name,statement,error in [
  ('event',f"UPDATE public.financial_events SET metadata=metadata||'{{\"later\":true}}' WHERE id={L(TARGET)}::uuid;",'event postimage mismatch'),
  ('link',"UPDATE public.lts_reconciliation_link SET note='later';",'link postimage mismatch'),
  ('decision',"UPDATE public.lts_v178_review_decision SET beneficiary='later';",'classification postimage mismatch'),
  ('receipt',"UPDATE public.lts_access_audit SET action='later';",'pinned committed receipt changed')]:
  c=reset();sql(render(c,'apply'));u=inverse(c);sql(statement);b=snap();sql(u,error);assert snap()==b;add('inverse-preserves-later-'+name)
 c=reset();sql(render(c,'apply'));sql("UPDATE public.accounts SET currency='USD';");b=snap();sql(render(c,'apply'),'nominal account context changed');assert snap()==b;add('retry-rejects-account-currency-drift')
 c=reset();sql(render(c,'apply'));b=snap();sql(render(c,'rollback'),'inverse requires authorized committed receipt');assert snap()==b;add('inverse-cannot-infer-authorization')
 c=reset();sql(render(c,'apply'));sql("UPDATE public.lts_access_audit SET meta=jsonb_set(meta,'{learning,automatic_expansion}','true');");b=snap();sql(render(c,'apply'),'durable receipt mismatch');assert snap()==b;add('retry-rejects-tampered-learning-receipt')
 c=reset();sql(render(c,'apply'));assert sql("SELECT public.lts_flow_current_effective_v1("+L(OWNER)+"::uuid,'2000-07-16','2000-07-31');")=='0';add('past-day-UI-zero-delta-still-requires-link-and-suppression')
 # Two-session proofs. An existing operation commits while apply waits on the event lock.
 def process(app):return subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env={**env,'PGAPPNAME':app},bufsize=1)
 def feed(proc,s):proc.stdin.write(s);proc.stdin.flush()
 def signal(proc,label):
  # Read the raw pipe: TextIOWrapper.readline can prebuffer HELD, leaving select
  # with an empty OS descriptor even though the marker is already in Python.
  deadline=time.monotonic()+10;pending=b'';marker=label.encode()
  while time.monotonic()<deadline:
   ready,_,_=select.select([proc.stdout],[],[],.2)
   if ready:
    chunk=os.read(proc.stdout.fileno(),65536)
    if not chunk:raise AssertionError(proc.stderr.read())
    pending+=chunk
    lines=pending.split(b'\n');pending=lines.pop()
    if any(line.strip()==marker for line in lines):return
  raise AssertionError('holder did not signal '+label)
 def blocked(app):
  deadline=time.monotonic()+1.3
  while time.monotonic()<deadline:
   if sql("SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name="+L(app)+" AND wait_event_type='Lock');")=='t':return
   time.sleep(.02)
  raise AssertionError('contender did not block')
 def finish(proc):
  proc.stdin.close();proc.stdin=None;return proc.communicate(timeout=15)
 for scenario in ['operation-before-event-lock','new-operation-waits-behind-apply','duplicate-apply-serializes','source-reuse-different-target']:
  c=reset();apply=render(c,'apply');holder=contender=None
  try:
   holder=process('synthetic-iptu-holder')
   if scenario=='operation-before-event-lock':
    feed(holder,f"BEGIN;INSERT INTO public.lts_flow_event_operation(target_event_id,operation) VALUES({L(TARGET)},'synthetic');\n\\echo HELD\n");signal(holder,'HELD')
    contender=process('synthetic-iptu-contender');feed(contender,apply);contender.stdin.close();contender.stdin=None;blocked('synthetic-iptu-contender');feed(holder,'COMMIT;\n\\q\n');finish(holder);out,err=contender.communicate(timeout=15)
    assert contender.returncode and 'unexpected event operation' in err,err;assert len(snap()['lts_access_audit'])==0
   else:
    feed(holder,apply.rsplit('COMMIT;',1)[0]+'\n\\echo HELD\n');signal(holder,'HELD')
    contender=process('synthetic-iptu-contender')
    cs=(f"INSERT INTO public.lts_flow_event_operation(target_event_id,operation) VALUES({L(TARGET)},'synthetic');" if scenario=='new-operation-waits-behind-apply' else apply)
    if scenario=='source-reuse-different-target':
     # A second complete contracted writer targets another nominal occurrence but reuses the source.
     other=copy.deepcopy(c);other['operation_id']='synthetic-other-obligation';other['target_id']=EVENTS[0]
     other['forecast_date']='2000-06-15';other['marker']='synthetic_other_marker'
     other['original_event']=query("SET TIME ZONE 'UTC';SELECT to_jsonb(e) FROM public.financial_events e WHERE id="+L(EVENTS[0])+"::uuid;")
     other['original_event_md5']=sql("SET TIME ZONE 'UTC';SELECT md5(to_jsonb(e)::text) FROM public.financial_events e WHERE id="+L(EVENTS[0])+"::uuid;")
     # Use two unchanged independent witnesses, so the source-reuse check is the rejection we exercise.
     other['protected_events']=query("SET TIME ZONE 'UTC';SELECT jsonb_agg(jsonb_build_object('id',e.id,'row_md5',md5(to_jsonb(e)::text)) ORDER BY id) FROM public.financial_events e WHERE id IN ("+L(EVENTS[1])+"::uuid,"+L(OTHER_EVENT)+"::uuid);")
     cs=render(other,'apply')
    feed(contender,cs);contender.stdin.close();contender.stdin=None;blocked('synthetic-iptu-contender');feed(holder,'COMMIT;\n\\q\n');finish(holder);out,err=contender.communicate(timeout=15)
    if scenario!='source-reuse-different-target':assert not contender.returncode,err
    if scenario=='source-reuse-different-target':
     assert contender.returncode and 'endpoint reused or conflicting link across owners' in err,err
     assert len(snap()['lts_reconciliation_link'])==1 and epoch()==103
    elif scenario=='duplicate-apply-serializes':assert 'already_applied_exact' in out and epoch()==103 and len(snap()['lts_access_audit'])==1
   add('two-session-'+scenario)
  finally:
   for proc in [holder,contender]:
    if proc and proc.poll() is None:proc.kill();proc.wait()
 REPORT.update(status='passed',passed=len(REPORT['tests']),server_version_num=pre['version'],allowlist_sha256=manifest['files'])
 a.results_dir.mkdir(parents=True,exist_ok=True);(a.results_dir/'result.json').write_text(json.dumps(REPORT,indent=2)+'\n');print(json.dumps(REPORT,indent=2))
if __name__=='__main__':
 try:main()
 except Exception as e:
  REPORT.update(status='failed',error=str(e),passed=len(REPORT['tests']));print(json.dumps(REPORT,indent=2));raise
