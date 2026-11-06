-- Preserve the installed optimized readers and existing privileges.
DO $guard$
BEGIN
 IF md5(pg_get_functiondef(to_regprocedure('lts_projection_private_v412.build(uuid,date)'))) IS DISTINCT FROM '9722ace9c25710cdf3b1f41499cea031' THEN
  RAISE EXCEPTION 'Unexpected definition for build; review the installed baseline.';
 END IF;
 IF md5(pg_get_functiondef(to_regprocedure('lts_projection_private_v412.calculate(jsonb,jsonb,jsonb,date)'))) IS DISTINCT FROM '007b0ba1030dd8d669a80c13764a27a4' THEN
  RAISE EXCEPTION 'Unexpected definition for calculate; review the installed baseline.';
 END IF;
 IF md5(pg_get_functiondef(to_regprocedure('lts_projection_private_v412.refresh_reference(uuid,date)'))) IS DISTINCT FROM '2c2450b61583c11df96709bc3e782975' THEN
  RAISE EXCEPTION 'Unexpected definition for refresh_reference; review the installed baseline.';
 END IF;
END $guard$;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.build(p_user_id uuid, p_as_of date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE policy jsonb:=lts_projection_private_v412.owner_policy(p_user_id); horizon date;
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
     'authoritative',authoritative,'cancelled',cancelled,
     'replacement_amount_brl',replace_amount,'replacement_refs',replace_refs,
     'withholding_brl',withholding,'withholding_known',withholding_known,
     'source_refs',refs||coalesce(t->'source_refs','[]')));
   END LOOP;
  END LOOP;
 END LOOP;
 RETURN lts_projection_private_v412.calculate(policy,history,slots,p_as_of);
END $function$;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.calculate(p_policy jsonb, p_history jsonb, p_slots jsonb, p_as_of date)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE r jsonb; s jsonb; f jsonb; stats jsonb; series jsonb:='[]'; events jsonb:='[]'; replacements jsonb:='[]';
 warnings jsonb:='[]'; slot_warnings jsonb; key text; method text; horizon date; wf date; wt date; nr date;
 count_months integer; spend_months integer; partial_months integer; source_count integer; amount_sum numeric;
 mean_amount numeric; q1 numeric; q3 numeric; outliers jsonb; amount numeric; known numeric; replacement_amount numeric;
 target numeric; extra numeric; effective_date date; protected boolean; cancelled boolean; complete boolean;
 skipped integer; generated integer; invalid_slots integer; annual jsonb; slot_result jsonb; results jsonb:='[]';
 series_from date; series_to date; expected_months integer; history_basis text;
 reference jsonb; reference_from date;reference_to date;reference_stale boolean;uses_history boolean;
BEGIN
 IF p_policy IS NULL THEN RETURN jsonb_build_object('version','projection-policy-v412','enabled',false); END IF;
 IF p_as_of IS NULL OR NOT pg_catalog.isfinite(p_as_of) OR p_as_of<(p_policy->>'approved_on')::date
  OR jsonb_typeof(p_history) IS DISTINCT FROM 'array' OR jsonb_typeof(p_slots) IS DISTINCT FROM 'array'
  THEN RAISE EXCEPTION 'Escopo de projeção inválido.'; END IF;
 horizon:=lts_projection_private_v412.horizon_end(p_as_of);
 SELECT * INTO wf,wt,nr FROM lts_projection_private_v412.review_window(p_policy,p_as_of);
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_history)x
  WHERE coalesce(x->>'coverage','') NOT IN('complete','observed','documented_zero')
   OR coalesce(x->>'month','')!~'^[0-9]{4}-[0-9]{2}-01$'
   OR NOT coalesce(pg_catalog.pg_input_is_valid(x->>'month','date'),false)
   OR coalesce(x->>'amount_brl','') !~ '^[0-9]+([.][0-9]+)?$'
   OR (x->>'coverage'='documented_zero' AND (x->>'amount_brl')::numeric<>0))
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_history)x
   GROUP BY x->>'series_key',x->>'month' HAVING count(*)>1)
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_slots)x
   GROUP BY x->>'series_key',x->>'event_date' HAVING count(*)>1)
 THEN RAISE EXCEPTION 'A base mensal contém valores inválidos ou competências repetidas.'; END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(p_policy->'rules')
  WHERE coalesce(value->>'active','true')='true' ORDER BY value->>'series_key' LOOP
  key:=r->>'series_key';method:=r->>'method';results:='[]';generated:=0;skipped:=0;invalid_slots:=0;
  uses_history:=method='history_total_budget' OR(method='inflated_calendar' AND r->>'template_source'='history_mean');
  expected_months:=12;series_from:=wf;series_to:=wt;
  history_basis:='owner_authorized_12m_history';
  IF method='history_total_budget' AND r->>'source_kind'='card_invoice' THEN
   expected_months:=3;
   series_from:=(date_trunc('month',p_as_of::timestamp)-interval '3 months')::date;
   series_to:=date_trunc('month',p_as_of::timestamp)::date-1;
   history_basis:='owner_authorized_3m_history';
  END IF;
  SELECT count(*)::int,count(*)FILTER(WHERE (x->>'amount_brl')::numeric>0)::int,
   count(*)FILTER(WHERE x->>'coverage'='observed')::int,
   coalesce(sum((x->>'amount_brl')::numeric),0),
   round(avg((x->>'amount_brl')::numeric),2),
   percentile_disc(.25)WITHIN GROUP(ORDER BY (x->>'amount_brl')::numeric),
   percentile_disc(.75)WITHIN GROUP(ORDER BY (x->>'amount_brl')::numeric),
   coalesce(sum(jsonb_array_length(coalesce(x->'source_refs','[]'))),0)::int
  INTO count_months,spend_months,partial_months,amount_sum,mean_amount,q1,q3,source_count
  FROM jsonb_array_elements(p_history)x WHERE x->>'series_key'=key
   AND (x->>'month')::date BETWEEN series_from AND series_to;
  SELECT coalesce(jsonb_agg(x->>'month' ORDER BY x->>'month'),'[]') INTO outliers
  FROM jsonb_array_elements(p_history)x WHERE x->>'series_key'=key
   AND (x->>'month')::date BETWEEN series_from AND series_to
   AND ((x->>'amount_brl')::numeric>q3+1.5*(q3-q1)
     OR (x->>'amount_brl')::numeric<greatest(0,q1-1.5*(q3-q1)));
  slot_warnings:='[]';
  reference_from:=series_from;reference_to:=series_to;reference_stale:=false;
  IF uses_history AND count_months=0 THEN
   slot_warnings:=slot_warnings||jsonb_build_array('history_unavailable');
  ELSIF uses_history AND (count_months<expected_months OR partial_months>0) THEN
   slot_warnings:=slot_warnings||jsonb_build_array('partial_history');
  END IF;
  IF uses_history AND jsonb_array_length(outliers)>0 THEN
   slot_warnings:=slot_warnings||jsonb_build_array('outliers_included'); END IF;
  IF uses_history AND (count_months<>expected_months OR partial_months>0) THEN
   -- Keep only a compatible complete reference when current coverage is incomplete.
   mean_amount:=NULL;
   SELECT v INTO reference FROM jsonb_array_elements(coalesce(p_policy#>'{_history_reference,series}','[]'))v
    WHERE v->>'series_key'=key
     AND (expected_months=12 OR (v->>'coverage_months'='3'
      AND CASE WHEN pg_catalog.pg_input_is_valid(v->>'window_to','date')
       THEN (v->>'window_to')::date<=series_to ELSE true END));
   IF reference IS NOT NULL THEN
    IF reference->>'coverage_months' IS DISTINCT FROM expected_months::text
     OR coalesce(reference->>'sum_brl','')!~'^[0-9]+([.][0-9]+)?$'
     OR coalesce(reference->>'mean_brl','')!~'^[0-9]+([.][0-9]{1,2})?$'
     OR NOT coalesce(pg_catalog.pg_input_is_valid(reference->>'window_from','date'),false)
     OR NOT coalesce(pg_catalog.pg_input_is_valid(reference->>'window_to','date'),false)
     OR coalesce(jsonb_array_length(reference->'source_refs'),0)=0
     OR round((reference->>'sum_brl')::numeric/expected_months,2)<>(reference->>'mean_brl')::numeric
     THEN RAISE EXCEPTION 'A última base de projeção precisa ser conferida.'; END IF;
    reference_from:=(reference->>'window_from')::date;reference_to:=(reference->>'window_to')::date;
    IF reference_to>series_to OR reference_from<>date_trunc('month',reference_from)::date
     OR reference_to<>(reference_from+make_interval(months=>expected_months)-interval '1 day')::date
     THEN RAISE EXCEPTION 'A janela da última base de projeção é inválida.'; END IF;
    mean_amount:=(reference->>'mean_brl')::numeric;reference_stale:=true;
    slot_warnings:=slot_warnings||jsonb_build_array('previous_complete_window');
   END IF;
  END IF;
  FOR s IN SELECT value FROM jsonb_array_elements(p_slots)
   WHERE value->>'series_key'=key ORDER BY value->>'event_date' LOOP
   IF NOT coalesce(pg_catalog.pg_input_is_valid(s->>'event_date','date'),false)
    THEN RAISE EXCEPTION 'Há uma data inválida no calendário de projeção.'; END IF;
   effective_date:=(s->>'event_date')::date;
   IF effective_date<=p_as_of OR effective_date>horizon OR effective_date<(r->>'starts_on')::date
    OR (r->>'ends_on' IS NOT NULL AND effective_date>(r->>'ends_on')::date)
    THEN CONTINUE; END IF;
   cancelled:=coalesce((s->>'cancelled')::boolean,false);
   protected:=coalesce((s->>'authoritative')::boolean,false);
   complete:=coalesce((s->>'known_complete')::boolean,true);
   known:=nullif(s->>'known_amount_brl','')::numeric;
   replacement_amount:=coalesce((s->>'replacement_amount_brl')::numeric,0);
   IF known IS NULL OR known<0 OR replacement_amount<0 OR replacement_amount>known
    THEN complete:=false; END IF;
   IF replacement_amount>0 AND coalesce(jsonb_array_length(s->'replacement_refs'),0)=0
    THEN RAISE EXCEPTION 'Falta a identidade da estimativa que será substituída.'; END IF;
   IF cancelled OR protected THEN
    skipped:=skipped+1;
    results:=results||jsonb_build_array(jsonb_build_object('event_date',effective_date,
     'budget_total_brl',known,'additional_brl',0,'basis',CASE WHEN cancelled THEN 'owner_cancelled' ELSE 'documentary_precedence' END));
    CONTINUE;
   END IF;
   IF NOT complete THEN invalid_slots:=invalid_slots+1;CONTINUE;END IF;
   target:=NULL;
   CASE method
    WHEN 'history_total_budget' THEN target:=mean_amount;
    WHEN 'fixed' THEN target:=lts_projection_private_v412.fixed_amount(r,effective_date);
    WHEN 'salary_net' THEN
     IF coalesce((s->>'withholding_known')::boolean,false) AND nullif(s->>'withholding_brl','') IS NOT NULL
      AND (s->>'withholding_brl')::numeric>=0
      THEN target:=(r->>'amount_brl')::numeric-(s->>'withholding_brl')::numeric;
     ELSE invalid_slots:=invalid_slots+1;CONTINUE;END IF;
    WHEN 'inflated_calendar' THEN
     target:=round(CASE WHEN uses_history THEN mean_amount ELSE(s->>'base_amount_brl')::numeric END
       *power(1+(r->>'annual_rate')::numeric,
       greatest(0,extract(year FROM effective_date)::int-CASE WHEN uses_history
        THEN extract(year FROM reference_to)::int ELSE(r->>'base_year')::int END)),2);
    WHEN 'repeat_calendar' THEN target:=(s->>'base_amount_brl')::numeric;
   END CASE;
   IF target IS NULL THEN CONTINUE;END IF;
   IF target<0 OR target>100000000 OR target<>round(target,2)
    THEN RAISE EXCEPTION 'Valor de projeção fora dos limites.';END IF;
   IF method='history_total_budget' THEN
    -- A total budget floor. It is deliberately not "new spending plus installments".
    extra:=greatest(0,target-known);amount:=greatest(target,known);
   ELSIF method='inflated_calendar' THEN
    -- Replace only identified, non-documentary future estimates at this exact slot.
    IF known>replacement_amount THEN
     skipped:=skipped+1;
     results:=results||jsonb_build_array(jsonb_build_object('event_date',effective_date,
      'budget_total_brl',known,'additional_brl',0,'basis','existing_occurrence'));
     CONTINUE;
    END IF;
    extra:=target;amount:=target;
   ELSE
    IF known>0 THEN
     skipped:=skipped+1;
     results:=results||jsonb_build_array(jsonb_build_object('event_date',effective_date,
      'budget_total_brl',known,'additional_brl',0,'basis','existing_occurrence'));
     CONTINUE;
    END IF;
    extra:=target;amount:=target;
   END IF;
   slot_result:=jsonb_build_object('event_date',effective_date,'budget_total_brl',amount,
    'additional_brl',extra,'known_amount_brl',known,'basis',
    CASE WHEN method='history_total_budget' THEN history_basis ELSE method END);
   results:=results||jsonb_build_array(slot_result);
   IF extra>0 THEN
    IF method='inflated_calendar' THEN
     replacements:=replacements||coalesce(s->'replacement_refs','[]'); END IF;
    events:=events||jsonb_build_array(jsonb_build_object('event_date',effective_date,
     'account',r->>'account','description',r->>'description',
     'signed_amount',CASE WHEN r->>'direction'='income' THEN extra ELSE -extra END,
     'source','planning_projection_v412','source_ref','projection:v412:'||key||':'||effective_date,
     'confidence',CASE WHEN method='history_total_budget' THEN history_basis ELSE 'owner_authorized_planning_rule' END,
     'account_assignment','owner_policy','legacy_index',NULL,'original_date',effective_date,'displaced',false,
     'series_key',key,'method',method,'budget_total_brl',amount,'known_amount_brl',known,
     'source_refs',coalesce(s->'source_refs','[]')||CASE WHEN method='fixed' THEN coalesce((
      SELECT jsonb_build_array(c->>'source_ref') FROM jsonb_array_elements(coalesce(r->'amount_changes','[]'))c
      WHERE (c->>'effective_on')::date<=effective_date ORDER BY (c->>'effective_on')::date DESC LIMIT 1),'[]')
      ELSE '[]'::jsonb END));
    generated:=generated+1;
   END IF;
  END LOOP;
  IF invalid_slots>0 THEN slot_warnings:=slot_warnings||jsonb_build_array('unreconciled_periods'); END IF;
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_slots)x WHERE x->>'series_key'=key)
   THEN slot_warnings:=slot_warnings||jsonb_build_array('calendar_unavailable'); END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(a)ORDER BY year),'[]') INTO annual FROM(
   SELECT extract(year FROM(x->>'event_date')::date)::int AS year,
    round(sum((x->>'budget_total_brl')::numeric),2) budget_total_brl,
    round(sum((x->>'additional_brl')::numeric),2) additional_brl,
    extract(year FROM(x->>'event_date')::date)::int=extract(year FROM p_as_of)::int partial_year
   FROM jsonb_array_elements(results)x GROUP BY 1,4)a;
  series:=series||jsonb_build_array(jsonb_build_object('series_key',key,'description',r->>'description',
   'direction',r->>'direction','account',r->>'account','method',method,
   'reference_amount_brl',CASE WHEN uses_history THEN mean_amount WHEN method='fixed' THEN lts_projection_private_v412.fixed_amount(r,p_as_of) ELSE nullif(r->>'amount_brl','')::numeric END,
   'history_total_brl',CASE WHEN uses_history THEN amount_sum END,'uses_history',uses_history,
   'template_source',r->>'template_source','template_year',r->'template_year',
   'reference_window',jsonb_build_object('from',reference_from,'to',reference_to),
   'reference_stale',reference_stale,
   'coverage_months',count_months-partial_months,'observed_months',count_months,
   'months_with_spend',spend_months,'partial_months',partial_months,
   'expected_months',expected_months,'source_count',source_count,'outlier_months',outliers,
   'annual_rate',coalesce((r->>'annual_rate')::numeric,0),'warnings',slot_warnings,
   'projected_occurrences',generated,'preserved_occurrences',skipped,'unresolved_periods',invalid_slots,
   'annual_totals',annual,'due_day_basis',r->>'due_day_basis'));
  IF jsonb_array_length(slot_warnings)>0 THEN
   warnings:=warnings||jsonb_build_array(jsonb_build_object('series_key',key,'description',r->>'description','codes',slot_warnings));
  END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements_text(replacements)x GROUP BY x HAVING count(*)>1)
  THEN RAISE EXCEPTION 'Uma previsão antiga não pode ser substituída duas vezes.'; END IF;
 RETURN jsonb_build_object('version','projection-policy-v412','schema_version',1,'enabled',true,
  'as_of',p_as_of,'horizon_end',horizon,'next_review_on',nr,
  'history_window',jsonb_build_object('from',wf,'to',wt),
  'series',series,'warnings',warnings,'events',events,'replacement_refs',replacements,
  'card_method','total_budget_floor','outliers_excluded',false,'missing_months_assumed_zero',false,
  'financial_sources_modified',false,'current_year_partial',extract(doy FROM p_as_of)>1);
END $function$;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.refresh_reference(p_user_id uuid, p_as_of date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE policy jsonb:=lts_projection_private_v412.owner_policy(p_user_id);old_state jsonb;
 result jsonb;previous_series jsonb;next_series jsonb;facts jsonb;r jsonb;candidate jsonb;key text;
 series_from date;series_to date;expected_months int;
 wf date;wt date;nr date;n int;partial_count int;total numeric;mean numeric;refs jsonb;hashes jsonb;
 raw text;digest text;changed int:=0;deferred int:=0;
BEGIN
 IF policy IS NULL THEN RETURN jsonb_build_object('changed',false,'updated_series',0); END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_user_id::text,166));
 old_state:=lts_projection_private_v412.reference_state(p_user_id);
 previous_series:=coalesce(old_state->'series','[]');next_series:=previous_series;
 SELECT * INTO wf,wt,nr FROM lts_projection_private_v412.review_window(policy,p_as_of);
 SELECT coalesce(jsonb_agg(to_jsonb(f)ORDER BY series_key,month),'[]') INTO facts
 FROM lts_projection_private_v412.monthly_source_facts_v412(p_user_id,
  least(wf,(date_trunc('month',p_as_of::timestamp)-interval '3 months')::date),
  greatest(wt,date_trunc('month',p_as_of::timestamp)::date-1),policy)f;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(facts)x
   WHERE coalesce(x->>'month','')!~'^[0-9]{4}-[0-9]{2}-01$'
    OR NOT coalesce(pg_catalog.pg_input_is_valid(x->>'month','date'),false)
    OR coalesce(x->>'amount_brl','')!~'^[0-9]+([.][0-9]+)?$'
    OR (x->>'coverage'='documented_zero' AND (x->>'amount_brl')::numeric<>0))
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(facts)x GROUP BY x->>'series_key',x->>'month' HAVING count(*)>1)
  THEN RAISE EXCEPTION 'A base mensal da revisão contém uma competência inválida.';END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(policy->'rules')
  WHERE coalesce(value->>'active','true')='true' AND(value->>'method'='history_total_budget'
   OR(value->>'method'='inflated_calendar' AND value->>'template_source'='history_mean'))
  ORDER BY value->>'series_key' LOOP
  key:=r->>'series_key';
  expected_months:=12;series_from:=wf;series_to:=wt;
  IF r->>'method'='history_total_budget' AND r->>'source_kind'='card_invoice' THEN
   expected_months:=3;
   series_from:=(date_trunc('month',p_as_of::timestamp)-interval '3 months')::date;
   series_to:=date_trunc('month',p_as_of::timestamp)::date-1;
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(previous_series)x
    WHERE x->>'series_key'=key AND x->>'coverage_months'='3'
     AND (x->>'window_to')::date>series_to)
   THEN deferred:=deferred+1;CONTINUE;END IF;
  END IF;
  SELECT count(*)::int,count(*)FILTER(WHERE coalesce(x->>'coverage','') NOT IN('complete','documented_zero'))::int,
   sum((x->>'amount_brl')::numeric),round(avg((x->>'amount_brl')::numeric),2)
  INTO n,partial_count,total,mean FROM jsonb_array_elements(facts)x
  WHERE x->>'series_key'=key AND (x->>'month')::date BETWEEN series_from AND series_to;
  IF n<>expected_months OR partial_count<>0 THEN deferred:=deferred+1;CONTINUE;END IF;
  SELECT coalesce(jsonb_agg(DISTINCT a.value ORDER BY a.value),'[]') INTO refs
  FROM jsonb_array_elements(facts)x CROSS JOIN LATERAL jsonb_array_elements(coalesce(x->'source_refs','[]'))a(value)
  WHERE x->>'series_key'=key AND (x->>'month')::date BETWEEN series_from AND series_to;
  SELECT coalesce(jsonb_agg(DISTINCT a.value ORDER BY a.value),'[]') INTO hashes
  FROM jsonb_array_elements(facts)x CROSS JOIN LATERAL jsonb_array_elements(coalesce(x->'raw_hashes','[]'))a(value)
  WHERE x->>'series_key'=key AND (x->>'month')::date BETWEEN series_from AND series_to;
  IF jsonb_array_length(refs)=0 THEN deferred:=deferred+1;CONTINUE;END IF;
  candidate:=jsonb_build_object('series_key',key,'window_from',series_from,'window_to',series_to,
   'coverage_months',expected_months,'sum_brl',total,'mean_brl',mean,'source_refs',refs,'raw_hashes',hashes);
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(next_series)x WHERE x=candidate)THEN CONTINUE;END IF;
  SELECT coalesce(jsonb_agg(x ORDER BY x->>'series_key'),'[]')||jsonb_build_array(candidate) INTO next_series
  FROM jsonb_array_elements(next_series)x WHERE x->>'series_key'<>key;
  changed:=changed+1;
 END LOOP;
 SELECT coalesce(jsonb_agg(x ORDER BY x->>'series_key'),'[]') INTO next_series FROM jsonb_array_elements(next_series)x;
 IF changed=0 THEN RETURN jsonb_build_object('changed',false,'updated_series',0,'deferred_series',deferred);END IF;
 result:=jsonb_build_object('schema_version',1,'revision',coalesce((old_state->>'revision')::int,0)+1,
  'updated_on',p_as_of,'series',next_series);raw:=result::text;digest:=encode(sha256(convert_to(raw,'UTF8')),'hex');
 INSERT INTO public.legacy_namespace(usuario_id,chave,valor_bruto,sha256)
 VALUES(p_user_id,'lts_projection_reference_v412',raw,digest)
 ON CONFLICT(usuario_id,chave)DO UPDATE SET valor_bruto=excluded.valor_bruto,sha256=excluded.sha256,importado_em=clock_timestamp();
 INSERT INTO public.audit_log(user_id,action,entity_type,details)
 VALUES(p_user_id,'projection_reference_refreshed_v412','planning_reference',
  jsonb_build_object('as_of',p_as_of,'window_from',wf,'window_to',wt,'updated_series',changed,
   'deferred_series',deferred,'previous',old_state,'current',result,'sha256',digest));
 PERFORM lts_projection_private_v412.invalidate_reads(p_user_id);
 RETURN jsonb_build_object('changed',true,'updated_series',changed,'deferred_series',deferred,'revision',result->'revision');
END $function$;
