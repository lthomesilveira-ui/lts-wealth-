-- Use the reviewed documentary anchor and only later recorded bank↔asset legs.
CREATE OR REPLACE FUNCTION public.lts_cofrinho_effective_locked_v245(p_user_id uuid,p_date date)
RETURNS numeric LANGUAGE sql STABLE SET search_path='' AS $fn$
 WITH anchor AS (
  SELECT (canonical_value->>'amount')::numeric amount,(canonical_value->>'as_of')::date dt
  FROM public.lts_validated_lock_registry
  WHERE lock_key LIKE 'itau_cofrinho_%' AND superseded_at IS NULL
   AND (canonical_value->>'as_of')::date<=p_date
  ORDER BY (canonical_value->>'as_of')::date DESC LIMIT 1
 )
 SELECT amount+coalesce((SELECT sum(m.asset_delta_brl)
 FROM public.lts_liquidity_movement m JOIN public.asset_positions a ON a.id=m.asset_position_id AND a.user_id=m.user_id
 WHERE m.user_id=p_user_id AND m.status='active' AND a.asset_name='Cofrinho Itaú'
 AND a.asset_type='cash_investment' AND m.event_date>anchor.dt AND m.event_date<=p_date),0)
 FROM anchor;
$fn$;
REVOKE ALL ON FUNCTION public.lts_cofrinho_effective_locked_v245(uuid,date) FROM PUBLIC,anon,authenticated;


CREATE OR REPLACE FUNCTION public.lts_internal_transfer_legs_fix86_v1(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source_ref text, confidence text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
with raw as (
  select eu.id,
         (eu.dados->>'dia')::date event_date,
         case when eu.dados->>'conta'='Itau' then 'Itaú' else eu.dados->>'conta' end account,
         coalesce(eu.dados->>'desc','Transferência própria') description,
         case when lower(coalesce(eu.dados->>'efeito',''))='saida' then -abs(coalesce((eu.dados->>'valor')::numeric,0))
              else abs(coalesce((eu.dados->>'valor')::numeric,0)) end signed_amount,
         'evento_usuario:'||eu.id source_ref,
         coalesce((eu.dados->>'transferenciaPropria')::boolean,false)
           or lower(coalesce(eu.dados->>'natureza','')) in ('transferencia','transferência','transferência própria','transferencia propria')
           or (eu.dados ? 'grupoId' and lower(coalesce(eu.dados->>'tipo',''))='transferencia') explicit_transfer,
         lower(coalesce(eu.dados->>'desc','')) description_lc,
         eu.dados
  from public.evento_usuario eu
  where eu.usuario_id=p_user_id and eu.dados ? 'dia'
    and (eu.dados->>'dia')::date between p_from and p_to
    and eu.dados->>'conta' in ('Itau','Itaú','Bradesco','C6')
    and coalesce((eu.dados->>'valor')::numeric,0)<>0
), inferred as (
  select r.* from raw r
  where not r.explicit_transfer
    and (r.description_lc like '%pix%' or lower(coalesce(r.dados->>'tipo',''))='manual')
    and exists (
      select 1 from raw e where e.explicit_transfer and e.id<>r.id and e.account<>r.account
        and abs(e.signed_amount)=abs(r.signed_amount) and sign(e.signed_amount)=-sign(r.signed_amount)
        and abs(e.event_date-r.event_date)<=1
    )
), eu_legs as (
  select event_date,account,description,signed_amount,source_ref,
         case when explicit_transfer then 'documented_internal_transfer' else 'paired_internal_transfer' end confidence
  from raw where explicit_transfer
  union all
  select event_date,account,description,signed_amount,source_ref,'paired_internal_transfer' confidence from inferred
), latest as (
  select distinct on (o.target_event_id) o.target_event_id,o.operation,o.payload,o.op_seq
  from public.lts_flow_event_operation o
  where o.user_id=p_user_id and o.active
  order by o.target_event_id,o.op_seq desc
), fe_effective as (
  select
    coalesce(nullif(l.payload->>'event_date','')::date,fe.event_date) event_date,
    coalesce(nullif(trim(l.payload->>'account'),''),case when a.institution='Itau' then 'Itaú' else a.institution end) account,
    coalesce(nullif(trim(l.payload->>'description'),''),fe.description_normalized,fe.description_raw,'Transferência própria') description,
    case when fe.amount<0 then -abs(coalesce(nullif(l.payload->>'amount','')::numeric,fe.amount))
         else abs(coalesce(nullif(l.payload->>'amount','')::numeric,fe.amount)) end signed_amount,
    'financial_events:'||fe.id::text source_ref,
    case when fe.source='manual_transfer_reviewed' and nullif(fe.metadata->>'transfer_group','') is not null
         then 'user_flow_editable' else 'documented_current_internal_transfer' end confidence,
    l.operation
  from public.financial_events fe
  left join public.accounts a on a.id=fe.account_id and a.user_id=fe.user_id
  left join latest l on l.target_event_id=fe.id
  where fe.user_id=p_user_id and coalesce(fe.is_suppressed,false)=false
    and (coalesce(fe.is_internal_transfer,false)=true or lower(coalesce(fe.nature,''))='transfer')
    -- Dedicated liquidity events already contain this bank leg.
    and not exists(select 1 from public.lts_liquidity_movement m where m.user_id=fe.user_id and m.bank_event_id=fe.id and m.status='active')
), fe_legs as (
  select event_date,account,description,signed_amount,source_ref,confidence
  from fe_effective
  where coalesce(operation,'')<>'cancel' and event_date between p_from and p_to
    and account in ('Itau','Itaú','Bradesco','C6')
)
select * from eu_legs
union all
select f.* from fe_legs f
where not exists (
  select 1 from eu_legs e
  where e.event_date=f.event_date and e.account=f.account and e.signed_amount=f.signed_amount
);
$function$
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

CREATE OR REPLACE FUNCTION public.lts_dashboard_cash_ladder_from_flow_v229(p_user_id uuid, p_from date, p_to date, p_flow jsonb)
 RETURNS TABLE(flow_date date, operational_cash numeric, d01_resource numeric, balance_after_d01 numeric, rsu_vested_today numeric, rsu_vested_scheduled numeric, balance_no_new_vesting numeric, balance_with_scheduled_vesting numeric, fgts_projected numeric, balance_with_fgts_projected numeric)
 LANGUAGE sql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with base as (
 select (d->>'date')::date dt,(d#>>'{fix86_columns,saldo_final}')::numeric bank_close,(d#>>'{fix86_columns,liq_d0_1_recurso}')::numeric d01_resource
 from jsonb_array_elements(coalesce(p_flow->'days','[]'::jsonb)) d
), lay as (
 select b.dt flow_date,(select effective_value_brl from public.lts_asset_position_effective_v1(p_user_id,current_date) where asset_type='FGTS' order by documented_as_of desc,asset_position_id desc limit 1) fgts_value,
 coalesce((select sum(case when lower(s.asset_type) like '%cash%' then coalesce(s.net_value_brl,s.gross_value_brl) else coalesce(s.gross_value_brl,s.net_value_brl) end)
  from public.lts_future_liquidity_schedule s where s.user_id=p_user_id and s.active
  and (upper(trim(s.asset_type))='RSU' or lower(s.asset_type) like '%cash%')
  and s.eligibility_date+s.settlement_days<=b.dt),0)::numeric vested_rsu_value
 from base b join jsonb_array_elements(p_flow->'days') d on (d->>'date')::date=b.dt
),
params as (
 select (public.lts_open_finance_current_bank_position_v1(p_user_id)->>'bank_cash')::numeric bank_anchor,
 public.lts_cofrinho_effective_locked_v245(p_user_id,current_date) d0_anchor,
 coalesce((select (canonical_value->>'total_available_brl')::numeric from public.lts_validated_lock_registry where lock_key='morgan_available_20260922' and superseded_at is null),0) rsu_anchor
), anchor as (
 select (select bank_anchor from params)-coalesce((select bank_close from base where dt=current_date),(select bank_anchor from params)) bank_delta,
 (select d0_anchor from params)-coalesce((select d01_resource from base where dt=current_date),(select d0_anchor from params)) d0_delta,
 (select rsu_anchor from params)-coalesce((select vested_rsu_value from lay where flow_date=current_date),(select rsu_anchor from params)) rsu_delta
)
select b.dt,b.bank_close+a.bank_delta,b.d01_resource+a.d0_delta,b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta,
p.rsu_anchor,l.vested_rsu_value+a.rsu_delta,
b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta+p.rsu_anchor,
b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta+l.vested_rsu_value+a.rsu_delta,
l.fgts_value,
b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta+l.vested_rsu_value+a.rsu_delta+l.fgts_value
from base b join lay l on l.flow_date=b.dt cross join params p cross join anchor a order by b.dt
$function$
;

CREATE OR REPLACE FUNCTION public.lts_dashboard_cash_ladder_from_flow_v2(p_user_id uuid, p_from date, p_to date, p_flow jsonb)
 RETURNS TABLE(flow_date date, operational_cash numeric, d01_resource numeric, balance_after_d01 numeric, rsu_vested_today numeric, rsu_vested_scheduled numeric, balance_no_new_vesting numeric, balance_with_scheduled_vesting numeric, fgts_projected numeric, balance_with_fgts_projected numeric)
 LANGUAGE sql
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with base as (
 select (d->>'date')::date dt,(d#>>'{fix86_columns,saldo_final}')::numeric bank_close,(d#>>'{fix86_columns,liq_d0_1_recurso}')::numeric d01_resource
 from jsonb_array_elements(coalesce(p_flow->'days','[]'::jsonb)) d
), lay as (select * from public.lts_flow_dynamic_layers_v1(p_user_id,p_from,p_to)),
params as (
 select (public.lts_open_finance_current_bank_position_v1(p_user_id)->>'bank_cash')::numeric bank_anchor,
 public.lts_cofrinho_effective_locked_v245(p_user_id,current_date) d0_anchor,
 coalesce((select (canonical_value->>'total_available_brl')::numeric from public.lts_validated_lock_registry where lock_key='morgan_available_20260922' and superseded_at is null),0) rsu_anchor
), anchor as (
 select (select bank_anchor from params)-coalesce((select bank_close from base where dt=current_date),(select bank_anchor from params)) bank_delta,
 (select d0_anchor from params)-coalesce((select d01_resource from base where dt=current_date),(select d0_anchor from params)) d0_delta,
 (select rsu_anchor from params)-coalesce((select vested_rsu_value from lay where flow_date=current_date),(select rsu_anchor from params)) rsu_delta
)
select b.dt,b.bank_close+a.bank_delta,b.d01_resource+a.d0_delta,b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta,
p.rsu_anchor,l.vested_rsu_value+a.rsu_delta,
b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta+p.rsu_anchor,
b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta+l.vested_rsu_value+a.rsu_delta,
l.fgts_value,
b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta+l.vested_rsu_value+a.rsu_delta+l.fgts_value
from base b join lay l on l.flow_date=b.dt cross join params p cross join anchor a order by b.dt
$function$
;

CREATE OR REPLACE FUNCTION public.lts_browser_cash_today_v178()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE
 u uuid:=public.lts_browser_assert_user_v1(); positions jsonb; accounts jsonb; cols jsonb; row_today jsonb;
 bank numeric; d0 numeric; vested numeric; fgts numeric;
 d0_date date; vested_date date; fgts_date date;
BEGIN
 positions:=public.lts_open_finance_current_bank_position_v1(u);
 bank:=(positions->>'bank_cash')::numeric;
 IF (SELECT count(DISTINCT institution_code) FROM public.lts_open_finance_staging
     WHERE user_id=u AND resource_type='balance' AND provider_deleted_at IS NULL
     AND signed_amount IS NOT NULL AND institution_code IN ('341','237','336'))<>3
 THEN RAISE EXCEPTION 'canonical bank positions incomplete'; END IF;
 SELECT (canonical_value->>'amount')::numeric,(canonical_value->>'as_of')::date INTO d0,d0_date
 FROM public.lts_validated_lock_registry WHERE lock_key='itau_cofrinho_20260926' AND superseded_at IS NULL;
 d0:=public.lts_cofrinho_effective_locked_v245(u,current_date);
 SELECT (canonical_value->>'total_available_brl')::numeric,(canonical_value->>'as_of')::date INTO vested,vested_date
 FROM public.lts_validated_lock_registry WHERE lock_key='morgan_available_20260922' AND superseded_at IS NULL;
 SELECT value_brl,as_of_date INTO fgts,fgts_date FROM public.asset_positions
 WHERE user_id=u AND asset_type='FGTS' ORDER BY as_of_date DESC LIMIT 1;
 IF bank IS NULL OR d0 IS NULL OR vested IS NULL OR fgts IS NULL
 THEN RAISE EXCEPTION 'canonical current liquidity incomplete'; END IF;
 SELECT jsonb_object_agg(CASE a->>'institution_code' WHEN '341' THEN 'Itaú'
 WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END,
 jsonb_build_object('balance',a->'balance','net',NULL)) INTO accounts
 FROM jsonb_array_elements(positions->'accounts') a;
 -- A position is not a reconstructed bank statement: no made-up opening/entries/exits.
 cols:=jsonb_build_object(
  'saldo_anterior',NULL,'entradas',NULL,'saidas',NULL,'saldo_final',bank,
  'liq_d0_1_recurso',d0,'liq_d0_1',bank+d0,'saldo_apos_d0_1',bank+d0,
  'rsus_vested',vested,'saldo_apos_rsu',bank+d0+vested,'fgts',fgts,
  'saldo_apos_fgts',bank+d0+vested+fgts,'disponivel_total',bank+d0+vested,
  'posicao_antes_rsus',bank+d0,'posicao_curto_prazo',bank+d0+vested,
  'morgan_available_total_brl',vested,'cash_semantics','current_position_snapshot');
 row_today:=accounts||jsonb_build_object('date',current_date,'is_today',true,'position_only',true,
  'Consolidado',jsonb_build_object('bank_balance',bank,'economic_net',NULL,'unassigned_net',NULL),
  'summary',jsonb_build_object('Consolidado',jsonb_build_object('entries',NULL,'exits',NULL)),
  'fix86_columns',cols);
 RETURN jsonb_build_object('version','cash-today-v179-current-canonical','as_of',current_date,
  'computed_at',clock_timestamp(),'status','complete','cash',bank,'d0',d0,
  'brokerage_available',vested,'fgts',fgts,'available_total',round(bank+d0+vested,2),
  'day',row_today,'basis','current_open_finance_bank_plus_validated_cofrinho_and_morgan_locks',
  'position_dates',jsonb_build_object('d0',d0_date,'brokerage',vested_date,'fgts',fgts_date),
  'reader_revision','v230-independent-current-position');
END $function$
;

UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
DELETE FROM public.lts_v229_read_cache WHERE user_id IS NOT NULL;
CREATE OR REPLACE FUNCTION public.lts_current_flow_v229(p_user_id uuid, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  raw jsonb; position jsonb; first_day jsonb; days jsonb; events jsonb;
  delta_i numeric; delta_b numeric; delta_c numeric;
begin
  if p_from is null or p_to is null or p_from>p_to or p_from<current_date or p_to-current_date>12000 then
    raise exception 'invalid current/future range';
  end if;
  raw:=case when p_to+30<=current_date+1800 then public.lts_flow_future_read_slice_v9(p_user_id,current_date,p_to) else public.lts_daily_flow_fix86_v20(p_user_id,current_date,p_to) end;
  position:=public.lts_open_finance_current_bank_position_v1(p_user_id);
  select d into first_day from jsonb_array_elements(raw->'days') d where d->>'date'=current_date::text;
  if first_day is null then raise exception 'current anchor day unavailable'; end if;
  select (a->>'balance')::numeric-(first_day#>>'{Itaú,balance}')::numeric into delta_i from jsonb_array_elements(position->'accounts') a where a->>'institution_code'='341';
  select (a->>'balance')::numeric-(first_day#>>'{Bradesco,balance}')::numeric into delta_b from jsonb_array_elements(position->'accounts') a where a->>'institution_code'='237';
  select (a->>'balance')::numeric-(first_day#>>'{C6,balance}')::numeric into delta_c from jsonb_array_elements(position->'accounts') a where a->>'institution_code'='336';
  if delta_i is null or delta_b is null or delta_c is null then raise exception 'current bank anchors incomplete'; end if;
  with layers as materialized (
    select * from public.lts_dashboard_cash_ladder_from_flow_v229(p_user_id,current_date,p_to,raw)
  ), adjusted as (
    select (d->>'date')::date dt,
      d || jsonb_build_object(
        'Itaú',(d->'Itaú')||jsonb_build_object('balance',(d#>>'{Itaú,balance}')::numeric+delta_i,'opening_balance',coalesce((d#>>'{Itaú,opening_balance}')::numeric,(d#>>'{Itaú,balance}')::numeric-(d#>>'{Itaú,net}')::numeric)+delta_i),
        'Bradesco',(d->'Bradesco')||jsonb_build_object('balance',(d#>>'{Bradesco,balance}')::numeric+delta_b,'opening_balance',coalesce((d#>>'{Bradesco,opening_balance}')::numeric,(d#>>'{Bradesco,balance}')::numeric-(d#>>'{Bradesco,net}')::numeric)+delta_b),
        'C6',(d->'C6')||jsonb_build_object('balance',(d#>>'{C6,balance}')::numeric+delta_c,'opening_balance',coalesce((d#>>'{C6,opening_balance}')::numeric,(d#>>'{C6,balance}')::numeric-(d#>>'{C6,net}')::numeric)+delta_c),
        'Consolidado',(d->'Consolidado')||jsonb_build_object('bank_balance',l.operational_cash),
        'fix86_columns',(d->'fix86_columns')||jsonb_build_object(
          'saldo_anterior',(d#>>'{fix86_columns,saldo_anterior}')::numeric+l.operational_cash-(d#>>'{fix86_columns,saldo_final}')::numeric,
          'saldo_final',l.operational_cash,
          'liq_d0_1_recurso',l.d01_resource,
          'rsus_vested',l.rsu_vested_scheduled,
          'fgts',l.fgts_projected,
          'saldo_apos_d0_1',l.balance_after_d01,
          'saldo_apos_rsu',l.balance_with_scheduled_vesting,
          'saldo_apos_fgts',l.balance_with_fgts_projected,
          'liq_d0_1',l.balance_after_d01,
          'posicao_antes_rsus',l.balance_after_d01,
          'disponivel_total',l.balance_with_scheduled_vesting,
          'posicao_curto_prazo',l.balance_with_scheduled_vesting
        )
      ) value
    from jsonb_array_elements(raw->'days') d join layers l on l.flow_date=(d->>'date')::date
    where (d->>'date')::date between p_from and p_to
  ) select jsonb_agg(value order by dt) into days from adjusted;
  if jsonb_array_length(days)<>p_to-p_from+1 then raise exception 'incomplete current/future days'; end if;
  select coalesce(jsonb_agg(e order by e->>'event_date',e->>'source_ref'),'[]'::jsonb) into events
    from jsonb_array_elements(coalesce(raw->'events','[]'::jsonb)) e
    where (e->>'event_date')::date between p_from and p_to;
  return raw||jsonb_build_object('from',p_from,'to',p_to,'days',days,'events',events,
    'version','daily-flow-v225-current-anchors','current_anchor_date',current_date);
end
$function$
;
