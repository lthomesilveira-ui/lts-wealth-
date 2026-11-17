-- Specific owner-approved planning only. No bank, purchase or payment writes.
CREATE SCHEMA IF NOT EXISTS lts_recurring_private_v469;
REVOKE ALL ON SCHEMA lts_recurring_private_v469 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION lts_recurring_private_v469.owner_plan(u uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=''
AS $f$
DECLARE raw text; h text; j jsonb;
BEGIN
 SELECT valor_bruto,sha256 INTO raw,h FROM public.legacy_namespace
 WHERE usuario_id=u AND chave='lts_owner_recurring_plan_v469';
 IF NOT FOUND THEN RETURN NULL;END IF;
 IF h IS DISTINCT FROM encode(sha256(convert_to(raw,'UTF8')),'hex') THEN RAISE EXCEPTION 'Confira as despesas recorrentes do planejamento.';END IF;
 j:=raw::jsonb;
 IF j->>'owner_id' IS DISTINCT FROM u::text OR j->>'schema' IS DISTINCT FROM 'specific-recurring-plan-v469'
 OR jsonb_typeof(j->'budgets') IS DISTINCT FROM 'array' OR jsonb_typeof(j->'school_sources') IS DISTINCT FROM 'array'
 THEN RAISE EXCEPTION 'Confira as despesas recorrentes do planejamento.';END IF;
 RETURN j;
END $f$;

CREATE OR REPLACE FUNCTION lts_recurring_private_v469.third_business_day(m date)
RETURNS date LANGUAGE plpgsql IMMUTABLE SET search_path=''
AS $f$
DECLARE y int:=extract(year FROM m);a int;b int;c int;d int;e int;f int;g int;h int;i int;k int;l int;n int;z int;
 easter date; v date; cnt int:=0;
BEGIN
 IF m IS NULL OR y NOT BETWEEN 2024 AND 2099 THEN RAISE EXCEPTION 'Confira o mês da mensalidade.';END IF;
 -- Gregorian Easter; banking calendar follows CMN 4,880 art.6 and SP holidays.
 a:=y%19;b:=y/100;c:=y%100;d:=b/4;e:=b%4;f:=(b+8)/25;g:=(b-f+1)/3;
 h:=(19*a+b-d-g+15)%30;i:=c/4;k:=c%4;l:=(32+2*e+2*i-h-k)%7;n:=(a+11*h+22*l)/451;
 z:=h+l-7*n+114;easter:=make_date(y,z/31,z%31+1);
 v:=date_trunc('month',m)::date;
 LOOP
  IF extract(isodow FROM v)<6
   AND to_char(v,'MM-DD') NOT IN('01-01','01-25','04-21','05-01','07-09','09-07','10-12','11-02','11-15','11-20','12-25')
   AND v NOT IN(easter-48,easter-47,easter-2,easter+60)
  THEN cnt:=cnt+1;END IF;
  IF cnt=3 THEN RETURN v;END IF;
  v:=v+1;
 END LOOP;
END $f$;

CREATE OR REPLACE FUNCTION lts_recurring_private_v469.forecast(id text,descr text,acct text,amt numeric,d date)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path=''
AS $f$
SELECT jsonb_build_object('event_date',d,'original_date',d,'description',descr,'account',acct,
 'signed_amount',-amt,'source','planning_projection_v412','source_ref','projection:v469:'||id||':'||d::text,
 'confidence','owner_confirmed_specific_recurring_plan','account_assignment','owner_policy','legacy_index',NULL,
 'displaced',false,'series_key','recurring_'||id,'method','fixed');
$f$;

CREATE OR REPLACE FUNCTION lts_recurring_private_v469.calculate(plan jsonb,base jsonb,calendar jsonb,paid_school jsonb,asof date)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path=''
AS $f$
DECLARE horizon date:=(base->>'horizon_end')::date; ev jsonb:='[]'; rr jsonb:=coalesce(base->'replacement_refs','[]');
 series jsonb:=base->'series'; warnings jsonb:=base->'warnings'; e jsonb;s jsonb;r jsonb;c jsonb;x jsonb;
 m date;due date; target numeric;known numeric;extra numeric;periods jsonb;annual jsonb;cnt int;bad int;ident text;
BEGIN
 IF plan IS NULL THEN RETURN base;END IF;
 IF plan->>'schema' IS DISTINCT FROM 'specific-recurring-plan-v469' OR asof IS NULL
 OR base->>'as_of' IS DISTINCT FROM asof::text OR horizon<asof OR jsonb_typeof(calendar)<>'array'
 OR jsonb_typeof(paid_school)<>'array' OR jsonb_typeof(plan->'budgets')<>'array'
 OR jsonb_array_length(plan->'budgets')<>4 OR jsonb_typeof(plan->'school_sources')<>'array'
 OR (plan->>'school_total_brl')::numeric IS DISTINCT FROM (plan->>'school_food_brl')::numeric+(plan->>'school_tuition_brl')::numeric
 OR (SELECT count(DISTINCT x->>'id') FROM jsonb_array_elements(plan->'budgets')x)<>4
 OR (plan->>'school_food_day')::int NOT BETWEEN 1 AND 28
 THEN RAISE EXCEPTION 'Confira o planejamento de despesas recorrentes.';END IF;
 -- Only unreceived card forecasts move. Known invoices and direct debits stay.
 FOR e IN SELECT value FROM jsonb_array_elements(base->'events') LOOP
  IF e->>'source_ref' LIKE 'projection:v468:%' AND coalesce((plan->>'centralize_card_forecasts')::boolean,false) THEN
   due:=date_trunc('month',(e->>'event_date')::date)::date+2;
   IF due>asof THEN
    ident:='sub_'||split_part(e->>'source_ref',':',3);
    e:=e||jsonb_build_object('event_date',due,'original_date',due,'account','Bradesco',
     'source_ref','projection:v469:'||ident||':'||due::text,'series_key','recurring_'||ident);
    ev:=ev||jsonb_build_array(e);
   ELSE
    warnings:=warnings||jsonb_build_array(jsonb_build_object('series_key',e->>'series_key','codes',jsonb_build_array('elapsed_forecast_requires_review')));
   END IF;
  ELSE ev:=ev||jsonb_build_array(e);END IF;
 END LOOP;
 -- Preserve known coverage dates, move only the estimated subscription periods.
 SELECT coalesce(jsonb_agg(CASE WHEN s->>'series_key' LIKE 'subscription_%' AND coalesce((plan->>'centralize_card_forecasts')::boolean,false)
 THEN s||jsonb_build_object('account','Bradesco','coverage',(SELECT jsonb_agg(CASE WHEN x->>'status'='specific_recurring_forecast'
 THEN x||jsonb_build_object('event_date',date_trunc('month',(x->>'event_date')::date)::date+2) ELSE x END ORDER BY ord)
 FROM jsonb_array_elements(s->'coverage')WITH ORDINALITY z(x,ord))) ELSE s END ORDER BY n),'[]') INTO series
 FROM jsonb_array_elements(series)WITH ORDINALITY q(s,n);
 FOR r IN SELECT value FROM jsonb_array_elements(plan->'school_sources') LOOP
  IF (r->>'event_date')::date>asof THEN rr:=rr||jsonb_build_array(r->>'source_ref');END IF;
 END LOOP;
 -- Each month-end amount funds food this month and tuition next month.
 FOR m IN SELECT d::date FROM generate_series((plan->>'school_start_month')::date,date_trunc('month',horizon),interval '1 month')d LOOP
  FOR ident,target,due IN SELECT 'school_food',(plan->>'school_food_brl')::numeric,m+(plan->>'school_food_day')::int-1 UNION ALL
   SELECT 'school_tuition',(plan->>'school_tuition_brl')::numeric,lts_recurring_private_v469.third_business_day((m+interval '1 month')::date) LOOP
   IF due<=asof OR due>horizon THEN CONTINUE;END IF;
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(paid_school)p WHERE p->>'id'=ident AND p->>'cash_month'=date_trunc('month',due)::date::text) THEN CONTINUE;END IF;
   ev:=ev||jsonb_build_array(lts_recurring_private_v469.forecast(ident,
    CASE ident WHEN 'school_food' THEN plan->>'school_food_description' ELSE plan->>'school_tuition_description' END,plan->>'school_account',target,due));
  END LOOP;
 END LOOP;
 FOR r IN SELECT value FROM jsonb_array_elements(plan->'budgets') ORDER BY value->>'id' LOOP
  ident:=r->>'id';target:=(r->>'amount_brl')::numeric;periods:='[]';cnt:=0;bad:=0;
  IF ident NOT IN('pharmacy','hair','membership','prime_2990') OR target IS NULL OR target<=0 OR target>100000 OR nullif(r->>'description','') IS NULL
  THEN RAISE EXCEPTION 'Confira o valor da despesa recorrente.';END IF;
  FOR m IN SELECT d::date FROM generate_series((plan->>'budget_start_month')::date,date_trunc('month',horizon),interval '1 month')d LOOP
   due:=m+2;IF due<=asof OR due>horizon THEN CONTINUE;END IF;
   SELECT count(*) INTO cnt FROM jsonb_array_elements(calendar)z WHERE z->>'id'=ident AND z->>'cash_month'=m::text;
   IF cnt<>1 THEN RAISE EXCEPTION 'Não foi possível conferir a cobertura mensal.';END IF;
   SELECT value INTO c FROM jsonb_array_elements(calendar) WHERE value->>'id'=ident AND value->>'cash_month'=m::text;
   IF c->>'trusted' IS DISTINCT FROM 'true' THEN
    extra:=NULL;known:=NULL;bad:=bad+1;
   ELSE
    known:=greatest((c->>'known_brl')::numeric,0);extra:=greatest(target-known,0);
    IF extra>0 THEN ev:=ev||jsonb_build_array(lts_recurring_private_v469.forecast(ident,r->>'description','Bradesco',extra,due));END IF;
   END IF;
   periods:=periods||jsonb_build_array(jsonb_build_object('event_date',due,'budget_total_brl',target,'known_brl',known,'additional_brl',extra,'trusted',c->'trusted'));
  END LOOP;
  SELECT coalesce(jsonb_agg(jsonb_build_object('year',y,'partial_year',y=extract(year FROM asof)::int,
   'budget_total_brl',CASE WHEN ok THEN total ELSE NULL END,'additional_brl',CASE WHEN ok THEN more ELSE NULL END) ORDER BY y),'[]') INTO annual
  FROM(SELECT extract(year FROM(x->>'event_date')::date)::int y,bool_and((x->>'trusted')::boolean)ok,
   sum(greatest((x->>'budget_total_brl')::numeric,(x->>'known_brl')::numeric))total,sum((x->>'additional_brl')::numeric)more
   FROM jsonb_array_elements(periods)x GROUP BY 1)a;
  series:=series||jsonb_build_array(jsonb_build_object('series_key','recurring_'||ident,'description',r->>'description','account','Bradesco','direction','expense','method','fixed',
   'reference_amount_brl',target,'reference_window',r->'reference_window','uses_history',ident IN('pharmacy','hair'),'reference_stale',false,
   'expected_months',12,'coverage_months',r->'coverage_months','annual_totals',annual,'coverage',periods,'warnings',CASE WHEN bad>0 THEN '["unreconciled_periods"]'::jsonb ELSE '[]'::jsonb END));
  IF bad>0 THEN warnings:=warnings||jsonb_build_array(jsonb_build_object('series_key','recurring_'||ident,'codes',jsonb_build_array('unreconciled_periods')));END IF;
 END LOOP;
 RETURN base||jsonb_build_object('events',ev,'replacement_refs',rr,'series',series,'warnings',warnings);
END $f$;

CREATE OR REPLACE FUNCTION lts_recurring_private_v469.append_result(u uuid,asof date,base jsonb,cards jsonb,baseline jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' SET TimeZone='America/Sao_Paulo'
AS $f$
DECLARE plan jsonb:=lts_recurring_private_v469.owner_plan(u); calendar jsonb;paid jsonb;r jsonb;horizon date:=(base->>'horizon_end')::date;
BEGIN
 IF plan IS NULL THEN RETURN base;END IF;
 IF cards IS NULL THEN cards:=public.lts_card_cycles_v226(u);END IF;
 -- Reject a changed future school source instead of overwriting a user edit.
 FOR r IN SELECT value FROM jsonb_array_elements(plan->'school_sources') WHERE (value->>'event_date')::date>asof LOOP
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(baseline)b WHERE b->>'source_ref'=r->>'source_ref'
   AND b->>'event_date'=r->>'event_date' AND b->>'account'=plan->>'school_account'
   AND (b->>'signed_amount')::numeric=-(plan->>'school_total_brl')::numeric AND b->>'description'=plan->>'school_original_description')
  THEN RAISE EXCEPTION 'Uma previsão da escola foi alterada. Confira as datas e os valores.';END IF;
 END LOOP;
 WITH items AS MATERIALIZED(
  SELECT ca->>'family' family,date_trunc('month',(cy->>'due_date')::date)::date cash_month,cy->>'amount' cycle_amount,i,
   public.lts_v178_norm(i->>'category') cat,
   (SELECT sum(abs((b->>'signed_amount')::numeric)) FROM jsonb_array_elements(baseline)b
    WHERE (b->>'signed_amount')::numeric<0 AND public.lts_card_family_v226(b->>'description',b->>'account')=ca->>'family'
    AND date_trunc('month',(b->>'event_date')::date)=date_trunc('month',(cy->>'due_date')::date)) base_amount
  FROM jsonb_array_elements(cards->'cards')ca CROSS JOIN LATERAL jsonb_array_elements(ca->'cycles')cy
  CROSS JOIN LATERAL jsonb_array_elements(cy->'items')i
  WHERE (cy->>'due_date')::date>asof AND coalesce(i->>'is_payment','false')<>'true' AND (i->>'amount')::numeric>0
 ), matched AS MATERIALIZED(
  SELECT r->>'id' id,t.* FROM jsonb_array_elements(plan->'budgets')r JOIN items t ON
   (r->>'id'='pharmacy' AND t.cat='farmacia') OR (r->>'id'='hair' AND t.cat IN('cabelereiro','cabeleireiro'))
   OR (r->>'id'='membership' AND (t.cat='socio rei' OR public.lts_bank_merchant_key_v231(t.i->>'description') LIKE '%sociorei%'))
   OR (r->>'id'='prime_2990' AND t.family='bradesco_prime' AND (t.i->>'amount')::numeric=(r->>'amount_brl')::numeric)
 ), slots AS(
  SELECT r->>'id' id,d::date cash_month FROM jsonb_array_elements(plan->'budgets')r
  CROSS JOIN generate_series((plan->>'budget_start_month')::date,date_trunc('month',horizon),interval '1 month')d
 ) SELECT jsonb_agg(jsonb_build_object('id',s.id,'cash_month',s.cash_month,
  'known_brl',coalesce((SELECT sum((t.i->>'amount')::numeric) FROM matched t WHERE t.id=s.id AND t.cash_month=s.cash_month),0),
  'trusted',coalesce(cards->>'complete','false')='true'
   AND NOT EXISTS(SELECT 1 FROM matched t WHERE t.id=s.id AND t.cash_month=s.cash_month
    AND (nullif(t.i->>'source_id','') IS NULL OR t.base_amount IS NULL OR abs(t.base_amount-t.cycle_amount::numeric)>0.005))))
 INTO calendar FROM slots s;
 SELECT coalesce(jsonb_agg(DISTINCT jsonb_build_object('id',CASE WHEN description_raw ILIKE plan->>'school_tuition_match' THEN 'school_tuition' ELSE 'school_food' END,
  'cash_month',date_trunc('month',posting_date)::date)),'[]') INTO paid
 FROM public.lts_open_finance_staging WHERE user_id=u AND resource_type='transaction' AND currency='BRL'
 AND provider_deleted_at IS NULL AND normalized_payload->>'status'='POSTED'
 AND posting_date BETWEEN date_trunc('month',asof)::date AND asof
 AND ((description_raw ILIKE plan->>'school_tuition_match' AND signed_amount=-(plan->>'school_tuition_brl')::numeric)
  OR (description_raw ILIKE plan->>'school_food_match' AND -signed_amount IN(SELECT value::numeric FROM jsonb_array_elements_text(plan->'school_known_food_amounts'))));
 RETURN lts_recurring_private_v469.calculate(plan,base,calendar,paid,asof);
END $f$;

CREATE OR REPLACE FUNCTION lts_recurring_private_v469.classification(u uuid,e jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=''
AS $f$
DECLARE plan jsonb;id text;cat text;
BEGIN
 IF e->>'source' IS DISTINCT FROM 'planning_projection_v412' OR e->>'source_ref' NOT LIKE 'projection:v469:%' THEN RETURN NULL;END IF;
 plan:=lts_recurring_private_v469.owner_plan(u);IF plan IS NULL THEN RETURN NULL;END IF;
 id:=split_part(e->>'source_ref',':',3);
 cat:=CASE WHEN id IN('school_food','school_tuition') THEN plan->>'school_category'
  WHEN id='pharmacy' THEN 'Farmácia' WHEN id='hair' THEN 'Cabelereiro' WHEN id='membership' THEN 'Sócio Rei'
  WHEN id='prime_2990' THEN 'Assinaturas' WHEN id LIKE 'sub_apple_%' THEN 'Apple'
  WHEN id='sub_google_ai_plus' THEN 'Armazenamento' WHEN id='sub_spotify' THEN 'Spotify' WHEN id='sub_amazon_prime' THEN 'Amazon' END;
 IF cat IS NULL THEN RETURN NULL;END IF;
 RETURN e||jsonb_build_object('category',cat,'classification_confirmed',true,'center_cost',CASE WHEN id IN('school_food','school_tuition') THEN plan->>'school_beneficiary' ELSE NULL END);
END $f$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA lts_recurring_private_v469 FROM PUBLIC,anon,authenticated,service_role;

DO $guard$ BEGIN
 IF md5(pg_get_functiondef('lts_projection_private_v412.build(uuid,date)'::regprocedure))<>'1656f562eed0cb8936252ec8ca9381cc' OR md5(pg_get_functiondef('public.lts_flow_classification_decision_v1(uuid,jsonb)'::regprocedure))<>'4bc0f47babbba8bf30fced74161cf19a' THEN RAISE EXCEPTION 'Predecessor changed; reconcile before applying';END IF;
END $guard$;
CREATE OR REPLACE FUNCTION lts_projection_private_v412.build(p_user_id uuid, p_as_of date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE subscription_cards_v468 jsonb;
 received_income_v443 jsonb; projection_result_v418 jsonb; worker_claim_v418 jsonb;
 -- V437: transaction-local memo, valid only for this statement and input state.
 memo_key_v437 text; memo_v437 jsonb;
 policy jsonb:=lts_projection_private_v412.owner_policy(p_user_id); horizon date;
 wf date;wt date;nr date;history jsonb;templates jsonb;baseline jsonb;cycles jsonb;slots jsonb:='[]';
 r jsonb;t jsonb;period record;key text;method text;d date;nominal date;day_number int;
 base_amount numeric;known numeric;replace_amount numeric;replace_refs jsonb;refs jsonb;authoritative boolean;
 known_complete boolean;cancelled boolean;withholding numeric;withholding_known boolean;calendar_days jsonb;canonical_due date;
 seen_dates date[];replacement_seen text[]:='{}';withholding_rows int;invoice_amount numeric;invoice_count int;
 baseline_months jsonb;baseline_legacy_years jsonb;cycle_months jsonb;
 monthly_bucket jsonb;cycle_bucket jsonb;
BEGIN
 IF policy IS NULL THEN RETURN jsonb_build_object('version','projection-policy-v412','enabled',false); END IF;
 policy:=policy||jsonb_build_object('_history_reference',lts_projection_private_v412.reference_state(p_user_id));
 projection_result_v418:=lts_projection_private_v412.read_build_cache_v438(p_user_id,p_as_of,policy);
 IF projection_result_v418 IS NOT NULL THEN

 worker_claim_v418:=nullif(current_setting('lts.product_refresh_claim',true),'')::jsonb;
 IF worker_claim_v418->>'user_id'=p_user_id::text AND p_as_of=current_date THEN
  PERFORM set_config('lts.projection_summary_v418',jsonb_build_object(
   'user_id',p_user_id,'as_of',p_as_of,
   'summary',projection_result_v418-'events'-'replacement_refs')::text,true);
 END IF;
  RETURN projection_result_v418;
 END IF;
 memo_key_v437:=encode(sha256(convert_to(jsonb_build_array(
  p_user_id,p_as_of,current_user,pg_backend_pid(),statement_timestamp(),
  pg_current_snapshot()::text,
  (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true),
  policy,lts_product_refresh_private_v415.card_source_key(p_user_id)
 )::text,'UTF8')),'hex');
 BEGIN
  memo_v437:=nullif(current_setting('lts.projection_memo_v437',true),'')::jsonb;
 EXCEPTION WHEN invalid_text_representation THEN memo_v437:=NULL;
 END;
 IF memo_v437->>'key'=memo_key_v437
  AND memo_v437->>'digest'=encode(sha256(convert_to((memo_v437->'payload')::text,'UTF8')),'hex')
  AND jsonb_typeof(memo_v437->'payload')='object' THEN
  projection_result_v418:=memo_v437->'payload';

 worker_claim_v418:=nullif(current_setting('lts.product_refresh_claim',true),'')::jsonb;
 IF worker_claim_v418->>'user_id'=p_user_id::text AND p_as_of=current_date THEN
  PERFORM set_config('lts.projection_summary_v418',jsonb_build_object(
   'user_id',p_user_id,'as_of',p_as_of,
   'summary',projection_result_v418-'events'-'replacement_refs')::text,true);
 END IF;
  RETURN projection_result_v418;
 END IF;

 horizon:=lts_projection_private_v412.horizon_end(p_as_of);
 SELECT * INTO wf,wt,nr FROM lts_projection_private_v412.review_window(policy,p_as_of);
 SELECT coalesce(jsonb_agg(to_jsonb(f)ORDER BY series_key,month),'[]') INTO history
 FROM lts_projection_private_v412.monthly_source_facts_v412(p_user_id,
  least(wf,(date_trunc('month',p_as_of::timestamp)-interval '3 months')::date),
  greatest(wt,date_trunc('month',p_as_of::timestamp)::date-1),policy)f;
 SELECT coalesce(jsonb_agg(to_jsonb(template_row)ORDER BY series_key,event_month,event_day,source_ref),'[]') INTO templates
 FROM lts_projection_private_v412.calendar_templates_v412(p_user_id,policy)template_row;
 SELECT coalesce(jsonb_agg(to_jsonb(b)ORDER BY event_date,source_ref),'[]') INTO baseline
 FROM lts_projection_private_v412.base_flow(p_user_id,p_as_of+1,horizon)b;
 SELECT coalesce(jsonb_agg(to_jsonb(c)ORDER BY series_key,due_date),'[]') INTO cycles
 FROM lts_projection_private_v412.known_card_periods_v412(p_user_id)c;

 -- V413: classify each baseline row once and aggregate immutable lookup buckets.
 -- The slot loop retains the exact prior ordering, documentary precedence and
 -- replacement_seen semantics. These values exist only during this invocation.
 WITH normalized AS MATERIALIZED (
  SELECT public.lts_forecast_series_key_v1(b.value->>'description') AS series_key,
   ((b.value->>'signed_amount')::numeric>0) AS is_income,
   date_trunc('month',(b.value->>'event_date')::date)::date AS event_month,
   extract(year FROM (b.value->>'event_date')::date)::int AS event_year,
   abs((b.value->>'signed_amount')::numeric) AS amount_brl,
   b.value->>'source_ref' AS source_ref,b.value->>'source' AS source,
   b.value->>'confidence' AS confidence
  FROM jsonb_array_elements(baseline)b(value)
 ), monthly AS (
  SELECT jsonb_build_array(n.series_key,n.is_income,n.event_month)::text AS bucket,
   jsonb_build_object('amount_brl',coalesce(sum(n.amount_brl),0),
    'source_refs',jsonb_agg(n.source_ref ORDER BY n.source_ref),
    'legacy_estimate_brl',coalesce(sum(n.amount_brl) FILTER(WHERE n.source='legacy_fix86' AND n.confidence='legacy_projection_adjusted'),0),
    'documentary',coalesce(bool_or(NOT(n.source='legacy_fix86'
      AND n.confidence='legacy_projection_adjusted')),false)) AS facts
  FROM normalized n
  WHERE n.series_key IS NOT NULL AND n.is_income IS NOT NULL AND n.event_month IS NOT NULL
  GROUP BY n.series_key,n.is_income,n.event_month
 ), annual_legacy AS (
  SELECT jsonb_build_array(n.series_key,n.is_income,n.event_year)::text AS bucket,
   jsonb_agg(jsonb_build_object('source_ref',n.source_ref,'amount_brl',n.amount_brl)
    ORDER BY n.source_ref) AS facts
  FROM normalized n
  WHERE n.source='legacy_fix86' AND n.confidence='legacy_projection_adjusted'
   AND n.series_key IS NOT NULL AND n.is_income IS NOT NULL AND n.event_year IS NOT NULL
  GROUP BY n.series_key,n.is_income,n.event_year
 )
 SELECT coalesce((SELECT jsonb_object_agg(m.bucket,m.facts) FROM monthly m),'{}'),
  coalesce((SELECT jsonb_object_agg(a.bucket,a.facts) FROM annual_legacy a),'{}')
 INTO baseline_months,baseline_legacy_years;

 WITH normalized AS MATERIALIZED (
  SELECT v.value->>'series_key' AS series_key,(v.value->>'due_date')::date AS due_date,
   date_trunc('month',(v.value->>'due_date')::date)::date AS due_month,
   coalesce((v.value->>'closed')::boolean,false)
    OR coalesce((v.value->>'paid')::boolean,false) AS authoritative,
   coalesce((v.value->>'complete')::boolean,false) AS complete,
   (v.value->>'amount_brl')::numeric AS amount_brl
  FROM jsonb_array_elements(cycles)v(value)
 ), monthly AS (
  SELECT jsonb_build_array(n.series_key,n.due_month)::text AS bucket,
   jsonb_build_object('due_date',min(n.due_date),'invoice_count',count(*)::int,
    'authoritative',coalesce(bool_or(n.authoritative),false),
    'complete',coalesce(bool_and(n.complete),true),'amount_brl',sum(n.amount_brl)) AS facts
  FROM normalized n
  WHERE n.series_key IS NOT NULL AND n.due_month IS NOT NULL
  GROUP BY n.series_key,n.due_month
 )
 SELECT coalesce(jsonb_object_agg(m.bucket,m.facts),'{}') INTO cycle_months FROM monthly m;

 FOR r IN SELECT value FROM jsonb_array_elements(policy->'rules')
  WHERE coalesce(value->>'active','true')='true' ORDER BY value->>'series_key' LOOP
  key:=r->>'series_key';method:=r->>'method';seen_dates:='{}';calendar_days:='[]';
  IF method IN('inflated_calendar','repeat_calendar') AND coalesce(r->>'template_source','calendar')<>'history_mean' THEN
   -- Templates may include several installments and a separate license in a year.
   -- Equal calendar dates aggregate once, retaining all original references.
   SELECT coalesce(jsonb_agg(to_jsonb(a)ORDER BY event_month,event_day),'[]') INTO calendar_days
   FROM(SELECT (v->>'event_month')::int event_month,(v->>'event_day')::int event_day,
    sum((v->>'amount_brl')::numeric) amount_brl,jsonb_agg(v->>'source_ref') source_refs
    FROM jsonb_array_elements(templates)v WHERE v->>'series_key'=key
    GROUP BY 1,2)a;
  ELSE
   day_number:=nullif(r->>'due_day','')::int;
   IF day_number IS NULL THEN
    -- Modal observed day; ties use the earlier day and remain explicitly estimated.
    SELECT value::int INTO day_number FROM jsonb_array_elements(history)f
    CROSS JOIN LATERAL jsonb_array_elements_text(coalesce(f->'observed_days','[]'))x(value)
    WHERE f->>'series_key'=key AND (f->>'month')::date BETWEEN wf AND wt AND value~'^[0-9]{1,2}$' AND value::int BETWEEN 1 AND 31
    GROUP BY value ORDER BY count(*) DESC,value::int LIMIT 1;
   END IF;
   IF day_number BETWEEN 1 AND 31 THEN
    SELECT jsonb_agg(jsonb_build_object('event_month',n,'event_day',day_number,
     'amount_brl',r->'amount_brl','source_refs','[]'::jsonb)ORDER BY n) INTO calendar_days
    FROM generate_series(1,12)n;
   END IF;
  END IF;
  FOR period IN SELECT generate_series(extract(year FROM p_as_of)::int,extract(year FROM horizon)::int) AS calendar_year LOOP
   FOR t IN SELECT value FROM jsonb_array_elements(calendar_days) ORDER BY (value->>'event_month')::int,(value->>'event_day')::int LOOP
    nominal:=make_date(period.calendar_year,(t->>'event_month')::int,1);
    d:=nominal+least((t->>'event_day')::int,extract(day FROM nominal+interval '1 month -1 day')::int)-1;
    IF r->>'card_family' IS NOT NULL THEN
     -- Current owner calendar and an explicit transition outrank a historical mode.
     cycle_bucket:=cycle_months->(jsonb_build_array(key,nominal)::text);
     canonical_due:=(cycle_bucket->>'due_date')::date;
     -- A cycle's cash date already includes the V370 transition. Apply that
     -- transition only to a new nominal date, never a second time to a cycle.
     d:=CASE WHEN canonical_due IS NOT NULL THEN canonical_due
      ELSE public.lts_card_transition_cash_date_v370(p_user_id,r->>'card_family',d) END;
    END IF;
    IF d<=p_as_of OR d>horizon OR d<(r->>'starts_on')::date OR d=ANY(seen_dates)
     OR(r->>'ends_on' IS NOT NULL AND d>(r->>'ends_on')::date) THEN CONTINUE; END IF;
    seen_dates:=array_append(seen_dates,d);base_amount:=nullif(t->>'amount_brl','')::numeric;
    monthly_bucket:=baseline_months->(jsonb_build_array(key,r->>'direction'='income',
     date_trunc('month',d)::date)::text);
    known:=coalesce((monthly_bucket->>'amount_brl')::numeric,0);
    refs:=coalesce(monthly_bucket->'source_refs','[]');
    authoritative:=false;known_complete:=true;replace_amount:=0;replace_refs:='[]';
    IF r->>'card_family' IS NOT NULL THEN
     cycle_bucket:=cycle_months->(jsonb_build_array(key,date_trunc('month',d)::date)::text);
     invoice_count:=coalesce((cycle_bucket->>'invoice_count')::int,0);
     authoritative:=coalesce((cycle_bucket->>'authoritative')::boolean,false);
     known_complete:=coalesce((cycle_bucket->>'complete')::boolean,true);
     invoice_amount:=(cycle_bucket->>'amount_brl')::numeric;
     -- If a canonical cycle is missing from this reader, do not hide the mismatch
     -- by estimating a smaller residual against a different amount.
     IF invoice_count>0 AND invoice_amount IS NOT NULL AND NOT authoritative
      AND abs(invoice_amount-known)>0.005 THEN known_complete:=false;END IF;
    END IF;
    cancelled:=EXISTS(SELECT 1 FROM public.lts_projection_replacement_rule c
     WHERE c.user_id=p_user_id AND c.active AND c.action='suppress_legacy'
      AND c.replacement_source='owner_confirmation' AND coalesce(c.evidence->>'policy_action','')<>'revise'
      AND public.lts_forecast_series_key_v1(c.description_exact)=key AND d BETWEEN c.date_from AND c.date_to)
     OR EXISTS(SELECT 1 FROM public.lts_recurring_plan_v366 p
      WHERE p.user_id=p_user_id AND p.series_key=key
       AND (p.direction='entrada')=(r->>'direction'='income')
       AND p.confirmed_at >= (policy->>'_activated_at')::timestamptz
       AND ((NOT p.active AND d>=p.starts_on) OR (p.ends_on IS NOT NULL AND d>p.ends_on)));
    IF method='inflated_calendar' THEN
     -- The new annual template may split an old lump-sum estimate. Suppress all
     -- identified estimates for the same future year once, on its first slot.
     SELECT coalesce(jsonb_agg(v->>'source_ref' ORDER BY v->>'source_ref'),'[]'),
      coalesce(sum((v->>'amount_brl')::numeric),0)
     INTO replace_refs,replace_amount FROM jsonb_array_elements(coalesce(
      baseline_legacy_years->(jsonb_build_array(key,r->>'direction'='income',
       period.calendar_year)::text),'[]'))v
     WHERE NOT(v->>'source_ref'=ANY(replacement_seen));
     -- Documentary amounts in a month replace that month's estimate, preserving
     -- their identity/date and preventing a budget from adding a second payment.
     authoritative:=coalesce((monthly_bucket->>'documentary')::boolean,false);
     IF NOT authoritative AND NOT cancelled THEN
      SELECT coalesce(array_agg(value),'{}')||replacement_seen INTO replacement_seen
      FROM jsonb_array_elements_text(replace_refs);
      known:=replace_amount;
     ELSE replace_refs:='[]';replace_amount:=0; END IF;
    END IF;
    withholding:=NULL;withholding_known:=false;
    IF method='salary_net' THEN
     SELECT count(*)::int,sum(abs(amount_total)) INTO withholding_rows,withholding
     FROM public.lts_commitment_documentary_schedule c WHERE c.user_id=p_user_id
      AND c.commitment_id=r->>'withholding_commitment'
      AND date_trunc('month',c.due_date)=date_trunc('month',d);
     withholding_known:=withholding_rows>0;
     IF withholding_rows=0 AND pg_catalog.pg_input_is_valid(r->>'withholding_ends_on','date')
      AND nullif(btrim(r->>'withholding_end_source_ref'),'') IS NOT NULL
      AND d>(r->>'withholding_ends_on')::date
      THEN withholding:=0;withholding_known:=true;END IF;
    END IF;
    -- V443 reviewed incoming salary is already represented by its bank balance.
    received_income_v443:=lts_projection_private_v412.received_income_slot_v443(p_user_id,r,d,p_as_of);
    IF received_income_v443->>'status'='received_in_balance' THEN
     authoritative:=true;known:=(received_income_v443->>'amount_brl')::numeric;
     refs:=refs||received_income_v443->'source_refs';
    ELSIF received_income_v443->>'status'='receipt_requires_review' THEN
     known_complete:=false;
    END IF;
    slots:=slots||jsonb_build_array(jsonb_build_object('series_key',key,'event_date',d,
     'base_amount_brl',base_amount,'known_amount_brl',known,'known_complete',known_complete,
     'legacy_estimate_brl',coalesce((monthly_bucket->>'legacy_estimate_brl')::numeric,0),
     'authoritative',authoritative,'cancelled',cancelled,
     'replacement_amount_brl',replace_amount,'replacement_refs',replace_refs,
     'withholding_brl',withholding,'withholding_known',withholding_known,
     'source_refs',refs||coalesce(t->'source_refs','[]')));
   END LOOP;
  END LOOP;
 END LOOP;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(policy->'rules')scope_rule WHERE scope_rule->>'card_budget_mode'='scoped') THEN
  history:=lts_projection_private_v412.scope_history_read_v416(p_user_id,policy,history,p_as_of);
  subscription_cards_v468:=public.lts_card_cycles_v226(p_user_id);
  slots:=lts_projection_private_v412.scope_slots_v416(policy,slots,subscription_cards_v468);
 END IF;
 projection_result_v418:=lts_projection_private_v412.calculate(policy,history,slots,p_as_of);
 projection_result_v418:=lts_subscription_private_v468.append_result(p_user_id,p_as_of,projection_result_v418,subscription_cards_v468,baseline);
 projection_result_v418:=lts_recurring_private_v469.append_result(p_user_id,p_as_of,projection_result_v418,subscription_cards_v468,baseline);
 -- Capture only within the existing worker transaction. No second calculation
 -- or persistent write is introduced into this stable builder.
 worker_claim_v418:=nullif(current_setting('lts.product_refresh_claim',true),'')::jsonb;
 IF worker_claim_v418->>'user_id'=p_user_id::text AND p_as_of=current_date THEN
  PERFORM set_config('lts.projection_summary_v418',jsonb_build_object(
   'user_id',p_user_id,'as_of',p_as_of,
   'summary',projection_result_v418-'events'-'replacement_refs')::text,true);
 END IF;
 PERFORM set_config('lts.projection_memo_v437',jsonb_build_object(
  'user_id',p_user_id,'as_of',p_as_of,
  'inputs',jsonb_build_object('source_epoch',(SELECT epoch::text FROM public.lts_read_cache_epoch_v242 WHERE singleton=true),
   'card_source_key',lts_product_refresh_private_v415.card_source_key(p_user_id),'policy_fingerprint',md5(policy::text)),
  'key',memo_key_v437,'payload',projection_result_v418,
  'digest',encode(sha256(convert_to(projection_result_v418::text,'UTF8')),'hex'))::text,true);
 RETURN projection_result_v418;
END $function$
;
CREATE OR REPLACE FUNCTION public.lts_flow_classification_decision_v1(p_user_id uuid, p_event jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
SELECT coalesce(lts_recurring_private_v469.classification(p_user_id,p_event),coalesce((
 SELECT p_event||jsonb_build_object(
  'category',coalesce(CASE WHEN d.beneficiary IN('Benjamin','Larissa','Rafiki')
    AND d.category_label IS NOT NULL AND d.category_label !~* '^(Lucas|Benjamin|Larissa|Rafiki)[[:space:]]*[-—]'
   THEN d.beneficiary||' - '||d.category_label ELSE d.category_label END,p_event->>'category'),
  'center_cost',coalesce(d.beneficiary,p_event->>'center_cost'),
  'classification_confirmed',d.category_label IS NOT NULL)
 FROM public.lts_v178_review_decision d WHERE d.user_id=p_user_id
 AND d.source_table=CASE
  WHEN p_event->>'source'='open_finance' OR p_event->>'open_finance_id' IS NOT NULL THEN 'lts_open_finance_staging'
  WHEN p_event->>'source'='current_event' THEN 'daily_flow_documentary_bridge'
  WHEN p_event->>'source'='legacy_fix86' AND p_event->>'source_ref' ~ '^evento_base:[0-9]+$' THEN 'evento_base'
  ELSE p_event->>'source' END
 AND d.source_ref=CASE
  WHEN p_event->>'open_finance_id' IS NOT NULL THEN p_event->>'open_finance_id'
  WHEN p_event->>'source'='legacy_fix86' AND p_event->>'source_ref' ~ '^evento_base:[0-9]+$'
   THEN split_part(p_event->>'source_ref',':',2)
  ELSE p_event->>'source_ref' END
),p_event))
$function$
