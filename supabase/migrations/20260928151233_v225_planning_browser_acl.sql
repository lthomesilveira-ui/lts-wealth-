REVOKE EXECUTE ON FUNCTION public.lts_browser_planning_executive_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_planning_executive_v2() TO authenticated, service_role;
DO $$ BEGIN IF has_function_privilege('anon','public.lts_browser_planning_executive_v2()','EXECUTE') OR NOT has_function_privilege('authenticated','public.lts_browser_planning_executive_v2()','EXECUTE') THEN RAISE EXCEPTION 'Planning browser access boundary mismatch'; END IF; END $$;
