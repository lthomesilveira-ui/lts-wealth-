-- Restore the exact V403 exporter. Stored snapshots and the private helper are untouched.
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
DO $guard$
BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.lts_backup_modern_export_v380(uuid)'::regprocedure)
  NOT IN ('5773d7dca5fd7d31f84c54dccc4c5f1d','dc53800722b4c965dc0df629ff7453a9') THEN
  RAISE EXCEPTION 'Backup exporter changed; review before rollback';
 END IF;
END $guard$;
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
 'coverage',(b.j->'coverage')||jsonb_build_object('selected_tables',35,'position_observation_scope','daily_position_cohorts_and_verified_cofrinho_days',
 'all_observation_history',false,'verified_resource_mapping',true,'capture_transaction_isolation',current_setting('transaction_isolation'),'capture_kind',coalesce(nullif(current_setting('lts.backup_capture_kind',true),''),'unspecified'),'sync_history_scope','Staging references plus preserved daily position cohorts'),
 'schema_columns',(b.j->'schema_columns')||(SELECT j FROM schemas))FROM base b CROSS JOIN evidence e;
$function$;
