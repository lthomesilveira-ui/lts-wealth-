CREATE OR REPLACE FUNCTION public.lts_card_review_suggestions_v312(p_user_id uuid, p_targets jsonb)
 RETURNS TABLE(source_ref text, suggestion jsonb)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
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
$function$
