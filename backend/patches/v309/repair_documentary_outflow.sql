-- Correct the auxiliary source-document outflow after the first V309 reader deployment.
-- The underlying canonical summary already carries both documentary and future totals.
DO $repair$ DECLARE d text;s text;attrs jsonb;
old_line text:=$before$j:=jsonb_set(j,'{cipo_detail,documentary_contractual_outflow_brl}',coalesce(j#>'{cipo_detail,contractual_outflow_current_terms_brl}','null'::jsonb));$before$;
new_line text:=$after$j:=jsonb_set(j,'{cipo_detail,documentary_contractual_outflow_brl}',coalesce((SELECT c->'documentary_remaining_scheduled_outflow' FROM jsonb_array_elements(CASE WHEN jsonb_typeof(j#>'{financing,summary,commitments}')='array' THEN j#>'{financing,summary,commitments}' ELSE '[]'::jsonb END) c WHERE c->>'id'='cipo_396'),'null'::jsonb));$after$;
BEGIN
 SELECT pg_get_functiondef(p.oid),p.prosrc,jsonb_build_object('oid',p.oid,'owner',p.proowner,'acl',p.proacl,'config',p.proconfig,'definer',p.prosecdef,'volatility',p.provolatile) INTO d,s,attrs FROM pg_proc p
 WHERE p.oid='public.lts_browser_wealth_detail_v242()'::regprocedure;
 IF md5(d)='769a6cf3621b8dfb422acf23384827d4' THEN RETURN;END IF;
 IF md5(d)<>'b82efd50c52cf68d95b00ed4ecd75221' OR length(s)-length(replace(s,old_line,''))<>length(old_line)
 THEN RAISE EXCEPTION 'V309 documentary outflow repair lease changed';END IF;
 EXECUTE replace(d,s,replace(s,old_line,new_line));
 IF md5(pg_get_functiondef('public.lts_browser_wealth_detail_v242()'::regprocedure))<>'769a6cf3621b8dfb422acf23384827d4'
 OR attrs IS DISTINCT FROM(SELECT jsonb_build_object('oid',p.oid,'owner',p.proowner,'acl',p.proacl,'config',p.proconfig,'definer',p.prosecdef,'volatility',p.provolatile) FROM pg_proc p WHERE p.oid='public.lts_browser_wealth_detail_v242()'::regprocedure)
 THEN RAISE EXCEPTION 'V309 documentary outflow repair verification failed';END IF;
END $repair$;
