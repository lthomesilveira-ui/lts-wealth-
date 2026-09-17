-- LTS Wealth V170 -- V169 user-review closure
-- Scope: historical Flow display balances, Morgan Stanley reconciliation,
--        global award assumptions and management expense groups.

create table if not exists public.lts_brokerage_position_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  institution text not null,
  as_of_date date not null,
  currency text not null default 'BRL',
  total_gross_brl numeric(18,2) not null check (total_gross_brl >= 0),
  available_total_brl numeric(18,2) not null check (available_total_brl >= 0),
  unavailable_total_brl numeric(18,2) not null check (unavailable_total_brl >= 0),
  vested_shares_available_brl numeric(18,2) not null default 0 check (vested_shares_available_brl >= 0),
  brokerage_cash_available_brl numeric(18,2) not null default 0 check (brokerage_cash_available_brl >= 0),
  future_rsu_gross_brl numeric(18,2) not null default 0 check (future_rsu_gross_brl >= 0),
  future_cash_rsu_gross_brl numeric(18,2) not null default 0 check (future_cash_rsu_gross_brl >= 0),
  vested_share_quantity numeric(20,6),
  future_rsu_quantity numeric(20,6),
  future_cash_rsu_quantity numeric(20,6),
  source text not null,
  source_label text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint lts_brokerage_snapshot_total_reconciles check (
    abs(total_gross_brl - available_total_brl - unavailable_total_brl) <= 0.02
  ),
  constraint lts_brokerage_snapshot_future_reconciles check (
    abs(unavailable_total_brl - future_rsu_gross_brl - future_cash_rsu_gross_brl) <= 0.02
  ),
  constraint lts_brokerage_snapshot_available_reconciles check (
    abs(available_total_brl - vested_shares_available_brl - brokerage_cash_available_brl) <= 0.02
  ),
  unique (user_id, institution, as_of_date, source)
);

alter table public.lts_brokerage_position_snapshots enable row level security;
alter table public.lts_brokerage_position_snapshots force row level security;
revoke all on table public.lts_brokerage_position_snapshots from public, anon, authenticated;

insert into public.lts_brokerage_position_snapshots (
  user_id, institution, as_of_date, total_gross_brl, available_total_brl,
  unavailable_total_brl, vested_shares_available_brl,
  brokerage_cash_available_brl, future_rsu_gross_brl,
  future_cash_rsu_gross_brl, vested_share_quantity, future_rsu_quantity,
  future_cash_rsu_quantity, source, source_label, metadata
)
select u.id, 'Morgan Stanley', date '2026-09-17', 1745784.67, 15913.44,
       1729871.23, 13012.45, 2900.98, 1142654.04, 587217.19,
       184.954, 16080, 8310, 'user_provided_brokerage_screen',
       'Morgan Stanley · carteira exibida em 17/09/2026',
       jsonb_build_object(
         'evidence','user_provided_screenshot',
         'available_component_rounding_delta_brl',0.01,
         'cash_rsu_planning_reserve_rate',0.30,
         'note','The one-cent available-total difference is retained exactly as displayed by the brokerage.'
       )
from auth.users u
where lower(u.email)='l.thomesilveira@gmail.com'
on conflict (user_id, institution, as_of_date, source) do update
set total_gross_brl=excluded.total_gross_brl,
    available_total_brl=excluded.available_total_brl,
    unavailable_total_brl=excluded.unavailable_total_brl,
    vested_shares_available_brl=excluded.vested_shares_available_brl,
    brokerage_cash_available_brl=excluded.brokerage_cash_available_brl,
    future_rsu_gross_brl=excluded.future_rsu_gross_brl,
    future_cash_rsu_gross_brl=excluded.future_cash_rsu_gross_brl,
    vested_share_quantity=excluded.vested_share_quantity,
    future_rsu_quantity=excluded.future_rsu_quantity,
    future_cash_rsu_quantity=excluded.future_cash_rsu_quantity,
    source_label=excluded.source_label,
    metadata=excluded.metadata,
    updated_at=now();

create or replace function public.lts_flow_historical_relative_balance_overlay_v1(
  p_user_id uuid,
  p_flow jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public
set "TimeZone" = 'America/Sao_Paulo'
as $function$
declare
  v_origin date := date '2013-10-09';
  v_max_date date;
  v_days jsonb;
begin
  select max(nullif(x->>'date','')::date)
    into v_max_date
  from jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'::jsonb)) x;

  if v_max_date is null then
    return p_flow || jsonb_build_object(
      'historical_relative_balance_contract',jsonb_build_object(
        'version','historical-relative-ledger-v1',
        'opening_basis_date',v_origin,
        'opening_basis_brl',0,
        'display','no_historical_days'
      )
    );
  end if;

  with source_rows as materialized (
    select *
    from public.lts_flow_past_operational_v2(p_user_id,v_origin+1,v_max_date)
  ), daily as (
    select event_date,
           coalesce(sum(signed_amount) filter (
             where not coalesce(internal_transfer,false)
               and coalesce(source,'') <> 'economic_withholding'
           ),0)::numeric consolidated_delta,
           coalesce(sum(signed_amount) filter (
             where lower(replace(coalesce(account,''),'ú','u'))='itau'
           ),0)::numeric itau_delta,
           coalesce(sum(signed_amount) filter (
             where lower(coalesce(account,''))='bradesco'
           ),0)::numeric bradesco_delta,
           coalesce(sum(signed_amount) filter (
             where lower(coalesce(account,''))='c6'
           ),0)::numeric c6_delta
    from source_rows
    group by event_date
  ), calendar as (
    select g::date dt,
           coalesce(d.consolidated_delta,0) consolidated_delta,
           coalesce(d.itau_delta,0) itau_delta,
           coalesce(d.bradesco_delta,0) bradesco_delta,
           coalesce(d.c6_delta,0) c6_delta
    from generate_series(v_origin,v_max_date,interval '1 day') g
    left join daily d on d.event_date=g::date
  ), running as (
    select dt,
           sum(consolidated_delta) over(order by dt rows unbounded preceding) consolidated_close,
           sum(itau_delta) over(order by dt rows unbounded preceding) itau_close,
           sum(bradesco_delta) over(order by dt rows unbounded preceding) bradesco_close,
           sum(c6_delta) over(order by dt rows unbounded preceding) c6_close
    from calendar
  ), requested as (
    select d.x,d.ord,(d.x->>'date')::date dt,r.*
    from jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'::jsonb))
         with ordinality d(x,ord)
    join running r on r.dt=(d.x->>'date')::date
  ), account_patch as (
    select ord,dt,consolidated_close,
      case when x#>>'{Itaú,balance}' is null
        then jsonb_set(
               jsonb_set(
                 jsonb_set(x,array['Itaú','balance'],to_jsonb(itau_close),true),
                 array['Itaú','balance_certified'],'false'::jsonb,true
               ),
               array['Itaú','balance_basis'],to_jsonb('relative_movement_ledger'::text),true
             ) else x end x1,
      bradesco_close,c6_close
    from requested
  ), bradesco_patch as (
    select ord,dt,consolidated_close,c6_close,
      case when x1#>>'{Bradesco,balance}' is null
        then jsonb_set(
               jsonb_set(
                 jsonb_set(x1,array['Bradesco','balance'],to_jsonb(bradesco_close),true),
                 array['Bradesco','balance_certified'],'false'::jsonb,true
               ),
               array['Bradesco','balance_basis'],to_jsonb('relative_movement_ledger'::text),true
             ) else x1 end x2
    from account_patch
  ), c6_patch as (
    select ord,dt,consolidated_close,
      case when x2#>>'{C6,balance}' is null
        then jsonb_set(
               jsonb_set(
                 jsonb_set(x2,array['C6','balance'],to_jsonb(c6_close),true),
                 array['C6','balance_certified'],'false'::jsonb,true
               ),
               array['C6','balance_basis'],to_jsonb('relative_movement_ledger'::text),true
             ) else x2 end x3
    from bradesco_patch
  ), consolidated_patch as (
    select ord,
      case when x3#>>'{Consolidado,bank_balance}' is null
        then jsonb_set(
               jsonb_set(
                 jsonb_set(
                   x3,array['Consolidado','bank_balance'],to_jsonb(consolidated_close),true
                 ),
                 array['Consolidado','balance_certified'],'false'::jsonb,true
               ),
               array['Consolidado','balance_basis'],to_jsonb('relative_movement_ledger'::text),true
             ) || jsonb_build_object(
               'evidence_status','relative_movement_ledger_before_complete_documentary_opening',
               'absolute_balance_basis',null,
               'absolute_balance_certified',false,
               'absolute_balance_reconstructed',false,
               'relative_balance_display',true
             )
        else x3 end x4
    from c6_patch
  )
  select coalesce(jsonb_agg(x4 order by ord),'[]'::jsonb)
    into v_days
  from consolidated_patch;

  return jsonb_set(p_flow,'{historical,days}',v_days,true) || jsonb_build_object(
    'historical_relative_balance_contract',jsonb_build_object(
      'version','historical-relative-ledger-v1',
      'opening_basis_date',v_origin,
      'opening_basis_brl',0,
      'continuity','global_from_2013_10_09_not_reset_by_selected_range',
      'consolidated_rule','internal transfers excluded',
      'account_rule','internal transfer legs retained',
      'guardrail','Relative movement balances fill the arithmetic columns but are not represented as documentary bank balances.'
    )
  );
end
$function$;

revoke all on function public.lts_flow_historical_relative_balance_overlay_v1(uuid,jsonb)
  from public, anon, authenticated;

create or replace function public.lts_flow_morgan_available_overlay_v1(
  p_user_id uuid,
  p_flow jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public
set "TimeZone" = 'America/Sao_Paulo'
as $function$
declare
  v_snapshot public.lts_brokerage_position_snapshots%rowtype;
  v_legacy_vested numeric := 0;
  v_delta numeric := 0;
  v_days jsonb;
begin
  select * into v_snapshot
  from public.lts_brokerage_position_snapshots
  where user_id=p_user_id and institution='Morgan Stanley' and as_of_date<=current_date
  order by as_of_date desc,updated_at desc
  limit 1;

  if not found then return p_flow; end if;

  select coalesce(sum(value_brl),0) into v_legacy_vested
  from public.asset_positions
  where user_id=p_user_id and asset_type='RSU' and is_available_now;

  v_delta:=v_snapshot.available_total_brl-v_legacy_vested;

  with rows as (
    select d.x,d.ord
    from jsonb_array_elements(coalesce(p_flow#>'{current_future,days}','[]'::jsonb))
         with ordinality d(x,ord)
  ), values0 as (
    select ord,x,
      coalesce(nullif(x#>>'{fix86_columns,rsus_vested}','')::numeric,0)+v_delta new_available,
      coalesce(nullif(x#>>'{fix86_columns,saldo_apos_rsu}','')::numeric,0)+v_delta new_after_available,
      coalesce(nullif(x#>>'{fix86_columns,saldo_apos_fgts}','')::numeric,0)+v_delta new_after_fgts,
      coalesce(nullif(x#>>'{fix86_columns,posicao_economica_total}','')::numeric,0)+v_delta new_economic
    from rows
  ), patched as (
    select ord,
      jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(
              jsonb_set(
                jsonb_set(x,array['fix86_columns','rsus_vested'],to_jsonb(new_available),true),
                array['fix86_columns','morgan_available_total_brl'],to_jsonb(new_available),true
              ),
              array['fix86_columns','saldo_apos_rsu'],to_jsonb(new_after_available),true
            ),
            array['fix86_columns','disponivel_total'],to_jsonb(new_after_available),true
          ),
          array['fix86_columns','posicao_curto_prazo'],to_jsonb(new_after_available),true
        ),
        array['fix86_columns','saldo_apos_fgts'],to_jsonb(new_after_fgts),true
      ) x1,
      new_economic
    from values0
  ), patched2 as (
    select ord,
      jsonb_set(x1,array['fix86_columns','posicao_economica_total'],to_jsonb(new_economic),true) x
    from patched
  )
  select coalesce(jsonb_agg(x order by ord),'[]'::jsonb) into v_days
  from patched2;

  return jsonb_set(p_flow,'{current_future,days}',v_days,true) || jsonb_build_object(
    'morgan_available_contract',jsonb_build_object(
      'version','morgan-available-flow-v1',
      'snapshot_as_of',v_snapshot.as_of_date,
      'statement_available_total_brl',v_snapshot.available_total_brl,
      'legacy_vested_component_brl',v_legacy_vested,
      'constant_bridge_delta_brl',v_delta,
      'label','Morgan disponível',
      'guardrail','The bridge adds the complete currently available brokerage position; later scheduled vestings continue to accumulate independently.'
    )
  );
end
$function$;

revoke all on function public.lts_flow_morgan_available_overlay_v1(uuid,jsonb)
  from public, anon, authenticated;

create or replace function public.lts_browser_flow_v12(p_from date,p_to date)
returns jsonb
language plpgsql
security definer
set search_path = public
set "TimeZone" = 'America/Sao_Paulo'
as $function$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_base jsonb;
  v_flow jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
  if (p_to-p_from)>12000 then raise exception 'range too large'; end if;

  v_base:=public.lts_browser_flow_v11(p_from,p_to);
  v_flow:=v_base->'flow';

  if p_from<current_date then
    v_flow:=public.lts_flow_historical_relative_balance_overlay_v1(v_uid,v_flow);
  end if;
  if p_to>=current_date then
    v_flow:=public.lts_flow_morgan_available_overlay_v1(v_uid,v_flow);
  end if;

  v_flow:=v_flow||jsonb_build_object('version','daily-flow-browser-v12-v170-auditable-balances');
  return jsonb_build_object('ok',true,'flow',v_flow);
end
$function$;

revoke all on function public.lts_browser_flow_v12(date,date) from public, anon;
grant execute on function public.lts_browser_flow_v12(date,date) to authenticated;

create or replace function public.lts_browser_wealth_detail_v4()
returns jsonb
language plpgsql
security definer
set search_path = public
set "TimeZone" = 'America/Sao_Paulo'
as $function$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_base jsonb;
  v_snapshot public.lts_brokerage_position_snapshots%rowtype;
  v_summary jsonb;
  v_cash_net numeric;
  v_reserve numeric;
  v_future_net numeric;
  v_total_net numeric;
  v_schedule_cash_gross numeric;
begin
  v_base:=public.lts_browser_wealth_detail_v3();
  v_summary:=coalesce(v_base->'rsu_summary','{}'::jsonb);

  select * into v_snapshot
  from public.lts_brokerage_position_snapshots
  where user_id=v_uid and institution='Morgan Stanley'
  order by as_of_date desc,updated_at desc
  limit 1;

  if not found then
    return v_base||jsonb_build_object('version','wealth-detail-v5-v170-no-brokerage-snapshot');
  end if;

  v_cash_net:=round(v_snapshot.future_cash_rsu_gross_brl*0.70,2);
  v_reserve:=v_snapshot.future_cash_rsu_gross_brl-v_cash_net;
  v_future_net:=v_snapshot.future_rsu_gross_brl+v_cash_net;
  v_total_net:=v_snapshot.available_total_brl+v_future_net;

  select coalesce(sum(gross_value_brl) filter(where lower(asset_type) like '%cash%'),0)
    into v_schedule_cash_gross
  from public.lts_future_liquidity_schedule
  where user_id=v_uid and active;

  v_summary:=v_summary||jsonb_build_object(
    'as_of',v_snapshot.as_of_date,
    'vested_shares_brl',v_snapshot.vested_shares_available_brl,
    'brokerage_cash_brl',v_snapshot.brokerage_cash_available_brl,
    'available_total_brl',v_snapshot.available_total_brl,
    'statement_total_gross_brl',v_snapshot.total_gross_brl,
    'statement_unavailable_gross_brl',v_snapshot.unavailable_total_brl
  );

  return v_base||jsonb_build_object(
    'version','wealth-detail-v5-v170-morgan-reconciled',
    'rsu_summary',v_summary,
    'morgan_statement',jsonb_build_object(
      'institution',v_snapshot.institution,
      'as_of',v_snapshot.as_of_date,
      'source_label',v_snapshot.source_label,
      'gross_total_brl',v_snapshot.total_gross_brl,
      'available_total_brl',v_snapshot.available_total_brl,
      'unavailable_gross_brl',v_snapshot.unavailable_total_brl,
      'available_components',jsonb_build_object(
        'vested_shares_brl',v_snapshot.vested_shares_available_brl,
        'brokerage_cash_brl',v_snapshot.brokerage_cash_available_brl,
        'rounding_delta_brl',v_snapshot.available_total_brl-v_snapshot.vested_shares_available_brl-v_snapshot.brokerage_cash_available_brl
      ),
      'future_components',jsonb_build_object(
        'regular_rsu_gross_brl',v_snapshot.future_rsu_gross_brl,
        'cash_rsu_gross_brl',v_snapshot.future_cash_rsu_gross_brl,
        'cash_rsu_after_reserve_brl',v_cash_net,
        'cash_rsu_reserve_brl',v_reserve,
        'future_after_reserve_brl',v_future_net
      ),
      'considered_total_after_reserve_brl',v_total_net,
      'reserve_rate',0.30,
      'quantities',jsonb_build_object(
        'vested_shares',v_snapshot.vested_share_quantity,
        'future_regular_rsu',v_snapshot.future_rsu_quantity,
        'future_cash_rsu',v_snapshot.future_cash_rsu_quantity
      ),
      'planning_schedule_reconciliation',jsonb_build_object(
        'schedule_regular_gross_brl',nullif(v_summary->>'future_regular_brl','')::numeric,
        'statement_regular_gross_brl',v_snapshot.future_rsu_gross_brl,
        'regular_delta_brl',coalesce(nullif(v_summary->>'future_regular_brl','')::numeric,0)-v_snapshot.future_rsu_gross_brl,
        'schedule_cash_gross_brl',v_schedule_cash_gross,
        'statement_cash_gross_brl',v_snapshot.future_cash_rsu_gross_brl,
        'cash_delta_brl',v_schedule_cash_gross-v_snapshot.future_cash_rsu_gross_brl,
        'status','statement_and_assumption_model_kept_separate'
      ),
      'guardrail','Gross statement values are reconciled to the brokerage screen. The after-reserve value is a planning view, not a tax assessment or a second brokerage balance.'
    )
  );
end
$function$;

revoke all on function public.lts_browser_wealth_detail_v4() from public, anon;
grant execute on function public.lts_browser_wealth_detail_v4() to authenticated;

create or replace function public.lts_browser_save_all_award_assumptions_v1(
  p_unit_price_usd numeric,
  p_fx_rate numeric
) returns jsonb
language plpgsql
security definer
set search_path = public
set "TimeZone" = 'America/Sao_Paulo'
as $function$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_count integer := 0;
  v_before jsonb;
begin
  if p_unit_price_usd is null or p_unit_price_usd<=0 or p_unit_price_usd>10000 then
    raise exception 'invalid unit price';
  end if;
  if p_fx_rate is null or p_fx_rate<=0 or p_fx_rate>100 then
    raise exception 'invalid fx rate';
  end if;

  select jsonb_agg(to_jsonb(s) order by s.eligibility_date,s.id),count(*)
    into v_before,v_count
  from public.lts_future_liquidity_schedule s
  where s.user_id=v_uid and s.active
    and (upper(trim(s.asset_type))='RSU' or lower(s.asset_type) like '%cash%');

  if coalesce(v_count,0)=0 then raise exception 'no active award vestings found'; end if;

  update public.lts_future_liquidity_schedule s
  set unit_price_assumption=p_unit_price_usd,
      fx_assumption=p_fx_rate,
      gross_value_brl=round(coalesce(s.quantity,0)*p_unit_price_usd*p_fx_rate,2),
      net_value_brl=case
        when lower(s.asset_type) like '%cash%'
          then round(coalesce(s.quantity,0)*p_unit_price_usd*p_fx_rate*0.70,2)
        else round(coalesce(s.quantity,0)*p_unit_price_usd*p_fx_rate,2)
      end,
      metadata=coalesce(s.metadata,'{}'::jsonb)||jsonb_build_object(
        'manual_assumption_v170_global',true,
        'manual_assumption_at',now(),
        'manual_assumption_scope','all_active_rsu_and_cash_rsu_vestings'
      ),
      updated_at=now()
  where s.user_id=v_uid and s.active
    and (upper(trim(s.asset_type))='RSU' or lower(s.asset_type) like '%cash%');

  insert into public.audit_log(user_id,action,entity_type,entity_id,details)
  values(v_uid,'update_all_award_assumptions','award_schedule','all_active',
    jsonb_build_object(
      'before',v_before,
      'unit_price_usd',p_unit_price_usd,
      'fx_rate',p_fx_rate,
      'award_count',v_count,
      'cash_rsu_reserve_rate',0.30
    ));

  delete from public.lts_flow_future_read_cache where user_id=v_uid;
  delete from public.lts_flow_future_read_cache_v2 where user_id=v_uid;

  return jsonb_build_object(
    'ok',true,
    'award_count',v_count,
    'unit_price_usd',p_unit_price_usd,
    'fx_rate',p_fx_rate,
    'scope','all_active_rsu_and_cash_rsu_vestings'
  );
end
$function$;

revoke all on function public.lts_browser_save_all_award_assumptions_v1(numeric,numeric)
  from public, anon;
grant execute on function public.lts_browser_save_all_award_assumptions_v1(numeric,numeric)
  to authenticated;

create or replace function public.lts_browser_expense_executive_v5(
  p_from date default date '2023-01-01',
  p_to date default current_date
) returns jsonb
language plpgsql
security definer
set search_path = public
set "TimeZone" = 'America/Sao_Paulo'
as $function$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_base jsonb;
  v_groups jsonb := '[]'::jsonb;
  v_coverage jsonb := '{}'::jsonb;
  v_audit jsonb := '{}'::jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
  v_base:=public.lts_browser_expense_executive_v4(p_from,p_to);

  with source_rows as materialized (
    select r.*,
           coalesce(nullif(trim(r.category),''),'A classificar') category_name,
           coalesce(nullif(trim(r.center_cost),''),'Não atribuído') center_name
    from public.lts_expense_consumption_rows_v4(v_uid,p_from,p_to) r
  ), classified as (
    select s.*,
      case
        when lower(category_name) like 'cartão — detalhe histórico não recuperado%'
          or lower(category_name) like 'cartao - detalhe historico nao recuperado%'
          then 'Cobertura histórica sem compras individualizadas'
        when category_name ilike 'Financiamento Imobiliário%'
          or category_name ilike 'Financiamento Imobiliario%'
          or category_name ilike 'Financiamento veículo%'
          or category_name ilike 'Financiamento veiculo%'
          then 'Financiamentos'
        when category_name ilike 'Empréstimos%'
          or category_name ilike 'Emprestimos%'
          or category_name ilike 'Compromissos Financeiros%'
          then 'Empréstimos'
        when category_name ilike 'Educação%'
          or category_name ilike 'Educacao%'
          then 'Educação'
        when (
          category_name ilike '%O Parque%'
          or category_name ilike '%CIPÓ 396%'
          or category_name ilike '%CIPO 396%'
          or coalesce(description_raw,'') ilike '%O Parque%'
          or coalesce(description_raw,'') ilike '%CIPÓ 396%'
          or coalesce(description_raw,'') ilike '%CIPO 396%'
          or coalesce(counterparty,'') ilike '%O Parque%'
          or coalesce(counterparty,'') ilike '%CIPÓ 396%'
          or coalesce(counterparty,'') ilike '%CIPO 396%'
        ) then 'Obra e reforma · O Parque / CIPÓ 396'
        else category_name
      end management_group,
      case
        when lower(category_name) like 'cartão — detalhe histórico não recuperado%'
          or lower(category_name) like 'cartao - detalhe historico nao recuperado%'
          then 'Total de fatura preservado; compras não disponíveis'
        when category_name ilike 'Financiamento Imobiliário%'
          or category_name ilike 'Financiamento Imobiliario%'
          then 'Financiamento imobiliário · '||case when center_name='Não atribuído' then 'origem não atribuída' else center_name end
        when category_name ilike 'Financiamento veículo%'
          or category_name ilike 'Financiamento veiculo%'
          then 'Financiamento de veículo'
        when category_name ilike 'Compromissos Financeiros%'
          then 'Consignado · Coopharma'
        when category_name ilike 'Empréstimos%'
          or category_name ilike 'Emprestimos%'
          then 'Empréstimo · '||case
            when coalesce(account_raw,'') ilike '%Itaú%' or coalesce(account_raw,'') ilike '%Itau%' then 'Itaú'
            when nullif(trim(account_raw),'') is not null then trim(account_raw)
            else 'origem não atribuída' end
        when category_name ilike 'Educação%'
          or category_name ilike 'Educacao%'
          then 'Educação · '||lower(center_name)
        when (
          category_name ilike '%O Parque%'
          or category_name ilike '%CIPÓ 396%'
          or category_name ilike '%CIPO 396%'
          or coalesce(description_raw,'') ilike '%O Parque%'
          or coalesce(counterparty,'') ilike '%O Parque%'
        ) then case
          when category_name ilike 'Obra e Reforma%' then 'Mão de obra e serviços'
          else trim(regexp_replace(category_name,'\\s*[-·]\\s*(O Parque|CIPÓ 396|CIPO 396)\\s*$','','i'))
        end
        else category_name
      end management_subgroup
    from source_rows s
  ), subgroup as (
    select management_group,management_subgroup,
           round(sum(amount),2) total,count(*) rows
    from classified
    group by management_group,management_subgroup
  ), grouped as (
    select management_group,round(sum(amount),2) total,count(*) rows
    from classified
    where management_group<>'Cobertura histórica sem compras individualizadas'
    group by management_group
  ), source_categories as (
    select management_group,category_name,round(sum(amount),2) total,count(*) rows
    from classified
    where management_group<>'Cobertura histórica sem compras individualizadas'
    group by management_group,category_name
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'name',g.management_group,
      'total',g.total,
      'rows',g.rows,
      'subgroups',coalesce((
        select jsonb_agg(jsonb_build_object(
          'name',s.management_subgroup,'total',s.total,'rows',s.rows
        ) order by s.total desc,s.management_subgroup)
        from subgroup s where s.management_group=g.management_group
      ),'[]'::jsonb),
      'source_categories',coalesce((
        select jsonb_agg(jsonb_build_object(
          'name',c.category_name,'total',c.total,'rows',c.rows
        ) order by c.total desc,c.category_name)
        from source_categories c where c.management_group=g.management_group
      ),'[]'::jsonb)
    ) order by g.total desc,g.management_group),'[]'::jsonb)
  into v_groups
  from grouped g;

  with rows as materialized (
    select * from public.lts_expense_consumption_rows_v4(v_uid,p_from,p_to)
  )
  select jsonb_build_object(
    'total',round(coalesce(sum(amount),0),2),
    'rows',count(*),
    'label','Faturas históricas sem compras individualizadas',
    'guardrail','O total econômico foi preservado fora dos grupos gerenciais; estabelecimentos e categorias não são inventados.'
  ) into v_coverage
  from rows
  where lower(coalesce(category,'')) like 'cartão — detalhe histórico não recuperado%'
     or lower(coalesce(category,'')) like 'cartao - detalhe historico nao recuperado%';

  select jsonb_build_object(
    'financing_brl',coalesce(sum((g->>'total')::numeric) filter(where g->>'name'='Financiamentos'),0),
    'loans_brl',coalesce(sum((g->>'total')::numeric) filter(where g->>'name'='Empréstimos'),0),
    'works_brl',coalesce(sum((g->>'total')::numeric) filter(where g->>'name'='Obra e reforma · O Parque / CIPÓ 396'),0),
    'education_brl',coalesce(sum((g->>'total')::numeric) filter(where g->>'name'='Educação'),0),
    'financing_definition','Somente parcelas classificadas como financiamento imobiliário ou de veículo.',
    'works_definition','Itens de O Parque/CIPÓ 396, excluindo as parcelas de financiamento.'
  ) into v_audit
  from jsonb_array_elements(v_groups) g;

  return v_base||jsonb_build_object(
    'version','expense-executive-v13-v170-management-groups',
    'management_groups',v_groups,
    'management_group_audit',v_audit,
    'coverage_disclosure',v_coverage,
    'management_group_contract',jsonb_build_object(
      'version','management-groups-v1',
      'traceability','Every consolidated group retains its source categories and subgroups.',
      'financing_and_works_separated',true,
      'loans_consolidated_with_subgroups',true,
      'education_split_by_person',true
    )
  );
end
$function$;

revoke all on function public.lts_browser_expense_executive_v5(date,date) from public, anon;
grant execute on function public.lts_browser_expense_executive_v5(date,date) to authenticated;
