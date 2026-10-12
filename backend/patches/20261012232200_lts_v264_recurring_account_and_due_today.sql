-- V264: institutional code is the account identity; a due-today obligation remains projected.
DO $patch$ DECLARE d text; BEGIN
 SELECT pg_get_functiondef('public.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure) INTO d;
 IF md5(d)<>'2f36d7187b0c8b0389ae20db1e919556' THEN RAISE EXCEPTION 'source lease changed'; END IF;
 d:=replace(d,$old$h.account=s.institution_name$old$,$new$h.account=CASE s.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' ELSE s.institution_name END$new$);
 d:=replace(d,$old$p.as_of+1,p.horizon_end$old$,$new$p.as_of,p.horizon_end$new$);
 EXECUTE d;
END $patch$;
