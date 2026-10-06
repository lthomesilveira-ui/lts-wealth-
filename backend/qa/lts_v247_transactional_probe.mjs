// Build an operator-only migration probe. Candidate DDL, cache writes and
// financial fixtures all roll back inside one subtransaction; only its
// private validation report and migration receipt persist. No owner IDs.
import fs from 'node:fs';
import assert from 'node:assert/strict';
const root = 'backend/patches/';
const names = ['corrected_cash_memo_v247.sql', 'read_only_memo_safety_v247.sql',
  'read_only_future_fallback_v247.sql', 'documentary_cache_dependencies_v247.sql'];
const patches = names.map(name => fs.readFileSync(root + name, 'utf8'));
const future = patches[2];
const firstCreate = future.slice(future.indexOf('CREATE OR REPLACE FUNCTION'), future.indexOf('\nREVOKE'));
const baseline = firstCreate.replace('lts_flow_future_read_slice_v9_pre_v247(', 'lts_flow_future_read_slice_v9(').trim().replace(/;\s*$/, '').trim();
const qa = fs.readFileSync('backend/qa/lts_v247_cash_rollback.sql', 'utf8');
const qaBody = qa.slice(qa.indexOf('DO $qa$'), qa.indexOf("SELECT current_setting('lts.qa_results_v247')"));
const flowQa = fs.readFileSync('backend/qa/lts_v247_full_flow_probe.sql', 'utf8');
assert(qaBody.endsWith('END $qa$;\n'));
assert(!/\b(?:BEGIN;|COMMIT;|ROLLBACK;)\b/.test(qaBody));
const quote = value => "'" + value.replaceAll("'", "''") + "'";
const fingerprint = `(SELECT md5(jsonb_agg(jsonb_build_array(p.oid::regprocedure::text,pg_get_functiondef(p.oid),p.proacl::text) ORDER BY p.oid::regprocedure::text)::text) FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.prokind='f')`;
const query = `
SET LOCAL lock_timeout='1500ms';
SET LOCAL statement_timeout='45s';
SET LOCAL timezone='America/Sao_Paulo';
SET LOCAL jit='off';
CREATE TABLE IF NOT EXISTS public.lts_v247_validation_report (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 report jsonb NOT NULL
);
ALTER TABLE public.lts_v247_validation_report ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_v247_validation_report FROM PUBLIC,anon,authenticated,service_role;
DO $probe$
DECLARE before_hash text; after_hash text; report jsonb; started timestamptz:=clock_timestamp();
BEGIN
 before_hash:=${fingerprint};
 BEGIN
  IF btrim(pg_get_functiondef('public.lts_flow_future_read_slice_v9(uuid,date,date)'::regprocedure),E' \\t\\r\\n')<>${quote(baseline)} THEN
   RAISE EXCEPTION 'future slice baseline changed; do not apply hardcoded snapshot';
  END IF;
  ${patches.map(patch => 'EXECUTE ' + quote(patch) + ';').join('\n  ')}
  EXECUTE ${quote(qaBody)};
  report:=current_setting('lts.qa_results_v247')::jsonb||jsonb_build_object('status','PASS');
  EXECUTE ${quote(flowQa)};
  report:=report||jsonb_build_object('full_flow',current_setting('lts.qa_full_flow_v247')::jsonb);
  RAISE EXCEPTION USING ERRCODE='P2471',MESSAGE='rollback all V247 candidate DDL and fixtures';
 EXCEPTION
  WHEN SQLSTATE 'P2471' THEN NULL;
  WHEN query_canceled THEN report:=jsonb_build_object('status','FAIL','sqlstate',SQLSTATE,'error',SQLERRM);
  WHEN OTHERS THEN report:=jsonb_build_object('status','FAIL','sqlstate',SQLSTATE,'error',SQLERRM);
 END;
 after_hash:=${fingerprint};
 IF before_hash IS DISTINCT FROM after_hash OR to_regprocedure('public.lts_corrected_cashflow_fix86_v1_engine_v247(uuid,date,date)') IS NOT NULL THEN
  RAISE EXCEPTION 'probe rollback did not restore original functions';
 END IF;
 report:=coalesce(report,'{}')||jsonb_build_object('candidate_ddl_rolled_back',true,'function_definitions_and_acls_restored',true,
  'duration_ms',round(extract(epoch FROM(clock_timestamp()-started))*1000,1),'checked_at',clock_timestamp());
 INSERT INTO public.lts_v247_validation_report(report) VALUES(report);
END $probe$;
`;
process.stdout.write(JSON.stringify({query}));
