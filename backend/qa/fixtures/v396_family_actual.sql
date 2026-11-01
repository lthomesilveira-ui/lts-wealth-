CREATE OR REPLACE FUNCTION public.lts_card_family_v226(p_name text, p_bank text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
 DECLARE
 n text:=pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(p_name,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g');
 b text:=pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(p_bank,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g');
 BEGIN
 RETURN CASE WHEN n LIKE '%aeternum%' THEN 'aeternum'
 WHEN n LIKE '%c6%' OR n LIKE '%bandeirado%' THEN 'c6'
 WHEN n LIKE '%visa%' AND b LIKE '%itau%' THEN 'itau_visa'
 WHEN n LIKE '%visa%' AND b LIKE '%bradesco%' THEN 'bradesco_prime'
 WHEN n LIKE '%mastercard%' OR n LIKE '%mc black%' OR n LIKE '%personnalite%' THEN 'itau_mastercard'
 END;
 END $function$
;
