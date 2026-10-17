-- LOCAL HELD CONTROL, NOT A MIGRATION OR RELEASE. No execution authorized by this file.
-- No new persistent object, grant, policy, index or helper is permitted.
-- All financial reads/consumer comparisons occur outside the short atomic section.
-- Runtime pin and exact replacement DDL remain unbound pending PG/review/fresh lease.
DO $option_a_rollback$
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

 IF l->>'apply_operation_id' IS DISTINCT FROM op::text OR jsonb_typeof(l->'rollback_operation_id') IS DISTINCT FROM 'string'
 OR l->>'rollback_operation_id' !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 OR l->>'rollback_operation_id'=op::text THEN RAISE EXCEPTION 'separate compensation identity required'; END IF;
 IF jsonb_typeof(l->'required_gates') IS DISTINCT FROM 'object'
 OR (SELECT jsonb_agg(k ORDER BY k) FROM jsonb_object_keys(l->'required_gates')k)
 IS DISTINCT FROM '["coordinator_compensation_decision","fresh_rollback_leases","independent_policy_review","transactional_pg_passed"]'::jsonb
 OR EXISTS(SELECT 1 FROM jsonb_each(l->'required_gates')x WHERE x.value IS DISTINCT FROM 'true'::jsonb) THEN RAISE EXCEPTION 'rollback gates not complete'; END IF;
 IF jsonb_typeof(l->'expected_compensated_state')='object'
 AND evidence_rows IS NOT DISTINCT FROM l#>'{expected_compensated_state,evidence_rows}'
 AND decision IS NULL AND receipts IS NOT DISTINCT FROM l#>'{expected_compensated_state,receipts}'
 AND jsonb_array_length(evidence_rows)=1 AND jsonb_array_length(receipts)=2
 AND evidence_rows#>'{0,metadata,state,active}'='false'::jsonb THEN
  SELECT v INTO apply_receipt FROM jsonb_array_elements(receipts)v WHERE v->>'action'='option_a_nominal_apply_v1';
  SELECT v INTO compensation_receipt FROM jsonb_array_elements(receipts)v WHERE v->>'action'='option_a_nominal_rollback_v1';
  IF (SELECT count(*) FROM jsonb_array_elements(receipts)v WHERE v->>'action'='option_a_nominal_apply_v1')<>1
  OR (SELECT count(*) FROM jsonb_array_elements(receipts)v WHERE v->>'action'='option_a_nominal_rollback_v1')<>1
  OR apply_receipt IS NULL OR compensation_receipt IS NULL
  OR encode(sha256(convert_to(apply_receipt::text,'UTF8')),'hex') IS DISTINCT FROM l#>>'{expected_compensated_state,apply_receipt_sha256}'
  OR encode(sha256(convert_to(compensation_receipt::text,'UTF8')),'hex') IS DISTINCT FROM l#>>'{expected_compensated_state,compensation_receipt_sha256}'
  OR compensation_receipt#>>'{meta,apply_receipt_sha256}' IS DISTINCT FROM l#>>'{expected_compensated_state,apply_receipt_sha256}'
  OR compensation_receipt#>'{meta,compensates_audit_id}' IS DISTINCT FROM apply_receipt->'id'
  OR compensation_receipt#>>'{meta,rollback_operation_id}' IS DISTINCT FROM l->>'rollback_operation_id'
  OR compensation_receipt#>>'{meta,status}' IS DISTINCT FROM 'pending_postcheck'
  OR encode(sha256(convert_to((evidence_rows->0)::text,'UTF8')),'hex') IS DISTINCT FROM compensation_receipt#>>'{meta,revoked_evidence_sha256}'
  OR evidence_rows#>>'{0,metadata,state,revocation_operation_id}' IS DISTINCT FROM l->>'rollback_operation_id'
  THEN RAISE EXCEPTION 'idempotent compensation anchors differ'; END IF;
  IF l#>'{expected_compensated_state,function_contracts}' IS DISTINCT FROM
   (SELECT jsonb_agg(v ORDER BY v->>'signature') FROM jsonb_array_elements(l#>'{catalog_contracts,functions}')v WHERE v->>'signature' IN('public.lts_v229_expense_rows(uuid,date,date)','public.lts_browser_card_detail_v226(text,date)')) THEN RAISE EXCEPTION 'compensated consumer state mismatch'; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(l#>'{expected_compensated_state,function_contracts}') v WHERE v->>'definition_md5' IS DISTINCT FROM (apply_receipt#>'{meta,function_before_md5}')->>(v->>'signature')) THEN RAISE EXCEPTION 'idempotent restored hashes differ'; END IF;
  SELECT epoch INTO epoch_before FROM public.lts_read_cache_epoch_v242 WHERE singleton;
  IF epoch_before IS DISTINCT FROM (l->>'current_epoch')::bigint THEN RAISE EXCEPTION 'idempotent epoch drift'; END IF;
  IF lease_expires_at<=clock_timestamp() THEN RAISE EXCEPTION 'lease expired at idempotent boundary'; END IF;
  IF clock_timestamp()-evidence_locked_at>interval '2 seconds' THEN RAISE EXCEPTION 'idempotent check exceeded evidence-lock budget'; END IF;
  RETURN;
 END IF;
 IF jsonb_array_length(evidence_rows)<>1 OR evidence_rows->0 IS DISTINCT FROM l->'current_evidence_image'
 OR decision IS NULL OR decision IS DISTINCT FROM l->'current_representative_decision'
 OR jsonb_array_length(receipts)<>1 OR receipts#>>'{0,action}'<>'option_a_nominal_apply_v1'
 OR (receipts#>>'{0,id}')::bigint IS DISTINCT FROM (l->>'apply_audit_id')::bigint
 OR encode(sha256(convert_to((receipts->0)::text,'UTF8')),'hex') IS DISTINCT FROM l->>'apply_receipt_current_sha256'
 THEN RAISE EXCEPTION 'rollback CAS partial, missing, conflicting or edited state'; END IF;
 IF encode(sha256(convert_to((evidence_rows->0)::text,'UTF8')),'hex') IS DISTINCT FROM receipts#>>'{0,meta,evidence_row_sha256}'
 OR encode(sha256(convert_to(decision::text,'UTF8')),'hex') IS DISTINCT FROM receipts#>>'{0,meta,representative_decision_sha256}'
 OR evidence_rows#>'{0,metadata,state,active}' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'applied rows no longer exact'; END IF;
 IF jsonb_typeof(l->'expected_revoked_evidence') IS DISTINCT FROM 'object'
 OR (l->'expected_revoked_evidence'-'metadata') IS DISTINCT FROM ((evidence_rows->0)-'metadata')
 OR (l#>'{expected_revoked_evidence,metadata}'-'state') IS DISTINCT FROM (evidence_rows#>'{0,metadata}'-'state')
 OR jsonb_typeof(l#>'{expected_revoked_evidence,metadata,state}') IS DISTINCT FROM 'object'
 OR (SELECT jsonb_agg(k ORDER BY k) FROM jsonb_object_keys(l#>'{expected_revoked_evidence,metadata,state}')k) IS DISTINCT FROM '["active","revocation_operation_id","revoked_at"]'::jsonb
 OR l#>'{expected_revoked_evidence,metadata,state,active}' IS DISTINCT FROM 'false'::jsonb
 OR jsonb_typeof(l#>'{expected_revoked_evidence,metadata,state,revoked_at}') IS DISTINCT FROM 'string'
 OR length(l#>>'{expected_revoked_evidence,metadata,state,revoked_at}')=0
 OR l#>>'{expected_revoked_evidence,metadata,state,revocation_operation_id}' IS DISTINCT FROM l->>'rollback_operation_id'
 THEN RAISE EXCEPTION 'revocation changes more than permitted state'; END IF;
 BEGIN
  revoked_at:=(l#>>'{expected_revoked_evidence,metadata,state,revoked_at}')::timestamptz;
 EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN RAISE EXCEPTION 'revocation timestamp parse rejected'; END;
 IF revoked_at IS NULL OR NOT isfinite(revoked_at) THEN RAISE EXCEPTION 'revocation timestamp nonfinite'; END IF;
 IF jsonb_typeof(l->'restore_original_definitions') IS DISTINCT FROM 'array' OR jsonb_array_length(l->'restore_original_definitions')<>2
 OR (SELECT jsonb_agg(v->>'signature' ORDER BY v->>'signature') FROM jsonb_array_elements(l->'restore_original_definitions')v)
 IS DISTINCT FROM '["public.lts_browser_card_detail_v226(text,date)","public.lts_v229_expense_rows(uuid,date,date)"]'::jsonb THEN RAISE EXCEPTION 'two exact restore payloads required'; END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(l->'restore_original_definitions') ORDER BY value->>'signature' LOOP
  IF jsonb_typeof(item->'definition') IS DISTINCT FROM 'string'
   OR encode(sha256(convert_to(item->>'definition','UTF8')),'hex') IS DISTINCT FROM item->>'reviewed_definition_sha256'
   OR item->'before_contract' IS DISTINCT FROM (SELECT v FROM jsonb_array_elements(l#>'{catalog_contracts,functions}')v WHERE v->>'signature'=item->>'signature')
   OR jsonb_typeof(item->'after_contract') IS DISTINCT FROM 'object'
   OR item#>>'{before_contract,definition_md5}' IS DISTINCT FROM (receipts#>'{0,meta,function_after_md5}')->> (item->>'signature')
   OR item#>>'{after_contract,definition_md5}' IS DISTINCT FROM (receipts#>'{0,meta,function_before_md5}')->> (item->>'signature')
   OR (item->'before_contract'-ARRAY['definition_md5','prosrc_sha256']) IS DISTINCT FROM (item->'after_contract'-ARRAY['definition_md5','prosrc_sha256'])
   THEN RAISE EXCEPTION 'restore definition or public contract drift'; END IF;
 END LOOP;
 PERFORM 1 FROM public.lts_read_cache_epoch_v242 WHERE singleton FOR UPDATE;
 SELECT epoch INTO epoch_before FROM public.lts_read_cache_epoch_v242 WHERE singleton;
 IF epoch_before IS DISTINCT FROM (l->>'current_epoch')::bigint THEN RAISE EXCEPTION 'rollback epoch drift'; END IF;
 IF (SELECT coalesce(jsonb_agg(to_jsonb(a) ORDER BY a.id),'[]') FROM public.lts_access_audit a WHERE a.user_id=u
  AND a.action IN('option_a_nominal_apply_v1','option_a_nominal_rollback_v1') AND a.meta->>'operation_id'=op::text) IS DISTINCT FROM receipts
 THEN RAISE EXCEPTION 'receipt CAS at mutation boundary'; END IF;
 IF lease_expires_at<=clock_timestamp() THEN RAISE EXCEPTION 'lease expired at mutation boundary'; END IF;
 critical_at:=clock_timestamp();
 FOR item IN SELECT value FROM jsonb_array_elements(l->'restore_original_definitions') ORDER BY value->>'signature' LOOP
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
  IF actual IS DISTINCT FROM item->'after_contract' THEN RAISE EXCEPTION 'restored function mismatch'; END IF;
 END LOOP;
 UPDATE public.lts_reconciliation_evidence e SET metadata=l#>'{expected_revoked_evidence,metadata}' WHERE e.user_id=u AND e.id=op
 AND to_jsonb(e)=l->'current_evidence_image' RETURNING to_jsonb(e.*) INTO evidence_after;
 GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 OR evidence_after IS DISTINCT FROM l->'expected_revoked_evidence' THEN RAISE EXCEPTION 'revocation count or image'; END IF;
 DELETE FROM public.lts_v178_review_decision d WHERE d.user_id=u AND d.source_table='lts_open_finance_staging' AND d.source_ref=rep::text
 AND to_jsonb(d)=l->'current_representative_decision';
 GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'compensation decision CAS count'; END IF;
 SELECT epoch INTO epoch_after FROM public.lts_read_cache_epoch_v242 WHERE singleton;
 IF epoch_after<>epoch_before+2 THEN RAISE EXCEPTION 'compensation expected two existing invalidations'; END IF;
 IF EXISTS(SELECT 1 FROM public.lts_v229_read_cache WHERE user_id IS NOT NULL) THEN RAISE EXCEPTION 'compensation invalidation incomplete'; END IF;
 IF (SELECT jsonb_agg(to_jsonb(s) ORDER BY s.id) FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id IN(rep,prior,inv)) IS DISTINCT FROM sources THEN RAISE EXCEPTION 'source changed during compensation'; END IF;
 IF (SELECT to_jsonb(d) FROM public.lts_v178_review_decision d WHERE d.user_id=u AND d.source_table='lts_open_finance_staging' AND d.source_ref=prior::text) IS DISTINCT FROM prior_decision THEN RAISE EXCEPTION 'prior changed during compensation'; END IF;
 INSERT INTO public.lts_access_audit(user_id,action,meta) VALUES(u,'option_a_nominal_rollback_v1',jsonb_build_object('version',1,
  'operation_id',op,'rollback_operation_id',l->>'rollback_operation_id','evidence_id',op,'status','pending_postcheck',
  'compensates_audit_id',(l->>'apply_audit_id')::bigint,'apply_receipt_sha256',l->>'apply_receipt_current_sha256',
  'revoked_evidence_sha256',encode(sha256(convert_to(evidence_after::text,'UTF8')),'hex'),
  'epoch_before',epoch_before,'epoch_after',epoch_after)) RETURNING id INTO audit_id;
 IF (SELECT count(*) FROM public.lts_access_audit a WHERE a.user_id=u AND a.action='option_a_nominal_rollback_v1'
  AND a.meta->>'operation_id'=op::text)<>1 THEN RAISE EXCEPTION 'compensation receipt multiplicity'; END IF;
 IF (SELECT count(*) FROM public.lts_access_audit a WHERE a.user_id=u AND a.action IN('option_a_nominal_apply_v1','option_a_nominal_rollback_v1') AND a.meta->>'operation_id'=op::text)<>2
 OR (SELECT encode(sha256(convert_to(to_jsonb(a)::text,'UTF8')),'hex') FROM public.lts_access_audit a WHERE a.user_id=u AND a.id=(l->>'apply_audit_id')::bigint) IS DISTINCT FROM l->>'apply_receipt_current_sha256'
 THEN RAISE EXCEPTION 'compensation receipt linkage changed'; END IF;
 IF clock_timestamp()-critical_at>interval '2 seconds' OR clock_timestamp()-evidence_locked_at>interval '2 seconds' THEN RAISE EXCEPTION 'compensation posthoc duration exceeded; atomic abort'; END IF;
END $option_a_rollback$;
