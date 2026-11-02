DO $guard$BEGIN
IF position('v403-critical-source-backup' IN pg_get_functiondef('public.lts_backup_modern_export_v380(uuid)'::regprocedure))=0 AND position('v401-complete-backup-manifest' IN pg_get_functiondef('public.lts_backup_modern_export_v380(uuid)'::regprocedure))=0 AND 'lts_backup_modern_export_v380'<>'lts_backup_modern_export_v380' THEN RAISE EXCEPTION 'V401 predecessor required: lts_backup_modern_export_v380';END IF;
IF position('v403-critical-source-backup' IN pg_get_functiondef('public.lts_backup_bundle_read_v380(uuid,date)'::regprocedure))=0 AND position('v401-complete-backup-manifest' IN pg_get_functiondef('public.lts_backup_bundle_read_v380(uuid,date)'::regprocedure))=0 AND 'lts_backup_bundle_read_v380'<>'lts_backup_modern_export_v380' THEN RAISE EXCEPTION 'V401 predecessor required: lts_backup_bundle_read_v380';END IF;
IF position('v403-critical-source-backup' IN pg_get_functiondef('public.lts_backup_snapshot_take_v380(uuid,date)'::regprocedure))=0 AND position('v401-complete-backup-manifest' IN pg_get_functiondef('public.lts_backup_snapshot_take_v380(uuid,date)'::regprocedure))=0 AND 'lts_backup_snapshot_take_v380'<>'lts_backup_modern_export_v380' THEN RAISE EXCEPTION 'V401 predecessor required: lts_backup_snapshot_take_v380';END IF;
END $guard$;

CREATE OR REPLACE FUNCTION public.lts_backup_position_sources_v403(p_user uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path=pg_catalog AS $function$
WITH cohorts AS MATERIALIZED(
 SELECT DISTINCT ON(r.connection_id,(r.started_at AT TIME ZONE 'America/Sao_Paulo')::date)r.id
 FROM public.lts_open_finance_sync_run r
 WHERE r.user_id=p_user AND r.status='success' AND r.started_at<=statement_timestamp()
 ORDER BY r.connection_id,(r.started_at AT TIME ZONE 'America/Sao_Paulo')::date,r.started_at DESC,r.id DESC
), positions AS MATERIALIZED(
 SELECT o.* FROM cohorts c JOIN public.lts_open_finance_observation o ON o.sync_run_id=c.id
 WHERE o.user_id=p_user AND o.resource_type IN('balance','investment','loan') AND o.observed_at<=statement_timestamp()
)
SELECT jsonb_build_object('observations',coalesce((SELECT jsonb_agg(to_jsonb(o)ORDER BY o.id)FROM positions o),'[]'),
 'runs',coalesce((SELECT jsonb_agg(to_jsonb(r)ORDER BY r.id)FROM public.lts_open_finance_sync_run r
 WHERE r.user_id=p_user AND r.id IN(SELECT sync_run_id FROM positions)),'[]'),
 'mapping',coalesce((SELECT jsonb_agg(to_jsonb(m)ORDER BY m.id)FROM public.lts_open_finance_resource_map m WHERE m.user_id=p_user),'[]'));
$function$;
CREATE OR REPLACE FUNCTION public.lts_backup_manifest_valid_v403(p_payload jsonb,p_counts jsonb)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog AS $function$
DECLARE reduced jsonb;reduced_counts jsonb;actual jsonb;n int;
BEGIN
 IF jsonb_typeof(p_payload->'tables')IS DISTINCT FROM'object'OR jsonb_typeof(p_counts)IS DISTINCT FROM'object'THEN RETURN false;END IF;
 SELECT count(*)INTO n FROM jsonb_each(p_payload->'tables');
 IF n<>35 THEN RETURN public.lts_backup_manifest_valid_v401(p_payload,p_counts);END IF;
 IF jsonb_typeof(p_payload#>'{tables,lts_open_finance_resource_map}')IS DISTINCT FROM'array'
 OR jsonb_typeof(p_payload#>'{tables,lts_open_finance_observation}')IS DISTINCT FROM'array'
 OR p_payload#>>'{coverage,position_observation_scope}'IS DISTINCT FROM'last_successful_collection_per_bank_and_civil_day'
 OR p_payload#>'{coverage,all_observation_history}'IS DISTINCT FROM'false'::jsonb
 OR p_payload#>'{coverage,verified_resource_mapping}'IS DISTINCT FROM'true'::jsonb
 OR p_payload#>'{coverage,selected_tables}'IS DISTINCT FROM'35'::jsonb THEN RETURN false;END IF;
 IF EXISTS(SELECT 1 FROM jsonb_each(p_payload->'tables')WHERE jsonb_typeof(value)<>'array')THEN RETURN false;END IF;
 SELECT jsonb_object_agg(key,jsonb_array_length(value))INTO actual FROM jsonb_each(p_payload->'tables');
 IF actual IS DISTINCT FROM p_counts THEN RETURN false;END IF;
 reduced:=jsonb_set(p_payload,'{tables}',(p_payload->'tables')-ARRAY['lts_open_finance_resource_map','lts_open_finance_observation']);
 reduced:=jsonb_set(reduced,'{coverage,selected_tables}','33');
 reduced_counts:=p_counts-ARRAY['lts_open_finance_resource_map','lts_open_finance_observation'];
 RETURN public.lts_backup_manifest_valid_v401(reduced,reduced_counts);
END $function$;

DO $patch$
DECLARE d text;export_def text:=pg_get_functiondef('public.lts_backup_modern_export_v380(uuid)'::regprocedure);
BEGIN
 IF position('v403-critical-source-backup'IN export_def)=0 THEN
  IF position('v398-family-backup'IN export_def)=0 THEN RAISE EXCEPTION 'V398 family backup predecessor required';END IF;
  EXECUTE replace(export_def,'FUNCTION public.lts_backup_modern_export_v380(','FUNCTION public.lts_backup_modern_export_pre_v403(');
 END IF;
END $patch$;
CREATE OR REPLACE FUNCTION public.lts_backup_modern_export_v380(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path=pg_catalog AS $function$
-- v403-critical-source-backup
WITH base AS MATERIALIZED(SELECT public.lts_backup_modern_export_pre_v403(p_user_id)j),
 evidence AS MATERIALIZED(SELECT public.lts_backup_position_sources_v403(p_user_id)j),
 runs AS(SELECT coalesce(jsonb_agg(source_row ORDER BY source_row->>'id'),'[]')j FROM(
  SELECT x.value AS source_row FROM base b CROSS JOIN LATERAL jsonb_array_elements(b.j#>'{tables,lts_open_finance_sync_run}')AS x(value)
  UNION
  SELECT x.value AS source_row FROM evidence e CROSS JOIN LATERAL jsonb_array_elements(e.j->'runs')AS x(value)
 )s),schemas AS(
 SELECT coalesce(jsonb_agg(to_jsonb(c)ORDER BY c.table_schema,c.table_name,c.ordinal_position),'[]')j
 FROM information_schema.columns c WHERE c.table_schema='public'AND c.table_name IN('lts_open_finance_resource_map','lts_open_finance_observation')
)
SELECT b.j||jsonb_build_object('tables',(b.j->'tables')||jsonb_build_object(
 'lts_open_finance_sync_run',(SELECT j FROM runs),'lts_open_finance_resource_map',e.j->'mapping','lts_open_finance_observation',e.j->'observations'),
 'coverage',(b.j->'coverage')||jsonb_build_object('selected_tables',35,'position_observation_scope','last_successful_collection_per_bank_and_civil_day',
 'all_observation_history',false,'verified_resource_mapping',true,'capture_transaction_isolation',current_setting('transaction_isolation'),'sync_history_scope','Staging references plus preserved daily position cohorts'),
 'schema_columns',(b.j->'schema_columns')||(SELECT j FROM schemas))FROM base b CROSS JOIN evidence e;
$function$;
DO $patch$
DECLARE d text;
BEGIN
 d:=pg_get_functiondef('public.lts_backup_snapshot_take_v380(uuid,date)'::regprocedure);
 IF position('v403-critical-source-backup'IN d)=0 THEN
  IF position('if v_n<>33 or not public.lts_backup_manifest_valid_v401(j,v_counts)'IN d)=0 THEN RAISE EXCEPTION 'V401 writer changed';END IF;
  EXECUTE replace(d,'if v_n<>33 or not public.lts_backup_manifest_valid_v401(j,v_counts)','-- v403-critical-source-backup'||chr(10)||' if v_n<>35 or not public.lts_backup_manifest_valid_v403(j,v_counts)');
 END IF;
 d:=pg_get_functiondef('public.lts_backup_bundle_read_v380(uuid,date)'::regprocedure);
 IF position('v403-critical-source-backup'IN d)=0 THEN
  IF position('if not public.lts_backup_manifest_valid_v401(s.payload,s.counts)'IN d)=0 THEN RAISE EXCEPTION 'V401 reader changed';END IF;
  EXECUTE replace(d,'if not public.lts_backup_manifest_valid_v401(s.payload,s.counts)','-- v403-critical-source-backup'||chr(10)||' if not public.lts_backup_manifest_valid_v403(s.payload,s.counts)');
 END IF;
END $patch$;
REVOKE ALL ON FUNCTION public.lts_backup_position_sources_v403(uuid),public.lts_backup_manifest_valid_v403(jsonb,jsonb),public.lts_backup_modern_export_pre_v403(uuid)FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_backup_position_sources_v403(uuid),public.lts_backup_manifest_valid_v403(jsonb,jsonb),public.lts_backup_modern_export_pre_v403(uuid)TO service_role;
