BEGIN;
TRUNCATE public.lts_v229_read_cache;
SET LOCAL ROLE service_role;
DO $test$
DECLARE payload jsonb; attrs jsonb;
BEGIN
 PERFORM set_config('qa_v426.engine_calls','0',true);
 payload:=public.lts_open_finance_sources_v226(public.lts_open_finance_pilot_owner_v1(),current_date-365,current_date);
 IF payload IS DISTINCT FROM(SELECT b.payload FROM qa_v426.baseline b) THEN RAISE EXCEPTION 'Cold payload changed';END IF;
 IF current_setting('qa_v426.engine_calls')::int<>1 THEN RAISE EXCEPTION 'Nested engine was not shared';END IF;
 PERFORM public.lts_open_finance_sources_v226(public.lts_open_finance_pilot_owner_v1(),current_date-365,current_date);
 IF current_setting('qa_v426.engine_calls')::int<>1 THEN RAISE EXCEPTION 'Warm read recalculated';END IF;
 IF (SELECT count(*) FROM public.lts_v229_read_cache)<>2 THEN RAISE EXCEPTION 'Expected only the two derived memos';END IF;
 IF qa_v426.financial_signature()<>(SELECT financial_signature FROM qa_v426.baseline) THEN RAISE EXCEPTION 'Financial sources changed';END IF;
 IF payload::text LIKE '%other-user%' THEN RAISE EXCEPTION 'Foreign owner leaked';END IF;
 SELECT to_jsonb(p) INTO attrs FROM pg_proc p WHERE oid='public.lts_open_finance_sources_v226(uuid,date,date)'::regprocedure;
 IF attrs->>'provolatile'<>'v' OR (attrs-'provolatile') IS DISTINCT FROM(SELECT b.attrs-'provolatile' FROM qa_v426.baseline b) THEN
  RAISE EXCEPTION 'Body, owner, privileges or configuration changed';
 END IF;
 BEGIN
  PERFORM public.lts_open_finance_sources_v226('00000000-0000-0000-0000-000000000002',current_date-1,current_date);
  RAISE EXCEPTION 'Foreign owner was accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'PILOT_OWNER_MISMATCH' THEN RAISE;END IF;END;
 BEGIN
  PERFORM public.lts_open_finance_sources_v226(public.lts_open_finance_pilot_owner_v1(),current_date-366,current_date);
  RAISE EXCEPTION 'Oversized window was accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'SOURCE_WINDOW_MAX_366_DAYS' THEN RAISE;END IF;END;
 BEGIN
  PERFORM public.lts_open_finance_sources_v226(public.lts_open_finance_pilot_owner_v1(),NULL,current_date);
  RAISE EXCEPTION 'Null window was accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'SOURCE_WINDOW_MAX_366_DAYS' THEN RAISE;END IF;END;
 IF has_function_privilege('anon','public.lts_open_finance_sources_v226(uuid,date,date)','EXECUTE')
  OR has_function_privilege('authenticated','public.lts_open_finance_sources_v226(uuid,date,date)','EXECUTE') THEN RAISE EXCEPTION 'Source reader became public';END IF;
 RAISE NOTICE 'PASS: equal cold/warm payload, one engine call, two derived memos, unchanged sources and attributes, isolated owner, guarded windows and roles';
END $test$;
RESET ROLE;
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1;
SET LOCAL ROLE service_role;
DO $test$
BEGIN
 PERFORM public.lts_open_finance_sources_v226(public.lts_open_finance_pilot_owner_v1(),current_date-365,current_date);
 IF current_setting('qa_v426.engine_calls')::int<>2 THEN RAISE EXCEPTION 'Epoch invalidation failed';END IF;
END $test$;
RESET ROLE;
UPDATE public.lts_v229_read_cache SET refreshed_at=clock_timestamp()-interval '6 minutes';
SET LOCAL ROLE service_role;
DO $test$
BEGIN
 PERFORM public.lts_open_finance_sources_v226(public.lts_open_finance_pilot_owner_v1(),current_date-365,current_date);
 IF current_setting('qa_v426.engine_calls')::int<>3 THEN RAISE EXCEPTION 'TTL invalidation failed';END IF;
 RAISE NOTICE 'PASS: existing source epoch and five-minute expiry both invalidate the memos';
END $test$;
ROLLBACK;
