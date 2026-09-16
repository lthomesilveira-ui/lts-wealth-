-- V167: read-only planning audit through 2030.
-- This migration does not create financial events. It only compares documented
-- historical patterns with the already projected cash-flow horizon.

create or replace function public.lts_recurring_future_gap_audit_v5(
  p_user_id uuid,
  p_as_of date default current_date,
  p_horizon_end date default date '2030-12-31'
) returns jsonb
language sql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
with params as (
  select
    coalesce(p_as_of,(now() at time zone 'America/Sao_Paulo')::date) as as_of,
    greatest(coalesce(p_horizon_end,date '2030-12-31'),coalesce(p_as_of,current_date)+1) as horizon_end
), base as (
  select public.lts_recurring_future_gap_audit_v4(p_user_id,p.as_of) j,p.as_of,p.horizon_end
  from params p
), future_events as (
  select
    f.event_date,
    lower(regexp_replace(trim(coalesce(f.description,'')),'\s+',' ','g')) description_key,
    case when f.signed_amount>0 then 'income' else 'expense' end direction,
    abs(f.signed_amount) amount
  from params p,
       public.lts_corrected_cashflow_operational_v1(p_user_id,p.as_of+1,p.horizon_end) f
  where f.signed_amount<>0 and trim(coalesce(f.description,''))<>''
), historical_events as (
  select
    h.event_date,
    lower(regexp_replace(trim(coalesce(h.description,'')),'\s+',' ','g')) description_key,
    case when h.signed_amount>0 then 'income' else 'expense' end direction,
    abs(h.signed_amount) amount
  from params p,
       public.lts_historical_effective_cash_v4(p_user_id,(p.as_of-interval '36 months')::date,p.as_of) h
  where h.signed_amount<>0
    and coalesce(h.excluded_from_spend,false)=false
    and coalesce(h.internal_transfer,false)=false
    and trim(coalesce(h.description,''))<>''
), specs as (
  select * from (values
    ('salary','Salário','Receita mensal','income','monthly','salário|salario'),
    ('cards','Faturas de cartão','Despesa mensal','expense','monthly','fatura|cartão|cartao|aeternum|personnalite|mastercard'),
    ('taxes','Tributos recorrentes','Despesa anual','expense','annual','ipva|iptu|imposto|licenciamento|dpvat')
  ) v(key,title,description,direction,cadence,pattern)
), years as (
  select generate_series(extract(year from p.as_of)::int,extract(year from p.horizon_end)::int) calendar_year,p.*
  from params p
), year_coverage as (
  select
    s.key,s.title,s.description,s.direction,s.cadence,s.pattern,y.calendar_year,
    case
      when s.cadence='monthly' and y.calendar_year=extract(year from y.as_of)::int
        then 13-extract(month from y.as_of)::int
      when s.cadence='monthly' then 12
      else 1
    end expected_events,
    count(f.*)::int future_events,
    min(f.event_date) first_future_date,
    max(f.event_date) last_future_date
  from specs s cross join years y
  left join future_events f
    on f.direction=s.direction
   and extract(year from f.event_date)::int=y.calendar_year
   and f.description_key ~ s.pattern
  group by s.key,s.title,s.description,s.direction,s.cadence,s.pattern,y.calendar_year,y.as_of
), historical_matches as (
  select s.key,s.cadence,h.event_date,h.amount
  from specs s
  left join historical_events h
    on h.direction=s.direction and h.description_key ~ s.pattern
), historical_bucketed as (
  select
    key,
    cadence,
    case
      when cadence='monthly' then date_trunc('month',event_date)::date
      else date_trunc('year',event_date)::date
    end period_start,
    sum(amount) period_total_brl
  from historical_matches
  where event_date is not null
  group by key,cadence,
    case
      when cadence='monthly' then date_trunc('month',event_date)::date
      else date_trunc('year',event_date)::date
    end
), historical as (
  select
    s.key,
    min(m.event_date) historical_first_date,
    max(m.event_date) historical_last_date,
    count(m.event_date)::int historical_event_count,
    (select count(*)::int from historical_bucketed b where b.key=s.key) historical_period_count,
    (select round(percentile_cont(0.5) within group(order by b.period_total_brl)::numeric,2)
       from historical_bucketed b where b.key=s.key) observed_median_amount_brl
  from specs s
  left join historical_matches m on m.key=s.key
  group by s.key
), checks as (
  select jsonb_build_object(
    'key',y.key,
    'title',y.title,
    'description',y.description,
    'description_key',y.key,
    'direction',y.direction,
    'recurrence_pattern',case when y.cadence='monthly' then 'frequent_monthly' else 'annual_or_seasonal' end,
    'review_kind',case when bool_or(y.future_events<y.expected_events) then 'planning_review' else 'covered' end,
    'status',case when bool_or(y.future_events<y.expected_events) then 'review_future_gap' else 'covered_to_horizon' end,
    'historical_first_date',h.historical_first_date,
    'historical_last_date',h.historical_last_date,
    'historical_event_count',h.historical_event_count,
    'historical_period_count',h.historical_period_count,
    'observed_median_amount_brl',h.observed_median_amount_brl,
    'suggestion_basis',case when y.cadence='monthly'
      then 'mediana do total mensal histórico'
      else 'mediana do total anual histórico' end,
    'future_events_to_horizon',sum(y.future_events),
    'missing_years',coalesce(jsonb_agg(y.calendar_year order by y.calendar_year)
      filter(where y.future_events<y.expected_events),'[]'::jsonb),
    'year_coverage',jsonb_agg(jsonb_build_object(
      'year',y.calendar_year,
      'expected_events',y.expected_events,
      'future_events',y.future_events,
      'status',case when y.future_events>=y.expected_events then 'covered' else 'review' end,
      'first_future_date',y.first_future_date,
      'last_future_date',y.last_future_date
    ) order by y.calendar_year),
    'review_reason',case when bool_or(y.future_events<y.expected_events)
      then 'A projeção não cobre todos os anos/meses até o fim de 2030. A mediana histórica é apenas uma sugestão para revisão; nenhum lançamento é criado automaticamente.'
      else 'A projeção possui cobertura no horizonte auditado.' end
  ) item,
  bool_or(y.future_events<y.expected_events) needs_review
  from year_coverage y join historical h using(key)
  group by y.key,y.title,y.description,y.direction,y.cadence,
    h.historical_first_date,h.historical_last_date,h.historical_event_count,
    h.historical_period_count,h.observed_median_amount_brl
), aggregate as (
  select
    coalesce(jsonb_agg(item order by needs_review desc,item->>'title'),'[]'::jsonb) items,
    count(*) filter(where needs_review) review_count
  from checks
)
select b.j || jsonb_build_object(
  'version','recurring-future-gap-audit-v5-through-2030-read-only',
  'future_horizon_end',b.horizon_end,
  'future_horizon_years',extract(year from b.horizon_end)::int-extract(year from b.as_of)::int+1,
  'horizon_checks',(select items from aggregate),
  'horizon_review_count',(select review_count from aggregate),
  'horizon_contract','Salário e faturas são verificados por mês; tributos, por ano. A auditoria é somente leitura e nunca cria valores sem confirmação.'
) from base b
$function$;

create or replace function public.lts_browser_recurring_future_gap_audit_v5(
  p_as_of date default null,
  p_horizon_end date default date '2030-12-31'
) returns jsonb
language sql
security definer
set search_path=public
set timezone='America/Sao_Paulo'
as $function$
select public.lts_recurring_future_gap_audit_v5(
  public.lts_browser_assert_user_v1(),
  coalesce(p_as_of,(now() at time zone 'America/Sao_Paulo')::date),
  coalesce(p_horizon_end,date '2030-12-31')
)
$function$;

revoke execute on function public.lts_recurring_future_gap_audit_v5(uuid,date,date) from public,anon,authenticated;
revoke all on function public.lts_browser_recurring_future_gap_audit_v5(date,date) from public,anon;
grant execute on function public.lts_browser_recurring_future_gap_audit_v5(date,date) to authenticated;

comment on function public.lts_browser_recurring_future_gap_audit_v5(date,date) is
'Authenticated, read-only long-horizon recurring audit through 2030. It never creates financial events.';
