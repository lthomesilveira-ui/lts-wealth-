CREATE OR REPLACE FUNCTION public.lts_dashboard_cockpit_top_actions_v1(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with c as (
  select payload from public.lts_product_read_cache where user_id=p_user_id limit 1
), a as (
  select x,
    coalesce((x->>'priority')::int,9) priority,
    nullif(x->>'due_date','')::date due_date,
    coalesce(x->>'maintenance_kind','') kind,
    coalesce((x->>'year')::int,0) yr,
    case coalesce(x->>'maintenance_kind','')
      when 'bank_statement' then 0
      when 'vehicle_tax' then 1
      when 'card_cycle' then 2
      else 3 end kind_rank
  from c,lateral jsonb_array_elements(coalesce(c.payload#>'{updates,items}','[]'::jsonb)) x
  where coalesce(x->>'status','') in ('needs_confirmation','needs_review','review','missing','stale')
), eligible as (
  select * from a
  where priority=1
     or kind='bank_statement'
     or (due_date is not null and due_date<=current_date+60)
     or (kind='vehicle_tax' and yr between extract(year from current_date)::int and extract(year from current_date)::int+1)
), picked as (
  select * from eligible order by priority,kind_rank,due_date nulls last,x->>'title' limit 5
)
select coalesce(jsonb_agg(x order by priority,kind_rank,due_date nulls last,x->>'title'),'[]'::jsonb) from picked
$function$;

CREATE OR REPLACE FUNCTION public.lts_dashboard_source_key_v240(p_user_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
SELECT md5(jsonb_build_object(
 'revision','canonical-cache-v241','date',current_date,
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

CREATE OR REPLACE FUNCTION public.lts_refresh_dashboard_cockpit_v2(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  c record;
  tf jsonb;
  d jsonb;
  pl jsonb;
  pe jsonb;
  w jsonb;
  u jsonb;
  card jsonb;
  cr jsonb;
  sr jsonb;
  ei jsonb;
  bank numeric:=0;
  d0 numeric:=0;
  d3 numeric:=0;
  fgts numeric:=0;
  available numeric:=0;
  class_groups int:=0;
  curr_exp jsonb;
  prev_exp jsonb;
  top_actions jsonb:='[]'::jsonb;
  accounts jsonb:='[]'::jsonb;
  status text;
  headline text;
  message text;
  management_date date;
  uncovered_after_fgts date;
  request_by date;
  fgts_coverage numeric:=0;
  worst_before numeric;
  worst_after numeric;
  covers boolean:=false;
  outj jsonb;
begin
  select * into c from public.lts_product_read_cache where user_id=p_user_id limit 1;
  if not found or c.payload is null then raise exception 'product cache unavailable'; end if;
  if c.payload_version <> 'lts-product-fix86-v36' then raise exception 'unexpected product cache version'; end if;

  select x into tf
  from jsonb_array_elements(coalesce(c.payload#>'{flow,days}','[]'::jsonb)) x
  where x->>'date'=current_date::text
  limit 1;
  if tf is null then raise exception 'current Flow day unavailable in product cache'; end if;

  d:=coalesce(c.payload->'dashboard','{}'::jsonb);
  pl:=coalesce(c.payload->'planning_ladder','{}'::jsonb);
  pe:=coalesce(c.payload->'planning_executive','{}'::jsonb);
  w:=coalesce(c.payload->'wealth_executive','{}'::jsonb);
  if coalesce(w->>'version','') <> 'wealth-executive-v5-effective-bank-asset-liquidity' then
    w:=public.lts_wealth_executive_report_v5(p_user_id);
  end if;
  u:=coalesce(c.payload->'updates','{}'::jsonb);
  card:=coalesce(c.payload->'card_operating','{}'::jsonb);
  cr:=coalesce(c.payload->'card_classification_review','{}'::jsonb);
  sr:=coalesce(c.payload->'semantic_review','{}'::jsonb);
  ei:=coalesce(c.payload->'expense_insights','{}'::jsonb);

  bank:=coalesce((public.lts_current_evidence_position_v1(p_user_id)->>'bank_cash')::numeric,0);
  d0:=coalesce((public.lts_current_evidence_position_v1(p_user_id)->>'liquid_d0_assets')::numeric,0);
  d3:=coalesce((tf#>>'{fix86_columns,rsus_vested}')::numeric,0);
  fgts:=coalesce((w#>>'{liquidity,fgts_contingency}')::numeric,0);
  available:=bank+d0+d3;
  class_groups:=coalesce((cr->>'pending_groups')::int,0)+coalesce((sr->>'pending_groups')::int,0);

  management_date:=nullif(pl->>'first_real_gap_date','')::date;
  uncovered_after_fgts:=coalesce(nullif(pl->>'fgts_first_negative_date','')::date,nullif(pe#>>'{summary,first_negative_even_with_fgts}','')::date);
  request_by:=coalesce(nullif(pl#>>'{fgts_access,request_by_date}','')::date,nullif(pe#>>'{summary,fgts_request_by}','')::date);
  fgts_coverage:=coalesce((pl#>>'{fgts_access,amount_brl}')::numeric,(pe#>>'{summary,fgts_amount}')::numeric,fgts,0);
  select (x->>'worst_balance')::numeric into worst_before from jsonb_array_elements(coalesce(pl->'layers','[]'::jsonb)) x where x->>'id'='future_vestings' limit 1;
  select (x->>'worst_balance')::numeric into worst_after from jsonb_array_elements(coalesce(pl->'layers','[]'::jsonb)) x where x->>'id'='fgts' limit 1;
  covers:=coalesce((pl#>>'{fgts_access,covers_horizon_if_available}')::boolean,(pe#>>'{summary,fgts_covers_horizon}')::boolean,false);

  accounts:=coalesce(public.lts_current_evidence_position_v1(p_user_id)->'accounts','[]'::jsonb);

  select x into curr_exp from jsonb_array_elements(coalesce(ei->'monthly_12m','[]'::jsonb)) x where x->>'month'=date_trunc('month',current_date)::date::text limit 1;
  select x into prev_exp from jsonb_array_elements(coalesce(ei->'monthly_12m','[]'::jsonb)) x where x->>'month'=(date_trunc('month',current_date)-interval '1 month')::date::text limit 1;

  with a as (
    select x,coalesce((x->>'priority')::int,9) priority,nullif(x->>'due_date','')::date due_date,coalesce(x->>'maintenance_kind','') kind,coalesce((x->>'year')::int,0) yr
    from jsonb_array_elements(coalesce(u->'items','[]'::jsonb)) x
    where coalesce(x->>'status','') in ('needs_confirmation','needs_review','review','missing','stale')
  ), eligible as (
    select * from a where priority=1 or (due_date is not null and due_date<=current_date+60) or kind='bank_statement' or (kind='vehicle_tax' and yr between extract(year from current_date)::int and extract(year from current_date)::int+1)
  )
  select coalesce(jsonb_agg(x order by priority,due_date nulls last,x->>'title'),'[]'::jsonb)
  into top_actions from (select * from eligible order by priority,due_date nulls last,x->>'title' limit 5) q;

  status:=case when uncovered_after_fgts is not null then 'critical' when management_date is not null then 'attention' else 'ok' end;
  headline:=case status when 'critical' then 'Há um gap de liquidez ainda não coberto no horizonte.' when 'attention' then 'Há um ponto de gestão de liquidez que pode ser coberto com a contingência documental disponível.' else 'Liquidez coberta no horizonte auditado.' end;
  message:=case status
    when 'critical' then 'Com o FGTS documental atual de R$ '||to_char(fgts_coverage,'FM999G999G990D00')||', sem estimar depósitos futuros, a contingência D+30 não cobre todo o horizonte. Primeiro saldo negativo mesmo após FGTS: '||to_char(uncovered_after_fgts,'DD/MM/YYYY')||'.'
    when 'attention' then 'O primeiro ponto de gestão é '||to_char(management_date,'DD/MM/YYYY')||'. A análise usa somente o FGTS documental atual, sem estimar depósitos futuros.'
    else 'Não há ponto de gestão descoberto no horizonte auditado.' end;

  outj:=jsonb_build_object(
    'version','dashboard-cockpit-v2-documentary-fgts-no-projection',
    'as_of',current_date,
    'source_product_refreshed_at',c.refreshed_at,
    'status',status,
    'headline',headline,
    'executive_message',message,
    'liquidity',jsonb_build_object('bank_cash',round(bank,2),'d0',round(d0,2),'d3_vested',round(d3,2),'through_d3',round(available,2),'fgts_d30',round(fgts,2),'accounts',accounts),
    'cards',jsonb_build_object('closed_or_due_total',coalesce((card->>'closed_or_due_total')::numeric,0),'open_cycles_total',coalesce((card->>'open_cycles_total')::numeric,0),'next_due',coalesce(card->'next_due','{}'::jsonb)),
    'work',jsonb_build_object('actionable_count',coalesce((u->>'actionable_count')::int,0),'pending_count',coalesce((u->>'pending_count')::int,0),'classification_groups',class_groups,'top_actions',top_actions),
    'horizons',coalesce(d->'horizons','[]'::jsonb),
    'planning_audited',jsonb_build_object(
      'classification',case when uncovered_after_fgts is not null then 'uncovered_liquidity_gap_after_documented_fgts_d30' when management_date is not null then 'liquidity_management_point_covered_by_documented_fgts_d30' else 'covered_without_fgts' end,
      'management_point_date',management_date,
      'first_uncovered_gap_date',uncovered_after_fgts,
      'fgts_request_by',request_by,
      'coverage_amount_brl',round(fgts_coverage,2),
      'worst_before_brl',worst_before,
      'worst_after_brl',worst_after,
      'covers_horizon',covers,
      'fgts_future_accrual_estimated',false,
      'planning_ladder_version',pl->>'version'
    ),
    'future_liquidity',coalesce(d->'future_liquidity_calendar','[]'::jsonb),
    'wealth',jsonb_build_object('net_worth_central',w#>'{summary,net_worth_central}','known_debt_total',w#>'{summary,known_debt_total}','assets_central',w#>'{summary,assets_central}'),
    'expenses',jsonb_build_object('current_month',coalesce(curr_exp,'{}'::jsonb),'previous_month',coalesce(prev_exp,'{}'::jsonb),'coverage_warning',ei#>'{anomaly,coverage_warning}','comparison_is_reliable',coalesce((ei#>>'{anomaly,reliable}')::boolean,false)),
    'guardrails',jsonb_build_array(
      'Dashboard uses the current operational Planning ladder from the product read cache.',
      'FGTS is D+30 contingency, never immediate cash.',
      'FGTS coverage uses only the latest documentary balance; future FGTS deposits/accrual are not estimated.',
      'Future RSUs remain conditional until vesting + settlement.',
      'Bank↔asset liquidity movements change composition, not total liquidity or spend.'
    )
  );

  insert into public.lts_dashboard_cockpit_cache(user_id,as_of,source_product_refreshed_at,payload,refreshed_at)
  values(p_user_id,current_date,c.refreshed_at,outj,now())
  on conflict(user_id) do update set as_of=excluded.as_of,source_product_refreshed_at=excluded.source_product_refreshed_at,payload=excluded.payload,refreshed_at=excluded.refreshed_at;
  return outj;
end
$function$;
