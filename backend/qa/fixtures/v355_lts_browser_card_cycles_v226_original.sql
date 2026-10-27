CREATE OR REPLACE FUNCTION public.lts_browser_card_cycles_v226()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1(); begin
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1()); RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,public.lts_card_cycles_v226(u)); end
$function$
