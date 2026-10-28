CREATE OR REPLACE FUNCTION public.lts_corrected_cashflow_fix86_v5(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with scan as materialized (
  select * from public.lts_corrected_cashflow_fix86_v4(p_user_id,p_from-31,p_to+31)
), shifted as (
  select
    case when s.source='card_invoice' then coalesce(nullif(ci.metadata->>'cash_effect_date','')::date,s.event_date)
         when due_rule.due_day is not null then date_trunc('month',s.event_date)::date+due_rule.due_day-1
         else s.event_date end event_date,
    s.account,s.description,s.signed_amount,s.source,s.source_ref,s.confidence,s.account_assignment,s.legacy_index,
    s.original_date,
    case when s.source='card_invoice' then coalesce(nullif(ci.metadata->>'cash_effect_date','')::date,s.event_date)<>s.event_date
         when due_rule.due_day is not null then date_trunc('month',s.event_date)::date+due_rule.due_day-1<>s.event_date
         else s.displaced end displaced
  from scan s
  left join public.card_invoices ci
    on s.source='card_invoice'
   and ci.user_id=p_user_id
   and s.source_ref=ci.card_name||'|'||to_char(ci.reference_month,'YYYY-MM')
  left join lateral (
    select r.due_day from public.lts_card_due_rule_v290 r
    where r.user_id=p_user_id and r.family='aeternum'
      and r.effective_from<=date_trunc('month',s.event_date)::date
      and s.source='legacy_fix86' and s.confidence='legacy_projection_adjusted'
      and not coalesce(s.displaced,false) and s.signed_amount<0
      and lower(trim(s.description))='visa aeternum' and s.account='Bradesco'
    order by r.effective_from desc limit 1
  ) due_rule on true
)
select * from shifted where event_date between p_from and p_to
order by event_date,source,description;
$function$
