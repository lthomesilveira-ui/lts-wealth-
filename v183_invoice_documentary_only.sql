-- Evidence-only invoice register. Deliberately NOT card_invoices: operational
-- cash, debt, expense and forecast readers must not consume unverified evidence.
create table if not exists public.lts_invoice_documentary_only_v1 (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  bank text not null,
  card_label text not null,
  card_last4 text not null check (card_last4 ~ '^[0-9]{4}$'),
  reference_month date not null,
  due_date date not null,
  invoice_amount numeric(18,2) not null check (invoice_amount > 0),
  source_document text not null,
  purchase_date date,
  purchase_description text,
  purchase_amount numeric(18,2),
  candidate_bank_evidence_id uuid references public.lts_reconciliation_evidence(id),
  payment_proof text not null default 'not_confirmed'
    check (payment_proof = 'not_confirmed'),
  created_at timestamptz not null default now(),
  unique (user_id,bank,card_last4,due_date),
  check ((purchase_date is null and purchase_description is null and purchase_amount is null)
     or (purchase_date is not null and purchase_description is not null and purchase_amount > 0))
);

alter table public.lts_invoice_documentary_only_v1 enable row level security;
revoke all on public.lts_invoice_documentary_only_v1 from public, anon, authenticated;

-- The guarded RPC returns only evidence belonging to the logged-in user.
create or replace function public.lts_browser_invoice_documentary_only_v1()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
begin
  return jsonb_build_object(
    'version', 'invoice-documentary-only-v1',
    'financial_effect', 'none',
    'invoices', coalesce((
      select jsonb_agg(jsonb_build_object(
        'bank', i.bank,
        'card_label', i.card_label,
        'card_last4', i.card_last4,
        'reference_month', i.reference_month,
        'due_date', i.due_date,
        'invoice_amount', i.invoice_amount,
        'source_document', i.source_document,
        'purchases', case when i.purchase_amount is not null then
          jsonb_build_array(jsonb_build_object('date',i.purchase_date,
            'description',i.purchase_description,'amount',i.purchase_amount))
          else '[]'::jsonb end,
        'bank_debit_candidate', i.candidate_bank_evidence_id is not null,
        'bank_payment_confirmed', false
      ) order by i.due_date,i.bank,i.card_last4)
      from public.lts_invoice_documentary_only_v1 i where i.user_id=v_uid
    ), '[]'::jsonb)
  );
end $$;

revoke all on function public.lts_browser_invoice_documentary_only_v1() from public, anon;
grant execute on function public.lts_browser_invoice_documentary_only_v1() to authenticated;
