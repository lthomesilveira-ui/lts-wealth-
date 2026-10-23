-- Caller supplies the exact private manifest in lts.v305.input first.
\set ON_ERROR_STOP on
BEGIN ISOLATION LEVEL REPEATABLE READ;
\ir ../operations/confirm_health_reimbursement_v305.sql
SELECT set_config('lts.v305.first_receipt',current_setting('lts.v305.receipt'),true);
CREATE TEMP TABLE v305_first ON COMMIT DROP AS
 SELECT md5(to_jsonb(d)::text) decision,
 (SELECT count(*) FROM public.audit_log WHERE user_id=d.user_id
 AND action='confirm_bank_expense_category' AND entity_id=d.source_ref) audit_count
 FROM public.lts_v178_review_decision d WHERE user_id=public.lts_open_finance_pilot_owner_v1()
 AND source_table='lts_open_finance_staging' AND source_ref=current_setting('lts.v305.input')::jsonb#>>'{source,id}';
\ir ../operations/confirm_health_reimbursement_v305.sql
DO $replay$ BEGIN
 IF current_setting('lts.v305.writer_receipt')::jsonb->>'already_classified' IS DISTINCT FROM 'true'
 OR (SELECT decision FROM v305_first) IS DISTINCT FROM(SELECT md5(to_jsonb(d)::text)
 FROM public.lts_v178_review_decision d WHERE user_id=public.lts_open_finance_pilot_owner_v1()
 AND source_table='lts_open_finance_staging' AND source_ref=current_setting('lts.v305.input')::jsonb#>>'{source,id}')
 OR (SELECT audit_count FROM v305_first) IS DISTINCT FROM(SELECT count(*) FROM public.audit_log
 WHERE user_id=public.lts_open_finance_pilot_owner_v1() AND action='confirm_bank_expense_category'
 AND entity_id=current_setting('lts.v305.input')::jsonb#>>'{source,id}')
 THEN RAISE EXCEPTION 'Replay changed decision or duplicated audit';END IF;
END $replay$;
SELECT jsonb_build_object('status','PASS','first',current_setting('lts.v305.first_receipt')::jsonb,
 'second',current_setting('lts.v305.receipt')::jsonb,'replay_noop',true) receipt;
ROLLBACK;
