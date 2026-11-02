-- Read each provider day and the bank-receipt set once for a requested range.
-- Do not call the single-day bank/source adapters for every future calendar day.
CREATE OR REPLACE FUNCTION public.lts_dated_d0_series_v399(p_user_id uuid,p_from date,p_to date)
RETURNS TABLE(flow_date date,d0_resource numeric)
LANGUAGE sql STABLE SET search_path='' SET "TimeZone"='America/Sao_Paulo'
AS $function$
WITH days AS MATERIALIZED (
 SELECT p_from+n AS d FROM generate_series(0,p_to-p_from)n
), anchors AS MATERIALIZED (
 SELECT l.lock_key,l.locked_at,(l.canonical_value->>'as_of')::date AS dt,
  (l.canonical_value->>'amount')::numeric AS amount
 FROM public.lts_validated_lock_registry l
 WHERE l.lock_key LIKE 'itau_cofrinho_%' AND l.superseded_at IS NULL
 AND (l.canonical_value->>'as_of')::date<=p_to
 AND EXISTS(SELECT 1 FROM public.asset_positions a WHERE a.user_id=p_user_id
  AND a.asset_name='Cofrinho Itaú' AND a.asset_type='cash_investment'
  AND a.metadata->>'validated_lock_key'=l.lock_key)
), first_collection AS MATERIALIZED (
 SELECT (min(r.started_at) AT TIME ZONE 'America/Sao_Paulo')::date AS dt
 FROM public.lts_open_finance_sync_run r
 JOIN public.lts_open_finance_connection c ON c.id=r.connection_id AND c.user_id=r.user_id
 WHERE r.user_id=p_user_id AND c.provider='pluggy' AND c.institution_code='341'
), provider_days AS MATERIALIZED (
 SELECT DISTINCT least(d,current_date) AS d FROM days
 WHERE least(d,current_date)>=(SELECT dt FROM first_collection)
), provider_positions AS MATERIALIZED (
 SELECT d,public.lts_cofrinho_provider_position_v402(p_user_id,d) AS j FROM provider_days
), receipt_boundary AS MATERIALIZED (
 SELECT min(dt) AS dt FROM (
  SELECT min(dt) AS dt FROM anchors
  UNION ALL SELECT min((j->>'snapshot_date')::date) FROM provider_positions
  WHERE coalesce((j->>'has_position')::boolean,false)
 ) boundaries
), receipts AS MATERIALIZED (
 SELECT r.*,s.occurred_at
 FROM receipt_boundary b
 CROSS JOIN LATERAL public.lts_cofrinho_bank_redemptions_v381(p_user_id,b.dt-1,p_to) r
 JOIN public.lts_open_finance_staging s ON s.id=r.staging_id AND s.user_id=p_user_id
 WHERE b.dt IS NOT NULL
), movements AS MATERIALIZED (
 SELECT m.*,a.asset_name,a.asset_type,f.metadata AS bank_event_metadata
 FROM public.lts_liquidity_movement m
 JOIN public.asset_positions a ON a.id=m.asset_position_id AND a.user_id=m.user_id
 LEFT JOIN public.financial_events f ON f.id=m.bank_event_id AND f.user_id=m.user_id
 WHERE m.user_id=p_user_id AND m.status='active' AND m.event_date<=p_to
), linked_movements AS MATERIALIZED (
 SELECT m.*,r.n AS linked_receipts,r.occurred_at AS receipt_at
 FROM movements m CROSS JOIN LATERAL (
  SELECT count(*) AS n,min(r.occurred_at) AS occurred_at FROM receipts r
  WHERE m.metadata->>'bank_staging_id'=r.staging_id::text
   OR m.metadata#>>'{bank_reconciliation_evidence,bank_source_id}'=r.staging_id::text
   OR m.bank_event_metadata->>'bank_staging_id'=r.staging_id::text
 ) r
 WHERE m.asset_name='Cofrinho Itaú' AND m.asset_type='cash_investment'
), positions AS MATERIALIZED (
 SELECT d.d,a.id,a.asset_name,a.asset_type,a.as_of_date,a.value_brl,a.liquidity_class,a.is_available_now
 FROM days d LEFT JOIN LATERAL (
  SELECT DISTINCT ON(asset_name,asset_type)* FROM public.asset_positions
  WHERE user_id=p_user_id AND as_of_date<=d.d
  ORDER BY asset_name,asset_type,as_of_date DESC,id DESC
 ) a ON true
), cofrinho_context AS MATERIALIZED (
 SELECT d.d,a.dt AS documentary_date,a.amount AS documentary_amount,
  coalesce((p.j->>'has_position')::boolean,false) AS has_provider,
  (p.j->>'snapshot_date')::date AS provider_date,
  (p.j->>'snapshot_at')::timestamptz AS provider_at,
  (p.j->>'snapshot_brl')::numeric AS provider_amount
 FROM days d LEFT JOIN LATERAL (
  SELECT * FROM anchors a WHERE a.dt<=d.d
  ORDER BY a.dt DESC,a.locked_at DESC,a.lock_key DESC LIMIT 1
 ) a ON true
 LEFT JOIN provider_positions p ON p.d=least(d.d,current_date)
), cofrinho_values AS MATERIALIZED (
 SELECT c.d,
  c.documentary_date IS NOT NULL OR c.has_provider AS has_position,
  CASE WHEN c.has_provider AND(c.documentary_date IS NULL OR c.provider_date>c.documentary_date)
  THEN CASE WHEN
   EXISTS(SELECT 1 FROM receipts r WHERE r.event_date<=c.d AND r.occurred_at>c.provider_at AND r.representation_conflict)
   OR EXISTS(SELECT 1 FROM linked_movements m WHERE m.event_date=c.provider_date AND m.event_date<=c.d AND m.linked_receipts<>1)
  THEN NULL ELSE c.provider_amount
   +coalesce((SELECT sum(m.asset_delta_brl) FROM linked_movements m
     WHERE m.event_date<=c.d AND(m.event_date>c.provider_date OR(m.event_date=c.provider_date AND m.linked_receipts=1 AND m.receipt_at>c.provider_at))),0)
   +coalesce((SELECT sum(r.unrepresented_asset_delta_brl) FROM receipts r
     WHERE r.event_date<=c.d AND r.occurred_at>c.provider_at AND NOT r.representation_conflict),0)
  END
  ELSE CASE WHEN EXISTS(SELECT 1 FROM receipts r WHERE r.event_date>c.documentary_date
   AND r.event_date<=c.d AND r.representation_conflict) THEN NULL
  ELSE c.documentary_amount
   +coalesce((SELECT sum(m.asset_delta_brl) FROM movements m WHERE m.asset_name='Cofrinho Itaú'
     AND m.asset_type='cash_investment' AND m.event_date>c.documentary_date AND m.event_date<=c.d),0)
   +coalesce((SELECT sum(r.unrepresented_asset_delta_brl) FROM receipts r
     WHERE r.event_date>c.documentary_date AND r.event_date<=c.d AND NOT r.representation_conflict),0)
  END END AS amount
 FROM cofrinho_context c
), effective AS (
 SELECT p.*,CASE WHEN p.asset_name='Cofrinho Itaú' AND p.asset_type='cash_investment' AND c.has_position
 THEN c.amount ELSE p.value_brl+coalesce((SELECT sum(m.asset_delta_brl) FROM movements m
  WHERE m.asset_position_id=p.id AND m.event_date>p.as_of_date AND m.event_date<=p.d),0)
 END AS effective_value
 FROM positions p JOIN cofrinho_values c ON c.d=p.d
)
SELECT d,CASE WHEN bool_or(asset_name='Cofrinho Itaú' AND asset_type='cash_investment'
 AND liquidity_class='D+0' AND is_available_now AND effective_value IS NULL)
 THEN NULL ELSE coalesce(sum(effective_value) FILTER(WHERE liquidity_class='D+0' AND is_available_now),0)::numeric END
FROM effective GROUP BY d ORDER BY d;
$function$;
