-- Read-only source selection. A source replaces another composition; it never adds spending.
CREATE OR REPLACE FUNCTION public.lts_card_document_cycles_v226(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $f$
with documents as (
 select r.*,public.lts_card_family_v226(r.card_name,case when r.card_name ~* 'c6' then 'C6' when r.card_name ~* 'aeternum|bradesco|prime' then 'Bradesco' else 'Itaú' end) family,
 x.items,x.n,x.total
 from public.lts_card_invoice_detail_reconciliation r
 cross join lateral (
  select count(*) n,sum(p.installment_amount) total,jsonb_agg(jsonb_build_object(
   'description',p.description_raw,'purchase_date',p.purchase_date,'last4',p.card_final,'amount',p.installment_amount,
   'category',case when d.beneficiary in ('Lucas','Larissa','Benjamin','Rafiki') and coalesce(d.category_label,p.category) !~* '^(Lucas|Larissa|Benjamin|Rafiki)' then d.beneficiary||' — '||coalesce(d.category_label,p.category) else coalesce(d.category_label,p.category) end,
   'category_basis','reconciled_document','installment_number',p.installment_number,'total_installments',p.installments)
   order by p.purchase_date,p.row_id) items
  from public.lts_card_purchase_detail p left join public.lts_v178_review_decision d on d.user_id=p.user_id and d.source_table='card_purchase_detail' and d.source_ref=p.line_key
  where p.user_id=r.user_id and p.invoice_id=r.invoice_id
 )x
 where r.user_id=p_user_id and r.reconciled and r.detail_lines>0
 and x.n=r.detail_lines and round(x.total,2)=round(r.invoice_total,2)
)
select coalesce(jsonb_agg(jsonb_build_object('family',family,'reference_month',date_trunc('month',due_date)::date,
 'due_date',due_date,'amount',invoice_total,'detail_total',total,'difference',0,'detail_complete',true,
 'item_count',n,'items',items,'source','document_reconciled')),'[]'::jsonb) from documents where family is not null
$f$;
REVOKE ALL ON FUNCTION public.lts_card_document_cycles_v226(uuid) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_document_cycles_v226(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_card_workbook_cycles_v226(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $f$
with cycles as (
 select family,reference_month,max(expected_invoice_amount) amount,count(*) item_count,sum(amount) detail_total,
 jsonb_agg(jsonb_build_object('source_row',source_row,'source_sheet',source_sheet,'source_date',source_date,
 'category',category,'category_basis','historical_workbook','last4',last4,'amount',amount,
 'description','Linha '||source_row||' da planilha · estabelecimento não informado',
 'date_kind','reference_month','reference_month',reference_month,'purchase_date',null,'posting_date',null)
 order by source_row) items
 from public.lts_card_workbook_evidence_v226 where user_id=p_user_id group by family,reference_month
 having count(distinct source_hash)=1 and count(distinct expected_rows)=1 and count(*)=max(expected_rows)
 and count(distinct expected_invoice_amount)=1
)
select coalesce(jsonb_agg(jsonb_build_object('family',family,'reference_month',reference_month,
 'bank',case when family like 'itau%' then 'Itaú' when family='c6' then 'C6' else 'Bradesco' end,
 'card_name',family,'due_date',null,'amount',amount,'item_count',item_count,'detail_total',detail_total,
 'difference',round(amount-detail_total,2),'detail_complete',round(amount-detail_total,2)=0,
 'source',case when round(amount-detail_total,2)=0 then 'workbook_reconciled' else 'workbook_partial' end,'items',items)
 order by reference_month desc),'[]'::jsonb)from cycles
$f$;

CREATE OR REPLACE FUNCTION public.lts_card_history_v226(p_user_id uuid,p_from date,p_to date)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
with r as materialized(select * from public.lts_card_source_rows_v226(p_user_id)),
 alternatives as materialized(select value from jsonb_array_elements(public.lts_card_workbook_cycles_v226(p_user_id)||public.lts_card_document_cycles_v226(p_user_id))),
 bills as (
 select s.id,s.institution_name bank,public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) family,
 s.normalized_payload->>'card_name' card_name,s.normalized_payload->>'last4' last4,s.posting_date due_date,s.signed_amount amount,
 s.normalized_payload->>'provider_id' bill_id,s.normalized_payload->'payments' payments
 from public.lts_open_finance_staging s where s.user_id=p_user_id and s.resource_type='invoice'
 and s.provider_deleted_at is null and s.posting_date between p_from and p_to
), summary as (
 select b.*,date_trunc('month',b.due_date)::date reference_month,x.item_count,x.detail_total,x.unclassified,
 round(b.amount-x.detail_total,2) difference,abs(b.amount-x.detail_total)<0.005 and (x.item_count>0 or b.amount=0) detail_complete
 from bills b cross join lateral(select count(*) item_count,coalesce(sum(amount),0) detail_total,
 count(*) filter(where category_basis='unresolved') unclassified from r where r.bill_id=b.bill_id and not r.is_payment)x
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
 'invoices',coalesce(jsonb_agg(value order by value->>'reference_month' desc,value->>'bank'),'[]'::jsonb)) from combined
$f$;

CREATE OR REPLACE FUNCTION public.lts_browser_card_detail_v226(p_family text,p_month date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
declare u uuid:=public.lts_browser_assert_user_v1(); result jsonb; alternative jsonb;
begin
 if p_family not in ('aeternum','bradesco_prime','itau_mastercard','itau_visa','c6') or p_month is null then raise exception 'invalid card cycle'; end if;
 with r as materialized(select * from public.lts_card_source_rows_v226(u) where family=p_family and reference_month=date_trunc('month',p_month)::date and not is_payment),
 b as(select s.* from public.lts_open_finance_staging s where s.user_id=u and s.resource_type='invoice' and s.provider_deleted_at is null
 and public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name)=p_family
 and date_trunc('month',s.posting_date)::date=date_trunc('month',p_month)::date),
 t as(select count(*) n,coalesce(sum(amount),0) amount,count(*) filter(where category_basis='unresolved') pending from r)
 select jsonb_build_object('version','card-detail-v226','family',p_family,'month',date_trunc('month',p_month)::date,
 'amount',(select amount from t),'item_count',(select n from t),'unclassified',(select pending from t),
 'invoice_amount',(select signed_amount from b limit 1),'due_date',(select posting_date from b limit 1),
 'difference',(select signed_amount from b limit 1)-(select amount from t),
 'items',coalesce((select jsonb_agg(to_jsonb(r) order by posting_date desc,description,source_id) from r),'[]'::jsonb),
 'financial_effect','none') into result;
 if (result->>'item_count')::int=0 or abs(coalesce((result->>'difference')::numeric,0))>=0.005 then
  select w into alternative from jsonb_array_elements(public.lts_card_workbook_cycles_v226(u)||public.lts_card_document_cycles_v226(u))w
  where w->>'family'=p_family and (w->>'reference_month')::date=date_trunc('month',p_month)::date
  and (result->>'invoice_amount' is null or (w->>'amount')::numeric=(result->>'invoice_amount')::numeric)
  and (result->>'invoice_amount' is null or abs((w->>'difference')::numeric)<abs((result->>'difference')::numeric))
  order by abs((w->>'difference')::numeric),case when w->>'source'='document_reconciled' then 0 else 1 end limit 1;
  if alternative is not null then
   result:=result||alternative||jsonb_build_object('version','card-detail-v226','invoice_amount',(alternative->>'amount')::numeric,
    'due_date',coalesce(result->>'due_date',alternative->>'due_date'),'amount',(alternative->>'detail_total')::numeric,
    'alternative_items',result->'items','alternative_note','Itens também recebidos do banco para esta mesma fatura. São outra fonte de consulta, não despesas adicionais; não somar novamente.',
    'source_note',case when alternative->>'source'='document_reconciled' then 'Composição do documento importado, conferida com o total desta fatura.'
     else 'Composição da planilha por categoria, valor e mês de referência. Estabelecimento e dia da compra não estão informados nessa fonte. A diferença, quando houver, permanece explícita.' end);
  end if;
 end if;
 return result;
end
$f$;
