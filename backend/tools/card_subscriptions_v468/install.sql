-- Owner-approved, item-specific card subscription forecasts.
-- No bank, invoice, purchase, payment, or financial-event row is written.
CREATE SCHEMA IF NOT EXISTS lts_subscription_private_v468;
REVOKE ALL ON SCHEMA lts_subscription_private_v468 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION lts_subscription_private_v468.validate_plan(p_plan jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path=''
AS $f$
DECLARE r jsonb; other jsonb; seen text[]:='{}'; k text;
BEGIN
 IF p_plan IS NULL THEN RETURN NULL;END IF;
 IF jsonb_typeof(p_plan) IS DISTINCT FROM 'object'
 OR p_plan->>'schema' IS DISTINCT FROM 'owner-card-subscriptions-v1'
 OR NOT coalesce(pg_catalog.pg_input_is_valid(p_plan->>'owner_id','uuid'),false)
 OR NOT coalesce(pg_catalog.pg_input_is_valid(p_plan->>'approved_on','date'),false)
 OR nullif(btrim(p_plan->>'owner_evidence_ref'),'') IS NULL
 OR jsonb_typeof(p_plan->'rules') IS DISTINCT FROM 'array'
 OR jsonb_array_length(p_plan->'rules') NOT BETWEEN 1 AND 50
 THEN RAISE EXCEPTION 'Confira as assinaturas consideradas no planejamento.';END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(p_plan->'rules') LOOP
  k:=r->>'id';
  IF jsonb_typeof(r) IS DISTINCT FROM 'object' OR coalesce(k,'')!~'^[a-z][a-z0-9_]{2,70}$' OR k=ANY(seen)
  OR nullif(btrim(r->>'description'),'') IS NULL
  OR coalesce(r->>'family','') NOT IN('c6','itau_mastercard','itau_visa','aeternum','bradesco_prime')
  OR r->>'account' IS DISTINCT FROM (CASE WHEN r->>'family'='c6' THEN 'C6'
    WHEN r->>'family' IN('itau_mastercard','itau_visa') THEN 'Itaú' ELSE 'Bradesco' END)
  OR coalesce(r->>'last4','')!~'^[0-9]{4}$'
  OR coalesce(r->>'amount_brl','')!~'^[0-9]+([.][0-9]{1,2})?$'
  OR (r->>'amount_brl')::numeric<=0 OR (r->>'amount_brl')::numeric>1000000
  OR coalesce(r->>'cadence_months','') NOT IN('1','12')
  OR coalesce(r->>'due_day','')!~'^[0-9]{1,2}$' OR (r->>'due_day')::int NOT BETWEEN 1 AND 31
  OR coalesce(r->>'anchor_cash_month','')!~'^[0-9]{4}-[0-9]{2}-01$'
  OR NOT coalesce(pg_catalog.pg_input_is_valid(r->>'anchor_cash_month','date'),false)
  OR (r->>'ends_on' IS NOT NULL AND NOT pg_catalog.pg_input_is_valid(r->>'ends_on','date'))
  OR coalesce(r->>'active','true') NOT IN('true','false')
  OR coalesce(r->>'amount_selector','') NOT IN('merchant','exact_amount')
  OR jsonb_typeof(r->'merchant_keys') IS DISTINCT FROM 'array'
  OR jsonb_array_length(r->'merchant_keys') NOT BETWEEN 1 AND 8
  OR nullif(btrim(r->>'evidence_ref'),'') IS NULL
  THEN RAISE EXCEPTION 'Há uma assinatura sem valor, vigência ou referência válida.';END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(r->'merchant_keys')x
   WHERE jsonb_typeof(x)<>'string' OR nullif(btrim(x#>>'{}'),'') IS NULL)
  THEN RAISE EXCEPTION 'Confira a identificação da assinatura.';END IF;
  IF r->>'ends_on' IS NOT NULL AND (r->>'ends_on')::date<(r->>'anchor_cash_month')::date
  THEN RAISE EXCEPTION 'Confira a vigência da assinatura.';END IF;
  FOR other IN SELECT value FROM jsonb_array_elements(p_plan->'rules') WHERE value->>'id'=ANY(seen) LOOP
   IF other->>'family'=r->>'family'
    AND coalesce(other->>'active','true')='true' AND coalesce(r->>'active','true')='true'
    AND EXISTS(SELECT 1 FROM jsonb_array_elements_text(other->'merchant_keys')a
     JOIN jsonb_array_elements_text(r->'merchant_keys')b ON a.value=b.value)
    AND (other->>'amount_selector'='merchant' OR r->>'amount_selector'='merchant'
     OR (other->>'amount_brl')::numeric=(r->>'amount_brl')::numeric)
   THEN RAISE EXCEPTION 'A mesma assinatura não pode ser prevista duas vezes.';END IF;
  END LOOP;
  seen:=array_append(seen,k);
 END LOOP;
 RETURN p_plan;
END $f$;

CREATE OR REPLACE FUNCTION lts_subscription_private_v468.owner_plan(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=''
AS $f$
DECLARE raw text; digest text; j jsonb;
BEGIN
 SELECT valor_bruto,sha256 INTO raw,digest FROM public.legacy_namespace
 WHERE usuario_id=p_user_id AND chave='lts_owner_card_subscriptions_v468';
 IF NOT FOUND THEN RETURN NULL;END IF;
 IF digest IS DISTINCT FROM encode(sha256(convert_to(raw,'UTF8')),'hex')
 THEN RAISE EXCEPTION 'Não foi possível conferir as assinaturas. Atualize a consulta.';END IF;
 j:=lts_subscription_private_v468.validate_plan(raw::jsonb);
 IF j->>'owner_id' IS DISTINCT FROM p_user_id::text
 THEN RAISE EXCEPTION 'Não foi possível conferir as assinaturas desta conta.';END IF;
 RETURN j;
END $f$;

CREATE OR REPLACE FUNCTION lts_subscription_private_v468.calculate(
 p_plan jsonb,p_calendar jsonb,p_as_of date,p_horizon date)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path=''
AS $f$
DECLARE plan jsonb:=lts_subscription_private_v468.validate_plan(p_plan);
 r jsonb; c jsonb; item jsonb; a record; raw_amount text; amount numeric; hits int; known numeric;
 bad bool; unexpected bool; month_start date; due date; anchor date; delta int;
 result_events jsonb:='[]'; result_series jsonb:='[]'; result_warnings jsonb:='[]';
 periods jsonb; annual jsonb; codes jsonb; seen_periods text[]; ident text;
 period_status text; expected numeric; extra numeric; periods_bad int; generated int; preserved int;
 wf date; wt date;
BEGIN
 IF plan IS NULL THEN RETURN jsonb_build_object('events',result_events,'series',result_series,'warnings',result_warnings);END IF;
 IF p_as_of IS NULL OR p_horizon IS NULL OR p_horizon<p_as_of
 OR p_horizon>(date_trunc('year',p_as_of)+interval '6 years'-interval '1 day')::date
 OR jsonb_typeof(p_calendar) IS DISTINCT FROM 'array'
 THEN RAISE EXCEPTION 'Confira o período das assinaturas.';END IF;
 wf:=(date_trunc('year',p_as_of)-interval '1 year')::date;
 wt:=date_trunc('year',p_as_of)::date-1;
 FOR r IN SELECT value FROM jsonb_array_elements(plan->'rules') WHERE coalesce(value->>'active','true')='true' ORDER BY value->>'id' LOOP
  anchor:=(r->>'anchor_cash_month')::date;expected:=(r->>'amount_brl')::numeric;
  periods:='[]';seen_periods:='{}';periods_bad:=0;generated:=0;preserved:=0;
  FOR c IN SELECT value FROM jsonb_array_elements(p_calendar)
   WHERE value->>'family'=r->>'family' ORDER BY value->>'cash_month' LOOP
   IF NOT coalesce(pg_catalog.pg_input_is_valid(c->>'cash_month','date'),false)
    OR NOT coalesce(pg_catalog.pg_input_is_valid(c->>'due_date','date'),false)
    OR jsonb_typeof(c->'items') IS DISTINCT FROM 'array'
    OR jsonb_typeof(c->'trusted') IS DISTINCT FROM 'boolean'
    OR jsonb_typeof(c->'authoritative') IS DISTINCT FROM 'boolean'
   THEN RAISE EXCEPTION 'Não foi possível conferir uma fatura das assinaturas.';END IF;
   month_start:=(c->>'cash_month')::date;due:=(c->>'due_date')::date;
   IF month_start<>date_trunc('month',month_start)::date OR date_trunc('month',due)::date<>month_start
   THEN RAISE EXCEPTION 'Confira a data da fatura da assinatura.';END IF;
   delta:=(extract(year FROM month_start)::int-extract(year FROM anchor)::int)*12
    +extract(month FROM month_start)::int-extract(month FROM anchor)::int;
   IF delta<0 OR delta%(r->>'cadence_months')::int<>0 OR due<=p_as_of OR due>p_horizon
    OR due<(plan->>'approved_on')::date OR (r->>'ends_on' IS NOT NULL AND due>(r->>'ends_on')::date) THEN CONTINUE;END IF;
   ident:=month_start::text;
   IF ident=ANY(seen_periods) THEN RAISE EXCEPTION 'Há duas faturas para a mesma assinatura e mês.';END IF;
   seen_periods:=array_append(seen_periods,ident);
   hits:=0;known:=0;bad:=NOT(c->>'trusted')::boolean;unexpected:=false;
   FOR item IN SELECT value FROM jsonb_array_elements(c->'items') LOOP
    IF coalesce(item->>'is_payment','false')='true' THEN CONTINUE;END IF;
    raw_amount:=item->>'amount';
    IF coalesce(raw_amount,'')!~'^-?[0-9]+([.][0-9]{1,2})?$'
    THEN bad:=true;CONTINUE;END IF;
    amount:=raw_amount::numeric;
    IF amount<=0 THEN CONTINUE;END IF;
    IF coalesce(item->>'merchant_key','') IN(SELECT jsonb_array_elements_text(r->'merchant_keys')) THEN
     -- An original charge plus its refund remains received, never refilled.
     IF r->>'amount_selector'='merchant' OR amount=expected THEN
      IF item->>'last4' IS DISTINCT FROM r->>'last4'
       OR nullif(item->>'source_id','') IS NULL
       OR coalesce(item->>'total_installments','1')!~'^[0-9]+$'
       OR coalesce((item->>'total_installments')::int,1)>1
      THEN bad:=true;ELSE hits:=hits+1;known:=known+amount;END IF;
     ELSIF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(plan->'rules')other
      WHERE coalesce(other->>'active','true')='true' AND other->>'family'=r->>'family'
       AND other->>'amount_selector'='exact_amount' AND (other->>'amount_brl')::numeric=amount
       AND item->>'merchant_key' IN(SELECT jsonb_array_elements_text(other->'merchant_keys'))) THEN
      -- Apple does not identify the service: an unrecognized price cannot safely
      -- be interpreted as either an extra service or a replacement for a plan.
      unexpected:=true;
     END IF;
    END IF;
   END LOOP;
   extra:=0;
   IF (c->>'authoritative')::boolean THEN
    period_status:='official_invoice_precedence';preserved:=preserved+1;
   ELSIF bad OR hits>1 OR unexpected THEN
    period_status:='requires_review';periods_bad:=periods_bad+1;
   ELSIF hits=1 THEN
    period_status:='already_in_known_invoice';preserved:=preserved+1;
   ELSE
    period_status:='specific_recurring_forecast';extra:=expected;generated:=generated+1;
    result_events:=result_events||jsonb_build_array(jsonb_build_object(
     'event_date',due,'account',r->>'account','description',r->>'description',
     'signed_amount',-extra,'source','planning_projection_v412',
     'source_ref','projection:v468:'||(r->>'id')||':'||due::text,
     'confidence','owner_confirmed_specific_subscription','account_assignment','owner_policy',
     'legacy_index',NULL,'original_date',due,'displaced',false,
     'series_key','subscription_'||(r->>'id'),'method','fixed',
     'budget_total_brl',expected,'known_amount_brl',0,
     'source_refs',jsonb_build_array(r->>'evidence_ref')));
   END IF;
   periods:=periods||jsonb_build_array(jsonb_build_object('event_date',due,'cash_month',month_start,
    'status',period_status,'amount_brl',CASE WHEN hits=1 THEN known ELSE expected END,
    'additional_brl',CASE WHEN period_status='requires_review' THEN NULL ELSE extra END));
  END LOOP;
  SELECT coalesce(jsonb_agg(jsonb_build_object('year',year_no,'partial_year',year_no=extract(year FROM p_as_of)::int,
   'budget_total_brl',CASE WHEN incomplete THEN NULL ELSE total END,
   'additional_brl',CASE WHEN incomplete THEN NULL ELSE additional END) ORDER BY year_no),'[]')
  INTO annual FROM(
   SELECT extract(year FROM(x->>'event_date')::date)::int year_no,
    bool_or(x->>'status'='requires_review') incomplete,
    sum((x->>'amount_brl')::numeric) total,sum((x->>'additional_brl')::numeric) additional
   FROM jsonb_array_elements(periods)x GROUP BY 1)a;
  codes:=CASE WHEN periods_bad>0 THEN '["unreconciled_periods"]'::jsonb ELSE '[]'::jsonb END;
  result_series:=result_series||jsonb_build_array(jsonb_build_object(
   'series_key','subscription_'||(r->>'id'),'description',r->>'description','direction','expense',
   'account',r->>'account','method','fixed','uses_history',false,'reference_amount_brl',expected,
   'reference_window',jsonb_build_object('from',wf,'to',wt),'reference_stale',false,
   'expected_months',12,'coverage_months',0,'observed_months',0,'months_with_spend',0,
   'outlier_months','[]'::jsonb,'annual_rate',0,'warnings',codes,
   'projected_occurrences',generated,'preserved_occurrences',preserved,'unresolved_periods',periods_bad,
   'annual_totals',annual,'due_day_basis','received_card_calendar_estimate',
   'cadence_months',(r->>'cadence_months')::int,'coverage',periods));
  IF periods_bad>0 THEN result_warnings:=result_warnings||jsonb_build_array(jsonb_build_object(
   'series_key','subscription_'||(r->>'id'),'description',r->>'description','codes',codes));END IF;
 END LOOP;
 RETURN jsonb_build_object('events',result_events,'series',result_series,'warnings',result_warnings);
END $f$;

CREATE OR REPLACE FUNCTION lts_subscription_private_v468.append_result(
 p_user_id uuid,p_as_of date,p_base jsonb,p_cards jsonb,p_baseline jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' SET TimeZone='America/Sao_Paulo'
AS $f$
DECLARE plan jsonb:=lts_subscription_private_v468.owner_plan(p_user_id);cards jsonb:=p_cards;
 calendar jsonb;added jsonb;horizon date;
BEGIN
 IF plan IS NULL THEN RETURN p_base;END IF;
 IF p_base->>'enabled' IS DISTINCT FROM 'true' OR p_base->>'as_of' IS DISTINCT FROM p_as_of::text
 THEN RAISE EXCEPTION 'Aguarde a atualização das projeções.';END IF;
 horizon:=(p_base->>'horizon_end')::date;
 IF cards IS NULL THEN cards:=public.lts_card_cycles_v226(p_user_id);END IF;
 IF jsonb_typeof(cards->'cards') IS DISTINCT FROM 'array' OR jsonb_typeof(p_baseline) IS DISTINCT FROM 'array'
 THEN RAISE EXCEPTION 'Não foi possível conferir as faturas das assinaturas.';END IF;
 WITH families AS(
  SELECT r->>'family' family,min(r->>'account') account,min((r->>'due_day')::int) due_day
  FROM jsonb_array_elements(plan->'rules')r WHERE coalesce(r->>'active','true')='true' GROUP BY 1
 ), months AS(
  SELECT d::date cash_month FROM generate_series(date_trunc('month',p_as_of),
   date_trunc('month',horizon),interval '1 month')d
 ), slots AS(
  SELECT f.*,m.cash_month,c.card,c.card_count,cy.cycle,cy.cycle_count,
   coalesce(known.amount,0) baseline_amount,
   coalesce((cy.cycle->>'due_date')::date,
    public.lts_card_projection_date_v370(p_user_id,f.family,m.cash_month,
     m.cash_month+least(f.due_day,extract(day FROM m.cash_month+interval '1 month-1 day')::int)-1,NULL)) proposed_due
  FROM families f CROSS JOIN months m
  CROSS JOIN LATERAL(SELECT min(x::text)::jsonb card,count(*) card_count
   FROM jsonb_array_elements(cards->'cards')x WHERE x->>'family'=f.family)c
  CROSS JOIN LATERAL(SELECT min(x::text)::jsonb cycle,count(*) cycle_count
   FROM jsonb_array_elements(coalesce(c.card->'cycles','[]'))x
   WHERE pg_catalog.pg_input_is_valid(x->>'due_date','date')
   AND date_trunc('month',(x->>'due_date')::date)::date=m.cash_month)cy
  CROSS JOIN LATERAL(SELECT sum(abs((b->>'signed_amount')::numeric)) amount
   FROM jsonb_array_elements(p_baseline)b
   WHERE (b->>'event_date')::date BETWEEN m.cash_month AND (m.cash_month+interval '1 month-1 day')::date
    AND (b->>'signed_amount')::numeric<0
    AND public.lts_card_family_v226(b->>'description',b->>'account')=f.family)known
 ), inputs AS(
  SELECT s.*,
   CASE WHEN s.cycle IS NULL AND s.family='c6' AND extract(isodow FROM proposed_due) IN(6,7)
    THEN proposed_due+(8-extract(isodow FROM proposed_due)::int) ELSE proposed_due END due_date,
   coalesce((SELECT sum((i->>'amount')::numeric)FROM jsonb_array_elements(coalesce(s.cycle->'items','[]'))i
    WHERE coalesce(i->>'is_payment','false')<>'true'),0) item_total,
   coalesce(s.cycle->>'official_invoice_received',CASE WHEN s.cycle->>'invoice_source_id' IS NOT NULL
     AND s.cycle->>'documentary_amount' IS NOT NULL THEN 'true' ELSE 'false' END)::boolean authoritative
  FROM slots s
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('family',s.family,'cash_month',s.cash_month,'due_date',s.due_date,
  'authoritative',s.authoritative,
  'trusted',s.card_count=1 AND s.cycle_count<=1 AND coalesce(s.card->>'complete','true')='true'
   AND (coalesce(cards->>'complete','false')='true' OR jsonb_array_length(coalesce(cards->'incomplete_families','[]'))>0)
   AND NOT(coalesce(cards->'incomplete_families','[]') ? s.family)
   AND (CASE WHEN s.cycle_count=0 THEN s.baseline_amount=0
     ELSE abs((s.cycle->>'amount')::numeric-s.baseline_amount)<=0.005
      AND (s.authoritative OR abs(s.item_total-(s.cycle->>'amount')::numeric)<=0.005) END),
  'items',(SELECT coalesce(jsonb_agg(i||jsonb_build_object(
    'merchant_key',public.lts_bank_merchant_key_v231(i->>'description'))),'[]')
    FROM jsonb_array_elements(coalesce(s.cycle->'items','[]'))i))ORDER BY s.family,s.cash_month),'[]')
 INTO calendar FROM inputs s;
 added:=lts_subscription_private_v468.calculate(plan,calendar,p_as_of,horizon);
 RETURN p_base||jsonb_build_object(
  'events',(p_base->'events')||(added->'events'),
  'series',(p_base->'series')||(added->'series'),
  'warnings',(p_base->'warnings')||(added->'warnings'));
END $f$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA lts_subscription_private_v468 FROM PUBLIC,anon,authenticated,service_role;


DO $guard$
BEGIN
 IF md5(pg_get_functiondef('lts_projection_private_v412.build(uuid,date)'::regprocedure)) <> 'b5c214f5a8e1f54c7a82038bedbc03a1' THEN
 RAISE EXCEPTION 'Projection builder changed; reconcile before applying V468';END IF;
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
