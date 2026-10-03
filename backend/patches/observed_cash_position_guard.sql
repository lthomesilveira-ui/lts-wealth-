-- Read-model guard only: no bank movement, classification, or financial fact.
-- Apply with the configured migration integration. Existing function ACLs stay intact.
CREATE OR REPLACE FUNCTION public.lts_flow_observed_position_guard_v1(p_flow jsonb, p_today date)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path TO ''
AS $guard$
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
END $guard$;
REVOKE ALL ON FUNCTION public.lts_flow_observed_position_guard_v1(jsonb,date) FROM PUBLIC,anon,authenticated;

-- Synthetic contract tests execute inside the migration transaction.
DO $tests$
DECLARE f jsonb; g jsonb; h jsonb; day jsonb; t date:=date '2000-01-01';
BEGIN
 day:=jsonb_build_object('date',t,
  'Itaú',jsonb_build_object('balance',1000,'observed_balance',1000,'net',0,
   'opening_balance',1000,'reconciliation_gap',0,'unposted_projection_net',0,
   'balance_basis','observed_bank_position_and_recent_movements'),
  'Bradesco',jsonb_build_object('balance',400,'observed_balance',400,'reconciliation_gap',0),
  'C6',jsonb_build_object('balance',100,'observed_balance',100,'reconciliation_gap',0),
  'Consolidado',jsonb_build_object('bank_balance',1500,'net',0),
  'summary',jsonb_build_object('entries',0,'exits',0,'net',0),
  'fix86_columns',jsonb_build_object('saldo_final',1500,'saldo_anterior',1500,
   'entradas',0,'saidas',0,'liq_d0_1_recurso',200,'saldo_apos_d0_1',1700,
   'rsus_vested',300,'saldo_apos_rsu',2000,'fgts',50,'saldo_apos_fgts',2050,'liq_d30',321));
 f:=jsonb_build_object('current_future',jsonb_build_object('days',jsonb_build_array(day),'events','[]'::jsonb),
  'historical',jsonb_build_object('days',jsonb_build_array(day),'events','[]'::jsonb));
 ASSERT public.lts_flow_observed_position_guard_v1(f,t)=f,'zero-gap payload changed';
 g:=jsonb_set(jsonb_set(f,'{current_future,days,0,Itaú,observed_balance}','975'),
  '{current_future,days,0,Itaú,reconciliation_gap}','-25');
 h:=public.lts_flow_observed_position_guard_v1(g,t);
 ASSERT h#>>'{current_future,days,0,Itaú,balance}'='975','negative gap did not use observation';
 ASSERT h#>>'{current_future,days,0,fix86_columns,saldo_final}'='1475','consolidated mismatch';
 ASSERT h#>>'{current_future,days,0,fix86_columns,saldo_apos_fgts}'='2025','liquidity layer mismatch';
 ASSERT h#>>'{current_future,days,0,fix86_columns,liq_d30}'='321','look-ahead balance was double shifted';
 ASSERT h#>>'{current_future,days,0,summary,entries}' IS NULL,'unknown movements reported as zero';
 ASSERT h->'historical'=f->'historical','history modified';
 ASSERT h#>'{current_future,events}'=f#>'{current_future,events}','financial events modified';
 ASSERT public.lts_flow_observed_position_guard_v1(h,t)=h,'guard is not idempotent';
 g:=jsonb_set(jsonb_set(g,'{current_future,days,0,Itaú,unposted_projection_net}','-75'),
  '{current_future,days,0,Itaú,balance}','925');
 h:=public.lts_flow_observed_position_guard_v1(g,t);
 ASSERT h#>>'{current_future,days,0,Itaú,balance}'='900','documented current projection lost';
 ASSERT h#>>'{current_future,days,0,Itaú,unposted_projection_net}'='-75','projection amount changed';
 g:=jsonb_set(jsonb_set(f,'{current_future,days,0,Itaú,observed_balance}','1025'),
  '{current_future,days,0,Itaú,reconciliation_gap}','25');
 h:=public.lts_flow_observed_position_guard_v1(g,t);
 ASSERT h#>>'{current_future,days,0,Itaú,balance}'='1025','positive gap did not use observation';
 g:=jsonb_set(g,'{current_future,days,0,Itaú,observed_balance}','null');
 ASSERT public.lts_flow_observed_position_guard_v1(g,t)=g,'missing observation forced a balance';
 g:=jsonb_set(jsonb_set(f,'{current_future,days,0,Itaú,observed_balance}','975'),
  '{current_future,days,0,Itaú,reconciliation_gap}','-25');
 g:=jsonb_set(g,'{current_future,days,0,Bradesco}',
  jsonb_build_object('balance',400,'observed_balance',425,'reconciliation_gap',25,
   'net',0,'unposted_projection_net',0,'balance_basis','observed_bank_position_and_recent_movements'));
 h:=public.lts_flow_observed_position_guard_v1(g,t);
 ASSERT h#>>'{current_future,days,0,movements_complete}'='false','offsetting bank gaps falsely reconciled';
 ASSERT h#>>'{current_future,days,0,fix86_columns,saldo_final}'='1500','offsetting positions changed total';
END $tests$;

-- Patch only the guarded integration points in both canonical readers.
-- CREATE OR REPLACE retains each function's owner, execution grants and settings.
DO $patch$
DECLARE signature text; definition text; needle text; replacement text;
BEGIN
 FOREACH signature IN ARRAY ARRAY[
  'public.lts_browser_flow_pre_v248(date,date)',
  'public.lts_flow_cache_core_v240(uuid,date,date)'] LOOP
  definition:=pg_get_functiondef(signature::regprocedure);
  needle:=' -- Future balances continue the operational closing of today.';
  replacement:=' f:=public.lts_flow_observed_position_guard_v1(f,current_date);'||chr(10)||needle;
  IF strpos(definition,'lts_flow_observed_position_guard_v1')=0 THEN
   IF (length(definition)-length(replace(definition,needle,'')))/length(needle)<>1 THEN
    RAISE EXCEPTION 'unexpected canonical reader integration point: %',signature;
   END IF;
   definition:=replace(definition,needle,replacement);
   needle:='IF EXISTS(SELECT 1 FROM jsonb_each_text(bank_deltas) x WHERE abs(x.value::numeric)>.005) THEN';
   replacement:='IF EXISTS(SELECT 1 FROM jsonb_each_text(bank_deltas) x WHERE abs(x.value::numeric)>.005) OR f->''cash_position_guard'' IS NOT NULL THEN';
   IF strpos(definition,needle)=0 THEN RAISE EXCEPTION 'missing operational carry guard: %',signature; END IF;
   definition:=replace(definition,needle,replacement);
   EXECUTE definition;
  END IF;
 END LOOP;
 definition:=pg_get_functiondef('public.lts_dashboard_source_key_v240(uuid)'::regprocedure);
 needle:='''operational'',public.lts_operational_source_key_v238(p_user_id),';
 replacement:='''cash_position_guard_revision'',''observed-position-not-reconciled-ledger-v1'','||chr(10)||' '||needle;
 IF strpos(definition,'cash_position_guard_revision')=0 THEN
  IF strpos(definition,needle)=0 THEN RAISE EXCEPTION 'missing canonical cache revision point'; END IF;
  EXECUTE replace(definition,needle,replacement);
 END IF;
END $patch$;
