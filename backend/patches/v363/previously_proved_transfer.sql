-- Reuse a specific confirmed destination and a prior same-owner bank observation.
-- This is documentary continuity, not a new owner confirmation of an exact pair.
CREATE OR REPLACE FUNCTION public.lts_transfer_refresh_valid_v363(
 p_user_id uuid,p_debit jsonb,p_credit jsonb,p_prior jsonb,p_confirmation jsonb,
 p_origin jsonb,p_destination jsonb,p_origin_balance jsonb,p_destination_balance jsonb,p_evidence jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
SELECT coalesce(
 public.lts_posted_own_transfer_valid_v304(p_user_id,p_debit,p_confirmation,p_origin,p_destination,p_origin_balance)
 AND p_evidence->>'user_id'=p_user_id::text
 AND p_evidence->>'evidence_type'='previously_proved_transfer_refresh_v363'
 AND p_evidence->>'status'='documented'
 AND p_evidence->>'source_ref'='proved-transfer-refresh-v363:'||(p_debit->>'id')||':'||(p_credit->>'id')
 AND p_evidence#>>'{metadata,version}'='previously-proved-transfer-v363'
 AND p_evidence#>>'{metadata,basis}'='confirmed_destination_and_prior_same_owner_posted_pair'
 AND p_evidence#>>'{metadata,owner_confirmation_scope}'='destination_confirmation_only'
 AND p_evidence#>>'{metadata,incoming_payer_conflict_preserved}'='true'
 AND p_evidence#>>'{metadata,debit_id}'=p_debit->>'id'
 AND p_evidence#>>'{metadata,credit_id}'=p_credit->>'id'
 AND p_evidence#>>'{metadata,confirmation_audit_id}'=p_confirmation->>'id'
 AND p_evidence#>>'{metadata,prior_credit_observation_id}'=p_prior->>'id'
 AND p_evidence#>>'{metadata,debit_raw_hash}'=p_debit->>'raw_hash'
 AND p_evidence#>>'{metadata,credit_raw_hash}'=p_credit->>'raw_hash'
 AND p_evidence#>>'{metadata,prior_credit_raw_hash}'=p_prior->>'raw_hash'
 AND p_evidence->>'evidence_date'=p_debit->>'posting_date'
 AND p_evidence->'amount'=p_credit->'signed_amount'
 AND p_credit->>'user_id'=p_user_id::text AND p_prior->>'user_id'=p_user_id::text
 AND p_destination_balance->>'user_id'=p_user_id::text
 AND p_credit->>'id'<>p_debit->>'id'
 AND p_credit->>'resource_type'='transaction' AND p_credit->>'currency'='BRL'
 AND p_credit->>'provider_deleted_at' IS NULL
 AND p_credit#>>'{normalized_payload,status}'='POSTED' AND p_credit#>>'{raw_payload,status}'='POSTED'
 AND p_credit#>>'{normalized_payload,account_type}'='CHECKING_ACCOUNT'
 AND p_credit->>'posting_date'=p_debit->>'posting_date'
 AND (p_credit->>'signed_amount')::numeric=-(p_debit->>'signed_amount')::numeric
 AND p_credit->'signed_amount'=p_credit#>'{normalized_payload,amount}'
 AND p_credit->'signed_amount'=p_credit#>'{raw_payload,amount}'
 AND p_credit#>>'{normalized_payload,date}'=p_credit->>'posting_date'
 AND p_credit#>>'{raw_payload,currencyCode}'='BRL'
 AND p_credit->>'raw_hash'~'^[0-9a-f]{64}$' AND p_prior->>'raw_hash'~'^[0-9a-f]{64}$'
 AND p_credit->>'institution_code'<>p_debit->>'institution_code'
 AND p_credit->>'institution_code'=CASE p_destination->>'institution' WHEN 'Itaú' THEN '341' WHEN 'Bradesco' THEN '237' WHEN 'C6' THEN '336' END
 AND nullif(p_credit->>'provider_account_ref','')=p_credit#>>'{raw_payload,accountId}'
 AND p_credit->>'provider_account_ref'=p_credit#>>'{normalized_payload,provider_account_id}'
 AND p_credit->>'provider_record_id'=(p_credit#>>'{normalized_payload,item_id}')||':'||(p_credit#>>'{raw_payload,id}')
 AND p_credit#>>'{raw_payload,id}'=p_credit#>>'{normalized_payload,provider_id}'
 AND p_credit#>>'{raw_payload,paymentData,payer,routingNumber}'=p_debit->>'institution_code'
 AND p_destination_balance->>'resource_type'='balance'
 AND p_destination_balance->>'provider_deleted_at' IS NULL
 AND p_destination_balance->>'institution_code'=p_credit->>'institution_code'
 AND p_destination_balance->>'provider_account_ref'=p_credit->>'provider_account_ref'
 AND p_destination_balance#>>'{normalized_payload,account_type}'='CHECKING_ACCOUNT'
 AND regexp_replace(p_destination_balance#>>'{raw_payload,taxNumber}','[^0-9]','','g')~'^[0-9]{11}$'
 AND regexp_replace(p_destination_balance#>>'{raw_payload,taxNumber}','[^0-9]','','g')=regexp_replace(p_origin_balance#>>'{raw_payload,taxNumber}','[^0-9]','','g')
 AND p_credit#>>'{raw_payload,paymentData,receiver,documentNumber,type}'='CPF'
 AND p_credit#>>'{raw_payload,paymentData,payer,documentNumber,type}'='CPF'
 AND regexp_replace(p_credit#>>'{raw_payload,paymentData,receiver,documentNumber,value}','[^0-9]','','g')=regexp_replace(p_destination_balance#>>'{raw_payload,taxNumber}','[^0-9]','','g')
 AND regexp_replace(p_credit#>>'{raw_payload,paymentData,payer,documentNumber,value}','[^0-9]','','g')~'^[0-9]{11}$'
 AND p_prior->>'resource_type'='transaction'
 AND p_prior->>'connection_id'=p_credit->>'connection_id'
 AND p_prior->>'provider_record_id'=p_credit->>'provider_record_id'
 AND p_prior#>>'{raw_payload,id}'=p_credit#>>'{raw_payload,id}'
 AND p_prior#>>'{raw_payload,accountId}'=p_credit->>'provider_account_ref'
 AND p_prior#>>'{raw_payload,status}'='POSTED' AND p_prior#>>'{normalized_payload,status}'='POSTED'
 AND p_prior#>>'{normalized_payload,account_type}'='CHECKING_ACCOUNT'
 AND p_prior#>>'{normalized_payload,date}'=p_credit->>'posting_date'
 AND p_prior#>'{normalized_payload,amount}'=p_credit->'signed_amount'
 AND p_prior#>'{raw_payload,amount}'=p_credit->'signed_amount'
 AND p_prior#>>'{raw_payload,currencyCode}'='BRL'
 AND p_prior#>>'{raw_payload,paymentData,payer,routingNumber}'=p_debit->>'institution_code'
 AND p_prior#>>'{raw_payload,paymentData,payer,documentNumber,type}'='CPF'
 AND p_prior#>>'{raw_payload,paymentData,receiver,documentNumber,type}'='CPF'
 AND regexp_replace(p_prior#>>'{raw_payload,paymentData,payer,documentNumber,value}','[^0-9]','','g')=regexp_replace(p_origin_balance#>>'{raw_payload,taxNumber}','[^0-9]','','g')
 AND regexp_replace(p_prior#>>'{raw_payload,paymentData,receiver,documentNumber,value}','[^0-9]','','g')=regexp_replace(p_origin_balance#>>'{raw_payload,taxNumber}','[^0-9]','','g')
 AND (p_prior->>'observed_at')::timestamptz>=(p_credit->>'first_seen_at')::timestamptz
 AND (p_prior->>'observed_at')::timestamptz<(p_evidence->>'created_at')::timestamptz
 AND (p_confirmation->>'created_at')::timestamptz<(p_evidence->>'created_at')::timestamptz
,false)
$f$;
REVOKE ALL ON FUNCTION public.lts_transfer_refresh_valid_v363(uuid,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb)FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_transfer_refresh_valid_v363(uuid,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb)TO service_role;

CREATE OR REPLACE FUNCTION public.lts_previously_proved_transfer_pairs_v363(p_user_id uuid)
RETURNS TABLE(debit_id uuid,credit_id uuid)LANGUAGE sql STABLE SET search_path='' AS $f$
WITH proofs AS MATERIALIZED(
 SELECT e.* FROM public.lts_reconciliation_evidence e
 WHERE e.user_id=p_user_id AND e.evidence_type='previously_proved_transfer_refresh_v363' AND e.status='documented'
 AND e.metadata->>'prior_credit_observation_id'~'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
 AND e.metadata->>'confirmation_audit_id'~'^[0-9]+$'
), posted AS MATERIALIZED(
 SELECT * FROM public.lts_bank_posted_rows_v231(p_user_id)
), eligible AS MATERIALIZED(
 SELECT d.id debit_id,c.id credit_id
 FROM proofs e
 JOIN posted d ON d.id::text=e.metadata->>'debit_id'
 JOIN posted c ON c.id::text=e.metadata->>'credit_id'
 JOIN public.lts_open_finance_observation old ON old.id=(e.metadata->>'prior_credit_observation_id')::uuid AND old.user_id=p_user_id
 JOIN public.audit_log a ON a.id=(e.metadata->>'confirmation_audit_id')::bigint AND a.user_id=p_user_id
 JOIN public.accounts o ON o.user_id=p_user_id AND o.institution=CASE d.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6'END
 JOIN public.accounts t ON t.user_id=p_user_id AND t.id::text=a.details->>'destination_account_id'
 JOIN public.lts_open_finance_staging ob ON ob.user_id=p_user_id AND ob.resource_type='balance' AND ob.provider_account_ref=d.provider_account_ref AND ob.institution_code=d.institution_code AND ob.provider_deleted_at IS NULL
 JOIN public.lts_open_finance_staging tb ON tb.user_id=p_user_id AND tb.resource_type='balance' AND tb.provider_account_ref=c.provider_account_ref AND tb.institution_code=c.institution_code AND tb.provider_deleted_at IS NULL
 WHERE e.user_id=p_user_id AND e.evidence_type='previously_proved_transfer_refresh_v363' AND e.status='documented'
 AND (SELECT count(*)FROM public.accounts x WHERE x.user_id=p_user_id AND x.institution=o.institution AND x.is_active AND x.account_type='checking' AND x.currency='BRL')=1
 AND (SELECT count(*)FROM public.accounts x WHERE x.user_id=p_user_id AND x.institution=t.institution AND x.is_active AND x.account_type='checking' AND x.currency='BRL')=1
 AND NOT EXISTS(SELECT 1 FROM public.lts_external_reference_fact f WHERE f.reference_key='owner_confirmed_internal_transfer_pair'
 AND f.confidence='user_confirmed' AND f.metadata->>'user_id'=p_user_id::text
 AND(f.metadata->>'debit_id'=d.id::text OR f.metadata->>'credit_id'=c.id::text)
 AND(f.metadata->>'debit_id'IS DISTINCT FROM d.id::text OR f.metadata->>'credit_id'IS DISTINCT FROM c.id::text))
 AND public.lts_transfer_refresh_valid_v363(p_user_id,to_jsonb(d),to_jsonb(c),to_jsonb(old),to_jsonb(a),to_jsonb(o),to_jsonb(t),to_jsonb(ob),to_jsonb(tb),to_jsonb(e))
), counted AS(
 SELECT DISTINCT debit_id,credit_id FROM eligible
), unique_legs AS(
 SELECT *,count(*)OVER(PARTITION BY debit_id)dc,count(*)OVER(PARTITION BY credit_id)cc FROM counted
)
SELECT debit_id,credit_id FROM unique_legs WHERE dc=1 AND cc=1
$f$;
REVOKE ALL ON FUNCTION public.lts_previously_proved_transfer_pairs_v363(uuid)FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_previously_proved_transfer_pairs_v363(uuid)TO service_role;

DO $patch$
DECLARE target regprocedure:='public.lts_owner_confirmed_transfer_pairs_v263(uuid)'::regprocedure;
 definition text;attributes jsonb;original text;
 suffix text:=E'\nUNION\nSELECT debit_id,credit_id FROM public.lts_previously_proved_transfer_pairs_v363(p_user_id)';
BEGIN
 SELECT pg_get_functiondef(target),to_jsonb(p)-'prosrc' INTO definition,attributes FROM pg_proc p WHERE p.oid=target;
 IF strpos(definition,suffix)>0 THEN
  original:=replace(definition,suffix,'');
  IF md5(original)<>'dce29d4fe37ac6498143519153f340b1' THEN RAISE EXCEPTION 'V363_REPLAY_SOURCE_CHANGED';END IF;
  RETURN;
 END IF;
 IF md5(definition)<>'dce29d4fe37ac6498143519153f340b1' OR strpos(definition,E';\n$function$')=0 THEN RAISE EXCEPTION 'V363_PAIR_READER_SOURCE_CHANGED';END IF;
 EXECUTE replace(definition,E';\n$function$',suffix||E';\n$function$');
 IF attributes IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid=target)THEN RAISE EXCEPTION 'V363_PAIR_READER_ATTRIBUTES_CHANGED';END IF;
END $patch$;

-- Keep the displayed/private provenance truthful about the original owner's scope.
DO $label$
DECLARE target regprocedure:='public.lts_browser_flow_pre_v238(date,date)'::regprocedure;
 definition text;attributes jsonb;original text;
 old_part text:=$old$'classification_basis',CASE WHEN EXISTS(SELECT 1 FROM public.lts_owner_confirmed_transfer_pairs_v263(u) q WHERE q.debit_id=p.id OR q.credit_id=p.id) THEN 'owner_confirmed_exact_posted_pair' ELSE 'posted_pair_same_owner_cpf_and_bank_routing' END$old$;
 new_part text:=$new$'classification_basis',CASE WHEN EXISTS(SELECT 1 FROM public.lts_previously_proved_transfer_pairs_v363(u) q WHERE q.debit_id=p.id OR q.credit_id=p.id) THEN 'prior_documented_pair_with_owner_destination_v363' WHEN EXISTS(SELECT 1 FROM public.lts_owner_confirmed_transfer_pairs_v263(u) q WHERE q.debit_id=p.id OR q.credit_id=p.id) THEN 'owner_confirmed_exact_posted_pair' ELSE 'posted_pair_same_owner_cpf_and_bank_routing' END$new$;
BEGIN
 SELECT pg_get_functiondef(target),to_jsonb(p)-'prosrc'INTO definition,attributes FROM pg_proc p WHERE p.oid=target;
 IF strpos(definition,new_part)>0 THEN
  original:=replace(definition,new_part,old_part);
  IF md5(original)<>'a529f1b10855f2ac497b5631c13de492'THEN RAISE EXCEPTION 'V363_FLOW_REPLAY_SOURCE_CHANGED';END IF;
  RETURN;
 END IF;
 IF md5(definition)<>'a529f1b10855f2ac497b5631c13de492'OR(length(definition)-length(replace(definition,old_part,'')))/length(old_part)<>1
 THEN RAISE EXCEPTION 'V363_FLOW_BASIS_SOURCE_CHANGED';END IF;
 EXECUTE replace(definition,old_part,new_part);
 IF attributes IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid=target)THEN RAISE EXCEPTION 'V363_FLOW_ATTRIBUTES_CHANGED';END IF;
END $label$;
