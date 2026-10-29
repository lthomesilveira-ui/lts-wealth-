-- Keep the recurrence worker at least five full years ahead of any as-of day.
-- Existing plan amounts, validity, exclusions and private execution ACL stay intact.
DO $patch$
DECLARE definition text; before_meta jsonb; after_meta jsonb;
 old_line constant text:=$old$ horizon:=(date_trunc('year',p_as_of)+interval '5 years'-interval '1 day')::date;$old$;
 new_line constant text:=$new$ /* v376-at-least-five-future-years */
 horizon:=(date_trunc('year',p_as_of)+interval '6 years'-interval '1 day')::date;$new$;
 expected constant text:='43af1cb523961b60dd3d4e2fb6a006c9';
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO STRICT definition,before_meta
 FROM pg_proc p WHERE p.oid='public.lts_recurring_materialize_v366(uuid,date)'::regprocedure;
 IF strpos(definition,'/* v376-at-least-five-future-years */')>0 THEN
  IF md5(replace(definition,new_line,old_line))<>expected THEN RAISE EXCEPTION 'V376 recurrence worker changed after installation';END IF;
  RETURN;
 END IF;
 IF md5(definition)<>expected OR strpos(definition,old_line)=0 THEN RAISE EXCEPTION 'V376 recurrence worker lease mismatch';END IF;
 EXECUTE replace(definition,old_line,new_line);
 SELECT to_jsonb(p)-'prosrc' INTO STRICT after_meta FROM pg_proc p WHERE p.oid='public.lts_recurring_materialize_v366(uuid,date)'::regprocedure;
 IF before_meta IS DISTINCT FROM after_meta THEN RAISE EXCEPTION 'V376 recurrence metadata or ACL changed';END IF;
 IF md5(replace(pg_get_functiondef('public.lts_recurring_materialize_v366(uuid,date)'::regprocedure),new_line,old_line))<>expected THEN RAISE EXCEPTION 'V376 recurrence patch changed unrelated code';END IF;
END $patch$;
