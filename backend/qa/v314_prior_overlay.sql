CREATE OR REPLACE FUNCTION public.lts_card_classification_current_overlay_v1(p_user_id uuid, p_review jsonb, p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare c public.card_invoices%rowtype; d jsonb; pending jsonb; items jsonb:=coalesce(p_review->'items','[]'); invoices jsonb:=coalesce(p_review->'invoices','[]'); old_item jsonb; x jsonb; family text; bank text; stat jsonb; source_ok boolean:=true;
begin
 for c in select * from public.card_invoices where user_id=p_user_id and status='open' and jsonb_typeof(metadata->'items')='array' and jsonb_array_length(metadata->'items')>0 order by due_date,id loop
 bank:=case when lower(c.card_name) like '%c6%' then 'C6' when lower(c.card_name) like '%aeternum%' or lower(c.card_name) like '%prime%' then 'Bradesco' else 'Itaú' end;
 family:=public.lts_card_family_v1(c.card_name,bank);
 d:=public.lts_card_settlement_detail_core_v1(p_user_id,c.due_date,c.card_name,c.amount,bank);
 if not coalesce((d->>'matched')::boolean,false) or not coalesce((d->>'detail_complete')::boolean,false) then source_ok:=false;continue;end if;
 select coalesce(jsonb_agg(v),'[]') into items from jsonb_array_elements(items)v where not(v->>'due_date'=c.due_date::text and public.lts_card_family_v1(v->>'card_name',bank)=family);
 select coalesce(jsonb_agg(v),'[]') into invoices from jsonb_array_elements(invoices)v where not(v->>'due_date'=c.due_date::text and public.lts_card_family_v1(v->>'card_name',bank)=family);
 select coalesce(jsonb_agg(jsonb_build_object('description_key',k,'example_description',descr,'occurrences',n,'total_value',amount,'pending_credit_value',credits) order by amount desc,k),'[]') into pending from (
 select v->>'description_key' k,min(v->>'description') descr,count(*) n,sum((v->>'amount')::numeric) amount,coalesce(sum(abs((v->>'amount')::numeric)) filter(where (v->>'amount')::numeric<0),0) credits
 from jsonb_array_elements(d->'purchases')v where lower(coalesce(v->>'category','')) in ('','a classificar','—') group by v->>'description_key')q;
 if jsonb_array_length(pending)>0 then
  select jsonb_build_object('invoice_id',d->>'invoice_id','card_name',c.card_name,'due_date',c.due_date,'pending_groups',jsonb_array_length(pending),'pending_lines',sum((v->>'occurrences')::integer),'pending_value',sum((v->>'total_value')::numeric),'pending_credit_value',sum((v->>'pending_credit_value')::numeric),'source_lines',d->'detail_lines','source_invoice_total',d->'invoice_total','source_evidence_as_of',d->'evidence_as_of','source_basis','same_current_document_as_flow_invoice') into stat from jsonb_array_elements(pending)v;
  invoices:=invoices||jsonb_build_array(stat);
  for x in select value from jsonb_array_elements(pending) loop
   select v into old_item from jsonb_array_elements(coalesce(p_review->'items','[]'))v where v->>'description_key'=x->>'description_key' and v->>'due_date'=c.due_date::text and public.lts_card_family_v1(v->>'card_name',bank)=family limit 1;
   items:=items||jsonb_build_array(coalesce(old_item,'{}')||x||jsonb_build_object('invoice_id',d->>'invoice_id','card_name',c.card_name,'due_date',c.due_date,'source_basis','same_current_document_as_flow_invoice'));
  end loop;
 end if;
 end loop;
 select coalesce(jsonb_agg(v order by v->>'due_date' desc,(v->>'total_value')::numeric desc,v->>'description_key'),'[]') into items from (select value v from jsonb_array_elements(items) order by value->>'due_date' desc,(value->>'total_value')::numeric desc,value->>'description_key' limit greatest(1,least(coalesce(p_limit,50),50)))q;
 return p_review||jsonb_build_object('version','card-classification-current-source-v9','source_consistent',source_ok,'items',items,'invoices',invoices,'pending_groups',(select coalesce(sum((v->>'pending_groups')::integer),0) from jsonb_array_elements(invoices)v),'pending_lines',(select coalesce(sum((v->>'pending_lines')::integer),0) from jsonb_array_elements(invoices)v),'pending_value',(select coalesce(sum((v->>'pending_value')::numeric),0) from jsonb_array_elements(invoices)v),'safe_suggestion_groups',(select count(*) from jsonb_array_elements(items)v where coalesce((v->>'suggestion_safe')::boolean,false)),'all_suggestion_groups',(select count(*) from jsonb_array_elements(items)v where nullif(v->>'suggested_category','') is not null),'source_contract','current_open_invoice_overrides_legacy_same_family_same_due_v1');
end $function$
