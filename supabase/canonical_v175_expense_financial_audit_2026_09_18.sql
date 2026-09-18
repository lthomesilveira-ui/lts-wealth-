-- V175 canonical financial-expense audit recovery snapshot
-- Generated 2026-09-18 from live Supabase function definitions after validated migrations.
-- Applied migration names:
--   v175_workbook_monthly_category_source
--   v175_expense_financial_audit_core
--   v175_expense_financial_audit_readers
--   v175_cipo_component_order_fix
--   v175_financial_audit_qa
--
-- Workbook category rows are persisted separately in:
-- backups/V175_WORKBOOK_MONTHLY_CATEGORY_SOURCE_2026-09-18.json
-- Raw financial source rows are NOT rewritten by this package.

-- Private source tables created by V175:
create table if not exists public.lts_v175_workbook_monthly_category_source(
  id bigserial primary key,
  user_id uuid not null,
  competence_month date not null,
  parent_group text,
  category_raw text not null,
  amount numeric not null,
  card_total numeric not null,
  source_row integer not null,
  source_workbook_sha256 text not null,
  source_label text not null default 'Controle_Financeiro_v16.xlsm · Consolidado Cartão de Crédito',
  created_at timestamptz not null default now(),
  unique(user_id,competence_month,source_row)
);
alter table public.lts_v175_workbook_monthly_category_source enable row level security;

create table if not exists public.lts_v175_audit_issue(
  issue_id text primary key,
  user_id uuid not null,
  domain text not null,
  status text not null,
  title text not null,
  detail text not null,
  evidence jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.lts_v175_audit_issue enable row level security;


-- lts_browser_card_flow_schedule_v2(p_from date, p_to date)
CREATE OR REPLACE FUNCTION public.lts_browser_card_flow_schedule_v2(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_base jsonb:=public.lts_browser_card_flow_schedule_v1(p_from,p_to);
begin
  return v_base||jsonb_build_object(
    'version','card-flow-schedule-v2-v175',
    'inventory',public.lts_browser_card_inventory_v1(),
    'reading_contract',jsonb_build_object(
      'observed_invoice_precedence',true,
      'installment_floor_is_not_flow',true,
      'historical_inactive_cards_in_inventory',true
    )
  );
end
$function$


-- lts_browser_card_inventory_v1()
CREATE OR REPLACE FUNCTION public.lts_browser_card_inventory_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare v_uid uuid:=public.lts_browser_assert_user_v1();
begin
  return (
    with h as materialized (
      select * from public.lts_historical_effective_cash_v5(v_uid,date '2013-10-10',current_date)
      where signed_amount<0
    ), c as (
      select
        'Itaú' bank,'Mastercard Black Itaú' card_name,'Mastercard' family,null::text last4,
        min(event_date) filter(where account='Itaú' and description='Mastercard') first_seen,
        max(event_date) filter(where account='Itaú' and description='Mastercard') last_seen,
        sum(abs(signed_amount)) filter(where account='Itaú' and description='Mastercard') total_flow,
        true evidence
      from h
      union all select 'Itaú','Visa Itaú','Visa',null,
        min(event_date) filter(where account='Itaú' and description='Visa'),
        max(event_date) filter(where account='Itaú' and description='Visa'),
        sum(abs(signed_amount)) filter(where account='Itaú' and description='Visa'),true from h
      union all select 'Itaú','Visa Infinite Itaú','Visa Infinite',null,
        min(event_date) filter(where account='Itaú' and description='Visa Infinite - Itaú'),
        max(event_date) filter(where account='Itaú' and description='Visa Infinite - Itaú'),
        sum(abs(signed_amount)) filter(where account='Itaú' and description='Visa Infinite - Itaú'),true from h
      union all select 'Bradesco','Visa Infinite Prime','Visa Infinite','3980',
        min(event_date) filter(where account='Bradesco' and description='Visa Infinite'),
        max(event_date) filter(where account='Bradesco' and description='Visa Infinite'),
        sum(abs(signed_amount)) filter(where account='Bradesco' and description='Visa Infinite'),true from h
      union all select 'Bradesco','Visa Aeternum','Visa Aeternum',null,
        min(event_date) filter(where account='Bradesco' and description ~* 'Visa Aeternum|Fatura Visa Aeternum'),
        max(event_date) filter(where account='Bradesco' and description ~* 'Visa Aeternum|Fatura Visa Aeternum'),
        sum(abs(signed_amount)) filter(where account='Bradesco' and description ~* 'Visa Aeternum|Fatura Visa Aeternum'),true from h
      union all select 'C6','C6 histórico','C6','6610',
        min(competence_month),max(competence_month),sum(amount),true
        from public.lts_card_history_recovered_purchase where user_id=v_uid and card_final='6610'
      union all select 'C6','C6 Carbon','C6 Carbon','7873',
        min(competence_month),max(competence_month),sum(amount),true
        from public.lts_card_history_recovered_purchase where user_id=v_uid and card_final='7873'
      union all select 'C6','C6 Carbon','C6 Carbon','8304',
        min(competence_month),max(competence_month),sum(amount),true
        from public.lts_card_history_recovered_purchase where user_id=v_uid and card_final='8304'
    )
    select jsonb_build_object(
      'version','card-inventory-v1',
      'cards',coalesce(jsonb_agg(jsonb_build_object(
        'bank',bank,'card_name',card_name,'family',family,'last4',last4,
        'first_seen',first_seen,'last_seen',last_seen,'historical_amount_evidence',round(coalesce(total_flow,0),2),
        'status',case when last_seen>=current_date-interval '120 days' then 'current_or_recent' else 'historical' end
      ) order by bank,card_name,last4),'[]'::jsonb),
      'guardrail','Cartão inativo hoje continua no histórico. Valores são evidência de uso/fatura, não saldo devedor.'
    ) from c where evidence and first_seen is not null
  );
end
$function$


-- lts_browser_cipo_improvement_reconciliation_v2()
CREATE OR REPLACE FUNCTION public.lts_browser_cipo_improvement_reconciliation_v2()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid:=public.lts_browser_assert_user_v1();
  v_source jsonb:=public.lts_cipo_reconciliation_v4(v_uid);
  v_unique numeric:=0;
  v_source_card numeric:=0;
  v_dated numeric:=0;
  v_dated_card numeric:=0;
begin
  select round(coalesce(sum(source_paid),0),2) into v_unique
  from public.lts_cipo_source_component where user_id=v_uid and component_class='improvement';

  select round(coalesce(sum(source_paid),0),2) into v_source_card
  from public.lts_cipo_source_component
  where user_id=v_uid and component_class='improvement'
    and reconciliation_method='source_workbook_card_aggregate';

  select
    round(coalesce(sum(amount),0),2),
    round(coalesce(sum(amount) filter(where origin_type='cartão'),0),2)
  into v_dated,v_dated_card
  from public.lts_expense_effective_rows_v175(v_uid,date '2013-10-10',current_date)
  where public.lts_expense_management_group_v3(category,center_cost,counterparty,origin_name,coverage_mode)
        ='Investimentos no imóvel — obra e reforma';

  return jsonb_build_object(
    'version','cipo-improvement-browser-v2-v175',
    'workbook_summary_brl',nullif(v_source#>>'{source_internal_consistency,workbook_summary_reforms_improvements}','')::numeric,
    'reconciled_unique_brl',v_unique,
    'duplicate_source_brl',nullif(v_source#>>'{source_internal_consistency,duplicate_row_amount}','')::numeric,
    'duplicate_component',v_source#>>'{source_internal_consistency,duplicate_component}',
    'dated_reader_brl',v_dated,
    'historical_card_source_brl',v_source_card,
    'historical_card_classified_brl',v_dated_card,
    'historical_card_coverage_gap_brl',greatest(round(v_source_card-v_dated_card,2),0),
    'source_components',coalesce((
      select jsonb_agg(jsonb_build_object(
        'name',regexp_replace(source_description,'\s*-\s*O Parque\s*$','','i'),
        'total',total,'rows',rows,'origins',origins
      ) order by total desc,source_description)
      from (
        select source_description,round(sum(source_paid),2) total,count(*) rows,
               string_agg(distinct source_origin,', ' order by source_origin) origins
        from public.lts_cipo_source_component
        where user_id=v_uid and component_class='improvement'
        group by source_description
      ) q
    ),'[]'::jsonb),
    'guardrail','O total reconciliado usa componentes econômicos únicos. O resumo original e a duplicidade de R$ 2.937,26 continuam preservados como evidência; o complemento histórico de cartão não recebe datas inventadas.'
  );
end
$function$


-- lts_browser_expense_executive_v8(p_from date, p_to date)
CREATE OR REPLACE FUNCTION public.lts_browser_expense_executive_v8(p_from date DEFAULT '2023-01-01'::date, p_to date DEFAULT CURRENT_DATE)
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
  v_prop jsonb:='{}'::jsonb;
  v_full boolean:=false;
  v_property_total numeric:=0;
  v_card_gap numeric:=0;
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
  v_base:=public.lts_browser_expense_executive_v7(p_from,p_to);
  v_full:=p_from<=date '2013-10-10' and p_to>=current_date;

  if v_full then
    v_prop:=public.lts_browser_cipo_improvement_reconciliation_v2();
    v_property_total:=coalesce((v_prop->>'reconciled_unique_brl')::numeric,0);
    v_card_gap:=coalesce((v_prop->>'historical_card_coverage_gap_brl')::numeric,0);
  end if;

  with rows as materialized (
    select * from public.lts_expense_effective_rows_v175(v_uid,p_from,p_to)
  ), classified as materialized (
    select r.*,
      public.lts_expense_management_group_v3(r.category,r.center_cost,r.counterparty,r.origin_name,r.coverage_mode) management_group,
      case
        when r.category ~* '^Financiamento ve[ií]culo' and r.source_ref='volvo_financing_2026_p01' then 'Volvo XC40'
        else public.lts_expense_management_subgroup_v2(r.category,r.center_cost,r.counterparty,r.origin_name,r.coverage_mode)
      end management_subgroup
    from rows r
  ), g as (
    select management_group,round(sum(amount),2) total,count(*) rows
    from classified
    where management_group<>'Faturas conciliadas pelo total'
      and (not v_full or management_group<>'Investimentos no imóvel — obra e reforma')
    group by management_group
  ), sg as (
    select management_group,management_subgroup,round(sum(amount),2) total,count(*) rows
    from classified
    where management_group<>'Faturas conciliadas pelo total'
      and (not v_full or management_group<>'Investimentos no imóvel — obra e reforma')
    group by management_group,management_subgroup
  ), sc as (
    select management_group,coalesce(nullif(trim(category),''),'A classificar') category_name,
           round(sum(amount),2) total,count(*) rows
    from classified
    where management_group<>'Faturas conciliadas pelo total'
      and (not v_full or management_group<>'Investimentos no imóvel — obra e reforma')
    group by management_group,coalesce(nullif(trim(category),''),'A classificar')
  ), normal_groups as (
    select jsonb_build_object(
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
    ) obj from g
  ), prop_group as (
    select jsonb_build_object(
      'name','Investimentos no imóvel — obra e reforma',
      'total',v_property_total,
      'rows',coalesce(jsonb_array_length(v_prop->'source_components'),0),
      'source_reconciled',true,
      'subgroups',coalesce(v_prop->'source_components','[]'::jsonb),
      'source_categories',coalesce(v_prop->'source_components','[]'::jsonb)
    ) obj
    where v_full and v_property_total>0
  )
  select coalesce(jsonb_agg(obj order by (obj->>'total')::numeric desc,obj->>'name'),'[]'::jsonb)
    into v_groups
  from (
    select obj from normal_groups
    union all
    select obj from prop_group
  ) q;

  with rows as materialized (
    select * from public.lts_expense_effective_rows_v175(v_uid,p_from,p_to)
  ), cov as (
    select round(coalesce(sum(amount),0),2) total,count(*) rows,count(distinct competence_month) months,
           coalesce(jsonb_agg(jsonb_build_object('name',origin_name,'total',amount,'month',competence_month)
                              order by competence_month,origin_name),'[]'::jsonb) detail
    from rows where coverage_mode='card_invoice_aggregate_fallback'
  )
  select jsonb_build_object(
    'label','Faturas conciliadas pelo total',
    'total',greatest(coalesce(total,0)-case when v_full then v_card_gap else 0 end,0),
    'raw_aggregate_total',coalesce(total,0),
    'property_source_reallocated',case when v_full then v_card_gap else 0 end,
    'rows',rows,'months',months,'by_origin',detail,
    'guardrail','O total da fatura continua preservado. Parcela documentalmente reconciliada em obra é transferida da cobertura sem categoria para o grupo de obra; o restante não recebe categoria inventada.'
  ) into v_coverage from cov;

  return v_base||jsonb_build_object(
    'version','expense-executive-v17-v175-financial-audit',
    'management_groups',v_groups,
    'coverage_disclosure',v_coverage,
    'property_improvement_reconciliation',v_prop,
    'loan_audit',public.lts_browser_loan_audit_v1(),
    'management_group_contract',jsonb_build_object(
      'version','professional-management-groups-v5',
      'all_supported_cards_and_accounts_once',true,
      'recent_workbook_card_category_reconciliation',true,
      'loan_lender_split_by_counterparty',true,
      'family_outflows_explicit',true,
      'property_source_reconciled_full_history',true
    ),
    'summary',coalesce(v_base->'summary','{}'::jsonb)||
      case when v_full then jsonb_build_object('property_total',v_property_total) else '{}'::jsonb end
  );
end
$function$


-- lts_browser_loan_audit_v1()
CREATE OR REPLACE FUNCTION public.lts_browser_loan_audit_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare v_uid uuid:=public.lts_browser_assert_user_v1();
begin
  return (
    with x as (
      select h.event_date,h.amount,h.category,h.counterparty,h.origin_name,h.source_table,h.source_ref
      from public.lts_expense_effective_read_cache h
      where h.user_id=v_uid and h.category ~* '^(Empr[eé]stimos|Compromissos Financeiros)'
    ), source_split as (
      select
        case
          when category ~* '^Compromissos Financeiros' then 'Coopharma'
          when counterparty ~* '^Ita[uú]$' then 'Itaú'
          when counterparty ~* 'CooperMSD' then 'CooperMSD'
          when counterparty ~* '^CGI$' then 'CGI'
          when counterparty ~* '^CEF$' then 'CEF'
          when counterparty ~* 'Funcef' then 'Funcef'
          else coalesce(counterparty,'Não identificado')
        end lender,
        count(*) rows,round(sum(amount),2) paid_history,min(event_date) first_date,max(event_date) last_date
      from x group by 1
    )
    select jsonb_build_object(
      'version','loan-audit-v1',
      'historical_paid_total',(select round(sum(amount),2) from x),
      'source_split',coalesce((select jsonb_agg(to_jsonb(s) order by paid_history desc) from source_split s),'[]'::jsonb),
      'documentary_positions',coalesce((
        select jsonb_agg(jsonb_build_object(
          'commitment_id',d.commitment_id,'as_of',d.as_of_date,'institution',d.institution,
          'debt_balance',d.debt_balance,'status',d.status,'source_label',d.source_label,'metadata',d.metadata
        ) order by d.as_of_date desc)
        from public.lts_debt_position d where d.user_id=v_uid
      ),'[]'::jsonb),
      'guardrail','Histórico pago não é saldo devedor atual. Só mostrar dívida atual quando houver posição documental de saldo.'
    )
  );
end
$function$


-- lts_browser_monthly_balance_v5(p_from date, p_to date)
CREATE OR REPLACE FUNCTION public.lts_browser_monthly_balance_v5(p_from date, p_to date)
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
  v_confirmed jsonb:='[]'::jsonb;
  v_confirmed_total numeric:=0;
  v_stock_base jsonb;
  v_stock_combined jsonb;
  v_stock_total numeric:=0;
  v_extra_groups jsonb;
  v_month_totals jsonb;
  v_totals jsonb;
  v_open_issues jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid monthly balance range'; end if;
  if p_from<date '2013-10-10' or p_to>current_date then raise exception 'monthly balance range outside available history'; end if;

  v_base:=public.lts_browser_monthly_balance_v3(p_from,p_to);
  v_stock_base:=coalesce(v_base->'stock_sale_supplement','{}'::jsonb);

  with months as (
    select (jsonb_array_elements_text(v_base->'months'))::date month_key
  ), rows as materialized (
    select * from public.lts_expense_effective_rows_v175(v_uid,p_from,p_to)
  ), agg as (
    select competence_month month_key,
           public.lts_expense_management_group_v3(category,center_cost,counterparty,origin_name,coverage_mode) label,
           sum(amount)::numeric amount,count(*)::integer source_rows
    from rows
    where public.lts_expense_management_group_v3(category,center_cost,counterparty,origin_name,coverage_mode)
          <>'Faturas conciliadas pelo total'
    group by 1,2
  ), labels as (
    select label,sum(amount)::numeric total,sum(source_rows)::integer source_rows from agg group by label
  ), final as (
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
  ), rows as materialized (
    select * from public.lts_expense_effective_rows_v175(v_uid,p_from,p_to)
  ), agg as (
    select competence_month month_key,sum(amount)::numeric amount,count(*)::integer source_rows
    from rows where coverage_mode='card_invoice_aggregate_fallback'
    group by competence_month
  )
  select jsonb_build_object(
    'label','Faturas conciliadas pelo total',
    'total',round(coalesce(sum(a.amount),0),2),
    'source_rows',coalesce(sum(a.source_rows),0),
    'monthly',jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(a.amount,0)) order by m.month_key),
    'explanation','Quando o total da fatura existe mas a compra individual não está documentada, o LTS preserva o total sem inventar Restaurante, iFood, Rafiki ou outra categoria.'
  ) into v_coverage
  from months m left join agg a on a.month_key=m.month_key;

  with months as (
    select (jsonb_array_elements_text(v_base->'months'))::date month_key
  ), c as (
    select date_trunc('month',fe.event_date)::date month_key,sum(fe.amount)::numeric amount,count(*)::integer source_rows
    from public.financial_events fe
    where fe.user_id=v_uid and fe.event_date between p_from and p_to
      and fe.status='active' and not coalesce(fe.is_suppressed,false)
      and fe.amount>0
      and coalesce((fe.metadata->>'sale_context_confirmed_by_user')::boolean,false)=true
      and coalesce(fe.description_raw,'') !~* '(venda.*a[cç][oõ]es|realiza[cç][aã]o.*venda.*a[cç][oõ]es)'
    group by 1
  )
  select coalesce(sum(c.amount),0),
         jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(c.amount,0),'source_rows',coalesce(c.source_rows,0)) order by m.month_key)
  into v_confirmed_total,v_confirmed
  from months m left join c using(month_key);

  with months as (
    select (jsonb_array_elements_text(v_base->'months'))::date month_key
  ), b as (
    select (x->>'month')::date month_key,(x->>'amount')::numeric amount,coalesce((x->>'source_rows')::int,0) source_rows
    from jsonb_array_elements(coalesce(v_stock_base->'monthly','[]'::jsonb)) x
  ), c as (
    select (x->>'month')::date month_key,(x->>'amount')::numeric amount,coalesce((x->>'source_rows')::int,0) source_rows
    from jsonb_array_elements(coalesce(v_confirmed,'[]'::jsonb)) x
  )
  select round(coalesce(sum(coalesce(b.amount,0)+coalesce(c.amount,0)),0),2),
         jsonb_agg(jsonb_build_object(
           'month',m.month_key,'amount',coalesce(b.amount,0)+coalesce(c.amount,0),
           'source_rows',coalesce(b.source_rows,0)+coalesce(c.source_rows,0)
         ) order by m.month_key)
  into v_stock_total,v_stock_combined
  from months m left join b using(month_key) left join c using(month_key);

  with months as (
    select (jsonb_array_elements_text(v_base->'months'))::date month_key
  ), base_sale as (
    select (x->>'month')::date month_key,(x->>'amount')::numeric amount
    from jsonb_array_elements(coalesce(v_stock_base->'monthly','[]'::jsonb)) x
  ), goods_base as (
    select g
    from jsonb_array_elements(coalesce(v_base->'extraordinary_groups','[]'::jsonb)) g
    where g->>'label'='Venda de bens e ativos'
  ), goods_month as (
    select m.month_key,
      greatest(
        coalesce((
          select sum((mi->>'amount')::numeric)
          from goods_base gb cross join lateral jsonb_array_elements(coalesce(gb.g->'monthly','[]'::jsonb)) mi
          where (mi->>'month')::date=m.month_key
        ),0)-coalesce(bs.amount,0),0
      ) amount
    from months m left join base_sale bs using(month_key)
  ), other_groups as (
    select g
    from jsonb_array_elements(coalesce(v_base->'extraordinary_groups','[]'::jsonb)) g
    where g->>'label'<>'Venda de bens e ativos'
  ), built as (
    select g obj from other_groups
    union all
    select jsonb_build_object(
      'label','Venda de ações, RSUs e outros ativos','total',v_stock_total,
      'source_rows',(select coalesce(sum((x->>'source_rows')::int),0) from jsonb_array_elements(v_stock_combined) x),
      'monthly',v_stock_combined
    ) where v_stock_total<>0
    union all
    select jsonb_build_object(
      'label','Venda de bens','total',round(sum(amount),2),'source_rows',0,
      'monthly',jsonb_agg(jsonb_build_object('month',month_key,'amount',amount) order by month_key)
    ) from goods_month having sum(amount)<>0
  )
  select coalesce(jsonb_agg(obj order by (obj->>'total')::numeric desc,obj->>'label'),'[]'::jsonb)
  into v_extra_groups from built;

  with c as (
    select (x->>'month')::date month_key,(x->>'amount')::numeric amount
    from jsonb_array_elements(v_confirmed) x
  )
  select coalesce(jsonb_agg(
    (r.j-'extraordinary'-'cash_after_extraordinary')||
    jsonb_build_object(
      'extraordinary',coalesce((r.j->>'extraordinary')::numeric,0)+coalesce(c.amount,0),
      'cash_after_extraordinary',coalesce((r.j->>'cash_after_extraordinary')::numeric,0)+coalesce(c.amount,0)
    ) order by (r.j->>'month')::date
  ),'[]'::jsonb)
  into v_month_totals
  from jsonb_array_elements(coalesce(v_base->'monthly_totals','[]'::jsonb)) r(j)
  left join c on c.month_key=(r.j->>'month')::date;

  v_totals:=coalesce(v_base->'totals','{}'::jsonb)||
    jsonb_build_object(
      'extraordinary',coalesce((v_base#>>'{totals,extraordinary}')::numeric,0)+v_confirmed_total,
      'cash_after_extraordinary',coalesce((v_base#>>'{totals,cash_after_extraordinary}')::numeric,0)+v_confirmed_total
    );

  select coalesce(jsonb_agg(jsonb_build_object(
    'issue_id',issue_id,'status',status,'title',title,'detail',detail,'evidence',evidence
  ) order by issue_id),'[]'::jsonb)
  into v_open_issues
  from public.lts_v175_audit_issue
  where user_id=v_uid and status='open'
    and domain in ('extraordinary_income','expenses');

  return v_base||jsonb_build_object(
    'version','monthly-balance-v5-v175-financial-audit',
    'expense_groups',v_groups,
    'expense_unclassified_card_coverage',v_coverage,
    'extraordinary_groups',v_extra_groups,
    'monthly_totals',v_month_totals,
    'totals',v_totals,
    'stock_sale_supplement',jsonb_build_object(
      'total',v_stock_total,'monthly',v_stock_combined,
      'confirmed_source_addition',v_confirmed_total,
      'rule','Venda explícita/confirmada de ações é entrada extraordinária. Transferências posteriores entre C6, Itaú e Bradesco permanecem neutras.'
    ),
    'open_audit_issues',v_open_issues,
    'recurring_gap_audit',public.lts_browser_recurring_category_gap_audit_v1(greatest(p_from,date '2025-11-01'),p_to)
  );
end
$function$


-- lts_browser_recurring_category_gap_audit_v1(p_from date, p_to date)
CREATE OR REPLACE FUNCTION public.lts_browser_recurring_category_gap_audit_v1(p_from date DEFAULT '2025-11-01'::date, p_to date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare v_uid uuid:=public.lts_browser_assert_user_v1();
begin
  return (
    with rows as materialized (select * from public.lts_expense_effective_rows_v175(v_uid,p_from,p_to)),
    months as (
      select generate_series(date_trunc('month',p_from)::date,date_trunc('month',p_to)::date,interval '1 month')::date month_key
    ), targets(label) as (values('Restaurantes'),('Ifood'),('Rafiki')),
    g as (
      select competence_month,public.lts_expense_management_group_v3(category,center_cost,counterparty,origin_name,coverage_mode) label,
             sum(amount)::numeric amount,count(*) rows
      from rows group by 1,2
    ), cov as (
      select competence_month,sum(amount)::numeric amount
      from rows where coverage_mode='card_invoice_aggregate_fallback' group by 1
    ), audit as (
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
      'version','recurring-gap-audit-v1','from',p_from,'to',p_to,
      'items',jsonb_agg(to_jsonb(a) order by month_key,label),
      'open_zero_count',count(*) filter(where status<>'classified'),
      'guardrail','Ausência de categoria em fatura agregada não é tratada como gasto zero.'
    ) from audit a
  );
end
$function$


-- lts_expense_effective_rows_v175(p_user_id uuid, p_from date, p_to date)
CREATE OR REPLACE FUNCTION public.lts_expense_effective_rows_v175(p_user_id uuid, p_from date DEFAULT '2013-10-10'::date, p_to date DEFAULT CURRENT_DATE)
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
    and (
      s.competence_month>date_trunc('month',p_from)::date
      or p_from=date_trunc('month',p_from)::date
    )
    and (
      s.competence_month<date_trunc('month',p_to)::date
      or p_to >= (date_trunc('month',p_to)+interval '1 month - 1 day')::date
    )
),
retained as (
  select b.event_date,b.transaction_date,b.competence_month,b.amount,b.category,b.center_cost,b.counterparty,
         b.origin_type,b.origin_name,b.source_table,b.source_ref,b.coverage_mode,b.is_property,b.is_financing
  from base_all b
  where not (b.origin_type='cartão' and exists(select 1 from eligible e where e.competence_month=b.competence_month))
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
    'card_category_allocated_workbook_v175'::text as coverage_mode,
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


-- lts_expense_management_group_v3(p_category text, p_center_cost text, p_counterparty text, p_origin_name text, p_coverage_mode text)
CREATE OR REPLACE FUNCTION public.lts_expense_management_group_v3(p_category text, p_center_cost text, p_counterparty text, p_origin_name text, p_coverage_mode text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
select case
  when coalesce(p_coverage_mode,'')='card_invoice_aggregate_fallback'
    then 'Faturas conciliadas pelo total'
  when coalesce(p_category,'') ~* '^Financiamento Imobili[aá]rio'
    then 'Financiamento imobiliário'
  when coalesce(p_category,'') ~* '^Financiamento ve[ií]culo'
    then 'Financiamento de veículo'
  when coalesce(p_category,'') ~* '^(Empr[eé]stimos|Compromissos Financeiros)'
    then 'Empréstimos'
  when coalesce(p_category,'') ~* '^(Energia|Enel)'
    then 'Energia'
  when coalesce(p_category,'') ~* '^Condom'
    then 'Condomínio'
  when coalesce(p_category,'') ~* '^(IPTU|Impostos do Im[oó]vel)'
    then 'Impostos do imóvel'
  when coalesce(p_category,'') ~* '^Educa[cç][aã]o$' and coalesce(p_center_cost,'') ~* '^Benjamin$'
    then 'Benjamin — Educação'
  when coalesce(p_category,'') ~* '^Educa[cç][aã]o$'
    then 'Educação'
  when coalesce(p_category,'') ~* '^(Rafiki|Pet)$' or coalesce(p_center_cost,'') ~* '^Rafiki$'
    then 'Rafiki'
  when coalesce(p_category,'') ~* '^Fam[ií]lia$'
    then 'Família — saídas'
  when coalesce(p_category,'') ~* '^Restaurantes( e Lazer)?$'
    then 'Restaurantes'
  when coalesce(p_category,'') ~* '^Assinatura$'
    then 'Assinaturas'
  when coalesce(p_category,'') ~* '^(Cons[oó]rcio.*O Parque|Cart[oó]rio.*O Parque|Cip[oó] 396)$'
    then 'Investimento no imóvel — aquisição e histórico'
  when (
      coalesce(p_category,'') ~* '^Obra e Reforma$'
      or coalesce(p_category,'') ~* 'O Parque'
      or (coalesce(p_category,'') ~* '^M[oó]veis e Decora[cç][aã]o$' and coalesce(p_counterparty,'') ~* 'O Parque')
    )
    and coalesce(p_category,'') !~* '^(Condom|Enel|Energia|IPTU|Impostos|Cons[oó]rcio|Cart[oó]rio|Financiamento)'
    then 'Investimentos no imóvel — obra e reforma'
  else coalesce(nullif(trim(p_category),''),'A classificar')
end
$function$


-- lts_expense_management_subgroup_v2(p_category text, p_center_cost text, p_counterparty text, p_origin_name text, p_coverage_mode text)
CREATE OR REPLACE FUNCTION public.lts_expense_management_subgroup_v2(p_category text, p_center_cost text, p_counterparty text, p_origin_name text, p_coverage_mode text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
select case
  when coalesce(p_coverage_mode,'')='card_invoice_aggregate_fallback'
    then coalesce(nullif(trim(p_origin_name),''),'Fatura sem identificação')
  when coalesce(p_category,'') ~* '^Financiamento Imobili[aá]rio'
    then 'Financiamento imobiliário'
  when coalesce(p_category,'') ~* '^Compromissos Financeiros'
    then 'Empréstimo consignado · Coopharma'
  when coalesce(p_category,'') ~* '^Empr[eé]stimos' and coalesce(p_counterparty,'') ~* '^Ita[uú]$'
    then 'Histórico pago · Itaú'
  when coalesce(p_category,'') ~* '^Empr[eé]stimos' and coalesce(p_counterparty,'') ~* 'CooperMSD'
    then 'Histórico pago · CooperMSD'
  when coalesce(p_category,'') ~* '^Empr[eé]stimos' and coalesce(p_counterparty,'') ~* '^CGI$'
    then 'Histórico pago · CGI'
  when coalesce(p_category,'') ~* '^Empr[eé]stimos' and coalesce(p_counterparty,'') ~* '^CEF$'
    then 'Histórico pago · CEF'
  when coalesce(p_category,'') ~* '^Empr[eé]stimos' and coalesce(p_counterparty,'') ~* 'Funcef'
    then 'Histórico pago · Funcef'
  when coalesce(p_category,'') ~* '^Empr[eé]stimos'
    then 'Histórico pago · '||coalesce(nullif(trim(p_counterparty),''),'origem não identificada')
  when coalesce(p_category,'') ~* '^Financiamento ve[ií]culo'
    then coalesce(nullif(trim(p_counterparty),''),'Veículo não atribuído')
  when coalesce(p_category,'') ~* 'O Parque'
    then trim(regexp_replace(coalesce(p_category,''),'\s*[-·]\s*O Parque\s*$','','i'))
  else coalesce(nullif(trim(p_category),''),'A classificar')
end
$function$


-- lts_v175_financial_audit_qa_v1(p_user_id uuid)
CREATE OR REPLACE FUNCTION public.lts_v175_financial_audit_qa_v1(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_checks jsonb:='[]'::jsonb;
  v_pass boolean:=true;
  v_value numeric;
  v_months int;
  v_bad_months int;
  v_sep_sale numeric;
  v_apr_issue int;
begin
  -- Exact monthly workbook/card parity for Nov/2025 through Jun/2026.
  with src as (
    select competence_month,round(sum(amount),2) src_total,max(card_total) declared
    from public.lts_v175_workbook_monthly_category_source
    where user_id=p_user_id
    group by competence_month
  ), cache as (
    select competence_month,round(sum(amount),2) cache_total
    from public.lts_expense_effective_read_cache
    where user_id=p_user_id and origin_type='cartão'
      and competence_month between date '2025-11-01' and date '2026-06-01'
    group by competence_month
  )
  select count(*) into v_bad_months
  from src s join cache c using(competence_month)
  where abs(s.src_total-s.declared)>0.01 or abs(c.cache_total-s.declared)>0.01;
  v_checks:=v_checks||jsonb_build_array(jsonb_build_object('check','workbook_card_month_parity_nov25_jun26','pass',v_bad_months=0,'bad_months',v_bad_months));
  v_pass:=v_pass and v_bad_months=0;

  -- Restaurant/iFood/Rafiki exact recovered values in user-reported blank months.
  with r as (
    select * from public.lts_expense_effective_rows_v175(p_user_id,date '2025-12-01',date '2026-03-31')
  ), a as (
    select competence_month,
      public.lts_expense_management_group_v3(category,center_cost,counterparty,origin_name,coverage_mode) grp,
      round(sum(amount),2) total
    from r
    where public.lts_expense_management_group_v3(category,center_cost,counterparty,origin_name,coverage_mode) in ('Restaurantes','Ifood','Rafiki')
    group by 1,2
  ), expected(month_key,grp,total) as (
    values
      (date '2025-12-01','Restaurantes',8696.00::numeric),(date '2025-12-01','Ifood',2791.62),(date '2025-12-01','Rafiki',1862.40),
      (date '2026-01-01','Restaurantes',2274.69),(date '2026-01-01','Ifood',515.60),(date '2026-01-01','Rafiki',1706.17),
      (date '2026-02-01','Restaurantes',708.70),(date '2026-02-01','Ifood',1848.76),(date '2026-02-01','Rafiki',1651.89),
      (date '2026-03-01','Restaurantes',1284.70),(date '2026-03-01','Ifood',2263.38),(date '2026-03-01','Rafiki',3302.19)
  )
  select count(*) into v_bad_months
  from expected e left join a on a.competence_month=e.month_key and a.grp=e.grp
  where a.total is null or abs(a.total-e.total)>0.01;
  v_checks:=v_checks||jsonb_build_array(jsonb_build_object('check','reported_month_category_recovery','pass',v_bad_months=0,'mismatches',v_bad_months));
  v_pass:=v_pass and v_bad_months=0;

  -- Itaú historical paid amount separated from other lenders.
  select round(coalesce(sum(amount),0),2) into v_value
  from public.lts_expense_effective_read_cache
  where user_id=p_user_id and category='Empréstimos' and counterparty='Itaú';
  v_checks:=v_checks||jsonb_build_array(jsonb_build_object('check','itau_historical_paid_split','pass',abs(v_value-267441.25)<=0.01,'value',v_value,'expected',267441.25));
  v_pass:=v_pass and abs(v_value-267441.25)<=0.01;

  select round(coalesce(sum(amount),0),2) into v_value
  from public.lts_expense_effective_read_cache
  where user_id=p_user_id and category='Empréstimos' and counterparty='CooperMSD';
  v_checks:=v_checks||jsonb_build_array(jsonb_build_object('check','coopermsd_separate_from_itau','pass',abs(v_value-224164.59)<=0.01,'value',v_value,'expected',224164.59));
  v_pass:=v_pass and abs(v_value-224164.59)<=0.01;

  -- Property source reconciliation.
  select round(coalesce(sum(source_paid),0),2) into v_value
  from public.lts_cipo_source_component
  where user_id=p_user_id and component_class='improvement';
  v_checks:=v_checks||jsonb_build_array(jsonb_build_object('check','property_unique_reconciled_total','pass',abs(v_value-2174777.52)<=0.01,'value',v_value,'expected',2174777.52));
  v_pass:=v_pass and abs(v_value-2174777.52)<=0.01;

  -- Full historical monthly span exists in backend.
  select jsonb_array_length(public.lts_monthly_balance_v1(p_user_id,date '2013-10-10',date '2026-09-18')->'months') into v_months;
  v_checks:=v_checks||jsonb_build_array(jsonb_build_object('check','monthly_history_156_months','pass',v_months=156,'months',v_months));
  v_pass:=v_pass and v_months=156;

  -- September share-sale evidence.
  select round(coalesce(sum(amount),0),2) into v_sep_sale
  from public.financial_events
  where user_id=p_user_id and event_date between date '2026-09-01' and date '2026-09-30'
    and amount>0 and status='active' and not coalesce(is_suppressed,false)
    and coalesce((metadata->>'sale_context_confirmed_by_user')::boolean,false)=true;
  v_checks:=v_checks||jsonb_build_array(jsonb_build_object('check','sep26_stock_sale_confirmed_source','pass',abs(v_sep_sale-18808.69)<=0.01,'value',v_sep_sale,'expected',18808.69));
  v_pass:=v_pass and abs(v_sep_sale-18808.69)<=0.01;

  -- April remains explicit unresolved issue instead of fabricated income.
  select count(*) into v_apr_issue
  from public.lts_v175_audit_issue
  where user_id=p_user_id and issue_id='stock_sale_2026_04_missing_source' and status='open';
  v_checks:=v_checks||jsonb_build_array(jsonb_build_object('check','apr26_stock_sale_source_gap_explicit','pass',v_apr_issue=1));
  v_pass:=v_pass and v_apr_issue=1;

  return jsonb_build_object('pass',v_pass,'version','v175-financial-audit-qa-v1','checks',v_checks,'as_of',current_date);
end
$function$

