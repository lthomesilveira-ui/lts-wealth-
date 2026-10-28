CREATE OR REPLACE FUNCTION public.lts_aeternum_forecast_cycles_v311(p_user_id uuid)
 RETURNS TABLE(reference_month date, due_date date, amount numeric, item_count bigint, received_amount numeric, projected_amount numeric, observed_at timestamp with time zone, unclassified bigint, items jsonb, basis text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH source_rows AS MATERIALIZED (
 SELECT r.*,s.institution_code,s.provider_account_ref,
 CASE WHEN r.total_installments BETWEEN 2 AND 120 AND r.installment_number BETWEEN 1 AND r.total_installments
 AND nullif(s.raw_payload#>>'{creditCardMetadata,purchaseDate}','') IS NOT NULL
 AND r.purchase_date IS NOT NULL AND nullif(r.last4,'') IS NOT NULL
 AND nullif(s.provider_account_ref,'') IS NOT NULL
 THEN jsonb_build_array(r.family,s.institution_code,s.provider_account_ref,r.last4,r.purchase_date,
 public.lts_card_merchant_key_v226(r.description),r.total_installments,
 extract(year FROM r.reference_month)::int*12+extract(month FROM r.reference_month)::int-r.installment_number)::text END plan_key
 FROM public.lts_card_source_rows_v226(p_user_id) r
 JOIN public.lts_open_finance_staging s ON s.id=r.source_id AND s.user_id=p_user_id
 AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL AND s.currency='BRL'
 WHERE r.family='aeternum' AND NOT r.is_payment
), bills AS MATERIALIZED (
 SELECT b.*,s.institution_code,s.provider_account_ref,s.normalized_payload->>'provider_id' bill_id
 FROM public.lts_current_received_card_bills_v263(p_user_id) b
 JOIN public.lts_open_finance_staging s ON s.id=b.invoice_source_id AND s.user_id=p_user_id
 WHERE b.family='aeternum' AND s.provider_deleted_at IS NULL AND s.currency='BRL'
), latest AS MATERIALIZED (
 SELECT DISTINCT ON(family,institution_code,provider_account_ref) * FROM bills
 ORDER BY family,institution_code,provider_account_ref,reference_month DESC,due_date DESC
), anchor AS MATERIALIZED (
 SELECT r.* FROM source_rows r JOIN latest b USING(family,institution_code,provider_account_ref)
 WHERE r.bill_id=b.bill_id AND r.reference_month=b.reference_month AND r.provider_status='POSTED'
), observed AS MATERIALIZED (
 SELECT r.* FROM source_rows r LEFT JOIN latest b USING(family,institution_code,provider_account_ref)
 WHERE r.provider_status='PENDING' AND r.reference_month>=date_trunc('month',current_date)::date
 AND (b.reference_month IS NULL OR r.reference_month>b.reference_month)
 AND NOT EXISTS(SELECT 1 FROM bills x WHERE x.family=r.family AND x.reference_month=r.reference_month
 AND x.institution_code=r.institution_code AND x.provider_account_ref=r.provider_account_ref)
), plan_inputs AS MATERIALIZED (
 SELECT * FROM anchor WHERE plan_key IS NOT NULL AND amount>0
 UNION ALL SELECT * FROM observed WHERE plan_key IS NOT NULL AND amount>0
), groups AS MATERIALIZED (
 SELECT family,plan_key,reference_month,installment_number,total_installments,count(*) n,sum(amount) amount,
 jsonb_agg(to_jsonb(r)-ARRAY['plan_key','institution_code','provider_account_ref'] ORDER BY source_id) items
 FROM plan_inputs r GROUP BY family,plan_key,reference_month,installment_number,total_installments
), projected AS MATERIALIZED (
 SELECT DISTINCT ON(g.plan_key,(g.reference_month+make_interval(months=>step))::date)
 g.*,step,(g.reference_month+make_interval(months=>step))::date target_month
 FROM groups g CROSS JOIN LATERAL generate_series(1,g.total_installments-g.installment_number) step
 WHERE (g.reference_month+make_interval(months=>step))::date>=date_trunc('month',current_date)::date
 AND NOT EXISTS(SELECT 1 FROM groups actual WHERE actual.plan_key=g.plan_key
 AND actual.reference_month=(g.reference_month+make_interval(months=>step))::date)
 ORDER BY g.plan_key,(g.reference_month+make_interval(months=>step))::date,g.reference_month DESC
), items AS MATERIALIZED (
 SELECT family,reference_month,amount,'received'::text kind,to_jsonb(r)-ARRAY['plan_key','institution_code','provider_account_ref'] item
 FROM observed r
 UNION ALL
 SELECT family,target_month,(i->>'amount')::numeric,'projected',i||jsonb_build_object('reference_month',target_month,
 'due_date',NULL,'installment_number',(i->>'installment_number')::int+step,'provider_status','PROJECTED',
 'projection_basis','remaining_installments_from_latest_received_cycle','projection_source_month',reference_month)
 FROM projected CROSS JOIN LATERAL jsonb_array_elements(items)i
 WHERE NOT EXISTS(SELECT 1 FROM bills b WHERE b.family=projected.family AND b.reference_month=projected.target_month)
)
, cycle_rows AS (
SELECT family,reference_month,round(sum(amount),2) amount,
 count(*) item_count,count(*)filter(where kind='received') received_count,count(*)filter(where kind='projected') projected_count,
 round(coalesce(sum(amount)filter(where kind='received'),0),2) received_amount,
 round(coalesce(sum(amount)filter(where kind='projected'),0),2) projected_amount,
 max((item->>'observed_at')::timestamptz) observed_at,
 count(*)filter(where item->>'category_basis'='unresolved') unclassified,
 jsonb_agg(item ORDER BY item->>'description',item->>'source_id') items
FROM items GROUP BY family,reference_month
)
SELECT c.reference_month,
 c.reference_month+least(coalesce(rule.due_day,extract(day FROM latest.due_date)::int),
 extract(day FROM(c.reference_month+interval '1 month -1 day'))::int)-1,
 c.amount,c.item_count,c.received_amount,c.projected_amount,c.observed_at,c.unclassified,c.items,
 CASE WHEN c.received_count>0 AND c.projected_count>0 THEN 'received_and_projected_installments'
 WHEN c.received_count>0 THEN 'open_finance_composition' ELSE 'derived_current_installments' END
FROM cycle_rows c CROSS JOIN latest
LEFT JOIN LATERAL(SELECT r.due_day FROM public.lts_card_due_rule_v290 r
 WHERE r.user_id=p_user_id AND r.family='aeternum' AND r.effective_from<=c.reference_month
 ORDER BY r.effective_from DESC LIMIT 1)rule ON true
WHERE c.reference_month>latest.reference_month AND c.amount>=0
AND (SELECT count(*) FROM latest WHERE family='aeternum')=1
AND abs(latest.amount-coalesce((SELECT sum(r.amount) FROM anchor r),0))<0.005
AND NOT EXISTS(SELECT 1 FROM anchor r WHERE r.total_installments>r.installment_number
 AND r.installment_number>0 AND r.plan_key IS NULL)
AND NOT EXISTS(SELECT 1 FROM observed r WHERE r.total_installments>r.installment_number
 AND r.installment_number>0 AND r.plan_key IS NULL)
ORDER BY c.reference_month
$function$
