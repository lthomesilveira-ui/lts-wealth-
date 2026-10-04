-- V244: repair dated historical FGTS precedence only. Current/future
-- projections, cash, D0/D1, brokerage and unknowns are otherwise unchanged.
CREATE OR REPLACE FUNCTION public.lts_flow_liquidity_adjustments_v242(p_user_id uuid, p_flow jsonb, p_as_of date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
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
 -- Historical positions follow the latest primary statement valid on that
 -- day, never the current balance copied backwards. Missing evidence remains
 -- the original unknown/historical position; brokerage arithmetic is preserved.
 WITH brokerage AS (
 SELECT CASE WHEN debit>0 THEN d||jsonb_build_object('fix86_columns',c||jsonb_build_object(
  'rsus_vested',(c->>'rsus_vested')::numeric-debit,'saldo_apos_rsu',(c->>'saldo_apos_rsu')::numeric-debit,
  'disponivel_total',(c->>'disponivel_total')::numeric-debit,'posicao_curto_prazo',(c->>'posicao_curto_prazo')::numeric-debit,
  'saldo_apos_fgts',(c->>'saldo_apos_fgts')::numeric-debit,'posicao_economica_total',(c->>'posicao_economica_total')::numeric-debit,
  'brokerage_settled_withdrawals',debit)) ELSE d END d
 FROM jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'))d
 CROSS JOIN LATERAL(SELECT d->'fix86_columns' c,CASE WHEN (d->>'date')::date>=(SELECT min((x->>'settled_on')::date) FROM jsonb_array_elements(coalesce(a#>'{policy,brokerage_withdrawals}','[]'))x) THEN (public.lts_liquidity_adjustments_v242(p_user_id,(d->>'date')::date)->>'brokerage_settled_withdrawals')::numeric ELSE 0 END debit)adj
 )
 SELECT coalesce(jsonb_agg(CASE WHEN position.value_brl IS NOT NULL THEN d||jsonb_build_object('fix86_columns',c||jsonb_build_object(
  'fgts',documented+accrual,'fgts_documental',documented,'fgts_aportes_projetados',accrual,
  'saldo_apos_fgts',(c->>'saldo_apos_rsu')::numeric+documented+accrual,
  'saldo_apos_fgts_documental',(c->>'saldo_apos_rsu')::numeric+documented,
  'posicao_economica_total',(c->>'posicao_economica_total')::numeric-(c->>'fgts')::numeric+documented+accrual,
  'fgts_projection_basis','dated_primary_position_with_confirmed_withdrawal'
 )) ELSE d END ORDER BY d->>'date'),'[]') INTO historical_days
 FROM brokerage
 CROSS JOIN LATERAL(SELECT d->'fix86_columns' c,(d->>'date')::date dt)cols
 LEFT JOIN LATERAL(
  SELECT value_brl,as_of_date FROM public.asset_positions
  WHERE user_id=p_user_id AND asset_type='FGTS' AND as_of_date<=dt
  ORDER BY as_of_date DESC,created_at DESC LIMIT 1
 )position ON true
 CROSS JOIN LATERAL(
  SELECT CASE WHEN receipt IS NOT NULL AND dt>=receipt AND position.as_of_date<receipt THEN 0 ELSE position.value_brl END documented,
  CASE WHEN receipt IS NOT NULL AND dt>=receipt THEN monthly*(SELECT count(*) FROM jsonb_array_elements_text(credits)t WHERE t.value::date<=dt AND t.value::date>greatest(receipt,position.as_of_date)) ELSE 0 END accrual
 )resources;
 RETURN jsonb_set(jsonb_set(p_flow,'{current_future,days}',days),'{historical,days}',historical_days)||jsonb_build_object('fgts_projection_contract',jsonb_build_object(
 'version','owner-withdrawal-and-recomposition-v242','as_of',p_as_of,'enabled',monthly>0,
 'receipt_date',receipt,'withdrawal_brl',withdrawal,'principal_brl',policy->'principal_brl','jam_brl',policy->'jam_brl',
 'monthly_estimate_brl',monthly,'credit_dates',credits,'owner_confirmed_on',a#>'{policy,owner_confirmed_on}',
 'bank_credit_is_asset_transfer',true,'future_contributions_are_restricted_estimates',true));
END $function$
;

-- New fingerprint prevents a prior memo from surviving the reader correction.
CREATE OR REPLACE FUNCTION public.lts_browser_flow_v242(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '45s'
 SET jit TO 'off'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); cached jsonb; j jsonb; f jsonb; cache_epoch bigint;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_to-p_from>12000 THEN RAISE EXCEPTION 'invalid range'; END IF;
 SELECT epoch INTO cache_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 SELECT payload INTO cached FROM public.lts_v229_read_cache WHERE user_id=u AND kind='flow_v242' AND as_of=current_date
 AND from_date<=p_from AND to_date>=p_to AND source_fingerprint='v244.1:'||cache_epoch AND refreshed_at>clock_timestamp()-interval '30 minutes'
 ORDER BY to_date-from_date,refreshed_at DESC LIMIT 1;
 IF FOUND THEN RETURN public.lts_flow_slice_v242(cached,p_from,p_to); END IF;
 -- Keep the original bank and historical arithmetic, including unknown positions.
 j:=public.lts_browser_flow_v241(least(p_from,current_date),p_to);
 f:=public.lts_flow_liquidity_adjustments_v242(u,j->'flow',current_date);
 j:=j||jsonb_build_object('flow',f,'reader_revision','v244-dated-historical-fgts');
 j:=public.lts_flow_slice_v242(j,p_from,p_to);
 IF cache_epoch<>(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read'; END IF;
 INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
 VALUES(u,'flow_v242',current_date,p_from,p_to,j,clock_timestamp(),'v244.1:'||cache_epoch)
 ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
 RETURN j;
END $function$
;

