CREATE OR REPLACE FUNCTION public.lts_browser_card_classify_v226(p_source_id uuid, p_category text, p_beneficiary text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=public.lts_browser_assert_user_v1(); before_row jsonb; cat text:=public.lts_category_name_v290(u,nullif(trim(p_category),'')); person text:=nullif(trim(p_beneficiary),''); target record; v_st text:='lts_open_finance_staging';
begin
 if cat is null or length(cat)>120 or public.lts_v178_norm(cat) in ('a classificar','nao identificado','sem categoria') then raise exception 'Escolha uma categoria.'; end if;
 if person is not null and person not in ('Lucas','Larissa','Benjamin','Rafiki') then raise exception 'Beneficiário inválido.'; end if;
 select * into target from public.lts_open_finance_staging s where s.id=p_source_id and s.user_id=u and s.resource_type='card_transaction' and s.provider_deleted_at is null;
 if not found then
  IF NOT EXISTS(SELECT 1 FROM public.lts_card_document_supplement_v234 p WHERE p.user_id=u AND p.id=p_source_id)
  THEN raise exception 'Compra não encontrada.'; END IF;
  v_st:='lts_card_document_supplement_v234';
 end if;
 if not exists(select 1 from public.lts_category_catalog c where c.user_id=u and c.active and c.category=cat) then raise exception 'Categoria não disponível.'; end if;
 select to_jsonb(d) into before_row from public.lts_v178_review_decision d where d.user_id=u and d.source_table=v_st and d.source_ref=p_source_id::text;
 insert into public.lts_v178_review_decision(user_id,source_table,source_ref,category_label,beneficiary,decision_basis)
 values(u,v_st,p_source_id::text,cat,person,'authenticated_user_v226')
 on conflict(user_id,source_table,source_ref) do update set category_label=excluded.category_label,beneficiary=coalesce(excluded.beneficiary,lts_v178_review_decision.beneficiary),decision_basis=excluded.decision_basis,decided_at=now();
 insert into public.lts_access_audit(user_id,email,action,meta) values(u,lower(coalesce(auth.jwt()->>'email','')),'browser_card_classify_v226',jsonb_build_object('source_id',p_source_id,'before',before_row,'after',jsonb_build_object('category',cat,'beneficiary',person),'financial_effect','none'));
 return jsonb_build_object('ok',true,'source_id',p_source_id,'category',cat,'beneficiary',person);
end $function$
;
CREATE OR REPLACE FUNCTION public.lts_review_suggestions_v231(p_user_id uuid, p_targets jsonb)
 RETURNS TABLE(source_table text, source_ref text, suggestion jsonb)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH targets AS MATERIALIZED (
 SELECT t.*,coalesce(s.resource_type='transaction' AND s.signed_amount<0 AND s.normalized_payload->>'operation_type' IN('PIX','TED') AND s.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF',false) person_transfer,
 public.lts_card_merchant_key_v226(t.description) merchant_key,
  public.lts_bank_merchant_key_v231(t.description) bank_key,
  s.raw_payload#>>'{creditCardMetadata,cardNumber}' last4,
  CASE WHEN s.raw_payload#>>'{creditCardMetadata,totalInstallments}' ~ '^[0-9]+$' THEN (s.raw_payload#>>'{creditCardMetadata,totalInstallments}')::int END installments,
  CASE WHEN s.raw_payload#>>'{creditCardMetadata,purchaseDate}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' THEN ((s.raw_payload#>>'{creditCardMetadata,purchaseDate}')::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date::text ELSE left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10) END purchase_date
 FROM jsonb_to_recordset(p_targets) t(source_table text,source_ref text,description text,amount numeric,event_date date,category text,question_kind text)
 LEFT JOIN public.lts_open_finance_staging s ON t.source_table='lts_open_finance_staging' AND s.user_id=p_user_id AND s.id::text=t.source_ref
), raw_history AS MATERIALIZED (
 SELECT 'card_purchase_detail'::text st,p.line_key sr,p.description_raw description,p.category,p.installment_amount amount,
  p.invoice_due_date event_date,p.purchase_date,p.card_final last4,p.installments,null::text person,null::text property_code
 FROM public.lts_card_purchase_detail p WHERE p.user_id=p_user_id
 UNION ALL
 SELECT 'financial_events',p.id::text,p.description_raw,p.category,abs(p.amount),p.event_date,null,null,null,
  coalesce(p.metadata->>'center_cost',p.metadata->>'cost_center',p.metadata#>>'{user_classification_20260913,beneficiary}'),null
 FROM public.financial_events p WHERE p.user_id=p_user_id AND NOT p.is_suppressed AND NOT p.is_projection
 UNION ALL
 SELECT 'lts_document_card_purchase',p.id::text,p.description,p.category,p.amount,p.purchase_date,p.purchase_date,
  p.metadata->>'last4',null,p.cost_center,null FROM public.lts_document_card_purchase p WHERE p.user_id=p_user_id AND p.status<>'cancelled'
 UNION ALL
 SELECT 'lts_manual_card_purchase',p.id::text,p.description,p.category,p.amount,p.purchase_date,p.purchase_date,
  p.metadata->>'last4',null,p.cost_center,null FROM public.lts_manual_card_purchase p WHERE p.user_id=p_user_id AND p.status<>'cancelled'
 UNION ALL
 SELECT 'lts_card_history_recovered_purchase',p.source_hash,p.description_raw,coalesce(p.canonical_category,p.category_raw),p.amount,p.invoice_due_date,
  null,p.card_final,null,p.evidence->>'center_cost',null FROM public.lts_card_history_recovered_purchase p WHERE p.user_id=p_user_id
 UNION ALL
 SELECT 'card_invoice_current_items',p.id::text||':'||(i->>'source_line'),i->>'description',i->>'category',
  CASE WHEN coalesce(i->>'amount','') ~ '^-?[0-9]+([.][0-9]+)?$' THEN (i->>'amount')::numeric END,
  p.due_date,CASE WHEN i->>'purchase_date' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN (i->>'purchase_date')::date END,
  coalesce(i->>'last4',i->>'card_final'),CASE WHEN i->>'total_installments' ~ '^[0-9]+$' THEN (i->>'total_installments')::int END,
  coalesce(i->>'cost_center',i->>'center_cost'),null
 FROM public.card_invoices p CROSS JOIN LATERAL jsonb_array_elements(coalesce(p.metadata->'items','[]')) i WHERE p.user_id=p_user_id
 UNION ALL
 SELECT 'lts_open_finance_staging',s.id::text,s.description_raw,d.category_label,abs(s.signed_amount),s.posting_date,
  CASE WHEN s.raw_payload#>>'{creditCardMetadata,purchaseDate}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' THEN ((s.raw_payload#>>'{creditCardMetadata,purchaseDate}')::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date WHEN left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10)::date END,
  s.raw_payload#>>'{creditCardMetadata,cardNumber}',CASE WHEN s.raw_payload#>>'{creditCardMetadata,totalInstallments}' ~ '^[0-9]+$' THEN (s.raw_payload#>>'{creditCardMetadata,totalInstallments}')::int END,
  d.beneficiary,d.property_code
 FROM public.lts_open_finance_staging s JOIN public.lts_v178_review_decision d ON d.user_id=s.user_id AND d.source_table='lts_open_finance_staging' AND d.source_ref=s.id::text
 WHERE s.user_id=p_user_id AND s.provider_deleted_at IS NULL
 UNION ALL
 SELECT 'historico_analitico',h.idx::text,h.dados->>'desc',coalesce(h.dados->>'categoria',h.dados->>'cat'),
  abs((h.dados->>'valor')::numeric), (h.dados->>'dia')::date,null,null,null,coalesce(h.dados->>'center_cost',h.dados->>'cost_center'),null
 FROM public.historico_analitico h WHERE h.usuario_id=p_user_id AND h.dados->>'valor' ~ '^-?[0-9]+([.][0-9]+)?$'
  AND h.dados->>'dia' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
), history_names AS MATERIALIZED (
 SELECT DISTINCT coalesce(description,'') description FROM raw_history
), history_keys AS MATERIALIZED (
 SELECT description,public.lts_card_merchant_key_v226(description) merchant_key,
 public.lts_bank_merchant_key_v231(description) bank_key FROM history_names
), history AS MATERIALIZED (
 SELECT h.*,coalesce(d.category_label,h.category) decided_category,
  coalesce(d.beneficiary,h.person,substring(coalesce(d.category_label,h.category) from '^(Lucas|Larissa|Benjamin)')) decided_person,
  coalesce(d.property_code,h.property_code) decided_property,
  k.merchant_key,k.bank_key
 FROM raw_history h JOIN history_keys k ON k.description=coalesce(h.description,'') LEFT JOIN public.lts_v178_review_decision d ON d.user_id=p_user_id AND d.source_table=h.st AND d.source_ref=h.sr
 WHERE pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(coalesce(d.category_label,h.category),''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') NOT IN ('','a classificar','nao identificado','sem categoria','—')
), candidates AS (
 SELECT t.source_table,t.source_ref,h.decided_category category,h.decided_person person,h.decided_property property_code,
  CASE WHEN h.st='lts_open_finance_staging' AND t.last4=h.last4 AND t.installments=h.installments AND t.purchase_date=h.purchase_date::text AND abs(t.amount-h.amount)<.005 THEN 10
       WHEN t.last4=h.last4 AND t.installments=h.installments AND t.purchase_date=h.purchase_date::text AND abs(t.amount-h.amount)<=.05 THEN 15
       WHEN t.merchant_key=h.merchant_key AND abs(t.amount-h.amount)<.005 THEN 20
       WHEN t.merchant_key=h.merchant_key AND abs(t.amount-h.amount)<=.05 AND t.last4=h.last4 THEN 25
       ELSE 45 END priority,
  CASE WHEN t.last4=h.last4 AND t.installments=h.installments AND t.purchase_date=h.purchase_date::text AND abs(t.amount-h.amount)<=.05 THEN 'same_purchase_installments'
       WHEN t.merchant_key=h.merchant_key AND abs(t.amount-h.amount)<.005 THEN 'same_merchant_amount_history'
       WHEN t.merchant_key=h.merchant_key AND abs(t.amount-h.amount)<=.05 THEN 'merchant_card_near_amount_history'
       ELSE 'merchant_history' END basis,
  jsonb_build_object('source_table',h.st,'source_ref',h.sr,'date',h.event_date,'description',h.description,'amount',h.amount,'category',h.decided_category) evidence,
  null::text note,null::text source_url
 FROM targets t JOIN history h ON (t.merchant_key=h.merchant_key OR t.bank_key=h.bank_key)
  AND NOT (h.st=t.source_table AND h.sr=t.source_ref)
 WHERE (t.question_kind='classification'
 OR (t.question_kind='person' AND h.decided_person IS NOT NULL AND abs(t.event_date-h.event_date)<=100)
 OR (t.question_kind IN ('property','property_purpose') AND h.decided_property IS NOT NULL AND abs(t.event_date-h.event_date)<=100))
 AND (t.merchant_key !~ 'mercado|amazon|shopee|pagseguro|merpago' OR abs(t.amount-h.amount)<=.05)
 UNION ALL
 SELECT t.source_table,t.source_ref,r.category,r.center_cost,null,35,'confirmed_rule',
  jsonb_build_object('rule',r.id,'description',r.match_value,'category',r.category),null,null
 FROM targets t JOIN public.lts_semantic_rule r ON r.user_id=p_user_id AND r.active
  AND r.confidence IN ('user_confirmed','high','alta','system_high')
  AND ((r.match_type='exact' AND public.lts_card_merchant_key_v226(r.match_value)=t.merchant_key)
   OR (r.match_type='prefix' AND public.lts_bank_merchant_key_v231(r.match_value)=t.bank_key))
 WHERE t.question_kind='classification'
 UNION ALL
 SELECT t.source_table,t.source_ref,s.category,null,null,50,s.basis,'{}',s.note,s.source_url
 FROM targets t JOIN public.lts_v229_review_suggestion s ON s.user_id=p_user_id AND s.source_table=t.source_table AND s.source_ref=t.source_ref
 WHERE t.question_kind='classification' AND s.category IS NOT NULL
 UNION ALL
 SELECT t.source_table,t.source_ref,s.category,null,null,60,'public_merchant_source','{}',s.note,s.source_url
 FROM targets t JOIN public.lts_merchant_research_v231 s ON s.user_id=p_user_id AND s.merchant_key=t.merchant_key
 WHERE t.question_kind='classification' AND s.category IS NOT NULL
), ranked AS (
 SELECT *,min(priority) OVER(PARTITION BY source_table,source_ref) best FROM candidates
), best AS (
 SELECT source_table,source_ref,count(DISTINCT category) category_count,
  CASE WHEN count(DISTINCT category)=1 THEN min(category) END category,
  CASE WHEN count(DISTINCT person)=1 THEN min(person) END person,
  CASE WHEN count(DISTINCT property_code)=1 THEN min(property_code) END property_code,
  min(basis) basis,min(note) note,min(source_url) source_url,count(*) evidence_count,
  (jsonb_agg(DISTINCT evidence))->0 evidence,
  jsonb_agg(DISTINCT category) alternatives
 FROM ranked WHERE priority=best GROUP BY source_table,source_ref
)
SELECT t.source_table,t.source_ref,
 CASE WHEN t.person_transfer AND t.question_kind='classification' THEN jsonb_build_object('category',null,'requires_confirmation',true,'alternatives','[]'::jsonb,'basis','recipient_does_not_establish_purpose','note','O destinatário não comprova a finalidade desta transferência. Confirme o que foi pago.')
 WHEN b.category IS NOT NULL THEN jsonb_build_object('category',b.category,'beneficiary',b.person,'property_code',b.property_code,
  'basis',b.basis,'source_url',b.source_url,'evidence_count',b.evidence_count,'evidence',b.evidence,'requires_confirmation',true,
  'note',coalesce(b.note,CASE b.basis
   WHEN 'same_purchase_installments' THEN 'Sugestão baseada em parcela da mesma compra. Confira e confirme.'
   WHEN 'same_merchant_amount_history' THEN 'Mesmo estabelecimento e valor no histórico. Confira e confirme.'
   WHEN 'merchant_card_near_amount_history' THEN 'Mesmo estabelecimento e cartão; pequena diferença de centavos entre parcelas. Confira e confirme.'
   WHEN 'confirmed_rule' THEN 'Regra já confirmada no histórico. Confira se vale para esta compra.'
   ELSE 'Sugestão do histórico deste estabelecimento. Confira e confirme.' END))
 ELSE jsonb_build_object('category',null,'requires_confirmation',true,
  'alternatives',coalesce(b.alternatives,'[]'),'basis',CASE WHEN b.category_count>1 THEN 'conflicting_history' ELSE 'insufficient_evidence' END,
  'note',coalesce(r.note,s.note,CASE WHEN b.category_count>1 THEN 'O histórico tem classificações diferentes; confirme a finalidade deste lançamento.'
   WHEN t.question_kind='property' THEN 'A categoria está preservada. Falta somente identificar o imóvel.'
   WHEN t.question_kind='person' THEN 'A categoria está preservada. Falta somente identificar a pessoa.'
   WHEN t.merchant_key ~ 'mercado|amazon|shopee|pagseguro|merpago' THEN 'O nome identifica a plataforma, mas não o produto. A finalidade permanece a confirmar.'
   ELSE 'Não encontrei correspondência suficiente para sugerir com segurança.' END),'source_url',coalesce(r.source_url,s.source_url)) END
FROM targets t LEFT JOIN best b USING(source_table,source_ref)
LEFT JOIN public.lts_merchant_research_v231 r ON r.user_id=p_user_id AND r.merchant_key=t.merchant_key
LEFT JOIN public.lts_v229_review_suggestion s ON s.user_id=p_user_id AND s.source_table=t.source_table AND s.source_ref=t.source_ref
$function$
;
