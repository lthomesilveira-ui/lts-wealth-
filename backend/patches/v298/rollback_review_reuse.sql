-- Explicit restoration to the original five readers. Run only in one transaction.
-- Exact installed definition leases and every privilege/configuration are checked.
DO $restore$
DECLARE d text; before_oid oid; before_owner oid; before_acl aclitem[]; before_config text[]; before_security boolean; before_volatility "char";
BEGIN
 SELECT oid,pg_get_functiondef(oid),proowner,proacl,proconfig,prosecdef,provolatile INTO before_oid,d,before_owner,before_acl,before_config,before_security,before_volatility
 FROM pg_proc WHERE oid='public.lts_card_cycles_v226(uuid)'::regprocedure;
 IF md5(d)='e091114f321d7f7fa5d7fdd6a759cd33' THEN RETURN; END IF;
 IF md5(d)<>'bad00fdc296f78ad36e2cca6ef1ce75d' THEN RAISE EXCEPTION 'V298 restore lease changed: lts_card_cycles_v226(uuid)'; END IF;
 IF strpos(d,$a0$'financial_effect','none','provider_balance_used_as_invoice',false),
 EXISTS( SELECT 1 FROM c6_contract_validity WHERE NOT valid AND end_month>=date_trunc('month',current_date)::date
 UNION ALL SELECT 1 FROM rows r WHERE r.family='c6' AND r.provider_status IN('PENDING','POSTED','DOCUMENTED') AND NOT r.is_payment
 AND r.amount>0 AND r.total_installments>r.installment_number AND r.installment_number>0
 AND (r.reference_month IS NULL OR r.reference_month+make_interval(months=>r.total_installments-r.installment_number)>=date_trunc('month',current_date)::date)
 AND NOT EXISTS(SELECT 1 FROM c6_contract_rows identified WHERE identified.source_id=r.source_id)) INTO result,c6_contract_uncertain;$a0$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 0 changed'; END IF;
 d:=replace(d,$a0$'financial_effect','none','provider_balance_used_as_invoice',false),
 EXISTS( SELECT 1 FROM c6_contract_validity WHERE NOT valid AND end_month>=date_trunc('month',current_date)::date
 UNION ALL SELECT 1 FROM rows r WHERE r.family='c6' AND r.provider_status IN('PENDING','POSTED','DOCUMENTED') AND NOT r.is_payment
 AND r.amount>0 AND r.total_installments>r.installment_number AND r.installment_number>0
 AND (r.reference_month IS NULL OR r.reference_month+make_interval(months=>r.total_installments-r.installment_number)>=date_trunc('month',current_date)::date)
 AND NOT EXISTS(SELECT 1 FROM c6_contract_rows identified WHERE identified.source_id=r.source_id)) INTO result,c6_contract_uncertain;$a0$,$b0$'financial_effect','none','provider_balance_used_as_invoice',false) INTO result;$b0$);
 IF strpos(d,$a1$FROM document_matches_v298 m$a1$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 1 changed'; END IF;
 d:=replace(d,$a1$FROM document_matches_v298 m$a1$,$b1$FROM public.lts_card_document_matches_v234(p_user_id) m$b1$);
 IF strpos(d,$a2$with document_matches_v298 AS MATERIALIZED (
 SELECT * FROM public.lts_card_document_matches_v234(p_user_id)
), c6_eligible AS MATERIALIZED ($a2$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 2 changed'; END IF;
 d:=replace(d,$a2$with document_matches_v298 AS MATERIALIZED (
 SELECT * FROM public.lts_card_document_matches_v234(p_user_id)
), c6_eligible AS MATERIALIZED ($a2$,$b2$with c6_eligible AS MATERIALIZED ($b2$);
 IF strpos(d,$a3$BEGIN

with c6_eligible AS MATERIALIZED ($a3$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 3 changed'; END IF;
 d:=replace(d,$a3$BEGIN

with c6_eligible AS MATERIALIZED ($a3$,$b3$BEGIN
 SELECT EXISTS(WITH rows AS MATERIALIZED (SELECT * FROM public.lts_card_source_rows_v226(p_user_id)),
c6_contract_rows AS MATERIALIZED (
 SELECT r.*,jsonb_build_array(s.institution_code,s.provider_account_ref,r.last4,
 (s.raw_payload#>>'{creditCardMetadata,purchaseDate}')::timestamptz,
 public.lts_card_merchant_key_v226(r.description),r.total_installments)::text contract_key,
 (extract(year FROM r.reference_month)::int*12+extract(month FROM r.reference_month)::int-r.installment_number) cycle_offset
 FROM rows r LEFT JOIN public.lts_card_document_supplement_v234 doc ON doc.id=r.source_id AND doc.user_id=p_user_id
 JOIN public.lts_open_finance_staging s ON s.user_id=p_user_id
 AND (s.id=r.source_id OR (doc.id IS NOT NULL AND s.id::text=doc.metadata->>'prior_purchase_source_id'))
 WHERE r.family='c6' AND r.provider_status IN('PENDING','POSTED','DOCUMENTED') AND NOT r.is_payment AND r.amount>0 AND r.total_installments>1
 AND r.installment_number BETWEEN 1 AND r.total_installments AND r.reference_month IS NOT NULL
 AND s.resource_type='card_transaction' AND s.institution_code='336' AND nullif(s.provider_account_ref,'') IS NOT NULL
 AND nullif(r.last4,'') IS NOT NULL
 AND s.raw_payload#>>'{creditCardMetadata,purchaseDate}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T.*(Z|[+-][0-9]{2}:[0-9]{2})$'
 AND (doc.id IS NULL OR (doc.installment_number=(s.raw_payload#>>'{creditCardMetadata,installmentNumber}')::int+1
 AND doc.total_installments=(s.raw_payload#>>'{creditCardMetadata,totalInstallments}')::int
 AND doc.last4=coalesce(s.raw_payload#>>'{creditCardMetadata,cardNumber}',s.normalized_payload->>'last4')
 AND doc.purchase_date=((s.raw_payload#>>'{creditCardMetadata,purchaseDate}')::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date))
), c6_contract_validity AS MATERIALIZED (
 SELECT contract_key,count(DISTINCT cycle_offset)=1 AND count(*)=count(DISTINCT installment_number) valid,
 max(reference_month+make_interval(months=>total_installments-installment_number)) end_month
 FROM c6_contract_rows GROUP BY contract_key
), c6_projection_sources AS MATERIALIZED (
 SELECT DISTINCT ON(r.contract_key,(r.reference_month+make_interval(months=>step))::date) r.*,step projection_step
 FROM c6_contract_rows r JOIN c6_contract_validity v USING(contract_key)
 CROSS JOIN LATERAL generate_series(1,least(120,r.total_installments-r.installment_number)) step
 WHERE v.valid AND NOT EXISTS(SELECT 1 FROM c6_contract_rows actual WHERE actual.contract_key=r.contract_key
 AND actual.reference_month=(r.reference_month+make_interval(months=>step))::date)
 ORDER BY r.contract_key,(r.reference_month+make_interval(months=>step))::date,r.installment_number DESC
)
 SELECT 1 FROM c6_contract_validity WHERE NOT valid AND end_month>=date_trunc('month',current_date)::date
 UNION ALL SELECT 1 FROM rows r WHERE r.family='c6' AND r.provider_status IN('PENDING','POSTED','DOCUMENTED') AND NOT r.is_payment
 AND r.amount>0 AND r.total_installments>r.installment_number AND r.installment_number>0
 AND (r.reference_month IS NULL OR r.reference_month+make_interval(months=>r.total_installments-r.installment_number)>=date_trunc('month',current_date)::date)
 AND NOT EXISTS(SELECT 1 FROM c6_contract_rows identified WHERE identified.source_id=r.source_id)) INTO c6_contract_uncertain;
with c6_eligible AS MATERIALIZED ($b3$);
 EXECUTE d;
 IF md5(pg_get_functiondef(before_oid))<>'e091114f321d7f7fa5d7fdd6a759cd33' THEN RAISE EXCEPTION 'V298 restored definition mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=before_oid AND (p.proowner<>before_owner OR p.proacl IS DISTINCT FROM before_acl OR p.proconfig IS DISTINCT FROM before_config OR p.prosecdef IS DISTINCT FROM before_security OR p.provolatile<>before_volatility))
 THEN RAISE EXCEPTION 'V298 restoration privileges/configuration changed'; END IF;
END $restore$;

DO $restore$
DECLARE d text; before_oid oid; before_owner oid; before_acl aclitem[]; before_config text[]; before_security boolean; before_volatility "char";
BEGIN
 SELECT oid,pg_get_functiondef(oid),proowner,proacl,proconfig,prosecdef,provolatile INTO before_oid,d,before_owner,before_acl,before_config,before_security,before_volatility
 FROM pg_proc WHERE oid='public.lts_card_workbook_bank_rows_v1(uuid)'::regprocedure;
 IF md5(d)='a06bbae089c045121ecd9afc588835f6' THEN RETURN; END IF;
 IF md5(d)<>'e7912321b844aa828da58fc94f00390c' THEN RAISE EXCEPTION 'V298 restore lease changed: lts_card_workbook_bank_rows_v1(uuid)'; END IF;
 IF strpos(d,$a0$END) END AS corrected_row$a0$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 0 changed'; END IF;
 d:=replace(d,$a0$END) END AS corrected_row$a0$,$b0$END) AS corrected_row$b0$);
 IF strpos(d,$a1$SELECT CASE WHEN v.user_id IS NULL AND jsonb_typeof(w.evidence)='object' AND NOT (w.evidence ? 'bank_precedence_applied')
 THEN w ELSE jsonb_populate_record(NULL::public.lts_card_workbook_evidence_v226,$a1$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 1 changed'; END IF;
 d:=replace(d,$a1$SELECT CASE WHEN v.user_id IS NULL AND jsonb_typeof(w.evidence)='object' AND NOT (w.evidence ? 'bank_precedence_applied')
 THEN w ELSE jsonb_populate_record(NULL::public.lts_card_workbook_evidence_v226,$a1$,$b1$SELECT jsonb_populate_record(NULL::public.lts_card_workbook_evidence_v226,$b1$);
 EXECUTE d;
 IF md5(pg_get_functiondef(before_oid))<>'a06bbae089c045121ecd9afc588835f6' THEN RAISE EXCEPTION 'V298 restored definition mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=before_oid AND (p.proowner<>before_owner OR p.proacl IS DISTINCT FROM before_acl OR p.proconfig IS DISTINCT FROM before_config OR p.prosecdef IS DISTINCT FROM before_security OR p.provolatile<>before_volatility))
 THEN RAISE EXCEPTION 'V298 restoration privileges/configuration changed'; END IF;
END $restore$;

DO $restore$
DECLARE d text; before_oid oid; before_owner oid; before_acl aclitem[]; before_config text[]; before_security boolean; before_volatility "char";
BEGIN
 SELECT oid,pg_get_functiondef(oid),proowner,proacl,proconfig,prosecdef,provolatile INTO before_oid,d,before_owner,before_acl,before_config,before_security,before_volatility
 FROM pg_proc WHERE oid='public.lts_c6_cycle_identity_v269(uuid)'::regprocedure;
 IF md5(d)='077677805193b3167ca5041f69863900' THEN RETURN; END IF;
 IF md5(d)<>'8bb5a959015e5351c28820a39e987ca7' THEN RAISE EXCEPTION 'V298 restore lease changed: lts_c6_cycle_identity_v269(uuid)'; END IF;
 IF strpos(d,$a0$FROM public.lts_open_finance_staging b JOIN source_rows_v292 tx$a0$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 0 changed'; END IF;
 d:=replace(d,$a0$FROM public.lts_open_finance_staging b JOIN source_rows_v292 tx$a0$,$b0$FROM public.lts_open_finance_staging b JOIN public.lts_open_finance_staging tx$b0$);
 IF strpos(d,$a1$-- The materialized invoice calendar already contains only C6 rows.$a1$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 1 changed'; END IF;
 d:=replace(d,$a1$-- The materialized invoice calendar already contains only C6 rows.$a1$,$b1$AND public.lts_card_family_v226(ci.card_name,ci.card_name)='c6'$b1$);
 EXECUTE d;
 IF md5(pg_get_functiondef(before_oid))<>'077677805193b3167ca5041f69863900' THEN RAISE EXCEPTION 'V298 restored definition mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=before_oid AND (p.proowner<>before_owner OR p.proacl IS DISTINCT FROM before_acl OR p.proconfig IS DISTINCT FROM before_config OR p.prosecdef IS DISTINCT FROM before_security OR p.provolatile<>before_volatility))
 THEN RAISE EXCEPTION 'V298 restoration privileges/configuration changed'; END IF;
END $restore$;

DO $restore$
DECLARE d text; before_oid oid; before_owner oid; before_acl aclitem[]; before_config text[]; before_security boolean; before_volatility "char";
BEGIN
 SELECT oid,pg_get_functiondef(oid),proowner,proacl,proconfig,prosecdef,provolatile INTO before_oid,d,before_owner,before_acl,before_config,before_security,before_volatility
 FROM pg_proc WHERE oid='public.lts_expense_rows_v230_baseline(uuid,date,date)'::regprocedure;
 IF md5(d)='4b244b0ef223b50268ebc2de48235dd9' THEN RETURN; END IF;
 IF md5(d)<>'24c9b55478e02403bdca12003f5f22fe' THEN RAISE EXCEPTION 'V298 restore lease changed: lts_expense_rows_v230_baseline(uuid,date,date)'; END IF;
 IF strpos(d,$a0$from src where sr is not null
 AND EXISTS(SELECT 1 FROM b source_key_v298 WHERE source_key_v298.source_table=src.st AND source_key_v298.source_ref=src.sr)
 order by st,sr,priority,descr,cat$a0$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 0 changed'; END IF;
 d:=replace(d,$a0$from src where sr is not null
 AND EXISTS(SELECT 1 FROM b source_key_v298 WHERE source_key_v298.source_table=src.st AND source_key_v298.source_ref=src.sr)
 order by st,sr,priority,descr,cat$a0$,$b0$from src where sr is not null order by st,sr,priority,descr,cat$b0$);
 IF strpos(d,$a1$SELECT e.*,public.lts_expense_management_group_v3(coalesce(category_decision,category),center_cost,counterparty,origin_name,coverage_mode) old_group,
 pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') category_key_v298,
 pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(original_category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') original_category_key_v298 FROM enriched e$a1$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 1 changed'; END IF;
 d:=replace(d,$a1$SELECT e.*,public.lts_expense_management_group_v3(coalesce(category_decision,category),center_cost,counterparty,origin_name,coverage_mode) old_group,
 pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') category_key_v298,
 pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(original_category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') original_category_key_v298 FROM enriched e$a1$,$b1$SELECT e.*,public.lts_expense_management_group_v3(coalesce(category_decision,category),center_cost,counterparty,origin_name,coverage_mode) old_group FROM enriched e$b1$);
 IF strpos(d,$a2$original_category_key_v298$a2$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 2 changed'; END IF;
 d:=replace(d,$a2$original_category_key_v298$a2$,$b2$pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(original_category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')$b2$);
 IF strpos(d,$a3$category_key_v298$a3$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 3 changed'; END IF;
 d:=replace(d,$a3$category_key_v298$a3$,$b3$pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')$b3$);
 EXECUTE d;
 IF md5(pg_get_functiondef(before_oid))<>'4b244b0ef223b50268ebc2de48235dd9' THEN RAISE EXCEPTION 'V298 restored definition mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=before_oid AND (p.proowner<>before_owner OR p.proacl IS DISTINCT FROM before_acl OR p.proconfig IS DISTINCT FROM before_config OR p.prosecdef IS DISTINCT FROM before_security OR p.provolatile<>before_volatility))
 THEN RAISE EXCEPTION 'V298 restoration privileges/configuration changed'; END IF;
END $restore$;

DO $restore$
DECLARE d text; before_oid oid; before_owner oid; before_acl aclitem[]; before_config text[]; before_security boolean; before_volatility "char";
BEGIN
 SELECT oid,pg_get_functiondef(oid),proowner,proacl,proconfig,prosecdef,provolatile INTO before_oid,d,before_owner,before_acl,before_config,before_security,before_volatility
 FROM pg_proc WHERE oid='public.lts_expense_rows_pre_categories_v290(uuid,date,date)'::regprocedure;
 IF md5(d)='e4e25fa5c5ec9c4bd5225aff371f2e4e' THEN RETURN; END IF;
 IF md5(d)<>'0d845b5e55b0505af153d66adfcd6ea4' THEN RAISE EXCEPTION 'V298 restore lease changed: lts_expense_rows_pre_categories_v290(uuid,date,date)'; END IF;
 IF strpos(d,$a0$FROM q26_relevant_expenses_v298 x WHERE x.source_ref=p.c$a0$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 0 changed'; END IF;
 d:=replace(d,$a0$FROM q26_relevant_expenses_v298 x WHERE x.source_ref=p.c$a0$,$b0$FROM q26_original x WHERE x.source_ref=p.c$b0$);
 IF strpos(d,$a1$), q26_relevant_expenses_v298 AS MATERIALIZED (
 -- Retain every matching occurrence before the existing uniqueness checks.
 -- Full-row economic masks are evaluated only for the referenced pairs.
 SELECT x.* FROM q26_original x
 WHERE EXISTS(SELECT 1 FROM q26_pair p
  WHERE (x.source_ref=p.c->>'representative_id' OR x.source_ref=p.c->>'prior_id')
   AND to_jsonb(x.competence_month)=p.c->'competence_month')
), q26_resolvable AS MATERIALIZED ($a1$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 1 changed'; END IF;
 d:=replace(d,$a1$), q26_relevant_expenses_v298 AS MATERIALIZED (
 -- Retain every matching occurrence before the existing uniqueness checks.
 -- Full-row economic masks are evaluated only for the referenced pairs.
 SELECT x.* FROM q26_original x
 WHERE EXISTS(SELECT 1 FROM q26_pair p
  WHERE (x.source_ref=p.c->>'representative_id' OR x.source_ref=p.c->>'prior_id')
   AND to_jsonb(x.competence_month)=p.c->'competence_month')
), q26_resolvable AS MATERIALIZED ($a1$,$b1$), q26_resolvable AS MATERIALIZED ($b1$);
 IF strpos(d,$a2$z.id::text=x.c->>'invoice_anchor_id' AND z.id=CASE WHEN x.c->>'invoice_anchor_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (x.c->>'invoice_anchor_id')::uuid END$a2$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 2 changed'; END IF;
 d:=replace(d,$a2$z.id::text=x.c->>'invoice_anchor_id' AND z.id=CASE WHEN x.c->>'invoice_anchor_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (x.c->>'invoice_anchor_id')::uuid END$a2$,$b2$z.id::text=x.c->>'invoice_anchor_id'$b2$);
 IF strpos(d,$a3$z.id::text=x.c->>'prior_id' AND z.id=CASE WHEN x.c->>'prior_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (x.c->>'prior_id')::uuid END$a3$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 3 changed'; END IF;
 d:=replace(d,$a3$z.id::text=x.c->>'prior_id' AND z.id=CASE WHEN x.c->>'prior_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (x.c->>'prior_id')::uuid END$a3$,$b3$z.id::text=x.c->>'prior_id'$b3$);
 IF strpos(d,$a4$z.id::text=x.c->>'representative_id' AND z.id=CASE WHEN x.c->>'representative_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (x.c->>'representative_id')::uuid END$a4$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 4 changed'; END IF;
 d:=replace(d,$a4$z.id::text=x.c->>'representative_id' AND z.id=CASE WHEN x.c->>'representative_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (x.c->>'representative_id')::uuid END$a4$,$b4$z.id::text=x.c->>'representative_id'$b4$);
 IF strpos(d,$a5$b.id::text=x.c->>'invoice_anchor_id' AND b.id=CASE WHEN x.c->>'invoice_anchor_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (x.c->>'invoice_anchor_id')::uuid END$a5$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 5 changed'; END IF;
 d:=replace(d,$a5$b.id::text=x.c->>'invoice_anchor_id' AND b.id=CASE WHEN x.c->>'invoice_anchor_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (x.c->>'invoice_anchor_id')::uuid END$a5$,$b5$b.id::text=x.c->>'invoice_anchor_id'$b5$);
 IF strpos(d,$a6$o.id::text=x.c->>'prior_id' AND o.id=CASE WHEN x.c->>'prior_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (x.c->>'prior_id')::uuid END$a6$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 6 changed'; END IF;
 d:=replace(d,$a6$o.id::text=x.c->>'prior_id' AND o.id=CASE WHEN x.c->>'prior_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (x.c->>'prior_id')::uuid END$a6$,$b6$o.id::text=x.c->>'prior_id'$b6$);
 IF strpos(d,$a7$r.id::text=x.c->>'representative_id' AND r.id=CASE WHEN x.c->>'representative_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (x.c->>'representative_id')::uuid END$a7$)=0 THEN RAISE EXCEPTION 'V298 restoration anchor 7 changed'; END IF;
 d:=replace(d,$a7$r.id::text=x.c->>'representative_id' AND r.id=CASE WHEN x.c->>'representative_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (x.c->>'representative_id')::uuid END$a7$,$b7$r.id::text=x.c->>'representative_id'$b7$);
 EXECUTE d;
 IF md5(pg_get_functiondef(before_oid))<>'e4e25fa5c5ec9c4bd5225aff371f2e4e' THEN RAISE EXCEPTION 'V298 restored definition mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=before_oid AND (p.proowner<>before_owner OR p.proacl IS DISTINCT FROM before_acl OR p.proconfig IS DISTINCT FROM before_config OR p.prosecdef IS DISTINCT FROM before_security OR p.provolatile<>before_volatility))
 THEN RAISE EXCEPTION 'V298 restoration privileges/configuration changed'; END IF;
END $restore$;
