-- Run with the authorized owner, never persist the test classifications.
BEGIN;
SET LOCAL statement_timeout='120s';
SET LOCAL timezone='America/Sao_Paulo';
DO $qa$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); chosen record; after_row record; result jsonb; before_amount numeric; previous_rows text; after_rows text;
 BEGIN
 SELECT * INTO chosen FROM public.lts_v229_expense_rows(u,'2014-01-01','2014-12-31') WHERE source_table='historico_analitico' AND category='Família' ORDER BY event_date LIMIT 1;
 IF chosen.row_key IS NULL THEN RAISE EXCEPTION 'No original-source family fixture'; END IF;
 SELECT md5(string_agg(to_jsonb(x)::text,'|' ORDER BY row_key)) INTO previous_rows FROM public.lts_v229_expense_rows(u,chosen.event_date,chosen.event_date)x WHERE x.source_ref<>chosen.source_ref;
 result:=public.lts_browser_expense_classification_v232(chosen.event_date,chosen.event_date,chosen.row_key,'Presentes',NULL,NULL);
 SELECT * INTO after_row FROM public.lts_v229_expense_rows(u,chosen.event_date,chosen.event_date) WHERE source_table=chosen.source_table AND source_ref=chosen.source_ref;
 IF after_row.category<>'Presentes' OR after_row.management_group<>'Presentes' OR after_row.amount<>chosen.amount OR after_row.raw_category<>chosen.raw_category OR after_row.description<>chosen.description
 THEN RAISE EXCEPTION 'Classification not propagated or original evidence altered'; END IF;
 SELECT md5(string_agg(to_jsonb(x)::text,'|' ORDER BY row_key)) INTO after_rows FROM public.lts_v229_expense_rows(u,chosen.event_date,chosen.event_date)x WHERE x.source_ref<>chosen.source_ref;
 IF previous_rows IS DISTINCT FROM after_rows THEN RAISE EXCEPTION 'Unrelated records changed'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.lts_access_audit WHERE user_id=u AND action='expense_detail_classification_v232' AND meta->>'source_ref'=chosen.source_ref)
 THEN RAISE EXCEPTION 'Audit missing'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.lts_v178_review_decision WHERE user_id=u AND source_table=chosen.source_table AND source_ref=chosen.source_ref AND category_label='Presentes')
 THEN RAISE EXCEPTION 'Decision not persisted'; END IF;
 PERFORM set_config('lts.v232.qa.classification',jsonb_build_object('pass',true,'source',chosen.source_table,'persisted',true,'group_changed',true,'original_evidence_preserved',true,'unrelated_rows_unchanged',true,'test_rolled_back',true)::text,true);
 END $qa$;
SELECT current_setting('lts.v232.qa.classification')::jsonb result;
ROLLBACK;
