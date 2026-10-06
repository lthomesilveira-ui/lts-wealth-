-- Cached reads remain usable in a read-only transaction or STABLE caller.
-- Only the optional cache INSERT can absorb SQLSTATE 25006. Engine errors,
-- owner checks, source changes and permission errors continue to propagate.
DO $patch$
DECLARE p record; definition text; revised text;
BEGIN
 FOR p IN SELECT oid,proname FROM pg_proc WHERE oid=ANY(ARRAY[
 'public.lts_payroll_bank_matches_v231(uuid)'::regprocedure,
 'public.lts_flow_history_read_v229(date,date)'::regprocedure,
 'public.lts_flow_operational_read_v229(uuid,date,date)'::regprocedure,
 'public.lts_operational_source_key_v238(uuid)'::regprocedure,
 'public.lts_flow_read_source_key_v247(uuid)'::regprocedure,
 'public.lts_historical_effective_cash_v4(uuid,date,date)'::regprocedure,
 'public.lts_card_invoice_amounts_v230(uuid)'::regprocedure,
 'public.lts_browser_flow_v242(date,date)'::regprocedure
 ]) LOOP
  IF EXISTS(SELECT 1 FROM pg_proc s WHERE s.pronamespace='public'::regnamespace
   AND s.proname=p.proname||'_pre_v247' AND s.proargtypes=(SELECT proargtypes FROM pg_proc WHERE oid=p.oid)) THEN
   RAISE EXCEPTION 'V247 snapshot already exists: %',p.proname;
  END IF;
  definition:=pg_get_functiondef(p.oid);
  EXECUTE replace(definition,'FUNCTION public.'||p.proname||'(','FUNCTION public.'||p.proname||'_pre_v247(');
  EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC,anon,authenticated',p.proname||'_pre_v247',pg_get_function_identity_arguments(p.oid));
  IF (SELECT count(*) FROM regexp_matches(definition,'INSERT INTO public\.lts_v229_read_cache[^;]+;','g'))<>1 THEN
   RAISE EXCEPTION 'unexpected cache insertion count: %',p.proname;
  END IF;
  revised:=regexp_replace(definition,'(INSERT INTO public\.lts_v229_read_cache[^;]+;)',
   E'IF NOT current_setting(''transaction_read_only'')::boolean THEN\n BEGIN\n \\1\n EXCEPTION WHEN read_only_sql_transaction THEN NULL;\n END;\n END IF;','g');
  EXECUTE revised;
 END LOOP;
END $patch$;
-- These source hashes call optional cache writers: the correct category is
-- VOLATILE, not STABLE. Their financial fingerprint bodies do not change.
ALTER FUNCTION public.lts_dashboard_source_key_v240(uuid) VOLATILE;
ALTER FUNCTION public.lts_flow_read_key_engine_v243(uuid) VOLATILE;
