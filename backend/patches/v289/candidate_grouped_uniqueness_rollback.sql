-- Trial only. Keeps multiplicity and ordinary SQL null equality.
BEGIN;
DO $v289$
DECLARE d text; prior_oid oid; prior_owner oid; prior_acl aclitem[]; prior_config text[]; prior_security boolean;
BEGIN
 SELECT p.oid,pg_get_functiondef(p.oid),p.proowner,p.proacl,p.proconfig,p.prosecdef
 INTO prior_oid,d,prior_owner,prior_acl,prior_config,prior_security
 FROM pg_proc p WHERE p.oid='public.lts_expense_effective_rows_v176(uuid,date,date)'::regprocedure;
 IF md5(d)<>'13b18a77b393aa74e679b6b71094f698' THEN RAISE EXCEPTION 'V289 source definition lease changed'; END IF;
 IF (length(d)-length(replace(d,$anchor$cert AS MATERIALIZED($anchor$,'')))/length($anchor$cert AS MATERIALIZED($anchor$)<>1
 OR (length(d)-length(replace(d,$anchor$(SELECT count(*) FROM base x WHERE x.source_table=b.source_table AND x.source_ref=b.source_ref AND x.competence_month=b.competence_month)=1$anchor$,'')))/length($anchor$(SELECT count(*) FROM base x WHERE x.source_table=b.source_table AND x.source_ref=b.source_ref AND x.competence_month=b.competence_month)=1$anchor$)<>1
 THEN RAISE EXCEPTION 'V289 query anchor lease changed'; END IF;
 d:=replace(d,$anchor$cert AS MATERIALIZED($anchor$,$replacement$base_unique_v289 AS MATERIALIZED (
 SELECT source_table,source_ref,competence_month FROM base
 GROUP BY source_table,source_ref,competence_month HAVING count(*)=1
),
cert AS MATERIALIZED($replacement$);
 d:=replace(d,$anchor$(SELECT count(*) FROM base x WHERE x.source_table=b.source_table AND x.source_ref=b.source_ref AND x.competence_month=b.competence_month)=1$anchor$,
 $replacement$EXISTS(SELECT 1 FROM base_unique_v289 x WHERE x.source_table=b.source_table AND x.source_ref=b.source_ref AND x.competence_month=b.competence_month)$replacement$);
 EXECUTE d;
 IF 'public.lts_expense_effective_rows_v176(uuid,date,date)'::regprocedure::oid<>prior_oid
 OR EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=prior_oid AND
 (p.proowner<>prior_owner OR p.proacl IS DISTINCT FROM prior_acl OR p.proconfig IS DISTINCT FROM prior_config OR p.prosecdef IS DISTINCT FROM prior_security))
 THEN RAISE EXCEPTION 'V289 identity or privilege drift'; END IF;
END $v289$;
DO $v289$
DECLARE d text; prior_oid oid; prior_owner oid; prior_acl aclitem[]; prior_config text[]; prior_security boolean;
BEGIN
 SELECT p.oid,pg_get_functiondef(p.oid),p.proowner,p.proacl,p.proconfig,p.prosecdef
 INTO prior_oid,d,prior_owner,prior_acl,prior_config,prior_security
 FROM pg_proc p WHERE p.oid='public.lts_expense_effective_rows_pre_v268(uuid,date,date)'::regprocedure;
 IF md5(d)<>'de945f60b8211ab7f0c723938098e897' THEN RAISE EXCEPTION 'V289 source definition lease changed'; END IF;
 IF (length(d)-length(replace(d,$anchor$), replaced AS MATERIALIZED($anchor$,'')))/length($anchor$), replaced AS MATERIALIZED($anchor$)<>1
 OR (length(d)-length(replace(d,$anchor$SELECT 1 FROM scoped workbook WHERE workbook.competence_month=c.reference_month
 AND workbook.coverage_mode='card_category_allocated_workbook_v176'$anchor$,'')))/length($anchor$SELECT 1 FROM scoped workbook WHERE workbook.competence_month=c.reference_month
 AND workbook.coverage_mode='card_category_allocated_workbook_v176'$anchor$)<>1
 THEN RAISE EXCEPTION 'V289 query anchor lease changed'; END IF;
 d:=replace(d,$anchor$), replaced AS MATERIALIZED($anchor$,$replacement$), workbook_months_v289 AS MATERIALIZED (
 SELECT DISTINCT competence_month FROM scoped
 WHERE coverage_mode='card_category_allocated_workbook_v176'
), replaced AS MATERIALIZED($replacement$);
 d:=replace(d,$anchor$SELECT 1 FROM scoped workbook WHERE workbook.competence_month=c.reference_month
 AND workbook.coverage_mode='card_category_allocated_workbook_v176'$anchor$,
 $replacement$SELECT 1 FROM workbook_months_v289 workbook WHERE workbook.competence_month=c.reference_month$replacement$);
 EXECUTE d;
 IF 'public.lts_expense_effective_rows_pre_v268(uuid,date,date)'::regprocedure::oid<>prior_oid
 OR EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=prior_oid AND
 (p.proowner<>prior_owner OR p.proacl IS DISTINCT FROM prior_acl OR p.proconfig IS DISTINCT FROM prior_config OR p.prosecdef IS DISTINCT FROM prior_security))
 THEN RAISE EXCEPTION 'V289 identity or privilege drift'; END IF;
END $v289$;
ROLLBACK;
