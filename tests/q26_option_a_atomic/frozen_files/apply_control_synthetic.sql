-- LOCAL HELD CONTROL, NOT A MIGRATION OR RELEASE. No execution authorized by this file.
-- No new persistent object, grant, policy, index or helper is permitted.
-- All financial reads/consumer comparisons occur outside the short atomic section.
-- Runtime pin and exact replacement DDL remain unbound pending PG/review/fresh lease.
DO $option_a_apply$
DECLARE l jsonb:=__ATOMIC_LEASE__; fixed jsonb:=(SELECT value FROM public.fixture_atomic_config WHERE key='fixed'); required jsonb:=(SELECT value FROM public.fixture_atomic_config WHERE key='required');
 u uuid;op uuid;rep uuid;prior uuid;inv uuid;item jsonb;actual jsonb;sources jsonb;prior_decision jsonb;decision jsonb;evidence_rows jsonb;receipts jsonb;
 actual_pin text;evidence_after jsonb;decision_after jsonb;n integer;epoch_before bigint;epoch_after bigint;audit_id bigint;critical_at timestamptz;evidence_locked_at timestamptz;lease_expires_at timestamptz;revoked_at timestamptz;decision_at timestamptz;apply_receipt jsonb;compensation_receipt jsonb;
BEGIN

 PERFORM set_config('search_path','pg_catalog,public',true);
 PERFORM set_config('TimeZone','UTC',true);
 PERFORM set_config('lock_timeout','2s',true);
 -- No claim that an internal statement_timeout retroactively times this DO.
 IF l->'ready' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'held: not released'; END IF;
 IF current_setting('transaction_read_only')<>'off' OR current_setting('transaction_isolation')<>'read committed' THEN
  RAISE EXCEPTION 'writable READ COMMITTED atomic context required'; END IF;
 IF l->>'database' IS DISTINCT FROM current_database() OR l->>'role' IS DISTINCT FROM current_user THEN RAISE EXCEPTION 'database/role mismatch'; END IF;
 IF jsonb_typeof(l->'expires_at') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'lease expiry must be a JSON string'; END IF;
 BEGIN
  lease_expires_at := (l->>'expires_at')::timestamptz;
 EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN RAISE EXCEPTION 'lease expiry parse rejected'; END;
 IF lease_expires_at IS NULL OR NOT isfinite(lease_expires_at) OR lease_expires_at<=clock_timestamp() THEN RAISE EXCEPTION 'lease absent, nonfinite or expired'; END IF;
 IF l->>'owner_id' IS DISTINCT FROM fixed->>'owner_id' THEN RAISE EXCEPTION 'fixed owner scope mismatch'; END IF;
 u:=(fixed->>'owner_id')::uuid; op:=(fixed->>'operation_id')::uuid;
 rep:=(fixed->>'representative_id')::uuid; prior:=(fixed->>'prior_id')::uuid; inv:=(fixed->>'invoice_anchor_id')::uuid;
 IF NOT pg_try_advisory_xact_lock(hashtextextended('option-a-two-consumer-ddl-v1',0)) THEN RAISE EXCEPTION 'cooperating installer busy'; END IF;
 -- Catalog-only checks are deliberately before the evidence writer lock.
 IF jsonb_typeof(l->'catalog_contracts') IS DISTINCT FROM 'object'
 OR jsonb_typeof(l#>'{catalog_contracts,functions}') IS DISTINCT FROM 'array'
 OR jsonb_typeof(l#>'{catalog_contracts,relations}') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'catalog lease missing'; END IF;
 IF (SELECT jsonb_agg(v->>'signature' ORDER BY v->>'signature') FROM jsonb_array_elements(l#>'{catalog_contracts,functions}')v)
 IS DISTINCT FROM required->'functions' THEN RAISE EXCEPTION 'exact function coverage required'; END IF;
 IF (SELECT jsonb_agg(v->>'name' ORDER BY v->>'name') FROM jsonb_array_elements(l#>'{catalog_contracts,relations}')v)
 IS DISTINCT FROM required->'relations' THEN RAISE EXCEPTION 'exact relation coverage required'; END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(l#>'{catalog_contracts,functions}') LOOP
  SELECT jsonb_build_object('signature',item->>'signature','definition_md5',md5(pg_get_functiondef(p.oid)),
 'prosrc_sha256',encode(sha256(convert_to(p.prosrc,'UTF8')),'hex'),'owner',pg_get_userbyid(p.proowner),
 'acl',p.proacl::text[],'config',p.proconfig,'language',la.lanname,'volatility',p.provolatile,
 'security_definer',p.prosecdef,'result',pg_get_function_result(p.oid)) INTO actual FROM pg_proc p JOIN pg_language la ON la.oid=p.prolang WHERE p.oid=to_regprocedure(item->>'signature');
  IF actual IS DISTINCT FROM item THEN RAISE EXCEPTION 'function catalog drift: %',item->>'signature'; END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(l#>'{catalog_contracts,relations}') LOOP
  SELECT jsonb_build_object('name',r.relname,'owner',pg_get_userbyid(r.relowner),'kind',r.relkind,
 'acl',r.relacl::text[],'rls',r.relrowsecurity,'force_rls',r.relforcerowsecurity,
 'columns',(SELECT jsonb_agg(jsonb_build_object('name',a.attname,'type',format_type(a.atttypid,a.atttypmod),
  'not_null',a.attnotnull,'identity',a.attidentity,'generated',a.attgenerated,'acl',a.attacl::text[],
  'default',pg_get_expr(ad.adbin,ad.adrelid)) ORDER BY a.attnum)
  FROM pg_attribute a LEFT JOIN pg_attrdef ad ON ad.adrelid=a.attrelid AND ad.adnum=a.attnum WHERE a.attrelid=r.oid AND a.attnum>0 AND NOT a.attisdropped),
 'policies',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',p.polname,'command',p.polcmd,'roles',p.polroles,
  'using',pg_get_expr(p.polqual,p.polrelid),'check',pg_get_expr(p.polwithcheck,p.polrelid),'permissive',p.polpermissive) ORDER BY p.polname),'[]') FROM pg_policy p WHERE p.polrelid=r.oid),
 'constraints',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',c.conname,'type',c.contype,'definition',pg_get_constraintdef(c.oid),'validated',c.convalidated) ORDER BY c.conname),'[]') FROM pg_constraint c WHERE c.conrelid=r.oid),
 'indexes',(SELECT coalesce(jsonb_agg(jsonb_build_object('definition',pg_get_indexdef(i.indexrelid),'valid',i.indisvalid,'ready',i.indisready,'unique',i.indisunique) ORDER BY i.indexrelid::regclass::text),'[]') FROM pg_index i WHERE i.indrelid=r.oid),
 'triggers',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',t.tgname,'enabled',t.tgenabled,'definition',pg_get_triggerdef(t.oid),'function_md5',md5(pg_get_functiondef(t.tgfoid))) ORDER BY t.tgname),'[]') FROM pg_trigger t WHERE t.tgrelid=r.oid AND NOT t.tgisinternal)) INTO actual FROM pg_class r WHERE r.oid=to_regclass('public.'||(item->>'name'));
  IF actual IS DISTINCT FROM item THEN RAISE EXCEPTION 'relation catalog drift: %',item->>'name'; END IF;
 END LOOP;
 -- Excludes all evidence writers briefly, including different-ID logical competitors.
 LOCK TABLE public.lts_reconciliation_evidence IN SHARE ROW EXCLUSIVE MODE;
 evidence_locked_at:=clock_timestamp();
 -- A DDL writer may have committed while this transaction waited for the evidence lock.
 FOR item IN SELECT value FROM jsonb_array_elements(l#>'{catalog_contracts,relations}') LOOP
  SELECT jsonb_build_object('name',r.relname,'owner',pg_get_userbyid(r.relowner),'kind',r.relkind,
 'acl',r.relacl::text[],'rls',r.relrowsecurity,'force_rls',r.relforcerowsecurity,
 'columns',(SELECT jsonb_agg(jsonb_build_object('name',a.attname,'type',format_type(a.atttypid,a.atttypmod),
  'not_null',a.attnotnull,'identity',a.attidentity,'generated',a.attgenerated,'acl',a.attacl::text[],
  'default',pg_get_expr(ad.adbin,ad.adrelid)) ORDER BY a.attnum)
  FROM pg_attribute a LEFT JOIN pg_attrdef ad ON ad.adrelid=a.attrelid AND ad.adnum=a.attnum WHERE a.attrelid=r.oid AND a.attnum>0 AND NOT a.attisdropped),
 'policies',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',p.polname,'command',p.polcmd,'roles',p.polroles,
  'using',pg_get_expr(p.polqual,p.polrelid),'check',pg_get_expr(p.polwithcheck,p.polrelid),'permissive',p.polpermissive) ORDER BY p.polname),'[]') FROM pg_policy p WHERE p.polrelid=r.oid),
 'constraints',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',c.conname,'type',c.contype,'definition',pg_get_constraintdef(c.oid),'validated',c.convalidated) ORDER BY c.conname),'[]') FROM pg_constraint c WHERE c.conrelid=r.oid),
 'indexes',(SELECT coalesce(jsonb_agg(jsonb_build_object('definition',pg_get_indexdef(i.indexrelid),'valid',i.indisvalid,'ready',i.indisready,'unique',i.indisunique) ORDER BY i.indexrelid::regclass::text),'[]') FROM pg_index i WHERE i.indrelid=r.oid),
 'triggers',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',t.tgname,'enabled',t.tgenabled,'definition',pg_get_triggerdef(t.oid),'function_md5',md5(pg_get_functiondef(t.tgfoid))) ORDER BY t.tgname),'[]') FROM pg_trigger t WHERE t.tgrelid=r.oid AND NOT t.tgisinternal)) INTO actual FROM pg_class r WHERE r.oid=to_regclass('public.'||(item->>'name'));
  IF actual IS DISTINCT FROM item THEN RAISE EXCEPTION 'relation catalog drift after lock: %',item->>'name'; END IF;
 END LOOP;
 PERFORM 1 FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id IN(rep,prior,inv) ORDER BY s.id FOR UPDATE;
 IF (SELECT count(*) FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id IN(rep,prior,inv))<>3 THEN RAISE EXCEPTION 'nominal source cardinality'; END IF;
 PERFORM 1 FROM public.lts_v178_review_decision d WHERE d.user_id=u AND d.source_table='lts_open_finance_staging' AND d.source_ref=prior::text FOR SHARE;
 SELECT jsonb_agg(to_jsonb(s) ORDER BY s.id) INTO sources FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id IN(rep,prior,inv);
 IF sources IS DISTINCT FROM l->'source_full_beforeimages' THEN RAISE EXCEPTION 'full fresh source lease drift'; END IF;
 IF (SELECT to_jsonb(s) @> (fixed#>'{identity_contract,representative_identity}') FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id=rep) IS DISTINCT FROM true
 OR (SELECT to_jsonb(s) @> (fixed#>'{identity_contract,prior_identity}') FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id=prior) IS DISTINCT FROM true
 OR (SELECT to_jsonb(s) @> (fixed#>'{identity_contract,invoice_anchor_identity}') FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id=inv) IS DISTINCT FROM true THEN RAISE EXCEPTION 'economic identity differs from fixed reviewed relation'; END IF;
 SELECT to_jsonb(d) INTO prior_decision FROM public.lts_v178_review_decision d WHERE d.user_id=u AND d.source_table='lts_open_finance_staging' AND d.source_ref=prior::text;
 IF prior_decision IS DISTINCT FROM l->'prior_decision' OR prior_decision IS NULL THEN RAISE EXCEPTION 'prior classification lineage drift'; END IF;
 SELECT to_jsonb(d) INTO decision FROM public.lts_v178_review_decision d WHERE d.user_id=u AND d.source_table='lts_open_finance_staging' AND d.source_ref=rep::text;
 SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY e.id),'[]') INTO evidence_rows FROM public.lts_reconciliation_evidence e WHERE e.user_id=u AND
  (e.id=op OR e.source_ref='owner_confirmed_card_observation_pair_v1:'||op::text OR e.metadata#>>'{contract,operation_id}'=op::text
   OR e.evidence_type='owner_confirmed_card_observation_pair_v1');
 PERFORM 1 FROM public.lts_access_audit a WHERE a.user_id=u AND a.action IN('option_a_nominal_apply_v1','option_a_nominal_rollback_v1') AND a.meta->>'operation_id'=op::text ORDER BY a.id FOR SHARE;
 SELECT coalesce(jsonb_agg(to_jsonb(a) ORDER BY a.id),'[]') INTO receipts FROM public.lts_access_audit a WHERE a.user_id=u
  AND a.action IN('option_a_nominal_apply_v1','option_a_nominal_rollback_v1') AND a.meta->>'operation_id'=op::text;
 IF lease_expires_at<=clock_timestamp() THEN RAISE EXCEPTION 'lease expired while acquiring locks'; END IF;
 -- This lock does not prove permanent uniqueness or immunity to later privileged audit edits.

 IF l->>'operation_id' IS DISTINCT FROM op::text THEN RAISE EXCEPTION 'operation mismatch'; END IF;
 IF jsonb_typeof(l->'required_gates') IS DISTINCT FROM 'object'
 OR (SELECT jsonb_agg(k ORDER BY k) FROM jsonb_object_keys(l->'required_gates')k)
 IS DISTINCT FROM '["competing_writer_gate_passed","consumer_pg339_passed","fresh_financial_and_catalog_leases","independent_review_passed","policy_scope_released","transactional_pg_passed"]'::jsonb
 OR EXISTS(SELECT 1 FROM jsonb_each(l->'required_gates')x WHERE x.value IS DISTINCT FROM 'true'::jsonb) THEN RAISE EXCEPTION 'required gates not complete'; END IF;
 IF jsonb_typeof(l->'expected_complete_state')='object'
 AND evidence_rows IS NOT DISTINCT FROM l#>'{expected_complete_state,evidence_rows}'
 AND decision IS NOT DISTINCT FROM l#>'{expected_complete_state,decision}'
 AND receipts IS NOT DISTINCT FROM l#>'{expected_complete_state,receipts}'
 AND jsonb_array_length(evidence_rows)=1 AND jsonb_array_length(receipts)=1
 AND receipts#>>'{0,action}'='option_a_nominal_apply_v1'
 AND receipts#>>'{0,meta,status}'='pending_postcheck'
 AND evidence_rows#>'{0,metadata,state,active}'='true'::jsonb THEN
  IF encode(sha256(convert_to((receipts->0)::text,'UTF8')),'hex') IS DISTINCT FROM l#>>'{expected_complete_state,receipt_sha256}'
  OR encode(sha256(convert_to((evidence_rows->0)::text,'UTF8')),'hex') IS DISTINCT FROM receipts#>>'{0,meta,evidence_row_sha256}'
  OR encode(sha256(convert_to(decision::text,'UTF8')),'hex') IS DISTINCT FROM receipts#>>'{0,meta,representative_decision_sha256}'
  THEN RAISE EXCEPTION 'idempotent row/receipt anchors differ'; END IF;
  -- Complete-state contracts must be the currently leased candidate contracts, not old bodies.
  IF l#>'{expected_complete_state,function_contracts}' IS DISTINCT FROM
   (SELECT jsonb_agg(v ORDER BY v->>'signature') FROM jsonb_array_elements(l#>'{catalog_contracts,functions}')v WHERE v->>'signature' IN('public.lts_v229_expense_rows(uuid,date,date)','public.lts_browser_card_detail_v226(text,date)')) THEN RAISE EXCEPTION 'idempotent consumer state mismatch'; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(l#>'{expected_complete_state,function_contracts}') v WHERE v->>'definition_md5' IS DISTINCT FROM (receipts#>'{0,meta,function_after_md5}')->>(v->>'signature')) THEN RAISE EXCEPTION 'idempotent compiled hashes differ'; END IF;
  SELECT epoch INTO epoch_before FROM public.lts_read_cache_epoch_v242 WHERE singleton;
  IF epoch_before IS DISTINCT FROM (l->>'current_epoch')::bigint THEN RAISE EXCEPTION 'idempotent epoch drift'; END IF;
  IF lease_expires_at<=clock_timestamp() THEN RAISE EXCEPTION 'lease expired at idempotent boundary'; END IF;
  IF clock_timestamp()-evidence_locked_at>interval '2 seconds' THEN RAISE EXCEPTION 'idempotent check exceeded evidence-lock budget'; END IF;
  RETURN;
 END IF;
 IF evidence_rows<>'[]'::jsonb OR receipts<>'[]'::jsonb OR decision IS NOT NULL THEN RAISE EXCEPTION 'partial, conflicting or already used operation; no overwrite'; END IF;
 -- Owner-bound bridge collision checks; global PK collision still aborts naturally without reading another owner.
 IF EXISTS(SELECT 1 FROM public.financial_events f WHERE f.user_id=u AND (f.id=op OR f.legacy_id=op::text)) THEN RAISE EXCEPTION 'bridge source_ref collision'; END IF;
 IF jsonb_typeof(l#>'{evidence_insert,metadata}') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'evidence metadata root must be object'; END IF;
 IF (SELECT jsonb_agg(k ORDER BY k) FROM jsonb_object_keys(l#>'{evidence_insert,metadata}')k) IS DISTINCT FROM '["contract","immutable_fingerprint","state"]'::jsonb
 THEN RAISE EXCEPTION 'evidence metadata root keys must match runtime contract'; END IF;
 IF jsonb_typeof(l->'evidence_insert') IS DISTINCT FROM 'object' OR jsonb_typeof(l->'representative_decision_insert') IS DISTINCT FROM 'object'
 OR l#>>'{evidence_insert,id}' IS DISTINCT FROM op::text OR l#>>'{evidence_insert,user_id}' IS DISTINCT FROM u::text
 OR l#>>'{evidence_insert,evidence_date}' IS DISTINCT FROM '2020-10-16'
 OR l#>>'{evidence_insert,evidence_type}' IS DISTINCT FROM 'owner_confirmed_card_observation_pair_v1'
 OR l#>>'{evidence_insert,status}' IS DISTINCT FROM 'documented'
 OR l#>>'{evidence_insert,metadata,contract,owner_id}' IS DISTINCT FROM u::text
 OR l#>>'{evidence_insert,metadata,contract,representative_id}' IS DISTINCT FROM rep::text
 OR l#>>'{evidence_insert,metadata,contract,prior_id}' IS DISTINCT FROM prior::text
 OR l#>>'{evidence_insert,metadata,contract,invoice_anchor_id}' IS DISTINCT FROM inv::text
 OR l#>'{evidence_insert,metadata,contract}' IS DISTINCT FROM fixed->'identity_contract'
 OR ((l->'evidence_insert')-ARRAY['metadata','created_at']) IS DISTINCT FROM fixed->'evidence_external_projection'
 OR l#>'{evidence_insert,metadata,state}' IS DISTINCT FROM '{"active":true,"revoked_at":null,"revocation_operation_id":null}'::jsonb
 OR l#>>'{representative_decision_insert,user_id}' IS DISTINCT FROM u::text
 OR l#>>'{representative_decision_insert,source_table}' IS DISTINCT FROM 'lts_open_finance_staging'
 OR l#>>'{representative_decision_insert,source_ref}' IS DISTINCT FROM rep::text
 OR l#>'{representative_decision_insert,category_label}' IS DISTINCT FROM prior_decision->'category_label'
 OR l#>'{representative_decision_insert,beneficiary}' IS DISTINCT FROM prior_decision->'beneficiary'
 OR l#>'{representative_decision_insert,property_code}' IS DISTINCT FROM prior_decision->'property_code'
 THEN RAISE EXCEPTION 'nominal insertion scope mismatch'; END IF;
 IF (SELECT jsonb_agg(k ORDER BY k) FROM jsonb_object_keys(l->'representative_decision_insert')k) IS DISTINCT FROM '["beneficiary","category_label","decided_at","decision_basis","property_code","source_ref","source_table","user_id"]'::jsonb
 OR l#>>'{representative_decision_insert,decision_basis}' IS DISTINCT FROM 'owner_confirmed_nominal_composite_identity:'||op::text
 OR jsonb_typeof(l#>'{representative_decision_insert,decided_at}') IS DISTINCT FROM 'string'
 THEN RAISE EXCEPTION 'exact decision columns and basis required'; END IF;
 BEGIN
  decision_at:=(l#>>'{representative_decision_insert,decided_at}')::timestamptz;
 EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN RAISE EXCEPTION 'decision timestamp parse rejected'; END;
 IF decision_at IS NULL OR NOT isfinite(decision_at) THEN RAISE EXCEPTION 'decision timestamp nonfinite'; END IF;
 IF jsonb_typeof(l->'immutable_fingerprint') IS DISTINCT FROM 'string' OR l->>'immutable_fingerprint' !~ '^[0-9a-f]{64}$'
 OR l#>>'{evidence_insert,metadata,immutable_fingerprint}' IS DISTINCT FROM l->>'immutable_fingerprint' THEN RAISE EXCEPTION 'unbound canonical pin'; END IF;
 SELECT encode(sha256(convert_to(jsonb_build_object('schema','q26-evidence-immutable-v2',
  'evidence',jsonb_build_object('id',e.id,'user_id',e.user_id,'evidence_date',e.evidence_date,'account',e.account,'amount',e.amount,'description',e.description,'evidence_type',e.evidence_type,'source_ref',e.source_ref,'status',e.status),
  'contract',e.metadata->'contract')::text,'UTF8')),'hex') INTO actual_pin
 FROM jsonb_populate_record(NULL::public.lts_reconciliation_evidence,l->'evidence_insert')e;
 IF actual_pin IS DISTINCT FROM l->>'immutable_fingerprint' THEN RAISE EXCEPTION 'canonical immutable pin mismatch'; END IF;
 IF jsonb_typeof(l->'consumer_replacements') IS DISTINCT FROM 'array' OR jsonb_array_length(l->'consumer_replacements')<>2
 OR (SELECT jsonb_agg(v->>'signature' ORDER BY v->>'signature') FROM jsonb_array_elements(l->'consumer_replacements')v)
 IS DISTINCT FROM '["public.lts_browser_card_detail_v226(text,date)","public.lts_v229_expense_rows(uuid,date,date)"]'::jsonb THEN RAISE EXCEPTION 'two exact consumers required'; END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(l->'consumer_replacements') ORDER BY value->>'signature' LOOP
  IF jsonb_typeof(item->'definition') IS DISTINCT FROM 'string' OR item->>'definition' LIKE '%UNBOUND%'
   OR encode(sha256(convert_to(item->>'definition','UTF8')),'hex') IS DISTINCT FROM item->>'reviewed_definition_sha256'
   OR item->'before_contract' IS DISTINCT FROM (SELECT v FROM jsonb_array_elements(l#>'{catalog_contracts,functions}')v WHERE v->>'signature'=item->>'signature')
   OR jsonb_typeof(item->'after_contract') IS DISTINCT FROM 'object'
   OR ((item->'before_contract')-ARRAY['definition_md5','prosrc_sha256']) IS DISTINCT FROM ((item->'after_contract')-ARRAY['definition_md5','prosrc_sha256'])
   THEN RAISE EXCEPTION 'replacement payload/contract not exact'; END IF;
 END LOOP;
 -- The global epoch is acquired last. No historical/core/browser consumer runs below.
 PERFORM 1 FROM public.lts_read_cache_epoch_v242 WHERE singleton FOR UPDATE;
 SELECT epoch INTO epoch_before FROM public.lts_read_cache_epoch_v242 WHERE singleton;
 IF epoch_before IS DISTINCT FROM (l->>'current_epoch')::bigint THEN RAISE EXCEPTION 'epoch lease drift'; END IF;
 IF (SELECT coalesce(jsonb_agg(to_jsonb(a) ORDER BY a.id),'[]') FROM public.lts_access_audit a WHERE a.user_id=u
  AND a.action IN('option_a_nominal_apply_v1','option_a_nominal_rollback_v1') AND a.meta->>'operation_id'=op::text) IS DISTINCT FROM receipts
 THEN RAISE EXCEPTION 'receipt CAS at mutation boundary'; END IF;
 IF lease_expires_at<=clock_timestamp() THEN RAISE EXCEPTION 'lease expired at mutation boundary'; END IF;
 critical_at:=clock_timestamp();
 FOR item IN SELECT value FROM jsonb_array_elements(l->'consumer_replacements') ORDER BY value->>'signature' LOOP
  SELECT jsonb_build_object('signature',item->>'signature','definition_md5',md5(pg_get_functiondef(p.oid)),
 'prosrc_sha256',encode(sha256(convert_to(p.prosrc,'UTF8')),'hex'),'owner',pg_get_userbyid(p.proowner),
 'acl',p.proacl::text[],'config',p.proconfig,'language',la.lanname,'volatility',p.provolatile,
 'security_definer',p.prosecdef,'result',pg_get_function_result(p.oid)) INTO actual FROM pg_proc p JOIN pg_language la ON la.oid=p.prolang WHERE p.oid=to_regprocedure(item->>'signature');
  IF actual IS DISTINCT FROM item->'before_contract' THEN RAISE EXCEPTION 'last-moment consumer CAS drift'; END IF;
  EXECUTE item->>'definition';
  SELECT jsonb_build_object('signature',item->>'signature','definition_md5',md5(pg_get_functiondef(p.oid)),
 'prosrc_sha256',encode(sha256(convert_to(p.prosrc,'UTF8')),'hex'),'owner',pg_get_userbyid(p.proowner),
 'acl',p.proacl::text[],'config',p.proconfig,'language',la.lanname,'volatility',p.provolatile,
 'security_definer',p.prosecdef,'result',pg_get_function_result(p.oid)) INTO actual FROM pg_proc p JOIN pg_language la ON la.oid=p.prolang WHERE p.oid=to_regprocedure(item->>'signature');
  IF actual IS DISTINCT FROM item->'after_contract' THEN RAISE EXCEPTION 'replacement readback differs'; END IF;
 END LOOP;
 INSERT INTO public.lts_reconciliation_evidence SELECT * FROM jsonb_populate_record(NULL::public.lts_reconciliation_evidence,l->'evidence_insert') RETURNING to_jsonb(lts_reconciliation_evidence.*) INTO evidence_after;
 GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'evidence insert count'; END IF;
 INSERT INTO public.lts_v178_review_decision SELECT * FROM jsonb_populate_record(NULL::public.lts_v178_review_decision,l->'representative_decision_insert') RETURNING to_jsonb(lts_v178_review_decision.*) INTO decision_after;
 GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'decision insert count'; END IF;
 SELECT epoch INTO epoch_after FROM public.lts_read_cache_epoch_v242 WHERE singleton;
 IF epoch_after<>epoch_before+2 THEN RAISE EXCEPTION 'expected exactly two existing invalidations'; END IF;
 IF EXISTS(SELECT 1 FROM public.lts_v229_read_cache WHERE user_id IS NOT NULL) THEN RAISE EXCEPTION 'existing global invalidation incomplete'; END IF;
 IF (SELECT jsonb_agg(to_jsonb(s) ORDER BY s.id) FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id IN(rep,prior,inv)) IS DISTINCT FROM sources THEN RAISE EXCEPTION 'sources changed'; END IF;
 IF (SELECT to_jsonb(d) FROM public.lts_v178_review_decision d WHERE d.user_id=u AND d.source_table='lts_open_finance_staging' AND d.source_ref=prior::text) IS DISTINCT FROM prior_decision THEN RAISE EXCEPTION 'prior decision changed'; END IF;
 INSERT INTO public.lts_access_audit(user_id,action,meta) VALUES(u,'option_a_nominal_apply_v1',jsonb_build_object(
  'version',1,'operation_id',op,'evidence_id',op,'status','pending_postcheck','immutable_fingerprint',actual_pin,
  'function_before_md5',(SELECT jsonb_object_agg(v->>'signature',v#>>'{before_contract,definition_md5}') FROM jsonb_array_elements(l->'consumer_replacements')v),
  'function_after_md5',(SELECT jsonb_object_agg(v->>'signature',v#>>'{after_contract,definition_md5}') FROM jsonb_array_elements(l->'consumer_replacements')v),
  'evidence_row_sha256',encode(sha256(convert_to(evidence_after::text,'UTF8')),'hex'),
  'representative_decision_sha256',encode(sha256(convert_to(decision_after::text,'UTF8')),'hex'),
  'epoch_before',epoch_before,'epoch_after',epoch_after)) RETURNING id INTO audit_id;
 IF (SELECT count(*) FROM public.lts_access_audit a WHERE a.user_id=u AND a.action='option_a_nominal_apply_v1' AND a.meta->>'operation_id'=op::text)<>1 THEN RAISE EXCEPTION 'receipt multiplicity'; END IF;
 IF clock_timestamp()-critical_at>interval '2 seconds' OR clock_timestamp()-evidence_locked_at>interval '2 seconds' THEN RAISE EXCEPTION 'posthoc critical duration exceeded; atomic abort'; END IF;
END $option_a_apply$;
