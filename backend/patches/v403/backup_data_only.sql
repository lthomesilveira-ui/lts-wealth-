-- Backup data without re-running operational runtime gates or engine QA.
CREATE OR REPLACE FUNCTION public.lts_backup_data_export_v403(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY INVOKER
 SET search_path TO 'public'
AS $function$
select jsonb_build_object(
 'format','lts-backup-v1','exported_at',now(),'user_id',p_user_id,
 'checkpoint',(select to_jsonb(c) from public.lts_project_checkpoint c where id='canonical'),
 'accounts',coalesce((select jsonb_agg(to_jsonb(x)) from public.accounts x where user_id=p_user_id),'[]'::jsonb),
 'financial_events',coalesce((select jsonb_agg(to_jsonb(x)) from public.financial_events x where user_id=p_user_id),'[]'::jsonb),
 'asset_positions',coalesce((select jsonb_agg(to_jsonb(x)) from public.asset_positions x where user_id=p_user_id),'[]'::jsonb),
 'card_invoices',coalesce((select jsonb_agg(to_jsonb(x)) from public.card_invoices x where user_id=p_user_id),'[]'::jsonb),
 'source_documents',coalesce((select jsonb_agg(to_jsonb(x)) from public.source_documents x where user_id=p_user_id),'[]'::jsonb),
 'input_inbox',coalesce((select jsonb_agg(to_jsonb(x)-'storage_path') from public.lts_input_inbox x where user_id=p_user_id),'[]'::jsonb),
 'legacy',jsonb_build_object(
   'evento_base',coalesce((select jsonb_agg(to_jsonb(x)) from public.evento_base x where usuario_id=p_user_id),'[]'::jsonb),
   'evento_usuario',coalesce((select jsonb_agg(to_jsonb(x)) from public.evento_usuario x where usuario_id=p_user_id),'[]'::jsonb),
   'contrato',coalesce((select jsonb_agg(to_jsonb(x)) from public.contrato x where usuario_id=p_user_id),'[]'::jsonb),
   'compromisso',coalesce((select jsonb_agg(to_jsonb(x)) from public.compromisso x where usuario_id=p_user_id),'[]'::jsonb),
   'legacy_namespace',coalesce((select jsonb_agg(to_jsonb(x)) from public.legacy_namespace x where usuario_id=p_user_id),'[]'::jsonb)
 ),
 'integrity',jsonb_build_object('version','v403-data-backup-no-runtime-qa','diagnostics_reexecuted',false,'capture_kind',coalesce(nullif(current_setting('lts.backup_capture_kind',true),''),'unspecified'),'snapshot_isolation',current_setting('transaction_isolation'),'scope','Data integrity is checked by source counts, hashes and restoration; this backup does not certify runtime QA.'),
 'guardrail','Backup export contains financial data and must be stored securely. Private document binaries remain in Storage and are referenced through source-document metadata rather than embedded.'
);
$function$;
CREATE OR REPLACE FUNCTION public.lts_backup_data_take_v403(p_user_id uuid, p_snapshot_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_payload jsonb;
  v_hash text;
  v_bytes integer;
  v_inserted integer:=0;
begin
  if p_user_id is null then raise exception 'user required'; end if;
  v_payload:=public.lts_backup_data_export_v403(p_user_id);
  v_hash:=md5(v_payload::text);
  v_bytes:=octet_length(convert_to(v_payload::text,'UTF8'));
  insert into public.lts_backup_snapshot(user_id,snapshot_date,payload,payload_hash,payload_bytes)
  values(p_user_id,coalesce(p_snapshot_date,current_date),v_payload,v_hash,v_bytes)
  on conflict(user_id,snapshot_date) do nothing;
  get diagnostics v_inserted=row_count;
  return jsonb_build_object('ok',true,'user_id',p_user_id,'snapshot_date',coalesce(p_snapshot_date,current_date),'inserted',v_inserted,'payload_hash',v_hash,'payload_bytes',v_bytes);
end;
$function$
;
DO $patch$
DECLARE d text:=pg_get_functiondef('public.lts_backup_snapshot_take_v380(uuid,date)'::regprocedure);
BEGIN
 IF position('v403-cold-data-snapshot'IN d)>0 THEN RETURN;END IF;
 IF position('perform public.lts_backup_snapshot_take_v1(p_user_id,d);'IN d)=0 THEN RAISE EXCEPTION 'Legacy snapshot call changed';END IF;
 EXECUTE replace(d,'perform public.lts_backup_snapshot_take_v1(p_user_id,d);','-- v403-cold-data-snapshot'||chr(10)||' perform public.lts_backup_data_take_v403(p_user_id,d);');
END $patch$;
REVOKE ALL ON FUNCTION public.lts_backup_data_export_v403(uuid),public.lts_backup_data_take_v403(uuid,date)FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_backup_data_export_v403(uuid),public.lts_backup_data_take_v403(uuid,date)TO service_role;
