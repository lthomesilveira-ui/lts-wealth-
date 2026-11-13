DO $migration$ DECLARE applied boolean:=false;BEGIN IF to_regprocedure('public.lts_invoice_payment_order_equal_v442(jsonb,jsonb)') IS NULL THEN applied:=true;ELSIF (SELECT prosrc FROM pg_proc WHERE oid=to_regprocedure('public.lts_invoice_payment_order_equal_v442(jsonb,jsonb)'))IS DISTINCT FROM $body$
WITH p AS(SELECT CASE WHEN jsonb_typeof(p_invoice->'raw_payload')='object' THEN p_invoice->'raw_payload' END actual,
 CASE WHEN jsonb_typeof(p_contract->'invoice_canonical_payload')='object' THEN p_contract->'invoice_canonical_payload' END expected,p_contract->'issuer_payments' reviewed),
a AS(SELECT label,j FROM p CROSS JOIN LATERAL(VALUES('actual',actual->'payments'),('expected',expected->'payments'),('reviewed',reviewed))v(label,j)),
n AS(SELECT label,jsonb_agg(x ORDER BY x::text) normalized,
 count(*)=count(DISTINCT x->>'id') AND bool_and(jsonb_typeof(x)='object' AND nullif(x->>'id','')IS NOT NULL) valid
 FROM a CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(j)='array' THEN j ELSE '[]'::jsonb END)x GROUP BY label)
SELECT coalesce(jsonb_typeof(actual)='object' AND jsonb_typeof(expected)='object'
 AND (actual-'updatedAt'-'payments')=(expected-'payments')
 AND (SELECT count(*)=3 AND bool_and(CASE WHEN jsonb_typeof(j)='array' THEN jsonb_array_length(j)>0 ELSE false END) FROM a)
 AND (SELECT count(*)=3 AND bool_and(valid) AND count(DISTINCT normalized)=1 FROM n),false) FROM p
$body$ OR (SELECT provolatile<>'i' OR prosecdef OR prorettype<>'boolean'::regtype FROM pg_proc WHERE oid=to_regprocedure('public.lts_invoice_payment_order_equal_v442(jsonb,jsonb)'))THEN RAISE EXCEPTION 'V442 existing payment helper changed';END IF;applied:=applied OR md5(pg_get_functiondef('public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb)'::regprocedure))<>'c7fe16708fd3a9a1a768c0cfa8ee9a8c' OR md5(pg_get_functiondef('public.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)'::regprocedure))<>'77b372ac5c0dafdcc7ee179a2ee7b822';EXECUTE $helper$-- A provider may reorder payments. Retain every reviewed identity and field.
CREATE OR REPLACE FUNCTION public.lts_invoice_payment_order_equal_v442(p_invoice jsonb,p_contract jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $function$
WITH p AS(SELECT CASE WHEN jsonb_typeof(p_invoice->'raw_payload')='object' THEN p_invoice->'raw_payload' END actual,
 CASE WHEN jsonb_typeof(p_contract->'invoice_canonical_payload')='object' THEN p_contract->'invoice_canonical_payload' END expected,p_contract->'issuer_payments' reviewed),
a AS(SELECT label,j FROM p CROSS JOIN LATERAL(VALUES('actual',actual->'payments'),('expected',expected->'payments'),('reviewed',reviewed))v(label,j)),
n AS(SELECT label,jsonb_agg(x ORDER BY x::text) normalized,
 count(*)=count(DISTINCT x->>'id') AND bool_and(jsonb_typeof(x)='object' AND nullif(x->>'id','')IS NOT NULL) valid
 FROM a CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(j)='array' THEN j ELSE '[]'::jsonb END)x GROUP BY label)
SELECT coalesce(jsonb_typeof(actual)='object' AND jsonb_typeof(expected)='object'
 AND (actual-'updatedAt'-'payments')=(expected-'payments')
 AND (SELECT count(*)=3 AND bool_and(CASE WHEN jsonb_typeof(j)='array' THEN jsonb_array_length(j)>0 ELSE false END) FROM a)
 AND (SELECT count(*)=3 AND bool_and(valid) AND count(DISTINCT normalized)=1 FROM n),false) FROM p
$function$;
REVOKE ALL ON FUNCTION public.lts_invoice_payment_order_equal_v442(jsonb,jsonb)FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_invoice_payment_order_equal_v442(jsonb,jsonb)TO service_role;
$helper$;DO $patch$ DECLARE s text;a jsonb;BEGIN SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO STRICT s,a FROM pg_proc p WHERE p.oid='public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb)'::regprocedure;IF md5(s)='c7fe16708fd3a9a1a768c0cfa8ee9a8c' THEN RETURN;END IF;IF md5(s)<>'ae021358126947745f50673239ee2263' THEN RAISE EXCEPTION 'V442 payment evidence predecessor changed';END IF;EXECUTE $candidate$CREATE OR REPLACE FUNCTION public.lts_card_settlement_evidence_valid_v273(p_user_id uuid, p_payment_id uuid, p_link jsonb, p_invoice jsonb, p_payment jsonb, p_items jsonb, p_as_of date, p_contract jsonb, p_coverage jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
SELECT coalesce(
 CASE WHEN p_contract->>'item_settlement_policy'='canonical_invoice_payment_flags_v351' THEN
 p_link->>'institution_code'='336' AND p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351' AND
 (SELECT jsonb_agg(m->>'id'ORDER BY m->>'id')FROM jsonb_array_elements(p_contract->'consumption_manifest')m)
 =(SELECT jsonb_agg(i->>'id'ORDER BY i->>'id')FROM jsonb_array_elements(p_items)i WHERE NOT public.lts_card_item_is_invoice_payment_v351(i))
 ELSE true END AND

 (p_link-'created_at')=p_contract->'link_contract' AND p_contract->>'active'='true' AND p_contract->>'user_id'=p_user_id::text AND p_contract->>'payment_id'=p_payment_id::text
 AND p_contract->>'invoice_id'=p_link->>'invoice_source_id'
 AND (p_contract->>'amount')::numeric=(p_link->>'expected_amount')::numeric
 AND CASE WHEN p_contract->>'item_evidence_policy'='raw_except_order_updatedAt_v290' THEN
 (SELECT jsonb_agg(jsonb_build_object('id',i->>'id','signed_amount',(i->>'signed_amount')::numeric,
  'status',i#>>'{normalized_payload,status}','raw_status',i#>>'{raw_payload,status}',
  'operation_type',i#>>'{raw_payload,operationType}') ORDER BY i->>'id')
  FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END)i)
 =(SELECT jsonb_agg(m-'raw_hash' ORDER BY m->>'id') FROM jsonb_array_elements(p_contract->'manifest')m)
 AND (SELECT jsonb_agg(jsonb_build_object('id',i->>'id','sha256',
  encode(sha256(convert_to(((i->'raw_payload')-'order'-'updatedAt')::text,'UTF8')),'hex')) ORDER BY i->>'id')
  FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END)i)
 =p_contract->'item_canonical_manifest'
 ELSE (SELECT jsonb_agg(jsonb_build_object('id',i->>'id','raw_hash',i->>'raw_hash','signed_amount',(i->>'signed_amount')::numeric,'status',i#>>'{normalized_payload,status}','raw_status',i#>>'{raw_payload,status}','operation_type',i#>>'{raw_payload,operationType}') ORDER BY i->>'id') FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END)i)=p_contract->'manifest' END
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
 AND (CASE WHEN p_contract->>'invoice_evidence_policy'='raw_except_updatedAt_v1' THEN
   jsonb_typeof(p_invoice->'raw_payload')='object'
   AND jsonb_typeof(p_contract->'invoice_canonical_payload')='object'
   AND jsonb_typeof(p_invoice#>'{raw_payload,updatedAt}')='string'
   AND p_invoice#>>'{raw_payload,updatedAt}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?Z$'
   AND CASE WHEN p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351' THEN public.lts_card_later_issuer_payments_valid_v428(p_invoice,p_contract,p_link) WHEN p_contract->>'issuer_settlement_policy'='one_full_payment_in_cycle_v301' THEN public.lts_invoice_payment_order_equal_v442(p_invoice,p_contract) ELSE ((p_invoice->'raw_payload') - 'updatedAt')=p_contract->'invoice_canonical_payload' END
 ELSE p_contract->>'invoice_evidence_policy' IS NULL
   AND p_invoice->>'raw_hash'=p_contract->>'invoice_current_hash' END) AND CASE WHEN p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351' AND p_contract->>'invoice_evidence_policy'='raw_except_updatedAt_v1' THEN public.lts_card_later_issuer_payments_valid_v428(p_invoice,p_contract,p_link) WHEN p_contract->>'issuer_settlement_policy'='one_full_payment_in_cycle_v301' THEN public.lts_invoice_payment_order_equal_v442(p_invoice,p_contract) ELSE p_invoice#>'{raw_payload,payments}'=p_contract->'issuer_payments' END
 AND jsonb_array_length(p_contract->'settlement_manifest')=1
 AND CASE WHEN p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351' THEN public.lts_card_cycle_settlement_v351(p_contract,p_link)IS NOT NULL AND p_payment->>'description_raw'=p_contract#>>'{reviewed_other_payment,bank_description}'
 WHEN p_contract->>'issuer_settlement_policy'='one_full_payment_in_cycle_v301'
 THEN public.lts_card_cycle_settlement_v301(p_contract,p_link) IS NOT NULL
 ELSE (SELECT sum((pay->>'amount')::numeric) FROM jsonb_array_elements(p_contract->'issuer_payments')pay WHERE pay->>'valueType'='FULL_PAYMENT' AND pay->>'paymentMode'='DEBIT_ACCOUNT' AND pay->>'currencyCode'='BRL')=(p_link->>'expected_amount')::numeric END AND p_payment->>'raw_hash'=p_link->>'payment_raw_hash'
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
 AND (SELECT sum(-(i->>'signed_amount')::numeric) FILTER(WHERE CASE WHEN p_contract->>'item_settlement_policy'='canonical_invoice_payment_flags_v351' THEN NOT public.lts_card_item_is_invoice_payment_v351(i) ELSE i#>>'{raw_payload,operationType}' IS DISTINCT FROM 'PAGAMENTO_FATURA'END) FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END) i)=(p_link->>'expected_amount')::numeric
,false)
$function$
$candidate$;IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid='public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb)'::regprocedure) OR md5(pg_get_functiondef('public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb)'::regprocedure))<>'c7fe16708fd3a9a1a768c0cfa8ee9a8c' THEN RAISE EXCEPTION 'V442 payment evidence attributes changed';END IF;END $patch$;
DO $patch$ DECLARE s text;a jsonb;BEGIN SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO STRICT s,a FROM pg_proc p WHERE p.oid='public.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)'::regprocedure;IF md5(s)='77b372ac5c0dafdcc7ee179a2ee7b822' THEN RETURN;END IF;IF md5(s)<>'fae7df78dd9b93ef4ec0d687684a9575' THEN RAISE EXCEPTION 'V442 payment evidence predecessor changed';END IF;EXECUTE $candidate$CREATE OR REPLACE FUNCTION public.lts_card_payment_refresh_annotation_v273(p_user_id uuid, p_link jsonb, p_invoice jsonb, p_payment jsonb, p_contract jsonb, p_as_of date)
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
   AND CASE WHEN p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351' THEN public.lts_card_later_issuer_payments_valid_v428(p_invoice,p_contract,p_link) WHEN p_contract->>'issuer_settlement_policy'='one_full_payment_in_cycle_v301' THEN public.lts_invoice_payment_order_equal_v442(p_invoice,p_contract) ELSE ((p_invoice->'raw_payload') - 'updatedAt')=p_contract->'invoice_canonical_payload' END
 ELSE p_contract->>'invoice_evidence_policy' IS NULL
   AND p_invoice->>'raw_hash'=p_contract->>'invoice_current_hash' END)
   AND CASE WHEN p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351' AND p_contract->>'invoice_evidence_policy'='raw_except_updatedAt_v1' THEN public.lts_card_later_issuer_payments_valid_v428(p_invoice,p_contract,p_link) WHEN p_contract->>'issuer_settlement_policy'='one_full_payment_in_cycle_v301' THEN public.lts_invoice_payment_order_equal_v442(p_invoice,p_contract) ELSE p_invoice#>'{raw_payload,payments}'=p_contract->'issuer_payments' END
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
$candidate$;IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid='public.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)'::regprocedure) OR md5(pg_get_functiondef('public.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)'::regprocedure))<>'77b372ac5c0dafdcc7ee179a2ee7b822' THEN RAISE EXCEPTION 'V442 payment evidence attributes changed';END IF;END $patch$;IF applied THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;END IF;END $migration$;
