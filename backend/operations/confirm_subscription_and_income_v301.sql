-- Caller supplies a private, source-hash-pinned manifest in lts.v301.input.
-- Caller owns BEGIN/ROLLBACK or COMMIT. No raw financial source is edited.
SET LOCAL timezone='America/Sao_Paulo';
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='25s';
DO $prepare$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1();m jsonb:=current_setting('lts.v301.input')::jsonb;
 tag text;expected jsonb;actual jsonb;d public.lts_v178_review_decision%rowtype;fp jsonb;v text;
BEGIN
 IF m->>'operation_id' IS NULL OR m->>'owner_confirmation' IS NULL
 OR m->>'expense_category'<>'Assinaturas' OR m->>'income_category'<>'Reembolso Organon'
 THEN RAISE EXCEPTION 'Explicit confirmation required'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(u::text||':'||(m#>>'{payment,id}'),301));
 FOR tag IN SELECT unnest(ARRAY['payment','invoice','income']) LOOP
  expected:=m->tag;
  IF NOT coalesce(expected ?& ARRAY['id','raw_hash','resource_type','signed_amount','posting_date','currency','institution_code'],false)
  THEN RAISE EXCEPTION 'Incomplete source guard';END IF;
  SELECT to_jsonb(s) INTO STRICT actual FROM public.lts_open_finance_staging s
   WHERE s.user_id=u AND s.id=(expected->>'id')::uuid FOR SHARE;
  IF NOT(actual @> expected) OR actual->>'provider_deleted_at' IS NOT NULL
  THEN RAISE EXCEPTION 'Source changed'; END IF;
  IF tag<>'invoice' AND (actual#>>'{normalized_payload,status}' IS DISTINCT FROM 'POSTED'
   OR actual#>>'{normalized_payload,account_type}' IS DISTINCT FROM 'CHECKING_ACCOUNT')
  THEN RAISE EXCEPTION 'Posted checking evidence required'; END IF;
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM public.lts_category_catalog WHERE user_id=u AND active AND category=m->>'expense_category')
 OR NOT EXISTS(SELECT 1 FROM public.lts_category_catalog WHERE user_id=u AND active AND category=m->>'income_category')
 THEN RAISE EXCEPTION 'Use existing shared categories'; END IF;
 SELECT * INTO d FROM public.lts_v178_review_decision
 WHERE user_id=u AND source_table='lts_open_finance_staging' AND source_ref=m#>>'{payment,id}';
 IF FOUND AND (d.category_label IS DISTINCT FROM m->>'expense_category' OR d.beneficiary IS NOT NULL OR d.property_code IS NOT NULL)
 THEN RAISE EXCEPTION 'Do not replace another prior decision'; END IF;
 PERFORM set_config('lts.v301.expense_done',coalesce(d.category_label=m->>'expense_category',false)::text,true);
 PERFORM set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text
 FROM auth.users WHERE id=u),true);
 SELECT jsonb_build_object(
 'staging',md5(coalesce((SELECT jsonb_agg(to_jsonb(s) ORDER BY s.id)::text FROM public.lts_open_finance_staging s WHERE user_id=u),'[]')),
 'events',md5(coalesce((SELECT jsonb_agg(to_jsonb(s) ORDER BY s.id)::text FROM public.financial_events s WHERE user_id=u),'[]')),
 'other_decisions',md5(coalesce((SELECT jsonb_agg(to_jsonb(s) ORDER BY source_table,source_ref)::text FROM public.lts_v178_review_decision s
 WHERE user_id=u AND NOT(source_table='lts_open_finance_staging' AND source_ref IN(m#>>'{payment,id}',m#>>'{income,id}'))),'[]')),
 'bank_cash',public.lts_open_finance_current_bank_position_v1(u)->'bank_cash') INTO fp;
 PERFORM set_config('lts.v301.fingerprints',fp::text,true);
 SELECT md5(coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text)::text,'[]')) INTO v
 FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date) r
 WHERE NOT(r.source_table='lts_open_finance_staging' AND r.source_ref=m#>>'{payment,id}');
 PERFORM set_config('lts.v301.expected_expenses',v,true);
END $prepare$;
SET LOCAL ROLE authenticated;
SET LOCAL statement_timeout='8s';
DO $expense$
DECLARE m jsonb:=current_setting('lts.v301.input')::jsonb;r jsonb;
BEGIN
 IF current_setting('lts.v301.expense_done',true) IS DISTINCT FROM 'true' THEN
  r:=public.lts_browser_expense_review_decision_v229('lts_open_finance_staging',m#>>'{payment,id}',NULL,NULL,m->>'expense_category');
 ELSE r:='{"ok":true,"already_classified":true}'::jsonb; END IF;
 IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Expense confirmation failed';END IF;
 PERFORM set_config('lts.v301.expense_receipt',r::text,true);
 PERFORM set_config('lts.v301.writer_role',current_user::text,true);
END $expense$;
DO $income$
DECLARE m jsonb:=current_setting('lts.v301.input')::jsonb;r jsonb;
BEGIN
 r:=public.lts_browser_income_category_v183('open_finance',m#>>'{income,id}',
  (m#>>'{income,posting_date}')::date,'Itaú',(m#>>'{income,signed_amount}')::numeric,NULL,NULL);
 IF r->>'category' IS DISTINCT FROM m->>'income_category' THEN
  r:=public.lts_browser_income_category_v183('open_finance',m#>>'{income,id}',
   (m#>>'{income,posting_date}')::date,'Itaú',(m#>>'{income,signed_amount}')::numeric,m->>'income_category',r->>'token');
 ELSE r:=jsonb_build_object('ok',true,'already_classified',true,'category',r->>'category'); END IF;
 IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Income confirmation failed';END IF;
 PERFORM set_config('lts.v301.income_receipt',r::text,true);
END $income$;
RESET ROLE;
SET LOCAL statement_timeout='25s';
DO $link$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1();m jsonb:=current_setting('lts.v301.input')::jsonb;
 b public.lts_open_finance_staging%rowtype;p public.lts_open_finance_staging%rowtype;
 l public.lts_card_documentary_payment_link_v272%rowtype;items jsonb;coverage jsonb;
 c jsonb;prior jsonb;selected jsonb;manifest jsonb;consumption jsonb;canonical jsonb;month_key date;
 created_link boolean:=false;created_contract boolean:=false;v text;
BEGIN
 SELECT * INTO STRICT b FROM public.lts_open_finance_staging WHERE user_id=u AND id=(m#>>'{invoice,id}')::uuid;
 SELECT * INTO STRICT p FROM public.lts_open_finance_staging WHERE user_id=u AND id=(m#>>'{payment,id}')::uuid;
 IF b.resource_type<>'invoice' OR p.resource_type<>'transaction' OR b.currency<>'BRL' OR p.currency<>'BRL'
 OR p.signed_amount<>-b.signed_amount OR split_part(b.provider_record_id,':',1)<>split_part(p.provider_record_id,':',1)
 OR b.institution_code<>p.institution_code
 OR NOT EXISTS(SELECT 1 FROM public.lts_v229_card_recurring_commitment r WHERE r.user_id=u AND r.active
  AND r.family=public.lts_card_family_v226(b.normalized_payload->>'card_name',b.institution_name)
  AND r.amount=b.signed_amount AND r.category=m->>'expense_category')
 THEN RAISE EXCEPTION 'Known recurring invoice identity changed'; END IF;
 SELECT jsonb_agg(x) INTO selected FROM jsonb_array_elements(b.raw_payload->'payments') x
 WHERE left(x->>'paymentDate',10)::date>(b.normalized_payload->>'closing_date')::date
 AND left(x->>'paymentDate',10)::date<=p.posting_date;
 IF jsonb_array_length(selected) IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'Unique current-cycle issuer payment required';END IF;
 SELECT * INTO l FROM public.lts_card_documentary_payment_link_v272 WHERE user_id=u AND payment_source_id=p.id AND active;
 IF FOUND THEN
  IF l.invoice_source_id<>b.id OR (SELECT count(*) FROM public.lts_card_documentary_payment_link_v272 WHERE user_id=u AND payment_source_id=p.id AND active)<>1
  THEN RAISE EXCEPTION 'Conflicting payment link'; END IF;
 ELSE
  INSERT INTO public.lts_card_documentary_payment_link_v272(id,user_id,invoice_source_id,payment_source_id,institution_code,
   provider_item_id,invoice_account_ref,payment_account_ref,expected_amount,expected_due_date,expected_closing_date,
   expected_payment_date,invoice_raw_hash,payment_raw_hash,documentary_sources,active)
  VALUES(gen_random_uuid(),u,b.id,p.id,b.institution_code,split_part(b.provider_record_id,':',1),b.provider_account_ref,p.provider_account_ref,
   b.signed_amount,(b.normalized_payload->>'due_date')::date,(b.normalized_payload->>'closing_date')::date,p.posting_date,b.raw_hash,p.raw_hash,
   jsonb_build_array(jsonb_build_object('basis','owner_confirmed_recurring_subscription','statement',m->>'owner_confirmation','operation_id',m->>'operation_id'),
    jsonb_build_object('source_table','lts_open_finance_staging','source_ref',b.id,'raw_hash',b.raw_hash,'basis','issuer_bill_id_and_full_payment'),
    jsonb_build_object('source_table','lts_open_finance_staging','source_ref',p.id,'raw_hash',p.raw_hash,'basis','posted_bank_debit')),true)
  RETURNING * INTO l;created_link:=true;
 END IF;
 SELECT jsonb_agg(to_jsonb(i) ORDER BY i.id) INTO items FROM public.lts_open_finance_staging i
 WHERE i.user_id=u AND i.resource_type='card_transaction' AND i.provider_deleted_at IS NULL
 AND i.institution_code=b.institution_code AND i.provider_account_ref=b.provider_account_ref
 AND i.raw_payload#>>'{creditCardMetadata,billId}'=b.normalized_payload->>'provider_id';
 SELECT jsonb_agg(jsonb_build_object('id',i->>'id','raw_hash',i->>'raw_hash','signed_amount',(i->>'signed_amount')::numeric,
  'status',i#>>'{normalized_payload,status}','raw_status',i#>>'{raw_payload,status}','operation_type',i#>>'{raw_payload,operationType}') ORDER BY i->>'id'),
 jsonb_agg(jsonb_build_object('id',i->>'id','sha256',encode(sha256(convert_to(((i->'raw_payload')-'order'-'updatedAt')::text,'UTF8')),'hex')) ORDER BY i->>'id')
 INTO manifest,canonical FROM jsonb_array_elements(items)i;
 SELECT jsonb_agg(i ORDER BY i->>'id') INTO consumption FROM jsonb_array_elements(manifest)i WHERE i->>'operation_type' IS DISTINCT FROM 'PAGAMENTO_FATURA';
 month_key:=date_trunc('month',(b.normalized_payload->>'due_date')::date)::date;
 SELECT jsonb_agg(jsonb_build_object('source_ref',e.source_ref,'amount',e.amount,'competence_month',e.competence_month,'coverage_mode',e.coverage_mode) ORDER BY e.source_ref)
 INTO coverage FROM public.lts_expense_effective_rows_v176(u,month_key,(month_key+interval '1 month -1 day')::date)e
 WHERE e.source_table='lts_open_finance_staging' AND e.source_ref IN(SELECT i->>'id' FROM jsonb_array_elements(consumption)i);
 IF jsonb_array_length(coverage) IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'Exact subscription consumption coverage required'; END IF;
 c:=jsonb_build_object('active',true,'user_id',u,'payment_id',p.id,'invoice_id',b.id,'amount',b.signed_amount,
  'competence_month',month_key,'coverage_mode',coverage->0->>'coverage_mode','link_contract',to_jsonb(l)-'created_at',
  'manifest',manifest,'consumption_manifest',consumption,'item_evidence_policy','raw_except_order_updatedAt_v290','item_canonical_manifest',canonical,
  'invoice_current_hash',b.raw_hash,'invoice_evidence_policy','raw_except_updatedAt_v1','invoice_canonical_payload',b.raw_payload-'updatedAt',
  'issuer_payments',b.raw_payload->'payments','settlement_manifest',selected,'issuer_settlement_policy','one_full_payment_in_cycle_v301');
 IF NOT public.lts_card_settlement_evidence_valid_v273(u,p.id,to_jsonb(l),to_jsonb(b),to_jsonb(p),items,current_date,c,coverage)
 OR public.lts_card_payment_refresh_annotation_v273(u,to_jsonb(l),to_jsonb(b),to_jsonb(p),c,current_date) IS NULL
 THEN RAISE EXCEPTION 'Strict invoice, payment and purchase evidence failed'; END IF;
 SELECT payload INTO prior FROM public.lts_card_settlement_expense_contract_v273 WHERE user_id=u AND payment_source_id=p.id;
 IF FOUND THEN
  IF prior IS DISTINCT FROM c THEN RAISE EXCEPTION 'Do not overwrite a different settlement contract'; END IF;
 ELSE
  INSERT INTO public.lts_card_settlement_expense_contract_v273(user_id,payment_source_id,revision,payload,active)
  VALUES(u,p.id,m->>'operation_id',c,true);created_contract:=true;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.lts_reconciliation_evidence WHERE user_id=u AND source_ref=m->>'operation_id') THEN
  INSERT INTO public.lts_reconciliation_evidence(user_id,evidence_date,account,amount,description,evidence_type,source_ref,status,metadata)
  VALUES(u,(m->>'confirmation_date')::date,'Bradesco',abs(p.signed_amount),'Assinatura recorrente confirmada; consumo de fatura contado uma vez',
   'owner_confirmed_subscription_payment_v301',m->>'operation_id','documented',jsonb_build_object('owner_confirmation',m->>'owner_confirmation',
    'payment_id',p.id,'invoice_id',b.id,'consumption_manifest',consumption,'issuer_settlement_policy','one_full_payment_in_cycle_v301',
    'income_source_id',m#>>'{income,id}','income_category',m->>'income_category'));
 END IF;
 IF created_link OR created_contract THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;END IF;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text)::text,'[]')) INTO v
 FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)r;
 IF v IS DISTINCT FROM current_setting('lts.v301.expected_expenses') THEN RAISE EXCEPTION 'Unrelated canonical expenses changed'; END IF;
 PERFORM set_config('lts.v301.link_receipt',jsonb_build_object('payment_id',p.id,'invoice_id',b.id,'created_link',created_link,
  'created_contract',created_contract,'consumption_count',jsonb_array_length(consumption),'issuer_history_preserved',true)::text,true);
END $link$;
DO $sources$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1();m jsonb:=current_setting('lts.v301.input')::jsonb;fp jsonb;
BEGIN
 SELECT jsonb_build_object(
 'staging',md5(coalesce((SELECT jsonb_agg(to_jsonb(s) ORDER BY s.id)::text FROM public.lts_open_finance_staging s WHERE user_id=u),'[]')),
 'events',md5(coalesce((SELECT jsonb_agg(to_jsonb(s) ORDER BY s.id)::text FROM public.financial_events s WHERE user_id=u),'[]')),
 'other_decisions',md5(coalesce((SELECT jsonb_agg(to_jsonb(s) ORDER BY source_table,source_ref)::text FROM public.lts_v178_review_decision s
 WHERE user_id=u AND NOT(source_table='lts_open_finance_staging' AND source_ref IN(m#>>'{payment,id}',m#>>'{income,id}'))),'[]')),
 'bank_cash',public.lts_open_finance_current_bank_position_v1(u)->'bank_cash') INTO fp;
 IF fp IS DISTINCT FROM current_setting('lts.v301.fingerprints')::jsonb THEN RAISE EXCEPTION 'Financial source or unrelated decision changed';END IF;
END $sources$;
SELECT jsonb_build_object('ok',true,'writer_role',current_setting('lts.v301.writer_role'),
 'expense',current_setting('lts.v301.expense_receipt')::jsonb,'income',current_setting('lts.v301.income_receipt')::jsonb,
 'settlement',current_setting('lts.v301.link_receipt')::jsonb,'source_fingerprints_preserved',true,'all_other_expenses_preserved',true,
 'bank_cash',public.lts_open_finance_current_bank_position_v1(public.lts_open_finance_pilot_owner_v1())->'bank_cash') AS receipt;
