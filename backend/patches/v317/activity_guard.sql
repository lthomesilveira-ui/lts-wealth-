-- A provider activity that contradicts a restaurant MCC is insufficient for a restaurant guess.
CREATE OR REPLACE FUNCTION public.lts_card_activity_guard_v317(p_mcc text,p_provider_category text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $function$
SELECT CASE WHEN public.lts_card_activity_category_v312(p_mcc) IS NOT NULL AND p_provider_category='Transfers'
 OR p_mcc IN('5812','5814') AND p_provider_category IN('Cinema, theater and concerts','Stadiums and arenas','Gas stations')
 THEN 'bank_activity_conflict' END
$function$;
REVOKE ALL ON FUNCTION public.lts_card_activity_guard_v317(text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_activity_guard_v317(text,text) TO service_role;
