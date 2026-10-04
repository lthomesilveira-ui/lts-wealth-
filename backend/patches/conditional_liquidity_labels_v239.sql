CREATE OR REPLACE FUNCTION public.lts_browser_planning_ui_contract_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
declare j jsonb:=public.lts_browser_planning_executive_v2(); d01 text; rsu text; fg text;
begin
 if j->>'version'<>'planning-executive-v2-current-anchors' then raise exception 'planning v2 not ready'; end if;
 select x->>'first_need_next_layer' into d01 from jsonb_array_elements(j->'layers') x where x->>'id'='d01';
 select x->>'first_need_next_layer' into rsu from jsonb_array_elements(j->'layers') x where x->>'id'='future_vestings';
 fg:=j#>>'{summary,first_negative_even_with_fgts}';
 return jsonb_build_object('version','planning-ui-contract-v2','period_to',j#>>'{period,to}','d01_first_need',d01,'rsu_first_need',rsu,'fgts_first_negative',fg,'fgts_covers_horizon',(j#>>'{summary,fgts_covers_horizon}')::boolean,'fgts_request_by',j#>>'{summary,fgts_request_by}',
 'labels',jsonb_build_object('d01',case when d01 is null then 'Caixa consolidado após D0/D1 preservado até 31/12/2027' else 'Caixa consolidado após D0/D1 fica negativo em '||to_char(d01::date,'DD/MM/YYYY') end,
 'rsu',case when rsu is null then 'Com RSUs atuais e vestings programados, sem ruptura até 31/12/2027' else 'Com RSUs atuais e vestings programados, a primeira falta ocorre em '||to_char(rsu::date,'DD/MM/YYYY') end,
 'fgts',case when fg is null then 'Com FGTS, sem ruptura até 31/12/2027' else 'Mesmo com FGTS, a primeira falta ocorre em '||to_char(fg::date,'DD/MM/YYYY') end));
end $function$;
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
    'note','Sensibilidade limitada a Volvo e IPVA. Só considerar esta comparação explicada quando status=explained e as datas coincidirem. Em requires_review, ela não reproduz o baseline e não explica mudanças de fontes posteriores.'
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
