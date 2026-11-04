-- V406 replaces the exporter and adds a private schema-metadata helper.
-- Existing sources, archives, schedules and exporter grants remain unchanged.
-- Exact predecessor checks reject drift; replay of this exact body is supported.
-- Run atomically (migration transaction or psql --single-transaction).
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
DO $guard$
BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.lts_backup_modern_export_v380(uuid)'::regprocedure) NOT IN ('5773d7dca5fd7d31f84c54dccc4c5f1d','dc53800722b4c965dc0df629ff7453a9') THEN
  RAISE EXCEPTION 'Backup predecessor changed: lts_backup_modern_export_v380';
 END IF;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.lts_backup_modern_export_pre_v403(uuid)'::regprocedure) NOT IN ('a256df35dd6df8298039a7fa2c943edc') THEN
  RAISE EXCEPTION 'Backup predecessor changed: lts_backup_modern_export_pre_v403';
 END IF;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.lts_backup_family_extend_v398(uuid,jsonb)'::regprocedure) NOT IN ('35f10fc6b1c7b2776ab9df4c0fdca55d') THEN
  RAISE EXCEPTION 'Backup predecessor changed: lts_backup_family_extend_v398';
 END IF;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.lts_backup_position_sources_v403(uuid)'::regprocedure) NOT IN ('df5d1e81ba8acf7e565117088bbbd0ad') THEN
  RAISE EXCEPTION 'Backup predecessor changed: lts_backup_position_sources_v403';
 END IF;
 IF to_regprocedure('public.lts_backup_base_schema_v406()') IS NOT NULL AND
  (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.lts_backup_base_schema_v406()'))<>'21ba3ff89dc783789cd7538c3492488a' THEN
  RAISE EXCEPTION 'Backup predecessor changed: lts_backup_base_schema_v406';
 END IF;
END $guard$;

CREATE OR REPLACE FUNCTION public.lts_backup_base_schema_v406()
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,public
AS $function$
-- Preserve the predecessor's deparsed defaults without retaining financial payloads.
SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY c.table_schema,c.table_name,c.ordinal_position),'[]'::jsonb)
FROM information_schema.columns c
WHERE (c.table_schema='public' AND c.table_name IN('lts_brokerage_position_snapshots','lts_brokerage_reference_v352','lts_card_documentary_payment_link_v272','lts_card_due_rule_v290','lts_card_due_transition_v370','lts_card_history_item_v346','lts_card_history_parent_v346','lts_card_instruments','lts_card_settlement_expense_contract_v273','lts_category_alias','lts_category_binding_v290','lts_category_catalog','lts_commitment_documentary_schedule','lts_debt_position','lts_expense_documentary_amount_override','lts_future_liquidity_schedule','lts_liquidity_movement','lts_open_finance_staging','lts_projection_replacement_rule','lts_realized_bank_event_v238','lts_reconciliation_link','lts_recurring_occurrence_v366','lts_recurring_plan_v366','lts_semantic_rule','lts_v178_review_decision','lts_v229_card_recurring_commitment','lts_open_finance_connection','lts_open_finance_sync_run','usuario'))
OR (c.table_schema IN('lts_cash_alert_private_v377','lts_account_reminder_private_v387') AND c.table_name='delivery');
$function$;
REVOKE ALL ON FUNCTION public.lts_backup_base_schema_v406() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_backup_base_schema_v406() TO service_role;

CREATE OR REPLACE FUNCTION public.lts_backup_modern_export_v380(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog
AS $function$
-- v406-single-assembly: preserve the V403 profile without nested whole-bundle copies.
WITH bank_cohorts AS MATERIALIZED (
 SELECT DISTINCT ON(r.connection_id,(r.started_at AT TIME ZONE 'America/Sao_Paulo')::date) r.id
 FROM public.lts_open_finance_sync_run r
 WHERE r.user_id=p_user_id AND r.status='success' AND r.started_at<=statement_timestamp()
 AND EXISTS(SELECT 1 FROM public.lts_open_finance_observation o
  WHERE o.sync_run_id=r.id AND o.user_id=p_user_id AND o.resource_type IN('balance','investment','loan'))
 ORDER BY r.connection_id,(r.started_at AT TIME ZONE 'America/Sao_Paulo')::date,r.started_at DESC,r.id DESC
), bounds AS (
 SELECT min((r.started_at AT TIME ZONE 'America/Sao_Paulo')::date) first_day
 FROM public.lts_open_finance_sync_run r WHERE r.user_id=p_user_id AND r.status='success'
), verified_cofrinho AS MATERIALIZED (
 SELECT DISTINCT nullif(public.lts_cofrinho_provider_position_v402(p_user_id,d::date)->>'source_run_id','')::uuid id
 FROM bounds CROSS JOIN LATERAL generate_series(first_day::timestamp,
  (statement_timestamp() AT TIME ZONE 'America/Sao_Paulo')::date::timestamp,interval '1 day') d
), cohorts AS MATERIALIZED (
 SELECT id FROM bank_cohorts UNION SELECT id FROM verified_cofrinho WHERE id IS NOT NULL
), position_ids AS MATERIALIZED (
 -- Only the keys are retained between consumers; historical payloads stay in their table.
 SELECT o.id,o.sync_run_id
 FROM cohorts c JOIN public.lts_open_finance_observation o ON o.sync_run_id=c.id
 WHERE o.user_id=p_user_id AND o.resource_type IN('balance','investment','loan')
 AND o.observed_at<=statement_timestamp()
)
SELECT jsonb_build_object('format','lts-modern-supplement-v380','user_id',p_user_id,
 'captured_at',statement_timestamp(),'tables',jsonb_build_object(
'lts_brokerage_position_snapshots',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_brokerage_position_snapshots" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_brokerage_reference_v352',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_brokerage_reference_v352" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_card_documentary_payment_link_v272',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_card_documentary_payment_link_v272" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_card_due_rule_v290',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."family",t."effective_from") from public."lts_card_due_rule_v290" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_card_due_transition_v370',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."family") from public."lts_card_due_transition_v370" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_card_history_item_v346',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."source_hash",t."source_sheet",t."source_row") from public."lts_card_history_item_v346" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_card_history_parent_v346',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."parent_key") from public."lts_card_history_parent_v346" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_card_instruments',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_card_instruments" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_card_settlement_expense_contract_v273',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."payment_source_id") from public."lts_card_settlement_expense_contract_v273" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_category_alias',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."alias") from public."lts_category_alias" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_category_binding_v290',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."source_table",t."source_ref",t."raw_category") from public."lts_category_binding_v290" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_category_catalog',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."category_key") from public."lts_category_catalog" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_commitment_documentary_schedule',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_commitment_documentary_schedule" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_debt_position',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_debt_position" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_expense_documentary_amount_override',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_expense_documentary_amount_override" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_future_liquidity_schedule',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_future_liquidity_schedule" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_liquidity_movement',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_liquidity_movement" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_open_finance_staging',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_open_finance_staging" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_projection_replacement_rule',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_projection_replacement_rule" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_realized_bank_event_v238',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."financial_event_id") from public."lts_realized_bank_event_v238" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_reconciliation_link',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_reconciliation_link" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_recurring_occurrence_v366',coalesce((select jsonb_agg(to_jsonb(t) order by t."plan_id",t."revision",t."event_date") from public."lts_recurring_occurrence_v366" t where exists(select 1 from public.lts_recurring_plan_v366 p where p.id=t.plan_id and p.user_id=p_user_id)),'[]'::jsonb),
'lts_recurring_plan_v366',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_recurring_plan_v366" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_semantic_rule',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_semantic_rule" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_v178_review_decision',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."source_table",t."source_ref") from public."lts_v178_review_decision" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_v229_card_recurring_commitment',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."family",t."description") from public."lts_v229_card_recurring_commitment" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_open_finance_connection',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_open_finance_connection" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_open_finance_sync_run',coalesce((select jsonb_agg(to_jsonb(t) order by t.id::text) from public.lts_open_finance_sync_run t where t.user_id=p_user_id and (exists(select 1 from public.lts_open_finance_staging s where s.user_id=p_user_id and s.sync_run_id=t.id) or exists(select 1 from position_ids p where p.sync_run_id=t.id))),'[]'::jsonb),

'lts_cash_alert_private_v377.delivery',coalesce((select jsonb_agg(to_jsonb(t) order by t.sent_at,t.token) from lts_cash_alert_private_v377.delivery t where t.user_id=p_user_id),'[]'::jsonb),
'lts_account_reminder_private_v387.delivery',coalesce((select jsonb_agg(to_jsonb(t) order by t.sent_at,t.token) from lts_account_reminder_private_v387.delivery t where t.user_id=p_user_id),'[]'::jsonb),
'usuario',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."usuario" t where t.id=p_user_id),'[]'::jsonb),
'lts_family_loan_v398',coalesce((select jsonb_agg(to_jsonb(l) order by commitment_id) from public.lts_family_loan_v398 l where user_id=p_user_id),'[]'::jsonb),
'lts_savings_rate_v398',coalesce((select jsonb_agg(to_jsonb(r) order by period_start) from public.lts_savings_rate_v398 r where r.period_start>=(select min(starts_on) from public.lts_family_loan_v398 where user_id=p_user_id)),'[]'::jsonb),
'lts_open_finance_resource_map',coalesce((select jsonb_agg(to_jsonb(m) order by m.id) from public.lts_open_finance_resource_map m where m.user_id=p_user_id),'[]'::jsonb),
'lts_open_finance_observation',coalesce((select jsonb_agg(to_jsonb(o) order by o.id) from public.lts_open_finance_observation o join position_ids p on p.id=o.id),'[]'::jsonb)),
 'coverage',jsonb_build_object(
  'selected_tables',35,'notification_delivery_journals',true,'all_application_tables',false,
  'complete_schema_roles_auth',false,'storage_binaries',false,'full_restore_tested',false,
  'indexed_family_loan_inputs',true,
  'position_observation_scope','daily_position_cohorts_and_verified_cofrinho_days',
  'all_observation_history',false,'verified_resource_mapping',true,
  'capture_transaction_isolation',current_setting('transaction_isolation'),
  'capture_kind',coalesce(nullif(current_setting('lts.backup_capture_kind',true),''),'unspecified'),
  'sync_history_scope','Staging references plus preserved daily position cohorts'),
 'schema_columns',public.lts_backup_base_schema_v406()||
  (SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY
    CASE WHEN c.table_name IN('lts_family_loan_v398','lts_savings_rate_v398') THEN 1 ELSE 2 END,
    c.table_schema,c.table_name,c.ordinal_position),'[]'::jsonb)
   FROM information_schema.columns c WHERE c.table_schema='public'
   AND c.table_name IN('lts_family_loan_v398','lts_savings_rate_v398','lts_open_finance_resource_map','lts_open_finance_observation')));
$function$;
