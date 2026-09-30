-- Preserve the V181 engine output while assembling future days in one pass.
CREATE OR REPLACE FUNCTION public.lts_daily_flow_fix86_v19(p_user_id uuid, p_from date DEFAULT CURRENT_DATE, p_to date DEFAULT (CURRENT_DATE + '1 year'::interval))
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare base jsonb; d jsonb; dt date; rsu_remaining numeric; cash_remaining numeric; base_after_fgts numeric; out_days jsonb:='[]'::jsonb; out_events jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
  base:=public.lts_daily_flow_fix86_v14(p_user_id,p_from,p_to);
  -- Aggregate once instead of repeatedly copying a growing JSON array.
  -- Identical fields, availability dates and input ordering.
  with schedule as materialized (
    select upper(trim(asset_type)) kind,lower(asset_type) lower_kind,
      eligibility_date+settlement_days available_date,
      coalesce(gross_value_brl,net_value_brl) rsu_value,
      coalesce(net_value_brl,gross_value_brl) cash_value
    from public.lts_future_liquidity_schedule where user_id=p_user_id and active=true
  ), valued as (
    select x.d,x.ordinality,
      coalesce(nullif(x.d#>>'{fix86_columns,saldo_apos_fgts}','')::numeric,
        coalesce(nullif(x.d#>>'{fix86_columns,saldo_apos_rsu}','')::numeric,0)
        +coalesce(nullif(x.d#>>'{fix86_columns,fgts}','')::numeric,0)) base_total,
      s.rsu_remaining,s.cash_remaining
    from jsonb_array_elements(coalesce(base->'days','[]'::jsonb)) with ordinality x(d,ordinality)
    cross join lateral (
      select coalesce(sum(rsu_value) filter(where kind='RSU' and available_date>(x.d->>'date')::date),0) rsu_remaining,
        coalesce(sum(cash_value) filter(where lower_kind like '%cash%' and available_date>(x.d->>'date')::date),0) cash_remaining
      from schedule
    ) s
  )
  select coalesce(jsonb_agg(
    jsonb_set(jsonb_set(jsonb_set(v.d,
      '{fix86_columns,rsus_futuras}',to_jsonb(v.rsu_remaining),true),
      '{fix86_columns,cash_awards_futuros}',to_jsonb(v.cash_remaining),true),
      '{fix86_columns,posicao_economica_total}',to_jsonb(v.base_total+v.rsu_remaining+v.cash_remaining),true)
    order by v.ordinality),'[]'::jsonb) into out_days from valued v;
  select coalesce(jsonb_agg(e order by e->>'event_date',e->>'source_ref'),'[]'::jsonb) into out_events from (
    select value e from jsonb_array_elements(coalesce(base->'events','[]'::jsonb))
    union all
    select jsonb_build_object('event_date',(s.eligibility_date+s.settlement_days)::date,'account','Corretora','description','Cash RSU disponível','signed_amount',coalesce(s.net_value_brl,s.gross_value_brl),'category','Cash RSU','source','future_cash_rsu','source_ref',s.id,'status','expected','editable',false,'availability_from_vesting',true)
    from public.lts_future_liquidity_schedule s where s.user_id=p_user_id and s.active=true and lower(s.asset_type) like '%cash%' and (s.eligibility_date+s.settlement_days)::date between p_from and p_to
  ) q;
  return (base-'days'-'events')||jsonb_build_object('days',out_days,'events',out_events,'version','daily-flow-fix86-v19-cash-rsu-availability','future_awards_contract',jsonb_build_object('availability_rule','eligibility_date_plus_settlement_days','cash_rsu_net_factor',0.70,'cash_rsu_enters_projected_liquidity_on_available_date',true,'no_award_before_availability',true));
end
$function$
;
