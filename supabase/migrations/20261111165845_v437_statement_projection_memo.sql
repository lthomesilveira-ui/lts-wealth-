-- V437: reuse the exact projection only within one statement and input state.
-- No persistent memo, financial mutation, privilege, timeout, or schedule change.
DO $migration$
DECLARE target regprocedure:='lts_projection_private_v412.build(uuid,date)'::regprocedure;
 original text; candidate text; attributes jsonb;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc'
 INTO STRICT original,attributes FROM pg_proc p WHERE p.oid=target;
 IF md5(original)='9305b0e8f1195ced38fd39a3941162ea' THEN RETURN;END IF;
 IF md5(original)<>'c0002a050efc5fd139954ce034da99e1' THEN
  RAISE EXCEPTION 'V437 projection predecessor differs; review before applying';
 END IF;
 candidate:=original;
 candidate:=replace(candidate,$old0$DECLARE projection_result_v418 jsonb; worker_claim_v418 jsonb;$old0$,$new0$DECLARE projection_result_v418 jsonb; worker_claim_v418 jsonb;
 -- V437: transaction-local memo, valid only for this statement and input state.
 memo_key_v437 text; memo_v437 jsonb;
$new0$);
 candidate:=replace(candidate,$old1$ policy:=policy||jsonb_build_object('_history_reference',lts_projection_private_v412.reference_state(p_user_id));$old1$,$new1$ policy:=policy||jsonb_build_object('_history_reference',lts_projection_private_v412.reference_state(p_user_id));
 memo_key_v437:=encode(sha256(convert_to(jsonb_build_array(
  p_user_id,p_as_of,current_user,pg_backend_pid(),statement_timestamp(),
  pg_current_snapshot()::text,
  (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true),
  policy,lts_product_refresh_private_v415.card_source_key(p_user_id)
 )::text,'UTF8')),'hex');
 BEGIN
  memo_v437:=nullif(current_setting('lts.projection_memo_v437',true),'')::jsonb;
 EXCEPTION WHEN invalid_text_representation THEN memo_v437:=NULL;
 END;
 IF memo_v437->>'key'=memo_key_v437
  AND memo_v437->>'digest'=encode(sha256(convert_to((memo_v437->'payload')::text,'UTF8')),'hex')
  AND jsonb_typeof(memo_v437->'payload')='object' THEN
  projection_result_v418:=memo_v437->'payload';

 worker_claim_v418:=nullif(current_setting('lts.product_refresh_claim',true),'')::jsonb;
 IF worker_claim_v418->>'user_id'=p_user_id::text AND p_as_of=current_date THEN
  PERFORM set_config('lts.projection_summary_v418',jsonb_build_object(
   'user_id',p_user_id,'as_of',p_as_of,
   'summary',projection_result_v418-'events'-'replacement_refs')::text,true);
 END IF;
  RETURN projection_result_v418;
 END IF;
$new1$);
 candidate:=replace(candidate,$old2$ RETURN projection_result_v418;
END $function$$old2$,$new2$ PERFORM set_config('lts.projection_memo_v437',jsonb_build_object(
  'key',memo_key_v437,'payload',projection_result_v418,
  'digest',encode(sha256(convert_to(projection_result_v418::text,'UTF8')),'hex'))::text,true);
 RETURN projection_result_v418;
END $function$$new2$);
 EXECUTE candidate;
 IF attributes IS DISTINCT FROM (SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
  OR md5(pg_get_functiondef(target))<>'9305b0e8f1195ced38fd39a3941162ea' THEN
  RAISE EXCEPTION 'V437 projection attributes or definition changed unexpectedly';
 END IF;
END $migration$;
