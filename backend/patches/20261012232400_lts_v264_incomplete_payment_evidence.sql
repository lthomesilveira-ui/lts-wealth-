-- V264: incomplete or repeated fee evidence must not prove settlement.
DO $patch$ DECLARE d text; BEGIN
 SELECT pg_get_functiondef('public.lts_current_received_card_bills_v263(uuid)'::regprocedure) INTO d;
 IF md5(d)<>'ec79f06a007b60eb3d949446d421240c' THEN RAISE EXCEPTION 'source lease changed'; END IF;
 d:=replace(d,$old$bool_and(q.valid) valid$old$,$new$bool_and(coalesce(q.valid,false)) valid$new$);
 d:=replace(d,$old$AND coalesce(bool_and(c->>'currencyCode'='BRL'
  AND c->>'amount' ~ '^[0-9]+([.][0-9]+)?$'),true) valid$old$,$new$AND count(*)=count(DISTINCT c->>'id')
  AND coalesce(bool_and(coalesce(c->>'currencyCode'='BRL'
  AND c->>'amount' ~ '^[0-9]+([.][0-9]+)?$',false)),true) valid$new$);
 EXECUTE d;
END $patch$;
