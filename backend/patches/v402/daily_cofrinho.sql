-- Daily Cofrinho positions come only from the already verified resource identities.
-- Preserve every original observation, documentary position and bank movement.
DO $preserve$
DECLARE d text;
BEGIN
 IF to_regprocedure('public.lts_cofrinho_documentary_composition_v402(uuid,date)') IS NULL THEN
  d:=pg_get_functiondef('public.lts_cofrinho_composition_v399(uuid,date)'::regprocedure);
  IF position('dated-cofrinho-composition-v399' IN d)=0 THEN
   RAISE EXCEPTION 'Review the documentary composition before applying V402';
  END IF;
  EXECUTE replace(d,'FUNCTION public.lts_cofrinho_composition_v399(',
                   'FUNCTION public.lts_cofrinho_documentary_composition_v402(');
 END IF;
END $preserve$;

CREATE OR REPLACE FUNCTION public.lts_cofrinho_provider_position_v402(p_user_id uuid,p_date date)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' SET "TimeZone"='America/Sao_Paulo'
AS $function$
WITH mapping AS MATERIALIZED (
 SELECT m.*,c.id AS connection_id
 FROM public.lts_open_finance_resource_map m
 JOIN public.lts_open_finance_connection c
  ON c.user_id=m.user_id AND c.provider=m.provider
  AND c.provider_connection_ref=m.item_id AND c.institution_code='341'
 WHERE m.user_id=p_user_id AND m.provider='pluggy' AND m.resource_type='investment'
 AND m.local_target='itau_cofrinhos' AND p_date IS NOT NULL
), expected AS MATERIALIZED (
 SELECT count(*) AS n,count(DISTINCT connection_id) AS connections,
 count(DISTINCT provider_resource_id) AS identities,
 bool_and(reconciliation_status='verified'
  AND jsonb_typeof(metadata->'itau_cofrinhos_total')='number'
  AND jsonb_typeof(metadata->'component_net_valuation')='number') AS reviewed,
 sum(CASE WHEN jsonb_typeof(metadata->'component_net_valuation')='number'
  THEN (metadata->>'component_net_valuation')::numeric END) AS reviewed_components,
 min(CASE WHEN jsonb_typeof(metadata->'itau_cofrinhos_total')='number'
  THEN (metadata->>'itau_cofrinhos_total')::numeric END) AS reviewed_total_min,
 max(CASE WHEN jsonb_typeof(metadata->'itau_cofrinhos_total')='number'
  THEN (metadata->>'itau_cofrinhos_total')::numeric END) AS reviewed_total_max
 FROM mapping
), selected AS (
 SELECT r.id AS run_id,r.started_at,r.finished_at,q.*
 FROM public.lts_open_finance_sync_run r
 CROSS JOIN expected e
 CROSS JOIN LATERAL (
  SELECT count(*) AS n,bool_and(v.valid) AS valid,
   sum(v.net) AS amount,
   coalesce(min(v.source_at) FILTER(WHERE v.status='ACTIVE'),max(v.source_at)) AS source_at,
   max(v.source_at) FILTER(WHERE v.status='ACTIVE')-
    min(v.source_at) FILTER(WHERE v.status='ACTIVE') AS active_time_spread,
   max(o.observed_at) AS observed_at,
   jsonb_agg(jsonb_build_object('code',m.fingerprint,'provider_id',m.provider_resource_id,
    'net_brl',v.net,'gross_brl',o.raw_payload->'amount','tax_brl',o.raw_payload->'taxes',
    'status',v.status,'source_updated_at',v.source_at,'observed_at',o.observed_at,
    'observation_id',o.id,'raw_hash',o.raw_hash) ORDER BY m.provider_resource_id) AS components
  FROM mapping m
  JOIN public.lts_open_finance_observation o
   ON o.sync_run_id=r.id AND o.user_id=p_user_id AND o.connection_id=m.connection_id
   AND o.resource_type='investment'
   AND o.provider_record_id=m.item_id||':'||m.provider_resource_id
  CROSS JOIN LATERAL (
   SELECT o.raw_payload->>'status' AS status,
    CASE WHEN jsonb_typeof(o.raw_payload->'balance')='number'
     THEN (o.raw_payload->>'balance')::numeric END AS net,
    CASE WHEN pg_input_is_valid(o.raw_payload->>'updatedAt','timestamp with time zone')
     THEN (o.raw_payload->>'updatedAt')::timestamptz END AS source_at
  ) x
  CROSS JOIN LATERAL (
   SELECT x.*,
    coalesce(o.raw_payload->>'id'=m.provider_resource_id
     AND o.raw_payload->>'itemId'=m.item_id
     AND o.raw_payload->>'currencyCode'='BRL'
     AND x.status IN('ACTIVE','TOTAL_WITHDRAWAL') AND x.net>=0
     AND x.source_at IS NOT NULL AND x.source_at<=o.observed_at
     AND o.observed_at<least(statement_timestamp(),
       (p_date+1)::timestamp AT TIME ZONE 'America/Sao_Paulo')
     AND (x.status='TOTAL_WITHDRAWAL' AND x.net=0
       OR x.status='ACTIVE' AND trim(o.raw_payload->>'code')=m.fingerprint)
     AND o.normalized_payload->>'amount_semantics'='net_valuation'
     AND jsonb_typeof(o.normalized_payload->'net_valuation')='number'
     AND CASE WHEN jsonb_typeof(o.normalized_payload->'net_valuation')='number'
       THEN (o.normalized_payload->>'net_valuation')::numeric=x.net ELSE false END,false) AS valid
  ) v
  WHERE m.connection_id=r.connection_id
 ) q
 WHERE r.user_id=p_user_id AND r.status='success'
 AND r.connection_id IN(SELECT connection_id FROM mapping)
 AND r.started_at<least(statement_timestamp(),
   (p_date+1)::timestamp AT TIME ZONE 'America/Sao_Paulo')
 AND r.finished_at<least(statement_timestamp(),
   (p_date+1)::timestamp AT TIME ZONE 'America/Sao_Paulo')
 AND e.n>0 AND e.connections=1 AND e.identities=e.n AND e.reviewed
 AND e.reviewed_components=e.reviewed_total_min AND e.reviewed_total_min=e.reviewed_total_max
 AND q.n=e.n AND q.valid
 AND coalesce(q.active_time_spread<=interval '5 minutes',true)
 ORDER BY r.started_at DESC,r.id DESC LIMIT 1
)
SELECT coalesce((SELECT jsonb_build_object('has_position',true,
 'source_kind','verified_open_finance_components','snapshot_date',(source_at AT TIME ZONE 'America/Sao_Paulo')::date,
 'snapshot_at',source_at,'snapshot_brl',amount,'source_observed_at',observed_at,
 'source_run_id',run_id,'components',components,
 'source_date_field_used',false,'same_complete_collection',true)
 FROM selected),jsonb_build_object('has_position',false,
 'source_kind','verified_open_finance_components','snapshot_brl',NULL));
$function$;

CREATE OR REPLACE FUNCTION public.lts_cofrinho_composition_v399(p_user_id uuid,p_date date)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' SET "TimeZone"='America/Sao_Paulo'
AS $function$
DECLARE doc jsonb;pos jsonb;result jsonb;source_at timestamptz;source_date date;
 recorded jsonb;receipts jsonb;movement_delta numeric;receipt_delta numeric;conflict boolean;
BEGIN
 -- v402-daily-verified-cofrinho: a position is not a cash movement or guessed yield.
 doc:=public.lts_cofrinho_documentary_composition_v402(p_user_id,p_date);
 -- Preserve all dates preceding the original reviewed reconciliation boundary.
 IF NOT coalesce((doc->>'has_anchor')::boolean,false) THEN RETURN doc;END IF;
 pos:=public.lts_cofrinho_provider_position_v402(p_user_id,p_date);
 IF NOT coalesce((pos->>'has_position')::boolean,false) THEN
  RETURN doc||jsonb_build_object('source_kind','primary_confirmation_and_documented_movements',
   'daily_provider_position_available',false);
 END IF;
 source_date:=(pos->>'snapshot_date')::date;source_at:=(pos->>'snapshot_at')::timestamptz;
 IF source_date<(doc->>'snapshot_date')::date THEN RETURN doc;END IF;

 WITH receipt_rows AS MATERIALIZED (
  SELECT r.*,s.occurred_at
  FROM public.lts_cofrinho_bank_redemptions_v381(p_user_id,source_date-1,p_date) r
  JOIN public.lts_open_finance_staging s ON s.id=r.staging_id AND s.user_id=p_user_id
 ), move_rows AS MATERIALIZED (
  SELECT m.*,link.n AS linked_receipts,link.occurred_at AS receipt_at
  FROM public.lts_liquidity_movement m
  JOIN public.asset_positions a ON a.id=m.asset_position_id AND a.user_id=m.user_id
  LEFT JOIN public.financial_events f ON f.id=m.bank_event_id AND f.user_id=m.user_id
  CROSS JOIN LATERAL (
   SELECT count(*) AS n,min(r.occurred_at) AS occurred_at FROM receipt_rows r
   WHERE m.metadata->>'bank_staging_id'=r.staging_id::text
    OR m.metadata#>>'{bank_reconciliation_evidence,bank_source_id}'=r.staging_id::text
    OR f.metadata->>'bank_staging_id'=r.staging_id::text
  ) link
  WHERE m.user_id=p_user_id AND m.status='active'
  AND a.asset_name='Cofrinho Itaú' AND a.asset_type='cash_investment'
  AND m.event_date BETWEEN source_date AND p_date
 ), included_moves AS MATERIALIZED (
  SELECT * FROM move_rows
  WHERE event_date>source_date OR (linked_receipts=1 AND receipt_at>source_at)
 ), included_receipts AS MATERIALIZED (
  SELECT * FROM receipt_rows WHERE occurred_at>source_at
 )
 SELECT coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'event_date',event_date,
   'movement_type',movement_type,'asset_delta_brl',asset_delta_brl) ORDER BY event_date,id)
   FROM included_moves),'[]'),
  coalesce((SELECT jsonb_agg(to_jsonb(r) ORDER BY event_date,staging_id) FROM included_receipts r),'[]'),
  coalesce((SELECT sum(asset_delta_brl) FROM included_moves),0),
  coalesce((SELECT sum(unrepresented_asset_delta_brl) FROM included_receipts WHERE NOT representation_conflict),0),
  coalesce((SELECT bool_or(representation_conflict) FROM included_receipts),false)
   OR EXISTS(SELECT 1 FROM move_rows WHERE event_date=source_date AND linked_receipts<>1)
 INTO recorded,receipts,movement_delta,receipt_delta,conflict;

 result:=doc||pos||jsonb_build_object('version','daily-verified-cofrinho-v402',
  'has_anchor',true,'as_of',p_date,'complete',NOT conflict,
  'status',CASE WHEN conflict THEN 'reconciliation_required' ELSE 'verified_daily_position_and_distinct_later_movements' END,
  'lock_key',NULL,'recorded_movement_delta_brl',movement_delta,
  'unrepresented_redemption_delta_brl',receipt_delta,
  'available_brl',CASE WHEN NOT conflict THEN (pos->>'snapshot_brl')::numeric+movement_delta+receipt_delta END,
  'recorded_movements',recorded,'bank_redemptions',receipts,
  'daily_provider_position_available',true,'post_snapshot_movements_only',true,
  'source_cached_from_prior_day',source_date<least(p_date,current_date),
  'cash_event_created',false,'yield_event_created',false);
 IF source_date=(doc->>'snapshot_date')::date THEN
  -- Explicit owner positions remain authoritative for their own dates.
  IF (result->>'available_brl')::numeric IS NOT DISTINCT FROM (doc->>'available_brl')::numeric THEN
   RETURN doc||jsonb_build_object('version','daily-verified-cofrinho-v402',
    'source_kind','primary_confirmation_and_verified_open_finance',
    'components',pos->'components','source_observed_at',pos->'source_observed_at',
    'snapshot_at',pos->'snapshot_at','source_run_id',pos->'source_run_id',
    'daily_provider_position_available',true,'provider_comparison_equal',true,
    'source_cached_from_prior_day',source_date<least(p_date,current_date));
  END IF;
  RETURN doc||jsonb_build_object('source_kind','primary_confirmation_and_documented_movements',
   'provider_comparison_equal',false,'provider_comparison',result,
   'daily_provider_position_available',true);
 END IF;
 RETURN result;
END $function$;

CREATE OR REPLACE FUNCTION public.lts_cofrinho_effective_locked_v245(p_user_id uuid,p_date date)
RETURNS numeric LANGUAGE sql STABLE SET search_path='' SET "TimeZone"='America/Sao_Paulo'
AS $function$
 SELECT (public.lts_cofrinho_composition_v399(p_user_id,p_date)->>'available_brl')::numeric;
$function$;

DO $consumers$
DECLARE d text;old_block text;new_block text;changed boolean:=false;
BEGIN
 d:=pg_get_functiondef('public.lts_dated_d0_series_v399(uuid,date,date)'::regprocedure);
 IF position('v402-daily-verified-cofrinho-series' IN d)=0 THEN
  old_block:=substring(d FROM $regex$CASE WHEN p.asset_name='Cofrinho Itaú'[\s\S]*?ELSE p.value_brl$regex$);
  IF old_block IS NULL THEN RAISE EXCEPTION 'Review the batched D0 consumer before V402';END IF;
  new_block:=$new$CASE WHEN p.asset_name='Cofrinho Itaú' AND p.asset_type='cash_investment' AND x.dt IS NOT NULL
 THEN (public.lts_cofrinho_composition_v399(p_user_id,p.d)->>'available_brl')::numeric
 -- v402-daily-verified-cofrinho-series: other assets keep their original rules.
 ELSE p.value_brl$new$;
  EXECUTE replace(d,old_block,new_block);changed:=true;
 END IF;
 d:=pg_get_functiondef('public.lts_current_evidence_position_v2(uuid)'::regprocedure);
 IF position('v402-current-daily-cofrinho' IN d)=0 THEN
  old_block:=$old$c as (select (canonical_value->>'amount')::numeric v from public.lts_validated_lock_registry where lock_key='itau_cofrinho_20260926' and superseded_at is null)$old$;
  new_block:=$new$c as (select (j->>'available_brl')::numeric v,j->>'snapshot_date' dt from
   (select public.lts_cofrinho_composition_v399(p_user_id,current_date)j)p) -- v402-current-daily-cofrinho
 $new$;
  IF position(old_block IN d)=0 THEN RAISE EXCEPTION 'Review the current-position consumer before V402';END IF;
  d:=replace(d,old_block,new_block);
  d:=replace(d,$old$'type','cash_investment','as_of',current_date,'value_brl',c.v$old$,
              $new$'type','cash_investment','as_of',c.dt,'value_brl',c.v$new$);
  EXECUTE d;changed:=true;
 END IF;
 IF changed THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;END IF;
END $consumers$;

REVOKE ALL ON FUNCTION public.lts_cofrinho_documentary_composition_v402(uuid,date),
 public.lts_cofrinho_provider_position_v402(uuid,date),public.lts_cofrinho_composition_v399(uuid,date),
 public.lts_cofrinho_effective_locked_v245(uuid,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_cofrinho_documentary_composition_v402(uuid,date),
 public.lts_cofrinho_provider_position_v402(uuid,date),public.lts_cofrinho_composition_v399(uuid,date),
 public.lts_cofrinho_effective_locked_v245(uuid,date) TO service_role;
