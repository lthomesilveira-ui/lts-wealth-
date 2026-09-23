-- Candidate-only reader for reconciled legacy invoice cycles absent from the
-- current card_invoices register. No cash, debt or card table is written.
create or replace function public.lts_browser_legacy_invoice_gap_v183(
  p_from date, p_to date
) returns jsonb
language plpgsql security definer set search_path = ''
as $fn$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_rows jsonb;
begin
  if p_from is null or p_to is null or p_from > p_to
     or p_from < date '2013-10-10' or p_to > current_date + 366
     or p_to - p_from > 731 then
    raise exception 'invalid invoice period' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'card_name', trim(r.card_name), 'due_date', r.due_date,
    'documented_amount', r.invoice_total,
    'detail_lines', r.detail_lines, 'detail_difference', r.delta,
    'bank_payment_confirmed', false,
    'purchases', coalesce((
      select jsonb_agg(jsonb_build_object(
        'date', p.purchase_date, 'description', p.description_raw,
        'amount', p.installment_amount, 'card_final', p.card_final
      ) order by p.purchase_date, p.row_id)
      from public.lts_card_purchase_detail p
      where p.user_id = v_uid and p.invoice_id = r.invoice_id
    ), '[]'::jsonb)
  ) order by r.due_date, r.card_name), '[]'::jsonb)
  into v_rows
  from public.lts_card_invoice_detail_reconciliation r
  where r.user_id = v_uid and r.due_date between p_from and p_to
    and r.reconciled is true and r.detail_lines > 0
    and public.lts_card_family_v1(r.card_name, null) is not null
    and not exists (
      select 1 from public.card_invoices c
      where c.user_id = v_uid and c.due_date = r.due_date
        and public.lts_card_family_v1(c.card_name, null) =
            public.lts_card_family_v1(r.card_name, null)
    );

  return jsonb_build_object('version', 'legacy-invoice-gap-v183',
    'financial_effect', 'none', 'invoices', v_rows);
end $fn$;

revoke all on function public.lts_browser_legacy_invoice_gap_v183(date,date)
  from public, anon, authenticated;
grant execute on function public.lts_browser_legacy_invoice_gap_v183(date,date)
  to authenticated;
