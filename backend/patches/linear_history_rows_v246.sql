CREATE OR REPLACE FUNCTION public.lts_flow_workbook_positions_v248_pre_v246(p_user_id uuid, p_flow jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE lo date;hi date;proofs jsonb;proof jsonb;cash jsonb;dates jsonb;d jsonb;bank text;
 days jsonb:='[]';events jsonb;opening numeric;closing numeric;inc numeric;outflow numeric;
 total_open numeric;total_close numeric;total_in numeric;total_out numeric;complete boolean;
 first_bradesco date;first_c6 date;known boolean;c jsonb;bank_deltas jsonb;prior_delta numeric;day_delta numeric;effective jsonb;bank_precedence_used boolean; paid_identity jsonb;
BEGIN
 SELECT min((x->>'date')::date),max((x->>'date')::date) INTO lo,hi
 FROM jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'))x;
 IF lo IS NULL OR lo>date '2026-07-07' THEN RETURN public.lts_historical_bank_total_guard_v1(p_flow);END IF;
 hi:=least(hi,date '2026-07-07');
 paid_identity:=public.lts_c6_paid_identity_v237(p_user_id);
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
 IF paid_identity IS NOT NULL AND bank IN('Itaú','C6') AND (d->>'date')::date IN(date '2026-07-05',(paid_identity->>'paid_date')::date) THEN
 SELECT coalesce(sum((r->>'signed_amount')::numeric) FILTER(WHERE (r->>'signed_amount')::numeric>0),0),
 coalesce(-sum((r->>'signed_amount')::numeric) FILTER(WHERE (r->>'signed_amount')::numeric<0),0)
 INTO inc,outflow FROM jsonb_array_elements(cash) r WHERE r->>'account'=bank AND r->>'event_date'=d->>'date';
 bank_precedence_used:=true;
 END IF;
 bank_precedence_used:=bank_precedence_used OR prior_delta<>0 OR day_delta<>0;
    d:=jsonb_set(d,ARRAY[bank],coalesce(d->bank,'{}')||jsonb_build_object('balance',closing,'opening_balance',opening,'net',inc-outflow,
     'cash_entries',inc,'cash_exits',outflow,'balance_basis',CASE WHEN prior_delta<>0 OR day_delta<>0 THEN 'original_workbook_with_documented_bank_precedence' ELSE 'corroborated_original_workbook_cells' END,'balance_certified',false,
 'original_workbook_position',proof#>'{metadata,workbook_evidence,0,values}',
 'documented_bank_position_delta',prior_delta+day_delta,
 'documented_bank_day_delta',day_delta,
 'documented_settlement_identity',CASE WHEN bank IN('Itaú','C6') AND (d->>'date')::date IN(date '2026-07-05',(paid_identity->>'paid_date')::date) THEN paid_identity ELSE NULL END,
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
 RETURN public.lts_historical_bank_total_guard_v1(jsonb_set(jsonb_set(p_flow,'{historical,days}',days),'{historical,events}',events)||jsonb_build_object(
 'historical_workbook_positions',jsonb_build_object('version','corroborated-workbook-cash-v248','basis','two_original_workbooks','bank_certified',false,
 'display_note','Saldos históricos partem das planilhas originais. Pagamentos comprovados pelo banco prevalecem e seu efeito é carregado nos saldos seguintes, sem lançamento de ajuste.')));
END $function$
;
REVOKE ALL ON FUNCTION public.lts_flow_workbook_positions_v248_pre_v246(uuid,jsonb) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.lts_flow_workbook_positions_v248(p_user_id uuid, p_flow jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE output_rows jsonb[]:=ARRAY[]::jsonb[]; lo date;hi date;proofs jsonb;proof jsonb;cash jsonb;dates jsonb;d jsonb;bank text;
 days jsonb:='[]';events jsonb;opening numeric;closing numeric;inc numeric;outflow numeric;
 total_open numeric;total_close numeric;total_in numeric;total_out numeric;complete boolean;
 first_bradesco date;first_c6 date;known boolean;c jsonb;bank_deltas jsonb;prior_delta numeric;day_delta numeric;effective jsonb;bank_precedence_used boolean; paid_identity jsonb;
BEGIN
 SELECT min((x->>'date')::date),max((x->>'date')::date) INTO lo,hi
 FROM jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'))x;
 IF lo IS NULL OR lo>date '2026-07-07' THEN RETURN public.lts_historical_bank_total_guard_v1(p_flow);END IF;
 hi:=least(hi,date '2026-07-07');
 paid_identity:=public.lts_c6_paid_identity_v237(p_user_id);
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
 IF paid_identity IS NOT NULL AND bank IN('Itaú','C6') AND (d->>'date')::date IN(date '2026-07-05',(paid_identity->>'paid_date')::date) THEN
 SELECT coalesce(sum((r->>'signed_amount')::numeric) FILTER(WHERE (r->>'signed_amount')::numeric>0),0),
 coalesce(-sum((r->>'signed_amount')::numeric) FILTER(WHERE (r->>'signed_amount')::numeric<0),0)
 INTO inc,outflow FROM jsonb_array_elements(cash) r WHERE r->>'account'=bank AND r->>'event_date'=d->>'date';
 bank_precedence_used:=true;
 END IF;
 bank_precedence_used:=bank_precedence_used OR prior_delta<>0 OR day_delta<>0;
    d:=jsonb_set(d,ARRAY[bank],coalesce(d->bank,'{}')||jsonb_build_object('balance',closing,'opening_balance',opening,'net',inc-outflow,
     'cash_entries',inc,'cash_exits',outflow,'balance_basis',CASE WHEN prior_delta<>0 OR day_delta<>0 THEN 'original_workbook_with_documented_bank_precedence' ELSE 'corroborated_original_workbook_cells' END,'balance_certified',false,
 'original_workbook_position',proof#>'{metadata,workbook_evidence,0,values}',
 'documented_bank_position_delta',prior_delta+day_delta,
 'documented_bank_day_delta',day_delta,
 'documented_settlement_identity',CASE WHEN bank IN('Itaú','C6') AND (d->>'date')::date IN(date '2026-07-05',(paid_identity->>'paid_date')::date) THEN paid_identity ELSE NULL END,
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
  output_rows:=array_append(output_rows,d);
 END LOOP;
 SELECT coalesce(jsonb_agg(x ORDER BY x->>'event_date',x->>'source_ref'),'[]') INTO events FROM jsonb_array_elements(events)x;
 days:=to_jsonb(output_rows);
 RETURN public.lts_historical_bank_total_guard_v1(jsonb_set(jsonb_set(p_flow,'{historical,days}',days),'{historical,events}',events)||jsonb_build_object(
 'historical_workbook_positions',jsonb_build_object('version','corroborated-workbook-cash-v248','basis','two_original_workbooks','bank_certified',false,
 'display_note','Saldos históricos partem das planilhas originais. Pagamentos comprovados pelo banco prevalecem e seu efeito é carregado nos saldos seguintes, sem lançamento de ajuste.')));
END $function$
;

CREATE OR REPLACE FUNCTION public.lts_browser_flow_v240_pre_v246(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '45s'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); j jsonb; f jsonb; part text; d jsonb; c jsonb; historical_days jsonb:='[]'; bank text;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to THEN RAISE EXCEPTION 'invalid range';END IF;
 -- Include the anchor and preceding future payroll in every slice so the scenario is range independent.
 j:=public.lts_browser_flow_v229(least(p_from,current_date),p_to);
 f:=public.lts_flow_configured_fgts_v240(u,j->'flow',current_date);
 FOREACH part IN ARRAY ARRAY['historical','current_future'] LOOP
  f:=jsonb_set(f,ARRAY[part,'days'],coalesce((SELECT jsonb_agg(day_row ORDER BY day_row->>'date') FROM jsonb_array_elements(coalesce(f#>ARRAY[part,'days'],'[]'))day_row WHERE (day_row->>'date')::date BETWEEN p_from AND p_to),'[]'));
  f:=jsonb_set(f,ARRAY[part,'events'],coalesce((SELECT jsonb_agg(e ORDER BY e->>'event_date',e->>'source_ref') FROM jsonb_array_elements(coalesce(f#>ARRAY[part,'events'],'[]'))e WHERE (e->>'event_date')::date BETWEEN p_from AND p_to),'[]'));
 END LOOP;
 -- An unanchored cumulative ledger is not an absolute bank position.
 FOR d IN SELECT x FROM jsonb_array_elements(coalesce(f#>'{historical,days}','[]'))x ORDER BY x->>'date' LOOP
  IF coalesce((d->>'relative_balance_display')::boolean,false)
    AND NOT coalesce((d->>'absolute_balance_certified')::boolean,false)
    AND NOT coalesce((d->>'absolute_balance_reconstructed')::boolean,false) THEN
   c:=d->'fix86_columns';
   d:=d||jsonb_build_object('relative_position_debug',jsonb_build_object('legacy_columns',c,'legacy_consolidated',d->'Consolidado'),
    'absolute_position_status','unknown_source_conflict_or_missing_anchor',
    'Consolidado',(d->'Consolidado')||jsonb_build_object('bank_balance',NULL),
    'fix86_columns',c||jsonb_build_object('saldo_anterior',NULL,'saldo_final',NULL,'saldo_anterior_operacional',NULL,'saldo_final_operacional',NULL));
   FOREACH bank IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
    IF d#>>ARRAY[bank,'balance_basis']='relative_tracked_bank_ledger' THEN
     d:=jsonb_set(d,ARRAY[bank],(d->bank)||jsonb_build_object('balance',NULL,'opening_balance',NULL));
    END IF;
   END LOOP;
  END IF;
  historical_days:=historical_days||jsonb_build_array(d);
 END LOOP;
 f:=jsonb_set(f,'{historical,days}',historical_days)||jsonb_build_object('from',p_from,'to',p_to);
 RETURN j||jsonb_build_object('flow',f,'reader_revision','v240-configured-and-documentary-fgts-scenarios');
END $function$
;
REVOKE ALL ON FUNCTION public.lts_browser_flow_v240_pre_v246(date,date) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.lts_browser_flow_v240(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '45s'
AS $function$
DECLARE output_rows jsonb[]:=ARRAY[]::jsonb[]; u uuid:=public.lts_browser_assert_user_v1(); j jsonb; f jsonb; part text; d jsonb; c jsonb; historical_days jsonb:='[]'; bank text;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to THEN RAISE EXCEPTION 'invalid range';END IF;
 -- Include the anchor and preceding future payroll in every slice so the scenario is range independent.
 j:=public.lts_browser_flow_v229(least(p_from,current_date),p_to);
 f:=public.lts_flow_configured_fgts_v240(u,j->'flow',current_date);
 FOREACH part IN ARRAY ARRAY['historical','current_future'] LOOP
  f:=jsonb_set(f,ARRAY[part,'days'],coalesce((SELECT jsonb_agg(day_row ORDER BY day_row->>'date') FROM jsonb_array_elements(coalesce(f#>ARRAY[part,'days'],'[]'))day_row WHERE (day_row->>'date')::date BETWEEN p_from AND p_to),'[]'));
  f:=jsonb_set(f,ARRAY[part,'events'],coalesce((SELECT jsonb_agg(e ORDER BY e->>'event_date',e->>'source_ref') FROM jsonb_array_elements(coalesce(f#>ARRAY[part,'events'],'[]'))e WHERE (e->>'event_date')::date BETWEEN p_from AND p_to),'[]'));
 END LOOP;
 -- An unanchored cumulative ledger is not an absolute bank position.
 FOR d IN SELECT x FROM jsonb_array_elements(coalesce(f#>'{historical,days}','[]'))x ORDER BY x->>'date' LOOP
  IF coalesce((d->>'relative_balance_display')::boolean,false)
    AND NOT coalesce((d->>'absolute_balance_certified')::boolean,false)
    AND NOT coalesce((d->>'absolute_balance_reconstructed')::boolean,false) THEN
   c:=d->'fix86_columns';
   d:=d||jsonb_build_object('relative_position_debug',jsonb_build_object('legacy_columns',c,'legacy_consolidated',d->'Consolidado'),
    'absolute_position_status','unknown_source_conflict_or_missing_anchor',
    'Consolidado',(d->'Consolidado')||jsonb_build_object('bank_balance',NULL),
    'fix86_columns',c||jsonb_build_object('saldo_anterior',NULL,'saldo_final',NULL,'saldo_anterior_operacional',NULL,'saldo_final_operacional',NULL));
   FOREACH bank IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
    IF d#>>ARRAY[bank,'balance_basis']='relative_tracked_bank_ledger' THEN
     d:=jsonb_set(d,ARRAY[bank],(d->bank)||jsonb_build_object('balance',NULL,'opening_balance',NULL));
    END IF;
   END LOOP;
  END IF;
  output_rows:=array_append(output_rows,d);
 END LOOP;
 historical_days:=to_jsonb(output_rows);
 f:=jsonb_set(f,'{historical,days}',historical_days)||jsonb_build_object('from',p_from,'to',p_to);
 RETURN j||jsonb_build_object('flow',f,'reader_revision','v240-configured-and-documentary-fgts-scenarios');
END $function$
;

CREATE OR REPLACE FUNCTION public.lts_flow_documentary_bank_sum_v237_pre_v246(p_user_id uuid, p_flow jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
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
END $function$
;
REVOKE ALL ON FUNCTION public.lts_flow_documentary_bank_sum_v237_pre_v246(uuid,jsonb) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.lts_flow_documentary_bank_sum_v237(p_user_id uuid, p_flow jsonb)
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
END $function$
;

