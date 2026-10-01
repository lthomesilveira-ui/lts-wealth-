-- Keep the same pure expression, fully qualify builtins, and allow SQL inlining.
CREATE OR REPLACE FUNCTION public.lts_v178_norm(v text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$ select pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(v,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') $function$
;
