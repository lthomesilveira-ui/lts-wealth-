-- Return the existing supported not-ready state; never a false empty result.
BEGIN;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='10s';
DO $patch$
DECLARE target regprocedure:='lts_product_refresh_private_v415.expense_review_pending_v450(uuid,date,date)'::regprocedure; d text; attrs jsonb;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='2d41fa5eab16fe79d727c184de79021d' THEN
  IF (length(d)-length(replace(d,$needle$ source_guard:=lts_product_refresh_private_v415.review_guard_v450(p_user_id);$needle$,'')))/length($needle$ source_guard:=lts_product_refresh_private_v415.review_guard_v450(p_user_id);$needle$)<>1
  THEN RAISE EXCEPTION 'V457_REVIEW_READ_SHAPE_CHANGED'; END IF;
  EXECUTE replace(d,$needle$ source_guard:=lts_product_refresh_private_v415.review_guard_v450(p_user_id);$needle$,$replacement$ -- The worker also reads this queue before publication through an indirect caller.
 -- Only its exact current private claim may retain that original running path.
 -- Do not compete with that worker or certify an old/empty review meanwhile.
 IF EXISTS(SELECT 1 FROM lts_product_refresh_private_v415.queue q
  CROSS JOIN LATERAL(SELECT nullif(current_setting('lts.product_refresh_claim',true),'')::jsonb ctx) claim
  WHERE q.user_id=p_user_id AND q.state IN('pending','running')
  AND q.request_version>q.completed_version
  AND NOT coalesce(q.state='running' AND q.claim_token IS NOT NULL
   AND claim.ctx->>'user_id'=p_user_id::text AND claim.ctx->>'token'=q.claim_token::text
   AND claim.ctx->>'version'=q.claimed_version::text AND claim.ctx->>'epoch'=q.claimed_epoch::text,false)) THEN
  RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='Expense review is waiting for the existing product refresh';
 END IF;
 source_guard:=lts_product_refresh_private_v415.review_guard_v450(p_user_id);$replacement$);
 ELSIF md5(d)<>'3099bb8354d02fd9341ac7906e3efaa4' THEN RAISE EXCEPTION 'V457_PREDECESSOR_CHANGED'; END IF;
 IF md5(pg_get_functiondef(target))<>'3099bb8354d02fd9341ac7906e3efaa4'
 OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V457_FUNCTION_CONTRACT_CHANGED'; END IF;
END $patch$;
COMMIT;
