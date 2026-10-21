DO $reconcile$
DECLARE
 u uuid:=current_setting('lts.reconcile.owner_id')::uuid;
 ref text:=current_setting('lts.reconcile.target_ref');
 sid uuid:=current_setting('lts.reconcile.bank_source_id')::uuid;
 expected_plan numeric:=current_setting('lts.reconcile.expected_schedule_amount')::numeric;
 actual numeric:=current_setting('lts.reconcile.expected_actual_amount')::numeric;
 expected_hash text:=current_setting('lts.reconcile.expected_source_hash');
 f public.financial_events%rowtype;s public.lts_open_finance_staging%rowtype;
 mapping record; contract text; bank text; before_unrelated jsonb;after_unrelated jsonb;
 before_event jsonb;actual_rows jsonb; receipt jsonb; flow jsonb;flow_events jsonb;n integer;
BEGIN
 SELECT * INTO STRICT f FROM public.financial_events WHERE user_id=u AND legacy_id=ref FOR UPDATE;
 SELECT * INTO STRICT s FROM public.lts_open_finance_staging WHERE user_id=u AND id=sid FOR SHARE;
 IF EXISTS(SELECT 1 FROM public.lts_realized_bank_event_v238 r WHERE r.user_id=u AND r.financial_event_id=f.id
  AND r.staging_id=s.id AND r.expected_date=s.posting_date AND r.expected_amount=s.signed_amount
  AND NOT f.is_projection AND f.amount=s.signed_amount AND f.status='confirmed') THEN
  IF (s.raw_hash=expected_hash AND s.signed_amount=actual AND s.provider_deleted_at IS NULL
   AND s.currency='BRL' AND s.normalized_payload->>'status'='POSTED'
   AND f.metadata->>'documentary_schedule_amount'=abs(expected_plan)::text) IS DISTINCT FROM true
  THEN RAISE EXCEPTION 'Previously reconciled source no longer matches the expected evidence';END IF;
  RETURN;
 END IF;
 contract:=f.metadata->>'contract_ref';
 SELECT institution INTO STRICT bank FROM public.accounts WHERE user_id=u AND id=f.account_id
 AND is_active AND account_type='checking' AND currency='BRL';
 IF coalesce(contract IS NULL OR contract !~ '^[0-9]{5,20}$' OR f.source<>'documented_contract_schedule'
 OR NOT f.is_projection OR f.is_suppressed OR f.is_internal_transfer OR f.amount<>expected_plan
 OR expected_plan>=0 OR actual>=0 OR f.event_date<>s.posting_date OR f.event_date>current_date
 OR s.resource_type<>'transaction' OR s.currency<>'BRL' OR s.provider_deleted_at IS NOT NULL
 OR s.normalized_payload->>'status' IS DISTINCT FROM 'POSTED'
 OR s.normalized_payload->>'account_type' IS DISTINCT FROM 'CHECKING_ACCOUNT'
 OR s.signed_amount<>actual OR s.raw_hash<>expected_hash
 OR bank IS DISTINCT FROM (CASE s.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END)
 OR s.description_raw IS DISTINCT FROM 'PRESTACAO DE CRED IMOB - DOCTO: '||contract
  ,true) THEN RAISE EXCEPTION 'Contract debit identity changed or is not eligible';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.lts_open_finance_staging b WHERE b.user_id=u AND b.resource_type='balance'
 AND b.institution_code=s.institution_code AND b.provider_account_ref=s.provider_account_ref AND b.provider_deleted_at IS NULL
 AND b.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND (b.normalized_payload->>'as_of')::timestamptz>=s.occurred_at)
 THEN RAISE EXCEPTION 'Bank position does not cover the debit';END IF;
 SELECT count(*) INTO n FROM public.lts_open_finance_staging x WHERE x.user_id=u
 AND x.resource_type='transaction' AND x.provider_deleted_at IS NULL AND x.currency='BRL'
 AND x.institution_code=s.institution_code AND x.provider_account_ref=s.provider_account_ref
 AND x.normalized_payload->>'status'='POSTED' AND x.description_raw=s.description_raw
 AND date_trunc('month',x.posting_date)=date_trunc('month',f.event_date);
 IF n<>1 THEN RAISE EXCEPTION 'Ambiguous bank contract debit';END IF;
 SELECT count(*) INTO n FROM public.financial_events x WHERE x.user_id=u AND NOT x.is_suppressed
 AND x.account_id=f.account_id AND x.metadata->>'contract_ref'=contract
 AND date_trunc('month',x.event_date)=date_trunc('month',f.event_date);
 IF n<>1 THEN RAISE EXCEPTION 'Ambiguous contract obligation';END IF;
 SELECT min(r.category) category,min(r.property_code) property_code,min(r.management_group) management_group,
 min(r.management_subgroup) management_subgroup,min(r.property_component) property_component
 INTO mapping FROM public.lts_realized_bank_event_v238 r JOIN public.financial_events old
 ON old.user_id=r.user_id AND old.id=r.financial_event_id
 WHERE r.user_id=u AND old.account_id=f.account_id AND old.metadata->>'contract_ref'=contract
 AND old.description_normalized=f.description_normalized AND old.event_date<f.event_date
 HAVING count(*)>0 AND count(DISTINCT r.category)=1 AND count(DISTINCT r.property_code)=1
 AND count(DISTINCT r.management_group)=1 AND count(DISTINCT r.management_subgroup)=1
 AND count(DISTINCT r.property_component)=1;
 IF mapping.property_code IS NULL THEN RAISE EXCEPTION 'Contract property mapping not independently established';END IF;
 before_event:=to_jsonb(f);
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]') INTO before_unrelated
 FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)x
 WHERE x.source_ref NOT IN(f.id::text,f.legacy_id,s.id::text,'financial_events:'||f.id::text);
 receipt:=jsonb_build_object('version','exact-contract-debit-v293','basis','bank_posted_exact_contract_reference',
 'contract_ref',contract,'bank_raw_hash',s.raw_hash,'bank_posting_date',s.posting_date,
 'bank_signed_amount',s.signed_amount,'bank_account_ref',s.provider_account_ref,
 'before_financial_event',before_event,'documentary_schedule_amount',abs(f.amount),
 'actual_debit_amount',abs(s.signed_amount),'variance_vs_schedule',abs(s.signed_amount)-abs(f.amount),
 'variance_components_status','not_provided_by_bank','beneficiary_basis','not_inferred',
 'cash_rule','actual_bank_debit_replaces_schedule_not_a_second_expense');
 UPDATE public.financial_events SET amount=s.signed_amount,event_date=s.posting_date,
 is_projection=false,status='confirmed',metadata=metadata||jsonb_build_object(
 'documentary_schedule_amount',abs(f.amount),'documentary_schedule_due_date',f.event_date,
 'actual_debit_amount',abs(s.signed_amount),'actual_debit_date',s.posting_date,
 'variance_vs_schedule',abs(s.signed_amount)-abs(f.amount),'variance_components_status','not_provided_by_bank',
 'realized_bank_source_v293',receipt-'before_financial_event','reconciliation_rule','actual_bank_debit_overrides_documentary_schedule_for_cashflow')
 WHERE user_id=u AND id=f.id;
 INSERT INTO public.lts_realized_bank_event_v238(user_id,financial_event_id,staging_id,bank,expected_date,
 expected_amount,category,beneficiary,property_code,management_group,management_subgroup,property_component,evidence)
 VALUES(u,f.id,s.id,bank,s.posting_date,s.signed_amount,mapping.category,NULL,mapping.property_code,
 mapping.management_group,mapping.management_subgroup,mapping.property_component,receipt);
 INSERT INTO public.lts_v229_documentary_match(user_id,staging_id,source_ref,canonical_date,bank,signed_amount,evidence)
 VALUES(u,s.id,f.legacy_id,f.event_date,bank,s.signed_amount,receipt||jsonb_build_object('raw_hash',s.raw_hash,'actual_posting_date',s.posting_date));
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]') INTO after_unrelated
 FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)x
 WHERE x.source_ref NOT IN(f.id::text,f.legacy_id,s.id::text,'financial_events:'||f.id::text);
 IF before_unrelated IS DISTINCT FROM after_unrelated THEN RAISE EXCEPTION 'Unrelated canonical expenses changed';END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO actual_rows
 FROM public.lts_v229_expense_rows(u,f.event_date,f.event_date)x
 WHERE x.source_ref IN(f.id::text,f.legacy_id,s.id::text,'financial_events:'||f.id::text);
 IF jsonb_array_length(actual_rows)<>1 OR (actual_rows->0->>'amount')::numeric<>abs(s.signed_amount)
 OR actual_rows->0->>'property_code' IS DISTINCT FROM mapping.property_code
 OR actual_rows->0->>'beneficiary' IS NOT NULL
 THEN RAISE EXCEPTION 'Realized expense is missing, duplicated or has an inferred person: %',actual_rows;END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(public.lts_pending_projections_v233(u))x
 WHERE x->>'source_ref'=ref) THEN RAISE EXCEPTION 'Realized contract remains pending';END IF;
 PERFORM set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=u),true);
 flow:=public.lts_browser_flow_v242(f.event_date,f.event_date);
 SELECT coalesce(jsonb_agg(x),'[]') INTO flow_events FROM(
  SELECT x FROM jsonb_array_elements(coalesce(flow#>'{flow,historical,events}','[]'))x
  UNION ALL SELECT x FROM jsonb_array_elements(coalesce(flow#>'{flow,current_future,events}','[]'))x)q
 WHERE x->>'source_ref' IN(f.id::text,f.legacy_id,s.id::text);
 IF jsonb_array_length(flow_events)<>1 OR(flow_events->0->>'signed_amount')::numeric<>s.signed_amount
 OR flow_events->0->>'bank_confirmed' IS DISTINCT FROM 'true'
 THEN RAISE EXCEPTION 'Realized debit is missing or duplicated in Flow';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.lts_open_finance_staging WHERE user_id=u AND id=s.id AND raw_hash=expected_hash
 AND signed_amount=actual AND posting_date=f.event_date) THEN RAISE EXCEPTION 'Raw bank source changed';END IF;
 INSERT INTO public.audit_log(user_id,action,entity_type,entity_id,details)
 VALUES(u,'reconcile_posted_contract_debit','financial_events',f.id::text,receipt||jsonb_build_object(
 'staging_id',s.id,'after_amount',s.signed_amount,'after_is_projection',false,'after_status','confirmed',
 'unrelated_expense_parity',true,'realized_expense_count',1,'realized_flow_debit_count',1));
END $reconcile$;
