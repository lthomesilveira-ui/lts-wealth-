-- Run against the pilot only. Every test mutation is rolled back.
BEGIN;
SET LOCAL timezone='America/Sao_Paulo';
SET LOCAL jit='off';
DO $qa$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1(); e bigint; n bigint; sid uuid; fid uuid; clone_id uuid;
 result jsonb:='{}'; j jsonb; old_j jsonb; started timestamptz; warm jsonb; mismatch bigint;
BEGIN
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated','email',(SELECT email FROM auth.users WHERE id=u))::text,true);
 warm:=public.lts_warm_flow_cache_v245();
 SELECT epoch INTO e FROM public.lts_read_cache_epoch_v242 WHERE singleton;
 SELECT count(*) INTO n FROM public.lts_v229_read_cache;
 UPDATE public.financial_events SET amount=amount WHERE user_id=u AND false;
 UPDATE public.lts_open_finance_staging SET raw_hash=raw_hash WHERE user_id=u AND false;
 DELETE FROM public.lts_open_finance_staging WHERE user_id=u AND false;
 IF e<>(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)
  OR n<>(SELECT count(*) FROM public.lts_v229_read_cache) THEN RAISE EXCEPTION 'zero row invalidation'; END IF;
 result:=result||jsonb_build_object('zero_row_writes','PASS');
 UPDATE public.lts_open_finance_staging SET last_seen_at=clock_timestamp(),updated_at=clock_timestamp(),sync_run_id=sync_run_id WHERE user_id=u;
 UPDATE public.lts_open_finance_connection SET last_attempt_at=clock_timestamp(),last_success_at=clock_timestamp(),updated_at=clock_timestamp() WHERE user_id=u;
 UPDATE public.lts_open_finance_observation SET observed_at=clock_timestamp() WHERE id=(SELECT id FROM public.lts_open_finance_observation WHERE user_id=u AND resource_type='balance' AND normalized_payload->>'account_type'='CHECKING_ACCOUNT' LIMIT 1);
 IF e<>(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)
  OR n<>(SELECT count(*) FROM public.lts_v229_read_cache) THEN RAISE EXCEPTION 'sync heartbeat invalidation'; END IF;
 result:=result||jsonb_build_object('sync_heartbeats','PASS');
 UPDATE public.health_metrics SET notes=coalesce(notes,'')||' [rollback cache test]' WHERE id=(SELECT id FROM public.health_metrics WHERE user_id=u LIMIT 1);
 IF NOT FOUND THEN RAISE EXCEPTION 'Health fixture unavailable';END IF;
 IF e<>(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)
  OR n<>(SELECT count(*) FROM public.lts_v229_read_cache) THEN RAISE EXCEPTION 'Health invalidates finance';END IF;
 result:=result||jsonb_build_object('health_isolation','PASS');
 SELECT id INTO sid FROM public.lts_open_finance_staging WHERE user_id=u AND resource_type='transaction' AND normalized_payload->>'account_type'='CHECKING_ACCOUNT' AND normalized_payload->>'status'='POSTED' AND provider_deleted_at IS NULL LIMIT 1;
 IF sid IS NULL THEN RAISE EXCEPTION 'bank fixture unavailable';END IF;
 UPDATE public.lts_open_finance_staging SET raw_hash=raw_hash||'-rollback' WHERE id=sid;
 IF (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)<>e+1 OR EXISTS(SELECT 1 FROM public.lts_v229_read_cache) THEN RAISE EXCEPTION 'hash change retained cache';END IF;e:=e+1;
 UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{status}','"PENDING"') WHERE id=sid;
 IF (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)<>e+1 THEN RAISE EXCEPTION 'bank status retained cache';END IF;e:=e+1;
 UPDATE public.lts_open_finance_staging SET posting_date=posting_date+1 WHERE id=sid;
 IF (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)<>e+1 THEN RAISE EXCEPTION 'posting date retained cache';END IF;e:=e+1;
 UPDATE public.lts_open_finance_staging SET matched_source_ref=coalesce(matched_source_ref,'')||'-rollback' WHERE id=sid;
 IF (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)<>e+1 THEN RAISE EXCEPTION 'identity retained cache';END IF;e:=e+1;
 UPDATE public.lts_open_finance_staging SET provider_deleted_at=clock_timestamp() WHERE id=sid;
 IF (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)<>e+1 THEN RAISE EXCEPTION 'provider deletion retained cache';END IF;e:=e+1;
 result:=result||jsonb_build_object('hash_status_date_identity_deletion','PASS');
 SELECT id INTO fid FROM public.financial_events WHERE user_id=u LIMIT 1;
 INSERT INTO public.financial_events
 SELECT (jsonb_populate_record(NULL::public.financial_events,to_jsonb(f)||jsonb_build_object('id',gen_random_uuid(),'legacy_id','qa-v246-'||gen_random_uuid(),'is_suppressed',true))).*
 FROM public.financial_events f WHERE id=fid RETURNING id INTO clone_id;
 IF (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)<>e+1 THEN RAISE EXCEPTION 'financial insertion retained cache';END IF;e:=e+1;
 UPDATE public.financial_events SET amount=amount+1 WHERE id=clone_id;
 IF (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)<>e+1 THEN RAISE EXCEPTION 'financial amount retained cache';END IF;e:=e+1;
 BEGIN
  DELETE FROM public.financial_events WHERE id=clone_id;
  RAISE EXCEPTION 'append-only delete unexpectedly accepted';
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
  IF SQLERRM<>'DELETE is not allowed on append-only economic tables' THEN RAISE;END IF;
 END;
 IF (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)<>e THEN RAISE EXCEPTION 'blocked deletion changed epoch';END IF;
 INSERT INTO public.lts_open_finance_staging
 SELECT (jsonb_populate_record(NULL::public.lts_open_finance_staging,to_jsonb(s)||jsonb_build_object('id',gen_random_uuid(),'provider_record_id','qa-v246-'||gen_random_uuid()))).*
 FROM public.lts_open_finance_staging s WHERE id=sid RETURNING id INTO clone_id;
 IF (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)<>e+1 THEN RAISE EXCEPTION 'source insertion retained cache';END IF;e:=e+1;
 DELETE FROM public.lts_open_finance_staging WHERE id=clone_id;
 IF (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)<>e+1 THEN RAISE EXCEPTION 'source deletion retained cache';END IF;
 result:=result||jsonb_build_object('financial_insert_update','PASS','append_only_guard','PASS','source_insert_delete','PASS');
 IF EXISTS(SELECT 1 FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND
  (p.proname LIKE '%pre_v246' AND p.proname IN('lts_historical_effective_cash_v4_pre_v246','lts_flow_workbook_positions_v248_pre_v246','lts_flow_documentary_bank_sum_v237_pre_v246','lts_browser_flow_v240_pre_v246') OR p.proname IN('lts_v246_invalidate_finance_cache','lts_flow_bank_freshness_key_v246'))
  AND (has_function_privilege('anon',p.oid,'EXECUTE') OR has_function_privilege('authenticated',p.oid,'EXECUTE'))) THEN RAISE EXCEPTION 'private helper executable';END IF;
 result:=result||jsonb_build_object('private_helper_permissions','PASS','warm',warm);
 PERFORM set_config('lts.qa_results_v246',result::text,true);
END $qa$;
SELECT current_setting('lts.qa_results_v246')::jsonb result;
ROLLBACK;
