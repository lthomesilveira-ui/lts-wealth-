BEGIN;
SET LOCAL search_path TO '';
CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.review_guard_v450(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE profile jsonb:=lts_product_refresh_private_v415.review_profile_v450(); item jsonb; actual text; primary_hashes jsonb:='{}'; rel regclass; owner_column text;
BEGIN
 -- Unknown producer, view or invalidation rules disable reuse, including new
 -- dependencies. They never convert unavailable information into an empty list.
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'producers') LOOP
  SELECT md5(pg_get_functiondef(to_regprocedure(item->>'signature'))) INTO actual;
  IF actual IS DISTINCT FROM item->>'md5' THEN RETURN NULL;END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'views') LOOP
  SELECT md5(pg_get_viewdef(to_regclass(item->>'signature'),true)) INTO actual;
  IF actual IS DISTINCT FROM item->>'md5' THEN RETURN NULL;END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'epoch_tables') LOOP
  SELECT md5(string_agg(t.tgname::text||t.tgenabled::text||pg_get_triggerdef(t.oid),'|' ORDER BY t.tgname)) INTO actual
   FROM pg_trigger t WHERE t.tgrelid=to_regclass(item->>'signature') AND NOT t.tgisinternal;
  IF actual IS DISTINCT FROM item->>'md5' THEN RETURN NULL;END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'tables') LOOP
  -- Relations and owner-column names come only from the pinned private profile.
  rel:=to_regclass(format('%I.%I',item->>'schema',item->>'name'));owner_column:=item->>'owner';
  IF rel IS NULL THEN RETURN NULL;END IF;
  EXECUTE format('WITH row_hashes AS MATERIALIZED (SELECT md5(to_jsonb(s)::text) h FROM %s s%s) SELECT md5(coalesce(string_agg(h,'''' ORDER BY h),'''')) FROM row_hashes',
   rel,CASE WHEN owner_column IS NULL THEN '' ELSE format(' WHERE %I=$1',owner_column) END) INTO actual USING p_user_id;
  primary_hashes:=primary_hashes||jsonb_build_object(item->>'schema'||'.'||(item->>'name'),actual);
 END LOOP;
 RETURN jsonb_build_object('owner',p_user_id,'as_of',current_date,
  'epoch',(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true),
  'card_source_key',lts_product_refresh_private_v415.card_source_key(p_user_id),'primary_hashes',primary_hashes,'profile',md5(profile::text));
END $function$

DROP TRIGGER lts_review_input_v465_8a9422ecbf5b ON public.audit_log;
DROP TRIGGER lts_review_input_v465_2b29f94c35c7 ON public.lts_product_read_cache;
DROP TRIGGER lts_review_input_v465_9fad0bc3b99b ON public.lts_category_catalog;
DROP TRIGGER lts_review_input_v465_25e6e9ba3e70 ON public.lts_external_reference_fact;
DROP TRIGGER lts_review_input_v465_1072b201addd ON public.lts_open_finance_sync_run;
DROP TRIGGER lts_review_input_v465_c807bf87fda3 ON public.lts_expense_effective_read_cache;
DROP TRIGGER lts_review_input_v465_38c9b3032dc8 ON public.lts_open_finance_resource_map;
DROP TRIGGER lts_review_input_v465_fdf581f11b31 ON public.lts_v229_documentary_match;
DROP TRIGGER lts_review_input_v465_d599010d244e ON public.lts_workbook_identity_evidence_v232;
DROP TRIGGER lts_review_input_v465_ea7e1de2ee7d ON public.lts_card_formula_resolution_v237;
DROP TRIGGER lts_review_input_v465_28b093856d08 ON public.lts_card_documentary_payment_link_v272;
DROP TRIGGER lts_review_input_v465_4417f605769e ON public.lts_card_settlement_expense_contract_v273;
DROP TRIGGER lts_review_input_v465_dab77b4a684f ON public.lts_category_binding_v290;
DROP TRIGGER lts_review_input_v465_97f5bd34090d ON public.lts_card_due_rule_v290;
DROP TRIGGER lts_review_input_v465_c85849c8528b ON public.lts_recurring_plan_v366;
DROP TRIGGER lts_review_input_v465_ac593f6bbc3f ON public.lts_card_due_transition_v370;
DROP TRIGGER lts_review_input_v465_fc8e2fc1a10d ON public.lts_card_due_estimate_v391;
DROP TRIGGER lts_review_input_v465_e327cda32e48 ON lts_product_refresh_private_v415.queue;
DROP TRIGGER lts_review_input_v465_3b2e4316d2ec ON lts_projection_private_v412.received_income_evidence_v443;
DROP FUNCTION lts_product_refresh_private_v415.review_input_contract_ok_v465(jsonb);
DROP FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
DROP TABLE lts_product_refresh_private_v415.review_input_hash_cache_v465,lts_product_refresh_private_v415.review_input_contract_v465,lts_product_refresh_private_v415.review_input_epoch_v465;
COMMIT;
