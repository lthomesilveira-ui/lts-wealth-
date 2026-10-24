"""Run the real generic contract patch against an isolated PostgreSQL fixture.

The actual realized-bank reader is retained. Only its unrelated partial-payment
branch is explicitly doubled false. No production source or credential is read.
"""
from pathlib import Path
import json
import subprocess
import sys
from lts_v309_invalid_cases import CASES, ASSERTION

ROOT=Path(__file__).resolve().parents[2]
def run(sql,success=True):
 result=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1'],input=sql,text=True,capture_output=True)
 if success and result.returncode:raise RuntimeError(result.stderr)
 if not success and not result.returncode:raise RuntimeError('Expected guarded rejection did not occur')
 return result.stdout.strip()

run((ROOT/'backend/qa/v309_fixture.sql').read_text()+(ROOT/'backend/qa/v309_realized_dependency.sql').read_text())
definitions=json.loads(run("SELECT jsonb_object_agg(signature,pg_get_functiondef(to_regprocedure(signature))) FROM(VALUES('public.lts_commitments_summary_v1(uuid,date)'),('public.lts_documentary_commitments_v1(uuid)'),('public.lts_browser_wealth_detail_v242()')) t(signature);"))
patch=subprocess.check_output([sys.executable,str(ROOT/'backend/tools/build_contract_patch_v309.py')],input=json.dumps(definitions),text=True)
attributes=run("SELECT jsonb_agg(jsonb_build_object('oid',oid,'owner',proowner,'acl',proacl,'definer',prosecdef,'config',proconfig,'volatility',provolatile) ORDER BY oid) FROM pg_proc WHERE oid IN('public.lts_commitments_summary_v1(uuid,date)'::regprocedure,'public.lts_documentary_commitments_v1(uuid)'::regprocedure,'public.lts_browser_wealth_detail_v242()'::regprocedure);")
run('BEGIN;'+patch+'COMMIT;')
run((ROOT/'backend/qa/lts_v309_contract_cases.sql').read_text())
after=run("SELECT jsonb_agg(jsonb_build_object('oid',oid,'owner',proowner,'acl',proacl,'definer',prosecdef,'config',proconfig,'volatility',provolatile) ORDER BY oid) FROM pg_proc WHERE oid IN('public.lts_commitments_summary_v1(uuid,date)'::regprocedure,'public.lts_documentary_commitments_v1(uuid)'::regprocedure,'public.lts_browser_wealth_detail_v242()'::regprocedure);")
assert attributes==after,'Original security/identity attributes changed'
for label,mutation in CASES:
 try:run('BEGIN;'+mutation+ASSERTION+'ROLLBACK;')
 except Exception as error:raise RuntimeError(label) from error
digest_sql="SELECT md5(string_agg(pg_get_functiondef(oid),'|' ORDER BY oid)) FROM pg_proc WHERE proname LIKE '%v309' OR oid IN('public.lts_commitments_summary_v1(uuid,date)'::regprocedure,'public.lts_documentary_commitments_v1(uuid)'::regprocedure,'public.lts_browser_wealth_detail_v242()'::regprocedure);"
before=run(digest_sql);run('BEGIN;'+patch+'COMMIT;');assert before==run(digest_sql),'Replay changed a definition'
run("BEGIN;CREATE OR REPLACE FUNCTION public.lts_commitments_summary_v1(p_user_id uuid,p_as_of date DEFAULT CURRENT_DATE) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='public' AS $$SELECT '{}'::jsonb$$;"+patch,success=False)
assert before==run(digest_sql),'Rejected drift escaped rollback'
run("BEGIN;CREATE OR REPLACE FUNCTION public.lts_commitment_read_state_v309(p_user_id uuid,p_as_of date) RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $$SELECT '{}'::jsonb$$;"+patch,success=False)
assert before==run(digest_sql),'Rejected helper drift escaped rollback'
print(json.dumps({'pass':True,'base_assertions':14,'rejected_financial_evidence':len(CASES),'definition_drift_rejected':2,'replay_exact':True,'original_oid_acl_owner_config_exact':True,'private_helper_grants':True,'production_data_used':False}))
