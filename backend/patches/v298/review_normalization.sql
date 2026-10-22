-- V298: normalize the same category strings once within each canonical query.
-- Classification precedence, raw labels, null behavior and all financial fields are unchanged.
DO $patch$
DECLARE d text; before_oid oid; before_owner oid; before_acl aclitem[]; before_config text[]; before_security boolean; before_volatility "char";
BEGIN
 SELECT oid,pg_get_functiondef(oid),proowner,proacl,proconfig,prosecdef,provolatile INTO before_oid,d,before_owner,before_acl,before_config,before_security,before_volatility
 FROM pg_proc WHERE oid='public.lts_expense_rows_v230_baseline(uuid,date,date)'::regprocedure;
 IF md5(d)='24c9b55478e02403bdca12003f5f22fe' THEN RETURN; END IF;
 IF md5(d)<>'4b244b0ef223b50268ebc2de48235dd9' THEN RAISE EXCEPTION 'V298 baseline definition changed; inspect before applying'; END IF;
 IF strpos(d,$a0$pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')$a0$)=0 THEN RAISE EXCEPTION 'V298 normalization anchor 0 changed'; END IF;
 d:=replace(d,$a0$pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')$a0$,$b0$category_key_v298$b0$);
 IF strpos(d,$a1$pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(original_category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')$a1$)=0 THEN RAISE EXCEPTION 'V298 normalization anchor 1 changed'; END IF;
 d:=replace(d,$a1$pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(original_category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')$a1$,$b1$original_category_key_v298$b1$);
 IF strpos(d,$a2$SELECT e.*,public.lts_expense_management_group_v3(coalesce(category_decision,category),center_cost,counterparty,origin_name,coverage_mode) old_group FROM enriched e$a2$)=0 THEN RAISE EXCEPTION 'V298 normalization anchor 2 changed'; END IF;
 d:=replace(d,$a2$SELECT e.*,public.lts_expense_management_group_v3(coalesce(category_decision,category),center_cost,counterparty,origin_name,coverage_mode) old_group FROM enriched e$a2$,$b2$SELECT e.*,public.lts_expense_management_group_v3(coalesce(category_decision,category),center_cost,counterparty,origin_name,coverage_mode) old_group,
 pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') category_key_v298,
 pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(original_category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') original_category_key_v298 FROM enriched e$b2$);
 IF strpos(d,$a3$from src where sr is not null order by st,sr,priority,descr,cat$a3$)=0 THEN RAISE EXCEPTION 'V298 normalization anchor 3 changed'; END IF;
 d:=replace(d,$a3$from src where sr is not null order by st,sr,priority,descr,cat$a3$,$b3$from src where sr is not null
 AND EXISTS(SELECT 1 FROM b source_key_v298 WHERE source_key_v298.source_table=src.st AND source_key_v298.source_ref=src.sr)
 order by st,sr,priority,descr,cat$b3$);
 EXECUTE d;
 IF md5(pg_get_functiondef(before_oid))<>'24c9b55478e02403bdca12003f5f22fe' THEN RAISE EXCEPTION 'V298 baseline replacement mismatch'; END IF;
 IF 'public.lts_expense_rows_v230_baseline(uuid,date,date)'::regprocedure::oid<>before_oid
 OR EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=before_oid AND (p.proowner<>before_owner OR p.proacl IS DISTINCT FROM before_acl OR p.proconfig IS DISTINCT FROM before_config OR p.prosecdef IS DISTINCT FROM before_security OR p.provolatile<>before_volatility))
 THEN RAISE EXCEPTION 'V298 baseline identity, privileges or configuration changed'; END IF;
END $patch$;
