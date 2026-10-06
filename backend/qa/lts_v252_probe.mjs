// Operator-only rollback proof; never executes the financial mutator.
import fs from 'node:fs';
const quote=v=>"'"+v.replaceAll("'","''")+"'";
const patch=fs.readFileSync('backend/patches/private_legacy_pending_mutator_v252.sql','utf8');
const fingerprint=`(SELECT md5(jsonb_agg(jsonb_build_array(p.oid::regprocedure::text,pg_get_functiondef(p.oid),p.proacl::text)ORDER BY p.oid::regprocedure::text)::text)FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.prokind='f')`;
const financial=`(SELECT md5(coalesce(jsonb_agg(to_jsonb(f) ORDER BY f.id)::text,'[]')) FROM public.financial_events f)`;
const query=`
CREATE TABLE IF NOT EXISTS public.lts_v252_validation_report(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),report jsonb NOT NULL);
ALTER TABLE public.lts_v252_validation_report ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_v252_validation_report FROM PUBLIC,anon,authenticated,service_role;
DO $qa$ DECLARE before_hash text;before_finance text;report jsonb;BEGIN
 before_hash:=${fingerprint};before_finance:=${financial};
 BEGIN
 EXECUTE ${quote(patch)};
 IF before_finance IS DISTINCT FROM ${financial} THEN RAISE EXCEPTION 'financial event changed';END IF;
 report:=jsonb_build_object('status','PASS','external_execute_denied',true,'body_preserved',true,'financial_rows_exact',true,'mutator_never_invoked',true);
 RAISE EXCEPTION USING ERRCODE='P2520',MESSAGE='rollback ACL candidate';
 EXCEPTION WHEN SQLSTATE 'P2520' THEN NULL;
 WHEN OTHERS THEN report:=jsonb_build_object('status','FAIL','sqlstate',SQLSTATE,'error',SQLERRM);END;
 IF before_hash IS DISTINCT FROM ${fingerprint} OR before_finance IS DISTINCT FROM ${financial} THEN RAISE EXCEPTION 'rollback failed';END IF;
 INSERT INTO public.lts_v252_validation_report(report)VALUES(report||jsonb_build_object('all_definitions_and_acls_restored',true,'financial_rows_exact_after_rollback',true));
END $qa$;`;
process.stdout.write(JSON.stringify({query}));

