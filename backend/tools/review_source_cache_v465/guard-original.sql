CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.review_guard_v450(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE profile jsonb:=lts_product_refresh_private_v415.review_profile_v450(); item jsonb; actual text; primary_hashes jsonb:='{}'; rel regclass; owner_column text;
BEGIN
 -- Unknown producer, view or invalidation rules disable reuse, including new
 -- dependencies. They never convert unavailable information into an empty list.
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'producers') LOOP
  SELECT md5(pg_get_functiondef(to_regprocedure(item->>'signature'))) INTO actual;
  IF actual IS DISTINCT FROM item->>'md5' THEN RETURN NULL;END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'views') LOOP
  SELECT md5(pg_get_viewdef(to_regclass(item->>'signature'),true)) INTO actual;
  IF actual IS DISTINCT FROM item->>'md5' THEN RETURN NULL;END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'epoch_tables') LOOP
  SELECT md5(string_agg(t.tgname::text||t.tgenabled::text||pg_get_triggerdef(t.oid),'|' ORDER BY t.tgname)) INTO actual
   FROM pg_trigger t WHERE t.tgrelid=to_regclass(item->>'signature') AND NOT t.tgisinternal;
  IF actual IS DISTINCT FROM item->>'md5' THEN RETURN NULL;END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'tables') LOOP
  -- Relations and owner-column names come only from the pinned private profile.
  rel:=to_regclass(format('%I.%I',item->>'schema',item->>'name'));owner_column:=item->>'owner';
  IF rel IS NULL THEN RETURN NULL;END IF;
  EXECUTE format('WITH row_hashes AS MATERIALIZED (SELECT md5(to_jsonb(s)::text) h FROM %s s%s) SELECT md5(coalesce(string_agg(h,'''' ORDER BY h),'''')) FROM row_hashes',
   rel,CASE WHEN owner_column IS NULL THEN '' ELSE format(' WHERE %I=$1',owner_column) END) INTO actual USING p_user_id;
  primary_hashes:=primary_hashes||jsonb_build_object(item->>'schema'||'.'||(item->>'name'),actual);
 END LOOP;
 RETURN jsonb_build_object('owner',p_user_id,'as_of',current_date,
  'epoch',(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true),
  'card_source_key',lts_product_refresh_private_v415.card_source_key(p_user_id),'primary_hashes',primary_hashes,'profile',md5(profile::text));
END $function$
