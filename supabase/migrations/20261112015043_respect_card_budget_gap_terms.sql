BEGIN;
DO $guard$
DECLARE current_definition text;
BEGIN
 IF to_regprocedure('lts_projection_private_v412.card_budget_exempt_periods_v1(uuid,date,date)') IS NOT NULL THEN
  current_definition:=pg_get_functiondef('lts_projection_private_v412.card_budget_exempt_periods_v1(uuid,date,date)'::regprocedure);
  IF encode(sha256(convert_to(current_definition,'UTF8')),'hex') IS DISTINCT FROM $expected_helper$85006af01b53c57921cf61989a18cfdf73aa6d673d73bb8ac17aff65077db4cb$expected_helper$ THEN RAISE EXCEPTION 'Card gap helper changed; review before applying.'; END IF;
 END IF;
END $guard$;
-- Ended spending budgets do not end documented card liabilities.
-- Return only months with no active budget and no documented expectation.
CREATE OR REPLACE FUNCTION lts_projection_private_v412.card_budget_exempt_periods_v1(
 p_user_id uuid,p_as_of date,p_horizon_end date)
RETURNS TABLE(series_key text,direction text,period_start date)
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $function$
DECLARE policy jsonb:=lts_projection_private_v412.owner_policy(p_user_id);
BEGIN
 IF policy IS NULL OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(policy->'rules')r
  WHERE r->>'method'='history_total_budget' AND r->>'source_kind'='card_invoice'
   AND nullif(r->>'card_family','') IS NOT NULL AND r->>'direction'='expense'
   AND public.lts_card_family_v226(r->>'description',r->>'account')=r->>'card_family'
   AND public.lts_forecast_series_key_v1(r->>'description')=r->>'series_key'
   AND coalesce(r->>'active','true')='true' AND r->>'ends_on' IS NOT NULL) THEN
  RETURN;
 END IF;
 RETURN QUERY
 WITH rules AS MATERIALIZED (
  SELECT r FROM jsonb_array_elements(policy->'rules')r
  WHERE r->>'method'='history_total_budget' AND r->>'source_kind'='card_invoice'
   AND nullif(r->>'card_family','') IS NOT NULL AND r->>'direction'='expense'
   AND public.lts_card_family_v226(r->>'description',r->>'account')=r->>'card_family'
   AND public.lts_forecast_series_key_v1(r->>'description')=r->>'series_key'
   AND coalesce(r->>'active','true')='true' AND r->>'ends_on' IS NOT NULL
 ), known AS MATERIALIZED (
  -- Canonical invoice/installment schedule already uses confirmed cash dates.
  SELECT k.* FROM lts_projection_private_v412.known_card_periods_v412(p_user_id)k
 ), reliable AS MATERIALIZED (
  SELECT k.series_key FROM known k GROUP BY k.series_key
  HAVING count(*)=count(DISTINCT k.reference_month)
   AND bool_and(coalesce(k.complete IS TRUE AND k.due_date IS NOT NULL
   AND k.reference_month IS NOT NULL AND isfinite(k.due_date) AND isfinite(k.reference_month) AND k.amount_brl IS NOT NULL
   AND k.amount_brl>=0 AND k.amount_brl::text NOT IN('NaN','Infinity','-Infinity')
   AND jsonb_typeof(k.source_refs)='array'
   AND jsonb_array_length(k.source_refs)>0,false))
 ), legacy AS MATERIALIZED (
  -- Preserve original obligations independently of whether flow currently emits
  -- them. A missing/invalid date or value prevents an exemption for that series.
  SELECT r.r->>'series_key' AS series_key,
   CASE WHEN pg_catalog.pg_input_is_valid(b.dados->>'dia','date') THEN
    CASE WHEN isfinite((b.dados->>'dia')::date) THEN public.lts_card_projection_date_v370(p_user_id,r.r->>'card_family',
     date_trunc('month',(b.dados->>'dia')::date)::date,(b.dados->>'dia')::date,NULL) END
   END AS cash_date,
   CASE WHEN pg_catalog.pg_input_is_valid(b.dados->>'valor','numeric')
    THEN (b.dados->>'valor')::numeric END AS amount
  FROM rules r JOIN public.evento_base b ON b.usuario_id=p_user_id
   AND public.lts_forecast_series_key_v1(b.dados->>'desc')=r.r->>'series_key'
   AND b.dados->>'efeito'='saida'
  -- Account labels are not an exclusion key here: legacy aliases may differ.
  -- Same-owner, same-series sources conservatively keep a month expected.
 ), events AS MATERIALIZED (
  SELECT r.r->>'series_key' AS series_key,f.event_date,f.amount
  FROM rules r JOIN public.financial_events f ON f.user_id=p_user_id
   AND public.lts_forecast_series_key_v1(coalesce(f.description_normalized,f.description_raw))=r.r->>'series_key'
   AND NOT f.is_suppressed AND (f.amount<0 OR f.amount IS NULL OR f.amount::text IN('NaN','Infinity','-Infinity'))
 ), months AS (
  SELECT r.r,g::date AS period_start
  FROM rules r CROSS JOIN LATERAL generate_series(date_trunc('month',p_as_of),
   p_horizon_end,interval '1 month')g
  -- Retain the entire cutoff month, including a mid-month cutoff, conservatively.
  WHERE g::date>(r.r->>'ends_on')::date
 )
 SELECT m.r->>'series_key',m.r->>'direction',m.period_start
 FROM months m JOIN reliable v ON v.series_key=m.r->>'series_key'
 WHERE NOT EXISTS(SELECT 1 FROM known k WHERE k.series_key=v.series_key
   AND date_trunc('month',k.due_date)::date=m.period_start AND k.amount_brl>0)
  AND NOT EXISTS(SELECT 1 FROM legacy l WHERE l.series_key=v.series_key
   AND (l.cash_date IS NULL OR NOT isfinite(l.cash_date) OR l.amount IS NULL OR l.amount<0 OR l.amount::text IN('NaN','Infinity','-Infinity')
    OR (l.amount>0 AND date_trunc('month',l.cash_date)::date=m.period_start)))
  AND NOT EXISTS(SELECT 1 FROM events e WHERE e.series_key=v.series_key
   AND (e.event_date IS NULL OR NOT isfinite(e.event_date) OR e.amount IS NULL OR e.amount::text IN('NaN','Infinity','-Infinity')
    OR date_trunc('month',e.event_date)::date=m.period_start));
END $function$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.card_budget_exempt_periods_v1(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.card_budget_exempt_periods_v1(uuid,date,date) TO service_role;

DO $migration$
DECLARE definition text:=pg_get_functiondef('public.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure);
BEGIN
 IF encode(sha256(convert_to(definition,'UTF8')),'hex')='07f78a2c34b0bfcc7c5b8915ceca051c062583b3362ab59bb0741bf420894e75' THEN RETURN; END IF;
 IF encode(sha256(convert_to(definition,'UTF8')),'hex')<>'0284be638b117f07c9d88ca342fc0b44cdcb15e249ec1fe677c7c6a062e01abc' THEN
  RAISE EXCEPTION 'Recurring gap audit changed; review its current definition before applying this migration.';
 END IF;
 definition:=replace(definition,$old0$), coverage AS MATERIALIZED (
 SELECT p.*,$old0$,$new0$), card_budget_exempt_v1 AS MATERIALIZED (
 SELECT e.* FROM params p CROSS JOIN LATERAL
  lts_projection_private_v412.card_budget_exempt_periods_v1(p_user_id,p.as_of,p.horizon_end)e
), coverage AS MATERIALIZED (
 SELECT p.*,EXISTS(SELECT 1 FROM card_budget_exempt_v1 e
  WHERE p.cadence='monthly' AND e.series_key=p.series_key AND e.direction=p.direction
   AND e.period_start=p.period_start) AS budget_not_expected,$new0$);
 definition:=replace(definition,$old1$c.future_count+c.actual_count=0 AND c.unconfirmed_count=0 AND c.cancelled_count=0 AND c.transition_count=0$old1$,$new1$c.future_count+c.actual_count=0 AND c.unconfirmed_count=0 AND c.cancelled_count=0 AND c.transition_count=0 AND NOT c.budget_not_expected$new1$);
 definition:=replace(definition,$old2$ jsonb_agg((jsonb_build_object('period_start',c.period_start,'period_end',c.period_end,'actual_events',c.actual_count,'future_events',c.future_count,'unconfirmed_obligations',c.unconfirmed_count,'unconfirmed_evidence',c.unconfirmed_evidence,'status',CASE WHEN c.future_count+c.actual_count>0 THEN 'covered' WHEN c.unconfirmed_count>0 THEN 'awaiting_payment_evidence' WHEN c.cancelled_count>0 THEN 'cancelled_by_owner' WHEN c.transition_count>0 THEN 'no_payment_due' ELSE 'review' END)||CASE WHEN c.transition_count>0 AND c.future_count+c.actual_count+c.unconfirmed_count+c.cancelled_count=0 THEN jsonb_build_object('confirmed_transition',c.transition_evidence) ELSE '{}'::jsonb END||CASE WHEN c.cancelled_count>0 THEN jsonb_build_object('confirmed_exceptions',c.confirmed_exceptions) ELSE '{}'::jsonb END) ORDER BY c.period_start) period_coverage,$old2$,$new2$ coalesce(jsonb_agg((jsonb_build_object('period_start',c.period_start,'period_end',c.period_end,'actual_events',c.actual_count,'future_events',c.future_count,'unconfirmed_obligations',c.unconfirmed_count,'unconfirmed_evidence',c.unconfirmed_evidence,'status',CASE WHEN c.future_count+c.actual_count>0 THEN 'covered' WHEN c.unconfirmed_count>0 THEN 'awaiting_payment_evidence' WHEN c.cancelled_count>0 THEN 'cancelled_by_owner' WHEN c.transition_count>0 THEN 'no_payment_due' ELSE 'review' END)||CASE WHEN c.transition_count>0 AND c.future_count+c.actual_count+c.unconfirmed_count+c.cancelled_count=0 THEN jsonb_build_object('confirmed_transition',c.transition_evidence) ELSE '{}'::jsonb END||CASE WHEN c.cancelled_count>0 THEN jsonb_build_object('confirmed_exceptions',c.confirmed_exceptions) ELSE '{}'::jsonb END) ORDER BY c.period_start) FILTER(WHERE NOT c.budget_not_expected OR c.future_count+c.actual_count+c.unconfirmed_count+c.cancelled_count+c.transition_count>0),'[]'::jsonb) period_coverage,$new2$);
 IF encode(sha256(convert_to(definition,'UTF8')),'hex')<>'07f78a2c34b0bfcc7c5b8915ceca051c062583b3362ab59bb0741bf420894e75' THEN RAISE EXCEPTION 'Unexpected recurring gap audit transformation.'; END IF;
 EXECUTE definition;
END $migration$;
COMMIT;
