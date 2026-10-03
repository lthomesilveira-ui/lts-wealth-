CREATE OR REPLACE FUNCTION public.lts_updates_current_sources_v240(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH base AS MATERIALIZED (select public.lts_updates_fix86plus_v12(p_user_id) j),
positions AS MATERIALIZED (select public.lts_open_finance_checking_positions_v1(p_user_id) j),
kept AS (select x from base,lateral jsonb_array_elements(base.j->'items') x
 where NOT (x->>'maintenance_kind'='bank_statement' and exists(
  select 1 from positions,lateral jsonb_array_elements(positions.j) p
  where (p->>'as_of')::timestamptz::date=current_date and
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

ALTER FUNCTION public.lts_browser_dashboard_cockpit_v1() SET statement_timeout TO '45s';
ALTER FUNCTION public.lts_apply_current_liquidity_anchor_v1(uuid) SET statement_timeout TO '45s';
ALTER FUNCTION public.lts_refresh_product_read_cache_operational_v5(uuid) SET statement_timeout TO '45s';
CREATE OR REPLACE FUNCTION public.lts_dashboard_source_key_v240(p_user_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
SELECT md5(jsonb_build_object(
 'revision','canonical-cache-v242','date',current_date,
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
