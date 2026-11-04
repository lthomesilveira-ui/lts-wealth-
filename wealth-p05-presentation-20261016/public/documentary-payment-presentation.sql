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
