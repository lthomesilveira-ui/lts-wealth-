-- Run from the maintenance connection inside a transaction with authorized JWT
-- claims, then ROLLBACK. Direct source reads need the maintenance role.
-- Browser RPCs are also checked separately under the authenticated role.
-- Read-only parity checks; expected totals come from the canonical report.
DO $test$
DECLARE
 u uuid:=public.lts_browser_assert_user_v1(); first_page jsonb; page jsonb;
 offset_value integer:=0; cycle_rows bigint:=0; cycle_sum numeric:=0;
 expected_rows bigint; expected_sum numeric; sample record; detail jsonb;
BEGIN
 SELECT count(*),round(coalesce(sum(amount),0),2) INTO expected_rows,expected_sum
 FROM (SELECT signed_amount AS amount FROM public.lts_card_history_evidence_v235 WHERE user_id=u AND event_date BETWEEN '2013-10-10' AND current_date) signed_source;
 first_page:=public.lts_browser_card_history_inventory_v237('2013-10-10',current_date,0,50);
 IF (first_page#>>'{summary,record_count}')::bigint<>expected_rows
    OR (first_page#>>'{summary,total}')::numeric<>expected_sum THEN
  RAISE EXCEPTION 'inventory differs from canonical expenses';
 END IF;
 LOOP
  page:=public.lts_browser_card_history_inventory_v237('2013-10-10',current_date,offset_value,50);
  cycle_rows:=cycle_rows+jsonb_array_length(page->'cycles');
  cycle_sum:=cycle_sum+(SELECT coalesce(sum((x->>'amount')::numeric),0) FROM jsonb_array_elements(page->'cycles') x);
  IF page->'summary'<>first_page->'summary' THEN RAISE EXCEPTION 'pagination changed the summary'; END IF;
  EXIT WHEN page->>'next_offset' IS NULL;
  IF (page->>'next_offset')::integer<=offset_value THEN RAISE EXCEPTION 'pagination did not advance'; END IF;
  offset_value:=(page->>'next_offset')::integer;
 END LOOP;
 IF cycle_rows<>(first_page#>>'{summary,cycle_count}')::bigint OR cycle_sum<>expected_sum THEN
  RAISE EXCEPTION 'cycle pages do not match the complete summary';
 END IF;
 FOR sample IN
  SELECT DISTINCT ON (composition_status,signed_amount<0) *
  FROM public.lts_card_history_evidence_v235 WHERE user_id=u
  ORDER BY composition_status,signed_amount<0,event_date
 LOOP
  detail:=public.lts_browser_card_history_record_v237(sample.source_table,sample.source_ref,sample.event_date);
  IF (detail->>'cycle_total')::numeric<>(SELECT sum((x->>'amount')::numeric) FROM jsonb_array_elements(detail->'cycle_records') x) THEN
   RAISE EXCEPTION 'record ledger does not match cycle total';
  END IF;
  IF (detail->>'detail_rows')::integer<>jsonb_array_length(detail->'items') THEN RAISE EXCEPTION 'source lines truncated'; END IF;
  IF jsonb_array_length(detail->'items')>0 AND
   ((detail->>'detail_total')::numeric<>(SELECT sum((x->>'amount')::numeric) FROM jsonb_array_elements(detail->'items') x WHERE x->>'included_in_source_total' IS DISTINCT FROM 'false')
    OR (detail->>'detail_difference')::numeric<>(detail->>'detail_total')::numeric-(detail->>'cycle_total')::numeric) THEN
   RAISE EXCEPTION 'source difference is not explicit';
  END IF;
  IF detail->>'composition_status'='formula_reconciled' AND
   ((detail->>'raw_detail_total')::numeric<>(SELECT sum((x->>'amount')::numeric) FROM jsonb_array_elements(detail->'items') x)
    OR EXISTS(SELECT 1 FROM jsonb_array_elements(detail->'items') x WHERE jsonb_typeof(x->'included_in_source_total') IS DISTINCT FROM 'boolean')
    OR (SELECT count(*) FROM jsonb_array_elements(detail->'items') x WHERE x->>'included_in_source_total'='false')<>jsonb_array_length(detail->'excluded_rows')) THEN
   RAISE EXCEPTION 'raw workbook lines or formula exclusions are not explicit';
  END IF;
 END LOOP;
END $test$;
SELECT jsonb_build_object('pass',true,'check','canonical summary, complete pagination, signed ledger and source-line parity') result;
