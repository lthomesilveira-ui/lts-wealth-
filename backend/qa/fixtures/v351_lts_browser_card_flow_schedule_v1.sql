CREATE OR REPLACE FUNCTION public.lts_browser_card_flow_schedule_v1(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE v269_revision text;
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_flow jsonb;
  v_events jsonb;
begin
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
  if p_from is null or p_to is null or p_from>p_to then
    raise exception 'invalid card flow range';
  end if;
  v_flow := case when p_from>=current_date and p_to+30<=current_date+1800
    then public.lts_flow_future_read_slice_v9(v_uid,p_from,p_to)
    else public.lts_daily_flow_fix86_v12(v_uid,p_from,p_to) end;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'event_date',x->>'event_date',
      'account',x->>'account',
      'description',x->>'description',
      'card_name',coalesce(x->>'counterparty',x->>'description'),
      'amount',abs((x->>'signed_amount')::numeric),
      'source',x->>'source',
      'source_ref',x->>'source_ref',
      'confidence',x->>'confidence'
    )
    order by x->>'event_date',x->>'description'
  ),'[]'::jsonb)
  into v_events
  from jsonb_array_elements(coalesce(v_flow->'events','[]'::jsonb)) x
  where (x->>'signed_amount')::numeric<0
    and (
      coalesce(x->>'category','') in ('Cartões','Cartão de Crédito')
      or coalesce(x->>'description','') ~* '(Aeternum|Mastercard|Personnalit|Cart[aã]o C6|C6 Carbon|Visa Infinite)'
    );

  RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,jsonb_build_object(
    'version','card-flow-schedule-v1',
    'from',p_from,
    'to',p_to,
    'events',v_events
  ));
end
$function$
