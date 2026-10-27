DO $patch$
DECLARE d text;a jsonb;t regprocedure:='public.lts_browser_expenses_v229(date,date)'::regprocedure;
BEGIN
 SELECT pg_get_functiondef(oid),to_jsonb(p)-'prosrc'INTO d,a FROM pg_proc p WHERE oid=t;
 IF md5(d)<>'7e10dae22553dfd0d49cdf0599209dce'THEN RAISE EXCEPTION 'V353_EXPENSE_SOURCE_CHANGED';END IF;
 d:=replace(d,$old$ result:=public.lts_browser_expenses_v229_engine_v251(p_from,p_to);$old$,$new$ result:=public.lts_browser_expenses_v229_engine_v251(p_from,p_to);
 result:=result||jsonb_build_object('presentation',public.lts_expense_presentation_v353(u,p_from,p_to,'{}'));$new$);
 d:=replace(d,'expenses-v251:','expenses-v353:');EXECUTE d;
 IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid=t)THEN RAISE EXCEPTION 'V353_READER_ATTRIBUTES_CHANGED';END IF;
END $patch$;
