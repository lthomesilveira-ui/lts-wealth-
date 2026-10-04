CREATE OR REPLACE FUNCTION public.lts_historical_bank_position_deltas_pre_v237(p_user_id uuid, p_to date)
 RETURNS TABLE(event_date date, account text, delta numeric, original_amount numeric, bank_amount numeric, evidence_ref uuid, target_ref text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH candidates AS MATERIALIZED (
 SELECT e.evidence_date,e.account,e.amount,(e.metadata->>'original_signed_amount')::numeric old_amount,e.id,e.metadata->>'target_flow_source_ref' ref,
 count(*) OVER(PARTITION BY e.account,e.evidence_date,e.metadata->>'target_flow_source_ref') matches
 FROM public.lts_reconciliation_evidence e JOIN public.lts_open_finance_staging s
 ON s.user_id=e.user_id AND s.id::text=e.metadata->>'bank_staging_id'
 AND s.raw_hash=e.metadata->>'bank_raw_hash' AND s.provider_deleted_at IS NULL
 WHERE e.user_id=p_user_id AND e.evidence_date<=p_to AND e.status='documented'
 AND e.evidence_type='card_invoice_payment' AND e.metadata->>'cash_effect'='replace_existing_payment_amount'
 AND e.account='C6' AND s.institution_code='336' AND e.amount<0
 AND s.normalized_payload->>'layer'='card_invoice_obligation' AND s.normalized_payload->>'currency'='BRL'
 AND (s.normalized_payload->>'amount')::numeric=-e.amount
 AND EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(s.normalized_payload->'payments','[]')) pay
 WHERE pay->>'id'=e.metadata->>'bank_payment_id' AND (pay->>'amount')::numeric=-e.amount
 AND left(pay->>'paymentDate',10)::date=e.evidence_date AND pay->>'currencyCode'='BRL')
)
SELECT c.evidence_date,c.account,c.amount-c.old_amount,c.old_amount,c.amount,c.id,c.ref
FROM candidates c WHERE matches=1 AND c.old_amount<0
AND (SELECT count(*) FROM public.lts_corrected_cashflow_fix86_v3(p_user_id,c.evidence_date,c.evidence_date) f
 WHERE f.account=c.account AND f.source_ref=c.ref AND f.signed_amount=c.old_amount AND f.event_date=c.evidence_date)=1
AND EXISTS(SELECT 1 FROM public.lts_corrected_cashflow_fix86_v4(p_user_id,c.evidence_date,c.evidence_date) f
 WHERE f.account=c.account AND f.source_ref=c.ref AND f.signed_amount=c.amount
 AND f.confidence='bank_documented_settlement_precedence');
$function$;

CREATE OR REPLACE FUNCTION public.lts_historical_bank_position_deltas_v1(p_user_id uuid, p_to date)
 RETURNS TABLE(event_date date, account text, delta numeric, original_amount numeric, bank_amount numeric, evidence_ref uuid, target_ref text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 AS $f$
SELECT * FROM public.lts_historical_bank_position_deltas_pre_v237(p_user_id,p_to)
UNION ALL
SELECT v.day,'Itaú',v.multiplier*(j->>'amount')::numeric,0,v.multiplier*(j->>'amount')::numeric,
(j->>'invoice_id')::uuid,'evento_base:'||(j->>'transfer_idx')
FROM (SELECT public.lts_c6_paid_identity_v237(p_user_id) j) p
CROSS JOIN LATERAL (VALUES (date '2026-07-05',1),((j->>'paid_date')::date,-1)) v(day,multiplier)
WHERE j IS NOT NULL AND v.day<=p_to;
$f$;
REVOKE ALL ON FUNCTION public.lts_historical_bank_position_deltas_pre_v237(uuid,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_historical_bank_position_deltas_pre_v237(uuid,date) TO service_role;

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
END $function$;

CREATE OR REPLACE FUNCTION public.lts_browser_recurring_future_gap_audit_v5(p_as_of date DEFAULT CURRENT_DATE,p_horizon_end date DEFAULT '2031-12-31'::date)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $f$
SELECT public.lts_recurring_future_gap_audit_v6(public.lts_browser_assert_user_v1(),coalesce(p_as_of,(now() at time zone 'America/Sao_Paulo')::date),coalesce(p_horizon_end,date '2031-12-31'));
$f$;
