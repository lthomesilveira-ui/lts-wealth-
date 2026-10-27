CREATE OR REPLACE FUNCTION public.lts_payroll_withholding_effective_v1(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(schedule_due_date date, effective_event_date date, amount numeric, salary_source_ref text, salary_original_date date, source text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with corrected as materialized (select * from public.lts_corrected_cashflow_fix86_v4(p_user_id,(p_from-45)::date,(p_to+45)::date)), salary as materialized (
  select r.event_date,r.original_date,r.source_ref
  from corrected r
  where r.signed_amount>0 and lower(trim(r.description))='salário'
), doc as (
  select d.due_date,-abs(d.amount_total)::numeric amt
  from public.lts_commitment_documentary_schedule d
  where d.user_id=p_user_id and d.commitment_id='coopharma'
    and d.due_date between (p_from-45)::date and (p_to+45)::date
), mapped_doc as (
  select d.due_date schedule_due_date,
         coalesce(s.event_date,d.due_date) effective_event_date,
         d.amt amount,
         s.source_ref salary_source_ref,
         s.original_date salary_original_date,
         'documented_coopharma_schedule'::text source
  from doc d
  left join lateral (
    select x.* from salary x
    where x.original_date=d.due_date
       or date_trunc('month',x.original_date)=date_trunc('month',d.due_date)
    order by case when x.original_date=d.due_date then 0 else 1 end,
             abs(x.original_date-d.due_date),x.event_date
    limit 1
  ) s on true
), legacy as (
  select r.original_date schedule_due_date,
         r.event_date effective_event_date,
         sum(r.signed_amount)::numeric amount,
         null::text salary_source_ref,
         r.original_date salary_original_date,
         'legacy_economic_withholding'::text source
  from corrected r
  where r.source='economic_withholding'
    and not exists(select 1 from doc d where d.due_date=r.original_date or date_trunc('month',d.due_date)=date_trunc('month',r.original_date))
  group by r.original_date,r.event_date
)
select * from mapped_doc where effective_event_date between p_from and p_to
union all
select * from legacy where effective_event_date between p_from and p_to;
$function$

