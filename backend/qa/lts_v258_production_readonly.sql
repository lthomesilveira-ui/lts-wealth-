BEGIN READ ONLY;SET LOCAL TimeZone='America/Sao_Paulo';SET LOCAL jit=off;SET LOCAL statement_timeout='90s';
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
DO $engine$ DECLARE j jsonb;BEGIN
 j:=public.lts_browser_expenses_v229_engine_v251('2026-01-01',current_date);
 PERFORM set_config('lts.v258_expected_expense_digest',md5(j::text),true);
 PERFORM set_config('lts.v258_expected_epoch',(SELECT epoch::text FROM public.lts_read_cache_epoch_v242 WHERE singleton),true);
END $engine$;
SET LOCAL ROLE authenticated;
DO $verify$ DECLARE t timestamptz;j jsonb;receipt jsonb:='{}';BEGIN
 t:=clock_timestamp();j:=public.lts_browser_expenses_v229('2026-01-01',current_date);
 receipt:=receipt||jsonb_build_object('expenses',jsonb_build_object('ms',extract(epoch FROM clock_timestamp()-t)*1000,'digest',md5(j::text),'summary',j->'summary'));
 IF md5(j::text) IS DISTINCT FROM current_setting('lts.v258_expected_expense_digest') THEN RAISE EXCEPTION 'V258_PRODUCTION_EXPENSE_CHANGED';END IF;
 t:=clock_timestamp();j:=public.lts_browser_flow_v242('2026-01-01','2027-12-31');
 receipt:=receipt||jsonb_build_object('flow',jsonb_build_object('ms',extract(epoch FROM clock_timestamp()-t)*1000,'digest',md5(j::text),'days',jsonb_array_length(j#>'{flow,historical,days}')+jsonb_array_length(j#>'{flow,current_future,days}')));
 IF jsonb_array_length(j#>'{flow,historical,days}')+jsonb_array_length(j#>'{flow,current_future,days}')<>730 THEN RAISE EXCEPTION 'V258_PRODUCTION_DAY_COUNT';END IF;
 t:=clock_timestamp();j:=public.lts_browser_flow_v242('2028-02-01','2028-02-02');
 receipt:=receipt||jsonb_build_object('readonly_outside_regular_range',jsonb_build_object('ms',extract(epoch FROM clock_timestamp()-t)*1000,'digest',md5(j::text),'days',jsonb_array_length(j#>'{flow,historical,days}')+jsonb_array_length(j#>'{flow,current_future,days}')));
 IF jsonb_array_length(j#>'{flow,historical,days}')+jsonb_array_length(j#>'{flow,current_future,days}')<>2 THEN RAISE EXCEPTION 'V258_PRODUCTION_READONLY_DAY_COUNT';END IF;
 PERFORM set_config('lts.v258_production',receipt::text,true);
END $verify$;
RESET ROLE;
DO $epoch$ BEGIN
 IF current_setting('lts.v258_expected_epoch') IS DISTINCT FROM (SELECT epoch::text FROM public.lts_read_cache_epoch_v242 WHERE singleton) THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during verification';END IF;
END $epoch$;
SELECT now() checked_at,current_setting('transaction_read_only') read_only,current_setting('lts.v258_production')::jsonb receipt;ROLLBACK;
