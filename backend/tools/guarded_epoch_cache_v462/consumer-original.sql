CREATE OR REPLACE FUNCTION public.lts_c6_completeness_state_v269(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE previous_cache_lock_timeout text; fingerprint text; epoch bigint; result jsonb; cycles jsonb;
BEGIN
 SELECT e.epoch INTO epoch FROM public.lts_read_cache_epoch_v242 e WHERE singleton=true;
 -- Keep every semantic source field, including receipt and deletion evidence.
 -- Match V246: sync_run_id, last_seen_at and updated_at are bookkeeping only.
 -- Settlement links/contracts are also hashed because they have no epoch trigger.
 SELECT 'v307-card-state:'||epoch||':'||md5(
  coalesce((SELECT string_agg((to_jsonb(s)-ARRAY['sync_run_id','last_seen_at','updated_at'])::text,'' ORDER BY s.id)
   FROM public.lts_open_finance_staging s WHERE s.user_id=p_user_id),'')
  ||coalesce((SELECT string_agg(to_jsonb(i)::text,'' ORDER BY i.id)
   FROM public.card_invoices i WHERE i.user_id=p_user_id),'')
  ||coalesce((SELECT string_agg(to_jsonb(d)::text,'' ORDER BY d.id)
   FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=p_user_id),'')
  ||coalesce((SELECT string_agg(to_jsonb(l)::text,'' ORDER BY l.id)
   FROM public.lts_card_documentary_payment_link_v272 l WHERE l.user_id=p_user_id),'')
  ||coalesce((SELECT string_agg(to_jsonb(c)::text,'' ORDER BY c.payment_source_id)
   FROM public.lts_card_settlement_expense_contract_v273 c WHERE c.user_id=p_user_id),'')
 ) INTO fingerprint;
 SELECT payload INTO result FROM public.lts_v229_read_cache
 WHERE user_id=p_user_id AND kind='card_completeness_v269'
 AND as_of=current_date AND from_date=current_date AND to_date=current_date
 AND source_fingerprint=fingerprint;
 IF FOUND THEN RETURN result; END IF;
 cycles:=public.lts_card_cycles_v226(p_user_id);
 result:=jsonb_build_object('complete',coalesce((cycles->>'complete')::boolean,true),
  'incomplete_families',coalesce(cycles->'incomplete_families','[]'::jsonb),
  'source_revision',fingerprint,'source_epoch',epoch);
 IF epoch IS DISTINCT FROM(SELECT e.epoch FROM public.lts_read_cache_epoch_v242 e WHERE singleton=true) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
 END IF;
 IF NOT current_setting('transaction_read_only')::boolean THEN
  previous_cache_lock_timeout:=current_setting('lock_timeout');
  BEGIN
   -- Cache persistence is optional. Never wait behind a long reader's
   -- uncommitted cache write, and never increase an existing tighter limit.
   IF previous_cache_lock_timeout::interval=interval '0'
      OR previous_cache_lock_timeout::interval>interval '100 milliseconds' THEN
    PERFORM set_config('lock_timeout','100ms',true);
   END IF;
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
  VALUES(p_user_id,'card_completeness_v269',current_date,current_date,current_date,
   result,clock_timestamp(),fingerprint)
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET
   payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
  VALUES(p_user_id,'card_cycles_snapshot_v307',current_date,current_date,current_date,
   cycles,clock_timestamp(),fingerprint)
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET
   payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
   PERFORM set_config('lock_timeout',previous_cache_lock_timeout,true);
  EXCEPTION WHEN lock_not_available OR read_only_sql_transaction THEN
   -- The subtransaction rolls back both cache writes and the local timeout.
   -- Return the same computed result; source freshness checks stay mandatory.
   NULL;
  END;

 END IF;
 RETURN result;
END $function$;
