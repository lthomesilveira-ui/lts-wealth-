CREATE OR REPLACE FUNCTION public.lts_browser_invoice_flow_reconciliation_v183(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid:=public.lts_browser_assert_user_v1();
  v_result jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to
     or p_from<date '2013-10-10' or p_to>current_date+interval '730 days'
     or p_to-p_from>1095 then
    raise exception 'invalid invoice reconciliation range';
  end if;

  with invoices as materialized (
    select ci.*,
      ci.card_name||'|'||to_char(ci.reference_month,'YYYY-MM') expected_ref,
      public.lts_card_family_key_v181(ci.card_name,null) family_key
    from public.card_invoices ci
    where ci.user_id=v_uid
      and ci.due_date between p_from and p_to
      and (ci.status in ('closed','open') or (ci.status='projected' and ci.source<>'derived_installments'))
  ), flow as materialized (
    select * from public.lts_corrected_cashflow_fix86_v5(v_uid,p_from,p_to)
  ), reconciled as (
    select i.id,i.card_name,i.reference_month,i.due_date,i.status,i.amount,i.source,
      i.expected_ref,i.family_key,
      count(*) filter(where f.source in ('card_invoice','confirmed_fact') and f.source_ref=i.expected_ref and f.event_date=i.due_date and f.signed_amount<0 and public.lts_card_family_key_v181(f.description,f.account)=i.family_key) invoice_event_count,
      coalesce(sum(abs(f.signed_amount)) filter(where f.source in ('card_invoice','confirmed_fact') and f.source_ref=i.expected_ref and f.event_date=i.due_date and f.signed_amount<0 and public.lts_card_family_key_v181(f.description,f.account)=i.family_key),0) flow_amount,
      count(*) filter(where f.source='legacy_fix86'
        and date_trunc('month',f.event_date)::date=i.reference_month
        and i.family_key is not null
        and public.lts_card_family_key_v181(f.description,f.account)=i.family_key) legacy_conflict_count
    from invoices i
    left join flow f on (f.source in ('card_invoice','confirmed_fact') and f.source_ref=i.expected_ref and f.event_date=i.due_date and f.signed_amount<0 and public.lts_card_family_key_v181(f.description,f.account)=i.family_key)
      or (f.source='legacy_fix86' and date_trunc('month',f.event_date)::date=i.reference_month
        and i.family_key is not null
        and public.lts_card_family_key_v181(f.description,f.account)=i.family_key)
    group by i.id,i.card_name,i.reference_month,i.due_date,i.status,i.amount,i.source,
      i.expected_ref,i.family_key
  ), classified as (
    select r.*,
      round(r.flow_amount-r.amount,2) difference,
      case
        when r.family_key is null then 'card_identity_pending'
        when r.invoice_event_count<>1 then 'invoice_event_count_mismatch'
        when r.legacy_conflict_count<>0 then 'legacy_projection_conflict'
        when abs(r.flow_amount-r.amount)>0.02 then 'amount_mismatch'
        else 'reconciled'
      end reconciliation_status
    from reconciled r
  )
  select jsonb_build_object(
    'version','invoice-flow-reconciliation-v182-confirmed-fact',
    'from',p_from,'to',p_to,
    'row_count',(select count(*) from classified),
    'reconciled_count',(select count(*) from classified where reconciliation_status='reconciled'),
    'issue_count',(select count(*) from classified where reconciliation_status<>'reconciled'),
    'rows',coalesce((select jsonb_agg(jsonb_build_object(
      'id',id,'card_name',card_name,'reference_month',reference_month,'due_date',due_date,
      'invoice_status',status,'documented_amount',amount,'flow_amount',flow_amount,
      'difference',difference,'reconciliation_status',reconciliation_status,
      'invoice_event_count',invoice_event_count,'legacy_conflict_count',legacy_conflict_count,
      'source_ref',expected_ref,'detail_available',true
    ) order by due_date,card_name) from classified),'[]'::jsonb)
  ) into v_result;

  return v_result;
end
$function$;

revoke all on function public.lts_browser_invoice_flow_reconciliation_v183(date,date) from public, anon;
grant execute on function public.lts_browser_invoice_flow_reconciliation_v183(date,date) to authenticated;
