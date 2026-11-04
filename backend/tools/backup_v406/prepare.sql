-- Synthetic fixtures only. Retain the actual V403 exporter as the parity oracle.
-- Sequence deparsing depends on search_path; exercise both schema metadata scopes.
CREATE SEQUENCE public.fixture_reconciliation_id_v406;
ALTER TABLE public.lts_reconciliation_link ALTER COLUMN id
 SET DEFAULT nextval('public.fixture_reconciliation_id_v406');
CREATE SEQUENCE public.fixture_mapping_id_v406;
ALTER TABLE public.lts_open_finance_resource_map ALTER COLUMN id
 SET DEFAULT nextval('public.fixture_mapping_id_v406');
DO $copy$
BEGIN
 EXECUTE replace(pg_get_functiondef('public.lts_backup_modern_export_v380(uuid)'::regprocedure),
  'FUNCTION public.lts_backup_modern_export_v380(',
  'FUNCTION public.qa_backup_before_v406(');
END $copy$;

CREATE TABLE public.qa_backup_contract_v406 AS
SELECT (SELECT to_jsonb(proacl) FROM pg_proc
 WHERE oid='public.lts_backup_modern_export_v380(uuid)'::regprocedure) AS exporter_acl,
 (SELECT jsonb_agg(to_jsonb(j) ORDER BY jobid) FROM cron.job j) AS jobs,
 (SELECT jsonb_object_agg(proname,md5(pg_get_functiondef(oid))) FROM pg_proc
 WHERE pronamespace='public'::regnamespace AND proname LIKE 'lts_backup_%'
 AND proname<>'lts_backup_modern_export_v380') AS unchanged_functions;
