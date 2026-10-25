DO $helper_lease$ BEGIN
 IF to_regprocedure('public.lts_card_named_supplier_v327(text,text,text)') IS NOT NULL AND NOT EXISTS(
 SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.lts_card_named_supplier_v327(text,text,text)')
 AND md5(prosrc)='ba2b00ce3694028af7f456c785d1a684' AND NOT prosecdef AND provolatile='i'
 AND proconfig=ARRAY['search_path=""']::text[]
 AND NOT has_function_privilege('anon',oid,'EXECUTE') AND NOT has_function_privilege('authenticated',oid,'EXECUTE'))
 THEN RAISE EXCEPTION 'Named supplier helper changed';END IF;
END $helper_lease$;
-- Exact named supplier context; this does not identify a product or a person.
-- Public catalogs: moosekids.com.br, usealphaco.com.br, sleepo.com.br, booma.com.br.
CREATE OR REPLACE FUNCTION public.lts_card_named_supplier_v327(p_description text,p_mcc text,p_provider_category text)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $function$
SELECT CASE
 WHEN p_mcc='5611' AND p_provider_category='Clothing'
 AND public.lts_v178_norm(p_description) ~ '^ec[[:space:]]*[*][[:space:]]*(moosebabykids|alphaco)$' THEN true
 WHEN p_mcc='5698' AND p_provider_category='Clothing'
 AND public.lts_v178_norm(p_description) ~ '^pg[[:space:]]*[*][[:space:]]*sleepo[[:space:]]+modas$' THEN true
 WHEN p_mcc='5122' AND p_provider_category='Pharmacy'
 AND public.lts_v178_norm(p_description) ~ '^pg[[:space:]]*[*][[:space:]]*booma[[:space:]]+organic[[:space:]]+cosm[[:space:]]+brasilia[[:space:]]+bra$' THEN true
 ELSE false END
$function$;

REVOKE ALL ON FUNCTION public.lts_card_named_supplier_v327(text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_named_supplier_v327(text,text,text) TO service_role;

DO $lease$
DECLARE target oid:='public.lts_card_review_suggestions_v312(uuid,jsonb)'::regprocedure;
 before_attrs jsonb;before_data jsonb;after_data jsonb;
BEGIN
 IF md5(pg_get_functiondef(target)) NOT IN('cedcf46915e49344eaeb3279963b51e6','1960751e64de825dd72498a66c97712d') THEN RAISE EXCEPTION 'Suggestion definition changed';END IF;
 SELECT to_jsonb(p)-'prosrc' INTO before_attrs FROM pg_proc p WHERE p.oid=target;
 SELECT jsonb_build_object(
'sources',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.lts_open_finance_staging s),
'events',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.financial_events s),
'invoices',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY to_jsonb(s)::text)::text) FROM public.card_invoices s),
'details',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY to_jsonb(s)::text)::text) FROM public.lts_card_purchase_detail s),
'decisions',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY user_id,source_table,source_ref)::text) FROM public.lts_v178_review_decision s),
'categories',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY to_jsonb(s)::text)::text) FROM public.lts_category_catalog s),
'rules',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY to_jsonb(s)::text)::text) FROM public.lts_semantic_rule s),
'documents',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.source_documents s)) INTO before_data;
 EXECUTE $replacement$CREATE OR REPLACE FUNCTION public.lts_card_review_suggestions_v312(p_user_id uuid, p_targets jsonb)
 RETURNS TABLE(source_ref text, suggestion jsonb)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH targets AS MATERIALIZED(
 SELECT t.*,public.lts_card_merchant_key_v226(t.description) merchant_key,
 s.raw_payload#>>'{creditCardMetadata,payeeMCC}' mcc,
 coalesce(CASE WHEN public.lts_card_named_supplier_v327(t.description,s.raw_payload#>>'{creditCardMetadata,payeeMCC}',s.raw_payload->>'category')
 THEN NULL ELSE public.lts_card_identity_guard_v315(t.description,s.raw_payload#>>'{creditCardMetadata,payeeMCC}') END,
 public.lts_card_activity_guard_v317(s.raw_payload#>>'{creditCardMetadata,payeeMCC}',s.raw_payload->>'category')) identity_guard,
 coalesce(s.raw_payload->>'operationType','') IN('PIX','TED','TRANSFER','SAQUE')
 OR public.lts_v178_norm(t.description) ~ '^(pix|transferencia|saque)([^a-z]|$)' funding
 FROM jsonb_to_recordset(p_targets)t(source_table text,source_ref text,description text,amount numeric,event_date date,category text,question_kind text)
 JOIN public.lts_open_finance_staging s ON s.user_id=p_user_id AND s.id::text=t.source_ref
 AND t.source_table='lts_open_finance_staging' AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL
), history AS MATERIALIZED(SELECT * FROM public.lts_review_suggestions_v231(p_user_id,p_targets)),
resolved AS(
 SELECT t.*,h.suggestion old_suggestion,
 coalesce(h.suggestion->>'basis','insufficient_evidence') history_basis,
 (t.merchant_key ~ 'mercado|amazon|shopee|pagseguro|merpago|paypal|^pp|safe2pay|^s2p' OR t.identity_guard='payment_intermediary') IS TRUE platform,
 hc.category history_category,ac.category activity_category
 FROM targets t LEFT JOIN history h USING(source_table,source_ref)
 LEFT JOIN public.lts_category_catalog hc ON hc.user_id=p_user_id AND hc.active
 AND hc.category=public.lts_category_name_v290(p_user_id,h.suggestion->>'category')
 AND public.lts_v178_norm(hc.category) NOT IN('','a classificar','nao identificado','sem categoria','—')
 LEFT JOIN public.lts_category_catalog ac ON ac.user_id=p_user_id AND ac.active
 AND ac.category=public.lts_card_activity_category_v312(t.mcc)
), choices AS(
 SELECT *,CASE WHEN history_category IS NOT NULL AND (NOT platform OR history_basis='same_purchase_installments') AND (NOT funding OR history_basis='same_purchase_installments') THEN history_category
 WHEN NOT platform AND NOT funding AND identity_guard IS NULL AND history_basis<>'conflicting_history' THEN activity_category END chosen_category,
 CASE WHEN history_category IS NOT NULL AND (NOT platform OR history_basis='same_purchase_installments') AND (NOT funding OR history_basis='same_purchase_installments') THEN history_basis
 WHEN NOT platform AND NOT funding AND identity_guard IS NULL AND history_basis<>'conflicting_history' AND activity_category IS NOT NULL THEN 'bank_business_activity'
 WHEN funding AND history_basis<>'same_purchase_installments' THEN 'funding_purpose_needs_context'
 WHEN platform THEN 'platform_purchase_needs_context' WHEN identity_guard='bank_activity_conflict' THEN 'bank_activity_conflict' ELSE history_basis END chosen_basis
 FROM resolved
)
SELECT c.source_ref,jsonb_build_object('category',c.chosen_category,'beneficiary',NULL,'property_code',NULL,
 'basis',c.chosen_basis,'requires_confirmation',true,
 'note',CASE WHEN c.chosen_basis='funding_purpose_needs_context' THEN 'Confirme a finalidade desta operação antes de classificar.'
 WHEN c.chosen_basis='bank_business_activity' THEN 'Sugestão pela atividade do estabelecimento informada pelo banco. Confira a finalidade.'
 WHEN c.chosen_basis='bank_activity_conflict' THEN 'As informações desta compra divergem. Escolha a finalidade antes de classificar.'
 WHEN c.chosen_basis='platform_purchase_needs_context' THEN 'A plataforma não identifica o produto. Escolha a finalidade desta compra.'
 ELSE coalesce(c.old_suggestion->>'note','Sem correspondência suficiente. Escolha a finalidade desta compra.') END,
 'evidence',CASE WHEN c.chosen_basis='bank_business_activity' THEN jsonb_build_object('mcc',c.mcc,
 'reference','https://www.mastercard.com/content/dam/mccom/shared/business/support/rules-pdfs/mastercard-quick-reference-booklet-merchant.pdf')
 ELSE c.old_suggestion->'evidence' END)
FROM choices c
$function$
$replacement$;
 IF md5(pg_get_functiondef(target))<>'1960751e64de825dd72498a66c97712d' OR before_attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target) THEN RAISE EXCEPTION 'Suggestion attributes changed';END IF;
 SELECT jsonb_build_object(
'sources',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.lts_open_finance_staging s),
'events',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.financial_events s),
'invoices',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY to_jsonb(s)::text)::text) FROM public.card_invoices s),
'details',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY to_jsonb(s)::text)::text) FROM public.lts_card_purchase_detail s),
'decisions',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY user_id,source_table,source_ref)::text) FROM public.lts_v178_review_decision s),
'categories',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY to_jsonb(s)::text)::text) FROM public.lts_category_catalog s),
'rules',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY to_jsonb(s)::text)::text) FROM public.lts_semantic_rule s),
'documents',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.source_documents s)) INTO after_data;
 IF before_data IS DISTINCT FROM after_data THEN RAISE EXCEPTION 'Financial or source data changed';END IF;
END $lease$;
