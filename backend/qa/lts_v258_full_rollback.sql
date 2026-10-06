BEGIN;SET LOCAL TimeZone='America/Sao_Paulo';SET LOCAL jit=off;SET LOCAL statement_timeout='90s';
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
CREATE TEMP TABLE full_baseline_v258(kind text,lo date,hi date,j jsonb,ms numeric) ON COMMIT DROP;
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;
DO $baseline$ DECLARE r record;t timestamptz;j jsonb;BEGIN
 FOR r IN SELECT * FROM (VALUES(date '2026-01-01',current_date),(date '2019-01-01',date '2020-12-31'),(date '2026-07-01',date '2026-08-31'))v(lo,hi) LOOP
  t:=clock_timestamp();j:=public.lts_browser_expenses_v229_engine_v251(r.lo,r.hi);
  INSERT INTO full_baseline_v258 VALUES('expenses',r.lo,r.hi,j,extract(epoch FROM clock_timestamp()-t)*1000);
 END LOOP;
 t:=clock_timestamp();j:=public.lts_browser_flow_v242('2026-01-01','2027-12-31');
 INSERT INTO full_baseline_v258 VALUES('flow','2026-01-01','2027-12-31',j,extract(epoch FROM clock_timestamp()-t)*1000);
 t:=clock_timestamp();j:=public.lts_browser_wealth_detail_v242();
 INSERT INTO full_baseline_v258 VALUES('wealth',current_date,current_date,j#-'{current_liquidity,computed_at}',extract(epoch FROM clock_timestamp()-t)*1000);
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
CREATE OR REPLACE FUNCTION public.lts_bank_known_classification_v231(p_user_id uuid, p_staging_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 WITH target AS MATERIALIZED (SELECT s.*,public.lts_bank_merchant_key_v231(s.description_raw) AS merchant_key,public.lts_v178_norm(s.description_raw) AS normalized_description FROM public.lts_open_finance_staging s WHERE s.user_id=p_user_id AND s.id=p_staging_id),
 candidates AS (
  SELECT d.category_label category,d.beneficiary person,0 priority,'user_decision' basis
  FROM public.lts_v178_review_decision d WHERE d.user_id=p_user_id AND d.source_table='lts_open_finance_staging'
   AND d.source_ref=p_staging_id::text AND d.category_label IS NOT NULL
  UNION ALL
  SELECT r.category,r.center_cost,CASE WHEN r.confidence='user_confirmed' THEN 1 ELSE 2 END,'confirmed_rule'
  FROM public.lts_semantic_rule r CROSS JOIN target t WHERE r.user_id=p_user_id AND r.active
   AND r.confidence IN ('user_confirmed','high','alta','system_high')
   AND ((r.match_type IN ('exact','prefix') AND public.lts_bank_merchant_key_v231(r.match_value)=t.merchant_key)
    OR (r.match_type='prefix' AND starts_with(t.normalized_description,public.lts_v178_norm(r.match_value))))
  UNION ALL
  SELECT r.category,r.center_cost,3,'known_employer_payroll' FROM public.lts_semantic_rule r CROSS JOIN target t
  WHERE r.user_id=p_user_id AND r.active AND r.category='Salário'
   AND t.signed_amount>0 AND t.normalized_payload->>'operation_type'='FOLHA_PAGAMENTO'
   AND nullif(r.counterparty,'') IS NOT NULL AND length(public.lts_bank_merchant_key_v231(r.counterparty))>=4
   AND strpos(t.merchant_key,public.lts_bank_merchant_key_v231(r.counterparty))>0
 UNION ALL
 SELECT 'Rendimentos financeiros',null,4,'explicit_bank_yield' FROM target t
 WHERE t.signed_amount>0 AND t.normalized_description ~ '^rendimentos (remuner basica poup|juros poup)'
 ), ranked AS (SELECT *,min(priority) OVER() best FROM candidates
  WHERE public.lts_v178_norm(category) NOT IN ('','a classificar','nao identificado','sem categoria'))
 SELECT CASE WHEN count(DISTINCT category)=1 THEN jsonb_build_object('category',min(category),
  'beneficiary',CASE WHEN count(DISTINCT person)=1 THEN min(person) END,'basis',min(basis)) ELSE '{}'::jsonb END
 FROM ranked WHERE priority=best
$function$
;
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;
DO $candidate$ DECLARE r record;t timestamptz;j jsonb;receipts jsonb:='[]';elapsed numeric;BEGIN
 FOR r IN SELECT * FROM full_baseline_v258 ORDER BY kind,lo LOOP
  t:=clock_timestamp();
  CASE r.kind
  WHEN 'expenses' THEN j:=public.lts_browser_expenses_v229_engine_v251(r.lo,r.hi);
  WHEN 'flow' THEN j:=public.lts_browser_flow_v242(r.lo,r.hi);
  WHEN 'wealth' THEN j:=public.lts_browser_wealth_detail_v242();j:=j#-'{current_liquidity,computed_at}';
  END CASE;
  elapsed:=extract(epoch FROM clock_timestamp()-t)*1000;
  IF j::text IS DISTINCT FROM r.j::text THEN RAISE EXCEPTION 'V258_FULL_OUTPUT_CHANGED:%:%',r.kind,r.lo;END IF;
  receipts:=receipts||jsonb_build_array(jsonb_build_object('kind',r.kind,'from',r.lo,'to',r.hi,'baseline_ms',r.ms,'candidate_ms',elapsed,'digest',md5(j::text),'same_json_and_text',true,'normalization',CASE WHEN r.kind='wealth' THEN 'only current_liquidity.computed_at' ELSE 'none' END));
 END LOOP;PERFORM set_config('lts.v258_full',receipts::text,true);
 END $candidate$;
SELECT current_setting('lts.v258_full')::jsonb receipts;
ROLLBACK;
