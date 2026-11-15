CREATE OR REPLACE FUNCTION public.lts_browser_budget_read_v441(p_year integer)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
 SELECT lts_budget_private_v441.build(public.lts_browser_assert_user_v1(),p_year,current_date);
$function$
