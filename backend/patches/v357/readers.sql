DO $lease$
DECLARE t regprocedure:='public.lts_browser_dashboard_cockpit_v1()'::regprocedure;d text;a jsonb;
BEGIN
 SELECT pg_get_functiondef(oid),to_jsonb(p)-'prosrc' INTO d,a FROM pg_proc p WHERE oid=t;
 IF md5(d)<>'1206b7f59133a051cb07aa71963fe11e' THEN RAISE EXCEPTION 'V357_SOURCE_CHANGED: lts_browser_dashboard_cockpit_v1'; END IF;
 EXECUTE $definition$CREATE OR REPLACE FUNCTION public.lts_browser_dashboard_cockpit_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '45s'
AS $function$
DECLARE v269_revision text;
  u uuid;
  c record;
  pc timestamptz;
  j jsonb;
  w jsonb;
  v_had_cache boolean:=false;
  v_refreshed boolean:=false;
begin
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
  u:=public.lts_browser_assert_user_v1();

  perform public.lts_apply_current_liquidity_anchor_v1(u);

  select refreshed_at,payload->'wealth_executive'
  into pc,w
  from public.lts_product_read_cache
  where user_id=u;

  select * into c
  from public.lts_dashboard_cockpit_cache
  where user_id=u;
  v_had_cache:=found;

  if not v_had_cache
     or c.as_of<>current_date
     or c.source_product_refreshed_at is distinct from pc then
    j:=public.lts_refresh_dashboard_cockpit_v1(u);
    v_refreshed:=true;
  else
    j:=c.payload;
  end if;

  -- Prefer the already-reconciled canonical product cache. Only recompute the
  -- expensive wealth report when the cache is absent or predates the current
  -- effective-position reconciliation contract.
  if w is null
     or coalesce(w->>'reconciliation_version','')<>'wealth-summary-current-effective-v240' then
    w:=public.lts_wealth_executive_report_v5(u);
  end if;

  j:=jsonb_set(
    j,
    '{wealth}',
    coalesce(j->'wealth','{}'::jsonb) || jsonb_build_object(
      'net_worth_central',w#>'{summary,net_worth_central}',
      'known_debt_total',w#>'{summary,known_debt_total}',
      'assets_central',w#>'{summary,assets_central}',
      'distribution',coalesce(w->'distribution','[]'::jsonb),
      'reconciliation_version',w->'reconciliation_version'
    ),
    true
  );

  j:=jsonb_set(j,'{cards}',public.lts_card_operating_overlay_v355(coalesce(j->'cards','{}'),public.lts_card_cycles_presentation_v355(u),current_date),true);

  j:=jsonb_set(j,'{work,top_actions}',public.lts_dashboard_cockpit_top_actions_v1(u),true);

  if nullif(j#>>'{planning_audited,first_negative_date}','') is null
     and nullif(j#>>'{planning_audited,first_uncovered_gap_date}','') is not null then
    j:=jsonb_set(
      j,
      '{planning_audited,first_negative_date}',
      j#>'{planning_audited,first_uncovered_gap_date}',
      true
    );
  end if;

  -- Avoid an unnecessary write on every browser read. A refreshed cockpit is
  -- already persisted by the refresh routine; otherwise persist only a real
  -- overlay change (for example a newly available reconciliation field).
  if not v_refreshed and v_had_cache and c.payload is distinct from j then
    update public.lts_dashboard_cockpit_cache
    set payload=j
    where user_id=u;
  end if;

  j:=public.lts_current_debt_overlay_v357(j,public.lts_debt_evidence_read_v357(u,current_date),'cockpit');
  RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,j);
end
$function$
$definition$;
 IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE oid=t)
 THEN RAISE EXCEPTION 'V357_ATTRIBUTES_CHANGED: lts_browser_dashboard_cockpit_v1'; END IF;
END $lease$;

DO $lease$
DECLARE t regprocedure:='public.lts_browser_product_v1()'::regprocedure;d text;a jsonb;
BEGIN
 SELECT pg_get_functiondef(oid),to_jsonb(p)-'prosrc' INTO d,a FROM pg_proc p WHERE oid=t;
 IF md5(d)<>'d599147675ed01e0b0f3bc7a4e8204b0' THEN RAISE EXCEPTION 'V357_SOURCE_CHANGED: lts_browser_product_v1'; END IF;
 EXECUTE $definition$CREATE OR REPLACE FUNCTION public.lts_browser_product_v1()
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
$function$
$definition$;
 IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE oid=t)
 THEN RAISE EXCEPTION 'V357_ATTRIBUTES_CHANGED: lts_browser_product_v1'; END IF;
END $lease$;

DO $lease$
DECLARE t regprocedure:='public.lts_browser_wealth_detail_v242()'::regprocedure;d text;a jsonb;
BEGIN
 SELECT pg_get_functiondef(oid),to_jsonb(p)-'prosrc' INTO d,a FROM pg_proc p WHERE oid=t;
 IF md5(d)<>'7fc93a5a837f9af25b21a9fd851e3d3f' THEN RAISE EXCEPTION 'V357_SOURCE_CHANGED: lts_browser_wealth_detail_v242'; END IF;
 EXECUTE $definition$CREATE OR REPLACE FUNCTION public.lts_browser_wealth_detail_v242()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1(); j jsonb; a jsonb; cash jsonb; s jsonb; summary jsonb; delta numeric; key text; d0_delta numeric;
BEGIN
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
 j:=public.lts_browser_wealth_detail_v4();
 a:=public.lts_liquidity_adjustments_v242(u,current_date);
 cash:=public.lts_browser_cash_today_v242();
 s:=j->'rsu_summary';
 summary:=j#>'{wealth,summary}';
 d0_delta:=coalesce((j#>>'{wealth,liquidity,d0}')::numeric,0)-(cash->>'d0')::numeric;
 j:=jsonb_set(j,'{rsu_summary}',s||jsonb_build_object('available_total_brl',cash->'brokerage_available','settled_withdrawals_brl',a->'brokerage_settled_withdrawals','component_position_requires_new_statement',(a->>'brokerage_settled_withdrawals')::numeric>0));
 j:=jsonb_set(j,'{wealth,liquidity}',coalesce(j#>'{wealth,liquidity}','{}')||jsonb_build_object('bank_cash',cash->'cash','fgts_contingency',cash->'fgts','d0',cash->'d0'));
 j:=jsonb_set(j,'{morgan_statement,available_after_settled_transfers_brl}',cash->'brokerage_available');
 j:=jsonb_set(j,'{current_liquidity}',cash-'day');
 j:=jsonb_set(j,'{wealth,liquidity}',coalesce(j#>'{wealth,liquidity}','{}')||jsonb_build_object('d3',cash->'brokerage_available','through_d3',cash->'available_total'));
 j:=jsonb_set(j,'{wealth,distribution}',coalesce((SELECT jsonb_agg(x||CASE x->>'name' WHEN 'Liquidez até D+3' THEN jsonb_build_object('value',cash->'available_total','detail','Contas, aplicações e ações') WHEN 'FGTS' THEN jsonb_build_object('value',cash->'fgts','detail','Saldo restrito') ELSE '{}'::jsonb END) FROM jsonb_array_elements(coalesce(j#>'{wealth,distribution}','[]'))x),'[]'));
 delta:=d0_delta+(a->>'brokerage_settled_withdrawals')::numeric+coalesce((summary->>'restricted_contingency')::numeric,0)-(cash->>'fgts')::numeric;
 FOREACH key IN ARRAY ARRAY['assets_central','net_worth_central','net_worth_low','net_worth_high'] LOOP
  IF summary ? key THEN summary:=jsonb_set(summary,ARRAY[key],to_jsonb((summary->>key)::numeric-delta)); END IF;
 END LOOP;
 summary:=summary||jsonb_build_object('liquidity_through_d3',cash->'available_total','restricted_contingency',cash->'fgts');
 IF (summary->>'assets_central')::numeric>0 THEN summary:=summary||jsonb_build_object('cipo_share_of_assets_pct',round((j#>>'{wealth,assets,cipo_396,market_central}')::numeric/(summary->>'assets_central')::numeric*100,1),'known_debt_to_assets_pct',round((summary->>'known_debt_total')::numeric/(summary->>'assets_central')::numeric*100,1)); END IF;
 j:=jsonb_set(j,'{wealth,summary}',summary);
 IF j#>'{wealth_v167,assets_central_including_pensions}' IS NOT NULL THEN j:=jsonb_set(j,'{wealth_v167,assets_central_including_pensions}',to_jsonb((j#>>'{wealth_v167,assets_central_including_pensions}')::numeric-delta)); END IF;
 IF j#>'{wealth_v167,net_worth_central_including_pensions}' IS NOT NULL THEN j:=jsonb_set(j,'{wealth_v167,net_worth_central_including_pensions}',to_jsonb((j#>>'{wealth_v167,net_worth_central_including_pensions}')::numeric-delta)); END IF;
 -- v309-dated-contract-state: compatibility fields share the current canonical contract view.
 j:=jsonb_set(j,'{commitments}',coalesce(j#>'{financing,summary}','null'::jsonb));
 j:=jsonb_set(j,'{documentary_commitments}',coalesce(j#>'{financing,documentary}','null'::jsonb));
 j:=jsonb_set(j,'{cipo_detail,documentary_contractual_outflow_brl}',coalesce((SELECT c->'documentary_remaining_scheduled_outflow' FROM jsonb_array_elements(CASE WHEN jsonb_typeof(j#>'{financing,summary,commitments}')='array' THEN j#>'{financing,summary,commitments}' ELSE '[]'::jsonb END) c WHERE c->>'id'='cipo_396'),'null'::jsonb));
 j:=jsonb_set(j,'{cipo_detail,contractual_outflow_current_terms_brl}',coalesce((SELECT c->'remaining_scheduled_outflow_current_terms' FROM jsonb_array_elements(CASE WHEN jsonb_typeof(j#>'{financing,summary,commitments}')='array' THEN j#>'{financing,summary,commitments}' ELSE '[]'::jsonb END) c WHERE c->>'id'='cipo_396'),'null'::jsonb));
 j:=j||jsonb_build_object('contract_schedule_revision','v309-dated-contract-state');
 j:=public.lts_current_debt_overlay_v357(j,public.lts_debt_evidence_projection_v357(j#>'{financing,summary}',current_date),'wealth');
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,j||jsonb_build_object('brokerage_reference',public.lts_brokerage_reference_v352(u),'reader_revision','v242-settled-resource-transfers'));
END $function$
$definition$;
 IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE oid=t)
 THEN RAISE EXCEPTION 'V357_ATTRIBUTES_CHANGED: lts_browser_wealth_detail_v242'; END IF;
END $lease$;
