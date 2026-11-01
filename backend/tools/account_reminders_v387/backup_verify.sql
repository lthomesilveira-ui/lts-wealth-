\set ON_ERROR_STOP on
SET TIME ZONE 'America/Sao_Paulo';
DO $test$
DECLARE old record;u uuid:='00000000-0000-4000-8000-000000000003';r jsonb;h text;
BEGIN
 FOR old IN SELECT * FROM public.fixture_archived_backup_hash LOOP
  r:=public.lts_backup_bundle_read_v380(old.user_id,old.snapshot_date);
  IF r#>>'{manifest,modern_sha256}'<>old.payload_sha256 OR r#>>'{modern,coverage,selected_tables}'<>'29'THEN RAISE EXCEPTION 'Archived backup changed';END IF;
 END LOOP;
 r:=public.lts_backup_snapshot_take_v380(u);h:=r->>'payload_sha256';
 IF r->>'inserted'<>'true'OR r#>>'{counts,lts_cash_alert_private_v377.delivery}'<>'1'OR r#>>'{counts,lts_account_reminder_private_v387.delivery}'<>'1'THEN RAISE EXCEPTION 'Journal counts not preserved';END IF;
 r:=public.lts_backup_bundle_read_v380(u,current_date);
 IF r#>>'{modern,coverage,selected_tables}'<>'31'OR r#>>'{modern,coverage,full_restore_tested}'<>'false'OR r#>>'{modern,coverage,storage_binaries}'<>'false'THEN RAISE EXCEPTION 'Coverage contract wrong';END IF;
 IF r#>>'{modern,tables,lts_account_reminder_private_v387.delivery,0,message_id}'<>'accounts-three'OR r#>>'{modern,tables,lts_cash_alert_private_v377.delivery,0,message_id}'<>'cash-three'THEN RAISE EXCEPTION 'Wrong owner journal';END IF;
 IF(SELECT count(*)FROM jsonb_array_elements(r#>'{modern,schema_columns}')x WHERE x->>'table_schema'IN('lts_cash_alert_private_v377','lts_account_reminder_private_v387')AND x->>'table_name'='delivery')<>10 THEN RAISE EXCEPTION 'Journal schema columns missing';END IF;
 IF public.lts_backup_snapshot_take_v380(u)->>'payload_sha256'<>h THEN RAISE EXCEPTION 'New backup not idempotent';END IF;
 CREATE TEMP TABLE restored_delivery_v387(LIKE lts_account_reminder_private_v387.delivery INCLUDING ALL);
 INSERT INTO restored_delivery_v387 SELECT * FROM jsonb_populate_recordset(NULL::lts_account_reminder_private_v387.delivery,r#>'{modern,tables,lts_account_reminder_private_v387.delivery}');
 IF(SELECT message_id FROM restored_delivery_v387)<>'accounts-three'THEN RAISE EXCEPTION 'Typed journal recovery failed';END IF;
 IF(SELECT count(*)FROM lts_account_reminder_private_v387.delivery)<>2 OR(SELECT count(*)FROM lts_cash_alert_private_v377.delivery)<>2 THEN RAISE EXCEPTION 'Journal source mutated';END IF;
 IF(SELECT count(*)FROM cron.job)<>1 OR(SELECT schedule FROM cron.job WHERE jobid=1)<>'15 6 * * *'OR(SELECT active FROM cron.job WHERE jobid=1)IS NOT true THEN RAISE EXCEPTION 'Backup schedule changed';END IF;
END $test$;
SET ROLE service_role;
SELECT public.lts_backup_bundle_read_v380('00000000-0000-4000-8000-000000000003',current_date)#>>'{modern,coverage,selected_tables}'AS restricted_role_tables;
RESET ROLE;
SELECT jsonb_build_object('version',387,'backup_journals_pass',true,'archived_29_preserved',true,'new_selected_tables',31,'source_finances_changed',false,'full_restore_tested',false);
