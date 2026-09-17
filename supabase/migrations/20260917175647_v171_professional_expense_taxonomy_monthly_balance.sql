-- V171: professional management taxonomy and period-complete monthly balance.
-- The certified expense ledger is not mutated. These functions only provide
-- a clearer read model over the existing effective rows.

create or replace function public.lts_expense_management_group_v1(
  p_category text,
  p_center_cost text,
  p_counterparty text,
  p_origin_name text,
  p_coverage_mode text
) returns text
language sql
immutable
set search_path = public
as $function$
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
    when coalesce(p_category,'') ~* '^Impostos do Im[oó]vel'
      then 'Impostos do imóvel'
    when coalesce(p_category,'') ~* '^Educa[cç][aã]o$'
      and coalesce(p_center_cost,'') ~* '^Benjamin$'
      then 'Benjamin — Educação'
    when coalesce(p_category,'') ~* '^Educa[cç][aã]o$'
      then 'Educação'
    when coalesce(p_category,'') ~* 'Rafiki'
      or coalesce(p_center_cost,'') ~* '^Rafiki$'
      then 'Rafiki'
    when coalesce(p_category,'') ~* '(O Parque|Cip[oó] 396|Obra e Reforma)'
      then 'Investimentos no imóvel — obra e reforma'
    else coalesce(nullif(trim(p_category),''),'A classificar')
  end
$function$;

create or replace function public.lts_expense_management_subgroup_v1(
  p_category text,
  p_center_cost text,
  p_counterparty text,
  p_origin_name text,
  p_coverage_mode text
) returns text
language sql
immutable
set search_path = public
as $function$
  select case
    when coalesce(p_coverage_mode,'')='card_invoice_aggregate_fallback'
      then coalesce(nullif(trim(p_origin_name),''),'Fatura sem identificação do cartão')
    when coalesce(p_category,'') ~* '^Financiamento Imobili[aá]rio'
      then coalesce(nullif(trim(p_center_cost),''),'Imóvel não atribuído')
    when coalesce(p_category,'') ~* '^Financiamento ve[ií]culo'
      then coalesce(nullif(trim(p_counterparty),''),nullif(trim(p_origin_name),''),'Veículo não atribuído')
    when coalesce(p_category,'') ~* '^Compromissos Financeiros'
      then 'Consignado · Coopharma'
    when coalesce(p_category,'') ~* '^Empr[eé]stimos'
      and concat_ws(' ',p_counterparty,p_origin_name) ~* 'Ita[uú]'
      then 'Empréstimo · Itaú'
    when coalesce(p_category,'') ~* '^Empr[eé]stimos'
      and concat_ws(' ',p_counterparty,p_origin_name) ~* 'Pai|M[aã]e'
      then 'Empréstimo familiar · Pai e Mãe'
    when coalesce(p_category,'') ~* '^(Empr[eé]stimos|Compromissos Financeiros)'
      then coalesce(nullif(trim(p_counterparty),''),nullif(trim(p_origin_name),''),'Origem não atribuída')
    when coalesce(p_category,'') ~* '(O Parque|Cip[oó] 396|Obra e Reforma)'
      then trim(regexp_replace(coalesce(p_category,''),'\s*[-·]\s*(O Parque|Cip[oó] 396)\s*$','','i'))
    else coalesce(nullif(trim(p_category),''),'A classificar')
  end
$function$;

create or replace function public.lts_browser_expense_executive_v6(
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
  v_groups jsonb;
  v_coverage jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
  v_base:=public.lts_browser_expense_executive_v4(p_from,p_to);

  with classified as materialized (
    select h.*,
      public.lts_expense_management_group_v1(h.category,h.center_cost,h.counterparty,h.origin_name,h.coverage_mode) management_group,
      public.lts_expense_management_subgroup_v1(h.category,h.center_cost,h.counterparty,h.origin_name,h.coverage_mode) management_subgroup
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
    'subgroups',coalesce((select jsonb_agg(jsonb_build_object('name',s.management_subgroup,'total',s.total,'rows',s.rows) order by s.total desc,s.management_subgroup) from subgroups s where s.management_group=g.management_group),'[]'::jsonb),
    'source_categories',coalesce((select jsonb_agg(jsonb_build_object('name',s.category_name,'total',s.total,'rows',s.rows) order by s.total desc,s.category_name) from sources s where s.management_group=g.management_group),'[]'::jsonb)
  ) order by g.total desc,g.management_group),'[]'::jsonb)
  into v_groups from groups g;

  select jsonb_build_object(
    'total',round(coalesce(sum(total),0),2),
    'rows',coalesce(sum(rows),0),
    'label','Compras de cartão ainda sem categoria',
    'guardrail','O valor permanece no total do período, mas não é atribuído a um grupo até existir detalhe suficiente das compras.',
    'months',count(distinct competence_month),
    'by_origin',coalesce(jsonb_agg(jsonb_build_object('name',origin_name,'total',total,'rows',rows) order by total desc),'[]'::jsonb)
  ) into v_coverage
  from (
    select coalesce(nullif(trim(origin_name),''),'Cartão não identificado') origin_name,
      sum(amount)::numeric total,count(*) rows,min(competence_month) competence_month
    from public.lts_expense_effective_read_cache
    where user_id=v_uid and event_date between greatest(p_from,date '2013-10-10') and least(p_to,current_date)
      and coverage_mode='card_invoice_aggregate_fallback'
    group by coalesce(nullif(trim(origin_name),''),'Cartão não identificado'),competence_month
  ) q;

  return v_base||jsonb_build_object(
    'version','expense-executive-v15-v171-professional-taxonomy',
    'management_groups',v_groups,
    'coverage_disclosure',coalesce(v_coverage,'{}'::jsonb),
    'management_group_contract',jsonb_build_object(
      'version','professional-management-groups-v3',
      'investments_separate_from_recurring',true,
      'financing_separate',true,
      'education_benjamin_explicit_only',true,
      'other_education_consolidated',true,
      'historical_invoice_coverage_outside_ranking',true
    )
  );
end
$function$;

create or replace function public.lts_browser_monthly_balance_v2(
  p_from date,
  p_to date
) returns jsonb
language plpgsql
security definer
set search_path = public
set "TimeZone" = 'America/Sao_Paulo'
as $function$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_base jsonb;
  v_groups jsonb;
  v_coverage jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid monthly balance range'; end if;
  if p_from<date '2013-10-10' or p_to>current_date then raise exception 'monthly balance range outside available history'; end if;
  v_base:=public.lts_monthly_balance_v1(v_uid,p_from,p_to);

  with months as (
    select (jsonb_array_elements_text(v_base->'months'))::date month_key
  ), classified as materialized (
    select h.competence_month month_key,h.amount,h.source_ref,
      public.lts_expense_management_group_v1(h.category,h.center_cost,h.counterparty,h.origin_name,h.coverage_mode) group_label
    from public.lts_expense_effective_read_cache h
    where h.user_id=v_uid and h.event_date between p_from and p_to
  ), agg as (
    select month_key,group_label,sum(amount)::numeric amount,count(*)::integer source_rows
    from classified where group_label<>'Compras de cartão ainda sem categoria'
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
  select coalesce(jsonb_agg(jsonb_build_object('label',group_label,'total',total,'source_rows',source_rows,'monthly',monthly) order by total desc),'[]'::jsonb)
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
    'monthly',jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(a.amount,0)) order by m.month_key),
    'explanation','Valores preservados no total mensal e mantidos fora dos grupos até que as compras sejam identificadas.'
  ) into v_coverage
  from months m left join agg a on a.month_key=m.month_key;

  return v_base||jsonb_build_object(
    'version','monthly-balance-v2-v171-professional-taxonomy',
    'expense_groups',v_groups,
    'expense_unclassified_card_coverage',v_coverage,
    'professional_headings',jsonb_build_array('Receitas operacionais','Entradas extraordinárias','Despesas por grupo','Resultado mensal','Resultado após entradas extraordinárias')
  );
end
$function$;

revoke all on function public.lts_expense_management_group_v1(text,text,text,text,text) from public,anon,authenticated;
revoke all on function public.lts_expense_management_subgroup_v1(text,text,text,text,text) from public,anon,authenticated;
revoke all on function public.lts_browser_expense_executive_v6(date,date) from public,anon;
revoke all on function public.lts_browser_monthly_balance_v2(date,date) from public,anon;
grant execute on function public.lts_browser_expense_executive_v6(date,date) to authenticated;
grant execute on function public.lts_browser_monthly_balance_v2(date,date) to authenticated;

do $migration$
declare
  v_uid uuid;
  v_works numeric;
  v_rafiki numeric;
begin
  select user_id into v_uid from public.lts_expense_effective_read_cache group by user_id order by count(*) desc limit 1;
  select coalesce(sum(amount),0) into v_works
  from public.lts_expense_effective_read_cache
  where user_id=v_uid and public.lts_expense_management_group_v1(category,center_cost,counterparty,origin_name,coverage_mode)='Investimentos no imóvel — obra e reforma';
  select coalesce(sum(amount),0) into v_rafiki
  from public.lts_expense_effective_read_cache
  where user_id=v_uid and public.lts_expense_management_group_v1(category,center_cost,counterparty,origin_name,coverage_mode)='Rafiki';
  if v_works<1000000 then raise exception 'V171 work/reform audit unexpectedly low: %',v_works; end if;
  if v_rafiki<20000 then raise exception 'V171 Rafiki audit unexpectedly low: %',v_rafiki; end if;
end
$migration$;
