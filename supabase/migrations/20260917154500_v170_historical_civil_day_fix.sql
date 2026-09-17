-- Live follow-up for databases that already received the first V170 overlay.
-- Clean replays already contain this correction in the preceding migration.

do $migration$
declare
  v_definition text;
  v_before text;
begin
  select pg_get_functiondef(
    'public.lts_flow_historical_relative_balance_overlay_v1(uuid,jsonb)'::regprocedure
  ) into v_definition;
  v_before:=v_definition;

  if position('generate_series(0,v_max_date-v_origin)' in v_definition)>0 then
    return;
  end if;

  v_definition:=replace(
    v_definition,
    '    select g::date dt,',
    '    select (v_origin+g.day_offset)::date dt,'
  );
  v_definition:=replace(
    v_definition,
    '    from generate_series(v_origin,v_max_date,interval ''1 day'') g
    left join daily d on d.event_date=g::date',
    '    from generate_series(0,v_max_date-v_origin) g(day_offset)
    left join daily d on d.event_date=v_origin+g.day_offset'
  );

  if v_definition=v_before
    or position('generate_series(0,v_max_date-v_origin)' in v_definition)=0 then
    raise exception 'historical civil-day patch target not found';
  end if;

  execute v_definition;
end
$migration$;

revoke all on function public.lts_flow_historical_relative_balance_overlay_v1(uuid,jsonb)
  from public, anon, authenticated;
