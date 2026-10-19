-- Virtual future invoices carry known purchase composition, not a recorded bill.
CREATE TEMP TABLE virtual_invoice_spend_baseline_v290 ON COMMIT DROP AS
SELECT c.user_id,count(*) rows,sum(e.amount) amount,md5(jsonb_agg(to_jsonb(e) ORDER BY to_jsonb(e)::text)::text) digest
FROM public.lts_product_read_cache c CROSS JOIN LATERAL public.lts_v229_expense_rows(c.user_id,date '2013-10-10',current_date)e GROUP BY c.user_id;
CREATE OR REPLACE FUNCTION public.lts_card_projected_invoice_records_v290(p_user_id uuid)
RETURNS SETOF public.card_invoices LANGUAGE sql STABLE SET search_path='' AS $f$
WITH source_rows AS MATERIALIZED(SELECT * FROM public.lts_card_source_rows_v226(p_user_id))
SELECT r.* FROM public.lts_card_projection_rows_v290(p_user_id)p
CROSS JOIN LATERAL jsonb_populate_record(NULL::public.card_invoices,jsonb_build_object(
 'id',NULL,'user_id',p.user_id,'card_name',p.card_name,'reference_month',p.reference_month,
 'due_date',p.due_date,'status','projected','amount',p.amount,'source',p.source,
 'metadata',jsonb_build_object('projection_only',true,'official_invoice_received',false,
 'items',coalesce((SELECT jsonb_agg(to_jsonb(s)||jsonb_build_object('source_line',s.source_id,'card_final',s.last4) ORDER BY s.posting_date,s.source_id)
 FROM source_rows s WHERE s.family=public.lts_card_family_v226(p.card_name,p.card_name) AND s.reference_month=p.reference_month
 AND s.provider_status IN('PENDING','DOCUMENTED') AND NOT s.is_payment),'[]'))))r
WHERE NOT EXISTS(SELECT 1 FROM public.card_invoices i WHERE i.user_id=p.user_id AND i.reference_month=p.reference_month
 AND public.lts_card_family_v226(i.card_name,i.card_name)=public.lts_card_family_v226(p.card_name,p.card_name))
$f$;
REVOKE ALL ON FUNCTION public.lts_card_projected_invoice_records_v290(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_projected_invoice_records_v290(uuid) TO service_role;
DO $effective$ DECLARE d text; BEGIN
 SELECT pg_get_functiondef('public.lts_card_invoices_effective_v226(uuid)'::regprocedure) INTO d;
 IF position('lts_card_projected_invoice_records_v290' IN d)>0 THEN RAISE EXCEPTION 'Virtual invoice source already installed'; END IF;
 d:=replace(d,E'\n$function$',E'\nUNION ALL SELECT * FROM public.lts_card_projected_invoice_records_v290(p_user_id)\n$function$');
 EXECUTE d;
END $effective$;
DO $parity$ DECLARE b record; n bigint; v numeric; h text;
BEGIN FOR b IN SELECT * FROM virtual_invoice_spend_baseline_v290 LOOP
 SELECT count(*),sum(e.amount),md5(jsonb_agg(to_jsonb(e) ORDER BY to_jsonb(e)::text)::text) INTO n,v,h
 FROM public.lts_v229_expense_rows(b.user_id,date '2013-10-10',current_date)e;
 IF n IS DISTINCT FROM b.rows OR v IS DISTINCT FROM b.amount OR h IS DISTINCT FROM b.digest
 THEN RAISE EXCEPTION 'Virtual future invoices altered realized consumption'; END IF;
 END LOOP;
END $parity$;
