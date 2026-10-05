-- Derived finance cache invalidation. Health has its own read model.
-- Compare statement transition rows, preserving all source money, dates,
-- statuses, hashes, identity links and bank receipt timestamps.
CREATE OR REPLACE FUNCTION public.lts_v246_invalidate_finance_cache()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE changed boolean:=false; ignored text[]:=ARRAY[]::text[];
BEGIN
 IF TG_TABLE_SCHEMA='public' AND left(TG_TABLE_NAME,7)='health_' THEN RETURN NULL; END IF;
 IF TG_OP='TRUNCATE' THEN changed:=true;
 ELSIF TG_TABLE_NAME='lts_open_finance_observation' THEN
  IF TG_OP='INSERT' THEN
   SELECT EXISTS(SELECT 1 FROM new_rows n
    WHERE n.resource_type='balance' AND n.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
    AND NOT EXISTS(SELECT 1 FROM public.lts_open_finance_observation o
      WHERE o.user_id=n.user_id AND o.connection_id=n.connection_id AND o.resource_type='balance'
       AND o.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
       AND o.provider_record_id=n.provider_record_id AND o.raw_hash=n.raw_hash
       AND o.normalized_payload=n.normalized_payload AND o.raw_payload=n.raw_payload
       AND NOT EXISTS(SELECT 1 FROM new_rows inserted WHERE inserted.id=o.id))) INTO changed;
  ELSIF TG_OP='DELETE' THEN
   SELECT EXISTS(SELECT 1 FROM old_rows WHERE resource_type='balance' AND normalized_payload->>'account_type'='CHECKING_ACCOUNT') INTO changed;
  ELSE
   SELECT EXISTS(
    (SELECT to_jsonb(n)-ARRAY['sync_run_id','observed_at','ingest_action','reconciliation'] FROM new_rows n
      WHERE resource_type='balance' AND normalized_payload->>'account_type'='CHECKING_ACCOUNT'
     EXCEPT ALL
     SELECT to_jsonb(o)-ARRAY['sync_run_id','observed_at','ingest_action','reconciliation'] FROM old_rows o
      WHERE resource_type='balance' AND normalized_payload->>'account_type'='CHECKING_ACCOUNT')
    UNION ALL
    (SELECT to_jsonb(o)-ARRAY['sync_run_id','observed_at','ingest_action','reconciliation'] FROM old_rows o
      WHERE resource_type='balance' AND normalized_payload->>'account_type'='CHECKING_ACCOUNT'
     EXCEPT ALL
     SELECT to_jsonb(n)-ARRAY['sync_run_id','observed_at','ingest_action','reconciliation'] FROM new_rows n
      WHERE resource_type='balance' AND normalized_payload->>'account_type'='CHECKING_ACCOUNT')) INTO changed;
  END IF;
 ELSIF TG_OP='INSERT' THEN SELECT EXISTS(SELECT 1 FROM new_rows) INTO changed;
 ELSIF TG_OP='DELETE' THEN SELECT EXISTS(SELECT 1 FROM old_rows) INTO changed;
 ELSE
  IF TG_TABLE_NAME='lts_open_finance_staging' THEN ignored:=ARRAY['sync_run_id','last_seen_at','updated_at'];
  ELSIF TG_TABLE_NAME='lts_open_finance_connection' THEN ignored:=ARRAY['last_attempt_at','last_success_at','last_error_code','last_error_summary','updated_at']; END IF;
  SELECT EXISTS(
   (SELECT to_jsonb(n)-ignored FROM new_rows n EXCEPT ALL SELECT to_jsonb(o)-ignored FROM old_rows o)
   UNION ALL
   (SELECT to_jsonb(o)-ignored FROM old_rows o EXCEPT ALL SELECT to_jsonb(n)-ignored FROM new_rows n)) INTO changed;
 END IF;
 IF changed THEN
  UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
  DELETE FROM public.lts_v229_read_cache WHERE user_id IS NOT NULL;
 END IF;
 RETURN NULL;
END $fn$;
REVOKE ALL ON FUNCTION public.lts_v246_invalidate_finance_cache() FROM PUBLIC,anon,authenticated;

-- Keep the legacy trigger entry safe for subsequently created Health tables.
CREATE OR REPLACE FUNCTION public.lts_v229_invalidate_read_cache()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 IF TG_TABLE_SCHEMA='public' AND left(TG_TABLE_NAME,7)='health_' THEN RETURN NULL; END IF;
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
 DELETE FROM public.lts_v229_read_cache WHERE user_id IS NOT NULL;
 RETURN NULL;
END $fn$;

DO $migration$
DECLARE trigger_row record;
BEGIN
 FOR trigger_row IN SELECT c.relname,t.tgname FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
  WHERE c.relnamespace='public'::regnamespace AND NOT t.tgisinternal
  AND t.tgfoid='public.lts_v229_invalidate_read_cache()'::regprocedure
 LOOP
  EXECUTE format('DROP TRIGGER %I ON public.%I',trigger_row.tgname,trigger_row.relname);
  EXECUTE format('CREATE TRIGGER lts_v246_read_i AFTER INSERT ON public.%I REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache()',trigger_row.relname);
  EXECUTE format('CREATE TRIGGER lts_v246_read_u AFTER UPDATE ON public.%I REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache()',trigger_row.relname);
  EXECUTE format('CREATE TRIGGER lts_v246_read_d AFTER DELETE ON public.%I REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache()',trigger_row.relname);
  EXECUTE format('CREATE TRIGGER lts_v246_read_t AFTER TRUNCATE ON public.%I FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache()',trigger_row.relname);
 END LOOP;
END $migration$;
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
DELETE FROM public.lts_v229_read_cache WHERE user_id IS NOT NULL;
