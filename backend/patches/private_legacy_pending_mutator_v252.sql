-- Disable external execution of an unused, unauthenticated legacy mutator.
-- Do not invoke it, change its body, or reconcile any financial event.
DO $lease$ BEGIN
 IF md5(btrim(pg_get_functiondef('public.lts_open_finance_reconcile_pending_cards_v1()'::regprocedure),E' \t\r\n'))<>'db9093cb45584a35e54592b674f3b35d' THEN RAISE EXCEPTION 'V252_LEGACY_SOURCE_LEASE_CHANGED';END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.oid<>'public.lts_open_finance_reconcile_pending_cards_v1()'::regprocedure AND p.prosrc ILIKE '%lts_open_finance_reconcile_pending_cards_v1%')
 OR EXISTS(SELECT 1 FROM cron.job WHERE command ILIKE '%lts_open_finance_reconcile_pending_cards_v1%') THEN RAISE EXCEPTION 'V252_UNEXPECTED_LEGACY_CALLER';END IF;
END $lease$;
REVOKE ALL ON FUNCTION public.lts_open_finance_reconcile_pending_cards_v1() FROM PUBLIC,anon,authenticated,service_role;
DO $verify$ BEGIN
 IF has_function_privilege('anon','public.lts_open_finance_reconcile_pending_cards_v1()','EXECUTE')
 OR has_function_privilege('authenticated','public.lts_open_finance_reconcile_pending_cards_v1()','EXECUTE')
 OR has_function_privilege('service_role','public.lts_open_finance_reconcile_pending_cards_v1()','EXECUTE') THEN RAISE EXCEPTION 'V252_EXTERNAL_EXECUTION_REMAINS';END IF;
 IF md5(btrim(pg_get_functiondef('public.lts_open_finance_reconcile_pending_cards_v1()'::regprocedure),E' \t\r\n'))<>'db9093cb45584a35e54592b674f3b35d' THEN RAISE EXCEPTION 'V252_LEGACY_BODY_CHANGED';END IF;
END $verify$;

