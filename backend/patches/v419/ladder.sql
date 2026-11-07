CREATE OR REPLACE FUNCTION public.lts_dashboard_cash_ladder_from_flow_v1(p_user_id uuid,p_from date,p_to date,p_flow jsonb)
RETURNS TABLE(flow_date date,operational_cash numeric,d01_resource numeric,balance_after_d01 numeric,
 rsu_vested_today numeric,rsu_vested_scheduled numeric,balance_no_new_vesting numeric,
 balance_with_scheduled_vesting numeric,fgts_projected numeric,balance_with_fgts numeric)
LANGUAGE sql SET search_path='public' SET TimeZone='America/Sao_Paulo' AS $function$
WITH base AS (
 SELECT (d->>'date')::date dt,(d#>>'{fix86_columns,saldo_final}')::numeric bank_close,
 (d#>>'{fix86_columns,liq_d0_1_recurso}')::numeric d01_resource,
 (d#>>'{fix86_columns,rsus_vested}')::numeric scheduled_rsu,
 (d#>>'{fix86_columns,fgts}')::numeric daily_fgts
 FROM jsonb_array_elements(coalesce(p_flow->'days','[]'::jsonb))d
),params AS (
 SELECT (SELECT (canonical_value->>'total_available_brl')::numeric
 FROM public.lts_validated_lock_registry WHERE lock_key LIKE 'morgan_available_%'
 AND superseded_at IS NULL AND (canonical_value->>'as_of')::date<=current_date
 ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1) rsu_anchor
)
SELECT b.dt,b.bank_close,b.d01_resource,b.bank_close+b.d01_resource,p.rsu_anchor,b.scheduled_rsu,
 b.bank_close+b.d01_resource+p.rsu_anchor,b.bank_close+b.d01_resource+b.scheduled_rsu,b.daily_fgts,
 b.bank_close+b.d01_resource+b.scheduled_rsu+b.daily_fgts
FROM base b CROSS JOIN params p WHERE b.dt BETWEEN p_from AND p_to ORDER BY b.dt;
$function$;
