-- V174 deep Despesas audit read-model migrations.
-- Source of truth: Supabase migration history; no financial source rows are mutated.

-- 20260918152137 v174_expense_deep_audit_readers

create or replace function public.lts_expense_management_group_v2(
  p_category text,
  p_center_cost text,
  p_counterparty text,
  p_origin_name text,
  p_coverage_mode text
) returns text
language sql
immutable
set search_path to 'public'
as $$
  select case
    when coalesce(p_coverage_mode,'')='card_invoice_aggregate_fallback'
      then 'Compras de cartão ainda sem categoria'
    when coalesce(p_category,'') ~* '^Financiamento Imobili[aá]rio'
      then 'Financiamento imobiliário'
    when coalesce(p_category,'') ~* '^Financiamento ve[ií]culo'
      then 'Financiamento de veículo'
    when coalesce(p_category,'') ~* '^(Empr[eé]stimos|Compromissos Financeiros)'
      then 'Empréstimos e consignado'
    when coalesce(p_category,'') ~* '^(Energia|Enel)'
      then 'Energia'
    when coalesce(p_category,'') ~* '^Condom'
      then 'Condomínio'
    when coalesce(p_category,'') ~* '^(IPTU|Impostos do Im[oó]vel)'
      then 'Impostos do imóvel'
    when coalesce(p_category,'') ~* '^Educa[cç][aã]o$'
      and coalesce(p_center_cost,'') ~* '^Benjamin$'
      then 'Benjamin — Educação'
    when coalesce(p_category,'') ~* '^Educa[cç][aã]o$'
      then 'Educação'
    when coalesce(p_category,'') ~* '^(Rafiki|Pet)$'
      or coalesce(p_center_cost,'') ~* '^Rafiki$'
      then 'Rafiki'
    when coalesce(p_category,'') ~* '^Fam[ií]lia$'
      then 'Família — saídas'
    when coalesce(p_category,'') ~* '^(Cip[oó] 396|Cons[oó]rcio.*O Parque|Cart[oó]rio.*O Parque)'
      then 'Investimento no imóvel — aquisição e histórico'
    when coalesce(p_category,'') ~* '^Obra e Reforma$'
      then 'Investimentos no imóvel — obra e reforma'
    when coalesce(p_category,'') ~* 'O Parque'
      and coalesce(p_category,'') !~* '^(Condom|Enel|Energia|IPTU|Impostos|Cons[oó]rcio|Cart[oó]rio|Financiamento)'
      then 'Investimentos no imóvel — obra e reforma'
    else coalesce(nullif(trim(p_category),''),'A classificar')
  end
$$;

create or replace function public.lts_browser_cipo_improvement_reconciliation_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
set "TimeZone" to 'America/Sao_Paulo'
as $$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_rec jsonb;
  v_dated numeric := 0;
  v_card_detailed numeric := 0;
  v_card_source numeric := 0;
begin
  v_rec := public.lts_cipo_reconciliation_v4(v_uid);

  select round(coalesce(sum(h.amount),0),2)
    into v_dated
  from public.lts_expense_effective_read_cache h
  where h.user_id=v_uid
    and public.lts_expense_management_group_v2(
      h.category,h.center_cost,h.counterparty,h.origin_name,h.coverage_mode
    )='Investimentos no imóvel — obra e reforma';

  select round(coalesce(sum(h.amount),0),2)
    into v_card_detailed
  from public.lts_expense_effective_read_cache h
  where h.user_id=v_uid
    and h.source_table in (
      'lts_card_historical_category_allocation',
      'lts_card_history_recovered_purchase',
      'lts_card_purchase_detail',
      'lts_document_card_purchase',
      'lts_manual_card_purchase'
    )
    and public.lts_expense_management_group_v2(
      h.category,h.center_cost,h.counterparty,h.origin_name,h.coverage_mode
    )='Investimentos no imóvel — obra e reforma';

  v_card_source := coalesce(nullif(v_rec#>>'{historical_card_source_aggregates,improvement_total}','')::numeric,0);

  return jsonb_build_object(
    'version','cipo-improvement-browser-v1',
    'as_of',current_date,
    'workbook_summary_brl',nullif(v_rec#>>'{source_internal_consistency,workbook_summary_reforms_improvements}','')::numeric,
    'reconciled_unique_brl',nullif(v_rec#>>'{source_internal_consistency,improvement_detail_total}','')::numeric,
    'duplicate_source_brl',nullif(v_rec#>>'{source_internal_consistency,duplicate_row_amount}','')::numeric,
    'duplicate_component',v_rec#>>'{source_internal_consistency,duplicate_component}',
    'dated_reader_brl',v_dated,
    'historical_card_source_brl',v_card_source,
    'historical_card_detailed_brl',v_card_detailed,
    'historical_card_coverage_gap_brl',round(v_card_source-v_card_detailed,2),
    'card_source_by_origin',coalesce(v_rec#>'{historical_card_source_aggregates,by_source}','[]'::jsonb),
    'guardrail','O resumo original da planilha é preservado como evidência. A duplicidade de Móveis é contada uma única vez no valor reconciliado; agregados históricos de cartão sem compras individualizadas não recebem datas ou estabelecimentos inventados.'
  );
end
$$;

create or replace function public.lts_browser_card_flow_schedule_v1(p_from date, p_to date)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
set "TimeZone" to 'America/Sao_Paulo'
as $$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_flow jsonb;
  v_events jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then
    raise exception 'invalid card flow range';
  end if;
  v_flow := public.lts_daily_flow_fix86_v12(v_uid,p_from,p_to);

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'event_date',x->>'event_date',
      'account',x->>'account',
      'description',x->>'description',
      'card_name',coalesce(x->>'counterparty',x->>'description'),
      'amount',abs((x->>'signed_amount')::numeric),
      'source',x->>'source',
      'source_ref',x->>'source_ref',
      'confidence',x->>'confidence'
    )
    order by x->>'event_date',x->>'description'
  ),'[]'::jsonb)
  into v_events
  from jsonb_array_elements(coalesce(v_flow->'events','[]'::jsonb)) x
  where (x->>'signed_amount')::numeric<0
    and (
      coalesce(x->>'category','') in ('Cartões','Cartão de Crédito')
      or coalesce(x->>'description','') ~* '(Aeternum|Mastercard|Personnalit|Cart[aã]o C6|C6 Carbon|Visa Infinite)'
    );

  return jsonb_build_object(
    'version','card-flow-schedule-v1',
    'from',p_from,
    'to',p_to,
    'events',v_events
  );
end
$$;

create or replace function public.lts_browser_expense_executive_v7(
  p_from date default date '2023-01-01',
  p_to date default current_date
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
set "TimeZone" to 'America/Sao_Paulo'
as $$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_base jsonb;
  v_groups jsonb;
  v_prop jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
  v_base:=public.lts_browser_expense_executive_v6(p_from,p_to);

  with classified as materialized (
    select h.*,
      public.lts_expense_management_group_v2(
        h.category,h.center_cost,h.counterparty,h.origin_name,h.coverage_mode
      ) management_group,
      public.lts_expense_management_subgroup_v1(
        h.category,h.center_cost,h.counterparty,h.origin_name,h.coverage_mode
      ) management_subgroup
    from public.lts_expense_effective_read_cache h
    where h.user_id=v_uid
      and h.event_date between greatest(p_from,date '2013-10-10') and least(p_to,current_date)
  ), groups as (
    select management_group,round(sum(amount),2) total,count(*) rows
    from classified
    where management_group<>'Compras de cartão ainda sem categoria'
    group by management_group
  ), subgroups as (
    select management_group,management_subgroup,round(sum(amount),2) total,count(*) rows
    from classified
    where management_group<>'Compras de cartão ainda sem categoria'
    group by management_group,management_subgroup
  ), sources as (
    select management_group,coalesce(nullif(trim(category),''),'A classificar') category_name,
      round(sum(amount),2) total,count(*) rows
    from classified
    where management_group<>'Compras de cartão ainda sem categoria'
    group by management_group,coalesce(nullif(trim(category),''),'A classificar')
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'name',g.management_group,'total',g.total,'rows',g.rows,
    'subgroups',coalesce((
      select jsonb_agg(jsonb_build_object('name',s.management_subgroup,'total',s.total,'rows',s.rows)
        order by s.total desc,s.management_subgroup)
      from subgroups s where s.management_group=g.management_group
    ),'[]'::jsonb),
    'source_categories',coalesce((
      select jsonb_agg(jsonb_build_object('name',s.category_name,'total',s.total,'rows',s.rows)
        order by s.total desc,s.category_name)
      from sources s where s.management_group=g.management_group
    ),'[]'::jsonb)
  ) order by g.total desc,g.management_group),'[]'::jsonb)
  into v_groups from groups g;

  if p_from<=date '2013-10-10' and p_to>=current_date then
    v_prop:=public.lts_browser_cipo_improvement_reconciliation_v1();
  else
    v_prop:='{}'::jsonb;
  end if;

  return v_base||jsonb_build_object(
    'version','expense-executive-v16-v174-audited',
    'management_groups',v_groups,
    'property_improvement_reconciliation',v_prop,
    'management_group_contract',jsonb_build_object(
      'version','professional-management-groups-v4',
      'generic_cipo_not_works',true,
      'family_outflows_explicit',true,
      'pet_alias_to_rafiki',true,
      'full_period_property_source_reconciliation',true
    )
  );
end
$$;

create or replace function public.lts_browser_monthly_balance_v3(p_from date,p_to date)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
set "TimeZone" to 'America/Sao_Paulo'
as $$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_base jsonb;
  v_groups jsonb;
  v_coverage jsonb;
  v_sale_total numeric:=0;
  v_sale_monthly jsonb:='[]'::jsonb;
  v_extra_groups jsonb;
  v_month_totals jsonb;
  v_totals jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid monthly balance range'; end if;
  if p_from<date '2013-10-10' or p_to>current_date then raise exception 'monthly balance range outside available history'; end if;

  v_base:=public.lts_monthly_balance_v1(v_uid,p_from,p_to);

  with months as (
    select (jsonb_array_elements_text(v_base->'months'))::date month_key
  ), classified as materialized (
    select h.competence_month month_key,h.amount,h.source_ref,
      public.lts_expense_management_group_v2(
        h.category,h.center_cost,h.counterparty,h.origin_name,h.coverage_mode
      ) group_label
    from public.lts_expense_effective_read_cache h
    where h.user_id=v_uid and h.event_date between p_from and p_to
  ), agg as (
    select month_key,group_label,sum(amount)::numeric amount,count(*)::integer source_rows
    from classified
    where group_label<>'Compras de cartão ainda sem categoria'
    group by month_key,group_label
  ), labels as (
    select group_label,sum(amount)::numeric total,sum(source_rows)::integer source_rows
    from agg group by group_label
  ), final as (
    select l.group_label,l.total,l.source_rows,
      jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(a.amount,0)) order by m.month_key) monthly
    from labels l cross join months m
    left join agg a on a.group_label=l.group_label and a.month_key=m.month_key
    group by l.group_label,l.total,l.source_rows
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'label',group_label,'total',total,'source_rows',source_rows,'monthly',monthly
  ) order by total desc),'[]'::jsonb)
  into v_groups from final;

  with months as (
    select (jsonb_array_elements_text(v_base->'months'))::date month_key
  ), agg as (
    select h.competence_month month_key,sum(h.amount)::numeric amount,count(*)::integer source_rows
    from public.lts_expense_effective_read_cache h
    where h.user_id=v_uid and h.event_date between p_from and p_to
      and h.coverage_mode='card_invoice_aggregate_fallback'
    group by h.competence_month
  )
  select jsonb_build_object(
    'label','Compras de cartão ainda sem categoria',
    'total',coalesce(sum(a.amount),0),
    'source_rows',coalesce(sum(a.source_rows),0),
    'monthly',jsonb_agg(jsonb_build_object(
      'month',m.month_key,'amount',coalesce(a.amount,0)
    ) order by m.month_key),
    'explanation','Valores preservados no total mensal e mantidos fora dos grupos até que as compras sejam identificadas.'
  )
  into v_coverage
  from months m left join agg a on a.month_key=m.month_key;

  with h as materialized (
    select *
    from public.lts_historical_effective_cash_v5(v_uid,p_from,p_to)
    where signed_amount>0
  ), sale as (
    select date_trunc('month',event_date)::date month_key,
      sum(signed_amount)::numeric amount,count(*)::integer source_rows
    from h
    where not coalesce(internal_transfer,false)
      and (
        coalesce(description,'') ~* '(venda.*a[cç][oõ]es|realiza[cç][aã]o.*investimento.*venda.*a[cç][oõ]es)'
      )
      and (
        coalesce(excluded_from_spend,false)
        or coalesce(category,'') ~* '^Investimentos$'
        or coalesce(is_asset_movement,false)
      )
    group by 1
  ), months as (
    select (jsonb_array_elements_text(v_base->'months'))::date month_key
  )
  select coalesce(sum(s.amount),0),
    jsonb_agg(jsonb_build_object(
      'month',m.month_key,'amount',coalesce(s.amount,0),'source_rows',coalesce(s.source_rows,0)
    ) order by m.month_key)
  into v_sale_total,v_sale_monthly
  from months m left join sale s on s.month_key=m.month_key;

  with parts as (
    select g->>'label' label,(g->>'total')::numeric total,
      coalesce((g->>'source_rows')::integer,0) source_rows,g->'monthly' monthly
    from jsonb_array_elements(coalesce(v_base->'extraordinary_groups','[]'::jsonb)) g
    union all
    select 'Venda de bens e ativos',v_sale_total,
      coalesce((select sum((x->>'source_rows')::integer) from jsonb_array_elements(v_sale_monthly) x),0)::integer,
      v_sale_monthly
    where v_sale_total<>0
  ), labels as (
    select label,sum(total)::numeric total,sum(source_rows)::integer source_rows
    from parts group by label
  ), months as (
    select (jsonb_array_elements_text(v_base->'months'))::date month_key
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'label',l.label,'total',l.total,'source_rows',l.source_rows,
    'monthly',(
      select jsonb_agg(jsonb_build_object(
        'month',m.month_key,
        'amount',coalesce((
          select sum((mi->>'amount')::numeric)
          from parts p
          cross join lateral jsonb_array_elements(coalesce(p.monthly,'[]'::jsonb)) mi
          where p.label=l.label and (mi->>'month')::date=m.month_key
        ),0)
      ) order by m.month_key)
      from months m
    )
  ) order by l.total desc),'[]'::jsonb)
  into v_extra_groups
  from labels l;

  with sale as (
    select (x->>'month')::date month_key,(x->>'amount')::numeric amount
    from jsonb_array_elements(v_sale_monthly) x
  )
  select coalesce(jsonb_agg(
    (row.j - 'extraordinary' - 'cash_after_extraordinary') ||
    jsonb_build_object(
      'extraordinary',coalesce((row.j->>'extraordinary')::numeric,0)+coalesce(s.amount,0),
      'cash_after_extraordinary',coalesce((row.j->>'cash_after_extraordinary')::numeric,0)+coalesce(s.amount,0)
    )
    order by (row.j->>'month')::date
  ),'[]'::jsonb)
  into v_month_totals
  from jsonb_array_elements(coalesce(v_base->'monthly_totals','[]'::jsonb)) row(j)
  left join sale s on s.month_key=(row.j->>'month')::date;

  v_totals := coalesce(v_base->'totals','{}'::jsonb) ||
    jsonb_build_object(
      'extraordinary',coalesce((v_base#>>'{totals,extraordinary}')::numeric,0)+v_sale_total,
      'cash_after_extraordinary',coalesce((v_base#>>'{totals,cash_after_extraordinary}')::numeric,0)+v_sale_total
    );

  return v_base||jsonb_build_object(
    'version','monthly-balance-v3-v174-audited',
    'expense_groups',v_groups,
    'expense_unclassified_card_coverage',v_coverage,
    'extraordinary_groups',v_extra_groups,
    'monthly_totals',v_month_totals,
    'totals',v_totals,
    'stock_sale_supplement',jsonb_build_object(
      'total',v_sale_total,
      'monthly',v_sale_monthly,
      'rule','Explicit stock-sale realization is extraordinary income even when the cash event is an asset movement; subsequent interbank transfers remain excluded.'
    ),
    'professional_headings',jsonb_build_array(
      'Receitas operacionais','Entradas extraordinárias','Despesas por grupo','Resultado mensal','Resultado após entradas extraordinárias'
    )
  );
end
$$;

revoke all on function public.lts_browser_cipo_improvement_reconciliation_v1() from public,anon;
revoke all on function public.lts_browser_card_flow_schedule_v1(date,date) from public,anon;
revoke all on function public.lts_browser_expense_executive_v7(date,date) from public,anon;
revoke all on function public.lts_browser_monthly_balance_v3(date,date) from public,anon;
grant execute on function public.lts_browser_cipo_improvement_reconciliation_v1() to authenticated;
grant execute on function public.lts_browser_card_flow_schedule_v1(date,date) to authenticated;
grant execute on function public.lts_browser_expense_executive_v7(date,date) to authenticated;
grant execute on function public.lts_browser_monthly_balance_v3(date,date) to authenticated;


-- 20260918152623 v174_monthly_stock_sale_column_fix

do $patch$
declare v_definition text;
begin
  select pg_get_functiondef('public.lts_browser_monthly_balance_v3(date,date)'::regprocedure)
    into v_definition;
  v_definition:=replace(v_definition,
    E'        or coalesce(is_asset_movement,false)\n',
    '');
  if position('is_asset_movement' in v_definition)>0 then
    raise exception 'V174 stock-sale patch did not remove unsupported column';
  end if;
  execute v_definition;
end
$patch$;

