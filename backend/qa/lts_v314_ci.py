"""An archived card snapshot is superseded only by a complete classified received bill."""
from pathlib import Path
import subprocess,json,hashlib
ROOT=Path(__file__).resolve().parents[2]
U='00000000-0000-4000-8000-000000000001';OTHER='00000000-0000-4000-8000-000000000002'
def run(sql,success=True):
 r=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1'],input=sql,text=True,capture_output=True)
 if success and r.returncode:raise RuntimeError(r.stderr)
 if not success and not r.returncode:raise AssertionError('Expected drift rejection')
 return r.stdout.strip()
schema=r"""
CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;
CREATE TABLE public.card_invoices(id uuid,user_id uuid,card_name text,reference_month date,due_date date,amount numeric,status text,metadata jsonb);
CREATE TABLE public.lts_open_finance_staging(id uuid,user_id uuid,resource_type text,currency text,provider_deleted_at timestamptz,institution_code text,provider_account_ref text,normalized_payload jsonb,posting_date date,signed_amount numeric);
CREATE TABLE public.v314_rows(source_id uuid,user_id uuid,family text,reference_month date,due_date date,amount numeric,is_payment boolean,category text,category_basis text,bill_id text);
CREATE FUNCTION public.lts_card_source_rows_v226(uuid) RETURNS SETOF public.v314_rows LANGUAGE sql STABLE AS $$SELECT * FROM public.v314_rows WHERE user_id=$1$$;
CREATE FUNCTION public.lts_v178_norm(text) RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT lower(trim($1))$$;
CREATE FUNCTION public.lts_card_family_v1(text,text) RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT CASE WHEN lower($1) LIKE '%aeternum%' THEN 'aeternum' ELSE lower($1) END$$;
CREATE FUNCTION public.lts_card_settlement_detail_core_v1(uuid,date,text,numeric,text) RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT '{"matched":false,"detail_complete":false}'::jsonb$$;
"""
prior=(ROOT/'backend/qa/v314_prior_overlay.sql').read_text();patch=(ROOT/'backend/patches/v314/superseded_card_review.sql').read_text()
assert hashlib.md5(prior.encode()).hexdigest()=='743ae1ea19766a285dbfde10f08dc1d1'
run(schema+prior+';'+prior.replace('FUNCTION public.lts_card_classification_current_overlay_v1(', 'FUNCTION public.lts_card_classification_pre_v314(',1)+';')
run("REVOKE ALL ON FUNCTION public.lts_card_classification_current_overlay_v1(uuid,jsonb,integer) FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION public.lts_card_classification_current_overlay_v1(uuid,jsonb,integer) TO service_role;")
attrs=run("SELECT(to_jsonb(p)-'prosrc')::text FROM pg_proc p WHERE oid='public.lts_card_classification_current_overlay_v1(uuid,jsonb,integer)'::regprocedure;")
run(f"""INSERT INTO public.card_invoices VALUES('00000000-0000-4000-8000-000000000101','{U}','Visa Aeternum','2026-09-01','2026-09-25',300,'closed',
'{{"legacy_detail_snapshot_id":"fixture-archived","legacy_detail_snapshot_is_current":false,"document_amount_verified":true,"detail_reconciled_to_cycle_total":true,"items":[{{"amount":100}},{{"amount":100}},{{"amount":100}}]}}');
INSERT INTO public.lts_open_finance_staging VALUES('00000000-0000-4000-8000-000000000201','{U}','invoice','BRL',NULL,'237','fixture-account','{{"provider_id":"fixture-bill"}}','2026-09-25',300);""")
for n in [1,2,3]:
 uid=f'00000000-0000-4000-8000-{n:012d}'
 run(f"INSERT INTO public.lts_open_finance_staging VALUES('{uid}','{U}','card_transaction','BRL',NULL,'237','fixture-account','{{}}','2026-09-25',-100);INSERT INTO public.v314_rows VALUES('{uid}','{U}','aeternum','2026-09-01','2026-09-25',100,false,'Restaurantes','exact_source_decision','fixture-bill');")
review=dict(items=[dict(invoice_id='fixture-archived',due_date='2026-09-25',card_name='Visa Aeternum',description_key='fixture-one',total_value=50,occurrences=1),dict(invoice_id='fixture-archived',due_date='2026-09-25',card_name='Visa Aeternum',description_key='fixture-two',total_value=10,occurrences=1)],invoices=[dict(invoice_id='fixture-archived',due_date='2026-09-25',card_name='Visa Aeternum',pending_groups=2,pending_lines=2,pending_value=60)])
payload=json.dumps(review);call=lambda name:f"SELECT public.{name}('{U}','{payload}'::jsonb,50);"
before=json.loads(run(call('lts_card_classification_current_overlay_v1')));assert before['pending_lines']==2
run(patch);after=json.loads(run(call('lts_card_classification_current_overlay_v1')));assert after['pending_lines']==0 and after['items']==[]
run(patch)
assert attrs==run("SELECT(to_jsonb(p)-'prosrc')::text FROM pg_proc p WHERE oid='public.lts_card_classification_current_overlay_v1(uuid,jsonb,integer)'::regprocedure;")
finger="SELECT jsonb_build_object('staging',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.lts_open_finance_staging s),'invoices',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.card_invoices s),'classifications',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY source_id)::text) FROM public.v314_rows s));"
fp=run(finger);run(call('lts_card_classification_current_overlay_v1'));assert fp==run(finger)
guards=[
 "UPDATE public.card_invoices SET metadata=jsonb_set(metadata,'{legacy_detail_snapshot_is_current}','true');",
 "UPDATE public.card_invoices SET metadata=metadata-'document_amount_verified';",
 "UPDATE public.card_invoices SET metadata=jsonb_set(metadata,'{items}','[{\"amount\":100}]');",
 "UPDATE public.card_invoices SET metadata=jsonb_set(metadata,'{items}','{}');",
 "UPDATE public.v314_rows SET category='A classificar',category_basis='unresolved' WHERE source_id='00000000-0000-4000-8000-000000000001';",
 "UPDATE public.v314_rows SET amount=101 WHERE source_id='00000000-0000-4000-8000-000000000001';",
 "UPDATE public.lts_open_finance_staging SET signed_amount=299 WHERE resource_type='invoice';",
 "UPDATE public.lts_open_finance_staging SET currency='USD' WHERE resource_type='invoice';",
 "UPDATE public.lts_open_finance_staging SET provider_deleted_at=now() WHERE resource_type='card_transaction' AND id='00000000-0000-4000-8000-000000000001';",
 f"UPDATE public.lts_open_finance_staging SET user_id='{OTHER}' WHERE resource_type='invoice';",
 "UPDATE public.lts_open_finance_staging SET provider_account_ref='different-account' WHERE resource_type='invoice';",
 "UPDATE public.v314_rows SET is_payment=true WHERE source_id='00000000-0000-4000-8000-000000000001';",
 "UPDATE public.v314_rows SET bill_id='another-bill' WHERE source_id='00000000-0000-4000-8000-000000000001';"
]
for change in guards:
 r=json.loads(run('BEGIN;'+change+call('lts_card_classification_current_overlay_v1')+'ROLLBACK;'));assert r['pending_lines']==2,change
assert run(f"SELECT count(*) FROM public.lts_card_review_superseded_snapshots_v314('{OTHER}');")=='0'
run('BEGIN;'+prior.replace('declare c','declare /* drift */ c',1)+';'+patch+'ROLLBACK;',False)
assert run("SELECT NOT prosecdef AND NOT has_function_privilege('anon',oid,'EXECUTE') AND NOT has_function_privilege('authenticated',oid,'EXECUTE') FROM pg_proc WHERE oid='public.lts_card_review_superseded_snapshots_v314(uuid)'::regprocedure;")=='t'
print(json.dumps(dict(passed=True,engine='postgresql17',archived_pending_before=2,after=0,strict_rejections=len(guards),old_source_rows_unchanged=True,oid_owner_acl_config_exact=True,replay_and_drift_checked=True,production_data_used=False)))
