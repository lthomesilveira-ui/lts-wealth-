-- Service-side batch. The caller supplies owner/proofs through transaction-local
-- lts.v348_owner and lts.v348_proofs. This reuses established signed overrides;
-- The manifest is prepared by reading both physical workbooks, without macros or
-- recalculation. It does not alter raw imports, cash, invoice data or classifications.
DO $apply$
DECLARE
 owner_id uuid:=current_setting('lts.v348_owner')::uuid;
 supplied jsonb:=current_setting('lts.v348_proofs')::jsonb;
 before_rows jsonb;after_rows jsonb;before_sources text;after_sources text;
 before_cache jsonb;after_cache jsonb;inserted integer;changed integer;
 n integer;before_total numeric;after_total numeric;expected_delta numeric;
BEGIN
 IF owner_id IS NULL OR jsonb_typeof(supplied)<>'array'OR jsonb_array_length(supplied)=0
 THEN RAISE EXCEPTION 'V348_INVALID_MANIFEST';END IF;
 n:=jsonb_array_length(supplied);
 IF (SELECT count(DISTINCT x->>'source_ref')FROM jsonb_array_elements(supplied)x)<>n
 THEN RAISE EXCEPTION 'V348_REPEATED_SOURCE';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_to_recordset(supplied)x(source_ref text,documented_signed_amount numeric,imported_amount numeric,workbook_row integer)
 WHERE x.documented_signed_amount IS NULL OR x.documented_signed_amount>=0 OR x.imported_amount IS NULL OR x.imported_amount<>-x.documented_signed_amount OR x.workbook_row IS NULL OR x.workbook_row<=0)
 THEN RAISE EXCEPTION 'V348_INVALID_SIGN_OR_LOCATOR';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_to_recordset(supplied)x(source_ref text)JOIN public.lts_expense_documentary_amount_override o ON o.user_id=owner_id AND o.source_table='evento_base'AND o.source_ref=x.source_ref)
 THEN RAISE EXCEPTION 'V348_EXISTING_OVERRIDE_REQUIRES_REVIEW';END IF;

 IF (SELECT count(*) FROM jsonb_array_elements(supplied)x
 JOIN public.evento_base b ON b.usuario_id=owner_id AND b.idx::text=x->>'source_ref'
 WHERE x->>'source_table'='evento_base' AND x->'raw_payload'=b.dados
 AND b.dados->>'dia'=x->>'event_date' AND b.dados->>'desc'=x->>'description'
 AND b.dados->>'efeito'='saida' AND jsonb_typeof(b.dados->'valor')='number'
 AND round((b.dados->>'valor')::numeric,2)=(x->>'imported_amount')::numeric
 AND (x->>'event_date')::date BETWEEN date '2013-10-10' AND date '2026-07-08'
 AND x->'primary'->>'file'='Controle_Financeiro_v16.xlsm'
 AND x->'primary'->>'sha256'='57a7efb384f410d02f698de1bcefc6190112edcf68a41cb2f79b49fc8a102c1e'
 AND x->'secondary'->>'file'='Controle_Financeiro_Fase1_Compactado.xlsx'
 AND x->'secondary'->>'sha256'='36e26f4c168483680bfbb723934fb09165c5884b03de052cc07b39ded00ab086'
 AND (x->'primary')-ARRAY['file','sha256']=(x->'secondary')-ARRAY['file','sha256']
 AND x->'primary'->>'sheet'='Pagamentos e Recebimentos'
 AND x->'primary'->>'row'=x->>'workbook_row'
 AND x->'primary'->>'date'=x->>'event_date'
 AND x->'primary'->>'description'=x->>'description'
 AND x->'primary'->>'category'=x->>'source_category'
 AND round((x->'primary'->>'signed_amount')::numeric,2)=(x->>'documented_signed_amount')::numeric
 AND NOT EXISTS(SELECT 1 FROM public.lts_v178_review_decision d WHERE d.user_id=owner_id AND d.source_table='evento_base' AND d.source_ref=x->>'source_ref')
 )<>n THEN RAISE EXCEPTION 'V348_SOURCE_OR_DUAL_WORKBOOK_PROOF_CHANGED';END IF;
 IF (SELECT count(DISTINCT x->>'workbook_row')FROM jsonb_array_elements(supplied)x)<>n
 OR(SELECT count(DISTINCT x->>'row_key')FROM jsonb_array_elements(supplied)x)<>n
 THEN RAISE EXCEPTION 'V348_REPEATED_ORIGIN';END IF;
 SELECT md5(jsonb_agg(jsonb_build_array(idx,dados)ORDER BY idx)::text)INTO before_sources FROM public.evento_base WHERE usuario_id=owner_id;
 SELECT jsonb_agg(to_jsonb(r)ORDER BY row_key),sum(amount)INTO before_rows,before_total FROM public.lts_v229_expense_rows(owner_id,date '2013-10-10',current_date)r;
 SELECT jsonb_agg(to_jsonb(c)ORDER BY source_table,source_ref,event_date)INTO before_cache FROM public.lts_expense_effective_read_cache c WHERE user_id=owner_id;
 IF (SELECT count(*)FROM jsonb_to_recordset(supplied)x(source_ref text,event_date date,imported_amount numeric,row_key text)
 JOIN jsonb_array_elements(before_rows)r ON r->>'key'=x.row_key OR r->>'row_key'=x.row_key
 WHERE r->>'source_table'='evento_base'AND r->>'source_ref'=x.source_ref AND r->>'event_date'=x.event_date::text AND(r->>'amount')::numeric=x.imported_amount AND r->>'coverage_mode'='direct_cash')<>n
 THEN RAISE EXCEPTION 'V348_EFFECTIVE_MEMBERSHIP_CHANGED';END IF;
 INSERT INTO public.lts_expense_documentary_amount_override(user_id,source_table,source_ref,event_date,description_raw,imported_amount,documented_signed_amount,source_document,source_sheet,source_locator,evidence_note,status)
 SELECT owner_id,'evento_base',x.source_ref,x.event_date,x.description,x.imported_amount,x.documented_signed_amount,
 'Controle_Financeiro_v16.xlsm','Pagamentos e Recebimentos','Pagamentos e Recebimentos · linha '||x.workbook_row,
 jsonb_build_object('schema','documented-sign-v347','batch','workbook-source-v348','workbook_evidence',jsonb_build_array(x.primary_proof,x.secondary_proof),'basis','negative original expense is compensation; preserve existing cash and classification')::text,'documented'
 FROM jsonb_to_recordset((SELECT jsonb_agg(x||jsonb_build_object('primary_proof',x->'primary','secondary_proof',x->'secondary'))FROM jsonb_array_elements(supplied)x))x(source_ref text,event_date date,description text,imported_amount numeric,documented_signed_amount numeric,workbook_row integer,primary_proof jsonb,secondary_proof jsonb);
 GET DIAGNOSTICS inserted=ROW_COUNT;
 UPDATE public.lts_expense_effective_read_cache c SET amount=x.documented_signed_amount,coverage_mode='documentary_amount_override'
 FROM jsonb_to_recordset(supplied)x(source_ref text,event_date date,imported_amount numeric,documented_signed_amount numeric)
 WHERE c.user_id=owner_id AND c.source_table='evento_base'AND c.source_ref=x.source_ref AND c.event_date=x.event_date AND c.amount=x.imported_amount AND c.coverage_mode='direct_cash';
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF inserted<>n OR changed<>n THEN RAISE EXCEPTION 'V348_NARROW_UPDATE_COUNT';END IF;
 SELECT jsonb_agg(to_jsonb(r)ORDER BY row_key),sum(amount)INTO after_rows,after_total FROM public.lts_v229_expense_rows(owner_id,date '2013-10-10',current_date)r;
 SELECT jsonb_agg(to_jsonb(c)ORDER BY source_table,source_ref,event_date)INTO after_cache FROM public.lts_expense_effective_read_cache c WHERE user_id=owner_id;
 IF jsonb_array_length(after_rows)<>jsonb_array_length(before_rows) THEN RAISE EXCEPTION 'V348_CHANGED_EXPENSE_COUNT';END IF;
 IF EXISTS((SELECT r-ARRAY['amount','coverage_mode']FROM jsonb_array_elements(before_rows)r EXCEPT ALL SELECT r-ARRAY['amount','coverage_mode']FROM jsonb_array_elements(after_rows)r)
 UNION ALL(SELECT r-ARRAY['amount','coverage_mode']FROM jsonb_array_elements(after_rows)r EXCEPT ALL SELECT r-ARRAY['amount','coverage_mode']FROM jsonb_array_elements(before_rows)r))
 THEN RAISE EXCEPTION 'V348_UNRELATED_EXPENSE_ATTRIBUTES_CHANGED';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(after_rows)a JOIN jsonb_array_elements(before_rows)b ON a->>'row_key'=b->>'row_key'
 WHERE a IS DISTINCT FROM b AND NOT EXISTS(SELECT 1 FROM jsonb_to_recordset(supplied)x(row_key text,documented_signed_amount numeric)
 WHERE x.row_key=a->>'row_key'AND(a->>'amount')::numeric=x.documented_signed_amount AND a->>'coverage_mode'='documentary_amount_override'))
 THEN RAISE EXCEPTION 'V348_UNPROVED_CHANGE';END IF;
 IF EXISTS((SELECT r-ARRAY['amount','coverage_mode']FROM jsonb_array_elements(before_cache)r EXCEPT ALL SELECT r-ARRAY['amount','coverage_mode']FROM jsonb_array_elements(after_cache)r)
 UNION ALL(SELECT r-ARRAY['amount','coverage_mode']FROM jsonb_array_elements(after_cache)r EXCEPT ALL SELECT r-ARRAY['amount','coverage_mode']FROM jsonb_array_elements(before_cache)r))
 THEN RAISE EXCEPTION 'V348_UNRELATED_CACHE_ATTRIBUTES_CHANGED';END IF;
 SELECT sum(documented_signed_amount-imported_amount)INTO expected_delta FROM jsonb_to_recordset(supplied)x(documented_signed_amount numeric,imported_amount numeric);
 IF round(after_total-before_total,2)<>round(expected_delta,2)THEN RAISE EXCEPTION 'V348_TOTAL_DELTA_CHANGED';END IF;
 SELECT md5(jsonb_agg(jsonb_build_array(idx,dados)ORDER BY idx)::text)INTO after_sources FROM public.evento_base WHERE usuario_id=owner_id;
 IF before_sources IS DISTINCT FROM after_sources THEN RAISE EXCEPTION 'V348_RAW_IMPORT_CHANGED';END IF;
 PERFORM set_config('lts.v348_receipt',jsonb_build_object('pass',true,'count',n,'inserted_overrides',inserted,'updated_cache_rows',changed,'before_total',round(before_total,2),'after_total',round(after_total,2),'delta',round(expected_delta,2),'financial_count_preserved',jsonb_array_length(after_rows),'raw_import_unchanged',true,'classification_and_dates_unchanged',true)::text,true);
END $apply$;
