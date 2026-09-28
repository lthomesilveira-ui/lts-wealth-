-- Current validated locks and current Open Finance positions replace frozen arithmetic constants.
CREATE OR REPLACE FUNCTION public.lts_dashboard_cash_ladder_from_flow_v2(p_user_id uuid, p_from date, p_to date, p_flow jsonb)
 RETURNS TABLE(flow_date date, operational_cash numeric, d01_resource numeric, balance_after_d01 numeric, rsu_vested_today numeric, rsu_vested_scheduled numeric, balance_no_new_vesting numeric, balance_with_scheduled_vesting numeric, fgts_projected numeric, balance_with_fgts_projected numeric)
 LANGUAGE sql
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with base as (
 select (d->>'date')::date dt,(d#>>'{fix86_columns,saldo_final}')::numeric bank_close,(d#>>'{fix86_columns,liq_d0_1_recurso}')::numeric d01_resource
 from jsonb_array_elements(coalesce(p_flow->'days','[]'::jsonb)) d
), lay as (select * from public.lts_flow_dynamic_layers_v1(p_user_id,p_from,p_to)),
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
$function$
;
CREATE OR REPLACE FUNCTION public.lts_browser_cash_today_v178()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare u uuid:=public.lts_browser_assert_user_v1(); f jsonb; r jsonb; c jsonb; positions jsonb; bank numeric; d0 numeric; vested numeric; fgts numeric;
begin
 positions:=public.lts_open_finance_current_bank_position_v1(u);
 bank:=(positions->>'bank_cash')::numeric;
 select (canonical_value->>'amount')::numeric into d0 from public.lts_validated_lock_registry where lock_key='itau_cofrinho_20260926' and superseded_at is null;
 select (canonical_value->>'total_available_brl')::numeric into vested from public.lts_validated_lock_registry where lock_key='morgan_available_20260922' and superseded_at is null;
 select value_brl into fgts from public.asset_positions where user_id=u and asset_type='FGTS' order by as_of_date desc limit 1;
 if bank is null or d0 is null or vested is null or fgts is null then raise exception 'canonical current liquidity incomplete'; end if;
 f:=public.lts_browser_flow_v12(current_date,current_date);
 select d into r from jsonb_array_elements(coalesce(f#>'{flow,current_future,days}','[]')) d where d->>'date'=current_date::text limit 1;
 r:=coalesce(r,jsonb_build_object('date',current_date));
 r:=jsonb_set(r,'{Itaú,balance}',(select a->'balance' from jsonb_array_elements(positions->'accounts') a where a->>'institution_code'='341'),true);
 r:=jsonb_set(r,'{Bradesco,balance}',(select a->'balance' from jsonb_array_elements(positions->'accounts') a where a->>'institution_code'='237'),true);
 r:=jsonb_set(r,'{C6,balance}',(select a->'balance' from jsonb_array_elements(positions->'accounts') a where a->>'institution_code'='336'),true);
 r:=jsonb_set(r,'{Consolidado,bank_balance}',to_jsonb(bank),true);
 c:=coalesce(r->'fix86_columns','{}'::jsonb);
 c:=jsonb_set(c,'{saldo_final}',to_jsonb(bank),true);
 c:=jsonb_set(c,'{liq_d0_1_recurso}',to_jsonb(d0),true);
 c:=jsonb_set(c,'{rsus_vested}',to_jsonb(vested),true);
 c:=jsonb_set(c,'{fgts}',to_jsonb(fgts),true);
 c:=jsonb_set(c,'{saldo_apos_d0_1}',to_jsonb(bank+d0),true);
 c:=jsonb_set(c,'{saldo_apos_rsu}',to_jsonb(bank+d0+vested),true);
 c:=jsonb_set(c,'{saldo_apos_fgts}',to_jsonb(bank+d0+vested+fgts),true);
 r:=jsonb_set(r,'{fix86_columns}',c,true);
 return jsonb_build_object('version','cash-today-v179-current-canonical','as_of',current_date,'computed_at',clock_timestamp(),'status','complete',
 'cash',bank,'d0',d0,'brokerage_available',vested,'fgts',fgts,'available_total',round(bank+d0+vested,2),'day',r,
 'basis','current_open_finance_bank_plus_validated_cofrinho_and_morgan_locks');
end $function$
;

-- Read-model correction only. Financial facts, locks, schedules and sync jobs are unchanged.
CREATE OR REPLACE FUNCTION public.lts_current_flow_v225(p_user_id uuid,p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo'
AS $function$
declare
  raw jsonb; position jsonb; first_day jsonb; days jsonb; events jsonb;
  delta_i numeric; delta_b numeric; delta_c numeric;
begin
  if p_from is null or p_to is null or p_from>p_to or p_from<current_date or p_to-current_date>12000 then
    raise exception 'invalid current/future range';
  end if;
  raw:=public.lts_daily_flow_fix86_v20(p_user_id,current_date,p_to);
  position:=public.lts_open_finance_current_bank_position_v1(p_user_id);
  select d into first_day from jsonb_array_elements(raw->'days') d where d->>'date'=current_date::text;
  if first_day is null then raise exception 'current anchor day unavailable'; end if;
  select (a->>'balance')::numeric-(first_day#>>'{Itaú,balance}')::numeric into delta_i from jsonb_array_elements(position->'accounts') a where a->>'institution_code'='341';
  select (a->>'balance')::numeric-(first_day#>>'{Bradesco,balance}')::numeric into delta_b from jsonb_array_elements(position->'accounts') a where a->>'institution_code'='237';
  select (a->>'balance')::numeric-(first_day#>>'{C6,balance}')::numeric into delta_c from jsonb_array_elements(position->'accounts') a where a->>'institution_code'='336';
  if delta_i is null or delta_b is null or delta_c is null then raise exception 'current bank anchors incomplete'; end if;
  with layers as materialized (
    select * from public.lts_dashboard_cash_ladder_from_flow_v2(p_user_id,current_date,p_to,raw)
  ), adjusted as (
    select (d->>'date')::date dt,
      d || jsonb_build_object(
        'Itaú',(d->'Itaú')||jsonb_build_object('balance',(d#>>'{Itaú,balance}')::numeric+delta_i),
        'Bradesco',(d->'Bradesco')||jsonb_build_object('balance',(d#>>'{Bradesco,balance}')::numeric+delta_b),
        'C6',(d->'C6')||jsonb_build_object('balance',(d#>>'{C6,balance}')::numeric+delta_c),
        'Consolidado',(d->'Consolidado')||jsonb_build_object('bank_balance',l.operational_cash),
        'fix86_columns',(d->'fix86_columns')||jsonb_build_object(
          'saldo_anterior',(d#>>'{fix86_columns,saldo_anterior}')::numeric+delta_i+delta_b+delta_c,
          'saldo_final',l.operational_cash,
          'liq_d0_1_recurso',l.d01_resource,
          'rsus_vested',l.rsu_vested_scheduled,
          'fgts',l.fgts_projected,
          'saldo_apos_d0_1',l.balance_after_d01,
          'saldo_apos_rsu',l.balance_with_scheduled_vesting,
          'saldo_apos_fgts',l.balance_with_fgts_projected,
          'liq_d0_1',l.balance_after_d01,
          'posicao_antes_rsus',l.balance_after_d01,
          'disponivel_total',l.balance_with_scheduled_vesting,
          'posicao_curto_prazo',l.balance_with_scheduled_vesting
        )
      ) value
    from jsonb_array_elements(raw->'days') d join layers l on l.flow_date=(d->>'date')::date
    where (d->>'date')::date between p_from and p_to
  ) select jsonb_agg(value order by dt) into days from adjusted;
  if jsonb_array_length(days)<>p_to-p_from+1 then raise exception 'incomplete current/future days'; end if;
  select coalesce(jsonb_agg(e order by e->>'event_date',e->>'source_ref'),'[]'::jsonb) into events
    from jsonb_array_elements(coalesce(raw->'events','[]'::jsonb)) e
    where (e->>'event_date')::date between p_from and p_to;
  return raw||jsonb_build_object('from',p_from,'to',p_to,'days',days,'events',events,
    'version','daily-flow-v225-current-anchors','current_anchor_date',current_date);
end
$function$;
REVOKE ALL ON FUNCTION public.lts_current_flow_v225(uuid,date,date) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_current_flow_v225(uuid,date,date) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_browser_flow_v13(p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo'
AS $function$
declare u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to or p_to-p_from>12000 then raise exception 'invalid range'; end if;
  result:=jsonb_build_object('from',p_from,'to',p_to,'historical',jsonb_build_object('days','[]'::jsonb,'events','[]'::jsonb));
  if p_from<current_date then
    result:=(public.lts_browser_flow_v12(p_from,least(p_to,current_date-1))->'flow')||jsonb_build_object('from',p_from,'to',p_to);
  end if;
  if p_to>=current_date then
    result:=jsonb_set(result,'{current_future}',public.lts_current_flow_v225(u,greatest(p_from,current_date),p_to),true);
  end if;
  return jsonb_build_object('ok',true,'flow',result,'version','browser-flow-v13-current-open-finance-anchor-v225');
end
$function$;
REVOKE ALL ON FUNCTION public.lts_browser_flow_v13(date,date) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_flow_v13(date,date) TO authenticated,service_role;

-- Atomic preconditions: a failed assertion rolls back the migration.
DO $check$
declare u uuid:=public.lts_open_finance_pilot_owner_v1(); full_flow jsonb; slice_flow jsonb; day jsonb; pos jsonb; target date;
begin
  if not (public.lts_current_cash_release_qa_v1()->>'pass')::boolean then raise exception 'current cash release guard failed'; end if;
  if not (public.lts_planning_ui_release_qa_v1()->>'pass')::boolean then raise exception 'planning release guard failed'; end if;
  target:=(date_trunc('month',current_date)+interval '1 month')::date;
  full_flow:=public.lts_current_flow_v225(u,current_date,target+2);
  slice_flow:=public.lts_current_flow_v225(u,target,target+2);
  if (select jsonb_agg(d order by d->>'date') from jsonb_array_elements(full_flow->'days') d where (d->>'date')::date>=target) is distinct from slice_flow->'days' then
    raise exception 'future period invariance failed';
  end if;
  select d into day from jsonb_array_elements(full_flow->'days') d where d->>'date'=current_date::text;
  pos:=public.lts_open_finance_current_bank_position_v1(u);
  if (day#>>'{fix86_columns,saldo_final}')::numeric is distinct from (pos->>'bank_cash')::numeric then raise exception 'current flow anchor failed'; end if;
  if exists(select 1 from jsonb_array_elements(full_flow->'days') d where
    abs((d#>>'{fix86_columns,saldo_apos_rsu}')::numeric-((d#>>'{fix86_columns,saldo_final}')::numeric+(d#>>'{fix86_columns,liq_d0_1_recurso}')::numeric+(d#>>'{fix86_columns,rsus_vested}')::numeric))>0.01
    or abs((d#>>'{fix86_columns,saldo_apos_fgts}')::numeric-((d#>>'{fix86_columns,saldo_apos_rsu}')::numeric+(d#>>'{fix86_columns,fgts}')::numeric))>0.01
  ) then raise exception 'liquidity arithmetic failed'; end if;
end
$check$;
