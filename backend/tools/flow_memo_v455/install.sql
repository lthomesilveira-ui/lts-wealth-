-- Only a derived cache write changes. No source facts, guards or TTL change.
BEGIN;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='10s';
DO $patch$
DECLARE target regprocedure:='public.lts_flow_read_source_key_v247(uuid)'::regprocedure; d text; attrs jsonb;
BEGIN
 IF md5(pg_get_functiondef('lts_read_private_v430.try_cache_put(uuid,text,date,date,date,jsonb,text)'::regprocedure))<>'9c0d1ac15cb98696ef8fc98aca9ef6b6'
 THEN RAISE EXCEPTION 'V455_OPTIONAL_MEMO_HELPER_CHANGED'; END IF;
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='b65080ab49a211a349b5125aa4c1e48a' THEN
  IF (length(d)-length(replace(d,$needle$INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
 VALUES(p_user_id,'flow_source_key_v243',current_date,current_date,current_date,to_jsonb(key_value),cache_key,clock_timestamp())
 ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;$needle$,'')))/length($needle$INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
 VALUES(p_user_id,'flow_source_key_v243',current_date,current_date,current_date,to_jsonb(key_value),cache_key,clock_timestamp())
 ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;$needle$)<>1
  THEN RAISE EXCEPTION 'V455_MEMO_WRITE_SHAPE_CHANGED'; END IF;
  EXECUTE replace(d,$needle$INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
 VALUES(p_user_id,'flow_source_key_v243',current_date,current_date,current_date,to_jsonb(key_value),cache_key,clock_timestamp())
 ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;$needle$,$replacement$PERFORM lts_read_private_v430.try_cache_put(p_user_id,'flow_source_key_v243',current_date,current_date,current_date,to_jsonb(key_value),cache_key); /* optional_flow_memo_v455 */$replacement$);
 ELSIF md5(d)<>'210c2fa4addef8668aed479e86892975' THEN RAISE EXCEPTION 'V455_PREDECESSOR_CHANGED'; END IF;
 IF md5(pg_get_functiondef(target))<>'210c2fa4addef8668aed479e86892975'
 OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V455_FUNCTION_CONTRACT_CHANGED'; END IF;
END $patch$;
COMMIT;
