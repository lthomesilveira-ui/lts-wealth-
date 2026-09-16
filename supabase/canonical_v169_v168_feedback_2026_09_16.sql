-- V169: preserve calendar dates across Brazilian DST boundaries.
-- Generated from the live V168 function definitions on 2026-09-16.
-- Only date-series constructors are changed in this section.

-- lts_daily_flow_full_query_v4: civil-date series (DST safe)
CREATE OR REPLACE FUNCTION public.lts_daily_flow_full_query_v4(p_user_id uuid, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  hist jsonb; fut jsonb;
  y0 int:=2013;
  y1 int:=extract(year from current_date)::int + coalesce((select nullif(valor_bruto,'')::int from public.legacy_namespace where usuario_id=p_user_id and chave='lts_horizonte_anos' limit 1),15);
  v_as_of date:=coalesce(nullif(public.lts_current_evidence_position_v1(p_user_id)->>'as_of','')::date,current_date-1);
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
  if p_to-p_from>730 then raise exception 'range too large; query at most 731 days'; end if;

  with e as materialized (
    select event_date,account,description,signed_amount,
           case when signed_amount>=0 then 'entrada' else 'saida' end direction,
           abs(signed_amount) amount,source,source_ref,confidence,account_assignment,internal_transfer,category,counterparty,center_cost,excluded_from_spend
    from public.lts_flow_past_operational_v1(p_user_id,p_from,least(p_to,current_date-1))
  ), d as (
    select (p_from+s.n)::date dt
    from generate_series(0,least(p_to,current_date-1)-p_from) as s(n)
  ), a0 as (
    select d.dt,
      coalesce(sum(e.amount) filter(where e.direction='entrada' and e.account in ('Itaú','Bradesco','C6')),0) bank_entries,
      coalesce(sum(e.amount) filter(where e.direction='saida' and e.account in ('Itaú','Bradesco','C6')),0) bank_exits,
      coalesce(sum(e.signed_amount) filter(where e.account in ('Itaú','Bradesco','C6')),0) bank_net,
      coalesce(sum(e.signed_amount) filter(where not e.internal_transfer and e.account in ('Itaú','Bradesco','C6')),0) economic_net,
      coalesce(sum(e.signed_amount) filter(where e.account='Itaú'),0) itau_net,
      coalesce(sum(e.signed_amount) filter(where e.account='Bradesco'),0) bradesco_net,
      coalesce(sum(e.signed_amount) filter(where e.account='C6'),0) c6_net,
      count(e.*) n,count(e.*) filter(where e.internal_transfer) transfer_n
    from d left join e on e.event_date=d.dt group by d.dt
  ), a as (
    select a0.*,
      sum(bank_net) over(order by dt) relative_consolidated_balance,
      sum(itau_net) over(order by dt) relative_itau_balance,
      sum(bradesco_net) over(order by dt) relative_bradesco_balance,
      sum(c6_net) over(order by dt) relative_c6_balance
    from a0
  ), anchors as (
    select max(amount) filter(where evidence_type='balance_anchor' and evidence_date='2026-07-07' and account='Itaú') itau_start,
      105.76::numeric bradesco_start,0::numeric c6_start
    from public.lts_reconciliation_evidence where user_id=p_user_id
  ), tail as (
    select coalesce(sum(signed_amount) filter(where account='Itaú'),0) itau_tail,
      coalesce(sum(signed_amount) filter(where account='Bradesco'),0) bradesco_tail,
      coalesce(sum(signed_amount) filter(where account='C6'),0) c6_tail
    from public.lts_historical_effective_cash_v3(p_user_id,p_from,date '2026-07-07')
    where p_from<=date '2026-07-07'
  ), backward as (
    select a.dt,anchors.itau_start-tail.itau_tail+a.relative_itau_balance itau_balance,
      anchors.bradesco_start-tail.bradesco_tail+a.relative_bradesco_balance bradesco_balance,
      anchors.c6_start-tail.c6_tail+a.relative_c6_balance c6_balance
    from a cross join anchors cross join tail where a.dt<=date '2026-07-07'
  ), ae as materialized (
    select * from public.lts_flow_past_operational_v1(p_user_id,'2026-07-08',current_date-1)
  ), ad as (
    select (date '2026-07-07'+s.n)::date dt
    from generate_series(0,(current_date-1)-date '2026-07-07') as s(n)
  ), aa0 as (
    select ad.dt,
      coalesce(sum(ae.signed_amount) filter(where ae.account='Itaú'),0) itau_net,
      coalesce(sum(ae.signed_amount) filter(where ae.account='Bradesco'),0) bradesco_net,
      coalesce(sum(ae.signed_amount) filter(where ae.account='C6'),0) c6_net
    from ad left join ae on ae.event_date=ad.dt group by ad.dt
  ), arun0 as (
    select aa0.dt,anchors.itau_start+sum(aa0.itau_net) over(order by aa0.dt) itau_balance,
      anchors.bradesco_start+sum(aa0.bradesco_net) over(order by aa0.dt) bradesco_balance,
      anchors.c6_start+sum(aa0.c6_net) over(order by aa0.dt) c6_balance
    from aa0 cross join anchors
  ), arun as (
    select arun0.*,itau_balance+bradesco_balance+c6_balance consolidated_balance from arun0
  ), aj as (
    select a.*,coalesce(b.itau_balance,r.itau_balance) abs_itau,coalesce(b.bradesco_balance,r.bradesco_balance) abs_bradesco,
      coalesce(b.c6_balance,r.c6_balance) abs_c6,coalesce(b.itau_balance+b.bradesco_balance+b.c6_balance,r.consolidated_balance) abs_consolidated,
      case when b.dt is not null then 'backward_from_07_07_anchor' when r.dt is not null and a.dt<=v_as_of then 'forward_from_07_07_anchor' when r.dt is not null then 'post_position_operational_carry' end absolute_basis
    from a left join backward b on b.dt=a.dt left join arun r on r.dt=a.dt
  )
  select jsonb_build_object(
    'days',coalesce(jsonb_agg(jsonb_build_object(
      'date',dt,'historical',true,'evidence_status',case when dt<=v_as_of then 'through_certified_position' else 'post_position_pending_reconciliation' end,
      'summary',jsonb_build_object('entries',bank_entries,'exits',bank_exits,'net',bank_net,'economic_net',economic_net,'events',n,'transfers',transfer_n),
      'Itaú',jsonb_build_object('net',itau_net,'relative_balance',relative_itau_balance)||case when abs_itau is not null then jsonb_build_object('balance',abs_itau,'balance_certified',dt<=v_as_of) else '{}'::jsonb end,
      'Bradesco',jsonb_build_object('net',bradesco_net,'relative_balance',relative_bradesco_balance)||case when abs_bradesco is not null then jsonb_build_object('balance',abs_bradesco,'balance_certified',dt<=v_as_of) else '{}'::jsonb end,
      'C6',jsonb_build_object('net',c6_net,'relative_balance',relative_c6_balance)||case when abs_c6 is not null then jsonb_build_object('balance',abs_c6,'balance_certified',dt<=v_as_of) else '{}'::jsonb end,
      'Consolidado',jsonb_build_object('net',bank_net,'economic_net',economic_net,'relative_balance',relative_consolidated_balance)||case when abs_consolidated is not null then jsonb_build_object('bank_balance',abs_consolidated,'balance_certified',dt<=v_as_of) else '{}'::jsonb end
    )||case when abs_consolidated is not null then jsonb_build_object('absolute_balance_certified',dt<=v_as_of,'absolute_balance_reconstructed',true,'absolute_balance_basis',absolute_basis) else '{}'::jsonb end order by dt),'[]'::jsonb),
    'events',coalesce((select jsonb_agg(jsonb_build_object('event_date',event_date,'account',account,'account_attribution',account_assignment,'description',description,'direction',direction,'signed_amount',signed_amount,'category',category,'counterparty',counterparty,'center_cost',center_cost,'source',source,'source_ref',source_ref,'confidence',confidence,'internal_transfer',internal_transfer,'excluded',excluded_from_spend) order by event_date,source,description) from e),'[]'::jsonb)
  ) into hist from aj;

  if p_to>=current_date then select public.lts_daily_flow_fix86_v9(p_user_id,greatest(p_from,current_date),p_to) into fut;
  else fut:=jsonb_build_object('days','[]'::jsonb,'events','[]'::jsonb); end if;

  return jsonb_build_object('version','daily-flow-full-query-v4-post-position-operational','from',p_from,'to',p_to,'available_from','2013-10-10'::date,'available_year_from',y0,'available_year_to',y1,
    'bank_tabs',jsonb_build_array('Consolidado','Itaú','Bradesco','C6'),'filters',jsonb_build_object('presets',jsonb_build_array('Hoje','3 meses','Fim do ano','Tudo'),'manual_range',true,'year_selector',true,'future_years',true),
    'historical',hist,'current_future',fut,
    'historical_account_audit',jsonb_build_object('candidate_bank_2013_2017','Itaú','absolute_balance_status','reconstructed_from_certified_anchor','anchor_date','2026-07-07','latest_certified_position',v_as_of,'display_policy','Até a última posição documental, histórico factual. Depois dela, compromissos e fatos operacionais permanecem no fluxo até a próxima reconciliação, sem desaparecer na virada do dia.'),
    'contract',jsonb_build_object('historical_actuals_from_2013',true,'historical_events_in_rows',true,'historical_absolute_balance_reconstructed',true,'post_position_operational_carry',true,'backward_anchor_date','2026-07-07','future_on_demand',true,'max_query_days',731));
end;
$function$;

-- User-created internal transfers remain a single logical operation even
-- though the ledger stores one debit and one credit. The editor and mutator
-- below always read and write the pair atomically and append-only.
create or replace function public.lts_internal_transfer_editor_v1(
  p_user_id uuid,
  p_source_ref text
) returns jsonb
language plpgsql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
declare
  v_target_id uuid;
  v_group text;
  v_legs jsonb:='[]'::jsonb;
  v_out jsonb;
  v_in jsonb;
  v_count integer:=0;
  v_sum numeric:=0;
begin
  begin
    v_target_id:=replace(coalesce(p_source_ref,''),'financial_events:','')::uuid;
  exception when others then
    return jsonb_build_object('editable',false,'reason','Transferência não identificada.');
  end;

  select fe.metadata->>'transfer_group' into v_group
  from public.financial_events fe
  where fe.user_id=p_user_id and fe.id=v_target_id
    and fe.source='manual_transfer_reviewed'
    and coalesce(fe.is_internal_transfer,false)=true
    and coalesce(fe.is_suppressed,false)=false;

  if nullif(v_group,'') is null then
    return jsonb_build_object('editable',false,'reason','A origem não é uma transferência manual editável.');
  end if;

  with latest as (
    select distinct on (o.target_event_id)
      o.target_event_id,o.operation,o.payload,o.op_seq
    from public.lts_flow_event_operation o
    where o.user_id=p_user_id and o.active
    order by o.target_event_id,o.op_seq desc
  ), effective as (
    select
      fe.id,
      fe.amount base_amount,
      l.operation,
      coalesce(nullif(l.payload->>'event_date','')::date,fe.event_date) event_date,
      coalesce(nullif(trim(l.payload->>'description'),''),fe.description_normalized,fe.description_raw,'Transferência entre contas') description,
      coalesce(nullif(trim(l.payload->>'account'),''),case when a.institution='Itau' then 'Itaú' else a.institution end) account,
      case when fe.amount<0
           then -abs(coalesce(nullif(l.payload->>'amount','')::numeric,fe.amount))
           else  abs(coalesce(nullif(l.payload->>'amount','')::numeric,fe.amount)) end signed_amount
    from public.financial_events fe
    left join public.accounts a on a.id=fe.account_id and a.user_id=fe.user_id
    left join latest l on l.target_event_id=fe.id
    where fe.user_id=p_user_id
      and fe.metadata->>'transfer_group'=v_group
      and fe.source='manual_transfer_reviewed'
      and coalesce(fe.is_internal_transfer,false)=true
      and coalesce(fe.is_suppressed,false)=false
      and coalesce(l.operation,'')<>'cancel'
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'id',id,'event_date',event_date,'description',description,
           'account',account,'signed_amount',signed_amount
         ) order by signed_amount),'[]'::jsonb),
         count(*)::integer,coalesce(sum(signed_amount),0)
    into v_legs,v_count,v_sum
  from effective;

  if v_count<>2 then
    return jsonb_build_object('editable',false,'reason','A transferência não possui duas pernas ativas e íntegras.','transfer_group',v_group);
  end if;

  select value into v_out from jsonb_array_elements(v_legs) where (value->>'signed_amount')::numeric<0 limit 1;
  select value into v_in  from jsonb_array_elements(v_legs) where (value->>'signed_amount')::numeric>0 limit 1;

  if v_out is null or v_in is null
     or abs(v_sum)>0.005
     or abs(abs((v_out->>'signed_amount')::numeric)-abs((v_in->>'signed_amount')::numeric))>0.005
     or (v_out->>'event_date')<>(v_in->>'event_date')
     or replace(lower(v_out->>'account'),'ú','u')=replace(lower(v_in->>'account'),'ú','u') then
    return jsonb_build_object('editable',false,'reason','As duas pernas da transferência perderam a neutralidade ou a correspondência.','transfer_group',v_group,'legs',v_legs);
  end if;

  return jsonb_build_object(
    'editable',true,
    'kind','internal_transfer_pair',
    'source','internal_transfer',
    'source_ref','financial_events:'||v_target_id::text,
    'transfer_group',v_group,
    'event_date',v_out->>'event_date',
    'description',v_out->>'description',
    'amount',abs((v_out->>'signed_amount')::numeric),
    'display_amount',abs((v_out->>'signed_amount')::numeric),
    'from_account',v_out->>'account',
    'to_account',v_in->>'account',
    'consolidated_effect',v_sum,
    'legs',v_legs,
    'actions',jsonb_build_array('edit','cancel')
  );
end
$function$;

create or replace function public.lts_internal_transfer_mutate_v1(
  p_user_id uuid,
  p_action text,
  p_source_ref text,
  p_payload jsonb,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
declare
  v_editor jsonb;
  v_group text;
  v_out_id uuid;
  v_in_id uuid;
  v_date date;
  v_amount numeric;
  v_description text;
  v_from text;
  v_to text;
  v_result jsonb;
begin
  if p_action not in ('edit','cancel') then raise exception 'unsupported transfer action'; end if;
  if length(trim(coalesce(p_idempotency_key,'')))<8 then raise exception 'idempotency key required'; end if;

  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text||':'||p_source_ref,169));
  select a.result into v_result
  from public.lts_flow_mutation_audit a
  where a.user_id=p_user_id and a.idempotency_key=p_idempotency_key
  limit 1;
  if found then return v_result||jsonb_build_object('idempotent',true); end if;

  v_editor:=public.lts_internal_transfer_editor_v1(p_user_id,p_source_ref);
  if not coalesce((v_editor->>'editable')::boolean,false) then
    raise exception '%',coalesce(v_editor->>'reason','transfer not editable');
  end if;
  v_group:=v_editor->>'transfer_group';

  select fe.id into v_out_id
  from public.financial_events fe
  where fe.user_id=p_user_id and fe.metadata->>'transfer_group'=v_group and fe.amount<0
  order by fe.created_at,fe.id limit 1;
  select fe.id into v_in_id
  from public.financial_events fe
  where fe.user_id=p_user_id and fe.metadata->>'transfer_group'=v_group and fe.amount>0
  order by fe.created_at,fe.id limit 1;
  if v_out_id is null or v_in_id is null then raise exception 'transfer pair not found'; end if;

  if p_action='edit' then
    v_date:=coalesce(nullif(p_payload->>'event_date','')::date,(v_editor->>'event_date')::date);
    v_amount:=coalesce(nullif(p_payload->>'amount','')::numeric,(v_editor->>'amount')::numeric);
    v_description:=coalesce(nullif(trim(p_payload->>'description'),''),v_editor->>'description');
    v_from:=coalesce(nullif(trim(p_payload->>'from_account'),''),v_editor->>'from_account');
    v_to:=coalesce(nullif(trim(p_payload->>'to_account'),''),v_editor->>'to_account');
    if replace(lower(v_from),'ú','u')='itau' then v_from:='Itaú'; end if;
    if replace(lower(v_to),'ú','u')='itau' then v_to:='Itaú'; end if;

    if v_date<date '2013-10-10' or v_date>current_date+interval '15 years' then raise exception 'invalid transfer date'; end if;
    if v_amount is null or v_amount<=0 or v_amount>100000000 then raise exception 'invalid transfer amount'; end if;
    if length(v_description)<2 or length(v_description)>180 then raise exception 'invalid transfer description'; end if;
    if v_from not in ('Itaú','Bradesco','C6') or v_to not in ('Itaú','Bradesco','C6') then raise exception 'unsupported transfer account'; end if;
    if v_from=v_to then raise exception 'origin and destination must differ'; end if;
    if not exists(select 1 from public.accounts a where a.user_id=p_user_id and a.is_active and replace(lower(a.institution),'ú','u')=replace(lower(v_from),'ú','u')) then raise exception 'origin account not found'; end if;
    if not exists(select 1 from public.accounts a where a.user_id=p_user_id and a.is_active and replace(lower(a.institution),'ú','u')=replace(lower(v_to),'ú','u')) then raise exception 'destination account not found'; end if;

    insert into public.lts_flow_event_operation(user_id,target_event_id,operation,payload,idempotency_key)
    values
      (p_user_id,v_out_id,'edit',jsonb_build_object('event_date',v_date,'amount',round(v_amount,2),'description',v_description,'account',v_from,'transfer_group',v_group,'leg','out','note',p_payload->>'note'),p_idempotency_key||':out'),
      (p_user_id,v_in_id ,'edit',jsonb_build_object('event_date',v_date,'amount',round(v_amount,2),'description',v_description,'account',v_to  ,'transfer_group',v_group,'leg','in' ,'note',p_payload->>'note'),p_idempotency_key||':in');
    v_result:=jsonb_build_object('ok',true,'action','edit','source','internal_transfer','source_ref',p_source_ref,'transfer_group',v_group,'event_date',v_date,'amount',round(v_amount,2),'from_account',v_from,'to_account',v_to,'legs_updated',2,'consolidated_effect',0);
  else
    insert into public.lts_flow_event_operation(user_id,target_event_id,operation,payload,idempotency_key)
    values
      (p_user_id,v_out_id,'cancel',jsonb_build_object('transfer_group',v_group,'leg','out','note',p_payload->>'note'),p_idempotency_key||':out'),
      (p_user_id,v_in_id ,'cancel',jsonb_build_object('transfer_group',v_group,'leg','in' ,'note',p_payload->>'note'),p_idempotency_key||':in');
    v_date:=(v_editor->>'event_date')::date;
    v_result:=jsonb_build_object('ok',true,'action','cancel','source','internal_transfer','source_ref',p_source_ref,'transfer_group',v_group,'legs_cancelled',2,'consolidated_effect',0);
  end if;

  insert into public.lts_flow_mutation_audit(user_id,action,source,source_ref,event_date,payload,idempotency_key,result)
  values(p_user_id,p_action,'internal_transfer',p_source_ref,v_date,coalesce(p_payload,'{}'::jsonb),p_idempotency_key,v_result);
  insert into public.audit_log(user_id,action,entity_type,entity_id,details)
  values(p_user_id,'mutate_internal_transfer_pair','transfer_group',v_group,v_result||jsonb_build_object('append_only',true));
  delete from public.lts_flow_future_read_cache where user_id=p_user_id;
  delete from public.lts_flow_future_read_cache_v2 where user_id=p_user_id;
  return v_result||jsonb_build_object('idempotent',false,'append_only',true);
end
$function$;

create or replace function public.lts_browser_internal_transfer_editor_v1(p_source_ref text)
returns jsonb
language plpgsql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
declare v_uid uuid:=public.lts_browser_assert_user_v1();
begin
  return public.lts_internal_transfer_editor_v1(v_uid,p_source_ref);
end
$function$;

create or replace function public.lts_browser_internal_transfer_mutate_v1(
  p_action text,
  p_source_ref text,
  p_payload jsonb,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
declare v_uid uuid:=public.lts_browser_assert_user_v1();
begin
  return public.lts_internal_transfer_mutate_v1(v_uid,p_action,p_source_ref,coalesce(p_payload,'{}'::jsonb),p_idempotency_key);
end
$function$;

-- Make the Flow transfer layer operation-aware. A latest cancel removes both
-- legs; an edit overrides date, amount, description and account per leg.
create or replace function public.lts_internal_transfer_legs_fix86_v1(
  p_user_id uuid,
  p_from date,
  p_to date
) returns table(event_date date,account text,description text,signed_amount numeric,source_ref text,confidence text)
language sql
security definer
set search_path=public
as $function$
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
$function$;

-- Monthly economic balance. Regular revenue and extraordinary funding are
-- intentionally separated, while transfers, investments and card settlements
-- never inflate consumption.
create or replace function public.lts_monthly_balance_v1(
  p_user_id uuid,
  p_from date,
  p_to date
) returns jsonb
language sql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
with params as (
  select p_from::date from_date,p_to::date to_date,
         date_trunc('month',p_from)::date from_month,
         date_trunc('month',p_to)::date to_month
), month_count as (
  select ((extract(year from to_month)::int-extract(year from from_month)::int)*12
          +(extract(month from to_month)::int-extract(month from from_month)::int))::int n
  from params
), months as (
  select (p.from_month+make_interval(months=>s.n))::date month_key
  from params p cross join month_count c cross join lateral generate_series(0,c.n) s(n)
), income_raw as (
  select h.*,
         lower(coalesce(h.description,'')) description_lc,
         lower(coalesce(h.category,'')) category_lc
  from params p cross join lateral public.lts_historical_effective_cash_v5(p_user_id,p.from_date,p.to_date) h
  where h.signed_amount>0
), income_screened as (
  select r.*,
    case
      when coalesce(r.internal_transfer,false) or coalesce(r.excluded_from_spend,false)
        or r.category_lc in ('movimentação interna','movimentacao interna','transferência própria','transferencia propria','investimentos')
        or r.description_lc ~ '(recebimento|transfer[eê]ncia).*(ita[uú]|bradesco|c6).*(ita[uú]|bradesco|c6)'
        or r.description_lc ~ '(resgate.*cofrinho|aplica[cç][aã]o.*autom[aá]tica)' then 'excluded'
      when r.description_lc ~ '(empr[eé]stimo|novo coopharma|\mfgts\M|\mvenda\M|aliena[cç][aã]o)' then 'extraordinary'
      else 'revenue'
    end income_kind
  from income_raw r
), income_classified as (
  select date_trunc('month',event_date)::date month_key,income_kind,
    case
      when income_kind='extraordinary' and description_lc ~ '(empr[eé]stimo|novo coopharma)' then 'Empréstimos recebidos'
      when income_kind='extraordinary' and description_lc ~ '\mfgts\M' then 'Resgate de FGTS'
      when income_kind='extraordinary' and description_lc ~ '(\mvenda\M|aliena[cç][aã]o)' then 'Venda de bens e ativos'
      when income_kind='extraordinary' then 'Outras entradas extraordinárias'
      when description_lc ~ '(sal[aá]rio|adiantamento quinzenal|f[eé]rias|13o|13º|b[oô]nus|remunera[cç][aã]o)' or category_lc='salário' then 'Remuneração'
      when description_lc ~ '(reembolso|restitui[cç][aã]o|nota fiscal paulista)' or category_lc like 'reembolso%' then 'Reembolsos e restituições'
      when description_lc ~ 'fam[ií]lia' or category_lc='família' then 'Família'
      when description_lc ~ '(rendimento|juros|remuner.*poup)' or category_lc='rendimentos financeiros' then 'Rendimentos financeiros'
      else 'Outras receitas'
    end group_label,
    signed_amount::numeric amount,source_ref
  from income_screened
  where income_kind<>'excluded'
), income_agg as (
  select month_key,income_kind,group_label,sum(amount)::numeric amount,count(*)::integer source_rows
  from income_classified group by month_key,income_kind,group_label
), income_labels as (
  select income_kind,group_label,sum(amount)::numeric total,sum(source_rows)::integer source_rows
  from income_agg group by income_kind,group_label
), income_groups as (
  select l.income_kind,l.group_label,l.total,l.source_rows,
         jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(a.amount,0)) order by m.month_key) monthly
  from income_labels l cross join months m
  left join income_agg a on a.income_kind=l.income_kind and a.group_label=l.group_label and a.month_key=m.month_key
  group by l.income_kind,l.group_label,l.total,l.source_rows
), expense_classified as (
  select e.competence_month month_key,
    case
      when lower(coalesce(e.counterparty,'')) like '%coopharma%'
        or (coalesce(e.is_financing,false) and lower(coalesce(e.origin_name,'')) like '%coopharma%')
        then 'Empréstimo consignado · Coopharma'
      when e.coverage_mode='card_invoice_aggregate_fallback'
        then 'Faturas históricas sem compras individualizadas'
      else coalesce(nullif(trim(e.category),''),'A classificar')
    end group_label,
    e.amount::numeric amount,e.source_ref,e.coverage_mode
  from params p cross join lateral public.lts_expense_total_rows_v5(p_user_id,p.from_date,p.to_date) e
), expense_agg as (
  select month_key,group_label,sum(amount)::numeric amount,count(*)::integer source_rows
  from expense_classified group by month_key,group_label
), expense_labels as (
  select group_label,sum(amount)::numeric total,sum(source_rows)::integer source_rows
  from expense_agg group by group_label
), expense_groups as (
  select l.group_label,l.total,l.source_rows,
         jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(a.amount,0)) order by m.month_key) monthly
  from expense_labels l cross join months m
  left join expense_agg a on a.group_label=l.group_label and a.month_key=m.month_key
  group by l.group_label,l.total,l.source_rows
), month_totals as (
  select m.month_key,
    coalesce((select sum(a.amount) from income_agg a where a.month_key=m.month_key and a.income_kind='revenue'),0)::numeric revenue,
    coalesce((select sum(a.amount) from income_agg a where a.month_key=m.month_key and a.income_kind='extraordinary'),0)::numeric extraordinary,
    coalesce((select sum(a.amount) from expense_agg a where a.month_key=m.month_key),0)::numeric expenses
  from months m
), totals as (
  select coalesce(sum(revenue),0)::numeric revenue,
         coalesce(sum(extraordinary),0)::numeric extraordinary,
         coalesce(sum(expenses),0)::numeric expenses
  from month_totals
), excluded as (
  select coalesce(sum(signed_amount),0)::numeric amount,count(*)::integer source_rows
  from income_screened where income_kind='excluded'
), coverage as (
  select coalesce(sum(amount) filter(where coverage_mode='card_invoice_aggregate_fallback'),0)::numeric historical_invoice_aggregate,
         count(distinct month_key) filter(where coverage_mode='card_invoice_aggregate_fallback')::integer historical_invoice_months,
         count(*)::integer expense_source_rows
  from expense_classified
)
select jsonb_build_object(
  'version','monthly-balance-v1',
  'from',(select from_date from params),
  'to',(select to_date from params),
  'months',(select coalesce(jsonb_agg(month_key order by month_key),'[]'::jsonb) from months),
  'revenue_groups',(select coalesce(jsonb_agg(jsonb_build_object('label',group_label,'total',total,'source_rows',source_rows,'monthly',monthly) order by total desc),'[]'::jsonb) from income_groups where income_kind='revenue'),
  'extraordinary_groups',(select coalesce(jsonb_agg(jsonb_build_object('label',group_label,'total',total,'source_rows',source_rows,'monthly',monthly) order by total desc),'[]'::jsonb) from income_groups where income_kind='extraordinary'),
  'expense_groups',(select coalesce(jsonb_agg(jsonb_build_object('label',group_label,'total',total,'source_rows',source_rows,'monthly',monthly) order by total desc),'[]'::jsonb) from expense_groups),
  'monthly_totals',(select coalesce(jsonb_agg(jsonb_build_object(
       'month',month_key,'revenue',revenue,'extraordinary',extraordinary,'expenses',expenses,
       'operating_balance',revenue-expenses,'cash_after_extraordinary',revenue+extraordinary-expenses
     ) order by month_key),'[]'::jsonb) from month_totals),
  'totals',(select jsonb_build_object(
       'revenue',revenue,'extraordinary',extraordinary,'expenses',expenses,
       'operating_balance',revenue-expenses,'cash_after_extraordinary',revenue+extraordinary-expenses
     ) from totals),
  'coverage',(select jsonb_build_object(
       'historical_invoice_aggregate',historical_invoice_aggregate,
       'historical_invoice_months',historical_invoice_months,
       'expense_source_rows',expense_source_rows,
       'excluded_internal_or_investment_inflows',(select amount from excluded),
       'excluded_inflow_rows',(select source_rows from excluded)
     ) from coverage),
  'guardrails',jsonb_build_object(
    'internal_transfers_excluded',true,
    'investments_excluded_from_revenue',true,
    'card_bill_payments_excluded_from_consumption',true,
    'card_purchases_counted_once',true,
    'extraordinary_funding_separated_from_revenue',true,
    'expense_basis','competence_month'
  )
);
$function$;

create or replace function public.lts_browser_monthly_balance_v1(p_from date,p_to date)
returns jsonb
language plpgsql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
declare v_uid uuid:=public.lts_browser_assert_user_v1();
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid monthly balance range'; end if;
  if p_from<date '2013-10-10' or p_to>current_date then raise exception 'monthly balance range outside available history'; end if;
  if ((extract(year from p_to)::int-extract(year from p_from)::int)*12+(extract(month from p_to)::int-extract(month from p_from)::int))>239 then raise exception 'monthly balance range exceeds 240 months'; end if;
  return public.lts_monthly_balance_v1(v_uid,p_from,p_to);
end
$function$;

-- Machine-readable calendar and arithmetic audit used by the V169 gate.
create or replace function public.lts_flow_civil_day_audit_v1(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
declare
  y integer;
  d1 date;
  d2 date;
  j jsonb;
  days jsonb;
  events jsonb;
  expected integer;
  actual integer;
  distinct_days integer;
  net_mismatch integer;
  recurrence_mismatch integer;
  unsupported_balance_leaks integer;
  years jsonb:='[]'::jsonb;
begin
  for y in 2013..extract(year from current_date)::integer loop
    d1:=greatest(date '2013-10-10',make_date(y,1,1));
    d2:=least(current_date-1,make_date(y,12,31));
    if d2<d1 then continue; end if;
    j:=public.lts_daily_flow_full_query_v6(p_user_id,d1,d2);
    j:=public.lts_flow_historical_balance_truth_overlay_v1(p_user_id,j);
    days:=coalesce(j#>'{historical,days}','[]'::jsonb);
    events:=coalesce(j#>'{historical,events}','[]'::jsonb);
    expected:=d2-d1+1;
    actual:=jsonb_array_length(days);
    select count(distinct (x->>'date')::date)::integer into distinct_days from jsonb_array_elements(days) x;

    with ds as (
      select x,(x->>'date')::date dt,
             coalesce(nullif(x#>>'{summary,net}','')::numeric,0) summary_net,
             coalesce(nullif(x#>>'{summary,entries}','')::numeric,0) entries,
             coalesce(nullif(x#>>'{summary,exits}','')::numeric,0) exits,
             coalesce(nullif(x#>>'{Consolidado,net}','')::numeric,0) consolidated_net,
             nullif(x#>>'{Consolidado,relative_balance}','')::numeric relative_balance,
             lag(nullif(x#>>'{Consolidado,relative_balance}','')::numeric) over(order by (x->>'date')::date) prior_relative
      from jsonb_array_elements(days) x
    )
    select count(*) filter(where abs(summary_net-(entries-exits))>0.005 or abs(summary_net-consolidated_net)>0.005)::integer,
           count(*) filter(where prior_relative is not null and relative_balance is not null and abs(relative_balance-(prior_relative+consolidated_net))>0.005)::integer
      into net_mismatch,recurrence_mismatch
    from ds;

    select count(*)::integer into unsupported_balance_leaks
    from jsonb_array_elements(days) x
    where coalesce((x->>'absolute_balance_certified')::boolean,false)=false
      and nullif(x#>>'{Consolidado,bank_balance}','') is not null
      and coalesce(x->>'absolute_balance_basis','')<>'post_position_operational_carry';

    years:=years||jsonb_build_array(jsonb_build_object(
      'year',y,'from',d1,'to',d2,'expected_days',expected,'actual_days',actual,
      'distinct_days',distinct_days,'missing_days',expected-distinct_days,
      'duplicate_days',actual-distinct_days,'net_mismatches',net_mismatch,
      'relative_balance_mismatches',recurrence_mismatch,
      'unsupported_balance_leaks',unsupported_balance_leaks,
      'event_count',jsonb_array_length(events),
      'ok',actual=expected and distinct_days=expected and net_mismatch=0 and recurrence_mismatch=0 and unsupported_balance_leaks=0
    ));
  end loop;
  return jsonb_build_object(
    'version','flow-civil-day-audit-v1','available_from','2013-10-10','as_of',current_date,
    'years',years,
    'critical_years',jsonb_build_array(2018,2019,2020,2021),
    'all_ok',not exists(select 1 from jsonb_array_elements(years) x where not coalesce((x->>'ok')::boolean,false))
  );
end
$function$;

revoke all on function public.lts_internal_transfer_editor_v1(uuid,text) from public,anon,authenticated;
revoke all on function public.lts_internal_transfer_mutate_v1(uuid,text,text,jsonb,text) from public,anon,authenticated;
revoke all on function public.lts_monthly_balance_v1(uuid,date,date) from public,anon,authenticated;
revoke all on function public.lts_flow_civil_day_audit_v1(uuid) from public,anon,authenticated;
revoke all on function public.lts_internal_transfer_legs_fix86_v1(uuid,date,date) from public,anon,authenticated;

revoke all on function public.lts_browser_internal_transfer_editor_v1(text) from public,anon;
grant execute on function public.lts_browser_internal_transfer_editor_v1(text) to authenticated;
revoke all on function public.lts_browser_internal_transfer_mutate_v1(text,text,jsonb,text) from public,anon;
grant execute on function public.lts_browser_internal_transfer_mutate_v1(text,text,jsonb,text) to authenticated;
revoke all on function public.lts_browser_monthly_balance_v1(date,date) from public,anon;
grant execute on function public.lts_browser_monthly_balance_v1(date,date) to authenticated;

-- Derived Flow caches must be rebuilt so the new editable transfer confidence
-- and operation-aware legs are visible immediately. Source facts are untouched.
delete from public.lts_flow_future_read_cache;
delete from public.lts_flow_future_read_cache_v2;

-- lts_daily_flow_fix86_v10: civil-date series (DST safe)
CREATE OR REPLACE FUNCTION public.lts_daily_flow_fix86_v10(p_user_id uuid, p_from date DEFAULT CURRENT_DATE, p_to date DEFAULT (CURRENT_DATE + '1 year'::interval))
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with pos as (
  select public.lts_current_evidence_position_v1(p_user_id) j
), acct_raw as (
  select case when institution='Itau' then 'Itaú' else institution end account,
         coalesce((metadata->>'balance')::numeric,0) balance,
         nullif(metadata->>'balance_as_of','')::date balance_as_of
  from public.accounts
  where user_id=p_user_id and is_active=true and institution in ('Itaú','Itau','Bradesco','C6')
), start_acct as (
  select a.account,
         a.balance + case
           when a.balance_as_of is null then 0
           when p_from>a.balance_as_of then coalesce((
             select sum(z.signed_amount) from (
               select c.account,c.signed_amount
               from public.lts_corrected_cashflow_operational_v1(p_user_id,a.balance_as_of+1,p_from-1) c
               where p_from>a.balance_as_of+1
               union all
               select case when t.account='Itau' then 'Itaú' else t.account end,t.signed_amount
               from public.lts_internal_transfer_legs_fix86_v1(p_user_id,a.balance_as_of+1,p_from-1) t
               where p_from>a.balance_as_of+1
               union all
               select case when e.account='Itau' then 'Itaú' else e.account end,e.amount
               from public.lts_reconciliation_evidence e
               where e.user_id=p_user_id and e.evidence_date between a.balance_as_of+1 and p_from-1
                 and e.status='documented' and e.evidence_type='bank_statement'
                 and e.metadata->>'cash_effect'='statement_fact_not_new_projection'
             ) z where z.account=a.account
           ),0)
           when p_from<=a.balance_as_of then -coalesce((
             select sum(h.signed_amount)
             from public.lts_historical_effective_cash_v4(p_user_id,p_from,a.balance_as_of) h
             where case when h.account='Itau' then 'Itaú' else h.account end=a.account
           ),0)
           else 0 end balance
  from acct_raw a
), position_date as (
  select coalesce(nullif((select j->>'as_of' from pos),'')::date,(select max(balance_as_of) from acct_raw)) dt
), pre_range_unassigned as (
  select case when p_from>coalesce((select dt from position_date),p_from)+1 then coalesce((
    select sum(c.signed_amount)
    from public.lts_corrected_cashflow_operational_v1(p_user_id,(select dt from position_date)+1,p_from-1) c
    where coalesce(c.account,'') not in ('Itaú','Itau','Bradesco','C6')
  ),0) else 0 end net
), corrected as materialized (
  select * from public.lts_corrected_cashflow_operational_v1(p_user_id,p_from,p_to)
), own_transfer as materialized (
  select event_date,case when account='Itau' then 'Itaú' else account end account,description,signed_amount,
         'internal_transfer'::text source,source_ref,confidence,'assigned'::text account_assignment,
         null::integer legacy_index,event_date original_date,false displaced
  from public.lts_internal_transfer_legs_fix86_v1(p_user_id,p_from,p_to)
), documented as materialized (
  select e.evidence_date event_date,case when e.account='Itau' then 'Itaú' else e.account end account,e.description,e.amount signed_amount,
         'reconciliation_evidence'::text source,e.id::text source_ref,'documented_bank_statement_fact'::text confidence,
         'assigned'::text account_assignment,null::integer legacy_index,e.evidence_date original_date,false displaced
  from public.lts_reconciliation_evidence e
  where e.user_id=p_user_id and e.evidence_date between p_from and least(p_to,current_date)
    and e.status='documented' and e.evidence_type='bank_statement'
    and e.metadata->>'cash_effect'='statement_fact_not_new_projection'
    and not exists(
      select 1 from corrected c
      where c.event_date=e.evidence_date
        and coalesce(case when c.account='Itau' then 'Itaú' else c.account end,'')=coalesce(case when e.account='Itau' then 'Itaú' else e.account end,'')
        and abs(c.signed_amount-e.amount)<=0.02
    )
    and not exists(
      select 1 from own_transfer t
      where t.event_date=e.evidence_date
        and coalesce(t.account,'')=coalesce(case when e.account='Itau' then 'Itaú' else e.account end,'')
        and abs(t.signed_amount-e.amount)<=0.02
    )
), events as materialized (
  select *,false internal_transfer from corrected
  union all select *,true from own_transfer
  union all select *,false from documented
), layers as materialized (
  select * from public.lts_flow_dynamic_layers_v1(p_user_id,p_from,p_to)
), params as (
  select coalesce((select (j->>'liquid_d0_assets')::numeric from pos),0)::numeric d0_resource
), days as (
  select (p_from+s.n)::date dt
  from generate_series(0,p_to-p_from) as s(n)
), daily as (
  select d.dt,
    coalesce(sum(e.signed_amount) filter(where e.account='Itaú' and not e.internal_transfer),0) itau_operating,
    coalesce(sum(e.signed_amount) filter(where e.account='Bradesco' and not e.internal_transfer),0) bradesco_operating,
    coalesce(sum(e.signed_amount) filter(where e.account='C6' and not e.internal_transfer),0) c6_operating,
    coalesce(sum(e.signed_amount) filter(where e.account='Itaú' and e.internal_transfer),0) itau_transfer,
    coalesce(sum(e.signed_amount) filter(where e.account='Bradesco' and e.internal_transfer),0) bradesco_transfer,
    coalesce(sum(e.signed_amount) filter(where e.account='C6' and e.internal_transfer),0) c6_transfer,
    coalesce(sum(e.signed_amount) filter(where not e.internal_transfer and e.account in ('Itaú','Bradesco','C6')),0) assigned_operating,
    coalesce(sum(e.signed_amount) filter(where not e.internal_transfer and coalesce(e.account,'') not in ('Itaú','Bradesco','C6')),0) unassigned_operating,
    coalesce(sum(e.signed_amount) filter(where not e.internal_transfer),0) consolidated_operating,
    coalesce(sum(e.signed_amount) filter(where e.signed_amount>0 and not e.internal_transfer),0) entries,
    coalesce(sum(-e.signed_amount) filter(where e.signed_amount<0 and not e.internal_transfer),0) exits,
    count(*) filter(where not e.internal_transfer) event_count,
    count(*) filter(where e.internal_transfer) transfer_count
  from days d left join events e on e.event_date=d.dt group by d.dt
), run as (
  select x.*,
    coalesce((select balance from start_acct where account='Itaú'),0)+sum(itau_operating+itau_transfer) over(order by dt) itau_balance,
    coalesce((select balance from start_acct where account='Bradesco'),0)+sum(bradesco_operating+bradesco_transfer) over(order by dt) bradesco_balance,
    coalesce((select balance from start_acct where account='C6'),0)+sum(c6_operating+c6_transfer) over(order by dt) c6_balance,
    coalesce((select sum(balance) from start_acct),0)+coalesce((select net from pre_range_unassigned),0)+sum(consolidated_operating) over(order by dt) consolidated_cash,
    -sum(itau_transfer+bradesco_transfer+c6_transfer) over(order by dt) clearing_balance,
    coalesce(sum(consolidated_operating) over(order by dt rows between 1 following and 30 following),0) next30_net
  from daily x
), enrich as (
  select r.*,p.d0_resource,l.payroll_withholding_today,l.fgts_value,l.vested_rsu_value,
         lag(r.consolidated_cash) over(order by r.dt) previous_cash
  from run r cross join params p join layers l on l.flow_date=r.dt
), day_json as (
  select jsonb_agg(jsonb_build_object(
    'date',dt,'is_today',dt=current_date,
    'Itaú',jsonb_build_object('net',itau_operating+itau_transfer,'balance',itau_balance),
    'Bradesco',jsonb_build_object('net',bradesco_operating+bradesco_transfer,'balance',bradesco_balance),
    'C6',jsonb_build_object('net',c6_operating+c6_transfer,'balance',c6_balance),
    'Transferências em trânsito',jsonb_build_object('balance',clearing_balance),
    'Consolidado',jsonb_build_object('bank_balance',consolidated_cash,'economic_net',consolidated_operating,'unassigned_net',unassigned_operating),
    'summary',jsonb_build_object('Consolidado',jsonb_build_object('entries',entries,'exits',exits),'events',event_count,'transfers',transfer_count),
    'fix86_columns',jsonb_build_object(
      'saldo_anterior',coalesce(previous_cash,consolidated_cash-consolidated_operating),
      'entradas',entries,'saidas',exits,'saldo_final',consolidated_cash,
      'liq_d0_1_recurso',d0_resource,
      'liq_d0_1',consolidated_cash+d0_resource,
      'saldo_apos_d0_1',consolidated_cash+d0_resource,
      'rsus_vested',vested_rsu_value,
      'saldo_apos_rsu',consolidated_cash+d0_resource+vested_rsu_value,
      'fgts',fgts_value,
      'saldo_apos_fgts',consolidated_cash+d0_resource+vested_rsu_value+fgts_value,
      'disponivel_total',consolidated_cash+d0_resource+vested_rsu_value,
      'liq_d30',consolidated_cash+d0_resource+next30_net,
      'posicao_antes_rsus',consolidated_cash+d0_resource,
      'posicao_curto_prazo',consolidated_cash+d0_resource+vested_rsu_value,
      'payroll_withholding_today',payroll_withholding_today,
      'cash_semantics','net_salary_operational_cash_plus_separate_liquidity_layers')
  ) order by dt) j from enrich
), ev_json as (
  select coalesce(jsonb_agg(jsonb_build_object('event_date',event_date,'account',account,'description',description,'signed_amount',signed_amount,'source',source,'source_ref',source_ref,'confidence',confidence,'account_assignment',account_assignment,'legacy_index',legacy_index,'original_date',original_date,'displaced',displaced,'internal_transfer',internal_transfer) order by event_date,source,description),'[]'::jsonb) j from events
)
select jsonb_build_object(
 'version','daily-flow-fix86-v10-current-day-documentary','from',p_from,'to',p_to,'days',(select j from day_json),'events',(select j from ev_json),
 'display_contract',jsonb_build_object('bank_tabs',jsonb_build_array('Consolidado','Itaú','Bradesco','C6'),'columns',jsonb_build_array('Data','Histórico','Saldo anterior','Entradas','Saídas','Saldo final','D0/D1','Saldo c/ D0/D1','RSU vested','Saldo c/ RSU','FGTS','Saldo total'),'show_today',true,'show_drilldown',true),
 'semantic_contract',jsonb_build_object('salary_net_in_bank',true,'coopharma_no_second_bank_debit',true,'unassigned_cash_affects_consolidated_not_bank_assignment',true,'d0_resource_separate',true,'rsu_dynamic',true,'fgts_restricted_separate',true,'internal_transfers_neutral_consolidated',true,'documentary_current_day_facts_applied',true),
 'guardrails',jsonb_build_array('Salário entra líquido de retenção Coopharma no Itaú e no Consolidado.','Coopharma não gera uma segunda saída bancária.','Fatos documentais do próprio dia entram no Fluxo sem duplicar eventos canônicos já existentes.','Compromissos sem conta documentada reduzem o Consolidado sem inventar qual banco pagará.','D0/D1, RSU vested e FGTS são camadas separadas; FGTS permanece restrito.')
);
$function$;

-- lts_flow_dynamic_layers_v1: civil-date series (DST safe)
CREATE OR REPLACE FUNCTION public.lts_flow_dynamic_layers_v1(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(flow_date date, payroll_withholding_today numeric, fgts_value numeric, fgts_monthly_accrual numeric, vested_rsu_value numeric, vested_rsu_added_today numeric)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with params as (
  select
    coalesce((select value_brl from public.asset_positions where user_id=p_user_id and asset_type='FGTS' order by as_of_date desc limit 1),0)::numeric fgts_anchor,
    coalesce((select as_of_date from public.asset_positions where user_id=p_user_id and asset_type='FGTS' order by as_of_date desc limit 1),p_from)::date fgts_anchor_date,
    coalesce((select (dados->>'_v')::numeric from public.fgts where usuario_id=p_user_id and dados->>'_k'='salario_base' limit 1),0)::numeric fgts_salary_base,
    coalesce((select (dados->>'_v')::numeric from public.fgts where usuario_id=p_user_id and dados->>'_k'='percentual' limit 1),0)::numeric fgts_pct,
    coalesce((select (dados->>'_v')::boolean from public.fgts where usuario_id=p_user_id and dados->>'_k'='ativo' limit 1),false)::boolean fgts_active,
    coalesce((select sum(value_brl) from public.asset_positions where user_id=p_user_id and is_available_now=true and liquidity_class in ('D+1','D+2','D+3')),0)::numeric rsu_anchor
), salary_dates as (
  select distinct f.event_date from params p cross join lateral public.lts_corrected_cashflow_fix86_v4(p_user_id,(p.fgts_anchor_date+1)::date,p_to) f
  where f.signed_amount>0 and lower(trim(f.description))='salário'
), award_schedule as (
  select (eligibility_date+settlement_days)::date available_date,
    sum(case when lower(asset_type) like '%cash%' then coalesce(net_value_brl,gross_value_brl)
             else coalesce(gross_value_brl,net_value_brl) end)::numeric value_brl
  from public.lts_future_liquidity_schedule
  where user_id=p_user_id and active=true
    and (upper(trim(asset_type))='RSU' or lower(asset_type) like '%cash%')
  group by 1
), withholding as (
  select effective_event_date event_date,sum(amount)::numeric amt
  from public.lts_payroll_withholding_effective_v1(p_user_id,p_from,p_to) group by effective_event_date
), days as (
  select (p_from+s.n)::date d
  from generate_series(0,p_to-p_from) as s(n)
)
select d.d,coalesce(w.amt,0)::numeric,
 (p.fgts_anchor+case when p.fgts_active then (p.fgts_salary_base*p.fgts_pct)*(select count(*) from salary_dates s where s.event_date<=d.d) else 0 end)::numeric,
 case when p.fgts_active then (p.fgts_salary_base*p.fgts_pct)::numeric else 0::numeric end,
 (p.rsu_anchor+coalesce((select sum(r.value_brl) from award_schedule r where r.available_date<=d.d),0))::numeric,
 coalesce((select sum(r.value_brl) from award_schedule r where r.available_date=d.d),0)::numeric
from days d cross join params p left join withholding w on w.event_date=d.d order by d.d;
$function$;

-- lts_historical_fgts_layer_v1: civil-date series (DST safe)
CREATE OR REPLACE FUNCTION public.lts_historical_fgts_layer_v1(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(flow_date date, fgts_value numeric, fgts_basis text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with p as (
 select
   coalesce((select (dados->>'_v')::numeric from public.fgts where usuario_id=p_user_id and dados->>'_k'='saldo_inicial' limit 1),0)::numeric legacy_base,
   coalesce((select (dados->>'_v')::date from public.fgts where usuario_id=p_user_id and dados->>'_k'='data_inicio' limit 1),date '2026-07-21') legacy_date,
   (select value_brl from public.asset_positions where user_id=p_user_id and asset_type='FGTS' order by as_of_date desc limit 1)::numeric doc_base,
   (select as_of_date from public.asset_positions where user_id=p_user_id and asset_type='FGTS' order by as_of_date desc limit 1)::date doc_date
), d as (
  select (p_from+s.n)::date dt
  from generate_series(0,p_to-p_from) as s(n)
)
select d.dt,
       case when p.doc_date is not null and d.dt>=p.doc_date then p.doc_base
            when d.dt>=p.legacy_date then p.legacy_base
            else null end,
       case when p.doc_date is not null and d.dt>=p.doc_date then 'snapshot_documental_fgts'
            when d.dt>=p.legacy_date then 'posição_legada_fgts'
            else 'histórico_anterior_pendente_de_recuperação_do_excel' end
from d cross join p order by d.dt;
$function$;

-- lts_historical_liquidity_layers_v1: civil-date series (DST safe)
CREATE OR REPLACE FUNCTION public.lts_historical_liquidity_layers_v1(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(flow_date date, d0_resource numeric, rsu_vested numeric, d0_basis text, rsu_basis text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with cfg as (
  select
    (select valor_bruto::jsonb from public.legacy_namespace where usuario_id=p_user_id and chave='lts_liq_ajustes' limit 1) moves,
    (select valor_bruto::jsonb from public.legacy_namespace where usuario_id=p_user_id and chave='lts_liq_ajustes_oficiais' limit 1) officials
), moves as (
  select (x->>'dia')::date dt,x->>'assetId' asset_id,(x->>'delta')::numeric delta
  from cfg cross join lateral jsonb_array_elements(coalesce(moves,'[]'::jsonb)) x
  where nullif(x->>'dia','') is not null and nullif(x->>'delta','') is not null
), official as (
  select (x->>'dataBase')::date dt,x->>'assetId' asset_id,
         nullif(x->>'saldoAnteriorCents','')::numeric/100 prior_balance,
         nullif(x->>'saldoNovoCents','')::numeric/100 new_balance,
         x->>'origem' source
  from cfg cross join lateral jsonb_array_elements(coalesce(officials,'[]'::jsonb)) x
  where nullif(x->>'dataBase','') is not null
), cof_anchor as (
  select * from official where asset_id='liq_recursos_curto_prazo_cofrinho_itau' order by dt limit 1
), asa_anchor as (
  select * from official where asset_id='liq_asa_investimentos' order by dt limit 1
), rsu_anchor as (
  select * from official where asset_id='liq_rsu_vested' order by dt limit 1
), cof_doc as (
  select as_of_date current_asof,value_brl current_value,
         nullif(metadata->>'prior_as_of','')::date prior_asof,
         nullif(metadata->>'prior_value_brl','')::numeric prior_value
  from public.asset_positions
  where user_id=p_user_id and asset_name='Cofrinho Itaú'
  order by as_of_date desc limit 1
), rsu_doc as (
  select as_of_date,current_value
  from (
    select as_of_date,value_brl current_value
    from public.asset_positions
    where user_id=p_user_id and is_available_now=true and liquidity_class in ('D+1','D+2','D+3')
    order by as_of_date desc limit 1
  ) q
), dates as (
  select (p_from+s.n)::date d
  from generate_series(0,p_to-p_from) as s(n)
), layer as (
  select d.d,
    case
      when d.d < date '2026-07-07' then null
      when cd.prior_asof is not null and d.d >= cd.current_asof then cd.current_value
      when cd.prior_asof is not null and d.d >= cd.prior_asof then
        cd.prior_value - coalesce((
          select sum(abs(e.amount))
          from public.lts_reconciliation_evidence e
          where e.user_id=p_user_id and e.status='documented'
            and e.metadata->>'source_asset'='Cofrinho Itaú'
            and e.evidence_date>cd.prior_asof and e.evidence_date<=d.d
        ),0)
      when ca.dt is not null and d.d < ca.dt then
        ca.new_balance - coalesce((select sum(m.delta) from moves m where m.asset_id=ca.asset_id and m.dt>d.d and m.dt<=ca.dt),0)
      when ca.dt is not null then
        ca.new_balance + coalesce((select sum(m.delta) from moves m where m.asset_id=ca.asset_id and m.dt>ca.dt and m.dt<=d.d),0)
      else null
    end cofrinho,
    case
      when d.d < date '2026-07-07' then null
      when aa.dt is null then 0
      when d.d < aa.dt then coalesce(aa.prior_balance,0)
      else coalesce(aa.new_balance,0)
    end asa,
    case
      when d.d < date '2026-07-07' then null
      when rd.as_of_date is not null and d.d>=rd.as_of_date then rd.current_value
      when ra.dt is null then null
      when d.d < ra.dt then ra.prior_balance
      else ra.new_balance
    end rsu,
    ca.dt cof_legacy_anchor,cd.prior_asof cof_doc_prior,cd.current_asof cof_doc_current,
    aa.dt asa_change,ra.dt rsu_change,rd.as_of_date rsu_doc_date
  from dates d
  left join cof_anchor ca on true
  left join asa_anchor aa on true
  left join rsu_anchor ra on true
  left join cof_doc cd on true
  left join rsu_doc rd on true
)
select d,
       case when cofrinho is null then null else cofrinho+coalesce(asa,0) end d0_resource,
       rsu,
       case when d<date '2026-07-07' then 'not_evidenced_before_certified_2026_anchor'
            when cof_doc_current is not null and d>=cof_doc_current then 'documentary_cofrinho_current'
            when cof_doc_prior is not null and d>=cof_doc_prior then 'documentary_cofrinho_prior_plus_documented_asset_movements'
            else 'legacy_liquidity_official_anchor_plus_recorded_movements' end,
       case when d<date '2026-07-07' then 'not_evidenced_before_certified_2026_anchor'
            when rsu_doc_date is not null and d>=rsu_doc_date then 'documentary_vested_rsu_snapshot'
            else 'legacy_official_vested_rsu_adjustment' end
from layer
order by d;
$function$;
