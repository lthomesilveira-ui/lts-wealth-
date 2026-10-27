-- Service-only documentary batch; a negative salary adjustment is not spending.
-- Preserve the complete raw import AND physical effective-expense cache.
-- The canonical reader applies the already validated documentary rule.
DO $apply$
DECLARE
 owner_id uuid:=current_setting('lts.v354_owner')::uuid;
 p jsonb:=current_setting('lts.v354_income_proof')::jsonb;
 before_rows jsonb;after_rows jsonb;before_cache jsonb;after_cache jsonb;
 before_proofs jsonb;after_proofs jsonb;before_raw text;after_raw text;
 n integer;v numeric;new_id uuid;
BEGIN
 IF owner_id IS NULL OR p->>'source_table' IS DISTINCT FROM 'historico_analitico'
 OR p->>'source_ref' IS NULL OR p->>'row_key' IS NULL
 THEN RAISE EXCEPTION 'V354_INCOME_INVALID_PROOF';END IF;
 v:=(p->>'imported_amount')::numeric;
 IF v IS NULL OR v<=0 OR(p->>'documented_signed_amount')::numeric IS DISTINCT FROM -v
 THEN RAISE EXCEPTION 'V354_INCOME_INVALID_SIGN';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_reconciliation_evidence WHERE user_id=owner_id AND source_ref='historico_analitico:'||(p->>'source_ref') AND evidence_type='historical_workbook_nonspend_v343')
 THEN RAISE EXCEPTION 'V354_INCOME_EXISTING_EVIDENCE';END IF;
 IF (SELECT count(*)FROM public.historico_analitico h WHERE h.usuario_id=owner_id AND h.idx::text=p->>'source_ref'
 AND h.dados=p->'raw_payload' AND h.dados->>'e'='saida' AND h.dados->>'m'='sinal negativo'
 AND h.dados->>'c'='Salário' AND h.dados->>'x'='Salário' AND h.dados->>'d'=p->>'event_date'
 AND h.dados->'v'=to_jsonb(v))<>1
 THEN RAISE EXCEPTION 'V354_INCOME_SOURCE_CHANGED';END IF;
 SELECT md5(jsonb_agg(to_jsonb(h)ORDER BY idx)::text)INTO before_raw FROM public.historico_analitico h WHERE usuario_id=owner_id;
 SELECT jsonb_agg(to_jsonb(r)ORDER BY row_key)INTO before_rows FROM public.lts_v229_expense_rows(owner_id,date '2013-10-10',current_date)r;
 SELECT jsonb_agg(to_jsonb(c)ORDER BY source_table,source_ref,event_date)INTO before_cache FROM public.lts_expense_effective_read_cache c WHERE user_id=owner_id;
 SELECT coalesce(jsonb_agg(to_jsonb(e)ORDER BY source_ref),'[]')INTO before_proofs FROM public.lts_workbook_nonspend_source_v343 e WHERE user_id=owner_id;
 IF (SELECT count(*)FROM jsonb_array_elements(before_rows)r WHERE r->>'row_key'=p->>'row_key' AND(r->>'amount')::numeric=v)<>1
 THEN RAISE EXCEPTION 'V354_INCOME_MEMBERSHIP_CHANGED';END IF;
 INSERT INTO public.lts_reconciliation_evidence(user_id,evidence_date,account,amount,description,evidence_type,source_ref,status,metadata)
 VALUES(owner_id,(p->>'event_date')::date,'Itaú',v,'Salário','historical_workbook_nonspend_v343','historico_analitico:'||(p->>'source_ref'),'documented',p->'metadata')RETURNING id INTO new_id;
 IF (SELECT count(*)FROM public.lts_workbook_nonspend_source_v343 WHERE user_id=owner_id AND source_ref=p->>'source_ref' AND evidence_id=new_id AND nature='receipt_adjustment')<>1
 THEN RAISE EXCEPTION 'V354_INCOME_DOCUMENTARY_GUARD_REJECTED';END IF;
 IF (SELECT count(*)FROM public.lts_expense_realized WHERE user_id=owner_id AND source_table='historico_analitico' AND source_ref=p->>'source_ref' AND exclude_from_spend)<>1
 THEN RAISE EXCEPTION 'V354_INCOME_BUILDER_NOT_EXCLUDED';END IF;
 SELECT jsonb_agg(to_jsonb(r)ORDER BY row_key)INTO after_rows FROM public.lts_v229_expense_rows(owner_id,date '2013-10-10',current_date)r;
 SELECT jsonb_agg(to_jsonb(c)ORDER BY source_table,source_ref,event_date)INTO after_cache FROM public.lts_expense_effective_read_cache c WHERE user_id=owner_id;
 IF jsonb_array_length(after_rows)<>jsonb_array_length(before_rows)-1
 OR(SELECT sum((r->>'amount')::numeric)FROM jsonb_array_elements(before_rows)r)-(SELECT sum((r->>'amount')::numeric)FROM jsonb_array_elements(after_rows)r)<>v
 OR EXISTS((SELECT r FROM jsonb_array_elements(before_rows)r WHERE r->>'row_key'<>p->>'row_key' EXCEPT ALL SELECT r FROM jsonb_array_elements(after_rows)r)
 UNION ALL(SELECT r FROM jsonb_array_elements(after_rows)r EXCEPT ALL SELECT r FROM jsonb_array_elements(before_rows)r WHERE r->>'row_key'<>p->>'row_key'))
 THEN RAISE EXCEPTION 'V354_INCOME_UNRELATED_FINANCIAL_CHANGE';END IF;
 IF before_cache IS DISTINCT FROM after_cache THEN RAISE EXCEPTION 'V354_INCOME_PHYSICAL_CACHE_CHANGED';END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(e)ORDER BY source_ref),'[]')INTO after_proofs FROM public.lts_workbook_nonspend_source_v343 e WHERE user_id=owner_id AND evidence_id<>new_id;
 IF before_proofs IS DISTINCT FROM after_proofs THEN RAISE EXCEPTION 'V354_INCOME_EXISTING_PROOFS_CHANGED';END IF;
 SELECT md5(jsonb_agg(to_jsonb(h)ORDER BY idx)::text)INTO after_raw FROM public.historico_analitico h WHERE usuario_id=owner_id;
 IF before_raw IS DISTINCT FROM after_raw THEN RAISE EXCEPTION 'V354_INCOME_RAW_IMPORT_CHANGED';END IF;
 PERFORM set_config('lts.v354_income_receipt',jsonb_build_object('pass',true,'excluded_from_spending',1,'delta',-v,'financial_count',jsonb_array_length(after_rows),'raw_import_unchanged',true,'other_rows_unchanged',true,'existing_documentary_proofs_unchanged',true,'physical_cache_preserved',true)::text,true);
END $apply$;
