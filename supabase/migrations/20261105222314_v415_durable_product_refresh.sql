-- V415: derived-cache maintenance only. No source financial writes.
BEGIN;
SET LOCAL lock_timeout='3s';
SET LOCAL statement_timeout='30s';

CREATE TEMP TABLE v415_predecessor_metadata ON COMMIT DROP AS
SELECT p.oid,p.oid::regprocedure::text AS signature,p.proowner,p.provolatile,p.prosecdef,p.proconfig,p.proacl
FROM pg_proc p WHERE p.oid IN (
 'lts_projection_private_v412.invalidate_reads(uuid)'::regprocedure,
 'lts_projection_private_v412.refresh()'::regprocedure,
 'public.lts_browser_product_v1()'::regprocedure);

DO $guard$
DECLARE r record; actual text;
BEGIN
 IF to_regnamespace('lts_product_refresh_private_v415') IS NOT NULL THEN
  RAISE EXCEPTION 'V415 namespace already exists';
 END IF;
 FOR r IN SELECT * FROM (VALUES
  ('lts_projection_private_v412.invalidate_reads(uuid)','1f7467d92ff89ddc37a4e501088ebbaa'),
  ('lts_projection_private_v412.refresh()','2082f8834d179cb0cca0a431b3071ee1'),
  ('public.lts_browser_product_v1()','cfd7d1aa8d5a2fa0b26a5926d21d7d5e'),
  ('public.lts_product_read_cached_v1(uuid)','5c6a41497cdd810ee95a6df7a7dae8bb'),
  ('public.lts_recurring_maintenance_v366()','07d6c08ee1044ff79e2243cd78cf23db'),
  ('public.lts_refresh_product_read_cache_operational_v5(uuid)','1ec84b14b102731d33003f51fdb30e37'),
  ('public.lts_refresh_product_read_cache_v2(uuid)','b9bac9fc5c20cdacaa5acb102f8eaefb'),
  ('public.lts_c6_completeness_state_v269(uuid)','b987868460604430e0fd3c15cb22a9a0'),
  ('public.lts_has_card_presentation_v269()','5da1925e44cc8f3888130146e0256d76'),
  ('public.lts_product_card_completeness_v269(jsonb,jsonb)','549ba955fe3388dec25584f41b85a534')
 ) AS e(signature,expected_md5) LOOP
  SELECT md5(pg_get_functiondef(to_regprocedure(r.signature))) INTO actual;
  IF actual IS DISTINCT FROM r.expected_md5 THEN RAISE EXCEPTION 'Unexpected V415 predecessor: %',r.signature; END IF;
 END LOOP;
END $guard$;

CREATE SCHEMA lts_product_refresh_private_v415 AUTHORIZATION postgres;
REVOKE ALL ON SCHEMA lts_product_refresh_private_v415 FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA lts_product_refresh_private_v415 TO service_role;

CREATE TABLE lts_product_refresh_private_v415.queue (
 user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 request_version bigint NOT NULL DEFAULT 1 CHECK(request_version>0),
 completed_version bigint NOT NULL DEFAULT 0 CHECK(completed_version>=0 AND completed_version<=request_version),
 state text NOT NULL CHECK(state IN ('pending','running','ready','failed')),
 reason text NOT NULL,
 attempts integer NOT NULL DEFAULT 0 CHECK(attempts BETWEEN 0 AND 3),
 requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 started_at timestamptz,
 completed_at timestamptz,
 next_attempt_at timestamptz,
 lease_expires_at timestamptz,
 last_error_code text CHECK(last_error_code IS NULL OR last_error_code IN
  ('refresh_failed','refresh_timed_out','refresh_busy','refresh_superseded','refresh_access_changed','refresh_contract_invalid')),
 claim_token uuid,
 claimed_version bigint,
 claimed_epoch bigint,
 invalidate_caches boolean NOT NULL DEFAULT false
);
ALTER TABLE lts_product_refresh_private_v415.queue ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON lts_product_refresh_private_v415.queue FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON lts_product_refresh_private_v415.queue TO service_role;

CREATE FUNCTION lts_product_refresh_private_v415.allowed_owner(p_user_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 SELECT EXISTS(SELECT 1 FROM auth.users u
  WHERE u.id=p_user_id AND u.deleted_at IS NULL
   AND (u.banned_until IS NULL OR u.banned_until<=now())
   AND NOT coalesce(u.is_anonymous,false)
   AND EXISTS(SELECT 1 FROM public.lts_allowed_users a
    WHERE a.active=true AND lower(a.email)=lower(u.email)))
$f$;

CREATE FUNCTION lts_product_refresh_private_v415.compatible(p_version text,p_payload jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT coalesce(p_version='lts-product-fix86-v36'
  AND jsonb_typeof(p_payload)='object'
  AND p_payload->>'version'='lts-product-fix86-v36'
  AND jsonb_typeof(p_payload->'dashboard')='object'
  AND jsonb_typeof(p_payload->'flow')='object'
  AND jsonb_typeof(p_payload->'expenses')='object'
  AND jsonb_typeof(p_payload->'wealth')='object'
  AND jsonb_typeof(p_payload->'product_contract')='object'
  AND p_payload ?& ARRAY['version','navigation','dashboard','flow','expenses','wealth','commitments',
   'input','planning','planning_ladder','planning_executive','wealth_executive','product_contract',
   'updates','card_operating','documentary_commitments','card_instruments','commitment_schedules',
   'card_classification_review','semantic_review']
  AND CASE WHEN jsonb_typeof(p_payload->'navigation')='array'
   THEN jsonb_array_length(p_payload->'navigation')>0 ELSE false END,false)
$f$;

-- The guarded V307 fingerprint includes source fields without epoch triggers.
CREATE FUNCTION lts_product_refresh_private_v415.card_source_key(p_user_id uuid)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
SET "TimeZone"='America/Sao_Paulo' AS $f$
DECLARE fingerprint text; epoch bigint;
BEGIN
 SELECT e.epoch INTO epoch FROM public.lts_read_cache_epoch_v242 e WHERE singleton=true;
 -- Financial inputs in every bank are guarded by the existing epoch triggers.
 -- Include receipt-only fields explicitly: V246 deliberately ignores these.
 -- Settlement links/contracts are also hashed because they have no epoch trigger.
 SELECT 'v307-card-state:'||epoch||':'||md5(
  coalesce((SELECT string_agg(jsonb_build_array(s.id,s.sync_run_id,s.last_seen_at,s.updated_at)::text,'' ORDER BY s.id)
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

 RETURN fingerprint;
END $f$;

-- Read-only memo lookup. A miss is NULL, never a cold cycles calculation.
CREATE FUNCTION lts_product_refresh_private_v415.card_state_cached(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
SET "TimeZone"='America/Sao_Paulo' AS $f$
DECLARE fingerprint text; epoch bigint; result jsonb;
BEGIN
 SELECT e.epoch INTO epoch FROM public.lts_read_cache_epoch_v242 e WHERE singleton=true;
 fingerprint:=lts_product_refresh_private_v415.card_source_key(p_user_id);
 SELECT payload INTO result FROM public.lts_v229_read_cache
 WHERE user_id=p_user_id AND kind='card_completeness_v269'
 AND as_of=current_date AND from_date=current_date AND to_date=current_date
 AND source_fingerprint=fingerprint;
 IF FOUND AND jsonb_typeof(result->'complete')='boolean'
  AND result->>'source_revision'=fingerprint AND result->>'source_epoch'=epoch::text THEN RETURN result; END IF;
 RETURN NULL;
END $f$;

CREATE FUNCTION lts_product_refresh_private_v415.cache_info(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
SET "TimeZone"='America/Sao_Paulo' AS $f$
 SELECT coalesce((SELECT jsonb_build_object(
  'available',lts_product_refresh_private_v415.compatible(c.payload_version,c.payload),
  'current',lts_product_refresh_private_v415.compatible(c.payload_version,c.payload)
   AND c.payload#>>'{canonical_summary,as_of}'=current_date::text
   AND c.payload#>>'{updates,freshness,today}'=current_date::text
   AND c.payload#>>'{updates,document_change_summary_version}'='document-change-summary-v1'
   AND CASE WHEN jsonb_typeof(c.payload#>'{flow,days}')='array' THEN EXISTS(
    SELECT 1 FROM jsonb_array_elements(c.payload#>'{flow,days}') d WHERE d->>'date'=current_date::text) ELSE false END
   AND NOT coalesce(c.payload->'product_refresh_pending_v415'='true'::jsonb,false)
   AND lts_product_refresh_private_v415.card_state_cached(p_user_id) IS NOT NULL,
  'refreshed_at',c.refreshed_at) FROM public.lts_product_read_cache c WHERE c.user_id=p_user_id),
  jsonb_build_object('available',false,'current',false,'refreshed_at',NULL))
$f$;

CREATE FUNCTION lts_product_refresh_private_v415.status(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
SET "TimeZone"='America/Sao_Paulo' AS $f$
DECLARE q lts_product_refresh_private_v415.queue%ROWTYPE; c jsonb; s text; need boolean;
BEGIN
 c:=lts_product_refresh_private_v415.cache_info(p_user_id);
 SELECT * INTO q FROM lts_product_refresh_private_v415.queue WHERE user_id=p_user_id;
 need:=NOT coalesce((c->>'current')::boolean,false)
  OR coalesce(q.completed_version<q.request_version,false)
  OR coalesce(q.state IN ('pending','running','failed'),false);
 s:=CASE WHEN NOT need THEN 'ready' WHEN q.state IN ('pending','running','failed') THEN q.state ELSE 'pending' END;
 RETURN jsonb_build_object('state',s,'required',need,
  'cached_available',coalesce((c->>'available')::boolean,false),
  'request_version',coalesce(q.request_version,0)::text,'completed_version',coalesce(q.completed_version,0)::text,
  'attempts',coalesce(q.attempts,0),'requested_at',q.requested_at,'started_at',q.started_at,
  'completed_at',q.completed_at,'next_attempt_at',q.next_attempt_at,'error_code',q.last_error_code,
  'cached_refreshed_at',c->'refreshed_at','server_today',current_date);
END $f$;

CREATE FUNCTION lts_product_refresh_private_v415.enqueue(p_user_id uuid,p_reason text,p_force boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
SET "TimeZone"='America/Sao_Paulo' AS $f$
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
END $f$;

CREATE FUNCTION public.lts_browser_product_refresh_status_v415()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
SET "TimeZone"='America/Sao_Paulo' AS $f$
DECLARE u uuid:=public.lts_browser_assert_user_v1();
BEGIN
 RETURN jsonb_build_object('ok',true,'refresh',lts_product_refresh_private_v415.status(u));
END $f$;

CREATE FUNCTION public.lts_browser_product_refresh_request_v415()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
SET "TimeZone"='America/Sao_Paulo' AS $f$
DECLARE u uuid:=public.lts_browser_assert_user_v1();
BEGIN
 RETURN jsonb_build_object('ok',true,'refresh',lts_product_refresh_private_v415.enqueue(u,'manual',false));
END $f$;

-- Phase 1 commits the claim before expensive work. Queue readers/writers never
-- wait for the calculation, and a killed worker cannot erase its attempt count.
CREATE FUNCTION lts_product_refresh_private_v415.prepare(p_daily boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
SET "TimeZone"='America/Sao_Paulo' AS $f$
DECLARE u uuid; q lts_product_refresh_private_v415.queue%ROWTYPE; c jsonb;
 token uuid; epoch_now bigint; t timestamptz:=clock_timestamp();
BEGIN
 PERFORM set_config('lts.product_refresh_claim','',false);
 FOR u IN SELECT a.id FROM auth.users a
  WHERE lts_product_refresh_private_v415.allowed_owner(a.id) ORDER BY a.id LOOP
  c:=lts_product_refresh_private_v415.cache_info(u);
  IF p_daily OR NOT coalesce((c->>'current')::boolean,false) THEN
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
END $f$;

CREATE FUNCTION lts_product_refresh_private_v415.run_claimed()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
SET "TimeZone"='America/Sao_Paulo' AS $f$
DECLARE ctx jsonb; u uuid; token uuid; ver bigint; expected_epoch bigint; final_epoch bigint;
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
END $f$;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.invalidate_reads(p_user_id uuid)
RETURNS void LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN
 IF p_user_id IS NULL THEN RAISE EXCEPTION 'Invalid projection owner';END IF;
 -- Supersede first; a running worker must discard its entire calculation.
 PERFORM lts_product_refresh_private_v415.enqueue(p_user_id,'source_change',true);
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
 IF pg_try_advisory_xact_lock(hashtextextended(p_user_id::text,415)) THEN
  BEGIN
   -- Lock probes fail immediately. They never wait behind an unrelated cache
   -- writer; all deletions then happen together, or are deferred together.
   PERFORM 1 FROM public.lts_flow_future_read_cache WHERE user_id=p_user_id FOR UPDATE NOWAIT;
   PERFORM 1 FROM public.lts_flow_future_read_cache_v2 WHERE user_id=p_user_id FOR UPDATE NOWAIT;
   PERFORM 1 FROM public.lts_v229_read_cache WHERE user_id=p_user_id FOR UPDATE NOWAIT;
   PERFORM 1 FROM public.lts_dashboard_cockpit_cache WHERE user_id=p_user_id FOR UPDATE NOWAIT;
   PERFORM 1 FROM public.lts_product_read_cache WHERE user_id=p_user_id FOR UPDATE NOWAIT;
   DELETE FROM public.lts_flow_future_read_cache WHERE user_id=p_user_id;
   DELETE FROM public.lts_flow_future_read_cache_v2 WHERE user_id=p_user_id;
   DELETE FROM public.lts_v229_read_cache WHERE user_id=p_user_id;
   DELETE FROM public.lts_dashboard_cockpit_cache WHERE user_id=p_user_id;
   UPDATE public.lts_product_read_cache
    SET payload=((payload-'canonical_summary')#-'{updates,document_change_summary_version}')
     ||jsonb_build_object('product_refresh_pending_v415',true)
    WHERE user_id=p_user_id;
   UPDATE lts_product_refresh_private_v415.queue SET invalidate_caches=false WHERE user_id=p_user_id;
  EXCEPTION WHEN lock_not_available THEN
   -- The committed queue/epoch is sufficient to reject work in flight. The
   -- next worker removes all four derived caches before calculating again.
   NULL;
  END;
 END IF;
END $function$;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.refresh()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
 SET "TimeZone"='America/Sao_Paulo' AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(u::text,166));
 PERFORM lts_projection_private_v412.refresh_reference(u,current_date);
 -- Reuse the installed V366/V376 materializer for its existing fixed plans.
 PERFORM public.lts_recurring_materialize_v366(u,current_date);
 PERFORM lts_projection_private_v412.invalidate_reads(u);
 result:=lts_projection_private_v412.read_policy();
 RETURN result||jsonb_build_object('refreshed',true,'refresh',lts_product_refresh_private_v415.status(u));
END $function$;

CREATE OR REPLACE FUNCTION public.lts_browser_product_v1()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='public'
 SET "TimeZone"='America/Sao_Paulo' AS $function$
DECLARE v269_revision text;v_uid uuid;c jsonb;m jsonb;response jsonb;refresh jsonb;
 v_email text:=lower(coalesce(auth.jwt()->>'email',''));
 v_cached_today date;v_mode text:='cache_hit_fresh';v_doc_change_version text;
 v_is_stale boolean;v_available boolean;v_pending_path boolean:=false;card_state jsonb;verified_state jsonb;
BEGIN
 v_uid:=public.lts_browser_assert_user_v1();
 c:=public.lts_product_read_cached_v1(v_uid);
 v_available:=lts_product_refresh_private_v415.compatible(c->>'payload_version',c->'payload');
 refresh:=lts_product_refresh_private_v415.status(v_uid);
 v_is_stale:=coalesce((refresh->>'required')::boolean,true);
 IF NOT v_available OR v_is_stale THEN
  v_pending_path:=true;
  refresh:=lts_product_refresh_private_v415.enqueue(v_uid,'cache_read',false);
  v_is_stale:=true;
  v_mode:=CASE WHEN v_available THEN 'cache_hit_stale_deferred' ELSE 'initializing_deferred' END;
  m:=NULL::jsonb;
  IF v_available THEN
   card_state:=lts_product_refresh_private_v415.card_state_cached(v_uid);
   IF card_state IS NOT NULL AND (card_state->>'complete'='true' OR public.lts_has_card_presentation_v269()) THEN
    m:=c->'payload';
   END IF;
  END IF;
 ELSE
  -- These overlays and v269 guards are retained for the normal cached path.
  -- Missing/pending paths never enter them or call any cold product builder.
  v269_revision:=public.lts_card_read_start_v269(v_uid);
  m:=c->'payload';
  m:=public.lts_browser_enrich_flow_bank_gross_v1(m);
  m:=public.lts_current_debt_overlay_v357(m,public.lts_debt_evidence_read_v357(v_uid,current_date),'product');
  m:=public.lts_product_card_operating_overlay_v355(m,public.lts_card_cycles_presentation_v355(v_uid),current_date);
  refresh:=lts_product_refresh_private_v415.status(v_uid);
  v_is_stale:=coalesce((refresh->>'required')::boolean,true);
  IF v_is_stale THEN v_mode:='cache_hit_stale_deferred'; END IF;
 END IF;
 BEGIN v_cached_today:=nullif(c#>>'{payload,updates,freshness,today}','')::date;
 EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN v_cached_today:=NULL; END;
 v_doc_change_version:=coalesce(c#>>'{payload,updates,document_change_summary_version}','');
 INSERT INTO public.lts_access_audit(user_id,email,action,meta) VALUES(v_uid,v_email,'browser_rpc_product_read',
  jsonb_build_object('rpc_version',12,'payload_version',coalesce(c->>'payload_version','lts-product-fix86-v36'),
   'cached_today',v_cached_today,'server_today',current_date,'refresh_mode',v_mode,'refresh_required',v_is_stale,
   'document_change_summary_version',v_doc_change_version,'flow_bank_gross_basis','payload_events_reconciled_v1'));
 response:=jsonb_build_object('ok',true,'api_version',41,'product','lts-wealth-fix86-plus',
  'cache',jsonb_build_object('refreshed_at',c->'refreshed_at',
   'payload_version',coalesce(c->>'payload_version','lts-product-fix86-v36'),
   'cached_today',v_cached_today,'server_today',current_date,
   'is_stale',v_is_stale,'refresh_required',v_is_stale,'refresh_mode',v_mode),
  'refresh',refresh,'mvp',m);
 IF v_pending_path THEN
  IF m IS NOT NULL THEN
   response:=public.lts_product_card_completeness_v269(response,card_state);
   verified_state:=lts_product_refresh_private_v415.card_state_cached(v_uid);
   IF verified_state IS NULL OR verified_state->>'source_revision' IS DISTINCT FROM card_state->>'source_revision' THEN
    RETURN response||jsonb_build_object('mvp',NULL);
   END IF;
   IF public.lts_has_card_presentation_v269() THEN
    response:=response||jsonb_build_object('source_revision',card_state->>'source_revision',
     'source_complete',(card_state->>'complete')::boolean,'source_epoch',(card_state->>'source_epoch')::bigint);
   END IF;
  END IF;
  RETURN response;
 END IF;
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,
  public.lts_product_card_completeness_v269(response,public.lts_c6_completeness_state_v269(v_uid)));
END $function$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA lts_product_refresh_private_v415 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA lts_product_refresh_private_v415 TO service_role;
REVOKE ALL ON FUNCTION public.lts_browser_product_refresh_status_v415() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.lts_browser_product_refresh_request_v415() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_product_refresh_status_v415() TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.lts_browser_product_refresh_request_v415() TO authenticated,service_role;

-- Existing functions keep their exact security boundary, owner and execution
-- settings. No authenticated/authenticator statement_timeout is changed.
DO $metadata$
BEGIN
 IF EXISTS(SELECT 1 FROM v415_predecessor_metadata b JOIN pg_proc p ON p.oid=b.oid
  WHERE p.proowner IS DISTINCT FROM b.proowner OR p.provolatile IS DISTINCT FROM b.provolatile
   OR p.prosecdef IS DISTINCT FROM b.prosecdef OR p.proconfig IS DISTINCT FROM b.proconfig
   OR p.proacl IS DISTINCT FROM b.proacl) THEN
  RAISE EXCEPTION 'V415 changed predecessor execution metadata';
 END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='lts_product_refresh_private_v415' AND
   (has_function_privilege('anon',p.oid,'EXECUTE') OR has_function_privilege('authenticated',p.oid,'EXECUTE'))) THEN
  RAISE EXCEPTION 'V415 private function grant leak';
 END IF;
END $metadata$;

DO $cron$
DECLARE j record;before_job jsonb;after_job jsonb;pending_id bigint;
 daily_command text:=$job$
BEGIN;
SET LOCAL statement_timeout='8s';
SET LOCAL lock_timeout='2s';
SET LOCAL TimeZone='America/Sao_Paulo';
SELECT lts_product_refresh_private_v415.prepare(true);
COMMIT;
BEGIN;
SET LOCAL statement_timeout='600s';
SET LOCAL lock_timeout='3s';
SET LOCAL TimeZone='America/Sao_Paulo';
SELECT lts_product_refresh_private_v415.run_claimed();
COMMIT;
$job$;
 pending_command text:=$job$
BEGIN;
SET LOCAL statement_timeout='8s';
SET LOCAL lock_timeout='2s';
SET LOCAL TimeZone='America/Sao_Paulo';
SELECT lts_product_refresh_private_v415.prepare(false);
COMMIT;
BEGIN;
SET LOCAL statement_timeout='600s';
SET LOCAL lock_timeout='3s';
SET LOCAL TimeZone='America/Sao_Paulo';
SELECT lts_product_refresh_private_v415.run_claimed();
COMMIT;
$job$;
BEGIN
 IF (SELECT count(*) FROM cron.job WHERE jobname='lts_product_read_cache_operational_daily_v1')<>1 THEN
  RAISE EXCEPTION 'Expected one daily product cache job';
 END IF;
 SELECT * INTO j FROM cron.job WHERE jobname='lts_product_read_cache_operational_daily_v1';
 IF md5(j.command) IS DISTINCT FROM '6eeed355cc37d6ae399f4df76a735d0b' THEN
  RAISE EXCEPTION 'Unexpected daily product cache command';
 END IF;
 before_job:=to_jsonb(j);
 IF EXISTS(SELECT 1 FROM cron.job WHERE jobname='lts_product_refresh_pending_v415') THEN
  RAISE EXCEPTION 'V415 pending worker already exists';
 END IF;
 PERFORM cron.alter_job(job_id=>j.jobid,command=>daily_command);
 SELECT to_jsonb(x) INTO after_job FROM cron.job x WHERE x.jobid=j.jobid;
 IF before_job-'command' IS DISTINCT FROM after_job-'command' THEN
  RAISE EXCEPTION 'V415 changed daily job identity or schedule';
 END IF;
 pending_id:=cron.schedule('lts_product_refresh_pending_v415','* * * * *',pending_command);
 IF NOT EXISTS(SELECT 1 FROM cron.job x WHERE x.jobid=pending_id AND x.jobname='lts_product_refresh_pending_v415'
  AND x.schedule='* * * * *' AND x.active AND x.database=j.database AND x.username=j.username
  AND x.nodename=j.nodename AND x.nodeport=j.nodeport AND x.command=pending_command) THEN
  RAISE EXCEPTION 'V415 pending worker configuration mismatch';
 END IF;
END $cron$;

COMMIT;
