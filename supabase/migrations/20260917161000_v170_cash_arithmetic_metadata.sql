-- V170 cash arithmetic proof carried with every historical day.

create or replace function public.lts_flow_historical_cash_arithmetic_overlay_v1(
  p_user_id uuid,
  p_flow jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public
set "TimeZone" = 'America/Sao_Paulo'
as $function$
declare
  v_from date;
  v_to date;
  v_days jsonb;
begin
  select min(nullif(x->>'date','')::date),max(nullif(x->>'date','')::date)
    into v_from,v_to
  from jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'::jsonb)) x;

  if v_from is null or v_to is null then
    return p_flow || jsonb_build_object(
      'historical_cash_arithmetic_contract',jsonb_build_object(
        'version','tracked-bank-cash-arithmetic-v1',
        'display','no_historical_days'
      )
    );
  end if;

  with rows as materialized (
    select r.*,
           translate(lower(trim(coalesce(r.account,''))),
             'áàâãäéèêëíìîïóòôõöúùûüç',
             'aaaaaeeeeiiiiooooouuuuc') normalized_account
    from public.lts_flow_past_operational_v2(p_user_id,v_from,v_to) r
  ), daily as (
    select event_date,
           coalesce(sum(signed_amount) filter (
             where normalized_account in ('itau','bradesco','c6')
               and coalesce(source,'') <> 'economic_withholding'
               and not coalesce(internal_transfer,false)
               and signed_amount>0
           ),0)::numeric operating_entries,
           abs(coalesce(sum(signed_amount) filter (
             where normalized_account in ('itau','bradesco','c6')
               and coalesce(source,'') <> 'economic_withholding'
               and not coalesce(internal_transfer,false)
               and signed_amount<0
           ),0))::numeric operating_exits,
           coalesce(sum(signed_amount) filter (
             where normalized_account in ('itau','bradesco','c6')
               and coalesce(source,'') <> 'economic_withholding'
               and coalesce(internal_transfer,false)
           ),0)::numeric internal_transfer_net
    from rows
    group by event_date
  ), patched as (
    select d.ord,
           d.x || jsonb_build_object(
             'v170_cash_arithmetic',jsonb_build_object(
               'version','tracked-bank-cash-arithmetic-v1',
               'operating_entries_brl',coalesce(a.operating_entries,0),
               'operating_exits_brl',coalesce(a.operating_exits,0),
               'internal_transfer_net_brl',coalesce(a.internal_transfer_net,0),
               'tracked_bank_net_brl',coalesce(a.operating_entries,0)-coalesce(a.operating_exits,0)+coalesce(a.internal_transfer_net,0),
               'arithmetic_gap_brl',round((
                 coalesce(nullif(d.x#>>'{fix86_columns,saldo_final_operacional}','')::numeric,
                          nullif(d.x#>>'{Consolidado,bank_balance}','')::numeric,0)
                 - coalesce(nullif(d.x#>>'{fix86_columns,saldo_anterior_operacional}','')::numeric,
                            nullif(d.x#>>'{fix86_columns,saldo_anterior}','')::numeric,0)
                 - (coalesce(a.operating_entries,0)-coalesce(a.operating_exits,0)+coalesce(a.internal_transfer_net,0))
               )::numeric,2),
               'balanced',abs(
                 coalesce(nullif(d.x#>>'{fix86_columns,saldo_final_operacional}','')::numeric,
                          nullif(d.x#>>'{Consolidado,bank_balance}','')::numeric,0)
                 - coalesce(nullif(d.x#>>'{fix86_columns,saldo_anterior_operacional}','')::numeric,
                            nullif(d.x#>>'{fix86_columns,saldo_anterior}','')::numeric,0)
                 - (coalesce(a.operating_entries,0)-coalesce(a.operating_exits,0)+coalesce(a.internal_transfer_net,0))
               )<=0.02
             )
           ) x
    from jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'::jsonb))
         with ordinality d(x,ord)
    left join daily a on a.event_date=(d.x->>'date')::date
  )
  select coalesce(jsonb_agg(x order by ord),'[]'::jsonb)
    into v_days
  from patched;

  return jsonb_set(p_flow,'{historical,days}',v_days,true) || jsonb_build_object(
    'historical_cash_arithmetic_contract',jsonb_build_object(
      'version','tracked-bank-cash-arithmetic-v1',
      'perimeter',jsonb_build_array('Itaú','Bradesco','C6'),
      'equation','saldo anterior + entradas operacionais - saídas operacionais + movimentação interna líquida = saldo final',
      'transfer_rule','paired tracked-account legs net to zero; an untracked counter-leg remains a net internal cash movement',
      'classification_rule','internal movements are neither revenue nor expense'
    )
  );
end
$function$;

revoke all on function public.lts_flow_historical_cash_arithmetic_overlay_v1(uuid,jsonb)
  from public, anon, authenticated;

do $migration$
declare
  v_definition text;
  v_before text;
begin
  select pg_get_functiondef('public.lts_browser_flow_v12(date,date)'::regprocedure)
    into v_definition;
  v_before:=v_definition;

  if position('lts_flow_historical_cash_arithmetic_overlay_v1' in v_definition)>0 then
    return;
  end if;

  v_definition:=replace(
    v_definition,
    'v_flow:=public.lts_flow_historical_relative_balance_overlay_v1(v_uid,v_flow);',
    'v_flow:=public.lts_flow_historical_relative_balance_overlay_v1(v_uid,v_flow);' || chr(10) ||
    '    v_flow:=public.lts_flow_historical_cash_arithmetic_overlay_v1(v_uid,v_flow);'
  );

  if v_definition=v_before
    or position('lts_flow_historical_cash_arithmetic_overlay_v1' in v_definition)=0 then
    raise exception 'V170 cash-arithmetic insertion point not found';
  end if;

  execute v_definition;
end
$migration$;

revoke all on function public.lts_browser_flow_v12(date,date) from public, anon;
grant execute on function public.lts_browser_flow_v12(date,date) to authenticated;
