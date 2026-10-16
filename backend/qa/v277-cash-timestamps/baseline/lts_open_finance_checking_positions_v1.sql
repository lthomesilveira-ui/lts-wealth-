CREATE OR REPLACE FUNCTION public.lts_open_finance_checking_positions_v1(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE positions jsonb; account_count integer; bank_count integer; invalid_count integer;
BEGIN
 SELECT count(*),count(DISTINCT institution_code),
 count(*) FILTER (WHERE
  normalized_payload->>'balance_semantics' IS DISTINCT FROM 'available_bank_balance'
  OR jsonb_typeof(normalized_payload->'available_balance') IS DISTINCT FROM 'number'
  OR jsonb_typeof(raw_payload->'balance') IS DISTINCT FROM 'number'
  OR normalized_payload->>'currency' IS DISTINCT FROM 'BRL'
  OR raw_payload->>'currencyCode' IS DISTINCT FROM 'BRL'
  OR raw_payload->>'subtype' IS DISTINCT FROM 'CHECKING_ACCOUNT'
  OR provider_account_ref IS NULL
  OR normalized_payload->>'provider_account_id' IS DISTINCT FROM provider_account_ref
  OR raw_payload->>'id' IS DISTINCT FROM provider_account_ref
  OR nullif(normalized_payload->>'as_of','') IS NULL)
 INTO account_count,bank_count,invalid_count
 FROM public.lts_open_finance_staging
 WHERE user_id=p_user_id AND resource_type='balance'
  AND institution_code IN ('341','237','336') AND currency='BRL'
  AND normalized_payload->>'account_type'='CHECKING_ACCOUNT'
  AND provider_deleted_at IS NULL;
 IF account_count<>3 OR bank_count<>3 OR invalid_count<>0 THEN
  RAISE EXCEPTION 'checking account positions incomplete, ambiguous or invalid';
 END IF;
 IF EXISTS (SELECT 1 FROM public.lts_open_finance_staging
  WHERE user_id=p_user_id AND resource_type='balance' AND institution_code IN ('341','237','336')
   AND currency='BRL' AND normalized_payload->>'account_type'='CHECKING_ACCOUNT'
   AND provider_deleted_at IS NULL
   AND ((normalized_payload->>'available_balance')::numeric IS DISTINCT FROM (raw_payload->>'balance')::numeric
     OR (normalized_payload->>'as_of')::timestamptz IS DISTINCT FROM (raw_payload->>'updatedAt')::timestamptz)) THEN
  RAISE EXCEPTION 'normalized checking balance differs from bank source';
 END IF;
 SELECT jsonb_agg(jsonb_build_object(
  'bank',case institution_code when '341' then 'Itaú' when '237' then 'Bradesco' else 'C6' end,
  'institution_code',institution_code,'account_ref',provider_account_ref,
  'balance',(normalized_payload->>'available_balance')::numeric,
  'as_of',(normalized_payload->>'as_of')::timestamptz,
  'payload',normalized_payload,'source_id',id,'source_hash',raw_hash) ORDER BY institution_code)
 INTO positions FROM public.lts_open_finance_staging
 WHERE user_id=p_user_id AND resource_type='balance'
  AND institution_code IN ('341','237','336') AND currency='BRL'
  AND normalized_payload->>'account_type'='CHECKING_ACCOUNT'
  AND provider_deleted_at IS NULL;
 RETURN positions;
END $function$

