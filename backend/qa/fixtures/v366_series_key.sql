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
$function$
;
