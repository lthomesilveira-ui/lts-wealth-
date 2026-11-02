SET TIME ZONE 'America/Sao_Paulo';
DO $verify$
DECLARE
 u uuid:='00000000-0000-4000-8000-000000000004';r jsonb;j jsonb;c jsonb;bad jsonb;changed_counts jsonb;
 old_calls bigint;new_calls bigint;old_hash text;v record;got text;
BEGIN
 PERFORM public.fixture_expect((SELECT count(*) FROM public.fixture_old_archives)=2,'two_historical_profiles_saved');
 FOR v IN SELECT * FROM public.fixture_old_archives LOOP
  r:=public.lts_backup_bundle_read_v380(v.user_id,v.snapshot_date);
  PERFORM public.fixture_expect(r#>>'{manifest,modern_sha256}'=v.payload_sha256,'historical_reader_'||v.user_id);
  r:=public.lts_backup_snapshot_take_v380(v.user_id);
  PERFORM public.fixture_expect(r->'inserted'='false'::jsonb AND r->>'payload_sha256'=v.payload_sha256,'historical_replay_'||v.user_id);
 END LOOP;
 PERFORM public.fixture_expect(public.lts_backup_bundle_read_v380('00000000-0000-4000-8000-000000000003',current_date)#>>'{modern,coverage,selected_tables}'='33','preexisting_valid33_readable');

 SELECT last_value INTO old_calls FROM public.fixture_legacy_calls;
 r:=public.lts_backup_snapshot_take_v380(u);
 PERFORM public.fixture_expect(r->'inserted'='true'::jsonb,'new33_capture_inserted');
 old_hash:=r->>'payload_sha256';
 SELECT last_value INTO new_calls FROM public.fixture_legacy_calls;
 PERFORM public.fixture_expect(new_calls=old_calls+1,'legacy_capture_invoked_once');
 r:=public.lts_backup_bundle_read_v380(u,current_date);
 j:=r->'modern';c:=r#>'{manifest,counts}';
 PERFORM public.fixture_expect(j#>>'{coverage,selected_tables}'='33','declared_33_matches_export');
 PERFORM public.fixture_expect(public.lts_backup_manifest_valid_v401(j,c),'complete33_manifest_valid');
 PERFORM public.fixture_expect(j#>'{tables,lts_family_loan_v398,0,original_principal}'='2000','owner_family_principal_preserved');
 PERFORM public.fixture_expect(j#>>'{tables,lts_family_loan_v398,0,commitment_id}'='family-four','other_owner_family_excluded');
 PERFORM public.fixture_expect(jsonb_array_length(j#>'{tables,lts_savings_rate_v398}')=2,'both_official_rate_inputs_preserved');
 PERFORM public.fixture_expect(j#>>'{tables,lts_cash_alert_private_v377.delivery,0,token}'='four-cash','cash_journal_owner_scope');
 PERFORM public.fixture_expect(j#>>'{tables,lts_account_reminder_private_v387.delivery,0,token}'='four-accounts','account_journal_owner_scope');
 r:=public.lts_backup_snapshot_take_v380(u);
 PERFORM public.fixture_expect(r->'inserted'='false'::jsonb AND r->>'payload_sha256'=old_hash,'new33_replay_same_hash');
 PERFORM public.fixture_expect((SELECT last_value FROM public.fixture_legacy_calls)=new_calls,'replay_does_not_recapture');

 bad:=j#-'{tables,lts_savings_rate_v398}';
 PERFORM public.fixture_expect(NOT public.lts_backup_manifest_valid_v401(bad,c),'missing_family_table_rejected');
 bad:=jsonb_set(j#-'{tables,lts_family_loan_v398}','{tables,fake_family}','[]');
 PERFORM public.fixture_expect(NOT public.lts_backup_manifest_valid_v401(bad,c),'same_count_fake_family_rejected');
 bad:=jsonb_set(j#-'{tables,lts_cash_alert_private_v377.delivery}','{tables,fake_journal}','[]');
 PERFORM public.fixture_expect(NOT public.lts_backup_manifest_valid_v401(bad,c),'same_count_fake_journal_rejected');
 bad:=jsonb_set(j,'{tables,extra}','[]');
 PERFORM public.fixture_expect(NOT public.lts_backup_manifest_valid_v401(bad,c),'unexpected34_rejected');
 bad:=jsonb_set(j,'{coverage,selected_tables}','31');
 PERFORM public.fixture_expect(NOT public.lts_backup_manifest_valid_v401(bad,c),'incorrect_declared_coverage_rejected');
 bad:=j#-'{coverage,indexed_family_loan_inputs}';
 PERFORM public.fixture_expect(NOT public.lts_backup_manifest_valid_v401(bad,c),'missing_family_coverage_flag_rejected');
 changed_counts:=jsonb_set(c,'{lts_savings_rate_v398}','3');
 PERFORM public.fixture_expect(NOT public.lts_backup_manifest_valid_v401(j,changed_counts),'wrong_row_count_rejected');
 PERFORM public.fixture_expect(NOT public.lts_backup_manifest_valid_v401(jsonb_set(j,'{tables}','[]'),c),'array_instead_of_table_map_rejected');
 PERFORM public.fixture_expect(NOT public.lts_backup_manifest_valid_v401(jsonb_set(j,'{tables,usuario}','null'),c),'non_array_table_rows_rejected');
 PERFORM public.fixture_expect(NOT public.lts_backup_manifest_valid_v401(NULL,c),'null_payload_rejected');
 PERFORM public.fixture_expect(NOT public.lts_backup_manifest_valid_v401(j,NULL),'null_counts_rejected');

 -- The sequence is deliberately nontransactional: it exposes a legacy call
 -- even if the failing capture rolls back every table write.
 SELECT last_value INTO old_calls FROM public.fixture_legacy_calls;
 BEGIN
  EXECUTE 'CREATE OR REPLACE FUNCTION public.lts_backup_modern_export_v380(p_user_id uuid)RETURNS jsonb LANGUAGE sql STABLE AS $bad$SELECT ''{}''::jsonb$bad$';
  PERFORM public.lts_backup_snapshot_take_v380('00000000-0000-4000-8000-000000000005');
  RAISE EXCEPTION 'Invalid modern export accepted';
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM<>'incomplete modern backup'THEN RAISE;END IF;
 END;
 PERFORM public.fixture_expect((SELECT last_value FROM public.fixture_legacy_calls)=old_calls,'invalid_modern_export_fails_before_legacy');
 PERFORM public.fixture_expect(NOT EXISTS(SELECT 1 FROM public.lts_backup_snapshot WHERE user_id='00000000-0000-4000-8000-000000000005'),'invalid_export_leaves_no_legacy_row');
 BEGIN
  UPDATE public.lts_backup_supplement_v380 SET payload_sha256=repeat('0',64)WHERE user_id=u;
  PERFORM public.lts_backup_bundle_read_v380(u,current_date);
  RAISE EXCEPTION 'Corrupt modern hash accepted';
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM<>'modern backup integrity mismatch'THEN RAISE;END IF;
 END;
 PERFORM public.fixture_expect((SELECT payload_sha256 FROM public.lts_backup_supplement_v380 WHERE user_id=u)=old_hash,'tamper_test_rolled_back');
 BEGIN
  UPDATE public.lts_backup_snapshot SET payload_hash='bad'WHERE user_id=u;
  PERFORM public.lts_backup_bundle_read_v380(u,current_date);
  RAISE EXCEPTION 'Corrupt legacy hash accepted';
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM<>'legacy backup integrity mismatch'THEN RAISE;END IF;
 END;
 PERFORM public.fixture_expect(public.lts_backup_bundle_read_v380(u,current_date)#>>'{manifest,modern_sha256}'=old_hash,'legacy_tamper_test_rolled_back');
 BEGIN
  PERFORM public.lts_backup_snapshot_take_v380(NULL);
  RAISE EXCEPTION 'Null owner accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'user required'THEN RAISE;END IF;END;
 BEGIN
  PERFORM public.lts_backup_snapshot_take_v380(u,current_date-1);
  RAISE EXCEPTION 'Historical recapture accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'snapshot date must be today'THEN RAISE;END IF;END;
 BEGIN
  PERFORM public.lts_backup_snapshot_take_v380('00000000-0000-4000-8000-000000000099');
  RAISE EXCEPTION 'Unknown owner accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'unknown user'THEN RAISE;END IF;END;
 PERFORM public.fixture_expect(true,'invalid_owner_and_date_guards_preserved');

 PERFORM public.fixture_expect(NOT has_function_privilege('anon','public.lts_backup_manifest_valid_v401(jsonb,jsonb)','EXECUTE')AND NOT has_function_privilege('authenticated','public.lts_backup_manifest_valid_v401(jsonb,jsonb)','EXECUTE'),'new_validator_not_public');
 PERFORM public.fixture_expect(NOT has_function_privilege('anon','public.lts_backup_snapshot_take_v380(uuid,date)','EXECUTE')AND NOT has_function_privilege('authenticated','public.lts_backup_bundle_read_v380(uuid,date)','EXECUTE'),'writer_and_reader_privileges_preserved');
 PERFORM public.fixture_expect(has_function_privilege('service_role','public.lts_backup_manifest_valid_v401(jsonb,jsonb)','EXECUTE'),'service_validator_allowed');
 PERFORM public.fixture_expect(NOT EXISTS(SELECT 1 FROM public.fixture_old_archives f JOIN public.lts_backup_supplement_v380 s USING(user_id,snapshot_date)WHERE(s.payload_sha256,s.payload_bytes,s.counts)IS DISTINCT FROM(f.payload_sha256,f.payload_bytes,f.counts)),'historical_archive_bytes_and_counts_preserved');
 PERFORM public.fixture_expect((SELECT count(*) FROM cron.job)=2,'no_job_added_or_removed');
 PERFORM public.fixture_expect(NOT EXISTS(SELECT 1 FROM cron.job a JOIN public.fixture_job_before b USING(jobid)WHERE(a.schedule,a.active,a.jobname)IS DISTINCT FROM(b.schedule,b.active,b.jobname)),'job_schedule_and_state_preserved');
 PERFORM public.fixture_expect((SELECT command FROM cron.job WHERE jobid=2)=(SELECT command FROM public.fixture_job_before WHERE jobid=2),'unrelated_job_command_preserved');
 PERFORM public.fixture_expect((SELECT command FROM cron.job WHERE jobid=1)='SET statement_timeout = ''90s''; '||(SELECT replace(command,'snapshot_take_v1(','snapshot_take_v380(')FROM public.fixture_job_before WHERE jobid=1),'backup_command_timeout_scoped');
END $verify$;
SET ROLE service_role;
SELECT public.lts_backup_snapshot_take_v380('00000000-0000-4000-8000-000000000006');
SELECT public.lts_backup_bundle_read_v380('00000000-0000-4000-8000-000000000006',current_date)->>'user_id';
RESET ROLE;
SELECT public.fixture_expect(EXISTS(SELECT 1 FROM public.lts_backup_supplement_v380 WHERE user_id='00000000-0000-4000-8000-000000000006'),'service_role_capture_and_read_execute');
SET ROLE anon;
DO $$BEGIN
 BEGIN
  PERFORM public.lts_backup_snapshot_take_v380('00000000-0000-4000-8000-000000000006');
  RAISE EXCEPTION 'Anonymous capture unexpectedly executed';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END$$;
RESET ROLE;
SELECT public.fixture_expect(true,'anonymous_capture_execution_denied');
SELECT jsonb_build_object('native_postgres_17',true,'passed',count(*),'all_passed',bool_and(pass),'financial_data','synthetic only') FROM public.fixture_results;
