-- Owner-scoped classification and provisional card detail. No ledger writes.
CREATE OR REPLACE FUNCTION public.lts_browser_card_category_options_v226()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
declare u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
begin
 select coalesce(jsonb_agg(category order by category),'[]'::jsonb) into result from (
 select distinct x category from public.lts_product_read_cache c
 cross join lateral jsonb_array_elements_text(coalesce(c.payload#>'{card_classification_review,category_options}','[]'::jsonb)) x
 where c.user_id=u and public.lts_v178_norm(x) not in ('a classificar','nao identificado','sem categoria')
 )q;
 return jsonb_build_object('categories',result);
end $f$;

CREATE OR REPLACE FUNCTION public.lts_browser_card_classify_v226(p_source_id uuid,p_category text,p_beneficiary text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
declare u uuid:=public.lts_browser_assert_user_v1(); before_row jsonb; cat text:=nullif(trim(p_category),''); person text:=nullif(trim(p_beneficiary),''); target record;
begin
 if cat is null or length(cat)>120 or public.lts_v178_norm(cat) in ('a classificar','nao identificado','sem categoria') then raise exception 'Escolha uma categoria.'; end if;
 if person is not null and person not in ('Lucas','Larissa','Benjamin','Rafiki') then raise exception 'Beneficiário inválido.'; end if;
 select * into target from public.lts_open_finance_staging s where s.id=p_source_id and s.user_id=u and s.resource_type='card_transaction' and s.provider_deleted_at is null;
 if not found then raise exception 'Compra não encontrada.'; end if;
 if not exists(select 1 from public.lts_product_read_cache c cross join lateral jsonb_array_elements_text(coalesce(c.payload#>'{card_classification_review,category_options}','[]'::jsonb)) x where c.user_id=u and x=cat) then raise exception 'Categoria não disponível.'; end if;
 select to_jsonb(d) into before_row from public.lts_v178_review_decision d where d.user_id=u and d.source_table='lts_open_finance_staging' and d.source_ref=p_source_id::text;
 insert into public.lts_v178_review_decision(user_id,source_table,source_ref,category_label,beneficiary,decision_basis)
 values(u,'lts_open_finance_staging',p_source_id::text,cat,person,'authenticated_user_v226')
 on conflict(user_id,source_table,source_ref) do update set category_label=excluded.category_label,beneficiary=coalesce(excluded.beneficiary,lts_v178_review_decision.beneficiary),decision_basis=excluded.decision_basis,decided_at=now();
 insert into public.lts_access_audit(user_id,email,action,meta) values(u,lower(coalesce(auth.jwt()->>'email','')),'browser_card_classify_v226',jsonb_build_object('source_id',p_source_id,'before',before_row,'after',jsonb_build_object('category',cat,'beneficiary',person),'financial_effect','none'));
 return jsonb_build_object('ok',true,'source_id',p_source_id,'category',cat,'beneficiary',person);
end $f$;

CREATE OR REPLACE FUNCTION public.lts_browser_open_finance_pending_v225(p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
declare u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
begin
 if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
 with rows as materialized (
 select r.*,s.institution_code,s.provider_record_id from public.lts_card_source_rows_v226(u) r
 join public.lts_open_finance_staging s on s.id=r.source_id and s.user_id=u
 where r.provider_status='PENDING' and not r.is_payment and r.posting_date>date '2026-09-22' and r.posting_date between p_from and least(p_to,current_date)
 ), banks as (
 select institution_code,count(*) count,coalesce(sum(amount) filter(where amount>0),0) gross_expense,
 coalesce(sum(-amount) filter(where amount<0),0) credits,sum(amount) net_expense from rows group by institution_code
 ) select jsonb_build_object('version','pending-expense-v225','from',p_from,'to',p_to,
 'treatment','provisional_expense_until_provider_update','computed_at',clock_timestamp(),
 'transaction_count',(select count(*) from rows),'net_expense',(select coalesce(sum(amount),0) from rows),
 'unclassified_count',(select count(*) from rows where category_basis='unresolved'),
 'banks',coalesce((select jsonb_agg(to_jsonb(b) order by b.institution_code) from banks b),'[]'::jsonb),
 'rows',coalesce((select jsonb_agg(jsonb_build_object('key',institution_code||':'||provider_record_id,'source_id',source_id,
 'institution_code',institution_code,'family',family,'reference_month',reference_month,'date',posting_date,'purchase_date',purchase_date,
 'description',description,'last4',last4,'category',category,'category_basis',category_basis,'expense',amount,'provider_status','PENDING') order by posting_date desc,source_id) from rows),'[]'::jsonb),
 'creates_cash_obligation',false) into result;
 return result;
end $f$;

REVOKE ALL ON FUNCTION public.lts_browser_card_category_options_v226(),public.lts_browser_card_classify_v226(uuid,text,text) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_card_category_options_v226(),public.lts_browser_card_classify_v226(uuid,text,text) TO authenticated,service_role;
