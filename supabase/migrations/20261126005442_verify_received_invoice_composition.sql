-- Mark an invoice breakdown as verified only when every received bank item is
-- accounted for, including the distinction between a purchase and repayment.
DO $migration$
DECLARE
 definition text := pg_get_functiondef('public.lts_browser_card_detail_v226(text,date)'::regprocedure);
 anchor text := ' RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,result);';
 patch text := $insert$
 IF result->>'invoice_amount' IS NOT NULL AND result->>'due_date' IS NOT NULL
    AND (result->>'difference')::numeric = 0 AND jsonb_array_length(result->'items') > 0
    AND NOT (result ? 'invoice_document') AND NOT (result ? 'invoice_composition_complete')
    AND result->>'complete' IS DISTINCT FROM 'false' AND result->>'detail_complete' IS DISTINCT FROM 'false'
    AND result->>'document_items_matched' IS DISTINCT FROM 'false' THEN
   WITH invoice AS MATERIALIZED (
     SELECT i.*, count(*) OVER () AS candidates
     FROM public.lts_open_finance_staging i
     WHERE i.user_id=u AND i.resource_type='invoice' AND i.provider_deleted_at IS NULL
       AND i.posting_date=(result->>'due_date')::date AND i.currency='BRL'
       AND public.lts_card_family_v226(i.normalized_payload->>'card_name',i.institution_name)=p_family
   ), received AS MATERIALIZED (
     SELECT s.id,s.signed_amount,s.normalized_payload->>'status' AS status
     FROM invoice i JOIN public.lts_open_finance_staging s
       ON s.user_id=i.user_id AND s.provider=i.provider AND s.institution_code=i.institution_code
        AND s.provider_account_ref=i.provider_account_ref AND s.resource_type='card_transaction'
        AND s.provider_deleted_at IS NULL AND s.currency=i.currency
        AND s.raw_payload#>>'{creditCardMetadata,billId}'=i.raw_payload->>'id'
     WHERE i.candidates=1 AND i.signed_amount=(result->>'invoice_amount')::numeric
       AND nullif(i.raw_payload->>'id','') IS NOT NULL
   ), classified AS MATERIALIZED (
     SELECT s.id,s.signed_amount,s.status,r.is_payment,r.source_id,r.amount
     FROM received s LEFT JOIN public.lts_card_source_rows_v226(u) r ON r.source_id=s.id AND r.family=p_family
   ), expected AS (
     SELECT id::text AS id,amount FROM classified WHERE NOT is_payment
   ), shown AS (
     SELECT i->>'source_id' AS id, (i->>'amount')::numeric AS amount FROM jsonb_array_elements(result->'items') i
   )
   SELECT EXISTS(SELECT 1 FROM expected)
     AND NOT EXISTS(SELECT 1 FROM classified WHERE status IS DISTINCT FROM 'POSTED'
                    OR source_id IS NULL OR is_payment IS NULL OR amount IS DISTINCT FROM -signed_amount)
     AND (SELECT count(*)=count(DISTINCT id) FROM classified)
     AND NOT EXISTS(SELECT * FROM expected EXCEPT ALL SELECT * FROM shown)
     AND NOT EXISTS(SELECT * FROM shown EXCEPT ALL SELECT * FROM expected)
     AND (SELECT sum(amount) FROM expected)=(result->>'invoice_amount')::numeric
   INTO matched;
   IF matched THEN
     result:=result||jsonb_build_object('invoice_composition_complete',true,'composition_basis','verified_received_bill_items');
   END IF;
 END IF;
$insert$;
BEGIN
 IF strpos(definition,'verified_received_bill_items') > 0 THEN RETURN; END IF;
 IF strpos(definition,anchor)=0 THEN RAISE EXCEPTION 'Unexpected invoice detail return'; END IF;
 EXECUTE replace(definition,anchor,patch||anchor);
END
$migration$;
