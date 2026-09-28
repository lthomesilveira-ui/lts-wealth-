-- Finite budget for the existing combined history inventory and Flow comparison.
ALTER FUNCTION public.lts_browser_card_flow_schedule_v2(date,date) SET statement_timeout='18s';
NOTIFY pgrst,'reload config';
NOTIFY pgrst,'reload schema';
