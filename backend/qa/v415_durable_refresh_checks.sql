-- Exact-migration tests with deterministic synthetic cache builders.
CREATE FUNCTION qa_v415.reset(p_seed_first boolean DEFAULT true) RETURNS void LANGUAGE plpgsql AS $$BEGIN
 TRUNCATE lts_product_refresh_private_v415.queue,public.lts_product_read_cache,
  public.lts_dashboard_cockpit_cache,public.lts_flow_future_read_cache,
  public.lts_flow_future_read_cache_v2,public.lts_v229_read_cache,public.lts_access_audit,qa_v415.calls;
 ALTER SEQUENCE qa_v415.heavy_calls RESTART WITH 1;
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=415 WHERE singleton;
 UPDATE qa_v415.config SET value='"normal"' WHERE key='mode';
 UPDATE qa_v415.config SET value='null' WHERE key='pause_stage';
 UPDATE qa_v415.config SET value='true' WHERE key='c6_complete';
 PERFORM set_config('app.synthetic_uid','',false);
 PERFORM set_config('lts.product_refresh_claim','',false);
 PERFORM set_config('request.headers','{}',false);
 PERFORM set_config('request.path','',false);
 IF p_seed_first THEN PERFORM qa_v415.seed_cache(qa_v415.owner(1)); END IF;
 PERFORM qa_v415.seed_cache(qa_v415.owner(2));
 INSERT INTO public.lts_flow_future_read_cache VALUES(qa_v415.owner(1),'{"memo":"old-first"}');
 INSERT INTO public.lts_flow_future_read_cache_v2 VALUES(qa_v415.owner(1),'{"memo":"old-second"}');
 INSERT INTO public.lts_v229_read_cache VALUES(qa_v415.owner(1),'other-review',current_date,current_date,current_date,'{"memo":"old-review"}',now(),'other-fixture');
 DELETE FROM qa_v415.calls;ALTER SEQUENCE qa_v415.heavy_calls RESTART WITH 1;
END$$;
CREATE FUNCTION qa_v415.expect_denied(p_name text,p_sql text,p_role text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$DECLARE ec text;BEGIN
 BEGIN
  IF p_role IS NOT NULL THEN EXECUTE format('SET LOCAL ROLE %I',p_role); END IF;
  EXECUTE p_sql;
 EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS ec=RETURNED_SQLSTATE;END;
 RESET ROLE;
 PERFORM qa_v415.check(p_name,ec='42501',jsonb_build_object('error_code',ec));
END$$;
CREATE FUNCTION qa_v415.cycle() RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN
 PERFORM set_config('app.synthetic_uid','',false);
 PERFORM lts_product_refresh_private_v415.prepare(false);
 RETURN lts_product_refresh_private_v415.run_claimed();
END$$;

DO $metadata$
DECLARE okay boolean;BEGIN
 SELECT bool_and(o.attributes=i.attributes) INTO okay
 FROM qa_v415.original_functions o JOIN qa_v415.installed_functions i USING(signature);
 PERFORM qa_v415.check('existing execution attributes, owner and ACL preserved',okay);
 SELECT bool_and(o.body_md5=i.body_md5) INTO okay
 FROM qa_v415.original_functions o JOIN qa_v415.installed_functions i USING(signature)
 WHERE o.signature NOT IN('lts_browser_product_v1()',
  'lts_projection_private_v412.invalidate_reads(uuid)','lts_projection_private_v412.refresh()');
 PERFORM qa_v415.check('cache builders and recurring maintenance definitions unchanged',okay);
 PERFORM qa_v415.check('private queue RLS and no public table access',
  (SELECT relrowsecurity FROM pg_class WHERE oid='lts_product_refresh_private_v415.queue'::regclass)
  AND NOT has_schema_privilege('authenticated','lts_product_refresh_private_v415','USAGE')
  AND NOT has_schema_privilege('anon','lts_product_refresh_private_v415','USAGE')
  AND NOT has_table_privilege('authenticated','lts_product_refresh_private_v415.queue','SELECT,INSERT,UPDATE,DELETE')
  AND NOT has_table_privilege('anon','lts_product_refresh_private_v415.queue','SELECT,INSERT,UPDATE,DELETE'));
 PERFORM qa_v415.check('private functions have no browser or anonymous EXECUTE',
  NOT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='lts_product_refresh_private_v415'
   AND(has_function_privilege('authenticated',p.oid,'EXECUTE') OR has_function_privilege('anon',p.oid,'EXECUTE'))));
 PERFORM qa_v415.check('public refresh RPCs require authentication and have no owner parameter',
  (SELECT bool_and(pronargs=0 AND prosecdef AND proowner=(SELECT oid FROM pg_roles WHERE rolname='postgres')
   AND has_function_privilege('authenticated',p.oid,'EXECUTE') AND NOT has_function_privilege('anon',p.oid,'EXECUTE')
   AND proconfig @> ARRAY['search_path=""','TimeZone=America/Sao_Paulo'])
   FROM pg_proc p WHERE p.oid IN('public.lts_browser_product_refresh_request_v415()'::regprocedure,
    'public.lts_browser_product_refresh_status_v415()'::regprocedure)));
 PERFORM qa_v415.check('daily identity and unrelated schedule retained; two-phase pending worker added',
  (SELECT to_jsonb(j)-'command'=to_jsonb(o)-'command' FROM cron.job j JOIN qa_v415.original_cron o USING(jobid)
    WHERE o.jobid=2)
  AND(SELECT to_jsonb(j)=to_jsonb(o) FROM cron.job j JOIN qa_v415.original_cron o USING(jobid) WHERE o.jobid=99)
  AND(SELECT count(*)=1 AND bool_and(schedule='* * * * *' AND active AND command LIKE '%prepare(false)%'
    AND command LIKE '%COMMIT;%BEGIN;%' AND command LIKE '%run_claimed()%')
    FROM cron.job WHERE jobname='lts_product_refresh_pending_v415'));
END $metadata$;

SELECT qa_v415.reset(true);
DO $fresh_idle$
DECLARE j jsonb;before_cache text;after_cache text;BEGIN
 SELECT md5(jsonb_agg(to_jsonb(c) ORDER BY user_id)::text) INTO before_cache FROM public.lts_product_read_cache c;
 j:=lts_product_refresh_private_v415.prepare(false);
 SELECT md5(jsonb_agg(to_jsonb(c) ORDER BY user_id)::text) INTO after_cache FROM public.lts_product_read_cache c;
 PERFORM qa_v415.check('fresh caches and no queue make pending scheduler a no-op',
  j->>'claimed'='false' AND before_cache=after_cache AND qa_v415.count_calls()=0
  AND NOT EXISTS(SELECT FROM lts_product_refresh_private_v415.queue)
  AND NOT EXISTS(SELECT FROM public.lts_access_audit)
  AND(SELECT epoch=415 FROM public.lts_read_cache_epoch_v242 WHERE singleton));
 PERFORM set_config('app.synthetic_uid',qa_v415.owner(2)::text,false);
 SET LOCAL ROLE authenticated;
 j:=public.lts_browser_product_v1();
 RESET ROLE;
 PERFORM qa_v415.check('authenticated cached read returns only the asserted owner full payload',
  j#>>'{refresh,state}'='ready' AND j#>>'{refresh,required}'='false'
  AND j#>>'{mvp,owner_fixture}'=qa_v415.owner(2)::text
  AND j#>'{mvp,unknown_future_branch}'=qa_v415.full_payload(qa_v415.owner(2))->'unknown_future_branch'
  AND position(qa_v415.owner(1)::text IN j::text)=0
  AND NOT EXISTS(SELECT FROM lts_product_refresh_private_v415.queue));
END $fresh_idle$;

SELECT qa_v415.reset(false);
DO $miss$
DECLARE j jsonb;again jsonb;q_before jsonb;calls bigint;BEGIN
 PERFORM set_config('app.synthetic_uid',qa_v415.owner(1)::text,false);
 calls:=qa_v415.count_calls();
 j:=public.lts_browser_product_v1();again:=public.lts_browser_product_v1();
 PERFORM qa_v415.check('missing cache returns pending null product without any heavy dependency',
  j->>'ok'='true' AND j->'mvp'='null'::jsonb AND j#>>'{refresh,state}'='pending'
  AND j#>>'{refresh,required}'='true' AND j#>>'{refresh,cached_available}'='false'
  AND j#>>'{cache,refresh_required}'='true' AND qa_v415.count_calls()=calls
  AND NOT EXISTS(SELECT FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(1)));
 SELECT to_jsonb(q) INTO q_before FROM lts_product_refresh_private_v415.queue q WHERE user_id=qa_v415.owner(1);
 PERFORM public.lts_browser_product_refresh_request_v415();
 PERFORM public.lts_browser_product_refresh_status_v415();
 PERFORM public.lts_browser_product_refresh_status_v415();
 PERFORM qa_v415.check('repeated read, request and status coalesce without changing versions or attempts',
  q_before=(SELECT to_jsonb(q) FROM lts_product_refresh_private_v415.queue q WHERE user_id=qa_v415.owner(1))
  AND j#>>'{refresh,request_version}'=again#>>'{refresh,request_version}' AND qa_v415.count_calls()=calls);
 PERFORM qa_v415.check('single owner request does not create another owner queue',
  (SELECT count(*)=1 AND bool_and(user_id=qa_v415.owner(1)) FROM lts_product_refresh_private_v415.queue));
END $miss$;
SELECT qa_v415.expect_denied('anonymous status is denied','SELECT public.lts_browser_product_refresh_status_v415()','anon');
SELECT qa_v415.expect_denied('authenticated cannot choose another owner through private enqueue',
 $$SELECT lts_product_refresh_private_v415.enqueue('22222222-2222-4222-8222-222222222222','manual',true)$$,'authenticated');
SELECT qa_v415.expect_denied('authenticated cannot inspect private queue','SELECT * FROM lts_product_refresh_private_v415.queue','authenticated');
SELECT qa_v415.expect_denied('authenticated cannot invoke worker','SELECT lts_product_refresh_private_v415.run_claimed()','authenticated');
SELECT set_config('app.synthetic_uid','',false);
SELECT qa_v415.expect_denied('missing signed-in owner is denied','SELECT public.lts_browser_product_refresh_request_v415()');
SELECT set_config('app.synthetic_uid',qa_v415.owner(3)::text,false);
SELECT qa_v415.expect_denied('inactive allowlist owner is denied','SELECT public.lts_browser_product_refresh_request_v415()');
SELECT qa_v415.expect_denied('private queue also refuses inactive owner',
 $$SELECT lts_product_refresh_private_v415.enqueue('33333333-3333-4333-8333-333333333333','manual',true)$$);

DO $initialize$
DECLARE j jsonb;seq text[];other jsonb;BEGIN
 SELECT payload INTO other FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(2);
 j:=qa_v415.cycle();
 SELECT array_agg(stage ORDER BY id) FILTER(WHERE stage IN('v2','v5')) INTO seq FROM qa_v415.calls;
 PERFORM qa_v415.check('cold worker calls full v2 then operational v5 and publishes complete cache',
  seq=ARRAY['v2','v5'] AND j->>'published'='true'
  AND(SELECT state='ready' AND completed_version=request_version AND attempts=1 AND claim_token IS NULL
      FROM lts_product_refresh_private_v415.queue WHERE user_id=qa_v415.owner(1))
  AND(SELECT lts_product_refresh_private_v415.compatible(payload_version,payload)
   AND payload#>>'{canonical_summary,as_of}'=current_date::text
   AND payload->'unknown_future_branch'=qa_v415.full_payload(qa_v415.owner(1))->'unknown_future_branch'
   FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(1)));
 PERFORM qa_v415.check('worker does not change another owner product',
  other=(SELECT payload FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(2)));
 PERFORM set_config('app.synthetic_uid',qa_v415.owner(1)::text,false);
 j:=public.lts_browser_product_refresh_status_v415();
 PERFORM qa_v415.check('public completion agrees with queue and does not leak private claim context',
  j#>>'{refresh,state}'='ready' AND j#>>'{refresh,required}'='false'
  AND j#>>'{refresh,completed_version}'=j#>>'{refresh,request_version}'
  AND NOT ((j->'refresh') ?| ARRAY['user_id','claim_token','claimed_epoch','claimed_version','last_error_code'])
  AND position('22222222-' IN j::text)=0);
END $initialize$;

SELECT qa_v415.reset(true);
DO $invalidate$
DECLARE before_payload jsonb;after_payload jsonb;other jsonb;j jsonb;seq text[];BEGIN
 SELECT payload INTO before_payload FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(1);
 SELECT payload INTO other FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(2);
 PERFORM lts_projection_private_v412.invalidate_reads(qa_v415.owner(1));
 SELECT payload INTO after_payload FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(1);
 PERFORM qa_v415.check('soft invalidation retains every financial and unknown field',
  ((before_payload-'canonical_summary')#-'{updates,document_change_summary_version}')=
  ((after_payload-ARRAY['canonical_summary','product_refresh_pending_v415'])#-'{updates,document_change_summary_version}')
  AND other=(SELECT payload FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(2))
  AND(SELECT epoch=416 FROM public.lts_read_cache_epoch_v242 WHERE singleton)
  AND(SELECT state='pending' FROM lts_product_refresh_private_v415.queue WHERE user_id=qa_v415.owner(1)));
 PERFORM set_config('app.synthetic_uid',qa_v415.owner(1)::text,false);
 j:=public.lts_browser_product_v1();
 PERFORM qa_v415.check('pending browser with no current card memo defers presentation without heavy work',
  j->'mvp'='null'::jsonb AND j#>>'{refresh,required}'='true' AND j#>>'{refresh,cached_available}'='true'
  AND qa_v415.count_calls()=0
  AND after_payload=(SELECT payload FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(1)));
 j:=qa_v415.cycle();
 SELECT array_agg(stage ORDER BY id) FILTER(WHERE stage IN('v2','v5')) INTO seq FROM qa_v415.calls;
 PERFORM qa_v415.check('existing cache uses only v5 and preserves full unknown branches',
  seq=ARRAY['v5'] AND j->>'published'='true'
  AND(SELECT payload->'unknown_future_branch'=before_payload->'unknown_future_branch'
   AND payload->'expenses'=before_payload->'expenses' AND payload->'backup'=before_payload->'backup'
   FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(1)));
END $invalidate$;

SELECT qa_v415.reset(true);
DO $pending_card_guards$
DECLARE j jsonb;original jsonb;calls bigint;BEGIN
 SELECT payload INTO original FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(1);
 PERFORM lts_product_refresh_private_v415.enqueue(qa_v415.owner(1),'manual',false);
 PERFORM set_config('app.synthetic_uid',qa_v415.owner(1)::text,false);
 calls:=qa_v415.count_calls();
 j:=public.lts_browser_product_v1();
 PERFORM qa_v415.check('pending with verified complete memo preserves full payload without cold cards',
  j->'mvp'=original AND j#>>'{refresh,required}'='true' AND qa_v415.count_calls()=calls);
 UPDATE public.lts_v229_read_cache SET payload=jsonb_set(payload,'{complete}','false')
  ||jsonb_build_object('incomplete_families','["c6"]'::jsonb)
  WHERE user_id=qa_v415.owner(1) AND kind='card_completeness_v269';
 j:=public.lts_browser_product_v1();
 PERFORM qa_v415.check('incomplete cards without presentation capability return pending null payload',
  j->'mvp'='null'::jsonb AND qa_v415.count_calls()=calls);
 PERFORM set_config('request.headers','{"x-client-info":"lts-wealth-v269-c6-completeness"}',false);
 PERFORM set_config('request.path','/rpc/lts_browser_product_v1',false);
 j:=public.lts_browser_product_v1();
 PERFORM qa_v415.check('pending incomplete card memo applies real V269 presentation guard',
  j#>>'{mvp,complete}'='false' AND j->>'source_complete'='false' AND j->>'source_epoch'='415'
  AND j#>'{mvp,flow,days,1,fix86_columns,saldo_final}'='null'::jsonb
  AND j#>>'{mvp,flow,days,0,fix86_columns,saldo_final}'='123.45'
  AND j#>>'{mvp,flow,days,1,Itau,balance}'='50'
  AND j#>'{mvp,flow,events,1,signed_amount}'='null'::jsonb
  AND j#>>'{mvp,flow,events,1,observed_unreconciled_signed_amount}'='-25'
  AND j#>'{mvp,unknown_future_branch}'=original->'unknown_future_branch'
  AND original=(SELECT payload FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(1))
  AND qa_v415.count_calls()=calls);
 UPDATE public.lts_v229_read_cache SET source_fingerprint='stale-synthetic-revision'
  WHERE user_id=qa_v415.owner(1) AND kind='card_completeness_v269';
 j:=public.lts_browser_product_v1();
 PERFORM qa_v415.check('stale or another-owner card memo cannot authorize pending payload',
  j->'mvp'='null'::jsonb AND lts_product_refresh_private_v415.card_state_cached(qa_v415.owner(1)) IS NULL
  AND lts_product_refresh_private_v415.card_state_cached(qa_v415.owner(2)) IS NOT NULL
  AND qa_v415.count_calls()=calls);
END $pending_card_guards$;

SELECT qa_v415.reset(true);
DO $force_canonical$
DECLARE j jsonb;BEGIN
 -- Both old keys still match, but canonical as_of is absent: a call alone could short-circuit v5.
 UPDATE public.lts_product_read_cache SET payload=payload#-'{canonical_summary,as_of}' WHERE user_id=qa_v415.owner(1);
 PERFORM lts_product_refresh_private_v415.enqueue(qa_v415.owner(1),'manual',false);
 j:=qa_v415.cycle();
 PERFORM qa_v415.check('missing canonical freshness forces v5 recalculation despite matching old keys',
  j->>'published'='true' AND EXISTS(SELECT FROM qa_v415.calls WHERE stage='v5_recalculate')
  AND NOT EXISTS(SELECT FROM qa_v415.calls WHERE stage='v5_short_circuit')
  AND(SELECT payload#>>'{canonical_summary,as_of}'=current_date::text FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(1)));
END $force_canonical$;

DO $rollback_cases$
DECLARE mode text;j jsonb;before_cache jsonb;before_memo jsonb;expected text;BEGIN
 FOREACH mode IN ARRAY ARRAY['partial_v5','wrong_version','wrong_day','missing_current_day','raise_after_write','cancel_after_write'] LOOP
  PERFORM qa_v415.reset(true);
  SELECT to_jsonb(c) INTO before_cache FROM public.lts_product_read_cache c WHERE user_id=qa_v415.owner(1);
  SELECT to_jsonb(c) INTO before_memo FROM public.lts_flow_future_read_cache_v2 c WHERE user_id=qa_v415.owner(1);
  UPDATE qa_v415.config SET value=to_jsonb(mode) WHERE key='mode';
  PERFORM lts_product_refresh_private_v415.enqueue(qa_v415.owner(1),'manual',false);
  j:=qa_v415.cycle();
  expected:=CASE WHEN mode='raise_after_write' THEN 'refresh_failed' WHEN mode='cancel_after_write' THEN 'refresh_timed_out' ELSE 'refresh_contract_invalid' END;
  PERFORM qa_v415.check('failed refresh rolls back complete cache and memo: '||mode,
   j->>'published'='false' AND j->>'error_code'=expected
   AND before_cache=(SELECT to_jsonb(c) FROM public.lts_product_read_cache c WHERE user_id=qa_v415.owner(1))
   AND before_memo=(SELECT to_jsonb(c) FROM public.lts_flow_future_read_cache_v2 c WHERE user_id=qa_v415.owner(1))
   AND NOT EXISTS(SELECT FROM public.lts_dashboard_cockpit_cache WHERE user_id=qa_v415.owner(1))
   AND(SELECT state='pending' AND attempts=1 AND completed_version=0 AND last_error_code=expected
     AND next_attempt_at>clock_timestamp()+interval '20 seconds' AND claim_token IS NULL
    FROM lts_product_refresh_private_v415.queue WHERE user_id=qa_v415.owner(1)));
  PERFORM set_config('app.synthetic_uid',qa_v415.owner(1)::text,false);
  j:=public.lts_browser_product_refresh_status_v415();
  PERFORM qa_v415.check('safe public error only: '||mode,
   j#>>'{refresh,error_code}'=expected AND position('private synthetic' IN j::text)=0
   AND j#>>'{refresh,required}'='true' AND j#>>'{refresh,cached_available}'='true');
 END LOOP;
END $rollback_cases$;

SELECT qa_v415.reset(false);
DO $partial_init$
DECLARE j jsonb;BEGIN
 UPDATE qa_v415.config SET value='"partial_v2"' WHERE key='mode';
 PERFORM lts_product_refresh_private_v415.enqueue(qa_v415.owner(1),'manual',false);
 j:=qa_v415.cycle();
 PERFORM qa_v415.check('partial initialization never publishes or leaves a partial cache row',
  j->>'published'='false' AND j->>'error_code'='refresh_contract_invalid'
  AND NOT EXISTS(SELECT FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(1)));
END $partial_init$;

SELECT qa_v415.reset(true);
DO $retries$
DECLARE j jsonb;n integer;count_before bigint;BEGIN
 UPDATE qa_v415.config SET value='"raise_after_write"' WHERE key='mode';
 PERFORM lts_product_refresh_private_v415.enqueue(qa_v415.owner(1),'manual',false);
 FOR n IN 1..3 LOOP
  UPDATE lts_product_refresh_private_v415.queue SET next_attempt_at=clock_timestamp()-interval '1 second' WHERE user_id=qa_v415.owner(1);
  j:=qa_v415.cycle();
  PERFORM qa_v415.check('automatic attempt budget step '||n,
   j->>'published'='false' AND(SELECT attempts=n AND state=CASE WHEN n=3 THEN 'failed' ELSE 'pending' END
    AND (n=3 OR next_attempt_at>clock_timestamp()+CASE WHEN n=1 THEN interval '20 seconds' ELSE interval '110 seconds' END)
    FROM lts_product_refresh_private_v415.queue WHERE user_id=qa_v415.owner(1)));
 END LOOP;
 count_before:=qa_v415.count_calls();
 PERFORM qa_v415.cycle();
 PERFORM qa_v415.check('exhausted queue does not auto-retry',qa_v415.count_calls()=count_before
  AND(SELECT state='failed' AND attempts=3 AND next_attempt_at IS NULL FROM lts_product_refresh_private_v415.queue WHERE user_id=qa_v415.owner(1)));
 PERFORM set_config('app.synthetic_uid',qa_v415.owner(1)::text,false);
 j:=public.lts_browser_product_refresh_request_v415();
 PERFORM qa_v415.check('explicit request resets exhausted budget and advances version',
  j#>>'{refresh,state}'='pending' AND j#>>'{refresh,attempts}'='0' AND j#>>'{refresh,request_version}'='2');
 UPDATE qa_v415.config SET value='"normal"' WHERE key='mode';
 j:=qa_v415.cycle();
 PERFORM qa_v415.check('explicit retry can complete',j->>'published'='true');
END $retries$;

SELECT qa_v415.reset(true);
DO $lease$
DECLARE j jsonb;first_token uuid;count_before bigint;BEGIN
 PERFORM lts_product_refresh_private_v415.enqueue(qa_v415.owner(1),'manual',false);
 PERFORM lts_product_refresh_private_v415.prepare(false);
 SELECT claim_token INTO first_token FROM lts_product_refresh_private_v415.queue WHERE user_id=qa_v415.owner(1);
 PERFORM lts_product_refresh_private_v415.prepare(false);
 PERFORM qa_v415.check('live lease is not claimed twice',
  (SELECT state='running' AND attempts=1 AND claim_token=first_token FROM lts_product_refresh_private_v415.queue WHERE user_id=qa_v415.owner(1)));
 UPDATE lts_product_refresh_private_v415.queue SET lease_expires_at=clock_timestamp()-interval '1 second' WHERE user_id=qa_v415.owner(1);
 PERFORM lts_product_refresh_private_v415.prepare(false);
 PERFORM qa_v415.check('expired lease receives new token and durable attempt',
  (SELECT state='running' AND attempts=2 AND claim_token<>first_token FROM lts_product_refresh_private_v415.queue WHERE user_id=qa_v415.owner(1)));
 count_before:=qa_v415.count_calls();
 PERFORM set_config('lts.product_refresh_claim',jsonb_build_object('user_id',qa_v415.owner(1),'token',first_token,'version','1','epoch','415')::text,false);
 j:=lts_product_refresh_private_v415.run_claimed();
 PERFORM qa_v415.check('stale private claim token cannot execute cache builders',
  j->>'skipped'='claim_changed' AND qa_v415.count_calls()=count_before);
END $lease$;

SELECT qa_v415.reset(true);
DO $manual_policy$
DECLARE j jsonb;before_payload jsonb;BEGIN
 SELECT payload INTO before_payload FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(1);
 PERFORM set_config('app.synthetic_uid',qa_v415.owner(1)::text,false);
 j:=lts_projection_private_v412.refresh();
 PERFORM qa_v415.check('manual projection refresh preserves policy contract and exposes pending completion',
  j->>'refreshed'='true' AND j#>>'{refresh,required}'='true' AND j#>>'{refresh,state}'='pending'
  AND j->'unknown_policy'='[false,null,1]'::jsonb AND j#>>'{policy,keep}'='original-policy'
  AND(SELECT count(*)=1 FROM qa_v415.calls WHERE stage='refresh_reference')
  AND(SELECT count(*)=1 FROM qa_v415.calls WHERE stage='materialize_fixed')
  AND NOT EXISTS(SELECT FROM qa_v415.calls WHERE stage IN('v2','v5','v36'))
  AND(SELECT payload->'unknown_future_branch'=before_payload->'unknown_future_branch' FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(1)));
END $manual_policy$;

SELECT qa_v415.check('financial source rows, original history, users and allowlist unchanged',
 qa_v415.source_hash()=(SELECT digest FROM qa_v415.original_sources));
SELECT jsonb_build_object('pass',bool_and(pass),'runtime',version(),
 'scope','Exact V415 migration; synthetic dependencies, rollback, access and queue contracts. Native multi-session gate is separate.',
 'checks',count(*),'results',jsonb_agg(to_jsonb(r) ORDER BY name),
 'installed',(SELECT jsonb_agg(jsonb_build_object('signature',signature,'md5',body_md5) ORDER BY signature) FROM qa_v415.installed_functions))
FROM qa_v415.results r;
