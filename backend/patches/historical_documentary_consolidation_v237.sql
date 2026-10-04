CREATE OR REPLACE FUNCTION public.lts_flow_documentary_bank_sum_v237(p_user_id uuid,p_flow jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $f$
DECLARE d jsonb;days jsonb:='[]';bank text;lo date;hi date;anchor jsonb;cash jsonb;valid_c6 boolean:=false;
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
  IF (d->>'date')::date<date '2026-07-08' THEN days:=days||jsonb_build_array(d);CONTINUE;END IF;
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
  days:=days||jsonb_build_array(d);
 END LOOP;
 RETURN jsonb_set(p_flow,'{historical,days}',days)||jsonb_build_object('documentary_bank_sum_v237',jsonb_build_object('reconstructed_days',repaired,'c6_snapshot_and_received_stream_match',valid_c6,'itau_bradesco_independent_closing_calibration',calibrated,'full_bank_statement_certification',false));
END $f$;
REVOKE ALL ON FUNCTION public.lts_flow_documentary_bank_sum_v237(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_flow_documentary_bank_sum_v237(uuid,jsonb) TO service_role;
CREATE OR REPLACE FUNCTION public.lts_browser_flow_v229(p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' SET statement_timeout='45s' AS $f$
DECLARE u uuid:=public.lts_browser_assert_user_v1();j jsonb;
BEGIN
 j:=public.lts_browser_flow_pre_v248(p_from,p_to);
 j:=jsonb_set(j,'{flow}',public.lts_flow_documentary_bank_sum_v237(u,public.lts_flow_workbook_positions_v248(u,j->'flow')));
 RETURN j||jsonb_build_object('reader_revision','workbook-and-dated-bank-reconstruction-v237');
END $f$;
