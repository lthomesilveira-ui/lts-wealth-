-- Preserve the new dated loan input and public index evidence in the existing
-- selective daily supplement. Retention, capture dates and schedule stay intact.
CREATE OR REPLACE FUNCTION public.lts_backup_family_extend_v398(p_user_id uuid,p_base jsonb)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $fn$
WITH tables AS(
 SELECT coalesce(p_base->'tables','{}')||jsonb_build_object(
 'lts_family_loan_v398',coalesce((SELECT jsonb_agg(to_jsonb(l) ORDER BY commitment_id) FROM public.lts_family_loan_v398 l WHERE user_id=p_user_id),'[]'),
 'lts_savings_rate_v398',coalesce((SELECT jsonb_agg(to_jsonb(r) ORDER BY period_start) FROM public.lts_savings_rate_v398 r
  WHERE r.period_start>=(SELECT min(starts_on) FROM public.lts_family_loan_v398 WHERE user_id=p_user_id)),'[]')) j
)
SELECT p_base||jsonb_build_object('tables',t.j,'coverage',coalesce(p_base->'coverage','{}')||jsonb_build_object(
 'selected_tables',(SELECT count(*) FROM jsonb_object_keys(t.j)),
 'indexed_family_loan_inputs',true,'full_restore_tested',false),
 'schema_columns',coalesce(p_base->'schema_columns','[]')||coalesce((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.table_name,c.ordinal_position)
 FROM information_schema.columns c WHERE c.table_schema='public' AND c.table_name IN('lts_family_loan_v398','lts_savings_rate_v398')),'[]')) FROM tables t;
$fn$;
REVOKE ALL ON FUNCTION public.lts_backup_family_extend_v398(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_backup_family_extend_v398(uuid,jsonb) TO service_role;
DO $patch$
DECLARE body text;
BEGIN
 SELECT prosrc INTO body FROM pg_proc WHERE oid='public.lts_backup_modern_export_v380(uuid)'::regprocedure;
 IF position('v398-family-backup' IN body)>0 THEN RETURN;END IF;
 IF position('lts-modern-supplement-v380' IN body)=0 THEN RAISE EXCEPTION 'V398 backup source changed; inspect first';END IF;
 body:=regexp_replace(trim(body),';\s*$','');
 EXECUTE 'CREATE OR REPLACE FUNCTION public.lts_backup_modern_export_v380(p_user_id uuid) RETURNS jsonb LANGUAGE sql STABLE SET search_path=''pg_catalog'',''public'' AS $v398$'
  ||E'\n-- v398-family-backup\nWITH previous(payload) AS MATERIALIZED ('||body||') SELECT public.lts_backup_family_extend_v398(p_user_id,payload) FROM previous;$v398$';
END $patch$;
