BEGIN;
SET LOCAL lock_timeout='2s';
DO $check$ DECLARE p regprocedure;h text;acl text;cfg text[];definer boolean;owner text;BEGIN
p:='public.lts_current_flow_v229(uuid,date,date)'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO h,acl,cfg,definer,owner FROM pg_proc WHERE oid=p;
 IF h NOT IN('6c28fec1d35a2b172b36bcdeebc5bfbe','87e67d199a57d9c947c792faac147ad7') OR acl IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' OR cfg IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo'] OR definer IS DISTINCT FROM true OR owner<>'postgres' THEN RAISE EXCEPTION 'long flow reader changed concurrently: %',p;END IF;
p:='lts_product_refresh_private_v415.run_claimed()'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO h,acl,cfg,definer,owner FROM pg_proc WHERE oid=p;
 IF h NOT IN('71fd4b4ec3ec34a33df0a605c0e1a76b','dc6ada84c13393bffdabeba767614a17') OR acl IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' OR cfg IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo'] OR definer IS DISTINCT FROM true OR owner<>'postgres' THEN RAISE EXCEPTION 'long flow reader changed concurrently: %',p;END IF;
p:=to_regprocedure('lts_product_refresh_private_v415.long_flow_guard_v450(uuid)');IF p IS NOT NULL THEN
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO h,acl,cfg,definer,owner FROM pg_proc WHERE oid=p;
 IF h<>'62ee97b13bcaa0632612ecb7953cb17c' OR acl IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' OR cfg IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo'] OR definer OR owner<>'postgres' THEN RAISE EXCEPTION 'long flow helper changed concurrently';END IF;END IF;
p:=to_regprocedure('lts_product_refresh_private_v415.long_flow_raw_v450(uuid,date)');IF p IS NOT NULL THEN
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO h,acl,cfg,definer,owner FROM pg_proc WHERE oid=p;
 IF h<>'9be13bd9d50466e93e7e1c00d1893b29' OR acl IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' OR cfg IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo'] OR definer OR owner<>'postgres' THEN RAISE EXCEPTION 'long flow helper changed concurrently';END IF;END IF;
END $check$;
DO $install$ BEGIN
IF md5(pg_get_functiondef('public.lts_current_flow_v229(uuid,date,date)'::regprocedure))='6c28fec1d35a2b172b36bcdeebc5bfbe' THEN EXECUTE $replacement$CREATE OR REPLACE FUNCTION public.lts_current_flow_v229(p_user_id uuid, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  raw jsonb; position jsonb; first_day jsonb; days jsonb; events jsonb;
  delta_i numeric; delta_b numeric; delta_c numeric;
begin
  if p_from is null or p_to is null or p_from>p_to or p_from<current_date or p_to-current_date>12000 then
    raise exception 'invalid current/future range';
  end if;
  raw:=case when p_to+30<=current_date+1800 then public.lts_flow_future_read_slice_v9(p_user_id,current_date,p_to) else public.lts_daily_flow_fix86_v20(p_user_id,current_date,p_to+30) end;
  position:=public.lts_open_finance_current_bank_position_v1(p_user_id);
  select d into first_day from jsonb_array_elements(raw->'days') d where d->>'date'=current_date::text;
  if first_day is null then raise exception 'current anchor day unavailable'; end if;
  select (a->>'balance')::numeric-(first_day#>>'{Itaú,balance}')::numeric into delta_i from jsonb_array_elements(position->'accounts') a where a->>'institution_code'='341';
  select (a->>'balance')::numeric-(first_day#>>'{Bradesco,balance}')::numeric into delta_b from jsonb_array_elements(position->'accounts') a where a->>'institution_code'='237';
  select (a->>'balance')::numeric-(first_day#>>'{C6,balance}')::numeric into delta_c from jsonb_array_elements(position->'accounts') a where a->>'institution_code'='336';
  if delta_i is null or delta_b is null or delta_c is null then raise exception 'current bank anchors incomplete'; end if;
  with layers as materialized (
    select * from public.lts_dashboard_cash_ladder_from_flow_v229(p_user_id,current_date,p_to,raw)
  ), daily_totals as materialized (
    select (x->>'date')::date dt,count(*) row_count,
      count(nullif(x#>>'{Consolidado,economic_net}','')) known_count,
      sum(nullif(x#>>'{Consolidado,economic_net}','')::numeric) economic_net
    from jsonb_array_elements(raw->'days')x group by 1
  ), future_windows as materialized (
    select dt,count(*) over w future_dates,sum(row_count) over w future_rows,
      sum(known_count) over w known_movements,sum(economic_net) over w future_net
    from daily_totals
    window w as (order by dt range between interval '1 day' following and interval '30 days' following)
  ), adjusted as (
    select (d->>'date')::date dt,
      d || jsonb_build_object(
        'Itaú',(d->'Itaú')||jsonb_build_object('balance',(d#>>'{Itaú,balance}')::numeric+delta_i,'opening_balance',coalesce((d#>>'{Itaú,opening_balance}')::numeric,(d#>>'{Itaú,balance}')::numeric-(d#>>'{Itaú,net}')::numeric)+delta_i),
        'Bradesco',(d->'Bradesco')||jsonb_build_object('balance',(d#>>'{Bradesco,balance}')::numeric+delta_b,'opening_balance',coalesce((d#>>'{Bradesco,opening_balance}')::numeric,(d#>>'{Bradesco,balance}')::numeric-(d#>>'{Bradesco,net}')::numeric)+delta_b),
        'C6',(d->'C6')||jsonb_build_object('balance',(d#>>'{C6,balance}')::numeric+delta_c,'opening_balance',coalesce((d#>>'{C6,opening_balance}')::numeric,(d#>>'{C6,balance}')::numeric-(d#>>'{C6,net}')::numeric)+delta_c),
        'Consolidado',(d->'Consolidado')||jsonb_build_object('bank_balance',l.operational_cash),
        'fix86_columns',(d->'fix86_columns')||jsonb_build_object(
          'saldo_anterior',(d#>>'{fix86_columns,saldo_anterior}')::numeric+l.operational_cash-(d#>>'{fix86_columns,saldo_final}')::numeric,
          'saldo_final',l.operational_cash,
          'liq_d0_1_recurso',l.d01_resource,
          'rsus_vested',l.rsu_vested_scheduled,
          'fgts',l.fgts_projected,
          'saldo_apos_d0_1',l.balance_after_d01,
          'saldo_apos_rsu',l.balance_with_scheduled_vesting,
          'saldo_apos_fgts',l.balance_with_fgts_projected,
          'liq_d0_1',l.balance_after_d01,
          -- Short branch already includes next30 economic movements. Re-anchor
          -- only its eligible D0 basis. Long branch obtains the missing lookahead.
          'liq_d30',CASE WHEN p_to+30<=current_date+1800 THEN
            (d#>>'{fix86_columns,liq_d30}')::numeric+l.balance_after_d01-(d#>>'{fix86_columns,liq_d0_1}')::numeric
          ELSE CASE WHEN w.future_dates=30 AND w.future_rows=30 AND w.known_movements=30 THEN l.balance_after_d01+w.future_net ELSE NULL END END,
          'posicao_antes_rsus',l.balance_after_d01,
          'disponivel_total',l.balance_with_scheduled_vesting,
          'posicao_curto_prazo',l.balance_with_scheduled_vesting
        )
      ) value
    from jsonb_array_elements(raw->'days') d join layers l on l.flow_date=(d->>'date')::date left join future_windows w on w.dt=(d->>'date')::date
    where (d->>'date')::date between p_from and p_to
  ) select jsonb_agg(value order by dt) into days from adjusted;
  if jsonb_array_length(days)<>p_to-p_from+1 then raise exception 'incomplete current/future days'; end if;
  select coalesce(jsonb_agg(e order by e->>'event_date',e->>'source_ref'),'[]'::jsonb) into events
    from jsonb_array_elements(coalesce(raw->'events','[]'::jsonb)) e
    where (e->>'event_date')::date between p_from and p_to;
  return raw||jsonb_build_object('from',p_from,'to',p_to,'days',days,'events',events,
    'version','daily-flow-v225-current-anchors','current_anchor_date',current_date);
end
$function$
$replacement$;END IF;
IF md5(pg_get_functiondef('public.lts_current_flow_v229(uuid,date,date)'::regprocedure))<>'87e67d199a57d9c947c792faac147ad7' THEN RAISE EXCEPTION 'long flow reconstruction differs';END IF;
IF md5(pg_get_functiondef('lts_product_refresh_private_v415.run_claimed()'::regprocedure))='71fd4b4ec3ec34a33df0a605c0e1a76b' THEN EXECUTE $replacement$CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.run_claimed()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE audit_v442 jsonb; audit_guard_v442 jsonb; projection_full_v438 jsonb; projection_memo_v418 jsonb; ctx jsonb; u uuid; token uuid; ver bigint; expected_epoch bigint; final_epoch bigint;
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
  PERFORM set_config('lts.projection_memo_v437','',true);
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
   AND (nullif(current_setting('lts.projection_summary_v418',true),'') IS NULL
    OR nullif(current_setting('lts.projection_memo_v437',true),'') IS NULL) THEN
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
  -- Complete the same calendar audit once, off the browser's 8s request path.
  audit_guard_v442:=lts_product_refresh_private_v415.audit_guard_v442(u);
  audit_v442:=public.lts_recurring_future_gap_audit_v6(u,current_date,lts_projection_private_v412.horizon_end(current_date));
  IF jsonb_typeof(audit_v442->'horizon_checks') IS DISTINCT FROM 'array' THEN
   RAISE EXCEPTION USING ERRCODE='P0416',MESSAGE='Calendar audit unavailable';
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
   projection_full_v438:=nullif(current_setting('lts.projection_memo_v437',true),'')::jsonb;
   IF projection_full_v438->>'user_id' IS DISTINCT FROM u::text
    OR projection_full_v438->>'as_of' IS DISTINCT FROM current_date::text
    OR projection_full_v438#>>'{inputs,source_epoch}' IS DISTINCT FROM final_epoch::text
    OR projection_full_v438#>>'{inputs,card_source_key}' IS DISTINCT FROM expected_card_revision
    OR projection_full_v438#>>'{inputs,policy_fingerprint}' IS DISTINCT FROM md5((
     lts_projection_private_v412.owner_policy(u)||jsonb_build_object('_history_reference',lts_projection_private_v412.reference_state(u)))::text)
    OR jsonb_typeof(projection_full_v438->'payload') IS DISTINCT FROM 'object'
    OR projection_memo_v418->'summary' IS DISTINCT FROM ((projection_full_v438->'payload')-'events'-'replacement_refs')
    OR projection_full_v438->>'digest' IS DISTINCT FROM encode(sha256(convert_to((projection_full_v438->'payload')::text,'UTF8')),'hex') THEN
    RAISE EXCEPTION USING ERRCODE='P0416',MESSAGE='Projection payload unavailable';
   END IF;
   projection_full_v438:=jsonb_build_object('user_id',u,'as_of',current_date,
    'payload',projection_full_v438->'payload','digest',projection_full_v438->>'digest',
    'guard',(projection_memo_v418->'guard')||jsonb_build_object('policy_fingerprint',projection_full_v438#>>'{inputs,policy_fingerprint}'));
   UPDATE public.lts_product_read_cache
    SET payload=jsonb_set(jsonb_set(payload,'{projection_summary_v418}',projection_memo_v418,true),
     '{projection_build_v438}',projection_full_v438,true)
    WHERE user_id=u;
  END IF;
  IF audit_guard_v442 IS DISTINCT FROM lts_product_refresh_private_v415.audit_guard_v442(u) THEN
   RAISE EXCEPTION USING ERRCODE='P0415',MESSAGE='Calendar audit sources changed';
  END IF;
  UPDATE public.lts_product_read_cache SET payload=jsonb_set(payload,'{recurring_audit_v442}',jsonb_build_object(
   'guard',audit_guard_v442,'request_version',ver::text,'payload',audit_v442,
   'digest',encode(sha256(convert_to(audit_v442::text,'UTF8')),'hex')),true) WHERE user_id=u;
  UPDATE lts_product_refresh_private_v415.queue SET state='ready',completed_version=ver,
   completed_at=clock_timestamp(),next_attempt_at=NULL,lease_expires_at=NULL,last_error_code=NULL,
   claim_token=NULL,claimed_version=NULL,claimed_epoch=NULL,invalidate_caches=false WHERE user_id=u;
  -- Warm after all product and queue publication writes, in the same claim.
  -- No extra job, altered classification, browser identity or financial write.
  PERFORM 1 FROM lts_product_refresh_private_v415.expense_review_pending_v450(u,date '2013-10-10',current_date);
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
END $function$
$replacement$;END IF;
IF md5(pg_get_functiondef('lts_product_refresh_private_v415.run_claimed()'::regprocedure))<>'dc6ada84c13393bffdabeba767614a17' THEN RAISE EXCEPTION 'long flow reconstruction differs';END IF;
END $install$;
COMMIT;
