CREATE OR REPLACE FUNCTION public.lts_backup_export_v1(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
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
 'integrity',public.lts_integrity_gate_diagnostic_v1(p_user_id),
 'guardrail','Backup export contains financial data and must be stored securely. Private document binaries remain in Storage and are referenced through source-document metadata rather than embedded.'
);
$function$;
