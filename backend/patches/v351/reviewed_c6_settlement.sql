-- Preserve issuer OTHER_PAYMENT and require exact reviewed C6 cycle/bank evidence.
CREATE OR REPLACE FUNCTION public.lts_card_item_is_invoice_payment_v351(p_item jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
SELECT coalesce(p_item#>>'{raw_payload,operationType}'='PAGAMENTO_FATURA'
 OR p_item#>>'{raw_payload,category}'='Credit card payment'
 OR lower(translate(coalesce(p_item#>>'{raw_payload,description}',p_item->>'description_raw',''),'áàâãéêíóôõúç','aaaaeeiooouc'))
 ~ '^(inclusao de pagamento ciclo corrente|pagamento recebido|pagto fatura)',false)
$fn$;
CREATE OR REPLACE FUNCTION public.lts_card_cycle_settlement_v351(p_contract jsonb, p_link jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE x jsonb; selected jsonb; close_day date; bank_day date; item_day date; amount numeric; n integer:=0;
BEGIN
 IF p_contract->>'issuer_settlement_policy' IS DISTINCT FROM 'one_c6_other_payment_in_cycle_v351'
 OR jsonb_typeof(p_contract->'issuer_payments') IS DISTINCT FROM 'array'
 OR jsonb_typeof(p_contract->'settlement_manifest') IS DISTINCT FROM 'array'
 THEN RETURN NULL; END IF;
 IF p_link->>'institution_code'IS DISTINCT FROM '336'
 OR p_contract#>>'{reviewed_other_payment,basis}'IS DISTINCT FROM 'one_c6_cycle_and_exact_posted_bank_debit'
 OR p_contract#>>'{reviewed_other_payment,invoice_id}'IS DISTINCT FROM p_link->>'invoice_source_id'
 OR p_contract#>>'{reviewed_other_payment,payment_id}'IS DISTINCT FROM p_link->>'payment_source_id'
 OR p_contract#>>'{reviewed_other_payment,bank_description}'IS DISTINCT FROM 'PGTO FAT CARTAO C6'
 OR jsonb_array_length(p_contract->'settlement_manifest')<>1
 OR coalesce(p_link->>'expected_closing_date','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 OR coalesce(p_link->>'expected_payment_date','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 THEN RETURN NULL; END IF;
 close_day:=(p_link->>'expected_closing_date')::date;
 bank_day:=(p_link->>'expected_payment_date')::date;
 amount:=(p_link->>'expected_amount')::numeric;
 IF bank_day<=close_day OR amount IS NULL OR amount<=0 THEN RETURN NULL; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_contract->'issuer_payments') a
  WHERE jsonb_typeof(a) IS DISTINCT FROM 'object' OR nullif(a->>'id','') IS NULL)
 OR (SELECT count(DISTINCT a->>'id')<>count(*) FROM jsonb_array_elements(p_contract->'issuer_payments') a)
 THEN RETURN NULL; END IF;
 FOR x IN SELECT value FROM jsonb_array_elements(p_contract->'issuer_payments') LOOP
  IF coalesce(x->>'paymentDate','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?Z$'
  THEN RETURN NULL; END IF;
  PERFORM (x->>'paymentDate')::timestamptz;
  -- Issuer dates are civil dates, not timestamps to move into the bank timezone.
  item_day:=left(x->>'paymentDate',10)::date;
  IF item_day>close_day AND item_day<=bank_day THEN
   IF NOT coalesce(x->>'valueType'='OTHER_PAYMENT' AND x->>'paymentMode'='DEBIT_ACCOUNT'
    AND x->>'currencyCode'='BRL' AND jsonb_typeof(x->'amount')='number'
    AND (x->>'amount')::numeric=amount,false) THEN RETURN NULL; END IF;
   n:=n+1; selected:=x;
  END IF;
 END LOOP;
 IF n<>1 OR selected IS DISTINCT FROM p_contract->'settlement_manifest'->0
 OR selected->>'id'IS DISTINCT FROM p_contract#>>'{reviewed_other_payment,issuer_payment_id}'
 OR left(selected->>'paymentDate',10)IS DISTINCT FROM p_link->>'expected_due_date'
 OR p_link->>'expected_payment_date'IS DISTINCT FROM p_link->>'expected_due_date' THEN RETURN NULL; END IF;
 RETURN selected;
EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow
 OR numeric_value_out_of_range THEN RETURN NULL;
END $function$

;
REVOKE ALL ON FUNCTION public.lts_card_item_is_invoice_payment_v351(jsonb),public.lts_card_cycle_settlement_v351(jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_item_is_invoice_payment_v351(jsonb),public.lts_card_cycle_settlement_v351(jsonb,jsonb) TO service_role;
DO $patch$
DECLARE sp jsonb;e jsonb;target regprocedure;d text;next_d text;prior text;attrs jsonb;
BEGIN FOR sp IN SELECT s FROM jsonb_array_elements($specs$[{"target": "public.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)", "lease": "17be6c95beca64b23254e784cd1bd706", "edits": [{"old": " ELSE\n  IF jsonb_array_length(p_contract->'issuer_payments')<>1", "new": " ELSIF p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351' THEN\n  pay:=public.lts_card_cycle_settlement_v351(p_contract,p_link);\n  IF pay IS NULL OR p_payment->>'description_raw'IS DISTINCT FROM p_contract#>>'{reviewed_other_payment,bank_description}'THEN RETURN NULL;END IF;\n ELSE\n  IF jsonb_array_length(p_contract->'issuer_payments')<>1"}, {"old": "AND pay->>'valueType'='FULL_PAYMENT' AND pay->>'paymentMode'='DEBIT_ACCOUNT'", "new": "AND pay->>'valueType'=CASE WHEN p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351' THEN 'OTHER_PAYMENT' ELSE 'FULL_PAYMENT' END AND pay->>'paymentMode'='DEBIT_ACCOUNT'"}, {"old": "'basis','reviewed_original_link_and_exact_issuer_refresh'", "new": "'basis',CASE WHEN p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351' THEN 'reviewed_c6_other_payment_and_exact_posted_debit_v351' ELSE 'reviewed_original_link_and_exact_issuer_refresh' END"}, {"old": "'issuer_payment_type','FULL_PAYMENT'", "new": "'issuer_payment_type',pay->>'valueType'"}]}, {"target": "public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb)", "lease": "cb47e826b312258f5841216e8f0f7b18", "edits": [{"old": "SELECT coalesce(\n\n", "new": "SELECT coalesce(\n CASE WHEN p_contract->>'item_settlement_policy'='canonical_invoice_payment_flags_v351' THEN\n p_link->>'institution_code'='336' AND p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351' AND\n (SELECT jsonb_agg(m->>'id'ORDER BY m->>'id')FROM jsonb_array_elements(p_contract->'consumption_manifest')m)\n =(SELECT jsonb_agg(i->>'id'ORDER BY i->>'id')FROM jsonb_array_elements(p_items)i WHERE NOT public.lts_card_item_is_invoice_payment_v351(i))\n ELSE true END AND\n\n"}, {"old": "AND CASE WHEN p_contract->>'issuer_settlement_policy'='one_full_payment_in_cycle_v301'", "new": "AND CASE WHEN p_contract->>'issuer_settlement_policy'='one_c6_other_payment_in_cycle_v351' THEN public.lts_card_cycle_settlement_v351(p_contract,p_link)IS NOT NULL AND p_payment->>'description_raw'=p_contract#>>'{reviewed_other_payment,bank_description}'\n WHEN p_contract->>'issuer_settlement_policy'='one_full_payment_in_cycle_v301'"}, {"old": "FILTER(WHERE i#>>'{raw_payload,operationType}' IS DISTINCT FROM 'PAGAMENTO_FATURA')", "new": "FILTER(WHERE CASE WHEN p_contract->>'item_settlement_policy'='canonical_invoice_payment_flags_v351' THEN NOT public.lts_card_item_is_invoice_payment_v351(i) ELSE i#>>'{raw_payload,operationType}' IS DISTINCT FROM 'PAGAMENTO_FATURA'END)"}]}, {"target": "public.lts_card_settlement_overlay_v290(uuid,jsonb)", "lease": "ed5ca8008eb3866874dae0e1d4c55169", "edits": [{"old": "'settlement_basis','reviewed_issuer_full_payment_and_exact_posted_checking_debit'", "new": "'settlement_basis',CASE WHEN l.receipt->>'issuer_payment_type'='OTHER_PAYMENT' THEN 'reviewed_c6_other_payment_and_exact_posted_checking_debit' ELSE 'reviewed_issuer_full_payment_and_exact_posted_checking_debit'END"}]}, {"target": "public.lts_browser_card_flow_schedule_v1(date,date)", "lease": "5c07587acaaf5b1d45337878b0869e7a", "edits": [{"old": "  v_flow := case when p_from>=current_date and p_to+30<=current_date+1800\n    then public.lts_flow_future_read_slice_v9(v_uid,p_from,p_to)\n    else public.lts_daily_flow_fix86_v12(v_uid,p_from,p_to) end;", "new": "  v_flow := public.lts_browser_flow_v242(p_from,p_to);"}, {"old": "  from jsonb_array_elements(coalesce(v_flow->'events','[]'::jsonb)) x", "new": "  from (\n    SELECT e x FROM jsonb_array_elements(coalesce(v_flow#>'{flow,historical,events}','[]')||coalesce(v_flow#>'{flow,current_future,events}','[]'))e\n    UNION ALL\n    SELECT e||jsonb_build_object('v351_pending_projection',true) FROM jsonb_array_elements(coalesce(v_flow#>'{flow,observed_bank_movements,pending_projections}','[]'))e\n    WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(v_flow#>'{flow,historical,events}','[]')||coalesce(v_flow#>'{flow,current_future,events}','[]'))a WHERE a->>'source_ref'=e->>'source_ref'AND a->>'event_date'=e->>'event_date'AND a->>'account'=e->>'account')\n  ) events\n  LEFT JOIN LATERAL(\n    SELECT l.invoice_source_id,l.payment_source_id,l.expected_amount\n    FROM public.lts_card_documentary_payment_link_v272 l\n    JOIN public.lts_card_settlement_expense_contract_v273 c ON c.user_id=l.user_id AND c.payment_source_id=l.payment_source_id AND c.active\n    JOIN public.lts_open_finance_staging inv ON inv.user_id=l.user_id AND inv.id=l.invoice_source_id\n    JOIN public.lts_open_finance_staging pay ON pay.user_id=l.user_id AND pay.id=l.payment_source_id\n    WHERE l.user_id=v_uid AND l.active AND l.payment_source_id::text=coalesce(x->>'open_finance_id',x->>'source_ref')\n    AND public.lts_card_payment_refresh_annotation_v273(v_uid,to_jsonb(l),to_jsonb(inv),to_jsonb(pay),c.payload,current_date)IS NOT NULL\n  ) reviewed ON true"}, {"old": "'confidence',x->>'confidence'", "new": "'confidence',x->>'confidence',\n      'bank_confirmed',coalesce((x->>'bank_confirmed')::boolean,false),\n      'settlement_confirmed',reviewed.payment_source_id IS NOT NULL,\n      'invoice_source_id',reviewed.invoice_source_id,\n      'payment_source_id',reviewed.payment_source_id,\n      'payment_status',CASE WHEN reviewed.payment_source_id IS NOT NULL THEN 'paid'WHEN x->>'v351_pending_projection'='true'THEN 'pending'ELSE 'unconfirmed'END,\n      'excluded_from_cash',coalesce((x->>'excluded')::boolean,false)"}, {"old": "  where (x->>'signed_amount')::numeric<0", "new": "  where (x->>'signed_amount')::numeric<0\n    and(x->>'event_date')::date BETWEEN p_from AND p_to"}, {"old": "coalesce(x->>'category','') in", "new": "reviewed.payment_source_id IS NOT NULL or coalesce(x->>'category','') in"}, {"old": "'version','card-flow-schedule-v1'", "new": "'version','card-flow-schedule-v1-v351','cash_reader','lts_browser_flow_v242','pending_projection_visible',true"}]}]$specs$::jsonb)s LOOP
 target:=(sp->>'target')::regprocedure;
 SELECT pg_get_functiondef(oid),to_jsonb(p)-'prosrc'INTO d,attrs FROM pg_proc p WHERE oid=target;
 IF md5(d)<>sp->>'lease' THEN
  prior:=d;FOR e IN SELECT x FROM jsonb_array_elements(sp->'edits')x LOOP prior:=replace(prior,e->>'new',e->>'old');END LOOP;
  IF md5(prior)<>sp->>'lease'THEN RAISE EXCEPTION 'V351_SOURCE_LEASE_CHANGED: % / %',sp->>'target',md5(d);END IF;CONTINUE;
 END IF;
 next_d:=d;FOR e IN SELECT x FROM jsonb_array_elements(sp->'edits')x LOOP
 IF position(e->>'old'IN next_d)=0 THEN RAISE EXCEPTION 'V351_PATCH_SLOT_MISSING';END IF;
 next_d:=replace(next_d,e->>'old',e->>'new');END LOOP;
 EXECUTE next_d;
 IF attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid=target)THEN RAISE EXCEPTION 'V351_FUNCTION_ATTRIBUTES_CHANGED';END IF;
 END LOOP;END $patch$;
