-- Keep the existing ladder arithmetic; evaluate dated reference sources once.
CREATE OR REPLACE FUNCTION public.lts_dashboard_cash_ladder_from_flow_v229(p_user_id uuid,p_from date,p_to date,p_flow jsonb)
RETURNS TABLE(flow_date date,operational_cash numeric,d01_resource numeric,balance_after_d01 numeric,rsu_vested_today numeric,rsu_vested_scheduled numeric,balance_no_new_vesting numeric,balance_with_scheduled_vesting numeric,fgts_projected numeric,balance_with_fgts_projected numeric)
LANGUAGE sql SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $function$
-- v399-materialized-independent-ladder
WITH base AS MATERIALIZED(
 SELECT(d->>'date')::date dt,(d#>>'{fix86_columns,saldo_final}')::numeric bank_close,(d#>>'{fix86_columns,liq_d0_1_recurso}')::numeric d01_resource
 FROM jsonb_array_elements(coalesce(p_flow->'days','[]'))d
),awards AS MATERIALIZED(
 SELECT s.eligibility_date+s.settlement_days available_date,
 CASE WHEN lower(s.asset_type)LIKE'%cash%'THEN coalesce(s.net_value_brl,s.gross_value_brl)ELSE coalesce(s.gross_value_brl,s.net_value_brl)END value
 FROM public.lts_future_liquidity_effective_v290 s WHERE s.user_id=p_user_id AND s.active
 AND(upper(trim(s.asset_type))='RSU'OR lower(s.asset_type)LIKE'%cash%')
),fgts AS MATERIALIZED(
 SELECT(SELECT effective_value_brl FROM public.lts_asset_position_effective_v1(p_user_id,current_date)WHERE asset_type='FGTS'ORDER BY documented_as_of DESC,asset_position_id DESC LIMIT 1) value
),lay AS MATERIALIZED(
 SELECT b.dt flow_date,f.value fgts_value,coalesce((SELECT sum(a.value)FROM awards a WHERE a.available_date<=b.dt),0)::numeric vested_rsu_value
 FROM base b JOIN base d ON d.dt=b.dt CROSS JOIN fgts f
),params AS MATERIALIZED(
 SELECT(public.lts_open_finance_current_bank_position_v1(p_user_id)->>'bank_cash')::numeric bank_anchor,
 public.lts_cofrinho_effective_locked_v245(p_user_id,current_date)d0_anchor,
 coalesce((SELECT(canonical_value->>'total_available_brl')::numeric FROM public.lts_validated_lock_registry WHERE lock_key LIKE'morgan_available_%'AND superseded_at IS NULL AND(canonical_value->>'as_of')::date<=current_date ORDER BY(canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1),0)rsu_anchor
),anchor AS MATERIALIZED(
 SELECT(SELECT bank_anchor FROM params)-coalesce((SELECT bank_close FROM base WHERE dt=current_date),(SELECT bank_anchor FROM params))bank_delta,
 (SELECT d0_anchor FROM params)-coalesce((SELECT d01_resource FROM base WHERE dt=current_date),(SELECT d0_anchor FROM params))d0_delta,
 (SELECT rsu_anchor FROM params)-coalesce((SELECT vested_rsu_value FROM lay WHERE flow_date=current_date),(SELECT rsu_anchor FROM params))rsu_delta
)
SELECT b.dt,b.bank_close+a.bank_delta,b.d01_resource+a.d0_delta,b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta,
 p.rsu_anchor,l.vested_rsu_value+a.rsu_delta,
 b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta+p.rsu_anchor,
 b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta+l.vested_rsu_value+a.rsu_delta,
 l.fgts_value,b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta+l.vested_rsu_value+a.rsu_delta+l.fgts_value
FROM base b JOIN lay l ON l.flow_date=b.dt CROSS JOIN params p CROSS JOIN anchor a ORDER BY b.dt;
$function$;
