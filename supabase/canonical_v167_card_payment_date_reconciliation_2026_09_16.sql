-- V167: confirm a paid card invoice even when the user moved the cash event
-- from the contractual due date to the actual banking date.

create or replace function public.lts_browser_confirm_card_payment_v1(
  p_update_id text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
set "TimeZone" to 'America/Sao_Paulo'
as $function$
declare
  uid uuid;
  v_email text:=lower(coalesce(auth.jwt()->>'email',''));
  v_id uuid;
  ci public.card_invoices%rowtype;
  v_ref text;
  v_account text;
  v_amount numeric;
  v_payment_date date;
  inserted_count int:=0;
  cache_result jsonb;
begin
  uid:=public.lts_browser_assert_user_v1();

  if coalesce(p_update_id,'') !~ '^card_payment_[0-9a-fA-F-]{36}$' then
    raise exception 'invalid update item';
  end if;

  v_id:=replace(p_update_id,'card_payment_','')::uuid;

  select * into ci
  from public.card_invoices
  where id=v_id
    and user_id=uid
    and status='closed'
    and due_date<=current_date;

  if not found then
    raise exception 'invoice not eligible for payment confirmation';
  end if;

  v_ref:=ci.card_name||'|'||to_char(ci.reference_month,'YYYY-MM');

  select f.event_date,f.account,f.signed_amount
    into v_payment_date,v_account,v_amount
  from public.lts_corrected_cashflow_fix86_v4(
    uid,
    ci.due_date-7,
    greatest(current_date,ci.due_date+7)
  ) f
  where f.source_ref=v_ref
    and abs(f.signed_amount+abs(ci.amount))<=0.02
  order by
    case when f.source='confirmed_fact' then 0 else 1 end,
    abs(f.event_date-ci.due_date),
    f.event_date
  limit 1;

  if v_amount is null or v_payment_date is null then
    raise exception 'invoice cash event not found';
  end if;

  insert into public.lts_fact_confirmation(
    user_id,source_ref,event_date,account,signed_amount,confirmation_source,note
  )
  values(
    uid,v_ref,v_payment_date,v_account,v_amount,
    'browser_card_payment_confirmed',nullif(trim(p_note),'')
  )
  on conflict(user_id,source_ref) do nothing;

  get diagnostics inserted_count=row_count;

  insert into public.lts_access_audit(user_id,email,action,meta)
  values(
    uid,v_email,'browser_confirm_card_payment',
    jsonb_build_object(
      'invoice_id',ci.id,
      'card_name',trim(ci.card_name),
      'due_date',ci.due_date,
      'payment_date',v_payment_date,
      'amount',ci.amount,
      'inserted_confirmation',inserted_count
    )
  );

  cache_result:=public.lts_refresh_product_read_cache_confirmation_v1(uid);

  return jsonb_build_object(
    'ok',true,
    'update_id',p_update_id,
    'invoice_id',ci.id,
    'card_name',trim(ci.card_name),
    'due_date',ci.due_date,
    'payment_date',v_payment_date,
    'amount',ci.amount,
    'inserted_confirmation',inserted_count,
    'cache',cache_result
  );
end
$function$;

revoke all on function public.lts_browser_confirm_card_payment_v1(text,text) from public,anon;
grant execute on function public.lts_browser_confirm_card_payment_v1(text,text) to authenticated;
