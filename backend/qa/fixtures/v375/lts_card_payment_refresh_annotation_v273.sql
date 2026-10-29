CREATE OR REPLACE FUNCTION public.lts_card_payment_refresh_annotation_v273(p_user_id uuid, p_link jsonb, p_invoice jsonb, p_payment jsonb, p_contract jsonb, p_as_of date)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE pay jsonb; issuer_date date; bank_date date; due_date date; closing_date date; amount numeric;
BEGIN
 IF jsonb_typeof(p_link) IS DISTINCT FROM 'object'
 OR jsonb_typeof(p_invoice) IS DISTINCT FROM 'object'
 OR jsonb_typeof(p_payment) IS DISTINCT FROM 'object'
 OR jsonb_typeof(p_contract) IS DISTINCT FROM 'object'
 OR jsonb_typeof(p_contract->'issuer_payments') IS DISTINCT FROM 'array'
 OR jsonb_typeof(p_link->'documentary_sources') IS DISTINCT FROM 'array' THEN RETURN NULL; END IF;
 IF p_contract->>'issuer_settlement_policy'='one_full_payment_in_cycle_v301' THEN
  pay:=public.lts_card_cycle_settlement_v301(p_contract,p_link);
  IF pay IS NULL THEN RETURN NULL; END IF;
 ELSIF p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351' THEN
  pay:=public.lts_card_cycle_settlement_v351(p_contract,p_link);
  IF pay IS NULL OR p_payment->>'description_raw'IS DISTINCT FROM p_contract#>>'{reviewed_other_payment,bank_description}'THEN RETURN NULL;END IF;
 ELSE
  IF jsonb_array_length(p_contract->'issuer_payments')<>1 THEN RETURN NULL; END IF;
  pay:=p_contract->'issuer_payments'->0;
 END IF;
 -- Preserve the calendar date carried by the issuer, without timezone conversion.
 IF coalesce(pay->>'paymentDate','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?Z$'
 OR coalesce(p_link->>'expected_payment_date','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 OR coalesce(p_link->>'expected_due_date','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 OR coalesce(p_link->>'expected_closing_date','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN RETURN NULL; END IF;
 -- Also reject an invalid timestamp, not just a valid-looking date prefix.
 PERFORM (pay->>'paymentDate')::timestamptz;
 issuer_date:=left(pay->>'paymentDate',10)::date;
 bank_date:=(p_link->>'expected_payment_date')::date;
 due_date:=(p_link->>'expected_due_date')::date;
 closing_date:=(p_link->>'expected_closing_date')::date;
 amount:=(p_link->>'expected_amount')::numeric;
 IF NOT coalesce(
   p_user_id IS NOT NULL AND p_as_of IS NOT NULL
   AND (p_link-'created_at')=p_contract->'link_contract'
   AND p_contract->'active'='true'::jsonb AND p_link->'active'='true'::jsonb
   AND p_contract->>'user_id'=p_user_id::text AND p_link->>'user_id'=p_user_id::text
   AND p_invoice->>'user_id'=p_user_id::text AND p_payment->>'user_id'=p_user_id::text
   AND p_contract->>'payment_id'=p_link->>'payment_source_id'
   AND p_contract->>'invoice_id'=p_link->>'invoice_source_id'
   AND p_invoice->>'id'=p_link->>'invoice_source_id'
   AND p_payment->>'id'=p_link->>'payment_source_id'
   AND p_link->>'invoice_source_id'<>p_link->>'payment_source_id'
   AND nullif(p_contract->>'invoice_current_hash','') IS NOT NULL
   AND (CASE WHEN p_contract->>'invoice_evidence_policy'='raw_except_updatedAt_v1' THEN
   jsonb_typeof(p_invoice->'raw_payload')='object'
   AND jsonb_typeof(p_contract->'invoice_canonical_payload')='object'
   AND jsonb_typeof(p_invoice#>'{raw_payload,updatedAt}')='string'
   AND p_invoice#>>'{raw_payload,updatedAt}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?Z$'
   AND ((p_invoice->'raw_payload') - 'updatedAt')=p_contract->'invoice_canonical_payload'
 ELSE p_contract->>'invoice_evidence_policy' IS NULL
   AND p_invoice->>'raw_hash'=p_contract->>'invoice_current_hash' END)
   AND p_invoice#>'{raw_payload,payments}'=p_contract->'issuer_payments'
   AND nullif(p_link->>'payment_raw_hash','') IS NOT NULL
   AND p_payment->>'raw_hash'=p_link->>'payment_raw_hash'
   AND p_invoice->>'resource_type'='invoice' AND p_payment->>'resource_type'='transaction'
   AND p_invoice->>'provider_deleted_at' IS NULL AND p_payment->>'provider_deleted_at' IS NULL
   AND p_invoice->>'institution_code'=p_link->>'institution_code'
   AND p_payment->>'institution_code'=p_link->>'institution_code'
   AND split_part(p_invoice->>'provider_record_id',':',1)=p_link->>'provider_item_id'
   AND split_part(p_payment->>'provider_record_id',':',1)=p_link->>'provider_item_id'
   AND p_invoice->>'provider_account_ref'=p_link->>'invoice_account_ref'
   AND p_payment->>'provider_account_ref'=p_link->>'payment_account_ref'
   AND p_invoice->>'currency'='BRL' AND p_payment->>'currency'='BRL'
   AND amount>0 AND amount<10000000000000000
   AND (p_contract->>'amount')::numeric=amount AND (pay->>'amount')::numeric=amount
   AND (p_invoice->>'signed_amount')::numeric=amount
   AND (p_payment->>'signed_amount')::numeric=-amount
   AND p_invoice#>>'{normalized_payload,due_date}'=due_date::text
   AND p_invoice#>>'{normalized_payload,closing_date}'=closing_date::text
   AND p_payment->>'posting_date'=bank_date::text
   AND p_payment#>>'{normalized_payload,status}'='POSTED'
   AND p_payment#>>'{raw_payload,status}'='POSTED'
   AND p_payment#>>'{normalized_payload,account_type}'='CHECKING_ACCOUNT'
   AND pay->>'valueType'=CASE WHEN p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351' THEN 'OTHER_PAYMENT' ELSE 'FULL_PAYMENT' END AND pay->>'paymentMode'='DEBIT_ACCOUNT'
   AND pay->>'currencyCode'='BRL'
   AND issuer_date>closing_date AND issuer_date<=p_as_of
   AND bank_date>closing_date AND bank_date<=p_as_of
   AND jsonb_typeof(p_link->'documentary_sources')='array'
   AND jsonb_array_length(p_link->'documentary_sources')>=2,false) THEN RETURN NULL; END IF;
 RETURN jsonb_build_object(
   'status','identified_in_statement',
   'basis',CASE WHEN p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351' THEN 'reviewed_c6_other_payment_and_exact_posted_debit_v351' ELSE 'reviewed_original_link_and_exact_issuer_refresh' END,
   'payment_date',bank_date,'bank_posting_date',bank_date,'bank_posting_status','POSTED',
   'issuer_payment_date',issuer_date,'issuer_payment_type',pay->>'valueType',
   'amount',amount,'currency','BRL','cash_effect','none');
EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow OR numeric_value_out_of_range THEN
 RETURN NULL;
END
$function$
;
