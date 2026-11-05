-- Roll back readers only. Owner policy, evidence, complete reference snapshots,
-- source records and audit history remain intact for recovery and review.
BEGIN;
DO $rollback$
DECLARE original oid:=to_regprocedure('public.lts_corrected_cashflow_operational_v1(uuid,date,date)');
 saved oid:=to_regprocedure('lts_projection_private_v412.base_flow(uuid,date,date)');definition text;
BEGIN
 IF saved IS NULL THEN RAISE EXCEPTION 'V412 saved predecessor is unavailable';END IF;
 definition:=replace(pg_get_functiondef(saved),'FUNCTION lts_projection_private_v412.base_flow(',
  'FUNCTION public.lts_corrected_cashflow_operational_v1(');
 IF md5(definition)<>'0a687b1bf642ab20cdadfb96ec0f0bed'
  THEN RAISE EXCEPTION 'V412 saved predecessor changed';END IF;
 IF md5(pg_get_functiondef(original)) NOT IN('0a687b1bf642ab20cdadfb96ec0f0bed','5ba5df8823c2986f3d94cee05433abe9')
  THEN RAISE EXCEPTION 'Operational reader changed after V412';END IF;
 IF md5(pg_get_functiondef(to_regprocedure('public.lts_recurring_maintenance_v366()')))
  NOT IN('64fe0a7ace2fb8a4d3b78e4ec7b5def9','07d6c08ee1044ff79e2243cd78cf23db')
  THEN RAISE EXCEPTION 'Recurring maintenance changed after V412';END IF;
 EXECUTE definition;
END $rollback$;
CREATE OR REPLACE FUNCTION public.lts_recurring_maintenance_v366()
 RETURNS jsonb LANGUAGE plpgsql SET search_path TO '' SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid;results jsonb:='[]';BEGIN FOR u IN SELECT DISTINCT user_id FROM public.lts_recurring_plan_v366 WHERE active AND value_kind='fixed' LOOP results:=results||jsonb_build_array(public.lts_recurring_materialize_v366(u,current_date));END LOOP;RETURN results;END $function$;
-- Do not advertise a projected budget after its flow integration was removed.
-- Reapplying the migration restores both authenticated wrappers.
CREATE OR REPLACE FUNCTION public.lts_browser_projection_policy_v412()
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $f$
 SELECT jsonb_build_object('version','projection-policy-v412','enabled',false)
$f$;
CREATE OR REPLACE FUNCTION public.lts_browser_projection_refresh_v412()
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $f$
 SELECT jsonb_build_object('version','projection-policy-v412','enabled',false)
$f$;
DO $cache$
DECLARE owner_id uuid;
BEGIN
 FOR owner_id IN SELECT usuario_id FROM public.legacy_namespace WHERE chave='lts_owner_projection_policy_v412'
 LOOP PERFORM lts_projection_private_v412.invalidate_reads(owner_id);END LOOP;
END $cache$;
COMMIT;
