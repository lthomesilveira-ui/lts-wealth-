-- Coverage audit only: recognize the exact received direct-debit descriptor.
-- A posted receipt covers its own period; no future payment is created.
DO $patch$
DECLARE
 target regprocedure:='public.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure;
 definition text;attributes jsonb;
 anchor text:='END,s.description_raw)';
 replacement text:=$alias$END,/* v334-exact-received-merchant-alias */CASE
 WHEN public.lts_forecast_series_key_v1(s.description_raw)='debito automatico deb autor netflix.com'
 THEN 'netflix' END,s.description_raw)$alias$;
BEGIN
 SELECT pg_get_functiondef(target),to_jsonb(p)-'prosrc' INTO definition,attributes FROM pg_proc p WHERE p.oid=target;
 IF strpos(definition,'v334-exact-received-merchant-alias')>0 THEN
  IF md5(replace(definition,replacement,anchor))<>'9925841d7b2f8f98482d723691dbc2a1'
  THEN RAISE EXCEPTION 'Recurring audit replay lease changed';END IF;
  RETURN;
 END IF;
 IF md5(definition)<>'9925841d7b2f8f98482d723691dbc2a1'
 OR (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>2
 THEN RAISE EXCEPTION 'Recurring audit definition lease changed';END IF;
 EXECUTE replace(definition,anchor,replacement);
 IF attributes IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'Recurring audit attributes changed';END IF;
END $patch$;
