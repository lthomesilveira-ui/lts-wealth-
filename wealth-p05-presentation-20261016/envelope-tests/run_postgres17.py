#!/usr/bin/env python3
"""Exact single-DO template with fictional rows in a disposable loopback PG17 database."""
import argparse,copy,datetime,hashlib,json,os,re,subprocess,sys
from pathlib import Path
import build_envelope as E
import build_read as R
HERE=Path(__file__).parent; PUB=HERE.parent/'public'; OUT=HERE/'results';OUT.mkdir(exist_ok=True)
p=argparse.ArgumentParser();p.add_argument('--allow-fresh-synthetic-postgres17',action='store_true');args=p.parse_args()
if not args.allow_fresh_synthetic_postgres17:p.error('Disposable PostgreSQL17 opt-in required; no connection attempted')
ENV=dict(PATH=os.environ.get('PATH','/usr/bin:/bin'),LANG='C.UTF-8',PGHOST='127.0.0.1',PGPORT='5432',PGDATABASE='lts_p05_synthetic',PGUSER='lts_p05_synthetic',PGPASSWORD='synthetic-ci-only',PGCONNECT_TIMEOUT='5',PSQLRC='/dev/null')
LOG=[];RESULTS=[]
def sql(text,expect_ok=True):
 r=subprocess.run(['psql','-X','-q','-A','-t','--set=ON_ERROR_STOP=1'],input=text,env=ENV,text=True,capture_output=True)
 LOG.append({'rc':r.returncode,'stdout':r.stdout,'stderr':r.stderr})
 if expect_ok and r.returncode:raise AssertionError(r.stderr)
 if not expect_ok and not r.returncode:raise AssertionError('Expected abort did not occur')
 return r

def read_lease():
 lines=[x for x in sql(R.query).stdout.splitlines() if x.startswith('{')];assert len(lines)==1
 return json.loads(lines[0])
def snapshot():
 x=read_lease();return {k:x[k] for k in ['functions','tables','rows','epoch','function_defaults','original_presentation_definition']}
def passed(name):RESULTS.append({'case':name,'passed':True});print(name,flush=True)
def reject_unchanged(name,statement,needle=None):
 before=snapshot();r=sql(statement,False);assert snapshot()==before, name+' mutated database on rejection'
 if needle:assert needle in r.stderr,(name,r.stderr)
 passed(name)

# Initial environment guard runs before any destructive synthetic reset.
sql("DO $$ BEGIN IF current_database()<>'lts_p05_synthetic' OR current_user<>'lts_p05_synthetic' OR current_setting('server_version_num')::int/10000<>17 OR EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind IN ('r','v','m','f')) THEN RAISE EXCEPTION 'fresh local synthetic PG17 required'; END IF; END $$;")
sql('CREATE ROLE anon NOLOGIN; CREATE ROLE authenticated NOLOGIN; CREATE ROLE service_role NOLOGIN BYPASSRLS; CREATE ROLE lts_p05_leak NOLOGIN;')
subprocess.run([sys.executable,str(PUB/'build_tests.py')],check=True)
f=json.loads((PUB/'synthetic-fixture.json').read_text())['args'];u,l,b,t,c=[f[k] for k in ['user','link','invoice','payment','contract']]
original=(PUB/'original-presentation-helper.sql').read_text();table=original[original.index('CREATE TABLE'):original.index('CREATE FUNCTION')]
old,_=E.extract(PUB/'original-presentation-helper.sql','function')
bootstrap="""DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT USAGE ON SCHEMA public TO anon,authenticated,service_role;
"""+table+"""
CREATE TABLE public.lts_open_finance_staging(id uuid PRIMARY KEY,user_id uuid,resource_type text,provider_deleted_at timestamptz,institution_code text,provider_record_id text,provider_account_ref text,currency text,signed_amount numeric,normalized_payload jsonb,raw_payload jsonb,posting_date date,raw_hash text);
CREATE TABLE public.lts_card_settlement_expense_contract_v273(user_id uuid,payment_source_id uuid,revision text,payload jsonb,active boolean,PRIMARY KEY(user_id,payment_source_id));
ALTER TABLE public.lts_card_settlement_expense_contract_v273 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_card_settlement_expense_contract_v273 FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.lts_card_settlement_expense_contract_v273 TO service_role;
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY CHECK(singleton),epoch bigint NOT NULL);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,100);
"""+old+f"\nREVOKE ALL ON FUNCTION {E.CALLER} FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION {E.CALLER} TO service_role;\n"
for row in [b,t]:bootstrap+='INSERT INTO public.lts_open_finance_staging SELECT * FROM jsonb_populate_record(NULL::public.lts_open_finance_staging,'+E.j(row)+');\n'
bootstrap+='INSERT INTO public.lts_card_documentary_payment_link_v272 SELECT * FROM jsonb_populate_record(NULL::public.lts_card_documentary_payment_link_v272,'+E.j(l)+');\n'
bootstrap+=f"INSERT INTO public.lts_card_settlement_expense_contract_v273 VALUES('{u}','{t['id']}','synthetic',{E.j(c)},true);\n"
for sig in R.FUNCS[2:]:
 name=sig.split('(')[0];typ=sig.split('(')[1][:-1]
 ret='uuid' if sig.endswith('_owner_v1()') or sig.endswith('assert_user_v1()') else ('boolean' if 'settlement' in name else 'text' if 'read_start' in name else 'jsonb')
 if 'pilot_owner' in name:body="BEGIN RETURN '"+u+"'::uuid; END"
 else:body="BEGIN RAISE EXCEPTION 'forbidden full reader or financial execution in presentation envelope'; END"
 bootstrap+=f"CREATE FUNCTION {name}({typ}) RETURNS {ret} LANGUAGE plpgsql SET search_path TO '' AS $stub${body}$stub$;\nREVOKE ALL ON FUNCTION {sig} FROM PUBLIC,anon,authenticated;\nGRANT EXECUTE ON FUNCTION {sig} TO service_role;\n"

def reset(extra=''):
 sql(bootstrap+extra);return read_lease()
def apply(lease):
 r=sql(E.render(lease));line=next(x.split('P05_PRESENTATION_RECEIPT ',1)[1] for x in r.stderr.splitlines() if 'P05_PRESENTATION_RECEIPT ' in x)
 return json.loads(line)
def recovery(lease,receipt,oldlease):return E.render(lease,'recovery',receipt,oldlease)
try:
 base=reset();receipt=apply(base);now=read_lease()
 assert now['epoch']==101 and now['rows']==base['rows'] and now['tables']==base['tables'];assert receipt['annotation_allowlisted'] and not receipt['reader_rpc_executed']
 passed('apply_exact_allowlist_without_readers')
 reject_unchanged('same_apply_cannot_double_increment',E.render(base),'epoch lease changed')
 recover=recovery(now,receipt,base);sql(recover);back=read_lease()
 assert back['functions']==base['functions'] and back['original_presentation_definition']==base['original_presentation_definition'] and back['epoch']==102 and back['rows']==base['rows']
 passed('recovery_restores_exact_caller_acl_oid_and_drops_projector')
 # Default privileges are deliberately unsafe; migration must drain them, without changing defaults.
 base=reset('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO lts_p05_leak WITH GRANT OPTION;');receipt=apply(base)
 assert read_lease()['function_defaults']==base['function_defaults'];assert sql(f"SELECT has_function_privilege('lts_p05_leak','{E.PROJECTOR}','EXECUTE');").stdout.strip()=='f'
 passed('unexpected_default_acl_drained_without_altering_defaults')
 mutations=[
 ('stale_epoch',"UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1;"),
 ('bank_source_drift',"UPDATE public.lts_open_finance_staging SET raw_hash='unreviewed' WHERE resource_type='transaction';"),
 ('invoice_timestamp_after_lease',"UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{updatedAt}','\"2027-01-01T00:00:00Z\"');"),
 ('contract_drift',"UPDATE public.lts_card_settlement_expense_contract_v273 SET revision='unreviewed';"),
 ('original_link_drift',"UPDATE public.lts_card_documentary_payment_link_v272 SET expected_amount=101;"),
 ('caller_acl_drift',f"GRANT EXECUTE ON FUNCTION {E.CALLER} TO lts_p05_leak;"),
 ('function_default_drift',"ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO lts_p05_leak;"),
 ('caller_oid_recreated',f"DROP FUNCTION {E.CALLER};"+old+f"REVOKE ALL ON FUNCTION {E.CALLER} FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION {E.CALLER} TO service_role;"),
 ('unexpected_projector',E.PROJECTOR_DDL),
 ]
 for name,mutation in mutations:
  base=reset();statement=E.render(base);sql(mutation);reject_unchanged(name,statement)
 base=reset('GRANT SELECT(payload) ON public.lts_card_settlement_expense_contract_v273 TO authenticated;')
 reject_unchanged('fresh_lease_cannot_allow_contract_column_grant',E.render(base),'private contract privilege boundary changed')
 base=reset();typed=copy.deepcopy(base);typed['functions'][0]['oid']=str(typed['functions'][0]['oid'])
 reject_unchanged('oid_string_same_digits_rejected_atomically',E.render(typed),'lease changed')
 base=reset();stale=copy.deepcopy(base);stale['checked_at']='2000-01-01T00:00:00+00:00';reject_unchanged('expired_lease',E.render(stale),'fresh lease required')
 future=copy.deepcopy(base);future['checked_at']='2099-01-01T00:00:00+00:00';reject_unchanged('future_lease',E.render(future),'fresh lease required')
 # Lease is fresh/exact but evidence invalid: error happens after BOTH DDL statements.
 base=reset("UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{totalAmount}','101') WHERE resource_type='invoice';")
 reject_unchanged('invalid_evidence_after_ddl_rolls_back_both_helpers',E.render(base),'allowlisted annotation projection failed')
 base=reset();statement=E.render(base).replace('annotation:=public.lts_card_payment_refresh_annotation_v273',"RAISE EXCEPTION 'synthetic forced after DDL';\n annotation:=public.lts_card_payment_refresh_annotation_v273",1)
 reject_unchanged('forced_failure_after_ddl_atomic',statement,'synthetic forced after DDL')
 # A tracked SQL dependency must block DROP RESTRICT and roll back the caller restoration.
 base=reset();receipt=apply(base);fresh=read_lease();statement=recovery(fresh,receipt,base)
 sql(f"CREATE VIEW public.later_dependency AS SELECT public.lts_card_payment_refresh_annotation_v273(NULL::uuid,NULL::jsonb,NULL::jsonb,NULL::jsonb,NULL::jsonb,NULL::date) AS annotation;")
 reject_unchanged('recovery_later_dependency_is_atomic',statement,'depend')
 sql('DROP VIEW public.later_dependency;');sql(recovery(read_lease(),receipt,base));passed('recovery_after_dependency_removed')
 base=reset();receipt=apply(base);fresh=read_lease();statement=recovery(fresh,receipt,base)
 sql("CREATE FUNCTION public.later_textual_caller() RETURNS jsonb LANGUAGE sql AS $$ SELECT public.lts_card_payment_refresh_annotation_v273(NULL::uuid,NULL::jsonb,NULL::jsonb,NULL::jsonb,NULL::jsonb,NULL::date) $$;")
 reject_unchanged('recovery_later_textual_caller_is_atomic',statement,'later textual caller adopted projector')
 sql('DROP FUNCTION public.later_textual_caller();');sql(recovery(read_lease(),receipt,base));passed('recovery_after_textual_caller_removed')
 base=reset();receipt=apply(base);fresh=read_lease();statement=recovery(fresh,receipt,base)
 sql(f"COMMENT ON FUNCTION {E.PROJECTOR} IS 'synthetic non-body annotation';") # comments are harmless/not part of lease
 sql(f"ALTER FUNCTION {E.PROJECTOR} STABLE;")
 reject_unchanged('recovery_projector_attribute_drift',statement,'lease changed')
 try:recovery(read_lease(),receipt,base)
 except AssertionError:passed('recovery_refuses_fresh_lease_that_legitimizes_drift')
 else:raise AssertionError('Recovery accepted divergent installation receipt')
 base=reset("CREATE FUNCTION public.unexpected_epoch_effect() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RETURN NEW; END $$; CREATE TRIGGER unexpected_epoch_effect BEFORE UPDATE ON public.lts_read_cache_epoch_v242 FOR EACH ROW EXECUTE FUNCTION public.unexpected_epoch_effect();")
 reject_unchanged('epoch_trigger_forbidden',E.render(base),'epoch must have no unreviewed trigger effects')
 receipt={'status':'passed','cases':len(RESULTS),'results':RESULTS,'production_contacted':False,'private_evidence_in_package':False,'template_sha256':hashlib.sha256((HERE/'build_envelope.py').read_bytes()).hexdigest(),'projector_sha256':E.PINNED['payment-refresh-annotation.sql']}
 (OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt,indent=2))
except Exception as e:
 (OUT/'receipt.json').write_text(json.dumps({'status':'failed','passed_cases':RESULTS,'error':str(e)},indent=2)+'\n');raise
finally:
 (OUT/'execution-log.json').write_text(json.dumps(LOG,indent=2)+'\n')
