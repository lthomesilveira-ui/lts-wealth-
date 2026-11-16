CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.cache_info(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
 SELECT coalesce((SELECT jsonb_build_object(
  'available',lts_product_refresh_private_v415.compatible(c.payload_version,c.payload),
  'current',lts_product_refresh_private_v415.compatible(c.payload_version,c.payload)
   AND c.payload#>>'{canonical_summary,as_of}'=current_date::text
   AND c.payload#>>'{updates,freshness,today}'=current_date::text
   AND c.payload#>>'{updates,document_change_summary_version}'='document-change-summary-v1'
   AND CASE WHEN jsonb_typeof(c.payload#>'{flow,days}')='array' THEN EXISTS(
    SELECT 1 FROM jsonb_array_elements(c.payload#>'{flow,days}') d WHERE d->>'date'=current_date::text) ELSE false END
   AND NOT coalesce(c.payload->'product_refresh_pending_v415'='true'::jsonb,false)
   AND lts_product_refresh_private_v415.card_state_cached(p_user_id) IS NOT NULL
   AND lts_product_refresh_private_v415.projection_current_v452(p_user_id),
  'refreshed_at',c.refreshed_at) FROM public.lts_product_read_cache c WHERE c.user_id=p_user_id),
  jsonb_build_object('available',false,'current',false,'refreshed_at',NULL))
$function$
