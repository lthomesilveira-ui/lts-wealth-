-- Cold reads compute the requested horizon plus the reader's 30-day liquidity window.
-- The default and already wider cache horizons remain available.
CREATE OR REPLACE FUNCTION public.lts_flow_future_read_cache_refresh_v9(p_user_id uuid, p_days integer DEFAULT 730)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare d1 date:=current_date; d2 date:=current_date+least(1800,greatest(60,coalesce(p_days,730),coalesce((select to_date-current_date from public.lts_flow_future_read_cache_v2 where user_id=p_user_id and as_of=current_date),0))); j jsonb; t0 timestamptz:=clock_timestamp();
begin
  j:=public.lts_daily_flow_fix86_v20(p_user_id,d1,d2);
  insert into public.lts_flow_future_read_cache_v2(user_id,as_of,from_date,to_date,engine_version,payload,refreshed_at)
  values(p_user_id,d1,d1,d2,j->>'version',j,now())
  on conflict(user_id) do update set as_of=excluded.as_of,from_date=excluded.from_date,to_date=excluded.to_date,
    engine_version=excluded.engine_version,payload=excluded.payload,refreshed_at=excluded.refreshed_at;
  return jsonb_build_object('ok',true,'as_of',d1,'to',d2,'days',jsonb_array_length(coalesce(j->'days','[]'::jsonb)),
    'events',jsonb_array_length(coalesce(j->'events','[]'::jsonb)),'engine_version',j->>'version',
    'elapsed_ms',round((extract(epoch from(clock_timestamp()-t0))*1000)::numeric,1));
end
$function$
