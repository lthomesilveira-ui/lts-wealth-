-- Same ordering for apply and inverse. The coordinator serializes this maintenance window.
-- Locks may briefly block other owners. Only the named business rows may be changed.
LOCK TABLE public.lts_access_audit IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.lts_v178_review_decision IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.lts_reconciliation_link IN SHARE ROW EXCLUSIVE MODE;
-- Target first, then protected forecasts in UUID order. Both writers use this exact order.
SELECT to_jsonb(e) INTO STRICT v_event FROM public.financial_events e WHERE e.id=(c->>'target_id')::uuid FOR UPDATE;
FOR j IN SELECT value FROM jsonb_array_elements(c->'protected_events') ORDER BY value->>'id' LOOP
 SELECT jsonb_build_object('id',e.id,'row_md5',md5(to_jsonb(e)::text)) INTO STRICT v_now
 FROM public.financial_events e WHERE e.id=(j->>'id')::uuid FOR SHARE;
 IF v_now IS DISTINCT FROM j THEN RAISE EXCEPTION 'protected forecast changed'; END IF;
END LOOP;
-- The source and both PENDING witnesses are share-locked in one global UUID order.
FOR j IN SELECT value FROM jsonb_array_elements(c->'protected_sources') ORDER BY value->>'id' LOOP
 SELECT to_jsonb(s) INTO STRICT v_now FROM public.lts_open_finance_staging s WHERE s.id=(j->>'id')::uuid FOR SHARE;
 IF v_now->>'user_id' IS DISTINCT FROM c->>'owner_id'
 OR md5((v_now-ARRAY['sync_run_id','last_seen_at','updated_at'])::text) IS DISTINCT FROM j->>'stable_md5'
 THEN RAISE EXCEPTION 'protected bank source materially changed'; END IF;
 v_sources_before:=v_sources_before||jsonb_build_object(j->>'id',v_now);
 IF j->>'id'=c->>'source_id' THEN v_source:=v_now; END IF;
END LOOP;
IF v_source IS NULL THEN RAISE EXCEPTION 'source witness missing'; END IF;
SELECT to_jsonb(a) INTO STRICT v_account FROM public.accounts a WHERE a.id=(c#>>'{original_event,account_id}')::uuid FOR SHARE;
IF v_account->>'id' IS DISTINCT FROM c#>>'{account,id}'
 OR v_account->>'institution' IS DISTINCT FROM c#>>'{account,institution}'
 OR v_account->>'currency' IS DISTINCT FROM 'BRL'
 OR v_account->>'user_id' IS DISTINCT FROM c->>'owner_id' THEN RAISE EXCEPTION 'nominal account context changed'; END IF;
-- A validated, immediate, non-deferrable FK ensures inserts into operation wait on target FOR UPDATE.
IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_constraint
 WHERE conrelid='public.lts_flow_event_operation'::regclass AND contype='f'
 AND conname='lts_flow_event_operation_target_event_id_fkey' AND NOT condeferrable AND convalidated
 AND pg_get_constraintdef(oid)='FOREIGN KEY (target_event_id) REFERENCES financial_events(id)')
THEN RAISE EXCEPTION 'operation FK contract changed'; END IF;
IF EXISTS(SELECT 1 FROM public.lts_flow_event_operation WHERE target_event_id=(c->>'target_id')::uuid)
THEN RAISE EXCEPTION 'unexpected event operation'; END IF;
IF v_event->>'user_id' IS DISTINCT FROM c->>'owner_id'
 OR v_source->>'user_id' IS DISTINCT FROM c->>'owner_id' THEN RAISE EXCEPTION 'owner mismatch'; END IF;
IF md5((v_source-ARRAY['sync_run_id','last_seen_at','updated_at'])::text) IS DISTINCT FROM c#>>'{source_lease,stable_md5}'

 OR v_source->>'raw_hash' IS DISTINCT FROM c#>>'{source_lease,raw_hash}'
 OR v_source->>'resource_type' IS DISTINCT FROM 'transaction'
 OR v_source->>'institution_code' IS DISTINCT FROM c#>>'{source_lease,institution_code}'
 OR v_source->>'provider_account_ref' IS DISTINCT FROM c#>>'{source_lease,provider_account_ref}'
 OR v_source->>'provider_record_id' IS DISTINCT FROM c#>>'{source_lease,provider_record_id}'
 OR v_source->>'connection_id' IS DISTINCT FROM c#>>'{source_lease,connection_id}'
 OR v_source->>'currency' IS DISTINCT FROM 'BRL'
 OR v_source#>>'{raw_payload,status}' IS DISTINCT FROM 'POSTED'
 OR v_source#>>'{normalized_payload,status}' IS DISTINCT FROM 'POSTED'
 OR v_source->>'provider_deleted_at' IS NOT NULL
 OR (v_source->>'signed_amount')::numeric IS DISTINCT FROM (c->>'amount')::numeric
 OR v_source->>'posting_date' IS DISTINCT FROM c->>'posted_date'
THEN RAISE EXCEPTION 'posted source lease changed'; END IF;
IF EXISTS(SELECT 1 FROM public.lts_reconciliation_link l
 WHERE (l.target_event_id=(c->>'target_id')::uuid
 OR (l.candidate_source_table='lts_open_finance_staging' AND l.candidate_source_ref=c->>'source_id'))
 AND (l.user_id IS DISTINCT FROM (c->>'owner_id')::uuid
 OR l.target_event_id IS DISTINCT FROM (c->>'target_id')::uuid
 OR l.candidate_source_table IS DISTINCT FROM 'lts_open_finance_staging'
 OR l.candidate_source_ref IS DISTINCT FROM c->>'source_id'))
THEN RAISE EXCEPTION 'endpoint reused or conflicting link across owners'; END IF;
SELECT to_jsonb(l) INTO v_link FROM public.lts_reconciliation_link l
 WHERE l.target_event_id=(c->>'target_id')::uuid FOR UPDATE;
SELECT to_jsonb(d) INTO v_decision FROM public.lts_v178_review_decision d
 WHERE d.user_id=(c->>'owner_id')::uuid AND d.source_table='lts_open_finance_staging' AND d.source_ref=c->>'source_id' FOR UPDATE;
SELECT epoch INTO STRICT v_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true FOR UPDATE;
__CATALOG_QUERY__ INTO v_catalog;
IF v_catalog IS DISTINCT FROM c->'catalog' THEN RAISE EXCEPTION 'catalog ACL RLS trigger function or sequence lease changed'; END IF;
IF (SELECT count(*) FROM public.lts_access_audit WHERE meta->>'operation_id'=c->>'operation_id')>1
THEN RAISE EXCEPTION 'duplicate durable application receipt'; END IF;
SELECT to_jsonb(a) INTO v_receipt FROM public.lts_access_audit a WHERE a.meta->>'operation_id'=c->>'operation_id';
IF (SELECT count(*) FROM public.lts_access_audit WHERE meta->>'rollback_of'=c->>'operation_id')>1
THEN RAISE EXCEPTION 'duplicate durable inverse receipt'; END IF;
SELECT to_jsonb(a) INTO v_inverse FROM public.lts_access_audit a WHERE a.meta->>'rollback_of'=c->>'operation_id';
