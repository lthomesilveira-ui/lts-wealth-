-- Synthetic civil-date window checks; contains no private financial source.
WITH p AS (SELECT
 '{"id":"previous","paymentDate":"2025-12-20T00:00:00.000Z","amount":17.5,"valueType":"FULL_PAYMENT","paymentMode":"DEBIT_ACCOUNT","currencyCode":"BRL"}'::jsonb old_pay,
 '{"id":"current","paymentDate":"2026-01-20T00:00:00.000Z","amount":17.5,"valueType":"FULL_PAYMENT","paymentMode":"DEBIT_ACCOUNT","currencyCode":"BRL"}'::jsonb cur_pay),
base AS(SELECT jsonb_build_object('issuer_settlement_policy','one_full_payment_in_cycle_v301',
 'issuer_payments',jsonb_build_array(old_pay,cur_pay),'settlement_manifest',jsonb_build_array(cur_pay)) c,
 '{"expected_closing_date":"2026-01-07","expected_payment_date":"2026-01-21","expected_amount":17.5}'::jsonb l,old_pay,cur_pay FROM p),
cases AS(SELECT v.name,v.expected,v.c,v.l FROM base b CROSS JOIN LATERAL(VALUES
 ('positive_cumulative',true,b.c,b.l),
 ('positive_current_only',true,b.c||jsonb_build_object('issuer_payments',jsonb_build_array(cur_pay)),b.l),
 ('wrong_policy',false,b.c||'{"issuer_settlement_policy":"other"}',b.l),
 ('missing_current_payment',false,b.c||jsonb_build_object('issuer_payments',jsonb_build_array(old_pay)),b.l),
 ('duplicate_payment_identity',false,b.c||jsonb_build_object('issuer_payments',jsonb_build_array(old_pay,cur_pay,cur_pay)),b.l),
 ('two_current_payments',false,b.c||jsonb_build_object('issuer_payments',jsonb_build_array(old_pay,cur_pay,cur_pay||'{"id":"second"}')),b.l),
 ('wrong_amount',false,jsonb_set(b.c,'{issuer_payments,1,amount}','17.51'),b.l),
 ('wrong_currency',false,jsonb_set(b.c,'{issuer_payments,1,currencyCode}','"USD"'),b.l),
 ('partial_payment',false,jsonb_set(b.c,'{issuer_payments,1,valueType}','"PARTIAL_PAYMENT"'),b.l),
 ('wrong_payment_mode',false,jsonb_set(b.c,'{issuer_payments,1,paymentMode}','"BOLETO"'),b.l),
 ('invalid_timestamp',false,jsonb_set(b.c,'{issuer_payments,1,paymentDate}','"2026-99-20T00:00:00.000Z"'),b.l),
 ('on_closing_not_after',false,jsonb_set(b.c,'{issuer_payments,1,paymentDate}','"2026-01-07T00:00:00.000Z"'),b.l),
 ('after_bank_posting',false,jsonb_set(b.c,'{issuer_payments,1,paymentDate}','"2026-01-22T00:00:00.000Z"'),b.l),
 ('different_selected_manifest',false,jsonb_set(b.c,'{settlement_manifest,0,id}','"other"'),b.l),
 ('empty_manifest',false,b.c||'{"settlement_manifest":[]}',b.l),
 ('duplicate_manifest',false,b.c||jsonb_build_object('settlement_manifest',jsonb_build_array(cur_pay,cur_pay)),b.l),
 ('null_payments',false,b.c||'{"issuer_payments":null}',b.l),
 ('missing_payment_id',false,jsonb_set(b.c,'{issuer_payments,1,id}','null'),b.l),
 ('invalid_closing_date',false,b.c,b.l||'{"expected_closing_date":"2026-02-30"}'),
 ('bank_before_closing',false,b.c,b.l||'{"expected_payment_date":"2026-01-06"}'),
 ('wrong_expected_amount',false,b.c,b.l||'{"expected_amount":19}')
 )v(name,expected,c,l)),
result AS(SELECT name,expected,public.lts_card_cycle_settlement_v301(c,l) IS NOT NULL actual FROM cases)
SELECT jsonb_build_object('cases',count(*),'passed',count(*)=21 AND bool_and(actual IS NOT DISTINCT FROM expected),
 'failed',coalesce(jsonb_agg(name)FILTER(WHERE actual IS DISTINCT FROM expected),'[]')) AS receipt FROM result;
