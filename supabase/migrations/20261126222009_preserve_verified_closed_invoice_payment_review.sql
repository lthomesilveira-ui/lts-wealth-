-- Revalidate the recorded bank resolution when the action inventory is rebuilt
-- and when an earlier inventory is read. Leave the original invoice untouched.
DO $migration$
DECLARE
  proof text := $proof$exists (
       select 1
       from public.lts_update_lifecycle_event done
       join public.lts_open_finance_staging debit
         on debit.user_id=done.user_id and debit.id::text=done.meta->>'evidence_id'
       where done.user_id=ci.user_id and done.update_id='card_payment_'||ci.id::text
         and done.stage='resolved' and done.resolution_type='bank_posted_payment'
         and done.meta->>'invoice_id'=ci.id::text
         and done.meta->>'evidence_table'='lts_open_finance_staging'
         and done.meta->>'provider_status'='POSTED'
         and ci.metadata->>'billing_group'='C6 Carbon'
         and ci.metadata->>'bank_statement_closed'='true'
         and ci.metadata->'bank_statement_confirmed_amount'=to_jsonb(ci.amount)
         and debit.resource_type='transaction' and debit.provider_deleted_at is null
         and debit.institution_code='336' and debit.currency='BRL'
         and debit.normalized_payload->>'status'='POSTED'
         and debit.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
         and debit.description_raw='PGTO FAT CARTAO C6' and done.meta->>'description'=debit.description_raw
         and debit.posting_date=ci.due_date and done.meta->>'posting_date'=debit.posting_date::text
         and debit.signed_amount=-ci.amount and done.meta->'amount'=to_jsonb(debit.signed_amount)
         and not exists (
           select 1 from public.lts_update_lifecycle_event later
           where later.user_id=done.user_id and later.update_id=done.update_id and later.created_at>=done.created_at
             and (later.stage,later.resolution_type,later.meta->>'evidence_id')
                 is distinct from (done.stage,done.resolution_type,done.meta->>'evidence_id')
         )
         and not exists (
           select 1 from public.lts_update_lifecycle_event other
           where other.user_id=done.user_id and other.update_id<>done.update_id
             and other.stage='resolved' and other.resolution_type='bank_posted_payment'
             and other.meta->>'evidence_id'=done.meta->>'evidence_id'
         )
     )$proof$;
  build_anchor text := $part$where ci.user_id=p_user_id and ci.status='closed' and ci.due_date<=current_date$part$;
  read_anchor text := $part$where coalesce(x->>'type','')<>'projection_payment_review'$part$;
  build_sql text := pg_get_functiondef('public.lts_updates_fix86plus_v4(uuid)'::regprocedure);
  read_sql text := pg_get_functiondef('public.lts_updates_current_sources_v240(uuid)'::regprocedure);
  build_filter text := build_anchor || ' and not ' || proof;
  read_filter text := read_anchor || $part$
     and not (x->>'type'='card_payment_review' and exists (
       select 1 from public.card_invoices ci where ci.user_id=p_user_id
         and x->>'id'='card_payment_'||ci.id::text and $part$ || proof || '))';
BEGIN
  IF strpos(build_sql,build_anchor)=0 OR strpos(read_sql,read_anchor)=0 THEN
    RAISE EXCEPTION 'Unexpected source for card payment review';
  END IF;
  IF strpos(build_sql,build_filter)=0 THEN EXECUTE replace(build_sql,build_anchor,build_filter); END IF;
  IF strpos(read_sql,read_filter)=0 THEN EXECUTE replace(read_sql,read_anchor,read_filter); END IF;
END
$migration$;
