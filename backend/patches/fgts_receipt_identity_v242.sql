CREATE OR REPLACE FUNCTION public.lts_documented_bank_event_identity_v242(p_user_id uuid,p_staging_id uuid,p_event jsonb)
RETURNS boolean LANGUAGE plpgsql STABLE COST 1000 SET search_path='' AS $fn$
BEGIN
 IF p_event->>'source' IS DISTINCT FROM 'current_event' OR NOT starts_with(coalesce(p_event->>'source_ref',''),'owner_fgts_withdrawal_') THEN
  RETURN public.lts_documented_bank_event_identity_v240(p_user_id,p_staging_id,p_event);
 END IF;
 RETURN EXISTS(
 SELECT 1 FROM public.financial_events f
 JOIN public.app_settings a ON a.user_id=f.user_id
 JOIN public.lts_open_finance_staging s ON s.user_id=f.user_id AND s.id=p_staging_id
 WHERE f.user_id=p_user_id AND p_event->>'source'='current_event'
 AND p_event->>'source_ref' IN(f.id::text,f.legacy_id) AND NOT f.is_suppressed
 AND f.source='owner_confirmed_asset_redemption' AND f.metadata->>'source_asset_type'='FGTS'
 AND f.metadata->>'receipt_component' IN('principal','jam')
 AND f.event_date=(a.settings#>>'{liquidity_movements_v242,fgts,receipt_date}')::date
 AND f.amount=CASE f.metadata->>'receipt_component' WHEN 'principal' THEN (a.settings#>>'{liquidity_movements_v242,fgts,principal_brl}')::numeric ELSE (a.settings#>>'{liquidity_movements_v242,fgts,jam_brl}')::numeric END
 AND s.resource_type='transaction' AND s.institution_code='341' AND s.currency='BRL'
 AND s.provider_deleted_at IS NULL AND s.normalized_payload->>'status'='POSTED'
 AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND s.posting_date=f.event_date AND s.signed_amount=f.amount
 AND p_event->>'account'='Itaú' AND (p_event->>'event_date')::date=f.event_date
 AND (p_event->>'signed_amount')::numeric=f.amount
 AND (s.description_raw ILIKE '%FGTS%' OR (
  SELECT count(*) FROM public.lts_bank_posted_rows_v231(p_user_id) other
  WHERE other.user_id=p_user_id AND other.resource_type='transaction' AND other.institution_code='341'
  AND other.currency='BRL' AND other.provider_deleted_at IS NULL
  AND other.normalized_payload->>'status'='POSTED' AND other.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
  AND other.normalized_payload->>'provider_account_id'=s.normalized_payload->>'provider_account_id'
  AND other.posting_date=f.event_date
  AND other.signed_amount IN((a.settings#>>'{liquidity_movements_v242,fgts,principal_brl}')::numeric,(a.settings#>>'{liquidity_movements_v242,fgts,jam_brl}')::numeric)
 )=2 AND (
  SELECT count(DISTINCT other.signed_amount) FROM public.lts_bank_posted_rows_v231(p_user_id) other
  WHERE other.user_id=p_user_id AND other.resource_type='transaction' AND other.institution_code='341'
  AND other.currency='BRL' AND other.provider_deleted_at IS NULL
  AND other.normalized_payload->>'status'='POSTED' AND other.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
  AND other.normalized_payload->>'provider_account_id'=s.normalized_payload->>'provider_account_id'
  AND other.posting_date=f.event_date
  AND other.signed_amount IN((a.settings#>>'{liquidity_movements_v242,fgts,principal_brl}')::numeric,(a.settings#>>'{liquidity_movements_v242,fgts,jam_brl}')::numeric)
 )=2));
END $fn$;
REVOKE ALL ON FUNCTION public.lts_documented_bank_event_identity_v242(uuid,uuid,jsonb) FROM PUBLIC,anon,authenticated;
