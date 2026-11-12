CREATE OR REPLACE FUNCTION lts_projection_private_v412.calculate(p_policy jsonb, p_history jsonb, p_slots jsonb, p_as_of date)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE provision jsonb; provision_now jsonb; r jsonb; s jsonb; f jsonb; stats jsonb; series jsonb:='[]'; events jsonb:='[]'; replacements jsonb:='[]';
 warnings jsonb:='[]'; slot_warnings jsonb; key text; method text; horizon date; wf date; wt date; nr date;
 count_months integer; spend_months integer; partial_months integer; source_count integer; amount_sum numeric;
 mean_amount numeric; q1 numeric; q3 numeric; outliers jsonb; amount numeric; known numeric; replacement_amount numeric;
 target numeric; extra numeric; effective_date date; protected boolean; cancelled boolean; complete boolean;
 skipped integer; generated integer; invalid_slots integer; annual jsonb; slot_result jsonb; results jsonb:='[]';
 series_from date; series_to date; expected_months integer; history_basis text;
 budget_scopes jsonb; budget_scope jsonb; scope_key text; scope_keys text[];
 matched_amount numeric; scope_target numeric; scope_consumed numeric; scoped_extra numeric;
 reference jsonb; reference_from date;reference_to date;reference_stale boolean;uses_history boolean;
BEGIN
 IF p_policy IS NULL THEN RETURN jsonb_build_object('version','projection-policy-v412','enabled',false); END IF;
 IF p_policy ? 'current_month_card_budget'
  AND p_policy->>'current_month_card_budget' IS DISTINCT FROM 'known_only' THEN
  RAISE EXCEPTION 'A regra do orçamento de cartões precisa ser conferida.';
 END IF;
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
  WHERE coalesce(value->>'active','true')='true'
   AND (value->>'source_kind' IS DISTINCT FROM 'card_invoice' OR value->>'ends_on' IS NULL
    OR (value->>'ends_on')::date>=p_as_of) ORDER BY value->>'series_key' LOOP
  key:=r->>'series_key';method:=r->>'method';results:='[]';generated:=0;skipped:=0;invalid_slots:=0;
  provision_now:=lts_projection_private_v412.card_new_spend_provision(r,p_as_of);
  uses_history:=(method='history_total_budget' OR(method='inflated_calendar' AND r->>'template_source'='history_mean')) AND provision_now IS NULL;
  expected_months:=12;series_from:=wf;series_to:=wt;
  history_basis:='owner_authorized_12m_history';
  IF method='history_total_budget' AND r->>'source_kind'='card_invoice' AND r->>'history_window_months'='3' THEN
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
     AND (r->>'card_budget_mode' IS DISTINCT FROM 'scoped' OR v->>'scope_digest'=md5((r->'budget_definition')::text))
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
   -- Keep confirmed/known obligations; never fill the current due month
   -- to a spending average. Future months retain the approved scoped budgets.
   IF method='history_total_budget' AND r->>'source_kind'='card_invoice'
    AND p_policy->>'current_month_card_budget'='known_only'
    AND date_trunc('month',effective_date::timestamp)=date_trunc('month',p_as_of::timestamp) THEN
    skipped:=skipped+1;
    results:=results||jsonb_build_array(jsonb_build_object('event_date',effective_date,
     'budget_total_brl',known,'additional_brl',0,'known_amount_brl',known,
     'basis','current_month_known_only'));
    CONTINUE;
   END IF;
   provision:=lts_projection_private_v412.card_new_spend_provision(r,effective_date);
   -- Preserve source-verified obligations; unidentified forecasts still fail closed.
   IF provision IS NOT NULL AND NOT lts_projection_private_v412.card_legacy_obligations_match(r,s) THEN
    invalid_slots:=invalid_slots+1;CONTINUE;
   END IF;
   target:=NULL;
   IF provision IS NOT NULL THEN target:=(provision->>'amount_brl')::numeric;
   ELSE
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
   END IF;
   IF target IS NULL THEN CONTINUE;END IF;
   IF target<0 OR target>100000000 OR target<>round(target,2)
    THEN RAISE EXCEPTION 'Valor de projeção fora dos limites.';END IF;
   IF provision IS NOT NULL THEN
    -- This one provision replaces every historical/scoped budget for this card.
    -- Known installments remain in the base flow, and are never subtracted.
    extra:=target;amount:=known+extra;
   ELSIF method='history_total_budget' THEN
    -- A total budget floor. It is deliberately not "new spending plus installments".
    IF r->>'source_kind'='card_invoice' AND r->>'card_budget_mode'='scoped' THEN
     -- The adapter must provide mutually exclusive, verified scopes. The rolling
     -- reference is the general scope after separately budgeted purchases are removed.
     -- Obligations outside these scopes remain in known, but consume no budget.
     budget_scopes:=s->'verified_budget_scopes';
     IF jsonb_typeof(budget_scopes) IS DISTINCT FROM 'array'
      OR budget_scopes='[]'::jsonb THEN
      invalid_slots:=invalid_slots+1;CONTINUE;
     END IF;
     matched_amount:=0;scoped_extra:=0;scope_keys:='{}';
     FOR budget_scope IN SELECT value FROM jsonb_array_elements(budget_scopes) LOOP
      scope_key:=nullif(btrim(budget_scope->>'scope'),'');
      IF scope_key IS NULL OR scope_key=ANY(scope_keys)
       OR coalesce(budget_scope->>'consumed_brl','') !~ '^[0-9]{1,9}([.][0-9]{1,2})?$'
       OR (scope_key<>'general' AND coalesce(budget_scope->>'target_brl','') !~ '^[0-9]{1,9}([.][0-9]{1,2})?$')
      THEN EXIT; END IF;
      scope_keys:=array_append(scope_keys,scope_key);
      scope_target:=CASE WHEN scope_key='general' THEN target ELSE (budget_scope->>'target_brl')::numeric END;
      scope_consumed:=(budget_scope->>'consumed_brl')::numeric;
      matched_amount:=matched_amount+scope_consumed;
      scoped_extra:=scoped_extra+greatest(0,scope_target-scope_consumed);
     END LOOP;
     IF cardinality(scope_keys)<>jsonb_array_length(budget_scopes)
      OR NOT ('general'=ANY(scope_keys)) OR matched_amount>known OR scoped_extra>100000000
     THEN invalid_slots:=invalid_slots+1;CONTINUE; END IF;
     extra:=scoped_extra;amount:=known+extra;
    ELSE
     extra:=greatest(0,target-known);amount:=greatest(target,known);
    END IF;
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
    CASE WHEN provision IS NOT NULL THEN 'fixed_new_spend_provision' WHEN method='history_total_budget' THEN history_basis ELSE method END);
   results:=results||jsonb_build_array(slot_result);
   IF extra>0 THEN
    IF method='inflated_calendar' THEN
     replacements:=replacements||coalesce(s->'replacement_refs','[]'); END IF;
    events:=events||jsonb_build_array(jsonb_build_object('event_date',effective_date,
     'account',r->>'account','description',r->>'description',
     'signed_amount',CASE WHEN r->>'direction'='income' THEN extra ELSE -extra END,
     'source','planning_projection_v412','source_ref','projection:v412:'||key||':'||effective_date,
     'confidence',CASE WHEN provision IS NOT NULL THEN 'owner_authorized_new_spend_provision' WHEN method='history_total_budget' THEN history_basis ELSE 'owner_authorized_planning_rule' END,
     'account_assignment','owner_policy','legacy_index',NULL,'original_date',effective_date,'displaced',false,
     'series_key',key,'method',CASE WHEN provision IS NOT NULL THEN 'fixed_new_spend_provision' ELSE method END,'budget_total_brl',amount,'known_amount_brl',known,
     'source_refs',coalesce(s->'source_refs','[]')||CASE WHEN provision IS NOT NULL THEN jsonb_build_array(provision->>'source_ref') ELSE '[]'::jsonb END||CASE WHEN method='fixed' THEN coalesce((
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
   'reference_base_brl',CASE WHEN uses_history THEN mean_amount END,
   'reference_amount_brl',CASE WHEN provision_now IS NOT NULL THEN (provision_now->>'amount_brl')::numeric WHEN uses_history THEN mean_amount+CASE WHEN r->>'card_budget_mode'='scoped' THEN coalesce((SELECT sum((a->>'amount_brl')::numeric) FROM jsonb_array_elements(r#>'{budget_definition,allowances}')a WHERE a->>'funded_by_series'=key),0) ELSE 0 END WHEN method='fixed' THEN lts_projection_private_v412.fixed_amount(r,p_as_of) ELSE nullif(r->>'amount_brl','')::numeric END,
   'history_total_brl',CASE WHEN uses_history THEN amount_sum END,'uses_history',uses_history,
   'template_source',r->>'template_source','template_year',r->'template_year',
   'reference_window',jsonb_build_object('from',reference_from,'to',reference_to),
   'reference_stale',reference_stale,
   'coverage_months',count_months-partial_months,'observed_months',count_months,
   'months_with_spend',spend_months,'partial_months',partial_months,
   'expected_months',expected_months,'source_count',source_count,'outlier_months',outliers,
   'annual_rate',coalesce((r->>'annual_rate')::numeric,0),'warnings',slot_warnings,
   'projected_occurrences',generated,'preserved_occurrences',skipped,'unresolved_periods',invalid_slots,
   'annual_totals',annual,'due_day_basis',r->>'due_day_basis')||CASE WHEN r ? 'new_spend_provision' THEN jsonb_build_object('new_spend_provision',(r->'new_spend_provision')-'preserved_legacy_obligations') ELSE '{}'::jsonb END||CASE WHEN r->>'source_kind'='card_invoice' AND r->>'ends_on' IS NOT NULL THEN jsonb_build_object('ends_on',r->>'ends_on') ELSE '{}'::jsonb END);
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
END $function$
