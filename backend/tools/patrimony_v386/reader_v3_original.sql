CREATE OR REPLACE FUNCTION public.lts_browser_wealth_detail_v3()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid:=public.lts_browser_assert_user_v1();
  v_base jsonb;
  v_pensions jsonb:='[]'::jsonb;
  v_pension_total numeric:=0;
  v_rsu jsonb:='{}'::jsonb;
  v_commitments jsonb;
  v_docs jsonb;
  v_cipo_components jsonb:='[]'::jsonb;
  v_base_assets numeric:=0;
  v_base_net numeric:=0;
begin
  v_base:=public.lts_browser_wealth_detail_v2();
  with latest as (
    select distinct on (legacy_id) legacy_id,asset_name,as_of_date,quantity,unit_price,value_brl,liquidity_class,availability_note,metadata
    from public.asset_positions
    where user_id=v_uid and asset_type='private_pension'
    order by legacy_id,as_of_date desc,id desc
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',legacy_id,'name',asset_name,'as_of',as_of_date,'units',quantity,'unit_value',unit_price,
      'gross_balance_brl',value_brl,'liquidity_class',liquidity_class,'availability_note',availability_note,
      'tax_regime',metadata->>'tax_regime','profile',metadata->>'profile',
      'participant_balance_brl',metadata->'participant_balance_brl','sponsor_balance_brl',metadata->'sponsor_balance_brl',
      'monthly_return_brl',metadata->'monthly_return_brl','monthly_return_pct',metadata->'monthly_return_pct',
      'source_label',metadata->>'source_label'
    ) order by asset_name),'[]'::jsonb),coalesce(sum(value_brl),0)
    into v_pensions,v_pension_total from latest;

  select jsonb_build_object(
    'vested_shares_brl',coalesce(sum(value_brl) filter(where asset_type='RSU' and is_available_now),0),
    'brokerage_cash_brl',coalesce(sum(value_brl) filter(where asset_type='brokerage_cash' and is_available_now),0),
    'available_total_brl',coalesce(sum(value_brl) filter(where asset_type in ('RSU','brokerage_cash') and is_available_now),0),
    'as_of',max(as_of_date) filter(where asset_type in ('RSU','brokerage_cash')),
    'future_regular_brl',coalesce((select sum(coalesce(gross_value_brl,net_value_brl)) from public.lts_future_liquidity_effective_v290 where user_id=v_uid and active and upper(trim(asset_type))='RSU'),0),
    'future_cash_net_brl',coalesce((select sum(coalesce(net_value_brl,gross_value_brl)) from public.lts_future_liquidity_effective_v290 where user_id=v_uid and active and lower(asset_type) like '%cash%'),0),
    'future_considered_total_brl',coalesce((select sum(case when lower(asset_type) like '%cash%' then coalesce(net_value_brl,gross_value_brl) else coalesce(gross_value_brl,net_value_brl) end) from public.lts_future_liquidity_effective_v290 where user_id=v_uid and active),0)
  ) into v_rsu
  from public.asset_positions where user_id=v_uid;

  v_commitments:=public.lts_commitments_summary_v1(v_uid,current_date);
  v_docs:=public.lts_documentary_commitments_v1(v_uid);
  v_cipo_components:=coalesce(v_base#>'{wealth,cipo_reconciliation,components}',v_base#>'{cipo,components}','[]'::jsonb);
  v_base_assets:=coalesce(nullif(v_base#>>'{wealth,summary,assets_central}','')::numeric,0);
  v_base_net:=coalesce(nullif(v_base#>>'{wealth,summary,net_worth_central}','')::numeric,0);

  return v_base||jsonb_build_object(
    'version','wealth-detail-v4-v167-pensions-financing',
    'pensions',jsonb_build_object('total_gross_brl',v_pension_total,'positions',v_pensions,
      'tax_note','Regime regressivo: a alíquota depende do tempo de cada contribuição; o saldo líquido não é inferido.'),
    'rsu_summary',v_rsu,
    'financing',jsonb_build_object('summary',v_commitments,'documentary',v_docs),
    'cipo_detail',jsonb_build_object('components',v_cipo_components,
      'historical_purchase_plus_reform_brl',v_base#>'{wealth,assets,cipo_396,historical_purchase_plus_reform}',
      'current_payoff_brl',v_base#>'{wealth,assets,cipo_396,documentary_debt}',
      'contractual_outflow_current_terms_brl',(select x->'remaining_scheduled_outflow_current_terms'
        from jsonb_array_elements(coalesce(v_commitments->'commitments','[]'::jsonb)) x
        where x->>'id'='cipo_396' limit 1),
      'subject_to_tr',true),
    'wealth_v167',jsonb_build_object('assets_central_including_pensions',v_base_assets+v_pension_total,
      'net_worth_central_including_pensions',v_base_net+v_pension_total,'pensions_are_restricted',true),
    'schiavalli',jsonb_build_object('status','documentary_position_not_located','included_in_total',false)
  );
end
$function$
