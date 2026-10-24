-- Generic previous function bodies for an isolated PostgreSQL fixture.
CREATE OR REPLACE FUNCTION public.lts_c6_completeness_state_v269(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE fingerprint text; epoch bigint; result jsonb; cycles jsonb;
BEGIN
 SELECT e.epoch INTO epoch FROM public.lts_read_cache_epoch_v242 e WHERE singleton=true;
 SELECT 'v269-c6-state:'||epoch||':'||md5(coalesce((SELECT string_agg(to_jsonb(s)::text,'' ORDER BY s.id)
 FROM public.lts_open_finance_staging s WHERE s.user_id=p_user_id AND s.institution_code='336'
 AND s.resource_type IN('credit_card','card_transaction','invoice')),'')||coalesce((SELECT string_agg(to_jsonb(i)::text,'' ORDER BY i.id)
 FROM public.card_invoices i WHERE i.user_id=p_user_id AND public.lts_card_family_v226(i.card_name,i.card_name)='c6'),'')||
 coalesce((SELECT string_agg(to_jsonb(d)::text,'' ORDER BY d.id) FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=p_user_id AND d.family='c6'),'')) INTO fingerprint;
 SELECT payload INTO result FROM public.lts_v229_read_cache WHERE user_id=p_user_id AND kind='card_completeness_v269'
 AND as_of=current_date AND from_date=current_date AND to_date=current_date AND source_fingerprint=fingerprint;
 IF FOUND THEN RETURN result; END IF;
 cycles:=public.lts_card_cycles_v226(p_user_id);
 result:=jsonb_build_object('complete',coalesce((cycles->>'complete')::boolean,true),'incomplete_families',coalesce(cycles->'incomplete_families','[]'::jsonb),'source_revision',fingerprint,'source_epoch',epoch);
 IF NOT current_setting('transaction_read_only')::boolean THEN
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
  VALUES(p_user_id,'card_completeness_v269',current_date,current_date,current_date,result,clock_timestamp(),fingerprint)
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
 END IF;
 RETURN result;
END $function$
;
CREATE OR REPLACE FUNCTION public.lts_v246_invalidate_finance_cache()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
END $function$
;
