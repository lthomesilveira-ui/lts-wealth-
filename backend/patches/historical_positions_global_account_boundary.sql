-- Account activity boundary is global, not the first movement inside the selected range.
-- Original workbook positions and validated bank precedence are unchanged.
CREATE OR REPLACE FUNCTION public.lts_flow_workbook_positions_v248(p_user_id uuid, p_flow jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE lo date;hi date;proofs jsonb;proof jsonb;cash jsonb;dates jsonb;d jsonb;bank text;
 days jsonb:='[]';events jsonb;opening numeric;closing numeric;inc numeric;outflow numeric;
 total_open numeric;total_close numeric;total_in numeric;total_out numeric;complete boolean;
 first_bradesco date;first_c6 date;known boolean;c jsonb;bank_deltas jsonb;prior_delta numeric;day_delta numeric;effective jsonb;bank_precedence_used boolean;
BEGIN
 SELECT min((x->>'date')::date),max((x->>'date')::date) INTO lo,hi
 FROM jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'))x;
 IF lo IS NULL OR lo>date '2026-07-07' THEN RETURN p_flow;END IF;
 hi:=least(hi,date '2026-07-07');
 SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO bank_deltas FROM public.lts_historical_bank_position_deltas_v1(p_user_id,hi) x;
 SELECT min(e.evidence_date) INTO first_bradesco FROM public.lts_reconciliation_evidence e
 WHERE e.user_id=p_user_id AND e.evidence_type='historical_workbook_cash_day' AND e.account='Bradesco' AND e.status='documented';
 SELECT min(h.event_date) INTO first_c6 FROM public.lts_historical_effective_cash_pre_v246(p_user_id,date '2013-10-10',date '2026-07-07') h WHERE h.account='C6';
 WITH rows AS MATERIALIZED(SELECT * FROM public.lts_historical_effective_cash_v5(p_user_id,lo,hi)),
 proof AS(
 SELECT e.* FROM public.lts_reconciliation_evidence e
 WHERE e.user_id=p_user_id AND e.evidence_type='historical_workbook_cash_day' AND e.status='documented'
 AND e.evidence_date BETWEEN lo AND hi AND jsonb_array_length(e.metadata->'workbook_evidence')=2
 AND abs((e.metadata->>'source_closing')::numeric-(e.metadata->>'source_opening')::numeric-e.amount)<.005
 AND round(e.amount+coalesce((SELECT sum((z->>'delta')::numeric) FROM jsonb_array_elements(bank_deltas) z
 WHERE z->>'account'=e.account AND (z->>'event_date')::date=e.evidence_date),0),2)=round(coalesce((SELECT sum(r.signed_amount) FROM rows r WHERE r.event_date=e.evidence_date AND r.account=e.account),0),2)
 AND NOT EXISTS(SELECT 1 FROM public.projecao_op o WHERE o.usuario_id=p_user_id AND o.dados->>'dia'=e.evidence_date::text
 AND translate(lower(o.dados->>'conta'),'ú','u')=translate(lower(e.account),'ú','u')
 AND coalesce(o.dados->>'status','ativa')='ativa' AND nullif(o.dados->>'revertidaEm','') IS NULL)
 )
 SELECT coalesce(jsonb_object_agg(e.evidence_date::text||'|'||e.account,to_jsonb(e)),'{}'),
 coalesce(jsonb_object_agg(e.evidence_date::text||'|'||e.account,true),'{}'),
 coalesce((SELECT jsonb_agg(to_jsonb(r)||jsonb_build_object('direction',CASE WHEN r.signed_amount<0 THEN 'saida' ELSE 'entrada' END,'excluded',r.excluded_from_spend))
 FROM rows r WHERE EXISTS(SELECT 1 FROM proof p WHERE p.evidence_date=r.event_date AND p.account=r.account)),'[]')
 INTO proofs,dates,cash FROM proof e;
 SELECT coalesce(jsonb_agg(x),'[]') INTO events FROM jsonb_array_elements(coalesce(p_flow#>'{historical,events}','[]')) x
 WHERE NOT(x->>'source' IN('legacy_fix86','historico_analitico','historical_workbook_cash') AND dates ? ((x->>'event_date')||'|'||(x->>'account')))
 AND NOT(x->>'source'='legacy_fix86' AND x->>'account'='Bradesco' AND (x->>'event_date')::date<first_bradesco);
 events:=events||cash;
 FOR d IN SELECT x FROM jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]')) x ORDER BY x->>'date' LOOP
  total_open:=0;total_close:=0;total_in:=0;total_out:=0;complete:=true;known:=false;bank_precedence_used:=false;
  FOREACH bank IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
   proof:=proofs->((d->>'date')||'|'||bank);
   IF proof IS NOT NULL THEN
    SELECT coalesce(sum((z->>'delta')::numeric) FILTER(WHERE (z->>'event_date')::date<(d->>'date')::date),0),
 coalesce(sum((z->>'delta')::numeric) FILTER(WHERE (z->>'event_date')::date=(d->>'date')::date),0)
 INTO prior_delta,day_delta FROM jsonb_array_elements(bank_deltas) z WHERE z->>'account'=bank;
 effective:=public.lts_workbook_cash_position_with_delta_v1(proof#>'{metadata,workbook_evidence,0,values}',prior_delta,day_delta);
 opening:=(effective->>'opening')::numeric;closing:=(effective->>'closing')::numeric;
 inc:=(effective->>'income')::numeric;outflow:=(effective->>'expense')::numeric;
 bank_precedence_used:=bank_precedence_used OR prior_delta<>0 OR day_delta<>0;
    d:=jsonb_set(d,ARRAY[bank],coalesce(d->bank,'{}')||jsonb_build_object('balance',closing,'opening_balance',opening,'net',inc-outflow,
     'cash_entries',inc,'cash_exits',outflow,'balance_basis',CASE WHEN prior_delta<>0 OR day_delta<>0 THEN 'original_workbook_with_documented_bank_precedence' ELSE 'corroborated_original_workbook_cells' END,'balance_certified',false,
 'original_workbook_position',proof#>'{metadata,workbook_evidence,0,values}',
 'documented_bank_position_delta',prior_delta+day_delta,
 'documented_bank_day_delta',day_delta,
 'bank_precedence_evidence',coalesce((SELECT jsonb_agg(z) FROM jsonb_array_elements(bank_deltas) z WHERE z->>'account'=bank AND (z->>'event_date')::date<=(d->>'date')::date),'[]'),
     'workbook_cash_reconciled',true,'workbook_evidence_ref',proof->>'id','source_arithmetic_gap',closing-opening-inc+outflow));
    total_open:=total_open+opening;total_close:=total_close+closing;total_in:=total_in+inc;total_out:=total_out+outflow;known:=true;
   ELSIF (bank='Bradesco' AND (d->>'date')::date<first_bradesco) OR (bank='C6' AND first_c6 IS NOT NULL AND (d->>'date')::date<first_c6) THEN
    d:=jsonb_set(d,ARRAY[bank],coalesce(d->bank,'{}')||jsonb_build_object('balance',0,'opening_balance',0,'net',0,'cash_entries',0,'cash_exits',0,
     'balance_basis','before_first_recorded_account_activity','balance_certified',false,'workbook_cash_reconciled',false));
   ELSE
    complete:=false;
   END IF;
  END LOOP;
  IF known THEN
   c:=coalesce(d->'fix86_columns','{}');
   IF complete THEN
    d:=d||jsonb_build_object('Consolidado',coalesce(d->'Consolidado','{}')||jsonb_build_object('bank_balance',total_close,'net',total_in-total_out,'economic_net',total_in-total_out,
      'balance_basis','corroborated_original_workbook_cells','balance_certified',false,'workbook_cash_reconciled',true),
      'relative_balance_display',false,'absolute_balance_certified',false,'absolute_balance_basis',CASE WHEN bank_precedence_used THEN 'original_workbooks_and_documented_bank_payments' ELSE 'original_workbooks' END,
      'v170_cash_arithmetic',jsonb_build_object('version','workbook-positions-with-validated-bank-precedence-v1','balanced',abs(total_close-total_open-total_in+total_out)<.005,
       'arithmetic_gap_brl',total_close-total_open-total_in+total_out,'operating_entries_brl',total_in,'operating_exits_brl',total_out,'tracked_bank_net_brl',total_in-total_out,'internal_transfer_net_brl',0));
    c:=c||jsonb_build_object('saldo_anterior',total_open,'saldo_anterior_operacional',total_open,'saldo_final',total_close,'saldo_final_operacional',total_close,'entradas',total_in,'saidas',total_out);
   ELSE
    d:=d||jsonb_build_object('Consolidado',coalesce(d->'Consolidado','{}')||jsonb_build_object('bank_balance',null,'balance_certified',false,'workbook_cash_reconciled',false,'balance_basis','incomplete_historical_bank_positions'));
    c:=c||jsonb_build_object('saldo_anterior',null,'saldo_anterior_operacional',null,'saldo_final',null,'saldo_final_operacional',null);
   END IF;
   c:=c||jsonb_build_object('saldo_apos_d0_1',null,'saldo_apos_rsu',null,'saldo_apos_fgts',null,'liq_d0_1',null,'disponivel_total',null);
   d:=d||jsonb_build_object('fix86_columns',c);
  END IF;
  days:=days||jsonb_build_array(d);
 END LOOP;
 SELECT coalesce(jsonb_agg(x ORDER BY x->>'event_date',x->>'source_ref'),'[]') INTO events FROM jsonb_array_elements(events)x;
 RETURN jsonb_set(jsonb_set(p_flow,'{historical,days}',days),'{historical,events}',events)||jsonb_build_object(
 'historical_workbook_positions',jsonb_build_object('version','corroborated-workbook-cash-v248','basis','two_original_workbooks','bank_certified',false,
 'display_note','Saldos históricos partem das planilhas originais. Pagamentos comprovados pelo banco prevalecem e seu efeito é carregado nos saldos seguintes, sem lançamento de ajuste.'));
END $function$;
