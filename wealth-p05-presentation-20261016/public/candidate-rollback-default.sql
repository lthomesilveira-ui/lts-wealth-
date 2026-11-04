-- Candidate only: not authorized for production.
BEGIN;
SET LOCAL statement_timeout='15s';
SET LOCAL lock_timeout='2s';
-- LOCAL CANDIDATE ONLY. Pure, private presentation projection. No source writes.
-- The private contract's manifests are neither needed nor returned: this asserts
-- issuer payment evidence and a posted bank debit, never expense coverage.
CREATE OR REPLACE FUNCTION public.lts_card_payment_refresh_annotation_v273(
 p_user_id uuid,p_link jsonb,p_invoice jsonb,p_payment jsonb,p_contract jsonb,p_as_of date)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path TO '' AS $annotation$
DECLARE pay jsonb; issuer_date date; bank_date date; due_date date; closing_date date; amount numeric;
BEGIN
 IF jsonb_typeof(p_link) IS DISTINCT FROM 'object'
 OR jsonb_typeof(p_invoice) IS DISTINCT FROM 'object'
 OR jsonb_typeof(p_payment) IS DISTINCT FROM 'object'
 OR jsonb_typeof(p_contract) IS DISTINCT FROM 'object'
 OR jsonb_typeof(p_contract->'issuer_payments') IS DISTINCT FROM 'array'
 OR jsonb_typeof(p_link->'documentary_sources') IS DISTINCT FROM 'array' THEN RETURN NULL; END IF;
 IF jsonb_array_length(p_contract->'issuer_payments')<>1 THEN RETURN NULL; END IF;
 pay:=p_contract->'issuer_payments'->0;
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
   AND pay->>'valueType'='FULL_PAYMENT' AND pay->>'paymentMode'='DEBIT_ACCOUNT'
   AND pay->>'currencyCode'='BRL'
   AND issuer_date>closing_date AND issuer_date<=p_as_of
   AND bank_date>closing_date AND bank_date<=p_as_of
   AND jsonb_typeof(p_link->'documentary_sources')='array'
   AND jsonb_array_length(p_link->'documentary_sources')>=2,false) THEN RETURN NULL; END IF;
 RETURN jsonb_build_object(
   'status','identified_in_statement',
   'basis','reviewed_original_link_and_exact_issuer_refresh',
   'payment_date',bank_date,'bank_posting_date',bank_date,'bank_posting_status','POSTED',
   'issuer_payment_date',issuer_date,'issuer_payment_type','FULL_PAYMENT',
   'amount',amount,'currency','BRL','cash_effect','none');
EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow OR numeric_value_out_of_range THEN
 RETURN NULL;
END
$annotation$;
REVOKE ALL ON FUNCTION public.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date) FROM PUBLIC,anon,authenticated,service_role;
-- No new client RPC. The existing authenticated definer wrapper owns execution.

GRANT EXECUTE ON FUNCTION public.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_card_documentary_payment_presentation_v272(p_user_id uuid,p_payload jsonb)
RETURNS jsonb LANGUAGE sql STABLE SET search_path TO '' SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH links AS MATERIALIZED (
 SELECT l.id,l.invoice_source_id,l.expected_amount,l.expected_payment_date,l.expected_due_date,
 public.lts_card_payment_refresh_annotation_v273(p_user_id,to_jsonb(l),to_jsonb(b),to_jsonb(t),
   sc.payload,current_date) refreshed_annotation,
 coalesce(
   b.id IS NOT NULL AND t.id IS NOT NULL
   AND b.resource_type='invoice' AND t.resource_type='transaction'
   AND b.provider_deleted_at IS NULL AND t.provider_deleted_at IS NULL
   AND b.institution_code=l.institution_code AND t.institution_code=l.institution_code
   AND split_part(b.provider_record_id,':',1)=l.provider_item_id
   AND split_part(t.provider_record_id,':',1)=l.provider_item_id
   AND b.provider_account_ref=l.invoice_account_ref
   AND t.provider_account_ref=l.payment_account_ref
   AND b.currency='BRL' AND t.currency='BRL'
   AND b.signed_amount=l.expected_amount AND t.signed_amount=-l.expected_amount
   AND b.normalized_payload->>'due_date'=l.expected_due_date::text
   AND b.normalized_payload->>'closing_date'=l.expected_closing_date::text
   AND t.posting_date=l.expected_payment_date
   AND t.normalized_payload->>'status'='POSTED' AND t.raw_payload->>'status'='POSTED'
   AND l.expected_payment_date<=current_date
   AND b.raw_hash=l.invoice_raw_hash AND t.raw_hash=l.payment_raw_hash,false) valid
 FROM public.lts_card_documentary_payment_link_v272 l
 LEFT JOIN public.lts_open_finance_staging b ON b.id=l.invoice_source_id AND b.user_id=p_user_id
 LEFT JOIN public.lts_open_finance_staging t ON t.id=l.payment_source_id AND t.user_id=p_user_id
 LEFT JOIN public.lts_card_settlement_expense_contract_v273 sc
   ON sc.user_id=p_user_id AND sc.payment_source_id=l.payment_source_id AND sc.active
 WHERE l.user_id=p_user_id AND l.active
), cards AS (
 SELECT c.ord,CASE WHEN jsonb_typeof(c.value->'cycles')='array' THEN c.value||jsonb_build_object('cycles',coalesce((
 SELECT jsonb_agg((y.value-'documentary_payment_evidence')||CASE WHEN l.id IS NULL THEN '{}'::jsonb
 WHEN l.refreshed_annotation IS NOT NULL AND y.value->>'due_date'=l.expected_due_date::text AND CASE WHEN y.value->>'amount' ~ '^[0-9]+([.][0-9]+)?$' THEN (y.value->>'amount')::numeric=l.expected_amount ELSE false END THEN jsonb_build_object('documentary_payment_evidence',l.refreshed_annotation)
 WHEN l.valid AND y.value->>'due_date'=l.expected_due_date::text AND CASE WHEN y.value->>'amount' ~ '^[0-9]+([.][0-9]+)?$' THEN (y.value->>'amount')::numeric=l.expected_amount ELSE false END THEN jsonb_build_object('documentary_payment_evidence',jsonb_build_object(
 'status','identified_in_statement','basis','reviewed_documentary_alias_and_posted_bank_transaction',
 'payment_date',l.expected_payment_date,'amount',l.expected_amount,'currency','BRL','cash_effect','none'))
 ELSE jsonb_build_object('documentary_payment_evidence',jsonb_build_object('status','source_changed','cash_effect','none')) END ORDER BY y.ord)
 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(c.value->'cycles')='array' THEN c.value->'cycles' ELSE '[]'::jsonb END) WITH ORDINALITY y(value,ord)
 LEFT JOIN links l ON l.invoice_source_id::text=y.value->>'invoice_source_id'
 ),'[]'::jsonb)) ELSE c.value END value
 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_payload->'cards')='array' THEN p_payload->'cards' ELSE '[]'::jsonb END) WITH ORDINALITY c(value,ord)
)
SELECT CASE WHEN jsonb_typeof(p_payload->'cards')='array' THEN
jsonb_set(p_payload,'{cards}',coalesce((SELECT jsonb_agg(value ORDER BY ord) FROM cards),'[]'::jsonb),false)
ELSE p_payload END
$function$;
REVOKE ALL ON FUNCTION public.lts_card_documentary_payment_presentation_v272(uuid,jsonb) FROM PUBLIC,anon,authenticated;

ROLLBACK;
