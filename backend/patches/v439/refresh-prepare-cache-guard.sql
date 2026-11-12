DO $guard$ BEGIN
 IF md5(pg_get_functiondef('lts_product_refresh_private_v415.prepare(boolean)'::regprocedure)) <> 'a90dca638ebf95943ce5606f4922843b' THEN
 RAISE EXCEPTION 'prepare definition changed; review required'; END IF;
END $guard$;
CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.prepare(p_daily boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid; q lts_product_refresh_private_v415.queue%ROWTYPE; c jsonb;
 token uuid; epoch_now bigint; t timestamptz:=clock_timestamp();
BEGIN
 PERFORM set_config('lts.product_refresh_claim','',false);
 FOR u IN SELECT a.id FROM auth.users a
  WHERE lts_product_refresh_private_v415.allowed_owner(a.id) ORDER BY a.id LOOP
  c:=lts_product_refresh_private_v415.cache_info(u);
  -- Card completeness alone does not prove full projection freshness.
  -- Running workers intentionally publish their guarded payload last.
  IF p_daily OR NOT coalesce((c->>'current')::boolean,false)
   OR (EXISTS(SELECT 1 FROM lts_product_refresh_private_v415.queue z
       WHERE z.user_id=u AND z.state='ready')
    AND lts_projection_private_v412.owner_policy(u) IS NOT NULL
    AND lts_projection_private_v412.read_build_cache_v438(u,current_date,
     lts_projection_private_v412.owner_policy(u)||jsonb_build_object(
      '_history_reference',lts_projection_private_v412.reference_state(u))) IS NULL) THEN
   PERFORM lts_product_refresh_private_v415.enqueue(u,CASE WHEN p_daily THEN 'daily' ELSE 'cache_read' END,false);
  END IF;
 END LOOP;
 FOR q IN SELECT * FROM lts_product_refresh_private_v415.queue
  WHERE (state='pending' AND coalesce(next_attempt_at,t)<=t)
     OR (state='running' AND lease_expires_at<t)
  ORDER BY requested_at,user_id LOOP
  IF NOT pg_try_advisory_xact_lock(hashtextextended(q.user_id::text,415)) THEN CONTINUE; END IF;
  -- Re-read under a short lock; SKIP LOCKED keeps scheduler preparation bounded.
  SELECT * INTO q FROM lts_product_refresh_private_v415.queue x
   WHERE x.user_id=q.user_id AND
    ((x.state='pending' AND coalesce(x.next_attempt_at,t)<=t)
     OR (x.state='running' AND x.lease_expires_at<t)) FOR UPDATE SKIP LOCKED;
  IF NOT FOUND THEN CONTINUE; END IF;
  IF NOT lts_product_refresh_private_v415.allowed_owner(q.user_id) THEN
   UPDATE lts_product_refresh_private_v415.queue SET state='failed',last_error_code='refresh_access_changed',
    claim_token=NULL,lease_expires_at=NULL,next_attempt_at=NULL WHERE user_id=q.user_id;
   CONTINUE;
  END IF;
  IF q.attempts>=3 THEN
   UPDATE lts_product_refresh_private_v415.queue SET state='failed',last_error_code='refresh_timed_out',
    claim_token=NULL,lease_expires_at=NULL,next_attempt_at=NULL WHERE user_id=q.user_id;
   CONTINUE;
  END IF;
  SELECT epoch INTO epoch_now FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
  IF epoch_now IS NULL THEN RAISE EXCEPTION 'Missing source epoch'; END IF;
  token:=gen_random_uuid();
  UPDATE lts_product_refresh_private_v415.queue SET state='running',attempts=attempts+1,
   started_at=t,next_attempt_at=NULL,lease_expires_at=t+interval '12 minutes',
   last_error_code=NULL,claim_token=token,claimed_version=request_version,claimed_epoch=epoch_now
   WHERE user_id=q.user_id;
  PERFORM set_config('lts.product_refresh_claim',jsonb_build_object('user_id',q.user_id,'token',token,
   'version',q.request_version::text,'epoch',epoch_now::text)::text,false);
  RETURN jsonb_build_object('ok',true,'claimed',true);
 END LOOP;
 RETURN jsonb_build_object('ok',true,'claimed',false);
END $function$

