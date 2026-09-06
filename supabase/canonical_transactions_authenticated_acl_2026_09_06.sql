-- LTS Wealth canonical transaction-search ACL fix — 2026-09-06
-- Scope: expose the existing browser RPC to authenticated users only.
-- The RPC remains SECURITY DEFINER and calls lts_browser_assert_user_v1(), then
-- filters lts_expense_analytics_candidate by the asserted canonical user_id.

revoke all on function public.lts_browser_transactions_v1(date,date,text,text,text,integer,integer) from public, anon;
grant execute on function public.lts_browser_transactions_v1(date,date,text,text,text,integer,integer) to authenticated, service_role;