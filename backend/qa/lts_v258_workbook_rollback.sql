BEGIN;SET LOCAL TimeZone='America/Sao_Paulo';SET LOCAL jit=off;SET LOCAL statement_timeout='90s';
CREATE TEMP TABLE workbook_baseline_v258(j jsonb,ms numeric) ON COMMIT DROP;
DO $baseline$ DECLARE t timestamptz:=clock_timestamp();j jsonb;u uuid:=public.lts_open_finance_pilot_owner_v1();BEGIN
 SELECT coalesce(jsonb_agg(to_jsonb(w) ORDER BY to_jsonb(w)::text),'[]') INTO j FROM public.lts_card_workbook_bank_rows_v1(u) w;
 INSERT INTO workbook_baseline_v258 VALUES(j,extract(epoch FROM clock_timestamp()-t)*1000);
END $baseline$;
CREATE OR REPLACE FUNCTION public.lts_card_workbook_bank_rows_v1(p_user_id uuid)
 RETURNS SETOF lts_card_workbook_evidence_v226
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
WITH candidates AS MATERIALIZED (
 SELECT w.*,w.evidence->'bank_invoice' b FROM public.lts_card_workbook_evidence_v226 w WHERE w.user_id=p_user_id
), valid AS MATERIALIZED (
 SELECT user_id,family,reference_month FROM candidates
 GROUP BY user_id,family,reference_month
 HAVING count(*)=min(expected_rows) AND min(expected_rows)=max(expected_rows)
 AND count(DISTINCT source_hash)=1 AND count(DISTINCT source_sheet)=1
 AND count(DISTINCT expected_invoice_amount)=1
 AND count(DISTINCT b->>'source_sha256')=1 AND count(DISTINCT b->>'source_library_file_id')=1
 AND count(DISTINCT b->>'source_line')=count(*)
 AND bool_and(coalesce(b->>'basis'='official_bank_statement_user_provided'
  AND length(b->>'source_sha256')=64 AND b->>'source_library_file_id' LIKE 'libfile_%'
  AND b->>'workbook_source_hash'=source_hash AND b->>'workbook_source_sheet'=source_sheet
  AND (b->>'workbook_source_row')::int=source_row AND (b->>'original_amount')::numeric=amount
  AND b->>'original_category'=category AND b->>'original_last4'=last4
  AND (b->>'reference_month')::date=reference_month AND (b->>'expected_rows')::int=expected_rows
  AND (b->>'invoice_amount')::numeric=expected_invoice_amount
  AND b->>'purchase_date' ~ '^\d{4}-\d{2}-\d{2}$' AND b->>'last4' ~ '^\d{4}$'
  AND (b->>'installment_number')::int BETWEEN 1 AND (b->>'installments')::int
  AND nullif(b->>'description','') IS NOT NULL,false))
 AND round(sum((b->>'amount')::numeric),2)=max(expected_invoice_amount)
), patched AS MATERIALIZED (
SELECT jsonb_populate_record(NULL::public.lts_card_workbook_evidence_v226,
 to_jsonb(w)||CASE WHEN v.user_id IS NOT NULL THEN jsonb_build_object(
 'amount',(w.evidence#>>'{bank_invoice,amount}')::numeric,
 'last4',w.evidence#>>'{bank_invoice,last4}',
 'evidence',w.evidence||jsonb_build_object('bank_precedence_applied',true))
 ELSE jsonb_build_object('evidence',w.evidence-'bank_precedence_applied') END) AS corrected_row
FROM public.lts_card_workbook_evidence_v226 w LEFT JOIN valid v USING(user_id,family,reference_month)
WHERE w.user_id=p_user_id
)
SELECT (p.corrected_row).* FROM patched p
$function$
;
DO $candidate$ DECLARE t timestamptz:=clock_timestamp();j jsonb;u uuid:=public.lts_open_finance_pilot_owner_v1();BEGIN
 SELECT coalesce(jsonb_agg(to_jsonb(w) ORDER BY to_jsonb(w)::text),'[]') INTO j FROM public.lts_card_workbook_bank_rows_v1(u) w;
 IF j::text IS DISTINCT FROM (SELECT b.j::text FROM workbook_baseline_v258 b) THEN RAISE EXCEPTION 'V258_WORKBOOK_FULL_OUTPUT_CHANGED';END IF;
 PERFORM set_config('lts.v258_workbook_result',jsonb_build_object('pass',true,'baseline_ms',(SELECT ms FROM workbook_baseline_v258),'candidate_ms',extract(epoch FROM clock_timestamp()-t)*1000,'digest',md5(j::text),'same_json_and_text',true,'rows',jsonb_array_length(j))::text,true);
END $candidate$;
SELECT current_setting('lts.v258_workbook_result')::jsonb receipt;
ROLLBACK;
