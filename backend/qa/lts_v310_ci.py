"""Verify existing documentary payment reuse in an isolated PostgreSQL database."""
from pathlib import Path
import json,subprocess,sys
from lts_v310_invalid_cases import CASES,ASSERTION
from lts_v309_invalid_cases import CASES as PRIOR_CASES,ASSERTION as PRIOR_ASSERTION

ROOT=Path(__file__).resolve().parents[2]
def run(sql,success=True):
 r=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1'],input=sql,text=True,capture_output=True)
 if success and r.returncode:raise RuntimeError(r.stderr)
 if not success and not r.returncode:raise RuntimeError('Guarded rejection did not occur')
 return r.stdout.strip()

# The prior suite seeds the original fixture and proves the V309 baseline.
subprocess.run([sys.executable,str(ROOT/'backend/qa/lts_v309_ci.py')],check=True)
run((ROOT/'backend/qa/v310_fixture_extension.sql').read_text()+(ROOT/'backend/qa/v310_posted_dependency.sql').read_text())
assert run("SELECT public.lts_commitment_read_state_v309('00000000-0000-4000-8000-000000000001','2020-10-24')#>>'{volvo,confirmed_loaded_paid_count}';")=='0','Regression fixture must reproduce omitted documentary payment'
definition=run("SELECT jsonb_build_object('definition',pg_get_functiondef('public.lts_commitment_read_state_v309(uuid,date)'::regprocedure));")
patch=subprocess.check_output([sys.executable,str(ROOT/'backend/tools/build_contract_patch_v310.py')],input=definition,text=True)
attrs_sql="SELECT jsonb_build_object('oid',oid,'owner',proowner,'acl',proacl,'config',proconfig,'definer',prosecdef,'volatility',provolatile) FROM pg_proc WHERE oid='public.lts_commitment_read_state_v309(uuid,date)'::regprocedure;"
before=run(attrs_sql);run('BEGIN;'+patch+'COMMIT;');assert before==run(attrs_sql)
run((ROOT/'backend/qa/lts_v310_contract_cases.sql').read_text())
run((ROOT/'backend/qa/lts_v309_contract_cases.sql').read_text())
for label,mutation in CASES:
 try:run('BEGIN;'+mutation+ASSERTION+'ROLLBACK;')
 except Exception as error:raise RuntimeError(label) from error
for label,mutation in PRIOR_CASES:
 try:run('BEGIN;'+mutation+PRIOR_ASSERTION+'ROLLBACK;')
 except Exception as error:raise RuntimeError('Prior mortgage evidence: '+label) from error
run((ROOT/'backend/qa/lts_v310_second_installment_case.sql').read_text())

# A bank payment already visible through both supported paths is still one fact.
run((ROOT/'backend/qa/lts_v310_dedup_case.sql').read_text())

digest_sql="SELECT md5(string_agg(pg_get_functiondef(oid),'|' ORDER BY oid)) FROM pg_proc WHERE oid='public.lts_commitment_read_state_v309(uuid,date)'::regprocedure OR proname LIKE '%v310';"
digest=run(digest_sql);run('BEGIN;'+patch+'COMMIT;');assert digest==run(digest_sql)
for signature,body in [('public.lts_commitment_read_state_v309(p_user_id uuid,p_as_of date)',"RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $$SELECT '{}'::jsonb$$"),('public.lts_documentary_contract_payments_v310(p_user_id uuid,p_as_of date)',"RETURNS TABLE(financial_event_id uuid,staging_id uuid,paid_date date,paid_amount numeric) LANGUAGE sql STABLE SET search_path='' AS $$SELECT NULL::uuid,NULL::uuid,NULL::date,NULL::numeric WHERE false$$")]:
 run('BEGIN;CREATE OR REPLACE FUNCTION '+signature+' '+body+';'+patch,success=False)
 assert digest==run(digest_sql),'Rejected drift changed a definition'
qa=ROOT/'qa/v310';qa.mkdir(parents=True,exist_ok=True)
(qa/'native-wealth.json').write_text(run('SELECT public.lts_browser_wealth_detail_v242();'))
print(json.dumps({'pass':True,'prior_v309_suite':True,'reused_existing_documentary_payment':True,'negative_documentary_proofs':len(CASES),'mortgage_proofs_rechecked':len(PRIOR_CASES),'earlier_exact_bank_contract_installment_recognized':True,'direct_and_documentary_same_payment_counted_once':True,'owner_and_private_grants':True,'future_counts_and_other_contracts_preserved':True,'nominal_and_actual_dates_distinct':True,'existing_oid_acl_owner_config_exact':True,'exact_replay':True,'drift_rejections':2,'production_data_used':False}))
