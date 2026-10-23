-- Opt-in evidence for an existing owner-confirmed partial obligation.
-- No amount-only, date-only, merchant-wide or automatically inferred person rule.
CREATE OR REPLACE FUNCTION public.lts_partial_obligation_settlement_valid_v302(
 p_event jsonb,p_source jsonb,p_binding jsonb,p_evidence jsonb
) RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $fn$
DECLARE b jsonb:=p_evidence->'before_financial_event'; d jsonb:=p_evidence->'schedule_document';
 payee text; scheduled_payee text;
BEGIN
 IF jsonb_typeof(b) IS DISTINCT FROM 'object' OR jsonb_typeof(d) IS DISTINCT FROM 'object'
 OR NOT coalesce(p_evidence ?& ARRAY['version','basis','bank_source_id','bank_raw_hash','provider_record_id',
 'provider_account_ref','institution_code','receiver_document_hash','receiver_name','partial_evidence_id',
 'schedule_document','before_financial_event'],false) THEN RETURN false;END IF;
 payee:=regexp_replace(translate(lower(p_source#>>'{raw_payload,paymentData,receiver,name}'),
 'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'),'[^a-z0-9]','','g');
 scheduled_payee:=regexp_replace(translate(lower(d->>'payee'),
 'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'),'[^a-z0-9]','','g');
 RETURN coalesce(
 p_evidence->>'version'='exact-partial-obligation-v302'
 AND p_evidence->>'basis'='owner_confirmed_partial_obligation_and_documented_bank_schedule'
 AND nullif(p_evidence->>'partial_evidence_id','') IS NOT NULL
 AND p_evidence->>'bank_raw_hash' ~ '^[0-9a-f]{64}$'
 AND p_event->>'user_id'=p_source->>'user_id' AND p_event->>'user_id'=p_binding->>'user_id'
 AND p_event->>'id'=p_binding->>'financial_event_id'
 AND p_source->>'id'=p_binding->>'staging_id' AND p_source->>'id'=p_evidence->>'bank_source_id'
 AND p_source->>'id'=p_event#>>'{metadata,bank_staging_id}'
 AND p_event#>>'{metadata,bank_reconciliation_evidence,bank_raw_hash}'=p_evidence->>'bank_raw_hash'
 AND p_source->>'provider_record_id'=p_evidence->>'provider_record_id'
 AND p_source->>'provider_account_ref'=p_evidence->>'provider_account_ref'
 AND nullif(p_evidence->>'provider_account_ref','') IS NOT NULL
 AND p_source->>'institution_code'=p_evidence->>'institution_code'
 AND p_binding->>'bank'=CASE p_source->>'institution_code' WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END
 AND p_event->>'source'='user_confirmed_partial_obligation'
 AND p_event->>'status'='confirmed' AND (p_event->>'is_projection')::boolean=false
 AND (p_event->>'is_suppressed')::boolean=false AND (p_event->>'is_internal_transfer')::boolean=false
 AND (b->>'is_projection')::boolean=true AND b->>'status'='scheduled'
 AND p_event-ARRAY['metadata','status','is_projection','created_at']=b-ARRAY['metadata','status','is_projection','created_at']
 AND p_event->>'created_at' ~ '(Z|[+-][0-9]{2}:[0-9]{2})$'
 AND b->>'created_at' ~ '(Z|[+-][0-9]{2}:[0-9]{2})$'
 AND (p_event->>'created_at')::timestamptz=(b->>'created_at')::timestamptz
 AND (p_event->'metadata')-ARRAY['bank_staging_id','bank_reconciliation_evidence','realized_partial_obligation_v302']=b->'metadata'
 AND p_event->>'event_date'=p_source->>'posting_date'
 AND p_event->>'event_date'=p_binding->>'expected_date'
 AND (p_event->>'amount')::numeric=(p_source->>'signed_amount')::numeric
 AND (p_event->>'amount')::numeric=(p_binding->>'expected_amount')::numeric
 AND (p_event->>'amount')::numeric<0
 AND p_source->>'resource_type'='transaction' AND p_source->>'currency'='BRL'
 AND p_source->>'provider_deleted_at' IS NULL
 AND p_source#>>'{normalized_payload,status}'='POSTED'
 AND p_source#>>'{normalized_payload,account_type}'='CHECKING_ACCOUNT'
 AND p_source#>>'{normalized_payload,date}'=p_source->>'posting_date'
 AND (p_source#>>'{normalized_payload,amount}')::numeric=(p_source->>'signed_amount')::numeric
 AND p_source#>>'{raw_payload,status}'='POSTED'
 AND p_source#>>'{raw_payload,type}'='DEBIT'
 AND abs((p_source#>>'{raw_payload,amount}')::numeric)=abs((p_source->>'signed_amount')::numeric)
 AND ((p_source#>>'{raw_payload,date}')::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date::text=p_source->>'posting_date'
 AND p_source#>>'{raw_payload,paymentData,paymentMethod}'='BOLETO'
 AND p_source#>>'{raw_payload,paymentData,receiver,documentNumber,type}'='CNPJ'
 AND nullif(p_source#>>'{raw_payload,paymentData,receiver,documentNumber,value}','') IS NOT NULL
 AND md5(p_source#>>'{raw_payload,paymentData,receiver,documentNumber,value}')=p_evidence->>'receiver_document_hash'
 AND p_source#>>'{raw_payload,paymentData,receiver,name}'=p_evidence->>'receiver_name'
 AND length(scheduled_payee)>=8
 AND regexp_replace(payee,'(ltda|sa)$','')=regexp_replace(scheduled_payee,'(ltda|sa)$','')
 AND d->>'date'=b->>'event_date' AND (d->>'amount')::numeric=abs((b->>'amount')::numeric)
 AND (b#>'{metadata,schedule_evidence_files}') ? (d->>'file_name')
 AND nullif(d->>'library_file_id','') IS NOT NULL
 AND (b#>>'{metadata,obligation_amount}')::numeric-(b#>>'{metadata,paid_amount}')::numeric=abs((b->>'amount')::numeric)
 AND (b#>>'{metadata,paid_amount}')::numeric>0
 AND nullif(b#>>'{metadata,paid_bank_staging_id}','') IS NOT NULL
 AND p_binding->>'category'=b->>'category'
 AND p_binding->>'beneficiary' IS NOT DISTINCT FROM b#>>'{metadata,beneficiary}'
 AND p_binding->>'property_code' IS NULL
 AND p_event#>'{metadata,realized_partial_obligation_v302}'=p_evidence-'before_financial_event'
 ,false);
EXCEPTION WHEN OTHERS THEN RETURN false;
END $fn$;
REVOKE ALL ON FUNCTION public.lts_partial_obligation_settlement_valid_v302(jsonb,jsonb,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_partial_obligation_settlement_valid_v302(jsonb,jsonb,jsonb,jsonb) TO service_role;

DO $patch$
DECLARE d text;old_clause text:=$old$AND f.metadata->>'contract_ref'=r.evidence->>'contract_ref'
AND s.description_raw LIKE '%'||(r.evidence->>'contract_ref')||'%'$old$;
BEGIN
 SELECT pg_get_functiondef('public.lts_realized_bank_sources_v238(uuid)'::regprocedure) INTO d;
 IF d LIKE '%lts_partial_obligation_settlement_valid_v302%' THEN RETURN;END IF;
 IF strpos(d,old_clause)=0 THEN RAISE EXCEPTION 'Realized-source contract changed';END IF;
 EXECUTE replace(d,old_clause,$new$AND ((f.metadata->>'contract_ref'=r.evidence->>'contract_ref'
AND s.description_raw LIKE '%'||(r.evidence->>'contract_ref')||'%')
OR public.lts_partial_obligation_settlement_valid_v302(to_jsonb(f),to_jsonb(s),to_jsonb(r),r.evidence))$new$);
END $patch$;

DO $classification$
DECLARE d text;anchor text:=$anchor$  UNION ALL
  SELECT r.category,r.center_cost,CASE$anchor$;
BEGIN
 SELECT pg_get_functiondef('public.lts_bank_known_classification_v231(uuid,uuid)'::regprocedure) INTO d;
 IF d LIKE '%owner_confirmed_partial_obligation_v302%' THEN RETURN;END IF;
 IF strpos(d,anchor)=0 THEN RAISE EXCEPTION 'Known-bank classification contract changed';END IF;
 EXECUTE replace(d,anchor,$new$  UNION ALL
  SELECT v.category,v.beneficiary,0,'owner_confirmed_partial_obligation_v302'
  FROM public.lts_realized_bank_event_v238 binding
  JOIN LATERAL public.lts_realized_bank_sources_v238(p_user_id) v
   ON v.financial_event_id=binding.financial_event_id AND v.staging_id=binding.staging_id
  WHERE binding.user_id=p_user_id AND binding.staging_id=p_staging_id
   AND binding.evidence->>'version'='exact-partial-obligation-v302'
   AND NOT EXISTS(SELECT 1 FROM public.lts_v178_review_decision explicit_decision
    WHERE explicit_decision.user_id=p_user_id AND explicit_decision.source_table='lts_open_finance_staging'
     AND explicit_decision.source_ref=p_staging_id::text AND explicit_decision.category_label IS NOT NULL)
  UNION ALL
  SELECT r.category,r.center_cost,CASE$new$);
END $classification$;

-- The source engines originally accept only forecast statuses. Keep this
-- particular proven paid event in the same original row instead of appending
-- an overlay that could disagree with relative/economic cash calculations.
DO $cash_ledger$
DECLARE d text;fn text;anchor text:=$anchor$fe.status in ('scheduled','expected','active','needs_reconciliation')$anchor$;
BEGIN
 FOREACH fn IN ARRAY ARRAY['public.lts_corrected_cashflow_v1(uuid,date,date)',
 'public.lts_corrected_cashflow_fix86_v1_engine_v247(uuid,date,date)'] LOOP
  SELECT pg_get_functiondef(fn::regprocedure) INTO d;
  IF d LIKE '%partial_paid_source_v302%' THEN CONTINUE;END IF;
  IF strpos(d,anchor)=0 THEN RAISE EXCEPTION 'Cash source status contract changed: %',fn;END IF;
  EXECUTE replace(d,anchor,$new$(fe.status in ('scheduled','expected','active','needs_reconciliation')
 OR (fe.status='confirmed' AND EXISTS(
  SELECT 1 FROM public.lts_realized_bank_event_v238 partial_paid_source_v302
  JOIN LATERAL public.lts_realized_bank_sources_v238(p_user_id) realized
   ON realized.financial_event_id=partial_paid_source_v302.financial_event_id
   AND realized.staging_id=partial_paid_source_v302.staging_id
  WHERE partial_paid_source_v302.user_id=p_user_id
   AND partial_paid_source_v302.financial_event_id=fe.id
   AND partial_paid_source_v302.evidence->>'version'='exact-partial-obligation-v302'
  )))$new$);
 END LOOP;
END $cash_ledger$;
