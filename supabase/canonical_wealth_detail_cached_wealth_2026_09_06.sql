create or replace function public.lts_browser_wealth_detail_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
set "TimeZone" to 'America/Sao_Paulo'
as $function$
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
$function$;
