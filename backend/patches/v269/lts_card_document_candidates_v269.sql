CREATE OR REPLACE FUNCTION public.lts_card_document_candidates_v269(p_user_id uuid)
RETURNS TABLE(document_id uuid,provider_id uuid,dc bigint,pc bigint)
LANGUAGE sql STABLE SET search_path='' AS $function$
WITH identities AS MATERIALIZED (SELECT * FROM public.lts_c6_cycle_identity_v269(p_user_id)), documents AS MATERIALIZED (
  SELECT * FROM public.lts_card_document_supplement_v234 WHERE user_id=p_user_id
 ), candidates AS MATERIALIZED (
  SELECT d.id document_id,s.id provider_id
  FROM documents d JOIN public.lts_open_finance_staging s ON s.user_id=d.user_id
  AND s.institution_code=d.institution_code AND s.provider_account_ref=d.provider_account_ref
  AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL
  AND coalesce(s.raw_payload#>>'{creditCardMetadata,cardNumber}',s.normalized_payload->>'last4')
      IN (d.last4,d.metadata->>'original_card_last4')
  AND public.lts_card_merchant_key_v226(s.description_raw)=public.lts_card_merchant_key_v226(d.description)
  AND abs(-s.signed_amount-d.amount)<=0.15
  AND s.raw_payload#>>'{creditCardMetadata,installmentNumber}'=d.installment_number::text
  AND s.raw_payload#>>'{creditCardMetadata,totalInstallments}'=d.total_installments::text
  AND CASE WHEN left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
      THEN abs(left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10)::date-d.purchase_date)<=2 ELSE false END
  AND (EXISTS(SELECT 1 FROM identities ci WHERE ci.source_id=s.id AND ci.reference_month=d.reference_month AND ci.due_date=d.due_date)
   OR (NOT EXISTS(SELECT 1 FROM identities ci WHERE ci.source_id=s.id) AND s.raw_payload#>>'{creditCardMetadata,billForecastDate}'=to_char(d.reference_month,'YYYY-MM'))
   OR EXISTS(SELECT 1 FROM public.lts_open_finance_staging b
    WHERE b.user_id=s.user_id AND b.institution_code=s.institution_code AND b.provider_account_ref=s.provider_account_ref AND b.resource_type='invoice'
    AND b.provider_deleted_at IS NULL AND b.normalized_payload->>'provider_id'=s.raw_payload#>>'{creditCardMetadata,billId}'
    AND date_trunc('month',b.posting_date)::date=d.reference_month))
 ), unique_candidates AS (
  SELECT *,count(*) OVER(PARTITION BY document_id) dc,count(*) OVER(PARTITION BY provider_id) pc FROM candidates
 )
SELECT document_id,provider_id,dc,pc FROM unique_candidates;
$function$;
REVOKE ALL ON FUNCTION public.lts_card_document_candidates_v269(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_document_candidates_v269(uuid) TO service_role;
