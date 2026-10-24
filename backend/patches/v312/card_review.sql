-- Historical bank observations are reviewable without becoming new expenses.
CREATE OR REPLACE FUNCTION public.lts_card_pending_sources_v312(p_user_id uuid)
RETURNS TABLE(item jsonb) LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $function$
SELECT jsonb_build_object('source_table','lts_open_finance_staging','source_ref',r.source_id,
 'raw_hash',s.raw_hash,'description',r.description,'amount',r.amount,'currency',s.currency,
 'event_date',coalesce(r.purchase_date,r.posting_date),'posting_date',r.posting_date,'reference_month',r.reference_month,
 'category',r.category,'account_source',r.bank||' · '||r.card_name,'family',r.family,'last4',r.last4,
 'installment_number',r.installment_number,'total_installments',r.total_installments,'question_kind','classification')
FROM public.lts_card_source_rows_v226(p_user_id)r
JOIN public.lts_open_finance_staging s ON s.user_id=p_user_id AND s.id=r.source_id
 AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL
WHERE NOT r.is_payment AND r.amount>0 AND s.raw_hash ~ '^[0-9a-f]{64}$'
AND (r.category_basis='unresolved' OR public.lts_v178_norm(coalesce(r.category,'')) IN('','a classificar','nao identificado','sem categoria','—'))
$function$;

-- MCCs describe a business activity, not a purchase's purpose or beneficiary.
-- Reference: Mastercard Quick Reference Booklet, 2 June 2026.
CREATE OR REPLACE FUNCTION public.lts_card_activity_category_v312(p_mcc text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $function$
SELECT CASE
 WHEN p_mcc='5912' THEN 'Farmácia'
 WHEN p_mcc IN('5812','5814') THEN 'Restaurantes'
 WHEN p_mcc='5411' THEN 'Supermercado'
 WHEN p_mcc IN('5441','5451','5462','5499') THEN 'Alimentação e Bebidas'
 WHEN p_mcc='5921' THEN 'Bebidas'
 WHEN p_mcc IN('5611','5621','5631','5641','5651','5655','5661','5681','5691','5699') THEN 'Vestuário'
 WHEN p_mcc='6300' THEN 'Seguros'
 WHEN p_mcc IN('5541','5542') THEN 'Combustível'
 WHEN p_mcc='7523' THEN 'Estacionamento E Pedágio'
 WHEN p_mcc='7011' THEN 'Hotel'
 WHEN p_mcc='7512' THEN 'Aluguel Carro'
 WHEN p_mcc='7216' THEN 'Lavanderia'
 WHEN p_mcc IN('8211','8220','8244','8249','8299','8351') THEN 'Educação'
 WHEN p_mcc='5943' THEN 'Papelaria E Documentos'
 WHEN p_mcc IN('8011','8021','8041','8062','8071','8099') THEN 'Saúde'
 ELSE NULL END
$function$;

CREATE OR REPLACE FUNCTION public.lts_card_review_suggestions_v312(p_user_id uuid,p_targets jsonb)
RETURNS TABLE(source_ref text,suggestion jsonb) LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $function$
WITH targets AS MATERIALIZED(
 SELECT t.*,public.lts_card_merchant_key_v226(t.description) merchant_key,
 s.raw_payload#>>'{creditCardMetadata,payeeMCC}' mcc,
 coalesce(s.raw_payload->>'operationType','') IN('PIX','TED','TRANSFER','SAQUE')
 OR public.lts_v178_norm(t.description) ~ '^(pix|transferencia|saque)([^a-z]|$)' funding
 FROM jsonb_to_recordset(p_targets)t(source_table text,source_ref text,description text,amount numeric,event_date date,category text,question_kind text)
 JOIN public.lts_open_finance_staging s ON s.user_id=p_user_id AND s.id::text=t.source_ref
 AND t.source_table='lts_open_finance_staging' AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL
), history AS MATERIALIZED(SELECT * FROM public.lts_review_suggestions_v231(p_user_id,p_targets)),
resolved AS(
 SELECT t.*,h.suggestion old_suggestion,
 coalesce(h.suggestion->>'basis','insufficient_evidence') history_basis,
 t.merchant_key ~ 'mercado|amazon|shopee|pagseguro|merpago|paypal|^pp|safe2pay|^s2p' platform,
 hc.category history_category,ac.category activity_category
 FROM targets t LEFT JOIN history h USING(source_table,source_ref)
 LEFT JOIN public.lts_category_catalog hc ON hc.user_id=p_user_id AND hc.active
 AND hc.category=public.lts_category_name_v290(p_user_id,h.suggestion->>'category')
 AND public.lts_v178_norm(hc.category) NOT IN('','a classificar','nao identificado','sem categoria','—')
 LEFT JOIN public.lts_category_catalog ac ON ac.user_id=p_user_id AND ac.active
 AND ac.category=public.lts_card_activity_category_v312(t.mcc)
), choices AS(
 SELECT *,CASE WHEN history_category IS NOT NULL AND (NOT platform OR history_basis='same_purchase_installments') THEN history_category
 WHEN NOT platform AND NOT funding AND history_basis<>'conflicting_history' THEN activity_category END chosen_category,
 CASE WHEN history_category IS NOT NULL AND (NOT platform OR history_basis='same_purchase_installments') THEN history_basis
 WHEN NOT platform AND NOT funding AND history_basis<>'conflicting_history' AND activity_category IS NOT NULL THEN 'bank_business_activity'
 WHEN platform THEN 'platform_purchase_needs_context' ELSE history_basis END chosen_basis
 FROM resolved
)
SELECT c.source_ref,jsonb_build_object('category',c.chosen_category,'beneficiary',NULL,'property_code',NULL,
 'basis',c.chosen_basis,'requires_confirmation',true,
 'note',CASE WHEN c.chosen_basis='bank_business_activity' THEN 'Sugestão pela atividade do estabelecimento informada pelo banco. Confira a finalidade.'
 WHEN c.chosen_basis='platform_purchase_needs_context' THEN 'A plataforma não identifica o produto. Escolha a finalidade desta compra.'
 ELSE coalesce(c.old_suggestion->>'note','Sem correspondência suficiente. Escolha a finalidade desta compra.') END,
 'evidence',CASE WHEN c.chosen_basis='bank_business_activity' THEN jsonb_build_object('mcc',c.mcc,
 'reference','https://www.mastercard.com/content/dam/mccom/shared/business/support/rules-pdfs/mastercard-quick-reference-booklet-merchant.pdf')
 ELSE c.old_suggestion->'evidence' END)
FROM choices c
$function$;

CREATE OR REPLACE FUNCTION public.lts_browser_card_review_queue_v312(
 p_from date DEFAULT '2013-10-10',p_to date DEFAULT current_date,p_offset integer DEFAULT 0,p_limit integer DEFAULT 10,p_query text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' SET statement_timeout='18s' AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); pending jsonb; page_items jsonb; result jsonb; overlap text[]:=ARRAY[]::text[];
 total integer;matched integer;off integer:=greatest(coalesce(p_offset,0),0);lim integer:=least(greatest(coalesce(p_limit,10),1),50);
 first_month date;q text:=public.lts_v178_norm(nullif(trim(p_query),''));epoch_before bigint;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<'2013-10-10' OR length(coalesce(p_query,''))>300 THEN RAISE EXCEPTION 'Período ou busca inválidos.';END IF;
 SELECT epoch INTO epoch_before FROM public.lts_read_cache_epoch_v242 WHERE singleton;
 SELECT coalesce(jsonb_agg(item),'[]') INTO pending FROM public.lts_card_pending_sources_v312(u)
 WHERE (item->>'event_date')::date BETWEEN p_from AND least(p_to,current_date);
 total:=jsonb_array_length(pending);
 SELECT date_trunc('month',min(created_at))::date INTO first_month FROM public.lts_open_finance_staging
 WHERE user_id=u AND resource_type='card_transaction';
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(pending)x WHERE (x->>'reference_month')::date BETWEEN first_month AND date_trunc('month',current_date)::date) THEN
  SELECT coalesce(array_agg(r.source_ref),ARRAY[]::text[]) INTO overlap
  FROM public.lts_v229_review_rows(u,p_from,least(p_to,current_date))r
  WHERE r.source_table='lts_open_finance_staging' AND r.identity_status='pending'
  AND EXISTS(SELECT 1 FROM jsonb_array_elements(pending)x WHERE x->>'source_ref'=r.source_ref);
 END IF;
 SELECT count(*) INTO matched FROM jsonb_array_elements(pending)x
 WHERE q IS NULL OR q='' OR strpos(public.lts_v178_norm(concat_ws(' ',x->>'description',x->>'account_source',x->>'last4')),q)>0;
 SELECT coalesce(jsonb_agg(x ORDER BY x->>'event_date' DESC,x->>'source_ref'),'[]') INTO page_items
 FROM(SELECT x FROM jsonb_array_elements(pending)x WHERE q IS NULL OR q='' OR
 strpos(public.lts_v178_norm(concat_ws(' ',x->>'description',x->>'account_source',x->>'last4')),q)>0
 ORDER BY x->>'event_date' DESC,x->>'source_ref' OFFSET off LIMIT lim)page;
 SELECT jsonb_build_object('ok',true,'version','card-review-v312','row_count',total,
 'additional_count',(SELECT count(*) FROM jsonb_array_elements(pending)x WHERE NOT(x->>'source_ref'=ANY(overlap))),
 'matched_count',matched,'offset',off,'next_offset',CASE WHEN off+lim<matched THEN off+lim END,
 'category_options',(SELECT jsonb_agg(category ORDER BY category) FROM public.lts_category_catalog WHERE user_id=u AND active
 AND public.lts_v178_norm(category) NOT IN('','a classificar','nao identificado','sem categoria','—')),
 'rows',coalesce((SELECT jsonb_agg(x||jsonb_build_object('suggestion',s.suggestion) ORDER BY x->>'event_date' DESC,x->>'source_ref')
 FROM jsonb_array_elements(page_items)x LEFT JOIN public.lts_card_review_suggestions_v312(u,page_items)s ON s.source_ref=x->>'source_ref'),'[]'),
 'checked_at',clock_timestamp(),'financial_effect','none') INTO result;
 IF epoch_before IS DISTINCT FROM(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton) THEN
 RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='As informações foram atualizadas. Tente novamente.';END IF;
 RETURN result;
END $function$;

CREATE OR REPLACE FUNCTION public.lts_browser_card_review_save_v312(
 p_source_id uuid,p_expected_raw_hash text,p_category text,p_beneficiary text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' SET statement_timeout='18s' AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1();s public.lts_open_finance_staging%rowtype;
 cat text:=public.lts_category_name_v290(u,nullif(trim(p_category),''));d public.lts_v178_review_decision%rowtype;r jsonb;c record;
BEGIN
 IF p_expected_raw_hash IS NULL OR p_expected_raw_hash !~ '^[0-9a-f]{64}$' OR cat IS NULL
 OR NOT EXISTS(SELECT 1 FROM public.lts_category_catalog WHERE user_id=u AND active AND category=cat)
 OR public.lts_v178_norm(cat) IN('','a classificar','nao identificado','sem categoria','—')
 OR (nullif(trim(p_beneficiary),'') IS NOT NULL AND p_beneficiary NOT IN('Lucas','Larissa','Benjamin','Rafiki'))
 THEN RAISE EXCEPTION 'Escolha uma classificação válida.';END IF;
 SELECT * INTO s FROM public.lts_open_finance_staging WHERE id=p_source_id AND user_id=u
 AND resource_type='card_transaction' AND provider_deleted_at IS NULL FOR UPDATE;
 IF NOT FOUND OR s.raw_hash IS DISTINCT FROM p_expected_raw_hash THEN
 RAISE EXCEPTION 'Esta compra foi atualizada. Atualize a lista antes de classificar.';END IF;
 SELECT * INTO c FROM public.lts_card_source_rows_v226(u)x WHERE x.source_id=p_source_id AND NOT x.is_payment AND x.amount>0;
 IF NOT FOUND THEN RAISE EXCEPTION 'Compra não disponível para classificação.';END IF;
 SELECT * INTO d FROM public.lts_v178_review_decision WHERE user_id=u AND source_table='lts_open_finance_staging' AND source_ref=p_source_id::text;
 IF FOUND AND d.category_label IS NOT NULL THEN
  IF d.category_label=cat AND (nullif(trim(p_beneficiary),'') IS NULL OR d.beneficiary=p_beneficiary) THEN
   RETURN jsonb_build_object('ok',true,'source_id',p_source_id,'category',cat,'already_classified',true,'financial_effect','none');
  END IF;
  RAISE EXCEPTION 'Esta compra já recebeu outra classificação. Atualize a lista para conferir.';
 END IF;
 IF c.category_basis IS DISTINCT FROM 'unresolved' AND public.lts_v178_norm(coalesce(c.category,'')) NOT IN('','a classificar','nao identificado','sem categoria','—') THEN
  IF public.lts_category_name_v290(u,c.category)=cat AND nullif(trim(p_beneficiary),'') IS NULL THEN
   RETURN jsonb_build_object('ok',true,'source_id',p_source_id,'category',cat,'already_classified',true,'financial_effect','none');
  END IF;
  RAISE EXCEPTION 'Esta compra já foi identificada. Atualize a lista para conferir.';
 END IF;
 r:=public.lts_browser_card_classify_v226(p_source_id,cat,nullif(trim(p_beneficiary),''));
 IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'A classificação não foi confirmada.';END IF;
 RETURN r||jsonb_build_object('financial_effect','none','learning','confirmed_source_history');
END $function$;

REVOKE ALL ON FUNCTION public.lts_card_pending_sources_v312(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_card_activity_category_v312(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_card_review_suggestions_v312(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_pending_sources_v312(uuid),public.lts_card_activity_category_v312(text),public.lts_card_review_suggestions_v312(uuid,jsonb) TO service_role;
REVOKE ALL ON FUNCTION public.lts_browser_card_review_queue_v312(date,date,integer,integer,text),public.lts_browser_card_review_save_v312(uuid,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_card_review_queue_v312(date,date,integer,integer,text),public.lts_browser_card_review_save_v312(uuid,text,text,text) TO authenticated,service_role;
