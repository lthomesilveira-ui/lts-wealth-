-- Install together with functions.sql in a single transaction.
DO $install$
DECLARE
 sig regprocedure; body text; n int; old_part text; new_part text;
BEGIN
 sig:='lts_recurring_private_v469.calculate(jsonb,jsonb,jsonb,jsonb,date)'::regprocedure; body:=pg_get_functiondef(sig);
 IF position('_specific_card_through' IN body)=0 THEN
  IF md5(body)<>'a0d45646467712aed1ff4a9284f2b025' THEN RAISE EXCEPTION 'Confira a versão do cálculo mensal.'; END IF;
  old_part:=$a$IF e->>'source_ref' LIKE 'projection:v468:%' AND coalesce((plan->>'centralize_card_forecasts')::boolean,false) THEN$a$;
  new_part:=$a$IF e->>'source_ref' LIKE 'projection:v468:%' AND coalesce((plan->>'centralize_card_forecasts')::boolean,false)
   AND (plan->>'_specific_card_through' IS NULL OR (e->>'event_date')::date>(plan->>'_specific_card_through')::date) THEN$a$;
  IF position(old_part IN body)=0 THEN RAISE EXCEPTION 'Confira os eventos do cartão.'; END IF;
  body:=replace(body,old_part,new_part);
  old_part:=$a$CASE WHEN x->>'status'='specific_recurring_forecast'
 THEN$a$;
  new_part:=$a$CASE WHEN x->>'status'='specific_recurring_forecast'
 AND (plan->>'_specific_card_through' IS NULL OR (x->>'event_date')::date>(plan->>'_specific_card_through')::date)
 THEN$a$;
  IF position(old_part IN body)=0 THEN RAISE EXCEPTION 'Confira as datas de cobertura.'; END IF;
  body:=replace(body,old_part,new_part);
  body:=replace(body,' ELSE x END ORDER BY ord)', $a$ WHEN plan->>'_specific_card_through' IS NOT NULL AND (x->>'event_date')::date<=(plan->>'_specific_card_through')::date
 THEN x||jsonb_build_object('account',s->>'account') ELSE x END ORDER BY ord)$a$);
  EXECUTE body;
 END IF;
 sig:='lts_recurring_private_v469.append_result(uuid,date,jsonb,jsonb,jsonb)'::regprocedure; body:=pg_get_functiondef(sig);
 IF position('bank_commitments_v479' IN body)=0 THEN
  IF md5(body)<>'51e4352506fefba45782a7dc9ea10df6' THEN RAISE EXCEPTION 'Confira a versão de projeção dos compromissos.'; END IF;
  old_part:='IF cards IS NULL THEN cards:=public.lts_card_cycles_v226(u);END IF;';
  IF position(old_part IN body)=0 OR position(E'\n RETURN base;' IN body)=0 THEN RAISE EXCEPTION 'Confira a integração do calendário.'; END IF;
  body:=replace(body,old_part,old_part||$a$
 IF plan ? 'recurrence_policy_v479' THEN
  plan:=plan||jsonb_build_object('_specific_card_through',lts_recurring_private_v469.open_cash_end_v479(cards,asof));
 END IF;$a$);
  body:=replace(body,E'\n RETURN base;', $a$
 IF plan ? 'recurrence_policy_v479' THEN
  base:=lts_recurring_private_v469.card_commitments_v479(base,cards,asof,plan->'recurrence_policy_v479');
  base:=lts_recurring_private_v469.bank_commitments_v479(base,baseline,
   lts_recurring_private_v469.posted_bank_v479(u,asof,plan->'recurrence_policy_v479'),asof,plan->'recurrence_policy_v479');
 END IF;
 RETURN base;$a$);
  EXECUTE body;
 END IF;
 sig:='lts_projection_private_v412.build(uuid,date)'::regprocedure; body:=pg_get_functiondef(sig);
 IF position('skip_current_estimate_v479' IN body)=0 THEN
  old_part:=$a$IF d<=p_as_of OR d>horizon OR d<(r->>'starts_on')::date OR d=ANY(seen_dates)$a$;
  IF md5(body)<>'c73dc489c3771e5b8861569a2001f5b6' OR position(old_part IN body)=0 THEN RAISE EXCEPTION 'Confira a versão das estimativas.'; END IF;
  EXECUTE replace(body,old_part,old_part||E'\n     OR lts_recurring_private_v469.skip_current_estimate_v479(policy,r,d,p_as_of)');
 END IF;
END $install$;
