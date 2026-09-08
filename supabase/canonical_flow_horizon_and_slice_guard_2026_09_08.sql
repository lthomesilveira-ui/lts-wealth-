-- LTS Wealth canonical Flow horizon + D+30 slice guard — 2026-09-08
-- Scope: preserve the V151+ daily Flow while making 31/12/2029 reachable.
-- No financial facts are inserted, updated, or deleted by this migration.

do $$
begin
  if to_regprocedure('public.lts_daily_flow_fix86_v18(uuid,date,date)') is null
     or to_regprocedure('public.lts_flow_future_read_cache_refresh_v7(uuid,integer)') is null
     or to_regprocedure('public.lts_flow_future_read_slice_v7(uuid,date,date)') is null then
    raise exception 'Flow horizon migration aborted; required canonical functions are missing';
  end if;
end
$$;

create or replace function public.lts_flow_future_read_cache_refresh_v7(
  p_user_id uuid,
  p_days integer default 730
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
set "TimeZone" to 'America/Sao_Paulo'
as $function$
declare
  d1 date := current_date;
  d2 date := current_date + greatest(30, least(coalesce(p_days, 730), 1500));
  j jsonb;
  t0 timestamptz := clock_timestamp();
  ms numeric;
begin
  j := public.lts_daily_flow_fix86_v18(p_user_id, d1, d2);

  insert into public.lts_flow_future_read_cache_v2(
    user_id, as_of, from_date, to_date, engine_version, payload, refreshed_at
  )
  values (p_user_id, d1, d1, d2, j->>'version', j, now())
  on conflict (user_id) do update
    set as_of = excluded.as_of,
        from_date = excluded.from_date,
        to_date = excluded.to_date,
        engine_version = excluded.engine_version,
        payload = excluded.payload,
        refreshed_at = excluded.refreshed_at;

  ms := round((extract(epoch from (clock_timestamp() - t0)) * 1000)::numeric, 1);
  return jsonb_build_object(
    'ok', true,
    'as_of', d1,
    'to', d2,
    'days', jsonb_array_length(coalesce(j->'days', '[]'::jsonb)),
    'events', jsonb_array_length(coalesce(j->'events', '[]'::jsonb)),
    'elapsed_ms', ms,
    'engine_version', j->>'version',
    'horizon_days', d2 - d1,
    'version', 'flow-future-read-cache-v8-horizon1500'
  );
end
$function$;

create or replace function public.lts_flow_future_read_slice_v7(
  p_user_id uuid,
  p_from date,
  p_to date
)
returns jsonb
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
    perform public.lts_flow_future_read_cache_refresh_v7(
      p_user_id,
      greatest(730, (p_to - current_date) + 31)
    );

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
    'version', 'daily-flow-fix86-v18-future-cache-slice-v8-horizon1500',
    'horizon_contract', 'requested-period-plus-30-days-v1'
  );
  return base;
end
$function$;

revoke execute on function public.lts_flow_future_read_cache_refresh_v7(uuid,integer)
  from public, anon, authenticated;
revoke execute on function public.lts_flow_future_read_slice_v7(uuid,date,date)
  from public, anon, authenticated;

do $$
declare
  v_refresh text;
  v_slice text;
begin
  select pg_get_functiondef('public.lts_flow_future_read_cache_refresh_v7(uuid,integer)'::regprocedure)
  into v_refresh;
  select pg_get_functiondef('public.lts_flow_future_read_slice_v7(uuid,date,date)'::regprocedure)
  into v_slice;

  if position('1500' in v_refresh) = 0
     or position('all_src' in v_slice) = 0
     or position('to_date >= p_to + 30' in v_slice) = 0 then
    raise exception 'Flow horizon migration postcondition failed';
  end if;

  if has_function_privilege('public', 'public.lts_flow_future_read_cache_refresh_v7(uuid,integer)', 'EXECUTE')
     or has_function_privilege('anon', 'public.lts_flow_future_read_cache_refresh_v7(uuid,integer)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.lts_flow_future_read_cache_refresh_v7(uuid,integer)', 'EXECUTE')
     or has_function_privilege('public', 'public.lts_flow_future_read_slice_v7(uuid,date,date)', 'EXECUTE')
     or has_function_privilege('anon', 'public.lts_flow_future_read_slice_v7(uuid,date,date)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.lts_flow_future_read_slice_v7(uuid,date,date)', 'EXECUTE') then
    raise exception 'Flow horizon migration ACL postcondition failed';
  end if;
end
$$;

notify pgrst, 'reload schema';
