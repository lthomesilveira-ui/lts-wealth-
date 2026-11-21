CREATE OR REPLACE FUNCTION public.lts_card_settlement_evidence_valid_v273(p_user_id uuid, p_payment_id uuid, p_link jsonb, p_invoice jsonb, p_payment jsonb, p_items jsonb, p_as_of date, p_contract jsonb, p_coverage jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
SELECT coalesce(

 (p_link-'created_at')=p_contract->'link_contract' AND p_contract->>'active'='true' AND p_contract->>'user_id'=p_user_id::text AND p_contract->>'payment_id'=p_payment_id::text
 AND p_contract->>'invoice_id'=p_link->>'invoice_source_id'
 AND (p_contract->>'amount')::numeric=(p_link->>'expected_amount')::numeric
 AND (SELECT jsonb_agg(jsonb_build_object('id',i->>'id','raw_hash',i->>'raw_hash','signed_amount',(i->>'signed_amount')::numeric,'status',i#>>'{normalized_payload,status}','raw_status',i#>>'{raw_payload,status}','operation_type',i#>>'{raw_payload,operationType}') ORDER BY i->>'id') FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END)i)=p_contract->'manifest'
 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END)i WHERE i#>>'{normalized_payload,status}' IS DISTINCT FROM 'POSTED' OR i#>>'{raw_payload,status}' IS DISTINCT FROM 'POSTED')
 AND jsonb_typeof(p_coverage)='array'
 AND (SELECT jsonb_agg(jsonb_build_object('id',e->>'source_ref','amount',(e->>'amount')::numeric,'competence_month',e->>'competence_month','coverage_mode',e->>'coverage_mode') ORDER BY e->>'source_ref') FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_coverage)='array' THEN p_coverage ELSE '[]'::jsonb END)e)
 = (SELECT jsonb_agg(jsonb_build_object('id',m->>'id','amount',-(m->>'signed_amount')::numeric,'competence_month',p_contract->>'competence_month','coverage_mode',p_contract->>'coverage_mode') ORDER BY m->>'id') FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_contract->'consumption_manifest')='array' THEN p_contract->'consumption_manifest' ELSE '[]'::jsonb END)m)
 AND
 p_link->>'user_id'=p_user_id::text AND p_invoice->>'user_id'=p_user_id::text AND p_payment->>'user_id'=p_user_id::text
 AND p_link->>'active'='true'
 AND p_link->>'payment_source_id'=p_payment_id::text AND p_payment->>'id'=p_payment_id::text
 AND p_link->>'invoice_source_id'=p_invoice->>'id' AND p_link->>'invoice_source_id'<>p_link->>'payment_source_id'
 AND p_invoice->>'resource_type'='invoice' AND p_payment->>'resource_type'='transaction'
 AND p_invoice->>'provider_deleted_at' IS NULL AND p_payment->>'provider_deleted_at' IS NULL
 AND p_invoice->>'institution_code'=p_link->>'institution_code' AND p_payment->>'institution_code'=p_link->>'institution_code'
 AND split_part(p_invoice->>'provider_record_id',':',1)=p_link->>'provider_item_id'
 AND split_part(p_payment->>'provider_record_id',':',1)=p_link->>'provider_item_id'
 AND p_invoice->>'provider_account_ref'=p_link->>'invoice_account_ref'
 AND p_payment->>'provider_account_ref'=p_link->>'payment_account_ref'
 AND p_invoice->>'currency'='BRL' AND p_payment->>'currency'='BRL'
 AND (p_link->>'expected_amount')::numeric>0
 AND (p_invoice->>'signed_amount')::numeric=(p_link->>'expected_amount')::numeric
 AND (p_payment->>'signed_amount')::numeric=-(p_link->>'expected_amount')::numeric
 AND p_invoice#>>'{normalized_payload,due_date}'=p_link->>'expected_due_date'
 AND p_invoice#>>'{normalized_payload,closing_date}'=p_link->>'expected_closing_date'
 AND p_payment->>'posting_date'=p_link->>'expected_payment_date'
 AND (p_link->>'expected_payment_date')::date>(p_link->>'expected_closing_date')::date
 AND (p_link->>'expected_payment_date')::date<=p_as_of
 AND p_payment#>>'{normalized_payload,status}'='POSTED' AND p_payment#>>'{raw_payload,status}'='POSTED'
 AND p_payment#>>'{normalized_payload,account_type}'='CHECKING_ACCOUNT'
 AND p_invoice->>'raw_hash'=p_contract->>'invoice_current_hash' AND p_invoice#>'{raw_payload,payments}'=p_contract->'issuer_payments'
 AND jsonb_array_length(p_contract->'settlement_manifest')=1
 AND (SELECT sum((pay->>'amount')::numeric) FROM jsonb_array_elements(p_contract->'issuer_payments')pay WHERE pay->>'valueType'='FULL_PAYMENT' AND pay->>'paymentMode'='DEBIT_ACCOUNT' AND pay->>'currencyCode'='BRL')=(p_link->>'expected_amount')::numeric AND p_payment->>'raw_hash'=p_link->>'payment_raw_hash'
 AND jsonb_typeof(p_link->'documentary_sources')='array' AND jsonb_array_length(CASE WHEN jsonb_typeof(p_link->'documentary_sources')='array' THEN p_link->'documentary_sources' ELSE '[]'::jsonb END)>=2
 AND nullif(p_invoice#>>'{normalized_payload,provider_id}','') IS NOT NULL
 AND jsonb_typeof(p_items)='array' AND jsonb_array_length(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END)>0
 AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END) i WHERE NOT coalesce(
   i->>'user_id'=p_user_id::text AND i->>'resource_type'='card_transaction' AND i->>'provider_deleted_at' IS NULL
   AND i->>'institution_code'=p_link->>'institution_code' AND i->>'currency'='BRL'
   AND i->>'provider_account_ref'=p_link->>'invoice_account_ref'
   AND i#>>'{raw_payload,creditCardMetadata,billId}'=p_invoice#>>'{normalized_payload,provider_id}'
   AND i->>'signed_amount' IS NOT NULL,false))
 AND (SELECT count(DISTINCT i->>'id')=count(*) FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END) i)
 AND (SELECT sum(-(i->>'signed_amount')::numeric) FILTER(WHERE i#>>'{raw_payload,operationType}' IS DISTINCT FROM 'PAGAMENTO_FATURA') FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END) i)=(p_link->>'expected_amount')::numeric
,false)
$function$
;
