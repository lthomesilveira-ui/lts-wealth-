-- Planning targets only. Canonical expense/income readers own all actuals.
DO $guard$ BEGIN
 IF to_regnamespace('lts_budget_private_v441') IS NOT NULL
  OR to_regprocedure('public.lts_browser_budget_read_v441(integer)') IS NOT NULL
  OR to_regprocedure('public.lts_browser_budget_save_v441(integer,integer,jsonb,numeric,bigint)') IS NOT NULL
 THEN RAISE EXCEPTION 'Budget implementation already exists; inspect before applying';END IF;
END $guard$;
CREATE SCHEMA IF NOT EXISTS lts_budget_private_v441;
REVOKE ALL ON SCHEMA lts_budget_private_v441 FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS lts_budget_private_v441.plans(
 user_id uuid NOT NULL REFERENCES auth.users(id), year integer NOT NULL CHECK(year BETWEEN 2013 AND 2200),
 plan jsonb NOT NULL DEFAULT '{"targets":{},"months":{},"income_months":{}}'::jsonb,
 revision bigint NOT NULL DEFAULT 0 CHECK(revision>=0),updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,year),CHECK(jsonb_typeof(plan)='object')
);
ALTER TABLE lts_budget_private_v441.plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY owner_planning_targets ON lts_budget_private_v441.plans USING(user_id=auth.uid()) WITH CHECK(user_id=auth.uid());
REVOKE ALL ON lts_budget_private_v441.plans FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA lts_budget_private_v441 TO service_role;
GRANT ALL ON lts_budget_private_v441.plans TO service_role;

CREATE OR REPLACE FUNCTION lts_budget_private_v441.build(p_user uuid,p_year integer,p_today date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' SET TimeZone='America/Sao_Paulo' AS $f$
DECLARE cfg jsonb; rev bigint; first_day date; last_day date; ref_from date;ref_to date;read_from date;read_to date;
 result jsonb;source_epoch bigint;
BEGIN
 IF p_user IS NULL OR p_today IS NULL OR p_year<greatest(2013,extract(year FROM p_today)::int-1) OR p_year>extract(year FROM p_today)::int+5 THEN
  RAISE EXCEPTION 'Escolha um ano válido para o orçamento.';END IF;
 first_day:=make_date(p_year,1,1);last_day:=make_date(p_year,12,31);
 ref_to:=date_trunc('month',p_today)::date-1;ref_from:=(date_trunc('month',p_today)-interval '6 months')::date;
 read_from:=greatest(date '2013-10-10',least(first_day,ref_from));read_to:=least(p_today,greatest(last_day,ref_to));
 SELECT plan,revision INTO cfg,rev FROM lts_budget_private_v441.plans WHERE user_id=p_user AND year=p_year;
 cfg:=coalesce(cfg,'{"targets":{},"months":{},"income_months":{}}');rev:=coalesce(rev,0);
 SELECT epoch INTO source_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton;
 WITH expense AS MATERIALIZED(
  SELECT r.*,CASE WHEN coverage_mode='card_invoice_aggregate_fallback' THEN 'Cartão — categoria não recuperada'
   WHEN nullif(btrim(category),'') IS NULL OR public.lts_v178_norm(category) IN('a classificar','sem categoria','nao identificado','—') THEN 'Sem classificação'
   ELSE category END label
  FROM public.lts_v229_expense_rows(p_user,read_from,read_to)r
 ), income AS MATERIALIZED(
  SELECT x,(x->>'event_date')::date dt,(x->>'signed_amount')::numeric amount,
   (public.lts_v178_norm(coalesce(x->>'category','')) IN('salario','salario liquido','adiantamento','adiantamento quinzenal','adiantamento salarial')
    AND public.lts_v178_norm(concat_ws(' ',x->>'category',x->>'description')) !~ '(bonus|premio|ferias|13o|13º|13°|decimo terceiro)') regular,
   public.lts_v178_norm(concat_ws(' ',x->>'category',x->>'description')) ~ '(bonus|premio)' bonus
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
   round(coalesce(sum(amount)FILTER(WHERE coverage_mode='card_observed_pending'),0),2) pending
  FROM expense WHERE competence_month BETWEEN first_day AND last_day GROUP BY 1,2
 ), income_month AS(
  SELECT date_trunc('month',dt)::date AS month,round(coalesce(sum(amount)FILTER(WHERE regular),0),2) regular,
   round(coalesce(sum(amount)FILTER(WHERE NOT regular),0),2) extraordinary,
   round(coalesce(sum(amount)FILTER(WHERE NOT regular AND bonus),0),2) bonus
  FROM income WHERE dt BETWEEN first_day AND last_day GROUP BY 1
 ), grid AS MATERIALIZED(
  SELECT r.label,m.month,m.key,r.amount reference_monthly,
   coalesce(nullif(cfg#>>ARRAY['months',m.key,r.label],'')::numeric,nullif(cfg#>>ARRAY['targets',r.label],'')::numeric,r.amount) target,
   CASE WHEN cfg#>ARRAY['months',m.key,r.label] IS NOT NULL OR cfg#>ARRAY['targets',r.label] IS NOT NULL THEN 'owner' ELSE 'history' END target_basis,
   coalesce(e.amount,0) actual,coalesce(e.pending,0) pending
  FROM reference r CROSS JOIN month_keys m LEFT JOIN expense_month e ON e.label=r.label AND e.month=m.month
 ), categories AS(
  SELECT label category,max(reference_monthly) reference_monthly,
   jsonb_agg(jsonb_build_object('month',key,'target',target,'actual',actual,'pending',pending,'target_basis',target_basis) ORDER BY month) months
  FROM grid GROUP BY label
 ), months AS(
  SELECT m.month,m.key,
   CASE WHEN count(g.label)=0 OR count(g.label)FILTER(WHERE g.target IS NULL)>0 THEN NULL ELSE round(sum(g.target),2) END target,
   round(coalesce(sum(g.actual),0),2) actual,round(coalesce(sum(g.pending),0),2) pending,
   coalesce(nullif(cfg#>>ARRAY['income_months',m.key],'')::numeric,nullif(cfg->>'income_year','')::numeric,s.amount) income_target,
   coalesce(i.regular,0) income_regular,coalesce(i.extraordinary,0) income_extraordinary,coalesce(i.bonus,0) income_bonus
  FROM month_keys m CROSS JOIN salary s LEFT JOIN grid g ON g.month=m.month LEFT JOIN income_month i ON i.month=m.month
  GROUP BY m.month,m.key,s.amount,i.regular,i.extraordinary,i.bonus
 ) SELECT jsonb_build_object('ok',true,'version','budget-v441','year',p_year,'as_of',p_today,'plan_revision',rev,
  'proposed',rev=0,'reference',jsonb_build_object('from',ref_from,'to',ref_to,'expected_months',6,
   'months',(SELECT months FROM history_coverage),'salary_months',(SELECT months FROM salary),'salary_monthly',(SELECT amount FROM salary)),
  'rows',coalesce((SELECT jsonb_agg(to_jsonb(c) ORDER BY category) FROM categories c),'[]'),
  'months',(SELECT jsonb_agg(jsonb_build_object('month',key,'target',target,'actual',actual,'pending',pending,
   'income_target',income_target,'income_regular',income_regular,'income_extraordinary',income_extraordinary,'income_bonus',income_bonus,
   'started',month<=date_trunc('month',p_today)::date,'complete',month<date_trunc('month',p_today)::date) ORDER BY month) FROM months),
  'actual_income_groups',coalesce((SELECT jsonb_agg(jsonb_build_object('category',category,'amount',amount,'regular',regular) ORDER BY amount DESC,category)
   FROM(SELECT coalesce(x->>'category','Sem classificação') category,regular,round(sum(amount),2) amount FROM income
    WHERE dt BETWEEN first_day AND last_day GROUP BY 1,2)z),'[]'),
  'unclassified_actual',coalesce((SELECT round(sum(amount),2) FROM expense WHERE competence_month BETWEEN first_day AND last_day
   AND label IN('Cartão — categoria não recuperada','Sem classificação')),0),
  'basis','canonical_consumption_not_card_payment','flow_provision_included',false,
  'source_epoch',source_epoch) INTO result;
 IF source_epoch IS DISTINCT FROM(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Os dados foram atualizados. Confira novamente o orçamento.';END IF;
 RETURN result;
END $f$;
REVOKE ALL ON FUNCTION lts_budget_private_v441.build(uuid,integer,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_budget_private_v441.build(uuid,integer,date) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_browser_budget_read_v441(p_year integer)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' SET TimeZone='America/Sao_Paulo' SET statement_timeout='18s' AS $f$
 SELECT lts_budget_private_v441.build(public.lts_browser_assert_user_v1(),p_year,current_date);
$f$;
REVOKE ALL ON FUNCTION public.lts_browser_budget_read_v441(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_budget_read_v441(integer) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.lts_browser_budget_save_v441(p_year integer,p_month integer DEFAULT NULL,
 p_targets jsonb DEFAULT '{}'::jsonb,p_income numeric DEFAULT NULL,p_expected bigint DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET TimeZone='America/Sao_Paulo' SET statement_timeout='8s' AS $f$
DECLARE u uuid:=public.lts_browser_assert_user_v1();old jsonb;next jsonb;v bigint;month_key text;k text;val jsonb;path text[];
BEGIN
 IF p_year<greatest(2013,extract(year FROM current_date)::int-1) OR p_year>extract(year FROM current_date)::int+5 OR p_year IS NULL
  OR p_month IS NOT NULL AND p_month NOT BETWEEN 1 AND 12 OR p_expected IS NULL OR p_expected<0
  OR jsonb_typeof(p_targets) IS DISTINCT FROM 'object' OR (SELECT count(*) FROM jsonb_object_keys(p_targets))>200
  OR p_income IS NOT NULL AND p_income NOT BETWEEN 0 AND 100000000
  OR p_income IS NOT NULL AND p_income<>round(p_income,2) THEN RAISE EXCEPTION 'Confira o período e os valores das metas.';END IF;
 FOR k,val IN SELECT * FROM jsonb_each(p_targets) LOOP
  IF length(btrim(k))<1 OR length(k)>120 OR k~'[[:cntrl:]]' OR jsonb_typeof(val)<>'number'
   OR (val#>>'{}')!~'^[0-9]+([.][0-9]{1,2})?$' OR(val#>>'{}')::numeric>100000000
   THEN RAISE EXCEPTION 'Informe uma meta válida para cada categoria.';END IF;
 END LOOP;
 INSERT INTO lts_budget_private_v441.plans(user_id,year)VALUES(u,p_year) ON CONFLICT DO NOTHING;
 SELECT plan,revision INTO old,v FROM lts_budget_private_v441.plans WHERE user_id=u AND year=p_year FOR UPDATE;
 IF v IS DISTINCT FROM p_expected THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='As metas mudaram. Atualize o orçamento antes de salvar.';END IF;
 next:=old;month_key:=CASE WHEN p_month IS NOT NULL THEN to_char(make_date(p_year,p_month,1),'YYYY-MM') END;
 IF p_month IS NULL THEN
  next:=jsonb_set(next,'{targets}',coalesce(next->'targets','{}')||p_targets,true);
  FOR month_key IN SELECT jsonb_object_keys(coalesce(next->'months','{}')) LOOP
   next:=jsonb_set(next,ARRAY['months',month_key],(next#>ARRAY['months',month_key])-ARRAY(SELECT jsonb_object_keys(p_targets)),true);
  END LOOP;
  IF p_income IS NOT NULL THEN next:=jsonb_set(next,'{income_year}',to_jsonb(p_income),true);next:=jsonb_set(next,'{income_months}','{}',true);END IF;
 ELSE
  next:=jsonb_set(next,'{months}',coalesce(next->'months','{}')||jsonb_build_object(month_key,
    coalesce(next#>ARRAY['months',month_key],'{}')||p_targets),true);
  IF p_income IS NOT NULL THEN next:=jsonb_set(next,'{income_months}',coalesce(next->'income_months','{}')||jsonb_build_object(month_key,p_income),true);END IF;
 END IF;
 IF next=old THEN RETURN jsonb_build_object('ok',true,'saved',true,'revision',v,'unchanged',true,'financial_effect','none');END IF;
 UPDATE lts_budget_private_v441.plans SET plan=next,revision=revision+1,updated_at=now() WHERE user_id=u AND year=p_year RETURNING revision INTO v;
 INSERT INTO public.lts_access_audit(user_id,email,action,meta) VALUES(u,lower(coalesce(auth.jwt()->>'email','')),
  'budget_targets_v441',jsonb_build_object('year',p_year,'month',p_month,'before',old,'after',next,'revision',v,'financial_effect','none'));
 RETURN jsonb_build_object('ok',true,'saved',true,'revision',v,'financial_effect','none');
END $f$;
REVOKE ALL ON FUNCTION public.lts_browser_budget_save_v441(integer,integer,jsonb,numeric,bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_budget_save_v441(integer,integer,jsonb,numeric,bigint) TO authenticated,service_role;
