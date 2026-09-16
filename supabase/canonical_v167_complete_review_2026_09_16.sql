-- V167: truthful historical balances, explicit award milestones and an
-- authenticated wealth reader for pensions, financing and CIPÓ detail.
-- Private user values are intentionally not embedded in this migration.

create or replace function public.lts_flow_historical_balance_truth_overlay_v1(
  p_user_id uuid,
  p_flow jsonb
) returns jsonb
language plpgsql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
declare
  v_itau date;
  v_bradesco date;
  v_c6 date;
  v_consolidated date;
  v_day jsonb;
  v_date date;
  v_days jsonb := '[]'::jsonb;
begin
  select min((dados->>'data')::date) filter (where lower(coalesce(dados->>'conta','')) in ('itau','itaú')),
         min((dados->>'data')::date) filter (where lower(coalesce(dados->>'conta',''))='bradesco'),
         min((dados->>'data')::date) filter (where lower(coalesce(dados->>'conta',''))='c6')
    into v_itau,v_bradesco,v_c6
  from public.saldo_snapshot
  where usuario_id=p_user_id
    and coalesce(dados->>'data','') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';

  select least(v_itau,coalesce(min(nullif(metadata->>'prior_balance_as_of','')::date),v_itau))
    into v_itau from public.accounts
   where user_id=p_user_id and is_active and lower(institution) in ('itau','itaú');
  select least(v_bradesco,coalesce(min(nullif(metadata->>'prior_balance_as_of','')::date),v_bradesco))
    into v_bradesco from public.accounts
   where user_id=p_user_id and is_active and lower(institution)='bradesco';
  select coalesce(v_c6,min(coalesce(nullif(metadata->>'prior_balance_as_of','')::date,nullif(metadata->>'balance_as_of','')::date)))
    into v_c6 from public.accounts
   where user_id=p_user_id and is_active and lower(institution)='c6';

  if v_itau is null or v_bradesco is null or v_c6 is null then
    v_consolidated:=null;
  else
    v_consolidated:=greatest(v_itau,v_bradesco,v_c6);
  end if;

  for v_day in select value from jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'::jsonb)) loop
    v_date:=nullif(v_day->>'date','')::date;
    if v_itau is null or v_date<v_itau then
      v_day:=jsonb_set(jsonb_set(v_day,array['Itaú','balance'],'null'::jsonb,true),array['Itaú','balance_certified'],'false'::jsonb,true);
    end if;
    if v_bradesco is null or v_date<v_bradesco then
      v_day:=jsonb_set(jsonb_set(v_day,array['Bradesco','balance'],'null'::jsonb,true),array['Bradesco','balance_certified'],'false'::jsonb,true);
    end if;
    if v_c6 is null or v_date<v_c6 then
      v_day:=jsonb_set(jsonb_set(v_day,array['C6','balance'],'null'::jsonb,true),array['C6','balance_certified'],'false'::jsonb,true);
    end if;
    if v_consolidated is null or v_date<v_consolidated then
      v_day:=jsonb_set(v_day,array['Consolidado','bank_balance'],'null'::jsonb,true);
      v_day:=jsonb_set(v_day,array['Consolidado','balance_certified'],'false'::jsonb,true);
      v_day:=v_day||jsonb_build_object(
        'evidence_status','movement_only_before_complete_documentary_opening',
        'absolute_balance_basis',null,
        'absolute_balance_certified',false,
        'absolute_balance_reconstructed',false
      );
    end if;
    v_days:=v_days||jsonb_build_array(v_day);
  end loop;

  return jsonb_set(p_flow,'{historical,days}',v_days,true)||jsonb_build_object(
    'historical_balance_truth_contract',jsonb_build_object(
      'version','historical-balance-truth-v1',
      'itau_first_documentary_opening',v_itau,
      'bradesco_first_documentary_opening',v_bradesco,
      'c6_first_documentary_opening',v_c6,
      'consolidated_first_complete_opening',v_consolidated,
      'pre_opening_display','movements_only',
      'guardrail','Backward projections over incomplete history are never presented as certified balances.'
    )
  );
end
$function$;

create or replace function public.lts_daily_flow_fix86_v20(
  p_user_id uuid,
  p_from date default current_date,
  p_to date default current_date+interval '1 year'
) returns jsonb
language plpgsql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
declare v_base jsonb; v_events jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
  v_base:=public.lts_daily_flow_fix86_v19(p_user_id,p_from,p_to);
  with extra as (
    select jsonb_build_object(
      'event_date',s.eligibility_date,
      'account','Corretora',
      'description',case when lower(s.asset_type) like '%cash%' then 'Vesting Cash RSU · disponível em '
                         else 'Vesting RSU · disponível em ' end
                    ||to_char(s.eligibility_date+s.settlement_days,'DD/MM/YYYY'),
      'signed_amount',0,
      'category',case when lower(s.asset_type) like '%cash%' then 'Cash RSU' else 'RSU' end,
      'source','future_award_vesting_marker',
      'source_ref',s.id||':vesting',
      'status','expected',
      'editable',false,
      'non_cash_marker',true,
      'available_date',s.eligibility_date+s.settlement_days
    ) e
    from public.lts_future_liquidity_schedule s
    where s.user_id=p_user_id and s.active=true
      and (upper(trim(s.asset_type))='RSU' or lower(s.asset_type) like '%cash%')
      and s.eligibility_date between p_from and p_to
    union all
    select jsonb_build_object(
      'event_date',s.eligibility_date+s.settlement_days,
      'account','Corretora',
      'description','RSU disponível após liquidação',
      'signed_amount',coalesce(s.gross_value_brl,s.net_value_brl),
      'category','RSU',
      'source','future_rsu_available',
      'source_ref',s.id||':available',
      'status','expected',
      'editable',false,
      'liquidity_layer','D+3',
      'available_from_vesting',true
    ) e
    from public.lts_future_liquidity_schedule s
    where s.user_id=p_user_id and s.active=true
      and upper(trim(s.asset_type))='RSU'
      and (s.eligibility_date+s.settlement_days) between p_from and p_to
  ), all_events as (
    select value e from jsonb_array_elements(coalesce(v_base->'events','[]'::jsonb))
    union all select e from extra
  )
  select coalesce(jsonb_agg(e order by e->>'event_date',e->>'source_ref'),'[]'::jsonb)
    into v_events from all_events;
  return jsonb_set(v_base,'{events}',v_events,true)||jsonb_build_object(
    'version','daily-flow-fix86-v20-award-milestones',
    'award_milestone_contract',jsonb_build_object(
      'vesting_date_visible',true,
      'availability_date_visible',true,
      'vesting_marker_is_non_cash',true,
      'cash_rsu_uses_net_value_on_availability',true
    )
  );
end
$function$;

create or replace function public.lts_flow_future_read_cache_refresh_v9(
  p_user_id uuid,
  p_days integer default 730
) returns jsonb
language plpgsql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
declare d1 date:=current_date; d2 date:=current_date+greatest(30,least(coalesce(p_days,730),1800)); j jsonb; t0 timestamptz:=clock_timestamp();
begin
  j:=public.lts_daily_flow_fix86_v20(p_user_id,d1,d2);
  insert into public.lts_flow_future_read_cache_v2(user_id,as_of,from_date,to_date,engine_version,payload,refreshed_at)
  values(p_user_id,d1,d1,d2,j->>'version',j,now())
  on conflict(user_id) do update set as_of=excluded.as_of,from_date=excluded.from_date,to_date=excluded.to_date,
    engine_version=excluded.engine_version,payload=excluded.payload,refreshed_at=excluded.refreshed_at;
  return jsonb_build_object('ok',true,'as_of',d1,'to',d2,'days',jsonb_array_length(coalesce(j->'days','[]'::jsonb)),
    'events',jsonb_array_length(coalesce(j->'events','[]'::jsonb)),'engine_version',j->>'version',
    'elapsed_ms',round((extract(epoch from(clock_timestamp()-t0))*1000)::numeric,1));
end
$function$;

create or replace function public.lts_flow_future_read_slice_v9(
  p_user_id uuid,p_from date,p_to date
) returns jsonb
language plpgsql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
declare c record; d jsonb; e jsonb; base jsonb; requested_horizon integer;
begin
  if p_from is null or p_to is null or p_from>p_to or p_from<current_date then raise exception 'invalid future range'; end if;
  if p_to+30>current_date+1800 then raise exception 'future range exceeds supported horizon'; end if;
  select * into c from public.lts_flow_future_read_cache_v2
   where user_id=p_user_id and as_of=current_date and from_date<=p_from and to_date>=p_to+30
     and engine_version='daily-flow-fix86-v20-award-milestones'
   order by refreshed_at desc limit 1;
  if not found then
    requested_horizon:=greatest(60,(p_to-current_date)+31);
    perform public.lts_flow_future_read_cache_refresh_v9(p_user_id,requested_horizon);
    select * into c from public.lts_flow_future_read_cache_v2
     where user_id=p_user_id and as_of=current_date and from_date<=p_from and to_date>=p_to+30
       and engine_version='daily-flow-fix86-v20-award-milestones'
     order by refreshed_at desc limit 1;
  end if;
  if not found then raise exception 'future Flow cache could not cover requested range'; end if;
  with all_src as (
    select x,(x->>'date')::date dt from jsonb_array_elements(coalesce(c.payload->'days','[]'::jsonb)) x
     where (x->>'date')::date between p_from and p_to+30
  ), src as (select * from all_src where dt<=p_to), adj as (
    select s.dt,jsonb_set(s.x,'{fix86_columns,liq_d30}',to_jsonb(
      coalesce(nullif(s.x#>>'{fix86_columns,liq_d0_1}','')::numeric,0)+coalesce((
        select sum(nullif(y.x#>>'{Consolidado,economic_net}','')::numeric) from all_src y
         where y.dt>s.dt and y.dt<=s.dt+30),0)),true) x from src s
  ) select coalesce(jsonb_agg(x order by dt),'[]'::jsonb) into d from adj;
  select coalesce(jsonb_agg(x order by x->>'event_date',x->>'source_ref'),'[]'::jsonb) into e
    from jsonb_array_elements(coalesce(c.payload->'events','[]'::jsonb)) x
   where (x->>'event_date')::date between p_from and p_to;
  base:=(c.payload-'days'-'events')||jsonb_build_object('from',p_from,'to',p_to,'days',d,'events',e,
    'version','daily-flow-fix86-v20-award-milestones-cache-slice','horizon_contract','requested-period-plus-30-days-v3',
    'cold_refresh_horizon_days',requested_horizon);
  return base;
end
$function$;

create or replace function public.lts_browser_flow_v11(p_from date,p_to date)
returns jsonb
language plpgsql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
declare uid uuid; v_email text:=lower(coalesce(auth.jwt()->>'email','')); oldj jsonb; histflow jsonb; cf jsonb; flow jsonb;
begin
  uid:=public.lts_browser_assert_user_v1();
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
  if (p_to-p_from)>12000 then raise exception 'range too large'; end if;
  if p_to<current_date then
    oldj:=public.lts_browser_flow_v3(p_from,p_to);
    flow:=public.lts_flow_historical_exact_transfer_overlay_v1(uid,p_from,p_to,oldj->'flow');
    flow:=flow||jsonb_build_object('version','daily-flow-browser-v11-historical-truth');
  elsif p_from>=current_date then
    cf:=public.lts_flow_future_read_slice_v9(uid,p_from,p_to);
    flow:=jsonb_build_object('from',p_from,'to',p_to,'calculation_context_from',current_date,
      'historical',jsonb_build_object('days','[]'::jsonb,'events','[]'::jsonb),'current_future',cf,
      'version','daily-flow-browser-v11-future-v20-award-milestones');
  else
    oldj:=public.lts_browser_flow_v3(p_from,current_date-1);
    histflow:=public.lts_flow_historical_exact_transfer_overlay_v1(uid,p_from,current_date-1,oldj->'flow');
    cf:=public.lts_flow_future_read_slice_v9(uid,current_date,p_to);
    flow:=jsonb_build_object('from',p_from,'to',p_to,'calculation_context_from',p_from,
      'historical',histflow->'historical','current_future',cf,
      'version','daily-flow-browser-v11-mixed-truth-award-milestones',
      'historical_own_transfer_contract',histflow->'historical_own_transfer_contract');
  end if;
  flow:=public.lts_flow_documentary_close_overlay_v1(uid,flow);
  flow:=public.lts_flow_classification_source_overlay_v1(uid,flow);
  if p_from<current_date then flow:=public.lts_flow_historical_balance_truth_overlay_v1(uid,flow); end if;
  flow:=flow||jsonb_build_object('bank_evidence_as_of',(select jsonb_agg(jsonb_build_object(
    'bank',institution,'date',metadata->>'balance_as_of','documentary_balance',metadata->'balance') order by institution)
    from public.accounts where user_id=uid and is_active));
  insert into public.lts_access_audit(user_id,email,action,meta) values(uid,v_email,'browser_rpc_flow_read',
    jsonb_build_object('rpc_version',17,'from',p_from,'to',p_to,'historical_truth',p_from<current_date,'award_milestones',p_to>=current_date));
  return jsonb_build_object('ok',true,'flow',flow);
end
$function$;

create or replace function public.lts_browser_wealth_detail_v3()
returns jsonb
language plpgsql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
declare
  v_uid uuid:=public.lts_browser_assert_user_v1();
  v_base jsonb;
  v_pensions jsonb:='[]'::jsonb;
  v_pension_total numeric:=0;
  v_rsu jsonb:='{}'::jsonb;
  v_commitments jsonb;
  v_docs jsonb;
  v_cipo_components jsonb:='[]'::jsonb;
  v_base_assets numeric:=0;
  v_base_net numeric:=0;
begin
  v_base:=public.lts_browser_wealth_detail_v2();
  with latest as (
    select distinct on (legacy_id) legacy_id,asset_name,as_of_date,quantity,unit_price,value_brl,liquidity_class,availability_note,metadata
    from public.asset_positions
    where user_id=v_uid and asset_type='private_pension'
    order by legacy_id,as_of_date desc,id desc
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',legacy_id,'name',asset_name,'as_of',as_of_date,'units',quantity,'unit_value',unit_price,
      'gross_balance_brl',value_brl,'liquidity_class',liquidity_class,'availability_note',availability_note,
      'tax_regime',metadata->>'tax_regime','profile',metadata->>'profile',
      'participant_balance_brl',metadata->'participant_balance_brl','sponsor_balance_brl',metadata->'sponsor_balance_brl',
      'monthly_return_brl',metadata->'monthly_return_brl','monthly_return_pct',metadata->'monthly_return_pct',
      'source_label',metadata->>'source_label'
    ) order by asset_name),'[]'::jsonb),coalesce(sum(value_brl),0)
    into v_pensions,v_pension_total from latest;

  select jsonb_build_object(
    'vested_shares_brl',coalesce(sum(value_brl) filter(where asset_type='RSU' and is_available_now),0),
    'brokerage_cash_brl',coalesce(sum(value_brl) filter(where asset_type='brokerage_cash' and is_available_now),0),
    'available_total_brl',coalesce(sum(value_brl) filter(where asset_type in ('RSU','brokerage_cash') and is_available_now),0),
    'as_of',max(as_of_date) filter(where asset_type in ('RSU','brokerage_cash')),
    'future_regular_brl',coalesce((select sum(coalesce(gross_value_brl,net_value_brl)) from public.lts_future_liquidity_schedule where user_id=v_uid and active and upper(trim(asset_type))='RSU'),0),
    'future_cash_net_brl',coalesce((select sum(coalesce(net_value_brl,gross_value_brl)) from public.lts_future_liquidity_schedule where user_id=v_uid and active and lower(asset_type) like '%cash%'),0),
    'future_considered_total_brl',coalesce((select sum(case when lower(asset_type) like '%cash%' then coalesce(net_value_brl,gross_value_brl) else coalesce(gross_value_brl,net_value_brl) end) from public.lts_future_liquidity_schedule where user_id=v_uid and active),0)
  ) into v_rsu
  from public.asset_positions where user_id=v_uid;

  v_commitments:=public.lts_commitments_summary_v1(v_uid,current_date);
  v_docs:=public.lts_documentary_commitments_v1(v_uid);
  v_cipo_components:=coalesce(v_base#>'{wealth,cipo_reconciliation,components}',v_base#>'{cipo,components}','[]'::jsonb);
  v_base_assets:=coalesce(nullif(v_base#>>'{wealth,summary,assets_central}','')::numeric,0);
  v_base_net:=coalesce(nullif(v_base#>>'{wealth,summary,net_worth_central}','')::numeric,0);

  return v_base||jsonb_build_object(
    'version','wealth-detail-v4-v167-pensions-financing',
    'pensions',jsonb_build_object('total_gross_brl',v_pension_total,'positions',v_pensions,
      'tax_note','Regime regressivo: a alíquota depende do tempo de cada contribuição; o saldo líquido não é inferido.'),
    'rsu_summary',v_rsu,
    'financing',jsonb_build_object('summary',v_commitments,'documentary',v_docs),
    'cipo_detail',jsonb_build_object('components',v_cipo_components,
      'historical_purchase_plus_reform_brl',v_base#>'{wealth,assets,cipo_396,historical_purchase_plus_reform}',
      'current_payoff_brl',v_base#>'{wealth,assets,cipo_396,documentary_debt}',
      'contractual_outflow_current_terms_brl',(select x->'remaining_scheduled_outflow_current_terms'
        from jsonb_array_elements(coalesce(v_commitments->'commitments','[]'::jsonb)) x
        where x->>'id'='cipo_396' limit 1),
      'subject_to_tr',true),
    'wealth_v167',jsonb_build_object('assets_central_including_pensions',v_base_assets+v_pension_total,
      'net_worth_central_including_pensions',v_base_net+v_pension_total,'pensions_are_restricted',true),
    'schiavalli',jsonb_build_object('status','documentary_position_not_located','included_in_total',false)
  );
end
$function$;

revoke execute on function public.lts_flow_historical_balance_truth_overlay_v1(uuid,jsonb) from public,anon,authenticated;
revoke execute on function public.lts_daily_flow_fix86_v20(uuid,date,date) from public,anon,authenticated;
revoke execute on function public.lts_flow_future_read_cache_refresh_v9(uuid,integer) from public,anon,authenticated;
revoke execute on function public.lts_flow_future_read_slice_v9(uuid,date,date) from public,anon,authenticated;
revoke all on function public.lts_browser_wealth_detail_v3() from public,anon;
grant execute on function public.lts_browser_wealth_detail_v3() to authenticated;
revoke all on function public.lts_browser_flow_v11(date,date) from public,anon;
grant execute on function public.lts_browser_flow_v11(date,date) to authenticated;

create or replace function public.lts_browser_create_internal_transfer_v1(
  p_date date,
  p_amount numeric,
  p_from_account text,
  p_to_account text,
  p_description text,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
declare
  v_uid uuid:=public.lts_browser_assert_user_v1();
  v_from_id uuid;
  v_to_id uuid;
  v_group text;
  v_existing integer;
begin
  if p_date is null or p_date<current_date-interval '30 days' or p_date>current_date+interval '15 years' then raise exception 'invalid transfer date'; end if;
  if p_amount is null or p_amount<=0 or p_amount>100000000 then raise exception 'invalid transfer amount'; end if;
  if length(trim(coalesce(p_idempotency_key,'')))<8 then raise exception 'idempotency key required'; end if;
  if lower(trim(coalesce(p_from_account,'')))=lower(trim(coalesce(p_to_account,''))) then raise exception 'origin and destination must differ'; end if;
  select id into v_from_id from public.accounts where user_id=v_uid and is_active and lower(institution)=lower(trim(p_from_account)) limit 1;
  select id into v_to_id from public.accounts where user_id=v_uid and is_active and lower(institution)=lower(trim(p_to_account)) limit 1;
  if v_from_id is null or v_to_id is null then raise exception 'approved bank account not found'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text||p_idempotency_key,167));
  select count(*) into v_existing from public.financial_events where user_id=v_uid and metadata->>'idempotency_key'=p_idempotency_key;
  if v_existing>=2 then return jsonb_build_object('ok',true,'idempotent',true,'legs',v_existing); end if;
  v_group:='transfer:'||p_idempotency_key;
  insert into public.financial_events(user_id,account_id,event_date,description_raw,description_normalized,amount,nature,category,counterparty,source,status,is_internal_transfer,is_projection,is_suppressed,metadata)
  values
   (v_uid,v_from_id,p_date,coalesce(nullif(trim(p_description),''),'Transferência entre contas'),coalesce(nullif(trim(p_description),''),'Transferência entre contas'),-abs(p_amount),'expense','Movimentação interna','Própria','manual_transfer_reviewed',case when p_date<=current_date then 'active' else 'scheduled' end,true,p_date>current_date,false,jsonb_build_object('transfer_group',v_group,'idempotency_key',p_idempotency_key,'leg','out')),
   (v_uid,v_to_id,p_date,coalesce(nullif(trim(p_description),''),'Transferência entre contas'),coalesce(nullif(trim(p_description),''),'Transferência entre contas'), abs(p_amount),'income','Movimentação interna','Própria','manual_transfer_reviewed',case when p_date<=current_date then 'active' else 'scheduled' end,true,p_date>current_date,false,jsonb_build_object('transfer_group',v_group,'idempotency_key',p_idempotency_key,'leg','in'));
  insert into public.audit_log(user_id,action,entity_type,entity_id,details)
  values(v_uid,'create_reviewed_internal_transfer','transfer_group',v_group,jsonb_build_object('date',p_date,'amount',abs(p_amount),'from',p_from_account,'to',p_to_account,'description',p_description));
  delete from public.lts_flow_future_read_cache where user_id=v_uid;
  delete from public.lts_flow_future_read_cache_v2 where user_id=v_uid;
  return jsonb_build_object('ok',true,'idempotent',false,'transfer_group',v_group,'legs',2,'consolidated_effect',0);
end
$function$;

revoke all on function public.lts_browser_create_internal_transfer_v1(date,numeric,text,text,text,text) from public,anon;
grant execute on function public.lts_browser_create_internal_transfer_v1(date,numeric,text,text,text,text) to authenticated;
