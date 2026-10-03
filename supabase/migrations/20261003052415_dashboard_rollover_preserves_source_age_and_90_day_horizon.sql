CREATE OR REPLACE FUNCTION public.lts_updates_current_sources_v240(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH base AS MATERIALIZED (select coalesce((select payload->'updates' from public.lts_product_read_cache where user_id=p_user_id),public.lts_updates_fix86plus_v12(p_user_id)) j),
positions AS MATERIALIZED (select public.lts_open_finance_checking_positions_v1(p_user_id) j),
kept AS (select x from base,lateral jsonb_array_elements(base.j->'items') x
 where coalesce(x->>'type','')<>'projection_payment_review'
 AND NOT (x->>'type'='card_payment_review' AND EXISTS(select 1 from public.card_invoices i join public.lts_fact_confirmation fc on fc.user_id=i.user_id and fc.source_ref=i.card_name||'|'||to_char(i.reference_month,'YYYY-MM')
 where i.user_id=p_user_id and x->>'id'='card_payment_'||i.id::text and fc.signed_amount=-i.amount))
 AND NOT (x->>'maintenance_kind'='bank_statement' and exists(
  select 1 from positions,lateral jsonb_array_elements(positions.j) p
  where (p->>'as_of')::timestamptz BETWEEN current_timestamp-interval '24 hours' AND current_timestamp and
   x->>'id'=case p->>'bank' when 'Itaú' then 'maintenance_bank_ita_' when 'Bradesco' then 'maintenance_bank_bradesco' when 'C6' then 'maintenance_bank_c6' end))),
pending AS (select x from jsonb_array_elements(public.lts_pending_projections_v233(p_user_id)) x),
current_card_detail AS (select CASE WHEN i.card_name IS NOT NULL THEN x||jsonb_build_object(
 'detail','Última fatura fechada registrada: '||to_char(i.reference_month,'MM/YYYY')||'. O ciclo atual permanece sujeito à fatura oficial; valores de projeção não são confirmação de fatura fechada.',
 'last_closed_reference_month',i.reference_month,'last_closed_invoice_id',i.id) ELSE x END x
 from kept left join lateral(select ci.id,ci.card_name,ci.reference_month from public.card_invoices ci
 where ci.user_id=p_user_id AND ci.status='closed' AND x->>'maintenance_kind'='card_statement'
 AND public.lts_v178_norm(x->>'title')=public.lts_v178_norm('Fatura '||ci.card_name)
 order by ci.reference_month desc,ci.due_date desc limit 1) i ON true),
items AS (select x from current_card_detail union all select jsonb_build_object(
 'id','pending_projection_'||coalesce(x->>'source_ref',x->>'id'),'type','projection_payment_review',
 'title','Confirmar previsão · '||coalesce(x->>'description','Pagamento'),
 'detail','Classificação conhecida; o pagamento desta obrigação ainda requer correspondência documental.',
 'status','needs_confirmation','priority',1,'destination','Atualizações',
 'source_ref',x->'source_ref','category',x->'category','amount',x->'signed_amount','event_date',x->'event_date') from pending),
summary AS (select coalesce(jsonb_agg(x order by coalesce((x->>'priority')::int,9),x->>'id'),'[]') j,
 count(*) total,count(*) filter(where x->>'status' not in ('informational','guarded','resolved','current')) actionable,
 count(*) filter(where x->>'status' not in ('informational','guarded','resolved','current') and (x->>'priority')::int=1) urgent from items)
select base.j||jsonb_build_object('version','updates-v240-current-source-evidence','items',summary.j,
 'pending_count',summary.total,'actionable_count',summary.actionable,'urgent_count',summary.urgent,
 'current_bank_evidence',positions.j) from base,summary,positions
$function$;

CREATE OR REPLACE FUNCTION public.lts_dashboard_executive_from_flow_v1(p_user_id uuid, p_as_of date, p_flow jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with base as (
  select public.lts_dashboard_executive_v3(p_user_id,p_as_of) j
), ladder as materialized (
  select * from public.lts_dashboard_cash_ladder_from_flow_v1(p_user_id,p_as_of,greatest(p_as_of+90,make_date(extract(year from p_as_of)::int,12,31)),p_flow)
), hdef as (
  select * from (values
    (1,'30d','30 dias',p_as_of+30),
    (2,'90d','90 dias',p_as_of+90),
    (3,'year_end','Fim de '||extract(year from p_as_of)::int,make_date(extract(year from p_as_of)::int,12,31))
  ) v(ord,id,label,dt)
), hz as (
  select jsonb_agg(jsonb_build_object(
    'id',h.id,'label',h.label,'date',h.dt,
    'current_liquidity_balance',l.balance_no_new_vesting,
    'conditional_rsu_balance',l.balance_with_scheduled_vesting,
    'scheduled_vested_rsu',l.rsu_vested_scheduled,
    'rsu_vested_today',l.rsu_vested_today,
    'fgts_projected',l.fgts_projected,
    'restricted_total_balance',l.balance_with_fgts,
    'current_liquidity_status',case when l.balance_no_new_vesting<0 then 'negative' when l.balance_no_new_vesting<20000 then 'attention' else 'covered' end,
    'conditional_status',case when l.balance_with_scheduled_vesting<0 then 'negative' when l.balance_with_scheduled_vesting<20000 then 'attention' else 'covered' end,
    'liquidity_basis','bank cash + D0/D1 + RSU vested today; scheduled scenario promotes future awards only on vesting+settlement dates'
  ) order by h.ord) j
  from hdef h join ladder l on l.flow_date=h.dt
), vals as (
  select min(flow_date) filter(where balance_no_new_vesting<0) current_rupture,
         min(flow_date) filter(where balance_with_scheduled_vesting<0) scheduled_rupture,
         max(balance_no_new_vesting) filter(where flow_date=make_date(extract(year from p_as_of)::int,12,31)) current_end,
         max(balance_with_scheduled_vesting) filter(where flow_date=make_date(extract(year from p_as_of)::int,12,31)) scheduled_end,
         max(rsu_vested_today) rsu_anchor,
         max(rsu_vested_scheduled) filter(where flow_date=make_date(extract(year from p_as_of)::int,12,31)) rsu_year_end
  from ladder
), risk as (
  select coalesce((select j->'risk_layers' from base),'{}'::jsonb) j
), newrisk as (
  select (select j from risk) || jsonb_build_object(
    'current_liquidity',jsonb_build_object(
      'label','Liquidez sem novos vestings','first_negative_date',(select current_rupture from vals),'ending_balance_2026',(select current_end from vals),
      'meaning','Caixa + D0/D1 + RSU que já está vested hoje. Não promove awards futuros.'),
    'conditional_future_liquidity',jsonb_build_object(
      'label','Liquidez com vestings programados','first_negative_date',(select scheduled_rupture from vals),'ending_balance_2026',(select scheduled_end from vals),
      'future_rsu_gross',greatest((select rsu_year_end-rsu_anchor from vals),0),
      'meaning','Promove cada award futuro somente na sua data de vesting + settlement. Continua sujeito à efetiva ocorrência do vesting/liquidação.')
  ) j
), actions as (
  select jsonb_build_array(
    case when (select current_rupture from vals) is not null and (select scheduled_rupture from vals) is null then
      jsonb_build_object('priority',1,'type','liquidity_planning','status','attention','title','Planejar liquidez antes de '||(select current_rupture from vals)::text,'detail','Sem novos vestings o saldo cruza zero, mas a agenda de vesting programada mantém cobertura no horizonte.')
    when (select scheduled_rupture from vals) is not null then
      jsonb_build_object('priority',1,'type','resource_gap','status','action','title','Cobrir insuficiência projetada','detail','Há ruptura mesmo considerando os vestings já programados.')
    else jsonb_build_object('priority',1,'type','liquidity','status','ok','title','Liquidez coberta','detail','O horizonte permanece positivo inclusive sem novos vestings.') end,
    jsonb_build_object('priority',2,'type','bank_funding','status','attention','title','Antecipar funding entre contas','detail','Saldo negativo em uma conta específica pode ser redistribuição, não falta consolidada de recursos.'),
    jsonb_build_object('priority',3,'type','projection_quality','status','attention','title','Manter premissas futuras explícitas','detail','Vestings programados só entram na data elegível; FGTS permanece restrito e fora da cobertura de caixa.')
  ) j
)
select (select j from base) || jsonb_build_object(
  'version','dashboard-executive-v4-flow-consistent','as_of',p_as_of,
  'headline',case when (select scheduled_rupture from vals) is not null then 'Há insuficiência projetada mesmo após os vestings programados'
                  when (select current_rupture from vals) is not null then 'Liquidez exige planejamento, mas os vestings programados preservam cobertura em 2026'
                  else 'Liquidez coberta no horizonte de 2026' end,
  'executive_message',case when (select scheduled_rupture from vals) is not null then 'A trajetória cruza zero mesmo após promover apenas os vestings programados nas datas elegíveis.'
                           when (select current_rupture from vals) is not null then 'Sem novos vestings, a liquidez cruza zero em '||(select current_rupture from vals)::text||'. Com os vestings já programados entrando apenas nas datas elegíveis, o horizonte de 2026 permanece coberto.'
                           else 'A liquidez permanece positiva até o fim de 2026 mesmo sem novos vestings.' end,
  'health_status',case when (select scheduled_rupture from vals) is not null then 'critical' when (select current_rupture from vals) is not null then 'attention' else 'ok' end,
  'horizons',(select j from hz),'risk_layers',(select j from newrisk),'actions',(select j from actions),
  'horizon_basis','bank cash + D0/D1 + already vested RSU; scheduled vestings are a separate future scenario and FGTS remains restricted',
  'semantic_note','Dashboard horizons now use the same operational cash and vesting logic as the daily Flow. Future awards are not treated as available today and are promoted only on vesting+settlement dates.',
  'guardrails',coalesce((select j->'guardrails' from base),'[]'::jsonb) || jsonb_build_array(
    'Dashboard and Flow share the same operational cash motor.',
    'RSU already vested today is separated from future awards scheduled to vest later.',
    'FGTS remains restricted and is not used to declare cash coverage.')
);
$function$;

CREATE OR REPLACE FUNCTION public.lts_dashboard_source_key_v240(p_user_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
SELECT md5(jsonb_build_object(
 'revision','canonical-cache-v247-rollover','date',current_date,
 'operational',public.lts_operational_source_key_v238(p_user_id),
 'fact_confirmations',(select md5(coalesce(string_agg(to_jsonb(f)::text,'|' order by id),'empty')) from public.lts_fact_confirmation f where user_id=p_user_id),
 'bank',public.lts_open_finance_checking_positions_v1(p_user_id),
 'staging',(select md5(coalesce(string_agg(jsonb_build_array(id,resource_type,raw_hash,normalized_payload,posting_date,signed_amount,provider_deleted_at)::text,'|' order by id),'empty')) from public.lts_open_finance_staging where user_id=p_user_id),
 'decisions',(select md5(coalesce(string_agg(to_jsonb(d)::text,'|' order by source_table,source_ref),'empty')) from public.lts_v178_review_decision d where user_id=p_user_id),
 'assets',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.asset_positions a where user_id=p_user_id),
 'movements',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.lts_liquidity_movement a where user_id=p_user_id),
 'schedule',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.lts_future_liquidity_schedule a where user_id=p_user_id),
 'brokerage',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.lts_brokerage_position_snapshots a where user_id=p_user_id),
 'invoices',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.card_invoices a where user_id=p_user_id),
 'locks',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by lock_key),'empty')) from public.lts_validated_lock_registry a where superseded_at is null)
)::text)
$function$;
