-- Invented sources only; exercise the actual batch writer, not a copied CASE.
CREATE TABLE public.qa_clock_v427(id text PRIMARY KEY,first_record jsonb,next_record jsonb);
WITH cases(id,first_value,next_value) AS (VALUES
 ('equal-string','"2026-01-01T00:00:00Z"'::jsonb,'"2026-01-01T00:00:00Z"'::jsonb),
 ('changed-string','"2026-01-01T00:00:00Z"'::jsonb,'"2026-01-02T00:00:00Z"'::jsonb),
 ('absent',NULL::jsonb,NULL::jsonb),
 ('equal-json-null','null'::jsonb,'null'::jsonb),
 ('removed-string','"2026-01-01T00:00:00Z"'::jsonb,NULL::jsonb),
 ('added-string',NULL::jsonb,'"2026-01-01T00:00:00Z"'::jsonb),
 ('removed-json-null','null'::jsonb,NULL::jsonb),
 ('string-to-json-null','"2026-01-01T00:00:00Z"'::jsonb,'null'::jsonb),
 ('added-json-null',NULL::jsonb,'null'::jsonb),
 ('json-null-to-string','null'::jsonb,'"2026-01-01T00:00:00Z"'::jsonb)
), records AS (SELECT *,public.qa_record_v403('transaction','clock-'||id) r FROM cases)
INSERT INTO public.qa_clock_v427
SELECT id,
 CASE WHEN first_value IS NULL THEN r#-'{normalized_payload,source_sync_at}'
  ELSE jsonb_set(r,'{normalized_payload,source_sync_at}',first_value) END,
 CASE WHEN next_value IS NULL THEN r#-'{normalized_payload,source_sync_at}'
  ELSE jsonb_set(r,'{normalized_payload,source_sync_at}',next_value) END FROM records;
SELECT public.qa_run_v403('bbbbbbbb-bbbb-4bbb-8bbb-000000000001');
SELECT public.qa_batch_v403('bbbbbbbb-bbbb-4bbb-8bbb-000000000001',
 (SELECT jsonb_agg(first_record ORDER BY id) FROM public.qa_clock_v427));
SELECT public.qa_finish_v403('bbbbbbbb-bbbb-4bbb-8bbb-000000000001',10);
UPDATE public.lts_open_finance_staging SET last_seen_at='2000-01-01',updated_at='2000-01-01'
 WHERE provider_record_id LIKE 'synthetic-item:clock-%';
SELECT public.qa_run_v403('bbbbbbbb-bbbb-4bbb-8bbb-000000000002');
SELECT public.qa_batch_v403('bbbbbbbb-bbbb-4bbb-8bbb-000000000002',
 (SELECT jsonb_agg(next_record ORDER BY id) FROM public.qa_clock_v427));
DO $verify$
DECLARE x record;s public.lts_open_finance_staging;expected jsonb;
BEGIN
 FOR x IN SELECT * FROM public.qa_clock_v427 LOOP
  SELECT * INTO STRICT s FROM public.lts_open_finance_staging
   WHERE provider_record_id=x.next_record->>'provider_record_id';
  expected:=(x.next_record->'normalized_payload')||
   jsonb_build_object('reconciliation',x.next_record->'reconciliation');
  PERFORM public.qa_assert_v403('V427 complete payload and provenance: '||x.id,
   s.normalized_payload=expected AND s.raw_payload=x.first_record->'raw_payload'
   AND s.raw_hash=x.first_record->>'raw_hash' AND s.signed_amount=10
   AND s.sync_run_id='bbbbbbbb-bbbb-4bbb-8bbb-000000000002'
   AND s.last_seen_at>'2000-01-01' AND s.updated_at>'2000-01-01');
 END LOOP;
END $verify$;
SELECT public.qa_assert_v403('V427 clocks do not become source observations',
 NOT EXISTS(SELECT FROM public.lts_open_finance_observation
  WHERE sync_run_id='bbbbbbbb-bbbb-4bbb-8bbb-000000000002'));
SELECT public.qa_batch_v403('bbbbbbbb-bbbb-4bbb-8bbb-000000000002',
 (SELECT jsonb_agg(next_record ORDER BY id) FROM public.qa_clock_v427));
SELECT public.qa_finish_v403('bbbbbbbb-bbbb-4bbb-8bbb-000000000002',10);
SELECT public.qa_assert_v403('V427 exact replay keeps coverage without extra observations',
 (SELECT raw_count=10 AND metadata#>>'{ingestion_v403,observations_stored}'='0'
  FROM public.lts_open_finance_sync_run WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-000000000002'));
SELECT jsonb_build_object('passed',count(*),'cases',jsonb_agg(name ORDER BY name))
 FROM public.qa_results_v403;
