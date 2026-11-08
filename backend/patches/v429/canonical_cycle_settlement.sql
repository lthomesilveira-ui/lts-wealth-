-- Reuse an exact canonical fact confirmation in every card-cycle consumer.
-- This is read-only reconciliation: no invoice, payment, expense or cash fact is written.
BEGIN;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='10s';

DO $guard$
BEGIN
 IF md5(pg_get_functiondef('public.lts_card_invoice_settled_v290(uuid,text,date,date,numeric)'::regprocedure))
   NOT IN ('fbcc6cd38b1143fdbb02555ae7611744')
 AND position('exact_card_cycle_fact_confirmation_v429' IN
   pg_get_functiondef('public.lts_card_invoice_settled_v290(uuid,text,date,date,numeric)'::regprocedure))=0
 THEN RAISE EXCEPTION 'V429_INVOICE_SETTLED_PREDECESSOR_CHANGED'; END IF;
 IF md5(pg_get_functiondef('public.lts_card_settlement_overlay_v290(uuid,jsonb)'::regprocedure))
   NOT IN ('f08c891bd14405aef28d11782c78a9ef')
 AND position('exact_card_cycle_fact_confirmation_v429' IN
   pg_get_functiondef('public.lts_card_settlement_overlay_v290(uuid,jsonb)'::regprocedure))=0
 THEN RAISE EXCEPTION 'V429_SETTLEMENT_OVERLAY_PREDECESSOR_CHANGED'; END IF;
END
$guard$;

DO $patch$
DECLARE
 invoice_target regprocedure:='public.lts_card_invoice_settled_v290(uuid,text,date,date,numeric)'::regprocedure;
 overlay_target regprocedure:='public.lts_card_settlement_overlay_v290(uuid,jsonb)'::regprocedure;
 invoice_attrs jsonb; overlay_attrs jsonb; applied boolean:=false;
BEGIN
 SELECT to_jsonb(p)-'prosrc' INTO invoice_attrs FROM pg_catalog.pg_proc p WHERE p.oid=invoice_target;
 SELECT to_jsonb(p)-'prosrc' INTO overlay_attrs FROM pg_catalog.pg_proc p WHERE p.oid=overlay_target;
 IF invoice_attrs->>'prosecdef'<>'false' OR overlay_attrs->>'prosecdef'<>'false'
  OR has_function_privilege('anon',invoice_target,'EXECUTE')
  OR has_function_privilege('authenticated',invoice_target,'EXECUTE')
  OR has_function_privilege('anon',overlay_target,'EXECUTE')
  OR has_function_privilege('authenticated',overlay_target,'EXECUTE')
  OR NOT has_function_privilege('service_role',invoice_target,'EXECUTE')
  OR NOT has_function_privilege('service_role',overlay_target,'EXECUTE')
 THEN RAISE EXCEPTION 'V429_PREDECESSOR_ATTRIBUTES_CHANGED'; END IF;

 IF position('exact_card_cycle_fact_confirmation_v429' IN pg_get_functiondef(invoice_target))=0 THEN
  applied:=true;
  EXECUTE $definition$
CREATE OR REPLACE FUNCTION public.lts_card_invoice_settled_v290(p_user_id uuid, p_name text, p_month date, p_due date, p_amount numeric)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
SELECT EXISTS(
 SELECT 1 FROM public.lts_card_documentary_payment_link_v272 l
 JOIN public.lts_open_finance_staging inv ON inv.user_id=l.user_id AND inv.id=l.invoice_source_id
 JOIN public.lts_open_finance_staging pay ON pay.user_id=l.user_id AND pay.id=l.payment_source_id
 JOIN public.lts_card_settlement_expense_contract_v273 c ON c.user_id=l.user_id AND c.payment_source_id=l.payment_source_id AND c.active
 JOIN public.card_invoices ci ON ci.user_id=l.user_id AND ci.card_name=p_name
 AND ci.reference_month=p_month AND ci.due_date=p_due
 WHERE l.user_id=p_user_id AND l.active AND l.expected_due_date=p_due AND l.expected_amount=p_amount
 AND date_trunc('month',l.expected_due_date)::date=p_month
 AND public.lts_card_family_v226(ci.card_name,ci.card_name)=public.lts_card_family_v226(inv.normalized_payload->>'card_name',inv.institution_name)
 AND public.lts_card_payment_refresh_annotation_v273(p_user_id,to_jsonb(l),to_jsonb(inv),to_jsonb(pay),c.payload,current_date) IS NOT NULL
)
OR 1=(
 SELECT count(*) FROM public.card_invoices ci
 JOIN public.lts_fact_confirmation fc ON fc.user_id=ci.user_id
  AND fc.source_ref=ci.card_name||'|'||to_char(ci.reference_month,'YYYY-MM')
  AND fc.event_date=ci.due_date
  AND (fc.signed_amount IS NULL OR abs(fc.signed_amount+abs(ci.amount))<=0.02)
 WHERE ci.user_id=p_user_id AND ci.card_name=p_name AND ci.reference_month=p_month
  AND ci.due_date=p_due AND ci.amount=p_amount
  AND fc.confirmation_source IS NOT NULL
) /* exact_card_cycle_fact_confirmation_v429 */
$function$
  $definition$;
 END IF;

 IF position('exact_card_cycle_fact_confirmation_v429' IN pg_get_functiondef(overlay_target))=0 THEN
  applied:=true;
  EXECUTE $definition$
CREATE OR REPLACE FUNCTION public.lts_card_settlement_overlay_v290(p_user_id uuid, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
WITH links AS MATERIALIZED(
 SELECT l.invoice_source_id,l.expected_amount,l.expected_due_date,l.expected_payment_date,
 public.lts_card_payment_refresh_annotation_v273(p_user_id,to_jsonb(l),to_jsonb(inv),to_jsonb(pay),c.payload,current_date) receipt
 FROM public.lts_card_documentary_payment_link_v272 l
 JOIN public.lts_card_settlement_expense_contract_v273 c ON c.user_id=l.user_id AND c.payment_source_id=l.payment_source_id AND c.active
 JOIN public.lts_open_finance_staging inv ON inv.user_id=l.user_id AND inv.id=l.invoice_source_id
 JOIN public.lts_open_finance_staging pay ON pay.user_id=l.user_id AND pay.id=l.payment_source_id
 WHERE l.user_id=p_user_id AND l.active
), exact_confirmed AS MATERIALIZED(
 SELECT public.lts_card_family_v226(ci.card_name,ci.card_name) family,
  ci.reference_month,ci.due_date,ci.amount,min(ci.card_name) card_name
 FROM public.card_invoices ci
 WHERE ci.user_id=p_user_id
 GROUP BY public.lts_card_family_v226(ci.card_name,ci.card_name),ci.reference_month,ci.due_date,ci.amount
 HAVING count(*)=1 AND public.lts_card_invoice_settled_v290(
  p_user_id,min(ci.card_name),ci.reference_month,ci.due_date,ci.amount)
)
SELECT CASE WHEN jsonb_typeof(p_payload->'cards')='array' THEN jsonb_set(p_payload,'{cards}',(
 SELECT jsonb_agg(c.value||jsonb_build_object('cycles',(
 SELECT coalesce(jsonb_agg(y.value||CASE
  WHEN l.receipt IS NOT NULL
   AND CASE WHEN jsonb_typeof(y.value->'amount')='number' THEN (y.value->>'amount')::numeric=l.expected_amount ELSE false END
   AND CASE WHEN pg_input_is_valid(y.value->>'due_date','date') THEN (y.value->>'due_date')::date=l.expected_due_date ELSE false END THEN
   jsonb_build_object('source_payment_status',y.value->>'payment_status','payment_status','paid',
    'settlement_confirmed',true,'settled_on',l.expected_payment_date,
    'settlement_basis',CASE WHEN l.receipt->>'issuer_payment_type'='OTHER_PAYMENT'
     THEN 'reviewed_c6_other_payment_and_exact_posted_checking_debit'
     ELSE 'reviewed_issuer_full_payment_and_exact_posted_checking_debit' END)
  WHEN f.card_name IS NOT NULL THEN
   jsonb_build_object('source_payment_status',y.value->>'payment_status','payment_status','paid',
    'settlement_confirmed',true,'settled_on',f.due_date,
    'settlement_basis','exact_card_cycle_fact_confirmation_v429')
  ELSE '{}'::jsonb END ORDER BY y.ord),'[]')
 FROM jsonb_array_elements(coalesce(c.value->'cycles','[]')) WITH ORDINALITY y(value,ord)
 LEFT JOIN links l ON l.invoice_source_id::text=y.value->>'invoice_source_id'
 LEFT JOIN exact_confirmed f ON f.family=c.value->>'family'
  AND f.reference_month=CASE WHEN pg_input_is_valid(coalesce(y.value->>'month',y.value->>'reference_month'),'date')
   THEN coalesce(y.value->>'month',y.value->>'reference_month')::date END
  AND f.due_date=CASE WHEN pg_input_is_valid(y.value->>'due_date','date') THEN (y.value->>'due_date')::date END
  AND f.amount=CASE WHEN jsonb_typeof(y.value->'amount')='number' THEN (y.value->>'amount')::numeric END
 )) ORDER BY c.ord)
 FROM jsonb_array_elements(p_payload->'cards') WITH ORDINALITY c(value,ord)
),false) ELSE p_payload END /* exact_card_cycle_fact_confirmation_v429 */
$function$
  $definition$;
 END IF;

 IF invoice_attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_catalog.pg_proc p WHERE p.oid=invoice_target)
  OR overlay_attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_catalog.pg_proc p WHERE p.oid=overlay_target)
 THEN RAISE EXCEPTION 'V429_FUNCTION_ATTRIBUTES_CHANGED'; END IF;
 IF applied THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton; END IF;
END
$patch$;

NOTIFY pgrst,'reload schema';
COMMIT;
