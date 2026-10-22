-- Administrator operation. Supply private lts.income_purpose.owner_id, manifest,
-- expected_count and evidence settings inside an explicit transaction.
-- Each manifest entry pins one existing incoming ledger source and its category.
-- Run with ROLLBACK first. No money, date, source status or person is written.
DO $classify$
DECLARE
 u uuid:=current_setting('lts.income_purpose.owner_id')::uuid;
 manifest jsonb:=current_setting('lts.income_purpose.manifest')::jsonb;
 expected integer:=current_setting('lts.income_purpose.expected_count')::integer;
 evidence text:=current_setting('lts.income_purpose.evidence');
 scope_hash text;existing jsonb;item jsonb;source_row public.evento_base%rowtype;
 matched jsonb;previous jsonb;originals jsonb:='[]';registered text;
 before_income jsonb;after_income jsonb;before_cash jsonb;after_cash jsonb;
 before_expense jsonb;after_expense jsonb;before_other jsonb;after_other jsonb;
 before_sources text;after_sources text;before_key text;after_key text;
 pending_before integer;pending_after integer;n integer;changed integer:=0;
BEGIN
 IF u IS NULL OR expected<=0 OR expected>1000 OR jsonb_typeof(manifest)<>'array'
 OR jsonb_array_length(manifest)<>expected OR length(evidence)<30
 OR NOT EXISTS(SELECT 1 FROM auth.users WHERE id=u)
 THEN RAISE EXCEPTION 'An owner, nonempty exact manifest and documentary evidence are required';END IF;
 IF (SELECT count(DISTINCT x->>'source_ref') FROM jsonb_array_elements(manifest)x)<>expected
 THEN RAISE EXCEPTION 'Duplicate or missing source identity';END IF;
 scope_hash:=md5(manifest::text);
 PERFORM pg_advisory_xact_lock(hashtextextended(u::text||':documented-income:'||scope_hash,297));
 SELECT details INTO existing FROM public.audit_log WHERE user_id=u
 AND action='classify_documented_historical_income' AND entity_type='income_source_manifest'
 AND entity_id=scope_hash;

 -- Validate and lock every source before changing a classification.
 FOR item IN SELECT x FROM jsonb_array_elements(manifest)x LOOP
  IF item->>'source_ref' !~ '^[0-9]+$' OR item->>'source_hash' !~ '^[0-9a-f]{32}$'
  OR nullif(item->>'description','') IS NULL OR nullif(item->>'category','') IS NULL
  OR (item->>'amount')::numeric<=0 OR (item->>'event_date')::date>current_date
  OR (item->>'event_date')::date<date '2013-10-10'
  OR item->>'account' NOT IN('Itaú','Bradesco','C6')
  THEN RAISE EXCEPTION 'Invalid documented incoming source';END IF;
  SELECT * INTO STRICT source_row FROM public.evento_base
  WHERE usuario_id=u AND idx::text=item->>'source_ref' FOR SHARE;
  IF md5(to_jsonb(source_row)::text) IS DISTINCT FROM item->>'source_hash'
  OR source_row.dados->>'desc' IS DISTINCT FROM item->>'description'
  OR source_row.dados->>'efeito' IS DISTINCT FROM 'entrada'
  OR (source_row.dados->>'valor')::numeric IS DISTINCT FROM (item->>'amount')::numeric
  THEN RAISE EXCEPTION 'A documentary source no longer matches its exact snapshot';END IF;
  SELECT to_jsonb(d) INTO previous FROM public.lts_v178_review_decision d
  WHERE d.user_id=u AND d.source_table='evento_base' AND d.source_ref=item->>'source_ref'
  FOR UPDATE;
  IF previous->>'beneficiary' IS NOT NULL OR previous->>'property_code' IS NOT NULL
  THEN RAISE EXCEPTION 'An existing personal or property decision must be reviewed separately';END IF;
  IF existing IS NULL AND previous->>'category_label' IS NOT NULL
  THEN RAISE EXCEPTION 'A prior explicit category must not be overwritten';END IF;
  IF existing IS NOT NULL AND (previous->>'category_label' IS DISTINCT FROM item->>'category'
   OR previous->>'decision_basis' IS DISTINCT FROM 'source_explicit_purpose_v297:'||scope_hash)
  THEN RAISE EXCEPTION 'A previously applied source decision has changed';END IF;
  originals:=originals||jsonb_build_array(jsonb_build_object('source_ref',item->>'source_ref','decision',previous));
 END LOOP;
 IF existing IS NOT NULL THEN
  IF existing->'manifest' IS DISTINCT FROM manifest OR existing->>'documentary_evidence' IS DISTINCT FROM evidence
  THEN RAISE EXCEPTION 'The existing documentary operation differs';END IF;
  PERFORM set_config('lts.income_purpose.result',jsonb_build_object('pass',true,'idempotent',true,'classified',expected,'financial_effect',0)::text,true);
  RETURN;
 END IF;

 SELECT coalesce(jsonb_agg(x ORDER BY x->>'review_key'),'[]') INTO before_income
 FROM lts_income_private.rows_v296(u,'2013-10-10',current_date)x;
 FOR item IN SELECT x FROM jsonb_array_elements(manifest)x LOOP
  SELECT count(*),jsonb_agg(x)->0 INTO n,matched FROM jsonb_array_elements(before_income)x
  WHERE x->>'source_table'='evento_base' AND x->>'decision_ref'=item->>'source_ref'
  AND x->>'event_date'=item->>'event_date' AND x->>'account'=item->>'account'
  AND (x->>'signed_amount')::numeric=(item->>'amount')::numeric;
  IF n<>1 OR public.lts_v178_norm(matched->>'category') NOT IN
   ('','a classificar','classificacao pendente','sem categoria','nao identificado','—')
  THEN RAISE EXCEPTION 'The exact incoming source is no longer pending';END IF;
 END LOOP;
 SELECT count(*) INTO pending_before FROM jsonb_array_elements(before_income)x
 WHERE public.lts_v178_norm(x->>'category') IN('','a classificar','classificacao pendente','sem categoria','nao identificado','—');
 SELECT coalesce(jsonb_agg(to_jsonb(r)-'category' ORDER BY (to_jsonb(r)-'category')::text),'[]') INTO before_cash
 FROM public.lts_historical_effective_cash_v5(u,'2013-10-10',current_date)r;
 SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text),'[]') INTO before_expense
 FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)r;
 SELECT coalesce(jsonb_agg(to_jsonb(d) ORDER BY d.source_table,d.source_ref),'[]') INTO before_other
 FROM public.lts_v178_review_decision d WHERE d.user_id=u AND NOT(d.source_table='evento_base'
 AND EXISTS(SELECT 1 FROM jsonb_array_elements(manifest)x WHERE x->>'source_ref'=d.source_ref));
 SELECT md5(coalesce(string_agg(x,'|' ORDER BY x),'')) INTO before_sources FROM(
  SELECT 'base:'||to_jsonb(b)::text x FROM public.evento_base b WHERE b.usuario_id=u
  UNION ALL SELECT 'event:'||to_jsonb(f)::text FROM public.financial_events f WHERE f.user_id=u
  UNION ALL SELECT 'bank:'||to_jsonb(s)::text FROM public.lts_open_finance_staging s WHERE s.user_id=u)t;
 before_key:=public.lts_flow_read_source_key_v247(u);

 FOR item IN SELECT x FROM jsonb_array_elements(manifest)x LOOP
  registered:=public.lts_category_register_v290(u,item->>'category','documented_income_v297',item->>'source_ref');
  IF registered IS DISTINCT FROM item->>'category' OR NOT EXISTS(SELECT 1 FROM public.lts_category_catalog
   WHERE user_id=u AND category=registered AND active)
  THEN RAISE EXCEPTION 'The requested purpose is not an active canonical category';END IF;
  INSERT INTO public.lts_v178_review_decision(user_id,source_table,source_ref,category_label,beneficiary,decision_basis)
  VALUES(u,'evento_base',item->>'source_ref',registered,NULL,'source_explicit_purpose_v297:'||scope_hash)
  ON CONFLICT(user_id,source_table,source_ref) DO UPDATE SET category_label=excluded.category_label,
   decision_basis=excluded.decision_basis,decided_at=clock_timestamp()
  WHERE lts_v178_review_decision.category_label IS NULL AND lts_v178_review_decision.beneficiary IS NULL;
  GET DIAGNOSTICS n=ROW_COUNT;changed:=changed+n;
 END LOOP;
 IF changed<>expected THEN RAISE EXCEPTION 'The classification write scope changed';END IF;

 SELECT coalesce(jsonb_agg(x ORDER BY x->>'review_key'),'[]') INTO after_income
 FROM lts_income_private.rows_v296(u,'2013-10-10',current_date)x;
 IF(SELECT jsonb_agg(x-'category'-'token'-'classification_confirmed' ORDER BY x->>'review_key') FROM jsonb_array_elements(before_income)x)
 IS DISTINCT FROM(SELECT jsonb_agg(x-'category'-'token'-'classification_confirmed' ORDER BY x->>'review_key') FROM jsonb_array_elements(after_income)x)
 THEN RAISE EXCEPTION 'Incoming dates, amounts, identities, status, account or person changed';END IF;
 FOR item IN SELECT x FROM jsonb_array_elements(manifest)x LOOP
  IF(SELECT count(*) FROM jsonb_array_elements(after_income)x WHERE x->>'source_table'='evento_base'
   AND x->>'decision_ref'=item->>'source_ref' AND x->>'category'=item->>'category')<>1
  THEN RAISE EXCEPTION 'A documentary category was not returned by the actual incoming reader';END IF;
 END LOOP;
 SELECT count(*) INTO pending_after FROM jsonb_array_elements(after_income)x
 WHERE public.lts_v178_norm(x->>'category') IN('','a classificar','classificacao pendente','sem categoria','nao identificado','—');
 IF pending_before-pending_after<>expected THEN RAISE EXCEPTION 'Pending count does not match the exact documented scope';END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(r)-'category' ORDER BY (to_jsonb(r)-'category')::text),'[]') INTO after_cash
 FROM public.lts_historical_effective_cash_v5(u,'2013-10-10',current_date)r;
 SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text),'[]') INTO after_expense
 FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)r;
 IF before_cash IS DISTINCT FROM after_cash OR before_expense IS DISTINCT FROM after_expense
 THEN RAISE EXCEPTION 'Historical cash fields or any canonical expense changed';END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(d) ORDER BY d.source_table,d.source_ref),'[]') INTO after_other
 FROM public.lts_v178_review_decision d WHERE d.user_id=u AND NOT(d.source_table='evento_base'
 AND EXISTS(SELECT 1 FROM jsonb_array_elements(manifest)x WHERE x->>'source_ref'=d.source_ref));
 IF before_other IS DISTINCT FROM after_other THEN RAISE EXCEPTION 'An unrelated classification changed';END IF;
 SELECT md5(coalesce(string_agg(x,'|' ORDER BY x),'')) INTO after_sources FROM(
  SELECT 'base:'||to_jsonb(b)::text x FROM public.evento_base b WHERE b.usuario_id=u
  UNION ALL SELECT 'event:'||to_jsonb(f)::text FROM public.financial_events f WHERE f.user_id=u
  UNION ALL SELECT 'bank:'||to_jsonb(s)::text FROM public.lts_open_finance_staging s WHERE s.user_id=u)t;
 IF before_sources IS DISTINCT FROM after_sources THEN RAISE EXCEPTION 'A raw financial source changed';END IF;
 after_key:=public.lts_flow_read_source_key_v247(u);
 IF before_key IS NOT DISTINCT FROM after_key THEN RAISE EXCEPTION 'The real source fingerprint did not invalidate';END IF;
 INSERT INTO public.audit_log(user_id,action,entity_type,entity_id,details)
 VALUES(u,'classify_documented_historical_income','income_source_manifest',scope_hash,
  jsonb_build_object('version','documented-historical-income-v297','manifest',manifest,'original_decisions',originals,
   'documentary_evidence',evidence,'classified',changed,'pending_before',pending_before,'pending_after',pending_after,
   'no_person_inferred',true,'all_financial_sources_unchanged',true,'cash_fields_unchanged',true,
   'all_expenses_unchanged',true,'unrelated_decisions_unchanged',true,'financial_effect',0));
 PERFORM set_config('lts.income_purpose.result',jsonb_build_object('pass',true,'classified',changed,
  'pending_before',pending_before,'pending_after',pending_after,'financial_effect',0,'no_person_inferred',true,
  'all_financial_sources_and_expenses_unchanged',true)::text,true);
END $classify$;
