-- V170 compact yearly audit summary, derived from the proof attached to each
-- historical day.  This keeps production verification inexpensive and makes
-- missing/imbalanced days directly observable without returning the ledger.

create or replace function public.lts_flow_historical_cash_audit_summary_v1(
  p_flow jsonb
) returns jsonb
language sql
immutable
set search_path = public
as $function$
with days as (
  select (x->>'date')::date dt,
         coalesce((x#>>'{v170_cash_arithmetic,balanced}')::boolean,false) balanced,
         coalesce((x#>>'{v170_cash_arithmetic,arithmetic_gap_brl}')::numeric,0) gap
  from jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'::jsonb)) x
), audit as (
  select count(*) day_count,
         min(dt) first_day,
         max(dt) last_day,
         count(*) filter (where balanced and abs(gap)<=0.02) balanced_days,
         count(*) filter (where not balanced or abs(gap)>0.02) mismatch_days,
         coalesce(max(abs(gap)),0) max_abs_gap_brl
  from days
)
select p_flow || jsonb_build_object(
  'historical_cash_arithmetic_audit',jsonb_build_object(
    'version','tracked-bank-cash-audit-v1',
    'day_count',day_count,
    'first_day',first_day,
    'last_day',last_day,
    'balanced_days',balanced_days,
    'mismatch_days',mismatch_days,
    'max_abs_gap_brl',max_abs_gap_brl,
    'status',case when mismatch_days=0 then 'balanced' else 'mismatch' end
  )
)
from audit;
$function$;

revoke all on function public.lts_flow_historical_cash_audit_summary_v1(jsonb)
  from public, anon, authenticated;

do $migration$
declare
  v_definition text;
  v_before text;
begin
  select pg_get_functiondef('public.lts_browser_flow_v12(date,date)'::regprocedure)
    into v_definition;
  v_before:=v_definition;

  if position('lts_flow_historical_cash_audit_summary_v1' in v_definition)>0 then
    return;
  end if;

  v_definition:=replace(
    v_definition,
    'v_flow:=public.lts_flow_historical_cash_arithmetic_overlay_v1(v_uid,v_flow);',
    'v_flow:=public.lts_flow_historical_cash_arithmetic_overlay_v1(v_uid,v_flow);' || chr(10) ||
    '    v_flow:=public.lts_flow_historical_cash_audit_summary_v1(v_flow);'
  );

  if v_definition=v_before
    or position('lts_flow_historical_cash_audit_summary_v1' in v_definition)=0 then
    raise exception 'V170 cash-audit insertion point not found';
  end if;

  execute v_definition;
end
$migration$;

revoke all on function public.lts_browser_flow_v12(date,date) from public, anon;
grant execute on function public.lts_browser_flow_v12(date,date) to authenticated;
