-- Isolated bank-cash reconciliation candidate. Not an operational reader.
-- No bank facts, user IDs or private transaction amounts belong in this file.
create schema if not exists lts_work_audit;
revoke all on schema lts_work_audit from public, anon, authenticated;

create table if not exists lts_work_audit.bank_balance_evidence_v1 (
  user_id uuid not null,
  account text not null,
  balance_date date not null,
  balance numeric(18,2) not null,
  source_document text not null,
  source_page integer,
  primary key (user_id, account, balance_date)
);
alter table lts_work_audit.bank_balance_evidence_v1 enable row level security;
-- No client policies: the audit schema is DBA-only; advisor INFO is intentional.
revoke all on lts_work_audit.bank_balance_evidence_v1 from public, anon, authenticated;

create table if not exists lts_work_audit.cash_override_candidate_v1 (
  user_id uuid not null,
  source_ref text not null,
  leg smallint not null check (leg between 1 and 8),
  original_date date not null,
  event_date date not null,
  account text not null,
  signed_amount numeric(18,2) not null,
  evidence_document text not null,
  evidence_description text not null,
  economic_classification_status text not null default 'unreviewed'
    check (economic_classification_status in ('unreviewed','source_matched')),
  check (abs(event_date - original_date) <= 31),
  primary key (user_id, source_ref, leg)
);
alter table lts_work_audit.cash_override_candidate_v1 enable row level security;
revoke all on lts_work_audit.cash_override_candidate_v1 from public, anon, authenticated;

-- Deliberately returns cash legs only: never reuse source expense classifications
-- for a decomposed bank transaction. No app function calls this candidate.
create or replace function lts_work_audit.cash_candidate_v1(
  p_user_id uuid, p_from date, p_to date
) returns table (
  event_date date, account text, signed_amount numeric,
  source_ref text, leg smallint, evidence text
) language sql volatile security invoker set search_path = '' as $$
  with base as materialized (
    select e.event_date,e.account,e.signed_amount,e.source_ref
    from public.lts_historical_effective_cash_v5(
      p_user_id,p_from-31,p_to+31
    ) e
  ), unchanged as (
    select b.event_date,b.account,b.signed_amount,b.source_ref,
           0::smallint leg,'current_effective'::text evidence
    from base b
    where not exists (
      select 1 from lts_work_audit.cash_override_candidate_v1 o
      where o.user_id=p_user_id and o.source_ref=b.source_ref
    )
  ), substituted as (
    select o.event_date,o.account,o.signed_amount,o.source_ref,
           o.leg,o.evidence_description evidence
    from lts_work_audit.cash_override_candidate_v1 o
    where o.user_id=p_user_id
      and exists (
        select 1 from base b
        where b.source_ref=o.source_ref and b.event_date=o.original_date
      )
  )
  select * from unchanged where event_date between p_from and p_to
  union all
  select * from substituted where event_date between p_from and p_to;
$$;
revoke all on function lts_work_audit.cash_candidate_v1(uuid,date,date)
  from public, anon, authenticated;

create or replace function lts_work_audit.reconcile_cash_candidate_v1(
  p_user_id uuid, p_account text, p_from date, p_to date
) returns table (
  previous_date date, balance_date date, bank_delta numeric,
  modeled_delta numeric, difference numeric
) language sql volatile security invoker set search_path = '' as $$
  with balances as (
    select e.balance_date,e.balance,
      lag(e.balance_date) over(order by e.balance_date) previous_date,
      lag(e.balance) over(order by e.balance_date) previous_balance
    from lts_work_audit.bank_balance_evidence_v1 e
    where e.user_id=p_user_id and e.account=p_account
      and e.balance_date between p_from and p_to
  ), cash as materialized (
    select c.event_date,c.signed_amount
    from lts_work_audit.cash_candidate_v1(p_user_id,p_from,p_to) c
    where c.account=p_account
  )
  select b.previous_date,b.balance_date,
         b.balance-b.previous_balance,
         coalesce(sum(c.signed_amount),0),
         coalesce(sum(c.signed_amount),0)-(b.balance-b.previous_balance)
  from balances b
  left join cash c on c.event_date>b.previous_date
    and c.event_date<=b.balance_date
  where b.previous_date is not null
  group by b.previous_date,b.balance_date,b.balance,b.previous_balance
  order by b.balance_date;
$$;
revoke all on function lts_work_audit.reconcile_cash_candidate_v1(uuid,text,date,date)
  from public, anon, authenticated;
