\set ON_ERROR_STOP on
CREATE FUNCTION wealth_test.call_result(f text) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE j jsonb; s text; m text;
BEGIN
 EXECUTE 'SELECT public.'||quote_ident(f)||'()' INTO j;
 RETURN jsonb_build_object('ok',true,'value',j-'computed_at'-'bank_positions');
EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS s=RETURNED_SQLSTATE,m=MESSAGE_TEXT;
 RETURN jsonb_build_object('ok',false,'state',s,'message',m);
END $$;
CREATE FUNCTION wealth_test.compare_readers(label text, expected_error text DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
DECLARE a jsonb;b jsonb; suffix text;
BEGIN
 FOREACH suffix IN ARRAY ARRAY['178','242'] LOOP
  a:=wealth_test.call_result('lts_browser_cash_today_v'||suffix||'_before');
  b:=wealth_test.call_result('lts_browser_cash_today_v'||suffix);
  PERFORM wealth_test.assert_true(a=b,label||' unchanged v'||suffix);
  IF expected_error IS NOT NULL THEN
   PERFORM wealth_test.assert_true(b->>'ok'='false' AND b->>'message' LIKE expected_error,label||' expected error v'||suffix);
  ELSE
   PERFORM wealth_test.assert_true(b->>'ok'='true',label||' success v'||suffix);
  END IF;
 END LOOP;
END $$;
SELECT wealth_test.compare_readers('valid full functions');
SELECT wealth_test.assert_true(public.lts_browser_cash_today_v178()->'bank_positions'=public.lts_open_finance_current_bank_position_v1(public.lts_browser_assert_user_v1())->'accounts','exact projection from same current reader');
SELECT wealth_test.assert_true(public.lts_browser_cash_today_v242()->'bank_positions'=public.lts_browser_cash_today_v178()->'bank_positions','cash242 carries metadata unchanged');
SELECT wealth_test.assert_true(jsonb_array_length(public.lts_browser_cash_today_v178()->'bank_positions')=3,'three positions');
SELECT wealth_test.assert_true(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.lts_browser_cash_today_v178()->'bank_positions') a WHERE (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(a) k)<>ARRAY['as_of','balance','institution','institution_code','source_id']),'only five permitted projection keys');
SELECT wealth_test.assert_true((public.lts_browser_cash_today_v178()#>>'{bank_positions,0,as_of}')::timestamptz='2031-02-13T09:13:11.456Z'::timestamptz,'source instant millisecond precision retained');
SELECT wealth_test.assert_true(public.lts_browser_cash_today_v178()#>>'{bank_positions,0,institution_code}'='341' AND public.lts_browser_cash_today_v178()#>>'{bank_positions,1,institution_code}'='237' AND public.lts_browser_cash_today_v178()#>>'{bank_positions,2,institution_code}'='336','original source ordering retained');
SELECT wealth_test.assert_true((public.lts_browser_cash_today_v178()->>'cash')::numeric=1221.35 AND (public.lts_browser_cash_today_v242()->>'available_total')::numeric=1303.69,'synthetic figures exact');
SELECT wealth_test.assert_true(public.lts_browser_cash_today_v178()#>'{day,Itaú,net}'='null'::jsonb AND public.lts_browser_cash_today_v178()#>'{day,fix86_columns,entradas}'='null'::jsonb,'financial nulls stay null');
CREATE TEMP TABLE payload_before AS SELECT jsonb_agg(to_jsonb(s) ORDER BY id) payload FROM public.lts_open_finance_staging s;
SELECT public.lts_browser_cash_today_v178(),public.lts_browser_cash_today_v242() \g /dev/null
SELECT wealth_test.assert_true((SELECT payload FROM payload_before)=(SELECT jsonb_agg(to_jsonb(s) ORDER BY id) FROM public.lts_open_finance_staging s),'no staging or pending mutation');

-- Existing backend guards must raise precisely the same exception before/after.
UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{balance}','1234.57') WHERE institution_code='341' AND resource_type='balance';
SELECT wealth_test.compare_readers('one cent raw mismatch','normalized checking balance differs from bank source');
SELECT wealth_test.reset_fixtures();
UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{balance}','null') WHERE institution_code='341' AND resource_type='balance';
SELECT wealth_test.compare_readers('null raw amount','checking account positions incomplete, ambiguous or invalid');
SELECT wealth_test.reset_fixtures();
UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{balance}','"1234.56"') WHERE institution_code='341' AND resource_type='balance';
SELECT wealth_test.compare_readers('string raw amount','checking account positions incomplete, ambiguous or invalid');
SELECT wealth_test.reset_fixtures();
UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{available_balance}','true') WHERE institution_code='341' AND resource_type='balance';
SELECT wealth_test.compare_readers('boolean normalized amount','checking account positions incomplete, ambiguous or invalid');
SELECT wealth_test.reset_fixtures();
UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{as_of}','null') WHERE institution_code='341' AND resource_type='balance';
SELECT wealth_test.compare_readers('null source time','checking account positions incomplete, ambiguous or invalid');
SELECT wealth_test.reset_fixtures();
UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{as_of}','"invalid-timestamp"') WHERE institution_code='341' AND resource_type='balance';
SELECT wealth_test.compare_readers('invalid source time','invalid input syntax for type timestamp with time zone%');
SELECT wealth_test.reset_fixtures();
UPDATE public.lts_open_finance_staging SET raw_payload=raw_payload-'updatedAt' WHERE institution_code='341' AND resource_type='balance';
SELECT wealth_test.compare_readers('missing raw timestamp','normalized checking balance differs from bank source');
SELECT wealth_test.reset_fixtures();
UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{updatedAt}','"2031-02-12T09:13:11.456Z"') WHERE institution_code='341' AND resource_type='balance';
SELECT wealth_test.compare_readers('raw timestamp differs','normalized checking balance differs from bank source');
SELECT wealth_test.reset_fixtures();
UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{provider_account_id}','"wrong-account"') WHERE institution_code='341' AND resource_type='balance';
SELECT wealth_test.compare_readers('account identity mismatch','checking account positions incomplete, ambiguous or invalid');
SELECT wealth_test.reset_fixtures();
UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{currencyCode}','"USD"') WHERE institution_code='341' AND resource_type='balance';
SELECT wealth_test.compare_readers('raw currency mismatch','checking account positions incomplete, ambiguous or invalid');
SELECT wealth_test.reset_fixtures();
UPDATE public.lts_open_finance_staging SET currency='USD' WHERE institution_code='341' AND resource_type='balance';
SELECT wealth_test.compare_readers('staging currency mismatch','checking account positions incomplete, ambiguous or invalid');
SELECT wealth_test.reset_fixtures();
INSERT INTO public.lts_open_finance_staging SELECT '00000000-0000-0000-0000-000000000099'::uuid,user_id,resource_type,institution_code,currency,provider_account_ref,signed_amount,provider_deleted_at,normalized_payload,raw_payload,raw_hash FROM public.lts_open_finance_staging WHERE institution_code='341' AND resource_type='balance';
SELECT wealth_test.compare_readers('ambiguous duplicate account','checking account positions incomplete, ambiguous or invalid');
SELECT wealth_test.reset_fixtures();
UPDATE public.lts_open_finance_staging SET provider_deleted_at=now() WHERE institution_code='341' AND resource_type='balance';
SELECT wealth_test.compare_readers('deleted account incomplete','checking account positions incomplete, ambiguous or invalid');
SELECT wealth_test.reset_fixtures();
UPDATE public.lts_open_finance_staging SET signed_amount=NULL WHERE institution_code='341' AND resource_type='balance';
SELECT wealth_test.compare_readers('missing canonical amount','canonical bank positions incomplete');
SELECT wealth_test.reset_fixtures();
UPDATE wealth_test.resources SET d0=NULL;
SELECT wealth_test.compare_readers('null cofrinho','canonical current liquidity incomplete');
SELECT wealth_test.reset_fixtures();
DELETE FROM public.lts_validated_lock_registry WHERE lock_key LIKE 'morgan_available_%';
SELECT wealth_test.compare_readers('missing brokerage','canonical current liquidity incomplete');
SELECT wealth_test.reset_fixtures();
DELETE FROM public.asset_positions;
SELECT wealth_test.compare_readers('missing fgts','canonical current liquidity incomplete');
SELECT wealth_test.reset_fixtures();
UPDATE wealth_test.resources SET withdrawals=100;
SELECT wealth_test.assert_true(wealth_test.call_result('lts_browser_cash_today_v242_before')=wealth_test.call_result('lts_browser_cash_today_v242') AND wealth_test.call_result('lts_browser_cash_today_v242')->>'message'='brokerage withdrawal exceeds last known resource','cash242 negative adjustment error unchanged');
SELECT wealth_test.reset_fixtures();
UPDATE wealth_test.resources SET withdrawals=NULL,fgts=NULL;
SELECT wealth_test.compare_readers('cash242 null adjustments');
SELECT wealth_test.reset_fixtures();

-- Future source timestamp is retained, never replaced by a collection/page date.
-- Existing checking reader permits it: freshness UI must show unknown/anomaly.
UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{as_of}','"2099-01-01T00:00:00Z"'),raw_payload=jsonb_set(raw_payload,'{updatedAt}','"2099-01-01T00:00:00Z"') WHERE institution_code='341' AND resource_type='balance';
SELECT wealth_test.compare_readers('future source preserved');
SELECT wealth_test.assert_true((public.lts_browser_cash_today_v178()#>>'{bank_positions,0,as_of}')::timestamptz='2099-01-01T00:00:00Z'::timestamptz,'future metadata not relabeled current');
SELECT wealth_test.reset_fixtures();
UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{as_of}','"2031-02-14T02:59:59Z"'),raw_payload=jsonb_set(raw_payload,'{updatedAt}','"2031-02-14T02:59:59Z"') WHERE institution_code='341' AND resource_type='balance';
SELECT wealth_test.compare_readers('BRT previous day boundary');
SELECT wealth_test.assert_true((public.lts_browser_cash_today_v178()#>>'{bank_positions,0,as_of}')::timestamptz AT TIME ZONE 'America/Sao_Paulo'='2031-02-13 23:59:59'::timestamp,'BRT date is provider reference');
SELECT wealth_test.reset_fixtures();

-- Other owners never contribute to the scoped source. Different requested owner fails.
INSERT INTO public.lts_open_finance_staging SELECT '00000000-0000-0000-0000-000000000099'::uuid,'20000000-0000-0000-0000-000000000002'::uuid,resource_type,institution_code,currency,provider_account_ref,999999,provider_deleted_at,normalized_payload,raw_payload,raw_hash FROM public.lts_open_finance_staging WHERE institution_code='341' AND resource_type='balance';
SELECT wealth_test.compare_readers('other owner excluded');
SELECT set_config('wealth_test.user_id','20000000-0000-0000-0000-000000000002',false);
SELECT wealth_test.compare_readers('wrong owner incomplete','checking account positions incomplete, ambiguous or invalid');
SELECT set_config('wealth_test.user_id','',false);
SELECT wealth_test.compare_readers('missing authentication','fixture unauthenticated');
SELECT set_config('wealth_test.user_id','10000000-0000-0000-0000-000000000001',false);
SELECT wealth_test.reset_fixtures();

-- ACL behavior is exercised with synthetic roles. No live ACL or IDs in this harness.
GRANT INSERT,SELECT ON wealth_test.assertions TO wealth_fixture_browser,wealth_fixture_outsider;
SET ROLE wealth_fixture_browser;
SELECT wealth_test.compare_readers('authorized browser role');
RESET ROLE;
SET ROLE wealth_fixture_outsider;
SELECT wealth_test.assert_true(wealth_test.call_result('lts_browser_cash_today_v178')->>'state'='42501' AND wealth_test.call_result('lts_browser_cash_today_v242')->>'state'='42501','outsider cannot execute production entrypoints');
RESET ROLE;
SELECT wealth_test.assert_true(NOT has_function_privilege('wealth_fixture_browser','public.lts_open_finance_checking_positions_v1(uuid)','EXECUTE'),'browser cannot directly execute checking source');
SELECT wealth_test.assert_true(NOT has_function_privilege('wealth_fixture_browser','public.lts_open_finance_current_bank_position_v1(uuid)','EXECUTE'),'browser cannot directly execute current source');
SELECT count(*) AS synthetic_assertions_passed FROM wealth_test.assertions;
