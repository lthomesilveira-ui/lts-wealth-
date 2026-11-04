-- Full-row checks after all DML, including audit side effects.
FOR j IN SELECT value FROM jsonb_array_elements(c->'protected_events') LOOP
 SELECT jsonb_build_object('id',e.id,'row_md5',md5(to_jsonb(e)::text)) INTO STRICT v_now FROM public.financial_events e WHERE e.id=(j->>'id')::uuid;
 IF v_now IS DISTINCT FROM j THEN RAISE EXCEPTION 'protected forecast mutated'; END IF;
END LOOP;
FOR j IN SELECT value FROM jsonb_array_elements(c->'protected_sources') LOOP
 SELECT to_jsonb(s) INTO STRICT v_now FROM public.lts_open_finance_staging s WHERE s.id=(j->>'id')::uuid;
 IF v_now IS DISTINCT FROM v_sources_before->(j->>'id') THEN RAISE EXCEPTION 'protected bank source mutated'; END IF;
END LOOP;
IF (SELECT to_jsonb(a) FROM public.accounts a WHERE a.id=(c#>>'{original_event,account_id}')::uuid) IS DISTINCT FROM v_account THEN RAISE EXCEPTION 'bank account mutated'; END IF;
IF EXISTS(SELECT 1 FROM public.lts_flow_event_operation WHERE target_event_id=(c->>'target_id')::uuid) THEN RAISE EXCEPTION 'operation appeared'; END IF;
IF (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) IS DISTINCT FROM v_epoch+(c->>'expected_epoch_delta')::bigint THEN RAISE EXCEPTION 'unexpected cache epoch delta'; END IF;
__CATALOG_QUERY__ INTO v_catalog;
IF v_catalog IS DISTINCT FROM c->'catalog' THEN RAISE EXCEPTION 'catalog changed during mutation'; END IF;
SELECT to_jsonb(e) INTO STRICT v_event FROM public.financial_events e WHERE e.id=(c->>'target_id')::uuid;
SELECT to_jsonb(l) INTO v_link FROM public.lts_reconciliation_link l WHERE l.target_event_id=(c->>'target_id')::uuid;
SELECT to_jsonb(d) INTO v_decision FROM public.lts_v178_review_decision d WHERE d.user_id=(c->>'owner_id')::uuid AND d.source_table='lts_open_finance_staging' AND d.source_ref=c->>'source_id';
IF EXISTS(SELECT 1 FROM public.lts_reconciliation_link l
 WHERE (l.target_event_id=(c->>'target_id')::uuid OR (l.candidate_source_table='lts_open_finance_staging' AND l.candidate_source_ref=c->>'source_id'))
 AND (l.user_id IS DISTINCT FROM (c->>'owner_id')::uuid OR l.target_event_id IS DISTINCT FROM (c->>'target_id')::uuid
 OR l.candidate_source_table IS DISTINCT FROM 'lts_open_finance_staging' OR l.candidate_source_ref IS DISTINCT FROM c->>'source_id')) THEN RAISE EXCEPTION 'endpoint reuse appeared'; END IF;
IF (SELECT count(*) FROM public.lts_access_audit WHERE meta->>'operation_id'=c->>'operation_id')<>1 THEN RAISE EXCEPTION 'application receipt cardinality changed'; END IF;
SELECT to_jsonb(a) INTO STRICT v_receipt FROM public.lts_access_audit a WHERE a.meta->>'operation_id'=c->>'operation_id';
