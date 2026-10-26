-- Administrative negative-access probe: no identity/claims are fabricated.
-- Financial read RPCs only. No writer, ingestion, provider or upload RPC is called.
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='8s';
SET LOCAL lock_timeout='1s';
SET LOCAL search_path='pg_catalog','public';
DO $probe$
DECLARE r record;arguments text;code text;message text;checks jsonb:='[]'::jsonb;
BEGIN
 IF auth.uid() IS NOT NULL THEN RAISE EXCEPTION 'Probe requires an administrative connection without an application identity';END IF;
 FOR r IN
  SELECT p.oid,p.oid::regprocedure::text signature,n.nspname,p.proname,p.proargtypes
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public'
   AND p.proname ~ '^lts_browser_(product_|dashboard_cockpit_|cash_today_|income_review_queue_|card_review_queue_|expenses_|expense_executive_|expense_context_|expense_review_queue_|wealth_detail_|awards_|planning_ui_|flow_v|monthly_|card_cycles_|card_history_|card_detail_|card_flow_schedule_|open_finance_status_|open_finance_pending_|recurring_future_gap_|future_bank_|transactions_|card_settlement_detail_)'
   AND has_function_privilege('authenticated',p.oid,'EXECUTE')
  ORDER BY 2
 LOOP
  SELECT coalesce(string_agg('NULL::'||format_type(t,NULL),',' ORDER BY ord),'') INTO arguments
  FROM unnest(r.proargtypes) WITH ORDINALITY a(t,ord);
  code:=NULL;message:=NULL;
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
   EXECUTE format('SELECT %I.%I(%s)',r.nspname,r.proname,arguments);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS code=RETURNED_SQLSTATE,message=MESSAGE_TEXT;
  END;
  EXECUTE 'RESET ROLE';
  checks:=checks||jsonb_build_array(jsonb_build_object('signature',r.signature,'sql_state',code,
   'rejected',code IS NOT NULL,'reason',left(message,200)));
 END LOOP;
 PERFORM set_config('lts.missing_session_probe',jsonb_build_object('pass',jsonb_array_length(checks)>0 AND NOT EXISTS(
  SELECT 1 FROM jsonb_array_elements(checks)x WHERE x->>'sql_state' IS NULL
   OR x->>'sql_state' NOT IN('42501','28000','P0001')
   OR coalesce(x->>'reason','') !~* 'autoriz|authoriz|authenticated|autentica|permission denied|sessão|session|sign.in'),
  'application_identity_missing',true,'claims_modified',false,'financial_read_functions',jsonb_array_length(checks),
  'checks',checks,'financial_writers_called',false,'source_mutations',false,
  'native_database_role_test',true,'signed_http_identity_test',false,'transaction','ROLLBACK')::text,true);
END $probe$;
SELECT current_setting('lts.missing_session_probe')::jsonb receipt;
ROLLBACK;
