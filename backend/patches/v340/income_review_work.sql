-- Preserve the canonical full-income worker. Only the pending-review queue changes.
-- Reject a changed source definition rather than silently copying an obsolete worker.
DO $patch$
DECLARE
 source_oid regprocedure:='lts_income_private.rows_v296(uuid,date,date)'::regprocedure;
 queue_oid regprocedure:='lts_income_private.queue_v296(date,date,integer,integer,text)'::regprocedure;
 review_oid regprocedure;
 source_definition text;queue_definition text;review_definition text;old_queue_definition text;
 source_attributes jsonb;queue_attributes jsonb;worker_attributes jsonb;
 source_owner name;
 old_cte text:=$old$ ),identified AS MATERIALIZED($old$;
 new_cte text:=$new$ ),review_mapped AS MATERIALIZED(
  SELECT DISTINCT ON(source_table,source_ref,x->>'event_date',x->>'account') * FROM mapped
  ORDER BY source_table,source_ref,x->>'event_date',x->>'account',x::text
 ),identified AS MATERIALIZED($new$;
 old_input text:=E'  FROM mapped m\n ),unique_rows';
 new_input text:=$new$  FROM review_mapped m WHERE public.lts_v178_norm(m.category)
   IN('','a classificar','classificacao pendente','sem categoria','nao identificado','—')
 ),unique_rows$new$;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc',p.proowner::regrole::name
 INTO source_definition,source_attributes,source_owner FROM pg_proc p WHERE p.oid=source_oid;
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc'
 INTO queue_definition,queue_attributes FROM pg_proc p WHERE p.oid=queue_oid;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid=source_oid)<>'124ac74009c739975ff7b275151b0d65'
 OR md5(source_definition)<>'2cc3c7d1d235a33b4c595123b839de1b'
 THEN RAISE EXCEPTION 'V340 income worker definition lease changed';END IF;
 old_queue_definition:=replace(queue_definition,'lts_income_private.review_rows_v340(u,p_from,p_to)',
  'lts_income_private.rows_v296(u,p_from,p_to)');
 IF md5(old_queue_definition)<>'a13fd9c37aff2af5574cb70a5584146a'
 THEN RAISE EXCEPTION 'V340 income queue definition lease changed';END IF;
 IF (length(source_definition)-length(replace(source_definition,old_cte,'')))/length(old_cte)<>1
 OR (length(source_definition)-length(replace(source_definition,old_input,'')))/length(old_input)<>1
 THEN RAISE EXCEPTION 'V340 worker splice is ambiguous';END IF;
 review_definition:=replace(replace(replace(source_definition,
  'FUNCTION lts_income_private.rows_v296(', 'FUNCTION lts_income_private.review_rows_v340('),old_cte,new_cte),old_input,new_input);
 review_oid:=to_regprocedure('lts_income_private.review_rows_v340(uuid,date,date)');
 IF review_oid IS NOT NULL THEN
  IF pg_get_functiondef(review_oid) IS DISTINCT FROM review_definition
  THEN RAISE EXCEPTION 'V340 review worker already exists with a different definition';END IF;
 ELSE
  EXECUTE review_definition;
  EXECUTE format('ALTER FUNCTION lts_income_private.review_rows_v340(uuid,date,date) OWNER TO %I',source_owner);
 END IF;
 REVOKE ALL ON FUNCTION lts_income_private.review_rows_v340(uuid,date,date) FROM PUBLIC,anon,authenticated;
 GRANT EXECUTE ON FUNCTION lts_income_private.review_rows_v340(uuid,date,date) TO service_role;
 SELECT to_jsonb(p)-ARRAY['oid','proname','prosrc','proacl'] INTO worker_attributes FROM pg_proc p
 WHERE p.oid='lts_income_private.review_rows_v340(uuid,date,date)'::regprocedure;
 IF worker_attributes IS DISTINCT FROM source_attributes-ARRAY['oid','proname','proacl']
 THEN RAISE EXCEPTION 'V340 review worker attributes changed';END IF;
 IF queue_definition=old_queue_definition THEN
  EXECUTE replace(queue_definition,'lts_income_private.rows_v296(u,p_from,p_to)',
   'lts_income_private.review_rows_v340(u,p_from,p_to)');
 END IF;
 IF source_definition IS DISTINCT FROM pg_get_functiondef(source_oid)
 OR source_attributes IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=source_oid)
 OR queue_attributes IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=queue_oid)
 THEN RAISE EXCEPTION 'V340 protected function attributes changed';END IF;
END $patch$;
