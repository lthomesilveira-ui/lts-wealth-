BEGIN;SET LOCAL statement_timeout='30s';
CREATE OR REPLACE FUNCTION public.lts_historical_bank_total_guard_baseline_v257(p_flow jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE d jsonb; c jsonb; result_days jsonb:='[]'; bank_sum numeric; nested_total numeric; displayed_total numeric; invalid_count integer:=0;
BEGIN
 FOR d IN SELECT value FROM jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]')) LOOP
  c:=coalesce(d->'fix86_columns','{}');
  bank_sum:=(d#>>'{Itaú,balance}')::numeric+(d#>>'{Bradesco,balance}')::numeric+(d#>>'{C6,balance}')::numeric;
  nested_total:=(d#>>'{Consolidado,bank_balance}')::numeric;
  displayed_total:=(c->>'saldo_final')::numeric;
  IF bank_sum IS NOT NULL AND (abs(nested_total-bank_sum)>.005 OR abs(displayed_total-bank_sum)>.005) THEN
   invalid_count:=invalid_count+1;
   d:=d||jsonb_build_object('historical_bank_total_guard',jsonb_build_object(
    'version','inconsistent-aggregate-not-bank-cash-v1','status','awaiting_consistent_bank_position_evidence',
    'original_consolidated',d->'Consolidado','original_columns',c,'sum_of_displayed_bank_positions',bank_sum,
    'original_consolidated_gap',nested_total-bank_sum,'original_displayed_gap',displayed_total-bank_sum,
    'bank_sum_is_not_certified',true,'no_cash_adjustment_created',true));
   d:=d||jsonb_build_object('Consolidado',coalesce(d->'Consolidado','{}')||jsonb_build_object(
    'bank_balance',null,'balance_certified',false,'workbook_cash_reconciled',false,'balance_basis','incomplete_historical_bank_positions'),
    'relative_balance_display',false,'absolute_balance_certified',false,
    'absolute_balance_basis','awaiting_consistent_historical_bank_positions',
    'v170_cash_arithmetic',jsonb_build_object('version','inconsistent-aggregate-not-bank-cash-v1','balanced',null,'status','awaiting_consistent_bank_position_evidence'));
   c:=c||jsonb_build_object('saldo_anterior',null,'saldo_final',null,'saldo_anterior_operacional',null,'saldo_final_operacional',null,
    'saldo_apos_d0_1',null,'saldo_apos_rsu',null,'saldo_apos_fgts',null,'liq_d0_1',null,'disponivel_total',null,
    'posicao_curto_prazo',null,'posicao_antes_rsus',null);
   d:=d||jsonb_build_object('fix86_columns',c);
  END IF;
  result_days:=result_days||jsonb_build_array(d);
 END LOOP;
 IF invalid_count=0 THEN RETURN p_flow;END IF;
 RETURN jsonb_set(p_flow,'{historical,days}',result_days)||jsonb_build_object('historical_bank_total_guard',
 jsonb_build_object('version','inconsistent-aggregate-not-bank-cash-v1','invalidated_days',invalid_count,
 'note','Consolidado inconsistente com as posições por banco fica indisponível; fontes originais preservadas, sem ajuste.'));
END $function$
;
REVOKE ALL ON FUNCTION public.lts_historical_bank_total_guard_baseline_v257(jsonb) FROM PUBLIC,anon,authenticated,service_role;
CREATE TEMP TABLE fixtures_v257(name text,j jsonb) ON COMMIT DROP;
INSERT INTO fixtures_v257 VALUES('null',NULL),('empty','{}'),('absent','{"historical":{}}'),('null-days','{"historical":{"days":null}}'),('empty-days','{"historical":{"days":[]}}');
WITH base AS(SELECT '{"Itaú":{"balance":1.11},"Bradesco":{"balance":2.22},"C6":{"balance":3.33},"Consolidado":{"bank_balance":6.66},"fix86_columns":{"saldo_final":6.66,"saldo_anterior":5,"saldo_apos_rsu":10},"marker":"preserve"}'::jsonb d),
cases AS(SELECT 'valid' name,d FROM base UNION ALL SELECT 'mismatch',jsonb_set(d,'{Consolidado,bank_balance}','6.68') FROM base UNION ALL SELECT 'subcent',jsonb_set(d,'{Consolidado,bank_balance}','6.664') FROM base UNION ALL SELECT 'boundary',jsonb_set(d,'{Consolidado,bank_balance}','6.665') FROM base UNION ALL SELECT 'over-boundary',jsonb_set(d,'{Consolidado,bank_balance}','6.6651') FROM base UNION ALL SELECT 'missing-bank',d-'C6' FROM base UNION ALL SELECT 'null-bank',jsonb_set(d,'{C6,balance}','null') FROM base UNION ALL SELECT 'missing-total',d-'Consolidado' FROM base UNION ALL SELECT 'missing-columns',d-'fix86_columns' FROM base UNION ALL SELECT 'bad-number',jsonb_set(d,'{Itaú,balance}','"bad"') FROM base)
INSERT INTO fixtures_v257 SELECT name,jsonb_build_object('historical',jsonb_build_object('days',jsonb_build_array(d)),'other','preserve') FROM cases;
INSERT INTO fixtures_v257 SELECT 'duplicates-and-order',jsonb_build_object('historical',jsonb_build_object('days',(SELECT jsonb_agg(x) FROM(SELECT j#>'{historical,days,0}' x FROM fixtures_v257 WHERE name IN('mismatch','valid') UNION ALL SELECT j#>'{historical,days,0}' FROM fixtures_v257 WHERE name='valid')z)));
INSERT INTO fixtures_v257 VALUES('invalid-array','{"historical":{"days":{}}}');
DO $check$ DECLARE r record;a jsonb;b jsonb;ea text;eb text;n int:=0;BEGIN
 FOR r IN SELECT * FROM fixtures_v257 LOOP a:=NULL;b:=NULL;ea:=NULL;eb:=NULL;
  BEGIN a:=public.lts_historical_bank_total_guard_baseline_v257(r.j);EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS ea=RETURNED_SQLSTATE;END;
  BEGIN b:=public.lts_historical_bank_total_guard_v1(r.j);EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS eb=RETURNED_SQLSTATE;END;
  IF a::text IS DISTINCT FROM b::text OR ea IS DISTINCT FROM eb THEN RAISE EXCEPTION 'V257_FIXTURE_FAILED %',r.name;END IF;n:=n+1;
 END LOOP;PERFORM set_config('lts.v257_fixtures',jsonb_build_object('pass',true,'cases',n,'full_text_equal',true,'sqlstate_equal',true,'unknowns_subcent_order_duplicates_preserved',true)::text,true);
END $check$;
SELECT current_setting('lts.v257_fixtures')::jsonb receipt;ROLLBACK;
