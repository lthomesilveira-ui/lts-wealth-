-- V165 authenticated read/write surface for awards and full-history search.
-- Personal award facts remain in protected tables; this migration contains no
-- user identifiers, award amounts, quantities, prices, FX rates or vesting dates.

create or replace function public.lts_browser_wealth_detail_v2()
returns jsonb
language plpgsql
security definer
set search_path = public
set timezone = 'America/Sao_Paulo'
as $function$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_base jsonb;
  v_settings jsonb := '{}'::jsonb;
  v_schedule jsonb := '[]'::jsonb;
  v_retention_events jsonb := '[]'::jsonb;
  v_awards jsonb := '{}'::jsonb;
begin
  v_base := public.lts_browser_wealth_detail_v1();

  select coalesce(settings, '{}'::jsonb)
    into v_settings
  from public.app_settings
  where user_id = v_uid;

  with source_rows as (
    select
      s.id,
      case when lower(s.asset_type) like '%cash%' then 'Cash RSU' else 'RSU' end as award_type,
      s.eligibility_date,
      (s.eligibility_date + s.settlement_days) as available_date,
      s.quantity,
      s.unit_price_assumption,
      s.fx_assumption,
      s.gross_value_brl,
      s.net_value_brl,
      s.tax_status,
      s.cash_treatment,
      s.confidence,
      s.source
    from public.lts_future_liquidity_schedule s
    where s.user_id = v_uid
      and s.active = true
      and (upper(trim(s.asset_type)) = 'RSU' or lower(s.asset_type) like '%cash%')
  ), grouped as (
    select
      award_type,
      eligibility_date,
      max(available_date) as available_date,
      array_agg(id order by id) as award_ids,
      sum(quantity) as quantity,
      case when min(unit_price_assumption) = max(unit_price_assumption)
        then min(unit_price_assumption) end as unit_price_usd,
      case when min(fx_assumption) = max(fx_assumption)
        then min(fx_assumption) end as fx_rate,
      sum(gross_value_brl) as gross_value_brl,
      case when award_type = 'Cash RSU'
        then sum(coalesce(net_value_brl, 0))
        else sum(gross_value_brl)
      end as considered_value_brl,
      min(tax_status) as tax_status,
      min(cash_treatment) as cash_treatment,
      min(confidence) as confidence,
      min(source) as source,
      (case when award_type = 'Cash RSU' then 'cash_rsu:' else 'rsu:' end)
        || eligibility_date::text as group_key
    from source_rows
    group by award_type, eligibility_date
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'group_key', group_key,
      'award_ids', to_jsonb(award_ids),
      'asset_type', award_type,
      'eligibility_date', eligibility_date,
      'available_date', available_date,
      'quantity', quantity,
      'unit_price_usd', unit_price_usd,
      'fx_rate', fx_rate,
      'gross_value_brl', gross_value_brl,
      'net_value_brl', considered_value_brl,
      'anticipated_date', nullif(v_settings #>> array['wealth_v165','vesting_anticipation',group_key], ''),
      'tax_status', tax_status,
      'cash_treatment', cash_treatment,
      'confidence', confidence,
      'source', source
    ) order by eligibility_date, award_type
  ), '[]'::jsonb)
  into v_schedule
  from grouped;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', e.id::text,
      'date', (e.dados->>'dia')::date,
      'description', e.dados->>'desc',
      'account', e.dados->>'conta',
      'direction', e.dados->>'efeito',
      'amount', abs((e.dados->>'valor')::numeric)
    ) order by (e.dados->>'dia')::date, e.id
  ), '[]'::jsonb)
  into v_retention_events
  from public.evento_base e
  where e.usuario_id = v_uid
    and lower(coalesce(e.dados->>'desc','')) like '%retention%';

  v_awards := coalesce(v_settings #> '{wealth_v165,employment_awards}', '{}'::jsonb)
    || jsonb_build_object('retention_projected_events', v_retention_events);

  return v_base || jsonb_build_object(
    'version', 'wealth-detail-v3-private-awards-v165',
    'rsu', coalesce(v_base->'rsu', '{}'::jsonb) || jsonb_build_object(
      'future_schedule', v_schedule,
      'future_schedule_count', jsonb_array_length(v_schedule),
      'grouped_by_vesting_date', true,
      'anticipation_persisted', true
    ),
    'employment_awards', v_awards
  );
end
$function$;

create or replace function public.lts_browser_save_vesting_anticipation_v1(
  p_group_key text,
  p_anticipated_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
set timezone = 'America/Sao_Paulo'
as $function$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_original_date date;
  v_award_ids text[];
  v_settings jsonb := '{}'::jsonb;
  v_map jsonb := '{}'::jsonb;
  v_scenario jsonb;
begin
  if coalesce(p_group_key, '') !~ '^(rsu|cash_rsu):[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception 'invalid award group';
  end if;

  select s.eligibility_date, array_agg(s.id order by s.id)
    into v_original_date, v_award_ids
  from public.lts_future_liquidity_schedule s
  where s.user_id = v_uid
    and s.active = true
    and s.eligibility_date::text = split_part(p_group_key, ':', 2)
    and case
      when split_part(p_group_key, ':', 1) = 'cash_rsu' then lower(s.asset_type) like '%cash%'
      else upper(trim(s.asset_type)) = 'RSU'
    end
  group by s.eligibility_date;

  if v_original_date is null or coalesce(cardinality(v_award_ids), 0) = 0 then
    raise exception 'award group not found';
  end if;
  if p_anticipated_date is not null and p_anticipated_date < current_date then
    raise exception 'anticipated date must be today or future';
  end if;
  if p_anticipated_date is not null and p_anticipated_date > v_original_date then
    raise exception 'anticipated date must not be after original vesting';
  end if;

  select coalesce(settings, '{}'::jsonb)
    into v_settings
  from public.app_settings
  where user_id = v_uid;

  v_map := coalesce(v_settings #> '{wealth_v165,vesting_anticipation}', '{}'::jsonb);
  if p_anticipated_date is null then
    v_map := v_map - p_group_key;
  else
    v_map := v_map || jsonb_build_object(p_group_key, p_anticipated_date::text);
  end if;
  v_settings := v_settings || jsonb_build_object(
    'wealth_v165',
    coalesce(v_settings->'wealth_v165', '{}'::jsonb)
      || jsonb_build_object('vesting_anticipation', v_map)
  );

  insert into public.app_settings(user_id, settings, updated_at)
  values (v_uid, v_settings, now())
  on conflict (user_id) do update
    set settings = excluded.settings,
        updated_at = excluded.updated_at;

  insert into public.audit_log(user_id, action, entity_type, entity_id, details)
  values (
    v_uid,
    case when p_anticipated_date is null then 'clear_vesting_anticipation' else 'save_vesting_anticipation' end,
    'vesting_scenario',
    p_group_key,
    jsonb_build_object(
      'original_date', v_original_date,
      'anticipated_date', p_anticipated_date,
      'award_count', cardinality(v_award_ids),
      'scenario_only', true
    )
  );

  if p_anticipated_date is not null then
    v_scenario := public.lts_browser_vesting_scenario_v1(v_award_ids, p_anticipated_date);
  end if;

  return jsonb_build_object(
    'ok', true,
    'saved', p_anticipated_date is not null,
    'group_key', p_group_key,
    'original_date', v_original_date,
    'anticipated_date', p_anticipated_date,
    'award_ids', to_jsonb(v_award_ids),
    'scenario', v_scenario,
    'scenario_only', true
  );
end
$function$;

create or replace function public.lts_browser_transactions_v2(
  p_from date default null,
  p_to date default null,
  p_query text default null,
  p_direction text default null,
  p_account text default null,
  p_limit integer default 500,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_lim integer := least(greatest(coalesce(p_limit, 500), 1), 10000);
  v_off integer := greatest(coalesce(p_offset, 0), 0);
begin
  return (
    with analytics as (
      select
        c.event_date,
        c.description_raw,
        c.account_raw,
        c.direction,
        c.amount,
        c.source_table,
        c.source_ref,
        c.category_candidate,
        c.counterparty_candidate,
        c.center_cost_candidate,
        c.is_internal_transfer,
        c.is_asset_movement,
        c.exclude_from_spend,
        c.semantic_confidence,
        c.is_future_vs_checkpoint
      from public.lts_expense_analytics_candidate c
      where c.user_id = v_uid
    ), missing_legacy as (
      select
        (e.dados->>'dia')::date as event_date,
        e.dados->>'desc' as description_raw,
        e.dados->>'conta' as account_raw,
        e.dados->>'efeito' as direction,
        abs((e.dados->>'valor')::numeric) as amount,
        'evento_base'::text as source_table,
        e.id::text as source_ref,
        case when e.dados->>'efeito' = 'entrada' then 'Receita futura' else null end as category_candidate,
        null::text as counterparty_candidate,
        null::text as center_cost_candidate,
        false as is_internal_transfer,
        false as is_asset_movement,
        false as exclude_from_spend,
        'source_only'::text as semantic_confidence,
        ((e.dados->>'dia')::date > current_date) as is_future_vs_checkpoint
      from public.evento_base e
      where e.usuario_id = v_uid
        and not exists (
          select 1
          from analytics a
          where a.source_table = 'evento_base'
            and a.source_ref = e.id::text
        )
    ), all_rows as (
      select * from analytics
      union all
      select * from missing_legacy
    ), filtered as (
      select *
      from all_rows x
      where (p_from is null or x.event_date >= p_from)
        and (p_to is null or x.event_date <= p_to)
        and (p_direction is null or p_direction = '' or x.direction = p_direction)
        and (p_account is null or p_account = '' or coalesce(x.account_raw, '') = p_account)
        and (
          p_query is null or p_query = ''
          or lower(coalesce(x.description_raw, '')) like '%' || lower(p_query) || '%'
          or lower(coalesce(x.category_candidate, '')) like '%' || lower(p_query) || '%'
          or lower(coalesce(x.counterparty_candidate, '')) like '%' || lower(p_query) || '%'
          or lower(coalesce(x.account_raw, '')) like '%' || lower(p_query) || '%'
        )
    ), counted as (
      select count(*) as n from filtered
    ), paged as (
      select * from filtered
      order by event_date desc, source_table, source_ref
      limit v_lim offset v_off
    )
    select jsonb_build_object(
      'ok', true,
      'total', (select n from counted),
      'limit', v_lim,
      'offset', v_off,
      'rows', coalesce((
        select jsonb_agg(jsonb_build_object(
          'date', event_date,
          'description', description_raw,
          'account', account_raw,
          'direction', direction,
          'amount', amount,
          'category', category_candidate,
          'counterparty', counterparty_candidate,
          'center_cost', center_cost_candidate,
          'source', source_table,
          'source_ref', source_ref,
          'future', is_future_vs_checkpoint,
          'internal_transfer', is_internal_transfer,
          'asset_movement', is_asset_movement,
          'excluded_from_spend', exclude_from_spend,
          'confidence', semantic_confidence
        ) order by event_date desc, source_table, source_ref)
        from paged
      ), '[]'::jsonb)
    )
  );
end
$function$;

revoke all on function public.lts_browser_wealth_detail_v2() from public, anon;
revoke all on function public.lts_browser_save_vesting_anticipation_v1(text, date) from public, anon;
revoke all on function public.lts_browser_transactions_v2(date, date, text, text, text, integer, integer) from public, anon;

grant execute on function public.lts_browser_wealth_detail_v2() to authenticated;
grant execute on function public.lts_browser_save_vesting_anticipation_v1(text, date) to authenticated;
grant execute on function public.lts_browser_transactions_v2(date, date, text, text, text, integer, integer) to authenticated;

comment on function public.lts_browser_wealth_detail_v2() is
  'Authenticated V165 wealth read model. Private award facts are sourced server-side and grouped by vesting date.';
comment on function public.lts_browser_save_vesting_anticipation_v1(text, date) is
  'Persists only a user-owned hypothetical vesting date, appends an audit row and returns a read-only cash scenario.';
comment on function public.lts_browser_transactions_v2(date, date, text, text, text, integer, integer) is
  'Authenticated full-history search, including legacy future events not yet present in the expense analytics candidate.';
