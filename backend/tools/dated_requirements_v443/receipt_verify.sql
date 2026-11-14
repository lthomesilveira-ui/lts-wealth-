INSERT INTO lts_projection_private_v412.received_income_evidence_v443(user_id,series_key,due_date,receipt_source_id,receipt_hash,receipt_date,receipt_amount,balance_source_id,account_ref,institution_code,balance_as_of,proof_ref)
VALUES('00000000-0000-4000-8000-000000000001','salary_advance',date '2030-03-10'+1,'00000000-0000-4000-8000-000000000041',repeat('a',64),date '2030-03-10',123.45,'00000000-0000-4000-8000-000000000042','invented-checking','341',timestamptz '2030-03-10 10:00:00+00','invented-review');
DO $test$
DECLARE rule jsonb:='{"series_key":"salary_advance","direction":"income","method":"fixed","account":"Itaú","amount_brl":"123.45"}';r jsonb;
BEGIN
 r:=lts_projection_private_v412.received_income_slot_v443(public.lts_open_finance_pilot_owner_v1(),rule,date '2030-03-10'+1,date '2030-03-10');
 IF r->>'status'<>'received_in_balance' OR(r->>'amount_brl')::numeric<>123.45 THEN RAISE EXCEPTION 'Reviewed receipt not recognized';END IF;
 IF(SELECT count(*)FROM public.fixture_invalidation_v443)<>1 THEN RAISE EXCEPTION 'Receipt did not invalidate previous projection';END IF;
 IF lts_projection_private_v412.received_income_slot_v443('00000000-0000-4000-8000-000000000002',rule,date '2030-03-10'+1,date '2030-03-10')->>'status'<>'no_reviewed_receipt' THEN RAISE EXCEPTION 'Cross-owner receipt leaked';END IF;
 IF lts_projection_private_v412.received_income_slot_v443(public.lts_open_finance_pilot_owner_v1(),rule,date '2030-03-10'+32,date '2030-03-10')->>'status'<>'no_reviewed_receipt' THEN RAISE EXCEPTION 'Another payroll occurrence suppressed';END IF;
 IF lts_projection_private_v412.received_income_slot_v443(public.lts_open_finance_pilot_owner_v1(),jsonb_set(rule,'{series_key}','"thirteenth"'),date '2030-03-10'+1,date '2030-03-10')->>'status'<>'not_applicable' THEN RAISE EXCEPTION 'Thirteenth salary affected';END IF;
 UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{status}','"PENDING"');
 IF lts_projection_private_v412.received_income_slot_v443(public.lts_open_finance_pilot_owner_v1(),rule,date '2030-03-10'+1,date '2030-03-10')->>'status'<>'receipt_requires_review' THEN RAISE EXCEPTION 'Pending receipt accepted';END IF;
 UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{status}','"POSTED"'),signed_amount=123.44;
 IF lts_projection_private_v412.received_income_slot_v443(public.lts_open_finance_pilot_owner_v1(),rule,date '2030-03-10'+1,date '2030-03-10')->>'status'<>'receipt_requires_review' THEN RAISE EXCEPTION 'Changed amount accepted';END IF;
 UPDATE public.lts_open_finance_staging SET signed_amount=123.45,raw_hash=repeat('b',64);
 IF lts_projection_private_v412.received_income_slot_v443(public.lts_open_finance_pilot_owner_v1(),rule,date '2030-03-10'+1,date '2030-03-10')->>'status'<>'receipt_requires_review' THEN RAISE EXCEPTION 'Changed source identity accepted';END IF;
 UPDATE public.lts_open_finance_staging SET raw_hash=repeat('a',64),provider_deleted_at=now();
 IF lts_projection_private_v412.received_income_slot_v443(public.lts_open_finance_pilot_owner_v1(),rule,date '2030-03-10'+1,date '2030-03-10')->>'status'<>'receipt_requires_review' THEN RAISE EXCEPTION 'Deleted source accepted';END IF;
 UPDATE public.lts_open_finance_staging SET provider_deleted_at=NULL;
 UPDATE public.fixture_positions_v443 SET data=jsonb_set(data,'{0,as_of}',to_jsonb((timestamptz '2030-03-10 08:00:00+00')::text));
 IF lts_projection_private_v412.received_income_slot_v443(public.lts_open_finance_pilot_owner_v1(),rule,date '2030-03-10'+1,date '2030-03-10')->>'status'<>'receipt_requires_review' THEN RAISE EXCEPTION 'Balance before salary accepted';END IF;
 UPDATE public.fixture_positions_v443 SET data=jsonb_set(data,'{0,as_of}',to_jsonb((timestamptz '2030-03-10 10:00:00+00')::text));
 IF lts_projection_private_v412.received_income_slot_v443(public.lts_open_finance_pilot_owner_v1(),jsonb_set(rule,'{account}','"Bradesco"'),date '2030-03-10'+1,date '2030-03-10')->>'status'<>'receipt_requires_review' THEN RAISE EXCEPTION 'Wrong bank accepted';END IF;
 IF has_table_privilege('authenticated','lts_projection_private_v412.received_income_evidence_v443','SELECT') OR has_table_privilege('service_role','lts_projection_private_v412.received_income_evidence_v443','INSERT') OR has_function_privilege('authenticated','lts_projection_private_v412.received_income_slot_v443(uuid,jsonb,date,date)','EXECUTE') THEN RAISE EXCEPTION 'Receipt permissions broadened';END IF;
END $test$;
