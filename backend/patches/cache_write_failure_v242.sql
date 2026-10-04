-- Derived read data may be invalidated; economic records remain append-only.
-- The original statement trigger used DELETE with no predicate, which aborts
-- every edit under the production safe-update policy.
CREATE OR REPLACE FUNCTION public.lts_v229_invalidate_read_cache()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
BEGIN
 DELETE FROM public.lts_v229_read_cache WHERE user_id IS NOT NULL;
 RETURN NULL;
END $function$;
REVOKE ALL ON FUNCTION public.lts_v229_invalidate_read_cache() FROM PUBLIC,anon,authenticated;
