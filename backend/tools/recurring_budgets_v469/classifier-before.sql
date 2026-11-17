CREATE OR REPLACE FUNCTION public.lts_flow_classification_decision_v1(p_user_id uuid, p_event jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
SELECT coalesce((
 SELECT p_event||jsonb_build_object(
  'category',coalesce(CASE WHEN d.beneficiary IN('Benjamin','Larissa','Rafiki')
    AND d.category_label IS NOT NULL AND d.category_label !~* '^(Lucas|Benjamin|Larissa|Rafiki)[[:space:]]*[-—]'
   THEN d.beneficiary||' - '||d.category_label ELSE d.category_label END,p_event->>'category'),
  'center_cost',coalesce(d.beneficiary,p_event->>'center_cost'),
  'classification_confirmed',d.category_label IS NOT NULL)
 FROM public.lts_v178_review_decision d WHERE d.user_id=p_user_id
 AND d.source_table=CASE
  WHEN p_event->>'source'='open_finance' OR p_event->>'open_finance_id' IS NOT NULL THEN 'lts_open_finance_staging'
  WHEN p_event->>'source'='current_event' THEN 'daily_flow_documentary_bridge'
  WHEN p_event->>'source'='legacy_fix86' AND p_event->>'source_ref' ~ '^evento_base:[0-9]+$' THEN 'evento_base'
  ELSE p_event->>'source' END
 AND d.source_ref=CASE
  WHEN p_event->>'open_finance_id' IS NOT NULL THEN p_event->>'open_finance_id'
  WHEN p_event->>'source'='legacy_fix86' AND p_event->>'source_ref' ~ '^evento_base:[0-9]+$'
   THEN split_part(p_event->>'source_ref',':',2)
  ELSE p_event->>'source_ref' END
),p_event)
$function$

