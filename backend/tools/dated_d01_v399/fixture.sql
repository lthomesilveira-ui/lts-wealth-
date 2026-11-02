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

CREATE OR REPLACE FUNCTION public.lts_flow_future_read_slice_v9(p_user_id uuid, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare c record; d jsonb; e jsonb; base jsonb; requested_horizon integer; source_key text; horizon_end date;
begin
  if p_from is null or p_to is null or p_from>p_to or p_from<current_date then raise exception 'invalid future range'; end if;
  if p_to+30>current_date+1800 then raise exception 'future range exceeds supported horizon'; end if;
  source_key:=public.lts_flow_read_source_key_v247(p_user_id);
  select * into c from public.lts_flow_future_read_cache_v2
   where user_id=p_user_id and as_of=current_date and from_date<=p_from and to_date>=p_to+30
     and payload->>'source_fingerprint'=source_key and engine_version='daily-flow-fix86-v20-award-milestones-invoice-precedence-v181'
   order by refreshed_at desc limit 1;
  if not found then
    requested_horizon:=greatest(60,(p_to-current_date)+31);
    if current_setting('transaction_read_only')::boolean then
      -- Same engine, horizon and fingerprint as refresh_v9. No source writes.
      horizon_end:=current_date+least(1800,greatest(60,requested_horizon,
        coalesce((select to_date-current_date from public.lts_flow_future_read_cache_v2
          where user_id=p_user_id and as_of=current_date),0)));
      select p_user_id user_id,current_date as_of,current_date from_date,horizon_end to_date,
        'daily-flow-fix86-v20-award-milestones-invoice-precedence-v181'::text engine_version,
        public.lts_daily_flow_fix86_v20(p_user_id,current_date,horizon_end)
          ||jsonb_build_object('source_fingerprint',source_key) payload,now() refreshed_at into c;
    else
      perform public.lts_flow_future_read_cache_refresh_v9(p_user_id,requested_horizon);
      select * into c from public.lts_flow_future_read_cache_v2
       where user_id=p_user_id and as_of=current_date and from_date<=p_from and to_date>=p_to+30
         and payload->>'source_fingerprint'=source_key and engine_version='daily-flow-fix86-v20-award-milestones-invoice-precedence-v181'
       order by refreshed_at desc limit 1;
    end if;
  end if;
  if not found then raise exception 'future Flow cache could not cover requested range'; end if;
  c.payload:=public.lts_flow_invoice_amount_overlay_v226(c.payload,(select coalesce(jsonb_agg(to_jsonb(i)),'[]'::jsonb) from public.lts_card_invoice_amounts_v230(p_user_id)i where (i.status='open' OR (i.status='projected' AND i.source IN('derived_installments_v234','received_card_composition_v290'))) and i.due_date>=current_date));
  with all_src as (
    select x,(x->>'date')::date dt from jsonb_array_elements(coalesce(c.payload->'days','[]'::jsonb)) x
     where (x->>'date')::date between p_from and p_to+30
  ), src as (select * from all_src where dt<=p_to), adj as (
    select s.dt,jsonb_set(s.x,'{fix86_columns,liq_d30}',coalesce(to_jsonb(
      CASE WHEN (SELECT count(*)=30 AND count(DISTINCT y.dt)=30 AND count(nullif(y.x#>>'{Consolidado,economic_net}',''))=30 FROM all_src y WHERE y.dt>s.dt AND y.dt<=s.dt+30)
      THEN nullif(s.x#>>'{fix86_columns,liq_d0_1}','')::numeric+(
        select sum(nullif(y.x#>>'{Consolidado,economic_net}','')::numeric) from all_src y
         where y.dt>s.dt and y.dt<=s.dt+30) ELSE NULL END),'null'::jsonb),true) x from src s
  ) select coalesce(jsonb_agg(x order by dt),'[]'::jsonb) into d from adj;
  select coalesce(jsonb_agg(x order by x->>'event_date',x->>'source_ref'),'[]'::jsonb) into e
    from jsonb_array_elements(coalesce(c.payload->'events','[]'::jsonb)) x
   where (x->>'event_date')::date between p_from and p_to;
  base:=(c.payload-'days'-'events')||jsonb_build_object('from',p_from,'to',p_to,'days',d,'events',e,
    'version','daily-flow-fix86-v20-award-milestones-invoice-precedence-v181-cache-slice','horizon_contract','requested-period-plus-30-days-v3',
    'cold_refresh_horizon_days',requested_horizon);
  return base;
end
$function$;

CREATE TABLE public.lts_future_liquidity_effective_v290(user_id uuid,asset_type text,active boolean,eligibility_date date,settlement_days integer,net_value_brl numeric,gross_value_brl numeric);
CREATE FUNCTION public.lts_open_finance_current_bank_position_v1(uuid)RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT '{"bank_cash":77}'::jsonb;$$;
CREATE OR REPLACE FUNCTION public.qa_ladder_reference_v399(p_user_id uuid, p_from date, p_to date, p_flow jsonb)
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
  from public.lts_future_liquidity_effective_v290 s where s.user_id=p_user_id and s.active
  and (upper(trim(s.asset_type))='RSU' or lower(s.asset_type) like '%cash%')
  and s.eligibility_date+s.settlement_days<=b.dt),0)::numeric vested_rsu_value
 from base b join jsonb_array_elements(p_flow->'days') d on (d->>'date')::date=b.dt
),
params as (
 select (public.lts_open_finance_current_bank_position_v1(p_user_id)->>'bank_cash')::numeric bank_anchor,
 public.lts_cofrinho_effective_locked_v245(p_user_id,current_date) d0_anchor,
 coalesce((select (canonical_value->>'total_available_brl')::numeric from public.lts_validated_lock_registry where lock_key LIKE 'morgan_available_%' and superseded_at is null AND (canonical_value->>'as_of')::date<=current_date ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1),0) rsu_anchor
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

CREATE FUNCTION public.lts_browser_cash_today_v178()RETURNS jsonb LANGUAGE plpgsql AS $function$
DECLARE u uuid:='11111111-1111-4111-8111-111111111111';d0 numeric;d0_date date;
BEGIN
 SELECT (canonical_value->>'amount')::numeric,(canonical_value->>'as_of')::date INTO d0,d0_date
 FROM public.lts_validated_lock_registry WHERE lock_key='itau_cofrinho_20260926' AND superseded_at IS NULL;
 d0:=public.lts_cofrinho_effective_locked_v245(u,current_date);
 RETURN jsonb_build_object('d0',d0,'position_dates',jsonb_build_object('d0',d0_date));
END $function$;
