-- Apply an owner's known-only rule to the open Aeternum cycle and its planning summaries.
CREATE OR REPLACE FUNCTION lts_recurring_private_v469.open_card_cycle_v478(
  result jsonb, cards jsonb, as_of_date date
) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $body$
DECLARE
  last_cash_month date;
  kept jsonb;
  removed jsonb;
  series_result jsonb := '[]';
  s jsonb;
  period jsonb;
  annual jsonb;
  periods jsonb;
  totals jsonb;
  reductions jsonb;
  amount numeric;
  covered numeric := 0;
  removed_total numeric;
BEGIN
  IF result IS NULL OR as_of_date IS NULL THEN RETURN result; END IF;
  -- The issuer may move a due date. Use the cash month of the current statement period.
  SELECT max(date_trunc('month', (cycle->>'due_date')::date)::date) INTO last_cash_month
  FROM jsonb_array_elements(coalesce(cards->'cards','[]')) c
  CROSS JOIN LATERAL jsonb_array_elements(coalesce(c->'cycles','[]')) cycle
  WHERE c->>'family' = 'aeternum'
    AND (cycle->>'month')::date = date_trunc('month',as_of_date)::date
    AND (cycle->>'due_date')::date >= as_of_date;
  last_cash_month := coalesce(last_cash_month,(date_trunc('month',as_of_date)+interval '1 month')::date);

  WITH entries AS (
    SELECT e, ord, split_part(e->>'source_ref',':',3) AS rule_key,
      coalesce(e->>'source' = 'planning_projection_v412' AND e->>'account' = 'Bradesco'
        AND (e->>'signed_amount')::numeric < 0
        AND e->>'source_ref' ~ '^projection:v469:(sub_[a-z0-9_]+|owner_[a-z_]+|pharmacy|hair|membership|prime_2990):[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        AND split_part(e->>'source_ref',':',4) = e->>'event_date'
        AND (e->>'event_date')::date > as_of_date
        AND date_trunc('month',(e->>'event_date')::date)::date <= last_cash_month,false) AS omit
    FROM jsonb_array_elements(coalesce(result->'events','[]')) WITH ORDINALITY t(e,ord)
  )
  SELECT coalesce(jsonb_agg(e ORDER BY ord) FILTER (WHERE NOT omit),'[]'),
    coalesce(jsonb_agg(jsonb_build_object(
      'series',CASE WHEN left(rule_key,4)='sub_' THEN 'subscription_'||substr(rule_key,5)
                    WHEN left(rule_key,6)='owner_' THEN rule_key ELSE 'recurring_'||rule_key END,
      'due',e->>'event_date','amount',-(e->>'signed_amount')::numeric
    )) FILTER (WHERE omit),'[]') INTO kept,removed
  FROM entries;
  IF removed = '[]'::jsonb THEN RETURN result; END IF;
  SELECT sum((x->>'amount')::numeric) INTO removed_total FROM jsonb_array_elements(removed)x;

  FOR s IN SELECT value FROM jsonb_array_elements(result->'series') LOOP
    SELECT jsonb_agg(x) INTO reductions FROM jsonb_array_elements(removed)x WHERE x->>'series'=s->>'series_key';
    IF reductions IS NOT NULL THEN
      periods := '[]';
      FOR period IN SELECT value FROM jsonb_array_elements(s->'coverage') LOOP
        SELECT sum((x->>'amount')::numeric) INTO amount
        FROM jsonb_array_elements(reductions)x WHERE x->>'due'=period->>'event_date';
        IF amount IS NOT NULL THEN
          IF (period->>'additional_brl')::numeric IS DISTINCT FROM amount THEN
            RAISE EXCEPTION 'Confira os valores previstos na fatura.';
          END IF;
          covered := covered + amount;
          period := period || jsonb_build_object('additional_brl',0,'status','open_cycle_known_only');
          IF period ? 'known_brl' THEN
            period := period || jsonb_build_object('budget_total_brl',(period->>'known_brl')::numeric);
          ELSIF period ? 'amount_brl' THEN
            period := period || jsonb_build_object('amount_brl',0);
          END IF;
        END IF;
        periods := periods || jsonb_build_array(period);
      END LOOP;
      totals := '[]';
      FOR annual IN SELECT value FROM jsonb_array_elements(s->'annual_totals') LOOP
        SELECT sum((x->>'amount')::numeric) INTO amount FROM jsonb_array_elements(reductions)x
        WHERE left(x->>'due',4)=annual->>'year';
        IF amount IS NOT NULL THEN
          annual := annual || jsonb_build_object(
            'budget_total_brl',(annual->>'budget_total_brl')::numeric - amount,
            'additional_brl',(annual->>'additional_brl')::numeric - amount);
        END IF;
        totals := totals || jsonb_build_array(annual);
      END LOOP;
      s := s || jsonb_build_object('coverage',periods,'annual_totals',totals);
    END IF;
    series_result := series_result || jsonb_build_array(s);
  END LOOP;
  IF covered IS DISTINCT FROM removed_total THEN RAISE EXCEPTION 'Confira a composição da fatura prevista.'; END IF;
  RETURN result || jsonb_build_object('events',kept,'series',series_result);
END
$body$;
REVOKE ALL ON FUNCTION lts_recurring_private_v469.open_card_cycle_v478(jsonb,jsonb,date) FROM PUBLIC;
