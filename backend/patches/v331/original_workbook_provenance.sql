-- Keep original-workbook provenance after later restoration batches.
DO $lease$
DECLARE target regprocedure:='public.lts_card_source_rows_pre_v262(uuid)'::regprocedure;
 definition text;attributes jsonb;before_data jsonb;after_data jsonb;changed boolean:=false;n integer;
 needle text:=$needle$d.decision_basis like 'workbook_restore_v226%'$needle$;
 replacement text:=$replacement$(d.decision_basis like 'workbook_restore_v226%' OR d.decision_basis ~ '^workbook_restore_v[0-9]+:')$replacement$;
BEGIN
 SELECT pg_get_functiondef(target),to_jsonb(p)-'prosrc' INTO definition,attributes FROM pg_proc p WHERE p.oid=target;
 IF md5(definition) NOT IN('cbf6fed3b736e4d3fe6f90bec75ca161','d5e085fe7dbc8f6a2ad562feb290c1fb') THEN RAISE EXCEPTION 'Card source definition changed';END IF;
 SELECT jsonb_build_object(
 'sources',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.lts_open_finance_staging s),
 'events',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.financial_events s),
 'invoices',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.card_invoices s),
 'details',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY user_id,line_key)::text) FROM public.lts_card_purchase_detail s),
 'decisions',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY user_id,source_table,source_ref)::text) FROM public.lts_v178_review_decision s),
 'categories',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY user_id,category)::text) FROM public.lts_category_catalog s),
 'rules',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY user_id,id)::text) FROM public.lts_semantic_rule s),
 'documents',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.source_documents s)) INTO before_data;
 IF md5(definition)='cbf6fed3b736e4d3fe6f90bec75ca161' THEN
  IF (length(definition)-length(replace(definition,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'Original provenance branch changed';END IF;
  EXECUTE replace(definition,needle,replacement);changed:=true;
  -- The source wrapper caches by this existing revision, not by function body.
  UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
  GET DIAGNOSTICS n=ROW_COUNT;IF n<>1 THEN RAISE EXCEPTION 'Read cache revision unavailable';END IF;
 END IF;
 IF md5(pg_get_functiondef(target))<>'d5e085fe7dbc8f6a2ad562feb290c1fb' OR attributes IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target) THEN RAISE EXCEPTION 'Source function attributes changed';END IF;
 SELECT jsonb_build_object(
 'sources',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.lts_open_finance_staging s),
 'events',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.financial_events s),
 'invoices',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.card_invoices s),
 'details',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY user_id,line_key)::text) FROM public.lts_card_purchase_detail s),
 'decisions',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY user_id,source_table,source_ref)::text) FROM public.lts_v178_review_decision s),
 'categories',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY user_id,category)::text) FROM public.lts_category_catalog s),
 'rules',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY user_id,id)::text) FROM public.lts_semantic_rule s),
 'documents',(SELECT md5(jsonb_agg(to_jsonb(s) ORDER BY id)::text) FROM public.source_documents s)) INTO after_data;
 IF before_data IS DISTINCT FROM after_data THEN RAISE EXCEPTION 'Source or financial data changed';END IF;
END $lease$;
