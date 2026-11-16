BEGIN;
SET LOCAL lock_timeout='2s';
DO $guard$ DECLARE h text;acl text;cfg text[];definer boolean;owner text;BEGIN
SELECT md5(pg_get_functiondef(oid)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO h,acl,cfg,definer,owner FROM pg_proc WHERE oid='lts_product_refresh_private_v415.cache_info(uuid)'::regprocedure;
 IF h NOT IN('35a000166f41a2a1dda8a6f1a93d1cd5','6e11e7bef80d4f09e7e2d8adf285fa8c') OR acl IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' OR cfg IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo'] OR NOT definer OR owner<>'postgres' THEN RAISE EXCEPTION 'Projection readiness changed concurrently: lts_product_refresh_private_v415.cache_info(uuid)';END IF;
SELECT md5(pg_get_functiondef(oid)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO h,acl,cfg,definer,owner FROM pg_proc WHERE oid='public.lts_browser_product_refresh_status_v415()'::regprocedure;
 IF h NOT IN('487de700484d692455c9d6997a19caca','cdc801a8f4ce6218bac9f2eab70b168c') OR acl IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres,authenticated=X/postgres}' OR cfg IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo'] OR NOT definer OR owner<>'postgres' THEN RAISE EXCEPTION 'Projection readiness changed concurrently: public.lts_browser_product_refresh_status_v415()';END IF;
IF to_regprocedure('lts_product_refresh_private_v415.projection_current_v452(uuid)') IS NOT NULL THEN
 SELECT md5(pg_get_functiondef(oid)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO h,acl,cfg,definer,owner FROM pg_proc WHERE oid='lts_product_refresh_private_v415.projection_current_v452(uuid)'::regprocedure;
 IF h<>'8198f3bf2ec0b733b286eeee4b046736' OR acl IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' OR cfg IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo'] OR definer OR owner<>'postgres' THEN RAISE EXCEPTION 'Projection helper changed concurrently';END IF;END IF;
IF md5(pg_get_functiondef('lts_product_refresh_private_v415.enqueue(uuid,text,boolean)'::regprocedure))<>'87ca660940f70a21ab9be655903345e2' THEN RAISE EXCEPTION 'Existing refresh queue changed concurrently';END IF;
IF md5(pg_get_functiondef('lts_product_refresh_private_v415.status(uuid)'::regprocedure))<>'fc799b22831e1fe4b39cfd82a66a699f' THEN RAISE EXCEPTION 'Existing refresh queue changed concurrently';END IF;
END $guard$;
DO $change$ BEGIN
IF to_regprocedure('lts_product_refresh_private_v415.projection_current_v452(uuid)') IS NULL THEN EXECUTE $replace$CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.projection_current_v452(p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE memo jsonb; q record; epoch_now bigint;
BEGIN
 IF lts_projection_private_v412.owner_policy(p_user_id) IS NULL THEN RETURN true;END IF;
 SELECT payload->'projection_summary_v418' INTO memo FROM public.lts_product_read_cache WHERE user_id=p_user_id;
 SELECT * INTO q FROM lts_product_refresh_private_v415.queue WHERE user_id=p_user_id;
 SELECT epoch INTO epoch_now FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 IF NOT FOUND OR q IS NULL THEN RETURN false;END IF;
 RETURN memo->>'user_id' IS NOT DISTINCT FROM p_user_id::text
  AND memo->>'as_of' IS NOT DISTINCT FROM current_date::text
  AND q.state IS NOT DISTINCT FROM 'ready'
  AND q.completed_version IS NOT DISTINCT FROM q.request_version
  AND memo#>>'{guard,request_version}' IS NOT DISTINCT FROM q.completed_version::text
  AND memo#>>'{guard,source_epoch}' IS NOT DISTINCT FROM epoch_now::text
  AND memo#>>'{guard,card_source_key}' IS NOT DISTINCT FROM lts_product_refresh_private_v415.card_source_key(p_user_id)
  AND memo#>>'{guard,policy_sha256}' IS NOT DISTINCT FROM (SELECT sha256 FROM public.legacy_namespace WHERE usuario_id=p_user_id AND chave='lts_owner_projection_policy_v412')
  AND memo#>>'{guard,reference_sha256}' IS NOT DISTINCT FROM (SELECT sha256 FROM public.legacy_namespace WHERE usuario_id=p_user_id AND chave='lts_projection_reference_v412')
  AND memo#>>'{summary,enabled}' IS NOT DISTINCT FROM 'true';
END $function$
$replace$;ALTER FUNCTION lts_product_refresh_private_v415.projection_current_v452(uuid) OWNER TO postgres;REVOKE ALL ON FUNCTION lts_product_refresh_private_v415.projection_current_v452(uuid) FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION lts_product_refresh_private_v415.projection_current_v452(uuid) TO service_role;END IF;
IF md5(pg_get_functiondef('lts_product_refresh_private_v415.cache_info(uuid)'::regprocedure))='35a000166f41a2a1dda8a6f1a93d1cd5' THEN EXECUTE $replace$CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.cache_info(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
 SELECT coalesce((SELECT jsonb_build_object(
  'available',lts_product_refresh_private_v415.compatible(c.payload_version,c.payload),
  'current',lts_product_refresh_private_v415.compatible(c.payload_version,c.payload)
   AND c.payload#>>'{canonical_summary,as_of}'=current_date::text
   AND c.payload#>>'{updates,freshness,today}'=current_date::text
   AND c.payload#>>'{updates,document_change_summary_version}'='document-change-summary-v1'
   AND CASE WHEN jsonb_typeof(c.payload#>'{flow,days}')='array' THEN EXISTS(
    SELECT 1 FROM jsonb_array_elements(c.payload#>'{flow,days}') d WHERE d->>'date'=current_date::text) ELSE false END
   AND NOT coalesce(c.payload->'product_refresh_pending_v415'='true'::jsonb,false)
   AND lts_product_refresh_private_v415.card_state_cached(p_user_id) IS NOT NULL
   AND lts_product_refresh_private_v415.projection_current_v452(p_user_id),
  'refreshed_at',c.refreshed_at) FROM public.lts_product_read_cache c WHERE c.user_id=p_user_id),
  jsonb_build_object('available',false,'current',false,'refreshed_at',NULL))
$function$
$replace$;END IF;
IF md5(pg_get_functiondef('lts_product_refresh_private_v415.cache_info(uuid)'::regprocedure))<>'6e11e7bef80d4f09e7e2d8adf285fa8c' THEN RAISE EXCEPTION 'Projection readiness reconstruction differs';END IF;
IF md5(pg_get_functiondef('public.lts_browser_product_refresh_status_v415()'::regprocedure))='487de700484d692455c9d6997a19caca' THEN EXECUTE $replace$CREATE OR REPLACE FUNCTION public.lts_browser_product_refresh_status_v415()
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
$replace$;END IF;
IF md5(pg_get_functiondef('public.lts_browser_product_refresh_status_v415()'::regprocedure))<>'cdc801a8f4ce6218bac9f2eab70b168c' THEN RAISE EXCEPTION 'Projection readiness reconstruction differs';END IF;
END $change$;
COMMIT;
