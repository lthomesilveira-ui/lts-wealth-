-- Every mutation below is in a subtransaction deliberately rolled back.
-- This script performs no bank operation and commits no economic fact.
BEGIN;
SET LOCAL timezone='America/Sao_Paulo';
SET LOCAL jit='off';
SET LOCAL track_functions='all';
DO $qa$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1(); before_rows jsonb; after_rows jsonb;
 f date; t date; started timestamptz; uncached_ms numeric; memo_ms numeric; second_ms numeric;
 epoch_before bigint; target text; numeric_col text; changed integer;
 result jsonb:='{}'; report jsonb; baseline jsonb; cold jsonb; complete_ms numeric;
BEGIN
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated','email',(SELECT email FROM auth.users WHERE id=u))::text,true);
 BEGIN
  FOREACH f IN ARRAY ARRAY[date '2013-10-10',current_date,date '2027-01-01'] LOOP
   t:=CASE WHEN f<current_date THEN date '2026-07-07' ELSE date '2027-12-31' END;
   started:=clock_timestamp();
   SELECT coalesce(jsonb_agg(to_jsonb(r)),'[]') INTO before_rows FROM public.lts_corrected_cashflow_fix86_v1_engine_v247(u,f,t) r;
   uncached_ms:=round(extract(epoch FROM(clock_timestamp()-started))*1000,1);
   started:=clock_timestamp();
   SELECT coalesce(jsonb_agg(to_jsonb(r)),'[]') INTO after_rows FROM public.lts_corrected_cashflow_fix86_v1(u,f,t) r;
   memo_ms:=round(extract(epoch FROM(clock_timestamp()-started))*1000,1);
   IF before_rows<>after_rows THEN RAISE EXCEPTION 'corrected cash changed: % to %',f,t;END IF;
   started:=clock_timestamp();
   SELECT coalesce(jsonb_agg(to_jsonb(r)),'[]') INTO after_rows FROM public.lts_corrected_cashflow_fix86_v1(u,f,t) r;
   second_ms:=round(extract(epoch FROM(clock_timestamp()-started))*1000,1);
   IF before_rows<>after_rows THEN RAISE EXCEPTION 'memo replay changed rows';END IF;
   result:=result||jsonb_build_object(f::text,jsonb_build_object('rows',jsonb_array_length(before_rows),'equal',true,'engine_ms',uncached_ms,'first_ms',memo_ms,'replay_ms',second_ms));
  END LOOP;
  -- Exact argument and caller-timezone isolation; no range slicing of the base.
  IF (SELECT count(DISTINCT (from_date,to_date,source_fingerprint)) FROM public.lts_v229_read_cache WHERE user_id=u AND kind='corrected_cash_v1_v247')<3 THEN RAISE EXCEPTION 'memo arguments not isolated';END IF;
  FOREACH target IN ARRAY ARRAY['lts_card_document_supplement_v234','lts_card_history_source_audit_v235'] LOOP
   SELECT epoch INTO epoch_before FROM public.lts_read_cache_epoch_v242 WHERE singleton;
   SELECT column_name INTO numeric_col FROM information_schema.columns
   WHERE table_schema='public' AND table_name=target AND column_name IN('amount','source_signed_amount')
   ORDER BY CASE column_name WHEN 'amount' THEN 0 ELSE 1 END LIMIT 1;
   IF numeric_col IS NULL THEN RAISE EXCEPTION 'numeric source fixture missing: %',target;END IF;
   EXECUTE format('UPDATE public.%I SET %I=%I+1 WHERE ctid=(SELECT ctid FROM public.%I WHERE user_id=$1 AND %I IS NOT NULL LIMIT 1)',target,numeric_col,numeric_col,target,numeric_col) USING u;
   GET DIAGNOSTICS changed=ROW_COUNT;
   IF changed<>1 OR (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)<>epoch_before+1 OR EXISTS(SELECT 1 FROM public.lts_v229_read_cache) THEN RAISE EXCEPTION 'documentary source did not invalidate: %',target;END IF;
   result:=result||jsonb_build_object(target,'PASS');
  END LOOP;
  RAISE EXCEPTION USING ERRCODE='P2470',MESSAGE='rollback V247 source fixtures';
 EXCEPTION WHEN SQLSTATE 'P2470' THEN NULL;
 END;
 -- No anon/auth access to the raw engine, memo, or private snapshots.
 IF EXISTS(SELECT 1 FROM pg_proc p WHERE p.pronamespace='public'::regnamespace
 AND (p.proname LIKE '%pre_v247' OR p.proname='lts_corrected_cashflow_fix86_v1_engine_v247' OR p.proname='lts_corrected_cashflow_fix86_v1')
 AND (has_function_privilege('anon',p.oid,'EXECUTE') OR has_function_privilege('authenticated',p.oid,'EXECUTE'))) THEN RAISE EXCEPTION 'private function exposed';END IF;
 result:=result||jsonb_build_object('source_mutations_rolled_back',true,'private_helpers','PASS');
 PERFORM set_config('lts.qa_results_v247',result::text,true);
END $qa$;
SELECT current_setting('lts.qa_results_v247')::jsonb result;
ROLLBACK;
