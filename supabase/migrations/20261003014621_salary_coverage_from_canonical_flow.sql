CREATE OR REPLACE FUNCTION public.lts_updates_salary_coverage_v243(p_user_id uuid,p_updates jsonb,p_flow jsonb)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path TO '' SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH salary_months AS (
 SELECT DISTINCT date_trunc('month',(e->>'event_date')::date)::date m
 FROM jsonb_array_elements(public.lts_flow_operational_read_v229(p_user_id,make_date(extract(year from current_date)::int,1,1),current_date-1)) e
 WHERE (e->>'signed_amount')::numeric>0 AND public.lts_v178_norm(e->>'category')='salario'
 UNION
 SELECT DISTINCT date_trunc('month',(e->>'event_date')::date)::date
 FROM jsonb_array_elements(coalesce(p_flow->'events','[]')) e
 WHERE (e->>'signed_amount')::numeric>0 AND public.lts_v178_norm(e->>'category')='salario'
 AND extract(year from (e->>'event_date')::date)=extract(year from current_date)
), covered AS (select count(*)=12 ok,count(*) months from salary_months),
kept AS (select x from jsonb_array_elements(coalesce(p_updates->'items','[]')) x,covered
 WHERE NOT (covered.ok AND x->>'id'='coverage_salary_'||extract(year from current_date)::int::text)),
stats AS (select coalesce(jsonb_agg(x order by coalesce((x->>'priority')::int,9),x->>'id'),'[]') items,count(*) total,
 count(*) filter(where x->>'status' not in ('informational','guarded','resolved','current')) actionable,
 count(*) filter(where x->>'status' not in ('informational','guarded','resolved','current') and (x->>'priority')::int=1) urgent from kept)
SELECT p_updates||jsonb_build_object('items',stats.items,'pending_count',stats.total,'actionable_count',stats.actionable,'urgent_count',stats.urgent,
 'salary_current_year_coverage',jsonb_build_object('year',extract(year from current_date)::int,'months',covered.months,'complete',covered.ok,
 'basis','existing classified historical salary plus canonical future salary events; projections remain projections')) FROM stats,covered
$function$;
REVOKE ALL ON FUNCTION public.lts_updates_salary_coverage_v243(uuid,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_updates_salary_coverage_v243(uuid,jsonb,jsonb) TO service_role;
CREATE OR REPLACE FUNCTION public.lts_apply_current_liquidity_anchor_v1(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '45s'
AS $function$
<<cache_refresh>>
DECLARE c record; k text; cached_key text; f jsonb; flow jsonb; pe jsonb; dashboard jsonb; ladder jsonb; w jsonb; updates jsonb; payload jsonb; pending int; pending_rows jsonb; today_day jsonb; cockpit jsonb; horizon date:=(current_date+interval '12 months')::date;
BEGIN
 select * into c from public.lts_product_read_cache where user_id=p_user_id for update;
 if not found then raise exception 'product cache unavailable'; end if;
 k:=public.lts_dashboard_source_key_v240(p_user_id);
 cached_key:=public.lts_dashboard_payload_key_v240(c.payload);
 if c.payload#>>'{canonical_summary,source_key}'=k and c.payload#>>'{canonical_summary,payload_key}'=cached_key then
  return jsonb_build_object('ok',true,'version','canonical-cache-v240','cache_hit',true);
 end if;
 f:=public.lts_flow_cache_core_v240(p_user_id,current_date,horizon)->'flow';
 flow:=jsonb_build_object('version','canonical-flow-v240-cache','from',current_date,'to',horizon,
  'days',coalesce(f#>'{current_future,days}','[]'),'events',coalesce(f#>'{current_future,events}','[]'),
  'observed_bank_movements',f->'observed_bank_movements','projected_operational_anchor',f->'projected_operational_anchor');
 select x into today_day from jsonb_array_elements(flow->'days') x where x->>'date'=current_date::text;
 if today_day is null then raise exception 'canonical current flow day unavailable'; end if;
 pe:=public.lts_planning_executive_from_flow_v1(p_user_id,current_date,horizon,flow);
 dashboard:=public.lts_dashboard_executive_from_flow_v1(p_user_id,current_date,flow);
 ladder:=jsonb_build_object('version','planning-ladder-v240-canonical','from',pe#>'{period,from}','to',pe#>'{period,to}',
  'flow_basis','canonical_operational_flow_v240','layers',pe->'layers','first_real_gap_date',pe#>'{summary,first_real_gap_date}',
  'gap_episodes',pe->'gap_episodes','fgts_first_negative_date',pe#>'{summary,first_negative_even_with_fgts}','fgts_access',pe->'fgts_access');
 w:=public.lts_wealth_executive_report_v5(p_user_id);
 updates:=public.lts_updates_salary_coverage_v243(p_user_id,public.lts_updates_current_sources_v240(p_user_id),flow);
 select count(*),coalesce(jsonb_agg(to_jsonb(r) order by r.event_date desc,r.source_ref),'[]'::jsonb) into pending,pending_rows from public.lts_v229_review_rows(p_user_id,date '2013-10-10',current_date) r where r.identity_status='pending';
 payload:=c.payload||jsonb_build_object('flow',flow,'planning',public.lts_cashflow_scenarios_from_flow_v1(p_user_id,current_date,make_date(extract(year from current_date)::int,12,31),flow),
  'planning_executive',pe,'planning_ladder',ladder,'dashboard',dashboard,'wealth_executive',w,'updates',updates,
  'card_classification_review',jsonb_build_object('version','canonical-review-v229','pending_groups',pending,'pending_lines',pending,'items',pending_rows,'source_contract','canonical review queue'),
  'semantic_review',jsonb_build_object('version','canonical-review-v229','pending_groups',0,'items','[]'::jsonb,'source_contract','already counted once in canonical review queue'));
 payload:=payload||jsonb_build_object('canonical_summary',jsonb_build_object('version','v240','as_of',current_date,'source_key',k,
  'payload_key',public.lts_dashboard_payload_key_v240(payload),'financial_fact_changed',false));
 update public.lts_product_read_cache set payload=cache_refresh.payload,refreshed_at=now(),source='canonical_flow_current_sources_v240' where user_id=p_user_id;
 cockpit:=public.lts_refresh_dashboard_cockpit_v2(p_user_id);
 return jsonb_build_object('ok',true,'version','canonical-cache-v240','cache_hit',false,'classification_pending',pending,
  'target_bank_cash',today_day#>'{fix86_columns,saldo_final}','source_key',k,'horizon',horizon,'financial_fact_changed',false);
END $function$;

CREATE OR REPLACE FUNCTION public.lts_dashboard_source_key_v240(p_user_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
SELECT md5(jsonb_build_object(
 'revision','canonical-cache-v243','date',current_date,
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
