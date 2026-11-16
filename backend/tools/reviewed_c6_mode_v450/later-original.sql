CREATE OR REPLACE FUNCTION public.lts_card_later_issuer_payments_valid_v428(p_invoice jsonb, p_contract jsonb, p_link jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE original jsonb; current_payments jsonb; x jsonb; selected jsonb; bank_day date;
BEGIN
 IF p_contract->>'issuer_settlement_policy' IS DISTINCT FROM 'one_c6_other_payment_in_cycle_v351'
 OR p_contract->>'invoice_evidence_policy' IS DISTINCT FROM 'raw_except_updatedAt_v1'
 OR p_link->>'institution_code' IS DISTINCT FROM '336'
 OR jsonb_typeof(p_invoice->'raw_payload') IS DISTINCT FROM 'object'
 OR jsonb_typeof(p_contract->'invoice_canonical_payload') IS DISTINCT FROM 'object'
 OR jsonb_typeof(p_contract->'issuer_payments') IS DISTINCT FROM 'array'
 OR jsonb_typeof(p_invoice#>'{raw_payload,payments}') IS DISTINCT FROM 'array'
 OR coalesce(p_link->>'expected_payment_date','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 THEN RETURN false; END IF;
 original:=p_contract->'issuer_payments';
 current_payments:=p_invoice#>'{raw_payload,payments}';
 bank_day:=(p_link->>'expected_payment_date')::date;
 IF NOT coalesce(
  ((p_invoice->'raw_payload')-'updatedAt'-'payments')
    =((p_contract->'invoice_canonical_payload')-'payments')
  AND p_contract#>'{invoice_canonical_payload,payments}'=original,false)
 OR jsonb_array_length(original)=0 THEN RETURN false; END IF;
 -- The existing cycle selector validates dates, identity, uniqueness and the exact receipt.
 selected:=public.lts_card_cycle_settlement_v351(
  jsonb_set(p_contract,'{issuer_payments}',current_payments,false),p_link);
 IF selected IS NULL OR selected IS DISTINCT FROM
  public.lts_card_cycle_settlement_v351(p_contract,p_link) THEN RETURN false; END IF;
 -- Every previously reviewed payment must remain present byte-for-byte as JSONB.
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(original) o
  WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(current_payments) n WHERE n=o))
 THEN RETURN false; END IF;
 FOR x IN SELECT n FROM jsonb_array_elements(current_payments) n
  WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(original) o WHERE n=o)
 LOOP
  -- Added entries are allowed only after the reviewed bank payment's civil date.
  IF NOT coalesce(
   left(x->>'paymentDate',10)::date>bank_day
   AND x->>'valueType'='OTHER_PAYMENT' AND x->>'paymentMode'='DEBIT_ACCOUNT'
   AND x->>'currencyCode'='BRL' AND jsonb_typeof(x->'amount')='number'
   AND (x->>'amount')::numeric>0,false) THEN RETURN false; END IF;
 END LOOP;
 RETURN true;
EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format
 OR datetime_field_overflow OR numeric_value_out_of_range THEN RETURN false;
END
$function$
