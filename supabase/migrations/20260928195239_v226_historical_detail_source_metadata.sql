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
 result:=result||jsonb_build_object(
  'unclassified',(select count(*) from jsonb_array_elements(result->'items')x where x->>'category_basis'='unresolved'),
  'categories',(select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) from (select x->>'category' category,count(*) n,sum((x->>'amount')::numeric) amount from jsonb_array_elements(result->'items')x group by x->>'category')q),
  'instruments',(select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) from (select x->>'last4' last4,count(*) n,sum((x->>'amount')::numeric) amount from jsonb_array_elements(result->'items')x group by x->>'last4')q)
 );
 return result;
end
$f$;
