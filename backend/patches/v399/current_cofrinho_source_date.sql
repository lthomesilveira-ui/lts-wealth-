-- The current amount and its disclosure must use the same dated position.
DO $patch$
DECLARE definition text;old_part text;
BEGIN
 definition:=pg_get_functiondef('public.lts_browser_cash_today_v178()'::regprocedure);
 IF position('v399-current-cofrinho-source-date'IN definition)>0 THEN RETURN;END IF;
 old_part:=$old$ SELECT (canonical_value->>'amount')::numeric,(canonical_value->>'as_of')::date INTO d0,d0_date
 FROM public.lts_validated_lock_registry WHERE lock_key='itau_cofrinho_20260926' AND superseded_at IS NULL;$old$;
 IF position(old_part IN definition)=0 THEN RAISE EXCEPTION 'V399 current Cofrinho disclosure source changed';END IF;
 definition:=replace(definition,old_part,$new$ -- v399-current-cofrinho-source-date
 SELECT (j->>'snapshot_brl')::numeric,(j->>'snapshot_date')::date INTO d0,d0_date
 FROM(SELECT public.lts_cofrinho_composition_v399(u,current_date)j)p;$new$);
 EXECUTE definition;
END $patch$;
