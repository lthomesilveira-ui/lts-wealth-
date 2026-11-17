CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.review_input_contract_ok_v465(p_profile jsonb) RETURNS boolean
 LANGUAGE plpgsql STABLE SET search_path TO '' AS $function$
DECLARE item jsonb; c record; target_oid oid; actual text; seen integer:=0;
BEGIN
 IF current_user<>'postgres' OR current_setting('session_replication_role')<>'origin' THEN RETURN false;END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang
  WHERE p.oid=to_regprocedure('lts_product_refresh_private_v415.review_input_changed_v465()')
  AND md5(p.prosrc)='887587427da6715909959eab38bcd412' AND p.prosecdef AND p.provolatile='v'
  AND pg_get_userbyid(p.proowner)='postgres' AND l.lanname='plpgsql'
  AND p.proconfig=ARRAY['search_path=""']::text[]) THEN RETURN false;END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(p_profile->'tables') LOOP
  SELECT * INTO c FROM lts_product_refresh_private_v415.review_input_contract_v465 x
   WHERE x.schema_name=item->>'schema' AND x.table_name=item->>'name';
  IF NOT FOUND OR item->>'kind'<>'r' OR (item->>'epoch')::boolean IS DISTINCT FROM false THEN RETURN false;END IF;
  target_oid:=to_regclass(format('%I.%I',c.schema_name,c.table_name));
  IF target_oid IS DISTINCT FROM c.relation_oid THEN RETURN false;END IF;
  IF EXISTS(SELECT 1 FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid) THEN RETURN false;END IF;
  SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;
  IF actual IS DISTINCT FROM c.shape_hash THEN RETURN false;END IF;
  SELECT md5(t.oid::text||':'||t.xmin::text||':'||pg_get_triggerdef(t.oid)) INTO actual FROM pg_trigger t
   WHERE t.tgrelid=target_oid AND t.tgname=c.trigger_name AND t.tgenabled='A' AND NOT t.tgisinternal;
  IF actual IS DISTINCT FROM c.trigger_hash THEN RETURN false;END IF;
  seen:=seen+1;
 END LOOP;
 RETURN seen=19 AND seen=(SELECT count(*) FROM lts_product_refresh_private_v415.review_input_contract_v465)
  AND EXISTS(SELECT 1 FROM lts_product_refresh_private_v415.review_input_epoch_v465 WHERE singleton);
EXCEPTION WHEN undefined_table OR undefined_column OR undefined_function OR insufficient_privilege THEN RETURN false;
END
$function$;
REVOKE ALL ON FUNCTION lts_product_refresh_private_v415.review_input_contract_ok_v465(jsonb) FROM PUBLIC,anon,authenticated,service_role;
