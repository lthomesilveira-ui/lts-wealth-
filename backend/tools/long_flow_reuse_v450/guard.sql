CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.long_flow_guard_v450(p_user_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE profile jsonb; item jsonb; actual text; source_epoch bigint; key_value text; program_key text;
BEGIN
 profile:=lts_product_refresh_private_v415.review_profile_v450();
 IF jsonb_typeof(profile->'producers') IS DISTINCT FROM 'array'
  OR jsonb_typeof(profile->'views') IS DISTINCT FROM 'array'
  OR jsonb_typeof(profile->'epoch_tables') IS DISTINCT FROM 'array' THEN RETURN NULL; END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'producers') LOOP
  SELECT md5(pg_get_functiondef(to_regprocedure(item->>'signature'))) INTO actual;
  IF actual IS DISTINCT FROM item->>'md5' THEN RETURN NULL; END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'views') LOOP
  SELECT md5(pg_get_viewdef(to_regclass(item->>'signature'),true)) INTO actual;
  IF actual IS DISTINCT FROM item->>'md5' THEN RETURN NULL; END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'epoch_tables') LOOP
  SELECT md5(string_agg(tgname::text||tgenabled::text||pg_get_triggerdef(oid),'|' ORDER BY tgname)) INTO actual
   FROM pg_trigger WHERE tgrelid=to_regclass(item->>'signature') AND NOT tgisinternal;
  IF actual IS DISTINCT FROM item->>'md5' THEN RETURN NULL; END IF;
 END LOOP;
 SELECT epoch INTO source_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 key_value:=public.lts_flow_read_source_key_v247(p_user_id);
 -- Include all LTS program definitions, including the long-flow engine's
 -- transitive callees. A code change never reuses a previous engine result.
 SELECT md5(string_agg(p.oid::regprocedure::text||md5(pg_get_functiondef(p.oid)),'|' ORDER BY p.oid::regprocedure::text))
  INTO program_key FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE p.prokind IN('f','p') AND ((n.nspname='public' AND p.proname LIKE 'lts_%') OR n.nspname LIKE 'lts_%');
 IF source_epoch IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Long flow sources changed during read';
 END IF;
 RETURN 'long-flow-v450:'||source_epoch||':'||key_value||':'||program_key||':'||md5(profile::text);
END
$function$
