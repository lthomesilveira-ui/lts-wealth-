CREATE OR REPLACE FUNCTION public.lts_browser_product_refresh_status_v415()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1();
BEGIN
 RETURN jsonb_build_object('ok',true,'refresh',lts_product_refresh_private_v415.status(u));
END $function$
