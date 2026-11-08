BEGIN;

SET LOCAL statement_timeout='10s';

SET LOCAL lock_timeout='2s';

DO $guard$
DECLARE target regprocedure:='public.lts_bank_fgts_combined_receipt_v261(uuid,uuid)'::regprocedure; d text; attrs jsonb;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='42f8a1020a0c296b556a906ad001f0c3' THEN EXECUTE $replacement$CREATE OR REPLACE FUNCTION public.lts_bank_fgts_combined_receipt_v261(p_user_id uuid, p_staging_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE s public.lts_open_finance_staging%ROWTYPE; policy jsonb; refs jsonb; count_rows integer; count_components integer;
 principal numeric; jam numeric; total numeric; group_count integer; same_accounts boolean; receipt_count integer;
 owner_count integer; owner_facts jsonb;
BEGIN
 SELECT * INTO s FROM public.lts_open_finance_staging WHERE user_id=p_user_id AND id=p_staging_id;
 IF NOT FOUND OR s.resource_type<>'transaction' OR s.institution_code<>'341' OR s.currency<>'BRL'
 OR s.provider_deleted_at IS NOT NULL OR s.normalized_payload->>'status' IS DISTINCT FROM 'POSTED'
 OR s.normalized_payload->>'account_type' IS DISTINCT FROM 'CHECKING_ACCOUNT' OR s.signed_amount<=0
 OR s.raw_payload#>>'{paymentData,payer,documentNumber,type}' IS DISTINCT FROM 'CNPJ'
 OR regexp_replace(s.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g') IS DISTINCT FROM '00360305000104'
 OR s.raw_payload#>>'{paymentData,payer,routingNumber}' IS DISTINCT FROM '104'
 OR s.raw_payload#>>'{paymentData,receiver,documentNumber,type}' IS DISTINCT FROM 'CPF' THEN RETURN NULL;END IF;
 IF NOT EXISTS(SELECT 1 FROM public.lts_open_finance_staging owner_account
 WHERE owner_account.user_id=p_user_id AND owner_account.resource_type='balance'
 AND owner_account.institution_code=s.institution_code AND owner_account.provider_account_ref=s.provider_account_ref
 AND owner_account.provider_deleted_at IS NULL AND owner_account.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND regexp_replace(owner_account.raw_payload->>'taxNumber','[^0-9]','','g') ~ '^[0-9]{11}$'
 AND regexp_replace(owner_account.raw_payload->>'taxNumber','[^0-9]','','g')=
 regexp_replace(s.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g')) THEN RETURN NULL;END IF;

 -- An additional realized redemption needs an exact, source-bound owner statement.
 SELECT count(*),jsonb_agg(to_jsonb(f)) INTO owner_count,owner_facts
 FROM public.lts_external_reference_fact f
 WHERE f.reference_key='owner_confirmed_fgts_bank_redemption'
 AND f.confidence='user_confirmed' AND f.as_of_date=s.posting_date
 AND f.value_numeric=s.signed_amount AND f.unit='BRL'
 AND f.metadata->>'user_id'=p_user_id::text
 AND f.metadata->>'staging_id'=s.id::text
 AND (f.metadata->>'source_raw_hash'=s.raw_hash OR (
  f.metadata->>'hash_policy'='raw_except_order_updatedAt_v1'
  AND f.metadata->>'source_canonical_sha256'~'^[0-9a-f]{64}$'
  AND f.metadata->>'source_canonical_sha256'=encode(sha256(convert_to((s.raw_payload-'order'-'updatedAt')::text,'UTF8')),'hex')))
 AND f.metadata->>'provider_account_ref'=s.provider_account_ref
 AND f.metadata->>'asset_type'='FGTS'
 AND f.metadata->>'economic_effect'='asset_reclassification'
 AND nullif(btrim(f.evidence),'') IS NOT NULL
 AND CASE WHEN coalesce(pg_input_is_valid(f.metadata->>'owner_confirmed_on','date'),false)
  THEN (f.metadata->>'owner_confirmed_on')::date BETWEEN s.posting_date AND current_date ELSE false END;
 IF owner_count>1 THEN RETURN NULL; END IF;
 IF owner_count=1 THEN
  RETURN jsonb_build_object('projection_refs','[]'::jsonb,'total',s.signed_amount,
   'bank_source_id',s.id,'bank_source_hash',s.raw_hash,
   'basis','owner_confirmed_exact_posted_fgts_redemption',
   'owner_evidence_ref',owner_facts->0->>'scope',
   'components_identified',false);
 END IF;
 SELECT settings#>'{liquidity_movements_v242,fgts}' INTO policy FROM public.app_settings WHERE user_id=p_user_id;
 IF policy->>'receipt_date' IS NULL OR s.posting_date<>(policy->>'receipt_date')::date
 OR s.signed_amount<>(policy->>'total_brl')::numeric THEN RETURN NULL;END IF;
 SELECT count(*),count(DISTINCT f.metadata->>'receipt_component'),count(DISTINCT f.metadata->>'receipt_group_id'),
 sum(f.amount),max(f.amount) FILTER(WHERE f.metadata->>'receipt_component'='principal'),
 max(f.amount) FILTER(WHERE f.metadata->>'receipt_component'='jam'),
 coalesce(bool_and(a.institution='Itaú' AND a.is_active),false),
 jsonb_agg(coalesce(f.legacy_id,f.id::text) ORDER BY f.metadata->>'receipt_component')
 INTO count_rows,count_components,group_count,total,principal,jam,same_accounts,refs
 FROM public.financial_events f JOIN public.accounts a ON a.user_id=f.user_id AND a.id=f.account_id
 WHERE f.user_id=p_user_id AND f.is_projection AND NOT f.is_suppressed
 AND f.source='owner_confirmed_asset_redemption' AND f.metadata->>'source_asset_type'='FGTS'
 AND f.metadata->>'economic_effect'='asset_reclassification' AND f.metadata->>'receipt_component' IN('principal','jam')
 AND f.metadata->>'receipt_group_id' IS NOT NULL AND f.event_date=s.posting_date;
 IF count_rows<>2 OR count_components<>2 OR group_count<>1 OR NOT same_accounts
 OR total IS DISTINCT FROM s.signed_amount OR principal IS DISTINCT FROM (policy->>'principal_brl')::numeric
 OR jam IS DISTINCT FROM (policy->>'jam_brl')::numeric OR principal<=0 OR jam<=0 THEN RETURN NULL;END IF;
 SELECT count(*) INTO receipt_count FROM public.lts_bank_posted_rows_v231(p_user_id) other
 WHERE other.user_id=p_user_id AND other.resource_type='transaction' AND other.institution_code=s.institution_code
 AND other.provider_account_ref=s.provider_account_ref AND other.posting_date=s.posting_date AND other.currency='BRL'
 AND other.provider_deleted_at IS NULL AND other.normalized_payload->>'status'='POSTED'
 AND other.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND other.signed_amount IN(total,principal,jam);
 IF receipt_count<>1 THEN RETURN NULL;END IF;
 RETURN jsonb_build_object('projection_refs',refs,'principal',principal,'jam',jam,'total',total,
 'bank_source_id',s.id,'bank_source_hash',s.raw_hash,'basis','posted_combined_fgts_receipt_with_owner_confirmed_components');
END $function$
$replacement$;
 ELSIF md5(d)<>'3d06e4c309d8b0bc0466558f8f92e1a7' THEN RAISE EXCEPTION 'V432_PREDECESSOR_CHANGED: %',target;END IF;
 IF md5(pg_get_functiondef(target))<>'3d06e4c309d8b0bc0466558f8f92e1a7' OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V432_FUNCTION_CONTRACT_CHANGED: %',target;END IF;
END $guard$;

DO $guard$
DECLARE target regprocedure:='public.lts_fgts_position_evidence_v386(uuid,date)'::regprocedure; d text; attrs jsonb;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='e5327599d7ccd6dd391972671df959d9' THEN EXECUTE $replacement$CREATE OR REPLACE FUNCTION public.lts_fgts_position_evidence_v386(p_user_id uuid, p_as_of date)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
WITH position AS MATERIALIZED (
 SELECT value_brl,as_of_date,metadata
 FROM public.asset_positions
 WHERE user_id=p_user_id AND asset_type='FGTS' AND as_of_date<=p_as_of
 ORDER BY as_of_date DESC,created_at DESC,id DESC LIMIT 1
), policy AS MATERIALIZED (
 SELECT settings#>'{liquidity_movements_v242,fgts}' j
 FROM public.app_settings WHERE user_id=p_user_id
), receipt AS MATERIALIZED (
 SELECT s.posting_date,s.signed_amount,
   public.lts_bank_fgts_combined_receipt_v261(p_user_id,s.id) evidence
 FROM public.lts_open_finance_staging s
 WHERE s.user_id=p_user_id AND s.resource_type='transaction'
   AND s.institution_code='341' AND s.currency='BRL'
   AND s.provider_deleted_at IS NULL AND s.posting_date<=p_as_of
   AND ((s.posting_date=(SELECT (j->>'receipt_date')::date FROM policy)
     AND s.signed_amount=(SELECT (j->>'total_brl')::numeric FROM policy))
    OR EXISTS(SELECT 1 FROM public.lts_external_reference_fact f
     WHERE f.reference_key='owner_confirmed_fgts_bank_redemption'
     AND f.metadata->>'user_id'=p_user_id::text
     AND f.metadata->>'staging_id'=s.id::text))
), confirmed AS (
 SELECT count(*) n,min(posting_date) receipt_date,max(signed_amount) amount
 FROM receipt WHERE evidence IS NOT NULL
 AND posting_date=(SELECT max(posting_date) FROM receipt WHERE evidence IS NOT NULL)
), state AS (
 SELECT p.*,
   (SELECT (j->>'receipt_date')::date FROM policy) scheduled_date,
   c.n,c.receipt_date,c.amount,
   c.n=1 AND c.receipt_date>p.as_of_date received_after_position,
   coalesce((SELECT (j->>'receipt_date')::date FROM policy)<=p_as_of
     AND (SELECT (j->>'receipt_date')::date FROM policy)>p.as_of_date,false) scheduled_after_position
 FROM (SELECT (SELECT value_brl FROM position) value_brl,
   (SELECT as_of_date FROM position) as_of_date,
   (SELECT metadata FROM position) metadata) p CROSS JOIN confirmed c
)
SELECT jsonb_build_object(
 'version','fgts-position-evidence-v386','as_of',p_as_of,
 'status',CASE WHEN value_brl IS NULL THEN 'position_unavailable'
   WHEN received_after_position THEN 'position_after_withdrawal_unavailable'
   WHEN scheduled_after_position THEN 'withdrawal_requires_reconciliation'
   ELSE 'dated_documentary_position' END,
 'balance_brl',CASE WHEN NOT received_after_position AND NOT scheduled_after_position THEN value_brl END,
 'balance_as_of',CASE WHEN value_brl IS NOT NULL AND NOT received_after_position AND NOT scheduled_after_position THEN as_of_date END,
 'last_documented_balance_brl',value_brl,'last_documented_as_of',as_of_date,
 'document_last_posting_date',metadata->'document_last_posting_date',
 'source_label',metadata->'source',
 'withdrawal',jsonb_build_object('confirmed',n=1,'date',CASE WHEN n=1 THEN receipt_date END,'amount_brl',CASE WHEN n=1 THEN amount END),
 'restricted',true,'estimated_contributions_are_documented_balance',false
) FROM state;
$function$
$replacement$;
 ELSIF md5(d)<>'d1ba27f82c8ec6fcecbe0637969bb238' THEN RAISE EXCEPTION 'V432_PREDECESSOR_CHANGED: %',target;END IF;
 IF md5(pg_get_functiondef(target))<>'d1ba27f82c8ec6fcecbe0637969bb238' OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V432_FUNCTION_CONTRACT_CHANGED: %',target;END IF;
END $guard$;

COMMIT;
