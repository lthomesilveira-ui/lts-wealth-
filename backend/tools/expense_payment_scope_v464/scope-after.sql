CREATE OR REPLACE FUNCTION public.lts_expense_scope_v353(r jsonb, t jsonb, c text, s jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
 SELECT coalesce(
 (nullif(s->>'payment','')IS NULL OR s->>'payment'='card'AND (coalesce(r->>'source_table','') LIKE '%card%' OR coalesce(r->>'coverage_mode','') LIKE 'card_%') OR s->>'payment'='account'AND NOT (coalesce(r->>'source_table','') LIKE '%card%' OR coalesce(r->>'coverage_mode','') LIKE 'card_%'))AND
 (nullif(s->>'macrogroup','')IS NULL OR t->>'macrogroup'=s->>'macrogroup')AND
 (nullif(s->>'group','')IS NULL OR t->>'group'=s->>'group')AND
 (nullif(s->>'category','')IS NULL OR t->>'category'=s->>'category')AND
 (nullif(s->>'property','')IS NULL OR coalesce(r->>'property_code','__missing__')=s->>'property')AND
 (nullif(s->>'person','')IS NULL OR coalesce(r->>'beneficiary','__missing__')=s->>'person')AND
 (nullif(s->>'center_cost','')IS NULL OR coalesce(c,'__missing__')=s->>'center_cost')AND
 (coalesce(s->>'sign','net')='net'OR s->>'sign'='gross'AND(r->>'amount')::numeric>0 OR s->>'sign'='compensations'AND(r->>'amount')::numeric<0)AND
 (coalesce(s->>'view','type')<>'tax'OR t->>'is_tax'='true'),false)
$function$;
