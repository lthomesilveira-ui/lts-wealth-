BEGIN;
SET LOCAL lock_timeout='2s';
DO $lifecycle$ DECLARE p regprocedure;h text;a jsonb;changed boolean:=false;BEGIN
p:='lts_projection_private_v412.card_new_spend_provision(jsonb,date)'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),to_jsonb(f)-'prosrc' INTO h,a FROM pg_proc f WHERE oid=p;
 IF h NOT IN('4755895d26b059d2cbf969b200d9ecb9','671c515db478612f8f317c1559ad20db') OR a->>'proacl' IS DISTINCT FROM '["postgres=X/postgres", "service_role=X/postgres"]'
 OR a->>'proconfig' IS DISTINCT FROM '["search_path=\"\""]' OR (a->>'prosecdef')::boolean
 OR (SELECT pg_get_userbyid(proowner) FROM pg_proc WHERE oid=p)<>'postgres' THEN
 RAISE EXCEPTION 'Rolling card window predecessor changed: %',p;END IF;
p:='lts_projection_private_v412.calculate(jsonb,jsonb,jsonb,date)'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),to_jsonb(f)-'prosrc' INTO h,a FROM pg_proc f WHERE oid=p;
 IF h NOT IN('36e88d8f2482bd86bd24e3c129efb668','0b72f85595e0085bf61dbea8b9356ff4') OR a->>'proacl' IS DISTINCT FROM '["postgres=X/postgres", "service_role=X/postgres"]'
 OR a->>'proconfig' IS DISTINCT FROM '["search_path=\"\""]' OR (a->>'prosecdef')::boolean
 OR (SELECT pg_get_userbyid(proowner) FROM pg_proc WHERE oid=p)<>'postgres' THEN
 RAISE EXCEPTION 'Rolling card window predecessor changed: %',p;END IF;
p:='lts_product_refresh_private_v415.review_profile_v450()'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),to_jsonb(f)-'prosrc' INTO h,a FROM pg_proc f WHERE oid=p;
 IF h NOT IN('61ffab594e8c04fc1c3dbb217afc2f26','ed1586c39b1bd046b29303920a95a032') OR a->>'proacl' IS DISTINCT FROM '["postgres=X/postgres", "service_role=X/postgres"]'
 OR a->>'proconfig' IS DISTINCT FROM '["search_path=\"\""]' OR (a->>'prosecdef')::boolean
 OR (SELECT pg_get_userbyid(proowner) FROM pg_proc WHERE oid=p)<>'postgres' THEN
 RAISE EXCEPTION 'Rolling card window predecessor changed: %',p;END IF;
p:='lts_projection_private_v412.card_new_spend_provision(jsonb,date)'::regprocedure;
 IF md5(pg_get_functiondef(p))='4755895d26b059d2cbf969b200d9ecb9' THEN
  SELECT to_jsonb(f)-'prosrc' INTO a FROM pg_proc f WHERE oid=p;
  EXECUTE $replacement$CREATE OR REPLACE FUNCTION lts_projection_private_v412.card_new_spend_provision(p_rule jsonb, p_on date)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE c jsonb:=p_rule->'new_spend_provision';starts date; amount numeric;
BEGIN
 IF c IS NULL THEN RETURN NULL; END IF;
 IF jsonb_typeof(c) IS DISTINCT FROM 'object'
  OR p_rule->>'method' IS DISTINCT FROM 'history_total_budget'
  OR p_rule->>'source_kind' IS DISTINCT FROM 'card_invoice'
  OR p_rule->>'direction' IS DISTINCT FROM 'expense'
  OR nullif(btrim(p_rule->>'card_family'),'') IS NULL
  OR coalesce(c->>'starts_on','') !~ '^[0-9]{4}-[0-9]{2}-01$'
  OR NOT coalesce(pg_catalog.pg_input_is_valid(c->>'starts_on','date'),false)
  OR coalesce(c->>'amount_brl','') !~ '^[0-9]+([.][0-9]{1,2})?$'
  OR nullif(btrim(c->>'source_ref'),'') IS NULL
  THEN RAISE EXCEPTION 'Confira a provisão de novos gastos do cartão.'; END IF;
 starts:=(c->>'starts_on')::date;amount:=(c->>'amount_brl')::numeric;
 IF starts<(p_rule->>'starts_on')::date OR amount<=0 OR amount>100000000
  OR (p_rule->>'ends_on' IS NOT NULL AND starts>(p_rule->>'ends_on')::date)
  THEN RAISE EXCEPTION 'Confira a vigência e o valor da provisão do cartão.'; END IF;
 IF p_on IS NULL OR p_on<starts THEN RETURN NULL; END IF;
 RETURN c;
END $function$
$replacement$;
  IF md5(pg_get_functiondef(p))<>'671c515db478612f8f317c1559ad20db' OR a IS DISTINCT FROM(SELECT to_jsonb(f)-'prosrc' FROM pg_proc f WHERE oid=p) THEN
   RAISE EXCEPTION 'Rolling card window definition or attributes differ';END IF;
  changed:=true;
 END IF;
p:='lts_projection_private_v412.calculate(jsonb,jsonb,jsonb,date)'::regprocedure;
 IF md5(pg_get_functiondef(p))='36e88d8f2482bd86bd24e3c129efb668' THEN
  SELECT to_jsonb(f)-'prosrc' INTO a FROM pg_proc f WHERE oid=p;
  EXECUTE $replacement$CREATE OR REPLACE FUNCTION lts_projection_private_v412.calculate(p_policy jsonb, p_history jsonb, p_slots jsonb, p_as_of date)
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
$replacement$;
  IF md5(pg_get_functiondef(p))<>'0b72f85595e0085bf61dbea8b9356ff4' OR a IS DISTINCT FROM(SELECT to_jsonb(f)-'prosrc' FROM pg_proc f WHERE oid=p) THEN
   RAISE EXCEPTION 'Rolling card window definition or attributes differ';END IF;
  changed:=true;
 END IF;
p:='lts_product_refresh_private_v415.review_profile_v450()'::regprocedure;
 IF md5(pg_get_functiondef(p))='61ffab594e8c04fc1c3dbb217afc2f26' THEN
  SELECT to_jsonb(f)-'prosrc' INTO a FROM pg_proc f WHERE oid=p;
  EXECUTE $replacement$CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.review_profile_v450()
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$ SELECT $manifest${
  "producers": [
    {
      "md5": "3900ca2edf2711a189defff21baff121",
      "signature": "public.lts_current_evidence_position_v1(uuid)"
    },
    {
      "md5": "206c6ae57f42d3872a5526b6074bb9f2",
      "signature": "public.lts_corrected_cashflow_fix86_v1(uuid,date,date)"
    },
    {
      "md5": "b2a59acca5d7b3bda6c4d7623ae5576c",
      "signature": "public.lts_corrected_cashflow_fix86_v2(uuid,date,date)"
    },
    {
      "md5": "5107d8d47f89f04c44d77941b05900e2",
      "signature": "public.lts_canonical_description_fix86_v1(text)"
    },
    {
      "md5": "20d7ec098884b5a8ac06116781d8f3ac",
      "signature": "public.lts_corrected_cashflow_fix86_v3(uuid,date,date)"
    },
    {
      "md5": "bf16d2f5f23eac410cf1516674048d59",
      "signature": "public.lts_internal_transfer_legs_fix86_v1(uuid,date,date)"
    },
    {
      "md5": "c994cbe994eb1a22d43a79793b0f14c9",
      "signature": "public.lts_corrected_cashflow_fix86_v4(uuid,date,date)"
    },
    {
      "md5": "e9e5f710fe7144af4117a4a11688890d",
      "signature": "public.lts_historical_effective_cash_v2(uuid,date,date)"
    },
    {
      "md5": "6676a65ce3e8e41b678e62f0b489251a",
      "signature": "public.lts_historical_effective_cash_v3(uuid,date,date)"
    },
    {
      "md5": "1219e04b97f74a5190639e3d3f7d9618",
      "signature": "public.lts_flow_current_effective_v1(uuid,date,date)"
    },
    {
      "md5": "1c6fd4b90d14f41339b91d2db104319b",
      "signature": "public.lts_confirmation_key_for_flow_ref_v1(uuid,text)"
    },
    {
      "md5": "b5d0f51f32e389f903e2b6e2785cf63f",
      "signature": "public.lts_historical_effective_cash_v4(uuid,date,date)"
    },
    {
      "md5": "5ba5df8823c2986f3d94cee05433abe9",
      "signature": "public.lts_corrected_cashflow_operational_v1(uuid,date,date)"
    },
    {
      "md5": "2fe93166917418b9155a52c3ca39db74",
      "signature": "public.lts_canonical_category_v1(uuid,text)"
    },
    {
      "md5": "a6f95cef0dc87e44756cd08a476339bc",
      "signature": "public.lts_payroll_withholding_effective_v1(uuid,date,date)"
    },
    {
      "md5": "9330a40ad6071900cda300452a1c213b",
      "signature": "public.lts_historical_effective_cash_v5(uuid,date,date)"
    },
    {
      "md5": "0b181ac93fc98827cdf834043f214df9",
      "signature": "public.lts_flow_past_operational_v2(uuid,date,date)"
    },
    {
      "md5": "7280cf73ab6e4dd3003ab7ec66f5c013",
      "signature": "public.lts_corrected_cashflow_fix86_v5(uuid,date,date)"
    },
    {
      "md5": "2d94c51243c430e1ddfdcc8b98783c72",
      "signature": "public.lts_expense_management_group_v3(text,text,text,text,text)"
    },
    {
      "md5": "1be62bc2e068051f98f14c5fa2c828c3",
      "signature": "public.lts_expense_management_subgroup_v2(text,text,text,text,text)"
    },
    {
      "md5": "21af2733b8d46a42325233fa8e37257b",
      "signature": "public.lts_expense_effective_rows_v176(uuid,date,date)"
    },
    {
      "md5": "8bd38f36cd64245bdf8a84464a298839",
      "signature": "public.lts_v178_norm(text)"
    },
    {
      "md5": "affd7eefd5f929701be548b3da275f64",
      "signature": "public.lts_card_family_key_v181(text,text)"
    },
    {
      "md5": "c35a0e6a6941157964a79eb5f5b31fcf",
      "signature": "public.lts_card_invoice_account_v181(text)"
    },
    {
      "md5": "6c2360ed89bd0ee12de2e662de1ffce2",
      "signature": "public.lts_open_finance_current_bank_position_v1(uuid)"
    },
    {
      "md5": "b9d8f8f0db01f7a9a2310398ec5776bc",
      "signature": "public.lts_current_evidence_position_v2(uuid)"
    },
    {
      "md5": "848c0d41a080916b4c0a6b74dcc17a82",
      "signature": "public.lts_card_family_v226(text,text)"
    },
    {
      "md5": "ef996716f66fc61e5e466ce1636d6713",
      "signature": "public.lts_card_merchant_key_v226(text)"
    },
    {
      "md5": "d98e3a726149666eddf069cef8ad7a4e",
      "signature": "public.lts_card_source_rows_v226(uuid)"
    },
    {
      "md5": "71d0beacbd4803f0e14bbc2885e7247e",
      "signature": "public.lts_card_cycles_v226(uuid)"
    },
    {
      "md5": "9baacf4fb28872f1c17c00b862cad01f",
      "signature": "public.lts_card_exact_recovery_v226(uuid,date,date)"
    },
    {
      "md5": "1183985090fd8773db59036cee9e7ec6",
      "signature": "public.lts_expense_effective_rows_v225_baseline(uuid,date,date)"
    },
    {
      "md5": "3026f1d05acf5bc8ec573c9bfbf25531",
      "signature": "public.lts_flow_operational_read_v229(uuid,date,date)"
    },
    {
      "md5": "aae8c78fc55fe52fa0ddab347480f37c",
      "signature": "public.lts_v229_new_bank_rows(uuid,date,date)"
    },
    {
      "md5": "6bf5e8d7c0dda985892c8209b7222337",
      "signature": "public.lts_expense_rows_v230_baseline(uuid,date,date)"
    },
    {
      "md5": "ac823d4947b9a4f9739c24533ead5bc2",
      "signature": "public.lts_v229_review_rows(uuid,date,date)"
    },
    {
      "md5": "a95cf3f7802c4d3bafd7bfb49551e042",
      "signature": "public.lts_bank_description_key_v229(text)"
    },
    {
      "md5": "5edc57b30e5d6b8a52d632efa08ec498",
      "signature": "public.lts_card_invoice_amounts_v230(uuid)"
    },
    {
      "md5": "512e6b2b7f396b1e67e99818869ec12a",
      "signature": "public.lts_bank_merchant_key_v231(text)"
    },
    {
      "md5": "1dbb589d3877c60420fdff81c384fb8c",
      "signature": "public.lts_bank_posted_rows_v231(uuid)"
    },
    {
      "md5": "c89adcb69252efa960cbb34df2a89768",
      "signature": "public.lts_bank_known_classification_v231(uuid,uuid)"
    },
    {
      "md5": "24140ece2345c630f3db5051a6e422e9",
      "signature": "public.lts_payroll_bank_matches_v231(uuid)"
    },
    {
      "md5": "3df237f6269a6a13bc3403b05276fcac",
      "signature": "public.lts_card_installment_key_v231(public.lts_open_finance_staging)"
    },
    {
      "md5": "bd41db5479a15491422cf6268db89b47",
      "signature": "public.lts_v229_expense_rows_pre_v238(uuid,date,date)"
    },
    {
      "md5": "3f1a2c6e73150f6874cbda3db88317f9",
      "signature": "public.lts_card_document_matches_v234(uuid)"
    },
    {
      "md5": "68a27f360b474f8ac0df91a7650fe924",
      "signature": "public.lts_card_document_rows_v234(uuid)"
    },
    {
      "md5": "4df73b4ad0cafadc367377e48c5ca251",
      "signature": "public.lts_operational_source_key_v238(uuid)"
    },
    {
      "md5": "02696060487b81ddf0592be23a2e044f",
      "signature": "public.lts_realized_bank_sources_v238(uuid)"
    },
    {
      "md5": "a2ab1bb252ba1c27cb0ad7fa62cbe5cd",
      "signature": "public.lts_v229_expense_rows(uuid,date,date)"
    },
    {
      "md5": "164c5a3d3705549fcdbf2a6e93d6b9ed",
      "signature": "public.lts_card_workbook_bank_rows_v1(uuid)"
    },
    {
      "md5": "891b9f6b72365cc6d142aa098f941ff1",
      "signature": "public.lts_card_bank_monthly_deltas_v1(uuid)"
    },
    {
      "md5": "0c9a66e16022bb799bb268295515d50c",
      "signature": "public.lts_open_finance_checking_positions_v1(uuid)"
    },
    {
      "md5": "4bc0f47babbba8bf30fced74161cf19a",
      "signature": "public.lts_flow_classification_decision_v1(uuid,jsonb)"
    },
    {
      "md5": "60015122f8b310f2b3f79538e851f2cf",
      "signature": "public.lts_forecast_series_key_v1(text)"
    },
    {
      "md5": "1f72d7ac2b27a5e111de3f1c7d41fb42",
      "signature": "public.lts_historical_effective_cash_pre_v246(uuid,date,date)"
    },
    {
      "md5": "e2950ce945db74cbf6acc68587dcb7d6",
      "signature": "public.lts_card_observed_expense_eligible_v1(jsonb,date,date)"
    },
    {
      "md5": "240849f813a9ac43b853d42440ef02b0",
      "signature": "public.lts_historical_effective_cash_v4_pre_v237(uuid,date,date)"
    },
    {
      "md5": "e3e63ef8481594d301f5b0560d6ae25b",
      "signature": "public.lts_c6_paid_identity_v237(uuid)"
    },
    {
      "md5": "38238af5e695c1d54d45e63f1579dd26",
      "signature": "public.lts_operational_source_key_pre_v242(uuid)"
    },
    {
      "md5": "0498aef77c7c7970de52c6712c0d6c30",
      "signature": "public.lts_historical_cash_engine_v243(uuid,date,date)"
    },
    {
      "md5": "5db62be42ab458431614f11172fb70bc",
      "signature": "public.lts_card_invoice_amounts_v230_engine_v243(uuid)"
    },
    {
      "md5": "65fbb2bf3db4cefcce6f70e7a89f9561",
      "signature": "public.lts_payroll_bank_matches_v231_engine_v243(uuid)"
    },
    {
      "md5": "6b8b11bef56c749826f713904fdea55c",
      "signature": "public.lts_corrected_cashflow_fix86_v1_engine_v247(uuid,date,date)"
    },
    {
      "md5": "3d06e4c309d8b0bc0466558f8f92e1a7",
      "signature": "public.lts_bank_fgts_combined_receipt_v261(uuid,uuid)"
    },
    {
      "md5": "d5e085fe7dbc8f6a2ad562feb290c1fb",
      "signature": "public.lts_card_source_rows_pre_v262(uuid)"
    },
    {
      "md5": "363c2c63d3ee64df40173f8c3d7aab21",
      "signature": "public.lts_owner_confirmed_transfer_pairs_v263(uuid)"
    },
    {
      "md5": "0738e3c16dfe4fdea7b6a59d42d5535c",
      "signature": "public.lts_current_received_card_bills_v263(uuid)"
    },
    {
      "md5": "c8c716093de7f247be51f6ed6f34bd8f",
      "signature": "public.lts_expense_effective_rows_pre_v268(uuid,date,date)"
    },
    {
      "md5": "3869ff49b557837aecbc11b8528fca6a",
      "signature": "public.lts_c6_cycle_identity_v269(uuid)"
    },
    {
      "md5": "dd6e02daa77ff6fb09df0324e3e45692",
      "signature": "public.lts_card_document_candidates_v269(uuid)"
    },
    {
      "md5": "d0e199988d394dd3e875f8c059933fe7",
      "signature": "public.lts_c6_completeness_state_v269(uuid)"
    },
    {
      "md5": "cbfae2833915df136d8046fd9e18f81c",
      "signature": "public.lts_card_settlement_contract_v273(uuid,uuid)"
    },
    {
      "md5": "c7fe16708fd3a9a1a768c0cfa8ee9a8c",
      "signature": "public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb)"
    },
    {
      "md5": "56a8a53a1290893ae4f94634ffb01867",
      "signature": "public.lts_card_settlement_expense_excluded_v273(uuid,uuid,jsonb)"
    },
    {
      "md5": "45974b44368efcd4fa7080851a2125e1",
      "signature": "public.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)"
    },
    {
      "md5": "29778e4a296e728ad9723a6e08e1c55b",
      "signature": "public.lts_bill_source_fields_v286(jsonb,jsonb,date)"
    },
    {
      "md5": "9f5b3bc99757b695e3c32022c90388fb",
      "signature": "public.lts_card_invoice_settled_v290(uuid,text,date,date,numeric)"
    },
    {
      "md5": "a8a083f160fb6e2937dc96e165b2fbd8",
      "signature": "public.lts_card_due_overlay_v290(uuid,jsonb)"
    },
    {
      "md5": "8cc4cb82649edc926c2842afb7522d06",
      "signature": "public.lts_card_projection_rows_v290(uuid)"
    },
    {
      "md5": "f5ff0aefd33935bb5eabf3fdc925fe74",
      "signature": "public.lts_card_settlement_overlay_v290(uuid,jsonb)"
    },
    {
      "md5": "0d845b5e55b0505af153d66adfcd6ea4",
      "signature": "public.lts_expense_rows_pre_categories_v290(uuid,date,date)"
    },
    {
      "md5": "6e7bf2157a330190a5003cd29247161d",
      "signature": "lts_income_private.category_v296(uuid,text,text)"
    },
    {
      "md5": "3c681814ed788e864f2e75511fa4ffd1",
      "signature": "public.lts_card_cycle_settlement_v301(jsonb,jsonb)"
    },
    {
      "md5": "ad76fd524058f3b4e75bc481a032c338",
      "signature": "public.lts_partial_obligation_settlement_valid_v302(jsonb,jsonb,jsonb,jsonb)"
    },
    {
      "md5": "5f78416d190a1a7a375e3e0e11fe8445",
      "signature": "public.lts_posted_own_transfer_valid_v304(uuid,jsonb,jsonb,jsonb,jsonb,jsonb)"
    },
    {
      "md5": "33c9ee21e5e049a5be0266c67c719620",
      "signature": "public.lts_posted_own_transfer_out_v304(uuid)"
    },
    {
      "md5": "291dc64044041416759df58589a50b44",
      "signature": "public.lts_prepared_card_cycles_v307(uuid)"
    },
    {
      "md5": "655b63c0813b334710615843b9b9ddb4",
      "signature": "public.lts_aeternum_forecast_cycles_v311(uuid)"
    },
    {
      "md5": "dc900351b38a8f5a3bbf31955dc4c61a",
      "signature": "public.lts_card_forecast_overlay_v311(uuid,jsonb)"
    },
    {
      "md5": "866bfd2faad09d44a60f946b7b8c6c43",
      "signature": "public.lts_workbook_transfer_identity_v336(uuid)"
    },
    {
      "md5": "34b7114165a4e91be404399836782d83",
      "signature": "public.lts_workbook_transfer_identity_v338(uuid)"
    },
    {
      "md5": "092e901ed772fb34d2bda78bfdafcb10",
      "signature": "public.lts_c6_contract_clock_rows_v349(jsonb)"
    },
    {
      "md5": "b7ab98acb2b884c21b7355302a79cff5",
      "signature": "public.lts_card_item_is_invoice_payment_v351(jsonb)"
    },
    {
      "md5": "e38bfe13754a3a8b5696db120b1004d5",
      "signature": "public.lts_card_cycle_settlement_v351(jsonb,jsonb)"
    },
    {
      "md5": "0bcd78087d78d80dd2b00724318d6903",
      "signature": "public.lts_transfer_refresh_valid_v363(uuid,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb)"
    },
    {
      "md5": "ad87d534451381da68a290d7ab67f38b",
      "signature": "public.lts_previously_proved_transfer_pairs_v363(uuid)"
    },
    {
      "md5": "031156449872239330aba72b614af71b",
      "signature": "public.lts_card_projection_date_v370(uuid,text,date,date,date)"
    },
    {
      "md5": "c79ae9493992a7826017fa3062f97060",
      "signature": "public.lts_card_transition_cash_date_v370(uuid,text,date)"
    },
    {
      "md5": "6a73e664c65611c7a1f51b9b54380b3d",
      "signature": "public.lts_card_transition_overlay_v370(uuid,jsonb)"
    },
    {
      "md5": "e7ed129c02e3212302a4759a4a950724",
      "signature": "public.lts_cofrinho_bank_redemptions_v381(uuid,date,date)"
    },
    {
      "md5": "d1ba27f82c8ec6fcecbe0637969bb238",
      "signature": "public.lts_fgts_position_evidence_v386(uuid,date)"
    },
    {
      "md5": "58eebeb755504d01304bd801d569e036",
      "signature": "public.lts_card_due_estimate_overlay_v391(uuid,jsonb)"
    },
    {
      "md5": "556b9cdfff74827eea5819422c278546",
      "signature": "public.lts_cofrinho_composition_v399(uuid,date)"
    },
    {
      "md5": "eeeba973bfb0d4b067e004fd7ab5199a",
      "signature": "public.lts_cofrinho_documentary_composition_v402(uuid,date)"
    },
    {
      "md5": "b9849fe1221396d0a6c891463f43f7bb",
      "signature": "public.lts_cofrinho_provider_position_v402(uuid,date)"
    },
    {
      "md5": "cd55278c925c273fab0f32691b3a6d77",
      "signature": "lts_projection_private_v412.fixed_amount(jsonb,date)"
    },
    {
      "md5": "f42d27119ebc9c79d65df908a2e006fd",
      "signature": "lts_projection_private_v412.owner_policy(uuid)"
    },
    {
      "md5": "61d623e8d18f329f6bebccd4afeaf719",
      "signature": "lts_projection_private_v412.horizon_end(date)"
    },
    {
      "md5": "7bc0289413a6d546c5070414827023ad",
      "signature": "lts_projection_private_v412.review_window(jsonb,date)"
    },
    {
      "md5": "17c3b90c1df758e489d13378936391df",
      "signature": "lts_projection_private_v412.base_flow(uuid,date,date)"
    },
    {
      "md5": "d378c15fc35b8c8c6e10c5b928cfe96f",
      "signature": "lts_projection_private_v412.source_label(text)"
    },
    {
      "md5": "86f60fe0c33409204db6de7dc0d1bc7b",
      "signature": "lts_projection_private_v412.monthly_source_facts_v412(uuid,date,date,jsonb)"
    },
    {
      "md5": "a0c466ed037263cc6e3419b06a26bcfe",
      "signature": "lts_projection_private_v412.calendar_templates_v412(uuid,jsonb)"
    },
    {
      "md5": "8241371be1fd9688da69459c0c5b3c3e",
      "signature": "lts_projection_private_v412.known_card_periods_v412(uuid)"
    },
    {
      "md5": "0b72f85595e0085bf61dbea8b9356ff4",
      "signature": "lts_projection_private_v412.calculate(jsonb,jsonb,jsonb,date)"
    },
    {
      "md5": "20cd10920678a7233965813167ec0706",
      "signature": "lts_projection_private_v412.reference_state(uuid)"
    },
    {
      "md5": "b5c214f5a8e1f54c7a82038bedbc03a1",
      "signature": "lts_projection_private_v412.build(uuid,date)"
    },
    {
      "md5": "5fc273e25705711595caa96fee9f691d",
      "signature": "lts_product_refresh_private_v415.card_source_key(uuid)"
    },
    {
      "md5": "e23ee4f8f05cfedac0ca3c68b04bbec8",
      "signature": "lts_projection_private_v412.scope_match_v416(jsonb,jsonb,boolean)"
    },
    {
      "md5": "eb5ec59c4a5ba9090c8bf1645d6ab258",
      "signature": "lts_projection_private_v412.scope_history_v416(jsonb,jsonb,jsonb,date)"
    },
    {
      "md5": "c14a4064624418b03cd0fc6dc9e7ce99",
      "signature": "lts_projection_private_v412.scope_history_read_v416(uuid,jsonb,jsonb,date)"
    },
    {
      "md5": "7d6a29396f98680308840f19e25f7a0a",
      "signature": "lts_projection_private_v412.scope_slots_v416(jsonb,jsonb,jsonb)"
    },
    {
      "md5": "82627286a1c3a73ee4d18f1dba54a866",
      "signature": "public.lts_card_later_issuer_payments_valid_v428(jsonb,jsonb,jsonb)"
    },
    {
      "md5": "9c0d1ac15cb98696ef8fc98aca9ef6b6",
      "signature": "lts_read_private_v430.try_cache_put(uuid,text,date,date,date,jsonb,text)"
    },
    {
      "md5": "fcdc0852c1f0e8316ea961168b04b33d",
      "signature": "public.lts_confirmed_schedule_pairs_v431(uuid)"
    },
    {
      "md5": "ff09da81dbc2a7e7358cac2315fe9147",
      "signature": "lts_projection_private_v412.read_build_cache_v438(uuid,date,jsonb)"
    },
    {
      "md5": "671c515db478612f8f317c1559ad20db",
      "signature": "lts_projection_private_v412.card_new_spend_provision(jsonb,date)"
    },
    {
      "md5": "75a1eb59a97d445da40c51a6d642aeae",
      "signature": "lts_projection_private_v412.verify_card_legacy_obligations(uuid,jsonb)"
    },
    {
      "md5": "d5f23851a4049a9c380b3d13991d0814",
      "signature": "lts_projection_private_v412.card_legacy_obligations_match(jsonb,jsonb)"
    },
    {
      "md5": "30a6a78744316806e0ca52a632c73e6b",
      "signature": "public.lts_invoice_payment_order_equal_v442(jsonb,jsonb)"
    },
    {
      "md5": "01810b2f491005875361b564088edb53",
      "signature": "lts_projection_private_v412.received_income_slot_v443(uuid,jsonb,date,date)"
    },
    {
      "md5": "8829d7dff268811b63f7a3b19eaff092",
      "signature": "public.lts_expense_matched_bank_rows_v445(uuid,date,date)"
    },
    {
      "md5": "99f49c4f11e130d6cab4196173f41ec0",
      "signature": "public.lts_v246_invalidate_finance_cache()"
    },
    {
      "signature": "lts_product_refresh_private_v415.documented_own_out_v450(uuid)",
      "md5": "9b8208a7d073c1d68272875841215911"
    },
    {
      "signature": "lts_product_refresh_private_v415.reviewed_c6_mode_v450(jsonb,jsonb,jsonb)",
      "md5": "5fd0dd7b5989e3d59c33d06820568bab"
    }
  ],
  "tables": [
    {
      "kind": "r",
      "name": "audit_log",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_product_read_cache",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_category_catalog",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_external_reference_fact",
      "epoch": false,
      "owner": null,
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_open_finance_sync_run",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_expense_effective_read_cache",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_open_finance_resource_map",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_v229_documentary_match",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_workbook_identity_evidence_v232",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_card_formula_resolution_v237",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_card_documentary_payment_link_v272",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_card_settlement_expense_contract_v273",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_category_binding_v290",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_card_due_rule_v290",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_recurring_plan_v366",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_card_due_transition_v370",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_card_due_estimate_v391",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "queue",
      "epoch": false,
      "owner": "user_id",
      "schema": "lts_product_refresh_private_v415"
    },
    {
      "kind": "r",
      "name": "received_income_evidence_v443",
      "epoch": false,
      "owner": "user_id",
      "schema": "lts_projection_private_v412"
    }
  ],
  "epoch_tables": [
    {
      "signature": "public.accounts",
      "md5": "0cd95ba1233a645b7b6b89b899c91ee9"
    },
    {
      "signature": "public.financial_events",
      "md5": "cdd46c379c75ec1b13c0576d213d116c"
    },
    {
      "signature": "public.asset_positions",
      "md5": "784bbef4179e4c6201a0a57469fc2b9f"
    },
    {
      "signature": "public.card_invoices",
      "md5": "79141e85d01638ee3b3b5bcc85288ab0"
    },
    {
      "signature": "public.source_documents",
      "md5": "d2502a75b65d841b0078bdd23dc3f544"
    },
    {
      "signature": "public.app_settings",
      "md5": "8a272a34fee05cd774115f8b74bc891d"
    },
    {
      "signature": "public.legacy_namespace",
      "md5": "f1e3991f741b971ca5584408140f60b8"
    },
    {
      "signature": "public.evento_base",
      "md5": "67e711865d230fa0ebfeba0041da1d90"
    },
    {
      "signature": "public.historico_analitico",
      "md5": "a0743bb7ec6a95ea3fc069f531fa81f9"
    },
    {
      "signature": "public.evento_usuario",
      "md5": "d59d0ad57334f4dc2d4d28cb1858ff01"
    },
    {
      "signature": "public.reconciliacao",
      "md5": "931e76d391d7a2b142e983a1ef6c27a7"
    },
    {
      "signature": "public.deslocamento",
      "md5": "434b2d0111de5fb71ac0b34fd0fdb331"
    },
    {
      "signature": "public.projecao_op",
      "md5": "2898399189c102b2a555b92ee9fca339"
    },
    {
      "signature": "public.lts_projection_replacement_rule",
      "md5": "55abffad3dd07c3cf55f4ed7fc5b801e"
    },
    {
      "signature": "public.lts_semantic_rule",
      "md5": "81260f5c0c534b1aa65371f93040223b"
    },
    {
      "signature": "public.lts_manual_card_purchase",
      "md5": "4745ae14abd398447abd1d75094368fb"
    },
    {
      "signature": "public.lts_reconciliation_evidence",
      "md5": "29454b21cd3d71fae9c0e16967f7d876"
    },
    {
      "signature": "public.lts_document_card_purchase",
      "md5": "51f552d78c82e0a0ee24790ae1d293c4"
    },
    {
      "signature": "public.lts_fact_confirmation",
      "md5": "c252c1d875d3dfed8e6b5a299a539a09"
    },
    {
      "signature": "public.lts_flow_event_operation",
      "md5": "ced7e25c93af7437e65d0f450dae2c2f"
    },
    {
      "signature": "public.lts_commitment_documentary_schedule",
      "md5": "693ccd59d4f2c6ec1f9488a87541bef0"
    },
    {
      "signature": "public.lts_category_alias",
      "md5": "390fd09ae6c62e74adc764aff90404e6"
    },
    {
      "signature": "public.lts_semantic_amount_signature",
      "md5": "9158c8a6ddc3c3f60475ee2508e5d75c"
    },
    {
      "signature": "public.lts_card_history_recovered_purchase",
      "md5": "58596956f3c48ab508c925d2aab72466"
    },
    {
      "signature": "public.lts_open_finance_connection",
      "md5": "26b5c52a8f4be62ee376a6fe73888006"
    },
    {
      "signature": "public.lts_open_finance_staging",
      "md5": "3a4e2f69a3c7ae6d2564028a67121893"
    },
    {
      "signature": "public.lts_expense_documentary_amount_override",
      "md5": "5aea157c6ec11bee333ecb60340b98e1"
    },
    {
      "signature": "public.lts_card_historical_category_allocation",
      "md5": "17099f1184e352b7e39c9095d15ff88a"
    },
    {
      "signature": "public.lts_card_historical_validation_registry",
      "md5": "4c9b886570b29d69d91ae380336d5a28"
    },
    {
      "signature": "public.lts_liquidity_movement",
      "md5": "532e6df37a44350e864ff915bb958109"
    },
    {
      "signature": "public.lts_v175_workbook_monthly_category_source",
      "md5": "26bcfbde7b3616877262f5e5d4a09c98"
    },
    {
      "signature": "public.lts_v178_review_decision",
      "md5": "63cda13f1dcd530f551ab33fde4679f9"
    },
    {
      "signature": "public.lts_open_finance_observation",
      "md5": "10ab88c362d788e3023e10e025ed033a"
    },
    {
      "signature": "public.lts_validated_lock_registry",
      "md5": "522e3739fa5e349273c96eecfb990969"
    },
    {
      "signature": "public.lts_card_workbook_evidence_v226",
      "md5": "09977fb370184dcd69f03053c6825f01"
    },
    {
      "signature": "public.lts_card_document_supplement_v234",
      "md5": "5f25b9b2ab48bec94eeb07a7010d5fd0"
    },
    {
      "signature": "public.lts_card_history_source_audit_v235",
      "md5": "6e43df483c77c1b26d4777e6cbfb09ae"
    },
    {
      "signature": "public.lts_realized_bank_event_v238",
      "md5": "b9fdfeb875a350e9165fc66f4ff7a806"
    },
    {
      "signature": "public.lts_workbook_transfer_evidence_v336",
      "md5": "c9a73adb0694016e461716891c3a6279"
    },
    {
      "signature": "public.lts_workbook_transfer_reversal_v338",
      "md5": "3afb12f53e2d84a603838c6b293bbbcf"
    }
  ],
  "views": [
    {
      "md5": "30b883b57eac28644fafa04f96aec7ed",
      "signature": "public.lts_expense_realized"
    },
    {
      "md5": "5fb751309feb03a8b3ef84bf3816729c",
      "signature": "public.lts_card_purchase_detail"
    },
    {
      "md5": "950ad5a413e3cc3bf880714055858c89",
      "signature": "public.lts_workbook_nonspend_source_v343"
    }
  ]
}
$manifest$::jsonb $function$
$replacement$;
  IF md5(pg_get_functiondef(p))<>'ed1586c39b1bd046b29303920a95a032' OR a IS DISTINCT FROM(SELECT to_jsonb(f)-'prosrc' FROM pg_proc f WHERE oid=p) THEN
   RAISE EXCEPTION 'Rolling card window definition or attributes differ';END IF;
  changed:=true;
 END IF;
IF changed THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;END IF;
END $lifecycle$;
COMMIT;
