-- Set authorized owner request.jwt.claims. Only disposable caches are changed;
-- the transaction rolls back all test work. No customer identities are stored.
BEGIN;
SET LOCAL timezone='America/Sao_Paulo';
DO $$ DECLARE u uuid:=public.lts_browser_assert_user_v1();BEGIN
 DELETE FROM public.lts_flow_future_read_cache_v2 WHERE user_id=u;
 DELETE FROM public.lts_v229_read_cache WHERE user_id=u;
END $$;
SET LOCAL ROLE authenticated;
SET LOCAL statement_timeout='8s';
DO $$ DECLARE j jsonb;ds jsonb;d jsonb;c jsonb;t timestamptz:=clock_timestamp();
 horizon date:=make_date(extract(year FROM current_date)::int+1,12,31);
BEGIN
 j:=public.lts_browser_flow_v229(current_date,horizon);ds:=j#>'{flow,current_future,days}';
 IF jsonb_array_length(ds)<>horizon-current_date+1 THEN RAISE EXCEPTION 'Incomplete forecast';END IF;
 FOR d IN SELECT value FROM jsonb_array_elements(ds) LOOP
  c:=d->'fix86_columns';
  IF abs((c->>'saldo_final')::numeric-(d#>>'{Itaú,balance}')::numeric-(d#>>'{Bradesco,balance}')::numeric-(d#>>'{C6,balance}')::numeric)>.005
  OR abs((c->>'saldo_apos_rsu')::numeric-(c->>'saldo_apos_d0_1')::numeric-(c->>'rsus_vested')::numeric)>.005
  OR abs((c->>'saldo_apos_fgts')::numeric-(c->>'saldo_apos_rsu')::numeric-(c->>'fgts')::numeric)>.005
  THEN RAISE EXCEPTION 'Daily arithmetic failed';END IF;
 END LOOP;
 PERFORM set_config('lts.qa.cold_ms',(1000*extract(epoch FROM clock_timestamp()-t))::text,true);
 PERFORM set_config('lts.qa.flow',j::text,true);
END $$;
DO $$ DECLARE j jsonb;t timestamptz:=clock_timestamp();BEGIN
 j:=public.lts_browser_flow_v229(current_date,make_date(extract(year FROM current_date)::int+1,12,31));
 IF j#>'{flow,current_future,days}' IS DISTINCT FROM current_setting('lts.qa.flow')::jsonb#>'{flow,current_future,days}'
 OR j#>'{flow,current_future,events}' IS DISTINCT FROM current_setting('lts.qa.flow')::jsonb#>'{flow,current_future,events}'
 THEN RAISE EXCEPTION 'Cold and warm financial payloads differ';END IF;
 PERFORM set_config('lts.qa.warm_ms',(1000*extract(epoch FROM clock_timestamp()-t))::text,true);
END $$;
DO $$ DECLARE j jsonb;t timestamptz:=clock_timestamp();BEGIN
 j:=public.lts_browser_expense_review_queue_v229(date '2013-10-10',current_date,0,100,null);
 IF (j->>'row_count')::int<>jsonb_array_length(j->'rows') THEN RAISE EXCEPTION 'Incomplete review list';END IF;
 PERFORM set_config('lts.qa.review_ms',(1000*extract(epoch FROM clock_timestamp()-t))::text,true);
 PERFORM set_config('lts.qa.review_count',j->>'row_count',true);
END $$;
SELECT jsonb_build_object('pass',true,'authenticated_role',current_user,'cache_cleared',true,'rolled_back',true,
 'cold_ms',current_setting('lts.qa.cold_ms')::numeric,'warm_ms',current_setting('lts.qa.warm_ms')::numeric,
 'review_ms',current_setting('lts.qa.review_ms')::numeric,'review_count',current_setting('lts.qa.review_count')::int,
 'forecast_days',jsonb_array_length(current_setting('lts.qa.flow')::jsonb#>'{flow,current_future,days}')) result;
ROLLBACK;
