// Only a private receipt persists. Candidate DDL and staged synthetic data roll back.
import fs from 'node:fs';
const quote = value => "'" + value.replaceAll("'", "''") + "'";
const patch = fs.readFileSync('backend/patches/card_snapshot_upsert_v249.sql','utf8');
const qa = fs.readFileSync('backend/qa/lts_v249_staging_rollback.sql','utf8');
const fingerprint = `(SELECT md5(jsonb_agg(jsonb_build_array(p.oid::regprocedure::text,pg_get_functiondef(p.oid),p.proacl::text) ORDER BY p.oid::regprocedure::text)::text) FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.prokind='f')`;
const query = `
SET LOCAL lock_timeout='1500ms'; SET LOCAL statement_timeout='45s'; SET LOCAL jit='off';
CREATE TABLE IF NOT EXISTS public.lts_v249_validation_report (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),report jsonb NOT NULL
);
ALTER TABLE public.lts_v249_validation_report ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_v249_validation_report FROM PUBLIC,anon,authenticated,service_role;
DO $probe$
DECLARE before_hash text; after_hash text; report jsonb; started timestamptz:=clock_timestamp();
BEGIN
 before_hash:=${fingerprint};
 BEGIN
  EXECUTE ${quote(patch)};
  EXECUTE ${quote(qa)};
  report:=current_setting('lts.qa_v249')::jsonb;
  RAISE EXCEPTION USING ERRCODE='P2491',MESSAGE='rollback candidate DDL and all staged fixtures';
 EXCEPTION WHEN SQLSTATE 'P2491' THEN NULL;
  WHEN query_canceled THEN report:=jsonb_build_object('status','FAIL','sqlstate',SQLSTATE,'error',SQLERRM);
  WHEN OTHERS THEN report:=jsonb_build_object('status','FAIL','sqlstate',SQLSTATE,'error',SQLERRM);
 END;
 after_hash:=${fingerprint};
 IF before_hash IS DISTINCT FROM after_hash THEN RAISE EXCEPTION 'candidate definitions/ACLs not restored'; END IF;
 IF EXISTS(SELECT 1 FROM public.lts_open_finance_staging WHERE provider_record_id like '%:v249-qa-%')
 OR EXISTS(SELECT 1 FROM public.lts_open_finance_observation WHERE provider_record_id like '%:v249-qa-%')
 THEN RAISE EXCEPTION 'synthetic fixtures persisted'; END IF;
 report:=report||jsonb_build_object('candidate_ddl_rolled_back',true,'function_definitions_and_acls_restored',true,
  'fixtures_absent',true,'duration_ms',round(extract(epoch FROM(clock_timestamp()-started))*1000,1));
 INSERT INTO public.lts_v249_validation_report(report) VALUES(report);
END $probe$;`;
process.stdout.write(JSON.stringify({query}));
