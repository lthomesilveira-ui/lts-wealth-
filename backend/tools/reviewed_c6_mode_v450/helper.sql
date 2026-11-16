CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.reviewed_c6_mode_v450(p_contract jsonb, p_link jsonb, p_payment jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
SELECT coalesce(p_payment->>'paymentMode'='DEBIT_ACCOUNT' OR (
 p_payment->>'paymentMode'='BANK_SLIP'
 AND p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351'
 AND p_link->>'institution_code'='336'
 AND p_contract#>>'{reviewed_issuer_payment_mode_v450,version}'='reviewed-c6-mode-v450'
 AND p_contract#>>'{reviewed_issuer_payment_mode_v450,user_id}'=p_contract->>'user_id'
 AND p_contract#>>'{reviewed_issuer_payment_mode_v450,user_id}'=p_link->>'user_id'
 AND p_contract#>>'{reviewed_issuer_payment_mode_v450,link_id}'=p_link->>'id'
 AND p_contract#>>'{reviewed_issuer_payment_mode_v450,invoice_id}'=p_link->>'invoice_source_id'
 AND p_contract#>>'{reviewed_issuer_payment_mode_v450,payment_id}'=p_link->>'payment_source_id'
 AND p_contract#>>'{reviewed_issuer_payment_mode_v450,invoice_prior_raw_hash}'=p_contract->>'invoice_current_hash'
 AND p_contract#>>'{reviewed_issuer_payment_mode_v450,bank_payment_raw_hash}'=p_link->>'payment_raw_hash'
 AND p_contract#>>'{reviewed_issuer_payment_mode_v450,invoice_current_raw_hash}'~'^[0-9a-f]{64}$'
 AND p_contract#>>'{reviewed_issuer_payment_mode_v450,prior_payment,paymentMode}'='DEBIT_ACCOUNT'
 AND p_contract#>'{reviewed_issuer_payment_mode_v450,current_payment}'=p_payment
 AND (p_contract#>'{reviewed_issuer_payment_mode_v450,prior_payment}')-'paymentMode'=p_payment-'paymentMode'
 AND p_payment->>'id'=p_contract#>>'{reviewed_other_payment,issuer_payment_id}'
),false)
$function$
