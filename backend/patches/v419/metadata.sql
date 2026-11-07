DO $metadata$ BEGIN
 IF EXISTS(SELECT 1 FROM v419_before b JOIN pg_proc p USING(oid)
 WHERE b.attributes IS DISTINCT FROM to_jsonb(p)-'prosrc')
 THEN RAISE EXCEPTION 'Execution attributes changed'; END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='lts_fgts_private_v419' AND
 (has_function_privilege('anon',p.oid,'EXECUTE') OR has_function_privilege('authenticated',p.oid,'EXECUTE')))
 THEN RAISE EXCEPTION 'Private helper privileges exposed'; END IF;
END $metadata$;
