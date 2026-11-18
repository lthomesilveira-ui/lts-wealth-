-- Run functions.sql and this installation in one transaction.
DO $install$
DECLARE
  signature regprocedure := 'lts_recurring_private_v469.append_result(uuid,date,jsonb,jsonb,jsonb)'::regprocedure;
  before_sql text := pg_get_functiondef(signature);
  old_return text := 'RETURN lts_budget_private_v470.append_result(u,asof,lts_recurring_private_v469.calculate(plan,base,calendar,paid,asof),cards,baseline);';
  new_return text := 'base := lts_budget_private_v470.append_result(u,asof,lts_recurring_private_v469.calculate(plan,base,calendar,paid,asof),cards,baseline);
 IF plan->>''open_aeternum_cycle_known_only'' = ''true'' THEN
   base := lts_recurring_private_v469.open_card_cycle_v478(base,cards,asof);
 END IF;
 RETURN base;';
BEGIN
  IF position(new_return in before_sql)>0 THEN RETURN; END IF;
  IF md5(before_sql)<>'cdb4c1b3eb4910ec0c2ac98b5656dcba' OR position(old_return in before_sql)=0 THEN
    RAISE EXCEPTION 'A definição de planejamento mudou. Confira a versão instalada.';
  END IF;
  EXECUTE replace(before_sql,old_return,new_return);
END
$install$;
