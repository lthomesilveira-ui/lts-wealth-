CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.review_guard_v450(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE profile jsonb:=lts_product_refresh_private_v415.review_profile_v450(); item jsonb; actual text; primary_hashes jsonb:='{}'; rel regclass; owner_column text; reuse boolean:=false; cache_hit boolean:=false; input_revision bigint; input_epoch bigint; found_hashes jsonb; old_lock text;
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
 -- Reuse only exact full-row hashes, under a pinned producer profile and a
 -- complete statement-trigger/schema contract. All original checks above run.
 IF current_user='postgres' AND md5(profile::text)='3344fae485b34b6cf29a939801ab492e' AND EXISTS(
  SELECT 1 FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang
  WHERE p.oid=to_regprocedure('lts_product_refresh_private_v415.review_input_contract_ok_v465(jsonb)')
  AND md5(p.prosrc)='3dc2fac111a28c643aa3d38511bda88c' AND NOT p.prosecdef AND p.provolatile='s'
  AND pg_get_userbyid(p.proowner)='postgres' AND l.lanname='plpgsql'
  AND p.proconfig=ARRAY['search_path=""']::text[]) THEN
  reuse:=lts_product_refresh_private_v415.review_input_contract_ok_v465(profile);
 END IF;
 IF reuse THEN
  SELECT revision INTO input_revision FROM lts_product_refresh_private_v415.review_input_epoch_v465 WHERE singleton;
  SELECT epoch INTO input_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton;
  SELECT c.hashes INTO found_hashes FROM lts_product_refresh_private_v415.review_input_hash_cache_v465 c
   WHERE c.user_id=p_user_id AND c.source_revision=input_revision AND c.financial_epoch=input_epoch
   AND c.as_of=current_date AND c.profile_hash=md5(profile::text)
   AND jsonb_typeof(c.hashes)='object' AND c.digest=md5(c.hashes::text);
  IF FOUND AND (SELECT count(*) FROM jsonb_object_keys(found_hashes))=jsonb_array_length(profile->'tables')
   AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(profile->'tables') x
    WHERE NOT coalesce((found_hashes->>(x->>'schema'||'.'||(x->>'name'))) ~ '^[0-9a-f]{32}$',false)) THEN
   primary_hashes:=found_hashes;cache_hit:=true;
  END IF;
 END IF;
 IF NOT cache_hit THEN
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'tables') LOOP
  -- Relations and owner-column names come only from the pinned private profile.
  rel:=to_regclass(format('%I.%I',item->>'schema',item->>'name'));owner_column:=item->>'owner';
  IF rel IS NULL THEN RETURN NULL;END IF;
  EXECUTE format('WITH row_hashes AS MATERIALIZED (SELECT md5(to_jsonb(s)::text) h FROM %s s%s) SELECT md5(coalesce(string_agg(h,'''' ORDER BY h),'''')) FROM row_hashes',
   rel,CASE WHEN owner_column IS NULL THEN '' ELSE format(' WHERE %I=$1',owner_column) END) INTO actual USING p_user_id;
  primary_hashes:=primary_hashes||jsonb_build_object(item->>'schema'||'.'||(item->>'name'),actual);
 END LOOP;
  IF reuse AND NOT current_setting('transaction_read_only')::boolean
   AND input_revision=(SELECT revision FROM lts_product_refresh_private_v415.review_input_epoch_v465 WHERE singleton)
   AND input_epoch=(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton) THEN
   old_lock:=current_setting('lock_timeout');
   BEGIN
    IF old_lock::interval=interval '0' OR old_lock::interval>interval '100 milliseconds' THEN PERFORM set_config('lock_timeout','100ms',true);END IF;
    INSERT INTO lts_product_refresh_private_v415.review_input_hash_cache_v465(user_id,source_revision,financial_epoch,as_of,profile_hash,hashes,digest)
    VALUES(p_user_id,input_revision,input_epoch,current_date,md5(profile::text),primary_hashes,md5(primary_hashes::text))
    ON CONFLICT(user_id) DO UPDATE SET source_revision=excluded.source_revision,financial_epoch=excluded.financial_epoch,
     as_of=excluded.as_of,profile_hash=excluded.profile_hash,hashes=excluded.hashes,digest=excluded.digest;
    PERFORM set_config('lock_timeout',old_lock,true);
   EXCEPTION WHEN lock_not_available OR read_only_sql_transaction THEN NULL;END;
  END IF;
 END IF;
 IF cache_hit AND (input_revision IS DISTINCT FROM (SELECT revision FROM lts_product_refresh_private_v415.review_input_epoch_v465 WHERE singleton)
  OR input_epoch IS DISTINCT FROM(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Review sources changed during read';
 END IF;
 RETURN jsonb_build_object('owner',p_user_id,'as_of',current_date,
  'epoch',(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true),
  'card_source_key',lts_product_refresh_private_v415.card_source_key(p_user_id),'primary_hashes',primary_hashes,'profile',md5(profile::text));
END $function$
