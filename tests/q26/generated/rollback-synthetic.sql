-- SYNTHETIC ONLY; gates true apply solely to disposable invented fixtures.
-- PRIVATE Q26 LOCAL CANDIDATE. NOT EXECUTED. RELEASE GATES ARE FALSE.
-- PRIVATE CONDITIONAL ROLLBACK CANDIDATE. NOT EXECUTED.
DO $rollback$
DECLARE u constant uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'; op constant text := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'; a jsonb; cur jsonb; n integer; targets jsonb; before_rows jsonb; after_rows jsonb; t jsonb; source_now jsonb; origin_now jsonb; key_now text; key_ids jsonb; outside_decisions_before jsonb; outside_decisions_after jsonb;

 release_gates constant jsonb := $release${"key_radius_receipt_verified":true,"independent_review_passed":true,"postgres17_synthetic_gate_passed":true,"current_schema_acl_rls_trigger_review_passed":true,"current_full_consumer_chain_authorized":true,"specific_production_authorization_verified":true}$release$::jsonb;
 expected_targets constant jsonb := $expected$[{"source_ref":"11111111-1111-4111-8111-000000000001","source_expected":{"source_id":"11111111-1111-4111-8111-000000000001","raw_hash":"fixture-hash-1","resource_type":"card_transaction","provider_record_id":"fixture-record-1","provider_account_ref":"fixture-account","institution_code":"SYNTHETIC","description":"SYNTHETIC MARKETPLACE","signed_amount":-10,"currency":"BRL","posting_date":"2001-02-01","status":"POSTED","provider_deleted_at":null,"card_metadata":{"synthetic_key":"fixture-key-1","cardNumber":"1234","purchaseDate":"2001-01-01T12:00:00.000Z","installmentNumber":2,"totalInstallments":3},"normalized_payload":{"status":"POSTED","synthetic_only":true},"raw_description":"SYNTHETIC MARKETPLACE","raw_id":"fixture-provider-1","raw_status":"POSTED","raw_category":"Shopping"},"decision_before":null,"category":"Synthetic Marketplace","beneficiary":"Synthetic Person","property_code":null,"origin_decision":{"user_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","source_table":"lts_open_finance_staging","source_ref":"11111111-1111-4111-8111-000000000002","beneficiary":"Synthetic Person","property_code":null,"category_label":"Synthetic Marketplace","decision_basis":"SYNTHETIC PRIOR DECISION","decided_at":"2000-07-01T00:00:00-03:00"},"final_before":{"amount":10,"row_key":"synthetic:11111111-1111-4111-8111-000000000001","category":"A classificar","event_date":"2001-02-01","source_ref":"11111111-1111-4111-8111-000000000001","beneficiary":null,"description":"SYNTHETIC MARKETPLACE","raw_category":"A classificar","source_table":"lts_open_finance_staging","coverage_mode":"synthetic","property_code":null,"purchase_date":"2001-01-01","raw_reference":"SYNTHETIC MARKETPLACE","account_source":"SYNTHETIC CARD","identity_status":"pending","competence_month":"2001-02-01","management_group":"A classificar","transaction_date":"2001-02-01","property_component":null,"management_subgroup":"A classificar"},"evidence":"SYNTHETIC","installment_key_expected":"fixture-key-1","key_source_ids_expected":["11111111-1111-4111-8111-000000000001"]}]$expected$::jsonb;
 protected_ids constant jsonb := '["11111111-1111-4111-8111-000000000001","11111111-1111-4111-8111-000000000002","11111111-1111-4111-8111-000000000003"]'::jsonb;
 evidence_sources constant jsonb := $sources$[{"id":"11111111-1111-4111-8111-000000000001","raw_hash":"fixture-hash-1","posting_date":"2001-02-01","signed_amount":-10,"description_raw":"SYNTHETIC MARKETPLACE","provider_account_ref":"fixture-account","currency":"BRL","status":"POSTED","card_metadata":{"synthetic_key":"fixture-key-1","cardNumber":"1234","purchaseDate":"2001-01-01T12:00:00.000Z","installmentNumber":2,"totalInstallments":3}},{"id":"11111111-1111-4111-8111-000000000002","raw_hash":"fixture-hash-2","posting_date":"2001-02-01","signed_amount":-10,"description_raw":"SYNTHETIC MARKETPLACE","provider_account_ref":"fixture-account","currency":"BRL","status":"PENDING","card_metadata":{"synthetic_key":"fixture-key-2","cardNumber":"1234","purchaseDate":"2001-01-01T12:00:00.001Z","installmentNumber":2,"totalInstallments":3}},{"id":"11111111-1111-4111-8111-000000000003","raw_hash":"fixture-hash-3","posting_date":"2001-02-01","signed_amount":-10,"description_raw":"SYNTHETIC MARKETPLACE","provider_account_ref":"fixture-account","currency":"BRL","status":"POSTED","card_metadata":{"synthetic_key":"fixture-key-3","cardNumber":"1234","purchaseDate":"2001-01-01T11:00:00.000Z","installmentNumber":1,"totalInstallments":3}}]$sources$::jsonb;
 origin_decisions constant jsonb := $origins$[{"user_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","source_table":"lts_open_finance_staging","source_ref":"11111111-1111-4111-8111-000000000002","beneficiary":"Synthetic Person","property_code":null,"category_label":"Synthetic Marketplace","decision_basis":"SYNTHETIC PRIOR DECISION","decided_at":"2000-07-01T00:00:00-03:00"},{"user_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","source_table":"lts_open_finance_staging","source_ref":"11111111-1111-4111-8111-000000000003","beneficiary":"Synthetic Person","property_code":null,"category_label":"Synthetic Marketplace","decision_basis":"SYNTHETIC PRIOR DECISION","decided_at":"2000-07-01T00:00:00-03:00"},{"user_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","source_table":"card_purchase_detail","source_ref":"synthetic-document-line","beneficiary":"Synthetic Person","property_code":null,"category_label":"Synthetic Marketplace","decision_basis":"SYNTHETIC PRIOR DECISION","decided_at":"2000-07-01T00:00:00-03:00"}]$origins$::jsonb;
 origin_audits constant jsonb := $audits$[{"id":-1,"user_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","action":"SYNTHETIC PRIOR AUDIT","created_at":"2000-07-01T00:00:00-03:00","meta":{"source_ref":"11111111-1111-4111-8111-000000000002","synthetic_only":true}},{"id":-2,"user_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","action":"SYNTHETIC PRIOR AUDIT","created_at":"2000-07-01T00:00:00-03:00","meta":{"source_ref":"11111111-1111-4111-8111-000000000003","synthetic_only":true}}]$audits$::jsonb;
 evidence_row jsonb; evidence_now jsonb; staging_before jsonb; staging_after jsonb; audit_now jsonb;
BEGIN

 -- Fail closed before locks, functions, readers, or writes. Local evidence is not authorization.
 IF release_gates IS DISTINCT FROM (SELECT jsonb_object_agg(key,'true'::jsonb) FROM jsonb_each(release_gates)) THEN RAISE EXCEPTION 'Q26 release gates incomplete; local candidate only'; END IF;
 PERFORM set_config('TimeZone','America/Sao_Paulo',true);
 IF public.lts_open_finance_pilot_owner_v1() IS DISTINCT FROM u THEN RAISE EXCEPTION 'owner mismatch'; END IF;
 PERFORM set_config('lock_timeout','5s',true);
 -- Table locks also serialize writers which do not take this operation's advisory lock.
 LOCK TABLE public.lts_access_audit, public.lts_open_finance_staging, public.lts_v178_review_decision IN SHARE ROW EXCLUSIVE MODE;
 PERFORM pg_advisory_xact_lock(hashtextextended('wealth-exact-classification:'||u::text,0));

 FOR evidence_row IN SELECT j.value FROM jsonb_array_elements(evidence_sources) AS j(value) LOOP
  SELECT jsonb_build_object('id',s.id,'raw_hash',s.raw_hash,'posting_date',s.posting_date,'signed_amount',s.signed_amount,'description_raw',s.description_raw,'provider_account_ref',s.provider_account_ref,'currency',s.currency,'status',s.normalized_payload->>'status','card_metadata',s.raw_payload->'creditCardMetadata') INTO evidence_now
  FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id=(evidence_row->>'id')::uuid;
  IF evidence_now IS DISTINCT FROM evidence_row THEN RAISE EXCEPTION 'Q26 witness source changed'; END IF;
 END LOOP;
 FOR evidence_row IN SELECT j.value FROM jsonb_array_elements(origin_decisions) AS j(value) LOOP
  SELECT to_jsonb(d) INTO evidence_now FROM public.lts_v178_review_decision d WHERE d.user_id=u AND d.source_table=evidence_row->>'source_table' AND d.source_ref=evidence_row->>'source_ref';
  IF evidence_now IS DISTINCT FROM evidence_row THEN RAISE EXCEPTION 'Q26 lineage decision changed'; END IF;
 END LOOP;
 FOR evidence_row IN SELECT j.value FROM jsonb_array_elements(origin_audits) AS j(value) LOOP
  SELECT jsonb_build_object('id',a.id,'meta',a.meta,'action',a.action,'user_id',a.user_id,'created_at',a.created_at) INTO evidence_now FROM public.lts_access_audit a WHERE a.user_id=u AND a.id=(evidence_row->>'id')::bigint;
  IF evidence_now IS DISTINCT FROM evidence_row THEN RAISE EXCEPTION 'Q26 lineage audit changed'; END IF;
 END LOOP;
 SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.id),'[]'::jsonb) INTO staging_before FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id::text IN (SELECT jsonb_array_elements_text(protected_ids));
 IF jsonb_array_length(staging_before)<>3 THEN RAISE EXCEPTION 'Q26 protected source cardinality'; END IF;
 IF (SELECT count(*) FROM public.lts_access_audit WHERE user_id=u AND action='agent_restore_q26_synthetic_20261016' AND meta->>'operation_id'=op)<>1 THEN RAISE EXCEPTION 'application audit missing or ambiguous'; END IF;
 SELECT meta INTO a FROM public.lts_access_audit WHERE user_id=u AND action='agent_restore_q26_synthetic_20261016' AND meta->>'operation_id'=op;
 IF a IS NULL THEN RAISE EXCEPTION 'application audit missing'; END IF;
 IF EXISTS(SELECT 1 FROM public.lts_access_audit WHERE user_id=u AND action='agent_restore_q26_synthetic_20261016_rollback' AND meta->>'operation_id'=op) THEN RAISE EXCEPTION 'rollback already recorded'; END IF;
 targets:=a->'targets';
 IF targets IS DISTINCT FROM expected_targets OR a->'target_count' IS DISTINCT FROM '1'::jsonb OR a->'origin_decisions' IS DISTINCT FROM origin_decisions OR a->'origin_audits' IS DISTINCT FROM origin_audits OR a->'official_provider_link' IS DISTINCT FROM 'false'::jsonb OR a->'staging_before' IS DISTINCT FROM staging_before THEN RAISE EXCEPTION 'Q26 pinned receipt or source mismatch'; END IF;
 IF jsonb_typeof(targets) IS DISTINCT FROM 'array' OR jsonb_array_length(targets)<>1
 OR (SELECT count(DISTINCT j.value->>'source_ref') FROM jsonb_array_elements(targets) AS j(value))<>1
 OR a->'before_decisions' IS DISTINCT FROM '[]'::jsonb
 OR jsonb_typeof(a->'after_decisions') IS DISTINCT FROM 'array' OR jsonb_array_length(a->'after_decisions')<>1
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
   || CASE WHEN t->'source_expected' ? 'card_metadata' THEN jsonb_build_object('card_metadata',s.raw_payload->'creditCardMetadata','normalized_payload',s.normalized_payload,'raw_description',s.raw_payload->>'description','raw_id',s.raw_payload->>'id','raw_status',s.raw_payload->>'status','raw_category',s.raw_payload->>'category') ELSE '{}'::jsonb END
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
 GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'rollback cardinality'; END IF;
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
   || CASE WHEN t->'source_expected' ? 'card_metadata' THEN jsonb_build_object('card_metadata',s.raw_payload->'creditCardMetadata','normalized_payload',s.normalized_payload,'raw_description',s.raw_payload->>'description','raw_id',s.raw_payload->>'id','raw_status',s.raw_payload->>'status','raw_category',s.raw_payload->>'category') ELSE '{}'::jsonb END
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
 INSERT INTO public.lts_access_audit(user_id,email,action,meta) VALUES(u,NULL,'agent_restore_q26_synthetic_20261016_rollback',jsonb_build_object('operation_id',op,'restored_absence_count',n,'application_audit',a));

 FOR evidence_row IN SELECT j.value FROM jsonb_array_elements(evidence_sources) AS j(value) LOOP
  SELECT jsonb_build_object('id',s.id,'raw_hash',s.raw_hash,'posting_date',s.posting_date,'signed_amount',s.signed_amount,'description_raw',s.description_raw,'provider_account_ref',s.provider_account_ref,'currency',s.currency,'status',s.normalized_payload->>'status','card_metadata',s.raw_payload->'creditCardMetadata') INTO evidence_now
  FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id=(evidence_row->>'id')::uuid;
  IF evidence_now IS DISTINCT FROM evidence_row THEN RAISE EXCEPTION 'Q26 witness source changed'; END IF;
 END LOOP;
 FOR evidence_row IN SELECT j.value FROM jsonb_array_elements(origin_decisions) AS j(value) LOOP
  SELECT to_jsonb(d) INTO evidence_now FROM public.lts_v178_review_decision d WHERE d.user_id=u AND d.source_table=evidence_row->>'source_table' AND d.source_ref=evidence_row->>'source_ref';
  IF evidence_now IS DISTINCT FROM evidence_row THEN RAISE EXCEPTION 'Q26 lineage decision changed'; END IF;
 END LOOP;
 FOR evidence_row IN SELECT j.value FROM jsonb_array_elements(origin_audits) AS j(value) LOOP
  SELECT jsonb_build_object('id',a.id,'meta',a.meta,'action',a.action,'user_id',a.user_id,'created_at',a.created_at) INTO evidence_now FROM public.lts_access_audit a WHERE a.user_id=u AND a.id=(evidence_row->>'id')::bigint;
  IF evidence_now IS DISTINCT FROM evidence_row THEN RAISE EXCEPTION 'Q26 lineage audit changed'; END IF;
 END LOOP;
 SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.id),'[]'::jsonb) INTO staging_after FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id::text IN (SELECT jsonb_array_elements_text(protected_ids));
 IF staging_before IS DISTINCT FROM staging_after THEN RAISE EXCEPTION 'Q26 full protected source changed'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(d) ORDER BY user_id,source_table,source_ref),'[]') INTO outside_decisions_after FROM public.lts_v178_review_decision d WHERE NOT (d.user_id=u AND d.source_table='lts_open_finance_staging' AND d.source_ref IN(SELECT j.value->>'source_ref' FROM jsonb_array_elements(targets) AS j(value)));
 IF outside_decisions_before IS DISTINCT FROM outside_decisions_after THEN RAISE EXCEPTION 'Q26 audit insert changed outside decisions'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(d) ORDER BY source_ref),'[]') INTO audit_now FROM public.lts_v178_review_decision d WHERE d.user_id=u AND d.source_table='lts_open_finance_staging' AND d.source_ref IN(SELECT j.value->>'source_ref' FROM jsonb_array_elements(targets) AS j(value));
 IF audit_now IS DISTINCT FROM '[]'::jsonb THEN RAISE EXCEPTION 'Q26 rollback absence not preserved'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY source_table,source_ref,event_date,row_key),'[]') INTO audit_now FROM public.lts_v229_expense_rows(u,date '2000-01-01',date '2099-01-01') e;
 IF audit_now IS DISTINCT FROM after_rows THEN RAISE EXCEPTION 'Q26 audit insert changed final output'; END IF;
END
$rollback$;
