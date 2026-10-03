CREATE OR REPLACE FUNCTION public.lts_planning_executive_v2(p_user_id uuid, p_from date DEFAULT CURRENT_DATE, p_to date DEFAULT '2027-12-31'::date)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH source AS MATERIALIZED (
 SELECT public.lts_flow_cache_core_v240(p_user_id,p_from,p_to)->'flow' j
), canonical AS (
 SELECT jsonb_build_object('version','canonical-flow-v240-cache','from',p_from,'to',p_to,
  'days',coalesce(j#>'{historical,days}','[]'::jsonb)||coalesce(j#>'{current_future,days}','[]'::jsonb),
  'events',coalesce(j#>'{historical,events}','[]'::jsonb)||coalesce(j#>'{current_future,events}','[]'::jsonb)) j FROM source
), executive AS (
 SELECT public.lts_planning_executive_from_flow_v1(p_user_id,p_from,p_to,j) j FROM canonical
)
SELECT j||jsonb_build_object(
 'version','planning-executive-v2-current-anchors',
 'reader_revision','canonical-operational-flow-v245',
 'guardrails',jsonb_build_array(
  'Planning uses the same canonical operational Flow as the dashboard.',
  'Current checking positions come from validated Open Finance sources.',
  'D0 uses documented Cofrinho; Morgan uses the validated total available.',
  'Future vestings enter only after availability.',
  'FGTS uses only the current documented balance as restricted D+30 contingency; no future accrual is estimated.'
 )
) FROM executive
$function$;
COMMENT ON FUNCTION public.lts_planning_executive_v2(uuid,date,date)
 IS 'Uses canonical operational Flow and the documented fixed FGTS balance for Planning browser consumers; preserves the public JSON contract.';
