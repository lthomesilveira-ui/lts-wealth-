BEGIN;
SET LOCAL TimeZone='America/Sao_Paulo';SET LOCAL jit=off;
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
CREATE OR REPLACE FUNCTION public.lts_documentary_baseline_v255(p_user_id uuid, p_flow jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE output_rows jsonb[]:=ARRAY[]::jsonb[]; d jsonb;days jsonb:='[]';bank text;lo date;hi date;anchor jsonb;cash jsonb;valid_c6 boolean:=false;
 pos jsonb;c jsonb;bal numeric;inc numeric;outflow numeric;opening numeric;total_open numeric;total_close numeric;total_in numeric;total_out numeric;complete boolean;derived boolean;repaired int:=0;anchors jsonb;calibrated boolean:=false;base_itau numeric;base_bradesco numeric;
BEGIN
 SELECT min((x->>'date')::date),max((x->>'date')::date) INTO lo,hi FROM jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'))x;
 IF lo IS NULL THEN RETURN p_flow;END IF;
 SELECT to_jsonb(e) INTO anchor FROM public.lts_reconciliation_evidence e WHERE e.user_id=p_user_id AND e.account='C6' AND e.evidence_type='balance_anchor' AND e.evidence_date=date '2026-08-17' AND e.status='documented' AND e.metadata->>'anchor_class'='certified_snapshot' AND e.amount=0;
 SELECT coalesce(jsonb_agg(to_jsonb(h)),'[]') INTO cash FROM public.lts_historical_effective_cash_v5(p_user_id,date '2026-07-08',date '2026-08-23') h;
 IF anchor IS NOT NULL AND public.lts_c6_paid_identity_v237(p_user_id) IS NOT NULL AND lo<=date '2026-08-23' AND hi>=date '2026-07-08' THEN
 WITH days AS(SELECT generate_series(date '2026-07-07',date '2026-08-23','1 day')::date flow_date),
 bank_rows AS(SELECT posting_date,sum(signed_amount) net FROM public.lts_open_finance_staging WHERE user_id=p_user_id AND institution_code='336' AND resource_type='transaction' AND provider_deleted_at IS NULL AND normalized_payload->>'layer'='bank_cash' AND normalized_payload->>'account_type'='CHECKING_ACCOUNT' AND normalized_payload->>'status'='POSTED' AND currency='BRL' AND posting_date BETWEEN date '2026-07-07' AND date '2026-08-23' GROUP BY posting_date),
 cash_rows AS(SELECT event_date,sum(signed_amount) net FROM public.lts_historical_effective_cash_v5(p_user_id,date '2026-07-07',date '2026-08-23') WHERE account='C6' GROUP BY event_date)
 SELECT bool_and(coalesce(h.net,0)=coalesce(b.net,0)) AND sum(coalesce(b.net,0))=0 INTO valid_c6 FROM days d LEFT JOIN bank_rows b ON b.posting_date=d.flow_date LEFT JOIN cash_rows h ON h.event_date=d.flow_date;
 END IF;
 SELECT amount INTO base_itau FROM public.lts_reconciliation_evidence WHERE user_id=p_user_id AND account='Itaú' AND evidence_type='balance_anchor' AND status='documented' AND evidence_date=date '2026-07-07';
 SELECT amount INTO base_bradesco FROM public.lts_reconciliation_evidence WHERE user_id=p_user_id AND account='Bradesco' AND evidence_type='balance_anchor' AND status='documented' AND evidence_date=date '2026-07-24';
 SELECT count(*)=4 AND bool_and(abs(e.amount-CASE WHEN e.account='Itaú' THEN base_itau ELSE base_bradesco END-
 coalesce((SELECT sum((h->>'signed_amount')::numeric) FROM jsonb_array_elements(cash)h WHERE h->>'account'=e.account AND (h->>'event_date')::date<=e.evidence_date AND (e.account='Itaú' OR (h->>'event_date')::date>date '2026-07-24')),0))<.005),jsonb_agg(to_jsonb(e)) INTO calibrated,anchors
 FROM public.lts_reconciliation_evidence e WHERE e.user_id=p_user_id AND e.account IN('Itaú','Bradesco') AND e.evidence_type='balance_anchor' AND e.status='documented' AND e.evidence_date IN(date '2026-08-18',date '2026-08-23');
 FOR d IN SELECT x FROM jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'))x ORDER BY x->>'date' LOOP
  IF (d->>'date')::date<date '2026-07-08' THEN output_rows:=array_append(output_rows,d);CONTINUE;END IF;
  total_open:=0;total_close:=0;total_in:=0;total_out:=0;complete:=true;derived:=false;
  FOREACH bank IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
   pos:=d->bank;
   IF bank IN('Itaú','Bradesco') AND (d->>'date')::date<date '2026-07-24' AND calibrated THEN
    SELECT CASE WHEN bank='Itaú' THEN base_itau+coalesce(sum((h->>'signed_amount')::numeric) FILTER(WHERE (h->>'event_date')::date<=(d->>'date')::date),0)
    ELSE base_bradesco-coalesce(sum((h->>'signed_amount')::numeric) FILTER(WHERE (h->>'event_date')::date>(d->>'date')::date AND (h->>'event_date')::date<=date '2026-07-24'),0) END INTO bal FROM jsonb_array_elements(cash)h WHERE h->>'account'=bank;
    pos:=pos||jsonb_build_object('original_relative_position',pos,'balance',bal,'balance_basis','dated_anchors_and_cash_calibrated_to_two_independent_closings','balance_certified',false,'documentary_anchor_ref',anchors->0->>'id','documentary_reconstruction',true);derived:=true;
   END IF;
   IF bank='C6' AND (d->>'date')::date<=date '2026-08-22' AND valid_c6 THEN
    SELECT CASE WHEN (d->>'date')::date<=date '2026-08-17' THEN
 -coalesce(sum((h->>'signed_amount')::numeric) FILTER(WHERE (h->>'event_date')::date>(d->>'date')::date AND (h->>'event_date')::date<=date '2026-08-17'),0)
 ELSE coalesce(sum((h->>'signed_amount')::numeric) FILTER(WHERE (h->>'event_date')::date>date '2026-08-17' AND (h->>'event_date')::date<=(d->>'date')::date),0) END
 INTO bal FROM jsonb_array_elements(cash)h WHERE h->>'account'='C6';
    pos:=pos||jsonb_build_object('original_relative_position',pos,'balance',bal,'balance_basis','dated_snapshot_with_matching_received_bank_and_cash_streams','balance_certified',false,'documentary_anchor_ref',anchor->>'id','documentary_reconstruction',true,'reconstruction_note','Saldo reconstruído a partir do snapshot de 17/08 e movimentos recebidos. Não é certificação de extrato completo.');derived:=true;
   END IF;
   IF pos IS NULL OR pos->>'balance' IS NULL OR pos->>'balance_basis'='relative_tracked_bank_ledger' THEN complete:=false;CONTINUE;END IF;
   bal:=(pos->>'balance')::numeric;
   IF (d->>'date')::date<=date '2026-08-23' THEN
    SELECT coalesce(sum((h->>'signed_amount')::numeric) FILTER(WHERE (h->>'signed_amount')::numeric>0),0),
    coalesce(-sum((h->>'signed_amount')::numeric) FILTER(WHERE (h->>'signed_amount')::numeric<0),0) INTO inc,outflow FROM jsonb_array_elements(cash)h WHERE h->>'account'=bank AND h->>'event_date'=d->>'date';
   ELSE
    SELECT coalesce(sum((h->>'signed_amount')::numeric) FILTER(WHERE (h->>'signed_amount')::numeric>0),0),
    coalesce(-sum((h->>'signed_amount')::numeric) FILTER(WHERE (h->>'signed_amount')::numeric<0),0) INTO inc,outflow FROM jsonb_array_elements(coalesce(p_flow#>'{historical,events}','[]'))h WHERE h->>'account'=bank AND h->>'event_date'=d->>'date' AND h->>'source'<>'economic_withholding';
   END IF;
   opening:=bal-inc+outflow;
   pos:=pos||jsonb_build_object('opening_balance',opening,'cash_entries',inc,'cash_exits',outflow,'net',inc-outflow,'source_arithmetic_gap',0);
   d:=jsonb_set(d,ARRAY[bank],pos);total_open:=total_open+opening;total_close:=total_close+bal;total_in:=total_in+inc;total_out:=total_out+outflow;
  END LOOP;
  IF complete THEN
   c:=coalesce(d->'fix86_columns','{}');
   d:=d||jsonb_build_object('Consolidado',coalesce(d->'Consolidado','{}')||jsonb_build_object('bank_balance',total_close,'net',total_in-total_out,'economic_net',total_in-total_out,'balance_basis','sum_of_documented_account_positions','balance_certified',false,'documentary_reconstruction',true),
   'relative_balance_display',false,'absolute_balance_certified',false,'absolute_balance_basis','sum_of_documented_account_positions','historical_bank_total_guard',jsonb_build_object('status','reconstructed_from_account_positions','original_invalid_aggregate',d->'historical_bank_total_guard','no_cash_adjustment_created',true),
   'v170_cash_arithmetic',jsonb_build_object('version','account-positions-plus-effective-cash-v237','balanced',abs(total_close-total_open-total_in+total_out)<.005,'arithmetic_gap_brl',total_close-total_open-total_in+total_out,'operating_entries_brl',total_in,'operating_exits_brl',total_out,'tracked_bank_net_brl',total_in-total_out,'internal_transfer_net_brl',0));
   c:=c||jsonb_build_object('saldo_anterior',total_open,'saldo_anterior_operacional',total_open,'saldo_final',total_close,'saldo_final_operacional',total_close,'entradas',total_in,'saidas',total_out);
   IF (c->>'liq_d0_1_recurso') IS NOT NULL THEN c:=c||jsonb_build_object('saldo_apos_d0_1',total_close+(c->>'liq_d0_1_recurso')::numeric,'liq_d0_1',total_close+(c->>'liq_d0_1_recurso')::numeric);END IF;
   IF c->>'rsus_vested' IS NOT NULL AND c->>'saldo_apos_d0_1' IS NOT NULL THEN c:=c||jsonb_build_object('saldo_apos_rsu',(c->>'saldo_apos_d0_1')::numeric+(c->>'rsus_vested')::numeric,'disponivel_total',(c->>'saldo_apos_d0_1')::numeric+(c->>'rsus_vested')::numeric,'posicao_curto_prazo',(c->>'saldo_apos_d0_1')::numeric+(c->>'rsus_vested')::numeric);END IF;
   IF c->>'fgts' IS NOT NULL AND c->>'saldo_apos_rsu' IS NOT NULL THEN c:=c||jsonb_build_object('saldo_apos_fgts',(c->>'saldo_apos_rsu')::numeric+(c->>'fgts')::numeric);END IF;
   d:=d||jsonb_build_object('fix86_columns',c);repaired:=repaired+1;
  END IF;
  output_rows:=array_append(output_rows,d);
 END LOOP;
 days:=to_jsonb(output_rows);
 RETURN jsonb_set(p_flow,'{historical,days}',days)||jsonb_build_object('documentary_bank_sum_v237',jsonb_build_object('reconstructed_days',repaired,'c6_snapshot_and_received_stream_match',valid_c6,'itau_bradesco_independent_closing_calibration',calibrated,'full_bank_statement_certification',false));
END $function$;

REVOKE ALL ON FUNCTION public.lts_documentary_baseline_v255(uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;
-- V255: exact per-day documentary sums, without recomputing the arrays for each day.
DO $v255$
DECLARE s text:=pg_get_functiondef('public.lts_flow_documentary_bank_sum_v237(uuid,jsonb)'::regprocedure);needle text;
BEGIN
 IF md5(btrim(s,E' \t\r\n'))<>'7f651e68c7aa0b88d5a6245231884555' THEN RAISE EXCEPTION 'V255_SOURCE_LEASE_CHANGED';END IF;
 needle:=$old0$base_itau numeric;base_bradesco numeric;$old0$;
 IF (length(s)-length(replace(s,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'V255_REPLACEMENT_0_NOT_UNIQUE';END IF;
 s:=replace(s,needle,$new0$base_itau numeric;base_bradesco numeric;cash_daily_v255 jsonb;event_daily_v255 jsonb;$new0$);
 needle:=$old1$ FOR d IN SELECT x FROM jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'))x ORDER BY x->>'date' LOOP$old1$;
 IF (length(s)-length(replace(s,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'V255_REPLACEMENT_1_NOT_UNIQUE';END IF;
 s:=replace(s,needle,$new1$ -- Aggregate the same documentary movement rows once. No dates, sources,
 -- identities, anchor decisions, account balances or unknowns are changed.
 WITH rows_v255 AS MATERIALIZED (
  SELECT h->>'event_date' dt,h->>'account' bank,(h->>'signed_amount')::numeric amount
  FROM jsonb_array_elements(cash) h
 ), daily_v255 AS (
  SELECT r.dt,r.bank,coalesce(sum(r.amount) FILTER(WHERE r.amount>0),0) income,
   coalesce(-sum(r.amount) FILTER(WHERE r.amount<0),0) expense
  FROM rows_v255 r GROUP BY r.dt,r.bank
 )
 SELECT coalesce(jsonb_object_agg(a.dt||'|'||a.bank,jsonb_build_object('income',a.income,'expense',a.expense)),'{}')
 INTO cash_daily_v255 FROM daily_v255 a WHERE a.dt IS NOT NULL AND a.bank IS NOT NULL;
 WITH day_keys_v255 AS MATERIALIZED (
  SELECT DISTINCT (day.x->>'date')||'|'||b.bank k
  FROM jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]')) day(x)
  CROSS JOIN unnest(ARRAY['Itaú','Bradesco','C6']) b(bank)
  WHERE (day.x->>'date')::date>date '2026-08-23'
   AND (day.x->b.bank)->>'balance' IS NOT NULL
   AND (day.x->b.bank)->>'balance_basis' IS DISTINCT FROM 'relative_tracked_bank_ledger'
 ), rows_v255 AS MATERIALIZED (
  SELECT h->>'event_date' dt,h->>'account' bank,(h->>'signed_amount')::numeric amount
  FROM jsonb_array_elements(coalesce(p_flow#>'{historical,events}','[]')) h
  JOIN day_keys_v255 k ON k.k=(h->>'event_date')||'|'||(h->>'account')
  WHERE h->>'source'<>'economic_withholding'
 ), daily_v255 AS (
  SELECT r.dt,r.bank,coalesce(sum(r.amount) FILTER(WHERE r.amount>0),0) income,
   coalesce(-sum(r.amount) FILTER(WHERE r.amount<0),0) expense
  FROM rows_v255 r GROUP BY r.dt,r.bank
 )
 SELECT coalesce(jsonb_object_agg(a.dt||'|'||a.bank,jsonb_build_object('income',a.income,'expense',a.expense)),'{}')
 INTO event_daily_v255 FROM daily_v255 a;
 FOR d IN SELECT x FROM jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'))x ORDER BY x->>'date' LOOP$new1$);
 needle:=$old2$   IF (d->>'date')::date<=date '2026-08-23' THEN
    SELECT coalesce(sum((h->>'signed_amount')::numeric) FILTER(WHERE (h->>'signed_amount')::numeric>0),0),
    coalesce(-sum((h->>'signed_amount')::numeric) FILTER(WHERE (h->>'signed_amount')::numeric<0),0) INTO inc,outflow FROM jsonb_array_elements(cash)h WHERE h->>'account'=bank AND h->>'event_date'=d->>'date';
   ELSE
    SELECT coalesce(sum((h->>'signed_amount')::numeric) FILTER(WHERE (h->>'signed_amount')::numeric>0),0),
    coalesce(-sum((h->>'signed_amount')::numeric) FILTER(WHERE (h->>'signed_amount')::numeric<0),0) INTO inc,outflow FROM jsonb_array_elements(coalesce(p_flow#>'{historical,events}','[]'))h WHERE h->>'account'=bank AND h->>'event_date'=d->>'date' AND h->>'source'<>'economic_withholding';
   END IF;$old2$;
 IF (length(s)-length(replace(s,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'V255_REPLACEMENT_2_NOT_UNIQUE';END IF;
 s:=replace(s,needle,$new2$   IF (d->>'date')::date<=date '2026-08-23' THEN
    inc:=coalesce((cash_daily_v255#>>ARRAY[(d->>'date')||'|'||bank,'income'])::numeric,0);
    outflow:=coalesce((cash_daily_v255#>>ARRAY[(d->>'date')||'|'||bank,'expense'])::numeric,0);
   ELSE
    inc:=coalesce((event_daily_v255#>>ARRAY[(d->>'date')||'|'||bank,'income'])::numeric,0);
    outflow:=coalesce((event_daily_v255#>>ARRAY[(d->>'date')||'|'||bank,'expense'])::numeric,0);
   END IF;$new2$);
 EXECUTE s;
END $v255$;

DO $fixtures$
DECLARE u uuid:=public.lts_browser_assert_user_v1();f jsonb;days jsonb:='[]';events jsonb;j jsonb;b jsonb;d int;bank text;pos jsonb;
BEGIN
FOR d IN 24..26 LOOP
 j:=jsonb_build_object('date',make_date(2026,9,d),'fix86_columns',jsonb_build_object('saldo_final',600));
 FOREACH bank IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
 pos:=jsonb_build_object('balance',100,'balance_basis','documented_fixture');
 IF d=26 AND bank='Itaú' THEN pos:=jsonb_build_object('balance',NULL,'balance_basis','relative_tracked_bank_ledger');END IF;
 IF d=26 AND bank='Bradesco' THEN pos:=jsonb_build_object('balance',100,'balance_basis','relative_tracked_bank_ledger');END IF;
 j:=j||jsonb_build_object(bank,pos);
 END LOOP;
 days:=days||jsonb_build_array(j);
END LOOP;
events:='[
{"event_date":"2026-09-25","account":"Itaú","signed_amount":-10,"source":"current_event","source_ref":"synthetic-duplicate-a"},
{"event_date":"2026-09-25","account":"Itaú","signed_amount":-10,"source":"current_event","source_ref":"synthetic-duplicate-b"},
{"event_date":"2026-09-25","account":"Itaú","signed_amount":20,"source":"current_event"},
{"event_date":"2026-09-25","account":"Itaú","signed_amount":null,"source":"current_event"},
{"event_date":"2026-09-25","account":"Bradesco","signed_amount":-1.239,"source":"current_event"},
{"event_date":"2026-09-25","account":"Bradesco","signed_amount":1.239,"source":"current_event"},
{"event_date":"2026-09-25","account":"C6","signed_amount":999,"source":"economic_withholding"},
{"event_date":"2026-09-25","account":"C6","signed_amount":888,"source":null},
{"event_date":"2026-09-26","account":"Itaú","signed_amount":"not-number","source":"current_event"},
{"event_date":"2026-09-26","account":"Bradesco","signed_amount":"not-number","source":"current_event"},
{"event_date":"2026-09-26","account":"C6","signed_amount":-0.001,"source":"current_event"},
{"event_date":"2026-12-01","account":"C6","signed_amount":"not-number","source":"current_event"}
]'::jsonb;
f:=jsonb_build_object('historical',jsonb_build_object('days',days,'events',events));
b:=public.lts_documentary_baseline_v255(u,f);j:=public.lts_flow_documentary_bank_sum_v237(u,f);
IF b::text IS DISTINCT FROM j::text THEN RAISE EXCEPTION 'V255_SYNTHETIC_RESPONSE_CHANGED';END IF;
IF (j#>>'{historical,days,1,Itaú,cash_exits}')::numeric<>20 OR (j#>>'{historical,days,1,Itaú,cash_entries}')::numeric<>20 THEN RAISE EXCEPTION 'V255_DUPLICATES_OR_REFUNDS_NOT_PRESERVED';END IF;
IF j#>>'{historical,days,2,Itaú,balance}' IS NOT NULL THEN RAISE EXCEPTION 'V255_UNKNOWN_POSITION_FABRICATED';END IF;
IF (j#>>'{historical,days,1,C6,cash_entries}')::numeric<>0 THEN RAISE EXCEPTION 'V255_EXCLUDED_SOURCE_COUNTED';END IF;
PERFORM set_config('lts.v255_fixture_receipt',jsonb_build_object('status','PASS','duplicates_preserved',true,'positive_and_negative_preserved',true,'subcent_precision_preserved',true,'missing_or_withheld_source_excluded',true,'unknown_or_relative_positions_preserved',true,'unvisited_invalid_amount_ignored',true,'source_fixtures_written',false)::text,true);
END $fixtures$;
SELECT current_setting('lts.v255_fixture_receipt')::jsonb AS receipt;
ROLLBACK;