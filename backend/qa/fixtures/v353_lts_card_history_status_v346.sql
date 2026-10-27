CREATE OR REPLACE FUNCTION public.lts_card_history_status_v346(p_bound boolean, p_exists boolean, p_amount numeric, p_sum numeric, p_count bigint)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
 SELECT CASE WHEN p_exists AND NOT coalesce(p_bound,false) THEN 'stale'
 WHEN coalesce(p_count,0)=0 THEN 'missing'
 WHEN round(p_sum,2)=round(p_amount,2) THEN 'complete'
 WHEN p_amount>0 AND p_sum>=0 AND p_sum<p_amount THEN 'partial'
 ELSE 'difference' END;
$function$

