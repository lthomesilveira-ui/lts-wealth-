CREATE OR REPLACE FUNCTION public.lts_browser_recurring_future_gap_audit_v5(p_as_of date DEFAULT CURRENT_DATE, p_horizon_end date DEFAULT '2031-12-31'::date)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
SELECT public.lts_recurring_future_gap_audit_v6(public.lts_browser_assert_user_v1(),coalesce(p_as_of,(now() at time zone 'America/Sao_Paulo')::date),coalesce(p_horizon_end,date '2031-12-31'));
$function$
