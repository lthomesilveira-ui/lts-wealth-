-- Complete JSON equality includes financial rows, row order, schema column order,
-- owner scoping and every coverage field. Both calls share statement_timestamp().
DO $test$
DECLARE n integer;u uuid;equal_payload boolean;
BEGIN
 FOR n IN 1..6 LOOP
  u:=('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
  SELECT public.qa_backup_before_v406(u)=public.lts_backup_modern_export_v380(u)
  INTO equal_payload;
  PERFORM public.fixture_expect(equal_payload,'v406_complete_payload_owner_'||n);
 END LOOP;
 SELECT public.qa_backup_before_v406('00000000-0000-4000-8000-000000000009')=
  public.lts_backup_modern_export_v380('00000000-0000-4000-8000-000000000009') INTO equal_payload;
 PERFORM public.fixture_expect(equal_payload,'v406_complete_payload_unknown_owner');
 SELECT public.qa_backup_before_v406(NULL)=public.lts_backup_modern_export_v380(NULL)
 INTO equal_payload;
 PERFORM public.fixture_expect(equal_payload,'v406_complete_payload_null_owner');
 PERFORM public.fixture_expect((SELECT exporter_acl IS NOT DISTINCT FROM
  (SELECT to_jsonb(proacl) FROM pg_proc WHERE oid='public.lts_backup_modern_export_v380(uuid)'::regprocedure)
  FROM public.qa_backup_contract_v406),'v406_acl_unchanged');
 PERFORM public.fixture_expect((SELECT jobs=(SELECT jsonb_agg(to_jsonb(j) ORDER BY jobid) FROM cron.job j)
  FROM public.qa_backup_contract_v406),'v406_all_schedules_unchanged');
 PERFORM public.fixture_expect((SELECT unchanged_functions=(SELECT jsonb_object_agg(proname,md5(pg_get_functiondef(oid)))
  FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname LIKE 'lts_backup_%'
  AND proname NOT IN('lts_backup_modern_export_v380','lts_backup_base_schema_v406'))FROM public.qa_backup_contract_v406),'v406_writers_readers_guards_and_legacy_export_unchanged');
 PERFORM public.fixture_expect((SELECT NOT prosecdef AND provolatile='s'
  FROM pg_proc WHERE oid='public.lts_backup_modern_export_v380(uuid)'::regprocedure),
  'v406_stable_security_invoker');
 PERFORM public.fixture_expect(NOT has_function_privilege('anon','public.lts_backup_base_schema_v406()','EXECUTE')
  AND NOT has_function_privilege('authenticated','public.lts_backup_base_schema_v406()','EXECUTE')
  AND has_function_privilege('service_role','public.lts_backup_base_schema_v406()','EXECUTE')
  AND (SELECT NOT prosecdef AND provolatile='s' FROM pg_proc WHERE oid='public.lts_backup_base_schema_v406()'::regprocedure),
  'v406_metadata_helper_private_stable_invoker');
END $test$;
SELECT jsonb_build_object('v406_checks',count(*),'labels',jsonb_agg(label ORDER BY label))
FROM public.fixture_results WHERE label LIKE 'v406_%';
