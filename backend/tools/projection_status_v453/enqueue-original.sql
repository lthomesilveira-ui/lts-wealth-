CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.enqueue(p_user_id uuid, p_reason text, p_force boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE q lts_product_refresh_private_v415.queue%ROWTYPE; t timestamptz:=clock_timestamp(); inserted boolean;
BEGIN
 IF NOT lts_product_refresh_private_v415.allowed_owner(p_user_id) THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Not authorized';
 END IF;
 INSERT INTO lts_product_refresh_private_v415.queue(user_id,state,reason,next_attempt_at,invalidate_caches)
 VALUES(p_user_id,'pending',CASE WHEN p_reason IN ('manual','daily','source_change') THEN p_reason ELSE 'cache_read' END,t,
  p_reason='source_change') ON CONFLICT(user_id) DO NOTHING RETURNING true INTO inserted;
 IF coalesce(inserted,false) THEN RETURN lts_product_refresh_private_v415.status(p_user_id); END IF;
 SELECT * INTO q FROM lts_product_refresh_private_v415.queue WHERE user_id=p_user_id FOR UPDATE;
 IF p_force OR q.state='ready' OR (q.state='failed' AND p_reason='manual') THEN
  UPDATE lts_product_refresh_private_v415.queue SET
   request_version=request_version+1,
   state=CASE WHEN q.state='running' THEN 'running' ELSE 'pending' END,
   reason=CASE WHEN p_reason IN ('manual','daily','source_change') THEN p_reason ELSE 'cache_read' END,
   attempts=0,requested_at=t,next_attempt_at=t,last_error_code=NULL,
   invalidate_caches=invalidate_caches OR p_reason='source_change',
   claim_token=CASE WHEN q.state='running' THEN claim_token ELSE NULL END,
   claimed_version=CASE WHEN q.state='running' THEN claimed_version ELSE NULL END,
   claimed_epoch=CASE WHEN q.state='running' THEN claimed_epoch ELSE NULL END,
   lease_expires_at=CASE WHEN q.state='running' THEN lease_expires_at ELSE NULL END
   WHERE user_id=p_user_id;
 END IF;
 RETURN lts_product_refresh_private_v415.status(p_user_id);
END $function$
