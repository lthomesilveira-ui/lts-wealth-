-- Finite budgets for measured, authenticated report workloads and service-only sync.
-- Global role limits, ownership checks and write endpoints remain unchanged.
ALTER FUNCTION public.lts_browser_expenses_v178(date,date) SET statement_timeout='18s';
ALTER FUNCTION public.lts_browser_monthly_v178(date,date) SET statement_timeout='18s';
ALTER FUNCTION public.lts_browser_flow_v13(date,date) SET statement_timeout='18s';
ALTER FUNCTION public.lts_browser_planning_ui_contract_v1() SET statement_timeout='18s';
ALTER FUNCTION public.lts_open_finance_sources_v226(uuid,date,date) SET statement_timeout='20s';
NOTIFY pgrst, 'reload config';
NOTIFY pgrst, 'reload schema';

