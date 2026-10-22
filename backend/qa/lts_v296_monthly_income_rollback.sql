-- Financial consistency diagnostics; no persistent financial or category mutation.
BEGIN;
SET LOCAL TimeZone='America/Sao_Paulo';
SET LOCAL statement_timeout='60s';
DO $qa$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1();r jsonb;j jsonb;expected numeric;actual numeric;
 historic jsonb;canonical numeric;root_hash text;
BEGIN
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated',
  'email',(SELECT email FROM auth.users WHERE id=u))::text,true);
 SELECT x INTO r FROM lts_income_private.rows_v296(u,date_trunc('month',current_date)::date,current_date)x
 WHERE x->>'category'='Reembolso plano de saúde' ORDER BY x->>'event_date' DESC LIMIT 1;
 IF r IS NULL THEN RAISE EXCEPTION 'No documented healthcare receipt to validate';END IF;
 -- The latest healthcare receipt day has exactly one economic incoming source.
 SELECT sum((x->>'signed_amount')::numeric) INTO expected
 FROM lts_income_private.rows_v296(u,(r->>'event_date')::date,(r->>'event_date')::date)x;
 j:=public.lts_browser_monthly_v229((r->>'event_date')::date,(r->>'event_date')::date);
 actual:=(j#>>'{totals,revenue}')::numeric;
 IF actual IS DISTINCT FROM expected THEN RAISE EXCEPTION 'Daily report omitted or duplicated a canonical receipt';END IF;
 IF abs(actual-coalesce((SELECT sum((x->>'total')::numeric) FROM jsonb_array_elements(j->'revenue_groups')x),0))>.005
 THEN RAISE EXCEPTION 'Revenue groups do not reconcile';END IF;
 historic:=public.lts_browser_monthly_v229('2022-09-01','2022-09-30');
 SELECT round(sum(amount),2) INTO canonical FROM public.lts_v229_expense_rows(u,'2022-09-01','2022-09-30');
 IF(historic#>>'{totals,expenses}')::numeric IS DISTINCT FROM canonical THEN RAISE EXCEPTION 'Historical expense regression';END IF;
 SELECT md5(pg_get_functiondef('public.lts_monthly_balance_v1(uuid,date,date)'::regprocedure)) INTO root_hash;
 IF root_hash<>'fda8c35fcf1f62f36900fd5645fe29d2' THEN RAISE EXCEPTION 'Older report API changed';END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='lts_income_private' AND p.proname LIKE 'monthly_%_v296'
  AND(has_function_privilege('anon',p.oid,'EXECUTE') OR has_function_privilege('authenticated',p.oid,'EXECUTE')))
 THEN RAISE EXCEPTION 'Private monthly worker exposed';END IF;
 PERFORM set_config('lts.v296.monthly_qa',jsonb_build_object('pass',true,'receipt_date',r->>'event_date',
  'receipt_day_revenue',actual,'same_incoming_sources',true,'historical_expenses',canonical,
  'old_report_api_preserved',true,'private_workers_not_exposed',true,'rolled_back',true)::text,true);
END $qa$;
SELECT current_setting('lts.v296.monthly_qa')::jsonb AS result;
ROLLBACK;
