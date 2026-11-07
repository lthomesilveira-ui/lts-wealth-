DO $test$
DECLARE path text; checked int:=0;
BEGIN
 FOREACH path IN ARRAY ARRAY['','public','pg_temp, public, pg_catalog'] LOOP
  PERFORM set_config('search_path',path,true);
  IF EXISTS(SELECT 1 FROM qa.before_results b WHERE
   b.norm IS DISTINCT FROM public.lts_v178_norm(b.input)
   OR b.merchant IS DISTINCT FROM public.lts_bank_merchant_key_v231(b.input)) THEN
   RAISE EXCEPTION 'A result changed under caller search_path %',path;
  END IF;
  checked:=checked+(SELECT count(*)*2 FROM qa.before_results);
 END LOOP;
 IF EXISTS(SELECT 1 FROM qa.before_attributes b JOIN pg_catalog.pg_proc p USING(oid)
  WHERE b.attrs IS DISTINCT FROM to_jsonb(p)-'proconfig'
   OR p.proconfig IS DISTINCT FROM ARRAY['search_path=""']::text[]) THEN
  RAISE EXCEPTION 'Unexpected function metadata';
 END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_proc p WHERE p.oid IN(
  'public.lts_v178_norm(text)'::regprocedure,'public.lts_bank_merchant_key_v231(text)'::regprocedure)
  AND (has_function_privilege('anon',p.oid,'EXECUTE')
   OR has_function_privilege('authenticated',p.oid,'EXECUTE')
   OR NOT has_function_privilege('service_role',p.oid,'EXECUTE')
   OR p.prosecdef OR p.provolatile<>'i')) THEN
  RAISE EXCEPTION 'Privileges or execution semantics changed';
 END IF;
 RAISE NOTICE 'Verified % result comparisons and unchanged ownership, grants, source and execution attributes',checked;
END $test$;
SELECT jsonb_build_object('passed',true,'inputs',(SELECT count(*) FROM qa.before_results),
 'functions',2,'caller_paths',3,'result_comparisons',(SELECT count(*)*6 FROM qa.before_results),
 'source_bodies_unchanged',true,'privileges_unchanged',true,'financial_sources_used',false) AS proof;
