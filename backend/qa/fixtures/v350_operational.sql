CREATE OR REPLACE FUNCTION public.lts_corrected_cashflow_operational_v1(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with raw as materialized (
  select * from public.lts_corrected_cashflow_fix86_v5(p_user_id,p_from,p_to)
), wh as materialized (
  select * from public.lts_payroll_withholding_effective_v1(p_user_id,p_from,p_to)
)
select r.event_date,
       case when r.account='Itau' then 'Itaú' else r.account end account,
       case when lower(trim(r.description))='salário' and r.signed_amount>0 and coalesce(w.amount,0)<0 then 'Salário líquido' else r.description end description,
       case when lower(trim(r.description))='salário' and r.signed_amount>0 then r.signed_amount+coalesce(w.amount,0) else r.signed_amount end signed_amount,
       r.source,r.source_ref,r.confidence,r.account_assignment,r.legacy_index,r.original_date,r.displaced
from raw r
left join wh w on lower(trim(r.description))='salário' and r.signed_amount>0 and w.salary_source_ref=r.source_ref
where r.source<>'economic_withholding';
$function$

