-- V380: additive, owner-scoped daily backup supplement. No financial source writes.
create table if not exists public.lts_backup_supplement_v380 (
 user_id uuid not null,
 snapshot_date date not null,
 legacy_payload_hash text not null,
 legacy_sha256 text not null,
 legacy_created_at timestamptz not null,
 payload jsonb not null,
 payload_sha256 text not null,
 payload_bytes bigint not null check(payload_bytes>0),
 counts jsonb not null,
 created_at timestamptz not null default now(),
 primary key(user_id,snapshot_date),
 foreign key(user_id,snapshot_date) references public.lts_backup_snapshot(user_id,snapshot_date),
 check(payload->>'format'='lts-modern-supplement-v380'),
 check(payload->>'user_id'=user_id::text)
);
alter table public.lts_backup_supplement_v380 enable row level security;
revoke all on public.lts_backup_supplement_v380 from public,anon,authenticated,service_role;
grant select,insert on public.lts_backup_supplement_v380 to service_role;

create or replace function public.lts_backup_modern_export_v380(p_user_id uuid)
returns jsonb language sql stable security invoker set search_path=pg_catalog,public
as $fn$
select jsonb_build_object('format','lts-modern-supplement-v380','user_id',p_user_id,
 'captured_at',statement_timestamp(),'tables',jsonb_build_object(
'lts_brokerage_position_snapshots',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_brokerage_position_snapshots" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_brokerage_reference_v352',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_brokerage_reference_v352" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_card_documentary_payment_link_v272',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_card_documentary_payment_link_v272" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_card_due_rule_v290',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."family",t."effective_from") from public."lts_card_due_rule_v290" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_card_due_transition_v370',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."family") from public."lts_card_due_transition_v370" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_card_history_item_v346',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."source_hash",t."source_sheet",t."source_row") from public."lts_card_history_item_v346" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_card_history_parent_v346',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."parent_key") from public."lts_card_history_parent_v346" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_card_instruments',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_card_instruments" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_card_settlement_expense_contract_v273',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."payment_source_id") from public."lts_card_settlement_expense_contract_v273" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_category_alias',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."alias") from public."lts_category_alias" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_category_binding_v290',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."source_table",t."source_ref",t."raw_category") from public."lts_category_binding_v290" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_category_catalog',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."category_key") from public."lts_category_catalog" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_commitment_documentary_schedule',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_commitment_documentary_schedule" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_debt_position',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_debt_position" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_expense_documentary_amount_override',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_expense_documentary_amount_override" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_future_liquidity_schedule',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_future_liquidity_schedule" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_liquidity_movement',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_liquidity_movement" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_open_finance_staging',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_open_finance_staging" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_projection_replacement_rule',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_projection_replacement_rule" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_realized_bank_event_v238',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."financial_event_id") from public."lts_realized_bank_event_v238" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_reconciliation_link',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_reconciliation_link" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_recurring_occurrence_v366',coalesce((select jsonb_agg(to_jsonb(t) order by t."plan_id",t."revision",t."event_date") from public."lts_recurring_occurrence_v366" t where exists(select 1 from public.lts_recurring_plan_v366 p where p.id=t.plan_id and p.user_id=p_user_id)),'[]'::jsonb),
'lts_recurring_plan_v366',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_recurring_plan_v366" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_semantic_rule',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_semantic_rule" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_v178_review_decision',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."source_table",t."source_ref") from public."lts_v178_review_decision" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_v229_card_recurring_commitment',coalesce((select jsonb_agg(to_jsonb(t) order by t."user_id",t."family",t."description") from public."lts_v229_card_recurring_commitment" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_open_finance_connection',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_open_finance_connection" t where t.user_id=p_user_id),'[]'::jsonb),
'lts_open_finance_sync_run',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."lts_open_finance_sync_run" t where t.user_id=p_user_id and exists(select 1 from public.lts_open_finance_staging s where s.user_id=p_user_id and s.sync_run_id=t.id)),'[]'::jsonb),
'usuario',coalesce((select jsonb_agg(to_jsonb(t) order by t."id") from public."usuario" t where t.id=p_user_id),'[]'::jsonb)),
 'coverage',jsonb_build_object('selected_tables',29,'all_application_tables',false,
  'complete_schema_roles_auth',false,'storage_binaries',false,'full_restore_tested',false,
  'sync_history_scope','Only runs referenced by preserved staging records'),
 'schema_columns',(select coalesce(jsonb_agg(to_jsonb(c) order by c.table_name,c.ordinal_position),'[]'::jsonb)
 from information_schema.columns c where c.table_schema='public' and c.table_name in ('lts_brokerage_position_snapshots','lts_brokerage_reference_v352','lts_card_documentary_payment_link_v272','lts_card_due_rule_v290','lts_card_due_transition_v370','lts_card_history_item_v346','lts_card_history_parent_v346','lts_card_instruments','lts_card_settlement_expense_contract_v273','lts_category_alias','lts_category_binding_v290','lts_category_catalog','lts_commitment_documentary_schedule','lts_debt_position','lts_expense_documentary_amount_override','lts_future_liquidity_schedule','lts_liquidity_movement','lts_open_finance_staging','lts_projection_replacement_rule','lts_realized_bank_event_v238','lts_reconciliation_link','lts_recurring_occurrence_v366','lts_recurring_plan_v366','lts_semantic_rule','lts_v178_review_decision','lts_v229_card_recurring_commitment','lts_open_finance_connection','lts_open_finance_sync_run','usuario')));
$fn$;
revoke all on function public.lts_backup_modern_export_v380(uuid) from public,anon,authenticated;
grant execute on function public.lts_backup_modern_export_v380(uuid) to service_role;

create or replace function public.lts_backup_bundle_read_v380(p_user_id uuid,p_snapshot_date date)
returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public
as $fn$
declare s public.lts_backup_supplement_v380%rowtype; b public.lts_backup_snapshot%rowtype; v_counts jsonb;
begin
 select * into s from public.lts_backup_supplement_v380 where user_id=p_user_id and snapshot_date=p_snapshot_date;
 if not found then raise exception 'modern backup not found'; end if;
 select * into b from public.lts_backup_snapshot where user_id=p_user_id and snapshot_date=p_snapshot_date;
 if not found then raise exception 'legacy backup not found'; end if;
 if b.payload_hash is distinct from s.legacy_payload_hash or md5(b.payload::text) is distinct from s.legacy_payload_hash
 or encode(sha256(convert_to(b.payload::text,'UTF8')),'hex') is distinct from s.legacy_sha256
 or octet_length(convert_to(b.payload::text,'UTF8')) is distinct from b.payload_bytes
 then raise exception 'legacy backup integrity mismatch'; end if;
 if encode(sha256(convert_to(s.payload::text,'UTF8')),'hex') is distinct from s.payload_sha256
 or octet_length(convert_to(s.payload::text,'UTF8'))::bigint is distinct from s.payload_bytes
 then raise exception 'modern backup integrity mismatch'; end if;
 if s.payload->>'format' is distinct from 'lts-modern-supplement-v380'
 or s.payload->>'user_id' is distinct from p_user_id::text
 or b.payload->>'user_id' is distinct from p_user_id::text then raise exception 'backup owner mismatch';end if;
 select jsonb_object_agg(key,jsonb_array_length(value)) into v_counts from jsonb_each(s.payload->'tables');
 if v_counts is distinct from s.counts or (select count(*) from jsonb_each(s.payload->'tables'))<>29 then raise exception 'modern backup manifest mismatch';end if;
 return jsonb_build_object('format','lts-recovery-bundle-v380','user_id',p_user_id,
 'snapshot_date',p_snapshot_date,'base',b.payload,'modern',s.payload,
 'manifest',jsonb_build_object('legacy_sha256',s.legacy_sha256,'modern_sha256',s.payload_sha256,
 'legacy_created_at',s.legacy_created_at,'modern_created_at',s.created_at,'counts',s.counts,
 'single_transactional_snapshot',false,'full_restore_tested',false,'storage_binaries',false,
 'legacy_restore_compatible',false));
end $fn$;
revoke all on function public.lts_backup_bundle_read_v380(uuid,date) from public,anon,authenticated;
grant execute on function public.lts_backup_bundle_read_v380(uuid,date) to service_role;

create or replace function public.lts_backup_snapshot_take_v380(p_user_id uuid,p_snapshot_date date default null)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public set timezone='America/Sao_Paulo'
as $fn$
declare d date:=coalesce(p_snapshot_date,current_date);s public.lts_backup_supplement_v380%rowtype;b public.lts_backup_snapshot%rowtype;j jsonb;v_counts jsonb;v_n int;
begin
 if p_user_id is null then raise exception 'user required';end if;
 if d<>current_date then raise exception 'snapshot date must be today';end if;
 if not exists(select 1 from public.usuario where id=p_user_id) then raise exception 'unknown user';end if;
 perform pg_advisory_xact_lock(hashtextextended('lts-backup-v380:'||p_user_id::text||':'||d::text,0));
 select * into s from public.lts_backup_supplement_v380 where user_id=p_user_id and snapshot_date=d;
 if found then
  perform public.lts_backup_bundle_read_v380(p_user_id,d);
  return jsonb_build_object('ok',true,'inserted',false,'snapshot_date',d,'payload_sha256',s.payload_sha256,'payload_bytes',s.payload_bytes,'counts',s.counts);
 end if;
 perform public.lts_backup_snapshot_take_v1(p_user_id,d);
 select * into strict b from public.lts_backup_snapshot where user_id=p_user_id and snapshot_date=d;
 if b.payload_hash is distinct from md5(b.payload::text) then raise exception 'legacy backup integrity mismatch';end if;
 j:=public.lts_backup_modern_export_v380(p_user_id);
 select jsonb_object_agg(key,jsonb_array_length(value)),count(*) into v_counts,v_n from jsonb_each(j->'tables');
 if v_n<>29 then raise exception 'incomplete modern backup';end if;
 insert into public.lts_backup_supplement_v380(user_id,snapshot_date,legacy_payload_hash,legacy_sha256,legacy_created_at,payload,payload_sha256,payload_bytes,counts)
 values(p_user_id,d,b.payload_hash,encode(sha256(convert_to(b.payload::text,'UTF8')),'hex'),b.created_at,j,
 encode(sha256(convert_to(j::text,'UTF8')),'hex'),octet_length(convert_to(j::text,'UTF8')),v_counts)
 returning * into s;
 return jsonb_build_object('ok',true,'inserted',true,'snapshot_date',d,'payload_sha256',s.payload_sha256,'payload_bytes',s.payload_bytes,'counts',s.counts);
end $fn$;
revoke all on function public.lts_backup_snapshot_take_v380(uuid,date) from public,anon,authenticated;
grant execute on function public.lts_backup_snapshot_take_v380(uuid,date) to service_role;

do $migration$
declare j record;n int:=0;
begin
 for j in select jobid,command from cron.job where jobname='lts_daily_backup_snapshot' loop
  if j.command like '%public.lts_backup_snapshot_take_v1(%' then
   perform cron.alter_job(j.jobid,command:=replace(j.command,'public.lts_backup_snapshot_take_v1(','public.lts_backup_snapshot_take_v380('));
  elsif j.command not like '%public.lts_backup_snapshot_take_v380(%' then
   raise exception 'unexpected backup cron command; no schedule changed';
  end if;
  n:=n+1;
 end loop;
 if n<>1 then raise exception 'expected exactly one existing backup job';end if;
end $migration$;
