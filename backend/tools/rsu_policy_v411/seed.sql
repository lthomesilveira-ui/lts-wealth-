-- Two synthetic owners: only the first has an explicit policy.
INSERT INTO public.app_settings VALUES('00000000-0000-4000-8000-000000000001','{"market_quote_mode":"manual"}',now()),
 ('00000000-0000-4000-8000-000000000002','{"market_quote_mode":"manual"}',now());
INSERT INTO public.legacy_namespace(usuario_id,chave,valor_bruto) VALUES('00000000-0000-4000-8000-000000000001','lts_owner_rsu_policy_v411',
 '{"schema_version":1,"policy":{"reserve_rate":0.30,"net_factor":0.70,"scope":["RSU","Cash RSU"],"approved_on":"2026-01-02"},
 "morgan_reference":{"as_of_date":null,"received_at":null,"received_on":"2026-01-02","currency":"BRL","total_gross_brl":1505,"available_total_brl":3,"unavailable_gross_brl":1502,"regular_rsu_gross_brl":1000,"cash_rsu_gross_brl":500,"brokerage_cash_brl":3,"unallocated_gross_brl":2,"source_document_ids":[]},
 "acceleration":{"status":"conditional","event":"Synthetic closing","confirmed_date":null,"pre_2026_only":true,"price_usd":14,"grants":[
 {"grant_id":"old","grant_date":"2025-03-31","asset_type":"RSU","quantity":6},
 {"grant_id":"new","grant_date":"2026-03-31","asset_type":"RSU","quantity":4},
 {"grant_id":"cash","grant_date":"2026-02-18","asset_type":"Cash RSU","quantity":5}]},
 "payroll":{"monthly_base_brl":10000,"coopharma_treatment":"subtract_documented_schedule_once","actual_net_preserved":true}}');
INSERT INTO public.lts_future_liquidity_schedule(id,user_id,asset_type,institution,eligibility_date,settlement_days,quantity,unit_price_assumption,fx_assumption,gross_value_brl,net_value_brl,tax_status,cash_treatment,confidence,source,metadata,active)
SELECT prefix||x.id,u,x.kind,'Synthetic broker',current_date+x.days,3,x.qty,100,1,x.gross,x.net,'legacy','conditional_future_liquidity','synthetic','synthetic',x.metadata,true
FROM (VALUES('00000000-0000-4000-8000-000000000001'::uuid,'a_'),('00000000-0000-4000-8000-000000000002'::uuid,'b_'))owners(u,prefix)
CROSS JOIN(VALUES
 ('old','RSU',10,6::numeric,600::numeric,333::numeric,'{"grant_id":"old","grant_date":"2025-03-31","grant_date_basis":"documentary","grant_source_document_ids":["synthetic"]}'::jsonb),
 ('new','RSU',10,4,400,222,'{"grant_id":"new","grant_date":"2026-03-31","grant_date_basis":"documentary","grant_source_document_ids":["synthetic"]}'::jsonb),
 ('cash','Cash',20,5,500,350,'{"grant_id":"cash","grant_date":"2026-02-18","grant_date_basis":"documentary","grant_source_document_ids":["synthetic"]}'::jsonb),
 ('unknown','RSU',30,1,100,NULL,'{}'::jsonb))x(id,kind,days,qty,gross,net,metadata);
INSERT INTO public.lts_brokerage_position_snapshots(user_id,institution,as_of_date,available_total_brl,vested_shares_available_brl,brokerage_cash_available_brl,future_rsu_gross_brl,future_cash_rsu_gross_brl,other_unavailable_brl,total_gross_brl,unavailable_total_brl,metadata)
SELECT user_id,'Morgan Stanley',current_date-1,103,100,3,1100,500,2,1705,1602,'{}'::jsonb FROM public.app_settings;
INSERT INTO public.lts_validated_lock_registry VALUES('morgan_available_synthetic',jsonb_build_object('as_of',current_date-1,'total_available_brl',103,'shares_value_brl',100,'brokerage_cash_brl',3),NULL);
INSERT INTO public.asset_positions(user_id,asset_type,value_brl,is_available_now,liquidity_class,as_of_date,metadata)
 SELECT user_id,'RSU',100,true,'D+3',current_date-1,'{}'::jsonb FROM public.app_settings;
INSERT INTO public.accounts SELECT user_id,true,'{"balance":0}'::jsonb FROM public.app_settings;
INSERT INTO public.financial_events(user_id,event_date,amount,metadata)SELECT user_id,current_date-2,123.45,'{"realized":true}'::jsonb FROM public.app_settings;
INSERT INTO public.lts_v229_read_cache SELECT user_id,'synthetic_old_gross','{"value":1600}'::jsonb FROM public.app_settings;
INSERT INTO public.lts_dashboard_cockpit_cache SELECT user_id,'{"value":1600}'::jsonb FROM public.app_settings;
INSERT INTO public.lts_flow_future_read_cache SELECT user_id FROM public.app_settings;
INSERT INTO public.lts_flow_future_read_cache_v2 SELECT user_id FROM public.app_settings;
INSERT INTO public.lts_product_read_cache SELECT user_id,jsonb_build_object('planning_ladder',jsonb_build_object('to',current_date+40),
 'wealth',jsonb_build_object('asset_layers',jsonb_build_object('derived_future_schedule',
 (SELECT jsonb_agg(jsonb_build_object('id',s.id,'available_date',s.eligibility_date+s.settlement_days,'gross_value_brl',s.gross_value_brl,'net_value_brl',s.net_value_brl)) FROM public.lts_future_liquidity_schedule s WHERE s.user_id=a.user_id))))
FROM public.app_settings a;
SELECT set_config('test.user_id','00000000-0000-4000-8000-000000000002',false);
CREATE TABLE public.qa_before_v411 AS SELECT
 (SELECT md5(jsonb_agg(to_jsonb(s)ORDER BY id)::text) FROM public.lts_future_liquidity_schedule s) schedule_hash,
 (SELECT md5(jsonb_agg(to_jsonb(s)ORDER BY id)::text) FROM public.asset_positions s) positions_hash,
 (SELECT md5(jsonb_agg(to_jsonb(s)ORDER BY id)::text) FROM public.financial_events s) history_hash,
 public.lts_browser_wealth_detail_v2() wealth_v2,
 public.lts_daily_flow_fix86_v19('00000000-0000-4000-8000-000000000002',current_date,current_date+40) flow_v19,
 public.lts_daily_flow_fix86_v20('00000000-0000-4000-8000-000000000002',current_date,current_date+40) flow_v20,
 public.lts_cashflow_scenarios_v1('00000000-0000-4000-8000-000000000002',current_date,current_date+40) scenarios,
 public.qa_outputs_v411('00000000-0000-4000-8000-000000000002') all_reader_outputs;
