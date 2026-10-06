-- Maintenance-only current-source assertions; no source mutation or private values.
BEGIN READ ONLY;
SET LOCAL TimeZone='America/Sao_Paulo';
SET LOCAL jit=off;
SET LOCAL statement_timeout='90s';
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
DO $qa$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1(); cash jsonb:=public.lts_browser_cash_today_v242(); source jsonb; deductions numeric;
BEGIN
 SELECT canonical_value INTO STRICT source FROM public.lts_validated_lock_registry
 WHERE lock_key LIKE 'morgan_available_%' AND superseded_at IS NULL AND (canonical_value->>'as_of')::date<=current_date
 ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1;
 deductions:=(public.lts_liquidity_adjustments_v242(u,current_date)->>'brokerage_settled_withdrawals')::numeric;
 IF (cash->>'brokerage_available')::numeric<>(source->>'total_available_brl')::numeric-deductions
 OR (cash->>'cash')::numeric<>(public.lts_open_finance_current_bank_position_v1(u)->>'bank_cash')::numeric
 OR (cash->>'d0')::numeric<>public.lts_cofrinho_effective_locked_v245(u,current_date)
 OR (cash->>'available_total')::numeric<>(cash->>'cash')::numeric+(cash->>'d0')::numeric+(cash->>'brokerage_available')::numeric
 THEN RAISE EXCEPTION 'documentary position parity failed'; END IF;
END $qa$;
SET LOCAL ROLE authenticated;
SELECT jsonb_build_object('cash',public.lts_browser_cash_today_v242(),'awards',public.lts_browser_awards_v178(),'wealth',public.lts_browser_wealth_detail_v242(),'flow',public.lts_browser_flow_v242(make_date(extract(year from current_date)::int,1,1),make_date(extract(year from current_date)::int+1,12,31)));
RESET ROLE;
ROLLBACK;
