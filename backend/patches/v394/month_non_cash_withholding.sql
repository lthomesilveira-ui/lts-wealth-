-- The canonical Flow exposes payroll withholding for economic attribution,
-- while its salary cash leg is already net. Never count that leg as cash again.
DO $patch$
DECLARE d text:=pg_get_functiondef('lts_month_private_v393.build(jsonb,jsonb,date,date,date)'::regprocedure);
 old_part text:=$old$IF amount=0 OR coalesce((e->>'internal_transfer')::boolean,false)$old$;
 new_part text:=$new$IF amount=0 OR e->>'source'='economic_withholding' OR coalesce((e->>'internal_transfer')::boolean,false)$new$;
BEGIN
 IF position(new_part IN d)>0 THEN RETURN;END IF;
 IF md5(d)<>'ba58c7bd94e794c87f1e6d7a1dca9a37' OR position(old_part IN d)=0 THEN RAISE EXCEPTION 'Monthly cash reader changed';END IF;
 EXECUTE replace(d,old_part,new_part);
END $patch$;
