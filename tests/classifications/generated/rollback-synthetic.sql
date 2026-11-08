-- SYNTHETIC CONDITIONAL ROLLBACK. NOT PRODUCTION.
DO $rollback$
DECLARE u constant uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'; op constant text := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'; a jsonb; cur jsonb; n integer; targets jsonb; before_rows jsonb; after_rows jsonb; t jsonb; source_now jsonb; origin_now jsonb; key_now text; key_ids jsonb; outside_decisions_before jsonb; outside_decisions_after jsonb;
BEGIN
 PERFORM set_config('TimeZone','America/Sao_Paulo',true);
 IF public.lts_open_finance_pilot_owner_v1() IS DISTINCT FROM u THEN RAISE EXCEPTION 'owner mismatch'; END IF;
 PERFORM set_config('lock_timeout','5s',true);
 -- Table locks also serialize writers which do not take this operation's advisory lock.
 LOCK TABLE public.lts_access_audit, public.lts_open_finance_staging, public.lts_v178_review_decision IN SHARE ROW EXCLUSIVE MODE;
 PERFORM pg_advisory_xact_lock(hashtextextended('wealth-exact-classification:'||u::text,0));
 IF (SELECT count(*) FROM public.lts_access_audit WHERE user_id=u AND action='agent_restore_exact_classifications_20261016' AND meta->>'operation_id'=op)<>1 THEN RAISE EXCEPTION 'application audit missing or ambiguous'; END IF;
 SELECT meta INTO a FROM public.lts_access_audit WHERE user_id=u AND action='agent_restore_exact_classifications_20261016' AND meta->>'operation_id'=op;
 IF a IS NULL THEN RAISE EXCEPTION 'application audit missing'; END IF;
 IF EXISTS(SELECT 1 FROM public.lts_access_audit WHERE user_id=u AND action='agent_restore_exact_classifications_20261016_rollback' AND meta->>'operation_id'=op) THEN RAISE EXCEPTION 'rollback already recorded'; END IF;
 targets:=a->'targets';
 IF jsonb_typeof(targets) IS DISTINCT FROM 'array' OR jsonb_array_length(targets)<>5
 OR (SELECT count(DISTINCT j.value->>'source_ref') FROM jsonb_array_elements(targets) AS j(value))<>5
 OR a->'before_decisions' IS DISTINCT FROM '[]'::jsonb
 OR jsonb_typeof(a->'after_decisions') IS DISTINCT FROM 'array' OR jsonb_array_length(a->'after_decisions')<>5
 THEN RAISE EXCEPTION 'invalid application receipt'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p WHERE p.oid=to_regprocedure('public.lts_bank_known_classification_v231(uuid,uuid)')) IS DISTINCT FROM 'f0000000000000000000000000000001' THEN RAISE EXCEPTION 'reader lease changed: lts_bank_known_classification_v231(uuid,uuid)'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p WHERE p.oid=to_regprocedure('public.lts_card_installment_key_v231(lts_open_finance_staging)')) IS DISTINCT FROM 'f0000000000000000000000000000002' THEN RAISE EXCEPTION 'reader lease changed: lts_card_installment_key_v231(lts_open_finance_staging)'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p WHERE p.oid=to_regprocedure('public.lts_card_source_rows_pre_v262(uuid)')) IS DISTINCT FROM 'f0000000000000000000000000000003' THEN RAISE EXCEPTION 'reader lease changed: lts_card_source_rows_pre_v262(uuid)'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p WHERE p.oid=to_regprocedure('public.lts_expense_rows_v230_baseline(uuid,date,date)')) IS DISTINCT FROM 'f0000000000000000000000000000004' THEN RAISE EXCEPTION 'reader lease changed: lts_expense_rows_v230_baseline(uuid,date,date)'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p WHERE p.oid=to_regprocedure('public.lts_v229_expense_rows(uuid,date,date)')) IS DISTINCT FROM 'f0000000000000000000000000000005' THEN RAISE EXCEPTION 'reader lease changed: lts_v229_expense_rows(uuid,date,date)'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p WHERE p.oid=to_regprocedure('public.lts_open_finance_pilot_owner_v1()')) IS DISTINCT FROM 'f0000000000000000000000000000006' THEN RAISE EXCEPTION 'reader lease changed: lts_open_finance_pilot_owner_v1()'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p WHERE p.oid=to_regprocedure('public.lts_v246_invalidate_finance_cache()')) IS DISTINCT FROM 'f0000000000000000000000000000007' THEN RAISE EXCEPTION 'reader lease changed: lts_v246_invalidate_finance_cache()'; END IF;
 IF (SELECT jsonb_agg(jsonb_build_object('name',g.tgname,'enabled',g.tgenabled,'type',g.tgtype,'old',g.tgoldtable,'new',g.tgnewtable) ORDER BY g.tgname) FROM pg_trigger g WHERE g.tgrelid='public.lts_v178_review_decision'::regclass AND NOT g.tgisinternal AND g.tgfoid=to_regprocedure('public.lts_v246_invalidate_finance_cache()')) IS DISTINCT FROM '[{"name":"lts_v246_read_d","enabled":"O","type":8,"old":"old_rows","new":null},{"name":"lts_v246_read_i","enabled":"O","type":4,"old":null,"new":"new_rows"},{"name":"lts_v246_read_t","enabled":"O","type":32,"old":null,"new":null},{"name":"lts_v246_read_u","enabled":"O","type":16,"old":"old_rows","new":"new_rows"}]'::jsonb THEN RAISE EXCEPTION 'cache trigger binding changed'; END IF;
 FOR t IN SELECT value FROM jsonb_array_elements(targets) LOOP
  SELECT jsonb_build_object('source_id',s.id,'raw_hash',s.raw_hash,'resource_type',s.resource_type,'provider_record_id',s.provider_record_id,'provider_account_ref',s.provider_account_ref,'institution_code',s.institution_code,'description',s.description_raw,'signed_amount',s.signed_amount,'currency',s.currency,'posting_date',s.posting_date,'status',s.normalized_payload->>'status','provider_deleted_at',s.provider_deleted_at)
   || CASE WHEN t->'source_expected' ? 'card_metadata' THEN jsonb_build_object('card_metadata',s.raw_payload->'creditCardMetadata','normalized_payload',s.normalized_payload,'raw_description',s.raw_payload->>'description') ELSE '{}'::jsonb END
   INTO source_now FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id=(t->>'source_ref')::uuid;
  IF source_now IS DISTINCT FROM t->'source_expected' THEN RAISE EXCEPTION 'source changed: %',t->>'source_ref'; END IF;
  SELECT public.lts_card_installment_key_v231(s) INTO key_now FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id=(t->>'source_ref')::uuid;
  IF key_now IS DISTINCT FROM t->>'installment_key_expected' THEN RAISE EXCEPTION 'installment identity changed'; END IF;
  IF key_now IS NOT NULL THEN
   SELECT coalesce(jsonb_agg(s.id::text ORDER BY s.id::text),'[]') INTO key_ids FROM public.lts_open_finance_staging s WHERE s.user_id=u AND public.lts_card_installment_key_v231(s)=key_now;
   IF key_ids IS DISTINCT FROM t->'key_source_ids_expected' THEN RAISE EXCEPTION 'installment blast radius changed'; END IF;
  END IF;
  IF t->'origin_decision' <> 'null'::jsonb THEN
   SELECT to_jsonb(d) INTO origin_now FROM public.lts_v178_review_decision d WHERE d.user_id=u AND d.source_table=t#>>'{origin_decision,source_table}' AND d.source_ref=t#>>'{origin_decision,source_ref}';
   IF origin_now IS DISTINCT FROM t->'origin_decision' THEN RAISE EXCEPTION 'original decision changed'; END IF;
  END IF;
 END LOOP;
 SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY source_table,source_ref,event_date,row_key),'[]') INTO before_rows FROM public.lts_v229_expense_rows(u,date '2000-01-01',date '2099-01-01') e;
 SELECT coalesce(jsonb_agg(to_jsonb(d) ORDER BY user_id,source_table,source_ref),'[]') INTO outside_decisions_before FROM public.lts_v178_review_decision d WHERE NOT (d.user_id=u AND d.source_table='lts_open_finance_staging' AND d.source_ref IN(SELECT j.value->>'source_ref' FROM jsonb_array_elements(targets) AS j(value)));
 IF (SELECT jsonb_agg(e ORDER BY e::text) FROM jsonb_array_elements(before_rows)e WHERE e->>'source_table'='lts_open_finance_staging' AND e->>'source_ref' IN(SELECT j.value->>'source_ref' FROM jsonb_array_elements(targets) AS j(value))) IS DISTINCT FROM (SELECT jsonb_agg(e ORDER BY e::text) FROM jsonb_array_elements(a->'final_after_target_rows')e) THEN RAISE EXCEPTION 'target output changed: rollback blocked'; END IF;
 PERFORM 1 FROM public.lts_v178_review_decision d WHERE d.user_id=u AND d.source_table='lts_open_finance_staging' AND d.source_ref IN(SELECT j.value->>'source_ref' FROM jsonb_array_elements(a->'targets') AS j(value)) FOR UPDATE;
 SELECT jsonb_agg(to_jsonb(d) ORDER BY source_ref) INTO cur FROM public.lts_v178_review_decision d WHERE d.user_id=u AND d.source_table='lts_open_finance_staging' AND d.source_ref IN(SELECT j.value->>'source_ref' FROM jsonb_array_elements(a->'targets') AS j(value));
 IF cur IS DISTINCT FROM a->'after_decisions' THEN RAISE EXCEPTION 'concurrent decision change: rollback blocked'; END IF;
 DELETE FROM public.lts_v178_review_decision d WHERE d.user_id=u AND d.source_table='lts_open_finance_staging' AND d.source_ref IN(SELECT j.value->>'source_ref' FROM jsonb_array_elements(a->'targets') AS j(value));
 GET DIAGNOSTICS n=ROW_COUNT; IF n<>5 THEN RAISE EXCEPTION 'rollback cardinality'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY source_table,source_ref,event_date,row_key),'[]') INTO after_rows FROM public.lts_v229_expense_rows(u,date '2000-01-01',date '2099-01-01') e;
 IF jsonb_array_length(before_rows)<>jsonb_array_length(after_rows) THEN RAISE EXCEPTION 'expense cardinality changed'; END IF;
 IF EXISTS(
  (SELECT e-ARRAY['row_key','category','beneficiary','identity_status','management_group','management_subgroup','raw_category'] FROM jsonb_array_elements(before_rows)e
   EXCEPT ALL SELECT e-ARRAY['row_key','category','beneficiary','identity_status','management_group','management_subgroup','raw_category'] FROM jsonb_array_elements(after_rows)e)
  UNION ALL
  (SELECT e-ARRAY['row_key','category','beneficiary','identity_status','management_group','management_subgroup','raw_category'] FROM jsonb_array_elements(after_rows)e
   EXCEPT ALL SELECT e-ARRAY['row_key','category','beneficiary','identity_status','management_group','management_subgroup','raw_category'] FROM jsonb_array_elements(before_rows)e)
 ) THEN RAISE EXCEPTION 'financial projection changed'; END IF;
 IF EXISTS(
  (SELECT e FROM jsonb_array_elements(before_rows)e WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(targets) AS j(value) WHERE e->>'source_table'='lts_open_finance_staging' AND e->>'source_ref'=j.value->>'source_ref')
   EXCEPT ALL SELECT e FROM jsonb_array_elements(after_rows)e WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(targets) AS j(value) WHERE e->>'source_table'='lts_open_finance_staging' AND e->>'source_ref'=j.value->>'source_ref'))
  UNION ALL
  (SELECT e FROM jsonb_array_elements(after_rows)e WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(targets) AS j(value) WHERE e->>'source_table'='lts_open_finance_staging' AND e->>'source_ref'=j.value->>'source_ref')
   EXCEPT ALL SELECT e FROM jsonb_array_elements(before_rows)e WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(targets) AS j(value) WHERE e->>'source_table'='lts_open_finance_staging' AND e->>'source_ref'=j.value->>'source_ref'))
 ) THEN RAISE EXCEPTION 'unrelated output changed'; END IF;

 IF (SELECT jsonb_agg(e ORDER BY e::text) FROM jsonb_array_elements(after_rows)e WHERE e->>'source_table'='lts_open_finance_staging' AND e->>'source_ref' IN(SELECT j.value->>'source_ref' FROM jsonb_array_elements(targets) AS j(value))) IS DISTINCT FROM (SELECT jsonb_agg(e ORDER BY e::text) FROM jsonb_array_elements(a->'final_before_target_rows')e) THEN RAISE EXCEPTION 'rollback target restoration failed'; END IF;
 FOR t IN SELECT value FROM jsonb_array_elements(targets) LOOP
  SELECT jsonb_build_object('source_id',s.id,'raw_hash',s.raw_hash,'resource_type',s.resource_type,'provider_record_id',s.provider_record_id,'provider_account_ref',s.provider_account_ref,'institution_code',s.institution_code,'description',s.description_raw,'signed_amount',s.signed_amount,'currency',s.currency,'posting_date',s.posting_date,'status',s.normalized_payload->>'status','provider_deleted_at',s.provider_deleted_at)
   || CASE WHEN t->'source_expected' ? 'card_metadata' THEN jsonb_build_object('card_metadata',s.raw_payload->'creditCardMetadata','normalized_payload',s.normalized_payload,'raw_description',s.raw_payload->>'description') ELSE '{}'::jsonb END
   INTO source_now FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id=(t->>'source_ref')::uuid;
  IF source_now IS DISTINCT FROM t->'source_expected' THEN RAISE EXCEPTION 'source changed: %',t->>'source_ref'; END IF;
  SELECT public.lts_card_installment_key_v231(s) INTO key_now FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id=(t->>'source_ref')::uuid;
  IF key_now IS DISTINCT FROM t->>'installment_key_expected' THEN RAISE EXCEPTION 'installment identity changed'; END IF;
  IF key_now IS NOT NULL THEN
   SELECT coalesce(jsonb_agg(s.id::text ORDER BY s.id::text),'[]') INTO key_ids FROM public.lts_open_finance_staging s WHERE s.user_id=u AND public.lts_card_installment_key_v231(s)=key_now;
   IF key_ids IS DISTINCT FROM t->'key_source_ids_expected' THEN RAISE EXCEPTION 'installment blast radius changed'; END IF;
  END IF;
  IF t->'origin_decision' <> 'null'::jsonb THEN
   SELECT to_jsonb(d) INTO origin_now FROM public.lts_v178_review_decision d WHERE d.user_id=u AND d.source_table=t#>>'{origin_decision,source_table}' AND d.source_ref=t#>>'{origin_decision,source_ref}';
   IF origin_now IS DISTINCT FROM t->'origin_decision' THEN RAISE EXCEPTION 'original decision changed'; END IF;
  END IF;
 END LOOP;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p WHERE p.oid=to_regprocedure('public.lts_bank_known_classification_v231(uuid,uuid)')) IS DISTINCT FROM 'f0000000000000000000000000000001' THEN RAISE EXCEPTION 'reader lease changed: lts_bank_known_classification_v231(uuid,uuid)'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p WHERE p.oid=to_regprocedure('public.lts_card_installment_key_v231(lts_open_finance_staging)')) IS DISTINCT FROM 'f0000000000000000000000000000002' THEN RAISE EXCEPTION 'reader lease changed: lts_card_installment_key_v231(lts_open_finance_staging)'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p WHERE p.oid=to_regprocedure('public.lts_card_source_rows_pre_v262(uuid)')) IS DISTINCT FROM 'f0000000000000000000000000000003' THEN RAISE EXCEPTION 'reader lease changed: lts_card_source_rows_pre_v262(uuid)'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p WHERE p.oid=to_regprocedure('public.lts_expense_rows_v230_baseline(uuid,date,date)')) IS DISTINCT FROM 'f0000000000000000000000000000004' THEN RAISE EXCEPTION 'reader lease changed: lts_expense_rows_v230_baseline(uuid,date,date)'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p WHERE p.oid=to_regprocedure('public.lts_v229_expense_rows(uuid,date,date)')) IS DISTINCT FROM 'f0000000000000000000000000000005' THEN RAISE EXCEPTION 'reader lease changed: lts_v229_expense_rows(uuid,date,date)'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p WHERE p.oid=to_regprocedure('public.lts_open_finance_pilot_owner_v1()')) IS DISTINCT FROM 'f0000000000000000000000000000006' THEN RAISE EXCEPTION 'reader lease changed: lts_open_finance_pilot_owner_v1()'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p WHERE p.oid=to_regprocedure('public.lts_v246_invalidate_finance_cache()')) IS DISTINCT FROM 'f0000000000000000000000000000007' THEN RAISE EXCEPTION 'reader lease changed: lts_v246_invalidate_finance_cache()'; END IF;
 IF (SELECT jsonb_agg(jsonb_build_object('name',g.tgname,'enabled',g.tgenabled,'type',g.tgtype,'old',g.tgoldtable,'new',g.tgnewtable) ORDER BY g.tgname) FROM pg_trigger g WHERE g.tgrelid='public.lts_v178_review_decision'::regclass AND NOT g.tgisinternal AND g.tgfoid=to_regprocedure('public.lts_v246_invalidate_finance_cache()')) IS DISTINCT FROM '[{"name":"lts_v246_read_d","enabled":"O","type":8,"old":"old_rows","new":null},{"name":"lts_v246_read_i","enabled":"O","type":4,"old":null,"new":"new_rows"},{"name":"lts_v246_read_t","enabled":"O","type":32,"old":null,"new":null},{"name":"lts_v246_read_u","enabled":"O","type":16,"old":"old_rows","new":"new_rows"}]'::jsonb THEN RAISE EXCEPTION 'cache trigger binding changed'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(d) ORDER BY user_id,source_table,source_ref),'[]') INTO outside_decisions_after FROM public.lts_v178_review_decision d WHERE NOT (d.user_id=u AND d.source_table='lts_open_finance_staging' AND d.source_ref IN(SELECT j.value->>'source_ref' FROM jsonb_array_elements(targets) AS j(value)));
 IF outside_decisions_before IS DISTINCT FROM outside_decisions_after THEN RAISE EXCEPTION 'out-of-scope decisions changed'; END IF;
 INSERT INTO public.lts_access_audit(user_id,email,action,meta) VALUES(u,NULL,'agent_restore_exact_classifications_20261016_rollback',jsonb_build_object('operation_id',op,'restored_absence_count',n,'application_audit',a));
END
$rollback$;
