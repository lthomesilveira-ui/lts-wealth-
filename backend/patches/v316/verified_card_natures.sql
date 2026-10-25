-- Broad merchant natures only; policy identity and current coverage require separate evidence.
CREATE OR REPLACE FUNCTION public.lts_card_verified_nature_candidates_v316(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $function$
WITH rules(rule_id,merchant_pattern,mcc,provider_category,category,reference_url) AS(VALUES
 ('evino-beverages','^evinocomercio$','5921','Groceries','Bebidas','https://www.evino.com.br/sobre-nos'),
 ('5asec-laundry','^5asec$','7216','Services','Lavanderia','https://5asec.com.br/'),
 ('bradesco-life-insurance','^bradescovidparc$','6300','Insurance','Seguros','https://www.bradescoseguros.com.br/clientes/produtos/seguro-de-vida/vida-viva'),
 ('mapfre-insurance','^mapfrepcl[0-9]{1,2}de[0-9]{1,2}$','6300','Insurance','Seguros','https://www.mapfre.com.br/')
), pending AS MATERIALIZED(
 SELECT p.item,r.rule_id,r.category,r.reference_url,s.raw_payload->>'category' provider_category,
 s.raw_payload#>>'{creditCardMetadata,payeeMCC}' mcc
 FROM public.lts_card_pending_sources_v312(p_user_id)p
 JOIN public.lts_open_finance_staging s ON s.id::text=p.item->>'source_ref' AND s.user_id=p_user_id
 JOIN rules r ON public.lts_card_merchant_key_v226(p.item->>'description') ~ r.merchant_pattern
 AND s.raw_payload#>>'{creditCardMetadata,payeeMCC}'=r.mcc AND s.raw_payload->>'category'=r.provider_category
 JOIN public.lts_category_catalog c ON c.user_id=p_user_id AND c.active AND c.category=r.category
 WHERE s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL AND s.currency='BRL'
 AND s.normalized_payload->>'status'='POSTED' AND s.raw_payload->>'type'='DEBIT'
 AND s.signed_amount=-(p.item->>'amount')::numeric
 AND (p.item->>'event_date')::date<=current_date
 AND (p.item->>'reference_month')::date<(SELECT date_trunc('month',min(created_at))::date FROM public.lts_open_finance_staging WHERE user_id=p_user_id AND resource_type='card_transaction')
 AND NOT EXISTS(SELECT 1 FROM public.lts_v178_review_decision d WHERE d.user_id=p_user_id AND d.source_table='lts_open_finance_staging'
 AND d.source_ref=p.item->>'source_ref' AND(d.category_label IS NOT NULL OR d.beneficiary IS NOT NULL OR d.property_code IS NOT NULL))
), targets AS(SELECT coalesce(jsonb_agg(item),'[]') items FROM pending), suggestions AS MATERIALIZED(
 SELECT s.* FROM targets t CROSS JOIN LATERAL public.lts_card_review_suggestions_v312(p_user_id,t.items)s
)
SELECT coalesce(jsonb_agg(p.item||jsonb_build_object('category',p.category,'rule_id',p.rule_id,'evidence',
 jsonb_build_object('basis','verified_merchant_activity_v316','reference_url',p.reference_url,'mcc',p.mcc,'provider_category',p.provider_category,
 'scope','spending_nature_only','contract_identity_inferred',false,'coverage_current_inferred',false,'owner_confirmation',false,'beneficiary_inferred',false,'recurring_status_inferred',false)) ORDER BY p.item->>'source_ref'),'[]')
FROM pending p JOIN suggestions s ON s.source_ref=p.item->>'source_ref'
WHERE s.suggestion->>'category'=p.category AND s.suggestion->>'basis'='bank_business_activity'
$function$;

-- Service-only, source/hash-bound application of an explicitly reviewed candidate set.
CREATE OR REPLACE FUNCTION public.lts_apply_verified_card_natures_v316(p_user_id uuid,p_targets jsonb)
RETURNS jsonb LANGUAGE plpgsql SET search_path='' SET timezone='America/Sao_Paulo' AS $function$
DECLARE expected integer;locked integer;eligible jsonb;receipt jsonb;rec record;before_row jsonb;written integer;total_written integer:=0;
BEGIN
 IF p_user_id IS NULL OR jsonb_typeof(p_targets) IS DISTINCT FROM 'array' OR jsonb_array_length(p_targets) NOT BETWEEN 1 AND 50
 THEN RAISE EXCEPTION 'Invalid source set';END IF;
 expected:=jsonb_array_length(p_targets);
 IF (SELECT count(DISTINCT x->>'source_ref') FROM jsonb_array_elements(p_targets)x)<>expected THEN RAISE EXCEPTION 'Duplicate source';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_user_id::text||':verified-card-nature-v316',316));
 PERFORM 1 FROM public.lts_open_finance_staging s JOIN jsonb_array_elements(p_targets)x ON s.id::text=x->>'source_ref'
 WHERE s.user_id=p_user_id AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL
 AND s.raw_hash=x->>'raw_hash' AND s.raw_hash ~ '^[0-9a-f]{64}$' ORDER BY s.id FOR UPDATE OF s;
 GET DIAGNOSTICS locked=ROW_COUNT;
 IF locked<>expected THEN RAISE EXCEPTION 'Source identity or hash changed';END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_targets)x WHERE NOT EXISTS(
  SELECT 1 FROM public.lts_v178_review_decision d JOIN public.lts_category_catalog c ON c.user_id=d.user_id AND c.active AND c.category=d.category_label
  WHERE d.user_id=p_user_id AND d.source_table='lts_open_finance_staging' AND d.source_ref=x->>'source_ref'
  AND d.category_label=x->>'category' AND d.decision_basis='verified_merchant_activity_v316:'||(x->>'rule_id')
  AND d.beneficiary IS NULL AND d.property_code IS NULL)) THEN
  RETURN jsonb_build_object('ok',true,'already_applied',true,'decisions_written',0,'financial_effect','none');
 END IF;
 eligible:=public.lts_card_verified_nature_candidates_v316(p_user_id);
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_targets)x WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(eligible)e
 WHERE e->>'source_ref'=x->>'source_ref' AND e->>'raw_hash'=x->>'raw_hash' AND e->>'category'=x->>'category' AND e->>'rule_id'=x->>'rule_id'))
 THEN RAISE EXCEPTION 'Evidence or existing classification changed';END IF;
 FOR rec IN SELECT e FROM jsonb_array_elements(eligible)e JOIN jsonb_array_elements(p_targets)x ON e->>'source_ref'=x->>'source_ref' ORDER BY e->>'source_ref' LOOP
  SELECT to_jsonb(d) INTO before_row FROM public.lts_v178_review_decision d WHERE d.user_id=p_user_id AND d.source_table='lts_open_finance_staging' AND d.source_ref=rec.e->>'source_ref';
  INSERT INTO public.lts_v178_review_decision(user_id,source_table,source_ref,category_label,beneficiary,property_code,decision_basis)
  VALUES(p_user_id,'lts_open_finance_staging',rec.e->>'source_ref',rec.e->>'category',NULL,NULL,'verified_merchant_activity_v316:'||(rec.e->>'rule_id'))
  ON CONFLICT(user_id,source_table,source_ref) DO UPDATE SET category_label=EXCLUDED.category_label,decision_basis=EXCLUDED.decision_basis,decided_at=now()
  WHERE lts_v178_review_decision.category_label IS NULL AND lts_v178_review_decision.beneficiary IS NULL AND lts_v178_review_decision.property_code IS NULL;
  GET DIAGNOSTICS written=ROW_COUNT;
  IF written<>1 THEN RAISE EXCEPTION 'A classification was confirmed concurrently';END IF;
  total_written:=total_written+written;
  INSERT INTO public.lts_access_audit(user_id,email,action,meta) VALUES(p_user_id,lower(coalesce(auth.jwt()->>'email','')),
   'apply_verified_card_nature_v316',jsonb_build_object('source_id',rec.e->>'source_ref','source_hash',rec.e->>'raw_hash','before',before_row,
   'after',jsonb_build_object('category',rec.e->>'category','beneficiary',NULL,'property_code',NULL),'evidence',rec.e->'evidence',
   'actor','assistant_under_owner_authorization','owner_confirmation',false,'financial_effect','none'));
 END LOOP;
 IF total_written<>expected THEN RAISE EXCEPTION 'Incomplete application';END IF;
 RETURN jsonb_build_object('ok',true,'decisions_written',total_written,'financial_effect','none','basis','verified_merchant_activity_v316');
END $function$;

REVOKE ALL ON FUNCTION public.lts_card_verified_nature_candidates_v316(uuid),public.lts_apply_verified_card_natures_v316(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_verified_nature_candidates_v316(uuid),public.lts_apply_verified_card_natures_v316(uuid,jsonb) TO service_role;
