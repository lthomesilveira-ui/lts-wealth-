-- Explicitly confirmed pairs supplement strict automatic identity; raw bank documents stay unchanged.
CREATE OR REPLACE FUNCTION public.lts_owner_confirmed_transfer_pairs_v263(p_user_id uuid)
RETURNS TABLE(debit_id uuid,credit_id uuid)
LANGUAGE sql STABLE SET search_path='' AS $fn$
SELECT d.id,c.id
FROM public.lts_external_reference_fact f
JOIN public.lts_bank_posted_rows_v231(p_user_id) d ON d.id::text=f.metadata->>'debit_id'
JOIN public.lts_bank_posted_rows_v231(p_user_id) c ON c.id::text=f.metadata->>'credit_id'
WHERE f.reference_key='owner_confirmed_internal_transfer_pair'
 AND f.confidence='user_confirmed' AND f.metadata->>'user_id'=p_user_id::text
 AND f.metadata->>'confirmation_kind'='explicit_exact_pair'
 AND d.raw_hash=f.metadata->>'debit_raw_hash' AND c.raw_hash=f.metadata->>'credit_raw_hash'
 AND d.signed_amount<0 AND c.signed_amount=-d.signed_amount
 AND d.posting_date=c.posting_date AND d.institution_code<>c.institution_code
 AND d.institution_code IN('341','237','336') AND c.institution_code IN('341','237','336')
 AND d.raw_payload#>>'{paymentData,payer,documentNumber,type}'='CPF'
 AND d.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
 AND c.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
 AND regexp_replace(d.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g')
    =regexp_replace(d.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g')
 AND regexp_replace(d.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g')
    =regexp_replace(c.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g')
 AND d.raw_payload#>>'{paymentData,receiver,routingNumber}'=c.institution_code
 AND c.raw_payload#>>'{paymentData,payer,routingNumber}'=d.institution_code
 AND EXISTS(SELECT 1 FROM public.lts_open_finance_staging a WHERE a.user_id=p_user_id
   AND a.resource_type='balance' AND a.provider_deleted_at IS NULL
   AND a.institution_code=d.institution_code AND a.provider_account_ref=d.provider_account_ref
   AND a.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
   AND regexp_replace(a.raw_payload->>'taxNumber','[^0-9]','','g') ~ '^[0-9]{11}$'
   AND regexp_replace(a.raw_payload->>'taxNumber','[^0-9]','','g')
      =regexp_replace(d.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g'))
 AND EXISTS(SELECT 1 FROM public.lts_open_finance_staging a WHERE a.user_id=p_user_id
   AND a.resource_type='balance' AND a.provider_deleted_at IS NULL
   AND a.institution_code=c.institution_code AND a.provider_account_ref=c.provider_account_ref
   AND a.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
   AND regexp_replace(a.raw_payload->>'taxNumber','[^0-9]','','g')
      =regexp_replace(c.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g'));
$fn$;
REVOKE ALL ON FUNCTION public.lts_owner_confirmed_transfer_pairs_v263(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_owner_confirmed_transfer_pairs_v263(uuid) TO service_role;
