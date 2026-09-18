-- V176 canonical Flow/expense audit recovery snapshot
-- Generated 2026-09-18 from live Supabase function definitions.
-- Applied migrations:
--   v176_expense_window_integrity
--   v176_health_subgroup_transparency
--   v176_expense_window_qa
-- Raw financial source rows are NOT mutated by this package.


-- lts_browser_expense_executive_v9(p_from date, p_to date)
CREATE OR REPLACE FUNCTION public.lts_browser_expense_executive_v9(p_from date DEFAULT '2023-01-01'::date, p_to date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid:=public.lts_browser_assert_user_v1();
  v_base jsonb;
  v_groups jsonb;
  v_coverage jsonb;
  v_workbook_months jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
  v_base:=public.lts_browser_expense_executive_v8(p_from,p_to);

  with rows as materialized (
    select * from public.lts_expense_effective_rows_v176(v_uid,p_from,p_to)
  ),
  classified as materialized (
    select r.*,
      public.lts_expense_management_group_v3(r.category,r.center_cost,r.counterparty,r.origin_name,r.coverage_mode) management_group,
      case
        when r.category ~* '^Financiamento ve[ií]culo' and r.source_ref='volvo_financing_2026_p01' then 'Volvo XC40'
        when public.lts_expense_management_group_v3(r.category,r.center_cost,r.counterparty,r.origin_name,r.coverage_mode)='Saúde'
          then case when r.center_cost in ('Benjamin','Larissa') then r.center_cost else 'Saúde geral / não atribuído' end
        else public.lts_expense_management_subgroup_v2(r.category,r.center_cost,r.counterparty,r.origin_name,r.coverage_mode)
      end management_subgroup
    from rows r
  ),
  g as (
    select management_group,round(sum(amount),2) total,count(*) rows
    from classified
    where management_group<>'Faturas conciliadas pelo total'
    group by management_group
  ),
  sg as (
    select management_group,management_subgroup,round(sum(amount),2) total,count(*) rows
    from classified
    where management_group<>'Faturas conciliadas pelo total'
    group by management_group,management_subgroup
  ),
  sc as (
    select management_group,coalesce(nullif(trim(category),''),'A classificar') category_name,
           round(sum(amount),2) total,count(*) rows
    from classified
    where management_group<>'Faturas conciliadas pelo total'
    group by management_group,coalesce(nullif(trim(category),''),'A classificar')
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'name',g.management_group,'total',g.total,'rows',g.rows,
    'subgroups',coalesce((
      select jsonb_agg(jsonb_build_object('name',s.management_subgroup,'total',s.total,'rows',s.rows)
                       order by s.total desc,s.management_subgroup)
      from sg s where s.management_group=g.management_group
    ),'[]'::jsonb),
    'source_categories',coalesce((
      select jsonb_agg(jsonb_build_object('name',s.category_name,'total',s.total,'rows',s.rows)
                       order by s.total desc,s.category_name)
      from sc s where s.management_group=g.management_group
    ),'[]'::jsonb)
  ) order by g.total desc,g.management_group),'[]'::jsonb)
  into v_groups from g;

  -- Full-history property remains source-reconciled rather than only dated.
  if p_from<=date '2013-10-10' and p_to>=current_date then
    v_groups:=(
      with filtered as (
        select x from jsonb_array_elements(v_groups) x
        where x->>'name'<>'Investimentos no imóvel — obra e reforma'
      ),
      prop as (
        select jsonb_build_object(
          'name','Investimentos no imóvel — obra e reforma',
          'total',(v_base#>>'{property_improvement_reconciliation,reconciled_unique_brl}')::numeric,
          'rows',coalesce(jsonb_array_length(v_base#>'{property_improvement_reconciliation,source_components}'),0),
          'source_reconciled',true,
          'subgroups',coalesce(v_base#>'{property_improvement_reconciliation,source_components}','[]'::jsonb),
          'source_categories',coalesce(v_base#>'{property_improvement_reconciliation,source_components}','[]'::jsonb)
        ) x
        where (v_base#>>'{property_improvement_reconciliation,reconciled_unique_brl}') is not null
      )
      select coalesce(jsonb_agg(x order by (x->>'total')::numeric desc,x->>'name'),'[]'::jsonb)
      from (select x from filtered union all select x from prop) q
    );
  end if;

  with rows as materialized (
    select * from public.lts_expense_effective_rows_v176(v_uid,p_from,p_to)
  ),
  cov as (
    select round(coalesce(sum(amount),0),2) total,count(*) rows,count(distinct competence_month) months
    from rows where coverage_mode='card_invoice_aggregate_fallback'
  )
  select jsonb_build_object(
    'label','Faturas conciliadas pelo total',
    'total',total,'rows',rows,'months',months,
    'guardrail','O total permanece preservado quando a categoria não está documentada.'
  ) into v_coverage from cov;

  select coalesce(jsonb_agg(distinct competence_month order by competence_month),'[]'::jsonb)
  into v_workbook_months
  from public.lts_expense_effective_rows_v176(v_uid,p_from,p_to)
  where coverage_mode='card_category_allocated_workbook_v176';

  return v_base||jsonb_build_object(
    'version','expense-executive-v18-v176-window-integrity',
    'management_groups',v_groups,
    'coverage_disclosure',v_coverage,
    'window_integrity',jsonb_build_object(
      'from',p_from,'to',p_to,
      'workbook_months_used',v_workbook_months,
      'no_workbook_month_outside_range',true,
      'contract','full-month workbook category replacement only inside the selected range'
    )
  );
end
$function$


-- lts_browser_monthly_balance_v6(p_from date, p_to date)
CREATE OR REPLACE FUNCTION public.lts_browser_monthly_balance_v6(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid:=public.lts_browser_assert_user_v1();
  v_base jsonb;
  v_groups jsonb;
  v_coverage jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid monthly balance range'; end if;
  v_base:=public.lts_browser_monthly_balance_v5(p_from,p_to);

  with months as (
    select (jsonb_array_elements_text(v_base->'months'))::date month_key
  ),
  rows as materialized (
    select * from public.lts_expense_effective_rows_v176(v_uid,p_from,p_to)
  ),
  agg as (
    select competence_month month_key,
           public.lts_expense_management_group_v3(category,center_cost,counterparty,origin_name,coverage_mode) label,
           sum(amount)::numeric amount,count(*)::integer source_rows
    from rows
    where public.lts_expense_management_group_v3(category,center_cost,counterparty,origin_name,coverage_mode)
          <>'Faturas conciliadas pelo total'
    group by 1,2
  ),
  labels as (
    select label,sum(amount)::numeric total,sum(source_rows)::integer source_rows
    from agg group by label
  ),
  final as (
    select l.label,l.total,l.source_rows,
           jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(a.amount,0)) order by m.month_key) monthly
    from labels l cross join months m
    left join agg a on a.label=l.label and a.month_key=m.month_key
    group by l.label,l.total,l.source_rows
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'label',label,'total',round(total,2),'source_rows',source_rows,'monthly',monthly
  ) order by total desc,label),'[]'::jsonb)
  into v_groups from final;

  with months as (
    select (jsonb_array_elements_text(v_base->'months'))::date month_key
  ),
  rows as materialized (
    select * from public.lts_expense_effective_rows_v176(v_uid,p_from,p_to)
  ),
  agg as (
    select competence_month month_key,sum(amount)::numeric amount,count(*)::integer source_rows
    from rows where coverage_mode='card_invoice_aggregate_fallback'
    group by competence_month
  )
  select jsonb_build_object(
    'label','Faturas conciliadas pelo total',
    'total',round(coalesce(sum(a.amount),0),2),
    'source_rows',coalesce(sum(a.source_rows),0),
    'monthly',jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(a.amount,0)) order by m.month_key),
    'explanation','Total de fatura preservado sem categoria inventada.'
  ) into v_coverage
  from months m left join agg a on a.month_key=m.month_key;

  return v_base||jsonb_build_object(
    'version','monthly-balance-v6-v176-window-integrity',
    'expense_groups',v_groups,
    'expense_unclassified_card_coverage',v_coverage,
    'recurring_gap_audit',public.lts_browser_recurring_category_gap_audit_v2(greatest(p_from,date '2025-11-01'),p_to),
    'window_integrity',jsonb_build_object(
      'from',p_from,'to',p_to,
      'contract','no source month before p_from or after p_to may enter expense groups'
    )
  );
end
$function$


-- lts_browser_recurring_category_gap_audit_v2(p_from date, p_to date)
CREATE OR REPLACE FUNCTION public.lts_browser_recurring_category_gap_audit_v2(p_from date DEFAULT '2025-11-01'::date, p_to date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare v_uid uuid:=public.lts_browser_assert_user_v1();
begin
  return (
    with rows as materialized (
      select * from public.lts_expense_effective_rows_v176(v_uid,p_from,p_to)
    ),
    months as (
      select generate_series(date_trunc('month',p_from)::date,date_trunc('month',p_to)::date,interval '1 month')::date month_key
    ),
    targets(label) as (values('Restaurantes'),('Ifood'),('Rafiki')),
    g as (
      select competence_month,
             public.lts_expense_management_group_v3(category,center_cost,counterparty,origin_name,coverage_mode) label,
             sum(amount)::numeric amount,count(*) rows
      from rows group by 1,2
    ),
    cov as (
      select competence_month,sum(amount)::numeric amount
      from rows where coverage_mode='card_invoice_aggregate_fallback' group by 1
    ),
    audit as (
      select m.month_key,t.label,round(coalesce(g.amount,0),2) amount,coalesce(g.rows,0) source_rows,
             round(coalesce(cov.amount,0),2) aggregate_only,
             case when coalesce(g.amount,0)<>0 then 'classified'
                  when coalesce(cov.amount,0)<>0 then 'aggregate_only_unresolved'
                  else 'zero_or_source_missing' end status
      from months m cross join targets t
      left join g on g.competence_month=m.month_key and g.label=t.label
      left join cov on cov.competence_month=m.month_key
    )
    select jsonb_build_object(
      'version','recurring-gap-audit-v2-v176','from',p_from,'to',p_to,
      'items',jsonb_agg(to_jsonb(a) order by month_key,label),
      'open_zero_count',count(*) filter(where status<>'classified'),
      'guardrail','Ausência de categoria em fatura agregada não é tratada como gasto zero.'
    ) from audit a
  );
end
$function$


-- lts_expense_effective_rows_v176(p_user_id uuid, p_from date, p_to date)
CREATE OR REPLACE FUNCTION public.lts_expense_effective_rows_v176(p_user_id uuid, p_from date DEFAULT '2013-10-10'::date, p_to date DEFAULT CURRENT_DATE)
 RETURNS TABLE(event_date date, transaction_date date, competence_month date, amount numeric, category text, center_cost text, counterparty text, origin_type text, origin_name text, source_table text, source_ref text, coverage_mode text, is_property boolean, is_financing boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with base_all as materialized (
  select h.*
  from public.lts_expense_effective_read_cache h
  where h.user_id=p_user_id
    and h.event_date between greatest(p_from,date '2013-10-10') and least(p_to,current_date)
),
card_full as materialized (
  select competence_month,round(sum(amount),2) total
  from public.lts_expense_effective_read_cache
  where user_id=p_user_id and origin_type='cartão'
  group by competence_month
),
src_month as materialized (
  select s.competence_month,round(sum(s.amount),2) source_total,max(s.card_total) declared_total,count(*) source_rows
  from public.lts_v175_workbook_monthly_category_source s
  where s.user_id=p_user_id
  group by s.competence_month
),
eligible as materialized (
  select s.competence_month,s.declared_total,s.source_total
  from src_month s
  join card_full c using(competence_month)
  where abs(s.source_total-s.declared_total)<=0.01
    and abs(c.total-s.declared_total)<=0.01
    and s.competence_month>=date_trunc('month',p_from)::date
    and s.competence_month<=date_trunc('month',p_to)::date
    and (
      s.competence_month>date_trunc('month',p_from)::date
      or p_from=date_trunc('month',p_from)::date
    )
    and (
      s.competence_month<date_trunc('month',p_to)::date
      or p_to>=(date_trunc('month',p_to)+interval '1 month - 1 day')::date
    )
),
retained as (
  select b.event_date,b.transaction_date,b.competence_month,b.amount,b.category,b.center_cost,b.counterparty,
         b.origin_type,b.origin_name,b.source_table,b.source_ref,b.coverage_mode,b.is_property,b.is_financing
  from base_all b
  where not (
    b.origin_type='cartão'
    and exists(select 1 from eligible e where e.competence_month=b.competence_month)
  )
),
allocated as (
  select
    s.competence_month as event_date,
    s.competence_month as transaction_date,
    s.competence_month,
    s.amount,
    coalesce(a.canonical_category,s.category_raw) as category,
    case
      when s.parent_group like 'Benjamin - %' or s.category_raw like 'Benjamin - %' then 'Benjamin'
      when s.parent_group='Larissa' or s.category_raw like 'Larissa - %' then 'Larissa'
      when lower(trim(s.category_raw)) in ('rafiki','pet') then 'Rafiki'
      when s.parent_group='Cipó 396' then 'Casa'
      else 'Não atribuído'
    end as center_cost,
    s.parent_group as counterparty,
    'cartão'::text as origin_type,
    'Consolidado histórico dos cartões'::text as origin_name,
    'lts_v175_workbook_monthly_category_source'::text as source_table,
    s.id::text as source_ref,
    'card_category_allocated_workbook_v176'::text as coverage_mode,
    (s.parent_group='Cipó 396' or s.category_raw ~* 'O Parque') as is_property,
    false as is_financing
  from public.lts_v175_workbook_monthly_category_source s
  join eligible e using(competence_month)
  left join lateral (
    select ca.canonical_category
    from public.lts_category_alias ca
    where ca.active=true and lower(trim(ca.alias))=lower(trim(s.category_raw))
    limit 1
  ) a on true
  where s.user_id=p_user_id
)
select * from retained
union all
select * from allocated
$function$


-- lts_v176_expense_window_qa_v1(p_user_id uuid)
CREATE OR REPLACE FUNCTION public.lts_v176_expense_window_qa_v1(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_checks jsonb:='[]'::jsonb;
  v_pass boolean:=true;
  v_health6 numeric; v_health12 numeric; v_loans6 numeric; v_loans12 numeric;
  v_bad int;
begin
  with r as (
    select * from public.lts_expense_effective_rows_v176(p_user_id,date '2026-04-01',date '2026-09-18')
  )
  select
    round(coalesce(sum(amount) filter(where public.lts_expense_management_group_v3(category,center_cost,counterparty,origin_name,coverage_mode)='Saúde'),0),2),
    round(coalesce(sum(amount) filter(where public.lts_expense_management_group_v3(category,center_cost,counterparty,origin_name,coverage_mode)='Empréstimos'),0),2)
  into v_health6,v_loans6 from r;

  with r as (
    select * from public.lts_expense_effective_rows_v176(p_user_id,date '2025-10-01',date '2026-09-18')
  )
  select
    round(coalesce(sum(amount) filter(where public.lts_expense_management_group_v3(category,center_cost,counterparty,origin_name,coverage_mode)='Saúde'),0),2),
    round(coalesce(sum(amount) filter(where public.lts_expense_management_group_v3(category,center_cost,counterparty,origin_name,coverage_mode)='Empréstimos'),0),2)
  into v_health12,v_loans12 from r;

  v_checks:=v_checks||jsonb_build_array(jsonb_build_object('check','health_6m','pass',abs(v_health6-56307.56)<=0.01,'value',v_health6,'expected',56307.56));
  v_checks:=v_checks||jsonb_build_array(jsonb_build_object('check','health_12m','pass',abs(v_health12-105050.49)<=0.01,'value',v_health12,'expected',105050.49));
  v_checks:=v_checks||jsonb_build_array(jsonb_build_object('check','loans_6m','pass',abs(v_loans6-38691.93)<=0.01,'value',v_loans6,'expected',38691.93));
  v_checks:=v_checks||jsonb_build_array(jsonb_build_object('check','loans_12m','pass',abs(v_loans12-109227.39)<=0.01,'value',v_loans12,'expected',109227.39));
  v_pass:=v_pass and abs(v_health6-56307.56)<=0.01 and abs(v_health12-105050.49)<=0.01 and abs(v_loans6-38691.93)<=0.01 and abs(v_loans12-109227.39)<=0.01;

  select count(*) into v_bad
  from public.lts_expense_effective_rows_v176(p_user_id,date '2026-04-01',date '2026-09-18')
  where coverage_mode='card_category_allocated_workbook_v176'
    and competence_month<date '2026-04-01';
  v_checks:=v_checks||jsonb_build_array(jsonb_build_object('check','no_pre_april_workbook_rows_in_6m','pass',v_bad=0,'bad_rows',v_bad));
  v_pass:=v_pass and v_bad=0;

  return jsonb_build_object('pass',v_pass,'version','v176-expense-window-qa-v1','checks',v_checks,'as_of',current_date);
end
$function$

