-- Keep observations awaiting a bill available in the open-card and review views.
-- A closed invoice may exclude them only after every posted item is verified.
DO $migration$
DECLARE
  definition text := pg_get_functiondef('public.lts_browser_card_detail_v226(text,date)'::regprocedure);
  old_query text := $old$ with r as materialized(select * from public.lts_card_source_rows_v226(u) where family=p_family and reference_month=date_trunc('month',p_month)::date and not is_payment),
 b as(select s.* from public.lts_open_finance_staging s where s.user_id=u and s.resource_type='invoice' and s.provider_deleted_at is null
 and public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name)=p_family
 and date_trunc('month',s.posting_date)::date=date_trunc('month',p_month)::date),$old$;
  new_query text := $new$ with b as(select s.* from public.lts_open_finance_staging s where s.user_id=u and s.resource_type='invoice' and s.provider_deleted_at is null
 and public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name)=p_family
 and date_trunc('month',s.posting_date)::date=date_trunc('month',p_month)::date),
 cycle_rows as materialized (
   select * from public.lts_card_source_rows_v226(u)
   where family=p_family and reference_month=date_trunc('month',p_month)::date
 ),
 bank_invoice as materialized (
   select * from b where (select count(*) from b)=1 and currency='BRL'
     and nullif(raw_payload->>'id','') is not null
     and normalized_payload->>'due_date'=posting_date::text
     and exists(select 1 from cycle_rows where not is_payment and provider_status='PENDING')
 ),
 linked as materialized (
   select s.id,s.signed_amount,s.normalized_payload->>'status' as status,
          r.source_id,r.is_payment,r.amount
   from bank_invoice i join public.lts_open_finance_staging s
     on s.user_id=i.user_id and s.provider=i.provider and s.institution_code=i.institution_code
     and s.provider_account_ref=i.provider_account_ref and s.currency=i.currency
     and s.resource_type='card_transaction' and s.provider_deleted_at is null
     and s.raw_payload#>>'{creditCardMetadata,billId}'=i.raw_payload->>'id'
   left join cycle_rows r on r.source_id=s.id
 ),
 unbilled as materialized (
   select r.source_id from cycle_rows r join public.lts_open_finance_staging s on s.id=r.source_id
   join bank_invoice i on i.user_id=s.user_id and i.provider=s.provider
     and i.institution_code=s.institution_code and i.provider_account_ref=s.provider_account_ref
     and i.currency=s.currency
   where not r.is_payment and r.provider_status='PENDING' and r.amount=-s.signed_amount
     and s.resource_type='card_transaction' and s.provider_deleted_at is null
     and s.normalized_payload->>'status'='PENDING' and s.raw_payload->>'status'='PENDING'
     and nullif(s.raw_payload#>>'{creditCardMetadata,billId}','') is null
     and nullif(s.raw_payload->>'billId','') is null
 ),
 verified_invoice as (
   select 1 from bank_invoice i where exists(select 1 from unbilled)
     and exists(select 1 from linked where not is_payment)
     and not exists(select 1 from linked where status is distinct from 'POSTED'
       or source_id is null or is_payment is null or amount is distinct from -signed_amount)
     and (select count(*)=count(distinct id) from linked)
     and (select sum(amount) from linked where not is_payment)=i.signed_amount
     and not exists (
       select source_id from cycle_rows where not is_payment
       except all (select source_id from linked where not is_payment union all select source_id from unbilled)
     )
 ),
 r as materialized (
   select c.* from cycle_rows c where not c.is_payment and not exists (
     select 1 from unbilled p cross join verified_invoice where p.source_id=c.source_id
   )
 ),$new$;
BEGIN
  IF strpos(definition,new_query)>0 THEN RETURN; END IF;
  IF strpos(definition,old_query)=0 THEN RAISE EXCEPTION 'Unexpected card cycle query'; END IF;
  EXECUTE replace(definition,old_query,new_query);
END
$migration$;
