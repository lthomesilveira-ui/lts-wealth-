-- Run under an authorized connection with the owner's request.jwt.claims set.
-- Confirmation is exercised transactionally; all test decisions are rolled back.
BEGIN;
SET LOCAL timezone='America/Sao_Paulo';
SET LOCAL statement_timeout='60s';
DO $$ DECLARE u uuid:=public.lts_browser_assert_user_v1(); f jsonb; ds jsonb; es jsonb;
 d jsonb; c jsonb; e jsonb; b text; previous jsonb; actual numeric; k jsonb;
 BEGIN
 f:=public.lts_browser_flow_v229(current_date-10,current_date+10)->'flow';
 ds:=(f#>'{historical,days}')||(f#>'{current_future,days}');
 es:=(f#>'{historical,events}')||(f#>'{current_future,events}');
 IF EXISTS(SELECT 1 FROM jsonb_each_text(f#>'{observed_bank_movements,documentary_gaps}') g WHERE abs(g.value::numeric)>.005)
 THEN RAISE EXCEPTION 'An observed bank position is not explained by posted movements'; END IF;
 FOR d IN SELECT x FROM jsonb_array_elements(ds) x ORDER BY x->>'date' LOOP
  c:=d->'fix86_columns';
  IF abs((c->>'saldo_final')::numeric-(c->>'saldo_anterior')::numeric-(c->>'entradas')::numeric+(c->>'saidas')::numeric)>.005
  OR abs((c->>'saldo_apos_rsu')::numeric-(c->>'saldo_apos_d0_1')::numeric-(c->>'rsus_vested')::numeric)>.005
  THEN RAISE EXCEPTION 'Daily arithmetic mismatch on %',d->>'date'; END IF;
  IF previous IS NOT NULL AND abs((c->>'saldo_anterior')::numeric-(previous#>>'{fix86_columns,saldo_final}')::numeric)>.005
  THEN RAISE EXCEPTION 'Consolidated opening continuity mismatch on %',d->>'date'; END IF;
  FOREACH b IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
   IF d#>>ARRAY[b,'balance_basis']='observed_bank_position_and_recent_movements' THEN
    SELECT coalesce(sum((x->>'signed_amount')::numeric),0) INTO actual FROM jsonb_array_elements(es) x
    WHERE x->>'event_date'=d->>'date' AND x->>'account'=b AND x->>'source'<>'economic_withholding';
    IF abs(actual-(d#>>ARRAY[b,'net'])::numeric)>.005
    OR abs((d#>>ARRAY[b,'balance'])::numeric-(d#>>ARRAY[b,'opening_balance'])::numeric-actual)>.005
    OR (previous IS NOT NULL AND abs((d#>>ARRAY[b,'opening_balance'])::numeric-(previous#>>ARRAY[b,'balance'])::numeric)>.005)
    THEN RAISE EXCEPTION 'Bank detail or opening mismatch on % for %',d->>'date',b; END IF;
   END IF;
  END LOOP;
  previous:=d;
 END LOOP;
 FOR k IN SELECT to_jsonb(m) FROM public.lts_payroll_bank_matches_v231(u) m LOOP
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(es) x WHERE x->>'source_ref'=k->>'projection_ref')
  OR (SELECT count(*) FROM jsonb_array_elements(es) x WHERE x->>'open_finance_id'=k->>'staging_id')<>1
  THEN RAISE EXCEPTION 'Actual payroll does not replace exactly one prediction'; END IF;
 END LOOP;
 PERFORM set_config('lts.v231.qa.flow',f::text,true);
END $$;

DO $$ DECLARE u uuid:=public.lts_browser_assert_user_v1(); q jsonb; started timestamptz:=clock_timestamp();
 pending_count int; chosen record; baseline text; after_hash text; result jsonb;
 BEGIN
 q:=public.lts_browser_expense_review_queue_v229(date '2013-10-10',current_date,0,25,null);
 SELECT count(*) INTO pending_count FROM public.lts_v229_review_rows(u,date '2013-10-10',current_date) WHERE identity_status='pending';
 IF (q->>'row_count')::int<>pending_count THEN RAISE EXCEPTION 'Queue does not cover pending data'; END IF;
 IF q->'pending_projections' IS DISTINCT FROM current_setting('lts.v231.qa.flow')::jsonb#>'{observed_bank_movements,pending_projections}'
 THEN RAISE EXCEPTION 'Unrealized forecasts are hidden from Updates'; END IF;
 PERFORM set_config('lts.v231.qa.review_ms',(1000*extract(epoch FROM clock_timestamp()-started))::text,true);
 PERFORM set_config('lts.v231.qa.queue_breakdown',(q->'queue_breakdown')::text,true);
 WITH keys AS MATERIALIZED(SELECT s.id,public.lts_card_installment_key_v231(s) purchase_key
 FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL),
 shared AS MATERIALIZED(SELECT purchase_key FROM keys WHERE purchase_key IS NOT NULL GROUP BY purchase_key HAVING count(*)>1)
 SELECT s.id,k.purchase_key INTO chosen
 FROM public.lts_v229_review_rows(u,date '2013-10-10',current_date) r JOIN public.lts_open_finance_staging s
 ON s.user_id=u AND r.source_table='lts_open_finance_staging' AND r.source_ref=s.id::text
 JOIN keys k ON k.id=s.id JOIN shared ON shared.purchase_key=k.purchase_key
 WHERE r.identity_status='pending' LIMIT 1;
 IF chosen.id IS NULL THEN RAISE EXCEPTION 'No real installment case available to validate learning'; END IF;
 SELECT md5(string_agg(c.source_id::text||c.category,'|' ORDER BY c.source_id)) INTO baseline
 FROM public.lts_card_source_rows_v226(u) c JOIN public.lts_open_finance_staging s ON s.id=c.source_id
 WHERE public.lts_card_installment_key_v231(s) IS DISTINCT FROM chosen.purchase_key;
 result:=public.lts_browser_expense_review_decision_v229('lts_open_finance_staging',chosen.id::text,null,null,'Mercado');
 IF result->>'resolved'<>'true' THEN RAISE EXCEPTION 'Confirmation did not persist'; END IF;
 IF EXISTS(SELECT 1 FROM public.lts_card_source_rows_v226(u) c JOIN public.lts_open_finance_staging s ON s.id=c.source_id
 WHERE public.lts_card_installment_key_v231(s)=chosen.purchase_key AND c.category<>'Mercado')
 THEN RAISE EXCEPTION 'A same-purchase installment did not inherit its confirmed category'; END IF;
 SELECT md5(string_agg(c.source_id::text||c.category,'|' ORDER BY c.source_id)) INTO after_hash
 FROM public.lts_card_source_rows_v226(u) c JOIN public.lts_open_finance_staging s ON s.id=c.source_id
 WHERE public.lts_card_installment_key_v231(s) IS DISTINCT FROM chosen.purchase_key;
 IF baseline IS DISTINCT FROM after_hash THEN RAISE EXCEPTION 'Confirmation changed an unrelated purchase'; END IF;
 IF EXISTS(SELECT 1 FROM public.lts_v229_review_rows(u,date '2013-10-10',current_date) r JOIN public.lts_open_finance_staging s
 ON s.id::text=r.source_ref AND r.source_table='lts_open_finance_staging'
 WHERE public.lts_card_installment_key_v231(s)=chosen.purchase_key AND r.identity_status='pending')
 THEN RAISE EXCEPTION 'Confirmed installments remain in the queue'; END IF;
 PERFORM set_config('lts.v231.qa.confirmation','true',true);
END $$;

SELECT jsonb_build_object('pass',true,'banks',3,'daily_dates',21,
 'bank_gaps',current_setting('lts.v231.qa.flow')::jsonb#>'{observed_bank_movements,documentary_gaps}',
 'pending_forecasts_visible',true,'queue_breakdown',current_setting('lts.v231.qa.queue_breakdown')::jsonb,
 'review_read_and_count_ms',current_setting('lts.v231.qa.review_ms')::numeric,
 'same_purchase_learning',current_setting('lts.v231.qa.confirmation')::boolean,
 'unrelated_purchases_preserved',true,'all_test_decisions_rolled_back',true) result;
ROLLBACK;
