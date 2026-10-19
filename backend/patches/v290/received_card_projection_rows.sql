-- A received open-cycle composition is grouped from the same canonical purchase
-- reader used by Cards. No C6 derivation, no synthetic invoices, no legacy estimate.
CREATE OR REPLACE FUNCTION public.lts_card_projection_rows_v290(p_user_id uuid)
RETURNS TABLE(user_id uuid,card_name text,reference_month date,due_date date,status text,amount numeric,source text)
LANGUAGE sql SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
WITH enabled AS MATERIALIZED(SELECT DISTINCT ON(family) family,effective_from,due_day
 FROM public.lts_card_due_rule_v290 WHERE user_id=p_user_id ORDER BY family,effective_from DESC),
rows AS MATERIALIZED(SELECT r.* FROM public.lts_card_source_rows_v226(p_user_id)r
 WHERE r.provider_status IN('PENDING','DOCUMENTED') AND NOT r.is_payment),
bills AS MATERIALIZED(SELECT * FROM public.lts_current_received_card_bills_v263(p_user_id)),
grouped AS(SELECT r.family,r.reference_month,round(sum(r.amount),2) amount,rule.due_day
 FROM rows r JOIN enabled rule ON rule.family=r.family AND r.reference_month>=rule.effective_from
 WHERE r.family<>'c6' AND r.reference_month>=date_trunc('month',current_date)::date
 AND NOT EXISTS(SELECT 1 FROM bills b WHERE b.family=r.family AND b.reference_month=r.reference_month)
 GROUP BY r.family,r.reference_month,rule.due_day)
SELECT p_user_id,ci.card_name,g.reference_month,g.reference_month+g.due_day-1,'projected'::text,g.amount,
 'received_card_composition_v290'::text
FROM grouped g JOIN LATERAL(SELECT i.card_name FROM public.card_invoices i
 WHERE i.user_id=p_user_id AND public.lts_card_family_v226(i.card_name,i.card_name)=g.family
 ORDER BY i.reference_month DESC,i.due_date DESC LIMIT 1)ci ON true
WHERE g.amount>=0 AND g.reference_month+g.due_day-1>=current_date
$f$;
