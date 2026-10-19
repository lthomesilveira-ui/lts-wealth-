-- LOCAL PRIVATE CANDIDATE. ready=false. Not applied. No banking/payment action.
BEGIN ISOLATION LEVEL READ COMMITTED;
SET LOCAL statement_timeout='15s';
SET LOCAL lock_timeout='2s';
SET LOCAL idle_in_transaction_session_timeout='20s';
SET LOCAL TIME ZONE 'UTC';
SET LOCAL search_path=pg_catalog,public;
DO $apply$
DECLARE
 c constant jsonb := $contract$__CONTRACT__$contract$::jsonb;
 v_event jsonb; v_source jsonb; v_account jsonb; v_decision jsonb; v_link jsonb;
 v_receipt jsonb; v_inverse jsonb; v_catalog jsonb; v_now jsonb; v_expected jsonb;
 v_sources_before jsonb := '{}'::jsonb; v_marker jsonb; v_meta jsonb; j jsonb; v_epoch bigint; n bigint; v_stamp timestamptz;
BEGIN
__RELEASE_GUARD__
__COMMON__
IF v_inverse IS NOT NULL THEN RAISE EXCEPTION 'operation was reversed; no automatic reapplication'; END IF;
IF v_receipt IS NOT NULL OR v_link IS NOT NULL OR v_decision IS NOT NULL OR v_event IS DISTINCT FROM c->'original_event' THEN
 __VALIDATE_POSTIMAGE__
 -- Exact retry: no INSERT/UPDATE/DELETE, timestamp change, audit append, epoch or nextval.
 PERFORM set_config('wealth.iptu_outcome','already_applied_exact',true);
 RETURN;
END IF;
-- First application is full-row strict; safe polling-only drift is admitted only on exact retries/inverses.
FOR j IN SELECT value FROM jsonb_array_elements(c->'protected_sources') LOOP
 IF md5((v_sources_before->(j->>'id'))::text) IS DISTINCT FROM j->>'row_md5'
 THEN RAISE EXCEPTION 'first apply full source lease expired'; END IF;
END LOOP;
IF md5(v_account::text) IS DISTINCT FROM c#>>'{account,row_md5}' THEN RAISE EXCEPTION 'first apply full account lease expired'; END IF;
IF md5(v_event::text) IS DISTINCT FROM c->>'original_event_md5'
 OR v_event->>'id' IS DISTINCT FROM c->>'target_id'
 OR v_event->>'event_date' IS DISTINCT FROM c->>'forecast_date'
 OR (v_event->>'amount')::numeric IS DISTINCT FROM (c->>'amount')::numeric
 OR v_event->>'source' IS DISTINCT FROM 'itau_scheduled'
 OR v_event->>'status' IS DISTINCT FROM 'scheduled'
 OR v_event->'is_projection' IS DISTINCT FROM 'true'::jsonb
 OR v_event->'is_suppressed' IS DISTINCT FROM 'false'::jsonb
 OR v_event->>'category' IS DISTINCT FROM c->>'category'
 OR v_event#>>'{metadata,payment_type}' IS DISTINCT FROM 'IPTU'
 OR v_event#>>'{metadata,property}' IS DISTINCT FROM c->>'property_label'
 OR jsonb_typeof(v_event->'metadata') IS DISTINCT FROM 'object'
 OR (v_event->'metadata') ? (c->>'marker')
THEN RAISE EXCEPTION 'original forecast changed'; END IF;
v_stamp:=transaction_timestamp();
INSERT INTO public.lts_v178_review_decision(user_id,source_table,source_ref,category_label,property_code,beneficiary,decision_basis,decided_at)
VALUES((c->>'owner_id')::uuid,'lts_open_finance_staging',c->>'source_id',c->>'category',c->>'property_code',NULL,c->>'decision_basis',v_stamp)
RETURNING to_jsonb(lts_v178_review_decision) INTO STRICT v_decision;
GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'expected one decision insert'; END IF;
INSERT INTO public.lts_reconciliation_link(user_id,target_event_id,candidate_source_table,candidate_source_ref,candidate_event_date,candidate_amount,note,confirmed_at)
VALUES((c->>'owner_id')::uuid,(c->>'target_id')::uuid,'lts_open_finance_staging',c->>'source_id',(c->>'posted_date')::date,(c->>'amount')::numeric,c->>'note',v_stamp)
RETURNING to_jsonb(lts_reconciliation_link) INTO STRICT v_link;
GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'expected one link insert'; END IF;
v_marker:=jsonb_build_object(
 'operation_id',c->>'operation_id','user_message_id',c->>'user_message_id',
 'source_table','lts_open_finance_staging','source_ref',c->>'source_id','source_owner',c->>'owner_id',
 'source_lease',c->'source_lease','original_event',c->'original_event','original_event_md5',c->>'original_event_md5',
 'original_amount',(c->>'amount')::numeric,'original_date',c->>'forecast_date',
 'posted_amount',(c->>'amount')::numeric,'posted_date',c->>'posted_date','amount_difference',0,
 'date_difference_days',(c->>'posted_date')::date-(c->>'forecast_date')::date,
 'residual_created',false,'official_provider_link',false,'applied_at',to_jsonb(v_stamp),
 'link_snapshot',v_link,'decision_snapshot',v_decision,'learning',c->'learning');
v_expected:=v_event||jsonb_build_object('is_suppressed',true,'suppression_reason',c->>'reason',
 'metadata',(v_event->'metadata')||jsonb_build_object(c->>'marker',v_marker));
UPDATE public.financial_events e
 SET is_suppressed=true,suppression_reason=c->>'reason',metadata=v_expected->'metadata'
 WHERE e.id=(c->>'target_id')::uuid AND e.user_id=(c->>'owner_id')::uuid AND to_jsonb(e)=c->'original_event';
GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'expected one forecast update'; END IF;
SELECT to_jsonb(e) INTO STRICT v_event FROM public.financial_events e WHERE e.id=(c->>'target_id')::uuid;
IF v_event IS DISTINCT FROM v_expected THEN RAISE EXCEPTION 'unexpected event mutation'; END IF;
v_meta:=jsonb_build_object('operation_id',c->>'operation_id','contract',c-ARRAY['ready','gates','rollback'],
 'original_event',c->'original_event','original_event_md5',c->>'original_event_md5',
 'before_decision',NULL,'before_link',NULL,'after_event',v_event,'after_link',v_link,'after_decision',v_decision,
 'event_after_md5',md5(v_event::text),'link_after_md5',md5(v_link::text),'decision_after_md5',md5(v_decision::text),
 'source_row_md5_at_apply',md5(v_source::text),'learning',c->'learning','applied_at',to_jsonb(v_stamp),
 'epoch_before',v_epoch,'epoch_after',v_epoch+(c->>'expected_epoch_delta')::bigint);
INSERT INTO public.lts_access_audit(user_id,email,action,meta,created_at)
VALUES((c->>'owner_id')::uuid,NULL,c->>'audit_action',v_meta,v_stamp)
RETURNING to_jsonb(lts_access_audit) INTO STRICT v_receipt;
GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'expected one durable audit append'; END IF;
__POST_GUARDS__
__VALIDATE_POSTIMAGE__
PERFORM set_config('wealth.iptu_outcome','applied_in_transaction',true);
END $apply$;
__RECEIPT_READBACK__
COMMIT;
