DO $empty$ BEGIN
 IF current_setting('server_version_num')::int NOT BETWEEN 170000 AND 179999 THEN RAISE EXCEPTION 'PG17 required'; END IF;
 IF to_regnamespace('public') IS NULL OR to_regnamespace('auth') IS NOT NULL
 OR EXISTS(SELECT 1 FROM pg_depend d WHERE d.refclassid='pg_namespace'::regclass AND d.refobjid=to_regnamespace('public'))
 OR EXISTS(SELECT 1 FROM pg_class c WHERE c.relnamespace=to_regnamespace('public'))
 OR EXISTS(SELECT 1 FROM pg_proc p WHERE p.pronamespace=to_regnamespace('public'))
 OR EXISTS(SELECT 1 FROM pg_type t WHERE t.typnamespace=to_regnamespace('public'))
 OR EXISTS(SELECT 1 FROM pg_extension e WHERE e.extnamespace=to_regnamespace('public'))
 THEN RAISE EXCEPTION 'empty disposable database required: public contains preexisting objects'; END IF;
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname IN('fixture_owner','service_role','anon','authenticated')) THEN RAISE EXCEPTION 'fresh disposable roles required'; END IF;
END $empty$;
