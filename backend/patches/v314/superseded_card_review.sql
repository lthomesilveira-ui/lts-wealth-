-- An explicitly archived snapshot cannot reopen classifications resolved in its full received bill.
CREATE OR REPLACE FUNCTION public.lts_card_review_superseded_snapshots_v314(p_user_id uuid)
RETURNS TABLE(legacy_invoice_id text) LANGUAGE sql STABLE SET search_path='' AS $function$
WITH closed AS MATERIALIZED(
 SELECT * FROM public.card_invoices WHERE user_id=p_user_id AND status IN('closed','paid')
 AND jsonb_typeof(metadata->'items')='array'
),received AS MATERIALIZED(
 SELECT r.family,r.reference_month,r.due_date,s.institution_code,s.provider_account_ref,r.bill_id,
 count(*) item_count,sum(r.amount) amount,
 count(*) FILTER(WHERE r.amount>0 AND(r.category_basis='unresolved' OR public.lts_v178_norm(coalesce(r.category,'')) IN('','a classificar','nao identificado','sem categoria','—'))) pending
 FROM public.lts_card_source_rows_v226(p_user_id)r
 JOIN public.lts_open_finance_staging s ON s.user_id=p_user_id AND s.id=r.source_id
 AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL AND s.currency='BRL'
 WHERE NOT r.is_payment
 GROUP BY r.family,r.reference_month,r.due_date,s.institution_code,s.provider_account_ref,r.bill_id
)
SELECT DISTINCT c.metadata->>'legacy_detail_snapshot_id'
FROM closed c JOIN received r ON r.family=public.lts_card_family_v1(c.card_name,
 CASE r.institution_code WHEN '237' THEN 'Bradesco' WHEN '341' THEN 'Itaú' WHEN '336' THEN 'C6' END)
 AND r.reference_month=c.reference_month AND r.due_date=c.due_date AND r.amount=c.amount AND r.pending=0
WHERE c.user_id=p_user_id AND c.status IN('closed','paid') AND c.amount>0
 AND c.metadata->>'legacy_detail_snapshot_is_current'='false'
 AND nullif(c.metadata->>'legacy_detail_snapshot_id','') IS NOT NULL
 AND c.metadata->>'document_amount_verified'='true' AND c.metadata->>'detail_reconciled_to_cycle_total'='true'
 AND jsonb_typeof(c.metadata->'items')='array' AND jsonb_array_length(c.metadata->'items')=r.item_count
 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c.metadata->'items')x WHERE jsonb_typeof(x->'amount') IS DISTINCT FROM 'number')
 AND (SELECT sum(CASE WHEN jsonb_typeof(x->'amount')='number' THEN(x->>'amount')::numeric END) FROM jsonb_array_elements(c.metadata->'items')x)=c.amount
 AND (SELECT count(*) FROM public.lts_open_finance_staging b WHERE b.user_id=p_user_id
 AND b.resource_type='invoice' AND b.provider_deleted_at IS NULL AND b.currency='BRL'
 AND b.institution_code=r.institution_code AND b.provider_account_ref=r.provider_account_ref
 AND b.normalized_payload->>'provider_id'=r.bill_id AND b.posting_date=c.due_date AND b.signed_amount=c.amount)=1
$function$;
REVOKE ALL ON FUNCTION public.lts_card_review_superseded_snapshots_v314(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_review_superseded_snapshots_v314(uuid) TO service_role;

DO $patch$
DECLARE target oid:='public.lts_card_classification_current_overlay_v1(uuid,jsonb,integer)'::regprocedure;
 definition text;replacement text;before_attributes jsonb;
BEGIN
 SELECT pg_get_functiondef(target),to_jsonb(p)-'prosrc' INTO definition,before_attributes FROM pg_proc p WHERE p.oid=target;
 IF md5(definition)='5a5f373074b2a9c1427a7e8b29536214' THEN RETURN;END IF;
 IF md5(definition)<>'743ae1ea19766a285dbfde10f08dc1d1' THEN RAISE EXCEPTION 'Card classification overlay changed';END IF;
 replacement:=replace(definition,'source_ok boolean:=true;','source_ok boolean:=true; superseded text[];');
 replacement:=replace(replacement,E'begin\n for c',
 $text$begin
 select coalesce(array_agg(legacy_invoice_id),ARRAY[]::text[]) into superseded from public.lts_card_review_superseded_snapshots_v314(p_user_id);
 select coalesce(jsonb_agg(v),'[]') into items from jsonb_array_elements(items)v where not coalesce(v->>'invoice_id'=ANY(superseded),false);
 select coalesce(jsonb_agg(v),'[]') into invoices from jsonb_array_elements(invoices)v where not coalesce(v->>'invoice_id'=ANY(superseded),false);
 for c$text$);
 IF md5(replacement)<>'5a5f373074b2a9c1427a7e8b29536214' THEN RAISE EXCEPTION 'Unexpected card review transformation';END IF;
 EXECUTE replacement;
 IF (SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target) IS DISTINCT FROM before_attributes
 OR md5(pg_get_functiondef(target))<>'5a5f373074b2a9c1427a7e8b29536214' THEN RAISE EXCEPTION 'Card review metadata changed';END IF;
END $patch$;
