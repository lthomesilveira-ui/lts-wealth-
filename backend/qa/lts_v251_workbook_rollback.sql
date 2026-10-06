BEGIN;
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',c.user_id,'email',a.email,'role','authenticated')::text FROM public.lts_open_finance_connection c JOIN auth.users a ON a.id=c.user_id LIMIT 1),true);
CREATE TEMP TABLE v251_proofs(label text,lo date,hi date,input jsonb,expected jsonb,prior_ms numeric) ON COMMIT DROP;
DO $baseline$ DECLARE r record;j jsonb; t timestamptz;u uuid:=public.lts_browser_assert_user_v1();
BEGIN
 FOR r IN SELECT * FROM (VALUES('current_and_next',date '2026-01-01',date '2027-12-31'),('july_boundary',date '2026-06-30',date '2026-07-14'))v(label,lo,hi) LOOP
  j:=public.lts_browser_flow_pre_v248(r.lo,r.hi)->'flow';
  PERFORM public.lts_flow_workbook_positions_v248(u,j);
  t:=clock_timestamp();
  INSERT INTO v251_proofs SELECT r.label,r.lo,r.hi,j,public.lts_flow_workbook_positions_v248(u,j),extract(epoch from clock_timestamp()-t)*1000;
 END LOOP;
END $baseline$;
DO $lease$ BEGIN
 IF md5(btrim(pg_get_functiondef('public.lts_flow_workbook_positions_v248(uuid,jsonb)'::regprocedure),E' \t\r\n'))<>'3045d58010bdb36ff1af9ffe0e1a17e2'
 THEN RAISE EXCEPTION 'V251_WORKBOOK_SOURCE_LEASE_CHANGED';END IF;
END $lease$;
-- Derived date only. Full source epochs, owner and date remain isolated.
CREATE OR REPLACE FUNCTION public.lts_workbook_first_c6_date_v251(p_user_id uuid)
RETURNS date LANGUAGE plpgsql SET search_path TO '' SET "TimeZone" TO 'America/Sao_Paulo'
AS $fn$
DECLARE k text; d date; j jsonb; epoch_before bigint;
BEGIN
 SELECT epoch INTO epoch_before FROM public.lts_read_cache_epoch_v242 WHERE singleton;
 k:='workbook-first-c6-v251:'||epoch_before||':'||public.lts_flow_read_source_key_v247(p_user_id);
 SELECT payload INTO j FROM public.lts_v229_read_cache
 WHERE user_id=p_user_id AND kind='workbook_first_c6_v251' AND as_of=current_date
 AND from_date=date '2013-10-10' AND to_date=date '2026-07-07'
 AND source_fingerprint=k AND refreshed_at>clock_timestamp()-interval '5 minutes';
 IF FOUND THEN RETURN (j->>'date')::date; END IF;
 SELECT min(h.event_date) INTO d
 FROM public.lts_historical_effective_cash_pre_v246(p_user_id,date '2013-10-10',date '2026-07-07') h
 WHERE h.account='C6';
 IF epoch_before IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
 END IF;
 IF NOT current_setting('transaction_read_only')::boolean THEN
  BEGIN
   INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
   VALUES(p_user_id,'workbook_first_c6_v251',current_date,date '2013-10-10',date '2026-07-07',jsonb_build_object('date',d),k,clock_timestamp())
   ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET
    payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;
  EXCEPTION WHEN read_only_sql_transaction THEN NULL;
  END;
 END IF;
 RETURN d;
END $fn$;
REVOKE ALL ON FUNCTION public.lts_workbook_first_c6_date_v251(uuid) FROM PUBLIC,anon,authenticated,service_role;
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
 first_c6:=public.lts_workbook_first_c6_date_v251(p_user_id);
 WITH rows AS MATERIALIZED(SELECT * FROM public.lts_historical_effective_cash_v5(p_user_id,lo,hi)),
 day_totals AS MATERIALIZED(SELECT event_date,account,sum(signed_amount) total FROM rows GROUP BY event_date,account),
 proof AS(
 SELECT e.* FROM public.lts_reconciliation_evidence e
 WHERE e.user_id=p_user_id AND e.evidence_type='historical_workbook_cash_day' AND e.status='documented'
 AND e.evidence_date BETWEEN lo AND hi AND jsonb_array_length(e.metadata->'workbook_evidence')=2
 AND abs((e.metadata->>'source_closing')::numeric-(e.metadata->>'source_opening')::numeric-e.amount)<.005
 AND round(e.amount+coalesce((SELECT sum((z->>'delta')::numeric) FROM jsonb_array_elements(bank_deltas) z
 WHERE z->>'account'=e.account AND (z->>'event_date')::date=e.evidence_date),0),2)=round(coalesce((SELECT r.total FROM day_totals r WHERE r.event_date=e.evidence_date AND r.account=e.account),0),2)
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
   c:=c||jsonb_build_object(
 'saldo_apos_d0_1',CASE WHEN complete THEN total_close+(c->>'liq_d0_1_recurso')::numeric END,
 'liq_d0_1',CASE WHEN complete THEN total_close+(c->>'liq_d0_1_recurso')::numeric END,
 'posicao_antes_rsus',CASE WHEN complete THEN total_close+(c->>'liq_d0_1_recurso')::numeric END,
 'saldo_apos_rsu',CASE WHEN complete THEN total_close+(c->>'liq_d0_1_recurso')::numeric+(c->>'rsus_vested')::numeric END,
 'posicao_curto_prazo',CASE WHEN complete THEN total_close+(c->>'liq_d0_1_recurso')::numeric+(c->>'rsus_vested')::numeric END,
 'disponivel_total',CASE WHEN complete THEN total_close+(c->>'liq_d0_1_recurso')::numeric+(c->>'rsus_vested')::numeric END,
 'saldo_apos_fgts',CASE WHEN complete THEN total_close+(c->>'liq_d0_1_recurso')::numeric+(c->>'rsus_vested')::numeric+(c->>'fgts')::numeric END);
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
DO $verify$ DECLARE r record;j jsonb;t timestamptz;metrics jsonb:='[]';u uuid:=public.lts_browser_assert_user_v1();d date;n int;
BEGIN
 FOR r IN SELECT * FROM v251_proofs ORDER BY label LOOP
  PERFORM public.lts_flow_workbook_positions_v248(u,r.input);
  t:=clock_timestamp();j:=public.lts_flow_workbook_positions_v248(u,r.input);
  IF j IS DISTINCT FROM r.expected THEN RAISE EXCEPTION 'V251_FULL_JSON_PARITY_FAILED: %',r.label;END IF;
  metrics:=metrics||jsonb_build_array(jsonb_build_object('range',r.label,'prior_ms',r.prior_ms,'candidate_ms',extract(epoch from clock_timestamp()-t)*1000,'exact_json_equal',true,'digest',md5(j::text)));
  IF public.lts_flow_workbook_positions_v248(u,r.input) IS DISTINCT FROM j THEN RAISE EXCEPTION 'V251_REPEAT_CHANGED';END IF;
 END LOOP;
 SELECT min(h.event_date) INTO d FROM public.lts_historical_effective_cash_pre_v246(u,date '2013-10-10',date '2026-07-07')h WHERE h.account='C6';
 IF public.lts_workbook_first_c6_date_v251(u) IS DISTINCT FROM d THEN RAISE EXCEPTION 'V251_DATE_MISMATCH';END IF;
 IF has_function_privilege('anon','public.lts_workbook_first_c6_date_v251(uuid)','EXECUTE') OR has_function_privilege('authenticated','public.lts_workbook_first_c6_date_v251(uuid)','EXECUTE') OR has_function_privilege('service_role','public.lts_workbook_first_c6_date_v251(uuid)','EXECUTE') THEN RAISE EXCEPTION 'V251_PRIVATE_HELPER_EXPOSED';END IF;
 BEGIN
 PERFORM public.lts_workbook_first_c6_date_v251('00000000-0000-0000-0000-000000000000');
 RAISE EXCEPTION 'V251_INVALID_OWNER_WAS_ACCEPTED' USING ERRCODE='42501';
 EXCEPTION WHEN SQLSTATE 'P0001' THEN NULL;
END;
UPDATE public.lts_v229_read_cache SET refreshed_at=clock_timestamp()-interval '6 minutes'
WHERE user_id=u AND kind='workbook_first_c6_v251';
 SELECT count(*) INTO n FROM public.lts_v229_read_cache WHERE kind='workbook_first_c6_v251';
 PERFORM set_config('transaction_read_only','on',true);
 IF public.lts_workbook_first_c6_date_v251(u) IS DISTINCT FROM d THEN RAISE EXCEPTION 'V251_READ_ONLY_RESULT_CHANGED';END IF;
 IF n<>(SELECT count(*) FROM public.lts_v229_read_cache WHERE kind='workbook_first_c6_v251') THEN RAISE EXCEPTION 'V251_READ_ONLY_WROTE';END IF;
 PERFORM set_config('lts.v251_receipt',jsonb_build_object('status','PASS','full_output_parity',metrics,'memo_exact',true,'helper_acl_private',true,'no_owner_leak',true,'read_only_stale_miss_preserves_exact_date_without_write',true,'controlled_warm_comparison',true)::text,true);
END $verify$;
SELECT current_setting('lts.v251_receipt')::jsonb AS receipt;
ROLLBACK;