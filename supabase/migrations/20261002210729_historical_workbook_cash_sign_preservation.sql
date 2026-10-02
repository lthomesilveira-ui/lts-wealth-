-- Correct only individually corroborated saved historical cash signs.
-- Original workbooks, imported events, spending classifications and documented
-- bank positions are never changed. User operations and the app era are protected.
CREATE OR REPLACE FUNCTION public.lts_corrected_cashflow_fix86_v4(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with base_pre as (
 select f.event_date,f.account,f.description,coalesce(bo.amount,f.signed_amount) signed_amount,
        case when c.id is not null then 'confirmed_fact' else f.source end source,
        f.source_ref,
        case when bo.amount is not null then 'bank_documented_settlement_precedence'
             when c.id is not null then 'user_confirmed_fact'
             when f.source='current_event' and exists(
               select 1 from public.financial_events fe
               where fe.user_id=p_user_id and coalesce(fe.legacy_id,fe.id::text)=f.source_ref
                 and fe.event_date>=current_date
                 and coalesce(fe.status,'') in ('scheduled','expected')
                 and coalesce(fe.is_suppressed,false)=false
                 and coalesce(fe.is_internal_transfer,false)=false
                 and not exists(select 1 from public.lts_fact_confirmation fc where fc.user_id=p_user_id and fc.source_ref=coalesce(fe.legacy_id,fe.id::text))
             ) then 'user_flow_editable'
             else f.confidence end confidence,
        f.account_assignment,f.legacy_index,f.original_date,f.displaced
 from public.lts_corrected_cashflow_fix86_v3(p_user_id,p_from,p_to) f
 left join lateral (
   select min(ev.amount) amount
   from public.lts_reconciliation_evidence ev
   join public.lts_open_finance_staging st
     on st.user_id=ev.user_id and st.id::text=ev.metadata->>'bank_staging_id'
    and st.raw_hash=ev.metadata->>'bank_raw_hash' and st.provider_deleted_at is null
    and st.institution_code='336' and f.account='C6' and ev.account='C6'
   where ev.user_id=p_user_id and ev.status='documented'
     and ev.evidence_type='card_invoice_payment'
     and ev.metadata->>'cash_effect'='replace_existing_payment_amount'
     and ev.metadata->>'target_flow_source_ref'=f.source_ref
     and (ev.metadata->>'original_signed_amount')::numeric=f.signed_amount
     and ev.evidence_date=f.event_date and ev.account=f.account
     and ev.amount<0 and st.normalized_payload->>'layer'='card_invoice_obligation'
     and st.normalized_payload->>'currency'='BRL'
     and (st.normalized_payload->>'amount')::numeric=-ev.amount
     and exists (
       select 1 from jsonb_array_elements(coalesce(st.normalized_payload->'payments','[]'::jsonb)) pay
       where pay->>'id'=ev.metadata->>'bank_payment_id'
         and (pay->>'amount')::numeric=-ev.amount
         and left(pay->>'paymentDate',10)::date=f.event_date
         and pay->>'currencyCode'='BRL'
     )
   having count(*)=1
 ) bo on true
 left join public.lts_fact_confirmation c
   on c.user_id=p_user_id and c.source_ref=f.source_ref
  and c.event_date=f.event_date
  and (c.signed_amount is null or c.signed_amount=f.signed_amount)
), base as (
 select b.* from base_pre b
 where not (
   b.source='current_event'
   and exists (
     select 1 from public.financial_events fe
     join public.lts_flow_event_operation o on o.user_id=p_user_id and o.target_event_id=fe.id and o.active
     where fe.user_id=p_user_id and coalesce(fe.legacy_id,fe.id::text)=b.source_ref
   )
 )
), operated_current as (
 select e.event_date,e.account,e.description,e.signed_amount,'current_event'::text source,e.source_ref,'user_flow_editable'::text confidence,e.account_assignment,e.legacy_index,e.original_date,e.displaced
 from public.lts_flow_current_effective_v1(p_user_id,p_from,p_to) e
 where exists (
   select 1 from public.financial_events fe
   join public.lts_flow_event_operation o on o.user_id=p_user_id and o.target_event_id=fe.id and o.active
   where fe.user_id=p_user_id and coalesce(fe.legacy_id,fe.id::text)=e.source_ref
 )
)
select b.event_date,b.account,b.description,coalesce(ws.amount,b.signed_amount),b.source,b.source_ref,
 case when ws.amount is not null then 'historical_workbook_cash_sign_preserved' else b.confidence end,
 b.account_assignment,b.legacy_index,b.original_date,b.displaced
from base b
left join lateral (
 select min(ev.amount) amount
 from public.lts_reconciliation_evidence ev
 where ev.user_id=p_user_id and ev.status='documented'
   and ev.evidence_type='historical_workbook_cash_sign'
   and ev.metadata->>'cash_effect'='replace_existing_signed_cash'
   and ev.metadata->>'target_flow_source_ref'=b.source_ref
   and (ev.metadata->>'original_signed_cash')::numeric=b.signed_amount
   and ev.amount=-b.signed_amount and b.source='legacy_fix86'
   and b.event_date=ev.evidence_date and b.event_date=b.original_date
   and b.event_date<date '2026-07-08' and not b.displaced
   and translate(lower(ev.account),'ú','u')=translate(lower(b.account),'ú','u')
   and ev.metadata->>'original_description'=b.description
   and jsonb_typeof(ev.metadata->'workbook_evidence')='array'
   and jsonb_array_length(ev.metadata->'workbook_evidence')=2
   and not exists (
     select 1 from public.projecao_op op where op.usuario_id=p_user_id
       and coalesce(op.dados->>'status','ativa')='ativa' and nullif(op.dados->>'revertidaEm','') is null
       and (op.dados->>'dia')::date=b.original_date
       and lower(trim(op.dados->>'desc'))=lower(trim(b.description))
       and translate(lower(op.dados->>'conta'),'ú','u')=translate(lower(b.account),'ú','u')
   )
 having count(*)=1
) ws on true
union all
select * from operated_current;
$function$;

CREATE OR REPLACE FUNCTION public.lts_operational_source_key_v238(p_user_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
SELECT md5(jsonb_build_object(
 'financial_events',(SELECT md5(coalesce(string_agg(to_jsonb(f)::text,'|' ORDER BY f.id),'empty')) FROM public.financial_events f WHERE f.user_id=p_user_id),
 'accounts',(SELECT md5(coalesce(string_agg(to_jsonb(a)::text,'|' ORDER BY a.id),'empty')) FROM public.accounts a WHERE a.user_id=p_user_id),
 'semantic_rules',(SELECT md5(coalesce(string_agg(to_jsonb(r)::text,'|' ORDER BY r.id),'empty')) FROM public.lts_semantic_rule r WHERE r.user_id=p_user_id),
 'historical_rows',(SELECT md5(coalesce(string_agg(to_jsonb(h)::text,'|' ORDER BY to_jsonb(h)::text),'empty')) FROM public.historico_analitico h WHERE h.usuario_id=p_user_id),
 'legacy_rows',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY to_jsonb(e)::text),'empty')) FROM public.evento_base e WHERE e.usuario_id=p_user_id),
 'historical_cash_sign_evidence',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY e.id),'empty')) FROM public.lts_reconciliation_evidence e WHERE e.user_id=p_user_id AND e.evidence_type='historical_workbook_cash_sign'),
 'source_signs',(SELECT md5(coalesce(string_agg(to_jsonb(s)::text,'|' ORDER BY to_jsonb(s)::text),'empty')) FROM public.lts_card_history_source_audit_v235 s WHERE s.user_id=p_user_id)
)::text)
$function$;
