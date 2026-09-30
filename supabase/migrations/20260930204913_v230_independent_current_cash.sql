-- Independent current position; never rebuild the future projection to open KPIs.
-- Preserve the existing browser RPC contract and the validated position sources.
CREATE OR REPLACE FUNCTION public.lts_browser_cash_today_v178()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path='' SET timezone='America/Sao_Paulo' AS $function$
DECLARE
 u uuid:=public.lts_browser_assert_user_v1(); positions jsonb; accounts jsonb; cols jsonb; row_today jsonb;
 bank numeric; d0 numeric; vested numeric; fgts numeric;
 d0_date date; vested_date date; fgts_date date;
BEGIN
 positions:=public.lts_open_finance_current_bank_position_v1(u);
 bank:=(positions->>'bank_cash')::numeric;
 IF (SELECT count(DISTINCT institution_code) FROM public.lts_open_finance_staging
     WHERE user_id=u AND resource_type='balance' AND provider_deleted_at IS NULL
     AND signed_amount IS NOT NULL AND institution_code IN ('341','237','336'))<>3
 THEN RAISE EXCEPTION 'canonical bank positions incomplete'; END IF;
 SELECT (canonical_value->>'amount')::numeric,(canonical_value->>'as_of')::date INTO d0,d0_date
 FROM public.lts_validated_lock_registry WHERE lock_key='itau_cofrinho_20260926' AND superseded_at IS NULL;
 SELECT (canonical_value->>'total_available_brl')::numeric,(canonical_value->>'as_of')::date INTO vested,vested_date
 FROM public.lts_validated_lock_registry WHERE lock_key='morgan_available_20260922' AND superseded_at IS NULL;
 SELECT value_brl,as_of_date INTO fgts,fgts_date FROM public.asset_positions
 WHERE user_id=u AND asset_type='FGTS' ORDER BY as_of_date DESC LIMIT 1;
 IF bank IS NULL OR d0 IS NULL OR vested IS NULL OR fgts IS NULL
 THEN RAISE EXCEPTION 'canonical current liquidity incomplete'; END IF;
 SELECT jsonb_object_agg(CASE a->>'institution_code' WHEN '341' THEN 'Itaú'
 WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END,
 jsonb_build_object('balance',a->'balance','net',NULL)) INTO accounts
 FROM jsonb_array_elements(positions->'accounts') a;
 -- A position is not a reconstructed bank statement: no made-up opening/entries/exits.
 cols:=jsonb_build_object(
  'saldo_anterior',NULL,'entradas',NULL,'saidas',NULL,'saldo_final',bank,
  'liq_d0_1_recurso',d0,'liq_d0_1',bank+d0,'saldo_apos_d0_1',bank+d0,
  'rsus_vested',vested,'saldo_apos_rsu',bank+d0+vested,'fgts',fgts,
  'saldo_apos_fgts',bank+d0+vested+fgts,'disponivel_total',bank+d0+vested,
  'posicao_antes_rsus',bank+d0,'posicao_curto_prazo',bank+d0+vested,
  'morgan_available_total_brl',vested,'cash_semantics','current_position_snapshot');
 row_today:=accounts||jsonb_build_object('date',current_date,'is_today',true,'position_only',true,
  'Consolidado',jsonb_build_object('bank_balance',bank,'economic_net',NULL,'unassigned_net',NULL),
  'summary',jsonb_build_object('Consolidado',jsonb_build_object('entries',NULL,'exits',NULL)),
  'fix86_columns',cols);
 RETURN jsonb_build_object('version','cash-today-v179-current-canonical','as_of',current_date,
  'computed_at',clock_timestamp(),'status','complete','cash',bank,'d0',d0,
  'brokerage_available',vested,'fgts',fgts,'available_total',round(bank+d0+vested,2),
  'day',row_today,'basis','current_open_finance_bank_plus_validated_cofrinho_and_morgan_locks',
  'position_dates',jsonb_build_object('d0',d0_date,'brokerage',vested_date,'fgts',fgts_date),
  'reader_revision','v230-independent-current-position');
END $function$;
-- Existing grants/authentication stay unchanged; no new public endpoint.
