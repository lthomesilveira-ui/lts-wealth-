\set ON_ERROR_STOP on
-- Schema fixtures only. These checks do not certify production recovery or a private session.
set timezone='America/Sao_Paulo';
do $test$
declare u uuid:='00000000-0000-4000-8000-000000000001';v jsonb; b jsonb; h text; n int;
begin
 if has_function_privilege('anon','public.lts_backup_modern_export_v380(uuid)','EXECUTE')
 or has_function_privilege('authenticated','public.lts_backup_snapshot_take_v380(uuid,date)','EXECUTE')
 or has_function_privilege('authenticated','public.lts_backup_bundle_read_v380(uuid,date)','EXECUTE')
 then raise exception 'untrusted function access';end if;
 if has_table_privilege('anon','public.lts_backup_supplement_v380','SELECT')
 or has_table_privilege('authenticated','public.lts_backup_supplement_v380','SELECT')
 or has_table_privilege('service_role','public.lts_backup_supplement_v380','UPDATE')
 then raise exception 'unexpected table privilege';end if;
 if not (select relrowsecurity from pg_class where oid='public.lts_backup_supplement_v380'::regclass)
 then raise exception 'RLS missing';end if;
 if (select count(*) from cron.job)<>1 or (select schedule from cron.job where jobid=1)<>'15 6 * * *'
 or (select active from cron.job where jobid=1) is not true
 or (select command from cron.job where jobid=1) not like '%lts_backup_snapshot_take_v380(%'
 then raise exception 'cron changed outside writer';end if;
 begin perform public.lts_backup_snapshot_take_v380(null);raise exception 'null accepted';
 exception when others then if sqlerrm<>'user required' then raise;end if;end;
 begin perform public.lts_backup_snapshot_take_v380(u,current_date-1);raise exception 'past accepted';
 exception when others then if sqlerrm<>'snapshot date must be today' then raise;end if;end;
 begin perform public.lts_backup_snapshot_take_v380('00000000-0000-4000-8000-000000000099');raise exception 'unknown accepted';
 exception when others then if sqlerrm<>'unknown user' then raise;end if;end;
 v:=public.lts_backup_snapshot_take_v380(u);
 if v->>'inserted'<>'true' or v#>>'{counts,lts_v178_review_decision}'<>'1' then raise exception 'first capture failed';end if;
 h:=v->>'payload_sha256';
 v:=public.lts_backup_snapshot_take_v380(u);
 if v->>'inserted'<>'false' or v->>'payload_sha256'<>h then raise exception 'not idempotent';end if;
 if (select count(*) from public.lts_backup_supplement_v380)<>1 then raise exception 'duplicate capture';end if;
 b:=public.lts_backup_bundle_read_v380(u,current_date);
 if b->>'format'<>'lts-recovery-bundle-v380' or b#>>'{manifest,legacy_restore_compatible}'<>'false'
 or b#>>'{manifest,full_restore_tested}'<>'false' or b#>>'{manifest,single_transactional_snapshot}'<>'false'
 then raise exception 'incorrect recovery contract';end if;
 if b#>>'{modern,tables,lts_v178_review_decision,0,source_ref}'<>'one' then raise exception 'owner isolation';end if;
 begin perform public.lts_backup_bundle_read_v380('00000000-0000-4000-8000-000000000002',current_date);raise exception 'absent accepted';
 exception when others then if sqlerrm<>'modern backup not found' then raise;end if;end;
 -- Subtransactions roll back each corruption after its expected rejection.
 begin
  update public.lts_backup_supplement_v380 set payload=payload||'{"changed":true}'::jsonb where user_id=u;
  perform public.lts_backup_bundle_read_v380(u,current_date);raise exception 'modern corruption accepted';
 exception when others then if sqlerrm<>'modern backup integrity mismatch' then raise;end if;end;
 begin
  update public.lts_backup_snapshot set payload=payload||'{"changed":true}'::jsonb where user_id=u;
  perform public.lts_backup_bundle_read_v380(u,current_date);raise exception 'legacy corruption accepted';
 exception when others then if sqlerrm<>'legacy backup integrity mismatch' then raise;end if;end;
 begin
  update public.lts_backup_supplement_v380 set counts='{}'::jsonb where user_id=u;
  perform public.lts_backup_bundle_read_v380(u,current_date);raise exception 'manifest corruption accepted';
 exception when others then if sqlerrm<>'modern backup manifest mismatch' then raise;end if;end;
 perform public.lts_backup_bundle_read_v380(u,current_date);
 -- Restore an archived classification into a native temporary table, not the source.
 create temporary table restored_review (like public.lts_v178_review_decision including all) on commit drop;
 insert into restored_review select * from jsonb_populate_recordset(null::public.lts_v178_review_decision,b#>'{modern,tables,lts_v178_review_decision}');
 if (select count(*) from restored_review)<>1 or (select category_label from restored_review)<>'Presentes'
 then raise exception 'typed restore failed';end if;
end $test$;
-- Use the restricted writer role, with no synthetic JWT or private HTTP session.
set role service_role;
select public.lts_backup_snapshot_take_v380('00000000-0000-4000-8000-000000000002',current_date) as restricted_writer_capture;
reset role;
do $test$
begin
 if (select count(*) from public.lts_backup_supplement_v380)<>2 then raise exception 'restricted writer failed';end if;
 if (select count(*) from public.lts_v178_review_decision)<>2 then raise exception 'source rows changed';end if;
end $test$;
select 'PASS: backup V380 role boundaries, owner scopes, idempotency, integrity rejections, typed component recovery and cron preservation' as result;
