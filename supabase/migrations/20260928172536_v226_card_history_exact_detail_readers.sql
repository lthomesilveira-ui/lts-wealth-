-- Read-only detail recovery; a historical total is replaced only by a cent-exact composition.
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
select jsonb_build_object('version','card-history-v226','financial_effect','none','from',p_from,'to',p_to,
 'invoices',coalesce(jsonb_agg(to_jsonb(s)-'bill_id'-'id' order by due_date desc,bank,card_name),'[]'::jsonb)) from summary s
$f$;

CREATE OR REPLACE FUNCTION public.lts_browser_card_history_v226(p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
declare u uuid:=public.lts_browser_assert_user_v1(); begin
 if p_from is null or p_to is null or p_from>p_to or p_from<date '2013-10-10' then raise exception 'invalid range';end if;
 return public.lts_card_history_v226(u,p_from,least(p_to,current_date)); end
$f$;

CREATE OR REPLACE FUNCTION public.lts_browser_card_detail_v226(p_family text,p_month date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
declare u uuid:=public.lts_browser_assert_user_v1();result jsonb; begin
 if p_family not in ('aeternum','bradesco_prime','itau_mastercard','itau_visa','c6') or p_month is null then raise exception 'invalid card cycle'; end if;
 with r as materialized (select * from public.lts_card_source_rows_v226(u) where family=p_family and reference_month=date_trunc('month',p_month)::date and not is_payment),
 b as (select s.* from public.lts_open_finance_staging s where s.user_id=u and s.resource_type='invoice'
 and public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name)=p_family
 and date_trunc('month',s.posting_date)::date=date_trunc('month',p_month)::date),
 t as (select count(*) n,coalesce(sum(amount),0) amount,count(*) filter(where category_basis='unresolved') pending from r),
 categories as (select category,count(*) n,sum(amount) amount from r group by category),
 finals as (select last4,count(*) n,sum(amount) amount from r group by last4)
 select jsonb_build_object('version','card-detail-v226','family',p_family,'month',date_trunc('month',p_month)::date,
 'amount',(select amount from t),'item_count',(select n from t),'unclassified',(select pending from t),
 'invoice_amount',(select signed_amount from b limit 1),'due_date',(select posting_date from b limit 1),
 'difference',(select signed_amount from b limit 1)-(select amount from t),
 'categories',coalesce((select jsonb_agg(to_jsonb(c) order by amount desc,category) from categories c),'[]'::jsonb),
 'instruments',coalesce((select jsonb_agg(to_jsonb(c) order by last4) from finals c),'[]'::jsonb),
 'items',coalesce((select jsonb_agg(to_jsonb(r) order by posting_date desc,description,source_id) from r),'[]'::jsonb),
 'financial_effect','none') into result;return result;end
$f$;

CREATE OR REPLACE FUNCTION public.lts_card_exact_recovery_v226(p_user_id uuid,p_from date,p_to date)
RETURNS TABLE(event_date date,transaction_date date,competence_month date,amount numeric,category text,
 center_cost text,counterparty text,origin_type text,origin_name text,source_table text,source_ref text,
 coverage_mode text,is_property boolean,is_financing boolean,replaced_source_table text,replaced_source_ref text)
LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
with rows as materialized(select * from public.lts_card_source_rows_v226(p_user_id) where not is_payment),
bills as materialized (
 select s.id,s.posting_date,s.signed_amount,s.normalized_payload->>'provider_id' bill_id,
 public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) family
 from public.lts_open_finance_staging s where s.user_id=p_user_id and s.resource_type='invoice'
 and s.provider_deleted_at is null and s.posting_date between p_from and least(p_to,current_date)
), eligible as materialized (
 select c.*,b.bill_id from public.lts_expense_effective_read_cache c join bills b
 on b.posting_date=c.event_date and abs(b.signed_amount-c.amount)<0.005
 and b.family=public.lts_card_family_v226(c.origin_name,c.origin_name)
 cross join lateral(select sum(r.amount) amount,count(*) n from rows r where r.bill_id=b.bill_id)x
 where c.user_id=p_user_id and c.coverage_mode='card_invoice_aggregate_fallback'
 and x.n>0 and abs(x.amount-c.amount)<0.005
 and (select count(*) from bills bb where bb.posting_date=c.event_date and abs(bb.signed_amount-c.amount)<0.005
 and bb.family=public.lts_card_family_v226(c.origin_name,c.origin_name))=1
)
select e.event_date,r.purchase_date,e.competence_month,r.amount,r.category,
 case when r.category ~ '^Benjamin[[:space:]]*[-—]' then 'Benjamin' when r.category ~ '^Larissa[[:space:]]*[-—]' then 'Larissa'
 when r.category='Rafiki' then 'Rafiki' else 'Não atribuído' end,
 r.description,'cartão'::text,e.origin_name,'lts_open_finance_staging'::text,r.source_id::text,
 'card_detail_open_finance_exact'::text,false,false,e.source_table,e.source_ref
from eligible e join rows r on r.bill_id=e.bill_id
$f$;

REVOKE ALL ON FUNCTION public.lts_card_history_v226(uuid,date,date),public.lts_card_exact_recovery_v226(uuid,date,date),public.lts_browser_card_history_v226(date,date),public.lts_browser_card_detail_v226(text,date) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_card_history_v226(date,date),public.lts_browser_card_detail_v226(text,date) TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.lts_card_history_v226(uuid,date,date),public.lts_card_exact_recovery_v226(uuid,date,date) TO service_role;
