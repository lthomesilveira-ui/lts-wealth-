-- V264: preserve the original known category of the exact purchase before merchant fallback.
DO $patch$ DECLARE d text; before_acl aclitem[];
BEGIN
 SELECT pg_get_functiondef(oid),proacl INTO d,before_acl FROM pg_proc WHERE oid='public.lts_expense_rows_v230_baseline(uuid,date,date)'::regprocedure;
 IF md5(d)<>'672ccf3731df91e333a101b1585f63c2' THEN RAISE EXCEPTION 'source lease changed'; END IF;
 d:=replace(d,$old$case when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(x.category,'')$old$,$new$case when card_source.category is not null then card_source.category
 when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(x.category,'')$new$);
 d:=replace(d,$old$ from public.lts_expense_effective_rows_v176(p_user_id,p_from,p_to) x
 left join lateral ($old$,$new$ from public.lts_expense_effective_rows_v176(p_user_id,p_from,p_to) x
 -- A known category on this exact documentary purchase outranks a broad
 -- merchant heuristic. Explicit per-purchase review decisions still win
 -- downstream; unknown/ambiguous original categories remain fallbacks.
 left join lateral (
   select case when count(distinct nullif(trim(cd.category),''))=1 then min(nullif(trim(cd.category),'')) end category
   from public.lts_card_purchase_detail cd
   where x.source_table='card_purchase_detail' and cd.user_id=p_user_id
   and x.source_ref IN(cd.line_key,cd.purchase_key)
   and public.lts_v178_norm(cd.category) not in ('','a classificar','nao identificado','nao atribuida','nao atribuido')
 ) card_source on true
 left join lateral ($new$);
 EXECUTE d;
 IF (SELECT proacl FROM pg_proc WHERE oid='public.lts_expense_rows_v230_baseline(uuid,date,date)'::regprocedure) IS DISTINCT FROM before_acl THEN RAISE EXCEPTION 'ACL changed'; END IF;
END $patch$;
