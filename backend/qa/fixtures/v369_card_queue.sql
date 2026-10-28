CREATE OR REPLACE FUNCTION public.lts_browser_card_review_queue_v312(p_from date DEFAULT '2013-10-10'::date, p_to date DEFAULT CURRENT_DATE, p_offset integer DEFAULT 0, p_limit integer DEFAULT 10, p_query text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); pending jsonb; page_items jsonb; result jsonb; overlap text[]:=ARRAY[]::text[];
 total integer;matched integer;off integer:=greatest(coalesce(p_offset,0),0);lim integer:=least(greatest(coalesce(p_limit,10),1),50);
 first_month date;q text:=public.lts_v178_norm(nullif(trim(p_query),''));epoch_before bigint;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<'2013-10-10' OR length(coalesce(p_query,''))>300 THEN RAISE EXCEPTION 'Período ou busca inválidos.';END IF;
 SELECT epoch INTO epoch_before FROM public.lts_read_cache_epoch_v242 WHERE singleton;
 SELECT coalesce(jsonb_agg(item),'[]') INTO pending FROM public.lts_card_pending_sources_v312(u)
 WHERE (item->>'event_date')::date BETWEEN p_from AND least(p_to,current_date);
 total:=jsonb_array_length(pending);
 IF total>0 THEN
  SELECT coalesce(array_agg(r.source_ref),ARRAY[]::text[]) INTO overlap
  FROM public.lts_v229_review_rows(u,p_from,least(p_to,current_date))r
  WHERE r.source_table='lts_open_finance_staging' AND r.identity_status='pending'
  AND EXISTS(SELECT 1 FROM jsonb_array_elements(pending)x WHERE x->>'source_ref'=r.source_ref);
 END IF;
 SELECT count(*) INTO matched FROM jsonb_array_elements(pending)x
 WHERE q IS NULL OR q='' OR strpos(public.lts_v178_norm(concat_ws(' ',x->>'description',x->>'account_source',x->>'last4')),q)>0;
 SELECT coalesce(jsonb_agg(x ORDER BY x->>'event_date' DESC,x->>'source_ref'),'[]') INTO page_items
 FROM(SELECT x FROM jsonb_array_elements(pending)x WHERE q IS NULL OR q='' OR
 strpos(public.lts_v178_norm(concat_ws(' ',x->>'description',x->>'account_source',x->>'last4')),q)>0
 ORDER BY x->>'event_date' DESC,x->>'source_ref' OFFSET off LIMIT lim)page;
 SELECT jsonb_build_object('ok',true,'version','card-review-v312','row_count',total,
 'additional_count',(SELECT count(*) FROM jsonb_array_elements(pending)x WHERE NOT(x->>'source_ref'=ANY(overlap))),
 'matched_count',matched,'offset',off,'next_offset',CASE WHEN off+lim<matched THEN off+lim END,
 'category_options',(SELECT jsonb_agg(category ORDER BY category) FROM public.lts_category_catalog WHERE user_id=u AND active
 AND public.lts_v178_norm(category) NOT IN('','a classificar','nao identificado','sem categoria','—')),
 'rows',coalesce((SELECT jsonb_agg(x||jsonb_build_object('suggestion',s.suggestion) ORDER BY x->>'event_date' DESC,x->>'source_ref')
 FROM jsonb_array_elements(page_items)x LEFT JOIN public.lts_card_review_suggestions_v312(u,page_items)s ON s.source_ref=x->>'source_ref'),'[]'),
 'checked_at',clock_timestamp(),'financial_effect','none') INTO result;
 IF epoch_before IS DISTINCT FROM(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton) THEN
 RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='As informações foram atualizadas. Tente novamente.';END IF;
 RETURN result;
END $function$
;

