-- V183: one existing receipt, never a description-wide expense rule.
-- Privileged work is private because source readers/audit tables are DBA-only.
-- The public endpoint is INVOKER; the private function authorizes auth.uid()
-- itself, accepts no user id, and grants no direct access to underlying tables.
create schema if not exists lts_income_private;
revoke all on schema lts_income_private from public, anon, authenticated;
grant usage on schema lts_income_private to authenticated;

create or replace function lts_income_private.review_v183(
 p_source text, p_source_ref text, p_event_date date, p_account text,
 p_amount numeric, p_category text, p_expected text
) returns jsonb language plpgsql security definer set search_path = ''
set timezone = 'America/Sao_Paulo' as $$
declare
 u uuid := public.lts_browser_assert_user_v1();
 f public.financial_events%rowtype;
 before_row jsonb; token text; rows_json jsonb; effective jsonb;
 options jsonb := '["Família","Reembolso","Salário","Rendimentos","Outras receitas"]'::jsonb;
begin
 if p_source is null or p_source not in ('current_event','financial_events','confirmed_fact')
    or nullif(trim(p_source_ref),'') is null or p_event_date is null
    or p_event_date > current_date or p_amount is null or p_amount <= 0
    or nullif(trim(p_account),'') is null then
   raise exception 'Este recebimento não tem uma origem confirmada compatível com a revisão individual.';
 end if;
 -- STRICT rejects absent and ambiguous identities. Lock also protects the
 -- optimistic snapshot between validation and the category-only UPDATE.
 begin
   select e.* into strict f from public.financial_events e
   join public.accounts a on a.id=e.account_id and a.user_id=e.user_id
   where e.user_id=u and (e.id::text=p_source_ref or e.legacy_id=p_source_ref
     or 'financial_events:'||e.id::text=p_source_ref)
     and e.event_date=p_event_date and e.amount=p_amount
     and translate(lower(trim(a.institution)),'ú','u')=translate(lower(trim(p_account)),'ú','u')
   for update of e;
 exception when no_data_found or too_many_rows then
   raise exception 'Lançamento ausente, alterado ou ambíguo. Atualize o Fluxo antes de revisar.';
 end;
 if f.nature is distinct from 'income' or f.status is distinct from 'active'
   or f.is_projection is distinct from false or f.is_suppressed is distinct from false
   or f.is_internal_transfer is distinct from false then
   raise exception 'Somente receitas confirmadas podem ser classificadas aqui; transferências e previsões ficam preservadas.';
 end if;
 before_row := to_jsonb(f); token := md5(before_row::text);
 if p_category is not null and (p_expected is null or p_expected <> token) then
   raise exception 'O lançamento mudou desde a conferência. Feche e abra novamente; nada foi salvo.';
 end if;
 select coalesce(jsonb_agg(to_jsonb(e)),'[]'::jsonb) into rows_json
 from public.lts_historical_effective_cash_v5(u,p_event_date,p_event_date) e
 where e.source in ('current_event','financial_events','confirmed_fact')
   and (e.source_ref=f.id::text or e.source_ref=f.legacy_id or e.source_ref='financial_events:'||f.id::text)
   and e.event_date=f.event_date and e.signed_amount=f.amount
   and translate(lower(trim(e.account)),'ú','u')=translate(lower(trim(p_account)),'ú','u');
 if jsonb_array_length(rows_json) <> 1 then
   raise exception 'A origem não corresponde a um único recebimento no relatório. Nenhuma alteração foi feita.';
 end if;
 effective := rows_json->0;
 if coalesce((effective->>'internal_transfer')::boolean,false)
   or coalesce((effective->>'excluded_from_spend')::boolean,false) then
   raise exception 'Transferência ou movimento excluído: use a revisão da origem, não uma categoria de receita.';
 end if;
 if lower(trim(coalesce(f.category,''))) not in ('','a classificar','—','classificação pendente')
   or lower(trim(coalesce(effective->>'category',''))) not in ('','a classificar','—','classificação pendente') then
   return jsonb_build_object('ok',true,'editable',false,'saved',false,
     'category',coalesce(nullif(effective->>'category',''),f.category),
     'reason','Este recebimento já tem classificação na origem ou no relatório. A classificação existente foi preservada.');
 end if;
 if p_category is null then
   return jsonb_build_object('ok',true,'editable',true,'saved',false,'token',token,'options',options,
     'event',jsonb_build_object('description',f.description_raw,'event_date',f.event_date,
       'account',p_account,'amount',f.amount,'category',f.category));
 end if;
 if not (options ? p_category) then raise exception 'Escolha uma categoria de receita disponível.'; end if;
 update public.financial_events set category=p_category where user_id=u and id=f.id;
 -- Refuse a silent save hidden by a semantic rule/read-model overlay.
 if not exists(select 1 from public.lts_historical_effective_cash_v5(u,p_event_date,p_event_date) e
   where e.source in ('current_event','financial_events','confirmed_fact')
   and (e.source_ref=f.id::text or e.source_ref=f.legacy_id or e.source_ref='financial_events:'||f.id::text)
   and e.category=p_category and e.event_date=f.event_date and e.signed_amount=f.amount) then
   raise exception 'A categoria não foi refletida no relatório; a alteração foi desfeita.';
 end if;
 insert into public.lts_access_audit(user_id,email,action,meta)
 values(u,lower(coalesce(auth.jwt()->>'email','')),'income_category_v183',
   jsonb_build_object('source',p_source,'source_ref',p_source_ref,'event_id',f.id,
     'before_category',f.category,'after_category',p_category,'event_date',f.event_date,
     'amount',f.amount,'account_id',f.account_id,'cash_changed',false));
 return jsonb_build_object('ok',true,'saved',true,'category',p_category,'cash_changed',false);
end $$;
revoke all on function lts_income_private.review_v183(text,text,date,text,numeric,text,text) from public,anon,authenticated;
grant execute on function lts_income_private.review_v183(text,text,date,text,numeric,text,text) to authenticated;

create or replace function public.lts_browser_income_category_v183(
 p_source text, p_source_ref text, p_event_date date, p_account text,
 p_amount numeric, p_category text default null, p_expected text default null
) returns jsonb language sql security invoker set search_path = '' as $$
 select lts_income_private.review_v183(p_source,p_source_ref,p_event_date,p_account,p_amount,p_category,p_expected);
$$;
revoke all on function public.lts_browser_income_category_v183(text,text,date,text,numeric,text,text) from public,anon,authenticated;
grant execute on function public.lts_browser_income_category_v183(text,text,date,text,numeric,text,text) to authenticated;
