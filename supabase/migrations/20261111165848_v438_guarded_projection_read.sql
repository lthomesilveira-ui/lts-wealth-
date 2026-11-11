-- V438: publish the already-calculated full projection with the existing guarded refresh.
-- Reuse only a current ready publication. No new job, financial write or access grant.
DO $migration$
DECLARE b regprocedure:='lts_projection_private_v412.build(uuid,date)'::regprocedure;
 w regprocedure:='lts_product_refresh_private_v415.run_claimed()'::regprocedure;
 original_build text;original_worker text;build_attributes jsonb;worker_attributes jsonb;candidate text;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO STRICT original_build,build_attributes FROM pg_proc p WHERE p.oid=b;
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO STRICT original_worker,worker_attributes FROM pg_proc p WHERE p.oid=w;
 IF md5(original_build)='35fc3700f845a94fdb4963e0a8d47007' AND md5(original_worker)='1a40c6d25b2a31928ee0725799c6c3be' THEN
  IF NOT (EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=to_regprocedure('lts_projection_private_v412.read_build_cache_v438(uuid,date,jsonb)')
 AND md5(p.prosrc)='403a73d810908efda5a34bb5febcde18' AND p.provolatile='s' AND NOT p.prosecdef
 AND p.proconfig=ARRAY['search_path=""','TimeZone=America/Sao_Paulo']::text[])
 AND NOT has_function_privilege('anon','lts_projection_private_v412.read_build_cache_v438(uuid,date,jsonb)','EXECUTE')
 AND NOT has_function_privilege('authenticated','lts_projection_private_v412.read_build_cache_v438(uuid,date,jsonb)','EXECUTE')) THEN RAISE EXCEPTION 'V438 private reader drift';END IF;
  RETURN;END IF;
 IF md5(original_build)<>'9305b0e8f1195ced38fd39a3941162ea' OR md5(original_worker)<>'3af6180b5941f78e5f5edfad9798562f' THEN
  RAISE EXCEPTION 'V438 predecessor differs; review before applying';
 END IF;
 IF to_regprocedure('lts_projection_private_v412.read_build_cache_v438(uuid,date,jsonb)') IS NOT NULL THEN
  RAISE EXCEPTION 'V438 cache reader already exists unexpectedly';END IF;
 EXECUTE $helper$CREATE OR REPLACE FUNCTION lts_projection_private_v412.read_build_cache_v438(p_user_id uuid,p_as_of date,p_policy jsonb)
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
$helper$;
 REVOKE ALL ON FUNCTION lts_projection_private_v412.read_build_cache_v438(uuid,date,jsonb) FROM PUBLIC,anon,authenticated;
 GRANT EXECUTE ON FUNCTION lts_projection_private_v412.read_build_cache_v438(uuid,date,jsonb) TO service_role;
 candidate:=original_build;
 candidate:=replace(candidate,$b0$ policy:=policy||jsonb_build_object('_history_reference',lts_projection_private_v412.reference_state(p_user_id));$b0$,$bc0$ policy:=policy||jsonb_build_object('_history_reference',lts_projection_private_v412.reference_state(p_user_id));
 projection_result_v418:=lts_projection_private_v412.read_build_cache_v438(p_user_id,p_as_of,policy);
 IF projection_result_v418 IS NOT NULL THEN

 worker_claim_v418:=nullif(current_setting('lts.product_refresh_claim',true),'')::jsonb;
 IF worker_claim_v418->>'user_id'=p_user_id::text AND p_as_of=current_date THEN
  PERFORM set_config('lts.projection_summary_v418',jsonb_build_object(
   'user_id',p_user_id,'as_of',p_as_of,
   'summary',projection_result_v418-'events'-'replacement_refs')::text,true);
 END IF;
  RETURN projection_result_v418;
 END IF;$bc0$);
 candidate:=replace(candidate,$b1$ PERFORM set_config('lts.projection_memo_v437',jsonb_build_object(
  'key',memo_key_v437,'payload',projection_result_v418,$b1$,$bc1$ PERFORM set_config('lts.projection_memo_v437',jsonb_build_object(
  'user_id',p_user_id,'as_of',p_as_of,
  'inputs',jsonb_build_object('source_epoch',(SELECT epoch::text FROM public.lts_read_cache_epoch_v242 WHERE singleton=true),
   'card_source_key',lts_product_refresh_private_v415.card_source_key(p_user_id),'policy_fingerprint',md5(policy::text)),
  'key',memo_key_v437,'payload',projection_result_v418,$bc1$);
 EXECUTE candidate;
 candidate:=original_worker;
 candidate:=replace(candidate,$w0$DECLARE projection_memo_v418 jsonb;$w0$,$wc0$DECLARE projection_full_v438 jsonb; projection_memo_v418 jsonb;$wc0$);
 candidate:=replace(candidate,$w1$  PERFORM set_config('lts.projection_summary_v418','',true);$w1$,$wc1$  PERFORM set_config('lts.projection_summary_v418','',true);
  PERFORM set_config('lts.projection_memo_v437','',true);$wc1$);
 candidate:=replace(candidate,$w2$   AND nullif(current_setting('lts.projection_summary_v418',true),'') IS NULL THEN$w2$,$wc2$   AND (nullif(current_setting('lts.projection_summary_v418',true),'') IS NULL
    OR nullif(current_setting('lts.projection_memo_v437',true),'') IS NULL) THEN$wc2$);
 candidate:=replace(candidate,$w3$   UPDATE public.lts_product_read_cache
    SET payload=jsonb_set(payload,'{projection_summary_v418}',projection_memo_v418,true)
    WHERE user_id=u;$w3$,$wc3$   projection_full_v438:=nullif(current_setting('lts.projection_memo_v437',true),'')::jsonb;
   IF projection_full_v438->>'user_id' IS DISTINCT FROM u::text
    OR projection_full_v438->>'as_of' IS DISTINCT FROM current_date::text
    OR projection_full_v438#>>'{inputs,source_epoch}' IS DISTINCT FROM final_epoch::text
    OR projection_full_v438#>>'{inputs,card_source_key}' IS DISTINCT FROM expected_card_revision
    OR projection_full_v438#>>'{inputs,policy_fingerprint}' IS DISTINCT FROM md5((
     lts_projection_private_v412.owner_policy(u)||jsonb_build_object('_history_reference',lts_projection_private_v412.reference_state(u)))::text)
    OR jsonb_typeof(projection_full_v438->'payload') IS DISTINCT FROM 'object'
    OR projection_memo_v418->'summary' IS DISTINCT FROM ((projection_full_v438->'payload')-'events'-'replacement_refs')
    OR projection_full_v438->>'digest' IS DISTINCT FROM encode(sha256(convert_to((projection_full_v438->'payload')::text,'UTF8')),'hex') THEN
    RAISE EXCEPTION USING ERRCODE='P0416',MESSAGE='Projection payload unavailable';
   END IF;
   projection_full_v438:=jsonb_build_object('user_id',u,'as_of',current_date,
    'payload',projection_full_v438->'payload','digest',projection_full_v438->>'digest',
    'guard',(projection_memo_v418->'guard')||jsonb_build_object('policy_fingerprint',projection_full_v438#>>'{inputs,policy_fingerprint}'));
   UPDATE public.lts_product_read_cache
    SET payload=jsonb_set(jsonb_set(payload,'{projection_summary_v418}',projection_memo_v418,true),
     '{projection_build_v438}',projection_full_v438,true)
    WHERE user_id=u;$wc3$);
 EXECUTE candidate;
 IF build_attributes IS DISTINCT FROM (SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=b)
  OR worker_attributes IS DISTINCT FROM (SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=w)
  OR md5(pg_get_functiondef(b))<>'35fc3700f845a94fdb4963e0a8d47007' OR md5(pg_get_functiondef(w))<>'1a40c6d25b2a31928ee0725799c6c3be' THEN
  RAISE EXCEPTION 'V438 attributes or definitions changed unexpectedly';END IF;
END $migration$;
