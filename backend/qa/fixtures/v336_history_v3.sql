CREATE OR REPLACE FUNCTION public.lts_historical_effective_cash_v3(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean, internal_transfer boolean, category text, counterparty text, center_cost text, excluded_from_spend boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
select e.event_date,e.account,e.description,e.signed_amount,e.source,e.source_ref,e.confidence,e.account_assignment,e.legacy_index,e.original_date,e.displaced,e.internal_transfer,
       case when e.source='legacy_fix86' then coalesce(nullif(s.category_candidate,''),nullif(s.category_raw,''),e.category) else e.category end category,
       case when e.source='legacy_fix86' then coalesce(nullif(s.counterparty_candidate,''),e.counterparty) else e.counterparty end counterparty,
       case when e.source='legacy_fix86' then coalesce(nullif(s.center_cost_candidate,''),e.center_cost) else e.center_cost end center_cost,
       case when e.source='legacy_fix86' then coalesce(s.exclude_from_spend,e.excluded_from_spend) else e.excluded_from_spend end excluded_from_spend
from public.lts_historical_effective_cash_v2(p_user_id,p_from,p_to) e
left join lateral (
  select r.category_candidate,r.category_raw,r.counterparty_candidate,r.center_cost_candidate,r.exclude_from_spend
  from public.lts_expense_realized r
  where r.user_id=p_user_id and r.source_table='evento_base' and r.source_ref=split_part(e.source_ref,':',2)
  limit 1
) s on e.source='legacy_fix86';
$function$
