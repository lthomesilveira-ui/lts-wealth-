-- LTS Wealth canonical read-model reconciliation — 2026-09-06
-- Scope: read-model correctness only. No source financial fact, classification,
-- valuation input, debt input, planning rule or documentary evidence is changed.

create or replace function public.lts_wealth_executive_report_v5(p_user_id uuid)
returns jsonb
language sql
set search_path to 'public'
set "TimeZone" to 'America/Sao_Paulo'
as $function$
with b as materialized (
  select public.lts_wealth_executive_report_v4(p_user_id) j
), d as materialized (
  select public.lts_daily_flow_fix86_v13(p_user_id,current_date,current_date)->'days'->0 j
), a as materialized (
  select
    coalesce(sum(effective_value_brl) filter(where liquidity_class='D+0' and is_available_now),0)::numeric d0,
    coalesce(sum(effective_value_brl) filter(where liquidity_class in ('D+1','D+2','D+3') and is_available_now),0)::numeric d3,
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
      'read_basis','daily-flow-fix86-v13 + lts_asset_position_effective_v1'
    ),
    true
  ) j
  from calc
)
select (select j from patched)-'version' || jsonb_build_object(
  'version','wealth-executive-v5-effective-bank-asset-liquidity',
  'reconciliation_version','wealth-summary-current-effective-v1',
  'liquidity_basis','Current bank cash from Flow v13 plus effective asset positions. Superseded documentary snapshots are not summed as simultaneous current positions.',
  'current_reconciliation',jsonb_build_object(
    'bank_source','daily-flow-fix86-v13',
    'asset_source','lts_asset_position_effective_v1',
    'assets_identity_reconciled',true,
    'brokerage_available_unclassified_added_by_this_reconciliation',false
  ),
  'guardrails',coalesce((select j->'guardrails' from patched),'[]'::jsonb)||jsonb_build_array(
    'Aplicação/resgate altera a composição banco versus ativo, não cria renda, despesa ou patrimônio líquido adicional.',
    'Snapshots documentais supersededidos não são somados como posições correntes simultâneas.',
    'Brokerage cash available_unclassified continua fora de D0/D3 e não é adicionado por esta reconciliação; a regra vigente permanece até evidência documental de latência/alocação.'
  )
);
$function$;

create or replace function public.lts_browser_enrich_flow_bank_gross_v1(p_payload jsonb)
returns jsonb
language sql
immutable
as $function$
with ev as (
  select
    e->>'event_date' dt,
    e->>'account' account,
    round(sum(case when coalesce((e->>'signed_amount')::numeric,0)>0 then (e->>'signed_amount')::numeric else 0 end),2) entries,
    round(sum(case when coalesce((e->>'signed_amount')::numeric,0)<0 then -(e->>'signed_amount')::numeric else 0 end),2) exits
  from jsonb_array_elements(coalesce(p_payload#>'{flow,events}','[]'::jsonb)) e
  where e->>'account' in ('Itaú','Bradesco','C6')
  group by 1,2
), days as (
  select d.day,d.ord
  from jsonb_array_elements(coalesce(p_payload#>'{flow,days}','[]'::jsonb)) with ordinality d(day,ord)
), enriched as (
  select jsonb_agg(
    day || jsonb_build_object(
      'Itaú',coalesce(day->'Itaú','{}'::jsonb) || jsonb_build_object(
        'entries',coalesce((select entries from ev where dt=day->>'date' and account='Itaú'),0),
        'exits',coalesce((select exits from ev where dt=day->>'date' and account='Itaú'),0),
        'operational_balance',day#>'{Itaú,balance}'
      ),
      'Bradesco',coalesce(day->'Bradesco','{}'::jsonb) || jsonb_build_object(
        'entries',coalesce((select entries from ev where dt=day->>'date' and account='Bradesco'),0),
        'exits',coalesce((select exits from ev where dt=day->>'date' and account='Bradesco'),0),
        'operational_balance',day#>'{Bradesco,balance}'
      ),
      'C6',coalesce(day->'C6','{}'::jsonb) || jsonb_build_object(
        'entries',coalesce((select entries from ev where dt=day->>'date' and account='C6'),0),
        'exits',coalesce((select exits from ev where dt=day->>'date' and account='C6'),0),
        'operational_balance',day#>'{C6,balance}'
      )
    ) order by ord
  ) days_json
  from days
)
select case
  when p_payload is null then null
  else jsonb_set(p_payload,'{flow,days}',coalesce((select days_json from enriched),'[]'::jsonb),true)
end;
$function$;

create or replace function public.lts_product_payload_fix86_v36(p_user_id uuid)
returns jsonb
language sql
security definer
set search_path to 'public'
set "TimeZone" to 'America/Sao_Paulo'
as $function$
with base as materialized (
  select public.lts_product_payload_fix86_v35(p_user_id) j
), pe as materialized (
  select public.lts_planning_executive_v1(p_user_id,current_date,(current_date+interval '12 months')::date) j
), we as materialized (
  select public.lts_wealth_executive_report_v5(p_user_id) j
), pl as (
  select jsonb_build_object(
    'version','planning-liquidity-ladder-v4-flow-v12-fgts-d30',
    'from',pe.j#>'{period,from}',
    'to',pe.j#>'{period,to}',
    'flow_basis','lts_daily_flow_fix86_v12',
    'layers',pe.j->'layers',
    'first_real_gap_date',pe.j#>'{summary,first_real_gap_date}',
    'gap_episodes',pe.j->'gap_episodes',
    'fgts_first_negative_date',pe.j#>'{summary,first_negative_even_with_fgts}',
    'fgts_access',pe.j->'fgts_access',
    'guardrail','Gap real = saldo negativo mesmo após vestings programados. A escada usa o mesmo motor de Fluxo v12; FGTS permanece contingência D+30.'
  ) j from pe
)
select (select j from base) || jsonb_build_object(
  'version','lts-product-fix86-v36',
  'planning_ladder',(select j from pl),
  'planning_executive',(select j from pe),
  'wealth_executive',(select j from we),
  'wealth',public.lts_wealth_current_patch_v1(p_user_id,(select j->'wealth' from base)),
  'product_contract',coalesce((select j->'product_contract' from base),'{}'::jsonb) || jsonb_build_object(
    'planning_explainable_gaps',true,
    'planning_flow_v12_parity',true,
    'wealth_market_vs_documentary',true,
    'wealth_current_effective_reconciliation',true
  )
);
$function$;

create or replace function public.lts_browser_product_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
set "TimeZone" to 'America/Sao_Paulo'
as $function$
declare
  v_uid uuid;
  c jsonb;
  m jsonb;
  v_email text:=lower(coalesce(auth.jwt()->>'email',''));
  v_version text;
  v_cached_today date;
  v_mode text:='cache_hit_fresh';
  v_doc_change_version text;
  v_is_stale boolean:=false;
begin
  v_uid:=public.lts_browser_assert_user_v1();
  c:=public.lts_product_read_cached_v1(v_uid);
  v_version:=coalesce(c->>'payload_version','');

  begin
    v_cached_today:=nullif(c#>>'{payload,updates,freshness,today}','')::date;
  exception when others then
    v_cached_today:=null;
  end;
  v_doc_change_version:=coalesce(c#>>'{payload,updates,document_change_summary_version}','');

  if c is null or c->'payload' is null or v_version<>'lts-product-fix86-v36' then
    m:=public.lts_product_payload_fix86_v36(v_uid);
    insert into public.lts_product_read_cache(user_id,payload_version,payload,refreshed_at,source)
    values(v_uid,'lts-product-fix86-v36',m,now(),'browser_full_initialize_v36')
    on conflict(user_id) do update
      set payload_version=excluded.payload_version,
          payload=excluded.payload,
          refreshed_at=excluded.refreshed_at,
          source=excluded.source;
    c:=public.lts_product_read_cached_v1(v_uid);
    begin
      v_cached_today:=nullif(c#>>'{payload,updates,freshness,today}','')::date;
    exception when others then
      v_cached_today:=null;
    end;
    v_doc_change_version:=coalesce(c#>>'{payload,updates,document_change_summary_version}','');
    m:=c->'payload';
    v_mode:='full_initialize';
  else
    m:=c->'payload';
    v_is_stale := v_cached_today is distinct from current_date
                  or v_doc_change_version<>'document-change-summary-v1';
    if v_is_stale then
      v_mode:='cache_hit_stale_deferred';
    end if;
  end if;

  m:=public.lts_browser_enrich_flow_bank_gross_v1(m);

  insert into public.lts_access_audit(user_id,email,action,meta)
  values(
    v_uid,
    v_email,
    'browser_rpc_product_read',
    jsonb_build_object(
      'rpc_version',11,
      'payload_version',coalesce(c->>'payload_version','lts-product-fix86-v36'),
      'cached_today',v_cached_today,
      'server_today',current_date,
      'refresh_mode',v_mode,
      'refresh_required',v_is_stale,
      'document_change_summary_version',v_doc_change_version,
      'flow_bank_gross_basis','payload_events_reconciled_v1'
    )
  );

  return jsonb_build_object(
    'ok',true,
    'api_version',41,
    'product','lts-wealth-fix86-plus',
    'cache',jsonb_build_object(
      'refreshed_at',c->'refreshed_at',
      'payload_version',coalesce(c->>'payload_version','lts-product-fix86-v36'),
      'cached_today',v_cached_today,
      'server_today',current_date,
      'is_stale',v_is_stale,
      'refresh_required',v_is_stale,
      'refresh_mode',v_mode
    ),
    'mvp',m
  );
end;
$function$;

create or replace function public.lts_browser_dashboard_cockpit_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
set "TimeZone" to 'America/Sao_Paulo'
as $function$
declare
  u uuid;
  c record;
  pc timestamptz;
  j jsonb;
  w jsonb;
begin
  u:=public.lts_browser_assert_user_v1();
  select refreshed_at into pc from public.lts_product_read_cache where user_id=u;
  select * into c from public.lts_dashboard_cockpit_cache where user_id=u;
  if not found or c.as_of<>current_date or c.source_product_refreshed_at is distinct from pc then
    j:=public.lts_refresh_dashboard_cockpit_v1(u);
  else
    j:=c.payload;
  end if;

  w:=public.lts_wealth_executive_report_v5(u);
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
    j:=jsonb_set(j,'{planning_audited,first_negative_date}',j#>'{planning_audited,first_uncovered_gap_date}',true);
  end if;
  update public.lts_dashboard_cockpit_cache set payload=j where user_id=u;
  return j;
end
$function$;
