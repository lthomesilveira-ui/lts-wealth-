BEGIN;SET LOCAL statement_timeout='90s';SET LOCAL jit=off;SET LOCAL TimeZone='America/Sao_Paulo';
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
CREATE TEMP TABLE ranges_before_v257(lo date,hi date,j jsonb,ms numeric) ON COMMIT DROP;
DO $before$ DECLARE r record;t timestamptz;j jsonb;BEGIN FOR r IN SELECT * FROM(VALUES(date '2019-01-01',date '2020-12-31'),(date '2026-07-01',date '2026-08-31'),(date '2027-01-01',date '2027-12-31'))v(lo,hi) LOOP t:=clock_timestamp();j:=public.lts_browser_flow_v241(r.lo,r.hi);INSERT INTO ranges_before_v257 VALUES(r.lo,r.hi,j,extract(epoch FROM clock_timestamp()-t)*1000);END LOOP;END $before$;
CREATE OR REPLACE FUNCTION public.lts_historical_bank_total_guard_v1(p_flow jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE output_rows jsonb[]:=ARRAY[]::jsonb[]; d jsonb; c jsonb; result_days jsonb:='[]'; bank_sum numeric; nested_total numeric; displayed_total numeric; invalid_count integer:=0;
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
  output_rows:=array_append(output_rows,d);
 END LOOP;
 IF invalid_count=0 THEN RETURN p_flow;END IF;
 result_days:=to_jsonb(output_rows);
 RETURN jsonb_set(p_flow,'{historical,days}',result_days)||jsonb_build_object('historical_bank_total_guard',
 jsonb_build_object('version','inconsistent-aggregate-not-bank-cash-v1','invalidated_days',invalid_count,
 'note','Consolidado inconsistente com as posições por banco fica indisponível; fontes originais preservadas, sem ajuste.'));
END $function$
;
CREATE OR REPLACE FUNCTION public.lts_flow_bounded_workbook_positions_v238(p_user_id uuid, p_flow jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE output_rows jsonb[]:=ARRAY[]::jsonb[]; lo date; hi date; cash jsonb; proofs jsonb; windows jsonb; rejected jsonb;
 d jsonb; proof jsonb; pos jsonb; c jsonb; days jsonb:='[]'; dt date; bank text;
 opening numeric; closing numeric; inc numeric; outflow numeric;
 total_open numeric;total_close numeric;total_in numeric;total_out numeric;
 complete boolean; recovered int:=0;
BEGIN
 SELECT min((x->>'date')::date),max((x->>'date')::date) INTO lo,hi
 FROM jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'))x;
 IF lo IS NULL OR hi<date '2018-01-01' OR lo>date '2021-12-31' THEN RETURN p_flow; END IF;
 lo:=greatest(lo-8,date '2018-01-01');hi:=least(hi+8,date '2021-12-31');
 SELECT coalesce(jsonb_agg(to_jsonb(h)),'[]') INTO cash
 FROM public.lts_historical_effective_cash_v5(p_user_id,lo,hi) h WHERE h.account='Itaú';
 WITH source AS MATERIALIZED (
  SELECT e.*,count(*) OVER(PARTITION BY evidence_date) copies
  FROM public.lts_reconciliation_evidence e
  WHERE e.user_id=p_user_id AND e.account='Itaú' AND e.status='documented'
  AND e.evidence_type='historical_workbook_cash_day' AND e.evidence_date BETWEEN lo AND hi
 ), dated AS MATERIALIZED (
  SELECT s.* FROM source s WHERE copies=1
  AND jsonb_array_length(s.metadata->'workbook_evidence')=2
  AND (SELECT count(DISTINCT w->>'sha256')=2 AND bool_and(w->>'date'=s.evidence_date::text
   AND w->>'bank'=s.account AND w->>'sheet'='Fluxo de Caixa'
   AND abs((w#>>'{values,closing}')::numeric-(s.metadata->>'source_closing')::numeric)<.005
   AND abs((w#>>'{values,opening}')::numeric-(s.metadata->>'source_opening')::numeric)<.005)
   FROM jsonb_array_elements(s.metadata->'workbook_evidence')w)
  AND abs((s.metadata->>'source_closing')::numeric-(s.metadata->>'source_opening')::numeric-s.amount)<.005
  AND round(s.amount,2)=round(coalesce((SELECT sum((h->>'signed_amount')::numeric)
   FROM jsonb_array_elements(cash)h WHERE h->>'event_date'=s.evidence_date::text),0),2)
  AND NOT EXISTS(SELECT 1 FROM public.projecao_op o WHERE o.usuario_id=p_user_id
   AND o.dados->>'dia'=s.evidence_date::text AND translate(lower(o.dados->>'conta'),'ú','u')='itau'
   AND coalesce(o.dados->>'status','ativa')='ativa' AND nullif(o.dados->>'revertidaEm','') IS NULL)
 ), paired AS (
  SELECT d.*,lead(evidence_date) OVER(ORDER BY evidence_date) next_date,
   lead(id) OVER(ORDER BY evidence_date) next_ref,
   lead((metadata->>'source_opening')::numeric) OVER(ORDER BY evidence_date) next_opening
  FROM dated d
 ), bounded AS MATERIALIZED (
  SELECT p.*,(metadata->>'source_closing')::numeric start_closing,
   next_opening-(metadata->>'source_closing')::numeric-coalesce((SELECT sum((h->>'signed_amount')::numeric)
   FROM jsonb_array_elements(cash)h WHERE (h->>'event_date')::date>p.evidence_date
   AND (h->>'event_date')::date<p.next_date),0) gap
  FROM paired p WHERE next_date-evidence_date BETWEEN 2 AND 8
 ), expanded AS (
  SELECT b.evidence_date+g.n AS cash_date,b.* FROM bounded b
  CROSS JOIN LATERAL generate_series(1,b.next_date-b.evidence_date-1)g(n)
  WHERE abs(b.gap)<.005 AND NOT EXISTS(SELECT 1 FROM source s WHERE s.evidence_date=b.evidence_date+g.n)
  AND NOT EXISTS(SELECT 1 FROM public.projecao_op o WHERE o.usuario_id=p_user_id
   AND o.dados->>'dia'=(b.evidence_date+g.n)::text AND translate(lower(o.dados->>'conta'),'ú','u')='itau'
   AND coalesce(o.dados->>'status','ativa')='ativa' AND nullif(o.dados->>'revertidaEm','') IS NULL)
 )
 SELECT coalesce(jsonb_object_agg(cash_date::text,jsonb_build_object('before_date',evidence_date,'after_date',next_date,
  'before_evidence_ref',id,'after_evidence_ref',next_ref,'start_closing',start_closing,
  'end_opening',next_opening,'boundary_gap_brl',gap)),'{}'),
  coalesce((SELECT jsonb_agg(jsonb_build_object('before_date',evidence_date,'after_date',next_date,
   'missing_days',next_date-evidence_date-1,'boundary_gap_brl',gap)) FROM bounded WHERE abs(gap)<.005),'[]'),
  coalesce((SELECT jsonb_agg(jsonb_build_object('before_date',evidence_date,'after_date',next_date,
   'missing_days',next_date-evidence_date-1,'boundary_gap_brl',gap,'reason','cash_does_not_reconcile_dated_positions'))
   FROM bounded WHERE abs(gap)>=.005),'[]') INTO proofs,windows,rejected FROM expanded;
 FOR d IN SELECT x FROM jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'))x ORDER BY x->>'date' LOOP
  dt:=(d->>'date')::date;proof:=proofs->dt::text;
  IF proof IS NULL OR d#>>'{Itaú,balance_basis}' IS DISTINCT FROM 'relative_tracked_bank_ledger' THEN
   output_rows:=array_append(output_rows,d);CONTINUE;
  END IF;
  SELECT (proof->>'start_closing')::numeric+coalesce(sum((h->>'signed_amount')::numeric)
   FILTER(WHERE (h->>'event_date')::date<dt),0),
   coalesce(sum((h->>'signed_amount')::numeric) FILTER(WHERE h->>'event_date'=dt::text AND (h->>'signed_amount')::numeric>0),0),
   coalesce(-sum((h->>'signed_amount')::numeric) FILTER(WHERE h->>'event_date'=dt::text AND (h->>'signed_amount')::numeric<0),0)
   INTO opening,inc,outflow FROM jsonb_array_elements(cash)h
   WHERE (h->>'event_date')::date>(proof->>'before_date')::date AND (h->>'event_date')::date<=dt;
  closing:=opening+inc-outflow;
  pos:=d->'Itaú';pos:=pos||jsonb_build_object('original_relative_position',pos,'balance',closing,'opening_balance',opening,
   'cash_entries',inc,'cash_exits',outflow,'net',inc-outflow,'balance_basis','bounded_original_workbook_cash_reconstruction',
   'balance_certified',false,'documentary_reconstruction',true,'documentary_anchor_ref',proof->>'before_evidence_ref',
   'bounded_workbook_evidence',proof,'source_arithmetic_gap',0,
   'reconstruction_note','Dias entre duas posições datadas das planilhas, com movimentos que fecham o intervalo. Não é extrato bancário integral.');
  d:=jsonb_set(d,'{Itaú}',pos);recovered:=recovered+1;
  total_open:=0;total_close:=0;total_in:=0;total_out:=0;complete:=true;
  FOREACH bank IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
   pos:=d->bank;
   IF pos->>'balance' IS NULL OR pos->>'opening_balance' IS NULL
    OR pos->>'balance_basis'='relative_tracked_bank_ledger' THEN complete:=false;EXIT;END IF;
   total_open:=total_open+(pos->>'opening_balance')::numeric;total_close:=total_close+(pos->>'balance')::numeric;
   total_in:=total_in+coalesce((pos->>'cash_entries')::numeric,0);total_out:=total_out+coalesce((pos->>'cash_exits')::numeric,0);
  END LOOP;
  IF complete THEN
   c:=d->'fix86_columns';c:=c||jsonb_build_object('saldo_anterior',total_open,'saldo_anterior_operacional',total_open,
    'saldo_final',total_close,'saldo_final_operacional',total_close,'entradas',total_in,'saidas',total_out);
   d:=d||jsonb_build_object('fix86_columns',c,'relative_balance_display',false,'absolute_balance_certified',false,
    'absolute_balance_basis','bounded_original_workbooks_and_effective_cash',
    'Consolidado',(d->'Consolidado')||jsonb_build_object('bank_balance',total_close,'net',total_in-total_out,
     'economic_net',total_in-total_out,'balance_basis','bounded_original_workbooks_and_effective_cash',
     'balance_certified',false,'documentary_reconstruction',true),
    'v170_cash_arithmetic',jsonb_build_object('version','bounded-dated-workbook-cash-v238',
     'balanced',abs(total_close-total_open-total_in+total_out)<.005,'arithmetic_gap_brl',total_close-total_open-total_in+total_out,
     'operating_entries_brl',total_in,'operating_exits_brl',total_out,'tracked_bank_net_brl',total_in-total_out,'internal_transfer_net_brl',0));
  END IF;
  output_rows:=array_append(output_rows,d);
 END LOOP;
 days:=to_jsonb(output_rows);
 RETURN jsonb_set(p_flow,'{historical,days}',days)||jsonb_build_object('bounded_workbook_positions_v238',
  jsonb_build_object('recovered_days',recovered,'validated_intervals',windows,'rejected_intervals',rejected,
   'full_bank_statement_certification',false,'cash_adjustments_created',false));
END $function$
;
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;
DO $after$ DECLARE r record;t timestamptz;j jsonb;receipts jsonb:='[]';BEGIN FOR r IN SELECT * FROM ranges_before_v257 ORDER BY lo LOOP t:=clock_timestamp();j:=public.lts_browser_flow_v241(r.lo,r.hi);IF j::text IS DISTINCT FROM r.j::text THEN RAISE EXCEPTION 'V257_RANGE_CHANGED %',r.lo;END IF;receipts:=receipts||jsonb_build_array(jsonb_build_object('from',r.lo,'to',r.hi,'before_ms',r.ms,'after_ms',extract(epoch FROM clock_timestamp()-t)*1000,'digest',md5(j::text),'exact',true));END LOOP;PERFORM set_config('lts.v257_range_qa',jsonb_build_object('pass',true,'results',receipts)::text,true);END $after$;
SELECT current_setting('lts.v257_range_qa')::jsonb receipt;ROLLBACK;
