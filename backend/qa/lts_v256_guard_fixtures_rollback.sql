BEGIN;
SET LOCAL TimeZone='America/Sao_Paulo';SET LOCAL jit=off;SET LOCAL statement_timeout='60s';
CREATE OR REPLACE FUNCTION public.lts_guard_baseline_v256(p_flow jsonb, p_today date)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE
 f jsonb:=p_flow; d jsonb; old_day jsonb; days jsonb:='[]'; bank_name text;
 bank_row jsonb; observed numeric; projection numeric; difference numeric;
 delta numeric:=0; total_delta numeric; gaps jsonb; c jsonb; cash_field text;
 affected boolean; guard_metadata jsonb;
BEGIN
 IF p_flow IS NULL OR p_today IS NULL THEN RETURN p_flow; END IF;
 FOR d IN SELECT x FROM jsonb_array_elements(coalesce(f#>'{current_future,days}','[]')) x LOOP
  IF d->>'date'=p_today::text AND d#>>'{cash_position_guard,version}' IS NULL THEN
   old_day:=d; total_delta:=0; gaps:='{}'; affected:=false;
   FOREACH bank_name IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
    bank_row:=d->bank_name;
    IF bank_row->>'balance_basis'='observed_bank_position_and_recent_movements'
      AND bank_row->>'observed_balance' IS NOT NULL
      AND bank_row->>'balance' IS NOT NULL
      AND bank_row->>'unposted_projection_net' IS NOT NULL
      AND abs(coalesce((bank_row->>'reconciliation_gap')::numeric,0))>.005 THEN
     observed:=(bank_row->>'observed_balance')::numeric;
     projection:=(bank_row->>'unposted_projection_net')::numeric;
     difference:=(bank_row->>'reconciliation_gap')::numeric;
     delta:=observed+projection-(bank_row->>'balance')::numeric;
     total_delta:=total_delta+delta; affected:=true;
     gaps:=gaps||jsonb_build_object(bank_name,difference);
     bank_row:=bank_row||jsonb_build_object(
      'balance',observed+projection,'operational_balance',observed+projection,
      'balance_certified',false,'movements_complete',false,
      'known_movements_net',bank_row->'net','net',null,'operational_net',null,
      'opening_balance_basis','unverified_ledger_reconstruction_not_observed',
      'cash_position_guard',jsonb_build_object('version','observed-position-not-reconciled-ledger-v1',
       'ledger_reconstruction',d->bank_name,'position_delta',delta,
       'unexplained_balance_difference',difference,'difference_transaction_created',false,
       'difference_event_date',null,'projection_net_preserved',projection));
     d:=jsonb_set(d,ARRAY[bank_name],bank_row);
    END IF;
   END LOOP;
   IF affected THEN
    c:=d->'fix86_columns';
    -- These fields are today's cash plus separate same-day liquidity resources.
    -- liq_d30 is a look-ahead balance, already anchored by the underlying reader.
    FOREACH cash_field IN ARRAY ARRAY['saldo_final','saldo_final_operacional',
     'saldo_apos_d0_1','liq_d0_1','posicao_antes_rsus','saldo_apos_rsu',
     'disponivel_total','posicao_curto_prazo','saldo_apos_fgts','posicao_economica_total'] LOOP
     IF c->>cash_field IS NOT NULL THEN
      c:=jsonb_set(c,ARRAY[cash_field],to_jsonb((c->>cash_field)::numeric+total_delta));
     END IF;
    END LOOP;
    c:=c||jsonb_build_object('entradas',null,'saidas',null,
     'entradas_operacionais',null,'saidas_operacionais',null,
     'opening_balance_basis','unverified_ledger_reconstruction_not_observed',
     'cash_projection_basis','observed_bank_position_plus_documented_unposted_today');
    guard_metadata:=jsonb_build_object('version','observed-position-not-reconciled-ledger-v1',
     'as_of',p_today,'unexplained_bank_differences',gaps,'position_delta',total_delta,
     'known_day_summary',old_day->'summary','known_day_arithmetic',old_day->'v170_cash_arithmetic',
     'previous_columns',old_day->'fix86_columns','financial_fact_changed',false,
     'difference_transaction_created',false,'difference_event_date',null);
    d:=d||jsonb_build_object('movements_complete',false,'cash_position_guard',guard_metadata,
     'fix86_columns',c,
     'Consolidado',(d->'Consolidado')||jsonb_build_object('bank_balance',c->'saldo_final',
      'known_movements_net',old_day#>'{Consolidado,net}','net',null,'economic_net',null,
      'balance_certified',false,'movements_complete',false),
     'summary',(d->'summary')||jsonb_build_object('entries',null,'exits',null,'net',null,
      'Consolidado',jsonb_build_object('entries',null,'exits',null)),
     'v170_cash_arithmetic',jsonb_build_object('version','observed-position-not-reconciled-ledger-v1',
      'balanced',null,'arithmetic_gap_brl',null,'status','awaiting_bank_movement_evidence',
      'unexplained_bank_differences',gaps,'financial_fact_changed',false));
    f:=f||jsonb_build_object('cash_position_guard',guard_metadata);
   END IF;
  END IF;
  days:=days||jsonb_build_array(d);
 END LOOP;
 IF f->'cash_position_guard' IS NULL THEN RETURN p_flow; END IF;
 RETURN jsonb_set(f,'{current_future,days}',days);
END $function$
;
REVOKE ALL ON FUNCTION public.lts_guard_baseline_v256(jsonb,date) FROM PUBLIC,anon,authenticated,service_role;
-- V256: linear JSON assembly and one classification lookup per event.
DO $v256$
DECLARE s text; needle text;
BEGIN
 s:=pg_get_functiondef('public.lts_flow_observed_position_guard_v1(jsonb,date)'::regprocedure);
 IF md5(btrim(s,E' \t\r\n'))<>'8824224c21aaf1cc83623d9bd4294ac2' THEN RAISE EXCEPTION 'V256_GUARD_SOURCE_CHANGED';END IF;
 needle:=$old$ f jsonb:=p_flow; d jsonb; old_day jsonb; days jsonb:='[]'; bank_name text;$old$;
 IF (length(s)-length(replace(s,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'V256_GUARD_DECLARATION_NOT_UNIQUE';END IF;
 s:=replace(s,needle,$new$ f jsonb:=p_flow; d jsonb; old_day jsonb; day_rows_v256 jsonb[]:=ARRAY[]::jsonb[]; bank_name text;$new$);
 needle:=$old$  days:=days||jsonb_build_array(d);$old$;
 IF (length(s)-length(replace(s,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'V256_GUARD_APPEND_NOT_UNIQUE';END IF;
 s:=replace(s,needle,$new$  day_rows_v256:=array_append(day_rows_v256,d);$new$);
 needle:=$old$ RETURN jsonb_set(f,'{current_future,days}',days);$old$;
 IF (length(s)-length(replace(s,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'V256_GUARD_RETURN_NOT_UNIQUE';END IF;
 s:=replace(s,needle,$new$ RETURN jsonb_set(f,'{current_future,days}',to_jsonb(day_rows_v256));$new$);
 EXECUTE s;
 s:=pg_get_functiondef('public.lts_browser_flow_pre_v238(date,date)'::regprocedure);
 IF md5(btrim(s,E' \t\r\n'))<>'d7b44020c937ef74e4698437af9497a9' THEN RAISE EXCEPTION 'V256_CLASSIFICATION_SOURCE_CHANGED';END IF;
 needle:=$old$ LEFT JOIN LATERAL(SELECT public.lts_bank_known_classification_v231(u,(x->>'open_finance_id')::uuid) c WHERE x->>'open_finance_id' IS NOT NULL) k ON true;$old$;
 IF (length(s)-length(replace(s,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'V256_CLASSIFICATION_NOT_UNIQUE';END IF;
 s:=replace(s,needle,$new$ -- Keep this expression behind a lateral evaluation barrier: the same
 -- classification JSON is consumed by several output fields.
 LEFT JOIN LATERAL(SELECT public.lts_bank_known_classification_v231(u,(x->>'open_finance_id')::uuid) c WHERE x->>'open_finance_id' IS NOT NULL OFFSET 0) k ON true;$new$);
 EXECUTE s;
END $v256$;

CREATE TEMP TABLE fixture_results_v256(name text) ON COMMIT DROP;
DO $fixtures$ DECLARE flow jsonb;day jsonb;row jsonb;j jsonb;old jsonb;items jsonb;label text; today date:=date '2026-10-06';old_error text;new_error text;
BEGIN
 day:=jsonb_build_object('date',today,'Itaú',jsonb_build_object('balance_basis','observed_bank_position_and_recent_movements','balance',10.01,'observed_balance',12.34,'unposted_projection_net',-.12,'reconciliation_gap',2.45,'net',-1.239),
 'Bradesco',jsonb_build_object('balance',null,'net',null),'C6',jsonb_build_object('balance_basis','relative_tracked_bank_ledger','balance',0),
 'fix86_columns',jsonb_build_object('saldo_final',10.01,'saldo_final_operacional',10.01,'saldo_apos_d0_1',null,'liq_d0_1',20.01,'posicao_antes_rsus',20.01,'saldo_apos_rsu',21.249,'disponivel_total',21.249,'posicao_curto_prazo',21.249,'saldo_apos_fgts',30.01,'posicao_economica_total',31.01,'liq_d30',99,'entradas',null,'saidas',null),
 'Consolidado',jsonb_build_object('net',-1.239),'summary',jsonb_build_object('net',null),'v170_cash_arithmetic',jsonb_build_object('balanced',null));
 FOR label,flow IN
  SELECT * FROM (VALUES
   ('sql_null',NULL::jsonb),('missing_days','{}'::jsonb),('empty_days','{"current_future":{"days":[]}}'::jsonb),
   ('affected',jsonb_build_object('current_future',jsonb_build_object('days',jsonb_build_array(day)))),
   ('duplicate_and_order',jsonb_build_object('current_future',jsonb_build_object('days',jsonb_build_array(jsonb_set(day,'{date}','"2026-10-09"'),day,NULL,day,jsonb_set(day,'{date}','"2026-10-01"'))))),
   ('already_guarded',jsonb_build_object('current_future',jsonb_build_object('days',jsonb_build_array(day||'{"cash_position_guard":{"version":"existing"}}')))),
   ('existing_top_guard',jsonb_build_object('cash_position_guard',jsonb_build_object('version','existing'),'current_future',jsonb_build_object('days',jsonb_build_array(jsonb_set(day,'{date}','"2026-10-01"'))))),
   ('threshold_equal',jsonb_build_object('current_future',jsonb_build_object('days',jsonb_build_array(jsonb_set(day,ARRAY['Itaú','reconciliation_gap'],'0.005'))))),
   ('negative_gap_subcent',jsonb_build_object('current_future',jsonb_build_object('days',jsonb_build_array(jsonb_set(day,ARRAY['Itaú','reconciliation_gap'],'-0.00501'))))),
   ('unknown_balance',jsonb_build_object('current_future',jsonb_build_object('days',jsonb_build_array(jsonb_set(day,ARRAY['Itaú','balance'],'null'))))),
   ('unknown_observed',jsonb_build_object('current_future',jsonb_build_object('days',jsonb_build_array(jsonb_set(day,ARRAY['Itaú','observed_balance'],'null'))))),
   ('unknown_projection',jsonb_build_object('current_future',jsonb_build_object('days',jsonb_build_array(jsonb_set(day,ARRAY['Itaú','unposted_projection_net'],'null'))))),
   ('relative_position',jsonb_build_object('current_future',jsonb_build_object('days',jsonb_build_array(jsonb_set(day,ARRAY['Itaú','balance_basis'],'"relative_tracked_bank_ledger"'))))),
   ('bad_unvisited_amount',jsonb_build_object('current_future',jsonb_build_object('days',jsonb_build_array(jsonb_set(jsonb_set(day,'{date}','"2026-10-09"'),ARRAY['Itaú','balance'],'"invalid"')))))
  ) f(name,payload)
 LOOP
  old:=public.lts_guard_baseline_v256(flow,today);j:=public.lts_flow_observed_position_guard_v1(flow,today);
  IF old::text IS DISTINCT FROM j::text THEN RAISE EXCEPTION 'V256_FIXTURE_CHANGED %',label;END IF;
  IF public.lts_guard_baseline_v256(flow,NULL)::text IS DISTINCT FROM public.lts_flow_observed_position_guard_v1(flow,NULL)::text THEN RAISE EXCEPTION 'V256_NULL_TODAY_CHANGED';END IF;
  INSERT INTO fixture_results_v256 VALUES(label);
 END LOOP;
 SELECT jsonb_agg(CASE WHEN n=0 THEN day ELSE jsonb_set(day,'{date}',to_jsonb((today+n)::text)) END ORDER BY n DESC) INTO items FROM generate_series(0,729)n;
 flow:=jsonb_build_object('current_future',jsonb_build_object('days',items));
 IF public.lts_guard_baseline_v256(flow,today)::text IS DISTINCT FROM public.lts_flow_observed_position_guard_v1(flow,today)::text THEN RAISE EXCEPTION 'V256_LONG_UNSORTED_CHANGED';END IF;
 INSERT INTO fixture_results_v256 VALUES('730_days_unsorted');
 FOR label,flow IN SELECT * FROM (VALUES
 ('non_array','{"current_future":{"days":{}}}'::jsonb),
 ('bad_visited_amount',jsonb_build_object('current_future',jsonb_build_object('days',jsonb_build_array(jsonb_set(day,ARRAY['Itaú','balance'],'"invalid"')))))
 ) f(name,payload)
 LOOP
  old_error:=NULL;new_error:=NULL;
  BEGIN PERFORM public.lts_guard_baseline_v256(flow,today);EXCEPTION WHEN OTHERS THEN old_error:=SQLSTATE;END;
  BEGIN PERFORM public.lts_flow_observed_position_guard_v1(flow,today);EXCEPTION WHEN OTHERS THEN new_error:=SQLSTATE;END;
  IF old_error IS NULL OR old_error IS DISTINCT FROM new_error THEN RAISE EXCEPTION 'V256_ERROR_CONTRACT_CHANGED %',label;END IF;
  INSERT INTO fixture_results_v256 VALUES(label||':'||old_error);
 END LOOP;
END $fixtures$;
SELECT 'PASS' status,count(*) cases,jsonb_agg(name) fixtures,true full_text_exact,true sql_null_and_null_date_preserved,true error_contract_preserved,false financial_source_changes FROM fixture_results_v256;
ROLLBACK;
