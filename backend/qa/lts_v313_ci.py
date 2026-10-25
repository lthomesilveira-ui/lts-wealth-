"""Compare the unchanged pending-projection logic with one materialized operational read."""
from pathlib import Path
import json,subprocess,hashlib

ROOT=Path(__file__).resolve().parents[2]
U='00000000-0000-4000-8000-000000000001';OTHER='00000000-0000-4000-8000-000000000002'
def run(sql,success=True):
 r=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1'],input="SET timezone='America/Sao_Paulo';SET jit=off;"+sql,text=True,capture_output=True)
 if success and r.returncode:raise RuntimeError(r.stderr)
 if not success and not r.returncode:raise AssertionError('Expected definition drift rejection')
 return r.stdout.strip()
schema=r"""
CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;
CREATE TABLE public.accounts(user_id uuid,id uuid,institution text,is_active boolean,metadata jsonb);
CREATE TABLE public.financial_events(user_id uuid,id uuid,legacy_id text,event_date date,amount numeric,is_projection boolean,is_suppressed boolean);
CREATE TABLE public.lts_open_finance_staging(user_id uuid,id uuid,resource_type text,institution_code text,currency text,provider_deleted_at timestamptz,
 normalized_payload jsonb,occurred_at timestamptz,posting_date date,provider_account_ref text,signed_amount numeric,raw_hash text,description_raw text);
CREATE TABLE public.lts_v229_documentary_match(user_id uuid,source_ref text,staging_id uuid,signed_amount numeric,bank text,canonical_date date,evidence jsonb);
CREATE TABLE public.v313_operational(user_id uuid,items jsonb);
CREATE TABLE public.v313_calls(user_id uuid,calls int);
CREATE TABLE public.v313_payroll(user_id uuid,projection_ref text);
CREATE TABLE public.v313_fgts(user_id uuid,source_id uuid,receipt jsonb);
CREATE TABLE public.v313_legacy(user_id uuid,source_ref text);
CREATE FUNCTION public.lts_flow_operational_read_v229(uuid,date,date) RETURNS jsonb LANGUAGE plpgsql VOLATILE AS $$BEGIN
 UPDATE public.v313_calls SET calls=calls+1 WHERE user_id=$1;
 IF $2 IS NULL THEN RAISE EXCEPTION 'An absent anchor must not initiate an operational read';END IF;
 RETURN coalesce((SELECT jsonb_agg(x) FROM public.v313_operational f CROSS JOIN LATERAL jsonb_array_elements(f.items)x
 WHERE f.user_id=$1 AND (x->>'event_date')::date BETWEEN $2 AND $3),'[]');END$$;
CREATE FUNCTION public.lts_bank_posted_rows_v231(uuid) RETURNS SETOF public.lts_open_finance_staging LANGUAGE sql STABLE AS $$SELECT * FROM public.lts_open_finance_staging WHERE user_id=$1 AND resource_type='transaction'$$;
CREATE FUNCTION public.lts_payroll_bank_matches_v231(uuid) RETURNS TABLE(projection_ref text) LANGUAGE sql STABLE AS $$SELECT projection_ref FROM public.v313_payroll WHERE user_id=$1$$;
CREATE FUNCTION public.lts_bank_fgts_combined_receipt_v261(uuid,uuid) RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT receipt FROM public.v313_fgts WHERE user_id=$1 AND source_id=$2$$;
CREATE FUNCTION public.lts_flow_classification_decision_v1(uuid,jsonb) RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT $2||jsonb_build_object('category',coalesce($2->>'category','Teste'))$$;
CREATE FUNCTION public.lts_legacy_mastercard_settled_v291(uuid,jsonb) RETURNS boolean LANGUAGE sql STABLE AS $$SELECT EXISTS(SELECT 1 FROM public.v313_legacy WHERE user_id=$1 AND source_ref=$2->>'source_ref')$$;
CREATE FUNCTION public.lts_card_invoice_settled_v290(uuid,text,date,date,numeric) RETURNS boolean LANGUAGE sql STABLE AS $$SELECT $2='c6' AND $5=400$$;
"""
prior=(ROOT/'backend/qa/v313_prior_pending.sql').read_text();patch=(ROOT/'backend/patches/v313/pending_operational_once.sql').read_text()
assert hashlib.md5(prior.encode()).hexdigest()=='ec25065ddf4749c747127a41c3eb8764'
run(schema+prior+';'+prior.replace('FUNCTION public.lts_pending_projections_v233(', 'FUNCTION public.lts_pending_projections_pre_v313(',1)+';')
run("REVOKE ALL ON FUNCTION public.lts_pending_projections_v233(uuid) FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION public.lts_pending_projections_v233(uuid) TO service_role;")
attrs=run("SELECT (to_jsonb(p)-'prosrc')::text FROM pg_proc p WHERE oid='public.lts_pending_projections_v233(uuid)'::regprocedure;")
run(patch);assert attrs==run("SELECT (to_jsonb(p)-'prosrc')::text FROM pg_proc p WHERE oid='public.lts_pending_projections_v233(uuid)'::regprocedure;")
run(patch)
uid=lambda n:f'00000000-0000-4000-8000-{n:012d}'
run(f"INSERT INTO public.v313_calls VALUES('{U}',0),('{OTHER}',0);")
for n,bank,code in [(101,'Itaú','341'),(102,'Bradesco','237'),(103,'C6','336')]:
 run(f"""INSERT INTO public.accounts VALUES('{U}','{uid(n)}','{bank}',true,jsonb_build_object('evidence_sha256',repeat('a',64),'balance_as_of',(current_date-30)::text));
 INSERT INTO public.lts_open_finance_staging VALUES('{U}','{uid(n)}','balance','{code}','BRL',NULL,jsonb_build_object('account_type','CHECKING_ACCOUNT','provider_account_id','{bank}','as_of',now()::text),now(),current_date,'{bank}',0,repeat('a',64),'Posição');""")
def event(ref,bank,amount,days,source='current_event',confidence='documented_scheduled',**extra):
 return dict(source_ref=ref,account=bank,signed_amount=amount,days=days,source=source,confidence=confidence,description=ref,**extra)
events=[event('unsettled-a','Itaú',-100,4),event('unsettled-b','Bradesco',-220,2,source='card_invoice'),
 event('matched-bank','C6',-50,3),event('matched-document','C6',-55,4),event('payroll-forecast','Itaú',3000,3),
 event('fgts-principal','Itaú',100,2),event('fgts-jam','Itaú',10,2),event('mastercard|legacy-settled','Itaú',-300,2,source='card_invoice'),
 event('c6|settled-invoice','C6',-400,2,source='card_invoice'),event('plain-unposted','Bradesco',-80,3,confidence='untrusted'),
 event('bank-confirmed','C6',-70,2,bank_confirmed=True),event('anchor-day','Itaú',-10,30),event('foreign-bank','Outro',-12,2),event('future','Itaú',-13,-2)]
rows=[]
for e in events:
 days=e.pop('days');raw=json.dumps(e,ensure_ascii=False).replace("'","''")
 rows.append(f"jsonb_build_object('event_date',(current_date-({days}))::text)||'{raw}'::jsonb")
run(f"INSERT INTO public.v313_operational VALUES('{U}',jsonb_build_array("+','.join(rows)+f"));INSERT INTO public.v313_operational VALUES('{OTHER}','[]');")
run(f"""INSERT INTO public.financial_events VALUES('{U}','{uid(201)}','unsettled-a',current_date-4,-100,true,false),('{U}','{uid(202)}','plain-unposted',current_date-3,-80,true,false);
INSERT INTO public.v313_payroll VALUES('{U}','payroll-forecast');INSERT INTO public.v313_legacy VALUES('{U}','mastercard|legacy-settled');
INSERT INTO public.v313_fgts VALUES('{U}','{uid(303)}','{{"projection_refs":["fgts-principal","fgts-jam"]}}');""")
for n,bank,code,days,amount,desc in [(301,'C6','336',3,-50,'matched-bank'),(302,'C6','336',3,-55,'Pagamento confirmado'),(303,'Itaú','341',2,110,'Recebimento combinado')]:
 run(f"INSERT INTO public.lts_open_finance_staging VALUES('{U}','{uid(n)}','transaction','{code}','BRL',NULL,jsonb_build_object('account_type','CHECKING_ACCOUNT','status','POSTED','provider_account_id','{bank}'),now()-interval '{days} days',current_date-{days},'{bank}',{amount},repeat('a',64),'{desc}');")
run(f"INSERT INTO public.lts_v229_documentary_match VALUES('{U}','matched-document','{uid(302)}',-55,'C6',current_date-4,jsonb_build_object('basis','owner_confirmed_exact_obligation','raw_hash',repeat('a',64),'actual_posting_date',(current_date-3)::text));ANALYZE;")
def compare(label,setup='',expect_calls=1,expected_refs=None):
 if setup:run(setup)
 result={}
 for version in ['pre_v313','v233']:
  run(f"UPDATE public.v313_calls SET calls=0;")
  payload=json.loads(run(f"SELECT public.lts_pending_projections_{version}('{U}');"))
  calls=int(run(f"SELECT calls FROM public.v313_calls WHERE user_id='{U}';"));result[version]=(payload,calls)
 assert result['pre_v313'][0]==result['v233'][0],label
 assert result['v233'][1]==expect_calls,(label,result)
 if expected_refs is not None:assert {e['source_ref'] for e in result['v233'][0]}==set(expected_refs),(label,result)
 return dict(case=label,pass_=True,old_calls=result['pre_v313'][1],new_calls=result['v233'][1],pending=len(result['v233'][0]))
results=[compare('all_receipt_guards',expected_refs=['unsettled-a','unsettled-b','plain-unposted'])]
results.append(compare('missing_fgts_proof',"DELETE FROM public.v313_fgts;",expected_refs=['unsettled-a','unsettled-b','plain-unposted','fgts-principal','fgts-jam']))
results.append(compare('changed_document_source',"UPDATE public.lts_v229_documentary_match SET evidence=jsonb_set(evidence,'{raw_hash}',to_jsonb(repeat('b',64)));",expected_refs=['unsettled-a','unsettled-b','plain-unposted','fgts-principal','fgts-jam','matched-document']))
results.append(compare('single_anchor',"UPDATE public.accounts SET is_active=false WHERE institution<>'Itaú';"))
results.append(compare('no_anchors',"UPDATE public.accounts SET is_active=false;",expect_calls=0,expected_refs=[]))
run('BEGIN;'+prior.replace('WITH anchors AS','WITH /* drift */ anchors AS',1)+';'+patch+'ROLLBACK;',False)
assert attrs==run("SELECT (to_jsonb(p)-'prosrc')::text FROM pg_proc p WHERE oid='public.lts_pending_projections_v233(uuid)'::regprocedure;")
assert run("SELECT md5(pg_get_functiondef('public.lts_pending_projections_v233(uuid)'::regprocedure));")=='36e3321d535eb10a5e04a376d635a2a6'
assert json.loads(run(f"SELECT public.lts_pending_projections_v233('{OTHER}');"))==[]
assert run("SELECT NOT has_function_privilege('anon','public.lts_pending_projections_v233(uuid)','EXECUTE') AND NOT has_function_privilege('authenticated','public.lts_pending_projections_v233(uuid)','EXECUTE');")=='t'
print(json.dumps(dict(pass_=True,engine='postgresql17',results=results,definition_drift_rejected=True,oid_acl_owner_config_exact=True,production_data_used=False)))
