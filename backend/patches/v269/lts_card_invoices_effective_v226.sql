CREATE OR REPLACE FUNCTION public.lts_card_invoices_effective_v226(p_user_id uuid)
 RETURNS SETOF card_invoices
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with rows as materialized (
 select * from public.lts_card_source_rows_v226(p_user_id) where not is_payment and provider_status='PENDING' and reference_month>=date_trunc('month',current_date)::date
), composition as materialized (
 select family,reference_month,round(sum(amount),2) amount,max(observed_at) observed_at,
 jsonb_agg(to_jsonb(r)||jsonb_build_object('source_line',source_id,'card_final',last4) order by posting_date,description,source_id) items
 from rows r group by family,reference_month
), effective as materialized (
 select to_jsonb(i)||case when c.items is not null and i.status='open' and i.due_date>=current_date then
 jsonb_build_object('amount',c.amount,'source','open_finance_composition_v226','metadata',coalesce(i.metadata,'{}'::jsonb)||jsonb_build_object(
 'items',c.items,'open_finance_observed_at',c.observed_at,'documentary_snapshot',jsonb_build_object('amount',i.amount,'source',i.source,'as_of',i.metadata->'as_of')))
 else '{}'::jsonb end value
 from public.card_invoices i left join composition c on c.reference_month=i.reference_month
 and c.family=public.lts_card_family_v226(i.card_name,case when i.card_name ~* 'c6' then 'C6' when i.card_name ~* 'aeternum|bradesco|prime' then 'Bradesco' else 'Itaú' end)
 where i.user_id=p_user_id
)
select r.* from effective e
 LEFT JOIN public.lts_card_invoice_amounts_v230(p_user_id) a ON public.lts_card_family_v226(e.value->>'card_name',e.value->>'card_name')='c6'
 AND public.lts_card_family_v226(a.card_name,a.card_name)='c6'
 AND (e.value->>'reference_month')::date=a.reference_month AND (e.value->>'due_date')::date=a.due_date
 AND e.value->>'status' IN('open','projected')
 cross join lateral jsonb_populate_record(null::public.card_invoices,e.value||CASE WHEN a.reference_month IS NOT NULL THEN
 jsonb_build_object('amount',a.amount,'source',a.source) ELSE '{}'::jsonb END)r
$function$;
