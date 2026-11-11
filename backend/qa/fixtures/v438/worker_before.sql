-- Exact reviewed worker; all test dependencies are synthetic.
CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.run_claimed()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE projection_memo_v418 jsonb; ctx jsonb; u uuid; token uuid; ver bigint; expected_epoch bigint; final_epoch bigint;
 q lts_product_refresh_private_v415.queue%ROWTYPE; c jsonb; result jsonb; card_state jsonb;
 error_code text; succeeded boolean:=false; retry_at timestamptz; expected_card_revision text;
BEGIN
 BEGIN
  ctx:=nullif(current_setting('lts.product_refresh_claim',true),'')::jsonb;
  u:=(ctx->>'user_id')::uuid;token:=(ctx->>'token')::uuid;
  ver:=(ctx->>'version')::bigint;expected_epoch:=(ctx->>'epoch')::bigint;
 EXCEPTION WHEN OTHERS THEN RETURN jsonb_build_object('ok',true,'skipped','no_claim'); END;
 IF u IS NULL OR token IS NULL OR ver IS NULL OR expected_epoch IS NULL THEN
  RETURN jsonb_build_object('ok',true,'skipped','no_claim');
 END IF;
 IF NOT pg_try_advisory_xact_lock(hashtextextended(u::text,415)) THEN
  RETURN jsonb_build_object('ok',true,'skipped','busy');
 END IF;
 SELECT * INTO q FROM lts_product_refresh_private_v415.queue WHERE user_id=u;
 IF NOT FOUND OR q.state<>'running' OR q.claim_token IS DISTINCT FROM token
  OR q.claimed_version IS DISTINCT FROM ver OR q.claimed_epoch IS DISTINCT FROM expected_epoch THEN
  RETURN jsonb_build_object('ok',true,'skipped','claim_changed');
 END IF;
 -- All derived cache writes are within this exception subtransaction. The
 -- queue row is not locked during calculation. A failed publication guard
 -- rolls back both v2 and v5, including their lower derived-cache writes.
 BEGIN
  IF NOT lts_product_refresh_private_v415.allowed_owner(u) THEN
   RAISE EXCEPTION USING ERRCODE='P0417',MESSAGE='Refresh access changed';
  END IF;
  IF q.request_version<>ver OR (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true)<>expected_epoch THEN
   RAISE EXCEPTION USING ERRCODE='P0415',MESSAGE='Refresh superseded';
  END IF;
  expected_card_revision:=lts_product_refresh_private_v415.card_source_key(u);
  PERFORM set_config('lts.projection_summary_v418','',true);
  IF q.invalidate_caches THEN
   DELETE FROM public.lts_flow_future_read_cache WHERE user_id=u;
   DELETE FROM public.lts_flow_future_read_cache_v2 WHERE user_id=u;
   DELETE FROM public.lts_v229_read_cache WHERE user_id=u;
   DELETE FROM public.lts_dashboard_cockpit_cache WHERE user_id=u;
  END IF;
  c:=lts_product_refresh_private_v415.cache_info(u);
  IF NOT coalesce((c->>'available')::boolean,false) THEN
   result:=public.lts_refresh_product_read_cache_v2(u);
   IF result->>'ok' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION USING ERRCODE='P0416',MESSAGE='Refresh contract invalid';
   END IF;
  END IF;
  -- Source-key v240 alone does not include every policy/documentary input.
  -- Force the existing complete operational refresh, never a partial payload.
  UPDATE public.lts_product_read_cache
   SET payload=(payload-'canonical_summary'-'product_refresh_pending_v415')#-'{updates,document_change_summary_version}'
   WHERE user_id=u;
  result:=public.lts_refresh_product_read_cache_operational_v5(u);
  IF result->>'ok' IS DISTINCT FROM 'true' THEN
   RAISE EXCEPTION USING ERRCODE='P0416',MESSAGE='Refresh contract invalid';
  END IF;
  IF lts_projection_private_v412.owner_policy(u) IS NOT NULL
   AND nullif(current_setting('lts.projection_summary_v418',true),'') IS NULL THEN
   -- Lower readers may have reused a valid flow without invoking the builder.
   -- Calculate this missing summary in the worker, before publication locks.
   PERFORM lts_projection_private_v412.build(u,current_date);
  END IF;
  -- Warm the existing completeness memo before declaring the browser ready.
  -- This function only writes the existing derived read-cache tables.
  card_state:=public.lts_c6_completeness_state_v269(u);
  IF jsonb_typeof(card_state->'complete') IS DISTINCT FROM 'boolean' THEN
   RAISE EXCEPTION USING ERRCODE='P0416',MESSAGE='Refresh contract invalid';
  END IF;
  UPDATE public.lts_product_read_cache SET payload=payload-'product_refresh_pending_v415'
   WHERE user_id=u;
  c:=lts_product_refresh_private_v415.cache_info(u);
  IF NOT coalesce((c->>'available')::boolean,false) OR NOT coalesce((c->>'current')::boolean,false) THEN
   RAISE EXCEPTION USING ERRCODE='P0416',MESSAGE='Refresh contract invalid';
  END IF;
  -- Protect publication, briefly, against a concurrent committed source epoch.
  SELECT epoch INTO final_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true FOR SHARE;
  IF final_epoch IS DISTINCT FROM expected_epoch
   OR card_state->>'source_revision' IS DISTINCT FROM expected_card_revision
   OR lts_product_refresh_private_v415.card_source_key(u) IS DISTINCT FROM expected_card_revision
   OR NOT lts_product_refresh_private_v415.allowed_owner(u) THEN
   RAISE EXCEPTION USING ERRCODE='P0415',MESSAGE='Refresh superseded';
  END IF;
  -- NOWAIT avoids lock inversion with an invalidator holding queue then epoch.
  SELECT * INTO q FROM lts_product_refresh_private_v415.queue WHERE user_id=u FOR UPDATE NOWAIT;
  IF q.request_version IS DISTINCT FROM ver OR q.claim_token IS DISTINCT FROM token OR q.state<>'running' THEN
   RAISE EXCEPTION USING ERRCODE='P0415',MESSAGE='Refresh superseded';
  END IF;
  -- Persist the summary already produced during this guarded refresh.
  -- The same publication subtransaction rolls it back on a superseded claim.
  IF lts_projection_private_v412.owner_policy(u) IS NOT NULL THEN
   projection_memo_v418:=nullif(current_setting('lts.projection_summary_v418',true),'')::jsonb;
   IF projection_memo_v418->>'user_id' IS DISTINCT FROM u::text
    OR projection_memo_v418->>'as_of' IS DISTINCT FROM current_date::text
    OR projection_memo_v418#>>'{summary,enabled}' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION USING ERRCODE='P0416',MESSAGE='Projection summary unavailable';
   END IF;
   projection_memo_v418:=projection_memo_v418||jsonb_build_object('guard',jsonb_build_object(
    'source_epoch',final_epoch::text,'card_source_key',expected_card_revision,
    'request_version',ver::text,
    'policy_sha256',(SELECT sha256 FROM public.legacy_namespace
     WHERE usuario_id=u AND chave='lts_owner_projection_policy_v412'),
    'reference_sha256',(SELECT sha256 FROM public.legacy_namespace
     WHERE usuario_id=u AND chave='lts_projection_reference_v412')));
   UPDATE public.lts_product_read_cache
    SET payload=jsonb_set(payload,'{projection_summary_v418}',projection_memo_v418,true)
    WHERE user_id=u;
  END IF;
  UPDATE lts_product_refresh_private_v415.queue SET state='ready',completed_version=ver,
   completed_at=clock_timestamp(),next_attempt_at=NULL,lease_expires_at=NULL,last_error_code=NULL,
   claim_token=NULL,claimed_version=NULL,claimed_epoch=NULL,invalidate_caches=false WHERE user_id=u;
  succeeded:=true;
 EXCEPTION
  WHEN query_canceled THEN error_code:='refresh_timed_out';
  WHEN lock_not_available OR deadlock_detected THEN error_code:='refresh_busy';
  WHEN SQLSTATE 'P0415' THEN error_code:='refresh_superseded';
  WHEN SQLSTATE 'P0416' THEN error_code:='refresh_contract_invalid';
  WHEN SQLSTATE 'P0417' THEN error_code:='refresh_access_changed';
  WHEN OTHERS THEN error_code:='refresh_failed';
 END;
 IF succeeded THEN
  PERFORM set_config('lts.product_refresh_claim','',false);
  RETURN jsonb_build_object('ok',true,'published',true);
 END IF;
 -- This runs after the subtransaction rollback. Preserve a newer requested
 -- version and its attempt budget; do not erase a replacement worker's claim.
 SELECT * INTO q FROM lts_product_refresh_private_v415.queue WHERE user_id=u FOR UPDATE;
 IF FOUND AND q.claim_token IS NOT DISTINCT FROM token THEN
  retry_at:=clock_timestamp()+CASE WHEN q.attempts<=1 THEN interval '30 seconds' ELSE interval '120 seconds' END;
  UPDATE lts_product_refresh_private_v415.queue SET
   state=CASE WHEN q.request_version<>ver THEN 'pending'
    WHEN q.attempts>=3 OR error_code='refresh_access_changed' THEN 'failed' ELSE 'pending' END,
   next_attempt_at=CASE WHEN q.request_version<>ver THEN clock_timestamp()
    WHEN q.attempts>=3 OR error_code='refresh_access_changed' THEN NULL ELSE retry_at END,
   last_error_code=CASE WHEN q.request_version<>ver THEN NULL ELSE error_code END,
   claim_token=NULL,claimed_version=NULL,claimed_epoch=NULL,lease_expires_at=NULL
   WHERE user_id=u;
 END IF;
 PERFORM set_config('lts.product_refresh_claim','',false);
 RETURN jsonb_build_object('ok',false,'published',false,'error_code',error_code);
END $function$;
