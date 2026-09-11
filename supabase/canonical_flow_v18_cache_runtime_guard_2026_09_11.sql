-- Keep the V18 Flow cache aligned with the browser reader and prevent a cold
-- 730-day rebuild from running inside the authenticated eight-second request.

create or replace function public.lts_flow_future_read_slice_v8(
  p_user_id uuid,
  p_from date,
  p_to date
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
set "TimeZone" to 'America/Sao_Paulo'
as $function$
declare
  c record;
  d jsonb;
  e jsonb;
  base jsonb;
  requested_horizon integer;
begin
  if p_from is null or p_to is null or p_from > p_to or p_from < current_date then
    raise exception 'invalid future range';
  end if;
  if p_to + 30 > current_date + 1500 then
    raise exception 'future range exceeds supported horizon';
  end if;

  select * into c
  from public.lts_flow_future_read_cache_v2
  where user_id = p_user_id
    and as_of = current_date
    and from_date <= p_from
    and to_date >= p_to + 30
    and engine_version = 'daily-flow-fix86-v18-future-award-economic-parity'
  order by refreshed_at desc
  limit 1;

  if not found then
    requested_horizon := greatest(60, (p_to - current_date) + 31);
    perform public.lts_flow_future_read_cache_refresh_v7(p_user_id, requested_horizon);

    select * into c
    from public.lts_flow_future_read_cache_v2
    where user_id = p_user_id
      and as_of = current_date
      and from_date <= p_from
      and to_date >= p_to + 30
      and engine_version = 'daily-flow-fix86-v18-future-award-economic-parity'
    order by refreshed_at desc
    limit 1;
  end if;

  if not found then
    raise exception 'future Flow cache could not cover requested range';
  end if;

  with all_src as (
    select x, (x->>'date')::date as dt
    from jsonb_array_elements(coalesce(c.payload->'days', '[]'::jsonb)) x
    where (x->>'date')::date between p_from and p_to + 30
  ), src as (
    select * from all_src where dt <= p_to
  ), adj as (
    select
      s.dt,
      jsonb_set(
        s.x,
        '{fix86_columns,liq_d30}',
        to_jsonb(
          coalesce(nullif(s.x#>>'{fix86_columns,liq_d0_1}', '')::numeric, 0)
          + coalesce((
              select sum(nullif(y.x#>>'{Consolidado,economic_net}', '')::numeric)
              from all_src y
              where y.dt > s.dt and y.dt <= s.dt + 30
            ), 0)
        ),
        true
      ) as x
    from src s
  )
  select coalesce(jsonb_agg(x order by dt), '[]'::jsonb)
  into d
  from adj;

  select coalesce(jsonb_agg(x order by x->>'event_date'), '[]'::jsonb)
  into e
  from jsonb_array_elements(coalesce(c.payload->'events', '[]'::jsonb)) x
  where (x->>'event_date')::date between p_from and p_to;

  base := (c.payload - 'days' - 'events') || jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'days', d,
    'events', e,
    'version', 'daily-flow-fix86-v18-future-cache-slice-v9-runtime-guard',
    'horizon_contract', 'requested-period-plus-30-days-v2',
    'cold_refresh_horizon_days', requested_horizon
  );
  return base;
end
$function$;

create or replace function public.lts_browser_flow_v11(p_from date, p_to date)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
set "TimeZone" to 'America/Sao_Paulo'
as $function$
declare
  uid uuid;
  v_email text := lower(coalesce(auth.jwt()->>'email', ''));
  oldj jsonb;
  histflow jsonb;
  cf jsonb;
  flow jsonb;
begin
  uid := public.lts_browser_assert_user_v1();
  if p_from is null or p_to is null or p_from > p_to then raise exception 'invalid range'; end if;
  if (p_to - p_from) > 12000 then raise exception 'range too large'; end if;

  if p_to < current_date then
    oldj := public.lts_browser_flow_v3(p_from, p_to);
    flow := public.lts_flow_historical_exact_transfer_overlay_v1(uid, p_from, p_to, oldj->'flow');
    flow := flow || jsonb_build_object('version', 'daily-flow-browser-v11-historical-exact-own-transfer-tags');
  elsif p_from >= current_date then
    cf := public.lts_flow_future_read_slice_v8(uid, p_from, p_to);
    flow := jsonb_build_object(
      'from', p_from,
      'to', p_to,
      'calculation_context_from', current_date,
      'historical', jsonb_build_object('days', '[]'::jsonb, 'events', '[]'::jsonb),
      'current_future', cf,
      'version', 'daily-flow-browser-v11-future-v18-cache-runtime-guard',
      'liquidity_history_contract', jsonb_build_object(
        'future_read_cache_v2', true,
        'bank_asset_movement_parity', true,
        'future_award_economic_parity', true,
        'cold_refresh_runtime_guard', true
      )
    );
  else
    oldj := public.lts_browser_flow_v3(p_from, current_date - 1);
    histflow := public.lts_flow_historical_exact_transfer_overlay_v1(uid, p_from, current_date - 1, oldj->'flow');
    cf := public.lts_flow_future_read_slice_v8(uid, current_date, p_to);
    flow := jsonb_build_object(
      'from', p_from,
      'to', p_to,
      'calculation_context_from', p_from,
      'historical', histflow->'historical',
      'current_future', cf,
      'version', 'daily-flow-browser-v11-mixed-historical-tags-future-v18-runtime-guard',
      'liquidity_history_contract', coalesce(histflow->'liquidity_history_contract', '{}'::jsonb)
        || jsonb_build_object(
          'future_read_cache_v2', true,
          'bank_asset_movement_parity', true,
          'future_award_economic_parity', true,
          'cold_refresh_runtime_guard', true
        ),
      'historical_own_transfer_contract', histflow->'historical_own_transfer_contract'
    );
  end if;

  insert into public.lts_access_audit(user_id, email, action, meta)
  values (
    uid,
    v_email,
    'browser_rpc_flow_read',
    jsonb_build_object(
      'rpc_version', 15,
      'from', p_from,
      'to', p_to,
      'historical_exact_own_transfer_tags', p_from < current_date,
      'future_v18_cache', p_to >= current_date,
      'future_award_economic_parity', p_to >= current_date,
      'cold_refresh_runtime_guard', p_to >= current_date
    )
  );
  return jsonb_build_object('ok', true, 'flow', flow);
end
$function$;

create or replace function public.lts_browser_flow_mutate_v2(
  p_action text,
  p_source text,
  p_source_ref text,
  p_payload jsonb,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
set "TimeZone" to 'America/Sao_Paulo'
as $function$
declare
  u uuid;
  j jsonb;
begin
  u := public.lts_browser_assert_user_v1();
  j := public.lts_flow_mutate_v1(
    u,
    p_action,
    p_source,
    p_source_ref,
    coalesce(p_payload, '{}'::jsonb),
    p_idempotency_key
  );
  delete from public.lts_flow_future_read_cache where user_id = u;
  delete from public.lts_flow_future_read_cache_v2 where user_id = u;
  return j || jsonb_build_object(
    'future_read_cache_invalidated', true,
    'future_read_cache_v2_invalidated', true
  );
end
$function$;

create or replace function public.lts_refresh_product_read_cache_operational_v5(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
set "TimeZone" to 'America/Sao_Paulo'
as $function$
declare
  base_result jsonb;
  flow_result jsonb;
begin
  base_result := public.lts_refresh_product_read_cache_operational_v4(p_user_id);
  flow_result := public.lts_flow_future_read_cache_refresh_v7(p_user_id, 730);
  return jsonb_build_object(
    'ok', coalesce((base_result->>'ok')::boolean, false) and coalesce((flow_result->>'ok')::boolean, false),
    'version', 'operational-refresh-v6-flow-v18-cache',
    'base_refresh', base_result,
    'flow_v18_refresh', flow_result
  );
end
$function$;

do $block$
declare
  target_job_id bigint;
begin
  select jobid into target_job_id
  from cron.job
  where jobname = 'lts_product_read_cache_operational_daily_v1'
  limit 1;

  if target_job_id is null then
    raise exception 'daily operational cache cron job not found';
  end if;

  perform cron.alter_job(
    job_id => target_job_id,
    command => 'select public.lts_refresh_product_read_cache_operational_v5(user_id) from public.lts_product_read_cache order by user_id;'
  );
end
$block$;

revoke execute on function public.lts_flow_future_read_slice_v8(uuid,date,date) from public, anon, authenticated;
revoke execute on function public.lts_refresh_product_read_cache_operational_v5(uuid) from public, anon, authenticated;

revoke execute on function public.lts_browser_flow_v11(date,date) from public, anon;
grant execute on function public.lts_browser_flow_v11(date,date) to authenticated;

revoke execute on function public.lts_browser_flow_mutate_v2(text,text,text,jsonb,text) from public, anon;
grant execute on function public.lts_browser_flow_mutate_v2(text,text,text,jsonb,text) to authenticated;

