CREATE OR REPLACE FUNCTION public.lts_browser_wealth_detail_v242()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); j jsonb:=public.lts_browser_wealth_detail_v4(); a jsonb:=public.lts_liquidity_adjustments_v242(u,current_date); cash jsonb:=public.lts_browser_cash_today_v242(); s jsonb:=j->'rsu_summary'; summary jsonb:=j#>'{wealth,summary}'; delta numeric; key text; d0_delta numeric:=coalesce((j#>>'{wealth,liquidity,d0}')::numeric,0)-(cash->>'d0')::numeric;
BEGIN
 j:=jsonb_set(j,'{rsu_summary}',s||jsonb_build_object('available_total_brl',cash->'brokerage_available','settled_withdrawals_brl',a->'brokerage_settled_withdrawals','component_position_requires_new_statement',(a->>'brokerage_settled_withdrawals')::numeric>0));
 j:=jsonb_set(j,'{wealth,liquidity}',coalesce(j#>'{wealth,liquidity}','{}')||jsonb_build_object('bank_cash',cash->'cash','fgts_contingency',cash->'fgts','d0',cash->'d0'));
 j:=jsonb_set(j,'{morgan_statement,available_after_settled_transfers_brl}',cash->'brokerage_available');
 j:=jsonb_set(j,'{current_liquidity}',cash-'day');
 j:=jsonb_set(j,'{wealth,liquidity}',coalesce(j#>'{wealth,liquidity}','{}')||jsonb_build_object('d3',cash->'brokerage_available','through_d3',cash->'available_total'));
 j:=jsonb_set(j,'{wealth,distribution}',coalesce((SELECT jsonb_agg(x||CASE x->>'name' WHEN 'Liquidez até D+3' THEN jsonb_build_object('value',cash->'available_total','detail','Contas, aplicações e ações') WHEN 'FGTS' THEN jsonb_build_object('value',cash->'fgts','detail','Saldo restrito') ELSE '{}'::jsonb END) FROM jsonb_array_elements(coalesce(j#>'{wealth,distribution}','[]'))x),'[]'));
 delta:=d0_delta+(a->>'brokerage_settled_withdrawals')::numeric+coalesce((summary->>'restricted_contingency')::numeric,0)-(cash->>'fgts')::numeric;
 FOREACH key IN ARRAY ARRAY['assets_central','net_worth_central','net_worth_low','net_worth_high'] LOOP
  IF summary ? key THEN summary:=jsonb_set(summary,ARRAY[key],to_jsonb((summary->>key)::numeric-delta)); END IF;
 END LOOP;
 summary:=summary||jsonb_build_object('liquidity_through_d3',cash->'available_total','restricted_contingency',cash->'fgts');
 IF (summary->>'assets_central')::numeric>0 THEN summary:=summary||jsonb_build_object('cipo_share_of_assets_pct',round((j#>>'{wealth,assets,cipo_396,market_central}')::numeric/(summary->>'assets_central')::numeric*100,1),'known_debt_to_assets_pct',round((summary->>'known_debt_total')::numeric/(summary->>'assets_central')::numeric*100,1)); END IF;
 j:=jsonb_set(j,'{wealth,summary}',summary);
 IF j#>'{wealth_v167,assets_central_including_pensions}' IS NOT NULL THEN j:=jsonb_set(j,'{wealth_v167,assets_central_including_pensions}',to_jsonb((j#>>'{wealth_v167,assets_central_including_pensions}')::numeric-delta)); END IF;
 IF j#>'{wealth_v167,net_worth_central_including_pensions}' IS NOT NULL THEN j:=jsonb_set(j,'{wealth_v167,net_worth_central_including_pensions}',to_jsonb((j#>>'{wealth_v167,net_worth_central_including_pensions}')::numeric-delta)); END IF;
 RETURN j||jsonb_build_object('reader_revision','v242-settled-resource-transfers');
END $function$

