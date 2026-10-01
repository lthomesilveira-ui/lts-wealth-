DO $guard$ DECLARE definition text; BEGIN
 SELECT pg_get_functiondef('public.lts_browser_flow_v229(date,date)'::regprocedure) INTO definition;
 definition:=replace(definition,' -- Past/current projections are not posted cash. Retain them for review, never erase.',
 $replacement$ -- A realized payroll replaces its matched forecast even when an older cache exists.
 SELECT coalesce(jsonb_agg(x),'[]') INTO recent FROM jsonb_array_elements(recent) x
 WHERE NOT EXISTS(SELECT 1 FROM public.lts_payroll_bank_matches_v231(u) pm WHERE pm.projection_ref=x->>'source_ref');
 -- Past/current projections are not posted cash. Retain them for review, never erase.$replacement$);
 EXECUTE definition;
END $guard$;
-- Disposable read caches only; financial source records and decisions are unchanged.
DELETE FROM public.lts_v229_read_cache;
DELETE FROM public.lts_flow_future_read_cache_v2;
NOTIFY pgrst,'reload schema';
