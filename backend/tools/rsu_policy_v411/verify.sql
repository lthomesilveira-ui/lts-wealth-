-- Synthetic regression checks. All hypothetical writes are rolled back locally.
SELECT set_config('test.user_id','00000000-0000-4000-8000-000000000001',false);
SELECT public.qa_assert_v411('source schedule unchanged',
 (SELECT schedule_hash FROM qa_before_v411)=(SELECT md5(jsonb_agg(to_jsonb(s)ORDER BY id)::text)FROM lts_future_liquidity_schedule s));
SELECT public.qa_assert_v411('positions unchanged',
 (SELECT positions_hash FROM qa_before_v411)=(SELECT md5(jsonb_agg(to_jsonb(s)ORDER BY id)::text)FROM asset_positions s));
SELECT public.qa_assert_v411('realized history unchanged',
 (SELECT history_hash FROM qa_before_v411)=(SELECT md5(jsonb_agg(to_jsonb(s)ORDER BY id)::text)FROM financial_events s));
SELECT public.qa_assert_v411('policy owner: every component uses rounded gross once',
 (SELECT count(*)=4 AND bool_and(net_value_brl=round(gross_value_brl*.70,2))
  FROM lts_future_liquidity_effective_v290 WHERE user_id='00000000-0000-4000-8000-000000000001'));
SELECT public.qa_assert_v411('Cash RSU is 350, never a second 245 deduction',
 (SELECT net_value_brl=350 FROM lts_future_liquidity_effective_v290 WHERE id='a_cash'));
SELECT public.qa_assert_v411('manual legacy net and NULL preserved without policy',
 (SELECT bool_and(to_jsonb(s)=to_jsonb(e)) FROM lts_future_liquidity_schedule s
  JOIN lts_future_liquidity_effective_v290 e USING(id) WHERE s.user_id='00000000-0000-4000-8000-000000000002'));

DO $$DECLARE before jsonb;after jsonb;r record;BEGIN
 SELECT all_reader_outputs INTO before FROM qa_before_v411;
 after:=public.qa_outputs_v411('00000000-0000-4000-8000-000000000002');
 FOR r IN SELECT key,value FROM jsonb_each(before) LOOP
  PERFORM public.qa_assert_v411('unconfigured owner preserves monetary fields: '||r.key,
   public.qa_numeric_same_v411(r.value,after->r.key));
 END LOOP;
 PERFORM public.qa_assert_v411('unconfigured owner keeps gross labels and warnings',
  after#>'{executive,risk_layers,conditional_future_liquidity,meaning}'=before#>'{executive,risk_layers,conditional_future_liquidity,meaning}'
  AND after#>'{executive,guardrails}'=before#>'{executive,guardrails}'
  AND after#>'{scenarios1,scenarios,2,label}'=before#>'{scenarios1,scenarios,2,label}'
  AND after#>'{scenarios1,scenarios,2,warning}'=before#>'{scenarios1,scenarios,2,warning}');
 PERFORM public.qa_assert_v411('unconfigured owner never labels legacy gross as new net',
  after#>'{executive,risk_layers,conditional_future_liquidity,future_rsu_net}'='null'::jsonb
  AND after#>>'{executive,risk_layers,conditional_future_liquidity,amount_basis}'='legacy_basis'
  AND after#>'{scenarios1,conditional_rsu_net_in_horizon}'='null'::jsonb
  AND after#>'{scenarios2,conditional_rsu_net_in_horizon}'='null'::jsonb
  AND after#>'{scenarios_flow,conditional_rsu_net_in_horizon}'='null'::jsonb);
 PERFORM public.qa_assert_v411('new regular net reserve fields are unknown without owner policy',
  after#>'{wealth3,rsu_summary,future_regular_net_brl}'='null'::jsonb
  AND after#>'{wealth4,morgan_statement,future_components,regular_rsu_after_reserve_brl}'='null'::jsonb
  AND after#>'{wealth4,morgan_statement,future_components,regular_rsu_reserve_brl}'='null'::jsonb);
END$$;
SELECT set_config('test.user_id','00000000-0000-4000-8000-000000000001',false);
DO $$DECLARE j jsonb:=public.lts_browser_rsu_policy_v411();w jsonb;BEGIN
 PERFORM public.qa_assert_v411('reader summary separated gross and net',
  (j#>>'{summary,schedule_gross_brl}')::numeric=1600 AND (j#>>'{summary,schedule_net_brl}')::numeric=1120);
 PERFORM public.qa_assert_v411('untimed reference cannot replace dated position',
  j#>'{morgan_reference,as_of_date}'='null'::jsonb AND j#>>'{morgan_reference,received_on}'='2026-01-02'
  AND j#>'{morgan_reference,replaces_dated_position}'='false'::jsonb);
 PERFORM public.qa_assert_v411('known reference net plus untouched cash',
  (j#>>'{morgan_reference,known_awards_net_brl}')::numeric=1050
  AND (j#>>'{morgan_reference,brokerage_cash_brl}')::numeric=3
  AND (j#>>'{morgan_reference,known_after_reserve_brl}')::numeric=1053
  AND j#>'{morgan_reference,unallocated_net_brl}'='null'::jsonb);
 PERFORM public.qa_assert_v411('conditional grants exclude 2026 and preserve calendar',
  j#>>'{acceleration,status}'='conditional' AND j#>'{acceleration,confirmed_date}'='null'::jsonb
  AND (j#>>'{acceleration,eligible_quantity}')::numeric=6
  AND (j#>>'{acceleration,excluded_quantity}')::numeric=9
  AND j#>'{acceleration,calendar_unchanged}'='true'::jsonb
  AND (j#>>'{acceleration,schedule_mapped_count}')::integer=3
  AND (j#>>'{acceleration,schedule_unmapped_count}')::integer=1);
 w:=public.lts_browser_wealth_detail_v4();
 PERFORM public.qa_assert_v411('dated available money and vested position stay untouched',
  (w#>>'{morgan_statement,available_total_brl}')::numeric=103
  AND (w#>>'{morgan_statement,available_components,vested_shares_brl}')::numeric=100
  AND (w#>>'{morgan_statement,available_components,brokerage_cash_brl}')::numeric=3);
 PERFORM public.qa_assert_v411('dated snapshot unknown residual has no invented net',
  (w#>>'{morgan_statement,future_components,regular_rsu_after_reserve_brl}')::numeric=770
  AND (w#>>'{morgan_statement,future_components,cash_rsu_after_reserve_brl}')::numeric=350
  AND (w#>>'{morgan_statement,future_components,future_after_reserve_brl}')::numeric=1120
  AND w#>'{morgan_statement,future_components,unallocated_net_brl}'='null'::jsonb
  AND (w#>>'{morgan_statement,considered_total_after_reserve_brl}')::numeric=1223);
END$$;
SELECT public.qa_assert_v411('future flow uses net with unchanged current anchor',
 (SELECT vested_rsu_value=1220 FROM public.lts_flow_dynamic_layers_v1('00000000-0000-4000-8000-000000000001',current_date,current_date+40)WHERE flow_date=current_date+40));
SELECT public.qa_assert_v411('cash ladder adds 1120 net and preserves dated available 103',
 (SELECT balance_with_scheduled_vesting=1223 AND rsu_vested_today=103
 FROM public.lts_dashboard_cash_ladder_from_flow_v229('00000000-0000-4000-8000-000000000001',current_date,current_date+40,
  public.lts_daily_flow_fix86_v14('00000000-0000-4000-8000-000000000001',current_date,current_date+40))WHERE flow_date=current_date+40));
SELECT public.qa_assert_v411('flow milestone carries net plus explicit gross',
 (SELECT bool_and((e->>'signed_amount')::numeric=(e->>'net_value_brl')::numeric)
 FROM jsonb_array_elements(public.lts_daily_flow_fix86_v20('00000000-0000-4000-8000-000000000001',current_date,current_date+40)->'events')e
 WHERE e ? 'net_value_brl'));

-- Mixed or unmapped grants cannot be accelerated through either writer or RPC.
DO $$DECLARE blocked boolean:=false;BEGIN
 BEGIN PERFORM public.lts_browser_save_vesting_anticipation_v1('rsu:'||(current_date+10)::text,current_date+1);
 EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'Antecipação exige%' THEN blocked:=true;ELSE RAISE;END IF;END;
 PERFORM public.qa_assert_v411('mixed group cannot bypass grant cutoff',blocked);
 blocked:=false;
 BEGIN PERFORM public.lts_browser_vesting_scenario_v1(ARRAY['a_unknown'],current_date+1);
 EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'O cenário exige%' THEN blocked:=true;ELSE RAISE;END IF;END;
 PERFORM public.qa_assert_v411('unmapped grant cannot accelerate',blocked);
 blocked:=false;
 BEGIN PERFORM public.lts_browser_vesting_scenario_v1(ARRAY['a_new'],current_date+1);
 EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'O cenário exige%' THEN blocked:=true;ELSE RAISE;END IF;END;
 PERFORM public.qa_assert_v411('2026 grant cannot accelerate',blocked);
 PERFORM public.qa_assert_v411('documented pre2026 scenario is read only and net',
  (public.lts_browser_vesting_scenario_v1(ARRAY['a_old'],current_date+1)->>'selected_amount_brl')::numeric=420);
END$$;

-- A single invalid component must fail before aggregation, not disappear in SUM.
DO $$DECLARE blocked boolean:=false;BEGIN
 BEGIN
  UPDATE lts_future_liquidity_schedule SET gross_value_brl=NULL WHERE id='a_new';
  PERFORM public.lts_browser_rsu_policy_v411();
 EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'Componente de RSU sem valor bruto%' THEN blocked:=true;ELSE RAISE;END IF;END;
 PERFORM public.qa_assert_v411('one NULL component fails before aggregate',blocked);
END$$;

DO $$DECLARE ok boolean:=false;BEGIN
 BEGIN
  UPDATE lts_future_liquidity_schedule SET gross_value_brl=.05 WHERE id IN('a_old','a_new');
  ok:=(SELECT sum(net_value_brl)=.08 FROM lts_future_liquidity_effective_v290 WHERE id IN('a_old','a_new'));
  RAISE SQLSTATE 'P9999';
 EXCEPTION WHEN SQLSTATE 'P9999' THEN NULL;END;
 PERFORM public.qa_assert_v411('round each component before summing',ok);
END$$;

DO $$DECLARE ok boolean:=false;BEGIN
 BEGIN
  UPDATE qa_market_context_v411 SET context='{"complete":true,"stock":{"value":10},"usd_brl":{"value":5}}';
  UPDATE app_settings SET settings='{"market_quote_mode":"automatic"}';
  ok:=(SELECT bool_and(net_value_brl=round(gross_value_brl*.7,2)) FROM lts_future_liquidity_effective_v290 WHERE id LIKE 'a_%')
   AND (SELECT bool_and(net_value_brl=round(gross_value_brl*CASE WHEN asset_type='Cash' THEN .7 ELSE 1 END,2)) FROM lts_future_liquidity_effective_v290 WHERE id LIKE 'b_%');
  RAISE SQLSTATE 'P9999';
 EXCEPTION WHEN SQLSTATE 'P9999' THEN NULL;END;
 PERFORM public.qa_assert_v411('automatic market quotes apply policy once and retain other owner legacy',ok);
END$$;

DO $$DECLARE ok boolean:=false;BEGIN
 BEGIN
  PERFORM public.lts_browser_save_award_assumption_v1('rsu:'||(current_date+10)::text,20,5);
  ok:=(SELECT bool_and(net_value_brl=round(gross_value_brl*.7,2)) FROM lts_future_liquidity_schedule WHERE id IN('a_old','a_new'));
  PERFORM public.lts_browser_save_all_award_assumptions_v1(20,5);
  ok:=ok AND (SELECT bool_and(net_value_brl=round(gross_value_brl*.7,2)) FROM lts_future_liquidity_schedule WHERE id LIKE 'a_%');
  PERFORM set_config('test.user_id','00000000-0000-4000-8000-000000000002',true);
  PERFORM public.lts_browser_save_all_award_assumptions_v1(20,5);
  ok:=ok AND (SELECT bool_and(net_value_brl=round(gross_value_brl*CASE WHEN asset_type='Cash' THEN .7 ELSE 1 END,2)) FROM lts_future_liquidity_schedule WHERE id LIKE 'b_%');
  RAISE SQLSTATE 'P9999';
 EXCEPTION WHEN SQLSTATE 'P9999' THEN NULL;END;
 PERFORM public.qa_assert_v411('price writers use owner policy and preserve unconfigured owner rule',ok);
END$$;

DO $$DECLARE ok boolean:=false;blocked boolean:=false;BEGIN
 BEGIN
  INSERT INTO legacy_namespace(usuario_id,chave,valor_bruto)VALUES('00000000-0000-4000-8000-000000000002','lts_owner_rsu_policy_v411','malformed');
  ok:=(SELECT sum(net_value_brl)=1120 FROM lts_future_liquidity_effective_v290 WHERE user_id='00000000-0000-4000-8000-000000000001');
  ok:=ok AND (public.lts_browser_rsu_policy_v411()#>>'{summary,schedule_net_brl}')::numeric=1120;
  BEGIN
   PERFORM set_config('test.user_id','00000000-0000-4000-8000-000000000002',true);
   PERFORM public.lts_browser_rsu_policy_v411();
  EXCEPTION WHEN invalid_text_representation THEN blocked:=true;END;
  RAISE SQLSTATE 'P9999';
 EXCEPTION WHEN SQLSTATE 'P9999' THEN NULL;END;
 PERFORM public.qa_assert_v411('malformed other owner cannot break current owner view or RPC',ok AND blocked);
END$$;

DO $$DECLARE ok boolean:=false;j jsonb;BEGIN
 BEGIN
  UPDATE lts_future_liquidity_schedule SET gross_value_brl=NULL WHERE id='b_unknown';
  PERFORM set_config('test.user_id','00000000-0000-4000-8000-000000000002',true);
  j:=public.lts_browser_rsu_policy_v411();
  ok:=j#>'{policy,enabled}'='false'::jsonb AND j->'summary'='null'::jsonb AND j->'future_schedule'='[]'::jsonb;
  RAISE SQLSTATE 'P9999';
 EXCEPTION WHEN SQLSTATE 'P9999' THEN NULL;END;
 PERFORM public.qa_assert_v411('unconfigured owner exits before validating or labeling legacy financial rows',ok);
END$$;

DO $$DECLARE blocked boolean:=false;BEGIN
 BEGIN
  UPDATE legacy_namespace SET valor_bruto='' WHERE usuario_id='00000000-0000-4000-8000-000000000001' AND chave='lts_owner_rsu_policy_v411';
  PERFORM public.lts_browser_rsu_policy_v411();
 EXCEPTION WHEN raise_exception THEN IF SQLERRM='Política de RSU existente sem conteúdo válido.' THEN blocked:=true;ELSE RAISE;END IF;END;
 PERFORM public.qa_assert_v411('damaged existing policy never falls back silently to gross',blocked);
END$$;

SELECT public.qa_assert_v411('private helpers have no public or authenticated execution',
 (SELECT bool_and(NOT has_function_privilege('anon',p.oid,'EXECUTE') AND NOT has_function_privilege('authenticated',p.oid,'EXECUTE')
  AND has_function_privilege('service_role',p.oid,'EXECUTE') AND NOT p.prosecdef AND p.proconfig=ARRAY['search_path=""'])
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='lts_award_private' AND p.proname LIKE '%_v411'));
SELECT public.qa_assert_v411('RPC authenticated gate and fixed search path',
 (SELECT p.prosecdef AND has_function_privilege('authenticated',p.oid,'EXECUTE') AND NOT has_function_privilege('anon',p.oid,'EXECUTE')
  AND p.proconfig @> ARRAY['search_path=""','TimeZone=America/Sao_Paulo'] FROM pg_proc p WHERE p.oid='public.lts_browser_rsu_policy_v411()'::regprocedure));
SELECT public.qa_assert_v411('effective view remains service-only security invoker',
 (SELECT reloptions @> ARRAY['security_invoker=true'] AND NOT has_table_privilege('anon',oid,'SELECT')
  AND NOT has_table_privilege('authenticated',oid,'SELECT') AND has_table_privilege('service_role',oid,'SELECT')
  FROM pg_class WHERE oid='public.lts_future_liquidity_effective_v290'::regclass));
DO $$DECLARE blocked boolean:=false;BEGIN
 BEGIN
  PERFORM set_config('test.user_id','',true);PERFORM public.lts_browser_rsu_policy_v411();
 EXCEPTION WHEN raise_exception THEN IF SQLERRM='authentication required' THEN blocked:=true;ELSE RAISE;END IF;END;
 PERFORM public.qa_assert_v411('missing authenticated owner is rejected',blocked);
END$$;
SELECT public.qa_assert_v411('all temporary writer/source changes rolled back',
 (SELECT schedule_hash FROM qa_before_v411)=(SELECT md5(jsonb_agg(to_jsonb(s)ORDER BY id)::text)FROM lts_future_liquidity_schedule s)
 AND NOT EXISTS(SELECT 1 FROM audit_log));
