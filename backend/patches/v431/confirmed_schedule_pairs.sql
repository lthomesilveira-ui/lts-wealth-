-- Pair a posted credit only with an already confirmed own-account schedule.
-- A provider's conflicting payer CPF stays intact; no new owner statement is invented.
BEGIN;
SET LOCAL statement_timeout='10s';
SET LOCAL lock_timeout='2s';
CREATE OR REPLACE FUNCTION public.lts_confirmed_schedule_pairs_v431(p_user_id uuid)
RETURNS TABLE(debit_id uuid,credit_id uuid)
LANGUAGE sql STABLE SET search_path='' AS $function$
WITH approved AS MATERIALIZED(
 SELECT * FROM public.lts_posted_own_transfer_out_v304(p_user_id)
),owned AS MATERIALIZED(
 SELECT DISTINCT b.institution_code,b.provider_account_ref,
  regexp_replace(b.raw_payload->>'taxNumber','[^0-9]','','g') cpf
 FROM public.lts_open_finance_staging b
 WHERE b.user_id=p_user_id AND b.resource_type='balance' AND b.provider_deleted_at IS NULL
 AND b.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND nullif(b.provider_account_ref,'') IS NOT NULL
 AND regexp_replace(b.raw_payload->>'taxNumber','[^0-9]','','g')~'^[0-9]{11}$'
),candidates AS MATERIALIZED(
 SELECT d.id debit_id,c.id credit_id
 FROM approved a
 JOIN public.lts_open_finance_staging d ON d.user_id=p_user_id
  AND d.id=a.source_id AND d.raw_hash=a.source_raw_hash
 JOIN public.lts_open_finance_staging c ON c.user_id=d.user_id
  AND c.posting_date=d.posting_date AND c.signed_amount=-d.signed_amount
  AND c.institution_code<>d.institution_code
 JOIN owned od ON od.institution_code=d.institution_code AND od.provider_account_ref=d.provider_account_ref
  AND od.cpf=regexp_replace(d.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g')
 JOIN owned oc ON oc.institution_code=c.institution_code AND oc.provider_account_ref=c.provider_account_ref
  AND oc.cpf=od.cpf
  AND oc.cpf=regexp_replace(c.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g')
 WHERE d.resource_type='transaction' AND c.resource_type='transaction'
 AND d.currency='BRL' AND c.currency='BRL'
 AND d.provider_deleted_at IS NULL AND c.provider_deleted_at IS NULL
 AND d.normalized_payload->>'status'='POSTED' AND c.normalized_payload->>'status'='POSTED'
 AND d.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND c.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND d.signed_amount<0 AND c.signed_amount>0 AND d.posting_date<=current_date
 AND d.posting_date=a.event_date AND d.signed_amount=a.signed_amount
 AND CASE d.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END=a.from_bank
 AND CASE c.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END=a.to_bank
 AND d.raw_payload#>>'{paymentData,payer,documentNumber,type}'='CPF'
 AND d.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
 AND c.raw_payload#>>'{paymentData,payer,documentNumber,type}'='CPF'
 AND c.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
 AND regexp_replace(d.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g')=od.cpf
 AND d.raw_payload#>>'{paymentData,receiver,routingNumber}'=c.institution_code
 AND c.raw_payload#>>'{paymentData,payer,routingNumber}'=d.institution_code
 AND (c.raw_payload#>>'{paymentData,receiver,routingNumber}' IS NULL
  OR c.raw_payload#>>'{paymentData,receiver,routingNumber}'=c.institution_code)
 AND d.raw_payload#>>'{paymentData,paymentMethod}'='PIX'
 AND c.raw_payload#>>'{paymentData,paymentMethod}'='PIX'
),unique_pairs AS(
 SELECT *,count(*) OVER(PARTITION BY debit_id) nd,count(*) OVER(PARTITION BY credit_id) nc FROM candidates
)
SELECT debit_id,credit_id FROM unique_pairs WHERE nd=1 AND nc=1
$function$;
REVOKE ALL ON FUNCTION public.lts_confirmed_schedule_pairs_v431(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_confirmed_schedule_pairs_v431(uuid) TO service_role;

DO $patch$
DECLARE target regprocedure:='public.lts_owner_confirmed_transfer_pairs_v263(uuid)'::regprocedure;
 d text; attrs jsonb;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='dbb6612d587bdb88be7e8b46d3c08369' THEN
  IF (length(d)-length(replace(d,$needle$SELECT debit_id,credit_id FROM public.lts_previously_proved_transfer_pairs_v363(p_user_id);$needle$,'')))/length($needle$SELECT debit_id,credit_id FROM public.lts_previously_proved_transfer_pairs_v363(p_user_id);$needle$)<>1
  THEN RAISE EXCEPTION 'V431_PAIR_READER_SHAPE_CHANGED'; END IF;
  EXECUTE replace(d,$needle$SELECT debit_id,credit_id FROM public.lts_previously_proved_transfer_pairs_v363(p_user_id);$needle$,$replacement$SELECT debit_id,credit_id FROM public.lts_previously_proved_transfer_pairs_v363(p_user_id)
UNION SELECT debit_id,credit_id FROM public.lts_confirmed_schedule_pairs_v431(p_user_id);$replacement$);
 ELSIF md5(d)<>'363c2c63d3ee64df40173f8c3d7aab21' THEN RAISE EXCEPTION 'V431_PREDECESSOR_CHANGED'; END IF;
 IF md5(pg_get_functiondef(target))<>'363c2c63d3ee64df40173f8c3d7aab21'
 OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V431_PAIR_READER_CONTRACT_CHANGED'; END IF;
END $patch$;
COMMIT;

