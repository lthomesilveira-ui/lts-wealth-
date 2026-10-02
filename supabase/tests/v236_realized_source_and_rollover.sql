-- Read-only financial contracts. Run with the authorized maintenance JWT in a
-- transaction, then ROLLBACK. No private owner, amount or source ID is embedded.
DO $test$
DECLARE
 u uuid:=public.lts_browser_assert_user_v1(); full_flow jsonb; sliced jsonb; d jsonb; prev jsonb; c jsonb; bank_name text;
 v record; realized jsonb; debit_day jsonb; prior_day jsonb; one_day jsonb; expected_count integer;
BEGIN
 full_flow:=public.lts_browser_flow_v229(current_date,current_date+29)->'flow';
 sliced:=public.lts_browser_flow_v229(current_date+1,current_date+7)->'flow';
 FOR d IN SELECT x FROM jsonb_array_elements(full_flow#>'{current_future,days}') x ORDER BY x->>'date' LOOP
  c:=d->'fix86_columns';
  IF abs((c->>'saldo_final')::numeric-(c->>'saldo_anterior')::numeric-coalesce((c->>'entradas')::numeric,0)+coalesce((c->>'saidas')::numeric,0))>.005 THEN RAISE EXCEPTION 'daily cash arithmetic failed';END IF;
  IF abs((c->>'saldo_final')::numeric-(d#>>'{Itaú,balance}')::numeric-(d#>>'{Bradesco,balance}')::numeric-(d#>>'{C6,balance}')::numeric)>.005 THEN RAISE EXCEPTION 'bank total differs from consolidated';END IF;
  IF abs((c->>'saldo_apos_d0_1')::numeric-(c->>'saldo_final')::numeric-(c->>'liq_d0_1_recurso')::numeric)>.005
   OR abs((c->>'saldo_apos_rsu')::numeric-(c->>'saldo_apos_d0_1')::numeric-(c->>'rsus_vested')::numeric)>.005
   OR abs((c->>'saldo_apos_fgts')::numeric-(c->>'saldo_apos_rsu')::numeric-(c->>'fgts')::numeric)>.005 THEN RAISE EXCEPTION 'availability layers failed';END IF;
  IF prev IS NOT NULL THEN
   IF abs((prev#>>'{fix86_columns,saldo_final}')::numeric-(c->>'saldo_anterior')::numeric)>.005 THEN RAISE EXCEPTION 'consolidated closing does not carry';END IF;
   FOREACH bank_name IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
    IF abs((prev#>>ARRAY[bank_name,'balance'])::numeric+coalesce((d#>>ARRAY[bank_name,'net'])::numeric,0)-(d#>>ARRAY[bank_name,'balance'])::numeric)>.005 THEN RAISE EXCEPTION 'bank closing does not carry';END IF;
   END LOOP;
  END IF;
  prev:=d;
 END LOOP;
 IF EXISTS(
  SELECT x->>'date',x->'fix86_columns' FROM jsonb_array_elements(sliced#>'{current_future,days}') x
  EXCEPT
  SELECT x->>'date',x->'fix86_columns' FROM jsonb_array_elements(full_flow#>'{current_future,days}') x
 ) THEN RAISE EXCEPTION 'future-only selection changes the calculated position';END IF;
 FOR v IN SELECT * FROM public.lts_realized_bank_sources_v238(u) WHERE event_date<current_date LOOP
  realized:=public.lts_browser_flow_v229(v.event_date-1,v.event_date)->'flow';
  SELECT x INTO prior_day FROM jsonb_array_elements(realized#>'{historical,days}') x WHERE (x->>'date')::date=v.event_date-1;
  SELECT x INTO debit_day FROM jsonb_array_elements(realized#>'{historical,days}') x WHERE (x->>'date')::date=v.event_date;
  one_day:=public.lts_browser_flow_v229(v.event_date,v.event_date)#>'{flow,historical,days,0}';
  IF NOT (debit_day#>>'{v170_cash_arithmetic,balanced}')::boolean OR abs((prior_day#>>ARRAY[v.bank,'balance'])::numeric+(debit_day#>>ARRAY[v.bank,'net'])::numeric-(debit_day#>>ARRAY[v.bank,'balance'])::numeric)>.005 THEN RAISE EXCEPTION 'realized debit does not reconcile dated positions';END IF;
  IF one_day->'fix86_columns'<>debit_day->'fix86_columns' THEN RAISE EXCEPTION 'one-day source selection changes its cash position';END IF;
  SELECT count(*) INTO expected_count FROM jsonb_array_elements(realized#>'{historical,events}') x WHERE x->>'financial_event_id'=v.financial_event_id::text OR x->>'source_ref' IN(v.financial_event_id::text,v.legacy_id,v.staging_id::text);
  IF expected_count<>1 THEN RAISE EXCEPTION 'realized debit did not occur exactly once';END IF;
  SELECT count(*) INTO expected_count FROM public.lts_v229_expense_rows(u,v.event_date,v.event_date) e WHERE e.source_table='financial_events' AND e.source_ref=v.financial_event_id::text AND e.amount=abs(v.signed_amount);
  IF expected_count<>1 THEN RAISE EXCEPTION 'realized expense did not occur exactly once';END IF;
 END LOOP;
 IF has_function_privilege('anon','public.lts_browser_flow_v229(date,date)','EXECUTE')
  OR has_function_privilege('authenticated','public.lts_browser_flow_pre_v238(date,date)','EXECUTE')
  OR has_table_privilege('authenticated','public.lts_realized_bank_event_v238','SELECT')
  OR has_function_privilege('authenticated','public.lts_realized_bank_sources_v238(uuid)','EXECUTE') THEN RAISE EXCEPTION 'private source reader privileges broadened';END IF;
END $test$;
SELECT jsonb_build_object('pass',true,'check','All daily banks, consolidated cash, layers, future selection and exact realized source identities') result;
