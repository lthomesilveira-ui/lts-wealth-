CREATE OR REPLACE FUNCTION public.lts_card_due_overlay_v290(p_user_id uuid, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
SELECT public.lts_card_transition_overlay_v370(p_user_id,CASE WHEN jsonb_typeof(p_payload->'cards')='array' THEN jsonb_set(p_payload,'{cards}',coalesce((
 SELECT jsonb_agg(c.value||jsonb_build_object('cycles',coalesce((
 SELECT jsonb_agg(y.value||CASE WHEN r.due_day IS NOT NULL AND y.value->>'invoice_source_id' IS NULL THEN
 jsonb_build_object('due_date',((y.value->>'month')::date+r.due_day-1),
 'original_due_date',y.value->>'due_date','due_date_basis','owner_confirmed_cycle_rule',
 'due_rule_effective_from',r.effective_from,'due_rule_confirmed_at',r.confirmed_at)
 WHEN r.due_day IS NOT NULL AND (y.value->>'due_date')::date<>((y.value->>'month')::date+r.due_day-1)
 THEN jsonb_build_object('due_date_conflict',true,'owner_expected_due_date',((y.value->>'month')::date+r.due_day-1))
 ELSE '{}'::jsonb END ORDER BY y.ord)
 FROM jsonb_array_elements(coalesce(c.value->'cycles','[]')) WITH ORDINALITY y(value,ord)
 LEFT JOIN LATERAL(SELECT r.* FROM public.lts_card_due_rule_v290 r WHERE r.user_id=p_user_id
 AND r.family=c.value->>'family' AND (y.value->>'month')::date>=r.effective_from
 ORDER BY r.effective_from DESC LIMIT 1)r ON true
 ),'[]'::jsonb)) ORDER BY c.ord)
 FROM jsonb_array_elements(p_payload->'cards') WITH ORDINALITY c(value,ord)
),'[]'),false) ELSE p_payload END)
$function$
