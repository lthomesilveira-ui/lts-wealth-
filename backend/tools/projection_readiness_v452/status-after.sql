CREATE OR REPLACE FUNCTION public.lts_browser_product_refresh_status_v415()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); refresh jsonb;
BEGIN
 refresh:=lts_product_refresh_private_v415.status(u);
 -- A refreshed card view must not certify an obsolete projection snapshot.
 -- Join the existing queue only when no version is already pending/running.
 -- enqueue(false) rechecks under its existing row lock and never starts a worker.
 IF refresh->>'required'='true' AND refresh->>'state'='pending'
  AND refresh->>'request_version'=refresh->>'completed_version' THEN
  refresh:=lts_product_refresh_private_v415.enqueue(u,'cache_read',false);
 END IF;
 RETURN jsonb_build_object('ok',true,'refresh',refresh);
END $function$
