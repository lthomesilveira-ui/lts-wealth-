-- Authenticated readers reuse the completed, source-invalidated flow payload.
-- Private helpers never accept an owner identity from the browser.
CREATE OR REPLACE FUNCTION public.lts_liquidity_adjustments_v242(p_user_id uuid,p_as_of date)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $fn$
 WITH policy AS (SELECT coalesce(settings->'liquidity_movements_v242','{}') j FROM public.app_settings WHERE user_id=p_user_id),
 pos AS (SELECT value_brl,as_of_date FROM public.asset_positions WHERE user_id=p_user_id AND asset_type='FGTS' AND as_of_date<=p_as_of ORDER BY as_of_date DESC,created_at DESC LIMIT 1),
 lock AS (SELECT (canonical_value->>'as_of')::date dt FROM public.lts_validated_lock_registry WHERE lock_key LIKE 'morgan_available_%' AND superseded_at IS NULL ORDER BY canonical_value->>'as_of' DESC LIMIT 1)
 SELECT jsonb_build_object('policy',coalesce((SELECT j FROM policy),'{}'),
 'fgts_documented',CASE WHEN p_as_of>=(SELECT (j#>>'{fgts,receipt_date}')::date FROM policy) AND (SELECT as_of_date FROM pos)<(SELECT (j#>>'{fgts,receipt_date}')::date FROM policy) THEN 0 ELSE (SELECT value_brl FROM pos) END,
 'brokerage_settled_withdrawals',coalesce((SELECT sum((x->>'amount_brl')::numeric) FROM policy CROSS JOIN LATERAL jsonb_array_elements(coalesce(j->'brokerage_withdrawals','[]'))x WHERE (x->>'settled_on')::date<=p_as_of AND (x->>'settled_on')::date>(SELECT dt FROM lock)),0));
$fn$;

CREATE OR REPLACE FUNCTION public.lts_flow_liquidity_adjustments_v242(p_user_id uuid,p_flow jsonb,p_as_of date)
RETURNS jsonb LANGUAGE plpgsql SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $fn$
DECLARE a jsonb:=public.lts_liquidity_adjustments_v242(p_user_id,p_as_of); policy jsonb:=a#>'{policy,fgts}';
 receipt date:=(policy->>'receipt_date')::date; withdrawal numeric:=(policy->>'total_brl')::numeric;
 deductions numeric:=(a->>'brokerage_settled_withdrawals')::numeric; cfg record; monthly numeric:=0;
 credits jsonb; base_date date; base_value numeric; days jsonb; historical_days jsonb;
BEGIN
 SELECT count(*) FILTER(WHERE dados->>'_k' IN('salario_base','percentual','ativo'))=3 valid,
 max((dados->>'_v')::numeric) FILTER(WHERE dados->>'_k'='salario_base') salary,
 max((dados->>'_v')::numeric) FILTER(WHERE dados->>'_k'='percentual') pct,
 bool_or((dados->>'_v')::boolean) FILTER(WHERE dados->>'_k'='ativo') active
 INTO cfg FROM public.fgts WHERE usuario_id=p_user_id;
 IF coalesce((policy->>'resume_configured_contributions')::boolean,false) AND cfg.valid AND cfg.active AND cfg.salary>=0 AND cfg.pct BETWEEN 0 AND 1 THEN monthly:=round(cfg.salary*cfg.pct,2); END IF;
 SELECT as_of_date,value_brl INTO base_date,base_value FROM public.asset_positions
 WHERE user_id=p_user_id AND asset_type='FGTS' AND as_of_date<=p_as_of ORDER BY as_of_date DESC,created_at DESC LIMIT 1;
 -- Persisted dates represent past estimates only; current effective salary events
 -- replace them for future months. A later primary position replaces accrued estimates.
 WITH live AS (
 SELECT left(e->>'event_date',7) payroll_month,min((e->>'event_date')::date) dt
 FROM jsonb_array_elements(coalesce(p_flow#>'{current_future,events}','[]'))e
 WHERE (e->>'event_date')::date>receipt AND (e->>'signed_amount')::numeric>0
 AND NOT coalesce((e->>'displaced')::boolean,false)
 AND (e->>'semantic_rule_id'='sys_salario_liquido_exact' OR lower(trim(e->>'description')) IN('salário','salário líquido'))
 GROUP BY left(e->>'event_date',7)
 ), calendar AS (
 SELECT dt FROM live UNION SELECT dt::date FROM jsonb_array_elements_text(coalesce(policy->'credit_dates','[]'))s(dt)
 WHERE dt::date>receipt AND dt::date<=p_as_of AND NOT EXISTS(SELECT 1 FROM live WHERE payroll_month=left(s.dt,7))
 ) SELECT coalesce(jsonb_agg(dt ORDER BY dt),'[]') INTO credits FROM calendar;
 SELECT coalesce(jsonb_agg(d||jsonb_build_object('fix86_columns',c||jsonb_build_object(
 'rsus_vested',(c->>'rsus_vested')::numeric-deductions,
 'saldo_apos_rsu',(c->>'saldo_apos_rsu')::numeric-deductions,
 'disponivel_total',(c->>'saldo_apos_rsu')::numeric-deductions,
 'posicao_curto_prazo',(c->>'saldo_apos_rsu')::numeric-deductions,
 'brokerage_settled_withdrawals',deductions,
 'fgts',documented+accrual,'fgts_documental',documented,'fgts_aportes_projetados',accrual,
 'saldo_apos_fgts',(c->>'saldo_apos_rsu')::numeric-deductions+documented+accrual,
 'saldo_apos_fgts_documental',(c->>'saldo_apos_rsu')::numeric-deductions+documented,
 'posicao_economica_total',(c->>'posicao_economica_total')::numeric-deductions-(c->>'fgts')::numeric+documented+accrual,
 'fgts_projection_basis','owner_confirmed_withdrawal_then_configured_regular_payroll'
 )) ORDER BY d->>'date'),'[]') INTO days
 FROM jsonb_array_elements(coalesce(p_flow#>'{current_future,days}','[]'))d
 CROSS JOIN LATERAL(SELECT d->'fix86_columns' c,(d->>'date')::date dt)cols
 CROSS JOIN LATERAL(SELECT CASE WHEN receipt IS NOT NULL AND dt>=receipt AND base_date<receipt THEN 0 ELSE base_value END documented,
 monthly*(SELECT count(*) FROM jsonb_array_elements_text(credits)t WHERE t.value::date<=dt AND t.value::date>greatest(coalesce(receipt,base_date),base_date)) accrual)resources;
 SELECT coalesce(jsonb_agg(CASE WHEN debit>0 THEN d||jsonb_build_object('fix86_columns',c||jsonb_build_object(
  'rsus_vested',(c->>'rsus_vested')::numeric-debit,'saldo_apos_rsu',(c->>'saldo_apos_rsu')::numeric-debit,
  'disponivel_total',(c->>'disponivel_total')::numeric-debit,'posicao_curto_prazo',(c->>'posicao_curto_prazo')::numeric-debit,
  'saldo_apos_fgts',(c->>'saldo_apos_fgts')::numeric-debit,'posicao_economica_total',(c->>'posicao_economica_total')::numeric-debit,
  'brokerage_settled_withdrawals',debit)) ELSE d END ORDER BY d->>'date'),'[]') INTO historical_days
 FROM jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'))d
 CROSS JOIN LATERAL(SELECT d->'fix86_columns' c,CASE WHEN (d->>'date')::date>=(SELECT min((x->>'settled_on')::date) FROM jsonb_array_elements(coalesce(a#>'{policy,brokerage_withdrawals}','[]'))x) THEN (public.lts_liquidity_adjustments_v242(p_user_id,(d->>'date')::date)->>'brokerage_settled_withdrawals')::numeric ELSE 0 END debit)adj;
 RETURN jsonb_set(jsonb_set(p_flow,'{current_future,days}',days),'{historical,days}',historical_days)||jsonb_build_object('fgts_projection_contract',jsonb_build_object(
 'version','owner-withdrawal-and-recomposition-v242','as_of',p_as_of,'enabled',monthly>0,
 'receipt_date',receipt,'withdrawal_brl',withdrawal,'principal_brl',policy->'principal_brl','jam_brl',policy->'jam_brl',
 'monthly_estimate_brl',monthly,'credit_dates',credits,'owner_confirmed_on',a#>'{policy,owner_confirmed_on}',
 'bank_credit_is_asset_transfer',true,'future_contributions_are_restricted_estimates',true));
END $fn$;

CREATE OR REPLACE FUNCTION public.lts_flow_slice_v242(p_payload jsonb,p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $fn$
DECLARE f jsonb:=p_payload->'flow'; part text;
BEGIN
 FOREACH part IN ARRAY ARRAY['historical','current_future'] LOOP
 f:=jsonb_set(f,ARRAY[part,'days'],coalesce((SELECT jsonb_agg(x ORDER BY x->>'date') FROM jsonb_array_elements(coalesce(f#>ARRAY[part,'days'],'[]'))x WHERE (x->>'date')::date BETWEEN p_from AND p_to),'[]'));
 f:=jsonb_set(f,ARRAY[part,'events'],coalesce((SELECT jsonb_agg(x ORDER BY x->>'event_date',x->>'source_ref') FROM jsonb_array_elements(coalesce(f#>ARRAY[part,'events'],'[]'))x WHERE (x->>'event_date')::date BETWEEN p_from AND p_to),'[]'));
 END LOOP;
 RETURN p_payload||jsonb_build_object('flow',f||jsonb_build_object('from',p_from,'to',p_to));
END $fn$;

CREATE OR REPLACE FUNCTION public.lts_browser_flow_v242(p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' SET statement_timeout='45s' AS $fn$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); cached jsonb; j jsonb; f jsonb; cache_epoch bigint;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_to-p_from>12000 THEN RAISE EXCEPTION 'invalid range'; END IF;
 SELECT epoch INTO cache_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 SELECT payload INTO cached FROM public.lts_v229_read_cache WHERE user_id=u AND kind='flow_v242' AND as_of=current_date
 AND from_date<=p_from AND to_date>=p_to AND source_fingerprint='v242.1:'||cache_epoch AND refreshed_at>clock_timestamp()-interval '30 minutes'
 ORDER BY to_date-from_date,refreshed_at DESC LIMIT 1;
 IF FOUND THEN RETURN public.lts_flow_slice_v242(cached,p_from,p_to); END IF;
 -- Keep the original bank and historical arithmetic, including unknown positions.
 j:=public.lts_browser_flow_v241(least(p_from,current_date),p_to);
 f:=public.lts_flow_liquidity_adjustments_v242(u,j->'flow',current_date);
 j:=j||jsonb_build_object('flow',f,'reader_revision','v242-source-invalidated-flow');
 j:=public.lts_flow_slice_v242(j,p_from,p_to);
 IF cache_epoch<>(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read'; END IF;
 INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
 VALUES(u,'flow_v242',current_date,p_from,p_to,j,clock_timestamp(),'v242.1:'||cache_epoch)
 ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
 RETURN j;
END $fn$;

CREATE OR REPLACE FUNCTION public.lts_browser_cash_today_v242()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $fn$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); j jsonb:=public.lts_browser_cash_today_v178(); a jsonb:=public.lts_liquidity_adjustments_v242(u,current_date);
 r numeric:=(j->>'brokerage_available')::numeric-(a->>'brokerage_settled_withdrawals')::numeric; fg numeric:=(a->>'fgts_documented')::numeric; c jsonb:=j#>'{day,fix86_columns}'; base numeric:=(j->>'cash')::numeric+(j->>'d0')::numeric;
BEGIN
 IF r<0 THEN RAISE EXCEPTION 'brokerage withdrawal exceeds last known resource'; END IF;
 j:=jsonb_set(j,'{day,fix86_columns}',c||jsonb_build_object('rsus_vested',r,'saldo_apos_rsu',base+r,'fgts',fg,'saldo_apos_fgts',base+r+fg,'disponivel_total',base+r,'posicao_curto_prazo',base+r));
 RETURN j||jsonb_build_object('brokerage_available',r,'available_total',base+r,'fgts',fg,'reader_revision','v242-settled-resource-transfers');
END $fn$;

CREATE OR REPLACE FUNCTION public.lts_browser_wealth_detail_v242()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $fn$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); j jsonb:=public.lts_browser_wealth_detail_v4(); a jsonb:=public.lts_liquidity_adjustments_v242(u,current_date); cash jsonb:=public.lts_browser_cash_today_v242(); s jsonb:=j->'rsu_summary'; summary jsonb:=j#>'{wealth,summary}'; delta numeric; key text;
BEGIN
 j:=jsonb_set(j,'{rsu_summary}',s||jsonb_build_object('available_total_brl',cash->'brokerage_available','settled_withdrawals_brl',a->'brokerage_settled_withdrawals','component_position_requires_new_statement',(a->>'brokerage_settled_withdrawals')::numeric>0));
 j:=jsonb_set(j,'{wealth,liquidity}',coalesce(j#>'{wealth,liquidity}','{}')||jsonb_build_object('bank_cash',cash->'cash','fgts_contingency',cash->'fgts','d0',cash->'d0'));
 j:=jsonb_set(j,'{morgan_statement,available_after_settled_transfers_brl}',cash->'brokerage_available');
 j:=jsonb_set(j,'{current_liquidity}',cash-'day');
 j:=jsonb_set(j,'{wealth,liquidity}',coalesce(j#>'{wealth,liquidity}','{}')||jsonb_build_object('d3',cash->'brokerage_available','through_d3',cash->'available_total'));
 j:=jsonb_set(j,'{wealth,distribution}',coalesce((SELECT jsonb_agg(x||CASE x->>'name' WHEN 'Liquidez até D+3' THEN jsonb_build_object('value',cash->'available_total','detail','Contas, aplicações e ações') WHEN 'FGTS' THEN jsonb_build_object('value',cash->'fgts','detail','Saldo restrito') ELSE '{}'::jsonb END) FROM jsonb_array_elements(coalesce(j#>'{wealth,distribution}','[]'))x),'[]'));
 delta:=(a->>'brokerage_settled_withdrawals')::numeric+coalesce((summary->>'restricted_contingency')::numeric,0)-(cash->>'fgts')::numeric;
 FOREACH key IN ARRAY ARRAY['assets_central','net_worth_central','net_worth_low','net_worth_high'] LOOP
  IF summary ? key THEN summary:=jsonb_set(summary,ARRAY[key],to_jsonb((summary->>key)::numeric-delta)); END IF;
 END LOOP;
 summary:=summary||jsonb_build_object('liquidity_through_d3',cash->'available_total','restricted_contingency',cash->'fgts');
 IF (summary->>'assets_central')::numeric>0 THEN summary:=summary||jsonb_build_object('cipo_share_of_assets_pct',round((j#>>'{wealth,assets,cipo_396,market_central}')::numeric/(summary->>'assets_central')::numeric*100,1),'known_debt_to_assets_pct',round((summary->>'known_debt_total')::numeric/(summary->>'assets_central')::numeric*100,1)); END IF;
 j:=jsonb_set(j,'{wealth,summary}',summary);
 IF j#>'{wealth_v167,assets_central_including_pensions}' IS NOT NULL THEN j:=jsonb_set(j,'{wealth_v167,assets_central_including_pensions}',to_jsonb((j#>>'{wealth_v167,assets_central_including_pensions}')::numeric-delta)); END IF;
 IF j#>'{wealth_v167,net_worth_central_including_pensions}' IS NOT NULL THEN j:=jsonb_set(j,'{wealth_v167,net_worth_central_including_pensions}',to_jsonb((j#>>'{wealth_v167,net_worth_central_including_pensions}')::numeric-delta)); END IF;
 RETURN j||jsonb_build_object('reader_revision','v242-settled-resource-transfers');
END $fn$;

REVOKE ALL ON FUNCTION public.lts_liquidity_adjustments_v242(uuid,date),public.lts_flow_liquidity_adjustments_v242(uuid,jsonb,date),public.lts_flow_slice_v242(jsonb,date,date) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_browser_flow_v242(date,date),public.lts_browser_cash_today_v242(),public.lts_browser_wealth_detail_v242() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_flow_v242(date,date),public.lts_browser_cash_today_v242(),public.lts_browser_wealth_detail_v242() TO authenticated,service_role;

-- These input tables were not covered by the pre-existing invalidation triggers.
CREATE TRIGGER lts_v242_invalidate_read_cache AFTER INSERT OR UPDATE OR DELETE ON public.lts_open_finance_staging FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v229_invalidate_read_cache();
CREATE TRIGGER lts_v242_invalidate_read_cache AFTER INSERT OR UPDATE OR DELETE ON public.lts_open_finance_observation FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v229_invalidate_read_cache();
CREATE TRIGGER lts_v242_invalidate_read_cache AFTER INSERT OR UPDATE OR DELETE ON public.lts_open_finance_connection FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v229_invalidate_read_cache();
CREATE TRIGGER lts_v242_invalidate_read_cache AFTER INSERT OR UPDATE OR DELETE ON public.lts_realized_bank_event_v238 FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v229_invalidate_read_cache();
