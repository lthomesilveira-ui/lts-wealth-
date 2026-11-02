CREATE FUNCTION pg_temp.check_case(p_ok boolean,p_name text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF p_ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',p_name;END IF;RAISE NOTICE 'PASS: %',p_name;END $$;
DO $tests$
DECLARE r jsonb:='[{"period_start":"2025-01-01","period_end":"2025-02-01","rate_pct":1},{"period_start":"2025-02-01","period_end":"2025-03-01","rate_pct":2}]';j jsonb;k jsonb;u uuid:='11111111-1111-4111-8111-111111111111';
BEGIN
 j:=public.lts_family_savings_calculate_v398(1000,'2025-01-01','2025-03-01',r,'[]');
 PERFORM pg_temp.check_case((j->>'balance_brl')::numeric=1030.20,'compounds published full periods');
 PERFORM pg_temp.check_case((j->>'completed_periods')::integer=2,'counts completed anniversaries');
 PERFORM pg_temp.check_case(j->'contractual_due_date'='null'::jsonb AND j->'forecasts_are_repayments'='false','no fixed due date or projected amortization');
 j:=public.lts_family_savings_calculate_v398(1000,'2025-01-01','2025-01-31',r,'[]');
 PERFORM pg_temp.check_case((j->>'balance_brl')::numeric=1000,'incomplete month earns no correction');
 j:=public.lts_family_savings_calculate_v398(1000,'2025-01-01','2025-03-15',r,'[]');
 PERFORM pg_temp.check_case((j->>'balance_brl')::numeric=1030.20,'announced future months do not accrue early');
 j:=public.lts_family_savings_calculate_v398(1000,'2025-01-01','2025-04-01',r,'[]');
 PERFORM pg_temp.check_case(j->>'status'='rate_coverage_incomplete' AND j->'balance_brl'='null','missing official rate is visible');
 j:=public.lts_family_savings_calculate_v398(1000,'2025-01-01','2025-02-01',r||jsonb_build_array(r->0),'[]');
 PERFORM pg_temp.check_case(j->>'status'='rate_coverage_incomplete','duplicate period rejected');
 j:=public.lts_family_savings_calculate_v398(1000,'2025-01-01','2025-03-01',r,'[{"date":"2025-02-01","amount":100}]');
 PERFORM pg_temp.check_case((j->>'balance_brl')::numeric=928.20 AND (j->>'confirmed_repayments_brl')::numeric=100,'anniversary payment applied once after prior correction');
 j:=public.lts_family_savings_calculate_v398(1000,'2025-01-01','2025-02-01',r,'[{"date":"2025-01-15","amount":100}]');
 PERFORM pg_temp.check_case((j->>'balance_brl')::numeric=909,'intraperiod repayment reduces savings base');
 j:=public.lts_family_savings_calculate_v398(1000,'2025-01-01','2025-02-01',r,'[{"date":"2025-02-01","amount":1011}]');
 PERFORM pg_temp.check_case(j->>'status'='payment_exceeds_balance','overpayment not silently clipped');
 j:=public.lts_family_savings_calculate_v398(1000,'2025-01-01','2025-04-01',r,'[{"date":"2025-02-01","amount":1010}]');
 PERFORM pg_temp.check_case(j->>'status'='settled' AND (j->>'balance_brl')::numeric=0,'settled balance stops growing without future rates');
 j:=public.lts_family_savings_calculate_v398(1000,'2025-01-01','2025-02-01',r,'[{"date":"2025-01-15"}]');
 PERFORM pg_temp.check_case(j->>'status'='invalid_payment','missing amount rejected');
 j:=public.lts_family_savings_calculate_v398(1000,'2025-01-01','2025-02-01',r,'[{"date":"2025-01-99","amount":5}]');
 PERFORM pg_temp.check_case(j->>'status'='invalid_payment','invalid date rejected');
 k:=public.lts_commitments_summary_v1(u,'2025-03-01');
 PERFORM pg_temp.check_case(k#>>'{commitments,1,next_due}'='2027-04-01','unconfigured owner unchanged');
 INSERT INTO public.lts_family_loan_v398(user_id,commitment_id,original_principal,starts_on,contract_ref,source_label)
 VALUES(u,'pai_mae',1000,'2025-01-01','synthetic-family','Synthetic');
 INSERT INTO public.lts_savings_rate_v398(period_start,period_end,rate_pct,source_url)
 SELECT (x->>'period_start')::date,(x->>'period_end')::date,(x->>'rate_pct')::numeric,'https://api.bcb.gov.br/dados/serie/bcdata.sgs.195/dados' FROM jsonb_array_elements(r)x;
 j:=public.lts_commitments_summary_v1(u,'2025-03-01');
 PERFORM pg_temp.check_case(j#>'{commitments,0}'=k#>'{commitments,0}','unrelated commitment byte-equivalent');
 PERFORM pg_temp.check_case((j#>>'{commitments,1,current_documentary_debt_balance}')::numeric=1030.20,'summary uses corrected balance');
 PERFORM pg_temp.check_case(j#>>'{commitments,1,planned_next_payment_date}'='2027-04-01' AND j#>'{commitments,1,next_due}'='null','planned date separated from obligation');
 PERFORM pg_temp.check_case((j#>>'{commitments,1,remaining_scheduled_outflow}')::numeric=50,'cash plan preserved without adding to principal');
 PERFORM pg_temp.check_case(j#>>'{commitments,1,schedule_rows,0,status}'='planned','future installments labeled planning');
 INSERT INTO public.financial_events(id,user_id,metadata,status,nature) VALUES('22222222-2222-4222-8222-222222222222',u,'{"contract_ref":"synthetic-family"}','confirmed','expense');
 j:=public.lts_family_loan_position_v398(u,'2025-03-01');
 PERFORM pg_temp.check_case((j->>'confirmed_repayments_brl')::numeric=0,'unproved event does not amortize');
 INSERT INTO public.test_bank_source VALUES('22222222-2222-4222-8222-222222222222','33333333-3333-4333-8333-333333333333','2025-02-01',-100);
 j:=public.lts_family_loan_position_v398(u,'2025-03-01');
 PERFORM pg_temp.check_case((j->>'balance_brl')::numeric=928.20,'verified identity-linked payment amortizes');
 INSERT INTO public.test_bank_source SELECT * FROM public.test_bank_source;
 j:=public.lts_family_loan_position_v398(u,'2025-03-01');
 PERFORM pg_temp.check_case(j->>'status'='payment_proof_ambiguous' AND j->'balance_brl'='null','ambiguous bank proof cannot reduce balance');
 PERFORM pg_temp.check_case(NOT has_function_privilege('anon','public.lts_family_loan_position_v398(uuid,date)','EXECUTE') AND NOT has_function_privilege('authenticated','public.lts_family_loan_position_v398(uuid,date)','EXECUTE'),'internal reader has no public execute');
 PERFORM pg_temp.check_case((SELECT relrowsecurity FROM pg_class WHERE oid='public.lts_family_loan_v398'::regclass),'owner policy enabled');
END $tests$;
-- Response ingestion is idempotent and rejects an entire malformed response.
INSERT INTO lts_savings_private_v398.request(request_id) VALUES(8001);
INSERT INTO net._http_response VALUES(8001,200,'[{"data":"01/01/2025","dataFim":"01/02/2025","valor":"1"},{"data":"01/02/2025","dataFim":"01/03/2025","valor":"2"}]',false,NULL);
SELECT lts_savings_private_v398.collect();
TABLE lts_savings_private_v398.request;
SELECT pg_temp.check_case((SELECT accepted_rows=2 AND error_code IS NULL FROM lts_savings_private_v398.request WHERE request_id=8001),'official response accepted');
SELECT pg_temp.check_case(lts_savings_private_v398.collect()='{ "changed_rows": 0 }'::jsonb,'response replay writes zero');
INSERT INTO lts_savings_private_v398.request(request_id) VALUES(8002);
INSERT INTO net._http_response VALUES(8002,200,'[{"data":"01/03/2025","dataFim":"01/04/2025","valor":"1"},{"data":"bad","valor":"1"}]',false,NULL);
SELECT lts_savings_private_v398.collect();
SELECT pg_temp.check_case(NOT EXISTS(SELECT 1 FROM public.lts_savings_rate_v398 WHERE period_start='2025-03-01'),'malformed response has no partial writes');
SELECT pg_temp.check_case((SELECT count(*)=1 FROM cron.job WHERE jobname='lts_savings_daily_v398'),'one private scheduled collector');
SELECT pg_temp.check_case(public.lts_backup_modern_export_v380('11111111-1111-4111-8111-111111111111')#>'{tables,old_fixture}'='["preserved"]','old selective backup content preserved');
SELECT pg_temp.check_case(public.lts_backup_modern_export_v380('11111111-1111-4111-8111-111111111111')#>>'{tables,lts_family_loan_v398,0,original_principal}'='1000','new loan input included in selected backup');
SELECT pg_temp.check_case(public.lts_backup_modern_export_v380('11111111-1111-4111-8111-111111111111')#>>'{coverage,selected_tables}'='3','selected backup count agrees with actual keys');
