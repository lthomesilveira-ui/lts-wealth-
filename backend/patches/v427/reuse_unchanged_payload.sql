-- Keep consultation clocks current without rebuilding an identical JSON value.
-- Every original source observation and complete position cohort is preserved.
BEGIN;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='8s';
DO $patch$
DECLARE
 target regprocedure:='public.lts_open_finance_stage_batch_core_v403(uuid,uuid,uuid,jsonb,text[])'::regprocedure;
 u uuid:=public.lts_open_finance_pilot_owner_v1();
 d text; before_attrs jsonb; after_attrs jsonb;
 predecessor text:='7eae45733a61ba7e2dbda772616ec4cf';
 old_block text:=$old$normalized_payload=CASE WHEN (t->>'has_source_sync_at')::boolean THEN jsonb_set(s.normalized_payload,'{source_sync_at}',t->'source_sync_at') ELSE s.normalized_payload-'source_sync_at' END$old$;
 new_block text:=$new$normalized_payload=CASE -- v427-reuse-unchanged-payload
   WHEN (t->>'has_source_sync_at')::boolean THEN
    CASE WHEN s.normalized_payload->'source_sync_at' IS DISTINCT FROM t->'source_sync_at'
     THEN jsonb_set(s.normalized_payload,'{source_sync_at}',t->'source_sync_at')
     ELSE s.normalized_payload END
   WHEN s.normalized_payload?'source_sync_at' THEN s.normalized_payload-'source_sync_at'
   ELSE s.normalized_payload END$new$;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('lts-open-finance-itau:'||u::text,0));
 PERFORM pg_advisory_xact_lock(hashtextextended('lts-open-finance-bank:237:'||u::text,0));
 PERFORM pg_advisory_xact_lock(hashtextextended('lts-open-finance-bank:336:'||u::text,0));
 IF EXISTS(SELECT FROM public.lts_open_finance_sync_run WHERE user_id=u AND status='running') THEN
  RAISE EXCEPTION 'Active collection; wait before applying V427';
 END IF;
 SELECT pg_get_functiondef(p.oid),to_jsonb(p) INTO d,before_attrs
 FROM pg_catalog.pg_proc p WHERE p.oid=target;
 IF before_attrs->>'prosecdef'<>'false'
  OR has_function_privilege('anon',target,'EXECUTE')
  OR has_function_privilege('authenticated',target,'EXECUTE')
  OR NOT has_function_privilege('service_role',target,'EXECUTE') THEN
  RAISE EXCEPTION 'Unexpected ingestion privileges; review before applying';
 END IF;
 IF md5(d)=predecessor AND position(old_block IN d)>0 THEN
  EXECUTE replace(d,old_block,new_block);
 ELSIF position(new_block IN d)>0 AND md5(replace(d,new_block,old_block))=predecessor THEN
  NULL; -- exact reviewed replay
 ELSE
  RAISE EXCEPTION 'Unexpected ingestion predecessor; review before applying';
 END IF;
 SELECT to_jsonb(p) INTO after_attrs FROM pg_catalog.pg_proc p WHERE p.oid=target;
 IF (before_attrs-'prosrc') IS DISTINCT FROM (after_attrs-'prosrc') THEN
  RAISE EXCEPTION 'Unexpected ingestion signature, owner, configuration or privilege change';
 END IF;
END $patch$;
COMMIT;
