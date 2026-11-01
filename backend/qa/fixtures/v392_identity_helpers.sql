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
 END $function$;
CREATE OR REPLACE FUNCTION public.lts_forecast_series_key_v1(p_description text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
 SELECT CASE
  WHEN d ~ '^salario( liquido)?$' THEN 'salary'
  WHEN d ~ '^adiantamento quinzenal' THEN 'salary_advance'
  WHEN d ~ 'aeternum' THEN 'card_aeternum'
  WHEN d ~ '(mastercard|personnalite|5546)' AND d !~ 'seguro' THEN 'card_itau'
  WHEN d ~ '(cartao c6|fatura c6|c6master|c6 carbon)' THEN 'card_c6'
  WHEN d ~ '(ipva|dpvat|licenciamento)' THEN 'vehicle_tax'
  WHEN d ~ '^iptu.*(o parque|cipo.?396)' THEN 'property_tax_cipo'
  ELSE d END
 FROM (SELECT translate(lower(regexp_replace(trim(coalesce(p_description,'')),'\s+',' ','g')),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc') d) x;
$function$;
