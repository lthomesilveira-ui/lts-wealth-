\set ON_ERROR_STOP on
\ir lts_v430_setup.sql
\ir ../patches/v430/optional_memo_writes.sql
DO $checks$
DECLARE u uuid:='00000000-0000-4000-8000-000000000001'; initial_timeout text; a jsonb;b jsonb;
BEGIN
 SELECT jsonb_agg(to_jsonb(x)) INTO a FROM public.lts_corrected_cashflow_fix86_v1_engine_v247(u,current_date,current_date)x;
 SELECT jsonb_agg(to_jsonb(x)) INTO b FROM public.lts_corrected_cashflow_fix86_v1(u,current_date,current_date)x;
 IF a IS DISTINCT FROM b THEN RAISE EXCEPTION 'Cash output changed';END IF;
 SELECT jsonb_agg(to_jsonb(x)) INTO a FROM public.lts_card_invoice_amounts_v230_engine_v243(u)x;
 SELECT jsonb_agg(to_jsonb(x)) INTO b FROM public.lts_card_invoice_amounts_v230(u)x;
 IF a IS DISTINCT FROM b THEN RAISE EXCEPTION 'Card output changed';END IF;
 SELECT jsonb_agg(to_jsonb(x)) INTO a FROM public.lts_payroll_bank_matches_v231_engine_v243(u)x;
 SELECT jsonb_agg(to_jsonb(x)) INTO b FROM public.lts_payroll_bank_matches_v231(u)x;
 IF a IS DISTINCT FROM b THEN RAISE EXCEPTION 'Payroll output changed';END IF;
 IF EXISTS(SELECT 1 FROM v430_attributes b JOIN pg_proc p ON p.oid=b.oid WHERE b.attributes IS DISTINCT FROM to_jsonb(p)-'prosrc')
 THEN RAISE EXCEPTION 'Original function attributes changed';END IF;
 IF has_function_privilege('anon','lts_read_private_v430.try_cache_put(uuid,text,date,date,date,jsonb,text)','EXECUTE')
 OR has_function_privilege('authenticated','lts_read_private_v430.try_cache_put(uuid,text,date,date,date,jsonb,text)','EXECUTE')
 THEN RAISE EXCEPTION 'Memo helper exposed';END IF;
 initial_timeout:=current_setting('lock_timeout');
 PERFORM lts_read_private_v430.try_cache_put(u,'test',current_date,current_date,current_date,'{}','one');
 IF current_setting('lock_timeout')<>initial_timeout THEN RAISE EXCEPTION 'Lock timeout leaked';END IF;
 PERFORM set_config('lock_timeout','50ms',true);
 PERFORM lts_read_private_v430.try_cache_put(u,'test',current_date,current_date,current_date,'{}','two');
 IF current_setting('lock_timeout')<>'50ms' THEN RAISE EXCEPTION 'Stricter timeout changed';END IF;
 -- A cold entry remains bounded by the original source epoch and TTL.
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1;
 PERFORM * FROM public.lts_corrected_cashflow_fix86_v1(u,current_date,current_date);
 IF NOT EXISTS(SELECT 1 FROM public.lts_v229_read_cache WHERE kind='corrected_cash_v1_v268' AND source_fingerprint LIKE 'cash-base-v268:2:%')
 THEN RAISE EXCEPTION 'Source invalidation lost';END IF;
END $checks$;
BEGIN READ ONLY;
DO $$BEGIN
 IF lts_read_private_v430.try_cache_put('00000000-0000-4000-8000-000000000001','readonly',current_date,current_date,current_date,'{}','read')
 THEN RAISE EXCEPTION 'Read-only transaction wrote a memo';END IF;
 PERFORM * FROM public.lts_card_invoice_amounts_v230('00000000-0000-4000-8000-000000000002');
END$$;
COMMIT;
-- Reapplication must retain the same definitions and original contracts.
\ir ../patches/v430/optional_memo_writes.sql
SELECT '{"pass":true,"scope":"optional-cache-writes-only","real_financial_data":false}' AS receipt;
