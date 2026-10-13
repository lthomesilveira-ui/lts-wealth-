-- Reuse the prepared statement for the exact existing paid-cycle identity.
-- A measured plan preparation cost dominated this unchanged source query.
-- All invoice, bank, dates, owner, amount, routing and uniqueness predicates
-- are retained byte-for-byte. No payment or cash movement is created.
DO $patch$
DECLARE target regprocedure:='public.lts_c6_paid_identity_v237(uuid)'::regprocedure;
 d text; original_acl aclitem[]; original_owner oid;
 old_tail text:=$tail$SELECT CASE WHEN count(*)=1 THEN jsonb_agg(to_jsonb(c))->0 ELSE NULL END FROM candidates c;
$function$$tail$;
 new_tail text:=$tail$SELECT CASE WHEN count(*)=1 THEN jsonb_agg(to_jsonb(c))->0 ELSE NULL END INTO result FROM candidates c;
RETURN result;
END;
$function$$tail$;
BEGIN
 SELECT pg_get_functiondef(target),proacl,proowner INTO d,original_acl,original_owner
 FROM pg_proc WHERE oid=target;
 IF md5(d)<>'ebc2055bc7319d791799ef9b33e3120e'
 THEN RAISE EXCEPTION 'paid identity definition lease changed'; END IF;
 IF strpos(d,old_tail)=0 OR strpos(d,E'AS $function$\nWITH inv AS MATERIALIZED (')=0
 THEN RAISE EXCEPTION 'paid identity body anchor changed'; END IF;
 d:=replace(d,E' LANGUAGE sql\n',E' LANGUAGE plpgsql\n');
 d:=replace(d,E' SET search_path TO \'\'\n',E' SET search_path TO \'\'\n SET plan_cache_mode TO \'force_generic_plan\'\n');
 d:=replace(d,E'AS $function$\nWITH inv AS MATERIALIZED (',
  E'AS $function$\nDECLARE result jsonb;\nBEGIN\nWITH inv AS MATERIALIZED (');
 d:=replace(d,old_tail,new_tail);
 EXECUTE d;
 IF EXISTS(SELECT 1 FROM pg_proc WHERE oid=target AND
  (proacl IS DISTINCT FROM original_acl OR proowner IS DISTINCT FROM original_owner
   OR NOT prosecdef OR proisstrict OR provolatile<>'s'
   OR proconfig IS DISTINCT FROM ARRAY['search_path=""','plan_cache_mode=force_generic_plan']::text[]))
 THEN RAISE EXCEPTION 'paid identity privileges or execution contract changed'; END IF;
 IF has_function_privilege('anon',target,'EXECUTE') OR has_function_privilege('authenticated',target,'EXECUTE')
 THEN RAISE EXCEPTION 'paid identity helper exposed'; END IF;
END;
$patch$;
