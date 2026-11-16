BEGIN;
SET LOCAL lock_timeout='2s';
DO $guard$ DECLARE h text;acl text;cfg text[];definer boolean;owner text;BEGIN
SELECT md5(pg_get_functiondef(oid)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO h,acl,cfg,definer,owner FROM pg_proc WHERE oid='public.lts_browser_product_refresh_status_v415()'::regprocedure;
 IF h NOT IN('15e2c30dcd35410e94e91fdf7b2bad13','487de700484d692455c9d6997a19caca') OR acl IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres,authenticated=X/postgres}' OR cfg IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo'] OR NOT definer OR owner<>'postgres' THEN RAISE EXCEPTION 'Projection readiness changed concurrently: public.lts_browser_product_refresh_status_v415()';END IF;
IF to_regprocedure('lts_product_refresh_private_v415.projection_current_v452(uuid)') IS NOT NULL THEN
 SELECT md5(pg_get_functiondef(oid)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO h,acl,cfg,definer,owner FROM pg_proc WHERE oid='lts_product_refresh_private_v415.projection_current_v452(uuid)'::regprocedure;
 IF h<>'8198f3bf2ec0b733b286eeee4b046736' OR acl IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' OR cfg IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo'] OR definer OR owner<>'postgres' THEN RAISE EXCEPTION 'Projection helper changed concurrently';END IF;END IF;
IF md5(pg_get_functiondef('lts_product_refresh_private_v415.cache_info(uuid)'::regprocedure))<>'35a000166f41a2a1dda8a6f1a93d1cd5' THEN RAISE EXCEPTION 'Existing refresh queue changed concurrently';END IF;
IF md5(pg_get_functiondef('lts_product_refresh_private_v415.enqueue(uuid,text,boolean)'::regprocedure))<>'87ca660940f70a21ab9be655903345e2' THEN RAISE EXCEPTION 'Existing refresh queue changed concurrently';END IF;
IF md5(pg_get_functiondef('lts_product_refresh_private_v415.status(uuid)'::regprocedure))<>'fc799b22831e1fe4b39cfd82a66a699f' THEN RAISE EXCEPTION 'Existing refresh queue changed concurrently';END IF;
END $guard$;
DO $change$ BEGIN
IF md5(pg_get_functiondef('public.lts_browser_product_refresh_status_v415()'::regprocedure))='15e2c30dcd35410e94e91fdf7b2bad13' THEN EXECUTE $replace$CREATE OR REPLACE FUNCTION public.lts_browser_product_refresh_status_v415()
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
$replace$;END IF;
IF md5(pg_get_functiondef('public.lts_browser_product_refresh_status_v415()'::regprocedure))<>'487de700484d692455c9d6997a19caca' THEN RAISE EXCEPTION 'Projection readiness reconstruction differs';END IF;
DROP FUNCTION IF EXISTS lts_product_refresh_private_v415.projection_current_v452(uuid);
END $change$;
COMMIT;
