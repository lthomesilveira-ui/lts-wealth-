-- A read-only view of the existing canonical cash and expense readers.
-- No source, financial event, payment, forecast or category is changed.
CREATE SCHEMA IF NOT EXISTS lts_month_private_v393;
REVOKE ALL ON SCHEMA lts_month_private_v393 FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA lts_month_private_v393 TO service_role;

CREATE OR REPLACE FUNCTION lts_month_private_v393.cash_metrics(p_rows jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path='' AS $fn$
 SELECT jsonb_build_object(
  'entries',round(coalesce(sum(greatest((x->>'signed_amount')::numeric,0)),0),2),
  'payments',round(coalesce(-sum(least((x->>'signed_amount')::numeric,0)),0),2),
  'result',round(coalesce(sum((x->>'signed_amount')::numeric),0),2),'count',count(*))
 FROM jsonb_array_elements(p_rows)x;
$fn$;

CREATE OR REPLACE FUNCTION lts_month_private_v393.projected_items(p_cycles jsonb,p_from date,p_to date)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $fn$
 SELECT coalesce(jsonb_agg(i||jsonb_build_object(
  'row_key','projected_card:'||(ca->>'family')||':'||(i->>'source_id')||':'||(cy->>'month')||':'||coalesce(i->>'installment_number','0'),
  'event_date',cy->>'month','competence_month',cy->>'month','transaction_date',i->>'posting_date',
  'account_source',ca->>'name','family',ca->>'family','source_table','projected_card_installment',
  'source_ref',i->>'source_id','coverage_mode','card_installment_projected','due_date',cy->>'due_date',
  'institution_code',CASE i->>'bank' WHEN 'Itaú' THEN '341' WHEN 'Bradesco' THEN '237' WHEN 'C6' THEN '336' END,
  'raw_reference','Parcela '||coalesce(i->>'installment_number','?')||'/'||coalesce(i->>'total_installments','?'))
 ORDER BY ca->>'family',cy->>'month',i->>'source_id',i->>'installment_number'),'[]')
 FROM jsonb_array_elements(p_cycles->'cards')ca CROSS JOIN LATERAL jsonb_array_elements(ca->'cycles')cy
 CROSS JOIN LATERAL jsonb_array_elements(cy->'items')i
 WHERE (cy->>'month')::date BETWEEN date_trunc('month',p_from)::date AND date_trunc('month',p_to)::date
 AND i->>'provider_status'='PROJECTED' AND NOT coalesce((i->>'is_payment')::boolean,false);
$fn$;

CREATE OR REPLACE FUNCTION lts_month_private_v393.build(
 p_flow jsonb,p_expenses jsonb,p_from date,p_to date,p_as_of date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $fn$
DECLARE raw jsonb; events jsonb; cash jsonb:='[]'; exclusions jsonb:='[]'; e jsonb; state text;
 actual jsonb; forecast jsonb; pending jsonb; book jsonb; monthly jsonb; amount numeric; dt date;
 undated jsonb:=coalesce(p_flow->'month_undated_card_invoices_v393','[]');
 projected jsonb:=coalesce(p_flow->'month_projected_card_expenses_v393','[]');all_expenses jsonb;
 book_from date:=greatest(date '2013-10-10',date_trunc('month',p_from)::date);
 book_to date:=(date_trunc('month',p_to)+interval '1 month'-interval '1 day')::date;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_as_of IS NULL OR p_from>p_to OR p_to-p_from>12000
 OR p_from<date '2013-10-10' OR p_to>make_date(extract(year from p_as_of)::int+5,12,31)
 OR jsonb_typeof(p_flow#>'{flow,historical,events}') IS DISTINCT FROM 'array'
 OR jsonb_typeof(p_flow#>'{flow,current_future,events}') IS DISTINCT FROM 'array'
 OR jsonb_typeof(p_expenses) IS DISTINCT FROM 'array' OR jsonb_typeof(undated) IS DISTINCT FROM 'array' OR jsonb_typeof(projected) IS DISTINCT FROM 'array'
 OR p_flow#>>'{flow,from}' IS DISTINCT FROM p_from::text
 OR p_flow#>>'{flow,to}' IS DISTINCT FROM p_to::text
 THEN RAISE EXCEPTION 'Invalid monthly overview scope or source';END IF;
 raw:=(p_flow#>'{flow,historical,events}')||(p_flow#>'{flow,current_future,events}')
  ||coalesce(p_flow#>'{flow,observed_bank_movements,pending_projections}','[]');
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(raw)x WHERE
  (x->>'event_date')::date BETWEEN p_from AND p_to AND
  (nullif(x->>'source','') IS NULL OR nullif(x->>'source_ref','') IS NULL
   OR nullif(x->>'signed_amount','') IS NULL)) THEN RAISE EXCEPTION 'Incomplete monthly cash event';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(raw)x WHERE (x->>'event_date')::date BETWEEN p_from AND p_to
  GROUP BY x->>'source',x->>'source_ref',x->>'account',x->>'event_date' HAVING count(DISTINCT x)>1)
 THEN RAISE EXCEPTION 'Conflicting canonical cash identity';END IF;
 SELECT coalesce(jsonb_agg(x ORDER BY x->>'event_date',x->>'account',x->>'source',x->>'source_ref'),'[]') INTO events
 FROM(SELECT DISTINCT x FROM jsonb_array_elements(raw)x WHERE (x->>'event_date')::date BETWEEN p_from AND p_to) q;
 FOR e IN SELECT x FROM jsonb_array_elements(events)x LOOP
  dt:=(e->>'event_date')::date;amount:=(e->>'signed_amount')::numeric;
  IF amount=0 OR coalesce((e->>'internal_transfer')::boolean,false) OR e->>'source'='internal_transfer'
   OR coalesce((e->>'is_asset_movement')::boolean,false) OR coalesce((e->>'asset_movement')::boolean,false)
   OR coalesce((e->>'non_cash_marker')::boolean,false) OR coalesce((e->>'available_from_vesting')::boolean,false)
   OR e->>'account' IN('Corretora','FGTS','Cofrinho Itaú') THEN
   exclusions:=exclusions||jsonb_build_array(e||jsonb_build_object('exclusion_reason',
    CASE WHEN coalesce((e->>'internal_transfer')::boolean,false) OR e->>'source'='internal_transfer'
    THEN 'own_transfer' ELSE 'asset_or_non_cash' END));CONTINUE;
  END IF;
  IF NOT coalesce(e->>'account' IN('Itaú','Bradesco','C6'),false) OR e->>'account_assignment' IN('pending','unassigned')
  THEN RAISE EXCEPTION 'Unassigned monthly cash account';END IF;
  state:=CASE
   WHEN dt>p_as_of THEN 'forecast'
   WHEN coalesce((e->>'bank_confirmed')::boolean,false) OR coalesce((e->>'realization_confirmed')::boolean,false)
    OR e->>'confidence' IN('bank_posted','bank_confirmed','documented_paid') THEN 'realized'
   WHEN coalesce((e->>'is_projection')::boolean,false) OR coalesce((e->>'unposted_current_projection')::boolean,false)
    OR coalesce((e->>'unposted_past_projection')::boolean,false)
    OR lower(coalesce(e->>'status','')) IN('scheduled','expected','pending','open','projected')
    OR e->>'confidence' IN('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot','documented_closed','bank_scheduled_owner_confirmed_v293') THEN 'unconfirmed'
   WHEN dt<=date '2026-07-07' AND e->>'source' IN('historical_workbook_cash','historico_analitico','legacy_fix86') THEN 'realized'
   ELSE 'unconfirmed' END;
  cash:=cash||jsonb_build_array(e||jsonb_build_object('cash_state',state,'movement_kind',CASE WHEN amount>0 THEN 'entry' ELSE 'payment' END));
 END LOOP;
 all_expenses:=p_expenses||projected;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(projected)x JOIN jsonb_array_elements(p_expenses)y
  ON x->>'source_ref'=y->>'source_ref' AND x->>'competence_month'=y->>'competence_month')
 THEN RAISE EXCEPTION 'Received and projected expense identity overlaps';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(all_expenses)x WHERE nullif(x->>'row_key','') IS NULL
  OR nullif(x->>'amount','') IS NULL OR (x->>'event_date')::date NOT BETWEEN book_from AND book_to
  OR (x->>'competence_month')::date<>date_trunc('month',(x->>'event_date')::date)::date)
 OR (SELECT count(*) FROM jsonb_array_elements(all_expenses))<>(SELECT count(DISTINCT x->>'row_key') FROM jsonb_array_elements(all_expenses)x)
 THEN RAISE EXCEPTION 'Invalid or duplicated canonical expense identity';END IF;
 SELECT coalesce(jsonb_agg(x),'[]') INTO actual FROM jsonb_array_elements(cash)x WHERE x->>'cash_state'='realized';
 SELECT coalesce(jsonb_agg(x),'[]') INTO forecast FROM jsonb_array_elements(cash)x WHERE x->>'cash_state'='forecast';
 SELECT coalesce(jsonb_agg(x),'[]') INTO pending FROM jsonb_array_elements(cash)x WHERE x->>'cash_state'='unconfirmed';
 SELECT jsonb_build_object('from',book_from,'to',book_to,'total',round(coalesce(sum((x->>'amount')::numeric),0),2),
  'count',count(*),'items',all_expenses,'basis','competence_month','payment_proven',false,
  'received_total',(SELECT round(coalesce(sum((r->>'amount')::numeric),0),2) FROM jsonb_array_elements(p_expenses)r),
  'projected_total',(SELECT round(coalesce(sum((r->>'amount')::numeric),0),2) FROM jsonb_array_elements(projected)r)) INTO book FROM jsonb_array_elements(all_expenses)x;
 SELECT coalesce(jsonb_agg(jsonb_build_object('month',m::date,
  'cash',lts_month_private_v393.cash_metrics(coalesce((SELECT jsonb_agg(x) FROM jsonb_array_elements(cash)x WHERE date_trunc('month',(x->>'event_date')::date)=m),'[]')),
  'competence',round(coalesce((SELECT sum((x->>'amount')::numeric) FROM jsonb_array_elements(all_expenses)x WHERE (x->>'competence_month')::date=m),0),2)) ORDER BY m),'[]') INTO monthly
 FROM generate_series(date_trunc('month',p_from),date_trunc('month',p_to),interval '1 month') m;
 RETURN jsonb_build_object('version','month-overview-v393','from',p_from,'to',p_to,'as_of',p_as_of,
  'complete',p_flow->>'complete' IS DISTINCT FROM 'false' AND p_flow#>>'{flow,current_future,complete}' IS DISTINCT FROM 'false',
  'cash_complete',p_flow->>'complete' IS DISTINCT FROM 'false' AND p_flow#>>'{flow,current_future,complete}' IS DISTINCT FROM 'false' AND jsonb_array_length(undated)=0,
  'cash',jsonb_build_object('realized',lts_month_private_v393.cash_metrics(actual),'forecast',lts_month_private_v393.cash_metrics(forecast),
    'unconfirmed',lts_month_private_v393.cash_metrics(pending),'total',lts_month_private_v393.cash_metrics(cash),'items',cash,'excluded',exclusions,'undated',undated),
  'competence',book,'months',monthly,'guardrails',jsonb_build_object('own_transfers_excluded',true,'asset_availability_not_income',true,
    'invoice_payments_cash_only',true,'purchases_competence_only',true,'scheduled_not_realized',true,'known_sources_only',true));
END $fn$;

CREATE OR REPLACE FUNCTION public.lts_browser_month_overview_v393(p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' SET statement_timeout='45s' AS $fn$
DECLARE u uuid:=public.lts_browser_assert_user_v1();revision text;epoch bigint;f jsonb;e jsonb;j jsonb;undated jsonb;cycles jsonb;projected jsonb;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<date '2013-10-10' OR p_to-p_from>12000
 OR p_to>make_date(extract(year from current_date)::int+5,12,31) THEN RAISE EXCEPTION 'Invalid monthly range';END IF;
 revision:=public.lts_card_read_start_v269(u);
 SELECT x.epoch INTO epoch FROM public.lts_read_cache_epoch_v242 x WHERE singleton;
 f:=public.lts_browser_flow_v242(p_from,p_to);
 cycles:=public.lts_prepared_card_cycles_v307(u);
 SELECT coalesce(jsonb_agg(jsonb_build_object('family',ca->>'family','card_name',ca->>'name','month',cy->>'month',
  'amount',cy->'amount','due_date',null) ORDER BY ca->>'family',cy->>'month'),'[]') INTO undated
 FROM jsonb_array_elements(cycles->'cards') ca
 CROSS JOIN LATERAL jsonb_array_elements(ca->'cycles')cy
 WHERE nullif(cy->>'due_date','') IS NULL AND (nullif(cy->>'amount','') IS NULL OR (cy->>'amount')::numeric<>0)
 AND (cy->>'month')::date BETWEEN date_trunc('month',p_from)::date AND date_trunc('month',p_to)::date
 AND coalesce(cy->>'payment_status','') NOT IN('paid','settled');
 projected:=lts_month_private_v393.projected_items(cycles,p_from,p_to);
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(cycles->'cards')ca CROSS JOIN LATERAL jsonb_array_elements(ca->'cycles')cy
  WHERE (cy->>'month')::date BETWEEN date_trunc('month',p_from)::date AND date_trunc('month',p_to)::date
  AND abs(coalesce((cy->>'projected_amount')::numeric,0)-coalesce((SELECT sum((i->>'amount')::numeric)
   FROM jsonb_array_elements(projected)i WHERE i->>'family'=ca->>'family' AND i->>'competence_month'=cy->>'month'),0))>.005)
 THEN RAISE EXCEPTION 'Projected card rows do not reconcile to canonical cycles';END IF;
 f:=f||jsonb_build_object('month_undated_card_invoices_v393',undated,'month_projected_card_expenses_v393',projected);
 SELECT coalesce(jsonb_agg(to_jsonb(r)||jsonb_build_object('institution_code',s.institution_code) ORDER BY r.event_date,r.row_key),'[]') INTO e
 FROM public.lts_v229_expense_rows(u,greatest(date '2013-10-10',date_trunc('month',p_from)::date),
  (date_trunc('month',p_to)+interval '1 month'-interval '1 day')::date)r
 LEFT JOIN public.lts_open_finance_staging s ON r.source_table='lts_open_finance_staging' AND s.user_id=u AND s.id::text=r.source_ref;
 j:=lts_month_private_v393.build(f,e,p_from,p_to,current_date);
 IF epoch IS DISTINCT FROM(SELECT x.epoch FROM public.lts_read_cache_epoch_v242 x WHERE singleton)
 THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Sources changed during monthly read';END IF;
 RETURN public.lts_card_read_finish_v269(u,revision,j);
END $fn$;
REVOKE ALL ON FUNCTION lts_month_private_v393.cash_metrics(jsonb),lts_month_private_v393.projected_items(jsonb,date,date),lts_month_private_v393.build(jsonb,jsonb,date,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_month_private_v393.cash_metrics(jsonb),lts_month_private_v393.projected_items(jsonb,date,date),lts_month_private_v393.build(jsonb,jsonb,date,date,date) TO service_role;
REVOKE ALL ON FUNCTION public.lts_browser_month_overview_v393(date,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_month_overview_v393(date,date) TO authenticated,service_role;
