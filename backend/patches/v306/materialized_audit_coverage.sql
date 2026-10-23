-- Only prevent repeated evaluation of the same pure coverage counts.
-- No data, totals, response fields, grants or timeout configuration change.
DO $patch$
DECLARE d text;prior jsonb;sig regprocedure:='public.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure;
 anchor text:='), coverage AS (';replacement text:='), coverage AS MATERIALIZED (';
BEGIN
 SELECT pg_get_functiondef(oid),jsonb_build_object('oid',oid,'owner',proowner,'acl',proacl,
 'config',proconfig,'definer',prosecdef,'volatility',provolatile) INTO d,prior FROM pg_proc WHERE oid=sig;
 IF strpos(d,replacement)>0 THEN RETURN;END IF;
 IF md5(d)<>'ede9e6d0c93f43cf8d3c4101f1489b95' OR strpos(d,'v303-proved-bank-receipts')=0
 OR (length(d)-length(replace(d,anchor,'')))/length(anchor)<>1
 THEN RAISE EXCEPTION 'Audit definition lease changed';END IF;
 EXECUTE replace(d,anchor,replacement);
 IF prior IS DISTINCT FROM(SELECT jsonb_build_object('oid',oid,'owner',proowner,'acl',proacl,
 'config',proconfig,'definer',prosecdef,'volatility',provolatile) FROM pg_proc WHERE oid=sig)
 THEN RAISE EXCEPTION 'Audit identity or security attributes changed';END IF;
END $patch$;
