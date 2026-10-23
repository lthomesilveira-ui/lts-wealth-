-- Existing-source trial; no real transfer or financial/source mutation.
\set ON_ERROR_STOP on
BEGIN ISOLATION LEVEL REPEATABLE READ;
SET LOCAL timezone='America/Sao_Paulo';
SET LOCAL statement_timeout='25s';SET LOCAL lock_timeout='2s';
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text
 FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
CREATE FUNCTION pg_temp.v304_sources() RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1();r record;j jsonb:='{}';h text;
BEGIN
 FOR r IN SELECT * FROM(VALUES('lts_open_finance_staging','user_id'),('financial_events','user_id'),
 ('lts_v178_review_decision','user_id'),('evento_base','usuario_id'),('audit_log','user_id'),
 ('accounts','user_id'),('lts_v229_documentary_match','user_id'))x(tab,col) LOOP
  EXECUTE format('SELECT md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,''[]'')) FROM public.%I t WHERE %I=$1',r.tab,r.col) INTO h USING u;
  j:=j||jsonb_build_object(r.tab,h);
 END LOOP;RETURN j;
END $f$;
CREATE TEMP TABLE v304_sources_before ON COMMIT DROP AS SELECT pg_temp.v304_sources() j;
CREATE TEMP TABLE v304_expenses_before ON COMMIT DROP AS SELECT *
 FROM public.lts_v229_expense_rows(public.lts_open_finance_pilot_owner_v1(),'2013-10-10',current_date);
CREATE TEMP TABLE v304_monthly_before ON COMMIT DROP AS
 SELECT public.lts_browser_monthly_v229(date_trunc('month',current_date)::date,current_date) j;
CREATE TEMP TABLE v304_flow_before ON COMMIT DROP AS
 SELECT public.lts_browser_flow_v242(current_date-1,current_date) j;
\ir ../patches/v304/posted_own_transfer.sql
\ir lts_v304_evidence.sql
CREATE TEMP TABLE v304_expenses_after ON COMMIT DROP AS SELECT *
 FROM public.lts_v229_expense_rows(public.lts_open_finance_pilot_owner_v1(),'2013-10-10',current_date);
CREATE TEMP TABLE v304_monthly_after ON COMMIT DROP AS
 SELECT public.lts_browser_monthly_v229(date_trunc('month',current_date)::date,current_date) j;
CREATE TEMP TABLE v304_flow_after ON COMMIT DROP AS
 SELECT public.lts_browser_flow_v242(current_date-1,current_date) j;
DO $parity$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1();amount_out numeric;b jsonb;a jsonb;od jsonb;nd jsonb;delta numeric;
BEGIN
 IF pg_temp.v304_sources() IS DISTINCT FROM(SELECT j FROM v304_sources_before)
 THEN RAISE EXCEPTION 'Financial/source/decision/audit data changed';END IF;
 IF (SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]') FROM v304_expenses_before x
 WHERE NOT(x.source_table='lts_open_finance_staging' AND x.source_ref IN(SELECT source_id::text FROM public.lts_posted_own_transfer_out_v304(u))))
 IS DISTINCT FROM(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]') FROM v304_expenses_after x)
 THEN RAISE EXCEPTION 'Other canonical expenses changed or transfer not removed';END IF;
 IF EXISTS(SELECT 1 FROM v304_expenses_after x WHERE x.source_table='lts_open_finance_staging'
 AND x.source_ref IN(SELECT source_id::text FROM public.lts_posted_own_transfer_out_v304(u)))
 THEN RAISE EXCEPTION 'Own transfer remains spending';END IF;
 SELECT coalesce(sum(x.amount),0) INTO amount_out FROM v304_expenses_before x WHERE x.source_table='lts_open_finance_staging'
 AND x.source_ref IN(SELECT source_id::text FROM public.lts_posted_own_transfer_out_v304(u))
 AND x.event_date BETWEEN date_trunc('month',current_date)::date AND current_date;
 SELECT j->'totals' INTO b FROM v304_monthly_before;SELECT j->'totals' INTO a FROM v304_monthly_after;
 IF a IS DISTINCT FROM b||jsonb_build_object('expenses',(b->>'expenses')::numeric-amount_out,
 'operating_balance',(b->>'operating_balance')::numeric+amount_out,'cash_after_extraordinary',(b->>'cash_after_extraordinary')::numeric+amount_out)
 THEN RAISE EXCEPTION 'Monthly delta is not exactly the known transfer debit';END IF;
 SELECT j INTO b FROM v304_flow_before;SELECT j INTO a FROM v304_flow_after;
 IF a#>'{flow,historical}' IS DISTINCT FROM b#>'{flow,historical}'
 THEN RAISE EXCEPTION 'Past-day history changed';END IF;
 FOR od IN SELECT * FROM jsonb_array_elements(b#>'{flow,current_future,days}') LOOP
  SELECT x INTO STRICT nd FROM jsonb_array_elements(a#>'{flow,current_future,days}')x WHERE x->>'date'=od->>'date';
  SELECT coalesce(sum(signed_amount),0) INTO delta FROM public.lts_posted_own_transfer_out_v304(u)
  WHERE event_date=(od->>'date')::date;
  IF nd IS DISTINCT FROM od||jsonb_build_object(
   'Consolidado',(od->'Consolidado')||jsonb_build_object('economic_net',(od#>>'{Consolidado,economic_net}')::numeric-delta),
   'v170_cash_arithmetic',(od->'v170_cash_arithmetic')||jsonb_build_object(
   'operating_exits_brl',(od#>>'{v170_cash_arithmetic,operating_exits_brl}')::numeric+delta,
   'internal_transfer_net_brl',(od#>>'{v170_cash_arithmetic,internal_transfer_net_brl}')::numeric+delta))
  THEN RAISE EXCEPTION 'Cash, balance or non-target day fields changed';END IF;
 END LOOP;
 IF (SELECT coalesce(jsonb_agg(jsonb_strip_nulls(x-ARRAY['category','excluded','internal_transfer','classification_confirmed',
 'excluded_from_spend','classification_basis','own_transfer_destination_bank','own_transfer_counterleg_status']) ORDER BY x->>'source_ref'),'[]')
 FROM jsonb_array_elements(a#>'{flow,current_future,events}')x)
 IS DISTINCT FROM(SELECT coalesce(jsonb_agg(jsonb_strip_nulls(x-ARRAY['category','excluded','internal_transfer','classification_confirmed',
 'excluded_from_spend','classification_basis','own_transfer_destination_bank','own_transfer_counterleg_status']) ORDER BY x->>'source_ref'),'[]')
 FROM jsonb_array_elements(b#>'{flow,current_future,events}')x)
 THEN RAISE EXCEPTION 'Event amounts, identity or count changed';END IF;
END $parity$;
CREATE TEMP TABLE v304_definitions ON COMMIT DROP AS SELECT oid,pg_get_functiondef(oid) definition
 FROM pg_proc WHERE oid IN('public.lts_v229_new_bank_rows(uuid,date,date)'::regprocedure,
 'public.lts_browser_flow_pre_v238(date,date)'::regprocedure);
\ir ../patches/v304/posted_own_transfer.sql
DO $replay$ BEGIN
 IF EXISTS(SELECT 1 FROM v304_definitions WHERE definition IS DISTINCT FROM pg_get_functiondef(oid))
 OR pg_temp.v304_sources() IS DISTINCT FROM(SELECT j FROM v304_sources_before)
 THEN RAISE EXCEPTION 'Replay changed definitions or financial source data';END IF;
END $replay$;
SELECT jsonb_build_object('status','PASS','source_rows_and_decisions_exact',true,'other_canonical_expenses_exact',true,
 'cash_dates_amounts_balances_exact',true,'only_proved_own_transfer_economic_delta',true,
 'reader_replay_noop',true,'cache_epoch_invalidation_expected',true,
 'synthetic',current_setting('lts.v304.synthetic_receipt')::jsonb,
 'posted_outgoing_only',(SELECT jsonb_agg(to_jsonb(r)) FROM public.lts_posted_own_transfer_out_v304(public.lts_open_finance_pilot_owner_v1())r),
 'monthly_before',(SELECT j FROM v304_monthly_before),'monthly_after',(SELECT j FROM v304_monthly_after),
 'flow_before',(SELECT j FROM v304_flow_before),'flow_after',(SELECT j FROM v304_flow_after)) receipt;
ROLLBACK;
