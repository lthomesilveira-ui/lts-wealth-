-- LOCAL PRIVATE INVERSE. ready=false. Requires separate authorization and pinned COMMITTED receipt.
BEGIN ISOLATION LEVEL READ COMMITTED;
SET LOCAL statement_timeout='15s';
SET LOCAL lock_timeout='2s';
SET LOCAL idle_in_transaction_session_timeout='20s';
SET LOCAL TIME ZONE 'UTC';
SET LOCAL search_path=pg_catalog,public;
DO $rollback$
DECLARE
 c constant jsonb := $contract$__CONTRACT__$contract$::jsonb;
 v_event jsonb; v_source jsonb; v_account jsonb; v_decision jsonb; v_link jsonb;
 v_receipt jsonb; v_inverse jsonb; v_catalog jsonb; v_now jsonb; v_expected jsonb;
 v_sources_before jsonb := '{}'::jsonb; v_marker jsonb; v_meta jsonb; j jsonb; v_epoch bigint; n bigint; v_stamp timestamptz;
BEGIN
__RELEASE_GUARD__
IF c#>'{rollback,authorized}' IS DISTINCT FROM 'true'::jsonb
 OR c#>'{rollback,committed_receipt_verified}' IS DISTINCT FROM 'true'::jsonb
 OR coalesce(c#>>'{rollback,receipt_md5}','') !~ '^[0-9a-f]{32}$'
THEN RAISE EXCEPTION 'inverse requires authorized committed receipt'; END IF;
__COMMON__
IF md5(v_receipt::text) IS DISTINCT FROM c#>>'{rollback,receipt_md5}' THEN RAISE EXCEPTION 'pinned committed receipt changed'; END IF;
IF v_inverse IS NOT NULL THEN
 IF v_event IS DISTINCT FROM c->'original_event' OR v_decision IS NOT NULL OR v_link IS NOT NULL
 OR v_inverse->>'user_id' IS DISTINCT FROM c->>'owner_id' OR v_inverse->>'action' IS DISTINCT FROM (c->>'audit_action')||'_rollback'
 OR v_inverse->'email' IS DISTINCT FROM 'null'::jsonb
 OR v_inverse->'meta' IS DISTINCT FROM jsonb_build_object('rollback_of',c->>'operation_id','application_receipt',v_receipt,
  'restored_event',c->'original_event','restored_decision',NULL,'restored_link',NULL,
  'restored_at',v_inverse->'created_at','epoch_before',v_inverse#>'{meta,epoch_before}',
  'epoch_after',(v_inverse#>>'{meta,epoch_before}')::bigint+(c->>'expected_epoch_delta')::bigint)
 OR v_inverse#>'{meta,epoch_before}' IS NULL
 THEN RAISE EXCEPTION 'inverse receipt or restored state changed'; END IF;
 PERFORM set_config('wealth.iptu_outcome','already_reversed_exact',true);
 RETURN;
END IF;
__VALIDATE_POSTIMAGE__
UPDATE public.financial_events e SET
 is_suppressed=(c#>>'{original_event,is_suppressed}')::boolean,
 suppression_reason=c#>>'{original_event,suppression_reason}',metadata=c#>'{original_event,metadata}'
 WHERE e.id=(c->>'target_id')::uuid AND e.user_id=(c->>'owner_id')::uuid AND to_jsonb(e)=v_event;
GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'expected one restored forecast'; END IF;
DELETE FROM public.lts_reconciliation_link l WHERE l.id=(v_link->>'id')::bigint
 AND l.user_id=(c->>'owner_id')::uuid AND l.target_event_id=(c->>'target_id')::uuid AND to_jsonb(l)=v_link;
GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'expected one removed link'; END IF;
DELETE FROM public.lts_v178_review_decision d WHERE d.user_id=(c->>'owner_id')::uuid
 AND d.source_table='lts_open_finance_staging' AND d.source_ref=c->>'source_id' AND to_jsonb(d)=v_decision;
GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'expected one removed exact decision'; END IF;
v_stamp:=transaction_timestamp();
INSERT INTO public.lts_access_audit(user_id,email,action,meta,created_at)
VALUES((c->>'owner_id')::uuid,NULL,(c->>'audit_action')||'_rollback',
 jsonb_build_object('rollback_of',c->>'operation_id','application_receipt',v_receipt,
 'restored_event',c->'original_event','restored_decision',NULL,'restored_link',NULL,
 'restored_at',to_jsonb(v_stamp),'epoch_before',v_epoch,'epoch_after',v_epoch+(c->>'expected_epoch_delta')::bigint),v_stamp)
RETURNING to_jsonb(lts_access_audit) INTO STRICT v_inverse;
GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'expected one inverse audit append'; END IF;
__POST_GUARDS__
IF v_event IS DISTINCT FROM c->'original_event' OR v_link IS NOT NULL OR v_decision IS NOT NULL
 OR md5(v_receipt::text) IS DISTINCT FROM c#>>'{rollback,receipt_md5}'
THEN RAISE EXCEPTION 'inverse restoration failed'; END IF;
IF (SELECT count(*) FROM public.lts_access_audit WHERE meta->>'rollback_of'=c->>'operation_id')<>1
 OR (SELECT to_jsonb(a) FROM public.lts_access_audit a WHERE a.meta->>'rollback_of'=c->>'operation_id') IS DISTINCT FROM v_inverse
THEN RAISE EXCEPTION 'inverse audit changed'; END IF;
PERFORM set_config('wealth.iptu_outcome','reversed_in_transaction',true);
END $rollback$;
__RECEIPT_READBACK__
COMMIT;
