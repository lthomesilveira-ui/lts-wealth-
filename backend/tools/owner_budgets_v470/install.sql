DO $guard$ BEGIN IF md5(pg_get_functiondef('lts_recurring_private_v469.append_result(uuid,date,jsonb,jsonb,jsonb)'::regprocedure))<>'7f88eee1e992dbfb990aee805ac91c8e' OR md5(pg_get_functiondef('lts_recurring_private_v469.classification(uuid,jsonb)'::regprocedure))<>'98a5ea34bfb247d2146a40c1e493050b' THEN RAISE EXCEPTION 'Recurring implementation changed';END IF;END $guard$;
-- Private owner-selected targets. No source financial records are changed.
CREATE SCHEMA IF NOT EXISTS lts_budget_private_v470;
REVOKE ALL ON SCHEMA lts_budget_private_v470 FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION lts_budget_private_v470.owner_plan(u uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' AS $f$
DECLARE raw text;h text;p jsonb;
BEGIN
 SELECT valor_bruto,sha256 INTO raw,h FROM public.legacy_namespace WHERE usuario_id=u AND chave='lts_owner_budgets_v470';
 IF NOT FOUND THEN RETURN NULL;END IF;
 p:=raw::jsonb;
 IF h IS DISTINCT FROM encode(sha256(convert_to(raw,'UTF8')),'hex') OR p->>'owner_id' IS DISTINCT FROM u::text
 OR p->>'schema' IS DISTINCT FROM 'owner-budgets-v470' OR jsonb_typeof(p->'budgets') IS DISTINCT FROM 'array'
 THEN RAISE EXCEPTION 'Confira as despesas previstas.';END IF;
 RETURN p;
END $f$;
CREATE OR REPLACE FUNCTION lts_budget_private_v470.matches(r jsonb,e jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT coalesce(EXISTS(SELECT 1 FROM jsonb_array_elements_text(coalesce(r->'categories','[]'))c WHERE public.lts_v178_norm(c)=public.lts_v178_norm(e->>'category'))
 OR (nullif(r->>'merchant_pattern','') IS NOT NULL AND coalesce(e->>'description','')~*(r->>'merchant_pattern'))
 OR coalesce(r->'source_refs','[]') ? coalesce(e->>'source_ref',''),false);
$f$;
CREATE OR REPLACE FUNCTION lts_budget_private_v470.calculate(p jsonb,base jsonb,calendar jsonb,asof date)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE ev jsonb:=base->'events';rr jsonb:=base->'replacement_refs';series jsonb:=base->'series';warnings jsonb:=base->'warnings';
 r jsonb;c jsonb;s jsonb;m date;d date;h date:=(base->>'horizon_end')::date;target numeric;known numeric;extra numeric;periods jsonb;annual jsonb;bad int;n int;
BEGIN
 IF p IS NULL THEN RETURN base;END IF;
 IF p->>'schema' IS DISTINCT FROM 'owner-budgets-v470' OR base->>'as_of' IS DISTINCT FROM asof::text
 OR jsonb_typeof(calendar) IS DISTINCT FROM 'array' OR jsonb_array_length(p->'budgets')<1
 OR (SELECT count(DISTINCT x->>'id')FROM jsonb_array_elements(p->'budgets')x)<>jsonb_array_length(p->'budgets')
 THEN RAISE EXCEPTION 'Confira o orçamento das despesas.';END IF;
 FOR s IN SELECT value FROM jsonb_array_elements(coalesce(p->'suppressions','[]')) LOOP
  IF (s->>'event_date')::date>asof THEN rr:=rr||jsonb_build_array(s->>'source_ref');END IF;
 END LOOP;
 FOR r IN SELECT value FROM jsonb_array_elements(p->'budgets') ORDER BY value->>'id' LOOP
  target:=(r->>'amount_brl')::numeric;periods:='[]';bad:=0;
  IF r->>'id' !~ '^owner_[a-z_]+$' OR target IS NULL OR target<=0 OR target>100000 OR nullif(r->>'category','') IS NULL
  OR nullif(r->>'description','') IS NULL THEN RAISE EXCEPTION 'Confira o valor da despesa.';END IF;
  FOR m IN SELECT d0::date FROM generate_series((p->>'starts_on')::date,date_trunc('month',h),interval '1 month')d0 LOOP
   d:=m+2;IF d<=asof OR d>h THEN CONTINUE;END IF;
   SELECT count(*)INTO n FROM jsonb_array_elements(calendar)x WHERE x->>'id'=r->>'id' AND x->>'cash_month'=m::text;
   IF n<>1 THEN RAISE EXCEPTION 'Confira os compromissos do mês.';END IF;
   SELECT value INTO c FROM jsonb_array_elements(calendar)x WHERE x->>'id'=r->>'id' AND x->>'cash_month'=m::text;
   IF c->>'trusted' IS DISTINCT FROM 'true' THEN known:=NULL;extra:=NULL;bad:=bad+1;
   ELSE
    known:=greatest((c->>'known_brl')::numeric,0);extra:=greatest(target-known,0);
    IF extra>0 THEN ev:=ev||jsonb_build_array(lts_recurring_private_v469.forecast(r->>'id',r->>'description','Bradesco',extra,d));END IF;
   END IF;
   periods:=periods||jsonb_build_array(jsonb_build_object('event_date',d,'budget_total_brl',target,'known_brl',known,'additional_brl',extra,'trusted',c->'trusted'));
  END LOOP;
  SELECT coalesce(jsonb_agg(jsonb_build_object('year',y,'partial_year',y=extract(year FROM asof)::int,'budget_total_brl',CASE WHEN ok THEN total ELSE NULL END,'additional_brl',CASE WHEN ok THEN more ELSE NULL END)ORDER BY y),'[]') INTO annual
  FROM(SELECT extract(year FROM(x->>'event_date')::date)::int y,bool_and((x->>'trusted')::boolean)ok,
   sum(greatest((x->>'budget_total_brl')::numeric,(x->>'known_brl')::numeric))total,sum((x->>'additional_brl')::numeric)more FROM jsonb_array_elements(periods)x GROUP BY 1)a;
  series:=series||jsonb_build_array(jsonb_build_object('series_key',r->>'id','description',r->>'description','account','Bradesco','direction','expense','method','fixed',
   'reference_amount_brl',target,'reference_window',r->'reference_window','uses_history',coalesce((r->>'uses_history')::boolean,false),'reference_stale',false,
   'expected_months',12,'coverage_months',r->'coverage_months','coverage',periods,'annual_totals',annual,'warnings',CASE WHEN bad>0 THEN '["unreconciled_periods"]'::jsonb ELSE '[]'::jsonb END));
  IF bad>0 THEN warnings:=warnings||jsonb_build_array(jsonb_build_object('series_key',r->>'id','codes',jsonb_build_array('unreconciled_periods')));END IF;
 END LOOP;
 RETURN base||jsonb_build_object('events',ev,'replacement_refs',rr,'series',series,'warnings',warnings);
END $f$;
CREATE OR REPLACE FUNCTION lts_budget_private_v470.append_result(u uuid,asof date,base jsonb,cards jsonb,baseline jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' AS $f$
DECLARE p jsonb:=lts_budget_private_v470.owner_plan(u);calendar jsonb;s jsonb;
BEGIN
 IF p IS NULL THEN RETURN base;END IF;
 FOR s IN SELECT value FROM jsonb_array_elements(coalesce(p->'suppressions','[]')) WHERE (value->>'event_date')::date>asof LOOP
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(baseline)b WHERE b->>'source_ref'=s->>'source_ref' AND b->>'event_date'=s->>'event_date'
   AND b->>'description'=s->>'description' AND b->>'account'=s->>'account' AND b->>'signed_amount'=s->>'signed_amount')
  THEN RAISE EXCEPTION 'Uma despesa prevista mudou. Confira o lançamento.';END IF;
 END LOOP;
 WITH items AS MATERIALIZED(
  SELECT cy->>'due_date' due_date,ca->>'family'family,cy->>'amount'cycle_amount,i,
   (SELECT sum(abs((b->>'signed_amount')::numeric))FROM jsonb_array_elements(baseline)b WHERE (b->>'signed_amount')::numeric<0
    AND public.lts_card_family_v226(b->>'description',b->>'account')=ca->>'family' AND date_trunc('month',(b->>'event_date')::date)=date_trunc('month',(cy->>'due_date')::date)) base_amount
  FROM jsonb_array_elements(cards->'cards')ca CROSS JOIN LATERAL jsonb_array_elements(ca->'cycles')cy CROSS JOIN LATERAL jsonb_array_elements(cy->'items')i
  WHERE (cy->>'due_date')::date>asof AND coalesce(i->>'is_payment','false')<>'true' AND (i->>'amount')::numeric>0
 ), direct AS MATERIALIZED(
  SELECT b FROM jsonb_array_elements(baseline)b WHERE (b->>'signed_amount')::numeric<0 AND (b->>'event_date')::date>asof
   AND NOT coalesce(base->'replacement_refs','[]') ? (b->>'source_ref')
  UNION ALL SELECT e FROM jsonb_array_elements(base->'events')e WHERE (e->>'signed_amount')::numeric<0
 ), matched AS MATERIALIZED(
  SELECT r->>'id'id,date_trunc('month',(t.due_date)::date)::date cash_month,(t.i->>'amount')::numeric known,
   t.base_amount IS NOT NULL AND abs(t.base_amount-t.cycle_amount::numeric)<=0.005 AND nullif(t.i->>'source_id','')IS NOT NULL trusted
  FROM jsonb_array_elements(p->'budgets')r JOIN items t ON lts_budget_private_v470.matches(r,t.i)
  UNION ALL
  SELECT r->>'id',date_trunc('month',(b->>'event_date')::date)::date,-(b->>'signed_amount')::numeric,true
  FROM jsonb_array_elements(p->'budgets')r JOIN direct ON
   (public.lts_card_family_v226(b->>'description',b->>'account')IS NULL AND lts_budget_private_v470.matches(r,public.lts_flow_classification_decision_v1(u,b)))
   OR coalesce(r->'source_refs','[]') ? (b->>'source_ref')
 ), slots AS(
  SELECT r->>'id'id,d::date cash_month FROM jsonb_array_elements(p->'budgets')r CROSS JOIN generate_series((p->>'starts_on')::date,date_trunc('month',(base->>'horizon_end')::date),interval '1 month')d
 )SELECT jsonb_agg(jsonb_build_object('id',slots.id,'cash_month',slots.cash_month,'known_brl',coalesce((SELECT sum(known)FROM matched t WHERE t.id=slots.id AND t.cash_month=slots.cash_month),0),
  'trusted',coalesce(cards->>'complete','false')='true' AND NOT EXISTS(SELECT 1 FROM matched t WHERE t.id=slots.id AND t.cash_month=slots.cash_month AND NOT t.trusted)))INTO calendar FROM slots;
 RETURN lts_budget_private_v470.calculate(p,base,calendar,asof);
END $f$;
CREATE OR REPLACE FUNCTION lts_budget_private_v470.classification(u uuid,e jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' AS $f$
DECLARE p jsonb:=lts_budget_private_v470.owner_plan(u);r jsonb;
BEGIN
 IF p IS NULL OR e->>'source' IS DISTINCT FROM 'planning_projection_v412' OR e->>'source_ref' NOT LIKE 'projection:v469:owner_%' THEN RETURN NULL;END IF;
 SELECT value INTO r FROM jsonb_array_elements(p->'budgets') WHERE value->>'id'=split_part(e->>'source_ref',':',3);
 IF r IS NULL THEN RETURN NULL;END IF;
 RETURN e||jsonb_build_object('category',r->>'category','center_cost',r->>'beneficiary','classification_confirmed',true);
END $f$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA lts_budget_private_v470 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION lts_recurring_private_v469.append_result(u uuid, asof date, base jsonb, cards jsonb, baseline jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE plan jsonb:=lts_recurring_private_v469.owner_plan(u); calendar jsonb;paid jsonb;school_source jsonb;horizon date:=(base->>'horizon_end')::date;
BEGIN
 IF plan IS NULL THEN RETURN base;END IF;
 IF cards IS NULL THEN cards:=public.lts_card_cycles_v226(u);END IF;
 -- Reject a changed future school source instead of overwriting a user edit.
 FOR school_source IN SELECT value FROM jsonb_array_elements(plan->'school_sources') WHERE (value->>'event_date')::date>asof LOOP
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(baseline)b WHERE b->>'source_ref'=school_source->>'source_ref'
   AND b->>'event_date'=school_source->>'event_date' AND b->>'account'=plan->>'school_account'
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
 RETURN lts_budget_private_v470.append_result(u,asof,lts_recurring_private_v469.calculate(plan,base,calendar,paid,asof),cards,baseline);
END $function$
;
CREATE OR REPLACE FUNCTION lts_recurring_private_v469.classification(u uuid, e jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
DECLARE plan jsonb;id text;cat text;
BEGIN
 IF e->>'source' IS DISTINCT FROM 'planning_projection_v412' OR e->>'source_ref' NOT LIKE 'projection:v469:%' THEN RETURN NULL;END IF;
 plan:=lts_recurring_private_v469.owner_plan(u);IF plan IS NULL THEN RETURN NULL;END IF;
 id:=split_part(e->>'source_ref',':',3);
 cat:=CASE WHEN id IN('school_food','school_tuition') THEN plan->>'school_category'
  WHEN id='pharmacy' THEN 'Farmácia' WHEN id='hair' THEN 'Cabelereiro' WHEN id='membership' THEN 'Sócio Rei'
  WHEN id='prime_2990' THEN 'Assinaturas' WHEN id LIKE 'sub_apple_%' THEN 'Apple'
  WHEN id='sub_google_ai_plus' THEN 'Armazenamento' WHEN id='sub_spotify' THEN 'Spotify' WHEN id='sub_amazon_prime' THEN 'Amazon' END;
 IF cat IS NULL THEN RETURN lts_budget_private_v470.classification(u,e);END IF;
 RETURN e||jsonb_build_object('category',cat,'classification_confirmed',true,'center_cost',CASE WHEN id IN('school_food','school_tuition') THEN plan->>'school_beneficiary' ELSE NULL END);
END $function$
;
