CREATE OR REPLACE FUNCTION public.lts_open_finance_sources_v226(p_user_id uuid, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare result jsonb; source_as_of date;
begin
  if p_user_id is distinct from public.lts_open_finance_pilot_owner_v1() then raise exception 'PILOT_OWNER_MISMATCH'; end if;
  if p_from is null or p_to is null or p_to<p_from or p_to-p_from>31 then raise exception 'SOURCE_WINDOW_MAX_32_DAYS'; end if;
  source_as_of:=nullif(public.lts_current_evidence_position_v1(p_user_id)->>'as_of','')::date;
  with sources as (
    select jsonb_build_object('kind',k,'table','accounts','ref',a.id,'identity',a.legacy_id,'institution',a.institution,'name',a.account_name,
      'account_type',a.account_type,'currency',a.currency,'amount',nullif(a.metadata->>'balance','')::numeric,'date',a.metadata->>'balance_as_of',
      'provider_id',a.metadata->>'pluggy_account_id','scope','documented_account_position') j
    from public.accounts a cross join unnest(array['account','balance']) k where a.user_id=p_user_id
    union all
    select jsonb_build_object('kind','transaction','table','lts_historical_effective_cash_v5','ref',h.source||':'||h.source_ref,
      'institution',h.account,'date',h.event_date,'amount',h.signed_amount,'description',h.description,'currency','BRL','scope',h.confidence)
    from (select p_from lo,least(p_to,coalesce(source_as_of,p_to),current_date) hi where p_from<=least(p_to,coalesce(source_as_of,p_to),current_date)) w cross join lateral public.lts_historical_effective_cash_v5(p_user_id,w.lo,w.hi) h
    union all
    select jsonb_build_object('kind','transaction','table','lts_corrected_cashflow_operational_v1','ref',h.source||':'||h.source_ref,
      'institution',h.account,'date',h.event_date,'amount',h.signed_amount,'description',h.description,'currency','BRL','scope','operational_not_statement_certified')
    from (select greatest(p_from,coalesce(source_as_of,p_from-1)+1) lo,least(p_to,current_date) hi where greatest(p_from,coalesce(source_as_of,p_from-1)+1)<=least(p_to,current_date)) w cross join lateral public.lts_corrected_cashflow_operational_v1(p_user_id,w.lo,w.hi) h
    union all
    select jsonb_build_object('kind','credit_card','table','lts_card_instruments','ref',a.id,'institution',a.issuer,'name',a.product_name,
      'last4',a.last4,'currency','BRL','amount',null,'date',null,'scope','instrument_identity_only')
    from public.lts_card_instruments a where a.user_id=p_user_id
    union all
    select jsonb_build_object('kind','invoice','table','card_invoices','ref',a.id,'institution','Itaú','name',a.card_name,
      'last4',coalesce(a.metadata->>'last4',a.metadata->>'card_final'),'currency','BRL','date',a.due_date,'amount',a.amount,'scope',a.source)
    from public.card_invoices a where a.user_id=p_user_id and (a.card_name ilike '%ita%' or a.metadata->>'bank' in ('Itaú','Itau')) and a.due_date between p_from and p_to
    union all
    select jsonb_build_object('kind','card_transaction','table','lts_card_purchase_detail','ref',a.source_id||':'||a.row_id::text,
      'institution',a.bank,'name',a.card_name,'last4',a.card_final,'currency','BRL','date',a.purchase_date,
      'amount',-a.installment_amount,'description',a.description_raw,'scope',a.source)
    from public.lts_card_purchase_detail a where a.user_id=p_user_id and a.purchase_date between p_from and p_to
    union all
    select jsonb_build_object('kind','investment','table','asset_positions','ref',a.id,'institution',coalesce(a.metadata->>'institution',case when a.asset_name ilike '%ita%' then 'Itaú' end),
      'name',a.asset_name,'currency','BRL','date',a.as_of_date,'amount',a.value_brl,'code',a.metadata->>'investment_code',
      'provider_id',a.metadata->>'pluggy_investment_id','scope',a.asset_type)
    from public.asset_positions a where a.user_id=p_user_id
    union all
    select jsonb_build_object('kind','loan','table','lts_debt_position','ref',a.id,'institution',a.institution,'contract_ref',a.contract_ref,
      'currency','BRL','date',a.as_of_date,'amount',a.debt_balance,'scope',a.status)
    from public.lts_debt_position a where a.user_id=p_user_id
  ) select coalesce(jsonb_agg(j),'[]'::jsonb) into result from sources;
  return jsonb_build_object('rows',result,'from',p_from,'to',p_to,'source_as_of',source_as_of,'complete_for_consulted_sources',true,
    'limitations',jsonb_build_array('Matches are relative to existing LTS readers, not universal historical certification.',
    'Account labels do not establish immutable identity.','Position dates and value bases must agree before exact comparison.'));
end $function$;
REVOKE ALL ON FUNCTION public.lts_open_finance_sources_v226(uuid,date,date) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_open_finance_sources_v226(uuid,date,date) TO service_role;

