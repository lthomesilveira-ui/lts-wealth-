-- Preserve the exact 30 distinct complete days rule while computing it once per date.
CREATE OR REPLACE FUNCTION public.lts_forward_liquidity_days_v399(p_days jsonb,p_from date,p_to date)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $function$
WITH all_src AS MATERIALIZED(
 SELECT x,(x->>'date')::date dt FROM jsonb_array_elements(coalesce(p_days,'[]'))x
 WHERE (x->>'date')::date BETWEEN p_from AND p_to+30
),dated AS MATERIALIZED(
 SELECT dt,count(*) row_count,count(nullif(x#>>'{Consolidado,economic_net}','')) known_count,
 sum(nullif(x#>>'{Consolidado,economic_net}','')::numeric)net FROM all_src GROUP BY dt
),forward AS MATERIALIZED(
 SELECT dt,count(*)OVER w future_dates,sum(row_count)OVER w future_rows,
 sum(known_count)OVER w known_movements,sum(net)OVER w future_net FROM dated
 WINDOW w AS(ORDER BY dt RANGE BETWEEN INTERVAL '1day' FOLLOWING AND INTERVAL '30days' FOLLOWING)
)
SELECT coalesce(jsonb_agg(jsonb_set(s.x,'{fix86_columns,liq_d30}',coalesce(to_jsonb(
 CASE WHEN f.future_dates=30 AND f.future_rows=30 AND f.known_movements=30
 THEN nullif(s.x#>>'{fix86_columns,liq_d0_1}','')::numeric+f.future_net ELSE NULL END),'null'),true)ORDER BY s.dt),'[]')
FROM all_src s JOIN forward f USING(dt)WHERE s.dt<=p_to;
$function$;
REVOKE ALL ON FUNCTION public.lts_forward_liquidity_days_v399(jsonb,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_forward_liquidity_days_v399(jsonb,date,date) TO service_role;
DO $patch$
DECLARE definition text;old_part text;
BEGIN
 definition:=pg_get_functiondef('public.lts_flow_future_read_slice_v9(uuid,date,date)'::regprocedure);
 IF position('lts_forward_liquidity_days_v399'IN definition)>0 THEN RETURN;END IF;
 old_part:=substring(definition FROM '  with all_src as \([\s\S]+?into d from adj;');
 IF old_part IS NULL THEN RAISE EXCEPTION 'V399 expected forward liquidity source changed';END IF;
 definition:=replace(definition,old_part,$new$  -- v399-complete-forward-window, preserving unknown and duplicate-date guards.
  d:=public.lts_forward_liquidity_days_v399(c.payload->'days',p_from,p_to);$new$);
 EXECUTE definition;
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
END $patch$;
