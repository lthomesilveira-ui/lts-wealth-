-- Same incoming identities, one canonical expense pass. Older APIs stay byte-identical.
DO $private_owner$ DECLARE d text; BEGIN
 SELECT pg_get_functiondef('lts_income_private.rows_v296(uuid,date,date)'::regprocedure) INTO d;
 IF strpos(d,'p_user_id IS DISTINCT FROM public.lts_browser_assert_user_v1()')=0 THEN
  d:=replace(d,E'BEGIN\n',E'BEGIN\n IF p_user_id IS DISTINCT FROM public.lts_browser_assert_user_v1() THEN RAISE EXCEPTION ''Acesso não autorizado.'';END IF;\n');
  EXECUTE d;
 END IF;
 IF has_function_privilege('authenticated','lts_income_private.rows_v296(uuid,date,date)','EXECUTE')
 OR has_function_privilege('anon','lts_income_private.rows_v296(uuid,date,date)','EXECUTE')
 THEN RAISE EXCEPTION 'Private worker exposed';END IF;
END $private_owner$;
DO $lease$ BEGIN
 IF md5(pg_get_functiondef('public.lts_monthly_balance_v1(uuid,date,date)'::regprocedure)) NOT IN('fda8c35fcf1f62f36900fd5645fe29d2','082c557c0282d2849bcd73ed87547caa')
 OR md5(pg_get_functiondef('public.lts_browser_monthly_v229(date,date)'::regprocedure))<>'a3eae0fdf614951d15016c04b001e256'
 THEN RAISE EXCEPTION 'Monthly reader lease changed';END IF;
END $lease$;
-- Restore the older service-only report. Only V229 uses the new receipt source.
CREATE OR REPLACE FUNCTION public.lts_monthly_balance_v1(p_user_id uuid, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with params as (
  select p_from::date from_date,p_to::date to_date,
         date_trunc('month',p_from)::date from_month,
         date_trunc('month',p_to)::date to_month
), month_count as (
  select ((extract(year from to_month)::int-extract(year from from_month)::int)*12
          +(extract(month from to_month)::int-extract(month from from_month)::int))::int n
  from params
), months as (
  select (p.from_month+make_interval(months=>s.n))::date month_key
  from params p cross join month_count c cross join lateral generate_series(0,c.n) s(n)
), income_raw as (
  select h.*,
         lower(coalesce(h.description,'')) description_lc,
         lower(coalesce(h.category,'')) category_lc
  from params p cross join lateral public.lts_historical_effective_cash_v5(p_user_id,p.from_date,p.to_date) h
  where h.signed_amount>0
), income_screened as (
  select r.*,
    case
      when coalesce(r.internal_transfer,false) or coalesce(r.excluded_from_spend,false)
        or r.category_lc in ('movimentação interna','movimentacao interna','transferência própria','transferencia propria','investimentos')
        or r.description_lc ~ '(recebimento|transfer[eê]ncia).*(ita[uú]|bradesco|c6).*(ita[uú]|bradesco|c6)'
        or r.description_lc ~ '(resgate.*cofrinho|aplica[cç][aã]o.*autom[aá]tica)' then 'excluded'
      when r.description_lc ~ '(empr[eé]stimo|novo coopharma|\mfgts\M|\mvenda\M|aliena[cç][aã]o)' then 'extraordinary'
      else 'revenue'
    end income_kind
  from income_raw r
), income_classified as (
  select date_trunc('month',event_date)::date month_key,income_kind,
    case
      when income_kind='extraordinary' and description_lc ~ '(empr[eé]stimo|novo coopharma)' then 'Empréstimos recebidos'
      when income_kind='extraordinary' and description_lc ~ '\mfgts\M' then 'Resgate de FGTS'
      when income_kind='extraordinary' and description_lc ~ '(\mvenda\M|aliena[cç][aã]o)' then 'Venda de bens e ativos'
      when income_kind='extraordinary' then 'Outras entradas extraordinárias'
      when description_lc ~ '(sal[aá]rio|adiantamento quinzenal|f[eé]rias|13o|13º|b[oô]nus|remunera[cç][aã]o)' or category_lc='salário' then 'Remuneração'
      when description_lc ~ '(reembolso|restitui[cç][aã]o|nota fiscal paulista)' or category_lc like 'reembolso%' then 'Reembolsos e restituições'
      when description_lc ~ 'fam[ií]lia' or category_lc='família' then 'Família'
      when description_lc ~ '(rendimento|juros|remuner.*poup)' or category_lc='rendimentos financeiros' then 'Rendimentos financeiros'
      else 'Outras receitas'
    end group_label,
    signed_amount::numeric amount,source_ref
  from income_screened
  where income_kind<>'excluded'
), income_agg as (
  select month_key,income_kind,group_label,sum(amount)::numeric amount,count(*)::integer source_rows
  from income_classified group by month_key,income_kind,group_label
), income_labels as (
  select income_kind,group_label,sum(amount)::numeric total,sum(source_rows)::integer source_rows
  from income_agg group by income_kind,group_label
), income_groups as (
  select l.income_kind,l.group_label,l.total,l.source_rows,
         jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(a.amount,0)) order by m.month_key) monthly
  from income_labels l cross join months m
  left join income_agg a on a.income_kind=l.income_kind and a.group_label=l.group_label and a.month_key=m.month_key
  group by l.income_kind,l.group_label,l.total,l.source_rows
), expense_classified as (
  select e.competence_month month_key,
    case
      when lower(coalesce(e.counterparty,'')) like '%coopharma%'
        or (coalesce(e.is_financing,false) and lower(coalesce(e.origin_name,'')) like '%coopharma%')
        then 'Empréstimo consignado · Coopharma'
      when e.coverage_mode='card_invoice_aggregate_fallback'
        then 'Faturas históricas sem compras individualizadas'
      else coalesce(nullif(trim(e.category),''),'A classificar')
    end group_label,
    e.amount::numeric amount,e.source_ref,e.coverage_mode
  from params p cross join lateral public.lts_expense_total_rows_v5(p_user_id,p.from_date,p.to_date) e
  where e.event_date between p.from_date and p.to_date
), expense_agg as (
  select month_key,group_label,sum(amount)::numeric amount,count(*)::integer source_rows
  from expense_classified group by month_key,group_label
), expense_labels as (
  select group_label,sum(amount)::numeric total,sum(source_rows)::integer source_rows
  from expense_agg group by group_label
), expense_groups as (
  select l.group_label,l.total,l.source_rows,
         jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(a.amount,0)) order by m.month_key) monthly
  from expense_labels l cross join months m
  left join expense_agg a on a.group_label=l.group_label and a.month_key=m.month_key
  group by l.group_label,l.total,l.source_rows
), month_totals as (
  select m.month_key,
    coalesce((select sum(a.amount) from income_agg a where a.month_key=m.month_key and a.income_kind='revenue'),0)::numeric revenue,
    coalesce((select sum(a.amount) from income_agg a where a.month_key=m.month_key and a.income_kind='extraordinary'),0)::numeric extraordinary,
    coalesce((select sum(a.amount) from expense_agg a where a.month_key=m.month_key),0)::numeric expenses
  from months m
), totals as (
  select coalesce(sum(revenue),0)::numeric revenue,
         coalesce(sum(extraordinary),0)::numeric extraordinary,
         coalesce(sum(expenses),0)::numeric expenses
  from month_totals
), excluded as (
  select coalesce(sum(signed_amount),0)::numeric amount,count(*)::integer source_rows
  from income_screened where income_kind='excluded'
), coverage as (
  select coalesce(sum(amount) filter(where coverage_mode='card_invoice_aggregate_fallback'),0)::numeric historical_invoice_aggregate,
         count(distinct month_key) filter(where coverage_mode='card_invoice_aggregate_fallback')::integer historical_invoice_months,
         count(*)::integer expense_source_rows
  from expense_classified
)
select jsonb_build_object(
  'version','monthly-balance-v1',
  'from',(select from_date from params),
  'to',(select to_date from params),
  'months',(select coalesce(jsonb_agg(month_key order by month_key),'[]'::jsonb) from months),
  'revenue_groups',(select coalesce(jsonb_agg(jsonb_build_object('label',group_label,'total',total,'source_rows',source_rows,'monthly',monthly) order by total desc),'[]'::jsonb) from income_groups where income_kind='revenue'),
  'extraordinary_groups',(select coalesce(jsonb_agg(jsonb_build_object('label',group_label,'total',total,'source_rows',source_rows,'monthly',monthly) order by total desc),'[]'::jsonb) from income_groups where income_kind='extraordinary'),
  'expense_groups',(select coalesce(jsonb_agg(jsonb_build_object('label',group_label,'total',total,'source_rows',source_rows,'monthly',monthly) order by total desc),'[]'::jsonb) from expense_groups),
  'monthly_totals',(select coalesce(jsonb_agg(jsonb_build_object(
       'month',month_key,'revenue',revenue,'extraordinary',extraordinary,'expenses',expenses,
       'operating_balance',revenue-expenses,'cash_after_extraordinary',revenue+extraordinary-expenses
     ) order by month_key),'[]'::jsonb) from month_totals),
  'totals',(select jsonb_build_object(
       'revenue',revenue,'extraordinary',extraordinary,'expenses',expenses,
       'operating_balance',revenue-expenses,'cash_after_extraordinary',revenue+extraordinary-expenses
     ) from totals),
  'coverage',(select jsonb_build_object(
       'historical_invoice_aggregate',historical_invoice_aggregate,
       'historical_invoice_months',historical_invoice_months,
       'expense_source_rows',expense_source_rows,
       'excluded_internal_or_investment_inflows',(select amount from excluded),
       'excluded_inflow_rows',(select source_rows from excluded)
     ) from coverage),
  'guardrails',jsonb_build_object(
    'internal_transfers_excluded',true,
    'investments_excluded_from_revenue',true,
    'card_bill_payments_excluded_from_consumption',true,
    'card_purchases_counted_once',true,
    'extraordinary_funding_separated_from_revenue',true,
    'expense_basis','competence_month'
  )
);
$function$;

CREATE OR REPLACE FUNCTION lts_income_private.monthly_base_v296(p_user_id uuid, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with params as (
  select p_from::date from_date,p_to::date to_date,
         date_trunc('month',p_from)::date from_month,
         date_trunc('month',p_to)::date to_month
), month_count as (
  select ((extract(year from to_month)::int-extract(year from from_month)::int)*12
          +(extract(month from to_month)::int-extract(month from from_month)::int))::int n
  from params
), months as (
  select (p.from_month+make_interval(months=>s.n))::date month_key
  from params p cross join month_count c cross join lateral generate_series(0,c.n) s(n)
), income_raw as (
  select h.*,
         lower(coalesce(h.description,'')) description_lc,
         lower(coalesce(h.category,'')) category_lc
  from params p cross join lateral (
    select (x->>'event_date')::date event_date,x->>'description' description,
      x->>'category' category,(x->>'signed_amount')::numeric signed_amount,
      x->>'source_ref' source_ref,false internal_transfer,false excluded_from_spend
    from lts_income_private.rows_v296(p_user_id,p.from_date,p.to_date)x
    union all
    -- Retain excluded documentary rows for the existing coverage counters and
    -- explicit stock-sale supplement; they never become ordinary revenue.
    select h.event_date,h.description,h.category,h.signed_amount,h.source_ref,
      h.internal_transfer,h.excluded_from_spend
    from public.lts_historical_effective_cash_v5(p_user_id,p.from_date,p.to_date)h
    where h.signed_amount>0 and(h.internal_transfer or h.excluded_from_spend)
  )h
  where h.signed_amount>0
), income_screened as (
  select r.*,
    case
      when coalesce(r.internal_transfer,false) or coalesce(r.excluded_from_spend,false)
        or r.category_lc in ('movimentação interna','movimentacao interna','transferência própria','transferencia propria','investimentos')
        or r.description_lc ~ '(recebimento|transfer[eê]ncia).*(ita[uú]|bradesco|c6).*(ita[uú]|bradesco|c6)'
        or r.description_lc ~ '(resgate.*cofrinho|aplica[cç][aã]o.*autom[aá]tica)' then 'excluded'
      when r.description_lc ~ '(empr[eé]stimo|novo coopharma|\mfgts\M|\mvenda\M|aliena[cç][aã]o)' then 'extraordinary'
      else 'revenue'
    end income_kind
  from income_raw r
), income_classified as (
  select date_trunc('month',event_date)::date month_key,income_kind,
    case
      when income_kind='extraordinary' and description_lc ~ '(empr[eé]stimo|novo coopharma)' then 'Empréstimos recebidos'
      when income_kind='extraordinary' and description_lc ~ '\mfgts\M' then 'Resgate de FGTS'
      when income_kind='extraordinary' and description_lc ~ '(\mvenda\M|aliena[cç][aã]o)' then 'Venda de bens e ativos'
      when income_kind='extraordinary' then 'Outras entradas extraordinárias'
      when description_lc ~ '(sal[aá]rio|adiantamento quinzenal|f[eé]rias|13o|13º|b[oô]nus|remunera[cç][aã]o)' or category_lc='salário' then 'Remuneração'
      when description_lc ~ '(reembolso|restitui[cç][aã]o|nota fiscal paulista)' or category_lc like 'reembolso%' then 'Reembolsos e restituições'
      when description_lc ~ 'fam[ií]lia' or category_lc='família' then 'Família'
      when description_lc ~ '(rendimento|juros|remuner.*poup)' or category_lc='rendimentos financeiros' then 'Rendimentos financeiros'
      else 'Outras receitas'
    end group_label,
    signed_amount::numeric amount,source_ref
  from income_screened
  where income_kind<>'excluded'
), income_agg as (
  select month_key,income_kind,group_label,sum(amount)::numeric amount,count(*)::integer source_rows
  from income_classified group by month_key,income_kind,group_label
), income_labels as (
  select income_kind,group_label,sum(amount)::numeric total,sum(source_rows)::integer source_rows
  from income_agg group by income_kind,group_label
), income_groups as (
  select l.income_kind,l.group_label,l.total,l.source_rows,
         jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(a.amount,0)) order by m.month_key) monthly
  from income_labels l cross join months m
  left join income_agg a on a.income_kind=l.income_kind and a.group_label=l.group_label and a.month_key=m.month_key
  group by l.income_kind,l.group_label,l.total,l.source_rows
), expense_classified as (
  select e.competence_month month_key,
    case
      when lower(coalesce(e.counterparty,'')) like '%coopharma%'
        or (coalesce(e.is_financing,false) and lower(coalesce(e.origin_name,'')) like '%coopharma%')
        then 'Empréstimo consignado · Coopharma'
      when e.coverage_mode='card_invoice_aggregate_fallback'
        then 'Faturas históricas sem compras individualizadas'
      else coalesce(nullif(trim(e.category),''),'A classificar')
    end group_label,
    e.amount::numeric amount,e.source_ref,e.coverage_mode
  from params p cross join lateral public.lts_expense_total_rows_v5(p_user_id,p.from_date,p.to_date) e
  where false
), expense_agg as (
  select month_key,group_label,sum(amount)::numeric amount,count(*)::integer source_rows
  from expense_classified group by month_key,group_label
), expense_labels as (
  select group_label,sum(amount)::numeric total,sum(source_rows)::integer source_rows
  from expense_agg group by group_label
), expense_groups as (
  select l.group_label,l.total,l.source_rows,
         jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(a.amount,0)) order by m.month_key) monthly
  from expense_labels l cross join months m
  left join expense_agg a on a.group_label=l.group_label and a.month_key=m.month_key
  group by l.group_label,l.total,l.source_rows
), month_totals as (
  select m.month_key,
    coalesce((select sum(a.amount) from income_agg a where a.month_key=m.month_key and a.income_kind='revenue'),0)::numeric revenue,
    coalesce((select sum(a.amount) from income_agg a where a.month_key=m.month_key and a.income_kind='extraordinary'),0)::numeric extraordinary,
    coalesce((select sum(a.amount) from expense_agg a where a.month_key=m.month_key),0)::numeric expenses
  from months m
), totals as (
  select coalesce(sum(revenue),0)::numeric revenue,
         coalesce(sum(extraordinary),0)::numeric extraordinary,
         coalesce(sum(expenses),0)::numeric expenses
  from month_totals
), excluded as (
  select coalesce(sum(signed_amount),0)::numeric amount,count(*)::integer source_rows
  from income_screened where income_kind='excluded'
), coverage as (
  select coalesce(sum(amount) filter(where coverage_mode='card_invoice_aggregate_fallback'),0)::numeric historical_invoice_aggregate,
         count(distinct month_key) filter(where coverage_mode='card_invoice_aggregate_fallback')::integer historical_invoice_months,
         count(*)::integer expense_source_rows
  from expense_classified
)
select jsonb_build_object(
  'version','monthly-balance-v1',
  'from',(select from_date from params),
  'to',(select to_date from params),
  'months',(select coalesce(jsonb_agg(month_key order by month_key),'[]'::jsonb) from months),
  'revenue_groups',(select coalesce(jsonb_agg(jsonb_build_object('label',group_label,'total',total,'source_rows',source_rows,'monthly',monthly) order by total desc),'[]'::jsonb) from income_groups where income_kind='revenue'),
  'extraordinary_groups',(select coalesce(jsonb_agg(jsonb_build_object('label',group_label,'total',total,'source_rows',source_rows,'monthly',monthly) order by total desc),'[]'::jsonb) from income_groups where income_kind='extraordinary'),
  'expense_groups',(select coalesce(jsonb_agg(jsonb_build_object('label',group_label,'total',total,'source_rows',source_rows,'monthly',monthly) order by total desc),'[]'::jsonb) from expense_groups),
  'monthly_totals',(select coalesce(jsonb_agg(jsonb_build_object(
       'month',month_key,'revenue',revenue,'extraordinary',extraordinary,'expenses',expenses,
       'operating_balance',revenue-expenses,'cash_after_extraordinary',revenue+extraordinary-expenses
     ) order by month_key),'[]'::jsonb) from month_totals),
  'totals',(select jsonb_build_object(
       'revenue',revenue,'extraordinary',extraordinary,'expenses',expenses,
       'operating_balance',revenue-expenses,'cash_after_extraordinary',revenue+extraordinary-expenses
     ) from totals),
  'coverage',(select jsonb_build_object(
       'historical_invoice_aggregate',historical_invoice_aggregate,
       'historical_invoice_months',historical_invoice_months,
       'expense_source_rows',expense_source_rows,
       'excluded_internal_or_investment_inflows',(select amount from excluded),
       'excluded_inflow_rows',(select source_rows from excluded)
     ) from coverage),
  'guardrails',jsonb_build_object(
    'internal_transfers_excluded',true,
    'investments_excluded_from_revenue',true,
    'card_bill_payments_excluded_from_consumption',true,
    'card_purchases_counted_once',true,
    'extraordinary_funding_separated_from_revenue',true,
    'expense_basis','competence_month'
  )
);
$function$;
REVOKE ALL ON FUNCTION lts_income_private.monthly_base_v296(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_income_private.monthly_base_v296(uuid,date,date) TO service_role;

CREATE OR REPLACE FUNCTION lts_income_private.monthly_groups_v296(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
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

  v_base:=lts_income_private.monthly_base_v296(v_uid,p_from,p_to);

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
$function$;
REVOKE ALL ON FUNCTION lts_income_private.monthly_groups_v296(date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_income_private.monthly_groups_v296(date,date) TO service_role;

CREATE OR REPLACE FUNCTION lts_income_private.monthly_supplement_v296(p_from date, p_to date)
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

  v_base:=lts_income_private.monthly_groups_v296(p_from,p_to);
  v_stock_base:=coalesce(v_base->'stock_sale_supplement','{}'::jsonb);

  with months as (
    select (jsonb_array_elements_text(v_base->'months'))::date month_key
  ), rows as materialized (
    select * from public.lts_expense_effective_rows_v175(v_uid,p_from,p_to) where false
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
    select * from public.lts_expense_effective_rows_v175(v_uid,p_from,p_to) where false
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
$function$;
REVOKE ALL ON FUNCTION lts_income_private.monthly_supplement_v296(date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_income_private.monthly_supplement_v296(date,date) TO service_role;

CREATE OR REPLACE FUNCTION lts_income_private.monthly_window_v296(p_from date, p_to date)
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
  v_base:=lts_income_private.monthly_supplement_v296(p_from,p_to);

  with months as (
    select (jsonb_array_elements_text(v_base->'months'))::date month_key
  ),
  rows as materialized (
    select * from public.lts_expense_effective_rows_v176(v_uid,p_from,p_to) where false
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
    select * from public.lts_expense_effective_rows_v176(v_uid,p_from,p_to) where false
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
$function$;
REVOKE ALL ON FUNCTION lts_income_private.monthly_window_v296(date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_income_private.monthly_window_v296(date,date) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_browser_monthly_v229(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1(); b jsonb; groups jsonb; computed numeric; month_amounts jsonb; coverage jsonb;
BEGIN
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<date '2013-10-10' OR p_to>current_date THEN RAISE EXCEPTION 'invalid monthly range';END IF;
 b:=lts_income_private.monthly_window_v296(p_from,p_to);
 WITH r AS MATERIALIZED(SELECT * FROM public.lts_v229_expense_rows(u,p_from,p_to)),
 months AS(SELECT (m#>>'{}')::date month_key FROM jsonb_array_elements(b->'months') m),
 a AS(SELECT management_group label,competence_month month_key,sum(amount) amount,count(*) source_rows FROM r WHERE coverage_mode<>'card_invoice_aggregate_fallback' GROUP BY 1,2),
 labels AS(SELECT label,sum(amount) total,sum(source_rows) source_rows FROM a GROUP BY label),
 monthly AS(SELECT competence_month month_key,sum(amount) amount FROM r GROUP BY 1),
 unknown AS(SELECT competence_month month_key,sum(amount) amount FROM r WHERE coverage_mode='card_invoice_aggregate_fallback' GROUP BY 1)
 SELECT coalesce(jsonb_agg(jsonb_build_object('label',l.label,'total',round(l.total,2),'source_rows',l.source_rows,
 'monthly',(SELECT jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(a.amount,0)) ORDER BY m.month_key)
 FROM months m LEFT JOIN a ON a.month_key=m.month_key AND a.label=l.label)) ORDER BY l.total DESC,l.label),'[]'),
 (SELECT round(coalesce(sum(amount),0),2) FROM r),
 (SELECT coalesce(jsonb_agg(to_jsonb(monthly)),'[]') FROM monthly),
 jsonb_build_object('total',(SELECT coalesce(sum(amount),0) FROM unknown),
 'source_rows',(SELECT count(*) FROM r),'months',(SELECT count(*) FROM unknown WHERE amount<>0),
 'monthly',(SELECT coalesce(jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(x.amount,0)) ORDER BY m.month_key),'[]')
 FROM months m LEFT JOIN unknown x ON x.month_key=m.month_key))
 INTO groups,computed,month_amounts,coverage FROM labels l;
 b:=b||jsonb_build_object('coverage',coalesce(b->'coverage','{}')||jsonb_build_object('historical_invoice_aggregate',(coverage->>'total')::numeric,'historical_invoice_months',(coverage->>'months')::integer,'expense_source_rows',(coverage->>'source_rows')::integer),'monthly_totals',coalesce((SELECT jsonb_agg(m||jsonb_build_object(
 'expenses',coalesce((a->>'amount')::numeric,0),
 'operating_balance',(m->>'revenue')::numeric-coalesce((a->>'amount')::numeric,0),
 'cash_after_extraordinary',(m->>'revenue')::numeric+coalesce((m->>'extraordinary')::numeric,0)-coalesce((a->>'amount')::numeric,0)) ORDER BY m->>'month')
 FROM jsonb_array_elements(b->'monthly_totals') m LEFT JOIN jsonb_array_elements(month_amounts) a ON a->>'month_key'=m->>'month'),'[]'),
 'totals',(b->'totals')||jsonb_build_object('expenses',computed,
 'operating_balance',(b#>>'{totals,revenue}')::numeric-computed,
 'cash_after_extraordinary',(b#>>'{totals,revenue}')::numeric+coalesce((b#>>'{totals,extraordinary}')::numeric,0)-computed),
 'expense_unclassified_card_coverage',coverage);
 IF abs(computed-coalesce((SELECT sum((m->>'expenses')::numeric) FROM jsonb_array_elements(b->'monthly_totals') m),0))>.005
 OR abs(computed-coalesce((SELECT sum((g->>'total')::numeric) FROM jsonb_array_elements(groups)g),0)-(coverage->>'total')::numeric)>.005
 THEN RAISE EXCEPTION 'monthly classified rows, months and total do not reconcile';END IF;
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,b||jsonb_build_object('version','monthly-v178-person-integrity','expense_groups',groups,'expense_total_verified',computed));
END $function$;
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
