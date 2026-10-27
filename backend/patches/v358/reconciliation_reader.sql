DO $lease$
DECLARE t regprocedure:='public.lts_cipo_reconciliation_v4(uuid)'::regprocedure;d text;a jsonb;
BEGIN
 SELECT pg_get_functiondef(oid),to_jsonb(p)-'prosrc'INTO d,a FROM pg_proc p WHERE oid=t;
 IF md5(d)<>'3943928840d792c2537403b94a23cd4f'THEN RAISE EXCEPTION 'V358_READER_SOURCE_CHANGED';END IF;
 EXECUTE $definition$CREATE OR REPLACE FUNCTION public.lts_cipo_reconciliation_v4(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  j jsonb;
  v_target numeric;
  v_staged numeric;
  v_missing numeric;
  v_rows int;
begin
  j:=public.lts_cipo_reconciliation_v4_legacy(p_user_id);
  select coalesce(t.target_amount,0),
         coalesce((select sum(s.amount) from public.lts_card_history_recovery_staging s
                   where s.user_id=p_user_id and s.invoice_due_date=date '2024-08-15' and s.billing_family_key='c6_legacy_group'),0),
         coalesce((select count(*) from public.lts_card_history_recovery_staging s
                   where s.user_id=p_user_id and s.invoice_due_date=date '2024-08-15' and s.billing_family_key='c6_legacy_group'),0)
  into v_target,v_staged,v_rows
  from public.lts_card_history_recovery_target t
  where t.user_id=p_user_id and t.invoice_due_date=date '2024-08-15' and t.billing_family_key='c6_legacy_group'
  limit 1;
  v_missing:=round(v_target-v_staged,2);

  j:=jsonb_set(j,'{c6_aug_2024_recovery,status}',to_jsonb(case when abs(v_missing)<=0.005 then 'certified_cycle' else 'partial_line_recovery' end::text),true);
  j:=jsonb_set(j,'{c6_aug_2024_recovery,guardrail}',to_jsonb(case when abs(v_missing)<=0.005
    then 'Ciclo documental fechado ao centavo; preservar as linhas fonte e não reabrir sem evidência conflitante.'
    else 'Não promover o ciclo inteiro enquanto a diferença total não for zero.'
  end::text),true);
  j:=jsonb_set(j,'{c6_aug_2024_recovery,staged_rows}',to_jsonb(v_rows),true);
  j:=jsonb_set(j,'{c6_aug_2024_recovery,staged_total}',to_jsonb(round(v_staged,2)),true);
  j:=jsonb_set(j,'{c6_aug_2024_recovery,target_total}',to_jsonb(round(v_target,2)),true);
  j:=jsonb_set(j,'{c6_aug_2024_recovery,missing_total}',to_jsonb(v_missing),true);
  return public.lts_cipo_consortium_presentation_v358(j,public.lts_cipo_consortium_source_v358(p_user_id));
end
$function$
$definition$;
 IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid=t)
 THEN RAISE EXCEPTION 'V358_READER_ATTRIBUTES_CHANGED';END IF;
END $lease$;
