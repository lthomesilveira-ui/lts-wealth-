DO $guard$BEGIN IF md5(pg_get_functiondef('public.lts_browser_card_cycles_v229()'::regprocedure))<>'68a6ba83a6e4024dc78a38d388038711'OR md5(pg_get_functiondef('public.lts_browser_card_cycles_v226()'::regprocedure))<>'3cc7826df478e7a440af1ab216c18751'THEN RAISE EXCEPTION 'V355_FINAL_CYCLE_SOURCE_CHANGED';END IF;END$guard$;

CREATE FUNCTION public.lts_card_cycles_presentation_v355(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid:=p_user_id; j jsonb; cards jsonb;
BEGIN
 j:=public.lts_card_read_finish_v269(u,public.lts_card_read_start_v269(u),public.lts_card_cycles_v226(u));
 WITH source_dates AS MATERIALIZED (
 SELECT public.lts_card_family_v226(s.normalized_payload->>'name',s.institution_name) family,
 max(coalesce(nullif(s.normalized_payload->>'as_of',''),nullif(s.normalized_payload->>'provider_updated_at',''),nullif(s.raw_payload->>'updatedAt',''))::timestamptz) source_updated_at,
 max(s.last_seen_at) received_at
 FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.resource_type='credit_card' AND s.provider_deleted_at IS NULL GROUP BY 1
 ) SELECT jsonb_agg(c||jsonb_build_object('source_updated_at',sd.source_updated_at,'received_at',sd.received_at,'source_time_basis','provider_resource_update')||jsonb_build_object('document_source_as_of',doc.as_of,'document_source_file',doc.source_file,'documented_supplement_items',doc.n)||CASE WHEN hint.amount IS NOT NULL AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(c->'cycles','[]'::jsonb)) q
 WHERE q->>'month'=((date_trunc('month',current_date)+interval '1 month')::date)::text) THEN jsonb_build_object(
 'cycles',coalesce(c->'cycles','[]'::jsonb)||jsonb_build_array(jsonb_build_object('month',(date_trunc('month',current_date)+interval '1 month')::date,'due_date',
 CASE WHEN c->>'last_due' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
 make_date(extract(year FROM current_date+interval '1 month')::int,extract(month FROM current_date+interval '1 month')::int,
 least(extract(day FROM (c->>'last_due')::date)::int,extract(day FROM date_trunc('month',current_date)+interval '2 months -1 day')::int)) END,
 'due_date_basis','estimate_from_received_due_day',
 'amount',hint.amount,'basis','user_confirmed_recurring_estimate','items',hint.items))) ELSE '{}'::jsonb END ORDER BY ord) INTO cards
 FROM jsonb_array_elements(j->'cards') WITH ORDINALITY src(c,ord)
 LEFT JOIN source_dates sd ON sd.family=c->>'family'
 LEFT JOIN LATERAL(SELECT max(d.source_as_of) as_of,min(d.source_file_ref) source_file,count(*) n
 FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=u AND d.family=c->>'family'
 AND d.reference_month=date_trunc('month',current_date)::date) doc ON true
 LEFT JOIN LATERAL(SELECT sum(h.amount) amount,jsonb_agg(jsonb_build_object('description',h.description,'amount',h.amount,'last4',c->>'last4','category',h.category,'category_basis','user_confirmed_recurring_estimate')) items
 FROM public.lts_v229_card_recurring_commitment h WHERE h.user_id=u AND h.active AND h.family=c->>'family') hint ON true;
 RETURN public.lts_card_documentary_payment_presentation_v272(u,j||jsonb_build_object('cards',cards,'recurring_estimates_separate',true));
END $function$
;
REVOKE ALL ON FUNCTION public.lts_card_cycles_presentation_v355(uuid)FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_cycles_presentation_v355(uuid)TO service_role;

DO $patch$DECLARE d text;a jsonb;t regprocedure:='public.lts_browser_card_cycles_v229()'::regprocedure;BEGIN
 SELECT pg_get_functiondef(oid),to_jsonb(p)-'prosrc'INTO d,a FROM pg_proc p WHERE oid=t;
 IF md5(d)<>'68a6ba83a6e4024dc78a38d388038711'THEN RAISE EXCEPTION 'V355_FINAL_READER_SOURCE_CHANGED: lts_browser_card_cycles_v229';END IF;
 EXECUTE $newdef$CREATE OR REPLACE FUNCTION public.lts_browser_card_cycles_v229()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1();rev text;BEGIN
 rev:=public.lts_card_read_start_v269(u);
 RETURN public.lts_card_read_finish_v269(u,rev,public.lts_card_cycles_presentation_v355(u));
END;
$function$
$newdef$;
 IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid=t)THEN RAISE EXCEPTION 'V355_FINAL_READER_ATTRIBUTES_CHANGED: lts_browser_card_cycles_v229';END IF;END$patch$;

DO $patch$DECLARE d text;a jsonb;t regprocedure:='public.lts_browser_dashboard_cockpit_v1()'::regprocedure;BEGIN
 SELECT pg_get_functiondef(oid),to_jsonb(p)-'prosrc'INTO d,a FROM pg_proc p WHERE oid=t;
 IF md5(d)<>'f3406987305e66c9d4dc91bba3cc08ea'THEN RAISE EXCEPTION 'V355_FINAL_READER_SOURCE_CHANGED: lts_browser_dashboard_cockpit_v1';END IF;
 EXECUTE $newdef$CREATE OR REPLACE FUNCTION public.lts_browser_dashboard_cockpit_v1()
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

  RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,j);
end
$function$
$newdef$;
 IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid=t)THEN RAISE EXCEPTION 'V355_FINAL_READER_ATTRIBUTES_CHANGED: lts_browser_dashboard_cockpit_v1';END IF;END$patch$;

DO $patch$DECLARE d text;a jsonb;t regprocedure:='public.lts_browser_product_v1()'::regprocedure;BEGIN
 SELECT pg_get_functiondef(oid),to_jsonb(p)-'prosrc'INTO d,a FROM pg_proc p WHERE oid=t;
 IF md5(d)<>'2b7fd28f2d6d4584f5b5a83dbfba9a19'THEN RAISE EXCEPTION 'V355_FINAL_READER_SOURCE_CHANGED: lts_browser_product_v1';END IF;
 EXECUTE $newdef$CREATE OR REPLACE FUNCTION public.lts_browser_product_v1()
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
$newdef$;
 IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid=t)THEN RAISE EXCEPTION 'V355_FINAL_READER_ATTRIBUTES_CHANGED: lts_browser_product_v1';END IF;END$patch$;

DO $patch$DECLARE d text;a jsonb;t regprocedure:='public.lts_card_operating_view_v3(uuid,date)'::regprocedure;BEGIN
 SELECT pg_get_functiondef(oid),to_jsonb(p)-'prosrc'INTO d,a FROM pg_proc p WHERE oid=t;
 IF md5(d)<>'39e9ea5e8576bc3ab6f242ae3b031670'THEN RAISE EXCEPTION 'V355_FINAL_READER_SOURCE_CHANGED: lts_card_operating_view_v3';END IF;
 EXECUTE $newdef$CREATE OR REPLACE FUNCTION public.lts_card_operating_view_v3(p_user_id uuid, p_as_of date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH prior(j)AS(
with b as (select public.lts_card_operating_view_v2(p_user_id,p_as_of) j),
     r as (select public.lts_card_classification_review_v2(p_user_id,100) j)
select (select j from b) || jsonb_build_object(
  'version','card-operating-v3-classification-parity',
  'classification_review',jsonb_build_object(
    'pending_groups',(select (j->>'pending_groups')::int from r),
    'pending_lines',(select (j->>'pending_lines')::int from r),
    'pending_value',(select (j->>'pending_value')::numeric from r),
    'safe_suggestion_groups',(select (j->>'safe_suggestion_groups')::int from r),
    'all_suggestion_groups',(select coalesce((j->>'all_suggestion_groups')::int,(j->>'safe_suggestion_groups')::int) from r)
  )
)
)SELECT CASE WHEN p_as_of=CURRENT_DATE THEN public.lts_card_operating_overlay_v355(j,public.lts_card_cycles_presentation_v355(p_user_id),p_as_of)ELSE j END FROM prior;
$function$
$newdef$;
 IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid=t)THEN RAISE EXCEPTION 'V355_FINAL_READER_ATTRIBUTES_CHANGED: lts_card_operating_view_v3';END IF;END$patch$;
