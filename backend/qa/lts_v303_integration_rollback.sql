-- Live-source diagnostic. No financial writes; all DDL/cache activity rolls back.
\set ON_ERROR_STOP on
BEGIN ISOLATION LEVEL REPEATABLE READ;
SET LOCAL timezone='America/Sao_Paulo';
SET LOCAL statement_timeout='25s';
SET LOCAL lock_timeout='2s';
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text
 FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
CREATE FUNCTION pg_temp.v303_snapshot() RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1();r record;j jsonb:='{}';h text;
BEGIN
 FOR r IN SELECT * FROM (VALUES
 ('financial_events','user_id'),('evento_base','usuario_id'),('lts_open_finance_staging','user_id'),
 ('lts_v178_review_decision','user_id'),('lts_realized_bank_event_v238','user_id'),
 ('lts_card_documentary_payment_link_v272','user_id'),('lts_card_settlement_expense_contract_v273','user_id'),
 ('lts_projection_replacement_rule','user_id'),('projecao_op','usuario_id'),('reconciliacao','usuario_id'),
 ('deslocamento','usuario_id'),('card_invoices','user_id'),('accounts','user_id'),('lts_v229_documentary_match','user_id'))x(tab,col)
 LOOP
  EXECUTE format('SELECT md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,''[]'')) FROM public.%I t WHERE %I=$1',r.tab,r.col) INTO h USING u;
  j:=j||jsonb_build_object(r.tab,h);
 END LOOP;
 RETURN jsonb_build_object('source_hashes',j,
 'expenses',(SELECT md5(coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text)::text,'[]'))
  FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)x),
 'audit_attributes',(SELECT jsonb_build_object('oid',oid,'owner',proowner,'acl',proacl,'definer',prosecdef,
  'volatility',provolatile,'config',proconfig) FROM pg_proc WHERE oid='public.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure),
 'monthly',public.lts_browser_monthly_v229(date_trunc('month',current_date)::date,current_date),
 'audit',public.lts_recurring_future_gap_audit_v6(u,current_date,'2031-12-31'));
END $f$;
CREATE TEMP TABLE v303_before ON COMMIT DROP AS SELECT pg_temp.v303_snapshot() j;
\ir ../patches/v303/paid_audit_identity.sql
CREATE TEMP TABLE v303_after ON COMMIT DROP AS SELECT pg_temp.v303_snapshot() j;
DO $verify$
DECLARE b jsonb;a jsonb;k text;r record;
BEGIN
 SELECT j INTO b FROM v303_before;SELECT j INTO a FROM v303_after;
 FOREACH k IN ARRAY ARRAY['source_hashes','expenses','audit_attributes','monthly'] LOOP
  IF b->k IS DISTINCT FROM a->k THEN RAISE EXCEPTION 'Financial data or attributes changed: %',k;END IF;
 END LOOP;
 IF ((a->'audit')-'horizon_checks'-'horizon_review_count'-'horizon_reconciliation_count'-'receipt_identity_revision')
 IS DISTINCT FROM ((b->'audit')-'horizon_checks'-'horizon_review_count'-'horizon_reconciliation_count')
 THEN RAISE EXCEPTION 'Non-horizon audit response changed';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(a#>'{audit,horizon_checks}')x
  JOIN jsonb_array_elements(b#>'{audit,horizon_checks}')y ON y->>'key'=x->>'key'
  CROSS JOIN LATERAL jsonb_array_elements(x->'period_coverage')xp
  JOIN LATERAL jsonb_array_elements(y->'period_coverage')yp ON yp->>'period_start'=xp->>'period_start'
  WHERE xp->>'period_start'>date_trunc('month',current_date)::date::text AND xp IS DISTINCT FROM yp)
 THEN RAISE EXCEPTION 'Future period coverage changed';END IF;
 FOR r IN SELECT * FROM public.lts_recurring_receipt_identities_v303(public.lts_open_finance_pilot_owner_v1(),current_date) LOOP
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(a#>'{audit,horizon_checks}')x
   WHERE x->>'key'=r.series_key AND x->>'direction'=r.direction
   AND x#>>'{period_coverage,0,status}'='covered'
   AND (x#>>'{period_coverage,0,actual_events}')::int>=1)
  THEN RAISE EXCEPTION 'Exact receipt not represented in current month';END IF;
 END LOOP;
 IF has_function_privilege('anon','public.lts_recurring_receipt_identities_v303(uuid,date)','EXECUTE')
 OR has_function_privilege('authenticated','public.lts_recurring_receipt_identities_v303(uuid,date)','EXECUTE')
 THEN RAISE EXCEPTION 'Private helper exposed';END IF;
END $verify$;
CREATE TEMP TABLE v303_replay ON COMMIT DROP AS SELECT
 pg_get_functiondef('public.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure) definition;
\ir ../patches/v303/paid_audit_identity.sql
DO $replay$ BEGIN
 IF (SELECT definition FROM v303_replay) IS DISTINCT FROM
 pg_get_functiondef('public.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure)
 THEN RAISE EXCEPTION 'Replay changed audit definition';END IF;
END $replay$;
SELECT jsonb_build_object('status','PASS','financial_sources_unchanged',true,'all_canonical_expenses_unchanged',true,
 'monthly_response_exact',true,'audit_attributes_unchanged',true,'base_audit_response_exact',true,
 'future_period_coverage_exact',true,'replay_noop',true,
 'receipts',(SELECT jsonb_agg(to_jsonb(r)) FROM public.lts_recurring_receipt_identities_v303(public.lts_open_finance_pilot_owner_v1(),current_date)r),
 'before_counts',(SELECT j#>'{audit,horizon_reconciliation_count}' FROM v303_before),
 'after_counts',(SELECT j#>'{audit,horizon_reconciliation_count}' FROM v303_after),
 'before_monthly',(SELECT j->'monthly' FROM v303_before),'after_monthly',(SELECT j->'monthly' FROM v303_after)) receipt;
ROLLBACK;
