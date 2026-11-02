-- The same dated D0 calculation, with one source-identity redemption scan per range.
CREATE OR REPLACE FUNCTION public.lts_dated_d0_series_v399(p_user_id uuid,p_from date,p_to date)
RETURNS TABLE(flow_date date,d0_resource numeric)
LANGUAGE sql STABLE SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $function$
WITH anchors AS MATERIALIZED(
 SELECT l.lock_key,l.locked_at,(l.canonical_value->>'as_of')::date dt,(l.canonical_value->>'amount')::numeric amount
 FROM public.lts_validated_lock_registry l WHERE l.lock_key LIKE 'itau_cofrinho_%'
 AND l.superseded_at IS NULL AND (l.canonical_value->>'as_of')::date<=p_to
 AND EXISTS(SELECT 1 FROM public.asset_positions a WHERE a.user_id=p_user_id
  AND a.asset_name='Cofrinho Itaú' AND a.asset_type='cash_investment'
  AND a.metadata->>'validated_lock_key'=l.lock_key)
),receipts AS MATERIALIZED(
 SELECT r.* FROM (SELECT min(dt)dt FROM anchors)x
 CROSS JOIN LATERAL public.lts_cofrinho_bank_redemptions_v381(p_user_id,x.dt,p_to)r WHERE x.dt IS NOT NULL
),movements AS MATERIALIZED(
 SELECT m.*,a.asset_name,a.asset_type FROM public.lts_liquidity_movement m
 JOIN public.asset_positions a ON a.id=m.asset_position_id AND a.user_id=m.user_id
 WHERE m.user_id=p_user_id AND m.status='active' AND m.event_date<=p_to
),days AS(
 SELECT p_from+n d FROM generate_series(0,p_to-p_from)n
),positions AS MATERIALIZED(
 SELECT d.d,a.id,a.asset_name,a.asset_type,a.as_of_date,a.value_brl,a.liquidity_class,a.is_available_now
 FROM days d LEFT JOIN LATERAL(
  SELECT DISTINCT ON(asset_name,asset_type)* FROM public.asset_positions
  WHERE user_id=p_user_id AND as_of_date<=d.d
  ORDER BY asset_name,asset_type,as_of_date DESC,id DESC
 )a ON true
),effective AS(
 SELECT p.*,CASE WHEN p.asset_name='Cofrinho Itaú'AND p.asset_type='cash_investment'AND x.dt IS NOT NULL AND x.amount IS NOT NULL
 THEN x.amount+coalesce((SELECT sum(m.asset_delta_brl)FROM movements m
  WHERE m.asset_name='Cofrinho Itaú'AND m.asset_type='cash_investment'AND m.event_date>x.dt AND m.event_date<=p.d),0)
 +coalesce((SELECT sum(r.unrepresented_asset_delta_brl)FROM receipts r WHERE NOT r.representation_conflict AND r.event_date>x.dt AND r.event_date<=p.d),0)
 ELSE p.value_brl+coalesce((SELECT sum(m.asset_delta_brl)FROM movements m
  WHERE m.asset_position_id=p.id AND m.event_date>p.as_of_date AND m.event_date<=p.d),0)END effective_value
 FROM positions p LEFT JOIN LATERAL(SELECT*FROM anchors x WHERE x.dt<=p.d ORDER BY x.dt DESC,x.locked_at DESC,x.lock_key DESC LIMIT 1)x ON true
)
SELECT d,coalesce(sum(effective_value)FILTER(WHERE liquidity_class='D+0'AND is_available_now),0)::numeric
FROM effective GROUP BY d ORDER BY d;
$function$;
REVOKE ALL ON FUNCTION public.lts_dated_d0_series_v399(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_dated_d0_series_v399(uuid,date,date) TO service_role;

DO $patch$
DECLARE definition text;old_part text;new_part text;
BEGIN
 definition:=pg_get_functiondef('public.lts_daily_flow_fix86_v14(uuid,date,date)'::regprocedure);
 IF position('v399-batched-dated-d0'IN definition)>0 THEN RETURN;END IF;
 old_part:=$old$    coalesce((
      select sum(effective_value_brl)
      from public.lts_asset_position_effective_v1(p_user_id,r.dt)
      where liquidity_class='D+0' and is_available_now
    ),0)::numeric d0_resource$old$;
 IF position(old_part IN definition)=0 OR position('), corrected as materialized ('IN definition)=0 THEN RAISE EXCEPTION 'V399 dated D0 daily source changed';END IF;
 definition:=replace(definition,old_part,$new$    coalesce((select x.d0_resource from batch_d0 x where x.flow_date=r.dt),0)::numeric d0_resource$new$);
 definition:=replace(definition,'), corrected as materialized (',$new$), batch_d0 as materialized (
  -- v399-batched-dated-d0: preserve all D0 assets and the original numeric rules.
  select * from public.lts_dated_d0_series_v399(p_user_id,p_from,p_to)
), corrected as materialized ($new$);
 EXECUTE definition;
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
END $patch$;
