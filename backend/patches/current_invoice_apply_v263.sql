DO $patch$ DECLARE d text; a aclitem[]; BEGIN
 SELECT pg_get_functiondef('public.lts_card_cycles_v226(uuid)'::regprocedure),proacl INTO d,a FROM pg_proc WHERE oid='public.lts_card_cycles_v226(uuid)'::regprocedure;
 IF md5(d)<>'6941430a8d0131a5955d707fbfb50568' THEN RAISE EXCEPTION 'V263 invoice definition lease changed'; END IF;
 IF strpos(d,$old$), card_rows as ($old$)=0 THEN RAISE EXCEPTION 'V263 invoice patch anchor missing'; END IF;
 d:=replace(d,$old$), card_rows as ($old$,$new$), received_bills AS MATERIALIZED (
 SELECT b.* FROM public.lts_current_received_card_bills_v263(p_user_id) b
 WHERE EXISTS(SELECT 1 FROM public.card_invoices i WHERE i.user_id=p_user_id
 AND i.status IN('open','projected') AND i.due_date=b.due_date AND i.reference_month=b.reference_month
 AND public.lts_card_family_v226(i.card_name,i.card_name)=b.family
 AND (CASE WHEN i.metadata->>'as_of' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 THEN (i.metadata->>'as_of')::date ELSE '-infinity'::date END)
 <=(b.source_updated_at AT TIME ZONE 'America/Sao_Paulo')::date)
), current_cycles AS (
 SELECT c.family,c.month,coalesce(b.due_date,c.due_date) due_date,
 coalesce(b.amount,c.amount) amount,CASE WHEN b.invoice_source_id IS NOT NULL
 THEN 'open_finance_invoice_v263' ELSE c.basis END basis,
 CASE WHEN b.invoice_source_id IS NOT NULL THEN t.n ELSE c.item_count END item_count,
 CASE WHEN b.invoice_source_id IS NOT NULL THEN t.unclassified ELSE c.unclassified END unclassified,
 CASE WHEN b.invoice_source_id IS NOT NULL THEN coalesce(t.items,'[]'::jsonb) ELSE c.items END items,
 coalesce(b.source_updated_at,c.observed_at) observed_at,
 c.documentary_amount,c.documentary_as_of,b.invoice_source_id,b.source_updated_at invoice_source_updated_at,
 b.received_at invoice_received_at,b.payment_status,b.reported_payment_amount,
 CASE WHEN b.invoice_source_id IS NOT NULL THEN b.amount-coalesce(t.amount,0) END invoice_composition_difference,
 CASE WHEN b.invoice_source_id IS NOT NULL THEN abs(b.amount-coalesce(t.amount,0))<0.005 END invoice_composition_complete
 FROM cycles0 c LEFT JOIN received_bills b ON b.family=c.family AND b.reference_month=c.month
 AND (c.due_date IS NULL OR c.due_date=b.due_date)
 LEFT JOIN public.lts_open_finance_staging sb ON sb.id=b.invoice_source_id AND sb.user_id=p_user_id
 LEFT JOIN LATERAL (
 SELECT count(*) n,coalesce(sum(br.amount),0) amount,
 count(*) FILTER(WHERE br.category_basis='unresolved') unclassified,
 jsonb_agg(to_jsonb(br)-'bank'-'family'-'card_name'-'billing_last4'-'bill_id'
 ORDER BY br.posting_date DESC,br.description,br.source_id) items
 FROM rows br WHERE br.family=b.family AND br.reference_month=b.reference_month
 AND br.bill_id=sb.normalized_payload->>'provider_id' AND NOT br.is_payment
 AND br.provider_status IN('POSTED','PENDING','DOCUMENTED')
 AND EXISTS(SELECT 1 FROM public.lts_open_finance_staging tx
 WHERE tx.user_id=p_user_id AND tx.id=br.source_id AND tx.currency='BRL')
 )t ON true
), card_rows as ($new$);
 IF strpos(d,$old$from cycles0 c where c.family=a.family$old$)=0 THEN RAISE EXCEPTION 'V263 invoice patch anchor missing'; END IF;
 d:=replace(d,$old$from cycles0 c where c.family=a.family$old$,$new$from current_cycles c where c.family=a.family$new$);
 EXECUTE d; IF (SELECT proacl FROM pg_proc WHERE oid='public.lts_card_cycles_v226(uuid)'::regprocedure) IS DISTINCT FROM a THEN RAISE EXCEPTION 'V263 invoice ACL changed'; END IF;
 END $patch$;
DO $patch$ DECLARE d text; a aclitem[]; BEGIN
 SELECT pg_get_functiondef('public.lts_card_invoice_amounts_v230_engine_v243(uuid)'::regprocedure),proacl INTO d,a FROM pg_proc WHERE oid='public.lts_card_invoice_amounts_v230_engine_v243(uuid)'::regprocedure;
 IF md5(d)<>'8901a75bc8375fcfdd3c794c5052c2a6' THEN RAISE EXCEPTION 'V263 invoice definition lease changed'; END IF;
 IF strpos(d,$old$AS $function$
WITH documented_families AS MATERIALIZED ($old$)=0 THEN RAISE EXCEPTION 'V263 invoice patch anchor missing'; END IF;
 d:=replace(d,$old$AS $function$
WITH documented_families AS MATERIALIZED ($old$,$new$AS $function$
WITH baseline AS MATERIALIZED (
WITH documented_families AS MATERIALIZED ($new$);
 IF strpos(d,$old$
$function$
$old$)=0 THEN RAISE EXCEPTION 'V263 invoice patch anchor missing'; END IF;
 d:=replace(d,$old$
$function$
$old$,$new$
), received_bills AS MATERIALIZED (
 SELECT b.* FROM public.lts_current_received_card_bills_v263(p_user_id) b
 WHERE EXISTS(SELECT 1 FROM public.card_invoices i WHERE i.user_id=p_user_id
 AND i.status IN('open','projected') AND i.due_date=b.due_date AND i.reference_month=b.reference_month
 AND public.lts_card_family_v226(i.card_name,i.card_name)=b.family
 AND (CASE WHEN i.metadata->>'as_of' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 THEN (i.metadata->>'as_of')::date ELSE '-infinity'::date END)
 <=(b.source_updated_at AT TIME ZONE 'America/Sao_Paulo')::date)
)
SELECT r.user_id,r.card_name,r.reference_month,r.due_date,
 CASE WHEN b.payment_status='paid' AND r.status IN('open','projected') THEN 'paid' ELSE r.status END status,
 CASE WHEN b.invoice_source_id IS NOT NULL AND r.status IN('open','projected') THEN b.amount ELSE r.amount END amount,
 CASE WHEN b.invoice_source_id IS NOT NULL AND r.status IN('open','projected') THEN 'open_finance_invoice_v263' ELSE r.source END source
FROM baseline r LEFT JOIN received_bills b ON r.reference_month=b.reference_month AND r.due_date=b.due_date
AND public.lts_card_family_v226(r.card_name,r.card_name)=b.family
$function$
$new$);
 EXECUTE d; IF (SELECT proacl FROM pg_proc WHERE oid='public.lts_card_invoice_amounts_v230_engine_v243(uuid)'::regprocedure) IS DISTINCT FROM a THEN RAISE EXCEPTION 'V263 invoice ACL changed'; END IF;
 END $patch$;
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;

