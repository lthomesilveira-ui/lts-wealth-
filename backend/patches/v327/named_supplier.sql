-- Exact named supplier context; this does not identify a product or a person.
-- Public catalogs: moosekids.com.br, usealphaco.com.br, sleepo.com.br, booma.com.br.
CREATE OR REPLACE FUNCTION public.lts_card_named_supplier_v327(p_description text,p_mcc text,p_provider_category text)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $function$
SELECT CASE
 WHEN p_mcc='5611' AND p_provider_category='Clothing'
 AND public.lts_v178_norm(p_description) ~ '^ec[[:space:]]*[*][[:space:]]*(moosebabykids|alphaco)$' THEN true
 WHEN p_mcc='5698' AND p_provider_category='Clothing'
 AND public.lts_v178_norm(p_description) ~ '^pg[[:space:]]*[*][[:space:]]*sleepo[[:space:]]+modas$' THEN true
 WHEN p_mcc='5122' AND p_provider_category='Pharmacy'
 AND public.lts_v178_norm(p_description) ~ '^pg[[:space:]]*[*][[:space:]]*booma[[:space:]]+organic[[:space:]]+cosm[[:space:]]+brasilia[[:space:]]+bra$' THEN true
 ELSE false END
$function$;
