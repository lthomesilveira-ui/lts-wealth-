-- Monthly workbook evidence is visible only when the complete source month is selected.
CREATE OR REPLACE FUNCTION public.lts_card_history_v226(p_user_id uuid,p_from date,p_to date)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
with r as materialized(select * from public.lts_card_source_rows_v226(p_user_id)),
bills as (
 select s.id,s.institution_name bank,public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) family,
 s.normalized_payload->>'card_name' card_name,s.normalized_payload->>'last4' last4,
 s.posting_date due_date,s.signed_amount amount,s.normalized_payload->>'provider_id' bill_id,
 s.normalized_payload->'payments' payments
 from public.lts_open_finance_staging s where s.user_id=p_user_id and s.resource_type='invoice'
 and s.provider_deleted_at is null and s.posting_date between p_from and p_to
), summary as (
 select b.*,date_trunc('month',b.due_date)::date reference_month,x.item_count,x.detail_total,x.unclassified,
 round(b.amount-x.detail_total,2) difference,abs(b.amount-x.detail_total)<0.005 and (x.item_count>0 or b.amount=0) detail_complete
 from bills b cross join lateral (select count(*) item_count,coalesce(sum(r.amount),0) detail_total,
 count(*) filter(where category_basis='unresolved') unclassified from r where r.bill_id=b.bill_id and not r.is_payment)x
)
, combined as (
 select to_jsonb(s)-'bill_id'-'id' value from summary s
 union all
 select w-'items' from jsonb_array_elements(public.lts_card_workbook_cycles_v226(p_user_id))w
 -- A month-only source cannot be attributed to an arbitrary day inside that month.
 where (w->>'reference_month')::date >= p_from
 and ((w->>'reference_month')::date + interval '1 month' - interval '1 day')::date <= p_to
 and not exists(select 1 from summary s where s.family=w->>'family' and s.reference_month=(w->>'reference_month')::date)
)
select jsonb_build_object('version','card-history-v226','financial_effect','none','from',p_from,'to',p_to,
 'invoices',coalesce(jsonb_agg(value order by value->>'reference_month' desc,value->>'bank'),'[]'::jsonb)) from combined
$f$;
