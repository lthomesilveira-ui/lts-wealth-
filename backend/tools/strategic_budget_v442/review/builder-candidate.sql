CREATE OR REPLACE FUNCTION lts_budget_private_v441.build(p_user uuid, p_year integer, p_today date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE cfg jsonb; rev bigint; first_day date; last_day date; ref_from date;ref_to date;read_from date;read_to date;
 result jsonb;source_epoch bigint;reviewed jsonb;
BEGIN
 IF p_user IS NULL OR p_today IS NULL OR p_year<greatest(2013,extract(year FROM p_today)::int-1) OR p_year>extract(year FROM p_today)::int+5 THEN
  RAISE EXCEPTION 'Escolha um ano válido para o orçamento.';END IF;
 first_day:=make_date(p_year,1,1);last_day:=make_date(p_year,12,31);
 ref_to:=date_trunc('month',p_today)::date-1;ref_from:=(date_trunc('month',p_today)-interval '6 months')::date;
 read_from:=greatest(date '2013-10-10',least(first_day,ref_from));read_to:=least(p_today,greatest(last_day,ref_to));
 SELECT plan,revision INTO cfg,rev FROM lts_budget_private_v441.plans WHERE user_id=p_user AND year=p_year;
 cfg:=coalesce(cfg,'{"targets":{},"months":{},"income_months":{}}');rev:=coalesce(rev,0);
 SELECT epoch INTO source_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton;
 reviewed:=lts_budget_private_v441.reviewed_planning_v442(cfg->'reviewed_planning',source_epoch,p_year);
 WITH expense AS MATERIALIZED(
  SELECT r.*,CASE WHEN coverage_mode='card_invoice_aggregate_fallback' THEN 'Cartão — categoria não recuperada'
   WHEN nullif(btrim(category),'') IS NULL OR public.lts_v178_norm(category) IN('a classificar','sem categoria','nao identificado','—') THEN 'Sem classificação'
   ELSE lts_budget_private_v441.reviewed_category_v442(to_jsonb(r),reviewed->'source_links') END label
  FROM public.lts_v229_expense_rows(p_user,read_from,read_to)r
 ), income AS MATERIALIZED(
  SELECT x,(x->>'event_date')::date dt,(x->>'signed_amount')::numeric amount,
   (public.lts_v178_norm(coalesce(x->>'category','')) IN('salario','salario liquido','adiantamento','adiantamento quinzenal','adiantamento salarial')
    AND public.lts_v178_norm(concat_ws(' ',x->>'category',x->>'description')) !~ '(bonus|premio|ferias|(^|[^0-9])13([º°o]|[[:space:]])|decimo terceiro)') regular,
   public.lts_v178_norm(concat_ws(' ',x->>'category',x->>'description')) ~ '(bonus|premio)' bonus,
   public.lts_v178_norm(concat_ws(' ',x->>'category',x->>'description'))~'(^|[^0-9])13([º°o]|[[:space:]])|decimo terceiro' thirteenth
  FROM lts_income_private.rows_v296(p_user,read_from,read_to)x
 ), history_coverage AS(
  SELECT count(DISTINCT competence_month)::int months FROM expense WHERE competence_month BETWEEN ref_from AND ref_to
 ), salaries AS(
  SELECT date_trunc('month',dt)::date AS month,sum(amount) amount FROM income
  WHERE regular AND dt BETWEEN ref_from AND ref_to GROUP BY 1 ORDER BY 1 DESC LIMIT 3
 ), salary AS(
  SELECT round((percentile_cont(.5) WITHIN GROUP(ORDER BY amount))::numeric,2) amount,count(*)::int months FROM salaries
 ), labels AS(
  SELECT DISTINCT label FROM expense WHERE competence_month BETWEEN first_day AND last_day OR competence_month BETWEEN ref_from AND ref_to
  UNION SELECT jsonb_object_keys(coalesce(cfg->'targets','{}'))
  UNION SELECT k FROM jsonb_each(coalesce(cfg->'months','{}'))m CROSS JOIN LATERAL jsonb_object_keys(m.value)k
 ), month_keys AS(
  SELECT d::date AS month,to_char(d,'YYYY-MM') key FROM generate_series(first_day,last_day,interval '1 month')d
 ), reference AS(
  SELECT l.label,CASE WHEN c.months=6 THEN round(greatest(coalesce(sum(e.amount),0),0)/6,2) END amount
  FROM labels l CROSS JOIN history_coverage c LEFT JOIN expense e ON e.label=l.label AND e.competence_month BETWEEN ref_from AND ref_to
  GROUP BY l.label,c.months
 ), expense_month AS(
  SELECT label,competence_month AS month,round(sum(amount),2) amount,
   round(coalesce(sum(amount)FILTER(WHERE coverage_mode='card_observed_pending'),0),2) pending,
   round(coalesce(sum(amount)FILTER(WHERE coverage_mode LIKE 'card_%'),0),2) card_actual
  FROM expense WHERE competence_month BETWEEN first_day AND last_day GROUP BY 1,2
 ), income_month AS(
  SELECT date_trunc('month',dt)::date AS month,round(coalesce(sum(amount)FILTER(WHERE regular),0),2) regular,
   round(coalesce(sum(amount)FILTER(WHERE NOT regular),0),2) extraordinary,
   round(coalesce(sum(amount)FILTER(WHERE NOT regular AND bonus),0),2) bonus,
   round(coalesce(sum(amount)FILTER(WHERE thirteenth),0),2) thirteenth
  FROM income WHERE dt BETWEEN first_day AND last_day GROUP BY 1
 ), grid AS MATERIALIZED(
  SELECT r.label,m.month,m.key,r.amount reference_monthly,
   coalesce(nullif(cfg#>>ARRAY['months',m.key,r.label],'')::numeric,nullif(cfg#>>ARRAY['targets',r.label],'')::numeric,r.amount) target,
   CASE WHEN cfg#>ARRAY['months',m.key,r.label] IS NOT NULL OR cfg#>ARRAY['targets',r.label] IS NOT NULL THEN 'owner' ELSE 'history' END target_basis,
   coalesce(e.amount,0) actual,coalesce(e.pending,0) pending,coalesce(e.card_actual,0) card_actual
  FROM reference r CROSS JOIN month_keys m LEFT JOIN expense_month e ON e.label=r.label AND e.month=m.month
 ), categories AS(
  SELECT label category,max(reference_monthly) reference_monthly,
   jsonb_agg(jsonb_build_object('month',key,'target',target,'actual',actual,'pending',pending,'card_actual',card_actual,'target_basis',target_basis) ORDER BY month) months
  FROM grid GROUP BY label
 ), months AS(
  SELECT m.month,m.key,
   CASE WHEN count(g.label)=0 OR count(g.label)FILTER(WHERE g.target IS NULL)>0 THEN NULL ELSE round(sum(g.target),2) END target,
   round(coalesce(sum(g.actual),0),2) actual,round(coalesce(sum(g.pending),0),2) pending,
   coalesce(nullif(cfg#>>ARRAY['income_months',m.key],'')::numeric,nullif(cfg->>'income_year','')::numeric,s.amount) income_target,
   coalesce(i.regular,0) income_regular,coalesce(i.extraordinary,0) income_extraordinary,coalesce(i.bonus,0) income_bonus,coalesce(i.thirteenth,0) income_thirteenth
  FROM month_keys m CROSS JOIN salary s LEFT JOIN grid g ON g.month=m.month LEFT JOIN income_month i ON i.month=m.month
  GROUP BY m.month,m.key,s.amount,i.regular,i.extraordinary,i.bonus,i.thirteenth
 ) SELECT jsonb_build_object('ok',true,'version','budget-v441','year',p_year,'as_of',p_today,'plan_revision',rev,
  'proposed',rev=0,'income_approvals',jsonb_build_object('year',cfg?'income_year','months',(SELECT coalesce(jsonb_object_agg(key,true),'{}'::jsonb) FROM jsonb_object_keys(coalesce(cfg->'income_months','{}'::jsonb))key)),'reference',jsonb_build_object('from',ref_from,'to',ref_to,'expected_months',6,
   'months',(SELECT months FROM history_coverage),'salary_months',(SELECT months FROM salary),'salary_monthly',(SELECT amount FROM salary)),
  'rows',coalesce((SELECT jsonb_agg(to_jsonb(c) ORDER BY category) FROM categories c),'[]'),
  'months',(SELECT jsonb_agg(jsonb_build_object('month',key,'target',target,'actual',actual,'pending',pending,
   'income_target',income_target,'income_regular',income_regular,'income_extraordinary',income_extraordinary,'income_bonus',income_bonus,'income_thirteenth',income_thirteenth,
   'started',month<=date_trunc('month',p_today)::date,'complete',month<date_trunc('month',p_today)::date) ORDER BY month) FROM months),
  'actual_income_groups',coalesce((SELECT jsonb_agg(jsonb_build_object('category',category,'amount',amount,'regular',regular) ORDER BY amount DESC,category)
   FROM(SELECT coalesce(x->>'category','Sem classificação') category,regular,round(sum(amount),2) amount FROM income
    WHERE dt BETWEEN first_day AND last_day GROUP BY 1,2)z),'[]'),
  'unclassified_actual',coalesce((SELECT round(sum(amount),2) FROM expense WHERE competence_month BETWEEN first_day AND last_day
   AND label IN('Cartão — categoria não recuperada','Sem classificação')),0),
  'category_aliases',coalesce((SELECT jsonb_object_agg(raw_category,category) FROM(SELECT b.raw_category,min(c.category)category FROM public.lts_category_binding_v290 b JOIN public.lts_category_catalog c USING(user_id,category_key) WHERE b.user_id=p_user GROUP BY b.raw_category HAVING count(DISTINCT b.category_key)=1)d),'{}'::jsonb),'basis','canonical_consumption_not_card_payment','flow_provision_included',false,
  'source_epoch',source_epoch) INTO result;
 IF source_epoch IS DISTINCT FROM(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Os dados foram atualizados. Confira novamente o orçamento.';END IF;
 RETURN result||jsonb_build_object('planning',reviewed);
END $function$
