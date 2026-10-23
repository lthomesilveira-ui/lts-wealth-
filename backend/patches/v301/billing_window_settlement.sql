-- V301: accept one exact issuer payment from its billing window.
-- Older cumulative issuer payments remain immutable source evidence.
CREATE OR REPLACE FUNCTION public.lts_card_cycle_settlement_v301(p_contract jsonb,p_link jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $fn$
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
END $fn$;
REVOKE ALL ON FUNCTION public.lts_card_cycle_settlement_v301(jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_cycle_settlement_v301(jsonb,jsonb) TO service_role;

DO $lease$
DECLARE d text;
BEGIN
 SELECT pg_get_functiondef('public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb)'::regprocedure) INTO d;
 IF md5(d)='cb47e826b312258f5841216e8f0f7b18' THEN RETURN; END IF;
 IF md5(d)<>'ceb89185c14534eef4f9b5d79508cbe4' OR strpos(d,$old$AND (SELECT sum((pay->>'amount')::numeric) FROM jsonb_array_elements(p_contract->'issuer_payments')pay WHERE pay->>'valueType'='FULL_PAYMENT' AND pay->>'paymentMode'='DEBIT_ACCOUNT' AND pay->>'currencyCode'='BRL')=(p_link->>'expected_amount')::numeric$old$)=0
 THEN RAISE EXCEPTION 'V301 reviewed reader lease changed'; END IF;
 EXECUTE replace(d,$old$AND (SELECT sum((pay->>'amount')::numeric) FROM jsonb_array_elements(p_contract->'issuer_payments')pay WHERE pay->>'valueType'='FULL_PAYMENT' AND pay->>'paymentMode'='DEBIT_ACCOUNT' AND pay->>'currencyCode'='BRL')=(p_link->>'expected_amount')::numeric$old$,$new$AND CASE WHEN p_contract->>'issuer_settlement_policy'='one_full_payment_in_cycle_v301'
 THEN public.lts_card_cycle_settlement_v301(p_contract,p_link) IS NOT NULL
 ELSE (SELECT sum((pay->>'amount')::numeric) FROM jsonb_array_elements(p_contract->'issuer_payments')pay WHERE pay->>'valueType'='FULL_PAYMENT' AND pay->>'paymentMode'='DEBIT_ACCOUNT' AND pay->>'currencyCode'='BRL')=(p_link->>'expected_amount')::numeric END$new$);
 IF md5(pg_get_functiondef('public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb)'::regprocedure))<>'cb47e826b312258f5841216e8f0f7b18'
 THEN RAISE EXCEPTION 'V301 replacement mismatch'; END IF;
END $lease$;

DO $lease$
DECLARE d text;
BEGIN
 SELECT pg_get_functiondef('public.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)'::regprocedure) INTO d;
 IF md5(d)='17be6c95beca64b23254e784cd1bd706' THEN RETURN; END IF;
 IF md5(d)<>'5d4e086ba848e8900c1378c070475f25' OR strpos(d,$old$IF jsonb_array_length(p_contract->'issuer_payments')<>1 THEN RETURN NULL; END IF;
 pay:=p_contract->'issuer_payments'->0;$old$)=0
 THEN RAISE EXCEPTION 'V301 reviewed reader lease changed'; END IF;
 EXECUTE replace(d,$old$IF jsonb_array_length(p_contract->'issuer_payments')<>1 THEN RETURN NULL; END IF;
 pay:=p_contract->'issuer_payments'->0;$old$,$new$IF p_contract->>'issuer_settlement_policy'='one_full_payment_in_cycle_v301' THEN
  pay:=public.lts_card_cycle_settlement_v301(p_contract,p_link);
  IF pay IS NULL THEN RETURN NULL; END IF;
 ELSE
  IF jsonb_array_length(p_contract->'issuer_payments')<>1 THEN RETURN NULL; END IF;
  pay:=p_contract->'issuer_payments'->0;
 END IF;$new$);
 IF md5(pg_get_functiondef('public.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)'::regprocedure))<>'17be6c95beca64b23254e784cd1bd706'
 THEN RAISE EXCEPTION 'V301 replacement mismatch'; END IF;
END $lease$;
