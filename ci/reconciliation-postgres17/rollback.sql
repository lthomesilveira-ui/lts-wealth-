-- Synthetic-fixture transaction only. Default ending remains ROLLBACK.
BEGIN ISOLATION LEVEL READ COMMITTED;
SET LOCAL statement_timeout='15s';
SET LOCAL lock_timeout='2s';
SET LOCAL TIME ZONE 'UTC';
-- Prevent concurrent links from reusing this source while the exact-target check runs.
-- Brief lock across fixture links; business rows outside the target stay unchanged.
LOCK TABLE reconciliation_fixture.links IN SHARE ROW EXCLUSIVE MODE;
DO $undo$
DECLARE
 v_contract constant jsonb := current_setting('reconciliation_test.contract')::jsonb;
 v_post_event_md5 constant text := coalesce(v_contract->>'post_event_md5','');
 v_post_link_md5 constant text := coalesce(v_contract->>'post_link_md5','');
 v_original constant jsonb := v_contract->'original_event';
 v_uid constant uuid := (v_original->>'user_id')::uuid;
 v_target constant uuid := (v_original->>'id')::uuid;
 v_source constant uuid := (v_contract#>>'{credit,id}')::uuid;
 v_marker constant text := v_contract->>'marker';
 v_reason constant text := 'reconciled_to_posted:'||v_source::text;
 v_note constant text := v_contract->>'note';
 v_event jsonb; v_credit jsonb; v_link jsonb; v_audit jsonb; v_after jsonb; v_triggers jsonb;
 v_epoch bigint; v_n bigint; v_constraints jsonb;
BEGIN
 IF current_database() IS DISTINCT FROM 'reconciliation_ci' OR current_setting('server_version_num')::integer/10000<>17 OR v_contract->>'fixture_contract' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Synthetic PostgreSQL 17 fixture contract required'; END IF;
 IF md5(pg_get_functiondef('reconciliation_fixture.cashflow_rows(uuid,date,date)'::regprocedure)) IS DISTINCT FROM (SELECT d->>'md5' FROM jsonb_array_elements(v_contract->'definitions') d WHERE d->>'signature'='reconciliation_fixture.cashflow_rows(uuid,date,date)') THEN RAISE EXCEPTION 'Reader/trigger definition lease changed: cashflow_rows(uuid,date,date)'; END IF;
 IF md5(pg_get_functiondef('reconciliation_fixture.current_rows(uuid,date,date)'::regprocedure)) IS DISTINCT FROM (SELECT d->>'md5' FROM jsonb_array_elements(v_contract->'definitions') d WHERE d->>'signature'='reconciliation_fixture.current_rows(uuid,date,date)') THEN RAISE EXCEPTION 'Reader/trigger definition lease changed: current_rows(uuid,date,date)'; END IF;
 IF md5(pg_get_functiondef('reconciliation_fixture.invalidate_cache()'::regprocedure)) IS DISTINCT FROM (SELECT d->>'md5' FROM jsonb_array_elements(v_contract->'definitions') d WHERE d->>'signature'='reconciliation_fixture.invalidate_cache()') THEN RAISE EXCEPTION 'Reader/trigger definition lease changed: invalidate_cache()'; END IF;
 IF md5(pg_get_functiondef('reconciliation_fixture.cashflow_engine(uuid,date,date)'::regprocedure)) IS DISTINCT FROM (SELECT d->>'md5' FROM jsonb_array_elements(v_contract->'definitions') d WHERE d->>'signature'='reconciliation_fixture.cashflow_engine(uuid,date,date)') THEN RAISE EXCEPTION 'Reader/trigger definition lease changed: cashflow_engine(uuid,date,date)'; END IF;
 SELECT jsonb_agg(jsonb_build_object('table',c.relname,'name',t.tgname,'enabled',t.tgenabled,'definition',pg_get_triggerdef(t.oid)) ORDER BY c.relname,t.tgname)
 INTO v_triggers FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
 WHERE t.tgrelid IN ('reconciliation_fixture.events'::regclass,'reconciliation_fixture.links'::regclass) AND NOT t.tgisinternal;
 IF v_triggers IS DISTINCT FROM (v_contract->'triggers') THEN RAISE EXCEPTION 'Trigger set changed'; END IF;
 SELECT jsonb_agg(to_jsonb(q) ORDER BY q.table_name,q.conname) INTO v_constraints FROM (SELECT c.relname AS table_name,con.conname,pg_get_constraintdef(con.oid) AS definition FROM pg_constraint con JOIN pg_class c ON c.oid=con.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='reconciliation_fixture' AND c.relname IN ('events','links')) q;
 IF v_constraints IS DISTINCT FROM (v_contract->'constraints') THEN RAISE EXCEPTION 'Constraint lease changed'; END IF;
 -- HARNESS_BARRIER_BEFORE_EVENT_LOCK
 SELECT to_jsonb(e) INTO STRICT v_event FROM reconciliation_fixture.events e WHERE e.id=v_target FOR UPDATE;
 -- HARNESS_BARRIER_AFTER_EVENT_LOCK
 SELECT to_jsonb(s) INTO STRICT v_credit FROM reconciliation_fixture.credits s WHERE s.id=v_source FOR SHARE;
 -- HARNESS_BARRIER_AFTER_CREDIT_LOCK
 IF v_event->>'user_id' IS DISTINCT FROM v_uid::text OR v_credit->>'user_id' IS DISTINCT FROM v_uid::text THEN RAISE EXCEPTION 'Owner mismatch'; END IF;
 IF md5((v_credit-ARRAY['sync_run_id','last_seen_at','updated_at'])::text) IS DISTINCT FROM (v_contract->>'credit_stable_md5')
 OR v_credit->>'raw_hash' IS DISTINCT FROM (v_contract->>'credit_raw_hash')
 OR v_credit->>'provider_account_ref' IS DISTINCT FROM (v_contract#>>'{credit,provider_account_ref}')
 OR v_credit->>'provider_record_id' IS DISTINCT FROM (v_contract#>>'{credit,provider_record_id}')
 OR v_credit->>'connection_id' IS DISTINCT FROM (v_contract#>>'{credit,connection_id}')
 OR v_credit->>'resource_type' IS DISTINCT FROM 'transaction'
 OR (v_credit->>'signed_amount')::numeric IS DISTINCT FROM (v_contract#>>'{credit,signed_amount}')::numeric
 OR v_credit->>'posting_date' IS DISTINCT FROM (v_contract#>>'{credit,posting_date}')
 OR v_credit->>'currency' IS DISTINCT FROM (v_contract#>>'{credit,currency}')
 OR v_credit#>>'{raw_payload,status}' IS DISTINCT FROM 'POSTED'
 OR v_credit#>>'{normalized_payload,status}' IS DISTINCT FROM 'POSTED'
 OR v_credit->>'provider_deleted_at' IS NOT NULL THEN RAISE EXCEPTION 'Posted credit lease changed'; END IF;
 -- READ COMMITTED observes operations committed while acquiring the event lock.
 -- The immediate validated FK blocks new target operations until this FOR UPDATE is released.
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='reconciliation_fixture.operations'::regclass AND conname='operations_target_event_id_fkey' AND contype='f' AND NOT condeferrable AND convalidated AND pg_get_constraintdef(oid)=(v_contract->>'operations_fk_definition')) THEN RAISE EXCEPTION 'Event-operation FK lease changed'; END IF;
 IF EXISTS(SELECT 1 FROM reconciliation_fixture.operations o WHERE o.target_event_id=v_target) THEN RAISE EXCEPTION 'Unexpected event operation'; END IF;
 IF EXISTS(SELECT 1 FROM reconciliation_fixture.links l
   WHERE l.candidate_source_table='credits' AND l.candidate_source_ref=v_source::text
   AND (l.user_id IS DISTINCT FROM v_uid OR l.target_event_id IS DISTINCT FROM v_target)) THEN RAISE EXCEPTION 'Credit already linked to a different target'; END IF;
 SELECT to_jsonb(l) INTO v_link FROM reconciliation_fixture.links l WHERE l.user_id=v_uid AND l.target_event_id=v_target FOR UPDATE;
 SELECT epoch INTO STRICT v_epoch FROM reconciliation_fixture.epoch WHERE singleton=true FOR UPDATE;
 IF EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='reconciliation_fixture.epoch'::regclass AND NOT tgisinternal) THEN RAISE EXCEPTION 'Unexpected epoch trigger'; END IF;

 IF v_event=v_original AND v_link IS NULL THEN
   PERFORM set_config('reconciliation_test.outcome','already_original',true);
   RETURN;
 END IF;

 v_audit:=v_event#>ARRAY['metadata',v_marker];
 IF v_audit IS NULL OR v_audit->'original_event' IS DISTINCT FROM v_original
 OR v_audit->>'operation_id' IS DISTINCT FROM 'synthetic-reconciliation-v1'
 OR v_audit->>'source_ref' IS DISTINCT FROM v_source::text
 OR v_audit->>'original_event_md5' IS DISTINCT FROM (v_contract->>'event_md5')
 OR v_audit->'link_snapshot' IS DISTINCT FROM v_link
 OR v_audit->'applied_at' IS DISTINCT FROM v_link->'confirmed_at'
 OR (v_audit-'applied_at') IS DISTINCT FROM jsonb_build_object(
   'operation_id','synthetic-reconciliation-v1','source_table','credits','source_ref',v_source,
   'received_date',(v_contract#>>'{credit,posting_date}')::date,'received_amount',(v_contract#>>'{credit,signed_amount}')::numeric,'original_expected_amount',(v_original->>'amount')::numeric,
   'difference_received_minus_expected',((v_contract#>>'{credit,signed_amount}')::numeric-(v_original->>'amount')::numeric),'residual_expected',false,
   'user_message_id',(v_contract->>'user_message_id'),
   'original_event',v_original,'original_event_md5',(v_contract->>'event_md5'),
   'credit_raw_hash',(v_contract->>'credit_raw_hash'),'credit_row_md5_at_apply',(v_contract->>'credit_md5'),
   'credit_updated_at_at_apply',(v_contract->>'credit_updated_at')::text,'link_snapshot',v_link)
 OR v_link IS NULL
 OR v_link->>'user_id' IS DISTINCT FROM v_uid::text
 OR v_link->>'target_event_id' IS DISTINCT FROM v_target::text
 OR v_link->>'candidate_source_table' IS DISTINCT FROM 'credits'
 OR v_link->>'candidate_source_ref' IS DISTINCT FROM v_source::text
 OR (v_link->>'candidate_amount')::numeric IS DISTINCT FROM (v_contract#>>'{credit,signed_amount}')::numeric
 OR v_link->>'candidate_event_date' IS DISTINCT FROM (v_contract#>>'{credit,posting_date}')
 OR v_link->>'note' IS DISTINCT FROM v_note
 OR (v_event-ARRAY['is_suppressed','suppression_reason','metadata']) IS DISTINCT FROM (v_original-ARRAY['is_suppressed','suppression_reason','metadata'])
 OR v_event->'metadata' IS DISTINCT FROM (v_original->'metadata'||jsonb_build_object(v_marker,v_audit))
 OR v_event->'is_suppressed' IS DISTINCT FROM 'true'::jsonb
 OR v_event->>'suppression_reason' IS DISTINCT FROM v_reason THEN RAISE EXCEPTION 'Not the exact applied state; manual review required'; END IF;

 IF v_post_event_md5 !~ '^[0-9a-f]{32}$' OR v_post_link_md5 !~ '^[0-9a-f]{32}$' THEN RAISE EXCEPTION 'Inverse requires approved COMMITTED receipt hashes'; END IF;
 IF md5(v_event::text) IS DISTINCT FROM v_post_event_md5 OR md5(v_link::text) IS DISTINCT FROM v_post_link_md5 THEN RAISE EXCEPTION 'Applied event or link changed since committed receipt'; END IF;
 -- Save the applied event/link receipt outside the database before using this inverse.
 -- The generated link is the only row removed; original financial data is restored, not deleted.
 UPDATE reconciliation_fixture.events e
 SET is_suppressed=(v_original->>'is_suppressed')::boolean,
     suppression_reason=v_original->>'suppression_reason',metadata=v_original->'metadata'
 WHERE e.id=v_target AND e.user_id=v_uid AND to_jsonb(e)=v_event;
 GET DIAGNOSTICS v_n=ROW_COUNT;
 IF v_n<>1 THEN RAISE EXCEPTION 'Expected exactly one restored event'; END IF;
 DELETE FROM reconciliation_fixture.links l
 WHERE l.id=(v_link->>'id')::bigint AND l.user_id=v_uid AND l.target_event_id=v_target AND to_jsonb(l)=v_link;
 GET DIAGNOSTICS v_n=ROW_COUNT;
 IF v_n<>1 THEN RAISE EXCEPTION 'Expected exactly one removed correction link'; END IF;
 IF (SELECT to_jsonb(e) FROM reconciliation_fixture.events e WHERE e.id=v_target) IS DISTINCT FROM v_original THEN RAISE EXCEPTION 'Original event not exactly restored'; END IF;
 IF EXISTS(SELECT 1 FROM reconciliation_fixture.links l WHERE l.user_id=v_uid AND l.target_event_id=v_target) THEN RAISE EXCEPTION 'Correction link survived inverse'; END IF;
 IF (SELECT to_jsonb(s) FROM reconciliation_fixture.credits s WHERE s.id=v_source) IS DISTINCT FROM v_credit THEN RAISE EXCEPTION 'Credit changed during inverse'; END IF;
 IF (SELECT epoch FROM reconciliation_fixture.epoch WHERE singleton=true) IS DISTINCT FROM v_epoch+2 THEN RAISE EXCEPTION 'Expected two automatic inverse invalidations'; END IF;
 PERFORM set_config('reconciliation_test.outcome','restored_in_transaction',true);
END $undo$;
SELECT current_setting('reconciliation_test.outcome',true) AS outcome,to_jsonb(e) AS restored_event
FROM reconciliation_fixture.events e WHERE e.id=((current_setting('reconciliation_test.contract')::jsonb)#>>'{original_event,id}')::uuid;
ROLLBACK; -- Runner can commit only inside the disposable fixture database.
