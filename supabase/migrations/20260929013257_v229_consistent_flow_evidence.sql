-- Source evidence is private; this migration contains no customer financial records.
CREATE TABLE public.lts_v229_documentary_match (
 user_id uuid NOT NULL REFERENCES auth.users(id), staging_id uuid NOT NULL REFERENCES public.lts_open_finance_staging(id),
 source_ref text NOT NULL, canonical_date date NOT NULL, bank text NOT NULL, signed_amount numeric NOT NULL,
 evidence jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(user_id,staging_id)
);
ALTER TABLE public.lts_v229_documentary_match ENABLE ROW LEVEL SECURITY;
CREATE POLICY own_evidence ON public.lts_v229_documentary_match FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
REVOKE ALL ON public.lts_v229_documentary_match FROM public,anon,authenticated;
GRANT SELECT ON public.lts_v229_documentary_match TO authenticated;
GRANT ALL ON public.lts_v229_documentary_match TO service_role;
CREATE TABLE public.lts_v229_read_cache (
 user_id uuid NOT NULL REFERENCES auth.users(id), kind text NOT NULL, as_of date NOT NULL,
 from_date date NOT NULL,to_date date NOT NULL,payload jsonb NOT NULL,refreshed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,kind,as_of,from_date,to_date)
);
ALTER TABLE public.lts_v229_read_cache ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_v229_read_cache FROM public,anon,authenticated;
GRANT ALL ON public.lts_v229_read_cache TO service_role;
-- Cache only established historical calculations. Live bank observations and decisions
-- are overlaid on every read. Source changes invalidate this disposable cache.
CREATE FUNCTION public.lts_v229_invalidate_read_cache() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN DELETE FROM public.lts_v229_read_cache; RETURN NULL; END $$;
REVOKE ALL ON FUNCTION public.lts_v229_invalidate_read_cache() FROM public,anon,authenticated;
DO $$ DECLARE t record; BEGIN
 FOR t IN SELECT DISTINCT table_name FROM information_schema.columns
 WHERE table_schema='public' AND column_name IN ('user_id','usuario_id')
 AND table_name NOT LIKE 'lts_v229_%' AND table_name NOT LIKE 'lts_open_finance_%'
 AND table_name NOT LIKE '%audit%' AND table_name NOT LIKE '%cache%' AND table_name NOT LIKE '%log%'
 AND table_name IN (SELECT tablename FROM pg_tables WHERE schemaname='public')
 LOOP EXECUTE format('CREATE TRIGGER lts_v229_invalidate AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v229_invalidate_read_cache()',t.table_name); END LOOP;
 IF EXISTS(SELECT 1 FROM pg_tables WHERE schemaname='public' AND tablename='lts_validated_lock_registry') THEN
  CREATE TRIGGER lts_v229_lock_invalidate AFTER INSERT OR UPDATE OR DELETE ON public.lts_validated_lock_registry FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v229_invalidate_read_cache();
 END IF;
END $$;

CREATE FUNCTION public.lts_flow_history_read_v229(p_from date,p_to date) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' AS $$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); j jsonb; hf date; ht date;
BEGIN
 SELECT payload INTO j FROM public.lts_v229_read_cache WHERE user_id=u AND kind='history' AND as_of=current_date AND from_date<=p_from AND to_date>=p_to ORDER BY refreshed_at DESC LIMIT 1;
 IF j IS NULL THEN
  hf:=p_from;ht:=p_to;
  j:=public.lts_browser_flow_v12(hf,ht)->'flow';
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload) VALUES(u,'history',current_date,hf,ht,j)
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,refreshed_at=now();
 END IF;
 RETURN j||jsonb_build_object('from',p_from,'to',p_to,'historical',(j->'historical')||jsonb_build_object(
  'days',coalesce((SELECT jsonb_agg(x ORDER BY x->>'date') FROM jsonb_array_elements(j#>'{historical,days}') x WHERE (x->>'date')::date BETWEEN p_from AND p_to),'[]'),
  'events',coalesce((SELECT jsonb_agg(x ORDER BY x->>'event_date') FROM jsonb_array_elements(j#>'{historical,events}') x WHERE (x->>'event_date')::date BETWEEN p_from AND p_to),'[]')));
END $$;
CREATE FUNCTION public.lts_flow_operational_read_v229(p_user_id uuid,p_from date,p_to date) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' AS $$
DECLARE j jsonb;
BEGIN
 SELECT payload INTO j FROM public.lts_v229_read_cache WHERE user_id=p_user_id AND kind='operational' AND as_of=current_date AND from_date<=p_from AND to_date>=p_to ORDER BY refreshed_at DESC LIMIT 1;
 IF j IS NULL THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x)||jsonb_build_object('account_attribution',x.account_assignment,'excluded',x.excluded_from_spend,'direction',CASE WHEN x.signed_amount<0 THEN 'saida' ELSE 'entrada' END)),'[]') INTO j FROM public.lts_flow_past_operational_v2(p_user_id,p_from,p_to) x;
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload) VALUES(p_user_id,'operational',current_date,p_from,p_to,j)
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,refreshed_at=now();
 END IF;
 RETURN coalesce((SELECT jsonb_agg(x) FROM jsonb_array_elements(j) x WHERE (x->>'event_date')::date BETWEEN p_from AND p_to),'[]');
END $$;
CREATE OR REPLACE FUNCTION public.lts_dashboard_cash_ladder_from_flow_v229(p_user_id uuid, p_from date, p_to date, p_flow jsonb)
 RETURNS TABLE(flow_date date, operational_cash numeric, d01_resource numeric, balance_after_d01 numeric, rsu_vested_today numeric, rsu_vested_scheduled numeric, balance_no_new_vesting numeric, balance_with_scheduled_vesting numeric, fgts_projected numeric, balance_with_fgts_projected numeric)
 LANGUAGE sql
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with base as (
 select (d->>'date')::date dt,(d#>>'{fix86_columns,saldo_final}')::numeric bank_close,(d#>>'{fix86_columns,liq_d0_1_recurso}')::numeric d01_resource
 from jsonb_array_elements(coalesce(p_flow->'days','[]'::jsonb)) d
), lay as (
 select b.dt flow_date,(d#>>'{fix86_columns,fgts}')::numeric fgts_value,
 coalesce((select sum(case when lower(s.asset_type) like '%cash%' then coalesce(s.net_value_brl,s.gross_value_brl) else coalesce(s.gross_value_brl,s.net_value_brl) end)
  from public.lts_future_liquidity_schedule s where s.user_id=p_user_id and s.active
  and (upper(trim(s.asset_type))='RSU' or lower(s.asset_type) like '%cash%')
  and s.eligibility_date+s.settlement_days<=b.dt),0)::numeric vested_rsu_value
 from base b join jsonb_array_elements(p_flow->'days') d on (d->>'date')::date=b.dt
),
params as (
 select (public.lts_open_finance_current_bank_position_v1(p_user_id)->>'bank_cash')::numeric bank_anchor,
 (select (canonical_value->>'amount')::numeric from public.lts_validated_lock_registry where lock_key='itau_cofrinho_20260926' and superseded_at is null) d0_anchor,
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
        'Itaú',(d->'Itaú')||jsonb_build_object('balance',(d#>>'{Itaú,balance}')::numeric+delta_i),
        'Bradesco',(d->'Bradesco')||jsonb_build_object('balance',(d#>>'{Bradesco,balance}')::numeric+delta_b),
        'C6',(d->'C6')||jsonb_build_object('balance',(d#>>'{C6,balance}')::numeric+delta_c),
        'Consolidado',(d->'Consolidado')||jsonb_build_object('bank_balance',l.operational_cash),
        'fix86_columns',(d->'fix86_columns')||jsonb_build_object(
          'saldo_anterior',(d#>>'{fix86_columns,saldo_anterior}')::numeric+delta_i+delta_b+delta_c,
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
CREATE OR REPLACE FUNCTION public.lts_browser_flow_base_v229(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
declare u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
begin
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
$function$
;
CREATE OR REPLACE FUNCTION public.lts_browser_flow_v229(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
DECLARE
 u uuid:=public.lts_browser_assert_user_v1(); anchors jsonb; positions jsonb;
 lo date; result jsonb; f jsonb; events jsonb; recent jsonb; observed jsonb;
 s record; b text; a jsonb; e jsonb; matched jsonb; match_count int; added jsonb:='[]';
 d jsonb; dt date; c jsonb; outdays jsonb; part text; dayev jsonb;
 bal numeric; net numeric; fin numeric; inc numeric; outflow numeric; internal numeric;
 op_in numeric; op_out numeric; rsu numeric; d0 numeric; fgts numeric; gaps jsonb:='{}';
 morgan jsonb; cofrinho jsonb; asof date; asset_net numeric;
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
 ), ranked AS (
  SELECT DISTINCT ON (x->>'event_date',x->>'account',x->>'source',x->>'source_ref') x
   FROM candidates ORDER BY x->>'event_date',x->>'account',x->>'source',x->>'source_ref',priority
 ) SELECT coalesce(jsonb_agg(x),'[]') INTO recent FROM ranked;
 SELECT coalesce(jsonb_agg(jsonb_build_object('bank',case institution_code when '341' then 'Itaú' when '237' then 'Bradesco' else 'C6' end,
  'account_ref',provider_account_ref,'balance',signed_amount,'as_of',(normalized_payload->>'as_of')::timestamptz,'payload',normalized_payload)),'[]') INTO positions
 FROM public.lts_open_finance_staging WHERE user_id=u AND resource_type='balance' AND institution_code IN ('341','237','336')
  AND normalized_payload->>'account_type'='CHECKING_ACCOUNT' AND currency='BRL' AND provider_deleted_at IS NULL;
 IF jsonb_array_length(positions)<>3 THEN RAISE EXCEPTION 'checking account positions incomplete or ambiguous'; END IF;
 FOR s IN SELECT st.*,case institution_code when '341' then 'Itaú' when '237' then 'Bradesco' else 'C6' end bank
  FROM public.lts_open_finance_staging st WHERE user_id=u AND resource_type='transaction'
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
   e:=jsonb_build_object('source','open_finance','source_ref',s.id,'open_finance_id',s.id,'event_date',s.posting_date,
    'account',s.bank,'account_attribution','assigned','description',s.description_raw,'signed_amount',s.signed_amount,
    'direction',case when s.signed_amount<0 then 'saida' else 'entrada' end,'confidence','bank_posted','bank_confirmed',true,
    'category',case when s.description_raw ILIKE '%RESGATE COFRINH%' then 'Movimentação interna' else 'A classificar' end,
    'internal_transfer',s.description_raw ILIKE '%RESGATE COFRINH%',
    'asset_movement',s.description_raw ILIKE '%RESGATE COFRINH%','excluded',s.description_raw ILIKE '%RESGATE COFRINH%');
   recent:=recent||jsonb_build_array(e);added:=added||jsonb_build_array(e);
  END IF;
 END LOOP;
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
   WHERE x->>'account'=b AND (x->>'event_date')::date>(a->>'date')::date AND x->>'source'<>'economic_withholding';
  gaps:=gaps||jsonb_build_object(b,round(bal-(a->>'balance')::numeric-net,2));
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
     SELECT (x->>'balance')::numeric INTO bal FROM jsonb_array_elements(positions) x WHERE x->>'bank'=b;
     SELECT bal-coalesce(sum((x->>'signed_amount')::numeric),0) INTO bal FROM jsonb_array_elements(recent) x
      WHERE x->>'account'=b AND (x->>'event_date')::date>dt AND x->>'source'<>'economic_withholding';
     SELECT coalesce(sum((x->>'signed_amount')::numeric),0) INTO net FROM jsonb_array_elements(recent) x
      WHERE x->>'account'=b AND (x->>'event_date')::date=dt AND x->>'source'<>'economic_withholding';
     d:=jsonb_set(d,ARRAY[b],coalesce(d->b,'{}')||jsonb_build_object('balance',bal,'net',net,'operational_balance',bal,'operational_net',net,
      'balance_basis','observed_bank_position_and_recent_movements','balance_certified',dt=current_date OR abs((gaps->>b)::numeric)<0.005,
      'reconciliation_gap',(gaps->>b)::numeric));
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
   outdays:=outdays||jsonb_build_array(d);
  END LOOP;
  f:=jsonb_set(f,ARRAY[part],coalesce(f->part,'{}')||jsonb_build_object('days',outdays,'events',coalesce((SELECT jsonb_agg(x ORDER BY x->>'event_date',x->>'source_ref')
   FROM jsonb_array_elements(events) x WHERE (x->>'event_date')::date BETWEEN p_from AND p_to
    AND case when part='historical' then (x->>'event_date')::date<current_date else (x->>'event_date')::date>=current_date end),'[]')));
 END LOOP;
 f:=f||jsonb_build_object('from',p_from,'to',p_to,'observed_bank_movements',jsonb_build_object('version','v229','added_count',jsonb_array_length(added),'documentary_gaps',gaps));
 RETURN result||jsonb_build_object('flow',f,'version','browser-flow-v229-consistent-evidence');
END $function$
;
REVOKE ALL ON FUNCTION public.lts_flow_history_read_v229(date,date) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_flow_history_read_v229(date,date) TO service_role;
REVOKE ALL ON FUNCTION public.lts_flow_operational_read_v229(uuid,date,date) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_flow_operational_read_v229(uuid,date,date) TO service_role;
REVOKE ALL ON FUNCTION public.lts_dashboard_cash_ladder_from_flow_v229(uuid,date,date,jsonb) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_dashboard_cash_ladder_from_flow_v229(uuid,date,date,jsonb) TO service_role;
REVOKE ALL ON FUNCTION public.lts_current_flow_v229(uuid,date,date) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_current_flow_v229(uuid,date,date) TO service_role;
REVOKE ALL ON FUNCTION public.lts_browser_flow_base_v229(date,date) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_browser_flow_base_v229(date,date) TO service_role;
REVOKE ALL ON FUNCTION public.lts_browser_flow_v229(date,date) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_browser_flow_v229(date,date) TO service_role;
GRANT EXECUTE ON FUNCTION public.lts_browser_flow_v229(date,date) TO authenticated;
