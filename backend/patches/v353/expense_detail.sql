CREATE FUNCTION public.lts_browser_expense_detail_v353(p_from date,p_to date,p_scope jsonb DEFAULT '{}',p_offset integer DEFAULT 0,p_limit integer DEFAULT 500,p_query text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb;base jsonb;result_rows jsonb;rev text;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_to>current_date OR p_from<date '2013-10-10' OR p_offset<0 OR p_limit NOT BETWEEN 1 AND 10000 OR jsonb_typeof(p_scope)IS DISTINCT FROM 'object'OR(p_scope-ARRAY['macrogroup','group','category','property','person','center_cost','sign','view'])<>'{}'OR coalesce(p_scope->>'view','type')NOT IN('type','property','tax')OR coalesce(p_scope->>'sign','net')NOT IN('net','gross','compensations')THEN RAISE EXCEPTION 'invalid detail range or filters';END IF;
 rev:=public.lts_card_read_start_v269(u);
 WITH context AS MATERIALIZED(
 SELECT source_table,source_ref,min(nullif(trim(center_cost),''))center_cost FROM public.lts_expense_effective_rows_v176(u,p_from,p_to)GROUP BY source_table,source_ref HAVING count(*)=1),
 r AS MATERIALIZED(
 SELECT x.*,t.taxonomy,CASE WHEN c.center_cost IN('Não atribuído','Não identificado')THEN NULL ELSE c.center_cost END center_cost
 FROM public.lts_v229_expense_rows(u,p_from,p_to)x
 LEFT JOIN context c ON c.source_table=x.source_table AND c.source_ref=x.source_ref
 CROSS JOIN LATERAL(SELECT public.lts_expense_taxonomy_v353(x.category,x.property_component,x.management_group)taxonomy)t
 WHERE public.lts_expense_scope_v353(to_jsonb(x),t.taxonomy,CASE WHEN c.center_cost IN('Não atribuído','Não identificado')THEN NULL ELSE c.center_cost END,p_scope)
 ), filtered AS MATERIALIZED(
  SELECT * FROM r WHERE nullif(trim(p_query),'') IS NULL OR strpos(public.lts_v178_norm(concat_ws(' ',description,account_source,beneficiary,raw_reference,category)),public.lts_v178_norm(trim(p_query)))>0
 ), page AS MATERIALIZED(SELECT * FROM filtered ORDER BY event_date DESC,amount DESC,row_key OFFSET p_offset LIMIT p_limit)
 SELECT jsonb_build_object('version','expense-detail-v178','from',p_from,'to',p_to,'scope',p_scope,
  'total',(SELECT round(coalesce(sum(amount),0),2) FROM r),'row_count',(SELECT count(*) FROM r),
  'matched_count',(SELECT count(*) FROM filtered),'matched_total',(SELECT round(coalesce(sum(amount),0),2) FROM filtered),'offset',p_offset,
  'next_offset',CASE WHEN p_offset+p_limit<(SELECT count(*) FROM filtered) THEN p_offset+p_limit END,
  'revision',(SELECT md5(coalesce(jsonb_agg(to_jsonb(x)ORDER BY x.row_key),'[]'::jsonb)::text)FROM r x),
  'rows',coalesce((SELECT jsonb_agg(jsonb_build_object(
   'key',p.row_key,'date',CASE WHEN p.source_table LIKE '%card%' OR p.coverage_mode LIKE 'card_%' THEN p.purchase_date ELSE p.event_date END,
   'event_date',p.event_date,'transaction_date',p.transaction_date,'period',p.competence_month,
   'date_kind',CASE WHEN (p.source_table LIKE '%card%' OR p.coverage_mode LIKE 'card_%') AND p.purchase_date IS NULL THEN 'month' ELSE 'day' END,
   'description',p.description,'account_source',p.account_source,'beneficiary',p.beneficiary,'reference',p.raw_reference,
   'amount',p.amount,'category',p.management_group,'current_category',p.category,'original_category',p.category,'taxonomy',p.taxonomy,'center_cost',p.center_cost,'component',p.property_component,
   'subgroup',p.management_subgroup,'status',p.identity_status,'property_code',p.property_code,'source_table',p.source_table,'source_ref',p.source_ref,
   'coverage_mode',p.coverage_mode,'can_classify',p.coverage_mode NOT IN ('card_invoice_aggregate_fallback','card_workbook_signed_adjustment_v235'),
   'invoice_family',CASE WHEN p.source_table LIKE '%card%' OR p.coverage_mode LIKE 'card_%' THEN coalesce(public.lts_card_family_v226(p.account_source,p.account_source),(SELECT public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) FROM public.lts_open_finance_staging s WHERE s.user_id=u AND p.source_table='lts_open_finance_staging' AND s.id::text=p.source_ref LIMIT 1)) END,
   'invoice_month',CASE WHEN p.source_table LIKE '%card%' OR p.coverage_mode LIKE 'card_%' THEN p.competence_month END,
   'document_status',CASE WHEN p.coverage_mode='card_invoice_aggregate_fallback' THEN 'composition_missing' END,
   'source_audit',CASE WHEN a.source_ref IS NOT NULL THEN jsonb_build_object(
    'file',a.source_file,'sheet',a.source_sheet,'rows',a.source_rows,'source_amount',a.source_signed_amount,
    'status',CASE WHEN a.source_signed_amount<0 THEN 'signed_adjustment' ELSE a.composition_status END,
    'detail_rows',a.detail_rows,'detail_total',a.detail_total,'difference',a.detail_difference,
    'note',CASE WHEN a.source_signed_amount<0 THEN 'Ajuste negativo registrado na planilha; não é nova compra nem comprovação de crédito bancário.'
     WHEN a.composition_status='unreconciled_detail' THEN 'A composição já foi recebida na planilha, mas ainda difere do total desta fatura.'
     ELSE 'A planilha registra o total ou parte da fatura. As compras individuais não foram localizadas nas fontes conferidas.' END) END,
   'source_identity',CASE WHEN e.source_ref IS NOT NULL THEN jsonb_build_object('category',e.original_category,'description',e.original_description,'sheet',e.source_sheet,'rows',e.source_rows,'note','Categoria conferida com a planilha original.') END,
   'review_question',CASE WHEN p.identity_status='pending' THEN 'Confirme a classificação deste lançamento.' END
  ) ORDER BY p.event_date DESC,p.amount DESC,p.row_key) FROM page p LEFT JOIN public.lts_card_history_source_audit_v235 a ON a.user_id=u
 AND a.source_table=p.source_table AND a.source_ref=p.source_ref AND a.event_date=p.event_date
 AND a.source_signed_amount=round(p.amount,2)
 LEFT JOIN public.lts_workbook_identity_evidence_v232 e ON e.user_id=u AND e.source_table=p.source_table AND e.source_ref=p.source_ref),'[]'::jsonb),
  'components','[]'::jsonb
 ) INTO result;
 base:=result;
 WITH items AS MATERIALIZED(SELECT e.r,e.ord FROM jsonb_array_elements(base->'rows') WITH ORDINALITY e(r,ord)),
 summary AS MATERIALIZED(
 SELECT c.parent_key,count(*) n,count(*) FILTER(WHERE c.amount<>0) nonzero,sum(c.amount) amount
 FROM public.lts_card_history_item_v346 c JOIN items i ON i.r->>'key'=c.parent_key
 WHERE c.user_id=u GROUP BY c.parent_key
 )
 SELECT coalesce(jsonb_agg(i.r || CASE WHEN i.r->>'coverage_mode' IN
 ('card_category_allocated_history','card_category_allocated_workbook_v176','card_invoice_aggregate_fallback')
 THEN jsonb_build_object('composition',jsonb_build_object(
 'status',public.lts_card_history_status_v346(p.signature=public.lts_card_history_signature_v346(i.r),p.parent_key IS NOT NULL,(i.r->>'amount')::numeric,s.amount,s.n),
 'count',coalesce(s.n,0),'nonzero_count',coalesce(s.nonzero,0))) ELSE '{}'::jsonb END ORDER BY i.ord),'[]'::jsonb)
 INTO result_rows FROM items i LEFT JOIN public.lts_card_history_parent_v346 p ON p.user_id=u AND p.parent_key=i.r->>'key'
 LEFT JOIN summary s ON s.parent_key=i.r->>'key';
 RETURN public.lts_card_read_finish_v269(u,rev,(base-'rows')||jsonb_build_object('rows',result_rows,'version','expense-detail-v353'));
END $function$
;
REVOKE ALL ON FUNCTION public.lts_browser_expense_detail_v353(date,date,jsonb,integer,integer,text)FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_expense_detail_v353(date,date,jsonb,integer,integer,text)TO authenticated,service_role;
