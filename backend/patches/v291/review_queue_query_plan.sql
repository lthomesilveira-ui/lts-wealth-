-- V291: remove per-row documentary scans and repeated group calculations.
-- Full canonical rows (including multiplicity) and queue JSON must remain identical.
-- The application's authenticated eight-second limit is not changed.
SET LOCAL statement_timeout='55s';
CREATE TEMP TABLE review_plan_before_v291(
 user_id uuid PRIMARY KEY, expense_rows jsonb, queue jsonb
) ON COMMIT DROP;
DO $before$ DECLARE u uuid; BEGIN
 FOR u IN SELECT DISTINCT user_id FROM public.lts_product_read_cache LOOP
  PERFORM set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=u),true);
  INSERT INTO review_plan_before_v291
  SELECT u,(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text),'[]'::jsonb)
   FROM public.lts_v229_expense_rows(u,date '2013-10-10',current_date) r),
   public.lts_browser_expense_review_queue_v229(date '2013-10-10',current_date,0,25,null);
 END LOOP;
END $before$;
DO $patch$
DECLARE d text; prior_oid oid; prior_owner oid; prior_acl aclitem[]; prior_config text[]; prior_security boolean;
 a integer; z integer;
BEGIN
 SELECT p.oid,pg_get_functiondef(p.oid),p.proowner,p.proacl,p.proconfig,p.prosecdef
 INTO prior_oid,d,prior_owner,prior_acl,prior_config,prior_security
 FROM pg_proc p WHERE p.oid='public.lts_expense_rows_v230_baseline(uuid,date,date)'::regprocedure;
 IF md5(d)<>'acd4b0ace8082e9a5970620ace24cd35' THEN RAISE EXCEPTION 'Review baseline definition lease changed'; END IF;
 IF strpos(d,$anchor$ left join lateral (
   select case when count(distinct nullif(trim(cd.category),''))=1 then min(nullif(trim(cd.category),'')) end category
   from public.lts_card_purchase_detail cd
   where x.source_table='card_purchase_detail' and cd.user_id=p_user_id
   and x.source_ref IN(cd.line_key,cd.purchase_key)
   -- Only this proved collision is overridden. Keep finer approved
   -- purposes (such as Batizado), beneficiary refinements and other
   -- current semantic categories intact; placeholders are never evidence.
   and public.lts_v178_norm(cd.category)='presentes'
   and public.lts_v178_norm(x.category)='vestuario'
   and public.lts_v178_norm(cd.category) not in ('','a classificar','nao identificado','nao atribuida','nao atribuido')
 ) card_source on true
 left join lateral (
   select case when count(distinct nullif(trim(e.category),''))=1 then min(nullif(trim(e.category),'')) end category
   from public.financial_events e
   where x.source_table='daily_flow_documentary_bridge' and e.user_id=p_user_id
     and (e.id::text=x.source_ref or e.legacy_id=x.source_ref)
     and pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(e.category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') not in ('a classificar','não identificado','nao identificado')
 ) source on true$anchor$)=0
 OR strpos(d,$anchor$), b as materialized($anchor$)=0
 OR strpos(d,$anchor$), person_rows as materialized($anchor$)=0
 OR strpos(d,$anchor$ from enriched e
), labeled$anchor$)=0 THEN RAISE EXCEPTION 'Review plan anchor changed'; END IF;
 d:=replace(d,$anchor$ left join lateral (
   select case when count(distinct nullif(trim(cd.category),''))=1 then min(nullif(trim(cd.category),'')) end category
   from public.lts_card_purchase_detail cd
   where x.source_table='card_purchase_detail' and cd.user_id=p_user_id
   and x.source_ref IN(cd.line_key,cd.purchase_key)
   -- Only this proved collision is overridden. Keep finer approved
   -- purposes (such as Batizado), beneficiary refinements and other
   -- current semantic categories intact; placeholders are never evidence.
   and public.lts_v178_norm(cd.category)='presentes'
   and public.lts_v178_norm(x.category)='vestuario'
   and public.lts_v178_norm(cd.category) not in ('','a classificar','nao identificado','nao atribuida','nao atribuido')
 ) card_source on true
 left join lateral (
   select case when count(distinct nullif(trim(e.category),''))=1 then min(nullif(trim(e.category),'')) end category
   from public.financial_events e
   where x.source_table='daily_flow_documentary_bridge' and e.user_id=p_user_id
     and (e.id::text=x.source_ref or e.legacy_id=x.source_ref)
     and pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(e.category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') not in ('a classificar','não identificado','nao identificado')
 ) source on true$anchor$,$replacement$ left join card_source_categories_v291 card_source on x.source_table='card_purchase_detail'
 AND public.lts_v178_norm(x.category)='vestuario' AND card_source.ref=x.source_ref
 left join flow_source_categories_v291 source on x.source_table='daily_flow_documentary_bridge' AND source.ref=x.source_ref$replacement$);
 d:=replace(d,$anchor$), b as materialized($anchor$,$replacement$), card_source_categories_v291 AS MATERIALIZED(
 SELECT k.ref,case when count(distinct nullif(trim(cd.category),''))=1 then min(nullif(trim(cd.category),'')) end category
 FROM public.lts_card_purchase_detail cd
 CROSS JOIN LATERAL(SELECT cd.line_key ref UNION SELECT cd.purchase_key WHERE cd.purchase_key IS NOT NULL) k
 WHERE cd.user_id=p_user_id AND public.lts_v178_norm(cd.category)='presentes'
 AND public.lts_v178_norm(cd.category) not in ('','a classificar','nao identificado','nao atribuida','nao atribuido')
 GROUP BY k.ref
), flow_source_categories_v291 AS MATERIALIZED(
 SELECT k.ref,case when count(distinct nullif(trim(e.category),''))=1 then min(nullif(trim(e.category),'')) end category
 FROM public.financial_events e
 CROSS JOIN LATERAL(SELECT e.id::text ref UNION SELECT e.legacy_id WHERE e.legacy_id IS NOT NULL) k
 WHERE e.user_id=p_user_id AND public.lts_v178_norm(e.category) not in ('a classificar','não identificado','nao identificado')
 GROUP BY k.ref
), b as materialized($replacement$);
 d:=replace(d,$anchor$), person_rows as materialized($anchor$,$replacement$), enriched_groups_v291 AS MATERIALIZED(
 SELECT e.*,public.lts_expense_management_group_v3(coalesce(category_decision,category),center_cost,counterparty,origin_name,coverage_mode) old_group FROM enriched e
), person_rows as materialized($replacement$);
 d:=replace(d,$anchor$ public.lts_expense_management_group_v3(coalesce(category_decision,category),center_cost,counterparty,origin_name,coverage_mode) old_group,
$anchor$,'');
 d:=replace(d,$anchor$(public.lts_expense_management_group_v3(coalesce(category_decision,category),center_cost,counterparty,origin_name,coverage_mode) in $anchor$,'(old_group in ');
 d:=replace(d,$anchor$ from enriched e
), labeled$anchor$,$replacement$ from enriched_groups_v291 e
), labeled$replacement$);
 EXECUTE d;
 IF 'public.lts_expense_rows_v230_baseline(uuid,date,date)'::regprocedure::oid<>prior_oid
 OR EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=prior_oid AND
 (p.proowner<>prior_owner OR p.proacl IS DISTINCT FROM prior_acl OR p.proconfig IS DISTINCT FROM prior_config OR p.prosecdef IS DISTINCT FROM prior_security))
 THEN RAISE EXCEPTION 'Review reader identity/privileges changed'; END IF;
END $patch$;
-- Same immutable normalization/precedence; avoid planning this tiny SQL query on every invocation.
CREATE TEMP TABLE card_family_before_v291 ON COMMIT DROP AS
WITH names AS(
 SELECT normalized_payload->>'card_name' name,institution_name bank FROM public.lts_open_finance_staging
 UNION SELECT normalized_payload->>'name',institution_name FROM public.lts_open_finance_staging
 UNION SELECT card_name,card_name FROM public.card_invoices
 UNION SELECT name,bank FROM (VALUES
 (null::text,null::text),('',''),('AETERNUM','Bradesco'),('C6 Mastercard','C6'),('Bandeirado',''),
 ('Visa','Itaú'),('Visa','Bradesco'),('Visa','unknown'),('Mastercard','Itaú'),
 ('MC BLACK',''),('PERSONNALITÉ',''),('ÁÉÍÓÚ   Aeternum',null),('Not a card','Itau'),
 ('Visa'||chr(9)||'Infinite','  ITAÚ '),('Aeternum C6 Visa Mastercard','Bradesco')
 ) v(name,bank)
) SELECT name,bank,public.lts_card_family_v226(name,bank) family FROM names;
DO $family$
DECLARE d text; prior_oid oid; prior_owner oid; prior_acl aclitem[]; prior_config text[]; prior_security boolean;
BEGIN
 SELECT p.oid,pg_get_functiondef(p.oid),p.proowner,p.proacl,p.proconfig,p.prosecdef
 INTO prior_oid,d,prior_owner,prior_acl,prior_config,prior_security
 FROM pg_proc p WHERE p.oid='public.lts_card_family_v226(text,text)'::regprocedure;
 IF md5(d)<>'999e96e7af58a62b69ad8f63bb0b990d' THEN RAISE EXCEPTION 'Card family definition lease changed'; END IF;
 EXECUTE $ddl$CREATE OR REPLACE FUNCTION public.lts_card_family_v226(p_name text,p_bank text)
 RETURNS text LANGUAGE plpgsql IMMUTABLE SET search_path=''
 AS $fn$
 DECLARE
 n text:=pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(p_name,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g');
 b text:=pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(p_bank,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g');
 BEGIN
 RETURN CASE WHEN n LIKE '%aeternum%' THEN 'aeternum'
 WHEN n LIKE '%c6%' OR n LIKE '%bandeirado%' THEN 'c6'
 WHEN n LIKE '%visa%' AND b LIKE '%itau%' THEN 'itau_visa'
 WHEN n LIKE '%visa%' AND b LIKE '%bradesco%' THEN 'bradesco_prime'
 WHEN n LIKE '%mastercard%' OR n LIKE '%mc black%' OR n LIKE '%personnalite%' THEN 'itau_mastercard'
 END;
 END $fn$;$ddl$;
 IF 'public.lts_card_family_v226(text,text)'::regprocedure::oid<>prior_oid
 OR EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=prior_oid AND
 (p.proowner<>prior_owner OR p.proacl IS DISTINCT FROM prior_acl OR p.proconfig IS DISTINCT FROM prior_config OR p.prosecdef IS DISTINCT FROM prior_security OR p.provolatile<>'i'))
 THEN RAISE EXCEPTION 'Card family identity/privileges changed'; END IF;
 IF EXISTS(SELECT 1 FROM card_family_before_v291 b WHERE public.lts_card_family_v226(b.name,b.bank) IS DISTINCT FROM b.family)
 THEN RAISE EXCEPTION 'Card family semantics changed'; END IF;
END $family$;
DO $parity$ DECLARE r record; actual_rows jsonb; actual_queue jsonb; BEGIN
 FOR r IN SELECT * FROM review_plan_before_v291 LOOP
  PERFORM set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=r.user_id),true);
  SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]'::jsonb) INTO actual_rows
  FROM public.lts_v229_expense_rows(r.user_id,date '2013-10-10',current_date) x;
  IF actual_rows IS DISTINCT FROM r.expense_rows THEN RAISE EXCEPTION 'Canonical expense rows/multiplicity changed'; END IF;
  actual_queue:=public.lts_browser_expense_review_queue_v229(date '2013-10-10',current_date,0,25,null);
  IF actual_queue IS DISTINCT FROM r.queue THEN RAISE EXCEPTION 'Complete review queue JSON changed'; END IF;
 END LOOP;
END $parity$;

