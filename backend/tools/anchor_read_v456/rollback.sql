-- Avoid a row lock only for a fully validated canonical cache hit.
BEGIN;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='10s';
DO $patch$
DECLARE target regprocedure:='public.lts_apply_current_liquidity_anchor_v1(uuid)'::regprocedure; d text; attrs jsonb;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='4452a275c50044bb89ac5ab8514a90aa' THEN
  IF (length(d)-length(replace(d,$needle$ select * into c from public.lts_product_read_cache where user_id=p_user_id;
 if not found then raise exception 'product cache unavailable'; end if;
 k:=public.lts_dashboard_source_key_v240(p_user_id);
 cached_key:=public.lts_dashboard_payload_key_v240(c.payload);
 if c.payload#>>'{canonical_summary,source_key}'=k and c.payload#>>'{canonical_summary,payload_key}'=cached_key then
  return jsonb_build_object('ok',true,'version','canonical-cache-v240','cache_hit',true);
 end if;
 -- A cache hit is read-only. Only a real rebuild takes the original lock;
 -- recheck after acquiring it because another writer may have finished.
 select * into c from public.lts_product_read_cache where user_id=p_user_id for update;
 if not found then raise exception 'product cache unavailable'; end if;
 k:=public.lts_dashboard_source_key_v240(p_user_id);
 cached_key:=public.lts_dashboard_payload_key_v240(c.payload);
 if c.payload#>>'{canonical_summary,source_key}'=k and c.payload#>>'{canonical_summary,payload_key}'=cached_key then
  return jsonb_build_object('ok',true,'version','canonical-cache-v240','cache_hit',true);
 end if;$needle$,'')))/length($needle$ select * into c from public.lts_product_read_cache where user_id=p_user_id;
 if not found then raise exception 'product cache unavailable'; end if;
 k:=public.lts_dashboard_source_key_v240(p_user_id);
 cached_key:=public.lts_dashboard_payload_key_v240(c.payload);
 if c.payload#>>'{canonical_summary,source_key}'=k and c.payload#>>'{canonical_summary,payload_key}'=cached_key then
  return jsonb_build_object('ok',true,'version','canonical-cache-v240','cache_hit',true);
 end if;
 -- A cache hit is read-only. Only a real rebuild takes the original lock;
 -- recheck after acquiring it because another writer may have finished.
 select * into c from public.lts_product_read_cache where user_id=p_user_id for update;
 if not found then raise exception 'product cache unavailable'; end if;
 k:=public.lts_dashboard_source_key_v240(p_user_id);
 cached_key:=public.lts_dashboard_payload_key_v240(c.payload);
 if c.payload#>>'{canonical_summary,source_key}'=k and c.payload#>>'{canonical_summary,payload_key}'=cached_key then
  return jsonb_build_object('ok',true,'version','canonical-cache-v240','cache_hit',true);
 end if;$needle$)<>1
  THEN RAISE EXCEPTION 'V456_ANCHOR_READ_SHAPE_CHANGED'; END IF;
  EXECUTE replace(d,$needle$ select * into c from public.lts_product_read_cache where user_id=p_user_id;
 if not found then raise exception 'product cache unavailable'; end if;
 k:=public.lts_dashboard_source_key_v240(p_user_id);
 cached_key:=public.lts_dashboard_payload_key_v240(c.payload);
 if c.payload#>>'{canonical_summary,source_key}'=k and c.payload#>>'{canonical_summary,payload_key}'=cached_key then
  return jsonb_build_object('ok',true,'version','canonical-cache-v240','cache_hit',true);
 end if;
 -- A cache hit is read-only. Only a real rebuild takes the original lock;
 -- recheck after acquiring it because another writer may have finished.
 select * into c from public.lts_product_read_cache where user_id=p_user_id for update;
 if not found then raise exception 'product cache unavailable'; end if;
 k:=public.lts_dashboard_source_key_v240(p_user_id);
 cached_key:=public.lts_dashboard_payload_key_v240(c.payload);
 if c.payload#>>'{canonical_summary,source_key}'=k and c.payload#>>'{canonical_summary,payload_key}'=cached_key then
  return jsonb_build_object('ok',true,'version','canonical-cache-v240','cache_hit',true);
 end if;$needle$,$replacement$ select * into c from public.lts_product_read_cache where user_id=p_user_id for update;
 if not found then raise exception 'product cache unavailable'; end if;
 k:=public.lts_dashboard_source_key_v240(p_user_id);
 cached_key:=public.lts_dashboard_payload_key_v240(c.payload);
 if c.payload#>>'{canonical_summary,source_key}'=k and c.payload#>>'{canonical_summary,payload_key}'=cached_key then
  return jsonb_build_object('ok',true,'version','canonical-cache-v240','cache_hit',true);
 end if;$replacement$);
 ELSIF md5(d)<>'9c49edc420a9661d2dfe5bef45db9371' THEN RAISE EXCEPTION 'V456_PREDECESSOR_CHANGED'; END IF;
 IF md5(pg_get_functiondef(target))<>'9c49edc420a9661d2dfe5bef45db9371'
 OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V456_FUNCTION_CONTRACT_CHANGED'; END IF;
END $patch$;
COMMIT;
