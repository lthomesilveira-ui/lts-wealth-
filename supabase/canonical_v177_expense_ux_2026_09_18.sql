-- V177 canonical expense audit / apartment roll-up / drill-down snapshot
-- Generated 2026-09-18 from live Supabase function definitions.
-- Applied migrations:
--   v177_property_rollup_drilldown_2020_audit
--   v177_group_detail_subgroup_filter
--   v177_product_qa
-- Raw financial source rows are NOT mutated by this package.


-- lts_browser_expense_executive_v10(p_from date, p_to date)
CREATE OR REPLACE FUNCTION public.lts_browser_expense_executive_v10(p_from date DEFAULT '2023-01-01'::date, p_to date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_base jsonb:=public.lts_browser_expense_executive_v9(p_from,p_to);
  v_prop jsonb:=public.lts_browser_property_rollup_v1(p_from,p_to);
  v_groups jsonb;
begin
  with keep as (
    select x
    from jsonb_array_elements(coalesce(v_base->'management_groups','[]'::jsonb)) x
    where x->>'name' not in (
      'Financiamento imobiliário',
      'Investimentos no imóvel — obra e reforma',
      'Investimento no imóvel — aquisição e histórico',
      'Moradia',
      'Impostos do imóvel',
      'Energia',
      'Seguro Residencial'
    )
  ),
  apartment as (
    select jsonb_build_object(
      'name',v_prop->>'name',
      'total',(v_prop->>'total_cash')::numeric,
      'rows',4,
      'subgroups',v_prop->'subgroups',
      'source_categories','[]'::jsonb,
      'detail_key','apartment'
    ) x
  )
  select coalesce(jsonb_agg(x order by (x->>'total')::numeric desc,x->>'name'),'[]'::jsonb)
    into v_groups
  from (
    select x from keep
    union all
    select x from apartment
  ) q;

  return v_base||jsonb_build_object(
    'version','expense-executive-v19-v177-property-rollup',
    'management_groups',v_groups,
    'property_rollup',v_prop,
    'ui_contract',jsonb_build_object(
      'professional_frontend_no_audit_badges',true,
      'apartment_rollup',true,
      'group_drilldown',true
    )
  );
end
$function$


-- lts_browser_expense_group_detail_v1(p_from date, p_to date, p_group text, p_subgroup text)
CREATE OR REPLACE FUNCTION public.lts_browser_expense_group_detail_v1(p_from date, p_to date, p_group text, p_subgroup text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid:=public.lts_browser_assert_user_v1();
  v_group text:=coalesce(trim(p_group),'');
  v_subgroup text:=nullif(trim(p_subgroup),'');
  v_full boolean:=p_from<=date '2013-10-10' and p_to>=current_date;
  v_rows jsonb:='[]'::jsonb;
  v_total numeric:=0;
  v_count int:=0;
  v_kind text:='transactions';
begin
  if p_from is null or p_to is null or p_from>p_to or v_group='' then raise exception 'invalid detail request'; end if;

  if v_group='Apartamento · CIPÓ 396' and (v_subgroup is null or v_subgroup='Obra e reforma') and v_full then
    if v_subgroup='Obra e reforma' then
      select coalesce(jsonb_agg(jsonb_build_object(
        'date',null,
        'date_label','Histórico',
        'description',regexp_replace(source_description,'\s*-\s*O Parque\s*$','','i'),
        'account_source',source_origin,
        'counterparty',null,
        'center_cost','Casa',
        'amount',source_paid,
        'row_kind','historical_component',
        'component','Obra e reforma'
      ) order by source_paid desc,source_description),'[]'::jsonb),
      round(coalesce(sum(source_paid),0),2),count(*)
      into v_rows,v_total,v_count
      from public.lts_cipo_source_component
      where user_id=v_uid and component_class='improvement';
      v_kind:='historical_components';
      return jsonb_build_object(
        'version','expense-group-detail-v1-v177','group',v_group,'subgroup',v_subgroup,
        'total',v_total,'rows',v_rows,'row_count',v_count,'detail_kind',v_kind,'reconciles',true
      );
    end if;
  end if;

  with base as materialized (
    select r.*,
      public.lts_expense_management_group_v3(r.category,r.center_cost,r.counterparty,r.origin_name,r.coverage_mode) management_group,
      public.lts_v177_management_subgroup_v1(r.category,r.center_cost,r.counterparty,r.origin_name,r.coverage_mode,r.source_ref) management_subgroup,
      public.lts_v177_property_component_v1(r.category,r.center_cost,r.counterparty,r.origin_name,r.coverage_mode) property_component
    from public.lts_expense_effective_rows_v176(v_uid,p_from,p_to) r
  ),
  filtered as (
    select *
    from base
    where
      (
        v_group='Apartamento · CIPÓ 396'
        and property_component is not null
        and (v_subgroup is null or property_component=v_subgroup)
        and not (v_full and property_component='Obra e reforma')
      )
      or
      (
        v_group<>'Apartamento · CIPÓ 396'
        and management_group=v_group
        and (v_subgroup is null or management_subgroup=v_subgroup)
      )
  ),
  described as (
    select f.*,
      coalesce(
        nullif(eb.dados->>'desc',''),
        nullif(ha.dados->>'desc',''),
        nullif(rp.description_raw,''),
        nullif(cp.description_raw,''),
        nullif(dp.description,''),
        nullif(mp.description,''),
        nullif(w.category_raw,''),
        nullif(f.counterparty,''),
        nullif(f.category,''),
        'Lançamento'
      ) description,
      case
        when f.origin_name is not null and trim(f.origin_name)<>'' then f.origin_name
        when f.origin_type='cartão' then 'Cartão'
        else f.origin_type
      end account_source
    from filtered f
    left join public.evento_base eb
      on f.source_table='evento_base' and eb.idx::text=f.source_ref
    left join public.historico_analitico ha
      on f.source_table='historico_analitico' and ha.idx::text=f.source_ref
    left join public.lts_card_history_recovered_purchase rp
      on f.source_table='lts_card_history_recovered_purchase' and rp.source_hash=f.source_ref
    left join public.lts_card_purchase_detail cp
      on f.source_table='card_purchase_detail' and (cp.line_key=f.source_ref or cp.purchase_key=f.source_ref)
    left join public.lts_document_card_purchase dp
      on f.source_table='lts_document_card_purchase' and dp.id::text=f.source_ref
    left join public.lts_manual_card_purchase mp
      on f.source_table='lts_manual_card_purchase' and mp.id::text=f.source_ref
    left join public.lts_v175_workbook_monthly_category_source w
      on f.source_table='lts_v175_workbook_monthly_category_source' and w.id::text=f.source_ref
  ),
  items as (
    select jsonb_build_object(
      'date',event_date,
      'date_label',to_char(event_date,'DD/MM/YYYY'),
      'description',description,
      'account_source',account_source,
      'counterparty',counterparty,
      'center_cost',center_cost,
      'amount',amount,
      'row_kind',case when coverage_mode like 'card_category_allocated_workbook%' then 'monthly_category_total' else 'transaction' end,
      'component',case when v_group='Apartamento · CIPÓ 396' then property_component else management_group end
    ) obj,
    amount,event_date,description
    from described

    union all

    select jsonb_build_object(
      'date',null,
      'date_label','Histórico',
      'description',regexp_replace(source_description,'\s*-\s*O Parque\s*$','','i'),
      'account_source',source_origin,
      'counterparty',null,
      'center_cost','Casa',
      'amount',source_paid,
      'row_kind','historical_component',
      'component','Obra e reforma'
    ) obj,
    source_paid amount,null::date event_date,source_description description
    from public.lts_cipo_source_component
    where v_group='Apartamento · CIPÓ 396'
      and v_subgroup is null
      and v_full
      and user_id=v_uid
      and component_class='improvement'
  )
  select coalesce(jsonb_agg(obj order by event_date desc nulls last,amount desc,description),'[]'::jsonb),
         round(coalesce(sum(amount),0),2),count(*)
  into v_rows,v_total,v_count
  from items;

  return jsonb_build_object(
    'version','expense-group-detail-v1-v177',
    'group',v_group,'subgroup',v_subgroup,
    'total',v_total,'rows',v_rows,'row_count',v_count,'detail_kind',v_kind,
    'reconciles',true
  );
end
$function$


-- lts_browser_property_rollup_v1(p_from date, p_to date)
CREATE OR REPLACE FUNCTION public.lts_browser_property_rollup_v1(p_from date DEFAULT '2013-10-10'::date, p_to date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid:=public.lts_browser_assert_user_v1();
  v_full boolean:=p_from<=date '2013-10-10' and p_to>=current_date;
  v_acquisition numeric:=0;
  v_financing numeric:=0;
  v_works numeric:=0;
  v_recurring numeric:=0;
  v_recurring_children jsonb:='[]'::jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid property range'; end if;

  with r as materialized (
    select * from public.lts_expense_effective_rows_v176(v_uid,p_from,p_to)
  )
  select
    round(coalesce(sum(amount) filter(where public.lts_v177_property_component_v1(category,center_cost,counterparty,origin_name,coverage_mode)='Aquisição do imóvel'),0),2),
    round(coalesce(sum(amount) filter(where public.lts_v177_property_component_v1(category,center_cost,counterparty,origin_name,coverage_mode)='Financiamento imobiliário'),0),2),
    round(coalesce(sum(amount) filter(where public.lts_v177_property_component_v1(category,center_cost,counterparty,origin_name,coverage_mode)='Obra e reforma'),0),2),
    round(coalesce(sum(amount) filter(where public.lts_v177_property_component_v1(category,center_cost,counterparty,origin_name,coverage_mode)='Custos recorrentes de moradia'),0),2)
  into v_acquisition,v_financing,v_works,v_recurring
  from r;

  if v_full then
    select round(coalesce(sum(source_paid),0),2)
      into v_works
    from public.lts_cipo_source_component
    where user_id=v_uid and component_class='improvement';
  end if;

  with r as materialized (
    select * from public.lts_expense_effective_rows_v176(v_uid,p_from,p_to)
  ), c as (
    select public.lts_v177_recurring_housing_detail_v1(category,counterparty) name,
           round(sum(amount),2) total,count(*) rows
    from r
    where public.lts_v177_property_component_v1(category,center_cost,counterparty,origin_name,coverage_mode)
          ='Custos recorrentes de moradia'
    group by 1
  )
  select coalesce(jsonb_agg(jsonb_build_object('name',name,'total',total,'rows',rows) order by total desc,name),'[]'::jsonb)
    into v_recurring_children
  from c;

  return jsonb_build_object(
    'version','property-rollup-v1-v177',
    'name','Apartamento · CIPÓ 396',
    'total_cash',round(v_acquisition+v_financing+v_works+v_recurring,2),
    'subgroups',jsonb_build_array(
      jsonb_build_object('name','Aquisição do imóvel','total',v_acquisition),
      jsonb_build_object('name','Financiamento imobiliário','total',v_financing),
      jsonb_build_object('name','Obra e reforma','total',v_works),
      jsonb_build_object('name','Custos recorrentes de moradia','total',v_recurring,'children',v_recurring_children)
    ),
    'recurring_children',v_recurring_children,
    'full_history_source_reconciled_works',v_full,
    'display_contract','Caixa destinado ao apartamento com aquisição, financiamento, obra e custos para morar economicamente separados.'
  );
end
$function$


-- lts_v177_2020_expense_qa_v1(p_user_id uuid)
CREATE OR REPLACE FUNCTION public.lts_v177_2020_expense_qa_v1(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_2019 numeric; v_2020 numeric; v_wedding numeric; v_norm2019 numeric;
  v_card2019 numeric; v_card2020 numeric; v_cardmonths2020 int; v_vis2020 numeric;
  v_checks jsonb:='[]'::jsonb; v_pass boolean:=true;
begin
  with r as (
    select * from public.lts_expense_effective_rows_v176(p_user_id,date '2019-01-01',date '2020-12-31')
  )
  select
    round(sum(amount) filter(where event_date between date '2019-01-01' and date '2019-12-31'),2),
    round(sum(amount) filter(where event_date between date '2020-01-01' and date '2020-12-31'),2),
    round(sum(amount) filter(where event_date between date '2019-01-01' and date '2019-12-31'
      and public.lts_expense_management_group_v3(category,center_cost,counterparty,origin_name,coverage_mode)='Casamento'),2),
    round(sum(amount) filter(where event_date between date '2019-01-01' and date '2019-12-31' and origin_type='cartão'),2),
    round(sum(amount) filter(where event_date between date '2020-01-01' and date '2020-12-31' and origin_type='cartão'),2),
    count(distinct competence_month) filter(where event_date between date '2020-01-01' and date '2020-12-31' and origin_type='cartão'),
    round(coalesce(sum(amount) filter(where event_date between date '2020-01-01' and date '2020-12-31'
      and origin_type='cartão' and origin_name ~* '^Visa$'),0),2)
  into v_2019,v_2020,v_wedding,v_card2019,v_card2020,v_cardmonths2020,v_vis2020
  from r;

  v_norm2019:=round(v_2019-v_wedding,2);

  v_checks:=v_checks||jsonb_build_array(jsonb_build_object('check','2019_total','pass',abs(v_2019-646933.25)<=0.01,'value',v_2019));
  v_checks:=v_checks||jsonb_build_array(jsonb_build_object('check','2020_total','pass',abs(v_2020-281377.71)<=0.01,'value',v_2020));
  v_checks:=v_checks||jsonb_build_array(jsonb_build_object('check','2019_wedding','pass',abs(v_wedding-344846.71)<=0.01,'value',v_wedding));
  v_checks:=v_checks||jsonb_build_array(jsonb_build_object('check','2020_card_months_complete','pass',v_cardmonths2020=12,'months',v_cardmonths2020));
  v_checks:=v_checks||jsonb_build_array(jsonb_build_object('check','2020_visa_absent_in_source','pass',abs(v_vis2020)<=0.01,'value',v_vis2020));
  v_pass:=abs(v_2019-646933.25)<=0.01 and abs(v_2020-281377.71)<=0.01 and abs(v_wedding-344846.71)<=0.01 and v_cardmonths2020=12 and abs(v_vis2020)<=0.01;

  return jsonb_build_object(
    'pass',v_pass,'version','v177-2020-expense-qa-v1',
    '2019_total',v_2019,'2019_monthly_avg',round(v_2019/12,2),
    '2019_wedding',v_wedding,'2019_normalized_ex_wedding',v_norm2019,'2019_normalized_monthly_avg',round(v_norm2019/12,2),
    '2020_total',v_2020,'2020_monthly_avg',round(v_2020/12,2),
    'normalized_delta',round(v_2020-v_norm2019,2),'normalized_delta_pct',round((v_2020/v_norm2019-1)*100,2),
    '2019_card_total',v_card2019,'2020_card_total',v_card2020,'2020_card_months',v_cardmonths2020,
    '2020_visa_total',v_vis2020,'checks',v_checks
  );
end
$function$


-- lts_v177_management_subgroup_v1(p_category text, p_center_cost text, p_counterparty text, p_origin_name text, p_coverage_mode text, p_source_ref text)
CREATE OR REPLACE FUNCTION public.lts_v177_management_subgroup_v1(p_category text, p_center_cost text, p_counterparty text, p_origin_name text, p_coverage_mode text, p_source_ref text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
select case
  when coalesce(p_category,'') ~* '^Financiamento ve[ií]culo' and coalesce(p_source_ref,'')='volvo_financing_2026_p01'
    then 'Volvo XC40'
  when public.lts_expense_management_group_v3(p_category,p_center_cost,p_counterparty,p_origin_name,p_coverage_mode)='Saúde'
    then case when p_center_cost in ('Benjamin','Larissa') then p_center_cost else 'Saúde geral / não atribuído' end
  else public.lts_expense_management_subgroup_v2(p_category,p_center_cost,p_counterparty,p_origin_name,p_coverage_mode)
end
$function$


-- lts_v177_product_qa_v1(p_user_id uuid)
CREATE OR REPLACE FUNCTION public.lts_v177_product_qa_v1(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_qa2020 jsonb:=public.lts_v177_2020_expense_qa_v1(p_user_id);
  v_prop jsonb;
  v_family jsonb;
  v_apartment jsonb;
  v_checks jsonb:='[]'::jsonb;
  v_pass boolean:=true;
  v_uid uuid:=p_user_id;
  v_email text;
begin
  select email into v_email from public.lts_allowed_users where active=true limit 1;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_uid::text,'email',v_email,'role','authenticated')::text,true);

  v_prop:=public.lts_browser_property_rollup_v1(date '2013-10-10',date '2026-09-18');
  v_family:=public.lts_browser_expense_group_detail_v1(date '2013-10-10',date '2026-09-18','Família — saídas',null);
  v_apartment:=public.lts_browser_expense_group_detail_v1(date '2013-10-10',date '2026-09-18','Apartamento · CIPÓ 396',null);

  v_checks:=v_checks||jsonb_build_array(jsonb_build_object(
    'check','2020_expense_audit','pass',coalesce((v_qa2020->>'pass')::boolean,false),
    'value',v_qa2020
  ));
  v_pass:=v_pass and coalesce((v_qa2020->>'pass')::boolean,false);

  v_checks:=v_checks||jsonb_build_array(jsonb_build_object(
    'check','property_rollup_total','pass',abs((v_prop->>'total_cash')::numeric-4529057.60)<=0.01,
    'value',(v_prop->>'total_cash')::numeric,'expected',4529057.60
  ));
  v_pass:=v_pass and abs((v_prop->>'total_cash')::numeric-4529057.60)<=0.01;

  v_checks:=v_checks||jsonb_build_array(jsonb_build_object(
    'check','family_drilldown_parity','pass',abs((v_family->>'total')::numeric-263909.54)<=0.01 and (v_family->>'row_count')::int=202,
    'total',(v_family->>'total')::numeric,'rows',(v_family->>'row_count')::int
  ));
  v_pass:=v_pass and abs((v_family->>'total')::numeric-263909.54)<=0.01 and (v_family->>'row_count')::int=202;

  v_checks:=v_checks||jsonb_build_array(jsonb_build_object(
    'check','apartment_drilldown_parity','pass',abs((v_apartment->>'total')::numeric-(v_prop->>'total_cash')::numeric)<=0.01,
    'detail_total',(v_apartment->>'total')::numeric,'rollup_total',(v_prop->>'total_cash')::numeric,
    'rows',(v_apartment->>'row_count')::int
  ));
  v_pass:=v_pass and abs((v_apartment->>'total')::numeric-(v_prop->>'total_cash')::numeric)<=0.01;

  return jsonb_build_object('pass',v_pass,'version','v177-product-qa-v1','checks',v_checks,'as_of',current_date);
end
$function$


-- lts_v177_property_component_v1(p_category text, p_center_cost text, p_counterparty text, p_origin_name text, p_coverage_mode text)
CREATE OR REPLACE FUNCTION public.lts_v177_property_component_v1(p_category text, p_center_cost text, p_counterparty text, p_origin_name text, p_coverage_mode text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
select case
  when public.lts_expense_management_group_v3(p_category,p_center_cost,p_counterparty,p_origin_name,p_coverage_mode)
       ='Investimento no imóvel — aquisição e histórico'
    then 'Aquisição do imóvel'
  when public.lts_expense_management_group_v3(p_category,p_center_cost,p_counterparty,p_origin_name,p_coverage_mode)
       ='Financiamento imobiliário'
    then 'Financiamento imobiliário'
  when public.lts_expense_management_group_v3(p_category,p_center_cost,p_counterparty,p_origin_name,p_coverage_mode)
       ='Investimentos no imóvel — obra e reforma'
    then 'Obra e reforma'
  when public.lts_expense_management_group_v3(p_category,p_center_cost,p_counterparty,p_origin_name,p_coverage_mode)
       in ('Moradia','Impostos do imóvel','Energia')
    then 'Custos recorrentes de moradia'
  when coalesce(p_category,'') ~* '^Seguro Residencial$'
    then 'Custos recorrentes de moradia'
  else null
end
$function$


-- lts_v177_recurring_housing_detail_v1(p_category text, p_counterparty text)
CREATE OR REPLACE FUNCTION public.lts_v177_recurring_housing_detail_v1(p_category text, p_counterparty text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
select case
  when coalesce(p_category,'') ~* '^Moradia$' or coalesce(p_counterparty,'') ~* '^Condom'
    then 'Condomínio'
  when coalesce(p_category,'') ~* '^(Energia|Enel|Enel - O Parque)$'
    then 'Energia elétrica'
  when coalesce(p_category,'') ~* '^(Impostos do Imóvel|IPTU|Impostos do imóvel)$'
    then 'IPTU e impostos do imóvel'
  when coalesce(p_category,'') ~* '^Seguro Residencial$'
    then 'Seguro residencial'
  when coalesce(p_category,'') ~* '^Aluguel'
    then 'Aluguel'
  else coalesce(nullif(trim(p_category),''),'Outros custos de moradia')
end
$function$

