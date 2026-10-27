-- Private manifest, service execution. Recognize existing posted payments;
-- preserve the final application cash ledger; create only the reviewed C6 association.
DO $apply$
DECLARE u uuid:=current_setting('lts.v351_owner')::uuid;p jsonb:=current_setting('lts.v351_manifest')::jsonb;
 bill public.lts_open_finance_staging%ROWTYPE;pay public.lts_open_finance_staging%ROWTYPE;
 l jsonb;c jsonb;items jsonb;manifest jsonb;consumption jsonb;coverage jsonb;selected jsonb;canon jsonb;
 before_flow jsonb;after_flow jsonb;before_cash jsonb;after_cash jsonb;before_spend jsonb;after_spend jsonb;
 before_links jsonb;before_contracts jsonb;
 b jsonb;new_link_id uuid;before_raw jsonb;after_raw jsonb;
 f date:=(p->>'window_from')::date;t date:=(p->>'window_to')::date;
BEGIN
 IF u IS NULL OR f IS NULL OR t IS NULL OR f>t OR t-f>120 OR jsonb_array_length(p->'bank_payments')<>3
 THEN RAISE EXCEPTION 'V351_INVALID_MANIFEST';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_card_documentary_payment_link_v272 WHERE user_id=u AND(invoice_source_id=(p#>>'{c6,invoice_id}')::uuid OR payment_source_id=(p#>>'{c6,payment_id}')::uuid))

 THEN RAISE EXCEPTION 'V351_ALREADY_APPLIED_REVIEW_REQUIRED';END IF;
 FOR b IN SELECT x FROM jsonb_array_elements(p->'bank_payments')x LOOP
  IF (SELECT count(*)FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id=(b->>'source_id')::uuid
   AND s.raw_hash=b->>'raw_hash'AND s.resource_type='transaction'AND s.provider_deleted_at IS NULL
   AND s.normalized_payload->>'status'='POSTED'AND s.raw_payload->>'status'='POSTED'
   AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'AND s.currency='BRL'
   AND s.signed_amount=(b->>'amount')::numeric AND s.signed_amount<0
   AND s.posting_date=(b->>'date')::date AND s.posting_date<=current_date
   AND s.description_raw=b->>'description'
   AND public.lts_v178_norm(s.institution_name)=public.lts_v178_norm(b->>'bank'))<>1
  THEN RAISE EXCEPTION 'V351_POSTED_PAYMENT_SOURCE_CHANGED';END IF;
 END LOOP;
 SELECT *INTO STRICT bill FROM public.lts_open_finance_staging WHERE user_id=u AND id=(p#>>'{c6,invoice_id}')::uuid;
 SELECT *INTO STRICT pay FROM public.lts_open_finance_staging WHERE user_id=u AND id=(p#>>'{c6,payment_id}')::uuid;
 IF bill.raw_hash IS DISTINCT FROM p#>>'{c6,invoice_hash}' OR bill.resource_type<>'invoice'
 OR bill.institution_code<>'336'OR pay.institution_code<>'336'OR bill.currency<>'BRL'OR bill.provider_deleted_at IS NOT NULL
 OR bill.signed_amount<>-pay.signed_amount OR pay.description_raw<>'PGTO FAT CARTAO C6'
 OR(SELECT count(DISTINCT provider_account_ref)FROM public.lts_open_finance_staging WHERE user_id=u AND institution_code='336'AND resource_type='credit_card'AND provider_deleted_at IS NULL)<>1
 OR NOT EXISTS(SELECT 1 FROM public.lts_open_finance_staging WHERE user_id=u AND institution_code='336'AND resource_type='credit_card'AND provider_deleted_at IS NULL AND provider_account_ref=bill.provider_account_ref)
 THEN RAISE EXCEPTION 'V351_C6_INVOICE_OR_ACCOUNT_CHANGED';END IF;
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
 before_flow:=public.lts_browser_flow_v242(f,t)->'flow';
 SELECT jsonb_agg(to_jsonb(r)ORDER BY row_key)INTO before_spend FROM public.lts_v229_expense_rows(u,date '2013-10-10',current_date)r;
 SELECT coalesce(jsonb_agg(to_jsonb(x)ORDER BY id),'[]')INTO before_links FROM public.lts_card_documentary_payment_link_v272 x WHERE user_id=u;
 SELECT coalesce(jsonb_agg(to_jsonb(x)ORDER BY payment_source_id),'[]')INTO before_contracts FROM public.lts_card_settlement_expense_contract_v273 x WHERE user_id=u;
 SELECT jsonb_agg(to_jsonb(x)ORDER BY id)INTO before_raw FROM public.lts_open_finance_staging x WHERE user_id=u AND institution_code IN('336','341','237');
 INSERT INTO public.lts_card_documentary_payment_link_v272(user_id,institution_code,provider_item_id,invoice_source_id,payment_source_id,invoice_account_ref,payment_account_ref,expected_amount,expected_due_date,expected_closing_date,expected_payment_date,invoice_raw_hash,payment_raw_hash,documentary_sources,active)
 VALUES(u,'336',split_part(bill.provider_record_id,':',1),bill.id,pay.id,bill.provider_account_ref,pay.provider_account_ref,bill.signed_amount,(bill.normalized_payload->>'due_date')::date,(bill.normalized_payload->>'closing_date')::date,pay.posting_date,bill.raw_hash,pay.raw_hash,
 jsonb_build_array(jsonb_build_object('basis','issuer_invoice_and_other_payment','source_ref',bill.id,'raw_hash',bill.raw_hash),jsonb_build_object('basis','exact_posted_c6_checking_debit','source_ref',pay.id,'raw_hash',pay.raw_hash),jsonb_build_object('basis','single_c6_billing_account_and_exact_cycle_review','invoice_account_ref',bill.provider_account_ref)),true)RETURNING id INTO new_link_id;
 SELECT to_jsonb(x)-'created_at'INTO l FROM public.lts_card_documentary_payment_link_v272 x WHERE id=new_link_id AND user_id=u;
 SELECT jsonb_agg(to_jsonb(s)ORDER BY id)INTO items FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.resource_type='card_transaction'AND s.provider_deleted_at IS NULL AND s.institution_code='336'AND s.provider_account_ref=bill.provider_account_ref AND s.raw_payload#>>'{creditCardMetadata,billId}'=bill.normalized_payload->>'provider_id';
 SELECT jsonb_agg(jsonb_build_object('id',i->>'id','raw_hash',i->>'raw_hash','signed_amount',(i->>'signed_amount')::numeric,'status',i#>>'{normalized_payload,status}','raw_status',i#>>'{raw_payload,status}','operation_type',i#>>'{raw_payload,operationType}')ORDER BY i->>'id'),
 jsonb_agg(jsonb_build_object('id',i->>'id','sha256',encode(sha256(convert_to(((i->'raw_payload')-'order'-'updatedAt')::text,'UTF8')),'hex'))ORDER BY i->>'id')INTO manifest,canon FROM jsonb_array_elements(items)i;
 SELECT jsonb_agg(m ORDER BY m->>'id')INTO consumption FROM jsonb_array_elements(manifest)m WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(items)i WHERE i->>'id'=m->>'id'AND public.lts_card_item_is_invoice_payment_v351(i));
 SELECT x INTO selected FROM jsonb_array_elements(bill.raw_payload->'payments')x WHERE x->>'valueType'='OTHER_PAYMENT'AND left(x->>'paymentDate',10)=l->>'expected_due_date'AND(x->>'amount')::numeric=bill.signed_amount;
 IF selected IS NULL THEN RAISE EXCEPTION 'V351_C6_ISSUER_PAYMENT_CHANGED';END IF;
 c:=jsonb_build_object('active',true,'amount',bill.signed_amount,'user_id',u,'invoice_id',bill.id,'payment_id',pay.id,'link_contract',l,'manifest',manifest,'item_canonical_manifest',canon,'consumption_manifest',consumption,'coverage_mode','card_bank_closed_complete','competence_month',date_trunc('month',bill.posting_date)::date,'invoice_current_hash',bill.raw_hash,'invoice_evidence_policy','raw_except_updatedAt_v1','invoice_canonical_payload',bill.raw_payload-'updatedAt','item_evidence_policy','raw_except_order_updatedAt_v290','issuer_payments',bill.raw_payload->'payments','settlement_manifest',jsonb_build_array(selected),'issuer_settlement_policy','one_c6_other_payment_in_cycle_v351','item_settlement_policy','canonical_invoice_payment_flags_v351','reviewed_other_payment',jsonb_build_object('basis','one_c6_cycle_and_exact_posted_bank_debit','invoice_id',bill.id,'payment_id',pay.id,'issuer_payment_id',selected->>'id','bank_description',pay.description_raw));
 SELECT coalesce(jsonb_agg(jsonb_build_object('source_ref',e.source_ref,'amount',e.amount,'competence_month',e.competence_month,'coverage_mode',e.coverage_mode)),'[]')INTO coverage FROM public.lts_expense_effective_rows_v176(u,date_trunc('month',bill.posting_date)::date,(date_trunc('month',bill.posting_date)+interval '1 month -1 day')::date)e WHERE e.source_table='lts_open_finance_staging'AND e.source_ref IN(SELECT m->>'id'FROM jsonb_array_elements(consumption)m);
 IF NOT public.lts_card_settlement_evidence_valid_v273(u,pay.id,l,to_jsonb(bill),to_jsonb(pay),items,current_date,c,coverage)
 OR public.lts_card_payment_refresh_annotation_v273(u,l,to_jsonb(bill),to_jsonb(pay),c,current_date)IS NULL
 THEN RAISE EXCEPTION 'V351_C6_SETTLEMENT_COVERAGE_REJECTED';END IF;
 INSERT INTO public.lts_card_settlement_expense_contract_v273(user_id,payment_source_id,payload,revision,active)VALUES(u,pay.id,c,'reviewed-c6-settlement-v351',true);
 FOR b IN SELECT x FROM jsonb_array_elements(p->'bank_payments')x LOOP
  IF(SELECT count(*)FROM public.lts_card_documentary_payment_link_v272 x JOIN public.lts_card_settlement_expense_contract_v273 sc ON sc.user_id=x.user_id AND sc.payment_source_id=x.payment_source_id AND sc.active JOIN public.lts_open_finance_staging inv ON inv.user_id=x.user_id AND inv.id=x.invoice_source_id JOIN public.lts_open_finance_staging tx ON tx.user_id=x.user_id AND tx.id=x.payment_source_id WHERE x.user_id=u AND x.payment_source_id=(b->>'source_id')::uuid AND x.active AND public.lts_card_payment_refresh_annotation_v273(u,to_jsonb(x),to_jsonb(inv),to_jsonb(tx),sc.payload,current_date)IS NOT NULL)<>1 THEN RAISE EXCEPTION 'V351_REVIEWED_SETTLEMENT_MISSING';END IF;
 END LOOP;
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
 after_flow:=public.lts_browser_flow_v242(f,t)->'flow';
 SELECT jsonb_agg(to_jsonb(r)ORDER BY row_key)INTO after_spend FROM public.lts_v229_expense_rows(u,date '2013-10-10',current_date)r;
 IF before_spend IS DISTINCT FROM after_spend THEN RAISE EXCEPTION 'V351_CONSUMPTION_CHANGED';END IF;
 SELECT jsonb_agg(to_jsonb(x)ORDER BY id)INTO after_raw FROM public.lts_open_finance_staging x WHERE user_id=u AND institution_code IN('336','341','237');
 IF before_raw IS DISTINCT FROM after_raw THEN RAISE EXCEPTION 'V351_RAW_SOURCE_CHANGED';END IF;
 IF before_flow#>'{historical,days}'IS DISTINCT FROM after_flow#>'{historical,days}'
 OR before_flow#>'{current_future,days}'IS DISTINCT FROM after_flow#>'{current_future,days}'
 OR before_flow#>'{current_future,events}'IS DISTINCT FROM after_flow#>'{current_future,events}'
 THEN RAISE EXCEPTION 'V351_APPLICATION_CASH_OR_FUTURE_CHANGED';END IF;
 SELECT jsonb_agg(to_jsonb(q)ORDER BY d,a)INTO before_cash FROM(
  SELECT e->>'event_date' d,e->>'account'a,sum((e->>'signed_amount')::numeric)amount,count(*)n
  FROM jsonb_array_elements(coalesce(before_flow#>'{historical,events}','[]'))e GROUP BY 1,2)q;
 SELECT jsonb_agg(to_jsonb(q)ORDER BY d,a)INTO after_cash FROM(
  SELECT e->>'event_date' d,e->>'account'a,sum((e->>'signed_amount')::numeric)amount,count(*)n
  FROM jsonb_array_elements(coalesce(after_flow#>'{historical,events}','[]'))e GROUP BY 1,2)q;
 IF before_cash IS DISTINCT FROM after_cash THEN RAISE EXCEPTION 'V351_APPLICATION_BANK_DAY_CASH_CHANGED';END IF;
 IF before_links IS DISTINCT FROM(SELECT coalesce(jsonb_agg(to_jsonb(x)ORDER BY id),'[]')FROM public.lts_card_documentary_payment_link_v272 x WHERE user_id=u AND id<>new_link_id)
 OR before_contracts IS DISTINCT FROM(SELECT coalesce(jsonb_agg(to_jsonb(x)ORDER BY payment_source_id),'[]')FROM public.lts_card_settlement_expense_contract_v273 x WHERE user_id=u AND payment_source_id<>pay.id)
 THEN RAISE EXCEPTION 'V351_EXISTING_SETTLEMENTS_CHANGED';END IF;
 PERFORM set_config('lts.v351_receipt',jsonb_build_object('pass',true,'new_payment_links',1,'new_posted_cash_facts',0,'cash_delta',0,'consumption_unchanged',true,'application_bank_days_unchanged',true,'future_events_unchanged',true,'existing_settlements_unchanged',true,'raw_sources_unchanged',true,'c6_issuer_type_preserved','OTHER_PAYMENT','c6_purchase_count',jsonb_array_length(consumption),'c6_raw_items',jsonb_array_length(items))::text,true);
END $apply$;
