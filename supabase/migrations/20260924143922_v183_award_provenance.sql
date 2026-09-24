-- Candidate-only, read-only provenance. No prices, quantities or cash are written.
create schema if not exists lts_award_private;
revoke all on schema lts_award_private from public, anon, authenticated;
grant usage on schema lts_award_private to authenticated;

create or replace function lts_award_private.provenance_v183()
returns jsonb language plpgsql security definer set search_path = ''
set timezone = 'America/Sao_Paulo' as $$
declare
  u uuid := public.lts_browser_assert_user_v1();
  groups jsonb;
begin
  with source_rows as (
    select s.*,
      case when lower(s.asset_type) like '%cash%' then 'cash_rsu' else 'rsu' end as kind,
      case when lower(s.asset_type) like '%cash%' then s.net_value_brl else s.gross_value_brl end as considered,
      case when nullif(s.metadata->>'manual_assumption_at','') is not null then 'manual'
           when s.source='liquidez_ativo' then 'historical_assumption' else 'unverified_assumption' end as provenance
    from public.lts_future_liquidity_schedule s
    where s.user_id=u and s.active
      and (upper(trim(s.asset_type))='RSU' or lower(s.asset_type) like '%cash%')
  ), grouped as (
    select kind, eligibility_date,
      sum(quantity) as quantity, sum(gross_value_brl) as gross,
      case when count(considered)=count(*) then sum(considered) end as considered,
      jsonb_agg(jsonb_build_object(
        'quantity',quantity,'unit_price_usd',unit_price_assumption,'fx_rate',fx_assumption,
        'gross_value_brl',gross_value_brl,'considered_value_brl',considered,
        'calculated_gross_brl',round(quantity*unit_price_assumption*fx_assumption,2),
        'calculation_delta_brl',gross_value_brl-round(quantity*unit_price_assumption*fx_assumption,2),
        'provenance',provenance,'market_quote_as_of',null,
        'assumption_recorded_at',nullif(metadata->>'manual_assumption_at',''),
        'source_updated_at',coalesce(nullif(metadata->>'legacy_updated_at',''),updated_at::text),
        'source',source,'settlement_days',settlement_days,
        'availability_basis','recorded_calendar_day_assumption'
      ) order by id) as components
    from source_rows group by kind,eligibility_date
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'group_key',kind||':'||eligibility_date::text,'asset_type',kind,
    'eligibility_date',eligibility_date,'quantity',quantity,
    'gross_value_brl',gross,'considered_value_brl',considered,'components',components
  ) order by eligibility_date,kind),'[]'::jsonb) into groups from grouped;
  return jsonb_build_object('version','award-provenance-v183','financial_effect','none',
    'read_at',now(),'groups',groups,'market_feed',false);
end $$;
revoke all on function lts_award_private.provenance_v183() from public,anon,authenticated;
grant execute on function lts_award_private.provenance_v183() to authenticated;

create or replace function public.lts_browser_award_provenance_v183()
returns jsonb language sql security invoker set search_path = '' as $$
  select lts_award_private.provenance_v183();
$$;
revoke all on function public.lts_browser_award_provenance_v183() from public,anon,authenticated;
grant execute on function public.lts_browser_award_provenance_v183() to authenticated;
