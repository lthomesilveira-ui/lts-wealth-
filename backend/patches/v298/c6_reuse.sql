-- V298: reuse the existing C6-only calendar and materialized source scope.
-- Keep every status, identity, calibration and ambiguity rule unchanged.
DO $patch$
DECLARE d text; before_oid oid; before_owner oid; before_acl aclitem[]; before_config text[]; before_security boolean; before_volatility "char";
BEGIN
 SELECT oid,pg_get_functiondef(oid),proowner,proacl,proconfig,prosecdef,provolatile INTO before_oid,d,before_owner,before_acl,before_config,before_security,before_volatility
 FROM pg_proc WHERE oid='public.lts_c6_cycle_identity_v269(uuid)'::regprocedure;
 IF md5(d)='8bb5a959015e5351c28820a39e987ca7' THEN RETURN; END IF;
 IF md5(d)<>'077677805193b3167ca5041f69863900' THEN RAISE EXCEPTION 'V298 C6 definition changed; inspect before applying'; END IF;
 IF strpos(d,$a0$AND public.lts_card_family_v226(ci.card_name,ci.card_name)='c6'$a0$)=0 THEN RAISE EXCEPTION 'V298 C6 anchor 0 changed'; END IF;
 d:=replace(d,$a0$AND public.lts_card_family_v226(ci.card_name,ci.card_name)='c6'$a0$,$b0$-- The materialized invoice calendar already contains only C6 rows.$b0$);
 IF strpos(d,$a1$FROM public.lts_open_finance_staging b JOIN public.lts_open_finance_staging tx$a1$)=0 THEN RAISE EXCEPTION 'V298 C6 anchor 1 changed'; END IF;
 d:=replace(d,$a1$FROM public.lts_open_finance_staging b JOIN public.lts_open_finance_staging tx$a1$,$b1$FROM public.lts_open_finance_staging b JOIN source_rows_v292 tx$b1$);
 EXECUTE d;
 IF md5(pg_get_functiondef(before_oid))<>'8bb5a959015e5351c28820a39e987ca7' THEN RAISE EXCEPTION 'V298 C6 replacement mismatch'; END IF;
 IF 'public.lts_c6_cycle_identity_v269(uuid)'::regprocedure::oid<>before_oid
 OR EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=before_oid AND (p.proowner<>before_owner OR p.proacl IS DISTINCT FROM before_acl OR p.proconfig IS DISTINCT FROM before_config OR p.prosecdef IS DISTINCT FROM before_security OR p.provolatile<>before_volatility))
 THEN RAISE EXCEPTION 'V298 C6 identity, privileges or configuration changed'; END IF;
END $patch$;
