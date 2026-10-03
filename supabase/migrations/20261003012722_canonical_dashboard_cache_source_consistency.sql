-- Keep all financial facts untouched; derived summaries consume the canonical operational flow.

CREATE OR REPLACE FUNCTION public.lts_flow_cache_base_v240(p_user_id uuid,p_from date,p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
declare u uuid:=p_user_id; result jsonb;
begin
  if p_from<current_date then raise exception 'cache worker accepts current and future dates only'; end if;
  if p_from is null or p_to is null or p_from>p_to or p_to-p_from>12000 then raise exception 'invalid range'; end if;
  result:=jsonb_build_object('from',p_from,'to',p_to,'historical',jsonb_build_object('days','[]'::jsonb,'events','[]'::jsonb));
  if p_from<current_date then
    result:=public.lts_flow_history_read_v229(p_from,least(p_to,current_date-1))||jsonb_build_object('from',p_from,'to',p_to);
  end if;
  if p_to>=current_date then
    result:=jsonb_set(result,'{current_future}',public.lts_current_flow_v229(u,greatest(p_from,current_date),p_to),true);
  end if;
  return jsonb_build_object('ok',true,'flow',result,'version','browser-flow-v13-current-open-finance-anchor-v225');
end
$function$;

REVOKE ALL ON FUNCTION public.lts_flow_cache_base_v240(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_flow_cache_base_v240(uuid,date,date) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_flow_cache_pre_v240(p_user_id uuid,p_from date,p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
DECLARE
 u uuid:=p_user_id; anchors jsonb; positions jsonb; own_global_return boolean;
 lo date; result jsonb; f jsonb; events jsonb; recent jsonb; observed jsonb;
 s record; b text; a jsonb; e jsonb; matched jsonb; match_count int; added jsonb:='[]';
 d jsonb; dt date; c jsonb; outdays jsonb; part text; dayev jsonb;
 bal numeric; net numeric; fin numeric; inc numeric; outflow numeric; internal numeric;
 op_in numeric; op_out numeric; rsu numeric; d0 numeric; fgts numeric; gaps jsonb:='{}';
 pending_predictions jsonb:='[]'; morgan jsonb; cofrinho jsonb; asof date; asset_net numeric; gap_dates jsonb:='{}'; first_gap date; day_gap numeric;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_to-p_from>12000 THEN RAISE EXCEPTION 'invalid range'; END IF;
 SELECT coalesce(jsonb_agg(x),'[]'),min((x->>'date')::date) INTO anchors,lo FROM (
  SELECT DISTINCT ON (institution) jsonb_build_object('bank',institution,'date',metadata->>'balance_as_of','balance',(metadata->>'balance')::numeric) x
  FROM public.accounts WHERE user_id=u AND is_active AND metadata->>'evidence_sha256' IS NOT NULL
   AND institution IN ('Itaú','Bradesco','C6') AND (metadata->>'balance_as_of')::date<current_date
  ORDER BY institution,(metadata->>'balance_as_of')::date DESC
 ) q;
 IF lo IS NULL OR p_to<=lo OR p_from>current_date THEN RETURN public.lts_flow_cache_base_v240(u,p_from,p_to); END IF;
 -- A complete recent context makes balances independent of the selected range.
 result:=public.lts_flow_cache_base_v240(u,p_from,p_to); f:=result->'flow';
 events:=coalesce(f#>'{historical,events}','[]')||coalesce(f#>'{current_future,events}','[]');
 -- Read only movement rows for context, without rendering historical balances.
 -- Prefer the existing reader's rich event metadata inside the requested range.
 WITH candidates AS (
  SELECT x,0 priority FROM jsonb_array_elements(events) x
   WHERE (x->>'event_date')::date>lo AND (x->>'event_date')::date<=current_date
  UNION ALL
  SELECT x,1 FROM jsonb_array_elements(public.lts_flow_operational_read_v229(u,lo+1,current_date)) x
 ), ranked AS (
  SELECT DISTINCT ON (x->>'event_date',x->>'account',x->>'source',x->>'source_ref') x
   FROM candidates ORDER BY x->>'event_date',x->>'account',x->>'source',x->>'source_ref',priority
 ) SELECT coalesce(jsonb_agg(x),'[]') INTO recent FROM ranked;
 positions:=public.lts_open_finance_checking_positions_v1(u);
 IF jsonb_array_length(positions)<>3 THEN RAISE EXCEPTION 'checking account positions incomplete or ambiguous'; END IF;
 FOR s IN SELECT st.*,case institution_code when '341' then 'Itaú' when '237' then 'Bradesco' else 'C6' end bank
  FROM public.lts_bank_posted_rows_v231(u) st WHERE user_id=u AND resource_type='transaction'
   AND institution_code IN ('341','237','336') AND currency='BRL' AND provider_deleted_at IS NULL
   AND normalized_payload->>'status'='POSTED' AND normalized_payload->>'account_type'='CHECKING_ACCOUNT'
   AND posting_date>lo AND posting_date<=current_date ORDER BY posting_date,id
 LOOP
  SELECT x INTO a FROM jsonb_array_elements(anchors) x WHERE x->>'bank'=s.bank;
  IF a IS NULL OR s.posting_date<=(a->>'date')::date THEN CONTINUE; END IF;
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(positions) x WHERE x->>'bank'=s.bank
   AND x#>>'{payload,provider_account_id}'=s.normalized_payload->>'provider_account_id'
   AND s.occurred_at<=(x->>'as_of')::timestamptz) THEN CONTINUE; END IF;
  -- Cross-date matches require a private documentary identity and exact bank/cents.
  -- This is not an amount-only proximity match or a generic suppression rule.
  IF EXISTS(SELECT 1 FROM public.lts_v229_documentary_match dm WHERE dm.user_id=u AND dm.staging_id=s.id
   AND dm.bank=s.bank AND dm.signed_amount=s.signed_amount AND dm.canonical_date<=(a->>'date')::date
   AND EXISTS(SELECT 1 FROM public.financial_events fe WHERE fe.user_id=u AND (fe.id::text=dm.source_ref OR fe.legacy_id=dm.source_ref) AND fe.event_date=dm.canonical_date AND fe.amount=dm.signed_amount)) THEN CONTINUE; END IF;
  -- Require exact source identity (or exact description), bank, date and cents.
  SELECT count(*),(jsonb_agg(x))->0 INTO match_count,matched FROM jsonb_array_elements(recent) x
   WHERE x->>'account'=s.bank AND (x->>'event_date')::date=s.posting_date AND (x->>'signed_amount')::numeric=s.signed_amount
   AND (EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(s.normalized_payload#>'{reconciliation,candidates}','[]')) z
     WHERE z->>'ref' IN (x->>'source_ref',(x->>'source')||':'||(x->>'source_ref')))
    OR lower(trim(x->>'description'))=lower(trim(s.description_raw))
    OR x->>'open_finance_id'=s.id::text);
  IF match_count>1 THEN RAISE EXCEPTION 'ambiguous bank movement identity'; END IF;
  IF match_count=1 THEN
   e:=matched||jsonb_build_object('open_finance_id',s.id,'bank_confirmed',true);
   SELECT coalesce(jsonb_agg(case when x=matched then e else x end),'[]') INTO recent FROM jsonb_array_elements(recent) x;
  ELSE
   own_global_return:=public.lts_bank_own_global_return_v1(u,s.id);
   e:=jsonb_build_object('source','open_finance','source_ref',s.id,'open_finance_id',s.id,'event_date',s.posting_date,
    'account',s.bank,'account_attribution','assigned','description',s.description_raw,'signed_amount',s.signed_amount,
    'direction',case when s.signed_amount<0 then 'saida' else 'entrada' end,'confidence','bank_posted','bank_confirmed',true,
    'category',case when s.description_raw ILIKE '%RESGATE COFRINH%' OR own_global_return then 'Movimentação interna' else 'A classificar' end,
    'internal_transfer',s.description_raw ILIKE '%RESGATE COFRINH%' OR own_global_return,
    'asset_movement',s.description_raw ILIKE '%RESGATE COFRINH%','excluded',s.description_raw ILIKE '%RESGATE COFRINH%' OR own_global_return);
   recent:=recent||jsonb_build_array(e);added:=added||jsonb_build_array(e);
  END IF;
 END LOOP;
 -- A realized payroll replaces its matched forecast even when an older cache exists.
 SELECT coalesce(jsonb_agg(x),'[]') INTO recent FROM jsonb_array_elements(recent) x
 WHERE NOT EXISTS(SELECT 1 FROM public.lts_payroll_bank_matches_v231(u) pm WHERE pm.projection_ref=x->>'source_ref');
 -- A scheduled event for today affects today's operational closing, while
 -- only posted/current facts participate in observed-bank reconciliation.
 SELECT coalesce(jsonb_agg(x||CASE WHEN NOT coalesce((x->>'bank_confirmed')::boolean,false)
  AND x->>'source'='current_event' AND (x->>'event_date')::date=current_date
  AND EXISTS(SELECT 1 FROM public.financial_events fe WHERE fe.user_id=u AND fe.is_projection AND NOT fe.is_suppressed
   AND (fe.id::text=x->>'source_ref' OR fe.legacy_id=x->>'source_ref')
   AND fe.event_date=(x->>'event_date')::date AND fe.amount=(x->>'signed_amount')::numeric)
  THEN jsonb_build_object('unposted_current_projection',true) ELSE '{}'::jsonb END),'[]') INTO recent FROM jsonb_array_elements(recent) x;
 -- Past/current projections are not posted cash. Retain them for review, never erase.
 SELECT coalesce(jsonb_agg(x),'[]') INTO pending_predictions FROM jsonb_array_elements(recent) x
  WHERE NOT coalesce((x->>'bank_confirmed')::boolean,false)
  AND x->>'confidence' IN ('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot')
  AND (x->>'event_date')::date>(SELECT (anchor_item->>'date')::date FROM jsonb_array_elements(anchors) anchor_item WHERE anchor_item->>'bank'=x->>'account');
 SELECT coalesce(jsonb_agg(x),'[]') INTO recent FROM jsonb_array_elements(recent) x
  WHERE coalesce((x->>'bank_confirmed')::boolean,false)
  OR coalesce(x->>'confidence','') NOT IN ('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot')
  OR (x->>'event_date')::date<=(SELECT (anchor_item->>'date')::date FROM jsonb_array_elements(anchors) anchor_item WHERE anchor_item->>'bank'=x->>'account');
 SELECT coalesce(jsonb_agg(x||CASE WHEN k.c->>'category' IS NOT NULL THEN jsonb_build_object(
  'category',k.c->>'category','center_cost',k.c->>'beneficiary','classification_confirmed',true,'classification_basis',k.c->>'basis') ELSE '{}'::jsonb END),'[]')
 INTO recent FROM jsonb_array_elements(recent) x
 LEFT JOIN LATERAL(SELECT public.lts_bank_known_classification_v231(u,(x->>'open_finance_id')::uuid) c WHERE x->>'open_finance_id' IS NOT NULL) k ON true;
 SELECT coalesce(jsonb_agg(x||CASE
  WHEN coalesce((x->>'asset_movement')::boolean,false) AND x->>'description' ILIKE '%RESGATE COFRINH%' THEN jsonb_build_object('description','Resgate Cofrinho')
  WHEN coalesce((x->>'internal_transfer')::boolean,false) AND pair.bank IS NOT NULL THEN jsonb_build_object('description','Transferência entre contas — '||CASE WHEN (x->>'signed_amount')::numeric<0 THEN (x->>'account')||' → '||pair.bank ELSE pair.bank||' → '||(x->>'account') END)
  ELSE '{}'::jsonb END),'[]') INTO recent FROM jsonb_array_elements(recent) x
 LEFT JOIN LATERAL(SELECT CASE WHEN count(*)=1 THEN min(y->>'account') END bank FROM jsonb_array_elements(recent) y
  WHERE coalesce((y->>'internal_transfer')::boolean,false) AND y->>'event_date'=x->>'event_date'
  AND y->>'account'<>x->>'account' AND (y->>'signed_amount')::numeric=-(x->>'signed_amount')::numeric) pair ON true;
 -- Preserve older history and projected events; replace only the recent context.
 SELECT coalesce(jsonb_agg(x),'[]') INTO events FROM jsonb_array_elements(events) x
  WHERE (x->>'event_date')::date<=lo OR (x->>'event_date')::date>current_date;
 events:=events||recent;
 -- Compare the recent ledger to its older documentary anchor. Differences remain
 -- evidence gaps, never synthetic transactions. Current bank positions stay exact.
 FOR a IN SELECT x FROM jsonb_array_elements(anchors) x LOOP
  b:=a->>'bank';SELECT (x->>'balance')::numeric INTO bal FROM jsonb_array_elements(positions) x WHERE x->>'bank'=b;
  SELECT coalesce(sum((x->>'signed_amount')::numeric),0) INTO net FROM jsonb_array_elements(recent) x
   WHERE x->>'account'=b AND (x->>'event_date')::date>(a->>'date')::date AND x->>'source'<>'economic_withholding' AND NOT coalesce((x->>'unposted_current_projection')::boolean,false);
  gaps:=gaps||jsonb_build_object(b,round(bal-(a->>'balance')::numeric-net,2));
  IF abs((gaps->>b)::numeric)>.005 THEN
   -- Repeated provider observations do not change the first discrepancy date.
   -- Parse each observed balance and the recent ledger once before comparing.
   WITH observed_balances AS MATERIALIZED (
    SELECT DISTINCT ((o.normalized_payload->>'as_of')::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date dt,
     (o.normalized_payload->>'amount')::numeric amount
    FROM public.lts_open_finance_observation o JOIN public.lts_open_finance_connection cn ON cn.id=o.connection_id
    WHERE o.user_id=u AND o.resource_type='balance' AND o.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
    AND CASE cn.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END=b
    AND ((o.normalized_payload->>'as_of')::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date>(a->>'date')::date
   ), ledger AS MATERIALIZED (
    SELECT (x->>'event_date')::date dt,sum((x->>'signed_amount')::numeric) amount
    FROM jsonb_array_elements(recent) x WHERE x->>'account'=b
     AND (x->>'event_date')::date>(a->>'date')::date AND x->>'source'<>'economic_withholding' AND NOT coalesce((x->>'unposted_current_projection')::boolean,false)
    GROUP BY (x->>'event_date')::date
   )
   SELECT min(o.dt) INTO first_gap FROM observed_balances o
   WHERE abs(o.amount-(a->>'balance')::numeric-coalesce((SELECT sum(l.amount) FROM ledger l WHERE l.dt<=o.dt),0))>.005;
   gap_dates:=gap_dates||jsonb_build_object(b,first_gap);
  END IF;
 END LOOP;
 SELECT canonical_value INTO morgan FROM public.lts_validated_lock_registry WHERE superseded_at IS NULL AND lock_key LIKE 'morgan_available_%' ORDER BY canonical_value->>'as_of' DESC LIMIT 1;
 SELECT canonical_value INTO cofrinho FROM public.lts_validated_lock_registry WHERE superseded_at IS NULL AND lock_key LIKE 'itau_cofrinho_%' ORDER BY canonical_value->>'as_of' DESC LIMIT 1;
 FOREACH part IN ARRAY ARRAY['historical','current_future'] LOOP
  outdays:='[]';
  FOR d IN SELECT x FROM jsonb_array_elements(coalesce(f#>ARRAY[part,'days'],'[]')) x WHERE (x->>'date')::date BETWEEN p_from AND p_to ORDER BY x->>'date' LOOP
   dt:=(d->>'date')::date;
   IF dt>lo AND dt<=current_date AND (dt=current_date OR EXISTS(SELECT 1 FROM jsonb_array_elements(added) observed_entry WHERE (observed_entry->>'event_date')::date<=dt)) THEN
    FOREACH b IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
     SELECT x INTO a FROM jsonb_array_elements(anchors) x WHERE x->>'bank'=b;
     IF a IS NULL OR dt<=(a->>'date')::date THEN CONTINUE; END IF;
     -- Reconstruct forwards from the dated documentary opening. The observed
     -- position is a check, not an input that can force the ledger to balance.
     SELECT (a->>'balance')::numeric+coalesce(sum((x->>'signed_amount')::numeric),0) INTO bal
      FROM jsonb_array_elements(recent) x WHERE x->>'account'=b
       AND (x->>'event_date')::date>(a->>'date')::date AND (x->>'event_date')::date<=dt
       AND x->>'source'<>'economic_withholding';
     SELECT coalesce(sum((x->>'signed_amount')::numeric),0) INTO net FROM jsonb_array_elements(recent) x
      WHERE x->>'account'=b AND (x->>'event_date')::date=dt AND x->>'source'<>'economic_withholding';
     first_gap:=NULL;
     d:=jsonb_set(d,ARRAY[b],coalesce(d->b,'{}')||jsonb_build_object('balance',bal,'net',net,'operational_balance',bal,'operational_net',net,
      'balance_basis','observed_bank_position_and_recent_movements','balance_certified',abs((gaps->>b)::numeric)<0.005 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(recent) proj WHERE proj->>'account'=b AND (proj->>'event_date')::date=dt AND coalesce((proj->>'unposted_current_projection')::boolean,false)),
      'unposted_projection_net',coalesce((SELECT sum((proj->>'signed_amount')::numeric) FROM jsonb_array_elements(recent) proj WHERE proj->>'account'=b AND (proj->>'event_date')::date=dt AND coalesce((proj->>'unposted_current_projection')::boolean,false)),0),
      'observed_balance',CASE WHEN dt=current_date THEN (SELECT (p->>'balance')::numeric FROM jsonb_array_elements(positions) p WHERE p->>'bank'=b) END,
      'movements_complete',dt IS DISTINCT FROM first_gap,'opening_balance',bal-net-CASE WHEN dt=first_gap THEN (gaps->>b)::numeric ELSE 0 END,'position_gap',CASE WHEN dt=first_gap THEN (gaps->>b)::numeric ELSE 0 END,'reconciliation_gap',(gaps->>b)::numeric));
    END LOOP;
    SELECT coalesce(jsonb_agg(x),'[]') INTO dayev FROM jsonb_array_elements(recent) x WHERE (x->>'event_date')::date=dt
     AND x->>'account' IN ('Itaú','Bradesco','C6') AND x->>'source'<>'economic_withholding';
    SELECT coalesce(sum(greatest((x->>'signed_amount')::numeric,0)) FILTER(WHERE NOT coalesce((x->>'internal_transfer')::boolean,false)),0),
     coalesce(-sum(least((x->>'signed_amount')::numeric,0)) FILTER(WHERE NOT coalesce((x->>'internal_transfer')::boolean,false)),0),
     coalesce(sum((x->>'signed_amount')::numeric) FILTER(WHERE coalesce((x->>'internal_transfer')::boolean,false)),0)
     INTO op_in,op_out,internal FROM jsonb_array_elements(dayev) x;
    inc:=op_in+greatest(internal,0);outflow:=op_out+greatest(-internal,0);
    fin:=(d#>>'{Itaú,balance}')::numeric+(d#>>'{Bradesco,balance}')::numeric+(d#>>'{C6,balance}')::numeric;
    c:=d->'fix86_columns';d0:=(c->>'liq_d0_1_recurso')::numeric;rsu:=(c->>'rsus_vested')::numeric;fgts:=(c->>'fgts')::numeric;
    IF dt>=(morgan->>'as_of')::date THEN rsu:=(morgan->>'total_available_brl')::numeric; END IF;
    IF dt>=(cofrinho->>'as_of')::date THEN d0:=(cofrinho->>'amount')::numeric;
    ELSE
     SELECT coalesce(sum((x->>'signed_amount')::numeric),0) INTO asset_net FROM jsonb_array_elements(added) x
      WHERE coalesce((x->>'asset_movement')::boolean,false) AND (x->>'event_date')::date<=dt;
     d0:=d0-asset_net;
    END IF;
    c:=c||jsonb_build_object('saldo_final',fin,'saldo_final_operacional',fin,'saldo_anterior',fin-inc+outflow,'saldo_anterior_operacional',fin-inc+outflow,
     'entradas',inc,'saidas',outflow,'entradas_operacionais',inc,'saidas_operacionais',outflow,'rsus_vested',rsu,'liq_d0_1_recurso',d0,
     'saldo_apos_d0_1',fin+d0,'liq_d0_1',fin+d0,'posicao_antes_rsus',fin+d0,'saldo_apos_rsu',fin+d0+rsu,
     'disponivel_total',fin+d0+rsu,'posicao_curto_prazo',fin+d0+rsu,'saldo_apos_fgts',fin+d0+rsu+fgts);
    d:=d||jsonb_build_object('fix86_columns',c,'Consolidado',(d->'Consolidado')||jsonb_build_object('bank_balance',fin,'net',inc-outflow,'economic_net',op_in-op_out,'balance_certified',coalesce((d#>>'{Itaú,balance_certified}')::boolean,false) AND coalesce((d#>>'{Bradesco,balance_certified}')::boolean,false) AND coalesce((d#>>'{C6,balance_certified}')::boolean,false)),
     'summary',(d->'summary')||jsonb_build_object('entries',inc,'exits',outflow,'net',inc-outflow,'events',jsonb_array_length(dayev),'Consolidado',jsonb_build_object('entries',inc,'exits',outflow)),
     'v170_cash_arithmetic',jsonb_build_object('version','tracked-bank-cash-arithmetic-v1','balanced',true,'arithmetic_gap_brl',0,
      'operating_entries_brl',op_in,'operating_exits_brl',op_out,'internal_transfer_net_brl',internal,'tracked_bank_net_brl',inc-outflow));
   END IF;
   day_gap:=coalesce((d#>>'{Itaú,position_gap}')::numeric,0)+coalesce((d#>>'{Bradesco,position_gap}')::numeric,0)+coalesce((d#>>'{C6,position_gap}')::numeric,0);
   IF abs(day_gap)>.005 THEN
    d:=d||jsonb_build_object('movements_complete',false,'position_gap',day_gap,'fix86_columns',(d->'fix86_columns')||jsonb_build_object(
     'saldo_anterior',(d#>>'{fix86_columns,saldo_anterior}')::numeric-day_gap,
     'saldo_anterior_operacional',(d#>>'{fix86_columns,saldo_anterior_operacional}')::numeric-day_gap,'entradas',null,'saidas',null));
   END IF;
   IF dt<current_date AND dt>=(morgan->>'as_of')::date THEN
    c:=d->'fix86_columns';rsu:=(morgan->>'total_available_brl')::numeric;
    IF rsu IS NOT NULL THEN
     c:=c||jsonb_build_object('rsus_vested',rsu,
      'saldo_apos_rsu',(c->>'saldo_apos_d0_1')::numeric+rsu,
      'disponivel_total',(c->>'saldo_apos_d0_1')::numeric+rsu,
      'posicao_curto_prazo',(c->>'saldo_apos_d0_1')::numeric+rsu,
      'saldo_apos_fgts',(c->>'saldo_apos_d0_1')::numeric+rsu+(c->>'fgts')::numeric,
      'historical_rsu_basis','dated_validated_brokerage_available');
     d:=d||jsonb_build_object('fix86_columns',c);
    END IF;
   END IF;
   outdays:=outdays||jsonb_build_array(d);
  END LOOP;
  f:=jsonb_set(f,ARRAY[part],coalesce(f->part,'{}')||jsonb_build_object('days',outdays,'events',coalesce((SELECT jsonb_agg(x ORDER BY x->>'event_date',x->>'source_ref')
   FROM jsonb_array_elements(events) x WHERE (x->>'event_date')::date BETWEEN p_from AND p_to
    AND case when part='historical' then (x->>'event_date')::date<current_date else (x->>'event_date')::date>=current_date end),'[]')));
 END LOOP;
 f:=f||jsonb_build_object('from',p_from,'to',p_to,'observed_bank_movements',jsonb_build_object('version','v229','added_count',jsonb_array_length(added),'documentary_gaps',gaps,'position_gap_dates',gap_dates,'pending_projections',pending_predictions,
  'matched_projections',coalesce((SELECT jsonb_agg(to_jsonb(m)) FROM public.lts_payroll_bank_matches_v231(u) m),'[]'::jsonb)));

 RETURN result||jsonb_build_object('flow',public.lts_flow_review_overlay_v229(u,f),'version','browser-flow-v229-consistent-evidence','reader_revision','v231-forward-realized-ledger');
END $function$;

REVOKE ALL ON FUNCTION public.lts_flow_cache_pre_v240(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_flow_cache_pre_v240(uuid,date,date) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_flow_cache_core_v240(p_user_id uuid,p_from date,p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
DECLARE u uuid:=p_user_id; result jsonb; f jsonb; lo date:=p_from;
 v record; d jsonb; prev jsonb; ev jsonb; part text; all_events jsonb; newdays jsonb; c jsonb;
 old_net numeric; actual_net numeric; opening numeric; closing numeric; inc numeric; outflow numeric; prior numeric; gap numeric;
 recovered jsonb:='[]'; today_row jsonb; bank_deltas jsonb:='{}'; bank_name text; bank_delta numeric; total_delta numeric:=0; projected_date date; cash_field text;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to THEN RAISE EXCEPTION 'invalid range';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_realized_bank_sources_v238(u) s WHERE s.event_date=p_from AND s.event_date<current_date) THEN lo:=p_from-1;END IF;
 IF p_to>=current_date THEN lo:=least(lo,current_date);END IF;
 result:=public.lts_flow_cache_pre_v240(u,lo,p_to);f:=result->'flow';
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
 -- Future balances continue the operational closing of today. The observed
 -- bank snapshot remains a separate fact and is never changed by this reader.
 SELECT x INTO today_row FROM jsonb_array_elements(coalesce(f#>'{current_future,days}','[]')) x WHERE (x->>'date')::date=current_date;
 IF today_row IS NOT NULL THEN
  FOREACH bank_name IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
   bank_delta:=coalesce((today_row#>>ARRAY[bank_name,'balance'])::numeric-(today_row#>>ARRAY[bank_name,'observed_balance'])::numeric,0);
   bank_deltas:=bank_deltas||jsonb_build_object(bank_name,bank_delta);total_delta:=total_delta+bank_delta;
  END LOOP;
  IF EXISTS(SELECT 1 FROM jsonb_each_text(bank_deltas) x WHERE abs(x.value::numeric)>.005) THEN
   newdays:='[]';
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
    prev:=d;newdays:=newdays||jsonb_build_array(d);
   END LOOP;
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
$function$;

REVOKE ALL ON FUNCTION public.lts_flow_cache_core_v240(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_flow_cache_core_v240(uuid,date,date) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_wealth_executive_report_v5(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with b as materialized (
  select public.lts_wealth_executive_report_v4(p_user_id) j
), d as materialized (
  select jsonb_build_object('Consolidado',jsonb_build_object('bank_balance',p->'bank_cash')) j from (select public.lts_open_finance_current_bank_position_v1(p_user_id) p) s
), a as materialized (
  select
    coalesce(sum(effective_value_brl) filter(where liquidity_class='D+0' and is_available_now),0)::numeric d0,
    (select (canonical_value->>'total_available_brl')::numeric from public.lts_validated_lock_registry where lock_key='morgan_available_20260922' and superseded_at is null)::numeric d3,
    coalesce(sum(effective_value_brl) filter(where liquidity_class='restricted'),0)::numeric restricted,
    coalesce(sum(effective_value_brl) filter(where liquidity_class='future'),0)::numeric future
  from public.lts_asset_position_effective_v1(p_user_id,current_date)
), n as (
  select
    coalesce((d.j#>>'{Consolidado,bank_balance}')::numeric,0) bank,
    a.d0,a.d3,a.restricted,a.future,
    (b.j#>>'{assets,cipo_396,market_low}')::numeric cipo_low,
    (b.j#>>'{assets,cipo_396,market_central}')::numeric cipo_central,
    (b.j#>>'{assets,cipo_396,market_high}')::numeric cipo_high,
    (b.j#>>'{assets,volvo_xc40,market_low}')::numeric volvo_low,
    (b.j#>>'{assets,volvo_xc40,market_central}')::numeric volvo_central,
    (b.j#>>'{assets,volvo_xc40,market_high}')::numeric volvo_high,
    coalesce((b.j#>>'{summary,known_debt_total}')::numeric,0) debt,
    (
      select count(*)
      from public.lts_liquidity_movement
      where user_id=p_user_id and status='active' and event_date<=current_date
    ) movement_count
  from d cross join a cross join b
), calc as (
  select n.*,
    bank+d0+d3 through_d3,
    bank+d0+d3+restricted+cipo_low+volvo_low assets_low,
    bank+d0+d3+restricted+cipo_central+volvo_central assets_central,
    bank+d0+d3+restricted+cipo_high+volvo_high assets_high
  from n
), patched as (
  select jsonb_set(
    jsonb_set(
      jsonb_set(
        jsonb_set(
          (select j from b),
          '{summary}',
          coalesce((select j->'summary' from b),'{}'::jsonb) || jsonb_build_object(
            'net_worth_low',round(assets_low-debt,2),
            'net_worth_central',round(assets_central-debt,2),
            'net_worth_high',round(assets_high-debt,2),
            'assets_central',round(assets_central,2),
            'known_debt_total',round(debt,2),
            'liquidity_through_d3',round(through_d3,2),
            'restricted_contingency',round(restricted,2),
            'future_awards_excluded',round(future,2),
            'known_debt_to_assets_pct',case when assets_central<>0 then round(100*debt/assets_central,1) else null end,
            'cipo_share_of_assets_pct',case when assets_central<>0 then round(100*cipo_central/assets_central,1) else null end
          ),
          true
        ),
        '{liquidity}',
        jsonb_build_object(
          'bank_cash',round(bank,2),
          'd0',round(d0,2),
          'd3',round(d3,2),
          'through_d3',round(through_d3,2),
          'fgts_contingency',round(restricted,2),
          'future_awards_excluded',round(future,2)
        ),
        true
      ),
      '{distribution}',
      jsonb_build_array(
        jsonb_build_object('name','Liquidez até D+3','detail','Bancos + D0 + D+3 documentados','value',round(through_d3,2)),
        jsonb_build_object('name','FGTS','detail','Restrito · contingência documental','value',round(restricted,2)),
        jsonb_build_object('name','CIPÓ 396','detail','Valor de mercado central · estimativa analítica','value',round(cipo_central,2)),
        jsonb_build_object('name','Volvo XC40','detail','Valor de mercado central · estimativa analítica','value',round(volvo_central,2))
      ),
      true
    ),
    '{effective_liquidity_movement}',
    jsonb_build_object(
      'active_movements_through_today',movement_count,
      'bank_asset_parity',true,
      'read_basis','validated checking position + effective assets + validated total brokerage available'
    ),
    true
  ) j
  from calc
)
select (select j from patched)-'version' || jsonb_build_object(
  'version','wealth-executive-v5-effective-bank-asset-liquidity',
  'reconciliation_version','wealth-summary-current-effective-v240',
  'liquidity_basis','Current validated bank cash plus effective assets and the independently validated total brokerage available, following the confirmed RSU Vested policy.',
  'current_reconciliation',jsonb_build_object(
    'bank_source','validated_open_finance_checking_position',
    'asset_source','lts_asset_position_effective_v1',
    'assets_identity_reconciled',true,
    'brokerage_total_available_basis','validated_morgan_lock_explicit_user_policy'
  ),
  'guardrails',coalesce((select j->'guardrails' from patched),'[]'::jsonb)||jsonb_build_array(
    'Aplicação/resgate altera a composição banco versus ativo, não cria renda, despesa ou patrimônio líquido adicional.',
    'Snapshots documentais supersededidos não são somados como posições correntes simultâneas.',
    'O total disponível da Morgan inclui ações e dinheiro já disponíveis conforme regra confirmada; não gera entrada bancária nem soma esses componentes novamente.'
  )
);
$function$;

CREATE OR REPLACE FUNCTION public.lts_dashboard_cash_ladder_from_flow_v1(p_user_id uuid, p_from date, p_to date, p_flow jsonb)
 RETURNS TABLE(flow_date date, operational_cash numeric, d01_resource numeric, balance_after_d01 numeric, rsu_vested_today numeric, rsu_vested_scheduled numeric, balance_no_new_vesting numeric, balance_with_scheduled_vesting numeric, fgts_projected numeric, balance_with_fgts numeric)
 LANGUAGE sql
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with base as (
 select (d->>'date')::date dt,(d#>>'{fix86_columns,saldo_final}')::numeric bank_close,
 (d#>>'{fix86_columns,liq_d0_1_recurso}')::numeric d01_resource,
 (d#>>'{fix86_columns,rsus_vested}')::numeric scheduled_rsu
 from jsonb_array_elements(coalesce(p_flow->'days','[]'::jsonb)) d
), params as (
 select (select (canonical_value->>'total_available_brl')::numeric from public.lts_validated_lock_registry where lock_key='morgan_available_20260922' and superseded_at is null) rsu_anchor,
 (select effective_value_brl from public.lts_asset_position_effective_v1(p_user_id,current_date) where asset_type='FGTS' order by documented_as_of desc,asset_position_id desc limit 1) fgts_anchor
)
select b.dt,b.bank_close,b.d01_resource,b.bank_close+b.d01_resource,p.rsu_anchor,b.scheduled_rsu,
 b.bank_close+b.d01_resource+p.rsu_anchor,b.bank_close+b.d01_resource+b.scheduled_rsu,p.fgts_anchor,
 b.bank_close+b.d01_resource+b.scheduled_rsu+p.fgts_anchor
from base b cross join params p where b.dt between p_from and p_to order by b.dt;
$function$;

CREATE OR REPLACE FUNCTION public.lts_planning_liquidity_ladder_from_flow_v1(p_user_id uuid, p_from date, p_to date, p_flow jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with l as materialized (
  select * from public.lts_dashboard_cash_ladder_from_flow_v1(p_user_id,p_from,p_to,p_flow)
), first_row as (select * from l order by flow_date limit 1),
last_row as (select * from l order by flow_date desc limit 1),
flags as (
  select l.*,(balance_with_scheduled_vesting<0) neg,lag(balance_with_scheduled_vesting<0) over(order by flow_date) prev_neg from l
), grouped as (
  select *,sum(case when prev_neg is distinct from neg then 1 else 0 end) over(order by flow_date) grp from flags
), episodes as (
  select min(flow_date) start_date,max(flow_date) end_date,min(balance_with_scheduled_vesting)::numeric worst_balance,count(*)::int days
  from grouped where neg group by grp
), episode_rows as (
  select e.*,(select min(flow_date) from l where flow_date>e.end_date and balance_with_scheduled_vesting>=0) recovery_date,
         (select balance_with_fgts from l where flow_date=e.start_date) fgts_balance_at_start
  from episodes e
), stats as (
  select (select operational_cash from first_row) cash_start,(select d01_resource from first_row) d01_start,
    (select rsu_vested_today from first_row) vested_start,(select fgts_projected from first_row) fgts_start,
    min(flow_date) filter(where operational_cash<0) cash_negative,
    min(flow_date) filter(where balance_after_d01<0) d01_negative,
    min(flow_date) filter(where balance_no_new_vesting<0) vested_negative,
    min(flow_date) filter(where balance_with_scheduled_vesting<0) scheduled_negative,
    min(flow_date) filter(where balance_with_fgts<0) fgts_negative,
    min(balance_with_scheduled_vesting) worst_scheduled,min(balance_with_fgts) worst_with_fgts,
    (select operational_cash from last_row) cash_end,(select balance_after_d01 from last_row) d01_end,
    (select balance_no_new_vesting from last_row) vested_end,(select balance_with_scheduled_vesting from last_row) scheduled_end,
    (select balance_with_fgts from last_row) fgts_end
  from l
)
select jsonb_build_object(
 'version','planning-liquidity-ladder-v240-canonical-fgts-d30','from',p_from,'to',p_to,'flow_basis','canonical_operational_flow_v240',
 'layers',jsonb_build_array(
   jsonb_build_object('order',1,'id','cash','label','Caixa','liquidity','immediate','starting_amount',(select cash_start from stats),'first_need_next_layer',(select cash_negative from stats),'ending_balance',(select cash_end from stats)),
   jsonb_build_object('order',2,'id','d01','label','Cofrinho / D+0-D+1','liquidity','D+0/D+1','starting_amount',(select d01_start from stats),'first_need_next_layer',(select d01_negative from stats),'ending_balance',(select d01_end from stats)),
   jsonb_build_object('order',3,'id','rsu_vested','label','RSU vested','liquidity','D+3','starting_amount',(select vested_start from stats),'first_need_next_layer',(select vested_negative from stats),'ending_balance',(select vested_end from stats)),
   jsonb_build_object('order',4,'id','future_vestings','label','Novos vestings programados','liquidity','conditional after vesting + settlement','starting_amount',0,'first_need_next_layer',(select scheduled_negative from stats),'ending_balance',(select scheduled_end from stats),'worst_balance',(select worst_scheduled from stats)),
   jsonb_build_object('order',5,'id','fgts','label','FGTS','liquidity','restricted D+30','starting_amount',(select fgts_start from stats),'first_need_next_layer',(select fgts_negative from stats),'ending_balance',(select fgts_end from stats),'worst_balance',(select worst_with_fgts from stats),'warning','Reserva de contingência D+30; não entra automaticamente no caixa.')
 ),
 'first_real_gap_date',(select scheduled_negative from stats),
 'gap_episodes',coalesce((select jsonb_agg(jsonb_build_object('start_date',start_date,'end_date',end_date,'recovery_date',recovery_date,'days',days,'worst_balance',worst_balance,'fgts_balance_at_start',fgts_balance_at_start) order by start_date) from episode_rows),'[]'::jsonb),
 'fgts_first_negative_date',(select fgts_negative from stats),
 'fgts_access',jsonb_build_object('classification','emergency_liquidity_D+30','lead_days',30,'amount_brl',(select fgts_start from stats),'first_gap_date',(select scheduled_negative from stats),
   'request_by_date',case when (select scheduled_negative from stats) is not null then (select scheduled_negative from stats)-30 else null end,
   'days_from_start_to_request',case when (select scheduled_negative from stats) is not null then ((select scheduled_negative from stats)-30)-p_from else null end,
   'covers_horizon_if_available',case when (select scheduled_negative from stats) is not null and (select fgts_negative from stats) is null then true else false end,
   'first_negative_even_with_fgts',(select fgts_negative from stats),'semantics','FGTS é restrito, mas pode ser acionado em necessidade com prazo aproximado de 30 dias; é contingência planejável, não caixa imediato.'),
 'guardrail','Gap real = saldo negativo mesmo após vestings programados. A escada usa o mesmo motor de Fluxo v12 da experiência atual; FGTS permanece contingência D+30.'
);
$function$;

CREATE OR REPLACE FUNCTION public.lts_planning_executive_from_flow_v1(p_user_id uuid, p_from date, p_to date, p_flow jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with flow as materialized (
  select p_flow j
), ladder as materialized (
  select public.lts_planning_liquidity_ladder_from_flow_v1(p_user_id,p_from,p_to,flow.j) j from flow
), events as materialized (
  select e,
         (e->>'event_date')::date event_date,
         (e->>'signed_amount')::numeric amount,
         coalesce(e->>'description','') description,
         coalesce(e->>'category','') category,
         coalesce(e->>'account','') account,
         coalesce(e->>'source_ref','') source_ref,
         coalesce(e->>'source','') source
  from flow,lateral jsonb_array_elements(coalesce(flow.j->'events','[]'::jsonb)) e
), cash as materialized (
  select x.* from flow,lateral public.lts_dashboard_cash_ladder_from_flow_v1(p_user_id,p_from,p_to,flow.j) x
), eps as (
  select ep,(ep->>'start_date')::date start_date,(ep->>'end_date')::date end_date,
         nullif(ep->>'recovery_date','')::date recovery_date,(ep->>'worst_balance')::numeric worst_balance
  from ladder,lateral jsonb_array_elements(coalesce(ladder.j->'gap_episodes','[]'::jsonb)) ep
), ep_enriched as (
  select ep || jsonb_build_object(
    'balance_day_before',coalesce((select balance_with_scheduled_vesting from cash c where c.flow_date=e.start_date-1),null),
    'balance_at_start',coalesce((select balance_with_scheduled_vesting from cash c where c.flow_date=e.start_date),null),
    'required_buffer_at_worst',round(greatest(0,-e.worst_balance),2),
    'driver_window_from',greatest(p_from,e.start_date-7),
    'key_outflows',coalesce((
      select jsonb_agg(x order by abs((x->>'amount')::numeric) desc)
      from (
        select jsonb_build_object('date',event_date,'description',description,'category',category,'account',account,'amount',round(amount,2),'source',source,'source_ref',source_ref) x
        from events
        where event_date between greatest(p_from,e.start_date-7) and e.end_date and amount<0
        order by abs(amount) desc,event_date limit 6
      ) q
    ),'[]'::jsonb),
    'recovery_inflows',coalesce((
      select jsonb_agg(jsonb_build_object('date',event_date,'description',description,'category',category,'account',account,'amount',round(amount,2),'source',source,'source_ref',source_ref) order by amount desc)
      from events
      where e.recovery_date is not null and event_date=e.recovery_date and amount>0
    ),'[]'::jsonb)
  ) enriched
  from eps e
), audit_events as (
  select
    coalesce((select -amount from events where event_date=date '2027-01-08' and source_ref='volvo_financing_2026_p05' limit 1),0)::numeric volvo_amount,
    coalesce((select -amount from events where event_date=date '2027-01-10' and description='IPVA, DPVAT e Licenciamento' limit 1),0)::numeric ipva_amount,
    coalesce((select e from events where event_date=date '2027-01-08' and source_ref='volvo_financing_2026_p05' limit 1),'{}'::jsonb) volvo_event,
    coalesce((select e from events where event_date=date '2027-01-10' and description='IPVA, DPVAT e Licenciamento' limit 1),'{}'::jsonb) ipva_event
), jan_cf as (
  select c.flow_date,
         c.balance_with_scheduled_vesting actual,
         c.balance_with_scheduled_vesting + case when c.flow_date>=date '2027-01-08' then a.volvo_amount else 0 end no_volvo,
         c.balance_with_scheduled_vesting + case when c.flow_date>=date '2027-01-08' then a.volvo_amount else 0 end + case when c.flow_date>=date '2027-01-10' then a.ipva_amount else 0 end baseline_like
  from cash c cross join audit_events a
  where c.flow_date between date '2027-01-01' and date '2027-01-31'
), transition as (
  select jsonb_build_object(
    'reference','wip35-v131_reports_qa','certified_first_gap_date','2027-01-12',
    'current_first_gap_date',(select j->>'first_real_gap_date' from ladder),
    'status',case when (select j->>'first_real_gap_date' from ladder)='2027-01-08' and (select min(flow_date) filter(where baseline_like<0) from jan_cf)=date '2027-01-12' then 'explained' else 'requires_review' end,
    'counterfactual',jsonb_build_object(
      'current_first_negative',(select min(flow_date) filter(where actual<0) from jan_cf),
      'without_volvo_first_negative',(select min(flow_date) filter(where no_volvo<0) from jan_cf),
      'without_volvo_and_ipva_first_negative',(select min(flow_date) filter(where baseline_like<0) from jan_cf)
    ),
    'drivers',jsonb_build_array(
      jsonb_build_object('date','2027-01-08','label','Parcela financiamento Volvo 5/60','amount_brl',(select volvo_amount from audit_events),'classification','documented_contract_now_in_effective_cash_ladder','evidence',(select volvo_event from audit_events)),
      jsonb_build_object('date','2027-01-10','label','IPVA, DPVAT e Licenciamento','amount_brl',(select ipva_amount from audit_events),'classification','legacy_obligation_now_in_effective_cash_ladder','evidence',(select ipva_event from audit_events))
    ),
    'note','O contrafactual não afirma quando o IPVA passou a ser considerado. Ele prova apenas que retirar Volvo e IPVA do modelo atual reproduz exatamente o primeiro gap certificado da v131 em 12/01/2027.'
  ) j
)
select jsonb_build_object(
  'version','planning-executive-v1-explainable-gaps',
  'period',jsonb_build_object('from',p_from,'to',p_to),
  'summary',jsonb_build_object(
    'first_real_gap_date',(select j->'first_real_gap_date' from ladder),
    'gap_episode_count',(select jsonb_array_length(j->'gap_episodes') from ladder),
    'worst_balance',coalesce((select min((x->>'worst_balance')::numeric) from ladder,lateral jsonb_array_elements(coalesce(ladder.j->'gap_episodes','[]'::jsonb)) x),0),
    'fgts_request_by',(select j#>'{fgts_access,request_by_date}' from ladder),
    'fgts_amount',(select j#>'{fgts_access,amount_brl}' from ladder),
    'fgts_covers_horizon',(select j#>'{fgts_access,covers_horizon_if_available}' from ladder),
    'first_negative_even_with_fgts',(select j#>'{fgts_access,first_negative_even_with_fgts}' from ladder)
  ),
  'layers',(select j->'layers' from ladder),
  'gap_episodes',coalesce((select jsonb_agg(enriched order by (enriched->>'start_date')::date) from ep_enriched),'[]'::jsonb),
  'fgts_access',(select j->'fgts_access' from ladder),
  'transition_from_v131',(select j from transition),
  'explanation','O Planejamento mostra quando cada camada de liquidez se esgota, quais compromissos geram cada episódio de déficit e quais entradas recuperam a posição.',
  'guardrails',jsonb_build_array(
    'A escada usa o mesmo motor de Fluxo v12 da experiência operacional atual.',
    'FGTS é contingência D+30 e nunca entra automaticamente como caixa.',
    'Vestings futuros só entram depois da data programada de vesting/settlement.',
    'Mudanças versus baselines anteriores são explicadas por contrafactual; o histórico certificado não é reescrito silenciosamente.'
  )
);
$function$;

CREATE OR REPLACE FUNCTION public.lts_dashboard_executive_from_flow_v1(p_user_id uuid, p_as_of date, p_flow jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with base as (
  select public.lts_dashboard_executive_v3(p_user_id,p_as_of) j
), ladder as materialized (
  select * from public.lts_dashboard_cash_ladder_from_flow_v1(p_user_id,p_as_of,make_date(extract(year from p_as_of)::int,12,31),p_flow)
), hdef as (
  select * from (values
    (1,'30d','30 dias',p_as_of+30),
    (2,'90d','90 dias',p_as_of+90),
    (3,'year_end','Fim de '||extract(year from p_as_of)::int,make_date(extract(year from p_as_of)::int,12,31))
  ) v(ord,id,label,dt)
), hz as (
  select jsonb_agg(jsonb_build_object(
    'id',h.id,'label',h.label,'date',h.dt,
    'current_liquidity_balance',l.balance_no_new_vesting,
    'conditional_rsu_balance',l.balance_with_scheduled_vesting,
    'scheduled_vested_rsu',l.rsu_vested_scheduled,
    'rsu_vested_today',l.rsu_vested_today,
    'fgts_projected',l.fgts_projected,
    'restricted_total_balance',l.balance_with_fgts,
    'current_liquidity_status',case when l.balance_no_new_vesting<0 then 'negative' when l.balance_no_new_vesting<20000 then 'attention' else 'covered' end,
    'conditional_status',case when l.balance_with_scheduled_vesting<0 then 'negative' when l.balance_with_scheduled_vesting<20000 then 'attention' else 'covered' end,
    'liquidity_basis','bank cash + D0/D1 + RSU vested today; scheduled scenario promotes future awards only on vesting+settlement dates'
  ) order by h.ord) j
  from hdef h join ladder l on l.flow_date=h.dt
), vals as (
  select min(flow_date) filter(where balance_no_new_vesting<0) current_rupture,
         min(flow_date) filter(where balance_with_scheduled_vesting<0) scheduled_rupture,
         max(balance_no_new_vesting) filter(where flow_date=make_date(extract(year from p_as_of)::int,12,31)) current_end,
         max(balance_with_scheduled_vesting) filter(where flow_date=make_date(extract(year from p_as_of)::int,12,31)) scheduled_end,
         max(rsu_vested_today) rsu_anchor,
         max(rsu_vested_scheduled) filter(where flow_date=make_date(extract(year from p_as_of)::int,12,31)) rsu_year_end
  from ladder
), risk as (
  select coalesce((select j->'risk_layers' from base),'{}'::jsonb) j
), newrisk as (
  select (select j from risk) || jsonb_build_object(
    'current_liquidity',jsonb_build_object(
      'label','Liquidez sem novos vestings','first_negative_date',(select current_rupture from vals),'ending_balance_2026',(select current_end from vals),
      'meaning','Caixa + D0/D1 + RSU que já está vested hoje. Não promove awards futuros.'),
    'conditional_future_liquidity',jsonb_build_object(
      'label','Liquidez com vestings programados','first_negative_date',(select scheduled_rupture from vals),'ending_balance_2026',(select scheduled_end from vals),
      'future_rsu_gross',greatest((select rsu_year_end-rsu_anchor from vals),0),
      'meaning','Promove cada award futuro somente na sua data de vesting + settlement. Continua sujeito à efetiva ocorrência do vesting/liquidação.')
  ) j
), actions as (
  select jsonb_build_array(
    case when (select current_rupture from vals) is not null and (select scheduled_rupture from vals) is null then
      jsonb_build_object('priority',1,'type','liquidity_planning','status','attention','title','Planejar liquidez antes de '||(select current_rupture from vals)::text,'detail','Sem novos vestings o saldo cruza zero, mas a agenda de vesting programada mantém cobertura no horizonte.')
    when (select scheduled_rupture from vals) is not null then
      jsonb_build_object('priority',1,'type','resource_gap','status','action','title','Cobrir insuficiência projetada','detail','Há ruptura mesmo considerando os vestings já programados.')
    else jsonb_build_object('priority',1,'type','liquidity','status','ok','title','Liquidez coberta','detail','O horizonte permanece positivo inclusive sem novos vestings.') end,
    jsonb_build_object('priority',2,'type','bank_funding','status','attention','title','Antecipar funding entre contas','detail','Saldo negativo em uma conta específica pode ser redistribuição, não falta consolidada de recursos.'),
    jsonb_build_object('priority',3,'type','projection_quality','status','attention','title','Manter premissas futuras explícitas','detail','Vestings programados só entram na data elegível; FGTS permanece restrito e fora da cobertura de caixa.')
  ) j
)
select (select j from base) || jsonb_build_object(
  'version','dashboard-executive-v4-flow-consistent','as_of',p_as_of,
  'headline',case when (select scheduled_rupture from vals) is not null then 'Há insuficiência projetada mesmo após os vestings programados'
                  when (select current_rupture from vals) is not null then 'Liquidez exige planejamento, mas os vestings programados preservam cobertura em 2026'
                  else 'Liquidez coberta no horizonte de 2026' end,
  'executive_message',case when (select scheduled_rupture from vals) is not null then 'A trajetória cruza zero mesmo após promover apenas os vestings programados nas datas elegíveis.'
                           when (select current_rupture from vals) is not null then 'Sem novos vestings, a liquidez cruza zero em '||(select current_rupture from vals)::text||'. Com os vestings já programados entrando apenas nas datas elegíveis, o horizonte de 2026 permanece coberto.'
                           else 'A liquidez permanece positiva até o fim de 2026 mesmo sem novos vestings.' end,
  'health_status',case when (select scheduled_rupture from vals) is not null then 'critical' when (select current_rupture from vals) is not null then 'attention' else 'ok' end,
  'horizons',(select j from hz),'risk_layers',(select j from newrisk),'actions',(select j from actions),
  'horizon_basis','bank cash + D0/D1 + already vested RSU; scheduled vestings are a separate future scenario and FGTS remains restricted',
  'semantic_note','Dashboard horizons now use the same operational cash and vesting logic as the daily Flow. Future awards are not treated as available today and are promoted only on vesting+settlement dates.',
  'guardrails',coalesce((select j->'guardrails' from base),'[]'::jsonb) || jsonb_build_array(
    'Dashboard and Flow share the same operational cash motor.',
    'RSU already vested today is separated from future awards scheduled to vest later.',
    'FGTS remains restricted and is not used to declare cash coverage.')
);
$function$;

CREATE OR REPLACE FUNCTION public.lts_dashboard_source_key_v240(p_user_id uuid)
RETURNS text LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO '' SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
SELECT md5(jsonb_build_object(
 'revision','canonical-cache-v240','date',current_date,
 'operational',public.lts_operational_source_key_v238(p_user_id),
 'bank',public.lts_open_finance_checking_positions_v1(p_user_id),
 'staging',(select md5(coalesce(string_agg(jsonb_build_array(id,resource_type,raw_hash,normalized_payload,posting_date,signed_amount,provider_deleted_at)::text,'|' order by id),'empty')) from public.lts_open_finance_staging where user_id=p_user_id),
 'decisions',(select md5(coalesce(string_agg(to_jsonb(d)::text,'|' order by source_table,source_ref),'empty')) from public.lts_v178_review_decision d where user_id=p_user_id),
 'assets',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.asset_positions a where user_id=p_user_id),
 'movements',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.lts_liquidity_movement a where user_id=p_user_id),
 'schedule',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.lts_future_liquidity_schedule a where user_id=p_user_id),
 'brokerage',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.lts_brokerage_position_snapshots a where user_id=p_user_id),
 'invoices',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.card_invoices a where user_id=p_user_id),
 'locks',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by lock_key),'empty')) from public.lts_validated_lock_registry a where superseded_at is null)
)::text)
$function$;
REVOKE ALL ON FUNCTION public.lts_dashboard_source_key_v240(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_dashboard_source_key_v240(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_dashboard_payload_key_v240(p_payload jsonb)
RETURNS text LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path TO ''
AS $function$
SELECT md5(jsonb_build_array(p_payload->'flow',p_payload->'planning',p_payload->'planning_executive',p_payload->'planning_ladder',p_payload->'dashboard',p_payload->'wealth_executive',p_payload->'updates',p_payload->'card_classification_review',p_payload->'semantic_review')::text)
$function$;
REVOKE ALL ON FUNCTION public.lts_dashboard_payload_key_v240(jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_dashboard_payload_key_v240(jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_updates_current_sources_v240(p_user_id uuid)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path TO '' SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH base AS MATERIALIZED (select public.lts_updates_fix86plus_v12(p_user_id) j),
positions AS MATERIALIZED (select public.lts_open_finance_checking_positions_v1(p_user_id) j),
kept AS (select x from base,lateral jsonb_array_elements(base.j->'items') x
 where NOT (x->>'maintenance_kind'='bank_statement' and exists(
  select 1 from positions,lateral jsonb_array_elements(positions.j) p
  where (p->>'as_of')::timestamptz::date=current_date and
   x->>'id'=case p->>'bank' when 'Itaú' then 'maintenance_bank_ita_' when 'Bradesco' then 'maintenance_bank_bradesco' when 'C6' then 'maintenance_bank_c6' end))),
pending AS (select x from jsonb_array_elements(public.lts_pending_projections_v233(p_user_id)) x),
items AS (select x from kept union all select jsonb_build_object(
 'id','pending_projection_'||coalesce(x->>'source_ref',x->>'id'),'type','projection_payment_review',
 'title','Confirmar previsão · '||coalesce(x->>'description','Pagamento'),
 'detail','Classificação conhecida; o pagamento desta obrigação ainda requer correspondência documental.',
 'status','needs_confirmation','priority',1,'destination','Atualizações',
 'source_ref',x->'source_ref','category',x->'category','amount',x->'signed_amount','event_date',x->'event_date') from pending),
summary AS (select coalesce(jsonb_agg(x order by coalesce((x->>'priority')::int,9),x->>'id'),'[]') j,
 count(*) total,count(*) filter(where x->>'status' not in ('informational','guarded','resolved','current')) actionable,
 count(*) filter(where x->>'status' not in ('informational','guarded','resolved','current') and (x->>'priority')::int=1) urgent from items)
select base.j||jsonb_build_object('version','updates-v240-current-source-evidence','items',summary.j,
 'pending_count',summary.total,'actionable_count',summary.actionable,'urgent_count',summary.urgent,
 'current_bank_evidence',positions.j) from base,summary,positions
$function$;
REVOKE ALL ON FUNCTION public.lts_updates_current_sources_v240(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_updates_current_sources_v240(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_apply_current_liquidity_anchor_v1(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE c record; k text; cached_key text; f jsonb; flow jsonb; pe jsonb; dashboard jsonb; ladder jsonb; w jsonb; updates jsonb; payload jsonb; pending int; pending_rows jsonb; today_day jsonb; cockpit jsonb; horizon date:=(current_date+interval '12 months')::date;
BEGIN
 select * into c from public.lts_product_read_cache where user_id=p_user_id for update;
 if not found then raise exception 'product cache unavailable'; end if;
 k:=public.lts_dashboard_source_key_v240(p_user_id);
 cached_key:=public.lts_dashboard_payload_key_v240(c.payload);
 if c.payload#>>'{canonical_summary,source_key}'=k and c.payload#>>'{canonical_summary,payload_key}'=cached_key then
  return jsonb_build_object('ok',true,'version','canonical-cache-v240','cache_hit',true);
 end if;
 f:=public.lts_flow_cache_core_v240(p_user_id,current_date,horizon)->'flow';
 flow:=jsonb_build_object('version','canonical-flow-v240-cache','from',current_date,'to',horizon,
  'days',coalesce(f#>'{current_future,days}','[]'),'events',coalesce(f#>'{current_future,events}','[]'),
  'observed_bank_movements',f->'observed_bank_movements','projected_operational_anchor',f->'projected_operational_anchor');
 select x into today_day from jsonb_array_elements(flow->'days') x where x->>'date'=current_date::text;
 if today_day is null then raise exception 'canonical current flow day unavailable'; end if;
 pe:=public.lts_planning_executive_from_flow_v1(p_user_id,current_date,horizon,flow);
 dashboard:=public.lts_dashboard_executive_from_flow_v1(p_user_id,current_date,flow);
 ladder:=jsonb_build_object('version','planning-ladder-v240-canonical','from',pe#>'{period,from}','to',pe#>'{period,to}',
  'flow_basis','canonical_operational_flow_v240','layers',pe->'layers','first_real_gap_date',pe#>'{summary,first_real_gap_date}',
  'gap_episodes',pe->'gap_episodes','fgts_first_negative_date',pe#>'{summary,first_negative_even_with_fgts}','fgts_access',pe->'fgts_access');
 w:=public.lts_wealth_executive_report_v5(p_user_id);
 updates:=public.lts_updates_current_sources_v240(p_user_id);
 select count(*),coalesce(jsonb_agg(to_jsonb(r) order by r.event_date desc,r.source_ref),'[]'::jsonb) into pending,pending_rows from public.lts_v229_review_rows(p_user_id,date '2013-10-10',current_date) r where r.identity_status='pending';
 payload:=c.payload||jsonb_build_object('flow',flow,'planning',public.lts_cashflow_scenarios_from_flow_v1(p_user_id,current_date,make_date(extract(year from current_date)::int,12,31),flow),
  'planning_executive',pe,'planning_ladder',ladder,'dashboard',dashboard,'wealth_executive',w,'updates',updates,
  'card_classification_review',jsonb_build_object('version','canonical-review-v229','pending_groups',pending,'pending_lines',pending,'items',pending_rows,'source_contract','canonical review queue'),
  'semantic_review',jsonb_build_object('version','canonical-review-v229','pending_groups',0,'items','[]'::jsonb,'source_contract','already counted once in canonical review queue'));
 payload:=payload||jsonb_build_object('canonical_summary',jsonb_build_object('version','v240','as_of',current_date,'source_key',k,
  'payload_key',public.lts_dashboard_payload_key_v240(payload),'financial_fact_changed',false));
 update public.lts_product_read_cache set payload=payload,refreshed_at=now(),source='canonical_flow_current_sources_v240' where user_id=p_user_id;
 cockpit:=public.lts_refresh_dashboard_cockpit_v2(p_user_id);
 return jsonb_build_object('ok',true,'version','canonical-cache-v240','cache_hit',false,'classification_pending',pending,
  'target_bank_cash',today_day#>'{fix86_columns,saldo_final}','source_key',k,'horizon',horizon,'financial_fact_changed',false);
END $function$;

CREATE OR REPLACE FUNCTION public.lts_refresh_product_read_cache_operational_v5(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
BEGIN
 RETURN public.lts_apply_current_liquidity_anchor_v1(p_user_id);
END $function$;

CREATE OR REPLACE FUNCTION public.lts_browser_dashboard_cockpit_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  u uuid;
  c record;
  pc timestamptz;
  j jsonb;
  w jsonb;
  v_had_cache boolean:=false;
  v_refreshed boolean:=false;
begin
  u:=public.lts_browser_assert_user_v1();

  perform public.lts_apply_current_liquidity_anchor_v1(u);

  select refreshed_at,payload->'wealth_executive'
  into pc,w
  from public.lts_product_read_cache
  where user_id=u;

  select * into c
  from public.lts_dashboard_cockpit_cache
  where user_id=u;
  v_had_cache:=found;

  if not v_had_cache
     or c.as_of<>current_date
     or c.source_product_refreshed_at is distinct from pc then
    j:=public.lts_refresh_dashboard_cockpit_v1(u);
    v_refreshed:=true;
  else
    j:=c.payload;
  end if;

  -- Prefer the already-reconciled canonical product cache. Only recompute the
  -- expensive wealth report when the cache is absent or predates the current
  -- effective-position reconciliation contract.
  if w is null
     or coalesce(w->>'reconciliation_version','')<>'wealth-summary-current-effective-v240' then
    w:=public.lts_wealth_executive_report_v5(u);
  end if;

  j:=jsonb_set(
    j,
    '{wealth}',
    coalesce(j->'wealth','{}'::jsonb) || jsonb_build_object(
      'net_worth_central',w#>'{summary,net_worth_central}',
      'known_debt_total',w#>'{summary,known_debt_total}',
      'assets_central',w#>'{summary,assets_central}',
      'distribution',coalesce(w->'distribution','[]'::jsonb),
      'reconciliation_version',w->'reconciliation_version'
    ),
    true
  );

  j:=jsonb_set(j,'{work,top_actions}',public.lts_dashboard_cockpit_top_actions_v1(u),true);

  if nullif(j#>>'{planning_audited,first_negative_date}','') is null
     and nullif(j#>>'{planning_audited,first_uncovered_gap_date}','') is not null then
    j:=jsonb_set(
      j,
      '{planning_audited,first_negative_date}',
      j#>'{planning_audited,first_uncovered_gap_date}',
      true
    );
  end if;

  -- Avoid an unnecessary write on every browser read. A refreshed cockpit is
  -- already persisted by the refresh routine; otherwise persist only a real
  -- overlay change (for example a newly available reconciliation field).
  if not v_refreshed and v_had_cache and c.payload is distinct from j then
    update public.lts_dashboard_cockpit_cache
    set payload=j
    where user_id=u;
  end if;

  return j;
end
$function$;
