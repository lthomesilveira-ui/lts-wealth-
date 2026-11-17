CREATE OR REPLACE FUNCTION public.lts_expense_node_v353(n text, s jsonb, g numeric, c numeric, v numeric, r bigint, ch jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
 SELECT jsonb_build_object('name',n,'scope',s,'gross',round(coalesce(g,0),2),'compensations',round(coalesce(c,0),2),'net',round(coalesce(v,0),2),'rows',r,'children',coalesce(ch,'[]'))
$function$;
