BEGIN;SET LOCAL TimeZone='America/Sao_Paulo';SET LOCAL jit=off;SET LOCAL statement_timeout='90s';
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
CREATE TEMP TABLE crossover_v256(response jsonb,ms numeric) ON COMMIT DROP;
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
DO $candidate$ DECLARE t timestamptz:=clock_timestamp();j jsonb;BEGIN j:=public.lts_browser_flow_v242('2026-01-01','2027-12-31');INSERT INTO crossover_v256 VALUES(j,round(extract(epoch from clock_timestamp()-t)*1000,3));END $candidate$;
CREATE OR REPLACE FUNCTION public.lts_flow_observed_position_guard_v1(p_flow jsonb, p_today date)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE
 f jsonb:=p_flow; d jsonb; old_day jsonb; days jsonb:='[]'; bank_name text;
 bank_row jsonb; observed numeric; projection numeric; difference numeric;
 delta numeric:=0; total_delta numeric; gaps jsonb; c jsonb; cash_field text;
 affected boolean; guard_metadata jsonb;
BEGIN
 IF p_flow IS NULL OR p_today IS NULL THEN RETURN p_flow; END IF;
 FOR d IN SELECT x FROM jsonb_array_elements(coalesce(f#>'{current_future,days}','[]')) x LOOP
  IF d->>'date'=p_today::text AND d#>>'{cash_position_guard,version}' IS NULL THEN
   old_day:=d; total_delta:=0; gaps:='{}'; affected:=false;
   FOREACH bank_name IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
    bank_row:=d->bank_name;
    IF bank_row->>'balance_basis'='observed_bank_position_and_recent_movements'
      AND bank_row->>'observed_balance' IS NOT NULL
      AND bank_row->>'balance' IS NOT NULL
      AND bank_row->>'unposted_projection_net' IS NOT NULL
      AND abs(coalesce((bank_row->>'reconciliation_gap')::numeric,0))>.005 THEN
     observed:=(bank_row->>'observed_balance')::numeric;
     projection:=(bank_row->>'unposted_projection_net')::numeric;
     difference:=(bank_row->>'reconciliation_gap')::numeric;
     delta:=observed+projection-(bank_row->>'balance')::numeric;
     total_delta:=total_delta+delta; affected:=true;
     gaps:=gaps||jsonb_build_object(bank_name,difference);
     bank_row:=bank_row||jsonb_build_object(
      'balance',observed+projection,'operational_balance',observed+projection,
      'balance_certified',false,'movements_complete',false,
      'known_movements_net',bank_row->'net','net',null,'operational_net',null,
      'opening_balance_basis','unverified_ledger_reconstruction_not_observed',
      'cash_position_guard',jsonb_build_object('version','observed-position-not-reconciled-ledger-v1',
       'ledger_reconstruction',d->bank_name,'position_delta',delta,
       'unexplained_balance_difference',difference,'difference_transaction_created',false,
       'difference_event_date',null,'projection_net_preserved',projection));
     d:=jsonb_set(d,ARRAY[bank_name],bank_row);
    END IF;
   END LOOP;
   IF affected THEN
    c:=d->'fix86_columns';
    -- These fields are today's cash plus separate same-day liquidity resources.
    -- liq_d30 is a look-ahead balance, already anchored by the underlying reader.
    FOREACH cash_field IN ARRAY ARRAY['saldo_final','saldo_final_operacional',
     'saldo_apos_d0_1','liq_d0_1','posicao_antes_rsus','saldo_apos_rsu',
     'disponivel_total','posicao_curto_prazo','saldo_apos_fgts','posicao_economica_total'] LOOP
     IF c->>cash_field IS NOT NULL THEN
      c:=jsonb_set(c,ARRAY[cash_field],to_jsonb((c->>cash_field)::numeric+total_delta));
     END IF;
    END LOOP;
    c:=c||jsonb_build_object('entradas',null,'saidas',null,
     'entradas_operacionais',null,'saidas_operacionais',null,
     'opening_balance_basis','unverified_ledger_reconstruction_not_observed',
     'cash_projection_basis','observed_bank_position_plus_documented_unposted_today');
    guard_metadata:=jsonb_build_object('version','observed-position-not-reconciled-ledger-v1',
     'as_of',p_today,'unexplained_bank_differences',gaps,'position_delta',total_delta,
     'known_day_summary',old_day->'summary','known_day_arithmetic',old_day->'v170_cash_arithmetic',
     'previous_columns',old_day->'fix86_columns','financial_fact_changed',false,
     'difference_transaction_created',false,'difference_event_date',null);
    d:=d||jsonb_build_object('movements_complete',false,'cash_position_guard',guard_metadata,
     'fix86_columns',c,
     'Consolidado',(d->'Consolidado')||jsonb_build_object('bank_balance',c->'saldo_final',
      'known_movements_net',old_day#>'{Consolidado,net}','net',null,'economic_net',null,
      'balance_certified',false,'movements_complete',false),
     'summary',(d->'summary')||jsonb_build_object('entries',null,'exits',null,'net',null,
      'Consolidado',jsonb_build_object('entries',null,'exits',null)),
     'v170_cash_arithmetic',jsonb_build_object('version','observed-position-not-reconciled-ledger-v1',
      'balanced',null,'arithmetic_gap_brl',null,'status','awaiting_bank_movement_evidence',
      'unexplained_bank_differences',gaps,'financial_fact_changed',false));
    f:=f||jsonb_build_object('cash_position_guard',guard_metadata);
   END IF;
  END IF;
  days:=days||jsonb_build_array(d);
 END LOOP;
 IF f->'cash_position_guard' IS NULL THEN RETURN p_flow; END IF;
 RETURN jsonb_set(f,'{current_future,days}',days);
END $function$
;
CREATE OR REPLACE FUNCTION public.lts_browser_flow_pre_v238(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
DECLARE
 u uuid:=public.lts_browser_assert_user_v1(); anchors jsonb; positions jsonb; own_global_return boolean;
 lo date; result jsonb; f jsonb; events jsonb; recent jsonb; observed jsonb;
 s record; b text; a jsonb; e jsonb; matched jsonb; match_count int; added jsonb:='[]';
 d jsonb; dt date; c jsonb; outdays jsonb; part text; dayev jsonb;
 bal numeric; net numeric; fin numeric; inc numeric; outflow numeric; internal numeric;
 op_in numeric; op_out numeric; rsu numeric; d0 numeric; fgts numeric; gaps jsonb:='{}';
 out_day_rows jsonb[];
 pending_predictions jsonb:='[]'; morgan jsonb; cofrinho jsonb; asof date; asset_net numeric; gap_dates jsonb:='{}'; first_gap date; day_gap numeric;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_to-p_from>12000 THEN RAISE EXCEPTION 'invalid range'; END IF;
 SELECT coalesce(jsonb_agg(x),'[]'),min((x->>'date')::date) INTO anchors,lo FROM (
  SELECT DISTINCT ON (institution) jsonb_build_object('bank',institution,'date',metadata->>'balance_as_of','balance',(metadata->>'balance')::numeric) x
  FROM public.accounts WHERE user_id=u AND is_active AND metadata->>'evidence_sha256' IS NOT NULL
   AND institution IN ('Itaú','Bradesco','C6') AND (metadata->>'balance_as_of')::date<current_date
  ORDER BY institution,(metadata->>'balance_as_of')::date DESC
 ) q;
 IF lo IS NULL OR p_to<=lo OR p_from>current_date THEN RETURN public.lts_browser_flow_base_v229(p_from,p_to); END IF;
 -- A complete recent context makes balances independent of the selected range.
 result:=public.lts_browser_flow_base_v229(p_from,p_to); f:=result->'flow';
 events:=coalesce(f#>'{historical,events}','[]')||coalesce(f#>'{current_future,events}','[]');
 -- Read only movement rows for context, without rendering historical balances.
 -- Prefer the existing reader's rich event metadata inside the requested range.
 WITH candidates AS (
  SELECT x,0 priority FROM jsonb_array_elements(events) x
   WHERE (x->>'event_date')::date>lo AND (x->>'event_date')::date<=current_date
  UNION ALL
  SELECT x,1 FROM jsonb_array_elements(public.lts_flow_operational_read_v229(u,lo+1,current_date)) x
  UNION ALL
  SELECT jsonb_build_object('source','liquidity_movement','source_ref','financial_events:'||fe.id::text,
   'event_date',m.event_date,'account',a.institution,'description',m.description,'signed_amount',m.bank_delta_brl,
   'direction',CASE WHEN m.bank_delta_brl<0 THEN 'saida' ELSE 'entrada' END,
   'confidence','documented_current_internal_transfer','internal_transfer',true,'asset_movement',true,
   'is_asset_movement',true,'excluded',true,'excluded_from_spend',true,
   'liquidity_movement_id',m.id,'category','Movimentação de liquidez'),0
  FROM public.lts_liquidity_movement m JOIN public.financial_events fe ON fe.id=m.bank_event_id AND fe.user_id=m.user_id
  JOIN public.accounts a ON a.id=m.account_id AND a.user_id=m.user_id
  JOIN public.asset_positions ap ON ap.id=m.asset_position_id AND ap.user_id=m.user_id
  WHERE m.user_id=u AND m.status='active' AND NOT fe.is_suppressed
   AND ap.asset_name='Cofrinho Itaú' AND ap.asset_type='cash_investment'
   AND m.event_date>greatest(lo,(SELECT max((canonical_value->>'as_of')::date)
     FROM public.lts_validated_lock_registry WHERE lock_key LIKE 'itau_cofrinho_%' AND superseded_at IS NULL))
   AND m.event_date<=current_date
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
    OR x->>'open_finance_id'=s.id::text OR public.lts_documented_bank_event_identity_v242(u,s.id,x));
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
  outdays:='[]';out_day_rows:=ARRAY[]::jsonb[];
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
    IF dt>=(cofrinho->>'as_of')::date THEN d0:=public.lts_cofrinho_effective_locked_v245(u,dt);
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
   out_day_rows:=array_append(out_day_rows,d);
  END LOOP;
  outdays:=to_jsonb(out_day_rows);
  f:=jsonb_set(f,ARRAY[part],coalesce(f->part,'{}')||jsonb_build_object('days',outdays,'events',coalesce((SELECT jsonb_agg(x ORDER BY x->>'event_date',x->>'source_ref')
   FROM jsonb_array_elements(events) x WHERE (x->>'event_date')::date BETWEEN p_from AND p_to
    AND case when part='historical' then (x->>'event_date')::date<current_date else (x->>'event_date')::date>=current_date end),'[]')));
 END LOOP;
 f:=f||jsonb_build_object('from',p_from,'to',p_to,'observed_bank_movements',jsonb_build_object('version','v229','added_count',jsonb_array_length(added),'documentary_gaps',gaps,'position_gap_dates',gap_dates,'pending_projections',pending_predictions,
  'matched_projections',coalesce((SELECT jsonb_agg(to_jsonb(m)) FROM public.lts_payroll_bank_matches_v231(u) m),'[]'::jsonb)));

 RETURN result||jsonb_build_object('flow',public.lts_flow_review_overlay_v229(u,f),'version','browser-flow-v229-consistent-evidence','reader_revision','v231-forward-realized-ledger');
END $function$
;
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;
DO $original$ DECLARE t timestamptz:=clock_timestamp();j jsonb;ms numeric;BEGIN
 j:=public.lts_browser_flow_v242('2026-01-01','2027-12-31');ms:=round(extract(epoch from clock_timestamp()-t)*1000,3);
 IF j::text IS DISTINCT FROM (SELECT response::text FROM crossover_v256) THEN RAISE EXCEPTION 'V256_CROSSOVER_CHANGED';END IF;
 PERFORM set_config('lts.v256_cross',jsonb_build_object('status','PASS','order','candidate_then_original','candidate_ms',(SELECT c.ms FROM crossover_v256 c),'original_ms',ms,'full_text_exact',true,'digest',md5(j::text),'physical_buffers_warm',true)::text,true);
END $original$;
SELECT current_setting('lts.v256_cross')::jsonb receipt;
ROLLBACK;