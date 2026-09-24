-- Recover explicit source categories only when the expense projection is unclassified.
-- No transaction, amount, date, balance, ownership or access-policy writes.
DO $repair$
DECLARE
  definition text;
  expected_fragment text := $old$ select x.* from public.lts_expense_effective_rows_v176(p_user_id,p_from,p_to) x$old$;
  replacement_fragment text := $new$ select x.event_date,x.transaction_date,x.competence_month,x.amount,
 case when public.lts_v178_norm(x.category)='a classificar' and source.category is not null
 then case when public.lts_v178_norm(source.category)='financiamento imovel' then 'Financiamento imobiliário' else source.category end
 else x.category end category,
 x.center_cost,x.counterparty,x.origin_type,x.origin_name,x.source_table,x.source_ref,x.coverage_mode,x.is_property,x.is_financing
 from public.lts_expense_effective_rows_v176(p_user_id,p_from,p_to) x
 left join lateral (
   select case when count(distinct nullif(trim(e.category),''))=1 then min(nullif(trim(e.category),'')) end category
   from public.financial_events e
   where x.source_table='daily_flow_documentary_bridge' and e.user_id=p_user_id
     and (e.id::text=x.source_ref or e.legacy_id=x.source_ref)
     and public.lts_v178_norm(e.category) not in ('a classificar','não identificado','nao identificado')
 ) source on true$new$;
  before_facts text;
  after_facts text;
BEGIN
  SELECT md5(coalesce(string_agg(concat_ws('|',u.user_id,r.source_table,r.source_ref,r.event_date,r.transaction_date,r.competence_month,r.amount,r.coverage_mode),E'\n' ORDER BY u.user_id,r.source_table,r.source_ref,r.event_date,r.competence_month,r.amount),'')) INTO before_facts
  FROM (SELECT DISTINCT user_id FROM public.lts_product_read_cache) u
  CROSS JOIN LATERAL public.lts_v178_expense_rows(u.user_id,date_trunc('year',current_date)::date,current_date) r;
  SELECT pg_get_functiondef('public.lts_v178_expense_rows(uuid,date,date)'::regprocedure) INTO definition;
  IF strpos(definition,expected_fragment)=0 OR strpos(definition,$needle$case when group_without_property like '%a revisar'$needle$)=0 THEN
    RAISE EXCEPTION 'Classification reader changed; review migration before applying';
  END IF;
  definition := replace(definition,expected_fragment,replacement_fragment);
  definition := replace(definition,$needle$case when group_without_property like '%a revisar'$needle$,
    $replacement$case when public.lts_v178_norm(coalesce(category_decision,category)) in ('a classificar','nao identificado','sem categoria') or group_without_property like '%a revisar'$replacement$);
  definition := replace(definition,
    'public.lts_expense_management_group_v3(category,center_cost,counterparty,origin_name,coverage_mode)',
    'public.lts_expense_management_group_v3(coalesce(category_decision,category),center_cost,counterparty,origin_name,coverage_mode)');
  EXECUTE definition;
  SELECT md5(coalesce(string_agg(concat_ws('|',u.user_id,r.source_table,r.source_ref,r.event_date,r.transaction_date,r.competence_month,r.amount,r.coverage_mode),E'\n' ORDER BY u.user_id,r.source_table,r.source_ref,r.event_date,r.competence_month,r.amount),'')) INTO after_facts
  FROM (SELECT DISTINCT user_id FROM public.lts_product_read_cache) u
  CROSS JOIN LATERAL public.lts_v178_expense_rows(u.user_id,date_trunc('year',current_date)::date,current_date) r;
  IF before_facts IS DISTINCT FROM after_facts THEN RAISE EXCEPTION 'Financial facts changed; reverting reader'; END IF;
  IF EXISTS (
    SELECT 1 FROM (SELECT DISTINCT user_id FROM public.lts_product_read_cache) u
    CROSS JOIN LATERAL public.lts_v178_expense_rows(u.user_id,date_trunc('year',current_date)::date,current_date) r
    WHERE public.lts_v178_norm(r.category) IN ('a classificar','nao identificado','sem categoria')
      AND r.identity_status<>'pending'
  ) THEN RAISE EXCEPTION 'Unclassified expenses remain hidden'; END IF;
END
$repair$;
