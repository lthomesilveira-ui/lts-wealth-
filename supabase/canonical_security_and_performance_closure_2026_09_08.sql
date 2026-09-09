-- Canonical LTS Wealth security/performance closure.
-- This migration changes no financial facts. It normalizes browser authorization,
-- preserves the existing owner-only RLS predicate and adds FK-side indexes.

create or replace function public.lts_browser_card_classification_triage_v1(
  p_limit integer default 100
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_user uuid := public.lts_browser_assert_user_v1();
begin
  return public.lts_card_classification_triage_v1(v_user, p_limit);
end
$function$;

create or replace function public.lts_browser_document_outcome_state_v1(
  p_limit integer default 100
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_user uuid := public.lts_browser_assert_user_v1();
begin
  return public.lts_document_outcome_state_v1(
    v_user,
    greatest(1, least(coalesce(p_limit, 100), 500))
  );
end
$function$;

create or replace function public.lts_browser_expense_total_v2(
  p_from date default '2023-01-01'::date,
  p_to date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path = public
set "TimeZone" = 'America/Sao_Paulo'
as $function$
declare
  v_user uuid := public.lts_browser_assert_user_v1();
begin
  return public.lts_expense_total_report_v2(v_user, p_from, p_to);
end
$function$;

revoke all on function public.lts_browser_card_classification_triage_v1(integer) from public, anon;
revoke all on function public.lts_browser_document_outcome_state_v1(integer) from public, anon;
revoke all on function public.lts_browser_expense_total_v2(date, date) from public, anon;
grant execute on function public.lts_browser_card_classification_triage_v1(integer) to authenticated, service_role;
grant execute on function public.lts_browser_document_outcome_state_v1(integer) to authenticated, service_role;
grant execute on function public.lts_browser_expense_total_v2(date, date) to authenticated, service_role;

drop policy if exists lts_expense_effective_read_cache_select_own
  on public.lts_expense_effective_read_cache;
create policy lts_expense_effective_read_cache_select_own
  on public.lts_expense_effective_read_cache
  for select
  to authenticated
  using (user_id = (select auth.uid()));

create index if not exists lts_doc_extract_inbox_idx
  on public.lts_document_extraction_attempts (inbox_id);
create index if not exists lts_doc_extract_source_document_idx
  on public.lts_document_extraction_attempts (source_document_id);
create index if not exists lts_external_accounts_connection_idx
  on public.lts_external_accounts_stage (connection_id);
create index if not exists lts_external_transactions_connection_idx
  on public.lts_external_transactions_stage (connection_id);
create index if not exists lts_external_transactions_inbox_idx
  on public.lts_external_transactions_stage (inbox_id);
create index if not exists lts_external_transactions_ingestion_job_idx
  on public.lts_external_transactions_stage (ingestion_job_id);
create index if not exists lts_flow_event_operation_target_event_idx
  on public.lts_flow_event_operation (target_event_id);
create index if not exists lts_ingestion_jobs_connection_idx
  on public.lts_ingestion_jobs (connection_id);
create index if not exists lts_liquidity_movement_account_idx
  on public.lts_liquidity_movement (account_id);
create index if not exists lts_liquidity_movement_asset_position_idx
  on public.lts_liquidity_movement (asset_position_id);
create index if not exists lts_liquidity_movement_bank_event_idx
  on public.lts_liquidity_movement (bank_event_id);
create index if not exists lts_open_finance_staging_sync_run_idx
  on public.lts_open_finance_staging (sync_run_id);
create index if not exists lts_open_finance_sync_run_connection_idx
  on public.lts_open_finance_sync_run (connection_id);
create index if not exists lts_reconciliation_link_target_event_idx
  on public.lts_reconciliation_link (target_event_id);
