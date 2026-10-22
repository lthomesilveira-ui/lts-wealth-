-- Source-specific owner confirmation; no changes to financial or bank source rows.
-- Required local lts.own_transfer.* settings are supplied privately by the operator.
DO $confirmation$
DECLARE
 u uuid:=current_setting('lts.own_transfer.owner_id')::uuid;
 did uuid:=current_setting('lts.own_transfer.debit_id')::uuid;
 cid uuid:=current_setting('lts.own_transfer.credit_id')::uuid;
 dh text:=current_setting('lts.own_transfer.debit_hash');
 ch text:=current_setting('lts.own_transfer.credit_hash');
 dt date:=current_setting('lts.own_transfer.posting_date')::date;
 amt numeric:=current_setting('lts.own_transfer.amount')::numeric;
 confirmed date:=current_setting('lts.own_transfer.confirmation_date')::date;
 statement text:=current_setting('lts.own_transfer.owner_statement');
 d public.lts_open_finance_staging%rowtype;c public.lts_open_finance_staging%rowtype;
 scope_key text;pair_ref text;before_other jsonb;after_other jsonb;
 before_sources text;after_sources text;before_events text;after_events text;
 before_key text;after_key text;receipt jsonb;existing jsonb;n integer;
BEGIN
 SELECT * INTO STRICT d FROM public.lts_open_finance_staging WHERE user_id=u AND id=did FOR SHARE;
 SELECT * INTO STRICT c FROM public.lts_open_finance_staging WHERE user_id=u AND id=cid FOR SHARE;
 IF (did<>cid AND amt>0 AND d.raw_hash=dh AND c.raw_hash=ch
  AND d.posting_date=dt AND c.posting_date=dt AND dt<=current_date
  AND d.signed_amount=-amt AND c.signed_amount=amt AND confirmed>=dt AND confirmed<=current_date
  AND length(statement)>=20 AND length(statement)<=4000
  AND d.provider_deleted_at IS NULL AND c.provider_deleted_at IS NULL
  AND d.resource_type='transaction' AND c.resource_type='transaction'
  AND d.currency='BRL' AND c.currency='BRL'
  AND d.normalized_payload->>'status'='POSTED' AND c.normalized_payload->>'status'='POSTED'
  AND d.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
  AND c.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
  AND d.institution_code<>c.institution_code) IS DISTINCT FROM true
 THEN RAISE EXCEPTION 'The confirmed pair no longer matches the supplied posted source snapshots';END IF;
 scope_key:='owner:'||u::text||':'||dt::text||':'||did::text||':'||cid::text;
 pair_ref:='owner-confirmed-transfer-v295:'||did::text||':'||cid::text;
 SELECT to_jsonb(f) INTO existing FROM public.lts_external_reference_fact f
 WHERE reference_key='owner_confirmed_internal_transfer_pair' AND as_of_date=confirmed AND scope=scope_key;
 IF existing IS NOT NULL THEN
  IF existing#>>'{metadata,debit_raw_hash}' IS DISTINCT FROM dh
   OR existing#>>'{metadata,credit_raw_hash}' IS DISTINCT FROM ch
   OR existing#>>'{metadata,owner_statement}' IS DISTINCT FROM statement
   OR (SELECT count(*) FROM public.lts_owner_confirmed_transfer_pairs_v263(u)p WHERE p.debit_id=did AND p.credit_id=cid)<>1
   OR (SELECT count(*) FROM public.lts_reconciliation_evidence e WHERE e.user_id=u AND e.source_ref=pair_ref
    AND e.evidence_type='owner_confirmed_posted_transfer_pair_v295' AND e.status='documented')<>1
  THEN RAISE EXCEPTION 'An existing confirmation differs from the requested source identity';END IF;
  RETURN;
 END IF;
 IF EXISTS(SELECT 1 FROM public.lts_external_reference_fact f
  WHERE f.reference_key='owner_confirmed_internal_transfer_pair' AND f.metadata->>'user_id'=u::text
   AND (f.metadata->>'debit_id'=did::text OR f.metadata->>'credit_id'=cid::text))
 THEN RAISE EXCEPTION 'A source leg already belongs to another explicit pair';END IF;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.id)::text,'[]')) INTO before_sources
 FROM public.lts_open_finance_staging s WHERE s.user_id=u;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(e) ORDER BY e.id)::text,'[]')) INTO before_events
 FROM public.financial_events e WHERE e.user_id=u;
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]') INTO before_other
 FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)x
 WHERE NOT (x.source_table='lts_open_finance_staging' AND x.source_ref=did::text);
 before_key:=public.lts_flow_read_source_key_v247(u);
 receipt:=jsonb_build_object('version','owner-confirmed-posted-transfer-v295',
  'user_id',u,'debit_id',did,'credit_id',cid,'debit_raw_hash',dh,'credit_raw_hash',ch,
  'confirmation_kind','explicit_exact_pair','owner_statement',statement,
  'confirmation_date',confirmed,'posting_date',dt,'amount',amt,
  'origin_bank_code',d.institution_code,'destination_bank_code',c.institution_code,
  'incoming_payer_document_conflict_preserved',
   c.raw_payload#>>'{paymentData,payer,documentNumber,value}' IS DISTINCT FROM c.raw_payload#>>'{paymentData,receiver,documentNumber,value}',
  'raw_bank_data_changed',false,'consolidated_cash_effect',0,'expense_effect',0);
 INSERT INTO public.lts_external_reference_fact(reference_key,as_of_date,scope,value_numeric,value_text,
  unit,confidence,source_name,evidence,metadata)
 VALUES('owner_confirmed_internal_transfer_pair',confirmed,scope_key,amt,'Transferência entre contas próprias',
  'BRL','user_confirmed','Confirmação explícita do proprietário',statement,receipt);
 SELECT count(*) INTO n FROM public.lts_owner_confirmed_transfer_pairs_v263(u)p
 WHERE p.debit_id=did AND p.credit_id=cid;
 IF n<>1 THEN RAISE EXCEPTION 'The existing owned-account and reciprocal-bank validator rejected the pair';END IF;
 -- Existing evidence invalidation also changes all relevant cache source keys.
 INSERT INTO public.lts_reconciliation_evidence(user_id,evidence_date,account,amount,description,evidence_type,
  source_ref,status,metadata)
 VALUES(u,dt,'Transferência própria',amt,'Transferência entre contas confirmada pelo proprietário',
  'owner_confirmed_posted_transfer_pair_v295',pair_ref,'documented',receipt);
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]') INTO after_other
 FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)x;
 IF before_other IS DISTINCT FROM after_other THEN RAISE EXCEPTION 'Canonical rows other than the transfer debit changed';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_v229_expense_rows(u,dt,dt)x
  WHERE x.source_table='lts_open_finance_staging' AND x.source_ref IN(did::text,cid::text))
 THEN RAISE EXCEPTION 'A confirmed transfer still appears as a canonical expense';END IF;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.id)::text,'[]')) INTO after_sources
 FROM public.lts_open_finance_staging s WHERE s.user_id=u;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(e) ORDER BY e.id)::text,'[]')) INTO after_events
 FROM public.financial_events e WHERE e.user_id=u;
 IF before_sources IS DISTINCT FROM after_sources OR before_events IS DISTINCT FROM after_events
 THEN RAISE EXCEPTION 'Original financial or bank source rows changed';END IF;
 after_key:=public.lts_flow_read_source_key_v247(u);
 IF before_key IS NOT DISTINCT FROM after_key THEN RAISE EXCEPTION 'The Flow source key was not invalidated';END IF;
 INSERT INTO public.audit_log(user_id,action,entity_type,entity_id,details)
 VALUES(u,'confirm_exact_posted_own_transfer','owner_transfer_pair',pair_ref,receipt||jsonb_build_object(
  'unrelated_expenses_unchanged',true,'all_bank_sources_unchanged',true,'financial_events_unchanged',true,
  'before_source_key',before_key,'after_source_key',after_key,
  'debit_source_snapshot',to_jsonb(d),'credit_source_snapshot',to_jsonb(c)));
END $confirmation$;
