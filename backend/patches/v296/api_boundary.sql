-- Keep the privileged owner-checked reader outside the exposed API schema.
CREATE OR REPLACE FUNCTION lts_income_private.queue_v296(p_from date,p_to date,
 p_offset integer DEFAULT 0,p_limit integer DEFAULT 25,p_query text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET TimeZone='America/Sao_Paulo' AS $fn$
DECLARE u uuid:=public.lts_browser_assert_user_v1();result jsonb;
BEGIN
 IF p_offset IS NULL OR p_limit IS NULL OR p_offset<0 OR p_limit NOT BETWEEN 1 AND 100 OR length(coalesce(p_query,''))>300 THEN RAISE EXCEPTION 'Filtro inválido.';END IF;
 WITH pending AS MATERIALIZED(
  SELECT x FROM lts_income_private.rows_v296(u,p_from,p_to)x
  WHERE public.lts_v178_norm(x->>'category') IN('','a classificar','classificacao pendente','sem categoria','nao identificado','—')
 ),filtered AS MATERIALIZED(
  SELECT x FROM pending WHERE nullif(trim(p_query),'') IS NULL
  OR strpos(public.lts_v178_norm(concat_ws(' ',x->>'description',x->>'account',x->>'category')),public.lts_v178_norm(p_query))>0
 ),page AS(
  SELECT x FROM filtered ORDER BY x->>'event_date' DESC,(x->>'signed_amount')::numeric DESC,x->>'review_key' OFFSET p_offset LIMIT p_limit
 ) SELECT jsonb_build_object('ok',true,'from',p_from,'to',p_to,'row_count',(SELECT count(*) FROM pending),
  'matched_count',(SELECT count(*) FROM filtered),'offset',p_offset,
  'next_offset',CASE WHEN p_offset+p_limit<(SELECT count(*) FROM filtered) THEN p_offset+p_limit END,
  'rows',coalesce((SELECT jsonb_agg(x ORDER BY x->>'event_date' DESC,(x->>'signed_amount')::numeric DESC,x->>'review_key') FROM page),'[]')) INTO result;
 RETURN result;
END $fn$;
REVOKE ALL ON FUNCTION lts_income_private.queue_v296(date,date,integer,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION lts_income_private.queue_v296(date,date,integer,integer,text) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.lts_browser_income_review_queue_v296(p_from date,p_to date,
 p_offset integer DEFAULT 0,p_limit integer DEFAULT 25,p_query text DEFAULT NULL)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $fn$
 SELECT lts_income_private.queue_v296(p_from,p_to,p_offset,p_limit,p_query);
$fn$;
REVOKE ALL ON FUNCTION public.lts_browser_income_review_queue_v296(date,date,integer,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_income_review_queue_v296(date,date,integer,integer,text) TO authenticated,service_role;
