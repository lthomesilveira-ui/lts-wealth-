-- Synthetic values only. A future confirmation must not route an earlier day through the old generic asset subtraction.
INSERT INTO public.lts_validated_lock_registry(lock_key,canonical_value)VALUES('itau_cofrinho_fixture_20300104','{"as_of":"2030-01-04","amount":750}');
INSERT INTO public.asset_positions VALUES('44444444-4444-4444-8444-444444444446','11111111-1111-4111-8111-111111111111','cash_investment','Cofrinho Itaú','2030-01-04',750,'D+0',true,'{"validated_lock_key":"itau_cofrinho_fixture_20300104"}');

CREATE FUNCTION public.lts_browser_flow_v228(p_from date,p_to date)RETURNS jsonb LANGUAGE plpgsql AS $function$
DECLARE u uuid:='11111111-1111-4111-8111-111111111111';dt date:=p_from;d0 numeric:=1000;asset_net numeric;c jsonb:='{}';cofrinho jsonb:='{"as_of":"2030-01-04","amount":750}';added jsonb:='[{"event_date":"2030-01-02","signed_amount":100,"asset_movement":true},{"event_date":"2030-01-03","signed_amount":200,"asset_movement":true},{"event_date":"2030-01-03","signed_amount":1500,"asset_movement":true,"description":"FGTS"}]';
BEGIN
    IF dt>=(cofrinho->>'as_of')::date THEN d0:=(cofrinho->>'amount')::numeric;
    ELSE
     SELECT coalesce(sum((x->>'signed_amount')::numeric),0) INTO asset_net FROM jsonb_array_elements(added) x
      WHERE coalesce((x->>'asset_movement')::boolean,false) AND (x->>'event_date')::date<=dt;
     d0:=d0-asset_net;
    END IF;
RETURN jsonb_build_object('fix86_columns',c||jsonb_build_object('saldo_final',77,'liq_d0_1_recurso',d0,'saldo_apos_d0_1',77+d0,'rsus_vested',10,'saldo_apos_rsu',77+d0+10,'fgts',500,'saldo_apos_fgts',77+d0+10+500));
END $function$;

CREATE FUNCTION public.lts_browser_flow_pre_v238(p_from date,p_to date)RETURNS jsonb LANGUAGE plpgsql AS $function$
DECLARE u uuid:='11111111-1111-4111-8111-111111111111';dt date:=p_from;d0 numeric:=1000;asset_net numeric;c jsonb:='{}';cofrinho jsonb:='{"as_of":"2030-01-04","amount":750}';added jsonb:='[{"event_date":"2030-01-02","signed_amount":100,"asset_movement":true},{"event_date":"2030-01-03","signed_amount":200,"asset_movement":true},{"event_date":"2030-01-03","signed_amount":1500,"asset_movement":true,"description":"FGTS"}]';
BEGIN
    IF dt>=(cofrinho->>'as_of')::date THEN d0:=(cofrinho->>'amount')::numeric;
    ELSE
     SELECT coalesce(sum((x->>'signed_amount')::numeric),0) INTO asset_net FROM jsonb_array_elements(added) x
      WHERE coalesce((x->>'asset_movement')::boolean,false) AND (x->>'event_date')::date<=dt;
     d0:=d0-asset_net;
    END IF;
RETURN jsonb_build_object('fix86_columns',c||jsonb_build_object('saldo_final',77,'liq_d0_1_recurso',d0,'saldo_apos_d0_1',77+d0,'rsus_vested',10,'saldo_apos_rsu',77+d0+10,'fgts',500,'saldo_apos_fgts',77+d0+10+500));
END $function$;

CREATE FUNCTION public.lts_flow_cache_pre_v240(p_user_id uuid,p_from date,p_to date)RETURNS jsonb LANGUAGE plpgsql AS $function$
DECLARE u uuid:='11111111-1111-4111-8111-111111111111';dt date:=p_from;d0 numeric:=1000;asset_net numeric;c jsonb:='{}';cofrinho jsonb:='{"as_of":"2030-01-04","amount":750}';added jsonb:='[{"event_date":"2030-01-02","signed_amount":100,"asset_movement":true},{"event_date":"2030-01-03","signed_amount":200,"asset_movement":true},{"event_date":"2030-01-03","signed_amount":1500,"asset_movement":true,"description":"FGTS"}]';
BEGIN
    IF dt>=(cofrinho->>'as_of')::date THEN d0:=(cofrinho->>'amount')::numeric;
    ELSE
     SELECT coalesce(sum((x->>'signed_amount')::numeric),0) INTO asset_net FROM jsonb_array_elements(added) x
      WHERE coalesce((x->>'asset_movement')::boolean,false) AND (x->>'event_date')::date<=dt;
     d0:=d0-asset_net;
    END IF;
RETURN jsonb_build_object('fix86_columns',c||jsonb_build_object('saldo_final',77,'liq_d0_1_recurso',d0,'saldo_apos_d0_1',77+d0,'rsus_vested',10,'saldo_apos_rsu',77+d0+10,'fgts',500,'saldo_apos_fgts',77+d0+10+500));
END $function$;

CREATE FUNCTION public.lts_daily_flow_fix86_v13(p_user_id uuid,p_from date,p_to date)RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT jsonb_build_object('days','[]'::jsonb);$$;
CREATE OR REPLACE FUNCTION public.lts_daily_flow_fix86_v14(p_user_id uuid, p_from date DEFAULT CURRENT_DATE, p_to date DEFAULT (CURRENT_DATE + '1 year'::interval))
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with base as materialized (
  select public.lts_daily_flow_fix86_v13(p_user_id,p_from,p_to) j
), rawdays as materialized (
  select d,(d->>'date')::date dt
  from base,lateral jsonb_array_elements(coalesce(base.j->'days','[]'::jsonb)) d
), corrected as materialized (
  select r.d,r.dt,
    coalesce((r.d#>>'{fix86_columns,saldo_final}')::numeric,0) bank_close,
    coalesce((r.d#>>'{fix86_columns,rsus_vested}')::numeric,0) rsu,
    coalesce((r.d#>>'{fix86_columns,fgts}')::numeric,0) fgts,
    coalesce((
      select sum(effective_value_brl)
      from public.lts_asset_position_effective_v1(p_user_id,r.dt)
      where liquidity_class='D+0' and is_available_now
    ),0)::numeric d0_resource
  from rawdays r
), days as (
  select jsonb_agg(
    jsonb_set(c.d,'{fix86_columns}',
      coalesce(c.d->'fix86_columns','{}'::jsonb) || jsonb_build_object(
        'liq_d0_1_recurso',c.d0_resource,
        'liq_d0_1',c.bank_close+c.d0_resource,
        'saldo_apos_d0_1',c.bank_close+c.d0_resource,
        'saldo_apos_rsu',c.bank_close+c.d0_resource+c.rsu,
        'saldo_apos_fgts',c.bank_close+c.d0_resource+c.rsu+c.fgts,
        'disponivel_total',c.bank_close+c.d0_resource+c.rsu,
        'posicao_antes_rsus',c.bank_close+c.d0_resource,
        'posicao_curto_prazo',c.bank_close+c.d0_resource+c.rsu,
        'd0_position_basis','effective_documentary_position_as_of_day'
      ),true
    ) order by c.dt
  ) j from corrected c
)
select (select j from base)
 || jsonb_build_object(
   'version','daily-flow-fix86-v14-documentary-d0-snapshot-parity',
   'days',coalesce((select j from days),'[]'::jsonb),
   'd0_snapshot_contract',jsonb_build_object(
      'reader','lts_asset_position_effective_v1',
      'basis','effective documentary position as of each flow day',
      'same_day_documentary_snapshot_included',true,
      'financial_fact_changed',false,
      'guardrail','Read-model parity only: no bank event, asset movement, category, amount or financial fact is created or mutated.'
   )
 );
$function$;
