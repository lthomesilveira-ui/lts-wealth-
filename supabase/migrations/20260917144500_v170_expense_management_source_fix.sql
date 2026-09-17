-- V170 follow-up: management groups must use the same complete effective
-- expense ledger as the executive report. The consumption-only reader omits
-- scheduled financing and loan rows by design.

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
    select h.*,
           coalesce(nullif(trim(h.category),''),'A classificar') category_name,
           coalesce(nullif(trim(h.center_cost),''),'Não atribuído') center_name
    from public.lts_expense_effective_read_cache h
    where h.user_id=v_uid
      and h.event_date between greatest(p_from,date '2013-10-10') and least(p_to,current_date)
  ), classified as (
    select s.*,
      case
        when coverage_mode='card_invoice_aggregate_fallback'
          then 'Cobertura histórica sem compras individualizadas'
        when category_name ilike 'Empréstimos%'
          or category_name ilike 'Emprestimos%'
          or category_name ilike 'Compromissos Financeiros%'
          then 'Empréstimos'
        when category_name ilike 'Financiamento Imobiliário%'
          or category_name ilike 'Financiamento Imobiliario%'
          or category_name ilike 'Financiamento veículo%'
          or category_name ilike 'Financiamento veiculo%'
          then 'Financiamentos'
        when category_name ilike 'Educação%'
          or category_name ilike 'Educacao%'
          then 'Educação'
        when (
          category_name ilike '%O Parque%'
          or category_name ilike '%CIPÓ 396%'
          or category_name ilike '%CIPO 396%'
          or coalesce(counterparty,'') ilike '%O Parque%'
          or coalesce(counterparty,'') ilike '%CIPÓ 396%'
          or coalesce(counterparty,'') ilike '%CIPO 396%'
          or coalesce(origin_name,'') ilike '%O Parque%'
          or coalesce(origin_name,'') ilike '%CIPÓ 396%'
          or coalesce(origin_name,'') ilike '%CIPO 396%'
        ) then 'Obra e reforma · O Parque / CIPÓ 396'
        else category_name
      end management_group,
      case
        when coverage_mode='card_invoice_aggregate_fallback'
          then 'Total de fatura preservado; compras não disponíveis'
        when category_name ilike 'Financiamento Imobiliário%'
          or category_name ilike 'Financiamento Imobiliario%'
          then 'Financiamento imobiliário · '||case
            when center_name='Não atribuído' then 'origem não atribuída'
            else center_name end
        when category_name ilike 'Financiamento veículo%'
          or category_name ilike 'Financiamento veiculo%'
          then 'Financiamento de veículo'
        when category_name ilike 'Compromissos Financeiros%'
          then 'Consignado · Coopharma'
        when category_name ilike 'Empréstimos%'
          or category_name ilike 'Emprestimos%'
          then 'Empréstimo · '||case
            when coalesce(counterparty,'') ilike '%Itaú%'
              or coalesce(counterparty,'') ilike '%Itau%'
              or coalesce(origin_name,'') ilike '%Itaú%'
              or coalesce(origin_name,'') ilike '%Itau%'
              then 'Itaú'
            when nullif(trim(counterparty),'') is not null then trim(counterparty)
            when nullif(trim(origin_name),'') is not null then trim(origin_name)
            else 'origem não atribuída' end
        when category_name ilike 'Educação%'
          or category_name ilike 'Educacao%'
          then 'Educação · '||lower(center_name)
        when (
          category_name ilike '%O Parque%'
          or category_name ilike '%CIPÓ 396%'
          or category_name ilike '%CIPO 396%'
          or coalesce(counterparty,'') ilike '%O Parque%'
          or coalesce(counterparty,'') ilike '%CIPÓ 396%'
          or coalesce(counterparty,'') ilike '%CIPO 396%'
          or coalesce(origin_name,'') ilike '%O Parque%'
          or coalesce(origin_name,'') ilike '%CIPÓ 396%'
          or coalesce(origin_name,'') ilike '%CIPO 396%'
        ) then case
          when category_name ilike 'Obra e Reforma%' then 'Mão de obra e serviços'
          else trim(regexp_replace(category_name,'\s*[-·]\s*(O Parque|CIPÓ 396|CIPO 396)\s*$','','i'))
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
    select h.*
    from public.lts_expense_effective_read_cache h
    where h.user_id=v_uid
      and h.event_date between greatest(p_from,date '2013-10-10') and least(p_to,current_date)
  )
  select jsonb_build_object(
    'total',round(coalesce(sum(amount),0),2),
    'rows',count(*),
    'label','Faturas históricas sem compras individualizadas',
    'guardrail','O total econômico foi preservado fora dos grupos gerenciais; estabelecimentos e categorias não são inventados.'
  ) into v_coverage
  from rows
  where coverage_mode='card_invoice_aggregate_fallback';

  select jsonb_build_object(
    'financing_brl',coalesce(sum((g->>'total')::numeric) filter(where g->>'name'='Financiamentos'),0),
    'loans_brl',coalesce(sum((g->>'total')::numeric) filter(where g->>'name'='Empréstimos'),0),
    'works_brl',coalesce(sum((g->>'total')::numeric) filter(where g->>'name'='Obra e reforma · O Parque / CIPÓ 396'),0),
    'education_brl',coalesce(sum((g->>'total')::numeric) filter(where g->>'name'='Educação'),0),
    'financing_definition','Somente parcelas classificadas como financiamento imobiliário ou de veículo.',
    'works_definition','Itens de O Parque/CIPÓ 396, excluindo as parcelas de financiamento.',
    'source_contract','same_effective_ledger_as_expense_executive_v4'
  ) into v_audit
  from jsonb_array_elements(v_groups) g;

  return v_base||jsonb_build_object(
    'version','expense-executive-v14-v170-management-source-fixed',
    'management_groups',v_groups,
    'management_group_audit',v_audit,
    'coverage_disclosure',v_coverage,
    'management_group_contract',jsonb_build_object(
      'version','management-groups-v2-effective-ledger',
      'traceability','Every consolidated group retains its source categories and subgroups.',
      'source_parity','Uses the same complete effective expense ledger as the executive report.',
      'financing_and_works_separated',true,
      'loans_consolidated_with_subgroups',true,
      'education_split_by_person',true
    )
  );
end
$function$;

revoke all on function public.lts_browser_expense_executive_v5(date,date) from public, anon;
grant execute on function public.lts_browser_expense_executive_v5(date,date) to authenticated;
