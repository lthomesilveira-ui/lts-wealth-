CREATE OR REPLACE FUNCTION lts_projection_private_v412.read_build_cache_v438(p_user_id uuid,p_as_of date,p_policy jsonb)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' SET TimeZone='America/Sao_Paulo' AS $cache$
 SELECT m.j->'payload'
 FROM public.lts_product_read_cache c
 JOIN lts_product_refresh_private_v415.queue q ON q.user_id=c.user_id
 CROSS JOIN LATERAL (SELECT c.payload->'projection_build_v438' j) m
 WHERE c.user_id=p_user_id AND p_as_of=current_date
 AND q.state='ready' AND q.completed_version=q.request_version
 AND m.j->>'user_id'=p_user_id::text AND m.j->>'as_of'=p_as_of::text
 AND m.j#>>'{guard,request_version}'=q.completed_version::text
 AND m.j#>>'{guard,source_epoch}'=(SELECT epoch::text FROM public.lts_read_cache_epoch_v242 WHERE singleton=true)
 AND m.j#>>'{guard,card_source_key}'=lts_product_refresh_private_v415.card_source_key(p_user_id)
 AND m.j#>>'{guard,policy_fingerprint}'=md5(p_policy::text)
 AND jsonb_typeof(m.j->'payload')='object' AND m.j#>>'{payload,enabled}'='true'
 AND m.j->>'digest'=encode(sha256(convert_to((m.j->'payload')::text,'UTF8')),'hex')
$cache$;
