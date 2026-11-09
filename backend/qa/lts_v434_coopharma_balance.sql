\set ON_ERROR_STOP on
\ir v309_fixture.sql
\ir v309_realized_dependency.sql
\ir ../patches/v309/contract_read_state.sql
\ir ../patches/v357/dated_debt_projection.sql

CREATE FUNCTION pg_temp.summary_at(owner_id uuid, position_day date)
RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT public.lts_commitment_summary_overlay_v309(owner_id,position_day,
  public.lts_commitments_summary_v1(owner_id,position_day) ||
  '{"version":"commitments-summary-v2-documentary"}'::jsonb)
$$;

CREATE TEMP TABLE previous_reader AS
SELECT oid,to_jsonb(p)-'prosrc' attributes
FROM pg_proc p WHERE oid='public.lts_commitment_summary_overlay_v309(uuid,date,jsonb)'::regprocedure;

CREATE TEMP TABLE previous_commitments AS
SELECT pg_temp.summary_at('00000000-0000-4000-8000-000000000001','2020-10-24') AS result;

\ir ../patches/v434/coopharma_dated_balance.sql
\ir ../patches/v434/coopharma_dated_balance.sql

DO $test$
DECLARE
 owner_id uuid := '00000000-0000-4000-8000-000000000001';
 other_id uuid := '00000000-0000-4000-8000-000000000002';
 report_day date := '2020-10-24';
 result jsonb;
 coopharma jsonb;
 debt jsonb;
 candidate numeric;
BEGIN
 IF pg_temp.summary_at(owner_id,report_day) IS DISTINCT FROM (SELECT previous_commitments.result FROM previous_commitments)
 THEN RAISE EXCEPTION 'A schedule without a balance must stay unchanged'; END IF;

 INSERT INTO public.lts_debt_position
 VALUES ('00000000-0000-4000-8000-000000000705',owner_id,'coopharma','2020-10-22',
  'Coopharma','SYNTHETIC-PAYROLL',54.32,'documented','Synthetic creditor observation',
  '{"remaining_installments":2,"remaining_schedule_current_terms":70}',now());
 result := pg_temp.summary_at(owner_id,report_day);
 SELECT c INTO STRICT coopharma FROM jsonb_array_elements(result->'commitments') c WHERE c->>'id'='coopharma';
 IF coopharma->'current_documentary_debt_balance' IS DISTINCT FROM '54.32'::jsonb
  OR coopharma->>'current_debt_as_of' IS DISTINCT FROM '2020-10-22'
  OR coopharma->'remaining_economic_outflow' IS DISTINCT FROM '70'::jsonb
  OR coopharma->'confirmed_loaded_paid_amount' IS DISTINCT FROM '10'::jsonb
  OR coopharma->>'next_due' IS DISTINCT FROM '2020-10-31'
  OR coopharma->>'cash_treatment' IS DISTINCT FROM
   (SELECT x->>'cash_treatment' FROM previous_commitments b,jsonb_array_elements(b.result->'commitments') x WHERE x->>'id'='coopharma')
 THEN RAISE EXCEPTION 'Dated balance and installment contract differ: %',coopharma; END IF;

 IF (SELECT jsonb_agg(c ORDER BY c->>'id') FROM jsonb_array_elements(result->'commitments') c WHERE c->>'id'<>'coopharma')
  IS DISTINCT FROM (SELECT jsonb_agg(c ORDER BY c->>'id') FROM previous_commitments b,jsonb_array_elements(b.result->'commitments') c WHERE c->>'id'<>'coopharma')
 THEN RAISE EXCEPTION 'An unrelated commitment changed'; END IF;

 debt := public.lts_debt_evidence_projection_v357(result,report_day);
 IF debt->'documented_subtotal' IS DISTINCT FROM '954.32'::jsonb
  OR debt->'complete' IS DISTINCT FROM 'false'::jsonb
  OR debt->'total_debt' IS DISTINCT FROM 'null'::jsonb
 THEN RAISE EXCEPTION 'Patrimony did not use the documented balance exactly once: %',debt; END IF;

 IF EXISTS(SELECT 1 FROM jsonb_array_elements(pg_temp.summary_at(owner_id,'2020-10-21')->'commitments') c
     WHERE c->>'id'='coopharma' AND c->>'current_documentary_debt_balance' IS NOT NULL)
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(pg_temp.summary_at(other_id,report_day)->'commitments') c
     WHERE c->>'id'='coopharma' AND c->>'current_documentary_debt_balance' IS NOT NULL)
 THEN RAISE EXCEPTION 'Dated balance leaked into a prior date or another owner'; END IF;

 FOREACH candidate IN ARRAY ARRAY[-1::numeric,'Infinity'::numeric,'NaN'::numeric,NULL::numeric] LOOP
  UPDATE public.lts_debt_position SET debt_balance=candidate WHERE commitment_id='coopharma' AND as_of_date='2020-10-22';
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(pg_temp.summary_at(owner_id,report_day)->'commitments') c
      WHERE c->>'id'='coopharma' AND c->>'current_documentary_debt_balance' IS NOT NULL)
  THEN RAISE EXCEPTION 'Invalid balance exposed: %',candidate; END IF;
 END LOOP;
 UPDATE public.lts_debt_position SET debt_balance=0 WHERE commitment_id='coopharma' AND as_of_date='2020-10-22';
 IF (SELECT c->'current_documentary_debt_balance' FROM jsonb_array_elements(pg_temp.summary_at(owner_id,report_day)->'commitments') c
     WHERE c->>'id'='coopharma') IS DISTINCT FROM '0'::jsonb
 THEN RAISE EXCEPTION 'Explicit documented zero was lost'; END IF;

 UPDATE public.lts_debt_position SET status='estimated',debt_balance=54.32 WHERE commitment_id='coopharma' AND as_of_date='2020-10-22';
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(pg_temp.summary_at(owner_id,report_day)->'commitments') c
      WHERE c->>'id'='coopharma' AND c->>'current_documentary_debt_balance' IS NOT NULL)
 THEN RAISE EXCEPTION 'An estimate was promoted to a documented balance'; END IF;

 IF NOT EXISTS(SELECT 1 FROM previous_reader b JOIN pg_proc p ON p.oid=b.oid
    WHERE b.attributes=to_jsonb(p)-'prosrc')
 OR has_function_privilege('anon','public.lts_commitment_summary_overlay_v309(uuid,date,jsonb)','execute')
 OR has_function_privilege('authenticated','public.lts_commitment_summary_overlay_v309(uuid,date,jsonb)','execute')
 THEN RAISE EXCEPTION 'Reader attributes or grants changed'; END IF;
END $test$;
SELECT 'V434 native balance, chronology, owner isolation and installment separation passed';
