-- Set authorized owner's request.jwt.claims before running. Tests roll back.
BEGIN;
SET LOCAL timezone='America/Sao_Paulo';
SET LOCAL statement_timeout='120s';
DO $qa$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); report jsonb; detail jsonb;
 expected numeric; detail_ms numeric; started timestamptz; r record; result jsonb;
BEGIN
 IF EXISTS(
  (SELECT row_key,event_date,transaction_date,competence_month,amount,category,raw_category,raw_reference
    FROM public.lts_expense_rows_v230_baseline(u,'2013-10-10','2026-09-30')
   EXCEPT ALL
   SELECT row_key,event_date,transaction_date,competence_month,amount,category,raw_category,raw_reference
    FROM public.lts_v229_expense_rows(u,'2013-10-10','2026-09-30'))
  UNION ALL
  (SELECT row_key,event_date,transaction_date,competence_month,amount,category,raw_category,raw_reference
    FROM public.lts_v229_expense_rows(u,'2013-10-10','2026-09-30')
   EXCEPT ALL
   SELECT row_key,event_date,transaction_date,competence_month,amount,category,raw_category,raw_reference
    FROM public.lts_expense_rows_v230_baseline(u,'2013-10-10','2026-09-30'))
 ) THEN RAISE EXCEPTION 'Original financial rows changed'; END IF;
 report:=public.lts_browser_expenses_v229('2013-10-10','2026-09-30');
 started:=clock_timestamp();
 detail:=public.lts_browser_expense_detail_v229('2013-10-10','2026-09-30',NULL,NULL,0,10000,NULL);
 detail_ms:=1000*extract(epoch from clock_timestamp()-started);
 IF detail->>'next_offset' IS NOT NULL OR (detail->>'row_count')::int<>jsonb_array_length(detail->'rows')
 OR (SELECT count(distinct x->>'key') FROM jsonb_array_elements(detail->'rows')x)<>jsonb_array_length(detail->'rows')
 OR abs((SELECT sum((x->>'amount')::numeric) FROM jsonb_array_elements(detail->'rows')x)-(report#>>'{summary,selected_total}')::numeric)>.005
 THEN RAISE EXCEPTION 'Full details differ from headline'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(detail->'rows')x WHERE x->>'category'='Larissa — despesas')
 THEN RAISE EXCEPTION 'Split Larissa group remains'; END IF;
 FOR r IN SELECT value AS g FROM jsonb_array_elements(report->'management_groups') LOOP
  SELECT round(sum((x->>'amount')::numeric),2) INTO expected FROM jsonb_array_elements(detail->'rows')x WHERE x->>'category'=r.g->>'name';
  IF expected IS DISTINCT FROM (r.g->>'total')::numeric THEN RAISE EXCEPTION 'Group total differs: %',r.g->>'name'; END IF;
 END LOOP;
 IF (SELECT count(*) FROM jsonb_array_elements(detail->'rows')x WHERE x->'source_identity'<>'null'::jsonb)<>368
 THEN RAISE EXCEPTION 'Verified workbook references missing'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(detail->'rows')x WHERE x->>'coverage_mode'='card_invoice_aggregate_fallback' AND (x->>'can_classify'='true' OR x->>'document_status'<>'composition_missing'))
 THEN RAISE EXCEPTION 'Invoice payment masquerades as classifiable purchase'; END IF;
 result:=jsonb_build_object('pass',true,'source_financial_rows_unchanged',true,'original_categories_verified',368,'rows',detail->'row_count','total',detail->'total','groups',jsonb_array_length(report->'management_groups'),'detail_ms',detail_ms,'pending_historical',(SELECT count(*) FROM jsonb_array_elements(detail->'rows')x WHERE x->>'status'='pending' AND x->>'event_date'<'2026-01-01'),'coverage',report->'coverage_disclosure');
 PERFORM set_config('lts.v232.qa.detail',result::text,true);
END $qa$;
SELECT current_setting('lts.v232.qa.detail')::jsonb result;
ROLLBACK;
