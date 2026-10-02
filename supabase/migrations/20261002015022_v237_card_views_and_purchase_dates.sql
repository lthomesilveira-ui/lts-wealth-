-- Apply verified workbook formula membership consistently to card history and detail.
-- Source records remain intact; excluded original rows stay available for audit.
CREATE OR REPLACE FUNCTION public.lts_card_workbook_cycles_v226(p_user_id uuid)
 RETURNS jsonb LANGUAGE sql STABLE SET search_path TO ''
AS $function$
WITH formula_valid AS MATERIALIZED (
 SELECT f.* FROM public.lts_card_formula_resolution_v237 f
 JOIN public.lts_card_workbook_evidence_v226 w ON w.user_id=f.user_id AND w.family=f.family AND w.reference_month=f.reference_month
 WHERE f.user_id=p_user_id
 GROUP BY f.user_id,f.family,f.reference_month,f.source_hash
 HAVING count(*)=f.expected_rows AND min(w.source_hash)=f.source_hash AND max(w.source_hash)=f.source_hash
 AND min(w.source_sheet)=f.source_sheet AND max(w.source_sheet)=f.source_sheet
 AND round(sum(w.amount),2)=f.raw_detail_total AND min(w.expected_invoice_amount)=f.invoice_amount AND max(w.expected_invoice_amount)=f.invoice_amount
 AND count(*) FILTER(WHERE EXISTS(SELECT 1 FROM jsonb_to_recordset(f.excluded_rows) x(source_row int,category text,amount numeric) WHERE x.source_row=w.source_row AND x.category=w.category AND x.amount=w.amount))=jsonb_array_length(f.excluded_rows)
), rows AS MATERIALIZED (
 SELECT w.*,EXISTS(SELECT 1 FROM jsonb_to_recordset(coalesce(f.excluded_rows,'[]')) x(source_row int,category text,amount numeric) WHERE x.source_row=w.source_row AND x.category=w.category AND x.amount=w.amount) formula_excluded
 FROM public.lts_card_workbook_evidence_v226 w LEFT JOIN formula_valid f ON f.user_id=w.user_id AND f.family=w.family AND f.reference_month=w.reference_month
 WHERE w.user_id=p_user_id
), cycles AS (
 SELECT family,reference_month,max(expected_invoice_amount) amount,count(*) raw_item_count,
 count(*) FILTER(WHERE NOT formula_excluded) item_count,sum(amount) raw_detail_total,
 sum(amount) FILTER(WHERE NOT formula_excluded) detail_total,
 jsonb_agg(jsonb_build_object('source_row',source_row,'source_sheet',source_sheet,'source_date',source_date,
 'category',category,'category_basis','historical_workbook','last4',last4,'amount',amount,
 'description','Linha '||source_row||' da planilha · estabelecimento não informado',
 'date_kind','reference_month','reference_month',reference_month,'purchase_date',null,'posting_date',null)
 ORDER BY source_row) FILTER(WHERE NOT formula_excluded) items,
 coalesce(jsonb_agg(jsonb_build_object('source_row',source_row,'source_sheet',source_sheet,'category',category,'amount',amount)
 ORDER BY source_row) FILTER(WHERE formula_excluded),'[]') excluded_items
 FROM rows GROUP BY family,reference_month
 HAVING count(distinct source_hash)=1 AND count(distinct expected_rows)=1 AND count(*)=max(expected_rows)
 AND count(distinct expected_invoice_amount)=1
)
SELECT coalesce(jsonb_agg(jsonb_build_object('family',c.family,'reference_month',c.reference_month,
 'bank',CASE WHEN c.family LIKE 'itau%' THEN 'Itaú' WHEN c.family='c6' THEN 'C6' ELSE 'Bradesco' END,
 'card_name',c.family,'due_date',null,'amount',c.amount,'item_count',c.item_count,'detail_total',c.detail_total,
 'difference',round(c.amount-c.detail_total,2),'detail_complete',round(c.amount-c.detail_total,2)=0,
 'source',CASE WHEN round(c.amount-c.detail_total,2)=0 THEN 'workbook_reconciled' ELSE 'workbook_partial' END,'items',c.items)
 ||CASE WHEN f.family IS NOT NULL AND round(c.detail_total,2)=f.invoice_amount THEN
 jsonb_build_object('formula_resolution',jsonb_build_object('source_note',f.source_note,'raw_detail_total',c.raw_detail_total,
 'raw_item_count',c.raw_item_count,'excluded_items',c.excluded_items,'formula_evidence',f.formula_evidence)) ELSE '{}' END
 ORDER BY c.reference_month DESC),'[]') FROM cycles c LEFT JOIN formula_valid f ON f.user_id=p_user_id AND f.family=c.family AND f.reference_month=c.reference_month
$function$;

CREATE OR REPLACE FUNCTION public.lts_review_suggestions_v231(p_user_id uuid, p_targets jsonb)
 RETURNS TABLE(source_table text, source_ref text, suggestion jsonb)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH targets AS MATERIALIZED (
 SELECT t.*,public.lts_card_merchant_key_v226(t.description) merchant_key,
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
), history AS MATERIALIZED (
 SELECT h.*,coalesce(d.category_label,h.category) decided_category,
  coalesce(d.beneficiary,h.person,substring(coalesce(d.category_label,h.category) from '^(Lucas|Larissa|Benjamin)')) decided_person,
  coalesce(d.property_code,h.property_code) decided_property,
  public.lts_card_merchant_key_v226(h.description) merchant_key,public.lts_bank_merchant_key_v231(h.description) bank_key
 FROM raw_history h LEFT JOIN public.lts_v178_review_decision d ON d.user_id=p_user_id AND d.source_table=h.st AND d.source_ref=h.sr
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
 CASE WHEN b.category IS NOT NULL THEN jsonb_build_object('category',b.category,'beneficiary',b.person,'property_code',b.property_code,
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

