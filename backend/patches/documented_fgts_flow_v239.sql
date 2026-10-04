CREATE OR REPLACE FUNCTION public.lts_dashboard_cash_ladder_from_flow_v229(p_user_id uuid, p_from date, p_to date, p_flow jsonb)
 RETURNS TABLE(flow_date date, operational_cash numeric, d01_resource numeric, balance_after_d01 numeric, rsu_vested_today numeric, rsu_vested_scheduled numeric, balance_no_new_vesting numeric, balance_with_scheduled_vesting numeric, fgts_projected numeric, balance_with_fgts_projected numeric)
 LANGUAGE sql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with base as (
 select (d->>'date')::date dt,(d#>>'{fix86_columns,saldo_final}')::numeric bank_close,(d#>>'{fix86_columns,liq_d0_1_recurso}')::numeric d01_resource
 from jsonb_array_elements(coalesce(p_flow->'days','[]'::jsonb)) d
), lay as (
 select b.dt flow_date,(select effective_value_brl from public.lts_asset_position_effective_v1(p_user_id,current_date) where asset_type='FGTS' order by documented_as_of desc,asset_position_id desc limit 1) fgts_value,
 coalesce((select sum(case when lower(s.asset_type) like '%cash%' then coalesce(s.net_value_brl,s.gross_value_brl) else coalesce(s.gross_value_brl,s.net_value_brl) end)
  from public.lts_future_liquidity_schedule s where s.user_id=p_user_id and s.active
  and (upper(trim(s.asset_type))='RSU' or lower(s.asset_type) like '%cash%')
  and s.eligibility_date+s.settlement_days<=b.dt),0)::numeric vested_rsu_value
 from base b join jsonb_array_elements(p_flow->'days') d on (d->>'date')::date=b.dt
),
params as (
 select (public.lts_open_finance_current_bank_position_v1(p_user_id)->>'bank_cash')::numeric bank_anchor,
 (select (canonical_value->>'amount')::numeric from public.lts_validated_lock_registry where lock_key='itau_cofrinho_20260926' and superseded_at is null) d0_anchor,
 coalesce((select (canonical_value->>'total_available_brl')::numeric from public.lts_validated_lock_registry where lock_key='morgan_available_20260922' and superseded_at is null),0) rsu_anchor
), anchor as (
 select (select bank_anchor from params)-coalesce((select bank_close from base where dt=current_date),(select bank_anchor from params)) bank_delta,
 (select d0_anchor from params)-coalesce((select d01_resource from base where dt=current_date),(select d0_anchor from params)) d0_delta,
 (select rsu_anchor from params)-coalesce((select vested_rsu_value from lay where flow_date=current_date),(select rsu_anchor from params)) rsu_delta
)
select b.dt,b.bank_close+a.bank_delta,b.d01_resource+a.d0_delta,b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta,
p.rsu_anchor,l.vested_rsu_value+a.rsu_delta,
b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta+p.rsu_anchor,
b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta+l.vested_rsu_value+a.rsu_delta,
l.fgts_value,
b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta+l.vested_rsu_value+a.rsu_delta+l.fgts_value
from base b join lay l on l.flow_date=b.dt cross join params p cross join anchor a order by b.dt
$function$;

COMMENT ON FUNCTION public.lts_dashboard_cash_ladder_from_flow_v229(uuid,date,date,jsonb) IS 'V239: current/future Flow uses the same effective documented restricted FGTS position as Planning. No estimated future accrual; cash, D0 and vesting unchanged.';
