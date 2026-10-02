CREATE OR REPLACE FUNCTION public.lts_browser_card_history_inventory_v237(p_from date, p_to date, p_offset integer DEFAULT 0, p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<'2013-10-10'::date OR p_to>current_date OR p_offset IS NULL OR p_offset<0 OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 500 THEN
  RAISE EXCEPTION 'invalid inventory range';
 END IF;
 WITH current_rows AS MATERIALIZED(SELECT * FROM public.lts_v229_expense_rows(u,p_from,p_to)), records AS MATERIALIZED (
  SELECT r.source_table,r.source_ref,r.event_date,r.competence_month,r.amount,
   coalesce(e.bank,'Banco a confirmar') bank,e.family,coalesce(e.card_name,r.account_source) card_name,
   CASE WHEN e.reference_month<b.detail_from AND e.composition_status='aggregate_only' THEN 'historical_total'
    WHEN e.composition_status='partial_source' AND formula.family IS NOT NULL THEN 'formula_reconciled'
    ELSE coalesce(e.composition_status,'audit_pending') END composition_status,
   e.signed_amount<0 AND e.signed_amount<>e.observed_amount sign_corrected,e.verified_at
  FROM current_rows r
  LEFT JOIN public.lts_card_history_evidence_v235 e ON e.user_id=u AND e.source_table=r.source_table AND e.source_ref=r.source_ref
   AND e.event_date=r.event_date AND e.reference_month=r.competence_month AND e.signed_amount=round(r.amount,2)
  LEFT JOIN public.lts_card_detail_boundary_v237 b ON b.user_id=u AND b.family=e.family
  LEFT JOIN public.lts_card_formula_resolution_v237 formula ON formula.user_id=u AND formula.family=e.family AND formula.reference_month=e.reference_month
  WHERE r.coverage_mode IN ('card_invoice_aggregate_fallback','card_workbook_signed_adjustment_v235')
  UNION ALL
  SELECT e.source_table,e.source_ref,e.event_date,e.reference_month,e.signed_amount,e.bank,e.family,e.card_name,
    'formula_reconciled',e.signed_amount<0 AND e.signed_amount<>e.observed_amount,e.verified_at
  FROM public.lts_card_history_evidence_v235 e
  JOIN public.lts_card_formula_resolution_v237 fr ON fr.user_id=u AND fr.family=e.family AND fr.reference_month=e.reference_month AND fr.invoice_amount=e.signed_amount
  JOIN public.lts_expense_effective_read_cache src ON src.user_id=u AND src.source_table=e.source_table AND src.source_ref=e.source_ref AND src.event_date=e.event_date AND round(src.amount,2)=e.signed_amount
  WHERE e.user_id=u AND e.event_date BETWEEN p_from AND p_to
    AND NOT EXISTS(SELECT 1 FROM current_rows rr WHERE rr.source_table=e.source_table AND rr.source_ref=e.source_ref)
    AND EXISTS(SELECT 1 FROM current_rows rr WHERE rr.source_table='lts_card_workbook_evidence_v226' AND rr.competence_month=fr.reference_month AND rr.source_ref LIKE fr.source_hash||':'||fr.source_sheet||':%' GROUP BY rr.competence_month HAVING count(DISTINCT rr.source_ref)=fr.expected_rows-jsonb_array_length(fr.excluded_rows) AND round(sum(rr.amount),2)=fr.invoice_amount)
 ), cycles AS MATERIALIZED (
  SELECT bank,family,card_name,competence_month reference_month,round(sum(amount),2) amount,count(*) record_count,
   round(coalesce(sum(amount) FILTER(WHERE amount>0),0),2) charges,
   round(coalesce(sum(amount) FILTER(WHERE amount<0),0),2) credits,
   (array_agg(source_table ORDER BY event_date,source_ref))[1] source_table,
   (array_agg(source_ref ORDER BY event_date,source_ref))[1] source_ref,
   min(event_date) event_date,
   CASE WHEN bool_or(composition_status='audit_pending') THEN 'audit_pending'
     WHEN bool_or(composition_status='partial_source') THEN 'partial_source'
     WHEN bool_or(composition_status='aggregate_only') THEN 'aggregate_only'
     WHEN bool_or(composition_status='formula_reconciled') THEN 'formula_reconciled' ELSE 'historical_total' END composition_status,
   max(verified_at) verified_at
  FROM records GROUP BY bank,family,card_name,competence_month
 ), page AS MATERIALIZED (SELECT * FROM cycles ORDER BY reference_month DESC,card_name,bank OFFSET p_offset LIMIT p_limit)
 SELECT jsonb_build_object('version','card-history-inventory-v237','from',p_from,'to',p_to,'offset',p_offset,
  'summary',jsonb_build_object('record_count',(SELECT count(*) FROM records),'cycle_count',(SELECT count(*) FROM cycles),
   'total',(SELECT round(coalesce(sum(amount),0),2) FROM records),
   'charges',(SELECT round(coalesce(sum(amount) FILTER(WHERE amount>0),0),2) FROM records),
   'credits',(SELECT round(coalesce(sum(amount) FILTER(WHERE amount<0),0),2) FROM records),
   'sign_corrections',(SELECT count(*) FROM records WHERE sign_corrected),
   'historical_total_cycles',(SELECT count(*) FROM cycles WHERE composition_status='historical_total'),
   'formula_reconciled_cycles',(SELECT count(*) FROM cycles WHERE composition_status='formula_reconciled'),
   'detail_boundaries',coalesce((SELECT jsonb_agg(jsonb_build_object('family',family,'detail_from',detail_from,'evidence',evidence) ORDER BY detail_from) FROM public.lts_card_detail_boundary_v237 WHERE user_id=u),'[]'),
   'aggregate_only_cycles',(SELECT count(*) FROM cycles WHERE composition_status='aggregate_only'),
   'partial_source_cycles',(SELECT count(*) FROM cycles WHERE composition_status='partial_source'),
   'audit_pending_cycles',(SELECT count(*) FROM cycles WHERE composition_status='audit_pending')),
  'next_offset',CASE WHEN p_offset+p_limit<(SELECT count(*) FROM cycles) THEN p_offset+p_limit END,
  'cycles',coalesce((SELECT jsonb_agg(to_jsonb(p) ORDER BY reference_month DESC,card_name,bank) FROM page p),'[]'::jsonb)
 ) INTO result;
 RETURN result;
END $function$
;
