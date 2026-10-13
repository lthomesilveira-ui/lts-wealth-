-- Run before and after the migration against the same source epoch/business day.
-- Compare the complete response digests, not just selected financial totals.
-- The only excluded field is the wealth reader's calculation clock.
BEGIN;
SET LOCAL statement_timeout='55s';
SET LOCAL jit=off;
SET LOCAL TimeZone='America/Sao_Paulo';
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text
 FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
DO $probe$
DECLARE t timestamptz; j jsonb; timings jsonb:='{}'; hashes jsonb:='{}';
 u uuid:=public.lts_open_finance_pilot_owner_v1();
BEGIN
 t:=clock_timestamp();j:=public.lts_browser_flow_v242(date '2026-01-01',date '2027-12-31');
 timings:=timings||jsonb_build_object('flow_ms',round(extract(epoch from clock_timestamp()-t)*1000,1));
 hashes:=hashes||jsonb_build_object('flow',md5(j::text),'days',
  jsonb_array_length(j#>'{flow,historical,days}')+jsonb_array_length(j#>'{flow,current_future,days}'));
 t:=clock_timestamp();j:=public.lts_browser_expenses_v229(date '2013-10-10',current_date);
 timings:=timings||jsonb_build_object('expenses_ms',round(extract(epoch from clock_timestamp()-t)*1000,1));
 hashes:=hashes||jsonb_build_object('expenses',md5(j::text));
 t:=clock_timestamp();j:=public.lts_browser_wealth_detail_v242();
 timings:=timings||jsonb_build_object('wealth_ms',round(extract(epoch from clock_timestamp()-t)*1000,1));
 j:=jsonb_set(j,'{current_liquidity}',(j->'current_liquidity')-'computed_at');
 hashes:=hashes||jsonb_build_object('wealth',md5(j::text));
 SELECT hashes||jsonb_build_object('expense_rows',count(*),'expense_unique_rows',count(DISTINCT row_key),
  'expense_identity_pending',count(*) FILTER(WHERE identity_status='pending'),
  'expense_rows_md5',md5(string_agg(to_jsonb(r)::text,E'\n' ORDER BY row_key)))
 INTO hashes FROM public.lts_v229_expense_rows(u,date '2013-10-10',current_date)r;
 SELECT hashes||jsonb_build_object('financial_events_count',count(*),
  'financial_events_md5',md5(string_agg(to_jsonb(f)::text,E'\n' ORDER BY id)))
 INTO hashes FROM public.financial_events f WHERE user_id=u;
 PERFORM set_config('lts.v267_probe',jsonb_build_object('timings',timings,'hashes',hashes,
  'epoch',(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton),
  'mutations','rolled_back','timezone','America/Sao_Paulo')::text,true);
END $probe$;
SELECT current_setting('lts.v267_probe')::jsonb receipt;
ROLLBACK;
