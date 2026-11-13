DO $guard$ DECLARE s text;a jsonb;BEGIN SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO STRICT s,a FROM pg_proc p WHERE p.oid='public.lts_expense_taxonomy_v353(text,text,text)'::regprocedure;IF md5(s)='fdb06094d1a5057c56cfd1d331f2d726' THEN RETURN;END IF;IF md5(s)<>'b51d96fe858c67d70c3f1b035b8c0af0' THEN RAISE EXCEPTION 'Loan grouping predecessor changed; review before applying';END IF;EXECUTE $candidate$CREATE OR REPLACE FUNCTION public.lts_expense_taxonomy_v353(p_category text, p_component text, p_management text)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE c text:=lower(translate(coalesce(p_category,''),'áàâãéêíóôõúç','aaaaeeiooouc'));
 k text:=lower(translate(coalesce(p_component,''),'áàâãéêíóôõúç','aaaaeeiooouc'));
 m text:=lower(translate(coalesce(p_management,''),'áàâãéêíóôõúç','aaaaeeiooouc'));
 macro text;g text;cat text:=nullif(trim(regexp_replace(coalesce(p_category,''),'[[:space:]]*[-—–][[:space:]]*O Parque$','','i')),'');
 tax boolean:=c~'tribut|imposto|iptu|ipva|itbi|licenci'OR k~'imposto';
BEGIN
 CASE
 WHEN c='cartao — detalhe historico nao recuperado'THEN macro:='Sem composição individual';g:='Cartões históricos';
 WHEN c~'^(credito|ajustes de fatura)'THEN macro:='Compensações';g:='Créditos e ajustes da origem';
 WHEN k~'aquisicao'OR c~'financiamento imobiliario|consorcio'THEN macro:='Patrimônio e financiamentos';g:='Aquisição imobiliária';
 WHEN c~'financiamento veiculo'OR m~'financiamento.*veiculo'THEN macro:='Patrimônio e financiamentos';g:='Aquisição e financiamento de veículo';
 WHEN c~'^emprestimos?$'OR m='emprestimos'THEN macro:='Patrimônio e financiamentos';g:='Empréstimos';
 WHEN c~'^emprestimos$|compromissos financeiros'THEN macro:='Compromissos financeiros';g:='Empréstimos e compromissos';
 WHEN c~'ipva|licenci|veiculos - tributos'THEN macro:='Mobilidade';g:='Tributos';
 WHEN tax AND(k~'imposto'OR c~'imovel|iptu|itbi')THEN macro:='Moradia';g:='Tributos';
 WHEN tax THEN macro:='Tributos e encargos';g:='Tributos sem bem detalhado';
 WHEN k~'obra|reforma'OR c~'obra|reforma|ar-condicionado|camas e estofados|cortinas|deck|envidracamento|espelhos e box|jardim|loucas e metais|marcenaria|mesa e banho|moveis|porta quarto|projeto|revestimento|serralheria|eletrodomesticos'THEN macro:='Moradia';g:='Obra, reforma e equipamentos';
 WHEN k~'moradia'OR c~'condominio|energia|enel|seguro residencial|^moradia$|casa - utensilios'THEN macro:='Moradia';g:='Uso e manutenção';
 WHEN c~'restaurante|ifood|rappi|^alimentacao|^bebidas$|mercado|supermercado'AND c NOT IN('mercado livre')THEN macro:='Alimentação';g:=CASE WHEN c~'restaurante|ifood|rappi'THEN'Refeições'ELSE'Compras e bebidas'END;
 WHEN c~'saude|farmacia|congelamento de ovulos'THEN macro:='Saúde';g:='Atendimento e medicamentos';
 WHEN c~'educacao|aulas|english class|desenvolvimento|lide futuro'THEN macro:='Educação';g:='Ensino e desenvolvimento';
 WHEN c~'combustivel|estacionamento|pedagio|taxi|uber|veiculos -|seguro carro|seguro jeep|aluguel carro|^carro$'THEN macro:='Mobilidade';g:='Uso de veículos';
 WHEN c~'company car|despesas organon'THEN macro:='Trabalho';g:='Despesas profissionais';
 WHEN c~'^vestuario$|cabelereiro|lavanderia'THEN macro:='Cuidados pessoais';g:='Vestuário e cuidados';
 WHEN c~'viagem|passagem aerea|^hotel$|duty free|^mala$'THEN macro:='Viagens';g:='Viagens e estadias';
 WHEN c~'lazer|passeio|rock in rio|socio rei|gympass|natacao'THEN macro:='Lazer e bem-estar';g:='Atividades e lazer';
 WHEN c~'casamento|batizado|^eventos$'THEN macro:='Eventos';g:='Eventos pessoais';
 WHEN c~'assinaturas|spotify|google|apple|armazenamento|telefone|iphone'THEN macro:='Comunicações e serviços digitais';g:='Serviços e equipamentos';
 WHEN c~'tarifas|juros|^iof$|^anuidade$'THEN macro:='Serviços financeiros';g:='Taxas e encargos';
 WHEN c~'^seguro|^seguros'THEN macro:='Seguros';g:='Proteção pessoal';
 WHEN c~'^presentes$|^doacoes$|^religiao$'THEN macro:='Vida pessoal e familiar';g:='Presentes e contribuições';
 WHEN c~'^(lucas|larissa|benjamin|rafiki|marino)([[:space:]]|$)|^familia$'THEN macro:='Vida pessoal e familiar';g:='Tipo de gasto não detalhado';cat:='Despesas pessoais sem tipo informado';
 ELSE macro:='Outras despesas';g:='Categorias da origem';
 END CASE;
 IF c='cipo 396'AND k~'aquisicao'THEN cat:='Pagamentos de aquisição sem composição';END IF;
 RETURN jsonb_build_object('macrogroup',macro,'group',g,'category',coalesce(cat,'Categoria não informada'),'is_tax',tax);
END $function$
$candidate$;IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid='public.lts_expense_taxonomy_v353(text,text,text)'::regprocedure) OR md5(pg_get_functiondef('public.lts_expense_taxonomy_v353(text,text,text)'::regprocedure))<>'fdb06094d1a5057c56cfd1d331f2d726' THEN RAISE EXCEPTION 'Loan grouping attributes changed';END IF;END $guard$;
DO $guard$ DECLARE s text;a jsonb;BEGIN SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO STRICT s,a FROM pg_proc p WHERE p.oid='lts_budget_private_v441.build(uuid,integer,date)'::regprocedure;IF md5(s)='3b046ddad96b3e8c5edce0901d1d49a2' THEN RETURN;END IF;IF md5(s) NOT IN('8041add67e5f514c102754dfaa81cc66','7f86141829a633859509f3e9457a23c4') THEN RAISE EXCEPTION 'Budget metadata and thirteenth separation predecessor changed; review before applying';END IF;EXECUTE $candidate$CREATE OR REPLACE FUNCTION lts_budget_private_v441.build(p_user uuid, p_year integer, p_today date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
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
 RETURN result;
END $function$
$candidate$;IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid='lts_budget_private_v441.build(uuid,integer,date)'::regprocedure) OR md5(pg_get_functiondef('lts_budget_private_v441.build(uuid,integer,date)'::regprocedure))<>'3b046ddad96b3e8c5edce0901d1d49a2' THEN RAISE EXCEPTION 'Budget metadata and thirteenth separation attributes changed';END IF;END $guard$;
DO $guard$ DECLARE s text;a jsonb;BEGIN SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO STRICT s,a FROM pg_proc p WHERE p.oid='public.lts_browser_flow_event_editor_v1(text,text,date)'::regprocedure;IF md5(s)='1767c0ac7a1b7bb9b033f723cd03a5dd' THEN RETURN;END IF;IF md5(s)<>'1158891eb0c5605e17e6ed130cf05b99' THEN RAISE EXCEPTION 'Read-only income composition predecessor changed; review before applying';END IF;EXECUTE $candidate$CREATE OR REPLACE FUNCTION public.lts_browser_flow_event_editor_v1(p_source text, p_source_ref text, p_event_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
 DECLARE u uuid:=public.lts_browser_assert_user_v1();r jsonb;original jsonb;parts jsonb;total numeric;
 BEGIN
  r:=public.lts_flow_event_editor_v1(u,p_source,p_source_ref,p_event_date);
  IF p_source='legacy_fix86' AND p_source_ref~'^evento_base:[0-9]+$' THEN
   SELECT jsonb_agg(dados)->0 INTO original FROM public.evento_base WHERE usuario_id=u AND 'evento_base:'||idx=p_source_ref HAVING count(*)=1;
   parts:=original->'composition';
   IF jsonb_typeof(parts)='array' AND jsonb_array_length(parts) BETWEEN 1 AND 12 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(parts)x WHERE NOT coalesce(jsonb_typeof(x->'amount')='number' AND x->>'amount'~'^[0-9]+([.][0-9]+)?$' AND nullif(trim(x->>'rubric'),'') IS NOT NULL,false)) THEN
    SELECT sum((x->>'amount')::numeric) INTO total FROM jsonb_array_elements(parts)x
    WHERE jsonb_typeof(x->'amount')='number' AND x->>'amount'~'^[0-9]+([.][0-9]+)?$';
    IF total=(r->>'amount')::numeric AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(parts)x
     WHERE nullif(trim(x->>'rubric'),'') IS NULL OR jsonb_typeof(x->'amount')<>'number') THEN
     r:=r||jsonb_build_object('composition',parts,'payroll_reference_date',original->>'payroll_reference_date',
      'composition_document_pending',coalesce(original#>'{evidence,statement_pending}'='true'::jsonb,false));
    END IF;
   END IF;
  END IF;
  RETURN r;
 END $function$
$candidate$;IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid='public.lts_browser_flow_event_editor_v1(text,text,date)'::regprocedure) OR md5(pg_get_functiondef('public.lts_browser_flow_event_editor_v1(text,text,date)'::regprocedure))<>'1767c0ac7a1b7bb9b033f723cd03a5dd' THEN RAISE EXCEPTION 'Read-only income composition attributes changed';END IF;END $guard$;
