BEGIN; SET LOCAL TimeZone='America/Sao_Paulo';SET LOCAL jit=off;SET LOCAL statement_timeout='90s';
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
CREATE TEMP TABLE guard_input_v256(flow jsonb,today date) ON COMMIT DROP;
CREATE TEMP TABLE baseline_v256(full_response jsonb,ms numeric,guard_response jsonb,guard_ms numeric,acls jsonb) ON COMMIT DROP;
CREATE OR REPLACE FUNCTION public.lts_browser_flow_pre_v248(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb; f jsonb; lo date:=p_from;
 v record; d jsonb; prev jsonb; ev jsonb; part text; all_events jsonb; newdays jsonb; c jsonb;
 old_net numeric; actual_net numeric; opening numeric; closing numeric; inc numeric; outflow numeric; prior numeric; gap numeric;
 projected_rows_v243 jsonb[]; recovered jsonb:='[]'; today_row jsonb; bank_deltas jsonb:='{}'; bank_name text; bank_delta numeric; total_delta numeric:=0; projected_date date; cash_field text;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to THEN RAISE EXCEPTION 'invalid range';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_realized_bank_sources_v238(u) s WHERE s.event_date=p_from AND s.event_date<current_date) THEN lo:=p_from-1;END IF;
 IF p_to>=current_date THEN lo:=least(lo,current_date);END IF;
 result:=public.lts_browser_flow_pre_v238(lo,p_to);f:=result->'flow';
 all_events:=coalesce(f#>'{historical,events}','[]')||coalesce(f#>'{current_future,events}','[]');
 FOR v IN SELECT * FROM public.lts_realized_bank_sources_v238(u) WHERE event_date BETWEEN p_from AND p_to AND event_date<current_date ORDER BY event_date,financial_event_id LOOP
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(all_events) x WHERE x->>'source_ref' IN(v.staging_id::text,v.financial_event_id::text,v.legacy_id) OR x->>'open_finance_id'=v.staging_id::text) THEN CONTINUE;END IF;
  SELECT x INTO d FROM jsonb_array_elements(coalesce(f#>'{historical,days}','[]')) x WHERE (x->>'date')::date=v.event_date;
  SELECT x INTO prev FROM jsonb_array_elements(coalesce(f#>'{historical,days}','[]')) x WHERE (x->>'date')::date=v.event_date-1;
  IF d IS NULL OR prev IS NULL OR NOT coalesce((prev#>>ARRAY[v.bank,'balance_certified'])::boolean,false) THEN RAISE EXCEPTION 'verified posted debit requires its preceding documented position';END IF;
  old_net:=(d#>>ARRAY[v.bank,'net'])::numeric;prior:=(prev#>>ARRAY[v.bank,'balance'])::numeric;closing:=(d#>>ARRAY[v.bank,'balance'])::numeric;
  actual_net:=old_net+v.signed_amount;
  IF abs(prior+actual_net-closing)>.005 THEN RAISE EXCEPTION 'posted debit does not reconcile independent dated bank positions';END IF;
  d:=jsonb_set(d,ARRAY[v.bank],(d->v.bank)||jsonb_build_object('net',actual_net,'operational_net',actual_net,'opening_balance',prior,'reconciliation_gap',0,'movements_complete',true,'bank_posted_recovery',v.staging_id));
  opening:=coalesce((prev#>>'{Itaú,balance}')::numeric,0)+coalesce((prev#>>'{Bradesco,balance}')::numeric,0)+coalesce((prev#>>'{C6,balance}')::numeric,0);
  closing:=(d#>>'{Consolidado,bank_balance}')::numeric;
  inc:=coalesce((d#>>'{v170_cash_arithmetic,operating_entries_brl}')::numeric,(d#>>'{summary,entries}')::numeric,0)+greatest(v.signed_amount,0)+greatest(coalesce((d#>>'{v170_cash_arithmetic,internal_transfer_net_brl}')::numeric,0),0);
  outflow:=coalesce((d#>>'{v170_cash_arithmetic,operating_exits_brl}')::numeric,(d#>>'{summary,exits}')::numeric,0)-least(v.signed_amount,0)+greatest(-coalesce((d#>>'{v170_cash_arithmetic,internal_transfer_net_brl}')::numeric,0),0);
  gap:=closing-opening-inc+outflow;
  IF abs(gap)>.005 THEN RAISE EXCEPTION 'posted event does not reconcile consolidated cash';END IF;
  c:=d->'fix86_columns';c:=c||jsonb_build_object('saldo_anterior',opening,'saldo_anterior_operacional',opening,'entradas',inc,'saidas',outflow,'entradas_operacionais',inc,'saidas_operacionais',outflow);
  d:=d||jsonb_build_object('fix86_columns',c,'Consolidado',(d->'Consolidado')||jsonb_build_object('net',inc-outflow,'economic_net',inc-outflow),
   'summary',(d->'summary')||jsonb_build_object('entries',inc,'exits',outflow,'net',inc-outflow,'events',coalesce((d#>>'{summary,events}')::int,0)+1,'Consolidado',jsonb_build_object('entries',inc,'exits',outflow)),
   'v170_cash_arithmetic',(d->'v170_cash_arithmetic')||jsonb_build_object('balanced',true,'arithmetic_gap_brl',gap,'operating_entries_brl',inc,'operating_exits_brl',outflow,'tracked_bank_net_brl',inc-outflow),
   'bank_posted_recovery',jsonb_build_object('source','existing_financial_event_and_bank_posting','financial_event_id',v.financial_event_id,'staging_id',v.staging_id));
  SELECT coalesce(jsonb_agg(CASE WHEN (x->>'date')::date=v.event_date THEN d ELSE x END ORDER BY x->>'date'),'[]') INTO newdays FROM jsonb_array_elements(f#>'{historical,days}') x;
  f:=jsonb_set(f,'{historical,days}',newdays);
  ev:=jsonb_build_object('source','open_finance','source_ref',v.staging_id,'open_finance_id',v.staging_id,'financial_event_id',v.financial_event_id,'event_date',v.event_date,
   'account',v.bank,'description',v.description,'signed_amount',v.signed_amount,'direction',CASE WHEN v.signed_amount<0 THEN 'saida' ELSE 'entrada' END,
   'confidence','bank_posted','bank_confirmed',true,'category',v.category,'center_cost',v.beneficiary,'property_code',v.property_code,'internal_transfer',false,'excluded',false);
  all_events:=all_events||jsonb_build_array(ev);
  f:=jsonb_set(f,'{historical,events}',coalesce(f#>'{historical,events}','[]')||jsonb_build_array(ev));
  recovered:=recovered||jsonb_build_array(jsonb_build_object('financial_event_id',v.financial_event_id,'staging_id',v.staging_id,'date',v.event_date,'bank',v.bank,'amount',v.signed_amount));
 END LOOP;
 INSERT INTO guard_input_v256 VALUES(f,current_date);
 f:=public.lts_flow_observed_position_guard_v1(f,current_date);
 -- Future balances continue the operational closing of today. The observed
 -- bank snapshot remains a separate fact and is never changed by this reader.
 SELECT x INTO today_row FROM jsonb_array_elements(coalesce(f#>'{current_future,days}','[]')) x WHERE (x->>'date')::date=current_date;
 IF today_row IS NOT NULL THEN
  FOREACH bank_name IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
   bank_delta:=coalesce((today_row#>>ARRAY[bank_name,'balance'])::numeric-(today_row#>>ARRAY[bank_name,'observed_balance'])::numeric,0);
   bank_deltas:=bank_deltas||jsonb_build_object(bank_name,bank_delta);total_delta:=total_delta+bank_delta;
  END LOOP;
  IF EXISTS(SELECT 1 FROM jsonb_each_text(bank_deltas) x WHERE abs(x.value::numeric)>.005) OR f->'cash_position_guard' IS NOT NULL THEN
   newdays:='[]';projected_rows_v243:=ARRAY[]::jsonb[];
   FOR d IN SELECT x FROM jsonb_array_elements(coalesce(f#>'{current_future,days}','[]')) x ORDER BY x->>'date' LOOP
    projected_date:=(d->>'date')::date;
    IF projected_date>current_date THEN
     FOREACH bank_name IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
      bank_delta:=(bank_deltas->>bank_name)::numeric;
      d:=jsonb_set(d,ARRAY[bank_name],(d->bank_name)||jsonb_build_object('balance',(d#>>ARRAY[bank_name,'balance'])::numeric+bank_delta,
       'opening_balance',coalesce((d#>>ARRAY[bank_name,'opening_balance'])::numeric,(d#>>ARRAY[bank_name,'balance'])::numeric-(d#>>ARRAY[bank_name,'net'])::numeric)+bank_delta,
       'balance_basis','projection_from_operational_closing','balance_certified',false));
     END LOOP;
     c:=d->'fix86_columns';
     FOREACH cash_field IN ARRAY ARRAY['saldo_anterior','saldo_anterior_operacional','saldo_final','saldo_final_operacional','saldo_apos_d0_1','liq_d0_1','posicao_antes_rsus','saldo_apos_rsu','disponivel_total','posicao_curto_prazo','saldo_apos_fgts','liq_d30','posicao_economica_total'] LOOP
      IF c->>cash_field IS NOT NULL THEN c:=jsonb_set(c,ARRAY[cash_field],to_jsonb((c->>cash_field)::numeric+total_delta));END IF;
     END LOOP;
     c:=c||jsonb_build_object('cash_projection_basis','current_operational_closing_plus_future_source_movements');
     gap:=(c->>'saldo_final')::numeric-(c->>'saldo_anterior')::numeric-coalesce((c->>'entradas')::numeric,0)+coalesce((c->>'saidas')::numeric,0);
     IF abs(gap)>.005 THEN RAISE EXCEPTION 'future source arithmetic is incomplete';END IF;
     FOREACH bank_name IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
      IF abs((prev#>>ARRAY[bank_name,'balance'])::numeric+coalesce((d#>>ARRAY[bank_name,'net'])::numeric,0)-(d#>>ARRAY[bank_name,'balance'])::numeric)>.005 THEN RAISE EXCEPTION 'future bank closing does not carry its prior source position';END IF;
     END LOOP;
     d:=d||jsonb_build_object('fix86_columns',c,'Consolidado',(d->'Consolidado')||jsonb_build_object('bank_balance',(c->>'saldo_final')::numeric,'balance_certified',false),
      'v170_cash_arithmetic',coalesce(d->'v170_cash_arithmetic','{}')||jsonb_build_object('balanced',true,'arithmetic_gap_brl',gap,'version','operational-projection-carry-v238'));
    END IF;
    prev:=d;projected_rows_v243:=array_append(projected_rows_v243,d);
   END LOOP;
   newdays:=to_jsonb(projected_rows_v243);
   f:=jsonb_set(f,'{current_future,days}',newdays);
   f:=f||jsonb_build_object('projected_operational_anchor',jsonb_build_object('as_of',current_date,'per_bank_difference_from_observed',bank_deltas,
    'observed_bank_cash',(today_row#>>'{Itaú,observed_balance}')::numeric+(today_row#>>'{Bradesco,observed_balance}')::numeric+(today_row#>>'{C6,observed_balance}')::numeric,
    'calculated_day_closing',(today_row#>>'{fix86_columns,saldo_final}')::numeric,'basis','Today commitments remain in future cash; observed balances are separate facts.'));
  END IF;
 END IF;
 FOREACH part IN ARRAY ARRAY['historical','current_future'] LOOP
  f:=jsonb_set(f,ARRAY[part,'days'],coalesce((SELECT jsonb_agg(x ORDER BY x->>'date') FROM jsonb_array_elements(coalesce(f#>ARRAY[part,'days'],'[]')) x WHERE (x->>'date')::date BETWEEN p_from AND p_to),'[]'));
  f:=jsonb_set(f,ARRAY[part,'events'],coalesce((SELECT jsonb_agg(x ORDER BY x->>'event_date',x->>'source_ref') FROM jsonb_array_elements(coalesce(f#>ARRAY[part,'events'],'[]')) x WHERE (x->>'event_date')::date BETWEEN p_from AND p_to),'[]'));
 END LOOP;
 f:=f||jsonb_build_object('from',p_from,'to',p_to,'realized_bank_recovery',jsonb_build_object('version','v238','events',recovered,'guardrail','Existing bank-posted source identity and independent adjacent bank positions are required. No position or amount is fabricated.'));
 SELECT jsonb_build_object('version','tracked-bank-cash-audit-v238','first_day',min(x->>'date'),'last_day',max(x->>'date'),'day_count',count(*),'balanced_days',count(*) FILTER(WHERE coalesce((x#>>'{v170_cash_arithmetic,balanced}')::boolean,false)),'mismatch_days',count(*) FILTER(WHERE NOT coalesce((x#>>'{v170_cash_arithmetic,balanced}')::boolean,false)),'max_abs_gap_brl',coalesce(max(abs((x#>>'{v170_cash_arithmetic,arithmetic_gap_brl}')::numeric)),0),'verified_bank_recoveries',jsonb_array_length(recovered)) INTO c FROM jsonb_array_elements(coalesce(f#>'{historical,days}','[]')) x;
 f:=f||jsonb_build_object('historical_cash_arithmetic_audit',c);
 RETURN result||jsonb_build_object('flow',f,'reader_revision','v238-realized-source-and-immutable-bank-positions');
END
$function$
;
DO $before$ DECLARE t timestamptz:=clock_timestamp();j jsonb;g jsonb;ms numeric;gs numeric;
BEGIN
 j:=public.lts_browser_flow_v242('2026-01-01','2027-12-31');ms:=round(extract(epoch from clock_timestamp()-t)*1000,3);
 t:=clock_timestamp();SELECT public.lts_flow_observed_position_guard_v1(flow,today) INTO g FROM guard_input_v256 LIMIT 1;gs:=round(extract(epoch from clock_timestamp()-t)*1000,3);
 INSERT INTO baseline_v256 SELECT j,ms,g,gs,(SELECT jsonb_object_agg(proname,proacl::text) FROM pg_proc WHERE oid IN ('public.lts_flow_observed_position_guard_v1(jsonb,date)'::regprocedure,'public.lts_browser_flow_pre_v238(date,date)'::regprocedure));
END $before$;
CREATE OR REPLACE FUNCTION public.lts_browser_flow_pre_v248(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb; f jsonb; lo date:=p_from;
 v record; d jsonb; prev jsonb; ev jsonb; part text; all_events jsonb; newdays jsonb; c jsonb;
 old_net numeric; actual_net numeric; opening numeric; closing numeric; inc numeric; outflow numeric; prior numeric; gap numeric;
 projected_rows_v243 jsonb[]; recovered jsonb:='[]'; today_row jsonb; bank_deltas jsonb:='{}'; bank_name text; bank_delta numeric; total_delta numeric:=0; projected_date date; cash_field text;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to THEN RAISE EXCEPTION 'invalid range';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_realized_bank_sources_v238(u) s WHERE s.event_date=p_from AND s.event_date<current_date) THEN lo:=p_from-1;END IF;
 IF p_to>=current_date THEN lo:=least(lo,current_date);END IF;
 result:=public.lts_browser_flow_pre_v238(lo,p_to);f:=result->'flow';
 all_events:=coalesce(f#>'{historical,events}','[]')||coalesce(f#>'{current_future,events}','[]');
 FOR v IN SELECT * FROM public.lts_realized_bank_sources_v238(u) WHERE event_date BETWEEN p_from AND p_to AND event_date<current_date ORDER BY event_date,financial_event_id LOOP
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(all_events) x WHERE x->>'source_ref' IN(v.staging_id::text,v.financial_event_id::text,v.legacy_id) OR x->>'open_finance_id'=v.staging_id::text) THEN CONTINUE;END IF;
  SELECT x INTO d FROM jsonb_array_elements(coalesce(f#>'{historical,days}','[]')) x WHERE (x->>'date')::date=v.event_date;
  SELECT x INTO prev FROM jsonb_array_elements(coalesce(f#>'{historical,days}','[]')) x WHERE (x->>'date')::date=v.event_date-1;
  IF d IS NULL OR prev IS NULL OR NOT coalesce((prev#>>ARRAY[v.bank,'balance_certified'])::boolean,false) THEN RAISE EXCEPTION 'verified posted debit requires its preceding documented position';END IF;
  old_net:=(d#>>ARRAY[v.bank,'net'])::numeric;prior:=(prev#>>ARRAY[v.bank,'balance'])::numeric;closing:=(d#>>ARRAY[v.bank,'balance'])::numeric;
  actual_net:=old_net+v.signed_amount;
  IF abs(prior+actual_net-closing)>.005 THEN RAISE EXCEPTION 'posted debit does not reconcile independent dated bank positions';END IF;
  d:=jsonb_set(d,ARRAY[v.bank],(d->v.bank)||jsonb_build_object('net',actual_net,'operational_net',actual_net,'opening_balance',prior,'reconciliation_gap',0,'movements_complete',true,'bank_posted_recovery',v.staging_id));
  opening:=coalesce((prev#>>'{Itaú,balance}')::numeric,0)+coalesce((prev#>>'{Bradesco,balance}')::numeric,0)+coalesce((prev#>>'{C6,balance}')::numeric,0);
  closing:=(d#>>'{Consolidado,bank_balance}')::numeric;
  inc:=coalesce((d#>>'{v170_cash_arithmetic,operating_entries_brl}')::numeric,(d#>>'{summary,entries}')::numeric,0)+greatest(v.signed_amount,0)+greatest(coalesce((d#>>'{v170_cash_arithmetic,internal_transfer_net_brl}')::numeric,0),0);
  outflow:=coalesce((d#>>'{v170_cash_arithmetic,operating_exits_brl}')::numeric,(d#>>'{summary,exits}')::numeric,0)-least(v.signed_amount,0)+greatest(-coalesce((d#>>'{v170_cash_arithmetic,internal_transfer_net_brl}')::numeric,0),0);
  gap:=closing-opening-inc+outflow;
  IF abs(gap)>.005 THEN RAISE EXCEPTION 'posted event does not reconcile consolidated cash';END IF;
  c:=d->'fix86_columns';c:=c||jsonb_build_object('saldo_anterior',opening,'saldo_anterior_operacional',opening,'entradas',inc,'saidas',outflow,'entradas_operacionais',inc,'saidas_operacionais',outflow);
  d:=d||jsonb_build_object('fix86_columns',c,'Consolidado',(d->'Consolidado')||jsonb_build_object('net',inc-outflow,'economic_net',inc-outflow),
   'summary',(d->'summary')||jsonb_build_object('entries',inc,'exits',outflow,'net',inc-outflow,'events',coalesce((d#>>'{summary,events}')::int,0)+1,'Consolidado',jsonb_build_object('entries',inc,'exits',outflow)),
   'v170_cash_arithmetic',(d->'v170_cash_arithmetic')||jsonb_build_object('balanced',true,'arithmetic_gap_brl',gap,'operating_entries_brl',inc,'operating_exits_brl',outflow,'tracked_bank_net_brl',inc-outflow),
   'bank_posted_recovery',jsonb_build_object('source','existing_financial_event_and_bank_posting','financial_event_id',v.financial_event_id,'staging_id',v.staging_id));
  SELECT coalesce(jsonb_agg(CASE WHEN (x->>'date')::date=v.event_date THEN d ELSE x END ORDER BY x->>'date'),'[]') INTO newdays FROM jsonb_array_elements(f#>'{historical,days}') x;
  f:=jsonb_set(f,'{historical,days}',newdays);
  ev:=jsonb_build_object('source','open_finance','source_ref',v.staging_id,'open_finance_id',v.staging_id,'financial_event_id',v.financial_event_id,'event_date',v.event_date,
   'account',v.bank,'description',v.description,'signed_amount',v.signed_amount,'direction',CASE WHEN v.signed_amount<0 THEN 'saida' ELSE 'entrada' END,
   'confidence','bank_posted','bank_confirmed',true,'category',v.category,'center_cost',v.beneficiary,'property_code',v.property_code,'internal_transfer',false,'excluded',false);
  all_events:=all_events||jsonb_build_array(ev);
  f:=jsonb_set(f,'{historical,events}',coalesce(f#>'{historical,events}','[]')||jsonb_build_array(ev));
  recovered:=recovered||jsonb_build_array(jsonb_build_object('financial_event_id',v.financial_event_id,'staging_id',v.staging_id,'date',v.event_date,'bank',v.bank,'amount',v.signed_amount));
 END LOOP;
 f:=public.lts_flow_observed_position_guard_v1(f,current_date);
 -- Future balances continue the operational closing of today. The observed
 -- bank snapshot remains a separate fact and is never changed by this reader.
 SELECT x INTO today_row FROM jsonb_array_elements(coalesce(f#>'{current_future,days}','[]')) x WHERE (x->>'date')::date=current_date;
 IF today_row IS NOT NULL THEN
  FOREACH bank_name IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
   bank_delta:=coalesce((today_row#>>ARRAY[bank_name,'balance'])::numeric-(today_row#>>ARRAY[bank_name,'observed_balance'])::numeric,0);
   bank_deltas:=bank_deltas||jsonb_build_object(bank_name,bank_delta);total_delta:=total_delta+bank_delta;
  END LOOP;
  IF EXISTS(SELECT 1 FROM jsonb_each_text(bank_deltas) x WHERE abs(x.value::numeric)>.005) OR f->'cash_position_guard' IS NOT NULL THEN
   newdays:='[]';projected_rows_v243:=ARRAY[]::jsonb[];
   FOR d IN SELECT x FROM jsonb_array_elements(coalesce(f#>'{current_future,days}','[]')) x ORDER BY x->>'date' LOOP
    projected_date:=(d->>'date')::date;
    IF projected_date>current_date THEN
     FOREACH bank_name IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
      bank_delta:=(bank_deltas->>bank_name)::numeric;
      d:=jsonb_set(d,ARRAY[bank_name],(d->bank_name)||jsonb_build_object('balance',(d#>>ARRAY[bank_name,'balance'])::numeric+bank_delta,
       'opening_balance',coalesce((d#>>ARRAY[bank_name,'opening_balance'])::numeric,(d#>>ARRAY[bank_name,'balance'])::numeric-(d#>>ARRAY[bank_name,'net'])::numeric)+bank_delta,
       'balance_basis','projection_from_operational_closing','balance_certified',false));
     END LOOP;
     c:=d->'fix86_columns';
     FOREACH cash_field IN ARRAY ARRAY['saldo_anterior','saldo_anterior_operacional','saldo_final','saldo_final_operacional','saldo_apos_d0_1','liq_d0_1','posicao_antes_rsus','saldo_apos_rsu','disponivel_total','posicao_curto_prazo','saldo_apos_fgts','liq_d30','posicao_economica_total'] LOOP
      IF c->>cash_field IS NOT NULL THEN c:=jsonb_set(c,ARRAY[cash_field],to_jsonb((c->>cash_field)::numeric+total_delta));END IF;
     END LOOP;
     c:=c||jsonb_build_object('cash_projection_basis','current_operational_closing_plus_future_source_movements');
     gap:=(c->>'saldo_final')::numeric-(c->>'saldo_anterior')::numeric-coalesce((c->>'entradas')::numeric,0)+coalesce((c->>'saidas')::numeric,0);
     IF abs(gap)>.005 THEN RAISE EXCEPTION 'future source arithmetic is incomplete';END IF;
     FOREACH bank_name IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
      IF abs((prev#>>ARRAY[bank_name,'balance'])::numeric+coalesce((d#>>ARRAY[bank_name,'net'])::numeric,0)-(d#>>ARRAY[bank_name,'balance'])::numeric)>.005 THEN RAISE EXCEPTION 'future bank closing does not carry its prior source position';END IF;
     END LOOP;
     d:=d||jsonb_build_object('fix86_columns',c,'Consolidado',(d->'Consolidado')||jsonb_build_object('bank_balance',(c->>'saldo_final')::numeric,'balance_certified',false),
      'v170_cash_arithmetic',coalesce(d->'v170_cash_arithmetic','{}')||jsonb_build_object('balanced',true,'arithmetic_gap_brl',gap,'version','operational-projection-carry-v238'));
    END IF;
    prev:=d;projected_rows_v243:=array_append(projected_rows_v243,d);
   END LOOP;
   newdays:=to_jsonb(projected_rows_v243);
   f:=jsonb_set(f,'{current_future,days}',newdays);
   f:=f||jsonb_build_object('projected_operational_anchor',jsonb_build_object('as_of',current_date,'per_bank_difference_from_observed',bank_deltas,
    'observed_bank_cash',(today_row#>>'{Itaú,observed_balance}')::numeric+(today_row#>>'{Bradesco,observed_balance}')::numeric+(today_row#>>'{C6,observed_balance}')::numeric,
    'calculated_day_closing',(today_row#>>'{fix86_columns,saldo_final}')::numeric,'basis','Today commitments remain in future cash; observed balances are separate facts.'));
  END IF;
 END IF;
 FOREACH part IN ARRAY ARRAY['historical','current_future'] LOOP
  f:=jsonb_set(f,ARRAY[part,'days'],coalesce((SELECT jsonb_agg(x ORDER BY x->>'date') FROM jsonb_array_elements(coalesce(f#>ARRAY[part,'days'],'[]')) x WHERE (x->>'date')::date BETWEEN p_from AND p_to),'[]'));
  f:=jsonb_set(f,ARRAY[part,'events'],coalesce((SELECT jsonb_agg(x ORDER BY x->>'event_date',x->>'source_ref') FROM jsonb_array_elements(coalesce(f#>ARRAY[part,'events'],'[]')) x WHERE (x->>'event_date')::date BETWEEN p_from AND p_to),'[]'));
 END LOOP;
 f:=f||jsonb_build_object('from',p_from,'to',p_to,'realized_bank_recovery',jsonb_build_object('version','v238','events',recovered,'guardrail','Existing bank-posted source identity and independent adjacent bank positions are required. No position or amount is fabricated.'));
 SELECT jsonb_build_object('version','tracked-bank-cash-audit-v238','first_day',min(x->>'date'),'last_day',max(x->>'date'),'day_count',count(*),'balanced_days',count(*) FILTER(WHERE coalesce((x#>>'{v170_cash_arithmetic,balanced}')::boolean,false)),'mismatch_days',count(*) FILTER(WHERE NOT coalesce((x#>>'{v170_cash_arithmetic,balanced}')::boolean,false)),'max_abs_gap_brl',coalesce(max(abs((x#>>'{v170_cash_arithmetic,arithmetic_gap_brl}')::numeric)),0),'verified_bank_recoveries',jsonb_array_length(recovered)) INTO c FROM jsonb_array_elements(coalesce(f#>'{historical,days}','[]')) x;
 f:=f||jsonb_build_object('historical_cash_arithmetic_audit',c);
 RETURN result||jsonb_build_object('flow',f,'reader_revision','v238-realized-source-and-immutable-bank-positions');
END
$function$
;
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

UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;
DO $after$ DECLARE t timestamptz:=clock_timestamp();j jsonb;g jsonb;ms numeric;gs numeric;ds jsonb;
BEGIN
 SELECT public.lts_flow_observed_position_guard_v1(flow,today) INTO g FROM guard_input_v256 LIMIT 1;gs:=round(extract(epoch from clock_timestamp()-t)*1000,3);
 IF g::text IS DISTINCT FROM (SELECT guard_response::text FROM baseline_v256) THEN RAISE EXCEPTION 'V256_GUARD_CHANGED';END IF;
 t:=clock_timestamp();j:=public.lts_browser_flow_v242('2026-01-01','2027-12-31');ms:=round(extract(epoch from clock_timestamp()-t)*1000,3);
 IF j::text IS DISTINCT FROM (SELECT full_response::text FROM baseline_v256) THEN RAISE EXCEPTION 'V256_FULL_RESPONSE_CHANGED';END IF;
 IF (SELECT acls FROM baseline_v256) IS DISTINCT FROM (SELECT jsonb_object_agg(proname,proacl::text) FROM pg_proc WHERE oid IN ('public.lts_flow_observed_position_guard_v1(jsonb,date)'::regprocedure,'public.lts_browser_flow_pre_v238(date,date)'::regprocedure)) THEN RAISE EXCEPTION 'V256_ACL_CHANGED';END IF;
 ds:=coalesce(j#>'{flow,historical,days}','[]')||coalesce(j#>'{flow,current_future,days}','[]');
 PERFORM set_config('lts.v256_first_result',jsonb_build_object('status','PASS','full_before_ms',(SELECT b.ms FROM baseline_v256 b),'full_after_ms',ms,'guard_before_ms',(SELECT guard_ms FROM baseline_v256),'guard_after_ms',gs,'days',jsonb_array_length(ds),'guard_exact',true,'full_text_exact',true,'digest',md5(j::text),'acl_exact',true,'ui_authenticated',false)::text,true);
END $after$;
SELECT current_setting('lts.v256_first_result')::jsonb receipt;
ROLLBACK;