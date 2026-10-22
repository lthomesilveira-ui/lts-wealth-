-- V298: share identical C6 contract CTEs and document matches within one cycle query.
-- The uncertainty predicate and every financial/evidence field are retained verbatim.
DO $patch$
DECLARE d text; before_oid oid; before_owner oid; before_acl aclitem[]; before_config text[]; before_security boolean; before_volatility "char";
BEGIN
 SELECT oid,pg_get_functiondef(oid),proowner,proacl,proconfig,prosecdef,provolatile INTO before_oid,d,before_owner,before_acl,before_config,before_security,before_volatility
 FROM pg_proc WHERE oid='public.lts_card_cycles_v226(uuid)'::regprocedure;
 IF md5(d)='bad00fdc296f78ad36e2cca6ef1ce75d' THEN RETURN; END IF;
 IF md5(d)<>'e091114f321d7f7fa5d7fdd6a759cd33' THEN RAISE EXCEPTION 'V298 cycle reader changed; inspect before applying'; END IF;
 IF strpos(d,$a0$ SELECT EXISTS(WITH rows AS MATERIALIZED (SELECT * FROM public.lts_card_source_rows_v226(p_user_id)),
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
 AND NOT EXISTS(SELECT 1 FROM c6_contract_rows identified WHERE identified.source_id=r.source_id)) INTO c6_contract_uncertain;$a0$)=0 THEN RAISE EXCEPTION 'V298 cycle anchor 0 changed'; END IF;
 d:=replace(d,$a0$ SELECT EXISTS(WITH rows AS MATERIALIZED (SELECT * FROM public.lts_card_source_rows_v226(p_user_id)),
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
 AND NOT EXISTS(SELECT 1 FROM c6_contract_rows identified WHERE identified.source_id=r.source_id)) INTO c6_contract_uncertain;$a0$,$b0$$b0$);
 IF strpos(d,$a1$with c6_eligible AS MATERIALIZED ($a1$)=0 THEN RAISE EXCEPTION 'V298 cycle anchor 1 changed'; END IF;
 d:=replace(d,$a1$with c6_eligible AS MATERIALIZED ($a1$,$b1$with document_matches_v298 AS MATERIALIZED (
 SELECT * FROM public.lts_card_document_matches_v234(p_user_id)
), c6_eligible AS MATERIALIZED ($b1$);
 IF strpos(d,$a2$FROM public.lts_card_document_matches_v234(p_user_id) m$a2$)=0 THEN RAISE EXCEPTION 'V298 cycle anchor 2 changed'; END IF;
 d:=replace(d,$a2$FROM public.lts_card_document_matches_v234(p_user_id) m$a2$,$b2$FROM document_matches_v298 m$b2$);
 IF strpos(d,$a3$'financial_effect','none','provider_balance_used_as_invoice',false) INTO result;$a3$)=0 THEN RAISE EXCEPTION 'V298 cycle anchor 3 changed'; END IF;
 d:=replace(d,$a3$'financial_effect','none','provider_balance_used_as_invoice',false) INTO result;$a3$,$b3$'financial_effect','none','provider_balance_used_as_invoice',false),
 EXISTS( SELECT 1 FROM c6_contract_validity WHERE NOT valid AND end_month>=date_trunc('month',current_date)::date
 UNION ALL SELECT 1 FROM rows r WHERE r.family='c6' AND r.provider_status IN('PENDING','POSTED','DOCUMENTED') AND NOT r.is_payment
 AND r.amount>0 AND r.total_installments>r.installment_number AND r.installment_number>0
 AND (r.reference_month IS NULL OR r.reference_month+make_interval(months=>r.total_installments-r.installment_number)>=date_trunc('month',current_date)::date)
 AND NOT EXISTS(SELECT 1 FROM c6_contract_rows identified WHERE identified.source_id=r.source_id)) INTO result,c6_contract_uncertain;$b3$);
 EXECUTE d;
 IF md5(pg_get_functiondef(before_oid))<>'bad00fdc296f78ad36e2cca6ef1ce75d' THEN RAISE EXCEPTION 'V298 cycle replacement mismatch'; END IF;
 IF 'public.lts_card_cycles_v226(uuid)'::regprocedure::oid<>before_oid
 OR EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=before_oid AND (p.proowner<>before_owner OR p.proacl IS DISTINCT FROM before_acl OR p.proconfig IS DISTINCT FROM before_config OR p.prosecdef IS DISTINCT FROM before_security OR p.provolatile<>before_volatility))
 THEN RAISE EXCEPTION 'V298 cycle identity, privileges or configuration changed'; END IF;
END $patch$;
