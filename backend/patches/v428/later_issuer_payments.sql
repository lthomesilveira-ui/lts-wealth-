-- Accept an issuer's appended later-cycle payments without changing a reviewed receipt.
-- No source row, documentary contract, payment or cash fact is written.
BEGIN;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='10s';
DO $guard$
BEGIN
 IF to_regprocedure('public.lts_card_later_issuer_payments_valid_v428(jsonb,jsonb,jsonb)') IS NOT NULL
 AND (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.lts_card_later_issuer_payments_valid_v428(jsonb,jsonb,jsonb)'))<>'1413ae19ccc99b594a3c313b0b400f58'
 THEN RAISE EXCEPTION 'V428_HELPER_CHANGED'; END IF;
END $guard$;
CREATE OR REPLACE FUNCTION public.lts_card_later_issuer_payments_valid_v428(
 p_invoice jsonb,p_contract jsonb,p_link jsonb)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $function$
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
$function$;
REVOKE ALL ON FUNCTION public.lts_card_later_issuer_payments_valid_v428(jsonb,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_later_issuer_payments_valid_v428(jsonb,jsonb,jsonb) TO service_role;

-- Exact-predecessor/replay checks and attribute-preserving changes are generated below.
DO $patch$
DECLARE spec jsonb; edit jsonb; target regprocedure; definition text; before_attrs jsonb; after_attrs jsonb; applied boolean:=false;
BEGIN
 FOR spec IN SELECT value FROM jsonb_array_elements($specs$[{"signature": "public.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)", "before_md5": "18ff33beb8fb18fd6e8e3cbc3773927c", "after_md5": "fae7df78dd9b93ef4ec0d687684a9575", "edits": [{"old": "AND ((p_invoice->'raw_payload') - 'updatedAt')=p_contract->'invoice_canonical_payload'", "new": "AND CASE WHEN p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351' THEN public.lts_card_later_issuer_payments_valid_v428(p_invoice,p_contract,p_link) ELSE ((p_invoice->'raw_payload') - 'updatedAt')=p_contract->'invoice_canonical_payload' END"}, {"old": "AND p_invoice#>'{raw_payload,payments}'=p_contract->'issuer_payments'", "new": "AND CASE WHEN p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351' AND p_contract->>'invoice_evidence_policy'='raw_except_updatedAt_v1' THEN public.lts_card_later_issuer_payments_valid_v428(p_invoice,p_contract,p_link) ELSE p_invoice#>'{raw_payload,payments}'=p_contract->'issuer_payments' END"}]}, {"signature": "public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb)", "before_md5": "991a801162907b2c92fa1773490c526b", "after_md5": "ae021358126947745f50673239ee2263", "edits": [{"old": "AND ((p_invoice->'raw_payload') - 'updatedAt')=p_contract->'invoice_canonical_payload'", "new": "AND CASE WHEN p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351' THEN public.lts_card_later_issuer_payments_valid_v428(p_invoice,p_contract,p_link) ELSE ((p_invoice->'raw_payload') - 'updatedAt')=p_contract->'invoice_canonical_payload' END"}, {"old": "AND p_invoice#>'{raw_payload,payments}'=p_contract->'issuer_payments'", "new": "AND CASE WHEN p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351' AND p_contract->>'invoice_evidence_policy'='raw_except_updatedAt_v1' THEN public.lts_card_later_issuer_payments_valid_v428(p_invoice,p_contract,p_link) ELSE p_invoice#>'{raw_payload,payments}'=p_contract->'issuer_payments' END"}]}]$specs$::jsonb) LOOP
  target:=to_regprocedure(spec->>'signature');
  IF target IS NULL THEN RAISE EXCEPTION 'V428_PREDECESSOR_MISSING'; END IF;
  SELECT to_jsonb(p) INTO before_attrs FROM pg_catalog.pg_proc p WHERE p.oid=target;
  definition:=pg_get_functiondef(target);
  IF before_attrs->>'prosecdef'<>'false'
   OR has_function_privilege('anon',target,'EXECUTE')
   OR has_function_privilege('authenticated',target,'EXECUTE')
   OR NOT has_function_privilege('service_role',target,'EXECUTE')
  THEN RAISE EXCEPTION 'V428_PREDECESSOR_CHANGED: %',target; END IF;
  IF md5(definition)=spec->>'after_md5' THEN CONTINUE; END IF;
  IF md5(definition) IS DISTINCT FROM spec->>'before_md5' THEN RAISE EXCEPTION 'V428_PREDECESSOR_CHANGED: %',target; END IF;
  FOR edit IN SELECT value FROM jsonb_array_elements(spec->'edits') LOOP
   IF (length(definition)-length(replace(definition,edit->>'old','')))/length(edit->>'old')<>1
   THEN RAISE EXCEPTION 'V428_EDIT_NOT_UNIQUE'; END IF;
   definition:=replace(definition,edit->>'old',edit->>'new');
  END LOOP;
  EXECUTE definition;
  applied:=true;
  SELECT to_jsonb(p) INTO after_attrs FROM pg_catalog.pg_proc p WHERE p.oid=target;
  IF (before_attrs-'prosrc') IS DISTINCT FROM (after_attrs-'prosrc')
   OR md5(pg_get_functiondef(target)) IS DISTINCT FROM spec->>'after_md5'
  THEN RAISE EXCEPTION 'V428_FUNCTION_ATTRIBUTES_CHANGED'; END IF;
 END LOOP;
 IF applied THEN
  UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;
 END IF;
END
$patch$;
NOTIFY pgrst,'reload schema';
COMMIT;
