-- Combine an evidenced FGTS bank receipt only when the scheduled components and owned bank identity agree.
CREATE OR REPLACE FUNCTION public.lts_bank_fgts_combined_receipt_v261(p_user_id uuid,p_staging_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $fn$
DECLARE s public.lts_open_finance_staging%ROWTYPE; policy jsonb; refs jsonb; count_rows integer; count_components integer;
 principal numeric; jam numeric; total numeric; group_count integer; same_accounts boolean; receipt_count integer;
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
END $fn$;
REVOKE ALL ON FUNCTION public.lts_bank_fgts_combined_receipt_v261(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_bank_fgts_combined_receipt_v261(uuid,uuid) TO service_role;

