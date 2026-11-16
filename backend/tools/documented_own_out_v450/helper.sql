CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.documented_own_out_v450(p_user_id uuid)
 RETURNS TABLE(source_id uuid, event_date date, signed_amount numeric)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
SELECT s.id,s.posting_date,s.signed_amount
FROM public.lts_open_finance_staging s
JOIN public.lts_v178_review_decision d ON d.user_id=s.user_id
 AND d.source_table='lts_open_finance_staging' AND d.source_ref=s.id::text
 AND d.category_label='Transferência própria'
WHERE s.user_id=p_user_id AND s.resource_type='transaction' AND s.currency='BRL'
 AND s.provider_deleted_at IS NULL AND s.signed_amount<0 AND s.posting_date<=current_date
 AND s.normalized_payload->>'status'='POSTED' AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND s.raw_payload->>'operationType'='PIX' AND s.raw_payload#>>'{paymentData,paymentMethod}'='PIX'
 AND s.raw_payload#>>'{paymentData,payer,documentNumber,type}'='CPF'
 AND s.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
 AND regexp_replace(s.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g') ~ '^[0-9]{11}$'
 AND regexp_replace(s.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g')
  =regexp_replace(s.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g')
 AND s.institution_code IS DISTINCT FROM s.raw_payload#>>'{paymentData,receiver,routingNumber}'
 AND EXISTS(SELECT 1 FROM public.lts_open_finance_staging b
  WHERE b.user_id=p_user_id AND b.resource_type='balance' AND b.provider_deleted_at IS NULL AND b.currency='BRL'
  AND b.provider_account_ref=s.provider_account_ref AND b.institution_code=s.institution_code
  AND b.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
  AND regexp_replace(b.raw_payload->>'taxNumber','[^0-9]','','g')
   =regexp_replace(s.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g'))
 AND EXISTS(SELECT 1 FROM public.lts_open_finance_staging b
  WHERE b.user_id=p_user_id AND b.resource_type='balance' AND b.provider_deleted_at IS NULL AND b.currency='BRL'
  AND b.institution_code=s.raw_payload#>>'{paymentData,receiver,routingNumber}'
  AND b.normalized_payload->>'account_type' IN('CHECKING_ACCOUNT','SAVINGS_ACCOUNT')
  AND regexp_replace(b.raw_payload->>'taxNumber','[^0-9]','','g')
   =regexp_replace(s.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g'))
$function$
