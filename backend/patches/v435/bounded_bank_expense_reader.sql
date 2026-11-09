-- Narrow the matching window and only read duplicate-detection context for eligible debits.
DO $v435$
DECLARE
 reader regprocedure := 'public.lts_v229_new_bank_rows(uuid,date,date)'::regprocedure;
 previous_definition text;
 previous_attributes jsonb;
 replacement text := $replacement$CREATE OR REPLACE FUNCTION public.lts_v229_new_bank_rows(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(id uuid, event_date date, signed_amount numeric, description text, bank text, category text)
 LANGUAGE sql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH anchors AS MATERIALIZED (
 SELECT institution bank,max((metadata->>'balance_as_of')::date) dt FROM public.accounts
 WHERE user_id=p_user_id AND is_active AND metadata->>'evidence_sha256' IS NOT NULL GROUP BY institution
), posted AS MATERIALIZED (
 SELECT tx_s.*,
 regexp_replace(tx_s.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g') payer_cpf,
 regexp_replace(tx_s.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g') receiver_cpf
 FROM public.lts_bank_posted_rows_v231(p_user_id) tx_s
 WHERE tx_s.posting_date BETWEEN p_from AND least(p_to,current_date)
 AND tx_s.posting_date>(SELECT min(dt) FROM anchors WHERE bank IN ('Itaú','Bradesco','C6'))
), owned_identity AS MATERIALIZED (
 SELECT DISTINCT tx_s.institution_code,tx_s.provider_account_ref,
 regexp_replace(tx_s.raw_payload->>'taxNumber','[^0-9]','','g') cpf
 FROM public.lts_open_finance_staging tx_s
 WHERE tx_s.user_id=p_user_id AND tx_s.resource_type='balance' AND tx_s.provider_deleted_at IS NULL
 AND tx_s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND nullif(tx_s.provider_account_ref,'') IS NOT NULL
 AND regexp_replace(tx_s.raw_payload->>'taxNumber','[^0-9]','','g') ~ '^[0-9]{11}$'
), eligible_pairs AS MATERIALIZED (
 SELECT tx_d.id debit_id,tx_c.id credit_id
 FROM posted tx_d JOIN posted tx_c ON tx_c.user_id=tx_d.user_id
 AND tx_c.posting_date=tx_d.posting_date AND tx_c.signed_amount=-tx_d.signed_amount
 AND tx_c.institution_code<>tx_d.institution_code
 JOIN owned_identity od ON od.institution_code=tx_d.institution_code
 AND od.provider_account_ref=tx_d.provider_account_ref AND od.cpf=tx_d.payer_cpf
 JOIN owned_identity oc ON oc.institution_code=tx_c.institution_code
 AND oc.provider_account_ref=tx_c.provider_account_ref AND oc.cpf=tx_c.receiver_cpf
 WHERE tx_d.signed_amount<0 AND tx_c.signed_amount>0
 AND tx_d.institution_code IN ('341','237','336') AND tx_c.institution_code IN ('341','237','336')
 AND tx_d.raw_payload#>>'{paymentData,payer,documentNumber,type}'='CPF'
 AND tx_d.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
 AND tx_c.raw_payload#>>'{paymentData,payer,documentNumber,type}'='CPF'
 AND tx_c.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
 AND tx_d.payer_cpf~'^[0-9]{11}$' AND tx_d.payer_cpf=tx_d.receiver_cpf
 AND tx_c.payer_cpf=tx_d.payer_cpf AND tx_c.receiver_cpf=tx_d.receiver_cpf
 AND tx_d.raw_payload#>>'{paymentData,receiver,routingNumber}'=tx_c.institution_code
 AND tx_c.raw_payload#>>'{paymentData,payer,routingNumber}'=tx_d.institution_code
), counted_pairs AS (
 SELECT *,count(*) OVER(PARTITION BY debit_id) debit_count,
 count(*) OVER(PARTITION BY credit_id) credit_count FROM eligible_pairs
), own_pairs AS MATERIALIZED (
 SELECT debit_id,credit_id FROM counted_pairs WHERE debit_count=1 AND credit_count=1
 UNION SELECT debit_id,credit_id FROM public.lts_owner_confirmed_transfer_pairs_v263(p_user_id)
), candidates AS MATERIALIZED (
 SELECT s.*,a.bank,public.lts_bank_description_key_v229(s.description_raw) AS description_key
 FROM posted s JOIN anchors a ON a.bank=CASE s.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END
 WHERE s.user_id=p_user_id AND s.resource_type='transaction' AND s.currency='BRL' AND s.provider_deleted_at IS NULL
 AND s.normalized_payload->>'status'='POSTED' AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND NOT EXISTS(SELECT 1 FROM own_pairs p WHERE p.debit_id=s.id)
 AND NOT EXISTS(SELECT 1 FROM public.lts_posted_own_transfer_out_v304(p_user_id) ot WHERE ot.source_id=s.id)
 AND s.signed_amount<0 AND s.posting_date>a.dt AND s.posting_date BETWEEN p_from AND least(p_to,current_date)
 AND NOT EXISTS(SELECT 1 FROM public.lts_v229_documentary_match m WHERE m.user_id=p_user_id AND m.staging_id=s.id)
), context AS MATERIALIZED (
 SELECT public.lts_flow_operational_read_v229(p_user_id,(SELECT min(dt)+1 FROM anchors),current_date) events
 WHERE EXISTS(SELECT 1 FROM candidates)
), unmatched AS MATERIALIZED (
 SELECT s.* FROM candidates s CROSS JOIN context c
 WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c.events) e WHERE e->>'account'=s.bank AND (e->>'event_date')::date=s.posting_date
 AND (e->>'signed_amount')::numeric=s.signed_amount
 AND (e->>'open_finance_id'=s.id::text OR public.lts_v178_norm(e->>'description')=s.description_key
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(s.normalized_payload#>'{reconciliation,candidates}','[]')) z
 WHERE z->>'ref' IN (e->>'source_ref',(e->>'source')||':'||(e->>'source_ref')))))
), classified AS MATERIALIZED (
 SELECT s.*,public.lts_bank_known_classification_v231(p_user_id,s.id)->>'category' AS known_category FROM unmatched s
), fallback_rules AS MATERIALIZED (
 SELECT r.category,r.match_type,public.lts_v178_norm(r.match_value) AS match_key
 FROM public.lts_semantic_rule r WHERE r.user_id=p_user_id AND r.active AND r.confidence IN ('user_confirmed','high','alta','system_high')
 AND NOT r.is_internal_transfer AND NOT r.is_asset_movement
 AND r.match_type IN ('exact','prefix') AND EXISTS(SELECT 1 FROM classified WHERE known_category IS NULL)
)
SELECT s.id,s.posting_date,s.signed_amount,s.description_raw,s.bank,coalesce(s.known_category,rule.category,'A classificar')
FROM classified s
LEFT JOIN LATERAL (
 SELECT CASE WHEN count(DISTINCT r.category)=1 THEN min(r.category) END category
 FROM fallback_rules r WHERE s.known_category IS NULL
 AND ((r.match_type='exact' AND r.match_key=s.description_key)
 OR (r.match_type='prefix' AND starts_with(s.description_key,r.match_key)))
) rule ON true;
$function$
$replacement$;
BEGIN
 SELECT pg_get_functiondef(reader), to_jsonb(p)-'prosrc'
 INTO STRICT previous_definition, previous_attributes
 FROM pg_proc p WHERE p.oid=reader;
 IF previous_definition=replacement THEN RETURN; END IF;
 IF md5(previous_definition)<>'ba23c0d4908a43e445c6d34ae2efd1aa' THEN
  RAISE EXCEPTION 'V435_PREDECESSOR_CHANGED: inspect the current bank expense reader';
 END IF;
 EXECUTE replacement;
 IF pg_get_functiondef(reader) IS DISTINCT FROM replacement
  OR (SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=reader) IS DISTINCT FROM previous_attributes THEN
  RAISE EXCEPTION 'V435_READER_CONTRACT_CHANGED';
 END IF;
END $v435$;
