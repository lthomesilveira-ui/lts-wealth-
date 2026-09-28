-- Independent source detail only; never writes the expense ledger or bank balances.
CREATE TABLE IF NOT EXISTS public.lts_card_workbook_evidence_v226(
 user_id uuid NOT NULL, family text NOT NULL, reference_month date NOT NULL,
 source_hash text NOT NULL,source_sheet text NOT NULL,source_row integer NOT NULL,
 source_date date NOT NULL,category text NOT NULL,last4 text,amount numeric NOT NULL,
 expected_invoice_amount numeric NOT NULL,expected_rows integer NOT NULL,
 evidence jsonb NOT NULL DEFAULT '{}'::jsonb,created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,family,reference_month,source_hash,source_sheet,source_row),
 CHECK(source_row>0 AND expected_rows>0),CHECK(length(source_hash)=64)
);
ALTER TABLE public.lts_card_workbook_evidence_v226 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.lts_card_workbook_evidence_v226 FROM public,anon,authenticated;
GRANT ALL ON TABLE public.lts_card_workbook_evidence_v226 TO service_role;

CREATE OR REPLACE FUNCTION public.lts_card_workbook_cycles_v226(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $f$
with cycles as (
 select family,reference_month,max(expected_invoice_amount) amount,count(*) item_count,sum(amount) detail_total,
 jsonb_agg(jsonb_build_object('source_row',source_row,'source_sheet',source_sheet,'source_date',source_date,
 'category',category,'category_basis','historical_workbook','last4',last4,'amount',amount,
 'description','Linha '||source_row||' da planilha · estabelecimento não informado',
 'date_kind','reference_month','reference_month',reference_month,'purchase_date',null,'posting_date',null)
 order by source_row) items
 from public.lts_card_workbook_evidence_v226 where user_id=p_user_id
 group by family,reference_month
 having count(distinct source_hash)=1 and count(distinct expected_rows)=1
 and count(*)=max(expected_rows) and count(distinct expected_invoice_amount)=1
 and round(sum(amount),2)=round(max(expected_invoice_amount),2)
)
select coalesce(jsonb_agg(jsonb_build_object('family',family,'reference_month',reference_month,
 'bank',case when family like 'itau%' then 'Itaú' when family='c6' then 'C6' else 'Bradesco' end,
 'card_name',family,'due_date',null,'amount',amount,'item_count',item_count,'detail_total',detail_total,
 'difference',0,'detail_complete',true,'source','workbook_reconciled','items',items)
 order by reference_month desc),'[]'::jsonb)from cycles
$f$;
REVOKE ALL ON FUNCTION public.lts_card_workbook_cycles_v226(uuid) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_workbook_cycles_v226(uuid) TO service_role;

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
 where (w->>'reference_month')::date between date_trunc('month',p_from)::date and date_trunc('month',p_to)::date
 and not exists(select 1 from summary s where s.family=w->>'family' and s.reference_month=(w->>'reference_month')::date)
)
select jsonb_build_object('version','card-history-v226','financial_effect','none','from',p_from,'to',p_to,
 'invoices',coalesce(jsonb_agg(value order by value->>'reference_month' desc,value->>'bank'),'[]'::jsonb)) from combined
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
 'financial_effect','none') into result;
 if (result->>'item_count')::int=0 then
  select w||jsonb_build_object('version','card-detail-v226','invoice_amount',(w->>'amount')::numeric,
   'financial_effect','none','source_note','Composição reconciliada da planilha. A fonte informa categoria, valor e mês de referência; não informa estabelecimento, dia da compra nem vencimento exato.') into result
  from jsonb_array_elements(public.lts_card_workbook_cycles_v226(u))w
  where w->>'family'=p_family and (w->>'reference_month')::date=date_trunc('month',p_month)::date;
 end if;
 return coalesce(result,jsonb_build_object('version','card-detail-v226','items','[]'::jsonb,'item_count',0));end
$f$;

