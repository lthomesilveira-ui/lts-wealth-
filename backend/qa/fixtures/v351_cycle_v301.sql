CREATE OR REPLACE FUNCTION public.lts_card_cycle_settlement_v301(p_contract jsonb, p_link jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE x jsonb; selected jsonb; close_day date; bank_day date; item_day date; amount numeric; n integer:=0;
BEGIN
 IF p_contract->>'issuer_settlement_policy' IS DISTINCT FROM 'one_full_payment_in_cycle_v301'
 OR jsonb_typeof(p_contract->'issuer_payments') IS DISTINCT FROM 'array'
 OR jsonb_typeof(p_contract->'settlement_manifest') IS DISTINCT FROM 'array'
 THEN RETURN NULL; END IF;
 IF jsonb_array_length(p_contract->'settlement_manifest')<>1
 OR coalesce(p_link->>'expected_closing_date','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 OR coalesce(p_link->>'expected_payment_date','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 THEN RETURN NULL; END IF;
 close_day:=(p_link->>'expected_closing_date')::date;
 bank_day:=(p_link->>'expected_payment_date')::date;
 amount:=(p_link->>'expected_amount')::numeric;
 IF bank_day<=close_day OR amount IS NULL OR amount<=0 THEN RETURN NULL; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_contract->'issuer_payments') a
  WHERE jsonb_typeof(a) IS DISTINCT FROM 'object' OR nullif(a->>'id','') IS NULL)
 OR (SELECT count(DISTINCT a->>'id')<>count(*) FROM jsonb_array_elements(p_contract->'issuer_payments') a)
 THEN RETURN NULL; END IF;
 FOR x IN SELECT value FROM jsonb_array_elements(p_contract->'issuer_payments') LOOP
  IF coalesce(x->>'paymentDate','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?Z$'
  THEN RETURN NULL; END IF;
  PERFORM (x->>'paymentDate')::timestamptz;
  -- Issuer dates are civil dates, not timestamps to move into the bank timezone.
  item_day:=left(x->>'paymentDate',10)::date;
  IF item_day>close_day AND item_day<=bank_day THEN
   IF NOT coalesce(x->>'valueType'='FULL_PAYMENT' AND x->>'paymentMode'='DEBIT_ACCOUNT'
    AND x->>'currencyCode'='BRL' AND jsonb_typeof(x->'amount')='number'
    AND (x->>'amount')::numeric=amount,false) THEN RETURN NULL; END IF;
   n:=n+1; selected:=x;
  END IF;
 END LOOP;
 IF n<>1 OR selected IS DISTINCT FROM p_contract->'settlement_manifest'->0 THEN RETURN NULL; END IF;
 RETURN selected;
EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow
 OR numeric_value_out_of_range THEN RETURN NULL;
END $function$

