-- The legacy invoice snapshot provides the reviewed card/cycle alias only.
-- Its old amount must not outrank the exact, refreshed issuer invoice and bank payment.
SET LOCAL lock_timeout='3s';
SET LOCAL statement_timeout='20s';
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
$function$;

DO $key$ DECLARE d text; BEGIN
 SELECT pg_get_functiondef('public.lts_flow_read_key_engine_v243(uuid)'::regprocedure) INTO d;
 IF position($a$ 'reader_revision','correlated-cash-and-calendar-coverage-v269-c6',$a$ IN d)=0
 THEN RAISE EXCEPTION 'V290 flow key source changed'; END IF;
 d:=replace(d,$a$ 'reader_revision','correlated-cash-and-calendar-coverage-v269-c6',$a$,
 $b$ 'reader_revision','shared-card-projection-v290',
 'card_due_rules',(SELECT jsonb_agg(to_jsonb(r) ORDER BY family,effective_from) FROM public.lts_card_due_rule_v290 r WHERE r.user_id=p_user_id),
 'current_card_projection',(SELECT jsonb_agg(to_jsonb(r) ORDER BY card_name,reference_month) FROM public.lts_card_projection_rows_v290(p_user_id)r),$b$);
 EXECUTE d;
END $key$;
