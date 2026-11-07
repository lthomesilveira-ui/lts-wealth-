-- The service-only source reader calls existing derived memo writers.
-- POSTgREST executes POST/STABLE as READ ONLY, preventing those memo fills.
-- Preserve the exact reader, financial engines, ACL, owner and configuration.
BEGIN;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='8s';
DO $patch$
DECLARE target regprocedure:='public.lts_open_finance_sources_v226(uuid,date,date)'::regprocedure;
 before_attrs jsonb; after_attrs jsonb; source_hash text;
BEGIN
 SELECT to_jsonb(p),md5(p.prosrc) INTO before_attrs,source_hash
 FROM pg_catalog.pg_proc p WHERE p.oid=target;
 IF source_hash<>'e739a5d976b0c1c6bf8c1be88437d7e0'
  OR before_attrs->>'provolatile' NOT IN ('s','v')
  OR (before_attrs->>'prosecdef')::boolean
  OR has_function_privilege('anon',target,'EXECUTE')
  OR has_function_privilege('authenticated',target,'EXECUTE')
  OR NOT has_function_privilege('service_role',target,'EXECUTE') THEN
  RAISE EXCEPTION 'Unexpected source reader predecessor or privileges; review before applying';
 END IF;
 IF before_attrs->>'provolatile'='s' THEN
  ALTER FUNCTION public.lts_open_finance_sources_v226(uuid,date,date) VOLATILE;
 END IF;
 SELECT to_jsonb(p) INTO after_attrs FROM pg_catalog.pg_proc p WHERE p.oid=target;
 IF (before_attrs-'provolatile') IS DISTINCT FROM (after_attrs-'provolatile')
  OR after_attrs->>'provolatile'<>'v' THEN
  RAISE EXCEPTION 'Unexpected source body, owner, configuration or privilege change';
 END IF;
END $patch$;
NOTIFY pgrst,'reload schema';
COMMIT;
