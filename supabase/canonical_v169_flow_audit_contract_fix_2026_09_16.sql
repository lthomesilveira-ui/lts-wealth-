-- V169 follow-up: post-position operational carry is an explicit, non-certified estimate,
-- not an unsupported historical balance leak.

create or replace function public.lts_flow_civil_day_audit_v1(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
declare
  y integer;
  d1 date;
  d2 date;
  j jsonb;
  days jsonb;
  events jsonb;
  expected integer;
  actual integer;
  distinct_days integer;
  net_mismatch integer;
  recurrence_mismatch integer;
  unsupported_balance_leaks integer;
  years jsonb:='[]'::jsonb;
begin
  for y in 2013..extract(year from current_date)::integer loop
    d1:=greatest(date '2013-10-10',make_date(y,1,1));
    d2:=least(current_date-1,make_date(y,12,31));
    if d2<d1 then continue; end if;
    j:=public.lts_daily_flow_full_query_v6(p_user_id,d1,d2);
    j:=public.lts_flow_historical_balance_truth_overlay_v1(p_user_id,j);
    days:=coalesce(j#>'{historical,days}','[]'::jsonb);
    events:=coalesce(j#>'{historical,events}','[]'::jsonb);
    expected:=d2-d1+1;
    actual:=jsonb_array_length(days);
    select count(distinct (x->>'date')::date)::integer into distinct_days from jsonb_array_elements(days) x;

    with ds as (
      select x,(x->>'date')::date dt,
             coalesce(nullif(x#>>'{summary,net}','')::numeric,0) summary_net,
             coalesce(nullif(x#>>'{summary,entries}','')::numeric,0) entries,
             coalesce(nullif(x#>>'{summary,exits}','')::numeric,0) exits,
             coalesce(nullif(x#>>'{Consolidado,net}','')::numeric,0) consolidated_net,
             nullif(x#>>'{Consolidado,relative_balance}','')::numeric relative_balance,
             lag(nullif(x#>>'{Consolidado,relative_balance}','')::numeric) over(order by (x->>'date')::date) prior_relative
      from jsonb_array_elements(days) x
    )
    select count(*) filter(where abs(summary_net-(entries-exits))>0.005 or abs(summary_net-consolidated_net)>0.005)::integer,
           count(*) filter(where prior_relative is not null and relative_balance is not null and abs(relative_balance-(prior_relative+consolidated_net))>0.005)::integer
      into net_mismatch,recurrence_mismatch
    from ds;

    select count(*)::integer into unsupported_balance_leaks
    from jsonb_array_elements(days) x
    where coalesce((x->>'absolute_balance_certified')::boolean,false)=false
      and nullif(x#>>'{Consolidado,bank_balance}','') is not null
      and coalesce(x->>'absolute_balance_basis','')<>'post_position_operational_carry';

    years:=years||jsonb_build_array(jsonb_build_object(
      'year',y,'from',d1,'to',d2,'expected_days',expected,'actual_days',actual,
      'distinct_days',distinct_days,'missing_days',expected-distinct_days,
      'duplicate_days',actual-distinct_days,'net_mismatches',net_mismatch,
      'relative_balance_mismatches',recurrence_mismatch,
      'unsupported_balance_leaks',unsupported_balance_leaks,
      'event_count',jsonb_array_length(events),
      'ok',actual=expected and distinct_days=expected and net_mismatch=0 and recurrence_mismatch=0 and unsupported_balance_leaks=0
    ));
  end loop;
  return jsonb_build_object(
    'version','flow-civil-day-audit-v1','available_from','2013-10-10','as_of',current_date,
    'years',years,
    'critical_years',jsonb_build_array(2018,2019,2020,2021),
    'all_ok',not exists(select 1 from jsonb_array_elements(years) x where not coalesce((x->>'ok')::boolean,false))
  );
end
$function$;

revoke all on function public.lts_flow_civil_day_audit_v1(uuid) from public,anon,authenticated;
