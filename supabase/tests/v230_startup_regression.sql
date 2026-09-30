-- Run via an authorized database connection with request.jwt.claims set for
-- the owner under test. No credentials or customer records belong in this file.
-- All disposable cache changes are rolled back; no financial source is changed.
BEGIN;
SET LOCAL timezone='America/Sao_Paulo';
DO $$ DECLARE u uuid:=public.lts_browser_assert_user_v1(); BEGIN
 DELETE FROM public.lts_flow_future_read_cache_v2 WHERE user_id=u;
 DELETE FROM public.lts_v229_read_cache WHERE user_id=u;
END $$;
SET LOCAL ROLE authenticated;
SET LOCAL statement_timeout='8s';

DO $$ DECLARE j jsonb; t timestamptz:=clock_timestamp(); c jsonb; BEGIN
 j:=public.lts_browser_cash_today_v178(); c:=j#>'{day,fix86_columns}';
 IF j->>'status'<>'complete' OR (j->>'as_of')::date<>current_date
 OR j->>'reader_revision'<>'v230-independent-current-position'
 OR abs((j->>'available_total')::numeric-(j->>'cash')::numeric-(j->>'d0')::numeric-(j->>'brokerage_available')::numeric)>.005
 OR abs((c->>'saldo_apos_rsu')::numeric-(c->>'saldo_apos_d0_1')::numeric-(c->>'rsus_vested')::numeric)>.005
 OR abs((c->>'saldo_apos_fgts')::numeric-(c->>'saldo_apos_rsu')::numeric-(c->>'fgts')::numeric)>.005
 OR c->>'entradas' IS NOT NULL OR c->>'saidas' IS NOT NULL OR c->>'saldo_anterior' IS NOT NULL
 THEN RAISE EXCEPTION 'Current position contract failed'; END IF;
 PERFORM set_config('lts.v230.qa.cash',j::text,true);
 PERFORM set_config('lts.v230.qa.cash_ms',(1000*extract(epoch FROM clock_timestamp()-t))::text,true);
END $$;

DO $$ DECLARE j jsonb; ds jsonb; d jsonb; c jsonb; cash jsonb;
 t timestamptz:=clock_timestamp(); horizon date:=make_date(extract(year FROM current_date)::int+1,12,31);
 BEGIN
 j:=public.lts_browser_flow_v229(current_date,horizon); ds:=j#>'{flow,current_future,days}';
 IF jsonb_typeof(ds) IS DISTINCT FROM 'array' OR coalesce(jsonb_array_length(ds),0)<>horizon-current_date+1 THEN RAISE EXCEPTION 'Incomplete forecast'; END IF;
 FOR d IN SELECT value FROM jsonb_array_elements(ds) LOOP
  c:=d->'fix86_columns';
  IF abs((c->>'saldo_apos_d0_1')::numeric-(c->>'saldo_final')::numeric-(c->>'liq_d0_1_recurso')::numeric)>.005
  OR abs((c->>'saldo_apos_rsu')::numeric-(c->>'saldo_apos_d0_1')::numeric-(c->>'rsus_vested')::numeric)>.005
  OR abs((c->>'saldo_apos_fgts')::numeric-(c->>'saldo_apos_rsu')::numeric-(c->>'fgts')::numeric)>.005
  OR abs((c->>'saldo_final')::numeric-(d#>>'{Itaú,balance}')::numeric-(d#>>'{Bradesco,balance}')::numeric-(d#>>'{C6,balance}')::numeric)>.005
  OR (c->>'entradas' IS NOT NULL AND c->>'saidas' IS NOT NULL AND
   abs((c->>'saldo_final')::numeric-(c->>'saldo_anterior')::numeric-(c->>'entradas')::numeric+(c->>'saidas')::numeric)>.005)
  THEN RAISE EXCEPTION 'Daily arithmetic or bank parity failed on %',d->>'date'; END IF;
 END LOOP;
 cash:=current_setting('lts.v230.qa.cash')::jsonb;
 IF (ds#>>'{0,fix86_columns,saldo_final}')::numeric<>(cash->>'cash')::numeric
 OR (ds#>>'{0,fix86_columns,rsus_vested}')::numeric<>(cash->>'brokerage_available')::numeric
 OR (ds#>>'{0,fix86_columns,saldo_apos_rsu}')::numeric<>(cash->>'available_total')::numeric
 THEN RAISE EXCEPTION 'Dashboard and Flow current availability differ'; END IF;
 PERFORM set_config('lts.v230.qa.flow',j::text,true);
 PERFORM set_config('lts.v230.qa.cold_ms',(1000*extract(epoch FROM clock_timestamp()-t))::text,true);
END $$;

DO $$ DECLARE j jsonb; t timestamptz:=clock_timestamp(); BEGIN
 j:=public.lts_browser_flow_v229(current_date,make_date(extract(year FROM current_date)::int+1,12,31));
 -- Cache diagnostics differ; the financial days and events must match exactly.
 IF j#>'{flow,current_future,days}' IS DISTINCT FROM current_setting('lts.v230.qa.flow')::jsonb#>'{flow,current_future,days}'
 OR j#>'{flow,current_future,events}' IS DISTINCT FROM current_setting('lts.v230.qa.flow')::jsonb#>'{flow,current_future,events}'
 THEN RAISE EXCEPTION 'Cold/warm financial Flow mismatch'; END IF;
 PERFORM set_config('lts.v230.qa.warm_ms',(1000*extract(epoch FROM clock_timestamp()-t))::text,true);
END $$;

DO $$ DECLARE j jsonb; ds jsonb:=current_setting('lts.v230.qa.flow')::jsonb#>'{flow,current_future,days}';
 d0 date; rsu date; fgts date; t timestamptz:=clock_timestamp(); BEGIN
 SELECT min((d->>'date')::date) FILTER(WHERE (d#>>'{fix86_columns,saldo_apos_d0_1}')::numeric<0),
 min((d->>'date')::date) FILTER(WHERE (d#>>'{fix86_columns,saldo_apos_rsu}')::numeric<0),
 min((d->>'date')::date) FILTER(WHERE (d#>>'{fix86_columns,saldo_apos_fgts}')::numeric<0)
 INTO d0,rsu,fgts FROM jsonb_array_elements(ds) d;
 j:=public.lts_browser_planning_ui_contract_v1();
 IF (j->>'d01_first_need')::date IS DISTINCT FROM d0 OR (j->>'rsu_first_need')::date IS DISTINCT FROM rsu
 OR (j->>'fgts_first_negative')::date IS DISTINCT FROM fgts
 THEN RAISE EXCEPTION 'Dashboard planning and dated Flow alerts disagree'; END IF;
 PERFORM set_config('lts.v230.qa.planning_ms',(1000*extract(epoch FROM clock_timestamp()-t))::text,true);
END $$;

DO $$ DECLARE j jsonb; c jsonb:=current_setting('lts.v230.qa.cash')::jsonb;
 t timestamptz:=clock_timestamp(); k text; BEGIN
 j:=public.lts_browser_wealth_detail_v4();
 FOREACH k IN ARRAY ARRAY['cash','d0','brokerage_available','available_total','fgts'] LOOP
  IF (j#>>ARRAY['current_liquidity',k])::numeric IS DISTINCT FROM (c->>k)::numeric
  THEN RAISE EXCEPTION 'Wealth and Dashboard current position differ'; END IF;
 END LOOP;
 PERFORM set_config('lts.v230.qa.wealth_ms',(1000*extract(epoch FROM clock_timestamp()-t))::text,true);
END $$;

-- The default Daily Flow window includes five historical days, unlike Dashboard.
DO $$ DECLARE j jsonb; t timestamptz:=clock_timestamp(); horizon date:=make_date(extract(year FROM current_date)::int,12,31);
 n int; BEGIN
 j:=public.lts_browser_flow_v229(current_date-5,horizon);
 n:=jsonb_array_length(j#>'{flow,historical,days}')+jsonb_array_length(j#>'{flow,current_future,days}');
 IF coalesce(n,0)<>horizon-(current_date-5)+1 THEN RAISE EXCEPTION 'Default Flow dates incomplete'; END IF;
 PERFORM set_config('lts.v230.qa.default_ms',(1000*extract(epoch FROM clock_timestamp()-t))::text,true);
END $$;

SELECT jsonb_build_object('pass',true,'authenticated_role',current_user,
 'cache_cleared_before_test',true,'source_data_changed',false,
 'forecast_days',jsonb_array_length(current_setting('lts.v230.qa.flow')::jsonb#>'{flow,current_future,days}'),
 'cash_ms',current_setting('lts.v230.qa.cash_ms')::numeric,
 'cold_forecast_ms',current_setting('lts.v230.qa.cold_ms')::numeric,
 'warm_forecast_ms',current_setting('lts.v230.qa.warm_ms')::numeric,
 'planning_ms',current_setting('lts.v230.qa.planning_ms')::numeric,
 'wealth_ms',current_setting('lts.v230.qa.wealth_ms')::numeric,
 'default_flow_ms',current_setting('lts.v230.qa.default_ms')::numeric) result;
ROLLBACK;
