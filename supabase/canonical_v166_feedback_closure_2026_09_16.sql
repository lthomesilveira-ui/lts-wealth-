-- V166: user-scoped award assumptions, cash-RSU availability in projected
-- liquidity, and an auditable refinement surface. No private values are
-- embedded in this migration.

create or replace function public.lts_browser_save_award_assumption_v1(
  p_group_key text,
  p_unit_price_usd numeric,
  p_fx_rate numeric
) returns jsonb
language plpgsql
security definer
set search_path = public
set timezone = 'America/Sao_Paulo'
as $function$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_date date;
  v_kind text;
  v_count integer;
  v_before jsonb;
begin
  if coalesce(p_group_key,'') !~ '^(rsu|cash_rsu):[0-9]{4}-[0-9]{2}-[0-9]{2}$' then raise exception 'invalid award group'; end if;
  if p_unit_price_usd is null or p_unit_price_usd <= 0 or p_unit_price_usd > 10000 then raise exception 'invalid unit price'; end if;
  if p_fx_rate is null or p_fx_rate <= 0 or p_fx_rate > 100 then raise exception 'invalid fx rate'; end if;
  v_date := split_part(p_group_key,':',2)::date;
  v_kind := split_part(p_group_key,':',1);

  select jsonb_agg(to_jsonb(s) order by s.id), count(*) into v_before, v_count
  from public.lts_future_liquidity_schedule s
  where s.user_id=v_uid and s.active=true and s.eligibility_date=v_date
    and case when v_kind='cash_rsu' then lower(s.asset_type) like '%cash%'
             else upper(trim(s.asset_type))='RSU' end;
  if coalesce(v_count,0)=0 then raise exception 'award group not found'; end if;

  update public.lts_future_liquidity_schedule s
  set unit_price_assumption=p_unit_price_usd,
      fx_assumption=p_fx_rate,
      gross_value_brl=round(coalesce(s.quantity,0)*p_unit_price_usd*p_fx_rate,2),
      net_value_brl=case when v_kind='cash_rsu' then round(coalesce(s.quantity,0)*p_unit_price_usd*p_fx_rate*0.70,2)
                         else round(coalesce(s.quantity,0)*p_unit_price_usd*p_fx_rate,2) end,
      metadata=coalesce(s.metadata,'{}'::jsonb)||jsonb_build_object('manual_assumption_v166',true,'manual_assumption_at',now()),
      updated_at=now()
  where s.user_id=v_uid and s.active=true and s.eligibility_date=v_date
    and case when v_kind='cash_rsu' then lower(s.asset_type) like '%cash%'
             else upper(trim(s.asset_type))='RSU' end;

  insert into public.audit_log(user_id,action,entity_type,entity_id,details)
  values(v_uid,'update_award_assumption','award_group',p_group_key,
    jsonb_build_object('before',v_before,'unit_price_usd',p_unit_price_usd,'fx_rate',p_fx_rate,'award_count',v_count));

  delete from public.lts_flow_future_read_cache where user_id=v_uid;
  delete from public.lts_flow_future_read_cache_v2 where user_id=v_uid;
  return jsonb_build_object('ok',true,'group_key',p_group_key,'award_count',v_count,'unit_price_usd',p_unit_price_usd,'fx_rate',p_fx_rate);
end
$function$;

create or replace function public.lts_browser_create_future_event_v1(
  p_date date,
  p_description text,
  p_amount numeric,
  p_direction text,
  p_account text,
  p_category text default null
) returns jsonb
language plpgsql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
declare v_uid uuid:=public.lts_browser_assert_user_v1(); v_id bigint; v_idx integer;
begin
  if p_date is null or p_date<current_date or p_date>current_date+interval '15 years' then raise exception 'invalid future date'; end if;
  if length(trim(coalesce(p_description,'')))<2 or length(p_description)>180 then raise exception 'invalid description'; end if;
  if p_amount is null or p_amount<=0 or p_amount>100000000 then raise exception 'invalid amount'; end if;
  if p_direction not in ('entrada','saida') then raise exception 'invalid direction'; end if;
  if p_account not in ('Itau','Itaú','Bradesco','C6') then raise exception 'invalid account'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text,166));
  select coalesce(max(idx),0)+1 into v_idx from public.evento_base where usuario_id=v_uid;
  insert into public.evento_base(usuario_id,idx,dados)
  values(v_uid,v_idx,jsonb_strip_nulls(jsonb_build_object('dia',p_date,'desc',trim(p_description),'conta',p_account,'valor',round(p_amount,2),'efeito',p_direction,'categoria',nullif(trim(coalesce(p_category,'')),''),'v166_suggested_confirmation',true)))
  returning id into v_id;
  insert into public.audit_log(user_id,action,entity_type,entity_id,details)
  values(v_uid,'create_future_event_from_audit','evento_base',v_id::text,jsonb_build_object('date',p_date,'description',trim(p_description),'amount',round(p_amount,2),'direction',p_direction,'account',p_account,'category',p_category));
  delete from public.lts_flow_future_read_cache where user_id=v_uid;
  delete from public.lts_flow_future_read_cache_v2 where user_id=v_uid;
  return jsonb_build_object('ok',true,'id',v_id,'source','evento_base','source_ref',v_id::text,'date',p_date);
end
$function$;

create or replace function public.lts_flow_dynamic_layers_v1(p_user_id uuid,p_from date,p_to date)
returns table(flow_date date,payroll_withholding_today numeric,fgts_value numeric,fgts_monthly_accrual numeric,vested_rsu_value numeric,vested_rsu_added_today numeric)
language sql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
with params as (
  select
    coalesce((select value_brl from public.asset_positions where user_id=p_user_id and asset_type='FGTS' order by as_of_date desc limit 1),0)::numeric fgts_anchor,
    coalesce((select as_of_date from public.asset_positions where user_id=p_user_id and asset_type='FGTS' order by as_of_date desc limit 1),p_from)::date fgts_anchor_date,
    coalesce((select (dados->>'_v')::numeric from public.fgts where usuario_id=p_user_id and dados->>'_k'='salario_base' limit 1),0)::numeric fgts_salary_base,
    coalesce((select (dados->>'_v')::numeric from public.fgts where usuario_id=p_user_id and dados->>'_k'='percentual' limit 1),0)::numeric fgts_pct,
    coalesce((select (dados->>'_v')::boolean from public.fgts where usuario_id=p_user_id and dados->>'_k'='ativo' limit 1),false)::boolean fgts_active,
    coalesce((select sum(value_brl) from public.asset_positions where user_id=p_user_id and is_available_now=true and liquidity_class in ('D+1','D+2','D+3')),0)::numeric rsu_anchor
), salary_dates as (
  select distinct f.event_date from params p cross join lateral public.lts_corrected_cashflow_fix86_v4(p_user_id,(p.fgts_anchor_date+1)::date,p_to) f
  where f.signed_amount>0 and lower(trim(f.description))='salário'
), award_schedule as (
  select (eligibility_date+settlement_days)::date available_date,
    sum(case when lower(asset_type) like '%cash%' then coalesce(net_value_brl,gross_value_brl)
             else coalesce(gross_value_brl,net_value_brl) end)::numeric value_brl
  from public.lts_future_liquidity_schedule
  where user_id=p_user_id and active=true
    and (upper(trim(asset_type))='RSU' or lower(asset_type) like '%cash%')
  group by 1
), withholding as (
  select effective_event_date event_date,sum(amount)::numeric amt
  from public.lts_payroll_withholding_effective_v1(p_user_id,p_from,p_to) group by effective_event_date
), days as (select generate_series(p_from,p_to,interval '1 day')::date d)
select d.d,coalesce(w.amt,0)::numeric,
 (p.fgts_anchor+case when p.fgts_active then (p.fgts_salary_base*p.fgts_pct)*(select count(*) from salary_dates s where s.event_date<=d.d) else 0 end)::numeric,
 case when p.fgts_active then (p.fgts_salary_base*p.fgts_pct)::numeric else 0::numeric end,
 (p.rsu_anchor+coalesce((select sum(r.value_brl) from award_schedule r where r.available_date<=d.d),0))::numeric,
 coalesce((select sum(r.value_brl) from award_schedule r where r.available_date=d.d),0)::numeric
from days d cross join params p left join withholding w on w.event_date=d.d order by d.d;
$function$;

create or replace function public.lts_daily_flow_fix86_v19(p_user_id uuid,p_from date default current_date,p_to date default current_date+interval '1 year')
returns jsonb
language plpgsql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
declare base jsonb; d jsonb; dt date; rsu_remaining numeric; cash_remaining numeric; base_after_fgts numeric; out_days jsonb:='[]'::jsonb; out_events jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
  base:=public.lts_daily_flow_fix86_v14(p_user_id,p_from,p_to);
  for d in select value from jsonb_array_elements(coalesce(base->'days','[]'::jsonb)) loop
    dt:=(d->>'date')::date;
    select
      coalesce(sum(coalesce(gross_value_brl,net_value_brl)) filter(where upper(trim(asset_type))='RSU' and (eligibility_date+settlement_days)::date>dt),0),
      coalesce(sum(coalesce(net_value_brl,gross_value_brl)) filter(where lower(asset_type) like '%cash%' and (eligibility_date+settlement_days)::date>dt),0)
    into rsu_remaining,cash_remaining from public.lts_future_liquidity_schedule
    where user_id=p_user_id and active=true;
    base_after_fgts:=coalesce(nullif(d#>>'{fix86_columns,saldo_apos_fgts}','')::numeric,coalesce(nullif(d#>>'{fix86_columns,saldo_apos_rsu}','')::numeric,0)+coalesce(nullif(d#>>'{fix86_columns,fgts}','')::numeric,0));
    d:=jsonb_set(d,'{fix86_columns,rsus_futuras}',to_jsonb(rsu_remaining),true);
    d:=jsonb_set(d,'{fix86_columns,cash_awards_futuros}',to_jsonb(cash_remaining),true);
    d:=jsonb_set(d,'{fix86_columns,posicao_economica_total}',to_jsonb(base_after_fgts+rsu_remaining+cash_remaining),true);
    out_days:=out_days||jsonb_build_array(d);
  end loop;
  select coalesce(jsonb_agg(e order by e->>'event_date',e->>'source_ref'),'[]'::jsonb) into out_events from (
    select value e from jsonb_array_elements(coalesce(base->'events','[]'::jsonb))
    union all
    select jsonb_build_object('event_date',(s.eligibility_date+s.settlement_days)::date,'account','Corretora','description','Cash RSU disponível','signed_amount',coalesce(s.net_value_brl,s.gross_value_brl),'category','Cash RSU','source','future_cash_rsu','source_ref',s.id,'status','expected','editable',false,'availability_from_vesting',true)
    from public.lts_future_liquidity_schedule s where s.user_id=p_user_id and s.active=true and lower(s.asset_type) like '%cash%' and (s.eligibility_date+s.settlement_days)::date between p_from and p_to
  ) q;
  return (base-'days'-'events')||jsonb_build_object('days',out_days,'events',out_events,'version','daily-flow-fix86-v19-cash-rsu-availability','future_awards_contract',jsonb_build_object('availability_rule','eligibility_date_plus_settlement_days','cash_rsu_net_factor',0.70,'cash_rsu_enters_projected_liquidity_on_available_date',true,'no_award_before_availability',true));
end
$function$;

create or replace function public.lts_flow_future_read_cache_refresh_v8(p_user_id uuid,p_days integer default 730)
returns jsonb language plpgsql security definer set search_path=public set timezone='America/Sao_Paulo'
as $function$
declare d1 date:=current_date; d2 date:=current_date+greatest(30,least(coalesce(p_days,730),1500)); j jsonb; t0 timestamptz:=clock_timestamp();
begin
  j:=public.lts_daily_flow_fix86_v19(p_user_id,d1,d2);
  insert into public.lts_flow_future_read_cache_v2(user_id,as_of,from_date,to_date,engine_version,payload,refreshed_at)
  values(p_user_id,d1,d1,d2,j->>'version',j,now()) on conflict(user_id) do update set as_of=excluded.as_of,from_date=excluded.from_date,to_date=excluded.to_date,engine_version=excluded.engine_version,payload=excluded.payload,refreshed_at=excluded.refreshed_at;
  return jsonb_build_object('ok',true,'as_of',d1,'to',d2,'days',jsonb_array_length(coalesce(j->'days','[]')),'events',jsonb_array_length(coalesce(j->'events','[]')),'engine_version',j->>'version','elapsed_ms',round((extract(epoch from(clock_timestamp()-t0))*1000)::numeric,1));
end
$function$;

create or replace function public.lts_flow_future_read_cache_refresh_v7(p_user_id uuid,p_days integer default 730)
returns jsonb language plpgsql security definer set search_path=public set timezone='America/Sao_Paulo'
as $function$
declare d1 date:=current_date; d2 date:=current_date+greatest(30,least(coalesce(p_days,730),1500)); j jsonb; t0 timestamptz:=clock_timestamp();
begin
  j:=public.lts_daily_flow_fix86_v19(p_user_id,d1,d2);
  insert into public.lts_flow_future_read_cache_v2(user_id,as_of,from_date,to_date,engine_version,payload,refreshed_at)
  values(p_user_id,d1,d1,d2,j->>'version',j,now()) on conflict(user_id) do update set as_of=excluded.as_of,from_date=excluded.from_date,to_date=excluded.to_date,engine_version=excluded.engine_version,payload=excluded.payload,refreshed_at=excluded.refreshed_at;
  return jsonb_build_object('ok',true,'as_of',d1,'to',d2,'days',jsonb_array_length(coalesce(j->'days','[]')),'events',jsonb_array_length(coalesce(j->'events','[]')),'engine_version',j->>'version','version','flow-future-read-cache-v9-cash-rsu','elapsed_ms',round((extract(epoch from(clock_timestamp()-t0))*1000)::numeric,1));
end
$function$;

create or replace function public.lts_flow_future_read_slice_v8(p_user_id uuid,p_from date,p_to date)
returns jsonb language plpgsql security definer set search_path=public set timezone='America/Sao_Paulo'
as $function$
declare c record; d jsonb; e jsonb; base jsonb; requested_horizon integer;
begin
  if p_from is null or p_to is null or p_from>p_to or p_from<current_date then raise exception 'invalid future range'; end if;
  if p_to+30>current_date+1500 then raise exception 'future range exceeds supported horizon'; end if;
  select * into c from public.lts_flow_future_read_cache_v2 where user_id=p_user_id and as_of=current_date and from_date<=p_from and to_date>=p_to+30 and engine_version='daily-flow-fix86-v19-cash-rsu-availability' order by refreshed_at desc limit 1;
  if not found then
    requested_horizon:=greatest(60,(p_to-current_date)+31);
    perform public.lts_flow_future_read_cache_refresh_v7(p_user_id,requested_horizon);
    select * into c from public.lts_flow_future_read_cache_v2 where user_id=p_user_id and as_of=current_date and from_date<=p_from and to_date>=p_to+30 and engine_version='daily-flow-fix86-v19-cash-rsu-availability' order by refreshed_at desc limit 1;
  end if;
  if not found then raise exception 'future Flow cache could not cover requested range'; end if;
  with all_src as (
    select x,(x->>'date')::date dt from jsonb_array_elements(coalesce(c.payload->'days','[]')) x where (x->>'date')::date between p_from and p_to+30
  ), src as (select * from all_src where dt<=p_to), adj as (
    select s.dt,jsonb_set(s.x,'{fix86_columns,liq_d30}',to_jsonb(coalesce(nullif(s.x#>>'{fix86_columns,liq_d0_1}','')::numeric,0)+coalesce((select sum(nullif(y.x#>>'{Consolidado,economic_net}','')::numeric) from all_src y where y.dt>s.dt and y.dt<=s.dt+30),0)),true) x from src s
  ) select coalesce(jsonb_agg(x order by dt),'[]') into d from adj;
  select coalesce(jsonb_agg(x order by x->>'event_date'),'[]') into e from jsonb_array_elements(coalesce(c.payload->'events','[]')) x where (x->>'event_date')::date between p_from and p_to;
  base:=(c.payload-'days'-'events')||jsonb_build_object('from',p_from,'to',p_to,'days',d,'events',e,'version','daily-flow-fix86-v19-cash-rsu-cache-slice','horizon_contract','requested-period-plus-30-days-v2','cold_refresh_horizon_days',requested_horizon);
  return base;
end
$function$;

revoke all on function public.lts_browser_save_award_assumption_v1(text,numeric,numeric) from public,anon;
grant execute on function public.lts_browser_save_award_assumption_v1(text,numeric,numeric) to authenticated;
revoke all on function public.lts_browser_create_future_event_v1(date,text,numeric,text,text,text) from public,anon;
grant execute on function public.lts_browser_create_future_event_v1(date,text,numeric,text,text,text) to authenticated;
revoke execute on function public.lts_flow_future_read_cache_refresh_v8(uuid,integer) from public,anon,authenticated;
revoke execute on function public.lts_daily_flow_fix86_v19(uuid,date,date) from public,anon,authenticated;
