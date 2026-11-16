BEGIN;
SET LOCAL lock_timeout='2s';
DO $due_today_identity$
DECLARE p regprocedure;actual_hash text;actual_acl text;actual_config text[];actual_definer boolean;actual_owner text;next_sql text;
BEGIN
 p:='public.lts_flow_cache_pre_v240(uuid,date,date)'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner)
 INTO actual_hash,actual_acl,actual_config,actual_definer,actual_owner FROM pg_proc WHERE oid=p;
 IF actual_hash NOT IN('d21cd4329f634356c675c4a9c8b56f67','2bced85c7ee1247102de52cfa0c93ea7') OR actual_acl IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}'
 OR actual_owner<>'postgres' OR actual_config IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo','statement_timeout=18s']
 OR actual_definer IS DISTINCT FROM false THEN
  RAISE EXCEPTION 'due-today identity reader changed concurrently: %',p;
 END IF;
 p:='public.lts_browser_flow_pre_v238(date,date)'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner)
 INTO actual_hash,actual_acl,actual_config,actual_definer,actual_owner FROM pg_proc WHERE oid=p;
 IF actual_hash NOT IN('53c238ec6c35ecee909b7f5cd4efd7eb','10eded9c70b9b7bdaf55702bcf3e72e0') OR actual_acl IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}'
 OR actual_owner<>'postgres' OR actual_config IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo','statement_timeout=18s']
 OR actual_definer IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'due-today identity reader changed concurrently: %',p;
 END IF;
 p:='public.lts_flow_cache_pre_v240(uuid,date,date)'::regprocedure;
 IF md5(pg_get_functiondef(p))='d21cd4329f634356c675c4a9c8b56f67' THEN
  next_sql:=replace(pg_get_functiondef(p),$identity_old$ pending_predictions:=public.lts_pending_projections_v233(u);
 -- The exact unpaid invoice already retained above is the same forecast,
 -- not another cash movement in the pending-review presentation lane.
 SELECT coalesce(jsonb_agg(x),'[]') INTO pending_predictions
 FROM jsonb_array_elements(pending_predictions) x
 WHERE NOT (x->>'source'='card_invoice'
  AND (x->>'event_date')::date=current_date
  AND EXISTS(SELECT 1 FROM jsonb_array_elements(recent) kept
   WHERE kept->>'source'='card_invoice'
    AND coalesce((kept->>'unposted_current_projection')::boolean,false)
    AND kept->>'source_ref'=x->>'source_ref'
    AND kept->>'account'=x->>'account'
    AND kept->>'event_date'=x->>'event_date'
    AND (kept->>'signed_amount')::numeric=(x->>'signed_amount')::numeric));$identity_old$,$identity_new$ pending_predictions:=public.lts_pending_projections_v233(u);$identity_new$);
  IF md5(next_sql)<>'2bced85c7ee1247102de52cfa0c93ea7' THEN RAISE EXCEPTION 'identity patch reconstruction differs';END IF;
  EXECUTE next_sql;
  IF md5(pg_get_functiondef(p))<>'2bced85c7ee1247102de52cfa0c93ea7' THEN RAISE EXCEPTION 'identity installed definition differs';END IF;
 END IF;
 p:='public.lts_browser_flow_pre_v238(date,date)'::regprocedure;
 IF md5(pg_get_functiondef(p))='53c238ec6c35ecee909b7f5cd4efd7eb' THEN
  next_sql:=replace(pg_get_functiondef(p),$identity_old$ pending_predictions:=public.lts_pending_projections_v233(u);
 -- The exact unpaid invoice already retained above is the same forecast,
 -- not another cash movement in the pending-review presentation lane.
 SELECT coalesce(jsonb_agg(x),'[]') INTO pending_predictions
 FROM jsonb_array_elements(pending_predictions) x
 WHERE NOT (x->>'source'='card_invoice'
  AND (x->>'event_date')::date=current_date
  AND EXISTS(SELECT 1 FROM jsonb_array_elements(recent) kept
   WHERE kept->>'source'='card_invoice'
    AND coalesce((kept->>'unposted_current_projection')::boolean,false)
    AND kept->>'source_ref'=x->>'source_ref'
    AND kept->>'account'=x->>'account'
    AND kept->>'event_date'=x->>'event_date'
    AND (kept->>'signed_amount')::numeric=(x->>'signed_amount')::numeric));$identity_old$,$identity_new$ pending_predictions:=public.lts_pending_projections_v233(u);$identity_new$);
  IF md5(next_sql)<>'10eded9c70b9b7bdaf55702bcf3e72e0' THEN RAISE EXCEPTION 'identity patch reconstruction differs';END IF;
  EXECUTE next_sql;
  IF md5(pg_get_functiondef(p))<>'10eded9c70b9b7bdaf55702bcf3e72e0' THEN RAISE EXCEPTION 'identity installed definition differs';END IF;
 END IF;
END $due_today_identity$;
COMMIT;
