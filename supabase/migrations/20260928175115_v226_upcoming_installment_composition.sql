CREATE OR REPLACE FUNCTION public.lts_card_cycles_v226(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
with rows as materialized (select * from public.lts_card_source_rows_v226(p_user_id)),
accounts as materialized (
 select s.institution_name bank,public.lts_card_family_v226(s.normalized_payload->>'name',s.institution_name) family,
 s.normalized_payload->>'name' name,s.normalized_payload->>'last4' last4,
 s.raw_payload#>>'{creditData,status}' status,s.raw_payload#>'{creditData,additionalCards}' additional_cards,
 nullif(s.normalized_payload->>'due_date','')::date last_due,s.last_seen_at observed_at
 from public.lts_open_finance_staging s where s.user_id=p_user_id and s.resource_type='credit_card' and s.provider_deleted_at is null
), pending as materialized (
 select family,reference_month,min(due_date) due_date,count(*) n,round(sum(amount),2) amount,
 count(*) filter(where category_basis='unresolved') unclassified,max(observed_at) observed_at,
 jsonb_agg(to_jsonb(r)-'bank'-'family'-'card_name'-'billing_last4'-'bill_id' order by posting_date desc,description,source_id) items
 from rows r where not is_payment and provider_status='PENDING' and reference_month>=date_trunc('month',current_date)::date group by family,reference_month
), first_cycles as materialized (select family,min(reference_month) AS month from pending group by family),
installments as materialized (
 select r.family,(r.reference_month+make_interval(months=>n))::date reference_month,r.amount,r.category_basis,r.observed_at,
 to_jsonb(r)||jsonb_build_object('reference_month',(r.reference_month+make_interval(months=>n))::date,'installment_number',r.installment_number+n,'provider_status','PROJECTED','projection_basis','remaining_installments_of_received_purchase') item
 from rows r join first_cycles f on f.family=r.family and f.month=r.reference_month
 cross join lateral generate_series(1,least(120,r.total_installments-r.installment_number)) n
 where not r.is_payment and r.provider_status='PENDING' and r.amount>0 and r.installment_number>0 and r.total_installments>r.installment_number
), projected as materialized (
 select family,reference_month,count(*) n,round(sum(amount),2) amount,count(*) filter(where category_basis='unresolved') unclassified,
 max(observed_at) observed_at,jsonb_agg(item order by item->>'description',item->>'source_id') items from installments group by family,reference_month
), composition as materialized (
 select coalesce(p.family,j.family) family,coalesce(p.reference_month,j.reference_month) reference_month,p.due_date,
 coalesce(p.n,j.n) n,coalesce(p.amount,j.amount) amount,coalesce(p.unclassified,j.unclassified) unclassified,
 coalesce(p.observed_at,j.observed_at) observed_at,coalesce(p.items,j.items) items,
 case when p.n>0 and p.reference_month=f.month then 'open_finance_composition' when p.n>0 then 'provider_installments' else 'derived_current_installments' end basis
 from pending p full join projected j on j.family=p.family and j.reference_month=p.reference_month
 left join first_cycles f on f.family=coalesce(p.family,j.family)
), docs as materialized (
 select i.*,public.lts_card_family_v226(i.card_name,case when i.card_name ~* 'c6' then 'C6' when i.card_name ~* 'aeternum|bradesco|prime' then 'Bradesco' else 'Itaú' end) family
 from public.card_invoices i where i.user_id=p_user_id and i.due_date>=current_date and i.status<>'paid'
), cycles0 as (
 select coalesce(p.family,d.family) family,coalesce(p.reference_month,d.reference_month) AS month,
 coalesce(p.due_date,d.due_date) due_date,
 case when p.basis='derived_current_installments' then greatest(p.amount,coalesce(d.amount,0)) else coalesce(p.amount,d.amount) end amount,
 case when p.basis='derived_current_installments' and d.amount>p.amount then 'documented_floor_partial_detail'
 else coalesce(p.basis,case when d.source='derived_installments' then 'contracted_installments' else 'documented_snapshot' end) end basis,
 coalesce(p.n,0) item_count,coalesce(p.unclassified,0) unclassified,coalesce(p.items,'[]'::jsonb) items,p.observed_at,d.amount documentary_amount,
 case when d.metadata->>'as_of' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then d.metadata->>'as_of' end documentary_as_of
 from composition p full join docs d on d.family=p.family and d.reference_month=p.reference_month
), card_rows as (
 select a.*,coalesce((select jsonb_agg(to_jsonb(c)-'family' order by month) from cycles0 c where c.family=a.family),'[]'::jsonb) cycles from accounts a
)
select jsonb_build_object('version','card-cycles-v226','as_of',current_date,'computed_at',clock_timestamp(),
 'active_billing_accounts',(select count(*) from accounts where status='ACTIVE'),
 'cards',coalesce((select jsonb_agg(to_jsonb(c) order by bank,name) from card_rows c),'[]'::jsonb),
 'financial_effect','none','provider_balance_used_as_invoice',false)
$f$;
