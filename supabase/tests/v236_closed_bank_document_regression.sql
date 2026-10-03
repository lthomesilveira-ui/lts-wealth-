-- Read-only contracts for closed bank documents. Run with the authorized
-- maintenance JWT in a transaction, then ROLLBACK. No private data is embedded.
DO $test$
DECLARE
 u uuid:=public.lts_browser_assert_user_v1(); v record; detail jsonb; dash jsonb;
 reader_rows jsonb; expected integer; family_name text; updates jsonb;
BEGIN
 SELECT coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) INTO reader_rows
 FROM public.lts_card_source_rows_v226(u) r;
 updates:=public.lts_updates_current_sources_v240(u);
 FOR v IN
  SELECT ci.*,sd.metadata document_metadata FROM public.card_invoices ci
  JOIN public.source_documents sd ON sd.id::text=ci.metadata->>'bank_statement_document_id' AND sd.user_id=ci.user_id
  WHERE ci.user_id=u AND ci.status='closed'
   AND ci.metadata->>'bank_statement_closed'='true'
   AND ci.metadata->>'bank_statement_full_composition'='true'
   AND sd.document_type='credit_card_statement' AND sd.processing_status='processed'
   AND sd.sha256=ci.metadata->>'bank_statement_sha256'
   AND sd.metadata->>'all_source_lines_matched'='true'
 LOOP
  family_name:=public.lts_card_family_v226(v.card_name,CASE WHEN v.card_name~*'c6' THEN 'C6' WHEN v.card_name~*'aeternum|bradesco|prime' THEN 'Bradesco' ELSE 'Itaú' END);
  IF EXISTS(
   SELECT 1 FROM jsonb_array_elements(v.document_metadata->'existing_source_items') e
   WHERE (SELECT count(*) FROM jsonb_array_elements(reader_rows) r
    WHERE r->>'source_id'=e->>'source_id'
     AND (r->>'reference_month')::date=v.reference_month AND (r->>'due_date')::date=v.due_date
     AND (r->>'amount')::numeric=(e->>'amount')::numeric)<>1
  ) THEN RAISE EXCEPTION 'closed document lost or duplicated a provider source identity'; END IF;
  detail:=public.lts_browser_card_detail_v226(family_name,v.reference_month);
  IF (detail->>'invoice_amount')::numeric<>v.amount OR (detail->>'amount')::numeric<>v.amount
   OR (detail->>'difference')::numeric<>0 OR detail->>'document_items_matched'<>'true'
   OR (detail->>'item_count')::int<>(v.document_metadata->>'nonpayment_detail_lines')::int
  THEN RAISE EXCEPTION 'closed bank document does not reconcile in browser detail'; END IF;
  IF v.reference_month=date_trunc('month',current_date)::date AND EXISTS(
   SELECT 1 FROM jsonb_array_elements(updates->'items') x
   WHERE x->>'maintenance_kind'='card_statement'
    AND public.lts_v178_norm(x->>'title')=public.lts_v178_norm('Fatura '||v.card_name)
  ) THEN RAISE EXCEPTION 'verified current-cycle document still requested'; END IF;
 END LOOP;
 dash:=public.lts_browser_dashboard_cockpit_v1();
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(dash->'horizons') h
  WHERE h->>'id'='90d' AND (h->>'date')::date=current_date+90)
 THEN RAISE EXCEPTION 'dashboard dropped the ninety-day horizon'; END IF;
 IF has_function_privilege('anon','public.lts_browser_card_detail_v226(text,date)','EXECUTE')
 THEN RAISE EXCEPTION 'card browser detail exposed anonymously'; END IF;
END $test$;
SELECT jsonb_build_object('pass',true,'check','Closed source identities, bank totals, document notices, 90-day horizon and anonymous access') result;
