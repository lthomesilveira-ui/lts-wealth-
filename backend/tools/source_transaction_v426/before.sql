BEGIN READ ONLY;
SET LOCAL ROLE service_role;
DO $test$
DECLARE payload jsonb;
BEGIN
 PERFORM set_config('qa_v426.engine_calls','0',true);
 payload:=public.lts_open_finance_sources_v226(public.lts_open_finance_pilot_owner_v1(),current_date-365,current_date);
 IF payload IS DISTINCT FROM(SELECT b.payload FROM qa_v426.baseline b) THEN RAISE EXCEPTION 'Read-only payload differs';END IF;
 PERFORM public.lts_open_finance_sources_v226(public.lts_open_finance_pilot_owner_v1(),current_date-365,current_date);
 IF current_setting('qa_v426.engine_calls')::int<>6 THEN RAISE EXCEPTION 'Expected repeated uncached nested engines: %',current_setting('qa_v426.engine_calls');END IF;
 IF EXISTS(SELECT FROM public.lts_v229_read_cache) THEN RAISE EXCEPTION 'READ ONLY unexpectedly persisted a memo';END IF;
 RAISE NOTICE 'PASS: old POST transaction reproduces six engine calls, equal payload, no memo writes';
END $test$;
ROLLBACK;
