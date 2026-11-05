-- Exact existing function definitions captured read-only for migration guard tests.
-- Definitions contain no production financial rows; permission metadata is preserved.

-- lts_projection_private_v412.invalidate_reads(uuid): canonical pg_get_functiondef MD5 1f7467d92ff89ddc37a4e501088ebbaa
CREATE OR REPLACE FUNCTION lts_projection_private_v412.invalidate_reads(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
 IF p_user_id IS NULL THEN RAISE EXCEPTION 'Invalid projection owner';END IF;
 DELETE FROM public.lts_flow_future_read_cache WHERE user_id=p_user_id;
 DELETE FROM public.lts_flow_future_read_cache_v2 WHERE user_id=p_user_id;
 DELETE FROM public.lts_v229_read_cache WHERE user_id=p_user_id;
 DELETE FROM public.lts_dashboard_cockpit_cache WHERE user_id=p_user_id;
 DELETE FROM public.lts_product_read_cache WHERE user_id=p_user_id;
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
END $function$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.invalidate_reads(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.invalidate_reads(uuid) TO service_role;

-- lts_projection_private_v412.refresh(): canonical pg_get_functiondef MD5 2082f8834d179cb0cca0a431b3071ee1
CREATE OR REPLACE FUNCTION lts_projection_private_v412.refresh()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(u::text,166));
 PERFORM lts_projection_private_v412.refresh_reference(u,current_date);
 -- Reuse the installed V366/V376 materializer for its existing fixed plans.
 PERFORM public.lts_recurring_materialize_v366(u,current_date);
 PERFORM lts_projection_private_v412.invalidate_reads(u);
 result:=lts_projection_private_v412.read_policy();
 RETURN result||jsonb_build_object('refreshed',true);
END $function$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.refresh() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.refresh() TO authenticated;

-- public.lts_browser_product_v1(): canonical pg_get_functiondef MD5 cfd7d1aa8d5a2fa0b26a5926d21d7d5e
CREATE OR REPLACE FUNCTION public.lts_browser_product_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE v269_revision text;
  v_uid uuid;
  c jsonb;
  m jsonb;
  v_email text:=lower(coalesce(auth.jwt()->>'email',''));
  v_version text;
  v_cached_today date;
  v_mode text:='cache_hit_fresh';
  v_doc_change_version text;
  v_is_stale boolean:=false;
begin
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
  v_uid:=public.lts_browser_assert_user_v1();
  c:=public.lts_product_read_cached_v1(v_uid);
  v_version:=coalesce(c->>'payload_version','');

  begin
    v_cached_today:=nullif(c#>>'{payload,updates,freshness,today}','')::date;
  exception when others then
    v_cached_today:=null;
  end;
  v_doc_change_version:=coalesce(c#>>'{payload,updates,document_change_summary_version}','');

  if c is null or c->'payload' is null or v_version<>'lts-product-fix86-v36' then
    m:=public.lts_product_payload_fix86_v36(v_uid);
    insert into public.lts_product_read_cache(user_id,payload_version,payload,refreshed_at,source)
    values(v_uid,'lts-product-fix86-v36',m,now(),'browser_full_initialize_v36')
    on conflict(user_id) do update
      set payload_version=excluded.payload_version,
          payload=excluded.payload,
          refreshed_at=excluded.refreshed_at,
          source=excluded.source;
    c:=public.lts_product_read_cached_v1(v_uid);
    begin
      v_cached_today:=nullif(c#>>'{payload,updates,freshness,today}','')::date;
    exception when others then
      v_cached_today:=null;
    end;
    v_doc_change_version:=coalesce(c#>>'{payload,updates,document_change_summary_version}','');
    m:=c->'payload';
    v_mode:='full_initialize';
  else
    m:=c->'payload';
    v_is_stale := v_cached_today is distinct from current_date
                  or v_doc_change_version<>'document-change-summary-v1';
    if v_is_stale then
      v_mode:='cache_hit_stale_deferred';
    end if;
  end if;

  m:=public.lts_browser_enrich_flow_bank_gross_v1(m);
  m:=public.lts_current_debt_overlay_v357(m,public.lts_debt_evidence_read_v357(v_uid,current_date),'product');
  m:=public.lts_product_card_operating_overlay_v355(m,public.lts_card_cycles_presentation_v355(v_uid),current_date);

  insert into public.lts_access_audit(user_id,email,action,meta)
  values(
    v_uid,
    v_email,
    'browser_rpc_product_read',
    jsonb_build_object(
      'rpc_version',11,
      'payload_version',coalesce(c->>'payload_version','lts-product-fix86-v36'),
      'cached_today',v_cached_today,
      'server_today',current_date,
      'refresh_mode',v_mode,
      'refresh_required',v_is_stale,
      'document_change_summary_version',v_doc_change_version,
      'flow_bank_gross_basis','payload_events_reconciled_v1'
    )
  );

  RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,public.lts_product_card_completeness_v269(jsonb_build_object(
    'ok',true,
    'api_version',41,
    'product','lts-wealth-fix86-plus',
    'cache',jsonb_build_object(
      'refreshed_at',c->'refreshed_at',
      'payload_version',coalesce(c->>'payload_version','lts-product-fix86-v36'),
      'cached_today',v_cached_today,
      'server_today',current_date,
      'is_stale',v_is_stale,
      'refresh_required',v_is_stale,
      'refresh_mode',v_mode
    ),
    'mvp',m
  ),public.lts_c6_completeness_state_v269(v_uid)));
end;
$function$;
REVOKE ALL ON FUNCTION public.lts_browser_product_v1() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.lts_browser_product_v1() TO authenticated;
GRANT EXECUTE ON FUNCTION public.lts_browser_product_v1() TO service_role;

-- public.lts_product_read_cached_v1(uuid): canonical pg_get_functiondef MD5 5c6a41497cdd810ee95a6df7a7dae8bb
CREATE OR REPLACE FUNCTION public.lts_product_read_cached_v1(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
select case when c.user_id is null then null else jsonb_build_object(
  'payload',c.payload,
  'payload_version',c.payload_version,
  'refreshed_at',c.refreshed_at,
  'source',c.source
) end
from (select p_user_id as requested_user) r
left join public.lts_product_read_cache c on c.user_id=r.requested_user;
$function$;
REVOKE ALL ON FUNCTION public.lts_product_read_cached_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.lts_product_read_cached_v1(uuid) TO service_role;

-- public.lts_recurring_maintenance_v366(): canonical pg_get_functiondef MD5 07d6c08ee1044ff79e2243cd78cf23db
CREATE OR REPLACE FUNCTION public.lts_recurring_maintenance_v366()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
-- lts-projection-v412: reuse the existing daily schedule and fixed-plan engine.
DECLARE u uuid;results jsonb:='[]';reference_result jsonb;
BEGIN
 FOR u IN
  SELECT user_id FROM public.lts_recurring_plan_v366 WHERE active AND value_kind='fixed'
  UNION
  SELECT usuario_id FROM public.legacy_namespace WHERE chave='lts_owner_projection_policy_v412'
 LOOP
  reference_result:=lts_projection_private_v412.refresh_reference(u,current_date);
  results:=results||jsonb_build_array(public.lts_recurring_materialize_v366(u,current_date));
  IF EXISTS(SELECT 1 FROM public.legacy_namespace WHERE usuario_id=u AND chave='lts_owner_projection_policy_v412')
   THEN PERFORM lts_projection_private_v412.invalidate_reads(u);END IF;
 END LOOP;
 RETURN results;
END
$function$;
REVOKE ALL ON FUNCTION public.lts_recurring_maintenance_v366() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.lts_recurring_maintenance_v366() TO service_role;

-- public.lts_refresh_product_read_cache_operational_v5(uuid): canonical pg_get_functiondef MD5 1ec84b14b102731d33003f51fdb30e37
CREATE OR REPLACE FUNCTION public.lts_refresh_product_read_cache_operational_v5(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '45s'
AS $function$
DECLARE source_key text; old_key text; updates jsonb;
BEGIN
 source_key:=public.lts_dashboard_source_key_v240(p_user_id);
 select payload#>>'{canonical_summary,source_key}' into old_key from public.lts_product_read_cache where user_id=p_user_id;
 -- Background service refreshes the full maintenance inventory without invoking the legacy automatic classifier.
 -- Authenticated browser refreshes reuse that inventory and recalculate current evidence and payment confirmations.
 IF auth.uid() IS NULL AND old_key IS DISTINCT FROM source_key THEN
  updates:=public.lts_updates_fix86plus_v12(p_user_id);
  update public.lts_product_read_cache set payload=jsonb_set(payload,'{updates}',updates,true) where user_id=p_user_id;
 END IF;
 RETURN public.lts_apply_current_liquidity_anchor_v1(p_user_id);
END $function$;
REVOKE ALL ON FUNCTION public.lts_refresh_product_read_cache_operational_v5(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.lts_refresh_product_read_cache_operational_v5(uuid) TO service_role;

-- public.lts_refresh_product_read_cache_v2(uuid): canonical pg_get_functiondef MD5 b9bac9fc5c20cdacaa5acb102f8eaefb
CREATE OR REPLACE FUNCTION public.lts_refresh_product_read_cache_v2(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare v_payload jsonb;
begin
  v_payload:=public.lts_product_payload_fix86_v36(p_user_id);
  insert into public.lts_product_read_cache(user_id,payload_version,payload,refreshed_at,source)
  values(p_user_id,'lts-product-fix86-v36',v_payload,now(),'lts_product_payload_fix86_v36')
  on conflict(user_id) do update set payload_version=excluded.payload_version,payload=excluded.payload,refreshed_at=excluded.refreshed_at,source=excluded.source;
  return jsonb_build_object('ok',true,'payload_version','lts-product-fix86-v36','refreshed_at',now());
end
$function$;
REVOKE ALL ON FUNCTION public.lts_refresh_product_read_cache_v2(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.lts_refresh_product_read_cache_v2(uuid) TO service_role;

-- public.lts_has_card_presentation_v269(): canonical pg_get_functiondef MD5 5da1925e44cc8f3888130146e0256d76
CREATE OR REPLACE FUNCTION public.lts_has_card_presentation_v269()
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
DECLARE headers jsonb; request_path text:=current_setting('request.path',true);
BEGIN
 BEGIN headers:=coalesce(nullif(current_setting('request.headers',true),''),'{}')::jsonb;
 EXCEPTION WHEN invalid_text_representation THEN RETURN false; END;
 RETURN coalesce(jsonb_typeof(headers)='object' AND headers->>'x-client-info'='lts-wealth-v269-c6-completeness'
 AND request_path=ANY(ARRAY['/rpc/lts_browser_flow_v242','/rpc/lts_browser_card_cycles_v226','/rpc/lts_browser_card_cycles_v229','/rpc/lts_browser_card_detail_v226','/rpc/lts_browser_product_v1']),false);
END $function$;
REVOKE ALL ON FUNCTION public.lts_has_card_presentation_v269() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_has_card_presentation_v269() TO service_role;

-- public.lts_c6_completeness_state_v269(uuid): canonical pg_get_functiondef MD5 b987868460604430e0fd3c15cb22a9a0
CREATE OR REPLACE FUNCTION public.lts_c6_completeness_state_v269(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE fingerprint text; epoch bigint; result jsonb; cycles jsonb;
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
 END IF;
 RETURN result;
END $function$;
REVOKE ALL ON FUNCTION public.lts_c6_completeness_state_v269(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_c6_completeness_state_v269(uuid) TO service_role;

-- public.lts_product_card_completeness_v269(jsonb,jsonb): canonical pg_get_functiondef MD5 549ba955fe3388dec25584f41b85a534
CREATE OR REPLACE FUNCTION public.lts_product_card_completeness_v269(p_payload jsonb, p_state jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
DECLARE m jsonb; c jsonb; card jsonb; planning jsonb; wealth jsonb; f jsonb;
BEGIN
 IF p_state->>'complete' IS DISTINCT FROM 'false' THEN RETURN p_payload; END IF;
 m:=p_payload->'mvp';
 planning:=jsonb_build_object('complete',false,'status','incomplete','layers','[]'::jsonb,'gap_episodes','[]'::jsonb,
 'summary',jsonb_build_object('fgts_covers_horizon',NULL,'first_real_gap_date',NULL,'first_negative_even_with_fgts',NULL),
 'fgts_access',jsonb_build_object('covers_horizon',NULL));
 c:=coalesce(m->'dashboard_cockpit','{}'::jsonb)||jsonb_build_object('complete',false,'planning_audited',planning->'summary','horizons','[]'::jsonb,
 'cards',jsonb_build_object('complete',false,'open_cycles_total',NULL,'closed_or_due_total',NULL,'next_due',NULL),
 'expenses',jsonb_build_object('complete',false,'current_month',jsonb_build_object('spend',NULL,'top_categories','[]'::jsonb)));
 card:=coalesce(m->'card_operating','{}'::jsonb)||jsonb_build_object('complete',false,'open_cycles_total',NULL,'open_cycles','[]'::jsonb,'next_due',NULL,
 'contracted_installment_floor_total',NULL,'contracted_installment_floor_months','[]'::jsonb);
 wealth:=coalesce(m->'wealth_executive','{}'::jsonb)||jsonb_build_object('complete',false,'summary',coalesce(m#>'{wealth_executive,summary}','{}'::jsonb)||
 jsonb_build_object('known_debt_total',NULL,'net_worth_central',NULL,'net_worth_low',NULL,'net_worth_high',NULL,'known_debt_to_assets_pct',NULL));
 f:=m->'flow';
 IF f ? 'current_future' THEN
  f:=public.lts_flow_card_completeness_v269(jsonb_build_object('flow',f),p_state)->'flow';
 ELSIF f ? 'days' THEN
  f:=public.lts_flow_card_completeness_v269(jsonb_build_object('flow',jsonb_build_object('current_future',f)),p_state)#>'{flow,current_future}';
 END IF;
 m:=m||jsonb_build_object('complete',false,'incomplete_families',p_state->'incomplete_families','dashboard_cockpit',c,
 'planning_ladder',planning,'planning_executive',planning,'wealth_executive',wealth,'card_operating',card,'flow',f);
 RETURN p_payload||jsonb_build_object('complete',false,'incomplete_families',p_state->'incomplete_families','mvp',m);
END $function$;
REVOKE ALL ON FUNCTION public.lts_product_card_completeness_v269(jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_product_card_completeness_v269(jsonb,jsonb) TO service_role;
