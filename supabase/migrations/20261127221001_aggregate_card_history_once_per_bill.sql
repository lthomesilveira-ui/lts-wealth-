-- Summarize the non-payment lines once per issuer bill. Preserve zero-line bills
-- and the existing document/workbook fallback when the composition is incomplete.
DO $guard$
BEGIN
 IF md5(pg_get_functiondef('public.lts_card_history_v226(uuid,date,date)'::regprocedure)) <> 'dec6ec14b87861420f78578a2430c508' THEN
  RAISE EXCEPTION 'The card history reader has changed. Review before applying.';
 END IF;
END
$guard$;

CREATE OR REPLACE FUNCTION public.lts_card_history_v226(p_user_id uuid, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with bill_items as materialized (
 select r.bill_id, count(*) item_count, sum(r.amount) detail_total,
        count(*) filter(where r.category_basis='unresolved') unclassified
 from public.lts_card_source_rows_v226(p_user_id) r
 where not r.is_payment and r.bill_id is not null
 group by r.bill_id
),
 alternatives as materialized(select value-'items' as value from jsonb_array_elements(public.lts_card_workbook_cycles_v226(p_user_id)||public.lts_card_document_cycles_v226(p_user_id))),
 bills as (
 select s.id,s.institution_name bank,public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) family,
 s.normalized_payload->>'card_name' card_name,s.normalized_payload->>'last4' last4,s.posting_date due_date,s.signed_amount amount,
 s.normalized_payload->>'provider_id' bill_id,s.normalized_payload->'payments' payments
 from public.lts_open_finance_staging s where s.user_id=p_user_id and s.resource_type='invoice'
 and s.provider_deleted_at is null and s.posting_date between p_from and p_to
), summary as (
 select b.*,date_trunc('month',b.due_date)::date reference_month,x.item_count,x.detail_total,x.unclassified,
 round(b.amount-x.detail_total,2) difference,abs(b.amount-x.detail_total)<0.005 and (x.item_count>0 or b.amount=0) detail_complete
 from bills b left join bill_items detail on detail.bill_id=b.bill_id
 cross join lateral (select coalesce(detail.item_count,0) item_count,
   coalesce(detail.detail_total,0) detail_total,coalesce(detail.unclassified,0) unclassified)x
), combined as (
 select (to_jsonb(s)-'bill_id'-'id')||coalesce(a.value-'items'-'due_date'-'card_name'-'bank','{}'::jsonb) value
 from summary s left join lateral(
  select value from alternatives where value->>'family'=s.family
  and (value->>'reference_month')::date=s.reference_month and (value->>'amount')::numeric=s.amount
  and not s.detail_complete and abs((value->>'difference')::numeric)<abs(s.difference)
  order by abs((value->>'difference')::numeric),case when value->>'source'='document_reconciled' then 0 else 1 end limit 1
 )a on true
 union all
 select value-'items' from alternatives where value->>'source' like 'workbook_%'
 and (value->>'reference_month')::date>=p_from
 and ((value->>'reference_month')::date+interval '1 month'-interval '1 day')::date<=p_to
 and not exists(select 1 from summary s where s.family=value->>'family' and s.reference_month=(value->>'reference_month')::date)
)
select jsonb_build_object('version','card-history-v226','financial_effect','none','from',p_from,'to',p_to,
 'invoices',coalesce(jsonb_agg(value order by value->>'reference_month' desc,value->>'bank',value->>'due_date',value->>'family',value->>'card_name',value),'[]'::jsonb)) from combined
$function$;
