CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.projection_current_v452(p_user_id uuid)
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
