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
