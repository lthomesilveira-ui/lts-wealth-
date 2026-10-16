CREATE OR REPLACE FUNCTION public.lts_open_finance_current_bank_position_v1(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with positions as (select public.lts_open_finance_checking_positions_v1(p_user_id) rows)
select jsonb_build_object('as_of',current_date,
 'accounts',(select jsonb_agg(jsonb_build_object('institution',x->>'bank',
  'institution_code',x->>'institution_code','balance',(x->>'balance')::numeric,
  'as_of',x->'as_of','source_id',x->'source_id') ORDER BY
  case x->>'institution_code' when '341' then 1 when '237' then 2 else 3 end)
  from positions,jsonb_array_elements(rows) x),
 'bank_cash',(select sum((x->>'balance')::numeric) from positions,jsonb_array_elements(rows) x),
 'source','open_finance_latest_balance','balance_basis','validated_normalized_checking_available_balance')
$function$

