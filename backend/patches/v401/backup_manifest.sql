-- V401: verify the complete backup profile, including the V398 family inputs.
-- Historical 29/31-table bundles retain their original bytes and hashes.
CREATE OR REPLACE FUNCTION public.lts_backup_manifest_valid_v401(p_payload jsonb,p_counts jsonb)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog AS $function$
DECLARE
 expected_keys text[] := ARRAY[
  'lts_brokerage_position_snapshots','lts_brokerage_reference_v352',
  'lts_card_documentary_payment_link_v272','lts_card_due_rule_v290',
  'lts_card_due_transition_v370','lts_card_history_item_v346',
  'lts_card_history_parent_v346','lts_card_instruments',
  'lts_card_settlement_expense_contract_v273','lts_category_alias',
  'lts_category_binding_v290','lts_category_catalog',
  'lts_commitment_documentary_schedule','lts_debt_position',
  'lts_expense_documentary_amount_override','lts_future_liquidity_schedule',
  'lts_liquidity_movement','lts_open_finance_staging',
  'lts_projection_replacement_rule','lts_realized_bank_event_v238',
  'lts_reconciliation_link','lts_recurring_occurrence_v366',
  'lts_recurring_plan_v366','lts_semantic_rule','lts_v178_review_decision',
  'lts_v229_card_recurring_commitment','lts_open_finance_connection',
  'lts_open_finance_sync_run','usuario'];
 actual_keys text[]; actual_counts jsonb; table_count integer;
BEGIN
 IF p_payload->>'format' IS DISTINCT FROM 'lts-modern-supplement-v380'
 OR jsonb_typeof(p_payload->'tables') IS DISTINCT FROM 'object'
 OR jsonb_typeof(p_counts) IS DISTINCT FROM 'object' THEN RETURN false;END IF;
 IF EXISTS(SELECT 1 FROM jsonb_each(p_payload->'tables') WHERE jsonb_typeof(value)<>'array') THEN RETURN false;END IF;
 SELECT array_agg(key ORDER BY key COLLATE "C"),jsonb_object_agg(key,jsonb_array_length(value)),count(*)
 INTO actual_keys,actual_counts,table_count FROM jsonb_each(p_payload->'tables');
 IF table_count NOT IN(29,31,33) THEN RETURN false;END IF;
 IF table_count>=31 THEN
  expected_keys:=expected_keys||ARRAY['lts_cash_alert_private_v377.delivery','lts_account_reminder_private_v387.delivery'];
 END IF;
 IF table_count=33 THEN
  expected_keys:=expected_keys||ARRAY['lts_family_loan_v398','lts_savings_rate_v398'];
  IF p_payload#>'{coverage,indexed_family_loan_inputs}' IS DISTINCT FROM 'true'::jsonb THEN RETURN false;END IF;
 END IF;
 SELECT array_agg(x ORDER BY x COLLATE "C") INTO expected_keys FROM unnest(expected_keys)x;
 RETURN coalesce(actual_keys=expected_keys AND actual_counts=p_counts
  AND p_payload#>'{coverage,selected_tables}'=to_jsonb(table_count),false);
END $function$;
REVOKE ALL ON FUNCTION public.lts_backup_manifest_valid_v401(jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_backup_manifest_valid_v401(jsonb,jsonb) TO service_role;

DO $patch$
DECLARE
 take_def text:=pg_get_functiondef('public.lts_backup_snapshot_take_v380(uuid,date)'::regprocedure);
 read_def text:=pg_get_functiondef('public.lts_backup_bundle_read_v380(uuid,date)'::regprocedure);
 export_def text:=pg_get_functiondef('public.lts_backup_modern_export_v380(uuid)'::regprocedure);
 marker text:='v401-complete-backup-manifest';
 old_take text:=$old$ perform public.lts_backup_snapshot_take_v1(p_user_id,d);
 select * into strict b from public.lts_backup_snapshot where user_id=p_user_id and snapshot_date=d;
 if b.payload_hash is distinct from md5(b.payload::text) then raise exception 'legacy backup integrity mismatch';end if;
 j:=public.lts_backup_modern_export_v380(p_user_id);
 select jsonb_object_agg(key,jsonb_array_length(value)),count(*) into v_counts,v_n from jsonb_each(j->'tables');
 if v_n<>31 then raise exception 'incomplete modern backup';end if;$old$;
 new_take text:=$new$ -- v401-complete-backup-manifest
 j:=public.lts_backup_modern_export_v380(p_user_id);
 select jsonb_object_agg(key,jsonb_array_length(value)),count(*) into v_counts,v_n from jsonb_each(j->'tables');
 if v_n<>33 or not public.lts_backup_manifest_valid_v401(j,v_counts) then raise exception 'incomplete modern backup';end if;
 -- Reject an invalid modern export before invoking the legacy diagnostics.
 perform public.lts_backup_snapshot_take_v1(p_user_id,d);
 select * into strict b from public.lts_backup_snapshot where user_id=p_user_id and snapshot_date=d;
 if b.payload_hash is distinct from md5(b.payload::text) then raise exception 'legacy backup integrity mismatch';end if;$new$;
 old_read text:=$old$ select jsonb_object_agg(key,jsonb_array_length(value)) into v_counts from jsonb_each(s.payload->'tables');
 if v_counts is distinct from s.counts
 or (select count(*) from jsonb_each(s.payload->'tables')) not in(29,31)
 or (s.payload#>>'{coverage,selected_tables}')::int is distinct from(select count(*)::int from jsonb_each(s.payload->'tables'))
 or((s.payload#>>'{coverage,selected_tables}')::int=31 and not(s.payload->'tables'?'lts_cash_alert_private_v377.delivery'and s.payload->'tables'?'lts_account_reminder_private_v387.delivery'))then raise exception 'modern backup manifest mismatch';end if;$old$;
 new_read text:=$new$ -- v401-complete-backup-manifest
 if not public.lts_backup_manifest_valid_v401(s.payload,s.counts) then raise exception 'modern backup manifest mismatch';end if;$new$;
BEGIN
 IF position(marker IN take_def)>0 AND position(marker IN read_def)>0 THEN RETURN;END IF;
 IF position(marker IN take_def)>0 OR position(marker IN read_def)>0
 OR position('v398-family-backup' IN export_def)=0
 OR position(old_take IN take_def)=0 OR position(old_read IN read_def)=0 THEN
  RAISE EXCEPTION 'Backup pipeline changed; review its source before applying V401';
 END IF;
 EXECUTE replace(take_def,old_take,new_take);
 EXECUTE replace(read_def,old_read,new_read);
END $patch$;
