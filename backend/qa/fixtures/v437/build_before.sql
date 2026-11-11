-- Exact reviewed predecessor; financial sources are supplied by synthetic fixtures.
CREATE OR REPLACE FUNCTION lts_projection_private_v412.build(p_user_id uuid, p_as_of date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE projection_result_v418 jsonb; worker_claim_v418 jsonb; policy jsonb:=lts_projection_private_v412.owner_policy(p_user_id); horizon date;
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
  slots:=lts_projection_private_v412.scope_slots_v416(policy,slots,public.lts_card_cycles_v226(p_user_id));
 END IF;
 projection_result_v418:=lts_projection_private_v412.calculate(policy,history,slots,p_as_of);
 -- Capture only within the existing worker transaction. No second calculation
 -- or persistent write is introduced into this stable builder.
 worker_claim_v418:=nullif(current_setting('lts.product_refresh_claim',true),'')::jsonb;
 IF worker_claim_v418->>'user_id'=p_user_id::text AND p_as_of=current_date THEN
  PERFORM set_config('lts.projection_summary_v418',jsonb_build_object(
   'user_id',p_user_id,'as_of',p_as_of,
   'summary',projection_result_v418-'events'-'replacement_refs')::text,true);
 END IF;
 RETURN projection_result_v418;
END $function$;
