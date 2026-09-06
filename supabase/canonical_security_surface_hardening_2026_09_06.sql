-- LTS Wealth canonical security surface hardening — 2026-09-06
-- Scope: permissions / RLS / view execution semantics only. No financial arithmetic or data mutation.

-- 1) Internal append-only and catalog tables are never direct browser APIs.
alter table public.lts_flow_event_operation enable row level security;
alter table public.lts_flow_mutation_audit enable row level security;
alter table public.lts_category_catalog enable row level security;

revoke all privileges on table public.lts_flow_event_operation from public, anon, authenticated;
revoke all privileges on table public.lts_flow_mutation_audit from public, anon, authenticated;
revoke all privileges on table public.lts_category_catalog from public, anon, authenticated;

-- 2) Expense views must execute with the invoking identity. Browser readers are SECURITY DEFINER
-- wrappers scoped by lts_browser_assert_user_v1(); direct browser access to these internal views is removed.
alter view public.lts_expense_analytics_candidate set (security_invoker = true);
alter view public.lts_expense_realized set (security_invoker = true);
alter view public.lts_expense_analytics_candidate_fast_v1 set (security_invoker = true);

revoke all privileges on table public.lts_expense_analytics_candidate from public, anon, authenticated;
revoke all privileges on table public.lts_expense_realized from public, anon, authenticated;
revoke all privileges on table public.lts_expense_analytics_candidate_fast_v1 from public, anon, authenticated;

-- 3) Pure internal JSON enrichment helper: fixed search_path and no direct API exposure.
alter function public.lts_browser_enrich_flow_bank_gross_v1(jsonb)
  set search_path to pg_catalog, public;
revoke execute on function public.lts_browser_enrich_flow_bank_gross_v1(jsonb)
  from public, anon, authenticated;

-- 4) Compatibility browser reader remains authenticated-only (legacy public fallback may use it).
revoke execute on function public.lts_browser_expense_context_nature_v1(date,date)
  from public, anon;
grant execute on function public.lts_browser_expense_context_nature_v1(date,date)
  to authenticated;

-- 5) Internal / QA / arbitrary-user SECURITY DEFINER functions are not public browser APIs.
-- Current browser-facing wrappers call the needed internals as postgres-owned SECURITY DEFINER functions.
revoke execute on function public.lts_card_history_recovery_integrity_v1(uuid) from public, anon, authenticated;
revoke execute on function public.lts_card_history_recovery_promotion_preview_v1(uuid) from public, anon, authenticated;
revoke execute on function public.lts_card_history_recovery_qa_v1(uuid) from public, anon, authenticated;
revoke execute on function public.lts_daily_flow_fix86_v11(uuid,date,date) from public, anon, authenticated;
revoke execute on function public.lts_daily_flow_fix86_v14(uuid,date,date) from public, anon, authenticated;
revoke execute on function public.lts_daily_flow_full_query_v6(uuid,date,date) from public, anon, authenticated;
revoke execute on function public.lts_expense_context_nature_matrix_v1(uuid,date,date) from public, anon, authenticated;
revoke execute on function public.lts_expense_total_report_v1(uuid,date,date) from public, anon, authenticated;
revoke execute on function public.lts_expense_total_report_v2(uuid,date,date) from public, anon, authenticated;
revoke execute on function public.lts_expense_total_rows_v1(uuid,date,date) from public, anon, authenticated;
revoke execute on function public.lts_flow_future_fast_path_qa_v1(uuid) from public, anon, authenticated;
revoke execute on function public.lts_flow_future_read_cache_qa_v1(uuid) from public, anon, authenticated;
revoke execute on function public.lts_flow_future_read_cache_qa_v2(uuid) from public, anon, authenticated;
revoke execute on function public.lts_flow_future_read_cache_refresh_v1(uuid,integer) from public, anon, authenticated;
revoke execute on function public.lts_flow_future_read_cache_refresh_v3(uuid,integer) from public, anon, authenticated;
revoke execute on function public.lts_flow_future_read_slice_v2(uuid,date,date) from public, anon, authenticated;
revoke execute on function public.lts_refresh_after_liquidity_movement_v3(uuid) from public, anon, authenticated;
revoke execute on function public.lts_refresh_dashboard_cockpit_v2(uuid) from public, anon, authenticated;
revoke execute on function public.lts_refresh_expense_effective_read_cache_v1(uuid) from public, anon, authenticated;
revoke execute on function public.lts_release_candidate_financial_qa_v2_history_guard(uuid) from public, anon, authenticated;
revoke execute on function public.lts_salary_net_edit_qa_v1(uuid) from public, anon, authenticated;
revoke execute on function public.lts_sync_document_lifecycle_v1() from public, anon, authenticated;
revoke execute on function public.lts_sync_salary_projection_component_trigger_v1() from public, anon, authenticated;
revoke execute on function public.lts_update_lifecycle_append_v1(uuid,text,text,text,jsonb) from public, anon, authenticated;
revoke execute on function public.lts_updates_fix86plus_v11(uuid) from public, anon, authenticated;
revoke execute on function public.lts_wip35_v131_reports_qa(uuid) from public, anon, authenticated;
