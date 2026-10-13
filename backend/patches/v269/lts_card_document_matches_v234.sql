CREATE OR REPLACE FUNCTION public.lts_card_document_matches_v234(p_user_id uuid)
RETURNS TABLE(document_id uuid,provider_id uuid)
LANGUAGE sql STABLE SET search_path='' AS $function$
SELECT document_id,provider_id FROM public.lts_card_document_candidates_v269(p_user_id) WHERE dc=1 AND pc=1;
$function$;
