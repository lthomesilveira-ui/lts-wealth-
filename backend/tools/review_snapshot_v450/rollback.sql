BEGIN;
SET LOCAL lock_timeout='2s';
DO $checks$ DECLARE p regprocedure;actual_hash text;actual_acl text;actual_config text[];actual_definer boolean;actual_owner text;next_sql text;BEGIN
p:='public.lts_browser_expense_review_queue_v229(date,date,integer,integer,text)'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO actual_hash,actual_acl,actual_config,actual_definer,actual_owner FROM pg_proc WHERE oid=p;
 IF actual_hash NOT IN ('89367bae8cb6a173d468a8dd11142fc5','dcede5ed0d28052d1ec5d88a9d213a74') OR actual_acl IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres,authenticated=X/postgres}' OR actual_config IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo'] OR NOT actual_definer OR actual_owner<>'postgres' THEN RAISE EXCEPTION 'review reader changed concurrently: %',p;END IF;
p:='lts_product_refresh_private_v415.run_claimed()'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO actual_hash,actual_acl,actual_config,actual_definer,actual_owner FROM pg_proc WHERE oid=p;
 IF actual_hash NOT IN ('dc6ada84c13393bffdabeba767614a17','0505d522eb9007cacef7cf2d7d974416') OR actual_acl IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' OR actual_config IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo'] OR NOT actual_definer OR actual_owner<>'postgres' THEN RAISE EXCEPTION 'review reader changed concurrently: %',p;END IF;
END $checks$;
DO $changes$ DECLARE p regprocedure;next_sql text;BEGIN
p:='public.lts_browser_expense_review_queue_v229(date,date,integer,integer,text)'::regprocedure;
 IF md5(pg_get_functiondef(p))='89367bae8cb6a173d468a8dd11142fc5' THEN next_sql:=replace(pg_get_functiondef(p),$old_part$from lts_product_refresh_private_v415.expense_review_pending_v450(v_uid,p_from,p_to) r$old_part$,$new_part$from public.lts_v229_review_rows(v_uid,p_from,p_to) r$new_part$);
 IF md5(next_sql)<>'dcede5ed0d28052d1ec5d88a9d213a74' THEN RAISE EXCEPTION 'review patch reconstruction differs';END IF;EXECUTE next_sql;
 IF md5(pg_get_functiondef(p))<>'dcede5ed0d28052d1ec5d88a9d213a74' THEN RAISE EXCEPTION 'review installed definition differs';END IF;END IF;
p:='lts_product_refresh_private_v415.run_claimed()'::regprocedure;
 IF md5(pg_get_functiondef(p))='dc6ada84c13393bffdabeba767614a17' THEN next_sql:=replace(pg_get_functiondef(p),$old_part$  -- Warm after all product and queue publication writes, in the same claim.
  -- No extra job, altered classification, browser identity or financial write.
  PERFORM 1 FROM lts_product_refresh_private_v415.expense_review_pending_v450(u,date '2013-10-10',current_date);
  succeeded:=true;$old_part$,$new_part$  succeeded:=true;$new_part$);
 IF md5(next_sql)<>'0505d522eb9007cacef7cf2d7d974416' THEN RAISE EXCEPTION 'review patch reconstruction differs';END IF;EXECUTE next_sql;
 IF md5(pg_get_functiondef(p))<>'0505d522eb9007cacef7cf2d7d974416' THEN RAISE EXCEPTION 'review installed definition differs';END IF;END IF;
END $changes$;
COMMIT;
