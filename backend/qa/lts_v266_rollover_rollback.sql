BEGIN;
SET LOCAL statement_timeout='55s';
SET LOCAL jit=off;
SET LOCAL TimeZone='America/Sao_Paulo';
DO $probe$
DECLARE
 u uuid:=public.lts_open_finance_pilot_owner_v1();
 i public.card_invoices%rowtype;
 bill record; cycles jsonb; audit jsonb; c jsonb;
 financial_before text; financial_after text; manual_before text; manual_after text;
 source_before text; source_after text; engine_before jsonb; engine_after jsonb;
 tests integer:=0; amount_now numeric;
BEGIN
 SELECT ci.* INTO STRICT i
 FROM public.card_invoices ci
 JOIN public.lts_current_received_card_bills_v263(u) b
 ON b.family=public.lts_card_family_v226(ci.card_name,ci.card_name)
 AND b.reference_month=ci.reference_month AND b.due_date=ci.due_date
 WHERE ci.user_id=u AND ci.status IN('open','projected') AND ci.due_date<current_date
 AND ci.amount IS DISTINCT FROM b.amount ORDER BY ci.due_date DESC LIMIT 1;
 SELECT * INTO STRICT bill FROM public.lts_current_received_card_bills_v263(u) b
 WHERE b.family=public.lts_card_family_v226(i.card_name,i.card_name)
 AND b.reference_month=i.reference_month AND b.due_date=i.due_date;

 SELECT md5(jsonb_agg(to_jsonb(f) ORDER BY f.id)::text) INTO financial_before FROM public.financial_events f WHERE user_id=u;
 SELECT md5(jsonb_agg(to_jsonb(f) ORDER BY f.id)::text) INTO manual_before FROM public.card_invoices f WHERE user_id=u;
 SELECT md5(to_jsonb(f)::text) INTO source_before FROM public.lts_open_finance_staging f WHERE id=bill.invoice_source_id;
 SELECT jsonb_agg(to_jsonb(f) ORDER BY f.card_name,f.reference_month,f.due_date) INTO engine_before FROM public.lts_card_invoice_amounts_v230_engine_v243(u) f;
 SELECT amount INTO STRICT amount_now FROM public.lts_card_invoice_amounts_v230_engine_v243(u) f
 WHERE f.card_name=i.card_name AND f.reference_month=i.reference_month AND f.due_date=i.due_date;
 IF amount_now IS DISTINCT FROM bill.amount THEN RAISE EXCEPTION 'latest received amount lost after due date'; END IF;
 tests:=tests+1;
 cycles:=public.lts_card_cycles_v226(u);
 SELECT x INTO STRICT c FROM jsonb_array_elements(cycles->'cards')a
 CROSS JOIN LATERAL jsonb_array_elements(a->'cycles')x WHERE x->>'invoice_source_id'=bill.invoice_source_id::text;
 IF (c->>'amount')::numeric IS DISTINCT FROM bill.amount OR c->>'payment_status' IS DISTINCT FROM bill.payment_status
 OR c->>'invoice_composition_complete'<>'true'
 OR abs((SELECT sum((z->>'amount')::numeric) FROM jsonb_array_elements(c->'items')z)-bill.amount)>=.005
 THEN RAISE EXCEPTION 'received composition/payment evidence not retained'; END IF;
 tests:=tests+1;

 BEGIN
  UPDATE public.card_invoices SET metadata=metadata||jsonb_build_object('as_of',((bill.source_updated_at AT TIME ZONE 'America/Sao_Paulo')::date+1)::text) WHERE id=i.id;
  SELECT amount INTO STRICT amount_now FROM public.lts_card_invoice_amounts_v230_engine_v243(u) f WHERE f.card_name=i.card_name AND f.reference_month=i.reference_month;
  IF amount_now IS DISTINCT FROM i.amount THEN RAISE EXCEPTION 'older bank bill overrode newer manual evidence';END IF;
  cycles:=public.lts_card_cycles_v226(u);
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(cycles->'cards')a CROSS JOIN LATERAL jsonb_array_elements(a->'cycles')x WHERE x->>'invoice_source_id'=bill.invoice_source_id::text)
  THEN RAISE EXCEPTION 'newer manual evidence lost in cycles';END IF;
  RAISE EXCEPTION USING ERRCODE='PZ001',MESSAGE='rollback successful probe';
 EXCEPTION WHEN SQLSTATE 'PZ001' THEN tests:=tests+1;
 END;

 BEGIN
  UPDATE public.card_invoices SET status='closed' WHERE id=i.id;
  SELECT amount INTO STRICT amount_now FROM public.lts_card_invoice_amounts_v230_engine_v243(u) f WHERE f.card_name=i.card_name AND f.reference_month=i.reference_month;
  IF amount_now IS DISTINCT FROM i.amount THEN RAISE EXCEPTION 'closed documentary cycle changed';END IF;
  cycles:=public.lts_card_cycles_v226(u);
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(cycles->'cards')a CROSS JOIN LATERAL jsonb_array_elements(a->'cycles')x WHERE x->>'invoice_source_id'=bill.invoice_source_id::text)
  THEN RAISE EXCEPTION 'closed cycle revived';END IF;
  RAISE EXCEPTION USING ERRCODE='PZ002',MESSAGE='rollback successful probe';
 EXCEPTION WHEN SQLSTATE 'PZ002' THEN tests:=tests+1;
 END;

 BEGIN
  UPDATE public.lts_open_finance_staging SET currency='USD' WHERE id=bill.invoice_source_id;
  SELECT amount INTO STRICT amount_now FROM public.lts_card_invoice_amounts_v230_engine_v243(u) f WHERE f.card_name=i.card_name AND f.reference_month=i.reference_month;
  IF amount_now IS DISTINCT FROM i.amount THEN RAISE EXCEPTION 'ineligible source accepted';END IF;
  RAISE EXCEPTION USING ERRCODE='PZ003',MESSAGE='rollback successful probe';
 EXCEPTION WHEN SQLSTATE 'PZ003' THEN tests:=tests+1;
 END;

 BEGIN
  UPDATE public.card_invoices SET reference_month=(reference_month-interval '1 month')::date WHERE id=i.id;
  IF EXISTS(SELECT 1 FROM public.lts_card_invoice_amounts_v230_engine_v243(u)f WHERE f.reference_month=i.reference_month AND f.card_name=i.card_name AND f.source='open_finance_invoice_v263')
  THEN RAISE EXCEPTION 'past unbound cycle was seeded';END IF;
  RAISE EXCEPTION USING ERRCODE='PZ004',MESSAGE='rollback successful probe';
 EXCEPTION WHEN SQLSTATE 'PZ004' THEN tests:=tests+1;
 END;

 SELECT md5(jsonb_agg(to_jsonb(f) ORDER BY f.id)::text) INTO financial_after FROM public.financial_events f WHERE user_id=u;
 SELECT md5(jsonb_agg(to_jsonb(f) ORDER BY f.id)::text) INTO manual_after FROM public.card_invoices f WHERE user_id=u;
 SELECT md5(to_jsonb(f)::text) INTO source_after FROM public.lts_open_finance_staging f WHERE id=bill.invoice_source_id;
 SELECT jsonb_agg(to_jsonb(f) ORDER BY f.card_name,f.reference_month,f.due_date) INTO engine_after FROM public.lts_card_invoice_amounts_v230_engine_v243(u) f;
 IF financial_before IS DISTINCT FROM financial_after OR manual_before IS DISTINCT FROM manual_after
 OR source_before IS DISTINCT FROM source_after OR engine_before IS DISTINCT FROM engine_after
 THEN RAISE EXCEPTION 'probe rollback/source preservation failed';END IF;
 tests:=tests+1;

 audit:=public.lts_recurring_future_gap_audit_v6(u,current_date,(date_trunc('year',current_date)+interval '6 years -1 day')::date);
 SELECT x INTO STRICT c FROM jsonb_array_elements(audit->'horizon_checks')x
 WHERE x->>'key'=public.lts_forecast_series_key_v1('Fatura '||i.card_name);
 IF NOT (c->'awaiting_payment_evidence_months' ? to_char(i.due_date,'YYYY-MM'))
 OR (c->'missing_months' ? to_char(i.due_date,'YYYY-MM'))
 OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c->'period_coverage')p
 WHERE p->>'status'='awaiting_payment_evidence'
 AND EXISTS(SELECT 1 FROM jsonb_array_elements(p->'unconfirmed_evidence')z WHERE (z->>'amount')::numeric=bill.amount))
 THEN RAISE EXCEPTION 'recorded obligation mislabeled as missing projection';END IF;
 tests:=tests+1;

 IF NOT(public.lts_validated_lock_gate_v1()->>'pass')::boolean
 OR NOT(SELECT relrowsecurity FROM pg_class WHERE oid='public.lts_validated_lock_registry'::regclass)
 OR has_table_privilege('anon','public.lts_validated_lock_registry','SELECT')
 OR has_table_privilege('authenticated','public.lts_validated_lock_registry','SELECT')
 OR NOT has_table_privilege('service_role','public.lts_validated_lock_registry','SELECT')
 THEN RAISE EXCEPTION 'internal lock protection/readers failed';END IF;
 tests:=tests+1;
 PERFORM set_config('lts.v266_probe',jsonb_build_object('pass',true,'checks',tests,
 'scope','received invoice rollover, evidence precedence, wrong currency, wrong cycle, recurring proof, lock access',
 'financial_events_unchanged',true,'manual_invoices_unchanged',true,'bank_source_unchanged',true,
 'all_negative_mutations_rolled_back',true,'canonical_invoice_reader_unchanged_by_probes',true)::text,true);
END;
$probe$;
SELECT current_setting('lts.v266_probe')::jsonb receipt;
ROLLBACK;
