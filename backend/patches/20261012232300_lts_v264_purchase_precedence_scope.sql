-- V264: limit original-category precedence to the proven Presentes / merchant-Vestuário conflict.
DO $patch$ DECLARE d text; BEGIN
 SELECT pg_get_functiondef('public.lts_expense_rows_v230_baseline(uuid,date,date)'::regprocedure) INTO d;
 IF md5(d)<>'01f5fa0bf8a7435370a9a4046389e75c' THEN RAISE EXCEPTION 'source lease changed'; END IF;
 d:=replace(d,$old$and x.source_ref IN(cd.line_key,cd.purchase_key)$old$,$new$and x.source_ref IN(cd.line_key,cd.purchase_key)
   -- Only this proved collision is overridden. Keep finer approved
   -- purposes (such as Batizado), beneficiary refinements and other
   -- current semantic categories intact; placeholders are never evidence.
   and public.lts_v178_norm(cd.category)='presentes'
   and public.lts_v178_norm(x.category)='vestuario'$new$);
 EXECUTE d;
END $patch$;
