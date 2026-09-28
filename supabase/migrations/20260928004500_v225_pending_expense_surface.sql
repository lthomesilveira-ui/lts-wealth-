-- Live provisional view only: no promotion, cache mutation or extra cash obligation.
CREATE OR REPLACE FUNCTION public.lts_browser_open_finance_pending_v225(p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo'
AS $function$
declare u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
  with rows as materialized (
    select s.institution_code,s.provider_record_id,s.posting_date,s.signed_amount,s.description_raw,
      s.normalized_payload->>'last4' last4
    from public.lts_open_finance_staging s
    where s.user_id=u and s.institution_code in ('341','237','336') and s.resource_type='card_transaction'
      and s.normalized_payload->>'status'='PENDING' and s.posting_date>date '2026-09-22'
      and s.posting_date between p_from and least(p_to,current_date)
  ), banks as (
    select institution_code,count(*) count,
      coalesce(sum(-signed_amount) filter(where signed_amount<0),0) gross_expense,
      coalesce(sum(signed_amount) filter(where signed_amount>0),0) credits,-sum(signed_amount) net_expense
    from rows group by institution_code
  ) select jsonb_build_object('version','pending-expense-v225','from',p_from,'to',p_to,
    'treatment','provisional_expense_until_provider_update','computed_at',clock_timestamp(),
    'transaction_count',(select count(*) from rows),'net_expense',(select coalesce(-sum(signed_amount),0) from rows),
    'banks',coalesce((select jsonb_agg(to_jsonb(b) order by b.institution_code) from banks b),'[]'::jsonb),
    'rows',coalesce((select jsonb_agg(jsonb_build_object('key',institution_code||':'||provider_record_id,
      'institution_code',institution_code,'date',posting_date,'description',description_raw,'last4',last4,
      'expense',-signed_amount,'provider_status','PENDING') order by posting_date desc,institution_code,provider_record_id) from rows),'[]'::jsonb),
    'creates_cash_obligation',false) into result;
  return result;
end
$function$;
REVOKE ALL ON FUNCTION public.lts_browser_open_finance_pending_v225(date,date) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_open_finance_pending_v225(date,date) TO authenticated,service_role;
