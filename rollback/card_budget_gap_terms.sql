BEGIN;
DO $guard$
DECLARE current_definition text;
BEGIN
 IF to_regprocedure('lts_projection_private_v412.card_budget_exempt_periods_v1(uuid,date,date)') IS NOT NULL THEN
  current_definition:=pg_get_functiondef('lts_projection_private_v412.card_budget_exempt_periods_v1(uuid,date,date)'::regprocedure);
  IF encode(sha256(convert_to(current_definition,'UTF8')),'hex') IS DISTINCT FROM $expected_helper$85006af01b53c57921cf61989a18cfdf73aa6d673d73bb8ac17aff65077db4cb$expected_helper$ THEN RAISE EXCEPTION 'Card gap helper changed; review before applying.'; END IF;
 END IF;
END $guard$;
DO $migration$
DECLARE definition text:=pg_get_functiondef('public.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure);
BEGIN
 IF encode(sha256(convert_to(definition,'UTF8')),'hex')='0284be638b117f07c9d88ca342fc0b44cdcb15e249ec1fe677c7c6a062e01abc' THEN RETURN; END IF;
 IF encode(sha256(convert_to(definition,'UTF8')),'hex')<>'07f78a2c34b0bfcc7c5b8915ceca051c062583b3362ab59bb0741bf420894e75' THEN
  RAISE EXCEPTION 'Recurring gap audit changed; review its current definition before applying this migration.';
 END IF;
 definition:=replace(definition,$old0$ coalesce(jsonb_agg((jsonb_build_object('period_start',c.period_start,'period_end',c.period_end,'actual_events',c.actual_count,'future_events',c.future_count,'unconfirmed_obligations',c.unconfirmed_count,'unconfirmed_evidence',c.unconfirmed_evidence,'status',CASE WHEN c.future_count+c.actual_count>0 THEN 'covered' WHEN c.unconfirmed_count>0 THEN 'awaiting_payment_evidence' WHEN c.cancelled_count>0 THEN 'cancelled_by_owner' WHEN c.transition_count>0 THEN 'no_payment_due' ELSE 'review' END)||CASE WHEN c.transition_count>0 AND c.future_count+c.actual_count+c.unconfirmed_count+c.cancelled_count=0 THEN jsonb_build_object('confirmed_transition',c.transition_evidence) ELSE '{}'::jsonb END||CASE WHEN c.cancelled_count>0 THEN jsonb_build_object('confirmed_exceptions',c.confirmed_exceptions) ELSE '{}'::jsonb END) ORDER BY c.period_start) FILTER(WHERE NOT c.budget_not_expected OR c.future_count+c.actual_count+c.unconfirmed_count+c.cancelled_count+c.transition_count>0),'[]'::jsonb) period_coverage,$old0$,$new0$ jsonb_agg((jsonb_build_object('period_start',c.period_start,'period_end',c.period_end,'actual_events',c.actual_count,'future_events',c.future_count,'unconfirmed_obligations',c.unconfirmed_count,'unconfirmed_evidence',c.unconfirmed_evidence,'status',CASE WHEN c.future_count+c.actual_count>0 THEN 'covered' WHEN c.unconfirmed_count>0 THEN 'awaiting_payment_evidence' WHEN c.cancelled_count>0 THEN 'cancelled_by_owner' WHEN c.transition_count>0 THEN 'no_payment_due' ELSE 'review' END)||CASE WHEN c.transition_count>0 AND c.future_count+c.actual_count+c.unconfirmed_count+c.cancelled_count=0 THEN jsonb_build_object('confirmed_transition',c.transition_evidence) ELSE '{}'::jsonb END||CASE WHEN c.cancelled_count>0 THEN jsonb_build_object('confirmed_exceptions',c.confirmed_exceptions) ELSE '{}'::jsonb END) ORDER BY c.period_start) period_coverage,$new0$);
 definition:=replace(definition,$old1$c.future_count+c.actual_count=0 AND c.unconfirmed_count=0 AND c.cancelled_count=0 AND c.transition_count=0 AND NOT c.budget_not_expected$old1$,$new1$c.future_count+c.actual_count=0 AND c.unconfirmed_count=0 AND c.cancelled_count=0 AND c.transition_count=0$new1$);
 definition:=replace(definition,$old2$), card_budget_exempt_v1 AS MATERIALIZED (
 SELECT e.* FROM params p CROSS JOIN LATERAL
  lts_projection_private_v412.card_budget_exempt_periods_v1(p_user_id,p.as_of,p.horizon_end)e
), coverage AS MATERIALIZED (
 SELECT p.*,EXISTS(SELECT 1 FROM card_budget_exempt_v1 e
  WHERE p.cadence='monthly' AND e.series_key=p.series_key AND e.direction=p.direction
   AND e.period_start=p.period_start) AS budget_not_expected,$old2$,$new2$), coverage AS MATERIALIZED (
 SELECT p.*,$new2$);
 IF encode(sha256(convert_to(definition,'UTF8')),'hex')<>'0284be638b117f07c9d88ca342fc0b44cdcb15e249ec1fe677c7c6a062e01abc' THEN RAISE EXCEPTION 'Unexpected recurring gap audit transformation.'; END IF;
 EXECUTE definition;
END $migration$;
DROP FUNCTION IF EXISTS lts_projection_private_v412.card_budget_exempt_periods_v1(uuid,date,date);
COMMIT;
