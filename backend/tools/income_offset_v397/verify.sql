\set ON_ERROR_STOP on
BEGIN;
DO $tests$
DECLARE
 u uuid:='00000000-0000-0000-0000-000000000001';
 bank_id uuid:='00000000-0000-0000-0000-000000000002';
 proof_id uuid:='00000000-0000-0000-0000-000000000003';
 sign_id uuid:='00000000-0000-0000-0000-000000000004';
 d date:='2025-04-03';a numeric:=150.49;
 source_data jsonb:=jsonb_build_object('dia',d,'desc','Synthetic adjustment','conta','C6','valor',a,'efeito','saida');
 row_data jsonb:=jsonb_build_object('source','legacy_fix86','source_ref','evento_base:77','event_date',d,'account','C6','signed_amount',a,'internal_transfer',false,'excluded_from_spend',false);
 proof jsonb;original_sign jsonb;body text;n integer:=0;
BEGIN
 proof:=jsonb_build_object('version','documented-negative-expense-income-offset-v397',
 'basis','received_bank_credit_already_nets_documented_expense','source_table','evento_base','source_ref','77',
 'flow_source_ref','evento_base:77','bank_staging_id',bank_id,'bank_raw_hash',repeat('a',64),
 'bank_provider_record_id','synthetic-record','bank_provider_account_ref','synthetic-account',
 'expense_override_id','9','cash_sign_evidence_id',sign_id,'source_event_data',source_data,
 'workbook_sha256',repeat('b',64),'workbook_row',42);
 original_sign:=jsonb_build_object('target_flow_source_ref','evento_base:77','workbook_evidence',
 jsonb_build_array(jsonb_build_object('sha256',repeat('b',64),'row',42,'source_amount',(-a)::text)));
 INSERT INTO public.evento_base VALUES(u,77,source_data);
 INSERT INTO public.lts_expense_documentary_amount_override VALUES(9,u,'evento_base','77','documented',d,-a,a);
 INSERT INTO public.synthetic_expense VALUES(u,d,'evento_base','77',-a,'documentary_amount_override');
 INSERT INTO public.lts_open_finance_staging VALUES(bank_id,u,'transaction','BRL',NULL,a,d,repeat('a',64),'synthetic-record','synthetic-account',
 jsonb_build_object('status','POSTED','account_type','CHECKING_ACCOUNT','date',d),
 jsonb_build_object('status','POSTED','type','CREDIT','currencyCode','BRL','amount',a),'336');
 INSERT INTO public.lts_reconciliation_evidence VALUES(sign_id,u,d,'C6',a,'Synthetic adjustment','historical_workbook_cash_sign','sign:77','documented',original_sign);
 INSERT INTO public.lts_reconciliation_evidence VALUES(proof_id,u,d,'C6',a,'Synthetic adjustment','income_expense_offset_v397','offset:77','documented',proof);
 IF NOT public.lts_income_expense_offset_v397(u,row_data) THEN RAISE EXCEPTION 'Proved netted receipt was not recognized';END IF;n:=n+1;
 IF NOT public.lts_income_expense_offset_v397(u,(row_data-'source_ref')||jsonb_build_object('source','open_finance','open_finance_id',bank_id)) THEN RAISE EXCEPTION 'Same proved bank identity was not recognized';END IF;n:=n+1;
 IF public.lts_income_expense_offset_v397('00000000-0000-0000-0000-000000000099',row_data) THEN RAISE EXCEPTION 'Cross-owner exclusion';END IF;n:=n+1;
 IF public.lts_income_expense_offset_v397(u,row_data||jsonb_build_object('event_date',d+1)) THEN RAISE EXCEPTION 'Unrelated date excluded';END IF;n:=n+1;
 IF public.lts_income_expense_offset_v397(u,row_data||jsonb_build_object('signed_amount',a+1)) THEN RAISE EXCEPTION 'Unrelated amount excluded';END IF;n:=n+1;
 IF public.lts_income_expense_offset_v397(u,row_data||jsonb_build_object('signed_amount',-a)) THEN RAISE EXCEPTION 'Debit excluded';END IF;n:=n+1;
 IF public.lts_income_expense_offset_v397(u,row_data||jsonb_build_object('source_ref','evento_base:78')) THEN RAISE EXCEPTION 'Same-amount unlinked receipt excluded';END IF;n:=n+1;
 IF public.lts_income_expense_offset_v397(u,row_data||jsonb_build_object('account','Itaú')) THEN RAISE EXCEPTION 'Other bank excluded';END IF;n:=n+1;
 IF public.lts_income_expense_offset_v397(u,row_data||jsonb_build_object('internal_transfer',true)) THEN RAISE EXCEPTION 'Transfer mistaken for expense netting';END IF;n:=n+1;
 IF public.lts_income_expense_offset_v397(u,row_data||jsonb_build_object('excluded_from_spend',true)) THEN RAISE EXCEPTION 'Already excluded row reclassified';END IF;n:=n+1;
 UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{status}','"PENDING"');
 IF public.lts_income_expense_offset_v397(u,row_data) THEN RAISE EXCEPTION 'Pending credit accepted';END IF;n:=n+1;
 UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{status}','"POSTED"'),provider_deleted_at=now();
 IF public.lts_income_expense_offset_v397(u,row_data) THEN RAISE EXCEPTION 'Deleted credit accepted';END IF;n:=n+1;
 UPDATE public.lts_open_finance_staging SET provider_deleted_at=NULL,raw_hash=repeat('c',64);
 IF public.lts_income_expense_offset_v397(u,row_data) THEN RAISE EXCEPTION 'Changed bank evidence accepted';END IF;n:=n+1;
 UPDATE public.lts_open_finance_staging SET raw_hash=repeat('a',64),raw_payload=jsonb_set(raw_payload,'{type}','"DEBIT"');
 IF public.lts_income_expense_offset_v397(u,row_data) THEN RAISE EXCEPTION 'Raw debit accepted as credit';END IF;n:=n+1;
 UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{type}','"CREDIT"');
 UPDATE public.lts_expense_documentary_amount_override SET documented_signed_amount=a;
 IF public.lts_income_expense_offset_v397(u,row_data) THEN RAISE EXCEPTION 'Positive expense excluded income';END IF;n:=n+1;
 UPDATE public.lts_expense_documentary_amount_override SET documented_signed_amount=-a;
 UPDATE public.synthetic_expense SET amount=0;
 IF public.lts_income_expense_offset_v397(u,row_data) THEN RAISE EXCEPTION 'No current expense netting, but income excluded';END IF;n:=n+1;
 UPDATE public.synthetic_expense SET amount=-a;
 UPDATE public.evento_base SET dados=jsonb_set(dados,'{valor}',to_jsonb(a+1));
 IF public.lts_income_expense_offset_v397(u,row_data) THEN RAISE EXCEPTION 'Changed source record accepted';END IF;n:=n+1;
 UPDATE public.evento_base SET dados=source_data;
 UPDATE public.lts_reconciliation_evidence SET metadata=jsonb_set(metadata,'{workbook_evidence,0,source_amount}','"not-numeric"') WHERE id=sign_id;
 IF public.lts_income_expense_offset_v397(u,row_data) THEN RAISE EXCEPTION 'Invalid workbook number accepted';END IF;n:=n+1;
 UPDATE public.lts_reconciliation_evidence SET metadata=original_sign WHERE id=sign_id;
 INSERT INTO public.lts_reconciliation_evidence SELECT '00000000-0000-0000-0000-000000000005',user_id,evidence_date,account,amount,description,evidence_type,source_ref,status,metadata FROM public.lts_reconciliation_evidence WHERE id=proof_id;
 IF public.lts_income_expense_offset_v397(u,row_data) THEN RAISE EXCEPTION 'Ambiguous duplicate proof accepted';END IF;n:=n+1;
 DELETE FROM public.lts_reconciliation_evidence WHERE id='00000000-0000-0000-0000-000000000005';
 IF NOT public.lts_income_expense_offset_v397(u,row_data) THEN RAISE EXCEPTION 'Valid case changed after negative controls';END IF;n:=n+1;
 SELECT pg_get_functiondef('lts_income_private.rows_v296(uuid,date,date)'::regprocedure)INTO body;
 IF position('IF p_user_id IS DISTINCT FROM public.lts_browser_assert_user_v1()'IN body)=0 THEN RAISE EXCEPTION 'Actual auth guard changed';END IF;
 IF position('FROM unique_rows WHERE NOT public.lts_income_expense_offset_v397(p_user_id,x)'IN body)=0 THEN RAISE EXCEPTION 'Final canonical exclusion missing';END IF;n:=n+1;
 IF has_function_privilege('anon','public.lts_income_expense_offset_v397(uuid,jsonb)','EXECUTE') OR has_function_privilege('authenticated','public.lts_income_expense_offset_v397(uuid,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'Unnecessary direct access granted';END IF;
 IF NOT has_function_privilege('service_role','public.lts_income_expense_offset_v397(uuid,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'Service reader missing execute';END IF;n:=n+1;
 RAISE NOTICE 'V397: % meaningful controls passed; original auth code preserved; no auth/session acceptance claimed',n;
END $tests$;
ROLLBACK;
