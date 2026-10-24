CREATE OR REPLACE FUNCTION public.lts_card_forecast_overlay_v311(p_user_id uuid,p_payload jsonb)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $function$
WITH forecast AS MATERIALIZED(SELECT * FROM public.lts_aeternum_forecast_cycles_v311(p_user_id)),
cards AS(
 SELECT card,n,CASE WHEN card->>'family'<>'aeternum' OR NOT EXISTS(SELECT 1 FROM forecast)
 THEN card ELSE card||jsonb_build_object('cycles',(
  SELECT coalesce(jsonb_agg(value ORDER BY value->>'month'),'[]') FROM (
   SELECT c value FROM jsonb_array_elements(card->'cycles') c
   WHERE NOT EXISTS(SELECT 1 FROM forecast f WHERE f.reference_month=(c->>'month')::date)
   UNION ALL
   SELECT coalesce((SELECT c FROM jsonb_array_elements(card->'cycles')c WHERE (c->>'month')::date=f.reference_month),'{}')
    ||jsonb_build_object('month',f.reference_month,'due_date',f.due_date,'amount',f.amount,'basis',f.basis,
      'item_count',f.item_count,'unclassified',f.unclassified,'items',f.items,'observed_at',f.observed_at,
      'received_amount',f.received_amount,'projected_amount',f.projected_amount,
      'projection_only',true,'official_invoice_received',false,'invoice_source_id',NULL,
      'invoice_source_updated_at',NULL,'invoice_received_at',NULL,'invoice_composition_complete',NULL,
      'invoice_composition_difference',NULL,'payment_status',NULL,'reported_payment_amount',NULL)
   FROM forecast f
  ) all_cycles
 )) END value
 FROM jsonb_array_elements(coalesce(p_payload->'cards','[]')) WITH ORDINALITY a(card,n)
)
SELECT p_payload||jsonb_build_object('cards',coalesce(jsonb_agg(value ORDER BY n),'[]')) FROM cards
$function$;
