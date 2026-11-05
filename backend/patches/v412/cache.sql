CREATE OR REPLACE FUNCTION lts_projection_private_v412.invalidate_reads(p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $f$
BEGIN
 IF p_user_id IS NULL THEN RAISE EXCEPTION 'Invalid projection owner';END IF;
 DELETE FROM public.lts_flow_future_read_cache WHERE user_id=p_user_id;
 DELETE FROM public.lts_flow_future_read_cache_v2 WHERE user_id=p_user_id;
 DELETE FROM public.lts_v229_read_cache WHERE user_id=p_user_id;
 DELETE FROM public.lts_dashboard_cockpit_cache WHERE user_id=p_user_id;
 DELETE FROM public.lts_product_read_cache WHERE user_id=p_user_id;
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
END $f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.invalidate_reads(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.invalidate_reads(uuid) TO service_role;
