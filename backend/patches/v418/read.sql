CREATE OR REPLACE FUNCTION lts_projection_private_v412.read_policy()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
SET TimeZone='America/Sao_Paulo' AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); memo jsonb; q record; epoch_now bigint;
BEGIN
 IF lts_projection_private_v412.owner_policy(u) IS NULL THEN
  RETURN jsonb_build_object('version','projection-policy-v412','enabled',false,'read_at',clock_timestamp());
 END IF;
 SELECT payload->'projection_summary_v418' INTO memo
 FROM public.lts_product_read_cache WHERE user_id=u;
 SELECT * INTO q FROM lts_product_refresh_private_v415.queue WHERE user_id=u;
 SELECT epoch INTO epoch_now FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 IF memo->>'user_id' IS DISTINCT FROM u::text
  OR memo->>'as_of' IS DISTINCT FROM current_date::text
  OR q.state IS DISTINCT FROM 'ready'
  OR q.completed_version IS DISTINCT FROM q.request_version
  OR memo#>>'{guard,request_version}' IS DISTINCT FROM q.completed_version::text
  OR memo#>>'{guard,source_epoch}' IS DISTINCT FROM epoch_now::text
  OR memo#>>'{guard,card_source_key}' IS DISTINCT FROM lts_product_refresh_private_v415.card_source_key(u)
  OR memo#>>'{guard,policy_sha256}' IS DISTINCT FROM (SELECT sha256 FROM public.legacy_namespace
   WHERE usuario_id=u AND chave='lts_owner_projection_policy_v412')
  OR memo#>>'{guard,reference_sha256}' IS DISTINCT FROM (SELECT sha256 FROM public.legacy_namespace
   WHERE usuario_id=u AND chave='lts_projection_reference_v412')
  OR memo#>>'{summary,enabled}' IS DISTINCT FROM 'true'
 THEN
  RAISE EXCEPTION USING ERRCODE='55000',
   MESSAGE='As premissas estão sendo atualizadas. Tente novamente.';
 END IF;
 RETURN memo->'summary'||jsonb_build_object('read_at',clock_timestamp());
END $function$;
