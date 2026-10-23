CREATE TEMP TABLE v303_cases(name text,mutation text,expected integer);
INSERT INTO v303_cases VALUES
 ('payroll pending', $q$UPDATE v303_fixture.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{status}','"PENDING"') WHERE description_raw='Raw employer payment'$q$,1),
 ('payroll wrong currency',$q$UPDATE v303_fixture.lts_open_finance_staging SET currency='USD' WHERE description_raw='Raw employer payment'$q$,1),
 ('payroll deleted',$q$UPDATE v303_fixture.lts_open_finance_staging SET provider_deleted_at=now() WHERE description_raw='Raw employer payment'$q$,1),
 ('payroll wrong owner',$q$UPDATE v303_fixture.lts_open_finance_staging SET user_id='00000000-0000-4000-8000-000000000099' WHERE description_raw='Raw employer payment'$q$,1),
 ('payroll wrong bank',$q$UPDATE v303_fixture.lts_open_finance_staging SET institution_code='237' WHERE description_raw='Raw employer payment'$q$,1),
 ('payroll wrong source date',$q$UPDATE v303_fixture.lts_open_finance_staging SET posting_date='2020-04-16' WHERE description_raw='Raw employer payment'$q$,1),
 ('payroll wrong amount',$q$UPDATE v303_fixture.lts_open_finance_staging SET signed_amount=2001 WHERE description_raw='Raw employer payment'$q$,1),
 ('payroll non checking',$q$UPDATE v303_fixture.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{account_type}','"CREDIT"') WHERE description_raw='Raw employer payment'$q$,1),
 ('payroll non transaction',$q$UPDATE v303_fixture.lts_open_finance_staging SET resource_type='invoice' WHERE description_raw='Raw employer payment'$q$,1),
 ('payroll projection changed',$q$UPDATE v303_fixture.evento_base SET dados=jsonb_set(dados,'{valor}','2001') WHERE idx=2$q$,1),
 ('payroll wrong descriptor',$q$UPDATE v303_fixture.evento_base SET dados=jsonb_set(dados,'{desc}','"Other"') WHERE idx=2$q$,1),
 ('payroll wrong direction',$q$UPDATE v303_fixture.evento_base SET dados=jsonb_set(dados,'{efeito}','"saida"') WHERE idx=2$q$,1),
 ('payroll future projection',$q$UPDATE v303_fixture.evento_base SET dados=jsonb_set(dados,'{dia}','"2020-04-25"') WHERE idx=2$q$,1),
 ('payroll match amount differs',$q$UPDATE v303_fixture.payroll_match SET projection_amount=1999$q$,1),
 ('payroll same raw amount is insufficient',$q$DELETE FROM v303_fixture.payroll_match$q$,1),
 ('card inactive link',$q$UPDATE v303_fixture.lts_card_documentary_payment_link_v272 SET active=false$q$,1),
 ('card inactive contract',$q$UPDATE v303_fixture.lts_card_settlement_expense_contract_v273 SET active=false$q$,1),
 ('card no proof',$q$UPDATE v303_fixture.lts_card_settlement_expense_contract_v273 SET payload='{}'$q$,1),
 ('card wrong family',$q$UPDATE v303_fixture.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{card_name}','"Prime"') WHERE resource_type='invoice'$q$,1),
 ('card wrong issuer',$q$UPDATE v303_fixture.lts_open_finance_staging SET institution_code='237' WHERE resource_type='invoice'$q$,1),
 ('card source pending',$q$UPDATE v303_fixture.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{status}','"PENDING"') WHERE description_raw='Raw card payment'$q$,1),
 ('card source deleted',$q$UPDATE v303_fixture.lts_open_finance_staging SET provider_deleted_at=now() WHERE description_raw='Raw card payment'$q$,1),
 ('card source wrong owner',$q$UPDATE v303_fixture.lts_open_finance_staging SET user_id='00000000-0000-4000-8000-000000000099' WHERE description_raw='Raw card payment'$q$,1),
 ('card source future',$q$UPDATE v303_fixture.lts_open_finance_staging SET posting_date='2020-04-25' WHERE description_raw='Raw card payment'$q$,1),
 ('card source non checking',$q$UPDATE v303_fixture.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{account_type}','"CREDIT"') WHERE description_raw='Raw card payment'$q$,1),
 ('card source wrong currency',$q$UPDATE v303_fixture.lts_open_finance_staging SET currency='USD' WHERE description_raw='Raw card payment'$q$,1),
 ('card source wrong bank',$q$UPDATE v303_fixture.lts_open_finance_staging SET institution_code='237' WHERE description_raw='Raw card payment'$q$,1),
 ('card wrong plan account',$q$UPDATE v303_fixture.evento_base SET dados=jsonb_set(dados,'{conta}','"Bradesco"') WHERE idx=1$q$,1),
 ('card ambiguous plan',$q$INSERT INTO v303_fixture.evento_base SELECT usuario_id,99,dados FROM v303_fixture.evento_base WHERE idx=1$q$,1),
 ('card duplicate contract deduplicated',$q$INSERT INTO v303_fixture.lts_card_settlement_expense_contract_v273 SELECT * FROM v303_fixture.lts_card_settlement_expense_contract_v273$q$,2);
DO $tests$
DECLARE u uuid:='00000000-0000-4000-8000-000000000001';r record;n integer;bad boolean;j jsonb;b jsonb;
BEGIN
 SELECT count(*) INTO n FROM public.lts_recurring_receipt_identities_v303(u,'2020-04-20');
 IF n<>2 THEN RAISE EXCEPTION 'expected two exact identities, got %',n;END IF;
 IF (SELECT count(*) FROM public.lts_recurring_receipt_identities_v303(u,'2020-04-11'))<>0
 OR (SELECT count(*) FROM public.lts_recurring_receipt_identities_v303(u,'2020-04-12'))<>1
 OR (SELECT count(*) FROM public.lts_recurring_receipt_identities_v303(u,'2020-04-15'))<>2
 OR (SELECT count(*) FROM public.lts_recurring_receipt_identities_v303('00000000-0000-4000-8000-000000000099','2020-04-20'))<>0
 THEN RAISE EXCEPTION 'as-of/owner scope failed';END IF;
 FOR r IN SELECT * FROM v303_cases LOOP
  BEGIN
   EXECUTE r.mutation;
   SELECT count(*) INTO n FROM public.lts_recurring_receipt_identities_v303(u,'2020-04-20');
   IF n<>r.expected THEN RAISE EXCEPTION 'case % expected %, got %',r.name,r.expected,n;END IF;
   RAISE EXCEPTION USING ERRCODE='V3030',MESSAGE='rollback synthetic mutation';
  EXCEPTION WHEN SQLSTATE 'V3030' THEN NULL;
  END;
 END LOOP;
 IF has_function_privilege('anon','public.lts_recurring_receipt_identities_v303(uuid,date)','EXECUTE')
 OR has_function_privilege('authenticated','public.lts_recurring_receipt_identities_v303(uuid,date)','EXECUTE')
 THEN RAISE EXCEPTION 'private helper exposed';END IF;
 SELECT audit INTO b FROM v303_baseline;
 j:=public.lts_recurring_future_gap_audit_v6(u,'2020-04-20','2020-06-30');
 IF (j-'horizon_checks'-'horizon_review_count'-'horizon_reconciliation_count'-'receipt_identity_revision')
 IS DISTINCT FROM (b-'horizon_checks'-'horizon_review_count'-'horizon_reconciliation_count')
 THEN RAISE EXCEPTION 'non-horizon response changed';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(j->'horizon_checks')c
  WHERE c->>'key' IN('card_itau','salary_advance') AND
  (c#>>'{period_coverage,0,status}'<>'covered' OR c#>>'{period_coverage,0,actual_events}'<>'1'
   OR c#>>'{period_coverage,0,unconfirmed_obligations}'<>'0'))
 THEN RAISE EXCEPTION 'proved current month not covered';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(j->'horizon_checks')a
  JOIN jsonb_array_elements(b->'horizon_checks')z ON z->>'key'=a->>'key'
  CROSS JOIN LATERAL jsonb_array_elements(a->'period_coverage')ap
  JOIN LATERAL jsonb_array_elements(z->'period_coverage')zp ON zp->>'period_start'=ap->>'period_start'
  WHERE ap->>'period_start'>'2020-04-01' AND ap IS DISTINCT FROM zp)
 THEN RAISE EXCEPTION 'future period changed';END IF;
 PERFORM set_config('lts.v303.synthetic_receipt',jsonb_build_object('status','PASS','rejection_and_dedup_cases',(SELECT count(*) FROM v303_cases),
 'scope_checks',4,'real_audit_definition_exercised',true,'dependency_doubles_not_receipt_certification',true)::text,true);
END $tests$;
