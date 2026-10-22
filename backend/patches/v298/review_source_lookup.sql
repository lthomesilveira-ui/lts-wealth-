-- V298: indexable source identity lookups and a query-local expense subset.
-- Financial sources, evidence masks, multiplicity, RPC contracts and timeouts stay exact.
DO $patch$
DECLARE d text; before_oid oid; before_owner oid; before_acl aclitem[]; before_config text[]; before_security boolean; before_volatility "char";
BEGIN
 SELECT oid,pg_get_functiondef(oid),proowner,proacl,proconfig,prosecdef,provolatile INTO before_oid,d,before_owner,before_acl,before_config,before_security,before_volatility
 FROM pg_proc WHERE oid='public.lts_expense_rows_pre_categories_v290(uuid,date,date)'::regprocedure;
 IF md5(d)='0d845b5e55b0505af153d66adfcd6ea4' THEN RETURN; END IF;
 IF md5(d)<>'e4e25fa5c5ec9c4bd5225aff371f2e4e' THEN RAISE EXCEPTION 'V298 reader definition changed; inspect before applying'; END IF;
 IF strpos(d,$a0$r.id::text=x.c->>'representative_id'$a0$)=0 THEN RAISE EXCEPTION 'V298 anchor 0 changed'; END IF;
 d:=replace(d,$a0$r.id::text=x.c->>'representative_id'$a0$,$b0$r.id::text=x.c->>'representative_id' AND r.id=CASE WHEN x.c->>'representative_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (x.c->>'representative_id')::uuid END$b0$);
 IF strpos(d,$a1$o.id::text=x.c->>'prior_id'$a1$)=0 THEN RAISE EXCEPTION 'V298 anchor 1 changed'; END IF;
 d:=replace(d,$a1$o.id::text=x.c->>'prior_id'$a1$,$b1$o.id::text=x.c->>'prior_id' AND o.id=CASE WHEN x.c->>'prior_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (x.c->>'prior_id')::uuid END$b1$);
 IF strpos(d,$a2$b.id::text=x.c->>'invoice_anchor_id'$a2$)=0 THEN RAISE EXCEPTION 'V298 anchor 2 changed'; END IF;
 d:=replace(d,$a2$b.id::text=x.c->>'invoice_anchor_id'$a2$,$b2$b.id::text=x.c->>'invoice_anchor_id' AND b.id=CASE WHEN x.c->>'invoice_anchor_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (x.c->>'invoice_anchor_id')::uuid END$b2$);
 IF strpos(d,$a3$z.id::text=x.c->>'representative_id'$a3$)=0 THEN RAISE EXCEPTION 'V298 anchor 3 changed'; END IF;
 d:=replace(d,$a3$z.id::text=x.c->>'representative_id'$a3$,$b3$z.id::text=x.c->>'representative_id' AND z.id=CASE WHEN x.c->>'representative_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (x.c->>'representative_id')::uuid END$b3$);
 IF strpos(d,$a4$z.id::text=x.c->>'prior_id'$a4$)=0 THEN RAISE EXCEPTION 'V298 anchor 4 changed'; END IF;
 d:=replace(d,$a4$z.id::text=x.c->>'prior_id'$a4$,$b4$z.id::text=x.c->>'prior_id' AND z.id=CASE WHEN x.c->>'prior_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (x.c->>'prior_id')::uuid END$b4$);
 IF strpos(d,$a5$z.id::text=x.c->>'invoice_anchor_id'$a5$)=0 THEN RAISE EXCEPTION 'V298 anchor 5 changed'; END IF;
 d:=replace(d,$a5$z.id::text=x.c->>'invoice_anchor_id'$a5$,$b5$z.id::text=x.c->>'invoice_anchor_id' AND z.id=CASE WHEN x.c->>'invoice_anchor_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (x.c->>'invoice_anchor_id')::uuid END$b5$);
 IF strpos(d,$a6$), q26_resolvable AS MATERIALIZED ($a6$)=0 THEN RAISE EXCEPTION 'V298 anchor 6 changed'; END IF;
 d:=replace(d,$a6$), q26_resolvable AS MATERIALIZED ($a6$,$b6$), q26_relevant_expenses_v298 AS MATERIALIZED (
 -- Retain every matching occurrence before the existing uniqueness checks.
 -- Full-row economic masks are evaluated only for the referenced pairs.
 SELECT x.* FROM q26_original x
 WHERE EXISTS(SELECT 1 FROM q26_pair p
  WHERE (x.source_ref=p.c->>'representative_id' OR x.source_ref=p.c->>'prior_id')
   AND to_jsonb(x.competence_month)=p.c->'competence_month')
), q26_resolvable AS MATERIALIZED ($b6$);
 IF strpos(d,$a7$FROM q26_original x WHERE x.source_ref=p.c$a7$)=0 THEN RAISE EXCEPTION 'V298 anchor 7 changed'; END IF;
 d:=replace(d,$a7$FROM q26_original x WHERE x.source_ref=p.c$a7$,$b7$FROM q26_relevant_expenses_v298 x WHERE x.source_ref=p.c$b7$);
 EXECUTE d;
 IF md5(pg_get_functiondef(before_oid))<>'0d845b5e55b0505af153d66adfcd6ea4' THEN RAISE EXCEPTION 'V298 replacement definition mismatch'; END IF;
 IF 'public.lts_expense_rows_pre_categories_v290(uuid,date,date)'::regprocedure::oid<>before_oid
 OR EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=before_oid AND (p.proowner<>before_owner OR p.proacl IS DISTINCT FROM before_acl OR p.proconfig IS DISTINCT FROM before_config OR p.prosecdef IS DISTINCT FROM before_security OR p.provolatile<>before_volatility))
 THEN RAISE EXCEPTION 'V298 function identity, privileges or configuration changed'; END IF;
END $patch$;
