CREATE OR REPLACE FUNCTION lts_recurring_private_v469.append_result(u uuid, asof date, base jsonb, cards jsonb, baseline jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE plan jsonb:=lts_recurring_private_v469.owner_plan(u); calendar jsonb;paid jsonb;school_source jsonb;horizon date:=(base->>'horizon_end')::date;
BEGIN
 IF plan IS NULL THEN RETURN base;END IF;
 IF cards IS NULL THEN cards:=public.lts_card_cycles_v226(u);END IF;
 -- Reject a changed future school source instead of overwriting a user edit.
 FOR school_source IN SELECT value FROM jsonb_array_elements(plan->'school_sources') WHERE (value->>'event_date')::date>asof LOOP
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(baseline)b WHERE b->>'source_ref'=school_source->>'source_ref'
   AND b->>'event_date'=school_source->>'event_date' AND b->>'account'=plan->>'school_account'
   AND (b->>'signed_amount')::numeric=-(plan->>'school_total_brl')::numeric AND b->>'description'=plan->>'school_original_description')
  THEN RAISE EXCEPTION 'Uma previsão da escola foi alterada. Confira as datas e os valores.';END IF;
 END LOOP;
 WITH items AS MATERIALIZED(
  SELECT ca->>'family' family,date_trunc('month',(cy->>'due_date')::date)::date cash_month,cy->>'amount' cycle_amount,i,
   public.lts_v178_norm(i->>'category') cat,
   (SELECT sum(abs((b->>'signed_amount')::numeric)) FROM jsonb_array_elements(baseline)b
    WHERE (b->>'signed_amount')::numeric<0 AND public.lts_card_family_v226(b->>'description',b->>'account')=ca->>'family'
    AND date_trunc('month',(b->>'event_date')::date)=date_trunc('month',(cy->>'due_date')::date)) base_amount
  FROM jsonb_array_elements(cards->'cards')ca CROSS JOIN LATERAL jsonb_array_elements(ca->'cycles')cy
  CROSS JOIN LATERAL jsonb_array_elements(cy->'items')i
  WHERE (cy->>'due_date')::date>asof AND coalesce(i->>'is_payment','false')<>'true' AND (i->>'amount')::numeric>0
 ), matched AS MATERIALIZED(
  SELECT r->>'id' id,t.* FROM jsonb_array_elements(plan->'budgets')r JOIN items t ON
   (r->>'id'='pharmacy' AND t.cat='farmacia') OR (r->>'id'='hair' AND t.cat IN('cabelereiro','cabeleireiro'))
   OR (r->>'id'='membership' AND (t.cat='socio rei' OR public.lts_bank_merchant_key_v231(t.i->>'description') LIKE '%sociorei%'))
   OR (r->>'id'='prime_2990' AND t.family='bradesco_prime' AND (t.i->>'amount')::numeric=(r->>'amount_brl')::numeric)
 ), slots AS(
  SELECT r->>'id' id,d::date cash_month FROM jsonb_array_elements(plan->'budgets')r
  CROSS JOIN generate_series((plan->>'budget_start_month')::date,date_trunc('month',horizon),interval '1 month')d
 ) SELECT jsonb_agg(jsonb_build_object('id',s.id,'cash_month',s.cash_month,
  'known_brl',coalesce((SELECT sum((t.i->>'amount')::numeric) FROM matched t WHERE t.id=s.id AND t.cash_month=s.cash_month),0),
  'trusted',coalesce(cards->>'complete','false')='true'
   AND NOT EXISTS(SELECT 1 FROM matched t WHERE t.id=s.id AND t.cash_month=s.cash_month
    AND (nullif(t.i->>'source_id','') IS NULL OR t.base_amount IS NULL OR abs(t.base_amount-t.cycle_amount::numeric)>0.005))))
 INTO calendar FROM slots s;
 SELECT coalesce(jsonb_agg(DISTINCT jsonb_build_object('id',CASE WHEN description_raw ILIKE plan->>'school_tuition_match' THEN 'school_tuition' ELSE 'school_food' END,
  'cash_month',date_trunc('month',posting_date)::date)),'[]') INTO paid
 FROM public.lts_open_finance_staging WHERE user_id=u AND resource_type='transaction' AND currency='BRL'
 AND provider_deleted_at IS NULL AND normalized_payload->>'status'='POSTED'
 AND posting_date BETWEEN date_trunc('month',asof)::date AND asof
 AND ((description_raw ILIKE plan->>'school_tuition_match' AND signed_amount=-(plan->>'school_tuition_brl')::numeric)
  OR (description_raw ILIKE plan->>'school_food_match' AND -signed_amount IN(SELECT value::numeric FROM jsonb_array_elements_text(plan->'school_known_food_amounts'))));
 RETURN lts_recurring_private_v469.calculate(plan,base,calendar,paid,asof);
END $function$
