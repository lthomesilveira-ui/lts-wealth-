-- V264: bank-received current bills need no manually created invoice row.
DO $patch$
DECLARE d text; before_acl aclitem[];
BEGIN
 SELECT pg_get_functiondef(oid),proacl INTO d,before_acl FROM pg_proc WHERE oid='public.lts_card_cycles_v226(uuid)'::regprocedure;
 IF md5(d)<>'0f6eb9e9005c88a4b9d581f92c95cf87' THEN RAISE EXCEPTION 'source lease changed: lts_card_cycles_v226'; END IF;
 d:=replace(d,$old$ WHERE EXISTS(SELECT 1 FROM public.card_invoices i WHERE i.user_id=p_user_id
 AND i.status IN('open','projected') AND i.due_date=b.due_date AND i.reference_month=b.reference_month
 AND public.lts_card_family_v226(i.card_name,i.card_name)=b.family
 AND (CASE WHEN i.metadata->>'as_of' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 THEN (i.metadata->>'as_of')::date ELSE '-infinity'::date END)
 <=(b.source_updated_at AT TIME ZONE 'America/Sao_Paulo')::date)$old$,$new$ WHERE b.due_date>=current_date
 AND NOT EXISTS(SELECT 1 FROM public.card_invoices i WHERE i.user_id=p_user_id
 AND i.reference_month=b.reference_month
 AND public.lts_card_family_v226(i.card_name,i.card_name)=b.family
 AND (i.status NOT IN('open','projected') OR i.due_date IS DISTINCT FROM b.due_date
 OR (CASE WHEN i.metadata->>'as_of' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 THEN (i.metadata->>'as_of')::date ELSE '-infinity'::date END)
 >(b.source_updated_at AT TIME ZONE 'America/Sao_Paulo')::date))$new$);
 d:=replace(d,$old$SELECT c.family,c.month,coalesce(b.due_date,c.due_date) due_date,$old$,$new$SELECT coalesce(c.family,b.family) family,coalesce(c.month,b.reference_month) AS month,coalesce(b.due_date,c.due_date) due_date,$new$);
 d:=replace(d,$old$FROM cycles0 c LEFT JOIN received_bills b ON b.family=c.family AND b.reference_month=c.month
 AND (c.due_date IS NULL OR c.due_date=b.due_date)$old$,$new$FROM cycles0 c FULL JOIN received_bills b ON b.family=c.family AND b.reference_month=c.month$new$);
 EXECUTE d;
 IF (SELECT proacl FROM pg_proc WHERE oid='public.lts_card_cycles_v226(uuid)'::regprocedure) IS DISTINCT FROM before_acl THEN RAISE EXCEPTION 'ACL changed: lts_card_cycles_v226'; END IF;
 SELECT pg_get_functiondef(oid),proacl INTO d,before_acl FROM pg_proc WHERE oid='public.lts_card_invoice_amounts_v230_engine_v243(uuid)'::regprocedure;
 IF md5(d)<>'4d741192e8bc40fb88d56a1f77a24d98' THEN RAISE EXCEPTION 'source lease changed: lts_card_invoice_amounts_v230_engine_v243'; END IF;
 d:=replace(d,$old$ WHERE EXISTS(SELECT 1 FROM public.card_invoices i WHERE i.user_id=p_user_id
 AND i.status IN('open','projected') AND i.due_date=b.due_date AND i.reference_month=b.reference_month
 AND public.lts_card_family_v226(i.card_name,i.card_name)=b.family
 AND (CASE WHEN i.metadata->>'as_of' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 THEN (i.metadata->>'as_of')::date ELSE '-infinity'::date END)
 <=(b.source_updated_at AT TIME ZONE 'America/Sao_Paulo')::date)$old$,$new$ WHERE b.due_date>=current_date
 AND NOT EXISTS(SELECT 1 FROM public.card_invoices i WHERE i.user_id=p_user_id
 AND i.reference_month=b.reference_month
 AND public.lts_card_family_v226(i.card_name,i.card_name)=b.family
 AND (i.status NOT IN('open','projected') OR i.due_date IS DISTINCT FROM b.due_date
 OR (CASE WHEN i.metadata->>'as_of' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 THEN (i.metadata->>'as_of')::date ELSE '-infinity'::date END)
 >(b.source_updated_at AT TIME ZONE 'America/Sao_Paulo')::date))$new$);
 d:=replace(d,$old$AND public.lts_card_family_v226(r.card_name,r.card_name)=b.family
$function$$old$,$new$AND public.lts_card_family_v226(r.card_name,r.card_name)=b.family
UNION ALL
SELECT p_user_id,b.card_name,b.reference_month,b.due_date,
 CASE WHEN b.payment_status='paid' THEN 'paid' ELSE 'open' END,b.amount,'open_finance_invoice_v263'
FROM received_bills b WHERE NOT EXISTS(SELECT 1 FROM baseline r
 WHERE r.reference_month=b.reference_month AND public.lts_card_family_v226(r.card_name,r.card_name)=b.family)
$function$$new$);
 EXECUTE d;
 IF (SELECT proacl FROM pg_proc WHERE oid='public.lts_card_invoice_amounts_v230_engine_v243(uuid)'::regprocedure) IS DISTINCT FROM before_acl THEN RAISE EXCEPTION 'ACL changed: lts_card_invoice_amounts_v230_engine_v243'; END IF;
 SELECT pg_get_functiondef(oid),proacl INTO d,before_acl FROM pg_proc WHERE oid='public.lts_browser_card_cycles_v229()'::regprocedure;
 IF md5(d)<>'7b930507c56af526342d91f7de64082b' THEN RAISE EXCEPTION 'source lease changed: lts_browser_card_cycles_v229'; END IF;
 d:=replace(d,$old$CASE WHEN coalesce(jsonb_array_length(c->'cycles'),0)=0 AND hint.amount IS NOT NULL THEN jsonb_build_object(
 'cycles',jsonb_build_array(jsonb_build_object('month',(date_trunc('month',current_date)+interval '1 month')::date,'due_date',null,$old$,$new$CASE WHEN hint.amount IS NOT NULL AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(c->'cycles','[]'::jsonb)) q
 WHERE q->>'month'=((date_trunc('month',current_date)+interval '1 month')::date)::text) THEN jsonb_build_object(
 'cycles',coalesce(c->'cycles','[]'::jsonb)||jsonb_build_array(jsonb_build_object('month',(date_trunc('month',current_date)+interval '1 month')::date,'due_date',
 CASE WHEN c->>'last_due' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
 make_date(extract(year FROM current_date+interval '1 month')::int,extract(month FROM current_date+interval '1 month')::int,
 least(extract(day FROM (c->>'last_due')::date)::int,extract(day FROM date_trunc('month',current_date)+interval '2 months -1 day')::int)) END,
 'due_date_basis','estimate_from_received_due_day',$new$);
 EXECUTE d;
 IF (SELECT proacl FROM pg_proc WHERE oid='public.lts_browser_card_cycles_v229()'::regprocedure) IS DISTINCT FROM before_acl THEN RAISE EXCEPTION 'ACL changed: lts_browser_card_cycles_v229'; END IF;
END $patch$;
