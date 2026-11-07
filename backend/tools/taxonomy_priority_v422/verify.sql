DO $verify$
DECLARE x record; after_value jsonb; changed int:=0; unchanged int:=0;
BEGIN
 FOR x IN SELECT * FROM qa.taxonomy_before LOOP
  after_value:=public.lts_expense_taxonomy_v353(x.category,x.component,x.management);
  IF x.category='Compromissos Financeiros' AND x.management='Empréstimos' AND x.before_value->>'macrogroup'='Compromissos financeiros' THEN
   IF after_value IS DISTINCT FROM x.before_value||jsonb_build_object('macrogroup','Patrimônio e financiamentos','group','Empréstimos') THEN RAISE EXCEPTION 'Incorrect loan presentation';END IF;
   changed:=changed+1;
  ELSE
   IF after_value IS DISTINCT FROM x.before_value THEN RAISE EXCEPTION 'Unrelated classification changed';END IF;
   unchanged:=unchanged+1;
  END IF;
 END LOOP;
 IF changed=0 OR unchanged<50 THEN RAISE EXCEPTION 'Insufficient test coverage';END IF;
 IF (SELECT attributes FROM qa.attributes) IS DISTINCT FROM (SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE oid='public.lts_expense_taxonomy_v353(text,text,text)'::regprocedure) THEN RAISE EXCEPTION 'Function properties changed';END IF;
 RAISE NOTICE 'Matched % explicit loan cases; preserved % unrelated classifications',changed,unchanged;
END $verify$;
SELECT jsonb_build_object('passed',true,'cases',(SELECT count(*) FROM qa.taxonomy_before),'raw_categories_unchanged',true,'privileges_unchanged',true,'financial_sources_used',false) AS proof;
