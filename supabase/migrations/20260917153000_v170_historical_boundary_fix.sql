-- V170 follow-up: the legacy historical reader treats its upper boundary as
-- exclusive. Restore the requested final historical day (including events)
-- before applying the V170 relative-balance overlay.

create or replace function public.lts_browser_flow_v12(p_from date,p_to date)
returns jsonb
language plpgsql
security definer
set search_path = public
set "TimeZone" = 'America/Sao_Paulo'
as $function$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_base jsonb;
  v_flow jsonb;
  v_hist_end date;
  v_boundary jsonb;
  v_boundary_day jsonb;
  v_days jsonb;
  v_events jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
  if (p_to-p_from)>12000 then raise exception 'range too large'; end if;

  v_base:=public.lts_browser_flow_v11(p_from,p_to);
  v_flow:=v_base->'flow';

  if p_from<current_date then
    v_hist_end:=least(p_to,current_date-1);

    if v_hist_end>=p_from and not exists (
      select 1
      from jsonb_array_elements(coalesce(v_flow#>'{historical,days}','[]'::jsonb)) d(x)
      where d.x->>'date'=v_hist_end::text
    ) then
      v_boundary:=public.lts_browser_flow_v3(v_hist_end,v_hist_end+1)->'flow';
      v_boundary:=public.lts_flow_historical_exact_transfer_overlay_v1(
        v_uid,v_hist_end,v_hist_end,v_boundary
      );
      v_boundary:=public.lts_flow_documentary_close_overlay_v1(v_uid,v_boundary);
      v_boundary:=public.lts_flow_classification_source_overlay_v1(v_uid,v_boundary);
      v_boundary:=public.lts_flow_historical_balance_truth_overlay_v1(v_uid,v_boundary);

      select d.x into v_boundary_day
      from jsonb_array_elements(coalesce(v_boundary#>'{historical,days}','[]'::jsonb)) d(x)
      where d.x->>'date'=v_hist_end::text
      limit 1;

      if v_boundary_day is not null then
        select coalesce(jsonb_agg(q.x order by q.x->>'date'),'[]'::jsonb)
          into v_days
        from (
          select d.x
          from jsonb_array_elements(coalesce(v_flow#>'{historical,days}','[]'::jsonb)) d(x)
          union all
          select v_boundary_day
        ) q;
        v_flow:=jsonb_set(v_flow,'{historical,days}',v_days,true);
      end if;

      select coalesce(jsonb_agg(q.x order by q.x->>'event_date',q.x->>'source_ref'),'[]'::jsonb)
        into v_events
      from (
        select distinct z.x
        from (
          select e.x
          from jsonb_array_elements(coalesce(v_flow#>'{historical,events}','[]'::jsonb)) e(x)
          union all
          select e.x
          from jsonb_array_elements(coalesce(v_boundary#>'{historical,events}','[]'::jsonb)) e(x)
          where e.x->>'event_date'=v_hist_end::text
        ) z
      ) q;
      v_flow:=jsonb_set(v_flow,'{historical,events}',v_events,true);
    end if;

    v_flow:=public.lts_flow_historical_relative_balance_overlay_v1(v_uid,v_flow);
  end if;
  if p_to>=current_date then
    v_flow:=public.lts_flow_morgan_available_overlay_v1(v_uid,v_flow);
  end if;

  v_flow:=v_flow
    || jsonb_build_object(
      'from',p_from,
      'to',p_to,
      'version','daily-flow-browser-v12-v170-auditable-balances',
      'historical_upper_boundary_inclusive',true
    );
  return jsonb_build_object('ok',true,'flow',v_flow);
end
$function$;

revoke all on function public.lts_browser_flow_v12(date,date) from public, anon;
grant execute on function public.lts_browser_flow_v12(date,date) to authenticated;
