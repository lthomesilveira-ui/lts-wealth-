-- Private caller-supplied manifest; caller owns BEGIN and COMMIT/ROLLBACK.
-- The operation preserves the obligation's amount/date/person and all bank originals.
SET LOCAL timezone='America/Sao_Paulo';
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='25s';
DO $operation$
DECLARE m jsonb:=current_setting('lts.v302.input')::jsonb;u uuid:=public.lts_open_finance_pilot_owner_v1();
 f public.financial_events%rowtype;s public.lts_open_finance_staging%rowtype;
 partial public.lts_reconciliation_evidence%rowtype;binding public.lts_realized_bank_event_v238%rowtype;
 receipt jsonb;before_event jsonb;other_expenses jsonb;after_expenses jsonb;actual jsonb;prospective jsonb;
 cash jsonb;before_sources text;after_sources text;bank text;n integer;
BEGIN
 IF NOT coalesce(m ?& ARRAY['event_id','event_hash','bank_source_id','bank_raw_hash','partial_evidence_id','schedule_document'],false)
 THEN RAISE EXCEPTION 'Complete private evidence manifest required';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(u::text||':'||(m->>'event_id'),302));
 SELECT * INTO STRICT f FROM public.financial_events WHERE user_id=u AND id=(m->>'event_id')::uuid FOR UPDATE;
 SELECT * INTO STRICT s FROM public.lts_open_finance_staging WHERE user_id=u AND id=(m->>'bank_source_id')::uuid FOR SHARE;
 SELECT * INTO binding FROM public.lts_realized_bank_event_v238 WHERE user_id=u AND financial_event_id=f.id;
 IF FOUND THEN
  IF binding.staging_id<>s.id OR NOT public.lts_partial_obligation_settlement_valid_v302(to_jsonb(f),to_jsonb(s),to_jsonb(binding),binding.evidence)
  THEN RAISE EXCEPTION 'Existing settlement conflicts with the supplied evidence';END IF;
  PERFORM set_config('lts.v302.receipt',jsonb_build_object('status','already_reconciled','event_id',f.id,'bank_source_id',s.id)::text,true);
  RETURN;
 END IF;
 SELECT * INTO STRICT partial FROM public.lts_reconciliation_evidence
 WHERE user_id=u AND id=(m->>'partial_evidence_id')::uuid FOR SHARE;
 SELECT institution INTO STRICT bank FROM public.accounts WHERE user_id=u AND id=f.account_id
 AND is_active AND account_type='checking' AND currency='BRL';
 IF md5(((to_jsonb(f)-'created_at')||jsonb_build_object('created_at_epoch',extract(epoch FROM f.created_at)))::text)
 IS DISTINCT FROM m->>'event_hash' OR s.raw_hash IS DISTINCT FROM m->>'bank_raw_hash'
 OR f.source<>'user_confirmed_partial_obligation' OR NOT f.is_projection OR f.status<>'scheduled'
 OR f.is_suppressed OR f.is_internal_transfer OR f.amount>=0 OR f.amount<>s.signed_amount
 OR f.event_date<>s.posting_date OR f.event_date>current_date
 OR bank IS DISTINCT FROM (CASE s.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END)
 OR partial.evidence_type<>'user_confirmed_partial_obligation' OR partial.status<>'documented'
 OR partial.metadata->>'remaining_event_id'<>f.id::text
 OR partial.metadata->>'remaining_due_date'<>f.event_date::text
 OR (partial.metadata->>'remaining_amount')::numeric<>abs(f.amount)
 OR (partial.metadata->>'paid_amount')::numeric<>(f.metadata->>'paid_amount')::numeric
 OR (partial.metadata->>'obligation_amount')::numeric<>(f.metadata->>'obligation_amount')::numeric
 OR partial.metadata->>'bank_staging_id'<>f.metadata->>'paid_bank_staging_id'
 OR nullif(partial.metadata->>'user_confirmation','') IS NULL
 OR f.metadata ?| ARRAY['bank_staging_id','bank_reconciliation_evidence','realized_partial_obligation_v302']
 THEN RAISE EXCEPTION 'Original confirmed obligation or bank evidence changed';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_v229_documentary_match WHERE user_id=u AND (staging_id=s.id OR source_ref=f.id::text))
 OR EXISTS(SELECT 1 FROM public.lts_realized_bank_event_v238 WHERE user_id=u AND staging_id=s.id)
 THEN RAISE EXCEPTION 'The bank source or obligation is already bound';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_v178_review_decision d WHERE d.user_id=u
 AND d.source_table='lts_open_finance_staging' AND d.source_ref=s.id::text
 AND (d.category_label IS DISTINCT FROM f.category OR d.beneficiary IS DISTINCT FROM f.metadata->>'beneficiary'
 OR d.property_code IS NOT NULL)) THEN RAISE EXCEPTION 'A source-specific owner decision conflicts with the obligation';END IF;
 SELECT count(*) INTO n FROM public.lts_open_finance_staging x WHERE x.user_id=u AND x.resource_type='transaction'
 AND x.provider_deleted_at IS NULL AND x.currency='BRL' AND x.normalized_payload->>'status'='POSTED'
 AND x.normalized_payload->>'account_type'='CHECKING_ACCOUNT' AND x.provider_account_ref=s.provider_account_ref
 AND x.institution_code=s.institution_code AND x.posting_date=s.posting_date AND x.signed_amount=s.signed_amount
 AND x.raw_payload#>>'{paymentData,receiver,documentNumber,value}'=s.raw_payload#>>'{paymentData,receiver,documentNumber,value}';
 IF n<>1 THEN RAISE EXCEPTION 'Ambiguous posted payee/payment identity';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.lts_open_finance_staging p WHERE p.user_id=u AND p.id=(f.metadata->>'paid_bank_staging_id')::uuid
 AND p.currency='BRL' AND p.provider_deleted_at IS NULL AND p.normalized_payload->>'status'='POSTED'
 AND p.provider_account_ref=s.provider_account_ref AND p.institution_code=s.institution_code
 AND p.signed_amount=-(f.metadata->>'paid_amount')::numeric AND p.posting_date=(f.metadata->>'paid_date')::date)
 THEN RAISE EXCEPTION 'The separately confirmed earlier partial payment is missing';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.lts_open_finance_staging p WHERE p.user_id=u AND p.resource_type='balance'
 AND p.institution_code=s.institution_code AND p.provider_account_ref=s.provider_account_ref
 AND p.provider_deleted_at IS NULL AND p.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND (p.normalized_payload->>'as_of')::timestamptz>=s.occurred_at)
 THEN RAISE EXCEPTION 'Received bank position does not cover the payment';END IF;
 before_event:=to_jsonb(f);
 receipt:=jsonb_build_object('version','exact-partial-obligation-v302',
 'basis','owner_confirmed_partial_obligation_and_documented_bank_schedule',
 'bank_source_id',s.id,'bank_raw_hash',s.raw_hash,'provider_record_id',s.provider_record_id,
 'provider_account_ref',s.provider_account_ref,'institution_code',s.institution_code,
 'receiver_name',s.raw_payload#>>'{paymentData,receiver,name}',
 'receiver_document_hash',md5(s.raw_payload#>>'{paymentData,receiver,documentNumber,value}'),
 'partial_evidence_id',partial.id,'schedule_document',m->'schedule_document','before_financial_event',before_event,
 'beneficiary_basis','preserved_existing_explicit_owner_confirmation','future_payments_inferred',false);
 prospective:=before_event||jsonb_build_object('is_projection',false,'status','confirmed','metadata',f.metadata||jsonb_build_object(
 'bank_staging_id',s.id,'bank_reconciliation_evidence',jsonb_build_object('bank_raw_hash',s.raw_hash),
 'realized_partial_obligation_v302',receipt-'before_financial_event'));
 IF NOT public.lts_partial_obligation_settlement_valid_v302(prospective,to_jsonb(s),jsonb_build_object(
 'user_id',u,'financial_event_id',f.id,'staging_id',s.id,'bank',bank,'expected_date',f.event_date,
 'expected_amount',f.amount,'category',f.category,'beneficiary',f.metadata->>'beneficiary','property_code',NULL),receipt)
 THEN RAISE EXCEPTION 'Partial-obligation evidence is incomplete or inconsistent';END IF;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.id)::text,'[]')) INTO before_sources
 FROM public.lts_open_finance_staging x WHERE user_id=u;
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]') INTO other_expenses
 FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)x;
 cash:=public.lts_open_finance_current_bank_position_v1(u)->'bank_cash';
 UPDATE public.financial_events SET is_projection=false,status='confirmed',metadata=metadata||jsonb_build_object(
 'bank_staging_id',s.id,'bank_reconciliation_evidence',jsonb_build_object('bank_raw_hash',s.raw_hash),
 'realized_partial_obligation_v302',receipt-'before_financial_event') WHERE user_id=u AND id=f.id RETURNING * INTO f;
 INSERT INTO public.lts_realized_bank_event_v238(user_id,financial_event_id,staging_id,bank,expected_date,expected_amount,
 category,beneficiary,property_code,management_group,management_subgroup,property_component,evidence)
 VALUES(u,f.id,s.id,bank,f.event_date,f.amount,f.category,f.metadata->>'beneficiary',NULL,f.category,f.category,NULL,receipt)
 RETURNING * INTO binding;
 IF NOT public.lts_partial_obligation_settlement_valid_v302(to_jsonb(f),to_jsonb(s),to_jsonb(binding),receipt)
 THEN RAISE EXCEPTION 'Partial-obligation evidence is incomplete or inconsistent';END IF;
 INSERT INTO public.lts_v229_documentary_match(user_id,staging_id,source_ref,canonical_date,bank,signed_amount,evidence)
 VALUES(u,s.id,f.id::text,f.event_date,bank,f.amount,receipt||jsonb_build_object(
 'basis','owner_confirmed_exact_obligation','raw_hash',s.raw_hash,'actual_posting_date',s.posting_date));
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]') INTO after_expenses
 FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)x
 WHERE NOT(x.source_table='financial_events' AND x.source_ref=f.id::text);
 IF after_expenses IS DISTINCT FROM other_expenses THEN RAISE EXCEPTION 'An unrelated canonical expense changed';END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO actual
 FROM public.lts_v229_expense_rows(u,f.event_date,f.event_date)x
 WHERE (x.source_table='financial_events' AND x.source_ref=f.id::text) OR x.source_ref=s.id::text;
 IF jsonb_array_length(actual)<>1 OR (actual->0->>'amount')::numeric<>abs(f.amount)
 OR actual->0->>'category' IS DISTINCT FROM f.category
 OR actual->0->>'beneficiary' IS DISTINCT FROM f.metadata->>'beneficiary'
 THEN RAISE EXCEPTION 'Expense missing, duplicated or misattributed';END IF;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.id)::text,'[]')) INTO after_sources
 FROM public.lts_open_finance_staging x WHERE user_id=u;
 IF before_sources IS DISTINCT FROM after_sources OR cash IS DISTINCT FROM public.lts_open_finance_current_bank_position_v1(u)->'bank_cash'
 THEN RAISE EXCEPTION 'A bank original or observed cash position changed';END IF;
 INSERT INTO public.audit_log(user_id,action,entity_type,entity_id,details)
 VALUES(u,'reconcile_confirmed_partial_obligation','financial_events',f.id::text,receipt||jsonb_build_object(
 'canonical_expense_count',1,'canonical_expense_increase',abs(f.amount),'unrelated_expenses_preserved',true,
 'bank_sources_preserved',true,'observed_cash_preserved',true,'other_schedules_untouched',true));
 PERFORM set_config('lts.v302.receipt',jsonb_build_object('status','reconciled','event_id',f.id,'bank_source_id',s.id,
 'expense_added',abs(f.amount),'expense',actual->0,'cash_unchanged',true,'sources_unchanged',true)::text,true);
END $operation$;
