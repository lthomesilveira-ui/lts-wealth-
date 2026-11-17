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

