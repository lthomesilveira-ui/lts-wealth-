-- V381: account for identified, posted Cofrinho bank receipts exactly once.
-- This reader never creates a bank event, movement, expense or yield entry.
CREATE OR REPLACE FUNCTION public.lts_cofrinho_bank_redemptions_v381(
  p_user_id uuid, p_after date, p_through date
)
RETURNS TABLE (
  staging_id uuid, event_date date, bank_amount_brl numeric,
  represented_by_recorded_movement boolean, representation_conflict boolean,
  unrepresented_asset_delta_brl numeric, raw_hash text, provider_record_id text
)
LANGUAGE sql STABLE SET search_path='' SET "TimeZone"='America/Sao_Paulo'
AS $function$
WITH checking AS MATERIALIZED (
  SELECT DISTINCT p#>>'{payload,provider_account_id}' account_ref
  FROM jsonb_array_elements(public.lts_open_finance_checking_positions_v1(p_user_id)) p
  WHERE p->>'bank'='Itaú'
), receipts AS MATERIALIZED (
  SELECT s.*
  FROM public.lts_open_finance_staging s
  JOIN public.lts_open_finance_connection c ON c.id=s.connection_id AND c.user_id=s.user_id
  JOIN checking a ON a.account_ref=s.provider_account_ref
  WHERE s.user_id=p_user_id AND s.provider='pluggy' AND c.provider='pluggy'
    AND s.resource_type='transaction' AND s.institution_code='341' AND c.institution_code='341'
    AND s.currency='BRL' AND s.provider_deleted_at IS NULL
    AND s.posting_date>p_after AND s.posting_date<=p_through
    AND s.signed_amount>0 AND s.occurred_at IS NOT NULL
    AND (s.occurred_at AT TIME ZONE 'America/Sao_Paulo')::date=s.posting_date
    AND s.normalized_payload->>'status'='POSTED' AND s.raw_payload->>'status'='POSTED'
    AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
    AND s.normalized_payload->>'provider_account_id'=s.provider_account_ref
    AND s.raw_payload->>'accountId'=s.provider_account_ref
    AND s.normalized_payload->>'item_id'=c.provider_connection_ref
    AND s.normalized_payload->>'provider_id'=s.raw_payload->>'id'
    AND s.provider_record_id=c.provider_connection_ref||':'||(s.raw_payload->>'id')
    AND s.raw_payload->>'type'='CREDIT' AND s.raw_payload->>'currencyCode'='BRL'
    AND jsonb_typeof(s.raw_payload->'amount')='number'
    AND (s.raw_payload->>'amount')::numeric=s.signed_amount
    -- A bank's explicit product description is required; equal amounts or dates
    -- never establish a Cofrinho receipt or a link to an investment product.
    AND upper(regexp_replace(trim(s.description_raw),'\s+',' ','g'))
      ~ '^(ENTRADA )?(RESGATE )+(CDB )?COFRINHOS?$'
    AND s.description_raw=s.raw_payload->>'description'
)
SELECT s.id,s.posting_date,s.signed_amount,
  r.linked=1 AND r.exact=1,
  r.linked>0 AND NOT (r.linked=1 AND r.exact=1),
  CASE WHEN r.linked=0 THEN -s.signed_amount
       WHEN r.linked=1 AND r.exact=1 THEN 0::numeric ELSE NULL::numeric END,
  s.raw_hash,s.provider_record_id
FROM receipts s
CROSS JOIN LATERAL (
  SELECT count(*) linked,count(*) FILTER (
    WHERE m.event_date=s.posting_date AND m.bank_delta_brl=s.signed_amount
      AND m.asset_delta_brl=-s.signed_amount AND m.movement_type='redemption'
  ) exact
  FROM public.lts_liquidity_movement m
  JOIN public.asset_positions a ON a.id=m.asset_position_id AND a.user_id=m.user_id
  LEFT JOIN public.financial_events f ON f.id=m.bank_event_id AND f.user_id=m.user_id
  WHERE m.user_id=p_user_id AND m.status='active'
    AND a.asset_name='Cofrinho Itaú' AND a.asset_type='cash_investment'
    AND (m.metadata->>'bank_staging_id'=s.id::text
      OR m.metadata#>>'{bank_reconciliation_evidence,bank_source_id}'=s.id::text
      OR f.metadata->>'bank_staging_id'=s.id::text)
) r
ORDER BY s.posting_date,s.id;
$function$;
REVOKE ALL ON FUNCTION public.lts_cofrinho_bank_redemptions_v381(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_cofrinho_bank_redemptions_v381(uuid,date,date) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_cofrinho_effective_locked_v245(p_user_id uuid,p_date date)
RETURNS numeric LANGUAGE sql STABLE SET search_path='' SET "TimeZone"='America/Sao_Paulo'
AS $function$
WITH anchor AS MATERIALIZED (
  SELECT (l.canonical_value->>'amount')::numeric amount,
         (l.canonical_value->>'as_of')::date dt
  FROM public.lts_validated_lock_registry l
  WHERE l.lock_key LIKE 'itau_cofrinho_%' AND l.superseded_at IS NULL
    AND (l.canonical_value->>'as_of')::date<=p_date
    AND EXISTS (
      SELECT 1 FROM public.asset_positions a WHERE a.user_id=p_user_id
        AND a.asset_name='Cofrinho Itaú' AND a.asset_type='cash_investment'
        AND a.metadata->>'validated_lock_key'=l.lock_key
    )
  ORDER BY (l.canonical_value->>'as_of')::date DESC,l.locked_at DESC,l.lock_key DESC LIMIT 1
)
SELECT amount+coalesce((
  SELECT sum(m.asset_delta_brl)
  FROM public.lts_liquidity_movement m
  JOIN public.asset_positions a ON a.id=m.asset_position_id AND a.user_id=m.user_id
  WHERE m.user_id=p_user_id AND m.status='active' AND a.asset_name='Cofrinho Itaú'
    AND a.asset_type='cash_investment' AND m.event_date>anchor.dt AND m.event_date<=p_date
),0)+coalesce((
  SELECT sum(r.unrepresented_asset_delta_brl)
  FROM public.lts_cofrinho_bank_redemptions_v381(p_user_id,anchor.dt,p_date) r
  WHERE NOT r.representation_conflict
),0)
FROM anchor;
$function$;
REVOKE ALL ON FUNCTION public.lts_cofrinho_effective_locked_v245(uuid,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_cofrinho_effective_locked_v245(uuid,date) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_asset_position_effective_v1(p_user_id uuid,p_as_of date DEFAULT CURRENT_DATE)
RETURNS TABLE(asset_position_id uuid,asset_name text,asset_type text,documented_as_of date,
  documented_value_brl numeric,movement_delta_brl numeric,effective_value_brl numeric,
  liquidity_class text,is_available_now boolean)
LANGUAGE sql SECURITY DEFINER SET search_path=''
AS $function$
WITH latest AS MATERIALIZED (
  SELECT DISTINCT ON(asset_name,asset_type) * FROM public.asset_positions
  WHERE user_id=p_user_id AND as_of_date<=p_as_of
  ORDER BY asset_name,asset_type,as_of_date DESC,id DESC
), moves AS (
  SELECT m.asset_position_id,sum(m.asset_delta_brl)::numeric delta
  FROM public.lts_liquidity_movement m JOIN latest a ON a.id=m.asset_position_id
  WHERE m.user_id=p_user_id AND m.status='active'
    AND m.event_date>a.as_of_date AND m.event_date<=p_as_of
  GROUP BY m.asset_position_id
), effective AS (
  SELECT a.*,coalesce(m.delta,0) stored_delta,
    CASE WHEN a.asset_name='Cofrinho Itaú' AND a.asset_type='cash_investment'
    THEN coalesce(public.lts_cofrinho_effective_locked_v245(p_user_id,p_as_of),a.value_brl+coalesce(m.delta,0))
    ELSE a.value_brl+coalesce(m.delta,0) END actual_value
  FROM latest a LEFT JOIN moves m ON m.asset_position_id=a.id
)
SELECT a.id,a.asset_name,a.asset_type,a.as_of_date,a.value_brl,
  CASE WHEN a.asset_name='Cofrinho Itaú' AND a.asset_type='cash_investment' AND a.value_brl IS NOT NULL
    THEN a.actual_value-a.value_brl ELSE a.stored_delta END,
  a.actual_value,a.liquidity_class,a.is_available_now
FROM effective a ORDER BY a.asset_name;
$function$;
REVOKE ALL ON FUNCTION public.lts_asset_position_effective_v1(uuid,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_asset_position_effective_v1(uuid,date) TO service_role;

-- The browser Flow cache includes this epoch in its key. Invalidate the old
-- calculation without altering dated sources or creating financial records.
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
