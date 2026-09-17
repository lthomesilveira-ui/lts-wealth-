-- V170 follow-up: make historical cash arithmetic use the same perimeter as
-- the visible consolidated bank balance.  Only Itaú, Bradesco and C6 move
-- that balance.  Paired own-account transfers net to zero; a crossing to an
-- untracked resource (for example, a savings pocket) remains visible as a
-- net internal movement without becoming revenue or expense.

create or replace function public.lts_flow_historical_relative_balance_overlay_v1(
  p_user_id uuid,
  p_flow jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public
set "TimeZone" = 'America/Sao_Paulo'
as $function$
declare
  v_origin date := date '2013-10-09';
  v_max_date date;
  v_days jsonb;
begin
  select max(nullif(x->>'date','')::date)
    into v_max_date
  from jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'::jsonb)) x;

  if v_max_date is null then
    return p_flow || jsonb_build_object(
      'historical_relative_balance_contract',jsonb_build_object(
        'version','historical-tracked-bank-ledger-v2',
        'opening_basis_date',v_origin,
        'opening_basis_brl',0,
        'display','no_historical_days'
      )
    );
  end if;

  with source_rows as materialized (
    select *
    from public.lts_flow_past_operational_v2(p_user_id,v_origin+1,v_max_date)
  ), normalized as (
    select s.*,
           translate(lower(trim(coalesce(s.account,''))),
             'áàâãäéèêëíìîïóòôõöúùûüç',
             'aaaaaeeeeiiiiooooouuuuc') normalized_account
    from source_rows s
  ), daily as (
    select event_date,
           coalesce(sum(signed_amount) filter (
             where normalized_account in ('itau','bradesco','c6')
               and coalesce(source,'') <> 'economic_withholding'
           ),0)::numeric consolidated_delta,
           coalesce(sum(signed_amount) filter (
             where normalized_account='itau'
               and coalesce(source,'') <> 'economic_withholding'
           ),0)::numeric itau_delta,
           coalesce(sum(signed_amount) filter (
             where normalized_account='bradesco'
               and coalesce(source,'') <> 'economic_withholding'
           ),0)::numeric bradesco_delta,
           coalesce(sum(signed_amount) filter (
             where normalized_account='c6'
               and coalesce(source,'') <> 'economic_withholding'
           ),0)::numeric c6_delta
    from normalized
    group by event_date
  ), calendar as (
    select (v_origin+g.day_offset)::date dt,
           coalesce(d.consolidated_delta,0) consolidated_delta,
           coalesce(d.itau_delta,0) itau_delta,
           coalesce(d.bradesco_delta,0) bradesco_delta,
           coalesce(d.c6_delta,0) c6_delta
    from generate_series(0,v_max_date-v_origin) g(day_offset)
    left join daily d on d.event_date=v_origin+g.day_offset
  ), running as (
    select dt,consolidated_delta,
           sum(consolidated_delta) over(order by dt rows unbounded preceding) consolidated_close,
           sum(itau_delta) over(order by dt rows unbounded preceding) itau_close,
           sum(bradesco_delta) over(order by dt rows unbounded preceding) bradesco_close,
           sum(c6_delta) over(order by dt rows unbounded preceding) c6_close
    from calendar
  ), requested as (
    select d.x,d.ord,r.dt,r.consolidated_delta,r.consolidated_close,
           r.itau_close,r.bradesco_close,r.c6_close
    from jsonb_array_elements(coalesce(p_flow#>'{historical,days}','[]'::jsonb))
         with ordinality d(x,ord)
    join running r on r.dt=(d.x->>'date')::date
  ), account_patch as (
    select ord,dt,consolidated_delta,consolidated_close,
      case when x#>>'{Itaú,balance}' is null
        then jsonb_set(
               jsonb_set(
                 jsonb_set(x,array['Itaú','balance'],to_jsonb(itau_close),true),
                 array['Itaú','balance_certified'],'false'::jsonb,true
               ),
               array['Itaú','balance_basis'],to_jsonb('relative_tracked_bank_ledger'::text),true
             ) else x end x1,
      bradesco_close,c6_close
    from requested
  ), bradesco_patch as (
    select ord,dt,consolidated_delta,consolidated_close,c6_close,
      case when x1#>>'{Bradesco,balance}' is null
        then jsonb_set(
               jsonb_set(
                 jsonb_set(x1,array['Bradesco','balance'],to_jsonb(bradesco_close),true),
                 array['Bradesco','balance_certified'],'false'::jsonb,true
               ),
               array['Bradesco','balance_basis'],to_jsonb('relative_tracked_bank_ledger'::text),true
             ) else x1 end x2
    from account_patch
  ), c6_patch as (
    select ord,dt,consolidated_delta,consolidated_close,
      case when x2#>>'{C6,balance}' is null
        then jsonb_set(
               jsonb_set(
                 jsonb_set(x2,array['C6','balance'],to_jsonb(c6_close),true),
                 array['C6','balance_certified'],'false'::jsonb,true
               ),
               array['C6','balance_basis'],to_jsonb('relative_tracked_bank_ledger'::text),true
             ) else x2 end x3
    from bradesco_patch
  ), consolidated_patch as (
    select ord,consolidated_delta,consolidated_close,
           (x3#>>'{Consolidado,bank_balance}' is null) relative_applied,
      case when x3#>>'{Consolidado,bank_balance}' is null
        then jsonb_set(
               jsonb_set(
                 jsonb_set(
                   x3,array['Consolidado','bank_balance'],to_jsonb(consolidated_close),true
                 ),
                 array['Consolidado','balance_certified'],'false'::jsonb,true
               ),
               array['Consolidado','balance_basis'],to_jsonb('relative_tracked_bank_ledger'::text),true
             ) || jsonb_build_object(
               'evidence_status','relative_tracked_bank_ledger_before_complete_documentary_opening',
               'absolute_balance_basis',null,
               'absolute_balance_certified',false,
               'absolute_balance_reconstructed',false,
               'relative_balance_display',true
             )
        else x3 end x4
    from c6_patch
  ), fix_patch as (
    select ord,
      case when relative_applied then
        jsonb_set(
          x4,
          '{fix86_columns}',
          coalesce(x4->'fix86_columns','{}'::jsonb) || jsonb_build_object(
            'saldo_anterior',consolidated_close-consolidated_delta,
            'saldo_anterior_operacional',consolidated_close-consolidated_delta,
            'saldo_final',consolidated_close,
            'saldo_final_operacional',consolidated_close
          ),
          true
        )
      else x4 end x5
    from consolidated_patch
  )
  select coalesce(jsonb_agg(x5 order by ord),'[]'::jsonb)
    into v_days
  from fix_patch;

  return jsonb_set(p_flow,'{historical,days}',v_days,true) || jsonb_build_object(
    'historical_relative_balance_contract',jsonb_build_object(
      'version','historical-tracked-bank-ledger-v2',
      'opening_basis_date',v_origin,
      'opening_basis_brl',0,
      'continuity','global_from_2013_10_09_not_reset_by_selected_range',
      'consolidated_rule','Itaú + Bradesco + C6 cash movements; paired transfers net to zero',
      'internal_transfer_rule','net crossing to an untracked resource remains a cash movement, never revenue or expense',
      'excluded_rule','unassigned analytical rows and payroll withholding do not move tracked bank cash',
      'guardrail','Relative balances fill arithmetic columns before complete documentary opening and are never labeled as documentary bank balances.'
    )
  );
end
$function$;

revoke all on function public.lts_flow_historical_relative_balance_overlay_v1(uuid,jsonb)
  from public, anon, authenticated;
