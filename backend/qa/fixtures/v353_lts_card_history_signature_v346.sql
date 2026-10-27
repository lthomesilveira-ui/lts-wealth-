CREATE OR REPLACE FUNCTION public.lts_card_history_signature_v346(p_row jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
 SELECT jsonb_build_object('source_table',p_row->>'source_table','source_ref',p_row->>'source_ref',
 'event_date',p_row->>'event_date','period',coalesce(p_row->>'period',p_row->>'competence_month'),
 'amount',p_row->'amount');
$function$

