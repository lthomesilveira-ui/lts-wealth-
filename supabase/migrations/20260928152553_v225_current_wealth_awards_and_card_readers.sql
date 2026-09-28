-- Read models only. Canonical locks, evidence, events and debt facts remain unchanged.
CREATE OR REPLACE FUNCTION public.lts_browser_awards_v178()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare u uuid:=public.lts_browser_assert_user_v1(); snap public.lts_brokerage_position_snapshots%rowtype; current_position jsonb;
begin
 select * into snap from public.lts_brokerage_position_snapshots where user_id=u and institution='Morgan Stanley' order by as_of_date desc,updated_at desc limit 1;
 select canonical_value into current_position from public.lts_validated_lock_registry where lock_key='morgan_available_20260922' and superseded_at is null;
 if current_position is null or abs((current_position->>'total_available_brl')::numeric-(current_position->>'shares_value_brl')::numeric-(current_position->>'brokerage_cash_brl')::numeric)>0.01 then raise exception 'validated brokerage position incomplete'; end if;
 return jsonb_build_object('version','awards-v180','as_of',current_position->'as_of',
 'vested_shares',current_position->'shares_value_brl','brokerage_cash',current_position->'brokerage_cash_brl',
 'other_available',0,'brokerage_available',current_position->'total_available_brl',
 'other_unavailable',snap.other_unavailable_brl,'basis','validated_current_position',
 'events',coalesce((select jsonb_agg(jsonb_build_object(
 'id',s.id,'type',s.asset_type,'vesting_date',s.eligibility_date,'available_date',s.eligibility_date+coalesce(s.settlement_days,0),
 'value',coalesce(s.net_value_brl,s.gross_value_brl),'regular_rsu',upper(s.asset_type)='RSU','basis',s.source
 ) order by s.eligibility_date,s.id) from public.lts_future_liquidity_schedule s
 where s.user_id=u and s.active and s.eligibility_date>snap.as_of_date),'[]'::jsonb));
end $function$;

CREATE OR REPLACE FUNCTION public.lts_browser_wealth_detail_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  uid uuid:=public.lts_browser_assert_user_v1();
  p jsonb;
  cached_w jsonb;
  w jsonb;
  sched jsonb;
  docs jsonb;
  commits jsonb;
  cipo jsonb;
  vested jsonb;
  volvo jsonb;
  current_cash jsonb;
  current_awards jsonb;
  old_liquidity jsonb;
  delta numeric;
  key text;
begin
  select payload into p
  from public.lts_product_read_cache
  where user_id=uid;

  cached_w:=p->'wealth_executive';
  if coalesce(cached_w->>'reconciliation_version','')='wealth-summary-current-effective-v1' then
    w:=cached_w;
  else
    w:=public.lts_wealth_executive_report_v5(uid);
  end if;

  current_cash:=public.lts_browser_cash_today_v178();
  current_awards:=public.lts_browser_awards_v178();
  old_liquidity:=w->'liquidity';
  if old_liquidity->>'through_d3' is null or old_liquidity->>'fgts_contingency' is null then raise exception 'wealth liquidity basis incomplete'; end if;
  delta:=(current_cash->>'available_total')::numeric-(old_liquidity->>'through_d3')::numeric
    +(current_cash->>'fgts')::numeric-(old_liquidity->>'fgts_contingency')::numeric;
  foreach key in array array['assets_central','net_worth_low','net_worth_central','net_worth_high'] loop
    if w#>>array['summary',key] is not null then
      w:=jsonb_set(w,array['summary',key],to_jsonb(round((w#>>array['summary',key])::numeric+delta,2)),true);
    end if;
  end loop;
  w:=jsonb_set(w,'{liquidity}',old_liquidity||jsonb_build_object(
    'bank_cash',current_cash->'cash','d0',current_cash->'d0','d3',current_cash->'brokerage_available',
    'through_d3',current_cash->'available_total','fgts_contingency',current_cash->'fgts'),true);
  w:=jsonb_set(w,'{summary}',(w->'summary')||jsonb_build_object(
    'liquidity_through_d3',current_cash->'available_total','restricted_contingency',current_cash->'fgts',
    'known_debt_to_assets_pct',case when (w#>>'{summary,assets_central}')::numeric<>0 then round(100*(w#>>'{summary,known_debt_total}')::numeric/(w#>>'{summary,assets_central}')::numeric,1) end,
    'cipo_share_of_assets_pct',case when (w#>>'{summary,assets_central}')::numeric<>0 then round(100*(w#>>'{assets,cipo_396,market_central}')::numeric/(w#>>'{summary,assets_central}')::numeric,1) end),true);
  w:=w||jsonb_build_object('current_liquidity_basis','same canonical position as Dashboard and Flow','as_of',current_date);
    sched:=coalesce(p#>'{wealth,asset_layers,derived_future_schedule}','[]'::jsonb);
  docs:=coalesce(p->'documentary_commitments','{}'::jsonb);
  commits:=coalesce(p->'commitments','{}'::jsonb);
  cipo:=public.lts_cipo_396_summary_v2(uid);

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'asset_name',asset_name,
        'asset_type',asset_type,
        'as_of',as_of_date,
        'units',quantity,
        'unit_price',unit_price,
        'fx_rate',fx_rate,
        'value_brl',value_brl,
        'liquidity_class',liquidity_class,
        'availability_note',availability_note,
        'metadata',metadata
      ) order by as_of_date desc,id desc
    ),
    '[]'::jsonb
  ) into vested
  from public.asset_positions
  where user_id=uid
    and is_available_now=true
    and (
      upper(trim(coalesce(asset_type,'')))='RSU'
      or lower(trim(coalesce(asset_name,'')))='organon long share holdings'
    );

  with x as (
    select fe.event_date,abs(fe.amount)::numeric amount,a.institution,fe.metadata
    from public.financial_events fe
    left join public.accounts a on a.id=fe.account_id
    where fe.user_id=uid
      and fe.metadata->>'contract_ref'='volvo_financing_2026'
      and fe.status in ('active','scheduled')
  ), s as (
    select count(*) total_installments,
           count(*) filter(where event_date>=current_date) remaining_installments,
           min(event_date) first_due,
           max(event_date) last_due,
           min(event_date) filter(where event_date>=current_date) next_due,
           min(amount) min_amount,
           max(amount) max_amount,
           sum(amount) filter(where event_date>=current_date) future_schedule_total,
           count(*) filter(where institution='Bradesco') bradesco_rows
    from x
  )
  select jsonb_build_object(
    'total_installments',total_installments,
    'remaining_installments',remaining_installments,
    'first_due',first_due,
    'last_due',last_due,
    'next_due',next_due,
    'installment_amount',case when min_amount=max_amount then min_amount else null end,
    'future_schedule_total',round(coalesce(future_schedule_total,0),2),
    'all_assigned_bradesco',bradesco_rows=total_installments and total_installments>0,
    'cash_account','Bradesco',
    'guardrail','Cronograma futuro é saída de caixa contratada; soma de parcelas futuras não substitui saldo devedor atual.'
  ) into volvo
  from s;

  return jsonb_build_object(
    'version','wealth-detail-v2-rsu-financing-cipo-corrected',
    'as_of',current_date,
    'wealth',w,
    'current_liquidity',current_cash-'day',
    'current_awards',current_awards-'events',
    'rsu',jsonb_build_object(
      'vested_positions',vested,
      'future_schedule',sched,
      'future_schedule_count',jsonb_array_length(sched),
      'scenario_supported',true
    ),
    'cipo',cipo,
    'documentary_commitments',docs,
    'commitments',commits,
    'volvo_financing',volvo,
    'guardrails',jsonb_build_array(
      'Somente posições explicitamente RSU/Organon shares entram em RSU vested; aplicações como Cofrinho ficam fora desta seção.',
      'Awards futuros permanecem fora do patrimônio adquirido até vesting/settlement.',
      'Simulação de antecipação é cenário somente e nunca altera a data real do award.',
      'Cronogramas de parcelas não são convertidos em saldo devedor sem documento de posição.'
    )
  );
end
$function$
;
CREATE OR REPLACE FUNCTION public.lts_browser_card_flow_schedule_v1(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_flow jsonb;
  v_events jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then
    raise exception 'invalid card flow range';
  end if;
  v_flow := case when p_from>=current_date and p_to+30<=current_date+1800
    then public.lts_flow_future_read_slice_v9(v_uid,p_from,p_to)
    else public.lts_daily_flow_fix86_v12(v_uid,p_from,p_to) end;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'event_date',x->>'event_date',
      'account',x->>'account',
      'description',x->>'description',
      'card_name',coalesce(x->>'counterparty',x->>'description'),
      'amount',abs((x->>'signed_amount')::numeric),
      'source',x->>'source',
      'source_ref',x->>'source_ref',
      'confidence',x->>'confidence'
    )
    order by x->>'event_date',x->>'description'
  ),'[]'::jsonb)
  into v_events
  from jsonb_array_elements(coalesce(v_flow->'events','[]'::jsonb)) x
  where (x->>'signed_amount')::numeric<0
    and (
      coalesce(x->>'category','') in ('Cartões','Cartão de Crédito')
      or coalesce(x->>'description','') ~* '(Aeternum|Mastercard|Personnalit|Cart[aã]o C6|C6 Carbon|Visa Infinite)'
    );

  return jsonb_build_object(
    'version','card-flow-schedule-v1',
    'from',p_from,
    'to',p_to,
    'events',v_events
  );
end
$function$
;
REVOKE EXECUTE ON FUNCTION public.lts_browser_awards_v178(), public.lts_browser_wealth_detail_v1(), public.lts_browser_card_flow_schedule_v1(date,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_awards_v178(), public.lts_browser_wealth_detail_v1(), public.lts_browser_card_flow_schedule_v1(date,date) TO authenticated,service_role;
DO $$ BEGIN IF NOT (public.lts_current_cash_release_qa_v1()->>'pass')::boolean OR NOT (public.lts_planning_ui_release_qa_v1()->>'pass')::boolean THEN RAISE EXCEPTION 'canonical gates changed'; END IF; END $$;

